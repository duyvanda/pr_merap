USE [PhaNam_eSales_PRO]
GO

/****** Object:  StoredProcedure [dbo].[OM20870_pgAccumulatedResult]    Script Date: 24/05/2022 9:07:19 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER PROC [dbo].[OM20870_pgAccumulatedResult] 
----
/*
exec [dbo].[OM20870_pgAccumulatedResultDet] @UserName='admin',@CpnyID='MR0001',@LangID=1,@BranchID='MR0001',@Status='H'
,@AccumulateID='DUYEN_TTMB02_10D',@Cust=N'',@strData='',@FromDate='2020-06-24 00:00:00',@ToDate='2021-06-28 00:00:00'
*/
@UserName VARCHAR(30),   
@CpnyID VARCHAR(30),   
@LangID SMALLINT,
@BranchID  VARCHAR(30),
@Status VARCHAR(5),
@State VARCHAR(MAX),
@AccumulateID VARCHAR(50),
@Cust NVARCHAR(MAX),
@FromDate DATETIME,
@ToDate DATETIME
AS
	SET FMTONLY OFF
	-- TuanTA Commented 24/02/2021: Declare Virtual Table OM_AccumulatedResult Push All Value To Table From Store
	SELECT Sel = CAST(0 AS BIT), a.LineRef,
								 a.AccumulateID,
								 a.LevelID,
								 LevelIDRegis = d.LevelID,
								 c.LevelDescr,
								 a.BranchID,
								 a.CustID,
								 b.CustName,
								 a.AccumulatedValue,
								 a.Pass,
								 a.Prepay,
								 a.Reward,
								 a.CloseDate,
								 a.FromDate,
								 a.ToDate,
								 CheckDate = a.ToDate,
								 TotalValueUse = CAST(0 AS FLOAT), 
								 StrOrder = '',
								 MinDateOrder = CONVERT(DATE, GETDATE()),
								 a.RewardBack,
								 RewardFirst = a.Reward,
								 BeforeReward = CAST(0 AS FLOAT),
								 UsedAmt  = CAST(0 AS FLOAT)
	INTO #tblOM_AccumulatedResult
	FROM OM_AccumulatedResult a WITH(NOLOCK)
	INNER JOIN AR_Customer b WITH(NOLOCK) ON a.CustID = b.CustId
	AND a.BranchID = b.BranchID
	INNER JOIN OM_AccumulatedLevel c WITH(NOLOCK) ON a.AccumulateID = c.AccumulateID
	AND a.LevelID = c.LevelID
	INNER JOIN OM_AccumulatedRegis d WITH(NOLOCK) ON d.AccumulateID = a.AccumulateID
	AND d.CustID = a.CustID
	AND d.Status = 'C' 
	-- TuanTA Commented 03/02/2021: Input Record String Split (,) From @State To Table #State
	SELECT sp.value AS StateID INTO #StateParam
	FROM STRING_split(@State,
					  ',') sp 

	-- TuanTA Commented 24/02/2021: After Generation Model Table, We Delete All Recordd
	DELETE FROM #tblOM_AccumulatedResult 

	-- Create Table Result Total Value AccumulateID Group By CustID, BranchID
	CREATE TABLE #tblAccumulatedResultTotal (
		CustID varchar(50) NOT NULL,
		BranchID varchar(30) NOT NULL,
		Total FLOAT NOT NULL,
	)
	INSERT INTO #tblAccumulatedResultTotal(CustID,
										   BranchID,
										   Total)

	-- Sum Value AccumulateID Group By CustID, BranchID
	SELECT h.CustID,
		   h.BranchID,
		   Total = SUM(h.AccumulatedValue)
	FROM OM_AccumulatedResult h WITH(NOLOCK)
	WHERE h.BranchID = @BranchID
	  AND h.AccumulateID = @AccumulateID --AND h.Pass =1

	GROUP BY h.CustID,
			 h.BranchID
	CREATE TABLE #tblOrder 
	(
		CustID varchar(50) NOT NULL,
		OrderDate datetime NOT NULL
	)
	--SELECT DISTINCT o.BranchID, o.OrderNbr , o.OrigOrderNbr
	--INTO #ReturnOrd
	--FROM dbo.OM_SalesOrd o WITH(NOLOCK)
	--INNER JOIN dbo.OM_PDASalesOrd od WITH(NOLOCK) ON od.BranchID = o.BranchID AND od.OriOrderNbrUp = o.OrderNbr
	--INNER JOIN dbo.OM_SalesOrd oc WITH(NOLOCK) ON oc.BranchID = od.BranchID AND oc.OrigOrderNbr = od.OrderNbr
	--WHERE oc.Status ='C' AND o.BranchID=@BranchID --LẤY NGÀY ĐƠN HÀNG IN KHÔNG LOẠI ĐƠN TRẢ, NÊN KO LOẠI CÁC ĐƠN IN CÓ ĐƠN TRẢ

	---- Get Bill Status = 'C'
	--SELECT o.BranchID, o.OrigOrderNbr AS OrderNbr
	--INTO #SalesOrdC
	--FROM OM_SalesOrd o WITH(NOLOCK)
	----LEFT JOIN #ReturnOrd r WITH(NOLOCK) ON r.BranchID = o.BranchID AND r.OrderNbr = o.OrderNbr 
	--WHERE OrderType = 'IN' AND o.BranchID = @BranchID AND Status = 'C'
	----AND r.OrderNbr IS NULL

	----AND  o.OrderDate  <= CASE WHEN  o.CustID='P4723-0286' THEN '20210623' ELSE CAST(GETDATE() AS DATE) END
	
	-- Filter Accumulate Result Has Been Approved (Status = C)
	IF(@Status = 'C') 
	BEGIN
		SELECT T1.AccumulateID, T1.LineRef, T1.BranchID, T1.CustID, SUM(T2.Amt) AS UsedAmt
		INTO #OrdAccuResultDet
		FROM OM_AccumulatedResultDet T1 WITH(NOLOCK)
		INNER JOIN OM_PDAOrdAccumulate T2 WITH(NOLOCK) ON T1.BranchID = T2.BranchID AND T1.OrderNbr = T2.OrderNbr
		WHERE T1.AccumulateID = @AccumulateID
		GROUP BY T1.AccumulateID, T1.LineRef, T1.BranchID, T1.CustID
		
		
		INSERT INTO #tblOM_AccumulatedResult (Sel, LineRef, AccumulateID, LevelID, LevelIDRegis, 
		LevelDescr, BranchID, CustID, CustName, AccumulatedValue, Pass, Prepay, Reward, CloseDate
		, FromDate, ToDate, CheckDate, TotalValueUse, StrOrder, MinDateOrder, RewardBack, RewardFirst, BeforeReward, UsedAmt)
		SELECT Sel = CAST(0 AS BIT),
			   a.LineRef,
			   a.AccumulateID,
			   d.LevelID,
			   LevelIDRegis = d.LevelID,
			   LevelDescr = ISNULL(c.LevelDescr, ''),
			   a.BranchID,
			   a.CustID,
			   b.CustName,
			   a.AccumulatedValue,
			   a.Pass,
			   a.Prepay,
			   a.Reward,
			   a.CloseDate,
			   a.FromDate,
			   a.ToDate,
			   CheckDate = a.ToDate, -- field lấy lên để check data
			   TotalValueUse = ISNULL(k.Total, CAST(0 AS FLOAT)),
			   StrOrder = '',
			   CONVERT(DATE, GETDATE())  AS MinDateOrder,
			   a.RewardBack,
			   RewardFirst = a.Reward,
			   --BeforeReward = a.Reward + Prepay,
			   BeforeReward = CASE WHEN ISNULL(c.LevelType,'M')='P' 
							THEN round(cast(ISNULL(c.PercentBonus,0) as float)*A.AccumulatedValue/100,0)
							ELSE cast( ISNULL(c.PercentBonus,0) as float) END,--20210916 trunght Lấy từ level
			   ISNULL(T7.UsedAmt, 0)
		FROM OM_AccumulatedResult a WITH(NOLOCK)
		INNER JOIN AR_Customer b WITH(NOLOCK) ON a.CustID = b.CustId AND a.BranchID = b.BranchID
		INNER JOIN OM_AccumulatedRegis d WITH(NOLOCK) ON d.AccumulateID = a.AccumulateID AND d.CustID = a.CustID AND d.Status = 'C'
		--LEFT JOIN OM_AccumulatedLevel c WITH(NOLOCK) ON d.AccumulateID = c.AccumulateID AND d.LevelID = c.LevelID
		LEFT JOIN OM_AccumulatedLevel c WITH(NOLOCK) ON a.AccumulateID = c.AccumulateID AND a.LevelID = c.LevelID--20210923 trunght lấy a. để join không lấy d. vì KH đăng kí mức này nhưng vẫn cho nhận mức khác 
		LEFT JOIN #tblAccumulatedResultTotal k ON a.CustID = k.CustID AND a.BranchID = b.BranchID
		INNER JOIN #StateParam T6 ON T6.StateID = b.State
		LEFT JOIN #OrdAccuResultDet T7 ON a.AccumulateID = T7.AccumulateID AND a.LineRef = T7.LineRef AND a.CustID = T7.CustID AND a.BranchID = T7.BranchID
		WHERE a.BranchID = @BranchID
		  AND a.AccumulateID = @AccumulateID
		  AND ((a.CustID LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI)
			   OR (b.CustName LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI))
		  AND a.CloseDate BETWEEN @FromDate AND @ToDate   

		DROP TABLE #OrdAccuResultDet
	END 
	ELSE   
	BEGIN 
	DECLARE @EffectDateNbr INT = ISNULL(
								(SELECT TOP 1 EffectDateNbr
								FROM OM_Accumulated a WITH(NOLOCK)
								WHERE a.AccumulateID = @AccumulateID ), 0) 											
	DECLARE @AccLatType VARCHAR(5) = ISNULL(
								(SELECT TOP 1 AccLatType
								FROM OM_Accumulated a WITH(NOLOCK)
								WHERE a.AccumulateID = @AccumulateID ), '')

	CREATE TABLE #tblAccumulated 
	(
		CustID varchar(50) NOT NULL,
		ToDate datetime NOT NULL
	)

	INSERT INTO #tblAccumulated(CustID,ToDate)
	SELECT re.CustID, ToDate = MAX(re.ToDate)
	FROM OM_AccumulatedResult re WITH(NOLOCK)
	WHERE re.AccumulateID = @AccumulateID AND re.BranchID = @BranchID
	GROUP BY re.CustID 
	
	IF(@StatUS='H' AND @AccLatType='S')--20211001 trunght sua truong hop chot nhieu lam
	BEGIN 
		INSERT INTO #tblOrder
		(
			CustID,
			OrderDate
		)
		SELECT sa.CustID, OrderDate = MIN(sa.OrderDate)
		FROM OM_PDASalesOrd sa WITH(NOLOCK)
		INNER JOIN OM_PDASalesOrdDet det WITH(NOLOCK) ON sa.BranchID = det.BranchID AND sa.OrderNbr = det.OrderNbr
		INNER JOIN OM_AccumulatedRegis re WITH(NOLOCK) ON sa.CustID = re.CustID AND re.Status = 'C'
		INNER JOIN OM_AccumulatedInvtSetup ivt WITH(NOLOCK) ON ivt.InvtID = det.InvtID AND re.AccumulateID = ivt.AccumulateID
		INNER JOIN OM_Accumulated acc WITH(NOLOCK) ON acc.AccumulateID = re.AccumulateID
		INNER JOIN OM_SalesRoute T8 WITH(NOLOCK) ON T8.SalesRouteID = re.SlsPerID AND T8.RouteType = re.BugetID
		INNER JOIN OM_SalesOrd O ON O.BranchID = sa.BranchID AND O.OrigOrderNbr = sa.OrderNbr
		INNER JOIN OM_AccumulatedOrderApproval d WITH(NOLOCK) ON d.OrderNbr = SA.OrderNbr AND d.BranchID = SA.BranchID AND d.AccumulateID = re.AccumulateID
		LEFT JOIN #tblAccumulated tmp ON o.CustID=tmp.CustID
		LEFT JOIN OM_AccumulatedResultDet ad WITH(NOLOCK) ON sa.BranchID =ad.BranchID AND sa.OrderNbr=ad.OrderNbr
		WHERE O.OrderType = 'IN' AND o.BranchID = @BranchID AND O.Status IN('V', 'C')
		  AND ad.BranchID IS NULL --20211229 trunght loại các đơn đã có trong OM_AccumulatedResultDet
		  AND re.AccumulateID = @AccumulateID
		  AND sa.OrderDate >= CONVERT(DATE, re.Crtd_DateTime)
		  AND CONVERT(DATE, sa.OrderDate)<= CONVERT(DATE, acc.ToDate)
		  AND CONVERT(DATE, sa.OrderDate)> CONVERT(DATE, ISNULL(tmp.ToDate,DATEADD(DAY, -1,acc.FromDate)))
		GROUP BY sa.CustID
	END 
	ELSE
	BEGIN
		INSERT INTO #tblOrder
		(
			CustID,
			OrderDate
		)
		SELECT sa.CustID, OrderDate = MIN(sa.OrderDate)
		FROM OM_PDASalesOrd sa WITH(NOLOCK)
		INNER JOIN OM_PDASalesOrdDet det WITH(NOLOCK) ON sa.BranchID = det.BranchID AND sa.OrderNbr = det.OrderNbr
		INNER JOIN OM_AccumulatedRegis re WITH(NOLOCK) ON sa.CustID = re.CustID AND re.Status = 'C'
		INNER JOIN OM_AccumulatedInvtSetup ivt WITH(NOLOCK) ON ivt.InvtID = det.InvtID AND re.AccumulateID = ivt.AccumulateID
		INNER JOIN OM_Accumulated acc WITH(NOLOCK) ON acc.AccumulateID = re.AccumulateID
		INNER JOIN OM_SalesRoute T8 WITH(NOLOCK) ON T8.SalesRouteID = re.SlsPerID AND T8.RouteType = re.BugetID
		INNER JOIN OM_SalesOrd O ON O.BranchID = sa.BranchID AND O.OrigOrderNbr = sa.OrderNbr
		LEFT JOIN OM_AccumulatedResultDet ad WITH(NOLOCK) ON sa.BranchID =ad.BranchID AND sa.OrderNbr=ad.OrderNbr 
		WHERE O.OrderType = 'IN' AND o.BranchID = @BranchID AND O.Status = 'C'
		  AND ad.BranchID IS NULL --20211229 trunght loại các đơn đã có trong OM_AccumulatedResultDet
		  AND re.AccumulateID = @AccumulateID
		  AND sa.OrderDate >= CONVERT(DATE, re.Crtd_DateTime)
		  AND CONVERT(DATE, sa.OrderDate)<= CONVERT(DATE, acc.ToDate)
		  AND CONVERT(DATE, sa.OrderDate)>= CONVERT(DATE, acc.FromDate)
		GROUP BY sa.CustID
	END
	--SELECT * FROM #tblOrder
	--SELECT @EffectDateNbr
	IF(@AccLatType = 'S')
	BEGIN
	-- Nhiều Lần And Chốt Lần Đầu Tiên
	INSERT INTO #tblOM_AccumulatedResult (Sel, LineRef, AccumulateID, LevelID, LevelIDRegis, 
	LevelDescr, BranchID, CustID, CustName, AccumulatedValue, Pass, Prepay, Reward, CloseDate, 
	FromDate, ToDate, CheckDate, TotalValueUse, StrOrder, MinDateOrder, RewardBack, RewardFirst, BeforeReward, UsedAmt)
	SELECT Sel = CAST(0 AS BIT),
		   LineRef = '',
		   c.AccumulateID,
		   LevelID = '',
		   LevelIDRegis = a.LevelID,
		   c.LevelDescr,
		   b.BranchID,
		   a.CustID,
		   b.CustName,
		   AccumulatedValue = CAST(0 AS FLOAT),
		   Pass = CAST(0 AS BIT),
		   Prepay = CAST(0 AS FLOAT),
		   Reward = CAST(0 AS FLOAT),
		   CloseDate = CONVERT(DATE, GETDATE()),
	 -- TuanTA Commented 23/02/2021: If AccLatType = 'Q' AND EffectDateNbr = 0
	 FromDate = CONVERT(DATE, CASE
							WHEN @EffectDateNbr = 0 THEN a.Crtd_DateTime -- Get OrderDate Of First Order
							ELSE d.OrderDate
						END), 
	 -- TuanTA Commented 25/02/2021:  If AccLatType = 'Q' Set ToDate Is ToDay
	 ToDate = CONVERT(DATE, GETDATE()),
	 CheckDate = ISNULL(CASE
							WHEN @EffectDateNbr = 0
								 AND ac.ToDate < CONVERT(DATE, GETDATE()) THEN ac.ToDate
							WHEN @EffectDateNbr = 0
								 AND ac.ToDate >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
							WHEN @EffectDateNbr > 0
								 AND DATEADD(DAY, @EffectDateNbr, d.OrderDate) >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
							ELSE DATEADD(DAY, @EffectDateNbr, d.OrderDate)
						END, CONVERT(DATE, GETDATE())),
	 TotalValueUse = CAST(0 AS FLOAT),
	 StrOrder = '',
	 CONVERT(DATE, d.OrderDate)  AS MinDateOrder,
	 CAST(0 AS FLOAT),
	 CAST(0 AS FLOAT),
	 BeforeReward = CAST(0 AS FLOAT),
	 CAST(0 AS FLOAT)
	FROM OM_AccumulatedRegis a WITH(NOLOCK)
	INNER JOIN AR_Customer b WITH(NOLOCK) ON a.CustID = b.CustId --AND a.BranchID = b.BranchID
	INNER JOIN OM_AccumulatedLevel c WITH(NOLOCK) ON a.AccumulateID = c.AccumulateID AND a.LevelID = c.LevelID
	INNER JOIN OM_Accumulated ac WITH(NOLOCK) ON ac.AccumulateID = a.AccumulateID
	INNER JOIN #tblOrder d ON d.CustID = a.CustID
	INNER JOIN OM_SalesRoute T8 WITH(NOLOCK) ON T8.SalesRouteID = a.SlsPerID AND T8.RouteType = a.BugetID
	INNER JOIN #StateParam T6 ON T6.StateID = b.State
	WHERE b.BranchID = @BranchID
	  AND a.AccumulateID = @AccumulateID
	  AND ((a.CustID LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI)
		   OR (b.CustName LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI))
	  AND a.Status = 'C'
	  AND a.CustID NOT IN
		(
			SELECT CustID FROM #tblAccumulated
		)
	  AND ISNULL(CONVERT(DATE, d.OrderDate), CONVERT(DATE, a.Crtd_DateTime)) <= CONVERT(DATE, GETDATE())
	UNION ALL -- Nhiều Lần And After Latch the first time

	SELECT Sel = CAST(0 AS BIT),
		   LineRef = '',
		   c.AccumulateID,
		   LevelID ='',
		   LevelIDRegis = a.LevelID,
		   c.LevelDescr,
		   b.BranchID,
		   a.CustID,
		   b.CustName,
		   AccumulatedValue = CAST(0 AS FLOAT),
		   Pass = CAST(0 AS BIT),
		   Prepay = CAST(0 AS FLOAT),
		   Reward = CAST(0 AS FLOAT),
		   CloseDate = CONVERT(DATE, GETDATE()), 
	 -- TuanTA Commented 24/02/2021: FromDate After First Time = ToDate Second Time And So On ... + 1
	 FromDate = CONVERT(DATE, CASE
							WHEN @EffectDateNbr = 0 THEN DATEADD(DAY, 1, te.ToDate) -- Get OrderDate Of First Order
							ELSE d.OrderDate
						END), --DATEADD(DAY, 1, te.ToDate), --20211001 trunght lấy ngày đơn hàng
	 -- TuanTA Commented 25/02/2021:  If AccLatType = 'Q' Set ToDate Is ToDay
	 ToDate = CONVERT(DATE, GETDATE()),
	 CheckDate = ISNULL(CASE
							WHEN @EffectDateNbr = 0
								 AND ac.ToDate < CONVERT(DATE, GETDATE()) THEN ac.ToDate
							WHEN @EffectDateNbr = 0
								 AND ac.ToDate >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
							WHEN @EffectDateNbr > 0
								 AND DATEADD(DAY, @EffectDateNbr, d.OrderDate) >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
							ELSE DATEADD(DAY, @EffectDateNbr, d.OrderDate)
						END, CONVERT(DATE, GETDATE())),
	 TotalValueUse = ISNULL(old.Total, CAST(0 AS FLOAT)),
	 StrOrder = '',
	 CONVERT(DATE, d.OrderDate)  AS MinDateOrder,
	 CAST(0 AS FLOAT),
	 CAST(0 AS FLOAT),
	 BeforeReward = CAST(0 AS FLOAT),
	 CAST(0 AS FLOAT)
	FROM OM_AccumulatedRegis a WITH(NOLOCK)
	INNER JOIN AR_Customer b WITH(NOLOCK) ON a.CustID = b.CustId --AND a.BranchID = b.BranchID
	INNER JOIN OM_AccumulatedLevel c WITH(NOLOCK) ON a.AccumulateID = c.AccumulateID AND a.LevelID = c.LevelID
	INNER JOIN OM_Accumulated ac WITH(NOLOCK) ON ac.AccumulateID = a.AccumulateID
	INNER JOIN #tblAccumulated te WITH(NOLOCK) ON a.CustID = te.CustID
	INNER JOIN #tblOrder d ON d.CustID = a.CustID
	INNER JOIN OM_SalesRoute T8 WITH(NOLOCK) ON T8.SalesRouteID = a.SlsPerID AND T8.RouteType = a.BugetID
	LEFT JOIN #tblAccumulatedResultTotal old ON old.CustID = a.CustID AND old.BranchID = @BranchID
	INNER JOIN #StateParam T6 ON T6.StateID = b.State
	WHERE b.BranchID = @BranchID
	  AND a.AccumulateID = @AccumulateID
	  AND ((a.CustID LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI)
		   OR (b.CustName LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI))
	  AND a.Status = 'C'
	  AND a.CustID IN
		(
			 SELECT CustID FROM #tblAccumulated
		)
	  AND 
	  DATEADD(DAY, 1, te.ToDate) 
	  <= 
	  CONVERT(DATE, 
		IIF(@EffectDateNbr = 0, GETDATE(), DATEADD(DAY, @EffectDateNbr, d.OrderDate))
	  ) 
	END 
	ELSE IF(@AccLatType = 'O')-- Chốt 1 lần
	BEGIN
	INSERT INTO #tblOM_AccumulatedResult (Sel, LineRef, AccumulateID, LevelID, LevelIDRegis, 
	LevelDescr, BranchID, CustID, CustName, AccumulatedValue, Pass, Prepay, Reward, CloseDate, 
	FromDate, ToDate, CheckDate, TotalValueUse, StrOrder, MinDateOrder, RewardBack, RewardFirst, BeforeReward, UsedAmt)
	SELECT Sel = CAST(0 AS BIT),
		   LineRef = '',
		   c.AccumulateID,
		   LevelID = '',
		   LevelIDRegis = a.LevelID,
		   c.LevelDescr,
		   b.BranchID,
		   a.CustID,
		   b.CustName,
		   AccumulatedValue = CAST(0 AS FLOAT),
		   Pass = CAST(0 AS BIT),
		   Prepay = CAST(0 AS FLOAT),
		   Reward = CAST(0 AS FLOAT),
		   CloseDate = CONVERT(DATE, GETDATE()),
		   FromDate = CONVERT(DATE, 
			 -- TuanTA Commented 23/02/2021: If AccLatType = 'O' AND EffectDateNbr = 0 THEN GET CreateDateTime Of Accumulated
			 -- Else Get OrderDate Of First Order
			 CASE
				 WHEN @EffectDateNbr = 0 THEN a.Crtd_DateTime
				 ELSE d.OrderDate
			 END),
			ToDate = GETDATE(),
			CheckDate = ISNULL(CASE
									WHEN @EffectDateNbr = 0
										AND ac.ToDate < CONVERT(DATE, GETDATE()) THEN ac.ToDate
									WHEN @EffectDateNbr = 0
										AND ac.ToDate >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
									WHEN @EffectDateNbr > 0
										AND DATEADD(DAY, @EffectDateNbr, d.OrderDate) >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
									ELSE DATEADD(DAY, @EffectDateNbr, d.OrderDate)
								END, CONVERT(DATE, GETDATE())),
			TotalValueUse = CAST(0 AS FLOAT),
			StrOrder = '',
			CONVERT(DATE, d.OrderDate)  AS MinDateOrder,
			CAST(0 AS FLOAT),
			CAST(0 AS FLOAT),
			BeforeReward = CAST(0 AS FLOAT),
			CAST(0 AS FLOAT)
	FROM OM_AccumulatedRegis a WITH(NOLOCK)
	INNER JOIN AR_Customer b WITH(NOLOCK) ON a.CustID = b.CustId --AND a.BranchID = b.BranchID
	INNER JOIN OM_AccumulatedLevel c WITH(NOLOCK) ON a.AccumulateID = c.AccumulateID AND a.LevelID = c.LevelID
	INNER JOIN OM_Accumulated ac WITH(NOLOCK) ON ac.AccumulateID = a.AccumulateID
	INNER JOIN #tblOrder d ON d.CustID = a.CustID
	INNER JOIN OM_SalesRoute T8 WITH(NOLOCK) ON T8.SalesRouteID = a.SlsPerID AND T8.RouteType = a.BugetID
	INNER JOIN #StateParam T6 ON T6.StateID = b.State
	WHERE b.BranchID = @BranchID
	  AND a.AccumulateID = @AccumulateID
	  AND ((a.CustID LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI)
		   OR (b.CustName LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI))
	  AND a.Status = 'C'
	  AND a.CustID NOT IN
		(
			SELECT CustID FROM #tblAccumulated
		 )
	  AND ISNULL(CONVERT(DATE, d.OrderDate), CONVERT(DATE, a.Crtd_DateTime)) <= CONVERT(DATE, GETDATE()) 
	END 
	ELSE IF(@AccLatType = 'M')-- chốt 1 tháng 1 lần
	BEGIN
	INSERT INTO #tblOM_AccumulatedResult (Sel, LineRef, AccumulateID, LevelID, LevelIDRegis, 
	LevelDescr, BranchID, CustID, CustName, AccumulatedValue, Pass, Prepay, Reward, 
	CloseDate, FromDate, ToDate, CheckDate, TotalValueUse, StrOrder, MinDateOrder, RewardBack, RewardFirst, BeforeReward, UsedAmt)
	SELECT Sel = CAST(0 AS BIT),
		   LineRef = '',
		   c.AccumulateID,
		   LevelID = '',
		   LevelIDRegis = a.LevelID,
		   c.LevelDescr,
		   b.BranchID,
		   a.CustID,
		   b.CustName,
		   AccumulatedValue = CAST(0 AS FLOAT),
		   Pass = CAST(0 AS BIT),
		   Prepay = CAST(0 AS FLOAT),
		   Reward = CAST(0 AS FLOAT),
		   CloseDate = CONVERT(DATE, GETDATE()),
		   FromDate = CONVERT(DATE, -- TuanTA Commented 23/02/2021: If AccLatType = 'Q' AND EffectDateNbr = 0
				 CASE
					 WHEN @EffectDateNbr = 0 THEN -- If Regisation Of The Customer (CreatedDateTime OM_AccumulatedRegis) Is Month = 1 Then FromDate = CreatedDateTime
				 CASE
					 WHEN a.CustID NOT IN
						(
						  SELECT CustID FROM #tblAccumulated
						) THEN a.Crtd_DateTime -- Else Get First Day Of The Month For Regisation The Customer

					 ELSE DATEADD(mm, DATEDIFF(mm, 0, a.Crtd_DateTime), 0)
				 END
				ELSE d.OrderDate END),
			ToDate = GETDATE(),
			CheckDate = CASE
							WHEN @EffectDateNbr = 0
								AND CONVERT(DATE, CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, d.OrderDate))), DATEADD(mm, 1, d.OrderDate)))) >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
							WHEN @EffectDateNbr = 0
								AND CONVERT(DATE, CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, d.OrderDate))), DATEADD(mm, 1, d.OrderDate)))) < CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, d.OrderDate))), DATEADD(mm, 1, d.OrderDate))))
							WHEN @EffectDateNbr <> 0
								AND CONVERT(DATE, CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, d.OrderDate))), DATEADD(mm, 1, d.OrderDate)))) <= CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, d.OrderDate)) THEN CONVERT(DATE, CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, d.OrderDate))), DATEADD(mm, 1, d.OrderDate))))
							ELSE DATEADD(DAY, @EffectDateNbr, d.OrderDate)
						END,
			TotalValueUse = CAST(0 AS FLOAT),
			StrOrder = '',
			CONVERT(DATE, d.OrderDate)  AS MinDateOrder,
			CAST(0 AS FLOAT),
			CAST(0 AS FLOAT),
			BeforeReward = CAST(0 AS FLOAT),
			CAST(0 AS FLOAT)
	FROM OM_AccumulatedRegis a WITH(NOLOCK)
	INNER JOIN AR_Customer b WITH(NOLOCK) ON a.CustID = b.CustId --AND a.BranchID = b.BranchID
	INNER JOIN OM_AccumulatedLevel c WITH(NOLOCK) ON a.AccumulateID = c.AccumulateID AND a.LevelID = c.LevelID
	INNER JOIN OM_Accumulated ac WITH(NOLOCK) ON ac.AccumulateID = a.AccumulateID
	INNER JOIN #tblOrder d ON d.CustID = a.CustID
	INNER JOIN OM_SalesRoute T8 WITH(NOLOCK) ON T8.SalesRouteID = a.SlsPerID AND T8.RouteType = a.BugetID
	INNER JOIN #StateParam T6 ON T6.StateID = b.State
	WHERE a.AccumulateID = @AccumulateID
	  AND a.CustID NOT IN
		(SELECT CustID
		 FROM #tblAccumulated)
	  AND b.BranchID = @BranchID
	  AND ((a.CustID LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI)
		   OR (b.CustName LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI))
	  AND a.Status = 'C'
	  AND CONVERT(DATE, d.OrderDate)<= CONVERT(DATE, GETDATE())
	  AND ((@EffectDateNbr <> 0
			AND CONVERT(DATE, d.OrderDate) <= CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, d.OrderDate)))
		   OR (@EffectDateNbr = 0
			   AND CONVERT(DATE, d.OrderDate)<= CONVERT(DATE, ac.ToDate)))

	UNION ALL
	SELECT Sel = CAST(0 AS BIT),
		   LineRef = '',
		   c.AccumulateID,
		   LevelID = '',
		   LevelIDRegis = a.LevelID,
		   c.LevelDescr,
		   b.BranchID,
		   a.CustID,
		   b.CustName,
		   AccumulatedValue = CAST(0 AS FLOAT),
		   Pass = CAST(0 AS BIT),
		   Prepay = CAST(0 AS FLOAT),
		   Reward = CAST(0 AS FLOAT),
		   CloseDate = CONVERT(DATE, GETDATE()),
		   FromDate = CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, k.ToDate))-1), DATEADD(mm, 1, k.ToDate))),
		   ToDate = GETDATE(),
		   CheckDate = CASE
				WHEN @EffectDateNbr = 0
					AND CONVERT(DATE, CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, k.ToDate))), DATEADD(mm, 1, DATEADD(mm, 1, k.ToDate))))) >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
				WHEN @EffectDateNbr = 0
					AND CONVERT(DATE, CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, k.ToDate))), DATEADD(mm, 1, DATEADD(mm, 1, k.ToDate))))) < CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, k.ToDate))), DATEADD(mm, 2, k.ToDate))))
				WHEN @EffectDateNbr <> 0
					AND CONVERT(DATE, CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, k.ToDate))), DATEADD(mm, 1, DATEADD(mm, 1, k.ToDate)))))<= CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, k.ToDate)) THEN CONVERT(DATE, CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, k.ToDate))), DATEADD(mm, 1, DATEADD(mm, 1, k.ToDate)))))
				ELSE DATEADD(DAY, @EffectDateNbr, k.ToDate)
			END,
			TotalValueUse = ISNULL(old.Total, CAST(0 AS FLOAT)),
			StrOrder = '',
			CONVERT(DATE, d.OrderDate)  AS MinDateOrder,
			CAST(0 AS FLOAT),
			CAST(0 AS FLOAT),
			BeforeReward = CAST(0 AS FLOAT),
			CAST(0 AS FLOAT)
	FROM OM_AccumulatedRegis a WITH(NOLOCK)
	INNER JOIN AR_Customer b WITH(NOLOCK) ON a.CustID = b.CustId --AND a.BranchID = b.BranchID
	INNER JOIN OM_AccumulatedLevel c WITH(NOLOCK) ON a.AccumulateID = c.AccumulateID AND a.LevelID = c.LevelID
	INNER JOIN OM_Accumulated ac WITH(NOLOCK) ON ac.AccumulateID = a.AccumulateID
	INNER JOIN #tblOrder d ON d.CustID = a.CustID
	INNER JOIN OM_SalesRoute T8 WITH(NOLOCK) ON T8.SalesRouteID = a.SlsPerID AND T8.RouteType = a.BugetID
	INNER JOIN #tblAccumulated k ON a.CustID = k.CustID
	INNER JOIN #StateParam T6 ON T6.StateID = b.State
	LEFT JOIN #tblAccumulatedResultTotal old ON old.CustID = a.CustID AND old.BranchID = @BranchID
	WHERE a.AccumulateID = @AccumulateID
	  AND b.BranchID = @BranchID
	  AND ((a.CustID LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI)
		   OR (b.CustName LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI))
	  AND a.Status = 'C'
	  AND CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, k.ToDate))-1), DATEADD(mm, 1, k.ToDate))) <= CONVERT(DATE, GETDATE())
	  AND ((@EffectDateNbr <> 0
	  AND CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, k.ToDate))-1), DATEADD(mm, 1, k.ToDate))) <= CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, d.OrderDate)))
		OR (@EffectDateNbr = 0
	  AND CONVERT(DATE, DATEADD(dd, -(DAY(DATEADD(mm, 1, k.ToDate))-1), DATEADD(mm, 1, k.ToDate)))<= CONVERT(DATE, ac.ToDate))) 
	END 
	ELSE IF(@AccLatType = 'Q')-- chốt 1 Quý 1 lần
	BEGIN
	INSERT INTO #tblOM_AccumulatedResult (Sel, LineRef, AccumulateID, LevelID, LevelIDRegis, 
	LevelDescr, BranchID, CustID, CustName, AccumulatedValue, Pass, Prepay, Reward, CloseDate, 
	FromDate, ToDate, CheckDate, TotalValueUse, StrOrder, MinDateOrder, RewardBack, RewardFirst, BeforeReward, UsedAmt)
	SELECT 
	Sel = CAST(0 AS BIT),
	LineRef = '',
	c.AccumulateID,
	LevelID = '',
	LevelIDRegis = a.LevelID,
	c.LevelDescr,
	b.BranchID,
	a.CustID,
	b.CustName,
	AccumulatedValue = CAST(0 AS FLOAT),
	Pass = CAST(0 AS BIT),
	Prepay = CAST(0 AS FLOAT),
	Reward = CAST(0 AS FLOAT),
	CloseDate = CONVERT(DATE, GETDATE()),
	FromDate = CONVERT(DATE, 
			 -- TuanTA Commented 23/02/2021: If AccLatType = 'Q' AND EffectDateNbr = 0
			 CASE
				 WHEN @EffectDateNbr = 0 THEN 
				 -- If The Customer Has Been First Approve Is First Quarter Then FromDate = CreatedDateTime (CreatedDateTime OM_AccumulatedRegis)
				 CASE
					 WHEN a.CustID NOT IN
						(
						  SELECT CustID FROM #tblAccumulated
						) THEN a.Crtd_DateTime 
					 -- Else Get First Day Of The Quarter For Regisation The Customer
					 ELSE DATEADD(qq, DATEDIFF(qq, 0, a.Crtd_DateTime), 0)
				 END
				 ELSE d.OrderDate
			 END),
	ToDate = GETDATE(),
	CheckDate = CASE
			WHEN DATEADD(QUARTER, DATEDIFF(QUARTER, 0, d.OrderDate) + DATEPART(QUARTER, d.OrderDate), -1) >= CONVERT(DATE, GETDATE()) 
			THEN (CASE
				WHEN @EffectDateNbr = 0
					AND ac.ToDate >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
				WHEN @EffectDateNbr = 0
					AND ac.ToDate < CONVERT(DATE, GETDATE()) THEN ac.ToDate
				WHEN @EffectDateNbr <> 0
					AND CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, d.OrderDate)) >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
				ELSE CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, d.OrderDate))
			END)
			ELSE (CASE
				WHEN @EffectDateNbr = 0
					AND ac.ToDate >= DATEADD(QUARTER, DATEDIFF(QUARTER, 0, d.OrderDate) + DATEPART(QUARTER, d.OrderDate), -1) THEN DATEADD(QUARTER, DATEDIFF(QUARTER, 0, d.OrderDate) + DATEPART(QUARTER, d.OrderDate), -1)
				WHEN @EffectDateNbr = 0
					AND ac.ToDate < DATEADD(QUARTER, DATEDIFF(QUARTER, 0, d.OrderDate) + DATEPART(QUARTER, d.OrderDate), -1) THEN ac.ToDate
				WHEN @EffectDateNbr <> 0
					AND CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, d.OrderDate)) >= DATEADD(QUARTER, DATEDIFF(QUARTER, 0, d.OrderDate) + DATEPART(QUARTER, d.OrderDate), -1) THEN DATEADD(QUARTER, DATEDIFF(QUARTER, 0, d.OrderDate) + DATEPART(QUARTER, d.OrderDate), -1)
				ELSE CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, d.OrderDate))
			END)
		END,
	TotalValueUse = CAST(0 AS FLOAT),
	StrOrder = '',
	CONVERT(DATE, d.OrderDate)  AS MinDateOrder,
	CAST(0 AS FLOAT),
	CAST(0 AS FLOAT),
	BeforeReward = CAST(0 AS FLOAT),
	CAST(0 AS FLOAT)
	FROM OM_AccumulatedRegis a WITH(NOLOCK)
	INNER JOIN AR_Customer b WITH(NOLOCK) ON a.CustID = b.CustId --AND a.BranchID = b.BranchID
	INNER JOIN OM_AccumulatedLevel c WITH(NOLOCK) ON a.AccumulateID = c.AccumulateID AND a.LevelID = c.LevelID
	INNER JOIN OM_Accumulated ac WITH(NOLOCK) ON ac.AccumulateID = a.AccumulateID
	INNER JOIN #tblOrder d ON d.CustID = a.CustID
	INNER JOIN OM_SalesRoute T8 WITH(NOLOCK) ON T8.SalesRouteID = a.SlsPerID AND T8.RouteType = a.BugetID
	INNER JOIN #StateParam T6 ON T6.StateID = b.State
	WHERE a.AccumulateID = @AccumulateID
	  AND b.BranchID = @BranchID
	  AND ((a.CustID LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI)
		   OR (b.CustName LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI))
	  AND a.Status = 'C'
	  AND a.CustID NOT IN
		(SELECT CustID
		 FROM #tblAccumulated)
	  AND ISNULL(CONVERT(DATE, d.OrderDate), CONVERT(DATE, a.Crtd_DateTime))<= CONVERT(DATE, GETDATE())
	  AND ((@EffectDateNbr = 0
			AND CONVERT(DATE, ac.Todate)>= ISNULL(CONVERT(DATE, d.OrderDate), CONVERT(DATE, a.Crtd_DateTime))) OR(@EffectDateNbr <> 0
			AND DATEADD(DAY, @EffectDateNbr, d.OrderDate)>= ISNULL(CONVERT(DATE, d.OrderDate), CONVERT(DATE, a.Crtd_DateTime))))
	UNION ALL
	SELECT Sel = CAST(0 AS BIT),
		   LineRef = '',
		   c.AccumulateID,
		   LevelID = '',
		   LevelIDRegis = a.LevelID,
		   c.LevelDescr,
		   b.BranchID,
		   a.CustID,
		   b.CustName,
		   AccumulatedValue = CAST(0 AS FLOAT),
		   Pass = CAST(0 AS BIT),
		   Prepay = CAST(0 AS FLOAT),
		   Reward = CAST(0 AS FLOAT),
		   CloseDate = CONVERT(DATE, GETDATE()),
		   FromDate = DATEADD(qq, DATEDIFF(qq, 0, tbl.ToDate) + 1, 0),
		   ToDate = GETDATE(),
		   CheckDate = CASE
						WHEN DATEADD(QUARTER, DATEDIFF(QUARTER, 0, tbl.ToDate) + DATEPART(QUARTER, tbl.ToDate)+ 1, -1) >= CONVERT(DATE, GETDATE()) THEN (CASE
								WHEN @EffectDateNbr = 0
										AND CONVERT(DATE, ac.ToDate)>= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
								WHEN @EffectDateNbr = 0
										AND CONVERT(DATE, ac.ToDate)< CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, ac.ToDate)
								WHEN @EffectDateNbr <> 0
										AND DATEADD(DAY, @EffectDateNbr, d.OrderDate) >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
								ELSE DATEADD(DAY, @EffectDateNbr, d.OrderDate)
							END)
						ELSE (CASE
									WHEN @EffectDateNbr = 0
										AND CONVERT(DATE, ac.ToDate) >= DATEADD(QUARTER, DATEDIFF(QUARTER, 0, tbl.ToDate) + DATEPART(QUARTER, tbl.ToDate)+ 1, -1) THEN DATEADD(QUARTER, DATEDIFF(QUARTER, 0, tbl.ToDate) + DATEPART(QUARTER, tbl.ToDate)+ 1, -1)
									WHEN @EffectDateNbr = 0
										AND CONVERT(DATE, ac.ToDate)< DATEADD(QUARTER, DATEDIFF(QUARTER, 0, tbl.ToDate) + DATEPART(QUARTER, tbl.ToDate)+ 1, -1) THEN CONVERT(DATE, ac.ToDate)
									WHEN @EffectDateNbr <> 0
										AND DATEADD(DAY, @EffectDateNbr, d.OrderDate) >= DATEADD(QUARTER, DATEDIFF(QUARTER, 0, tbl.ToDate) + DATEPART(QUARTER, tbl.ToDate)+ 1, -1) THEN DATEADD(QUARTER, DATEDIFF(QUARTER, 0, tbl.ToDate) + DATEPART(QUARTER, tbl.ToDate)+ 1, -1)
									ELSE DATEADD(DAY, @EffectDateNbr, d.OrderDate)
								END)
					END,
			TotalValueUse = ISNULL(old.Total, CAST(0 AS FLOAT)),
			StrOrder = '',
			CONVERT(DATE, d.OrderDate)  AS MinDateOrder,
			CAST(0 AS FLOAT),
			CAST(0 AS FLOAT),
			BeforeReward = CAST(0 AS FLOAT),
			CAST(0 AS FLOAT)
	FROM OM_AccumulatedRegis a WITH(NOLOCK)
	INNER JOIN AR_Customer b WITH(NOLOCK) ON a.CustID = b.CustId --AND a.BranchID = b.BranchID
	INNER JOIN OM_AccumulatedLevel c WITH(NOLOCK) ON a.AccumulateID = c.AccumulateID AND a.LevelID = c.LevelID
	INNER JOIN OM_Accumulated ac WITH(NOLOCK) ON ac.AccumulateID = a.AccumulateID
	INNER JOIN #tblOrder d ON d.CustID = a.CustID
	INNER JOIN OM_SalesRoute T8 WITH(NOLOCK) ON T8.SalesRouteID = a.SlsPerID AND T8.RouteType = a.BugetID
	INNER JOIN #tblAccumulated tbl ON a.CustID = tbl.CustID
	INNER JOIN #StateParam T6 ON T6.StateID = b.State
	LEFT JOIN #tblAccumulatedResultTotal old ON old.CustID = a.CustID AND old.BranchID = @BranchID
	WHERE 
	a.AccumulateID = @AccumulateID
	  AND DATEADD(qq, DATEDIFF(qq, 0, tbl.ToDate) + 1, 0)<= CONVERT(DATE, GETDATE())
	  AND b.BranchID = @BranchID
	  AND ((a.CustID LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI)
		   OR (b.CustName LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI))
	  AND a.Status = 'C'
	  AND ((@EffectDateNbr = 0
			AND CONVERT(DATE, ac.ToDate) >= DATEADD(DAY, 1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, tbl.ToDate) + DATEPART(QUARTER, tbl.ToDate), -1))) 
	  OR (@EffectDateNbr <> 0
				AND DATEADD(DAY, @EffectDateNbr, d.OrderDate) >= DATEADD(qq, DATEDIFF(qq, 0, tbl.ToDate) + 1, 0)))
	END 
	ELSE IF(@AccLatType = 'C')-- chốt 1 Năm 1 lần
    BEGIN
	INSERT INTO #tblOM_AccumulatedResult (Sel, LineRef, AccumulateID, LevelID, LevelIDRegis, 
	LevelDescr, BranchID, CustID, CustName, AccumulatedValue, Pass, Prepay, Reward, 
	CloseDate, FromDate, ToDate, CheckDate, TotalValueUse, StrOrder, MinDateOrder, RewardBack, RewardFirst, BeforeReward, UsedAmt)
	SELECT Sel = CAST(0 AS BIT),
		   LineRef = '',
		   c.AccumulateID,
		   LevelID = '',
		   LevelIDRegis = a.LevelID,
		   c.LevelDescr,
		   b.BranchID,
		   a.CustID,
		   b.CustName,
		   AccumulatedValue = CAST(0 AS FLOAT),
		   Pass = CAST(0 AS BIT),
		   Prepay = CAST(0 AS FLOAT),
		   Reward = CAST(0 AS FLOAT),
		   CloseDate = CONVERT(DATE, GETDATE()),
		   FromDate = CONVERT(DATE, -- TuanTA Commented 23/02/2021: If AccLatType = 'O' AND EffectDateNbr = 0 THEN GET CreateDateTime Of Accumulated
	 -- Else Get OrderDate First Order
	 CASE
		 WHEN @EffectDateNbr = 0 THEN a.Crtd_DateTime
		 ELSE d.OrderDate
	 END),
	ToDate = GETDATE(),
	CheckDate = CASE
			WHEN EOMONTH (CONVERT(DATE, '12/15/' + CONVERT(VARCHAR, YEAR(d.OrderDate)))) >= CONVERT(DATE, GETDATE()) 
			THEN (CASE
				WHEN @EffectDateNbr = 0
					AND ac.ToDate >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
				WHEN @EffectDateNbr = 0
					AND ac.ToDate < CONVERT(DATE, GETDATE()) THEN ac.ToDate
				WHEN @EffectDateNbr <> 0
					AND CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, d.OrderDate)) >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
				ELSE CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, d.OrderDate))
				END 
			)--CONVERT(DATE,GETDATE())
		  ELSE(CASE
			  WHEN @EffectDateNbr = 0
				   AND ac.ToDate >= EOMONTH (CONVERT(DATE, '12/15/' + CONVERT(VARCHAR, YEAR(d.OrderDate)))) THEN EOMONTH (CONVERT(DATE, '12/15/' + CONVERT(VARCHAR, YEAR(d.OrderDate))))
			  WHEN @EffectDateNbr = 0
				   AND ac.ToDate < EOMONTH (CONVERT(DATE, '12/15/' + CONVERT(VARCHAR, YEAR(d.OrderDate)))) THEN ac.ToDate
			  WHEN @EffectDateNbr <> 0
				   AND DATEADD(DAY, @EffectDateNbr, d.OrderDate)>= EOMONTH (CONVERT(DATE, '12/15/' + CONVERT(VARCHAR, YEAR(d.OrderDate)))) THEN EOMONTH (CONVERT(DATE, '12/15/' + CONVERT(VARCHAR, YEAR(d.OrderDate))))
			  ELSE DATEADD(DAY, @EffectDateNbr, d.OrderDate)
		  END) --EOMONTH (CONVERT(DATE,'12/15/'+CONVERT(VARCHAR,YEAR(d.OrderDate))))
		END,
	TotalValueUse = CAST(0 AS FLOAT),
	StrOrder = '',
	CONVERT(DATE, d.OrderDate)  AS MinDateOrder,
	CAST(0 AS FLOAT),
	CAST(0 AS FLOAT),
	BeforeReward = CAST(0 AS FLOAT),
	CAST(0 AS FLOAT)
	FROM OM_AccumulatedRegis a WITH(NOLOCK)
	INNER JOIN AR_Customer b WITH(NOLOCK) ON a.CustID = b.CustId --AND a.BranchID = b.BranchID
	INNER JOIN OM_AccumulatedLevel c WITH(NOLOCK) ON a.AccumulateID = c.AccumulateID AND a.LevelID = c.LevelID
	INNER JOIN OM_Accumulated ac WITH(NOLOCK) ON ac.AccumulateID = a.AccumulateID
	INNER JOIN #tblOrder d ON d.CustID = a.CustID
	INNER JOIN OM_SalesRoute T8 WITH(NOLOCK) ON T8.SalesRouteID = a.SlsPerID AND T8.RouteType = a.BugetID
	INNER JOIN #StateParam T6 ON T6.StateID = b.State
	WHERE a.AccumulateID = @AccumulateID
	  AND a.CustID NOT IN
		(SELECT CustID
		 FROM #tblAccumulated)
	  AND b.BranchID = @BranchID
	  AND ((a.CustID LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI)
		   OR (b.CustName LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI))
	  AND a.Status = 'C'
	  AND CONVERT(DATE, d.OrderDate)<= CONVERT(DATE, GETDATE())
	  AND ((@EffectDateNbr <> 0
			AND CONVERT(DATE, d.OrderDate) <= CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, d.OrderDate)))
		   OR (@EffectDateNbr = 0
			   AND CONVERT(DATE, d.OrderDate)<= CONVERT(DATE, ac.ToDate)))
	UNION ALL
	SELECT Sel = CAST(0 AS BIT),
		   LineRef = '',
		   c.AccumulateID,
		   LevelID = '',
		   LevelIDRegis = a.LevelID,
		   c.LevelDescr,
		   b.BranchID,
		   a.CustID,
		   b.CustName,
		   AccumulatedValue = CAST(0 AS FLOAT),
		   Pass = CAST(0 AS BIT),
		   Prepay = CAST(0 AS FLOAT),
		   Reward = CAST(0 AS FLOAT),
		   CloseDate = CONVERT(DATE, GETDATE()),
		   FromDate = CONVERT(DATE, '01/01/' + CONVERT(VARCHAR, YEAR(k.ToDate)+ 1)),
		   ToDate = GETDATE(),
		   CheckDate = CASE
						   WHEN EOMONTH (CONVERT(DATE, '12/15/' + CONVERT(VARCHAR, YEAR(k.ToDate)+ 1))) >= CONVERT(DATE, GETDATE()) 
						   THEN (CASE
						WHEN @EffectDateNbr = 0
							AND ac.ToDate >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
						WHEN @EffectDateNbr = 0
							AND ac.ToDate < CONVERT(DATE, GETDATE()) THEN ac.ToDate
						WHEN @EffectDateNbr <> 0
							AND CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, d.OrderDate)) >= CONVERT(DATE, GETDATE()) THEN CONVERT(DATE, GETDATE())
						ELSE CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, d.OrderDate))
					END) ELSE(CASE
								WHEN @EffectDateNbr = 0
										AND ac.ToDate >= EOMONTH (CONVERT(DATE, '12/15/' + CONVERT(VARCHAR, YEAR(k.ToDate)+ 1))) THEN EOMONTH (CONVERT(DATE, '12/15/' + CONVERT(VARCHAR, YEAR(k.ToDate)+ 1)))
								WHEN @EffectDateNbr = 0
										AND ac.ToDate < EOMONTH (CONVERT(DATE, '12/15/' + CONVERT(VARCHAR, YEAR(k.ToDate)+ 1))) THEN ac.ToDate
								WHEN @EffectDateNbr <> 0
										AND DATEADD(DAY, @EffectDateNbr, d.OrderDate)>= EOMONTH (CONVERT(DATE, '12/15/' + CONVERT(VARCHAR, YEAR(k.ToDate)+ 1))) THEN EOMONTH (CONVERT(DATE, '12/15/' + CONVERT(VARCHAR, YEAR(k.ToDate)+ 1)))
								ELSE DATEADD(DAY, @EffectDateNbr, d.OrderDate)
							END)
					   END,
			TotalValueUse = ISNULL(old.Total, CAST(0 AS FLOAT)),
			StrOrder = '',
			CONVERT(DATE, d.OrderDate)  AS MinDateOrder,
			CAST(0 AS FLOAT),
			CAST(0 AS FLOAT),
			BeforeReward = CAST(0 AS FLOAT),
			CAST(0 AS FLOAT)
	FROM OM_AccumulatedRegis a WITH(NOLOCK)
	INNER JOIN AR_Customer b WITH(NOLOCK) ON a.CustID = b.CustId --AND a.BranchID = b.BranchID
	INNER JOIN OM_AccumulatedLevel c WITH(NOLOCK) ON a.AccumulateID = c.AccumulateID AND a.LevelID = c.LevelID
	INNER JOIN OM_Accumulated ac WITH(NOLOCK) ON ac.AccumulateID = a.AccumulateID
	INNER JOIN #tblOrder d ON d.CustID = a.CustID
	INNER JOIN OM_SalesRoute T8 WITH(NOLOCK) ON T8.SalesRouteID = a.SlsPerID AND T8.RouteType = a.BugetID
	INNER JOIN #tblAccumulated k ON a.CustID = k.CustID
	INNER JOIN #StateParam T6 ON T6.StateID = b.State
	LEFT JOIN #tblAccumulatedResultTotal old ON old.CustID = a.CustID AND old.BranchID = @BranchID
	WHERE a.AccumulateID = @AccumulateID
	  AND b.BranchID = @BranchID
	  AND ((a.CustID LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI)
		   OR (b.CustName LIKE '%' + @Cust + '%' COLLATE Japanese_Unicode_CI_AI))
	  AND a.Status = 'C'
	  AND CONVERT(DATE, '01/01/' + CONVERT(VARCHAR, YEAR(k.ToDate)+ 1)) <= CONVERT(DATE, GETDATE())
	  AND ((@EffectDateNbr <> 0

	  AND CONVERT(DATE, '01/01/' + CONVERT(VARCHAR, YEAR(k.ToDate)+ 1)) <= CONVERT(DATE, DATEADD(DAY, @EffectDateNbr, d.OrderDate)))

		OR (@EffectDateNbr = 0
	  AND CONVERT(DATE, '01/01/' + CONVERT(VARCHAR, YEAR(k.ToDate)+ 1))<= CONVERT(DATE, ac.ToDate))) 

	END
	DROP TABLE #tblAccumulated 
	END
	DROP TABLE #tblOrder
	DROP TABLE #tblAccumulatedResultTotal

	-- TuanTA Commented 24/02/2021: Get All Record By Table #tblOM_AccumulatedResult Result
	SELECT DISTINCT
		Sel, 
		T1.LineRef, 
		T1.AccumulateID, 
		LevelID, 
		LevelIDRegis,
		LevelDescr, 
		T1.BranchID, 
		T1.CustID, 
		CustName, 
		AccumulatedValue, 
		Pass = CASE WHEN @Status = 'H' AND T3.AccumulateID IS NOT NULL
		THEN T3.IsEditPass
		ELSE T1.Pass END, 
		Prepay, 
		Reward, 
		CloseDate, 
		T1.FromDate,
		ToDate = 
		CASE WHEN @Status = 'H' AND T3.AccumulateID IS NOT NULL
		THEN T3.ToDate
		ELSE
		IIF(@Status = 'H',
		            -- Hình thức chốt TL nhiều lần thì lấy ngày hiện tại.      
					CASE 
					  WHEN @AccLatType = 'S' THEN  
						IIF(@EffectDateNbr = 0,
						(SELECT MIN(v) 
						FROM (VALUES 
								 (GETDATE()),
								 (T2.ToDate)
							 ) AS VALUE(v)),
						(SELECT MIN(v) 
						FROM (VALUES 
								 (GETDATE()), 
								  (T2.ToDate),
								 (DATEADD(DAY,@EffectDateNbr,T1.MinDateOrder))
							 ) AS VALUE(v)) )					  
					  -- Hình thức chốt TL là 1 lần thì lấy ngày min(Ngày Hiện Tại, kết thúc CTTL)
					  WHEN @AccLatType = 'O' THEN 
						IIF(@EffectDateNbr = 0,
						(SELECT MIN(v) 
						FROM (VALUES 
								 (GETDATE()), 
								 (T2.ToDate)
							 ) AS VALUE(v)),
						(SELECT MIN(v) 
						FROM (VALUES 
								 (GETDATE()), 
								 (DATEADD(DAY,@EffectDateNbr,T1.MinDateOrder)),
								 (T2.ToDate)
							 ) AS VALUE(v)) )	
					  -- Hình thức chốt TL theo tháng thì lấy min(Ngày Hiện Tại, FromDate =+ @EffectDateNbr, ngày cuối tháng)
					  WHEN @AccLatType = 'M' THEN 
						IIF(@EffectDateNbr = 0,
						(SELECT MIN(v) 
						FROM (VALUES 
								 (EOMONTH(T1.FromDate)),
								 (T2.ToDate)
							 ) AS VALUE(v)),
						(SELECT MIN(v) 
						FROM (VALUES 
								 (DATEADD(DAY,@EffectDateNbr,T1.MinDateOrder)),
								 (EOMONTH(T1.FromDate))
							 ) AS VALUE(v)) )
					  -- Hình thức chốt TL theo quý thì lấy min(Ngày Hiện Tại, FromDate =+ @EffectDateNbr, ngày cuối quý)
					  WHEN @AccLatType = 'Q' THEN
						IIF(@EffectDateNbr = 0,
						(SELECT MIN(v) 
						FROM (VALUES 
								 (DATEADD(dd, -1, DATEADD(qq, DATEDIFF(qq, 0, T1.FromDate) + 1, 0))),
								 (T2.ToDate)
							 ) AS VALUE(v)),
						(SELECT MIN(v) 
						FROM (VALUES 
								 (DATEADD(DAY,@EffectDateNbr,T1.MinDateOrder)),
								 (DATEADD(dd, -1, DATEADD(qq, DATEDIFF(qq, 0, T1.FromDate) + 1, 0)))
							 ) AS VALUE(v)))
					  -- Hình thức chốt TL theo năm thì lấy min(Ngày Hiện Tại, FromDate =+ @EffectDateNbr, ngày cuối năm)
					  WHEN @AccLatType = 'C' THEN
						IIF(@EffectDateNbr = 0,
						(SELECT MIN(v) 
						FROM (VALUES 
								 (DATEADD(yy, DATEDIFF(yy, 0, T1.FromDate) + 1, -1)),
								 (T2.ToDate)
							 ) AS VALUE(v)),
						(SELECT MIN(v) 
						FROM (VALUES 
								 (DATEADD(DAY,@EffectDateNbr,T1.MinDateOrder)),
								 (DATEADD(yy, DATEDIFF(yy, 0, T1.FromDate) + 1, -1))
							 ) AS VALUE(v)))
					   ELSE 
					   CONVERT(DATE,GETDATE()) END, T1.ToDate) END,
		TotalValueUse, 
		StrOrder,
		IsEditPass = CAST(IIF(T1.Pass = 1, 0, 1) AS BIT),
		RewardBack ,
		RewardFirst,
		BeforeReward,
		--UsedAmt=CAST(UsedAmt AS FLOAT),
		T1.UsedAmt,
		AmtAvail = 
		
		IIF( ISNULL(RewardFirst, 0) + ISNULL(RewardBack,0) - ISNULL(T1.UsedAmt,0) < 0, 0, ISNULL(RewardFirst, 0) + ISNULL(RewardBack,0) - ISNULL(T1.UsedAmt,0))
	FROM #tblOM_AccumulatedResult AS T1
	INNER JOIN OM_Accumulated T2 WITH(NOLOCK) ON T1.AccumulateID = T2.AccumulateID
	LEFT JOIN OM_AccumulatedSequence T3 WITH(NOLOCK) ON T1.AccumulateID = T3.AccumulateID AND T1.BranchID = T3.BranchID AND T1.CustID = T3.CustID

	DROP TABLE #tblOM_AccumulatedResult
	DROP TABLE #StateParam

GO