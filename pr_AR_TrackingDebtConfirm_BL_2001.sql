USE [PhaNam_eSales_PRO]
GO

/****** Object:  StoredProcedure [dbo].[pr_AR_RawdataTrackingDebtConfirm]    Script Date: 20/01/2022 9:41:00 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[pr_AR_RawdataTrackingDebtConfirm] --pr_AR_RawdataTrackingDebtConfirm 1069
    @RPTID INT
AS
--DECLARE @RPTID INT = 1167;
--SELECT * FROM dbo.RPTRunning WHERE ReportNbr='OLAP111'  ORDER BY ReportID DESC
SET NOCOUNT ON;
DECLARE @Fromdate DATE,
        @Todate DATE,
        @UserID VARCHAR(30),
        @MachineName VARCHAR(50),
        @Branch VARCHAR(MAX),
        @CurrentDate DATE,
        @UserTypes VARCHAR(30),
        @ViewMode INT;
--SELECT @Fromdate='20210501',@Todate='20210909'

SET @CurrentDate = CAST(GETDATE() AS DATE);

SELECT @Fromdate = DateParm00,
       @Todate = DateParm01,
       @UserID = UserID
FROM dbo.RPTRunning
WHERE ReportID = @RPTID;
CREATE TABLE #TBranchID
(
    BranchID VARCHAR(30)
);
SELECT @UserTypes = UserTypes
FROM dbo.Users
WHERE UserName = @UserID;

/*
ViewMode= 1 hoặc 2 : 
- ViewMode=1 hiển thị hóa đơn, phục vụ cho nhóm người dùng Audit
- ViewMode =2 hiển thị không hóa đơn, phục vụ cho nhóm người dùng kế toán, MDS

*/
IF EXISTS
(
    SELECT *
    FROM dbo.fr_SplitStringMAX(@UserTypes, ',')
    WHERE part IN ( 'ADT', 'ADTM' )
)
BEGIN
    SELECT @ViewMode = 1;
END;
ELSE
BEGIN
    SELECT @ViewMode = 2;
END;

IF @RPTID = 0
BEGIN
    SET @ViewMode = 1;
END;

SELECT *
INTO #TSlsperID
FROM dbo.fr_ListSaleByData(@UserID);

IF @MachineName = '4DSERVER'
BEGIN
    IF ISNULL(@Branch, '') = ''
    BEGIN
        SELECT @Branch = CpnyID
        FROM dbo.Users WITH (NOLOCK)
        WHERE UserName = @UserID;
    END;

    INSERT INTO #TBranchID
    (
        BranchID
    )
    SELECT part
    FROM dbo.fr_SplitStringMAX(@Branch, ',');
END;
ELSE
BEGIN
    INSERT INTO #TBranchID
    (
        BranchID
    )
    SELECT BranchID = StringParm
    FROM dbo.RPTRunningParm0 WITH (NOLOCK)
    WHERE ReportID = @RPTID;
END;


CREATE TABLE #TOrderType
(
    OrderType VARCHAR(5),
    Descr NVARCHAR(100)
);
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

/*Những đơn hủy hóa đơn trả hàng trong cùng ngày => loại ra không đưa lên báo cáo*/
SELECT co.BranchID,
       COOrDer = co.OrderNbr,
       INOrderNbr = ino.OrderNbr,
       OrigOrderNbr = ino.OrigOrderNbr
INTO #WithOutOrderNbr
FROM dbo.OM_SalesOrd co WITH (NOLOCK)
    INNER JOIN dbo.OM_SalesOrd ino WITH (NOLOCK)
        ON ino.BranchID = co.BranchID
           AND co.InvcNbr = ino.InvcNbr
           AND co.InvcNote = ino.InvcNote
           AND ino.OrderDate = co.OrderDate
    INNER JOIN #TBranchID b WITH (NOLOCK)
        ON co.BranchID = b.BranchID
WHERE co.OrderType IN ( 'CO', 'HK' )
      AND ino.OrderType IN ( 'IN', 'IO', 'EP', 'NP' )
      AND co.Status = 'C'
      AND CAST(co.OrderDate AS DATE)
      BETWEEN @Fromdate AND @Todate;
/*Những đơn hủy hóa đơn trả hàng trong khác ngày */
SELECT co.BranchID,
       ReturnDate = co.OrderDate,
       ino.OrderDate,
       COOrDer = co.OrderNbr,
       INOrderNbr = ino.OrderNbr,
       OrigOrderNbr = ino.OrigOrderNbr
INTO #ReturnOrder
FROM dbo.OM_SalesOrd co WITH (NOLOCK)
    INNER JOIN dbo.OM_SalesOrd ino WITH (NOLOCK)
        ON ino.BranchID = co.BranchID
           AND co.InvcNbr = ino.InvcNbr
           AND co.InvcNote = ino.InvcNote
           AND ino.OrderDate <> co.OrderDate
    INNER JOIN #TBranchID b WITH (NOLOCK)
        ON co.BranchID = b.BranchID
WHERE co.OrderType IN ( 'CO', 'HK' )
      AND ino.OrderType IN ( 'IN', 'IO', 'EP', 'NP' )
      AND co.Status = 'C'
      --AND CAST(co.OrderDate AS DATE)
      --BETWEEN @Fromdate AND @Todate;

/*Loại những KH có kênh phụ là CLC1 và CLC2 */
CREATE TABLE #WithOutSubChannel
(
    SubChannel VARCHAR(30)
);
INSERT INTO #WithOutSubChannel
(
    SubChannel
)
VALUES
('CLC1_CK'),
('CLC2_CK'),
('INS1_CK'),
('INS2_CK'),
('INS3_CK'),
('CHUOI_CK'),
('DLPP1_CK'),
('INS1_TM'),
('INS2_TM'),
--('INS3_TM'),
--('CHUOI_TM'),
--('DLPP1_TM'),
('DLPP2_CK'),
('DLPP3_CK');


/*---------------------------------------------------*/
/*---------------------------------Main Query----------------*/

