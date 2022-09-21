USE [PhaNam_eSales_PRO]
GO

/****** Object:  StoredProcedure [dbo].[pr_OM_RawdataPDAOrderALL_BI]    Script Date: 21/04/2022 4:12:22 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[pr_OM_RawdataPDAOrderALL_BI]   -- pr_OM_RawdataPDAOrderALL_Test  9142
@Fromdate DATE, @Todate DATE
AS

----DECLARE @RPTID INT = 699

    

	SELECT BranchID , SlsperID
	INTO #SalesForce 
	FROM  dbo.fr_ListSaleByData('Admin')
	--SELECT * FROM #SalesForce
	--PhucPM them 
	--select * 
	--into #DataByGeography 
	--from fr_ListDataByGeography (@UserID) 
--SELECT @Zone, @Terr

---khoahnt them

SELECT * 
INTO #Customer
FROM dbo.vs_AR_CustomerInfo cu WITH(NOLOCK)


SELECT			DENSE_RANK() OVER (ORDER BY T1.DocDate, T2.OrigOrderNbr) AS OrderNo,
				---- HAILH Modified On 22/07/2020: Bổ Sung Thông Tin BatNbr, RefNbr để truyền giá trị xuống PDA
				T1.BranchID,T1.BatNbr, T1.RefNbr, T1.CustID,
				T2.OrigOrderNbr AS OrderNbr,
				T1.InvcNbr,T1.InvcNote,
				T1.DocDate AS InvoiceDate,
				T1.OrigDocAmt AS InvoiceAmount, 
				---- HAILH Modified On 16/07/2020: Bổ sung xét thời hạn thanh toán theo Hợp Đồng nếu có
				COALESCE (T5.DueType, T3.DueType, '') AS DueType,
				COALESCE (T5.DueIntrv, T3.DueIntrv, '') AS DueIntrv,
				T1.DueDate,
				T3.Descr AS PaymentTerm,
				T1.OrigDocAmt - T1.DocBal AS PaidAmount,
				T1.DocBal AS RemainAmount,
				--'' AS DebtStatus,
				--'' AS Color ,
				OverPaymentTerm = IIF (T1.DueDate >= GETDATE(), 0, DATEDIFF(DAY, T1.DueDate, GETDATE()))
	INTO #Doc
	FROM		AR_Doc T1 WITH(NOLOCK)
	--INNER JOIN dbo.RPTRunningParm0 r WITH(NOLOCK) ON r.StringParm = t1.BranchID AND r.ReportID = @RPTID
	INNER JOIN	OM_SalesOrd T2 WITH(NOLOCK)
		ON		T1.BranchID = T2.BranchID
				AND T1.RefNbr = T2.ARRefNbr
				AND T1.BatNbr = T2.ARBatNbr
	INNER JOIN	SI_Terms T3 WITH(NOLOCK)
		ON		T2.Terms = T3.TermsID
	---- HAILH Modified On 16/07/2020: Bổ sung xét thời hạn thanh toán theo Hợp Đồng nếu có
	LEFT JOIN	OM_OriginalContract T4 WITH(NOLOCK)
		ON		T2.ContractID = T4.ContractID
	LEFT JOIN	SI_Terms T5 WITH(NOLOCK)
		ON		T4.Terms = T5.TermsID
WHERE CAST(t2.OrderDate AS DATE) BETWEEN @fromdate AND @todate


SELECT a.BranchID,a.OrderNo , a.CustId , a.BatNbr , RefNbr , DebtStatus = t3.DebtStatusDescr , Color = T3.DebtStatusColor
INTO #DebtStatus
FROM #Doc a
LEFT JOIN	SI_DebtStatusSetup T2 WITH(NOLOCK)
	ON		a.DueType = T2.DueType
LEFT JOIN	SI_DebtStatus T3 WITH(NOLOCK)
	ON		T2.DebtStatusCode = T3.DebtStatusCode
WHERE		a.OverPaymentTerm BETWEEN T2.DOverFrom AND T2.DOverTo
		AND a.OverPaymentTerm BETWEEN (ROUND(T2.TOverDaysFrom * a.DueIntrv, 0) + T2.AddDaysFrom) AND ROUND(T2.TOverDaysTo * a.DueIntrv,0)
AND  PaidAmount <> 0

SELECT BranchID , OrderNbr  ,SlsPerID , OrderDate ,  invtid,  Lotsernbr , ExpDate ,
		Status , CustID , VATAmount , BeforeVATAmount , AfterVATAmount ,
		Crtd_User , Crtd_DateTime , ContractID , DeliveryID , ShipDate , OrdAmt, OrdQty, InvcNbr , InvcNote ,
		PNOrderNbr  ,  ChietKhau , a.OrderType, ContractNbr , a.Note
INTO #Ord
from
(

SELECT  
a.BranchID , a.OrderNbr  ,so.SlsPerID , a.OrderDate , 
		Status =	CASE		
					WHEN  ISNULL(so.status,'') = ''
					THEN (
							CASE	WHEN a.Status = 'C' THEN N'Đã Duyệt Đơn Hàng'
									WHEN a.Status = 'H' THEN N'Chờ Xử Lý'
									WHEN a.Status = 'E' THEN N'Đóng Đơn Hàng'
									WHEN a.Status = 'D' THEN N'Đơn Hàng Tạm' 
									WHEN a.Status = 'V' THEN N'Hủy Đơn Hàng' END )
					ELSE (
							CASE	WHEN so.Status = 'C' THEN N'Đã Phát Hành'
									WHEN so.Status = 'I' THEN N'Tạo Hóa Đơn'
									WHEN so.Status = 'N' THEN N'Tạo Hóa Đơn'
									WHEN so.Status = 'H' THEN N'Chờ Xử Lý'
									WHEN so.Status = 'D' THEN N'Đơn Hàng Tạm' 
									WHEN so.Status = 'E' THEN N'Đóng Đơn Hàng' 
									WHEN so.Status = 'V' THEN N'Hủy Hóa Đơn' END )				
					END , 
		a.CustID ,
		so.invtid,  Lotsernbr= so.Lotsernbr, ExpDate=so.ExpDate,
		VATAmount = Sum(  so.VATAmount), 
		BeforeVATAmount = Sum( so.BeforeVATAmount), 
		AfterVATAmount = SUM(so.AfterVATAmount), 
		a.Crtd_User , a.Crtd_DateTime , a.ContractID , a.DeliveryID , a.ShipDate , a.OrdAmt, OrdQty=so.Qty, InvcNbr = ISNULL(so.InvcNbr,''), InvcNote= ISNULL(so.InvcNote,''),
		PNOrderNbr = ISNULL(p.PNOrderNbr,'') , 
                       ChietKhau= Sum(so.ChietKhau),
					   a.OrderType, ContractNbr=ISNULL(ctr.ContractNbr,''),
		Note = a.Remark
FROM  dbo.OM_PDASalesOrd a WITH(NOLOCK)
--INNER JOIN dbo.RPTRunningParm0 r WITH(NOLOCK) ON r.StringParm = a.BranchID AND r.ReportID = @RPTID
--INNER JOIN(Select * from dbo.OM_PDASalesOrdDet   WITH(NOLOCK))b ON b.BranchID = a.BranchID AND b.OrderNbr = a.OrderNbr
LEFT JOIN dbo.API_PostHistory p WITH(NOLOCK) ON a.BranchID = p.DmsBranchID and a.OrderNbr=p.DmsOrderNbr
INNER JOIN (Select distinct o.BranchID, o.OrigOrderNbr, status= min(status) ,o.InvcNbr,o.InvcNote,b.SlsPerID,b.Invtid, Qty= isnull(l.Qty,b.LineQty) ,Lotsernbr=isnull(l.Lotsernbr,''), ExpDate=CAST(isnull(l.ExpDate,'') as varchar (20)) , ChietKhau=( o.OrdDiscAmt+ o.VolDiscAmt),
		BeforeVATAmount = SUM(CASE WHEN b.FreeItem = 1 THEN 0  ELSE (CASE WHEN oo.ARDocType in( 'IN','DM','CS') THEN 1  WHEN oo.ARDocType in( 'NA') THEN 0
                     ELSE -1 END ) *b.BeforeVATAmount END ), 
					 AfterVATAmount = SUM(CASE WHEN b.FreeItem = 1 THEN 0  ELSE (CASE WHEN oo.ARDocType in( 'IN','DM','CS') THEN 1  WHEN oo.ARDocType in( 'NA') THEN 0
                     ELSE -1 END ) *b.AfterVATAmount END ), 
					 VATAmount = SUM(CASE WHEN b.FreeItem = 1 THEN 0  ELSE (CASE WHEN oo.ARDocType in( 'IN','DM','CS') THEN 1  WHEN oo.ARDocType in( 'NA') THEN 0
                     ELSE -1 END ) *b.VATAmount END) 
			from dbo.OM_SalesOrd o  WITH(NOLOCK)  
			inner join OM_SalesOrddet b  WITH(NOLOCK) on  o.BranchID = b.BranchID AND o.OrderNbr = b.OrderNbr
			left join OM_lottrans l  WITH(NOLOCK) on  l.BranchID = b.BranchID AND l.OrderNbr = b.OrderNbr and l.omlineref=b.lineref
			INNER JOIN dbo.OM_OrderType oo WITH(NOLOCK) ON oo.OrderType = o.OrderType
			group by o.BranchID,o.OrigOrderNbr,o.InvcNbr,o.InvcNote, o.OrdDiscAmt,b.SlsPerID, o.VolDiscAmt,b.Invtid ,isnull(l.Lotsernbr,''),isnull(l.Qty,b.LineQty), isnull(l.ExpDate,'')) so ON so.BranchID = a.BranchID AND so.OrigOrderNbr = a.OrderNbr
Left join OM_OriginalContract ctr WITH (NOLOCK) ON  a.ContractID=ctr.ContractID
WHERE CAST(a.OrderDate AS DATE) BETWEEN @fromdate AND @todate
GROUP BY 
CASE WHEN ISNULL(so.status, '') = '' THEN
         ( CASE WHEN a.Status = 'C' THEN N'Đã Duyệt Đơn Hàng'
         WHEN a.Status = 'H' THEN N'Chờ Xử Lý'
         WHEN a.Status = 'E' THEN N'Đóng Đơn Hàng'
		 WHEN a.Status = 'D' THEN N'Đơn Hàng Tạm'
		 WHEN a.Status = 'V' THEN N'Hủy Đơn Hàng'
         END
         )
         ELSE ( CASE WHEN so.Status = 'C' THEN N'Đã Phát Hành'
         WHEN so.Status = 'I' THEN N'Tạo Hóa Đơn'
         WHEN so.Status = 'N' THEN N'Tạo Hóa Đơn'
         WHEN so.Status = 'H' THEN N'Chờ Xử Lý'
		 WHEN so.Status = 'D' THEN N'Đơn Hàng Tạm'
         WHEN so.Status = 'E' THEN N'Đóng Đơn Hàng'
		 WHEN so.Status = 'V' THEN N'Hủy Hóa Đơn' 
         END
         )
         END , so.Qty,
         a.BranchID , ISNULL(so.InvcNbr,'') ,ISNULL(so.InvcNote,''),so.invtid, so.ExpDate, so.Lotsernbr,
         a.OrderNbr ,
         so.SlsPerID ,
         a.OrderDate ,
         a.CustID ,
         a.Crtd_User ,
         a.Crtd_DateTime ,
 a.ContractID ,
         a.DeliveryID ,
         a.ShipDate ,
         a.OrdAmt,
		 a.OrderType,  ISNULL(ctr.ContractNbr,''),ISNULL(p.PNOrderNbr,'') ,
		 a.Remark
Union All

SELECT  
a.BranchID , a.OrderNbr  ,b.SlsPerID , a.OrderDate , 
		Status =	CASE		
					WHEN  ISNULL(so.status,'') = ''
					THEN (
							CASE	WHEN a.Status = 'C' THEN N'Đã Duyệt Đơn Hàng'
									WHEN a.Status = 'H' THEN N'Chờ Xử Lý'
									WHEN a.Status = 'E' THEN N'Đóng Đơn Hàng' 
									WHEN a.Status = 'D' THEN N'Đơn Hàng Tạm'
									WHEN a.Status = 'V' THEN N'Hủy Đơn Hàng' END )
					ELSE (
							CASE	WHEN so.Status = 'C' THEN N'Đã Phát Hành'
									WHEN so.Status = 'I' THEN N'Tạo Hóa Đơn'
									WHEN so.Status = 'N' THEN N'Tạo Hóa Đơn'
									WHEN so.Status = 'H' THEN N'Chờ Xử Lý'
									WHEN so.Status = 'D' THEN N'Đơn Hàng Tạm'
									WHEN so.Status = 'E' THEN N'Đóng Đơn Hàng' 
									WHEN so.Status = 'V' THEN N'Hủy Hóa Đơn' END )				
					END , 
		a.CustID ,b.invtid, Lotsernbr='', ExpDate='',
		VATAmount = Sum((CASE WHEN b.FreeItem = 1 THEN 0  ELSE (CASE WHEN oo.ARDocType in( 'IN','DM','CS') THEN 1  WHEN oo.ARDocType in( 'NA') THEN 0
                     ELSE -1 END ) * (b.AfterVATAmount -b.BeforeVATAmount) END )), 
		BeforeVATAmount = Sum(CASE WHEN b.FreeItem = 1 THEN 0  ELSE (CASE WHEN oo.ARDocType in( 'IN','DM','CS') THEN 1  WHEN oo.ARDocType in( 'NA') THEN 0
                            ELSE -1 END ) *ROUND(b.lineQty*(b.SlsPrice/(1+isnull(v.TaxRate,0)/100)),0) END ), 
		AfterVATAmount = SUM(CASE WHEN b.FreeItem = 1 THEN 0  ELSE (CASE WHEN oo.ARDocType in( 'IN','DM','CS') THEN 1  WHEN oo.ARDocType in( 'NA') THEN 0
                          ELSE -1 END ) * (b.LineQty*b.SlsPrice) END ), 
		a.Crtd_User , a.Crtd_DateTime , a.ContractID , a.DeliveryID , a.ShipDate , a.OrdAmt,  OrdQty=b.Lineqty, InvcNbr = ISNULL(so.InvcNbr,''), InvcNote= ISNULL(so.InvcNote,''),
		PNOrderNbr = ISNULL(p.PNOrderNbr,'') , 
                       ChietKhau= Sum(b.DocDiscAmt + b.DiscAmt + b.GroupDiscAmt1 + b.GroupDiscAmt2),
					   a.OrderType, ContractNbr=ISNULL(ctr.ContractNbr,''),
		Note=a.Remark
FROM  dbo.OM_PDASalesOrd a WITH(NOLOCK)
--INNER JOIN dbo.RPTRunningParm0 r WITH(NOLOCK) ON r.StringParm = a.BranchID AND r.ReportID = @RPTID
INNER JOIN dbo.OM_PDASalesOrdDet  b WITH(NOLOCK) ON b.BranchID = a.BranchID AND b.OrderNbr = a.OrderNbr
LEFT JOIN dbo.API_PostHistory p WITH(NOLOCK) ON a.BranchID = p.DmsBranchID and a.OrderNbr=p.DmsOrderNbr
LEFT JOIN dbo.OM_SalesOrd so  WITH(NOLOCK)  ON so.BranchID = a.BranchID AND so.OrigOrderNbr = a.OrderNbr
Left join OM_OriginalContract ctr WITH (NOLOCK) ON  a.ContractID=ctr.ContractID
INNER JOIN dbo.OM_OrderType oo WITH(NOLOCK) ON oo.OrderType = a.OrderType
LEFT join SI_Tax v  WITH(NOLOCK) on b.TaxID00=v.TaxID
WHERE so.OrigOrderNbr is null  --   a.OrderNbr ='DH032021-00271' and 
AND CAST(a.OrderDate AS DATE) BETWEEN @fromdate AND @todate 

GROUP BY 
CASE WHEN ISNULL(so.status, '') = '' THEN
         ( CASE WHEN a.Status = 'C' THEN N'Đã Duyệt Đơn Hàng'
         WHEN a.Status = 'H' THEN N'Chờ Xử Lý'
         WHEN a.Status = 'E' THEN N'Đóng Đơn Hàng'
		 WHEN a.Status = 'D' THEN N'Đơn Hàng Tạm'
		 WHEN a.Status = 'V' THEN N'Hủy Đơn Hàng'
         END
         )
         ELSE ( CASE WHEN so.Status = 'C' THEN N'Đã Phát Hành'
         WHEN so.Status = 'I' THEN N'Tạo Hóa Đơn'
         WHEN so.Status = 'N' THEN N'Tạo Hóa Đơn'
         WHEN so.Status = 'H' THEN N'Chờ Xử Lý'
		 WHEN so.Status = 'D' THEN N'Đơn Hàng Tạm'
         WHEN so.Status = 'E' THEN N'Đóng Đơn Hàng'
		 WHEN so.Status = 'V' THEN N'Hủy Hóa Đơn' 
         END
         )
         END , b.Lineqty,
         a.BranchID , ISNULL(so.InvcNbr,'') ,ISNULL(so.InvcNote,''),b.invtid,
         a.OrderNbr ,
         b.SlsPerID ,
         a.OrderDate ,
         a.CustID ,
         a.Crtd_User ,
         a.Crtd_DateTime ,
		 a.ContractID ,
         a.DeliveryID ,
         a.ShipDate ,
         a.OrdAmt,
		 a.OrderType,  ISNULL(ctr.ContractNbr,''),ISNULL(p.PNOrderNbr,'') ,
		 a.Remark
) a


----khoahnt them
SELECT distinct a.BranchID , a.OrderNbr   
INTO #Sales
FROM #Ord a
WHERE  CAST(a.OrderDate AS DATE) BETWEEN @fromdate AND @todate


----khoahnt them
SELECT DISTINCT ord.BranchID, ord.OrderNbr,d.InvtID,d.LineRef,dis.FreeItemID, sq.TypeDiscount
, DiscAmt=    CASE WHEN dis.DiscType='L' then d.DiscAmt
						   WHEN dis.DiscType='G'	THEN d.GroupDiscAmt1
						   WHEN dis.DiscType='D' THEN d.DocDiscAmt
					  END
				 
, DiscPct =  CASE WHEN dis.DiscType='L' then d.DiscPct
						   WHEN dis.DiscType='G'	THEN d.GroupDiscPct1
						   WHEN dis.DiscType='D' THEN d.DocDiscAmt -- Chưa biết tính như thế nào
				END 
,sq.DiscIDPN ,sq.DiscID, sq.DiscSeq,dis.SOLineRef, sq.Descr
INTO #TOrdDisc1
FROM dbo.OM_SalesOrd ord WITH (NOLOCK) 
INNER JOIN dbo.OM_SalesOrdDet d WITH (NOLOCK) ON d.BranchID = ord.BranchID AND d.OrderNbr = ord.OrderNbr
INNER JOIN dbo.OM_OrdDisc dis WITH (NOLOCK) ON dis.BranchID=d.BranchID AND dis.OrderNbr=d.OrderNbr AND d.LineRef IN (SELECT part FROM dbo.fr_SplitStringMAX(dis.GroupRefLineRef,','))
INNER JOIN dbo.OM_DiscSeq sq WITH (NOLOCK) ON sq.DiscID=dis.DiscID AND sq.DiscSeq=dis.DiscSeq
INNER JOIN dbo.#Sales s WITH (NOLOCK) ON ord.BranchID = s.BranchID AND ord.OrigOrderNbr=s.OrderNbr

WHERE  CAST(ord.OrderDate AS DATE) BETWEEN @fromdate AND @todate --   and ord.invcnbr='0086713'



----khoahnt them
SELECT DISTINCT d.BranchID, d.OrderNbr,d.InvtID,d.LineRef, d.TypeDiscount
, d.DiscAmt
, d.DiscPct 
,d.DiscIDPN ,d.DiscID, d.DiscSeq , d.Descr
INTO #TOrdDisc
FROM #TOrdDisc1 d
WHERE d.FreeItemID=''

--- Lấy danh sách sản phẩm khuyến mãi
CREATE TABLE #TDiscFreeItem (BranchID VARCHAR(30),OrderNbr VARCHAR(30),FreeItemID VARCHAR(30),TypeDiscount VARCHAR(30), DiscAmt FLOAT,DiscPct FLOAT
,DiscIDPN VARCHAR(30),DiscID VARCHAR(30), DiscSeq VARCHAR(30),SOLineRef VARCHAR(30),Descr nvarchar(MAX)
 )
INSERT INTO #TDiscFreeItem
(
    BranchID,
    OrderNbr,
    FreeItemID,
    TypeDiscount,
	DiscAmt,
	DiscPct,
    DiscIDPN,
    DiscID,
	DiscSeq,
    SOLineRef,
	Descr
)

SELECT DISTINCT dis.BranchID, dis.OrderNbr,dis.FreeItemID, dis.TypeDiscount,0,0

,dis.DiscIDPN ,dis.DiscID, dis.DiscSeq ,dis.SOLineRef, dis.Descr

FROM #TOrdDisc1 dis WITH (NOLOCK)
INNER JOIN dbo.OM_SalesOrdDet d WITH (NOLOCK) ON dis.BranchID=d.BranchID AND dis.OrderNbr=d.OrderNbr AND dis.FreeItemID=d.InvtID AND dis.SOLineRef=d.LineRef
--WHERE FreeItemID<>'' AND d.FreeItem=1  ---khoahnt bỏ để lấy các dòng sp áp khuyến mãi



INSERT INTO #TDiscFreeItem
(
    BranchID,
    OrderNbr,
    FreeItemID,
    TypeDiscount,
    DiscAmt,
    DiscPct,
    DiscIDPN,
    DiscID,
    DiscSeq,
    SOLineRef,
	Descr
)

SELECT DISTINCT ord.BranchID, ord.OrderNbr,pdis.FreeItemID, sq.TypeDiscount
, DiscAmt=0
, DiscPct=0
,sq.DiscIDPN ,sq.DiscID, sq.DiscSeq,SOLineRef=d.LineRef, sq.Descr
FROM #Sales bat
INNER JOIN dbo.OM_SalesOrd ord WITH (NOLOCK) ON ord.BranchID = bat.BranchID AND bat.OrderNbr=ord.OrigOrderNbr
INNER JOIN dbo.OM_SalesOrdDet d WITH (NOLOCK) ON d.BranchID = ord.BranchID AND d.OrderNbr = ord.OrderNbr
--INNER JOIN #TableBranchID r WITH(NOLOCK) ON r.BranchID=ord.BranchID 
INNER JOIN dbo.OM_PDAOrdDisc pdis WITH (NOLOCK) ON pdis.BranchID=d.BranchID AND pdis.OrderNbr=d.OrigOrderNbr AND d.InvtID=pdis.FreeItemID AND d.FreeItem=1 AND d.OriginalLineRef=pdis.SOLineRef
INNER JOIN dbo.OM_DiscSeq sq WITH (NOLOCK) ON sq.DiscID=pdis.DiscID AND sq.DiscSeq=pdis.DiscSeq
LEFT JOIN #TDiscFreeItem dis WITH (NOLOCK) ON  dis.BranchID=d.BranchID AND dis.FreeItemID=d.InvtID AND d.OrderNbr=dis.OrderNbr AND d.FreeItem=1 AND dis.SOLineRef=d.LineRef
WHERE dis.OrderNbr IS NULL



SELECT a.BranchID , a.OrderNbr , DiscAmt = SUM(a.DiscAmt)
INTO #Disc
FROM  dbo.OM_PDAOrdDisc a WITH(NOLOCK)
--INNER JOIN dbo.RPTRunningParm0 r WITH(NOLOCK) ON r.StringParm = a.BranchID AND r.ReportID = @RPTID
INNER JOIN dbo.OM_PDASalesOrd b WITH(NOLOCK) ON b.BranchID = a.BranchID AND b.OrderNbr = a.OrderNbr
INNER JOIN dbo.#Sales s WITH (NOLOCK)
        ON b.BranchID = s.BranchID
           AND b.OrderNbr = s.OrderNbr
WHERE a.DiscFor <> 'I'
AND CAST(b.OrderDate AS DATE) BETWEEN @fromdate AND @todate
GROUP BY a.BranchID , a.OrderNbr 

SELECT a.BranchID , a.BatNbr , a.SlsperID , a.Status , a.OrderNbr , ShipDate = ISNULL(c.ShipDate, a.Crtd_DateTime)
INTO #Deli
FROM dbo.OM_Delivery a WITH(NOLOCK) 
INNER JOIN #Sales d
        ON d.BranchID = a.BranchID
           AND d.OrderNbr = a.OrderNbr
--INNER JOIN dbo.RPTRunningParm0 r WITH(NOLOCK) ON r.StringParm = a.BranchID AND r.ReportID = @RPTID
INNER JOIN ( SELECT de.BranchID,
               de.BatNbr,
               de.OrderNbr,
               Sequence = MAX(Sequence)
        FROM dbo.OM_Delivery de
		INNER JOIN #Sales d
        ON d.BranchID = de.BranchID
           AND d.OrderNbr = de.OrderNbr
        GROUP BY de.BranchID,
                 de.BatNbr,
                 de.OrderNbr
			) b ON b.BatNbr = a.BatNbr AND b.BranchID = a.BranchID AND b.Sequence = a.Sequence AND b.OrderNbr = a.OrderNbr
LEFT JOIN (SELECT de.BranchID,
               de.BatNbr,
               de.OrderNbr,
               ShipDate = MAX(ShipDate)
        FROM dbo.OM_DeliHistory de
		INNER JOIN #Sales d
        ON d.BranchID = de.BranchID
           AND d.OrderNbr = de.OrderNbr
        GROUP BY de.BranchID,
                 de.BatNbr,
                 de.OrderNbr ) c ON c.BatNbr = a.BatNbr AND c.BranchID = a.BranchID AND c.OrderNbr = a.OrderNbr

SELECT ib.BranchID, ib.SlsperID, ib.BatNbr, ibe.OrderNbr, Name = FirstName , trs.Descr
INTO #Book
FROM OM_IssueBook ib  WITH(NOLOCK) 

--INNER JOIN dbo.RPTRunningParm0 r WITH(NOLOCK) ON r.StringParm = ib.BranchID AND r.ReportID = @RPTID
INNER join OM_IssueBookDet ibe  WITH(NOLOCK)  on ibe.BranchID = ib.BranchID and ibe.BatNbr = ib.BatNbr
INNER JOIN dbo.#Sales s WITH (NOLOCK)
        ON ibe.BranchID = s.BranchID
           AND ibe.OrderNbr = s.OrderNbr
	inner join Users u WITH(NOLOCK) on u.UserName = ib.SlsperID
	inner join AR_Transporter trs WITH(NOLOCK) on trs.Code = ib.DeliveryUnit
	SELECT * FROM(
SELECT DISTINCT [Mã Công Ty/CN] = ISNULL(a.BranchID,'') ,
       [Công Ty/CN] = ISNULL(com.CpnyName,'') ,
	   [Địa Chỉ Công Ty/CN] = ISNULL(com.Address,'') ,
       [Mã NV] = ISNULL(a.SlsPerID,'') ,
	   [Tên CVBH] = ISNULL(sa.FirstName,'') , 	   
       [Ngày Chứng Từ] = ISNULL(a.OrderDate,'') ,
	   [Số Đơn Đặt Hàng] = ISNULL(a.OrderNbr,'') ,
	   [Mã Đơn Hàng PN] = ISNULL(a.PNOrderNbr,'') , 
	   [Hóa Đơn] = ISNULL(b.InvcNbr,'') ,
	   [Ngày Tới Hạn TT] = ISNULL(CONVERT(VARCHAR(10),b.DueDate,103),'') , --PhucPM cmt lại ra convert ra k đúng format --ISNULL(CONVERT(VARCHAR(10),b.DueDate ),'') , --
	   [Số Hợp Đồng] = ISNULL(con.ContractNbr,'') ,
       [Trạng Thái] = a.Status ,
	   [Mã KH Thuế] = ISNULL(cu.CustIDInvoice,'') ,
	   [Tên KH Thuế] = ISNULL(cu.CustNameInvoice,'') ,
	   [Mã Số Thuế] = ISNULL(cu.TaxID,'') ,
       [Mã KH DMS] = ISNULL(a.CustID,'') ,   
	   [Mã KH Cũ] = ISNULL(cu.RefCustID,'') , 
	   [Tên Khách Hàng] = ISNULL(cu.CustName,'') ,
	   [Địa Chỉ KH] = ISNULL(cu.CustAddress,'') ,
	   [Tên Tỉnh KH] = ISNULL(cu.StateDescr,'') , 
	   [Quận/HUyện] = ISNULL(cu.DistrictDescr,'') , 
	   [Phường/Xã] = ISNULL(cu.WardDescr,'') , 
	   [Tên Kênh KH] = ISNULL(cu.ChannelDescr,'') , 
	   [Kênh Phụ] = ISNULL(cu.ShopTypeDescr,'') ,
	   [Mã Sản Phẩm] = ISNULL(a.InvtID,'') ,
	   [Tên Sản Phẩm] =ISNULL(invt.Descr,''),
		[Mã Kho] =ISNULL(od.SiteID,''),
		[Tên Kho]=ISNULL(wh.Name,''),
	   [Tên Viết Tắt] =  invt.Descr1,
	   [Số Lô]= ISNULL(a.LotserNbr,''),
	   [Hạn Dùng]= ISNULL(CONVERT(VARCHAR(10),a.ExpDate,103),'') , 
	   [Số Lượng] = isnull (a.OrdQty,''),
	   [Doanh Số (Có VAT)] = ISNULL(a.AfterVATAmount,0) ,
       [Doanh Số (Chưa VAT)] = ISNULL(a.BeforeVATAmount,0) ,
	    [Mã CTKM] = CASE WHEN ISNULL(dis.TypeDiscount,'')='PR' THEN ISNULL(dis.DiscIDPN,'')
						WHEN ISNULL(dis1.TypeDiscount,'')='PR' THEN ISNULL(dis1.DiscIDPN,'') ELSE '' END ,
		[Mã CSBH] = CASE WHEN ISNULL(dis.TypeDiscount,'')='SP' THEN ISNULL(dis.DiscIDPN,'') 
						 WHEN ISNULL(dis1.TypeDiscount,'')='SP' THEN ISNULL(dis1.DiscIDPN,'')  ELSE '' END,

	   --[Tổng GT Chiết Khấu] = ISNULL(a.ChietKhau,0) , 
	   --[Thành Tiền Sau CK] = ISNULL(a.AfterVATAmount,0)- ISNULL(a.ChietKhau,0),
	   --[Số Tiền Thanh Toán] = ISNULL(b.PaidAmount,0) ,
	   --[Số Tiền Còn Nợ] = ISNULL(b.RemainAmount,0) ,
	   --[Tình Trạng Nợ] = ISNULL(e.DebtStatus,'') , 
	   --[TenSUP] = ISNULL(su.FirstName,''),
	   --[TenASM] = ISNULL(am.FirstName,'') ,
	   --[TenRSM] = ISNULL(rm.FirstName,'') ,
	   [Ngày Đặt Đon] = ISNULL(a.Crtd_DateTime,'') ,
	   [Người Tạo Đơn] = ISNULL(cre.FirstName,'') , 
	   [Ghi Chú] = ISNULL(a.Note,''),
	   [Ngày Giao Hàng] = ISNULL(CONVERT(VARCHAR(20),d.ShipDate,103),'') ,
	   [Người Giao hàng] = ISNULL(deli.FirstName,iss.Name) ,	
	   [Trạng Thái Giao Hàng] = CASE	WHEN d.Status = 'H' THEN N'Chưa xác nhận'   
										WHEN d.Status = 'D' THEN N'KH Không nhận'
										WHEN d.Status = 'A' THEN N'Đã xác nhận'
										WHEN d.Status = 'R' THEN N'Từ Chối Giao Hàng'
										WHEN d.Status = 'C' THEN N'Đã giao hàng' 
										WHEN d.Status = 'E' THEN N'Không tiếp tục giao hàng' END  ,
	   [Sổ Xuất Hàng] = iss.BatNbr,
	   [Đơn Vị Giao Hàng] = iss.Descr,
	   [Người Chịu Trách Nhiệm Nợ] = ISNULL(foll.FirstName,'')
       
FROM #Ord a 
--INNER JOIN dbo.RPTRunningParm0 r WITH(NOLOCK) ON r.StringParm=a.BranchID AND r.ReportID=@RPTID
INNER JOIN #SalesForce sf WITH(NOLOCK) ON sf.BranchID = a.BranchID AND sf.SlsperID = a.SlsPerID
INNER JOIN dbo.IN_Inventory ii  WITH (NOLOCK) ON a.InvtID=ii.InvtID
LEFT JOIN #Doc b ON b.BranchID = a.BranchID AND b.CustId = a.CustID AND a.OrderNbr = b.OrderNbr and a.InvcNbr=b.InvcNbr and a.InvcNote=b.InvcNote
LEFT JOIN #DebtStatus e ON e.BranchID = b.BranchID AND e.CustId = b.CustId AND e.OrderNo = b.OrderNo and e.BatNbr=b.BatNbr and e.RefNbr=b.RefNbr
LEFT JOIN #Disc c ON c.BranchID = a.BranchID AND c.OrderNbr = a.OrderNbr
LEFT JOIN #Deli d ON d.BranchID = a.BranchID AND d.OrderNbr = a.OrderNbr
LEFT JOIN #Book iss ON iss.BranchID = a.BranchID AND iss.OrderNbr = a.OrderNbr
INNER JOIN #Customer cu WITH(NOLOCK) ON cu.BranchID = a.BranchID AND cu.CustId = a.CustID
INNER JOIN dbo.Users sa WITH(NOLOCK) ON sa.UserName = a.SlsPerID 
INNER JOIN dbo.IN_Inventory invt WITH(NOLOCK) ON invt.InvtID = a.InvtID 
--LEFT JOIN dbo.Users su WITH(NOLOCK) ON su.UserName = sa.Manager
--LEFT JOIN dbo.Users am WITH(NOLOCK) ON am.UserName = su.Manager
--LEFT JOIN dbo.Users rm WITH(NOLOCK) ON rm.UserName = rm.Manager
LEFT JOIN dbo.SYS_Company com WITH(NOLOCK) ON a.BranchID = com.CpnyID 
LEFT JOIN dbo.OM_DebtAllocateDet da WITH(NOLOCK) ON da.BranchID = a.BranchID AND da.OrderNbr = a.OrderNbr and a.InvcNbr=da.InvcNbr and a.InvcNote=da.InvcNote
LEFT JOIN dbo.OM_OriginalContract con WITH(NOLOCK) ON con.ContractID = a.ContractID
LEFT JOIN dbo.Users deli WITH(NOLOCK) ON deli.UserName = d.SlsperID
LEFT JOIN dbo.Users cre WITH(NOLOCK) ON cre.UserName = a.Crtd_User
LEFT JOIN dbo.Users foll WITH(NOLOCK) ON foll.UserName = da.SlsperID
LEFT JOIN dbo.OM_SalesOrdDet od WITH (NOLOCK) ON od.BranchID=a.BranchID AND a.OrderNbr=od.OrigOrderNbr AND a.InvtID = od.InvtID AND a.OrdQty = od.LineQty
LEFT JOIN #TOrdDisc1 dis WITH (NOLOCK) ON dis.BranchID=a.BranchID AND dis.OrderNbr=od.OrderNbr AND dis.LineRef=od.LineRef ---khoahnt đổi #TOrdDisc sang #TOrdDisc1  để lấy các dòng sp áp khuyến mãi
LEFT JOIN #TDiscFreeItem dis1 WITH (NOLOCK) ON dis1.BranchID=a.BranchID AND dis1.OrderNbr=od.OrderNbr AND dis1.FreeItemID=a.InvtID AND dis1.SOLineRef=od.LineRef
LEFT JOIN dbo.IN_Site wh WITH(NOLOCK) ON wh.SiteId = od.SiteID
---WHERE a.OrderNbr='DH0-0322-00934'
--where   (cu.Territory LIKE CASE WHEN @Terr = '' THEN '%' END OR cu.Territory IN (SELECT part FROM dbo.fr_SplitStringMAX(@Terr,',')))
)a
ORDER by a.[Mã Công Ty/CN],a.[Ngày Chứng Từ],a.[Số Đơn Đặt Hàng]

--SELECT * FROM #TOrdDisc WHERE OrderNbr='HD0-1221-01517'
--SELECT * FROM #TDiscFreeItem  WHERE OrderNbr='HD0-1221-01517'
DROP TABLE #Disc
DROP TABLE #Doc
DROP TABLE #Ord
DROP TABLE #Deli
DROP TABLE #SalesForce
DROP TABLE #DebtStatus
DROP TABLE #Customer
DROP TABLE #Book
--DROP TABLE #TableBranchID
DROP TABLE #TDiscFreeItem
DROP TABLE #TOrdDisc
DROP TABLE #TOrdDisc1
DROP TABLE #Sales
--SELECT * FROM #Ord
GO