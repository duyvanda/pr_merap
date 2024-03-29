USE [PhaNam_eSales_PRO]
GO

/****** Object:  StoredProcedure [dbo].[pr_OM_RawdataSellOutPayroll]    Script Date: 17/03/2022 2:01:02 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

---USE PhaNam_eSales_PRO_INTERNAL
ALTER PROC [dbo].[pr_OM_RawdataSellOutPayroll]   -- pr_OM_RawdataSellOutPayroll_Test  4424
@RPTID INT
AS
----chuẩn 1471 - 12409 dòng
--USE PhaNam_eSales_PRO_INTERNAL

---DECLARE @RPTID INT = 1471;

DECLARE @fromdate SMALLDATETIME;
DECLARE @todate SMALLDATETIME;
DECLARE @UserID VARCHAR(30);
DECLARE @Terr VARCHAR(MAX);
DECLARE @Zone VARCHAR(MAX);
DECLARE @MachineName VARCHAR(50);
DECLARE @Branch VARCHAR(MAX);
DECLARE @CurrentDate DATE = CAST(GETDATE() AS DATE);
SELECT @fromdate = DateParm00,
       @todate = DateParm01,
       @UserID = UserID,
       @MachineName = MachineName,
       @Branch = StringParm01
FROM dbo.RPTRunning WITH (NOLOCK)
WHERE ReportID = @RPTID;


CREATE TABLE #TableBranchID
(
    BranchID VARCHAR(50)
);
CREATE TABLE #TOrderType
(
    OrderType VARCHAR(5),
    Descr NVARCHAR(100)
);
IF @MachineName = '4DSERVER'
BEGIN

    IF ISNULL(@Branch, '') = ''
    BEGIN
        SELECT @Branch = CpnyID
        FROM dbo.Users WITH (NOLOCK)
        WHERE UserName = @UserID;
    END;

    INSERT INTO #TableBranchID
    (
        BranchID
    )
    SELECT part
    FROM dbo.fr_SplitStringMAX(@Branch, ',');

    INSERT INTO #TOrderType
    EXEC pr_ListOrderType_DS @ReportNbr = N'OLAP106',
                             @ReportDate = @CurrentDate,
                             @DateParm00 = @CurrentDate,
                             @DateParm01 = @CurrentDate,
                             @DateParm02 = @CurrentDate,
                             @DateParm03 = @CurrentDate,
                             @BooleanParm00 = N'0',
                             @BooleanParm01 = N'0',
                             @BooleanParm02 = N'0',
                             @BooleanParm03 = N'0',
                             @StringParm00 = N'',
                             @StringParm01 = N'',
                             @StringParm02 = N'',
                             @StringParm03 = N'',
                             @UserID = @UserID,
                             @CpnyID = N'MR0001',
                             @LangID = N'1';
END;
ELSE
BEGIN
    INSERT INTO #TableBranchID
    (
        BranchID
    )
    SELECT BranchID = StringParm
    FROM dbo.RPTRunningParm0 WITH (NOLOCK)
    WHERE ReportID = @RPTID;
    INSERT INTO #TOrderType
    (
        OrderType,
        Descr
    )
    SELECT StringParm,
           ''
    FROM dbo.RPTRunningParm1
    WHERE ReportID = @RPTID;
END;

SELECT BranchID,
       SlsperID
INTO #SalesForce
FROM dbo.fr_ListSaleByData(@UserID);
-- AnhTT Loại các đơn trả hàng CO, EP ko lấy lên báo cáo sellout
SELECT o.BranchID,
       o.OrderNbr
INTO #DataReturnIO
FROM OM_SalesOrd o WITH (NOLOCK)
    INNER JOIN OM_SalesOrd o1 WITH (NOLOCK)
        ON o.BranchID = o1.BranchID
           AND o.InvcNbr = o1.InvcNbr
           AND o.InvcNote = o1.InvcNote
           AND o1.OrderType = 'IO'
WHERE o.OrderDate
      BETWEEN @fromdate AND @todate
      AND o.OrderDate >= '20210501'
      AND o.OrderType IN ( 'CO', 'EP' )
      AND o.Status = 'C';

SELECT *
INTO #Customer
FROM dbo.vs_AR_CustomerInfoByTime cu WITH (NOLOCK);

CREATE TABLE #CustomerInvoice( BranchID VARCHAR(20),OrderNbr VARCHAR(50),CustID VARCHAR(50),CustName NVARCHAR(1000),CusAddress NVARCHAR(1000),CusTaxCode VARCHAR(100))
INSERT INTO #CustomerInvoice
(
    BranchID,
    OrderNbr,
    CustID,
    CustName,
    CusAddress,
    CusTaxCode
)

SELECT DISTINCT BranchID,OrderNbr,CustID,CustName,CusAddress,CusTaxCode FROM dbo.Log_InvoiceInfo
--UNION 
--SELECT DISTINCT BranchID,OrderNbr,CustID,CustName,CusAddress,CusTaxCode FROM dbo.Log_InvoiceAddress


SELECT * 
INTO #CustomerMaster
FROM dbo.vs_AR_CustomerInfo cu WITH(NOLOCK)
--WHERE (cu.Territory LIKE CASE WHEN @Terr = '' THEN '%' END OR cu.Territory IN (SELECT part FROM dbo.fr_SplitStringMAX(@Terr,',')))
--AND (cu.State LIKE CASE WHEN @Zone = '' THEN '%' END OR cu.State IN (SELECT part FROM dbo.fr_SplitStringMAX(@Zone,',')))

SELECT DENSE_RANK() OVER (ORDER BY T1.DocDate, T2.OrigOrderNbr) AS OrderNo,
       ---- HAILH Modified On 22/07/2020: Bổ Sung Thông Tin BatNbr, RefNbr để truyền giá trị xuống PDA
       T1.BranchID,
       T1.BatNbr,
       T1.RefNbr,
       T1.CustId,
       T2.OrigOrderNbr AS OrderNbr,
       T1.InvcNbr,
       T1.InvcNote,
       T1.DocDate AS InvoiceDate,
       T1.OrigDocAmt AS InvoiceAmount,
       ---- HAILH Modified On 16/07/2020: Bổ sung xét thời hạn thanh toán theo Hợp Đồng nếu có
       COALESCE(T5.DueType, T3.DueType, '') AS DueType,
       COALESCE(T5.DueIntrv, T3.DueIntrv, '') AS DueIntrv,
       T1.DueDate,
       T3.Descr AS PaymentTerm,
       T1.OrigDocAmt - T1.DocBal AS PaidAmount,
       T1.DocBal AS RemainAmount,
       --'' AS DebtStatus,
       --'' AS Color ,
       OverPaymentTerm = IIF(T1.DueDate >= GETDATE(), 0, DATEDIFF(DAY, T1.DueDate, GETDATE()))
INTO #Doc
FROM AR_Doc T1 WITH (NOLOCK)
    INNER JOIN OM_SalesOrd T2 WITH (NOLOCK)
        ON T1.BranchID = T2.BranchID
           AND T1.RefNbr = T2.ARRefNbr
           AND T1.BatNbr = T2.ARBatNbr
    INNER JOIN #TableBranchID r WITH (NOLOCK)
        ON r.BranchID = T1.BranchID
    INNER JOIN SI_Terms T3 WITH (NOLOCK)
        ON T2.Terms = T3.TermsID
    ---- HAILH Modified On 16/07/2020: Bổ sung xét thời hạn thanh toán theo Hợp Đồng nếu có
    LEFT JOIN OM_OriginalContract T4 WITH (NOLOCK)
        ON T2.ContractID = T4.ContractID
    LEFT JOIN SI_Terms T5 WITH (NOLOCK)
        ON T4.Terms = T5.TermsID
WHERE CAST(T2.OrderDate AS DATE)
      BETWEEN @fromdate AND @todate --and T1.invcnbr='0086899'
      AND T2.Status <> 'V'; ---khoahnt them

SELECT a.BranchID,
       a.OrderNo,
       a.CustId,
       a.BatNbr,
       RefNbr,
       DebtStatus = T3.DebtStatusDescr,
       Color = T3.DebtStatusColor
INTO #DebtStatus
FROM #Doc a
    LEFT JOIN SI_DebtStatusSetup T2 WITH (NOLOCK)
        ON a.DueType = T2.DueType
    LEFT JOIN SI_DebtStatus T3 WITH (NOLOCK)
        ON T2.DebtStatusCode = T3.DebtStatusCode
WHERE a.OverPaymentTerm
      BETWEEN T2.DOverFrom AND T2.DOverTo
      AND a.OverPaymentTerm
      BETWEEN (ROUND(T2.TOverDaysFrom * a.DueIntrv, 0) + T2.AddDaysFrom) AND ROUND(T2.TOverDaysTo * a.DueIntrv, 0)
      AND PaidAmount <> 0;


SELECT BranchID,
       OrderNbr,
       MaCT,
       SlsperID,
       OrderDate,
       ReturnOrder,
       ReturnOrderdate,
       InvtID,
       Lotsernbr,
       ExpDate,
       Status,
       CustID,
       VATAmount,
       BeforeVATAmount,
       AfterVATAmount,
       Crtd_User,
       Crtd_DateTime,
       ContractID,
       DeliveryID,
       ShipDate,
       OrdAmt,
       OrdQty,
       InvcNbr,
       InvcNote,
       ChietKhau,
       a.OrderType,
       ContractNbr,
       SlsPrice,
       BeforeVATPrice,
       FreeItem,
       LineRef,
       ReasonCode,
	   a.SupID,
	   a.ASM,
	   a.RSM
INTO #Ord
FROM
(
    SELECT so.BranchID,
           OrderNbr = CASE
                          WHEN so.OrigOrderNbr <> '' THEN
                              so.OrigOrderNbr
                          ELSE
                              so.OrderNbr
                      END,
           MaCT = so.OrderNbr,
           so.SlsperID,
           so.OrderDate,
           ReturnOrder = ISNULL(a1.OrigOrderNbr, ''),
           ReturnOrderdate = ISNULL(a1.OrderDate, '19000101'),
           Status = CASE
                        WHEN ISNULL(so.status, '') = '' THEN
           (CASE
                WHEN a.Status = 'C' THEN
                    N'Đã Duyệt Đơn Hàng'
                WHEN a.Status = 'H' THEN
                    N'Chờ Xử Lý'
                WHEN a.Status = 'E' THEN
                    N'Đóng Đơn Hàng'
                WHEN a.Status = 'V' THEN
                    N'Hủy Đơn Hàng'
            END
           )
                        ELSE
           (CASE
                WHEN so.status = 'C' THEN
                    N'Đã Phát Hành'
                WHEN so.status = 'I' THEN
                    N'Tạo Hóa Đơn'
                WHEN so.status = 'N' THEN
                    N'Tạo Hóa Đơn'
                WHEN so.status = 'H' THEN
                    N'Chờ Xử Lý'
                WHEN so.status = 'E' THEN
                    N'Đóng Đơn Hàng'
                WHEN so.status = 'V' THEN
                    N'Hủy Hóa Đơn'
            END
           )
                    END,
           so.CustID,
           so.InvtID,
           Lotsernbr = so.Lotsernbr,
           ExpDate = so.ExpDate,
           VATAmount = SUM(so.VATAmount),
           BeforeVATAmount = SUM(so.BeforeVATAmount),
           AfterVATAmount = SUM(so.AfterVATAmount),
           so.Crtd_User,
           so.Crtd_DateTime,
           so.ContractID,
           so.DeliveryID,
           so.ShipDate,
           OrdAmt = ISNULL(so.OrdAmt, 0),
           OrdQty = so.Qty,
           InvcNbr = ISNULL(so.InvcNbr, ''),
           InvcNote = ISNULL(so.InvcNote, ''),
           so.LineRef,
           ChietKhau = SUM(so.ChietKhau),
           so.OrderType,
           ContractNbr = ISNULL(ctr.ContractNbr, ''),
           so.SlsPrice,
           so.BeforeVATPrice,
           so.FreeItem,
           ReasonCode = CASE
                            WHEN a.ReasonCode <> '' THEN
                                a.ReasonCode
                            ELSE
                                so.ReasonCode
                        END,
						so.SupID,
		 so.ASM,
		 so.RSM
    FROM
    (
        SELECT DISTINCT
               o.BranchID,
               o.OrderDate,
               o.CustID,
               OrigOrderNbr = o.OrigOrderNbr,
               o.OrderNbr,
               o.Crtd_User,
               o.Crtd_DateTime,
               status = MIN(o.Status),
               o.ContractID,
               o.OrdAmt,
               o.InvcNbr,
               o.InvcNote,
               b.SlsperID,
               b.InvtID,
               b.FreeItem,
               Qty = SUM(ISNULL(l.Qty, b.LineQty)),
               Lotsernbr = ISNULL(l.LotSerNbr, ''),
               a.DeliveryID,
               a.ShipDate,
               ExpDate = CAST(ISNULL(l.ExpDate, '') AS VARCHAR(20)),
               ChietKhau = (o.OrdDiscAmt + o.VolDiscAmt),
               BeforeVATAmount = SUM(   CASE
                                            WHEN b.FreeItem = 1 THEN
                                                0
                                            ELSE
                                        (CASE
                                             WHEN oo.ARDocType IN ( 'IN', 'DM', 'CS' ) THEN
                                                 1
                                             WHEN oo.ARDocType IN ( 'NA' ) THEN
                                                 0
                                             ELSE
                                                 -1
                                         END
                                        ) * b.BeforeVATAmount
                                        END
                                    ),
               AfterVATAmount = SUM(   CASE
                                           WHEN b.FreeItem = 1 THEN
                                               0
                                           ELSE
                                       (CASE
                                            WHEN oo.ARDocType IN ( 'IN', 'DM', 'CS' ) THEN
                                                1
                                            WHEN oo.ARDocType IN ( 'NA' ) THEN
                                                0
                                            ELSE
                                                -1
                                        END
                                       ) * b.AfterVATAmount
                                       END
                                   ),
               VATAmount = SUM(   CASE
                                      WHEN b.FreeItem = 1 THEN
                                          0
                                      ELSE
                                  (CASE
                                       WHEN oo.ARDocType IN ( 'IN', 'DM', 'CS' ) THEN
                                           1
                                       WHEN oo.ARDocType IN ( 'NA' ) THEN
                                           0
                                       ELSE
                                           -1
                                   END
                                  ) * b.VATAmount
                                  END
                              ),
               b.SlsPrice,
               BeforeVATPrice = ROUND(b.BeforeVATPrice, 0),
               o.OrderType,
               ReasonCode = o.ReasonCode,
               b.LineRef,
			    b.SupID,
			   b.ASM,
			   b.RSM
        FROM dbo.OM_SalesOrd o WITH (NOLOCK)
            INNER JOIN OM_SalesOrdDet b WITH (NOLOCK)
                ON o.BranchID = b.BranchID
                   AND o.OrderNbr = b.OrderNbr
            LEFT JOIN OM_LotTrans l WITH (NOLOCK)
                ON l.BranchID = b.BranchID
                   AND l.OrderNbr = b.OrderNbr
                   AND l.OMLineRef = b.LineRef
            LEFT JOIN #DataReturnIO oity
                ON oity.BranchID = o.BranchID
                   AND oity.OrderNbr = o.OrderNbr
            INNER JOIN dbo.OM_OrderType oo WITH (NOLOCK)
                ON oo.OrderType = o.OrderType
                   AND ARDocType IN ( 'IN', 'DM', 'CS', 'CM' )
            INNER JOIN #TOrderType r1 WITH (NOLOCK)
                ON r1.OrderType = oo.OrderType
            INNER JOIN #TableBranchID r WITH (NOLOCK)
                ON r.BranchID = o.BranchID
            LEFT JOIN dbo.OM_PDASalesOrd a WITH (NOLOCK)
                ON o.BranchID = a.BranchID
                   AND o.OrigOrderNbr = a.OrderNbr
        WHERE (o.Status = 'C')
              AND CAST(o.OrderDate AS DATE)
              BETWEEN @fromdate AND @todate
              AND o.SalesOrderType <> 'RP' --  and o.invcnbr='0086713'
              AND oity.OrderNbr IS NULL
        GROUP BY o.BranchID,
                 o.OrigOrderNbr,
                 o.InvcNbr,
                 o.InvcNote,
                 o.OrdDiscAmt,
                 b.SlsperID,
                 o.VolDiscAmt,
                 b.InvtID,
                 ISNULL(l.LotSerNbr, ''),
                 o.OrdAmt,
                 o.OrderDate,
                 o.OrderType,
                 o.ContractID,
                 o.CustID,
                 o.Crtd_User,
                 o.Crtd_DateTime,
                 ISNULL(l.ExpDate, ''),
                 o.OrderNbr,
                 b.FreeItem,
                 b.SlsPrice,
                 a.DeliveryID,
                 a.ShipDate,
                 ROUND(b.BeforeVATPrice, 0),
                 o.ReasonCode,
                 b.LineRef, b.SupID,
			   b.ASM,
			   b.RSM
        UNION ALL
        SELECT DISTINCT
               o.BranchID,
               a.OrderDate,
               o.CustID,
               OrigOrderNbr = a.OrigOrderNbr,
               o.OrderNbr,
               o.Crtd_User,
               o.Crtd_DateTime,
               status = MIN(o.Status),
               o.ContractID,
               o.OrdAmt,
               o.InvcNbr,
               o.InvcNote,
               b.SlsperID,
               b.InvtID,
               b.FreeItem,
               Qty = SUM(ISNULL(l.Qty, b.LineQty)),
               Lotsernbr = ISNULL(l.LotSerNbr, ''),
               a.DeliveryID,
               a.ShipDate,
               ExpDate = CAST(ISNULL(l.ExpDate, '') AS VARCHAR(20)),
               ChietKhau = (o.OrdDiscAmt + o.VolDiscAmt),
               BeforeVATAmount = SUM(   CASE
                                            WHEN b.FreeItem = 1 THEN
                                                0
                                            ELSE
                                        (CASE
                                             WHEN oo.ARDocType IN ( 'IN', 'DM', 'CS' ) THEN
                                                 1
                                             WHEN oo.ARDocType IN ( 'NA' ) THEN
                                                 0
                                             ELSE
                                                 -1
                                         END
                                        ) * b.BeforeVATAmount
                                        END
                                    ),
               AfterVATAmount = SUM(   CASE
                                           WHEN b.FreeItem = 1 THEN
                                               0
                                           ELSE
                                       (CASE
                                            WHEN oo.ARDocType IN ( 'IN', 'DM', 'CS' ) THEN
                                                1
                                            WHEN oo.ARDocType IN ( 'NA' ) THEN
                                                0
                                            ELSE
                                                -1
                                        END
                                       ) * b.AfterVATAmount
                                       END
                                   ),
               VATAmount = SUM(   CASE
                                      WHEN b.FreeItem = 1 THEN
                                          0
                                      ELSE
                                  (CASE
                                       WHEN oo.ARDocType IN ( 'IN', 'DM', 'CS' ) THEN
                                           1
                                       WHEN oo.ARDocType IN ( 'NA' ) THEN
                                           0
                                       ELSE
                                           -1
                                   END
                                  ) * b.VATAmount
                                  END
                              ),
               b.SlsPrice,
               BeforeVATPrice = ROUND(b.BeforeVATPrice, 0),
               o.OrderType,
               ReasonCode = o.ReasonCode,
               b.LineRef,
			    b.SupID,
			   b.ASM,
			   b.RSM
        FROM dbo.OM_SalesOrd o WITH (NOLOCK)
            INNER JOIN OM_SalesOrdDet b WITH (NOLOCK)
                ON o.BranchID = b.BranchID
                   AND o.OrderNbr = b.OrderNbr
            LEFT JOIN OM_LotTrans l WITH (NOLOCK)
                ON l.BranchID = b.BranchID
                   AND l.OrderNbr = b.OrderNbr
                   AND l.OMLineRef = b.LineRef
            LEFT JOIN #DataReturnIO oity
                ON oity.BranchID = o.BranchID
                   AND oity.OrderNbr = o.OrderNbr
            INNER JOIN #TableBranchID r WITH (NOLOCK)
                ON r.BranchID = o.BranchID
            INNER JOIN dbo.OM_OrderType oo WITH (NOLOCK)
                ON oo.OrderType = o.OrderType
                   AND ARDocType IN ( 'IN', 'DM', 'CS', 'CM' )
            INNER JOIN dbo.OM_SalesOrd a WITH (NOLOCK)
                ON o.BranchID = a.BranchID
                   AND o.OrigOrderNbr = a.OrderNbr
        WHERE (o.Status = 'C')
              AND CAST(a.OrderDate AS DATE)
              BETWEEN @fromdate AND @todate
              AND o.SalesOrderType = 'RP' --  and o.invcnbr='0086713'
              AND oity.OrderNbr IS NULL
        GROUP BY o.BranchID,
                 a.OrigOrderNbr,
                 o.InvcNbr,
                 o.InvcNote,
                 o.OrdDiscAmt,
                 b.SlsperID,
                 o.VolDiscAmt,
                 b.InvtID,
                 ISNULL(l.LotSerNbr, ''),
                 o.OrdAmt,
                 a.OrderDate,
                 o.OrderType,
                 o.ContractID,
                 o.CustID,
                 o.Crtd_User,
                 o.Crtd_DateTime,
                 ISNULL(l.ExpDate, ''),
                 o.OrderNbr,
                 b.FreeItem,
                 b.SlsPrice,
                 a.DeliveryID,
                 a.ShipDate,
                 ROUND(b.BeforeVATPrice, 0),
                 o.ReasonCode,
                 b.LineRef,
				  b.SupID,
			   b.ASM,
			   b.RSM
    ) so
        LEFT JOIN dbo.OM_PDASalesOrd a WITH (NOLOCK)
            ON so.BranchID = a.BranchID
               AND so.OrigOrderNbr = a.OrderNbr
        LEFT JOIN dbo.OM_SalesOrd a1 WITH (NOLOCK)
            ON a.BranchID = a1.BranchID
               AND a.OriOrderNbrUp = a1.OrderNbr
        --INNER JOIN(Select * from dbo.OM_PDASalesOrdDet   WITH(NOLOCK))b ON b.BranchID = a.BranchID AND b.OrderNbr = a.OrderNbr
        INNER JOIN #TOrderType r1 WITH (NOLOCK)
            ON r1.OrderType = so.OrderType
        --LEFT JOIN dbo.API_PostHistory p WITH(NOLOCK) ON a.BranchID = p.DmsBranchID and a.OrderNbr=p.DmsOrderNbr

        LEFT JOIN OM_OriginalContract ctr WITH (NOLOCK)
            ON so.ContractID = ctr.ContractID
    --WHERE CAST(a.OrderDate AS DATE) BETWEEN @fromdate AND @todate and a.Status='C'
    GROUP BY CASE
                 WHEN ISNULL(so.status, '') = '' THEN
        (CASE
             WHEN a.Status = 'C' THEN
                 N'Đã Duyệt Đơn Hàng'
             WHEN a.Status = 'H' THEN
                 N'Chờ Xử Lý'
             WHEN a.Status = 'E' THEN
                 N'Đóng Đơn Hàng'
             WHEN a.Status = 'V' THEN
                 N'Hủy Đơn Hàng'
         END
        )
                 ELSE
        (CASE
             WHEN so.status = 'C' THEN
                 N'Đã Phát Hành'
             WHEN so.status = 'I' THEN
                 N'Tạo Hóa Đơn'
             WHEN so.status = 'N' THEN
                 N'Tạo Hóa Đơn'
             WHEN so.status = 'H' THEN
                 N'Chờ Xử Lý'
             WHEN so.status = 'E' THEN
                 N'Đóng Đơn Hàng'
             WHEN so.status = 'V' THEN
                 N'Hủy Hóa Đơn'
         END
        )
             END,
             so.BranchID,
             ISNULL(so.InvcNbr, ''),
             ISNULL(so.InvcNote, ''),
             so.InvtID,
             so.ExpDate,
             so.Lotsernbr,
             so.FreeItem,
             so.OrderNbr,
             so.SlsPrice,
             so.BeforeVATPrice,
             a1.OrigOrderNbr,
             a1.OrderDate,
             CASE
                 WHEN so.OrigOrderNbr <> '' THEN
                     so.OrigOrderNbr
                 ELSE
                     so.OrderNbr
             END,
             so.SlsperID,
             so.LineRef,
             CASE
                 WHEN a.ReasonCode <> '' THEN
                     a.ReasonCode
                 ELSE
                     so.ReasonCode
             END,
             so.OrderDate,
             so.CustID,
             so.Crtd_User,
             so.Crtd_DateTime,
             so.ContractID,
             so.DeliveryID,
             so.ShipDate,
             so.OrdAmt,
             so.Qty,
             so.OrderType,
             ISNULL(ctr.ContractNbr, ''),
			 so.SupID,
		 so.ASM,
		 so.RSM
) a;

SELECT DISTINCT
       a.BranchID,
       a.OrderNbr
INTO #Sales
FROM #Ord a
WHERE CAST(a.OrderDate AS DATE)
BETWEEN @fromdate AND @todate;



SELECT DISTINCT
       ord.BranchID,
       ord.OrderNbr,
       d.InvtID,
       d.LineRef,
       dis.FreeItemID,
       sq.TypeDiscount,
       DiscAmt = CASE
                     WHEN dis.DiscType = 'L' THEN
                         d.DiscAmt
                     WHEN dis.DiscType = 'G' THEN
                         d.GroupDiscAmt1
                     WHEN dis.DiscType = 'D' THEN
                         d.DocDiscAmt
                 END,
       DiscPct = CASE
                     WHEN dis.DiscType = 'L' THEN
                         d.DiscPct
                     WHEN dis.DiscType = 'G' THEN
                         d.GroupDiscPct1
                     WHEN dis.DiscType = 'D' THEN
                         d.DocDiscAmt -- Chưa biết tính như thế nào
                 END,
       sq.DiscIDPN,
       sq.DiscID,
       sq.DiscSeq,
       dis.SOLineRef,
       sq.Descr
INTO #TOrdDisc1
FROM dbo.OM_SalesOrd ord WITH (NOLOCK)
    INNER JOIN dbo.OM_SalesOrdDet d WITH (NOLOCK)
        ON d.BranchID = ord.BranchID
           AND d.OrderNbr = ord.OrderNbr
    INNER JOIN dbo.OM_OrdDisc dis WITH (NOLOCK)
        ON dis.BranchID = d.BranchID
           AND dis.OrderNbr = d.OrderNbr
           AND d.LineRef IN
               (
                   SELECT part FROM dbo.fr_SplitStringMAX(dis.GroupRefLineRef, ',')
               )
    INNER JOIN dbo.OM_DiscSeq sq WITH (NOLOCK)
        ON sq.DiscID = dis.DiscID
           AND sq.DiscSeq = dis.DiscSeq
    INNER JOIN dbo.#Sales s WITH (NOLOCK)
        ON ord.BranchID = s.BranchID
           AND ord.OrigOrderNbr = s.OrderNbr
WHERE CAST(ord.OrderDate AS DATE)
BETWEEN @fromdate AND @todate; --   and ord.invcnbr='0086713'



SELECT DISTINCT
       d.BranchID,
       d.OrderNbr,
       d.InvtID,
       d.LineRef,
       d.TypeDiscount,
       d.DiscAmt,
       d.DiscPct,
       d.DiscIDPN,
       d.DiscID,
       d.DiscSeq,
       d.Descr
INTO #TOrdDisc
FROM #TOrdDisc1 d
WHERE d.FreeItemID = '';

--- Lấy danh sách sản phẩm khuyến mãi
CREATE TABLE #TDiscFreeItem
(
    BranchID VARCHAR(30),
    OrderNbr VARCHAR(30),
    FreeItemID VARCHAR(30),
    TypeDiscount VARCHAR(30),
    DiscAmt FLOAT,
    DiscPct FLOAT,
    DiscIDPN VARCHAR(30),
    DiscID VARCHAR(30),
    DiscSeq VARCHAR(30),
    SOLineRef VARCHAR(30),
    Descr NVARCHAR(MAX)
);
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
SELECT DISTINCT
       dis.BranchID,
       dis.OrderNbr,
       dis.FreeItemID,
       dis.TypeDiscount,
       0,
       0,
       dis.DiscIDPN,
       dis.DiscID,
       dis.DiscSeq,
       dis.SOLineRef,
       dis.Descr
FROM #TOrdDisc1 dis
    INNER JOIN dbo.OM_SalesOrdDet d
        ON dis.BranchID = d.BranchID
           AND dis.OrderNbr = d.OrderNbr
           AND dis.FreeItemID = d.InvtID
           AND dis.SOLineRef = d.LineRef
WHERE FreeItemID <> ''
      AND d.FreeItem = 1;

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


SELECT DISTINCT
       ord.BranchID,
       ord.OrderNbr,
       pdis.FreeItemID,
       sq.TypeDiscount,
       DiscAmt = 0,
       DiscPct = 0,
       sq.DiscIDPN,
       sq.DiscID,
       sq.DiscSeq,
       SOLineRef = d.LineRef,
       sq.Descr
FROM #Sales bat
    INNER JOIN dbo.OM_SalesOrd ord WITH (NOLOCK)
        ON ord.BranchID = bat.BranchID
           AND bat.OrderNbr = ord.OrigOrderNbr
    INNER JOIN dbo.OM_SalesOrdDet d WITH (NOLOCK)
        ON d.BranchID = ord.BranchID
           AND d.OrderNbr = ord.OrderNbr
    INNER JOIN #TableBranchID r WITH (NOLOCK)
        ON r.BranchID = ord.BranchID
    INNER JOIN dbo.OM_PDAOrdDisc pdis WITH (NOLOCK)
        ON pdis.BranchID = d.BranchID
           AND pdis.OrderNbr = d.OrigOrderNbr
           AND d.InvtID = pdis.FreeItemID
           AND d.FreeItem = 1
           AND d.OriginalLineRef = pdis.SOLineRef
    INNER JOIN dbo.OM_DiscSeq sq WITH (NOLOCK)
        ON sq.DiscID = pdis.DiscID
           AND sq.DiscSeq = pdis.DiscSeq
    LEFT JOIN #TDiscFreeItem dis WITH (NOLOCK)
        ON dis.BranchID = d.BranchID
           AND dis.FreeItemID = d.InvtID
           AND d.OrderNbr = dis.OrderNbr
           AND d.FreeItem = 1
           AND dis.SOLineRef = d.LineRef
WHERE dis.OrderNbr IS NULL;

SELECT DISTINCT
       a.BranchID,
       a.BatNbr,
       a.SlsperID,
       a.Status,
       a.OrderNbr,
       ShipDate = ISNULL(c.ShipDate, a.Crtd_DateTime)
INTO #Deli
FROM dbo.OM_Delivery a WITH (NOLOCK)
    INNER JOIN #Sales d
        ON d.BranchID = a.BranchID
           AND d.OrderNbr = a.OrderNbr
    INNER JOIN
    (
        SELECT BranchID,
               BatNbr,
               OrderNbr,
               Sequence = MAX(Sequence)
        FROM dbo.OM_Delivery
        GROUP BY BranchID,
                 BatNbr,
                 OrderNbr
    ) b
        ON b.BatNbr = a.BatNbr
           AND b.BranchID = a.BranchID
           AND b.Sequence = a.Sequence
           AND b.OrderNbr = a.OrderNbr
    LEFT JOIN
    (
        SELECT BranchID,
               BatNbr,
               OrderNbr,
               ShipDate = MAX(ShipDate)
        FROM dbo.OM_DeliHistory
        GROUP BY BranchID,
                 BatNbr,
                 OrderNbr
    ) c
        ON c.BatNbr = a.BatNbr
           AND c.BranchID = a.BranchID
           AND c.OrderNbr = a.OrderNbr;

SELECT DISTINCT
       ib.BranchID,
       ib.SlsperID,
       ib.BatNbr,
       ibe.OrderNbr,
       Name = FirstName,
       trs.Descr,
       DeliveryUnitName = ISNULL(d.DeliveryUnitName, ''),
       TruckDescr = ISNULL(tr.Descr, '')
INTO #Book
FROM OM_IssueBook ib WITH (NOLOCK)
    LEFT JOIN OM_IssueBookDet ibe WITH (NOLOCK)
        ON ibe.BranchID = ib.BranchID
           AND ibe.BatNbr = ib.BatNbr
    --INNER JOIN  OM_SalesOrd s  WITH(NOLOCK)  on s.BranchID = ibe.BranchID AND s.OrigOrderNbr = ibe.OrderNbr
    INNER JOIN Users u WITH (NOLOCK)
        ON u.UserName = ib.SlsperID
    INNER JOIN AR_Transporter trs WITH (NOLOCK)
        ON trs.Code = ib.DeliveryUnit
    LEFT JOIN dbo.OM_ReceiptDet b WITH (NOLOCK)
        ON b.BranchID = ibe.BranchID
           AND b.OrderNbr = ibe.OrderNbr
    LEFT JOIN dbo.OM_Receipt a WITH (NOLOCK)
        ON b.ReportID = a.ReportID
    LEFT JOIN OM_Truck tr WITH (NOLOCK)
        ON a.TruckID = tr.Code
           AND tr.BranchID = a.BranchID
    LEFT JOIN dbo.OM_DeliReportDet de WITH (NOLOCK)
        ON de.BranchID = ibe.BranchID
           AND de.OrderNbr = ibe.OrderNbr
    LEFT JOIN dbo.OM_DeliReport da WITH (NOLOCK)
        ON da.ReportID = de.ReportID
           AND de.BranchID = da.BranchID
    LEFT JOIN dbo.AR_DeliveryUnit d WITH (NOLOCK)
        ON da.DeliveryUnit = d.DeliveryUnitID
           AND d.BranchID = da.BranchID;

--select * from #Ord
--select * from #TOrdDisc
--select * from #TDiscFreeItem

SELECT *
FROM
(
    SELECT DISTINCT
           [Mã Công Ty/CN] = ISNULL(a.BranchID, ''),
           [Công Ty/CN] = ISNULL(com.CpnyName, ''),
           --[Địa Chỉ Công Ty/CN] = ISNULL(com.Address,'') ,

           [Ngày Chứng Từ] = ISNULL(a.OrderDate, ''),
           [Số Đơn Đặt Hàng] = ISNULL(a.OrderNbr, ''),
           [Số Đơn Trả Hàng] = ISNULL(a.ReturnOrder, ''),
           [Ngày Trả Hàng] = ISNULL(CONVERT(VARCHAR(10), a.ReturnOrderdate, 103), ''),
           [Hóa Đơn] = ISNULL(a.InvcNbr, ''),
           [Ngày Tới Hạn TT] = ISNULL(CONVERT(VARCHAR(10), b.DueDate, 103), ''),
           [Số Hợp Đồng] = ISNULL(con.ContractNbr, ''),
           [Trạng Thái] = a.Status,
           [Mã KH Thuế] = ISNULL(o.InvoiceCustID, ''),
           [Tên KH Thuế] = ISNULL(cui.CustName,ISNULL(cum.CustNameInvoice, '')),
           [Địa Chỉ KH Thuế] = ISNULL(cui.CusAddress,ISNULL(cum.CustInvoiceAddr, '')),
           [Mã Số Thuế] = ISNULL(cui.CusTaxCode,ISNULL(cum.TaxID, '')),
           [Mã KH DMS] = ISNULL(a.CustID, ''),
           [Mã KH Cũ] = ISNULL(cu.RefCustID, ''),
           [Tên Khách Hàng] = ISNULL(cu.CustName, ''),
           [Địa Chỉ KH] = ISNULL(cu.CustAddress, ''),
           [Mã Vùng BH] = ISNULL(cu.Zone, ''),
           [Tên Vùng BH] = ISNULL(cu.ZoneDescr, ''),
           [Mã Khu Vực] = ISNULL(cu.Territory, ''),
           [Tên Khu Vực] = ISNULL(cu.TerritoryDescr, ''),
           [Mã Tỉnh KH] = ISNULL(cu.State, ''),
           [Tên Tỉnh KH] = ISNULL(cu.StateDescr, ''),
           [Mã Quận/HUyện] = ISNULL(cu.District, ''),
           [Tên Quận/HUyện] = ISNULL(cu.DistrictDescr, ''),
           [Phường/Xã] = ISNULL(cu.WardDescr, ''),
           [Mã Kênh KH] = ISNULL(cu.Channel, ''),
           [Tên Kênh KH] = ISNULL(cu.ChannelDescr, ''),
           [Mã Kênh Phụ] = ISNULL(cu.ShopType, ''),
           [Tên Kênh Phụ] = ISNULL(cu.ShopTypeDescr, ''),
           [Mã HCO] = ISNULL(cu.HCOID, ''),
           [Tên HCO] = ISNULL(cu.HCOName, ''),
           [Mã Phân Loại HCO] = ISNULL(cu.HCOTypeID, ''),
           [Tên Phân Loại HCO] = ISNULL(cu.HCOTypeName, ''),
           [Mã Phân Hạng HCO] = ISNULL(cu.ClassId, ''),
           [Tên Phân Hạng HCO] = ISNULL(cu.ClassDescr, ''),
           [Mã Sản Phẩm] = ISNULL(a.InvtID, ''),
           [Tên Sản Phẩm NB] = ISNULL(invt.Descr, ''),
           [Tên Sản Phẩm Viết Tắt] = CASE
                                         WHEN ISNULL(invt.Descr1, '') = '' THEN
                                             ISNULL(invt.Descr, '')
                                         ELSE
                                             ISNULL(invt.Descr1, '')
                                     END,
           [Số Lô] = ISNULL(a.Lotsernbr, ''),
           [Số Lượng] = CAST((CASE
                                  WHEN oo.ARDocType IN ( 'IN', 'DM', 'CS' ) THEN
                                      1
                                  ELSE
                                      -1
                              END
                             ) * ISNULL(a.OrdQty, 0) AS FLOAT),
           [Đơn Giá (Có VAT)] = CAST(ISNULL(a.SlsPrice, 0) AS FLOAT),
           [Doanh Số (Có VAT)] = CAST(CASE
                                          WHEN a.FreeItem = 1 THEN
                                              0
                                          ELSE
           (CASE
                WHEN oo.ARDocType IN ( 'IN', 'DM', 'CS' ) THEN
                    1
                ELSE
                    -1
            END
           ) * a.OrdQty * a.SlsPrice
                                      END AS FLOAT),
           [Đơn Giá (Chưa VAT)] = CAST(ISNULL(a.BeforeVATPrice, 0) AS FLOAT),
           [Doanh Số (Chưa VAT)] = CAST(CASE
                                            WHEN a.FreeItem = 1 THEN
                                                0
                                            ELSE
           (CASE
                WHEN oo.ARDocType IN ( 'IN', 'DM', 'CS' ) THEN
                    1
                ELSE
                    -1
            END
           ) * a.OrdQty * a.BeforeVATPrice
                                        END AS FLOAT),
           [Ngày Đặt Đon] = ISNULL(a.Crtd_DateTime, ''),
           [Người Tạo Đơn] = ISNULL(cre.FirstName, ''),
           [Ngày Giao Hàng] = ISNULL(CONVERT(VARCHAR(20), d.ShipDate, 103), ''),
           [Mã NV] = ISNULL(a.SlsperID, ''),
           [Tên CVBH] = ISNULL(sa.FirstName, ''),
		   [Tên Quản Lý TT] = ISNULL(sup.FirstName,''),
	   [Tên Quản Lý Khu Vực] = ISNULL(asm.FirstName,''),
	   [Tên Quản Lý Vùng] = ISNULL(Rsm.FirstName,''),
           [Mã NVGH (Trên SXH)] = ISNULL(iss.SlsperID, iss1.SlsperID),
           [Người Giao hàng (Trên SXH)] = ISNULL(iss.Name, iss1.Name),
           [Mã NVGH (Thực Tế)] = d.SlsperID,
           [Người Giao hàng (Thực Tế)] = deu.FirstName,
           [Trạng Thái Giao Hàng] = CASE
                                        WHEN d.Status = 'H' THEN
                                            N'Chưa xác nhận'
                                        WHEN d.Status = 'D' THEN
                                            N'KH Không nhận'
                                        WHEN d.Status = 'A' THEN
                                            N'Đã xác nhận'
                                        WHEN d.Status = 'R' THEN
                                            N'Từ Chối Giao Hàng'
                                        WHEN d.Status = 'C' THEN
                                            N'Đã giao hàng'
                                        WHEN d.Status = 'E' THEN
                                            N'Không tiếp tục giao hàng'
                                    END,
           [Sổ Xuất Hàng] = iss.BatNbr,
           [Đơn Vị Giao Hàng] = iss.Descr,
           [Tên Nhà Vận Chuyển] = iss.DeliveryUnitName,
           [Số Xe] = iss.TruckDescr,
           [Người Chịu Trách Nhiệm Nợ] = ISNULL(foll.FirstName, ''),
           [Kiểu Đơn Hàng] = a.OrderType,
           [Mã Lý Do] = sr.ProgramID,
           [Mã CSBH] = CASE
                           WHEN ISNULL(dis.TypeDiscount, '') = 'SP' THEN
                               ISNULL(dis.DiscIDPN, '')
                           WHEN ISNULL(dis1.TypeDiscount, '') = 'SP' THEN
                               ISNULL(dis1.DiscIDPN, '')
                           ELSE
                               ''
                       END,
           [Tên CSBH] = CASE
                            WHEN ISNULL(dis.TypeDiscount, '') = 'SP' THEN
                                ISNULL(dis.Descr, '')
                            WHEN ISNULL(dis1.TypeDiscount, '') = 'SP' THEN
                                ISNULL(dis1.Descr, '')
                            ELSE
                                ''
                        END,
           [Mã CTKM] = CASE
                           WHEN ISNULL(dis.TypeDiscount, '') = 'PR' THEN
                               ISNULL(dis.DiscIDPN, '')
                           WHEN ISNULL(dis1.TypeDiscount, '') = 'PR' THEN
                               ISNULL(dis1.DiscIDPN, '')
                           ELSE
                               ''
                       END,
           [Tên CTKM] = CASE
                            WHEN ISNULL(dis.TypeDiscount, '') = 'PR' THEN
                                ISNULL(dis.Descr, '')
                            WHEN ISNULL(dis1.TypeDiscount, '') = 'PR' THEN
                                ISNULL(dis1.Descr, '')
                            ELSE
                                ''
                        END,
           [Mã CTTL] = CASE
                           WHEN ISNULL(dis.TypeDiscount, '') = 'AC' THEN
                               ISNULL(dis.DiscIDPN, '')
                           WHEN ISNULL(dis1.TypeDiscount, '') = 'AC' THEN
                               ISNULL(dis1.DiscIDPN, '')
                           ELSE
                               ''
                       END,
           [Tên CTTL] = CASE
                            WHEN ISNULL(dis.TypeDiscount, '') = 'AC' THEN
                                ISNULL(dis.Descr, '')
                            WHEN ISNULL(dis1.TypeDiscount, '') = 'AC' THEN
                                ISNULL(dis1.Descr, '')
                            ELSE
                                ''
                        END,
           [Người Liên Hệ] = cu.Attn,
           [Số Điện Thoại] = cu.Phone
    FROM #Ord a
        LEFT JOIN dbo.OM_PDASalesOrd o WITH (NOLOCK)
            ON a.BranchID = o.BranchID
               AND a.OrderNbr = o.OrderNbr
               AND a.CustID = o.CustID
		
        INNER JOIN #TableBranchID r WITH (NOLOCK)
            ON r.BranchID = a.BranchID
        INNER JOIN dbo.OM_OrderType oo WITH (NOLOCK)
            ON oo.OrderType = a.OrderType
               AND ARDocType IN ( 'IN', 'DM', 'CS', 'CM' )
        LEFT JOIN #SalesForce sf WITH (NOLOCK)
            ON sf.BranchID = a.BranchID
               AND sf.SlsperID = a.SlsperID
        LEFT JOIN #Doc b
            ON b.BranchID = a.BranchID
               AND b.CustId = a.CustID
               AND a.OrderNbr = b.OrderNbr
               AND a.InvcNbr = b.InvcNbr
               AND a.InvcNote = b.InvcNote
        LEFT JOIN #DebtStatus e
            ON e.BranchID = b.BranchID
               AND e.CustId = b.CustId
               AND e.OrderNo = b.OrderNo
               AND e.BatNbr = b.BatNbr
               AND e.RefNbr = b.RefNbr
        LEFT JOIN #TOrdDisc dis WITH (NOLOCK)
            ON dis.BranchID = a.BranchID
               AND dis.OrderNbr = a.MaCT
               AND dis.LineRef = a.LineRef
        LEFT JOIN #TDiscFreeItem dis1 WITH (NOLOCK)
            ON dis1.BranchID = a.BranchID
               AND dis1.OrderNbr = a.MaCT
               AND dis1.FreeItemID = a.InvtID
               AND dis1.SOLineRef = a.LineRef
        LEFT JOIN dbo.SI_ReasonCode sr WITH (NOLOCK)
            ON sr.ReasonID = a.ReasonCode
        LEFT JOIN #Deli d
            ON d.BranchID = a.BranchID
               AND d.OrderNbr = a.OrderNbr
        LEFT JOIN #Book iss
            ON iss.BranchID = a.BranchID
               AND iss.OrderNbr = a.OrderNbr
        LEFT JOIN #Book iss1
            ON iss1.BranchID = a.BranchID
               AND iss1.OrderNbr = a.ReturnOrder
        --INNER JOIN #Customer cu WITH(NOLOCK) ON cu.CustId = a.CustID  AND a.Crtd_DateTime BETWEEN cu.Fromtime AND ISNULL(cu.Totime,'20990101')
        INNER JOIN #Customer cu WITH (NOLOCK)
            ON cu.CustId = a.CustID
               AND a.Crtd_DateTime
               BETWEEN cu.fromtime AND ISNULL(cu.totime, '20990101')
			   LEFT JOIN #CustomerInvoice cui WITH(NOLOCK) ON cui.BranchID = a.BranchID AND cui.OrderNbr=a.MaCT AND cui.CustID=a.CustID
			   LEFT JOIN #CustomerMaster cum WITH(NOLOCK) ON cum.CustId=a.CustID
        --INNER JOIN #CustomerInvoice cui WITH (NOLOCK)
        --    ON a.CustID = cui.CustID
        --       AND a.Crtd_DateTime
        --       BETWEEN cui.fromtime AND ISNULL(cui.totime, '20990101')
        INNER JOIN dbo.Users sa WITH (NOLOCK)
            ON sa.UserName = a.SlsperID
        INNER JOIN dbo.IN_Inventory invt WITH (NOLOCK)
            ON invt.InvtID = a.InvtID
        LEFT JOIN dbo.SYS_Company com WITH (NOLOCK)
            ON a.BranchID = com.CpnyID
        LEFT JOIN dbo.OM_DebtAllocateDet da WITH (NOLOCK)
            ON da.BranchID = a.BranchID
               AND da.OrderNbr = a.OrderNbr
               AND a.InvcNbr = da.InvcNbr
               AND a.InvcNote = da.InvcNote
        LEFT JOIN dbo.OM_OriginalContract con WITH (NOLOCK)
            ON con.ContractID = a.ContractID
        LEFT JOIN dbo.Users deli WITH (NOLOCK)
            ON deli.UserName = iss.SlsperID
        LEFT JOIN dbo.Users cre WITH (NOLOCK)
            ON cre.UserName = o.Crtd_User ----khoahnt doi lai lay nguoi tao don
        LEFT JOIN dbo.Users foll WITH (NOLOCK)
            ON foll.UserName = da.SlsperID
        LEFT JOIN dbo.Users deu WITH (NOLOCK)
            ON deu.UserName = d.SlsperID
				LEFT JOIN dbo.Users sup WITH (NOLOCK) ON sup.UserName=a.SupID
	LEFT JOIN dbo.Users asm WITH (NOLOCK) ON asm.UserName=a.ASM
	LEFT JOIN dbo.Users Rsm WITH (NOLOCK) ON rsm.UserName =a.RSM
    WHERE ISNULL(o.OrderType, '') <> ('IO') --khoahnt sửa lại cách bỏ đơn các đơn có liên quan IO 
	---AND cui.CustName IS NULL
) a

--WHERE LEFT(a.[Số Đơn Đặt Hàng],2)='IO'
--WHERE --a.[Hóa Đơn]='0012186'
--where   (cu.Territory LIKE CASE WHEN @Terr = '' THEN '%' END OR cu.Territory IN (SELECT part FROM dbo.fr_SplitStringMAX(@Terr,',')))
--order by a.BranchID,a.OrderDate, ISNULL(a.InvcNbr,'') ,a.OrderNbr,  ISNULL(a.InvtID,''), ISNULL(a.LotserNbr,'')
ORDER BY a.[Mã Công Ty/CN],
         a.[Ngày Chứng Từ],
         a.[Hóa Đơn],
         a.[Số Đơn Đặt Hàng],
         a.[Mã Sản Phẩm],
         a.[Số Lô]
	---	 SELECT * FROM #Doc
	---SELECT * FROM #Ord WHERE 
	
DROP TABLE #TOrdDisc1;
DROP TABLE #DataReturnIO;
DROP TABLE #Doc;
DROP TABLE #Ord;
DROP TABLE #Deli;
DROP TABLE #SalesForce;
DROP TABLE #DebtStatus;
DROP TABLE #Customer
DROP TABLE #CustomerInvoice
DROP TABLE #CustomerMaster
DROP TABLE #Book;
DROP TABLE #Sales;
DROP TABLE #TOrdDisc;
DROP TABLE #TDiscFreeItem;
DROP TABLE #TableBranchID;
DROP TABLE #TOrderType;
--DROP TABLE #tmp
--DROP TABLE #AR_CustomerHistory
--SELECT * FROM #ord WHERE OrderNbr='HD062021-00089'

--SELECT * FROM #Doc WHERE OrderNbr='HD062021-00089'


GO