SELECT *
INTO #TOrder
FROM
(
    /* Số đơn hàng đầu kỳ*/
    SELECT ord.BranchID,
           deb.SlsperID,
           ord.OrderNbr,
           OMOrder = sod.OrderNbr,
           DeliveryUnit = '',
           sod.CustID,
           sod.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           sod.Version,
           OrderDate = CAST(do.DocDate AS DATE),
           DateOfOrder = CAST(sod.OrderDate AS DATE),
           DeliveryTime = '',
           TermsID = do.Terms,
           DueDate = CASE
                         WHEN do.Terms = 'O1' THEN
                             DATEADD(DAY, 30, do.DocDate)
                         ELSE
                             do.DueDate
                     END,
           --CountOpeningOrder=1,
           OpeiningOrderAmt = do.OrigDocAmt,
           --CountOrdRelease = 0,
           OrdAmtRelease = 0,
           --DeliveredOrder = 0,
           DeliveredOrderAmt = 0,
           --CountReturnOrd = 0,
           ReturnOrdAmt = 0,
           ReceiveAmt = 0,
           Reason = '',
           --CountDebtConfirm = 0,
           DebConfirmAmt = 0,
           --CountDebtConfirmRelease = 0,
           DebConfirmAmtRelease = 0,
           sod.PaymentsForm
    FROM dbo.OM_PDASalesOrd ord WITH (NOLOCK)
        INNER JOIN #TOrderType ot WITH (NOLOCK)
            ON ot.OrderType = ord.OrderType
        INNER JOIN dbo.OM_SalesOrd sod WITH (NOLOCK)
            ON sod.BranchID = ord.BranchID
               AND sod.OrigOrderNbr = ord.OrderNbr
        INNER JOIN dbo.OM_DebtAllocateDet deb
            ON deb.BranchID = ord.BranchID
               AND deb.OrderNbr = ord.OrderNbr
               AND sod.ARBatNbr = deb.ARBatNbr
        INNER JOIN dbo.AR_Doc do
            ON sod.BranchID = do.BranchID
               AND sod.ARBatNbr = do.BatNbr
               AND sod.ARRefNbr = do.RefNbr
        INNER JOIN Batch b WITH (NOLOCK)
            ON do.BranchID = b.BranchID
               AND do.BatNbr = b.BatNbr
               AND b.Module = 'AR'
        LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK)
            ON woo.BranchID = ord.BranchID
               AND woo.OrigOrderNbr = ord.OrderNbr
        LEFT JOIN #TSlsperID ts WITH (NOLOCK)
            ON ts.BranchID = deb.BranchID
               AND ts.SlsperID = deb.SlsperID
    WHERE CAST(do.DocDate AS DATE)
          BETWEEN @Fromdate AND @Todate
          AND sod.Status = 'C'
          AND woo.OrigOrderNbr IS NULL
          AND CAST(sod.OrderDate AS DATE) < '20210501'
    UNION ALL
    --/*Số đơn hàng chốt sổ*/
    SELECT d.BranchID,
           i.SlsperID,
           d.OrderNbr,
           OMOrder = sod.OrderNbr,
           DeliveryUnit = ISNULL(i.DeliveryUnit, ''),
           sod.CustID,
           sod.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           sod.Version,
           OrderDate = IIF(CAST(i.IssueDate AS DATE) < CAST(sod.OrderDate AS DATE),
                           CAST(sod.OrderDate AS DATE),
                           CAST(i.IssueDate AS DATE)),
           DateOfOrder = CAST(sod.OrderDate AS DATE),
           DeliveryTime = '',
           TermsID = do.Terms,
           DueDate = CASE
                         WHEN do.Terms = 'O1' THEN
                             DATEADD(DAY, 30, do.DocDate)
                         ELSE
                             do.DueDate
                     END, --dbo.fr_GetDueDateOverLapping(sod.BranchID,sod.OrderNbr,@UserID),
                          --CountOpeningOrder=0,
           OpeiningOrderAmt = 0,
                          --CountOrdRelease = 1,
           OrdAmtRelease = do.OrigDocAmt,
                          --DeliveredOrder = 0,
           DeliveredOrderAmt = 0,
                          --CountReturnOrd = 0,
           ReturnOrdAmt = 0,
           ReceiveAmt = 0,
           Reason = '',
                          --CountDebtConfirm = 0,
           DebConfirmAmt = 0,
                          --CountDebtConfirmRelease = 0,
           DebConfirmAmtRelease = 0,
           sod.PaymentsForm
    FROM dbo.OM_IssueBook i WITH (NOLOCK)
        INNER JOIN dbo.OM_IssueBookDet d WITH (NOLOCK)
            ON d.BatNbr = i.BatNbr
               AND d.BranchID = i.BranchID
        INNER JOIN dbo.OM_PDASalesOrd ord WITH (NOLOCK)
            ON ord.BranchID = d.BranchID
               AND ord.OrderNbr = d.OrderNbr
        INNER JOIN dbo.OM_SalesOrd sod WITH (NOLOCK)
            ON sod.BranchID = ord.BranchID
               AND sod.OrigOrderNbr = ord.OrderNbr
        INNER JOIN #TOrderType ot WITH (NOLOCK)
            ON ot.OrderType = ord.OrderType
        INNER JOIN dbo.OM_DebtAllocateDet deb WITH (NOLOCK)
            ON deb.BranchID = d.BranchID
               AND deb.OrderNbr = d.OrderNbr
               AND sod.ARBatNbr = deb.ARBatNbr
        INNER JOIN dbo.AR_Doc do WITH (NOLOCK)
            ON sod.BranchID = do.BranchID
               AND sod.ARBatNbr = do.BatNbr
               AND sod.ARRefNbr = do.RefNbr
        INNER JOIN Batch b WITH (NOLOCK)
            ON do.BranchID = b.BranchID
               AND do.BatNbr = b.BatNbr
               AND b.Module = 'AR'
        INNER JOIN #TBranchID br WITH (NOLOCK)
            ON i.BranchID = br.BranchID
        LEFT JOIN #TSlsperID ts WITH (NOLOCK)
            ON ts.BranchID = i.BranchID
               AND ts.SlsperID = i.SlsperID
        LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK)
            ON woo.BranchID = ord.BranchID
               AND woo.OrigOrderNbr = ord.OrderNbr
    WHERE CAST(i.IssueDate AS DATE)
          BETWEEN @Fromdate AND @Todate
          AND i.Status = 'C'
          AND sod.Status = 'C'
          AND woo.OrigOrderNbr IS NULL
    UNION ALL
    --/*Số đơn hàng giao thành công*/
    SELECT b.BranchID,
           b.SlsperID,
           d.OrderNbr,
           OMOrder = sod.OrderNbr,
           DeliveryUnit = ISNULL(b.DeliveryUnit, ''),
           sod.CustID,
           sod.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           sod.Version,
           OrderDate = CAST(dl.LUpd_DateTime AS DATE),
           DateOfOrder = CAST(sod.OrderDate AS DATE),
           DeliveryTime = CAST((DATEDIFF(MINUTE, dl.Crtd_DateTime, dl.LUpd_DateTime)
                                - DATEDIFF(MINUTE, dl.Crtd_DateTime, dl.LUpd_DateTime) % 60
                               ) / 60 AS VARCHAR(8)) + ':'
                          + RIGHT('0' + CAST(DATEDIFF(MINUTE, dl.Crtd_DateTime, dl.LUpd_DateTime) % 60 AS VARCHAR(2)), 2),
           TermsID = do.Terms,
           DueDate = CASE
                         WHEN do.Terms = 'O1' THEN
                             DATEADD(DAY, 30, do.DocDate)
                         ELSE
                             do.DueDate
                     END,
           --CountOpeningOrder=0,
           OpeiningOrderAmt = 0,
           --CountOrdRelease = 0,
           OrdAmtRelease = 0,
           --CountDelivered = 1,
           DeliveredOrderAmt = do.OrigDocAmt,
           --CountReturnOrd = 0,
           ReturnOrdAmt = 0,
           ReceiveAmt = 0,
           Reason = '',
           --CountDebtConfirm = 0,
           DebConfirmAmt = 0,
           --CountDebtConfirmRelease = 0,
           DebConfirmAmtRelease = 0,
           sod.PaymentsForm
    FROM dbo.OM_IssueBook b WITH (NOLOCK)
        INNER JOIN dbo.OM_IssueBookDet d WITH (NOLOCK)
            ON d.BranchID = b.BranchID
               AND d.BatNbr = b.BatNbr
        INNER JOIN dbo.OM_PDASalesOrd o WITH (NOLOCK)
            ON o.BranchID = b.BranchID
               AND o.OrderNbr = d.OrderNbr
        INNER JOIN dbo.OM_SalesOrd sod WITH (NOLOCK)
            ON sod.BranchID = o.BranchID
               AND sod.OrigOrderNbr = o.OrderNbr
        INNER JOIN #TOrderType ot WITH (NOLOCK)
            ON ot.OrderType = o.OrderType
        INNER JOIN dbo.OM_Delivery dl WITH (NOLOCK)
            ON dl.BranchID = d.BranchID
               AND dl.OrderNbr = d.OrderNbr
               AND dl.Status = 'C'
        INNER JOIN dbo.OM_DebtAllocateDet deb WITH (NOLOCK)
            ON deb.BranchID = dl.BranchID
               AND deb.OrderNbr = dl.OrderNbr
               AND deb.ARBatNbr = sod.ARBatNbr
               AND dl.Status = 'C'
        INNER JOIN dbo.AR_Doc do WITH (NOLOCK)
            ON sod.BranchID = do.BranchID
               AND sod.ARBatNbr = do.BatNbr
               AND sod.ARRefNbr = do.RefNbr
        INNER JOIN Batch ba WITH (NOLOCK)
            ON do.BranchID = ba.BranchID
               AND do.BatNbr = ba.BatNbr
               AND ba.Module = 'AR'
        INNER JOIN #TBranchID br WITH (NOLOCK)
            ON b.BranchID = br.BranchID
        LEFT JOIN #TSlsperID ts WITH (NOLOCK)
            ON ts.BranchID = b.BranchID
               AND ts.SlsperID = b.SlsperID
        LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK)
            ON woo.BranchID = o.BranchID
               AND woo.OrigOrderNbr = o.OrderNbr
        LEFT JOIN #ReturnOrder rod WITH (NOLOCK)
            ON rod.BranchID = o.BranchID
               AND rod.OrigOrderNbr = o.OrderNbr
    WHERE b.Status = 'C'
          AND CAST(dl.LUpd_DateTime AS DATE)
          BETWEEN @Fromdate AND @Todate
          AND sod.Status = 'C'
          AND woo.OrigOrderNbr IS NULL
          AND rod.OrigOrderNbr IS NULL
    UNION ALL
    /*Số đơn đơn hàng không thu tiền được*/
    SELECT b.BranchID,
           b.SlsperID,
           d.OrderNbr,
           OMOrder = sod.OrderNbr,
           DeliveryUnit = ISNULL(b.DeliveryUnit, ''),
           sod.CustID,
           sod.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           sod.Version,
           OrderDate = CAST(dbc.CreateDate AS DATE),
           DateOfOrder = CAST(sod.OrderDate AS DATE),
           DeliveryTime = '',
           TermsID = do.Terms,
           DueDate = CASE
                         WHEN do.Terms = 'O1' THEN
                             DATEADD(DAY, 30, do.DocDate)
                         ELSE
                             do.DueDate
                     END,
           --CountOpeningOrder=0,
           OpeiningOrderAmt = 0,
           --CountOrdRelease = 0,
           OrdAmtRelease = 0,
           --CountDelivered = 0,
           DeliveredOrderAmt = 0,
           --CountReturnOrd = 0,
           ReturnOrdAmt = 0,
           ReceiveAmt = dbc.ReceiveAmt,
           Reason = ISNULL(ors.Descr, ''),
           --CountDebtConfirm = 0,
           DebConfirmAmt = 0,
           --CountDebtConfirmRelease = 0,
           DebConfirmAmtRelease = 0,
           sod.PaymentsForm
    FROM dbo.OM_IssueBook b WITH (NOLOCK)
        INNER JOIN dbo.OM_IssueBookDet d WITH (NOLOCK)
            ON d.BranchID = b.BranchID
               AND d.BatNbr = b.BatNbr
        INNER JOIN dbo.OM_PDASalesOrd o WITH (NOLOCK)
            ON o.BranchID = b.BranchID
               AND o.OrderNbr = d.OrderNbr
	    LEFT JOIN #ReturnOrder rod WITH (NOLOCK)
            ON rod.BranchID = o.BranchID
               AND rod.OrigOrderNbr = o.OrderNbr
        INNER JOIN #TOrderType ot WITH (NOLOCK)
            ON ot.OrderType = o.OrderType
        INNER JOIN dbo.OM_Delivery dl WITH (NOLOCK)
            ON dl.BranchID = d.BranchID
               AND dl.OrderNbr = d.OrderNbr
               AND dl.Status = 'C'
        INNER JOIN dbo.OM_SalesOrd sod WITH (NOLOCK)
            ON sod.BranchID = o.BranchID
               AND sod.OrigOrderNbr = o.OrderNbr
        INNER JOIN dbo.OM_DebtAllocateDet deb WITH (NOLOCK)
            ON deb.BranchID = dl.BranchID
               AND deb.OrderNbr = dl.OrderNbr
               AND dl.Status = 'C'
               AND sod.ARBatNbr = deb.ARBatNbr
        INNER JOIN dbo.AR_Doc do WITH (NOLOCK)
            ON sod.BranchID = do.BranchID
               AND sod.ARBatNbr = do.BatNbr
               AND sod.ARRefNbr = do.RefNbr
        INNER JOIN Batch ba WITH (NOLOCK)
            ON do.BranchID = ba.BranchID
               AND do.BatNbr = ba.BatNbr
               AND ba.Module = 'AR'
        INNER JOIN dbo.PPC_DebtConfirm dbc WITH (NOLOCK)
            ON dbc.InvcNbr = do.InvcNbr
               AND dbc.InvcNote = do.InvcNote
               AND dbc.BranchID = do.BranchID
               AND dbc.DocBatNbr = do.BatNbr
               AND dbc.DocRefNbr = do.RefNbr
        LEFT JOIN OM_ReasonCodePPC ors WITH (NOLOCK)
            ON dbc.Reason = ors.Code
               AND ors.Type = 'DEBTNOTPAY'
        INNER JOIN #TBranchID br WITH (NOLOCK)
            ON b.BranchID = br.BranchID
        LEFT JOIN #TSlsperID ts WITH (NOLOCK)
            ON ts.BranchID = b.BranchID
               AND ts.SlsperID = b.SlsperID
        LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK)
            ON woo.BranchID = o.BranchID
               AND woo.OrigOrderNbr = o.OrderNbr
    WHERE b.Status = 'C'
          AND CAST(dbc.CreateDate AS DATE)
          BETWEEN @Fromdate AND @Todate
          AND sod.Status = 'C'
          AND woo.OrigOrderNbr IS NULL
		  AND rod.OrigOrderNbr IS NULL
    UNION ALL
    --    /* Thông tin hủy hóa đơn - trả hàng*/
    SELECT d.BranchID,
           SlsperID = ISNULL(ib.SlsperID, deb.SlsperID),
           OrderNbr = d.OrigOrderNbr,
           OMOrder = sod.OrderNbr,
           DeliveryUnit = ISNULL(ib.DeliveryUnit, ''),
           sod.CustID,
           sod.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           sod.Version,
           OrderDate = CAST(d.ReturnDate AS DATE),
           DateOfOrder = CAST(sod.OrderDate AS DATE),
           DeliveryTime = '',
           TermsID = do.Terms,
           DueDate = CASE
                         WHEN do.Terms = 'O1' THEN
                             DATEADD(DAY, 30, do.DocDate)
                         ELSE
                             do.DueDate
                     END,
           --CountOpeningOrder=0,
           OpeiningOrderAmt = 0,
           --CountOrdRelease = 0,
           OrdAmtRelease = 0,
           --DeliveredOrder = 0,
           DeliveredOrderAmt = 0,
           --CountReturnOrd = 1,
           ReturnOrdAmt = do.OrigDocAmt,
           ReceiveAmt = 0,
           Reason = '',
           --CountDebtConfirm = 0,
           DebConfirmAmt = 0,
           --CountDebtConfirmRelease = 0,
           DebConfirmAmtRelease = 0,
           sod.PaymentsForm
    FROM #ReturnOrder d WITH (NOLOCK)
        INNER JOIN dbo.OM_PDASalesOrd ord WITH (NOLOCK)
            ON ord.BranchID = d.BranchID
               AND ord.OrderNbr = d.OrigOrderNbr
        INNER JOIN dbo.OM_SalesOrd sod WITH (NOLOCK)
            ON sod.BranchID = ord.BranchID
               AND sod.OrigOrderNbr = ord.OrderNbr
               AND sod.OrderNbr = d.INOrderNbr
        INNER JOIN #TOrderType ot WITH (NOLOCK)
            ON ot.OrderType = ord.OrderType
        INNER JOIN dbo.OM_DebtAllocateDet deb WITH (NOLOCK)
            ON deb.BranchID = d.BranchID
               AND deb.OrderNbr = d.OrigOrderNbr
               AND deb.ARBatNbr = sod.ARBatNbr
        LEFT JOIN dbo.OM_IssueBookDet bd WITH (NOLOCK)
            ON bd.BranchID = deb.BranchID
               AND bd.OrderNbr = deb.OrderNbr
        LEFT JOIN dbo.OM_IssueBook ib WITH (NOLOCK)
            ON ib.BranchID = bd.BranchID
               AND ib.BatNbr = bd.BatNbr
        INNER JOIN dbo.AR_Doc do WITH (NOLOCK)
            ON sod.BranchID = do.BranchID
               AND sod.ARBatNbr = do.BatNbr
               AND sod.ARRefNbr = do.RefNbr
        INNER JOIN Batch b WITH (NOLOCK)
            ON do.BranchID = b.BranchID
               AND do.BatNbr = b.BatNbr
               AND b.Module = 'AR'
        INNER JOIN #TBranchID br WITH (NOLOCK)
            ON d.BranchID = br.BranchID
        LEFT JOIN #TSlsperID ts WITH (NOLOCK)
            ON ts.BranchID = deb.BranchID
               AND ts.SlsperID = deb.SlsperID
        LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK)
            ON woo.BranchID = ord.BranchID
               AND woo.OrigOrderNbr = ord.OrderNbr
    WHERE CAST(d.ReturnDate AS DATE)
          BETWEEN @Fromdate AND @Todate
          AND sod.Status = 'C'
          AND woo.OrigOrderNbr IS NULL
    UNION ALL
    --/* Thông tin số đơn hàng lên bảng kê, chưa xác nhận*/
    SELECT a.BranchID,
           SlsperID = ISNULL(ib.SlsperID, deb.SlsperID),
           deb.OrderNbr,
           OMOrder = ord.OrderNbr,
           DeliveryUnit = ISNULL(ib.DeliveryUnit, ''),
           ord.CustID,
           ord.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           ord.Version,
           OrderDate = CAST(a.Crtd_DateTime AS DATE),
           DateOfOrder = CAST(ord.OrderDate AS DATE),
           DeliveryTime = '',
           TermsID = do.Terms,
           DueDate = CASE
                         WHEN do.Terms = 'O1' THEN
                             DATEADD(DAY, 30, do.DocDate)
                         ELSE
                             do.DueDate
                     END,
           --CountOpeningOrder=0,
           OpeiningOrderAmt = 0,
           --CountOrdRelease = 0,
           OrdAmtRelease = 0,
           --CountDelivered = 0,
           DeliveredOrderAmt = 0,
           --CountReturnOrd = 0,
           ReturnOrdAmt = 0,
           ReceiveAmt = 0,
           Reason = '',
           --CountDebtConfirm = 1,
           DebConfirmAmt = CASE
                               WHEN aDetail.AccountID IS NOT NULL
                                    AND aDetail.AccountID = '711' THEN
                                   0
                               ELSE
                                   ISNULL(aDetail.Amt, a.AdjAmt)
                           END,
           --CountDebtConfirmRelease = 0,
           DebConfirmAmtRelease = 0,
           ord.PaymentsForm
    --SELECT *
    FROM OM_SalesOrd ord
        INNER JOIN dbo.OM_DebtAllocateDet deb WITH (NOLOCK)
            ON deb.BranchID = ord.BranchID
               AND deb.OrderNbr = ord.OrigOrderNbr
               AND deb.ARBatNbr = ord.ARBatNbr
        LEFT JOIN dbo.OM_IssueBookDet bd WITH (NOLOCK)
            ON bd.BranchID = deb.BranchID
               AND bd.OrderNbr = deb.OrderNbr
        LEFT JOIN dbo.OM_IssueBook ib WITH (NOLOCK)
            ON ib.BranchID = bd.BranchID
               AND ib.BatNbr = bd.BatNbr
        LEFT JOIN #ReturnOrder rto WITH (NOLOCK)
            ON rto.BranchID = ord.BranchID
               AND rto.INOrderNbr = ord.OrderNbr
        INNER JOIN dbo.AR_Doc do WITH (NOLOCK)
            ON ord.BranchID = do.BranchID
               AND ord.ARBatNbr = do.BatNbr
               AND ord.ARRefNbr = do.RefNbr
        INNER JOIN dbo.AR_Adjust a WITH (NOLOCK)
            ON a.AdjdBatNbr = ord.ARBatNbr
               AND a.AdjdRefNbr = ord.ARRefNbr
               AND a.BranchID = ord.BranchID
               AND ISNULL(a.Reversal, '') = ''
        LEFT JOIN dbo.AR_AdjustDetail aDetail WITH (NOLOCK)
            ON aDetail.BranchID = a.BranchID
               AND aDetail.BatNbr = a.BatNbr
               AND aDetail.AdjgBatNbr = a.AdjgBatNbr
               AND aDetail.AdjgRefNbr = a.AdjgRefNbr
               AND aDetail.AdjdBatNbr = a.AdjdBatNbr
               AND aDetail.AdjdRefNbr = a.AdjdRefNbr
        INNER JOIN AR_Doc b WITH (NOLOCK)
            ON b.BranchID = a.BranchID
               AND b.BatNbr = a.AdjgBatNbr
               AND b.RefNbr = a.AdjgRefNbr
        INNER JOIN dbo.Batch ba WITH (NOLOCK)
            ON a.BranchID = ba.BranchID
               AND a.BatNbr = ba.BatNbr
               AND ba.Module = 'AR'
        INNER JOIN Batch bac WITH (NOLOCK)
            ON do.BranchID = bac.BranchID
               AND do.BatNbr = bac.BatNbr
               AND bac.Module = 'AR'
        --  --INNER JOIN dbo.OM_PDASalesOrd sod WITH (NOLOCK)
        --  --    ON sod.BranchID = deb.BranchID
        --  --       AND sod.OrderNbr = deb.OrderNbr
        INNER JOIN #TOrderType ot WITH (NOLOCK)
            ON ot.OrderType = ord.OrderType
        INNER JOIN #TBranchID br WITH (NOLOCK)
            ON deb.BranchID = br.BranchID
        LEFT JOIN #TSlsperID ts WITH (NOLOCK)
            ON ts.BranchID = deb.BranchID
               AND ts.SlsperID = deb.SlsperID
        LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK)
            ON woo.BranchID = ord.BranchID
               AND woo.OrigOrderNbr = ord.OrigOrderNbr
    WHERE CAST(a.Crtd_DateTime AS DATE)
          BETWEEN @Fromdate AND @Todate
          AND ord.Status = 'C'
          AND ba.Status <> 'V'
          AND woo.OrigOrderNbr IS NULL
          AND rto.INOrderNbr IS NULL
    UNION ALL
    /* Thông tin số đơn hàng lên bảng kê, ĐÃ xác nhận*/
    SELECT a.BranchID,
           SlsperID = ISNULL(ib.SlsperID, deb.SlsperID),
           sod.OrderNbr,
           OMOrder = ord.OrderNbr,
           DeliveryUnit = ISNULL(ib.DeliveryUnit, ''),
           ord.CustID,
           ord.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           ord.Version,
           OrderDate = CAST(a.AdjgDocDate AS DATE),
           DateOfOrder = CAST(ord.OrderDate AS DATE),
           DeliveryTime = '',
           TermsID = do.Terms,
           DueDate = CASE
                         WHEN do.Terms = 'O1' THEN
                             DATEADD(DAY, 30, do.DocDate)
                         ELSE
                             do.DueDate
                     END,
           --CountOpeningOrder=0,
           OpeiningOrderAmt = 0,
           --CountOrdRelease = 0,
           OrdAmtRelease = 0,
           --CountDelivered = 0,
           DeliveredOrderAmt = 0,
           --CountReturnOrd = 0,
           ReturnOrdAmt = 0,
           ReceiveAmt = 0,
           Reason = '',
           --CountDebtConfirm = 0,
           DebConfirmAmt = 0,
           --CountDebtConfirmRelease = 1,
           DebConfirmAmt = CASE
                               WHEN aDetail.AccountID IS NOT NULL
                                    AND aDetail.AccountID = '711' THEN
                                   0
                               ELSE
                                   ISNULL(aDetail.Amt, a.AdjAmt)
                           END,
           ord.PaymentsForm
    FROM OM_SalesOrd ord
        INNER JOIN dbo.OM_DebtAllocateDet deb WITH (NOLOCK)
            ON deb.BranchID = ord.BranchID
               AND deb.OrderNbr = ord.OrigOrderNbr
               AND deb.ARBatNbr = ord.ARBatNbr
        LEFT JOIN dbo.OM_IssueBookDet bd WITH (NOLOCK)
            ON bd.BranchID = deb.BranchID
               AND bd.OrderNbr = deb.OrderNbr
        LEFT JOIN dbo.OM_IssueBook ib WITH (NOLOCK)
            ON ib.BranchID = bd.BranchID
               AND ib.BatNbr = bd.BatNbr
        LEFT JOIN #ReturnOrder rto WITH (NOLOCK)
            ON rto.BranchID = ord.BranchID
               AND rto.INOrderNbr = ord.OrderNbr
        INNER JOIN dbo.AR_Doc do WITH (NOLOCK)
            ON ord.BranchID = do.BranchID
               AND ord.ARBatNbr = do.BatNbr
               AND ord.ARRefNbr = do.RefNbr
        INNER JOIN dbo.AR_Adjust a WITH (NOLOCK)
            ON a.AdjdBatNbr = ord.ARBatNbr
               AND a.AdjdRefNbr = ord.ARRefNbr
               AND a.BranchID = ord.BranchID
               AND ISNULL(a.Reversal, '') = ''
        LEFT JOIN dbo.AR_AdjustDetail aDetail WITH (NOLOCK)
            ON aDetail.BranchID = a.BranchID
               AND aDetail.BatNbr = a.BatNbr
               AND aDetail.AdjgBatNbr = a.AdjgBatNbr
               AND aDetail.AdjgRefNbr = a.AdjgRefNbr
               AND aDetail.AdjdBatNbr = a.AdjdBatNbr
               AND aDetail.AdjdRefNbr = a.AdjdRefNbr
        INNER JOIN AR_Doc b WITH (NOLOCK)
            ON b.BranchID = a.BranchID
               AND b.BatNbr = a.AdjgBatNbr
               AND b.RefNbr = a.AdjgRefNbr
        INNER JOIN dbo.Batch ba WITH (NOLOCK)
            ON a.BranchID = ba.BranchID
               AND a.BatNbr = ba.BatNbr
               AND ba.Module = 'AR'
        INNER JOIN dbo.OM_PDASalesOrd sod WITH (NOLOCK)
            ON sod.BranchID = deb.BranchID
               AND sod.OrderNbr = deb.OrderNbr
        INNER JOIN Batch bac WITH (NOLOCK)
            ON do.BranchID = bac.BranchID
               AND do.BatNbr = bac.BatNbr
               AND bac.Module = 'AR'
        INNER JOIN #TOrderType ot WITH (NOLOCK)
            ON ot.OrderType = sod.OrderType
        INNER JOIN #TBranchID br WITH (NOLOCK)
            ON deb.BranchID = br.BranchID
        LEFT JOIN #TSlsperID ts WITH (NOLOCK)
            ON ts.BranchID = deb.BranchID
               AND ts.SlsperID = deb.SlsperID
        LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK)
            ON woo.BranchID = sod.BranchID
               AND woo.OrigOrderNbr = sod.OrderNbr
    WHERE CAST(a.AdjgDocDate AS DATE)
          BETWEEN @Fromdate AND @Todate
          AND ba.Status = 'C'
          AND ord.Status = 'C'
          AND woo.OrigOrderNbr IS NULL
          AND rto.INOrderNbr IS NULL
) K;


SELECT DISTINCT
       od.BranchID,
       od.OrderNbr,
       od.OMOrder,
       PaymentsForm = CASE
                          WHEN od.PaymentsForm IN ( 'B', 'C' ) THEN
                              'TM'
                          ELSE
                              'CK'
                      END,
       --Terms = CASE
       --            WHEN cl.Terms = '' THEN
       --                c.Terms
       --            ELSE
       --                ISNULL(cl.Terms, c.Terms)
       --        END,
       Terms = od.TermsID,
       CustName = CASE
                      WHEN cl.CustName = '' THEN
                          c.CustName
                      ELSE
                          ISNULL(cl.CustName, c.CustName)
                  END,
       Channel = CASE
                     WHEN cl.Channel = '' THEN
                         c.Channel
                     ELSE
                         ISNULL(cl.Channel, c.Channel)
                 END,
       ShopType = CASE
                      WHEN cl.ShopType = '' THEN
                          c.ShopType
                      ELSE
                          ISNULL(cl.ShopType, c.ShopType)
                  END,
       Territory = CASE
                       WHEN cl.Territory = '' THEN
                           c.Territory
                       ELSE
                           ISNULL(cl.Territory, c.Territory)
                   END,
       StreetName = CASE
                        WHEN cl.Addr1 = '' THEN
                            c.Addr1
                        ELSE
                            ISNULL(cl.Addr1, c.Addr1)
                    END,
       Ward = CASE
                  WHEN cl.Ward = '' THEN
                      c.Ward
                  ELSE
                      ISNULL(cl.Ward, c.Ward)
              END,
       District = CASE
                      WHEN cl.District = '' THEN
                          c.District
                      ELSE
                          ISNULL(cl.District, c.District)
                  END,
       State = CASE
                   WHEN cl.State = '' THEN
                       c.State
                   ELSE
                       ISNULL(cl.State, c.State)
               END,
       attn = CASE
                  WHEN cl.Attn = '' THEN
                      c.Attn
                  ELSE
                      ISNULL(cl.Attn, c.Attn)
              END,
       Phone = CASE
                   WHEN cl.Phone = '' THEN
                       c.Phone
                   ELSE
                       ISNULL(cl.Phone, c.Phone)
               END,
       PhoneCustInvc = aci.Phone
INTO #TCustomer
FROM #TOrder od WITH (NOLOCK)
    INNER JOIN dbo.AR_Customer c
        ON c.CustId = od.CustID
    LEFT JOIN dbo.AR_CustomerInvoice aci WITH (NOLOCK)
        ON aci.CustIDInvoice = od.InvoiceCustID
    LEFT JOIN dbo.AR_HistoryCustClassID cl
        ON cl.Version = od.Version;

IF (@ViewMode = 1) -- Có hiển thị số hóa đơn
BEGIN
    SELECT [Mã Chi Nhánh/Cty] = o.BranchID,
           [Tên Chi Nhánh/Cty] = syc.CpnyName,
           [Quản Lý MDS] = uu.FirstName,
           [Mã Nhân Viên] = o.SlsperID,
           [Tên Nhân Viên] = u.FirstName,
           [Vai Trò] = CASE
                           WHEN u.UserTypes LIKE '%LOG%' THEN
                               'LOG'
                           WHEN u.Position IN ( 'D', 'SD', 'AD', 'RD' )
                                AND u.UserTypes NOT LIKE '%LOG%' THEN
                               'MDS'
                           WHEN u.UserTypes LIKE '%CS%' THEN
                               'CS'
                           WHEN u.Position IN ( 'S', 'SS', 'AM', 'RM' ) THEN
                               'P.BH'
                           ELSE
                               u.Position
                       END,
           [Hình Thức Thanh Toán] = tc.PaymentsForm,
           [Hạn Thanh Toán] = CASE
                                  WHEN st.DueType = 'D'
                                       AND st.DueIntrv IN ( '1', '3' ) THEN
                                      N'Thanh Toán Ngay'
                                  ELSE
                                      N'Cho nợ'
                              END,
           [Ngày Nghiệp Vụ] = CONVERT(VARCHAR(20), o.OrderDate, 103),
           [Mã Đơn Hàng] = o.OrderNbr,
           [Số Hóa Đơn] = o.InvcNbr,
           [Ký Hiệu Hóa Đơn] = o.InvcNote,
           [Ngày Đơn Hàng] = CONVERT(VARCHAR(20), o.DateOfOrder, 103),
           [Ngày Đơn Hàng] = CONVERT(VARCHAR(20), o.DateOfOrder, 103),
           [Tháng] = RIGHT('0' + CAST(MONTH(o.DateOfOrder) AS VARCHAR(2)), 2),
           [Năm] = YEAR(o.DateOfOrder),
           [Đơn Vị Giao Hàng] = ISNULL(atr.Descr, ''),
           [Thời Gian Giao Hàng (HH:MM)] = MAX(o.DeliveryTime),
           [Thời Hạn Thanh Toán] = ISNULL(stt.Descr, o.TermsID),
           [Ngày Đến Hạn] = CONVERT(VARCHAR(20), o.DueDate, 103),                 --CASE WHEN o.TermsID='O1' THEN dbo.fr_GetDueDateOverLapping(o.BranchID,o.OMOrder,@UserID) ELSE o.DueDate end,
           [Mã Khách Hàng] = o.CustID,
           [Tên Khách Hàng] = tc.CustName,
           [Mã Kênh] = tc.Channel,
           [Mã Kênh Phụ] = tc.ShopType,
           [Khu Vực] = ste.Descr,
           [Số Nhà Và Tên Đường] = StreetName,
           [Phường/Xã] = sw.Name,
           [Quận/Huyện] = sd.Name,
           [Tỉnh/Thành] = sta.Descr,
           [Người Liên Hệ] = tc.attn,
           [Số Điện Thoại] = tc.Phone,
           [Số Điện Thoại (KH Thuế)] = tc.PhoneCustInvc,
           [Đầu Kỳ (ĐH)] = IIF(SUM(OpeiningOrderAmt) > 0, 1, 0),                  --CountOpeningOrder),
           [Đầu Kỳ (Số Tiền)] = SUM(OpeiningOrderAmt) * 1,
           [Chốt Sổ (ĐH)] = IIF(SUM(OrdAmtRelease) > 0, 1, 0),                    --SUM(CountOrdRelease),
           [Chốt sổ (Số Tiền)] = SUM(OrdAmtRelease),
           [Giao Thành Công (ĐH)] = IIF(SUM(DeliveredOrderAmt) > 0, 1, 0),        -- SUM(DeliveredOrder),
           [Giao Thành Công (Số Tiền)] = SUM(DeliveredOrderAmt),
           [Hủy Hóa Đơn - Trả Hàng (ĐH)] = IIF(SUM(o.ReturnOrdAmt) > 0, 1, 0),    -- SUM(K.CountReturnOrd),
           [Hủy Hóa Đơn - Trả Hàng (Số Tiền)] = SUM(o.ReturnOrdAmt),
           [Xác Nhận Thu Nợ (Số Tiền)] = SUM(o.ReceiveAmt),
           [Lý Do Không Thu Nợ Được] = MAX(o.Reason),
           [Tạo Bảng Kê (ĐH)] = IIF(SUM(DebConfirmAmt) > 0, 1, 0),                -- SUM(CountDebtConfirm),
           [Tạo Bảng Kê (Số Tiền)] = SUM(DebConfirmAmt),
           [Xác Nhận TT Công Nợ (ĐH)] = IIF(SUM(DebConfirmAmtRelease) > 0, 1, 0), -- SUM(CountDebtConfirmRelease),
           [Xác Nhận TT Công Nợ (Số Tiền)] = SUM(DebConfirmAmtRelease),
           [Dư Nợ Cuối Kỳ] = SUM(OpeiningOrderAmt) + SUM(OrdAmtRelease) - SUM(o.ReturnOrdAmt)
                             - SUM(DebConfirmAmtRelease)
    FROM #TOrder o
        INNER JOIN #TCustomer tc
            ON tc.BranchID = o.BranchID
               AND tc.OrderNbr = o.OrderNbr
               AND tc.OMOrder = o.OMOrder
        INNER JOIN dbo.Users u WITH (NOLOCK)
            ON u.UserName = o.SlsperID
        INNER JOIN dbo.SYS_Company syc WITH (NOLOCK)
            ON o.BranchID = syc.CpnyID
        LEFT JOIN dbo.AR_Transporter atr WITH (NOLOCK)
            ON o.DeliveryUnit = atr.Code
        LEFT JOIN #TSlsperID ts WITH (NOLOCK)
            ON ts.SlsperID = o.SlsperID
               AND ts.BranchID = o.BranchID
        LEFT JOIN dbo.Users uu WITH (NOLOCK)
            ON uu.UserName = ts.SupID
        LEFT JOIN dbo.SI_Terms st WITH (NOLOCK)
            ON st.TermsID = tc.Terms
        LEFT JOIN dbo.SI_Terms stt WITH (NOLOCK)
            ON stt.TermsID = o.TermsID
        INNER JOIN dbo.SI_Territory ste WITH (NOLOCK)
            ON ste.Territory = tc.Territory
        INNER JOIN dbo.SI_State sta WITH (NOLOCK)
            ON sta.State = tc.State
        INNER JOIN dbo.SI_District sd WITH (NOLOCK)
            ON sd.District = tc.District
               AND sd.State = tc.State
        LEFT JOIN dbo.SI_Ward sw WITH (NOLOCK)
            ON sw.Ward = tc.Ward
               AND sw.State = tc.State
               AND sw.District = tc.District
    WHERE tc.ShopType + '_' + tc.PaymentsForm NOT IN (
                                                         SELECT SubChannel FROM #WithOutSubChannel
                                                     )
    GROUP BY CASE
                 WHEN u.UserTypes LIKE '%LOG%' THEN
                     'LOG'
                 WHEN u.Position IN ( 'D', 'SD', 'AD', 'RD' )
                      AND u.UserTypes NOT LIKE '%LOG%' THEN
                     'MDS'
                 WHEN u.UserTypes LIKE '%CS%' THEN
                     'CS'
                 WHEN u.Position IN ( 'S', 'SS', 'AM', 'RM' ) THEN
                     'P.BH'
                 ELSE
                     u.Position
             END,
             CASE
                 WHEN st.DueType = 'D'
                      AND st.DueIntrv IN ( '1', '3' ) THEN
                     N'Thanh Toán Ngay'
                 ELSE
                     N'Cho nợ'
             END,
             syc.CpnyName,
             uu.FirstName,
             u.FirstName,
             ISNULL(stt.Descr, o.TermsID),
             ste.Descr,
             tc.StreetName,
             sw.Name,
             sd.Name,
             sta.Descr,
             o.BranchID,
             o.SlsperID,
             tc.PaymentsForm,
             CONVERT(VARCHAR(20), o.OrderDate, 103),
             o.OrderNbr,
             o.InvcNbr,
             o.InvcNote,
             CONVERT(VARCHAR(20), o.DateOfOrder, 103),
             CONVERT(VARCHAR(20), o.DueDate, 103),
             o.CustID,
             tc.CustName,
             tc.Channel,
             tc.ShopType,
             tc.attn,
             tc.Phone,
             PhoneCustInvc,
             ISNULL(atr.Descr, ''),
             RIGHT('0' + CAST(MONTH(o.DateOfOrder) AS VARCHAR(2)), 2),
             YEAR(o.DateOfOrder)
    --CASE WHEN o.TermsID='O1' THEN dbo.fr_GetDueDateOverLapping(o.BranchID,o.OMOrder,@UserID) ELSE o.DueDate end
    ORDER BY o.BranchID,
             o.SlsperID,
             o.OrderNbr,
             CONVERT(VARCHAR(20), o.DateOfOrder, 103),
             CONVERT(VARCHAR(20), o.OrderDate, 103) ASC;
END;
ELSE -- View mode =2: Không hiển thị số hóa đơn
BEGIN
    SELECT [Mã Chi Nhánh/Cty] = o.BranchID,
           [Tên Chi Nhánh/Cty] = syc.CpnyName,
           [Quản Lý MDS] = uu.FirstName,
           [Mã Nhân Viên] = o.SlsperID,
           [Tên Nhân Viên] = u.FirstName,
           [Vai Trò] = CASE
                           WHEN u.UserTypes LIKE '%LOG%' THEN
                               'LOG'
                           WHEN u.Position IN ( 'D', 'SD', 'AD', 'RD' )
                                AND u.UserTypes NOT LIKE '%LOG%' THEN
                               'MDS'
                           WHEN u.UserTypes LIKE '%CS%' THEN
                               'CS'
                           WHEN u.Position IN ( 'S', 'SS', 'AM', 'RM' ) THEN
                               'P.BH'
                           ELSE
                               u.Position
                       END,
           [Hình Thức Thanh Toán] = tc.PaymentsForm,
           [Hạn Thanh Toán] = CASE
                                  WHEN st.DueType = 'D'
                                       AND st.DueIntrv IN ( '1', '3' ) THEN
                                      N'Thanh Toán Ngay'
                                  ELSE
                                      N'Cho nợ'
                              END,
           [Ngày Nghiệp Vụ] = CONVERT(VARCHAR(20), o.OrderDate, 103),
           [Mã Đơn Hàng] = o.OrderNbr,
           [Số Hóa Đơn] = '',
           [Ký Hiệu Hóa Đơn] = '',
           [Ngày Đơn Hàng] = CONVERT(VARCHAR(20), o.DateOfOrder, 103),
           [Tháng] = RIGHT('0' + CAST(MONTH(o.DateOfOrder) AS VARCHAR(2)), 2),
           [Năm] = YEAR(o.DateOfOrder),
           [Đơn Vị Giao Hàng] = ISNULL(atr.Descr, ''),
           [Thời Gian Giao Hàng (HH:MM)] = MAX(o.DeliveryTime),
           [Thời Hạn Thanh Toán] = ISNULL(stt.Descr, o.TermsID),
           [Ngày Đến Hạn] = CONVERT(VARCHAR(20), o.DueDate, 103),                 -- CASE WHEN o.TermsID='O1' THEN dbo.fr_GetDueDateOverLapping(o.BranchID,o.OMOrder,@UserID) ELSE o.DueDate end,
           [Mã Khách Hàng] = o.CustID,
           [Tên Khách Hàng] = tc.CustName,
           [Mã Kênh] = tc.Channel,
           [Mã Kênh Phụ] = tc.ShopType,
           [Khu Vực] = ste.Descr,
           [Số Nhà Và Tên Đường] = StreetName,
           [Phường/Xã] = sw.Name,
           [Quận/Huyện] = sd.Name,
           [Tỉnh/Thành] = sta.Descr,
           [Người Liên Hệ] = tc.attn,
           [Số Điện Thoại] = tc.Phone,
           [Số Điện Thoại (KH Thuế)] = tc.PhoneCustInvc,
           [Đầu Kỳ (ĐH)] = IIF(SUM(OpeiningOrderAmt) > 0, 1, 0),                  --CountOpeningOrder),
           [Đầu Kỳ (Số Tiền)] = SUM(OpeiningOrderAmt),
           [Chốt Sổ (ĐH)] = IIF(SUM(OrdAmtRelease) > 0, 1, 0),                    --SUM(CountOrdRelease),
           [Chốt sổ (Số Tiền)] = SUM(OrdAmtRelease),
           [Giao Thành Công (ĐH)] = IIF(SUM(DeliveredOrderAmt) > 0, 1, 0),        -- SUM(DeliveredOrder),
           [Giao Thành Công (Số Tiền)] = SUM(DeliveredOrderAmt),
           [Hủy Hóa Đơn - Trả Hàng (ĐH)] = IIF(SUM(o.ReturnOrdAmt) > 0, 1, 0),    -- SUM(K.CountReturnOrd),
           [Hủy Hóa Đơn - Trả Hàng (Số Tiền)] = SUM(o.ReturnOrdAmt),
           [Xác Nhận Thu Nợ (Số Tiền)] = SUM(o.ReceiveAmt),
           [Lý Do Không Thu Nợ Được] = MAX(o.Reason),
           [Tạo Bảng Kê (ĐH)] = IIF(SUM(DebConfirmAmt) > 0, 1, 0),                -- SUM(CountDebtConfirm),
           [Tạo Bảng Kê (Số Tiền)] = SUM(DebConfirmAmt),
           [Xác Nhận TT Công Nợ (ĐH)] = IIF(SUM(DebConfirmAmtRelease) > 0, 1, 0), -- SUM(CountDebtConfirmRelease),
           [Xác Nhận TT Công Nợ (Số Tiền)] = SUM(DebConfirmAmtRelease),
           [Dư Nợ Cuối Kỳ] = SUM(OpeiningOrderAmt) + SUM(OrdAmtRelease) - SUM(o.ReturnOrdAmt)
                             - SUM(DebConfirmAmtRelease)
    FROM #TOrder o
        INNER JOIN #TCustomer tc
            ON tc.BranchID = o.BranchID
               AND tc.OrderNbr = o.OrderNbr
               AND tc.OMOrder = o.OMOrder
        INNER JOIN dbo.Users u WITH (NOLOCK)
            ON u.UserName = o.SlsperID
        INNER JOIN dbo.SYS_Company syc WITH (NOLOCK)
            ON o.BranchID = syc.CpnyID
        LEFT JOIN dbo.AR_Transporter atr WITH (NOLOCK)
            ON o.DeliveryUnit = atr.Code
        LEFT JOIN #TSlsperID ts WITH (NOLOCK)
            ON ts.SlsperID = o.SlsperID
               AND ts.BranchID = o.BranchID
        LEFT JOIN dbo.Users uu WITH (NOLOCK)
            ON uu.UserName = ts.SupID
        LEFT JOIN dbo.SI_Terms st WITH (NOLOCK)
            ON st.TermsID = tc.Terms
        LEFT JOIN dbo.SI_Terms stt WITH (NOLOCK)
            ON stt.TermsID = o.TermsID
        INNER JOIN dbo.SI_Territory ste WITH (NOLOCK)
            ON ste.Territory = tc.Territory
        INNER JOIN dbo.SI_State sta WITH (NOLOCK)
            ON sta.State = tc.State
        INNER JOIN dbo.SI_District sd WITH (NOLOCK)
            ON sd.District = tc.District
               AND sd.State = tc.State
        LEFT JOIN dbo.SI_Ward sw WITH (NOLOCK)
            ON sw.Ward = tc.Ward
               AND sw.State = tc.State
               AND sw.District = tc.District
    WHERE tc.ShopType + '_' + tc.PaymentsForm NOT IN (
                                                         SELECT SubChannel FROM #WithOutSubChannel
                                                     )
    GROUP BY CASE
                 WHEN u.UserTypes LIKE '%LOG%' THEN
                     'LOG'
                 WHEN u.Position IN ( 'D', 'SD', 'AD', 'RD' )
                      AND u.UserTypes NOT LIKE '%LOG%' THEN
                     'MDS'
                 WHEN u.UserTypes LIKE '%CS%' THEN
                     'CS'
                 WHEN u.Position IN ( 'S', 'SS', 'AM', 'RM' ) THEN
                     'P.BH'
                 ELSE
                     u.Position
             END,
             CASE
                 WHEN st.DueType = 'D'
                      AND st.DueIntrv IN ( '1', '3' ) THEN
                     N'Thanh Toán Ngay'
                 ELSE
                     N'Cho nợ'
             END,
             syc.CpnyName,
             uu.FirstName,
             u.FirstName,
             ISNULL(stt.Descr, o.TermsID),
             ste.Descr,
             tc.StreetName,
             sw.Name,
             sd.Name,
             sta.Descr,
             o.BranchID,
             o.SlsperID,
             tc.PaymentsForm,
             CONVERT(VARCHAR(20), o.OrderDate, 103),
             o.OrderNbr,
             --o.InvcNbr,
             --o.InvcNote,
             CONVERT(VARCHAR(20), o.DateOfOrder, 103),
             CONVERT(VARCHAR(20), o.DueDate, 103),
             o.CustID,
             tc.CustName,
             tc.Channel,
             tc.ShopType,
             tc.attn,
             tc.Phone,
             PhoneCustInvc,
             ISNULL(atr.Descr, ''),
             RIGHT('0' + CAST(MONTH(o.DateOfOrder) AS VARCHAR(2)), 2),
             YEAR(o.DateOfOrder)
    --CASE WHEN o.TermsID='O1' THEN dbo.fr_GetDueDateOverLapping(o.BranchID,o.OMOrder,@UserID) ELSE o.DueDate end
    ORDER BY o.BranchID,
             o.SlsperID,
             o.OrderNbr,
             CONVERT(VARCHAR(20), o.DateOfOrder, 103),
             CONVERT(VARCHAR(20), o.OrderDate, 103) ASC;
END;

DROP TABLE #ReturnOrder;
DROP TABLE #WithOutOrderNbr;
DROP TABLE #TBranchID;
DROP TABLE #TOrderType;
DROP TABLE #TSlsperID;
DROP TABLE #WithOutSubChannel;
DROP TABLE #TOrder;
DROP TABLE #TCustomer;
GO