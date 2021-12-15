SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[pr_AR_TrackingDebtConfirm] --pr_AR_TrackingDebtConfirm '20201015','20201015'
    @Fromdate DATE,
    @Todate DATE
AS
SET NOCOUNT ON;
--DECLARE @Fromdate DATE, @Todate DATE
--SELECT @Fromdate='20210501',@Todate='20210909'
DECLARE @CurrentDate DATE,
        @UserID VARCHAR(30);
--SELECT @Fromdate='20210501',@Todate='20210909'
SELECT @CurrentDate = CAST(GETDATE() AS DATE),
       @UserID = 'Admin';
/* Lấy danh sách các ordertype cần thể hiện*/
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
WHERE co.OrderType IN ( 'CO', 'HK' )
      AND ino.OrderType IN ( 'IN', 'IO', 'EP', 'NP' )
      AND co.Status = 'C'
      AND CAST(co.OrderDate AS DATE)
      BETWEEN @Fromdate AND @Todate;

/*Loại những KH có kênh phụ là CLC1 và CLC2 */
--CREATE TABLE #WithOutSubChannel
--(
--    SubChannel VARCHAR(30)
--);
--INSERT INTO #WithOutSubChannel
--(
--    SubChannel
--)
--VALUES
--('CLC1_CK'),
--('CLC2_CK'),
--('INS1_CK'),
--('INS2_CK'),
--('INS3_CK'),
--('CHUOI_CK'),
--('DLPP1_CK'),
--('INS1_TM'),
--('INS2_TM'),
----('INS3_TM'),
----('CHUOI_TM'),
----('DLPP1_TM'),
--('DLPP2_CK'),
--('DLPP3_CK')

CREATE TABLE #GroupDebtOwner( Terms VARCHAR(10), PayMentForm VARCHAR(5), GroupID VARCHAR(10))
INSERT INTO #GroupDebtOwner
(
    Terms,
    PayMentForm,
    GroupID
)
VALUES
(   
'01',	'TM',	'MDS'),
('03',	'TM',	'MDS'),
('07',	'TM',	'CS'),
('10',	'TM',	'CS'),
('12',	'TM',	'CS'),
('15',	'TM',	'CS'),
('18',	'TM',	'CS'),
('20',	'TM',	'CS'),
('30',	'TM',	'CS'),
('45',	'TM',	'CS'),
('60',	'TM',	'CS'),
('90',	'TM',	'CS'),
('O1',	'TM',	'MDS'),
('O2',	'TM',	'CS'),
('O3',	'TM',	'CS'),
('01',	'CK',	'CS'),
('03',	'CK',	'CS'),
('07',	'CK',	'CS'),
('10',	'CK',	'CS'),
('12',	'CK',	'CS'),
('15',	'CK',	'CS'),
('18',	'CK',	'CS'),
('20',	'CK',	'CS'),
('30',	'CK',	'CS'),
('45',	'CK',	'CS'),
('60',	'CK',	'CS'),
('90',	'CK',	'CS'),
('O1',	'CK',	'CS'),
('O2',	'CK',	'CS'),
('O3',	'CK',	'CS')

    


SELECT *
INTO #TSlsperID
FROM dbo.fr_ListSaleByData(@UserID);

SELECT *
INTO #TOrder
FROM
(
    /* Số đơn hàng đầu kỳ*/
    SELECT ord.BranchID,
           deb.SlsperID,
           ord.OrderNbr,
		   DeliveryUnit='',
           sod.CustID,
		   sod.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           sod.Version,
           OrderDate = CAST(do.DocDate AS DATE),
           DateOfOrder = CAST(sod.OrderDate AS DATE),
		   DeliveryTime='',
           TermsID = do.Terms,
           DueDate= CASE WHEN do.Terms='O1' THEN  DATEADD(DAY,30,do.DocDate) ELSE do.DueDate end,
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
           DebConfirmAmtRelease = 0
    FROM dbo.OM_PDASalesOrd ord WITH (NOLOCK)
        INNER JOIN #TOrderType ot WITH (NOLOCK)
            ON ot.OrderType = ord.OrderType
		INNER JOIN dbo.OM_SalesOrd sod WITH (NOLOCK) ON sod.BranchID=ord.BranchID AND sod.OrigOrderNbr=ord.OrderNbr
        INNER JOIN dbo.OM_DebtAllocateDet deb
            ON deb.BranchID = ord.BranchID
               AND deb.OrderNbr = ord.OrderNbr
			   AND sod.ARBatNbr=deb.ARBatNbr
        INNER JOIN dbo.AR_Doc do
            ON deb.BranchID = do.BranchID
               AND deb.ARBatNbr = do.BatNbr
               AND deb.CustID = do.CustId
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
		   DeliveryUnit=ISNULL(i.DeliveryUnit,''),
           sod.CustID,
		   sod.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           sod.Version,
           OrderDate = IIF(CAST(i.IssueDate AS DATE)<CAST( sod.OrderDate AS DATE),CAST( sod.OrderDate AS DATE),CAST(i.IssueDate AS DATE)),
           DateOfOrder = CAST( sod.OrderDate AS DATE),
		   DeliveryTime='',
           TermsID = do.Terms,
           DueDate= CASE WHEN do.Terms='O1' THEN  DATEADD(DAY,30,do.DocDate) ELSE do.DueDate end,
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
           DebConfirmAmtRelease = 0
    FROM dbo.OM_IssueBook i WITH (NOLOCK)
        INNER JOIN dbo.OM_IssueBookDet d WITH (NOLOCK)
            ON d.BatNbr = i.BatNbr
               AND d.BranchID = i.BranchID
        INNER JOIN dbo.OM_PDASalesOrd ord WITH (NOLOCK)
            ON ord.BranchID = d.BranchID
               AND ord.OrderNbr = d.OrderNbr
		INNER JOIN dbo.OM_SalesOrd sod WITH (NOLOCK) ON sod.BranchID=ord.BranchID AND sod.OrigOrderNbr=ord.OrderNbr
        INNER JOIN #TOrderType ot WITH (NOLOCK)
            ON ot.OrderType = ord.OrderType
        INNER JOIN dbo.OM_DebtAllocateDet deb WITH (NOLOCK)
            ON deb.BranchID = d.BranchID
               AND deb.OrderNbr = d.OrderNbr
			   AND sod.ARBatNbr=deb.ARBatNbr
        INNER JOIN dbo.AR_Doc do WITH (NOLOCK)
            ON deb.BranchID = do.BranchID
               AND deb.ARBatNbr = do.BatNbr
               AND deb.CustID = do.CustId
        INNER JOIN Batch b WITH (NOLOCK)
            ON do.BranchID = b.BranchID
               AND do.BatNbr = b.BatNbr
               AND b.Module = 'AR'
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
		   DeliveryUnit=ISNULL(b.DeliveryUnit,''),
           sod.CustID,
		   sod.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           sod.Version,
           OrderDate = CAST(dl.LUpd_DateTime AS DATE),
           DateOfOrder = CAST( sod.OrderDate AS DATE),
		   DeliveryTime=CAST((DATEDIFF(MINUTE,dl.Crtd_DateTime,dl.LUpd_DateTime)-DATEDIFF(MINUTE,dl.Crtd_DateTime,dl.LUpd_DateTime)%60)/60 AS VARCHAR(8)) +':'+ RIGHT('0'+ CAST(DATEDIFF(MINUTE,dl.Crtd_DateTime,dl.LUpd_DateTime)%60 AS VARCHAR(2)),2),
           TermsID = do.Terms,
           DueDate= CASE WHEN do.Terms='O1' THEN  DATEADD(DAY,30,do.DocDate) ELSE do.DueDate end,
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
           DebConfirmAmtRelease = 0
    FROM dbo.OM_IssueBook b WITH (NOLOCK)
        INNER JOIN dbo.OM_IssueBookDet d WITH (NOLOCK)
            ON d.BranchID = b.BranchID
               AND d.BatNbr = b.BatNbr
        INNER JOIN dbo.OM_PDASalesOrd o WITH (NOLOCK)
            ON o.BranchID = b.BranchID
               AND o.OrderNbr = d.OrderNbr
		INNER JOIN dbo.OM_SalesOrd sod WITH (NOLOCK) ON sod.BranchID=o.BranchID AND sod.OrigOrderNbr=o.OrderNbr
        INNER JOIN #TOrderType ot WITH (NOLOCK)
            ON ot.OrderType = o.OrderType
        INNER JOIN dbo.OM_Delivery dl WITH (NOLOCK)
            ON dl.BranchID = d.BranchID
               AND dl.OrderNbr = d.OrderNbr
               AND dl.Status = 'C'
        INNER JOIN dbo.OM_DebtAllocateDet deb WITH (NOLOCK)
            ON deb.BranchID = dl.BranchID
               AND deb.OrderNbr = dl.OrderNbr
			   AND deb.ARBatNbr=sod.ARBatNbr
               AND dl.Status = 'C'
        INNER JOIN dbo.AR_Doc do WITH (NOLOCK)
            ON deb.BranchID = do.BranchID
               AND deb.ARBatNbr = do.BatNbr
               AND deb.CustID = do.CustId
        INNER JOIN Batch ba WITH (NOLOCK)
            ON do.BranchID = ba.BranchID
               AND do.BatNbr = ba.BatNbr
               AND ba.Module = 'AR'
        LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK)
            ON woo.BranchID = o.BranchID
               AND woo.OrigOrderNbr = o.OrderNbr
		LEFT JOIN #ReturnOrder rod WITH (NOLOCK) ON rod.BranchID=o.BranchID AND rod.OrigOrderNbr=o.OrderNbr
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
		   DeliveryUnit=ISNULL(b.DeliveryUnit,''),
           sod.CustID,
		   sod.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           sod.Version,
           OrderDate = CAST(dbc.CreateDate AS DATE),
           DateOfOrder = CAST(sod.OrderDate AS DATE),
		   DeliveryTime='',
           TermsID = do.Terms,
           DueDate= CASE WHEN do.Terms='O1' THEN  DATEADD(DAY,30,do.DocDate) ELSE do.DueDate end,
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
           DebConfirmAmtRelease = 0
    FROM dbo.OM_IssueBook b WITH (NOLOCK)
        INNER JOIN dbo.OM_IssueBookDet d WITH (NOLOCK)
            ON d.BranchID = b.BranchID
               AND d.BatNbr = b.BatNbr
        INNER JOIN dbo.OM_PDASalesOrd o WITH (NOLOCK)
            ON o.BranchID = b.BranchID
               AND o.OrderNbr = d.OrderNbr
        INNER JOIN #TOrderType ot WITH (NOLOCK)
            ON ot.OrderType = o.OrderType
        INNER JOIN dbo.OM_Delivery dl WITH (NOLOCK)
            ON dl.BranchID = d.BranchID
               AND dl.OrderNbr = d.OrderNbr
               AND dl.Status = 'C'
	    INNER JOIN dbo.OM_SalesOrd sod WITH (NOLOCK) ON sod.BranchID=o.BranchID AND sod.OrigOrderNbr=o.OrderNbr
        INNER JOIN dbo.OM_DebtAllocateDet deb WITH (NOLOCK)
            ON deb.BranchID = dl.BranchID
               AND deb.OrderNbr = dl.OrderNbr
               AND dl.Status = 'C'
			   AND sod.ARBatNbr=deb.ARBatNbr
        INNER JOIN dbo.AR_Doc do WITH (NOLOCK)
            ON deb.BranchID = do.BranchID
               AND deb.ARBatNbr = do.BatNbr
               AND deb.CustID = do.CustId
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
        LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK)
            ON woo.BranchID = o.BranchID
               AND woo.OrigOrderNbr = o.OrderNbr
    WHERE b.Status = 'C'
          AND CAST(dbc.CreateDate AS DATE)
          BETWEEN @Fromdate AND @Todate
          AND sod.Status = 'C'
          AND woo.OrigOrderNbr IS NULL
    UNION ALL
    --    /* Thông tin hủy hóa đơn - trả hàng*/
    SELECT d.BranchID,
           SlsperID=ISNULL(ib.SlsperID,deb.SlsperID),
           OrderNbr = d.OrigOrderNbr,
		   DeliveryUnit=ISNULL(ib.DeliveryUnit,''),
           sod.CustID,
		   sod.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           sod.Version,
           OrderDate = CAST(d.ReturnDate AS DATE),
           DateOfOrder = CAST( sod.OrderDate AS DATE),
		   DeliveryTime='',
           TermsID = do.Terms,
           DueDate= CASE WHEN do.Terms='O1' THEN  DATEADD(DAY,30,do.DocDate) ELSE do.DueDate end,
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
           DebConfirmAmtRelease = 0
    FROM #ReturnOrder d WITH (NOLOCK)
        INNER JOIN dbo.OM_PDASalesOrd ord WITH (NOLOCK)
            ON ord.BranchID = d.BranchID
               AND ord.OrderNbr = d.OrigOrderNbr
		INNER JOIN dbo.OM_SalesOrd sod WITH (NOLOCK) ON sod.BranchID=ord.BranchID AND sod.OrigOrderNbr=ord.OrderNbr AND sod.OrderNbr=d.INOrderNbr
        INNER JOIN #TOrderType ot WITH (NOLOCK)
            ON ot.OrderType = ord.OrderType
        INNER JOIN dbo.OM_DebtAllocateDet deb WITH (NOLOCK)
            ON deb.BranchID = d.BranchID
               AND deb.OrderNbr = d.OrigOrderNbr
			   AND deb.ARBatNbr=sod.ARBatNbr
		LEFT JOIN dbo.OM_IssueBookDet bd WITH (NOLOCK) ON bd.BranchID = deb.BranchID AND bd.OrderNbr=deb.OrderNbr
		LEFT JOIN dbo.OM_IssueBook ib WITH (NOLOCK) ON ib.BranchID = bd.BranchID AND ib.BatNbr = bd.BatNbr 
        INNER JOIN dbo.AR_Doc do WITH (NOLOCK)
            ON deb.BranchID = do.BranchID
               AND deb.ARBatNbr = do.BatNbr
               AND deb.CustID = do.CustId
        INNER JOIN Batch b WITH (NOLOCK)
            ON do.BranchID = b.BranchID
               AND do.BatNbr = b.BatNbr
               AND b.Module = 'AR'
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
           SlsperID=ISNULL(ib.SlsperID,deb.SlsperID),
           deb.OrderNbr,
		   DeliveryUnit=ISNULL(ib.DeliveryUnit,''),
           ord.CustID,
		   ord.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           ord.Version,
           OrderDate = CAST(b.Crtd_DateTime AS DATE),
           DateOfOrder = CAST( ord.OrderDate AS DATE),
		   DeliveryTime='',
           TermsID = do.Terms,
           DueDate= CASE WHEN do.Terms='O1' THEN  DATEADD(DAY,30,do.DocDate) ELSE do.DueDate end,
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
           DebConfirmAmtRelease = 0
    --SELECT *
    FROM OM_SalesOrd ord
        INNER JOIN dbo.OM_DebtAllocateDet deb WITH (NOLOCK)
            ON deb.BranchID = ord.BranchID
               AND deb.OrderNbr = ord.OrigOrderNbr
               AND deb.ARBatNbr = ord.ARBatNbr
		LEFT JOIN dbo.OM_IssueBookDet bd WITH (NOLOCK) ON bd.BranchID = deb.BranchID AND bd.OrderNbr=deb.OrderNbr
		LEFT JOIN dbo.OM_IssueBook ib WITH (NOLOCK) ON ib.BranchID = bd.BranchID AND ib.BatNbr = bd.BatNbr 
		LEFT JOIN #ReturnOrder rto WITH (NOLOCK) ON rto.BranchID = ord.BranchID AND rto.INOrderNbr=ord.OrderNbr
        INNER JOIN dbo.AR_Doc do WITH (NOLOCK)
            ON ord.BranchID = do.BranchID
               AND ord.ARBatNbr = do.BatNbr
               AND ord.ARRefNbr = do.RefNbr
        INNER JOIN dbo.AR_Adjust a WITH (NOLOCK)
            ON a.AdjdBatNbr = ord.ARBatNbr
               AND a.AdjdRefNbr = ord.ARRefNbr
               AND a.BranchID = ord.BranchID
			   AND ISNULL(a.Reversal,'') = ''
        LEFT JOIN dbo.AR_AdjustDetail aDetail WITH (NOLOCK)
            ON aDetail.BranchID = a.BranchID
               AND aDetail.AdjgBatNbr = a.BatNbr
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
        LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK)
            ON woo.BranchID = ord.BranchID
               AND woo.OrigOrderNbr = ord.OrigOrderNbr
    WHERE CAST(b.Crtd_DateTime AS DATE)
          BETWEEN @Fromdate AND @Todate
          AND ord.Status = 'C'
          AND ba.Status <> 'V'
          AND woo.OrigOrderNbr IS NULL
		  AND rto.INOrderNbr IS NULL
    UNION ALL
    /* Thông tin số đơn hàng lên bảng kê, ĐÃ xác nhận*/
    SELECT a.BranchID,
          SlsperID=ISNULL(ib.SlsperID, deb.SlsperID),
           sod.OrderNbr,
		   DeliveryUnit=ISNULL(ib.DeliveryUnit,''),
           ord.CustID,
		   ord.InvoiceCustID,
           do.InvcNbr,
           do.InvcNote,
           ord.Version,
           OrderDate = CAST(b.DocDate AS DATE),
           DateOfOrder = CAST( ord.OrderDate AS DATE),
		   DeliveryTime='',
           TermsID = do.Terms,
           DueDate= CASE WHEN do.Terms='O1' THEN  DATEADD(DAY,30,do.DocDate) ELSE do.DueDate end,
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
                           END
    FROM OM_SalesOrd ord
        INNER JOIN dbo.OM_DebtAllocateDet deb WITH (NOLOCK)
            ON deb.BranchID = ord.BranchID
               AND deb.OrderNbr = ord.OrigOrderNbr
               AND deb.ARBatNbr = ord.ARBatNbr
		LEFT JOIN dbo.OM_IssueBookDet bd WITH (NOLOCK) ON bd.BranchID = deb.BranchID AND bd.OrderNbr=deb.OrderNbr
		LEFT JOIN dbo.OM_IssueBook ib WITH (NOLOCK) ON ib.BranchID = bd.BranchID AND ib.BatNbr = bd.BatNbr 
		LEFT JOIN #ReturnOrder rto WITH (NOLOCK) ON rto.BranchID = ord.BranchID AND rto.INOrderNbr=ord.OrderNbr
        INNER JOIN dbo.AR_Doc do WITH (NOLOCK)
            ON ord.BranchID = do.BranchID
               AND ord.ARBatNbr = do.BatNbr
               AND ord.ARRefNbr = do.RefNbr
        INNER JOIN dbo.AR_Adjust a WITH (NOLOCK)
            ON a.AdjdBatNbr = ord.ARBatNbr
               AND a.AdjdRefNbr = ord.ARRefNbr
               AND a.BranchID = ord.BranchID
			   AND ISNULL(a.Reversal,'') = ''
        LEFT JOIN dbo.AR_AdjustDetail aDetail WITH (NOLOCK)
            ON aDetail.BranchID = a.BranchID
               AND aDetail.AdjgBatNbr = a.BatNbr
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
        LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK)
            ON woo.BranchID = sod.BranchID
               AND woo.OrigOrderNbr = sod.OrderNbr
    WHERE CAST(b.DocDate AS DATE)
          BETWEEN @Fromdate AND @Todate
          AND ba.Status = 'C'
          AND ord.Status = 'C'
          AND woo.OrigOrderNbr IS NULL
		  AND rto.INOrderNbr IS NULL

) K;


SELECT DISTINCT
       od.BranchID,
       od.OrderNbr,
       PaymentsForm = CASE
                          WHEN CASE
                                   WHEN cl.PaymentsForm = '' THEN
                                       c.PaymentsForm
                                   ELSE
                                       ISNULL(cl.PaymentsForm, c.PaymentsForm)
                               END IN ( 'B', 'C' ) THEN
                              'TM'
                          ELSE
                              'CK'
                      END,
       Terms = CASE
                   WHEN cl.Terms = '' THEN
                       c.Terms
                   ELSE
                       ISNULL(cl.Terms, c.Terms)
               END,
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
	  PhoneCustInvc=aci.Phone
INTO #TCustomer
FROM #TOrder od WITH (NOLOCK)
    INNER JOIN dbo.AR_Customer c
        ON c.CustId = od.CustID
	LEFT JOIN dbo.AR_CustomerInvoice aci WITH (NOLOCK) ON aci.CustIDInvoice=od.InvoiceCustID 
    LEFT JOIN dbo.AR_HistoryCustClassID cl
        ON cl.Version = od.Version;
 SELECT BranchID = o.BranchID,
       BranchName = syc.CpnyName,
       SupName = ISNULL(uu.FirstName,''),
	   ASMName = ISNULL(am.FirstName,''),
	   RSMName= ISNULL(rm.FirstName,''),
       SlsperID = o.SlsperID,
       SlsperName = u.FirstName,
       Position = CASE
                       WHEN u.UserTypes LIKE '%LOG%' THEN
                           'LOG'
                       ELSE
                           'MDS'
                   END,
	   DebtInCharge=ISNULL(g.GroupID,'CS'),
       PaymentsForm = tc.PaymentsForm,
       TermsType = CASE
                              WHEN st.DueType = 'D'
                                   AND st.DueIntrv IN ( '1', '3' ) THEN
                                  N'Thanh Toán Ngay'
                              ELSE
                                  N'Cho nợ'
                          END,
       OrderDate = CAST(o.OrderDate AS DATE),
       OrderNbr = o.OrderNbr,
       --[Số Hóa Đơn] = o.InvcNbr,
       --[Ký Hiệu Hóa Đơn] = o.InvcNote,
       DateOfOrder = CAST(o.DateOfOrder AS DATE),
	   DeliveryUnit= ISNULL(atr.Descr,''),
	   DeliveryTime= MAX(o.DeliveryTime),
       Terms = stt.Descr,
       DueDate = CAST(o.DueDate AS DATE),
       CustID = o.CustID,
       CustName = tc.CustName,
       Channels = tc.Channel,
       SubChannel = tc.ShopType,
       Territory = ste.Descr,
       Streets= StreetName,
       Ward = sw.Name,
       District = sd.Name,
       State = sta.Descr,
       Attn = tc.attn,
       Phone = tc.Phone,
	   PhoneCustInvc = tc.PhoneCustInvc,
       CountOpeningOrder = IIF(SUM(OpeiningOrderAmt) > 0, 1, 0),                  --CountOpeningOrder),
       OpeiningOrderAmt = SUM(OpeiningOrderAmt),
       CountOrdRelease = IIF(SUM(OrdAmtRelease) > 0, 1, 0),                    --SUM(CountOrdRelease),
       OrdAmtRelease = SUM(OrdAmtRelease),
       DeliveredOrder = IIF(SUM(DeliveredOrderAmt) > 0, 1, 0),        -- SUM(DeliveredOrder),
       DeliveredOrderAmt = SUM(DeliveredOrderAmt),
       CountReturnOrd = IIF(SUM(o.ReturnOrdAmt) > 0, 1, 0),    -- SUM(K.CountReturnOrd),
       ReturnOrdAmt = SUM(o.ReturnOrdAmt),
       ConfirmAmt = SUM(o.ReceiveAmt),
       ReasonNoPay = MAX(o.Reason),
       CountDebtConfirm = IIF(SUM(DebConfirmAmt) > 0, 1, 0),                -- SUM(CountDebtConfirm),
       DebConfirmAmt = SUM(DebConfirmAmt),
       CountDebtConfirmRelease = IIF(SUM(DebConfirmAmtRelease) > 0, 1, 0), -- SUM(CountDebtConfirmRelease),
       DebConfirmAmtRelease = SUM(DebConfirmAmtRelease)
FROM #TOrder o
    INNER JOIN #TCustomer tc
        ON tc.BranchID = o.BranchID
           AND tc.OrderNbr = o.OrderNbr
    INNER JOIN dbo.Users u WITH (NOLOCK)
        ON u.UserName = o.SlsperID
    INNER JOIN dbo.SYS_Company syc WITH (NOLOCK)
        ON o.BranchID = syc.CpnyID
	LEFT JOIN #GroupDebtOwner g WITH (NOLOCK) ON g.PayMentForm=tc.PaymentsForm AND g.Terms=o.TermsID
	LEFT JOIN dbo.AR_Transporter atr WITH (NOLOCK) ON o.DeliveryUnit=atr.Code
    LEFT JOIN #TSlsperID ts WITH (NOLOCK)
        ON ts.SlsperID = o.SlsperID
           AND ts.BranchID = o.BranchID
    LEFT JOIN dbo.Users uu WITH (NOLOCK)
        ON uu.UserName = ts.SupID
	LEFT JOIN dbo.Users am WITH (NOLOCK) ON am.UserName=ts.ASM
	LEFT JOIN dbo.Users rm WITH (NOLOCK) ON rm.UserName=ts.RSMID
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
--WHERE tc.ShopType+'_'+tc.PaymentsForm NOT IN (
--                             SELECT SubChannel FROM #WithOutSubChannel
--                         )
GROUP BY CASE WHEN u.UserTypes LIKE '%LOG%' THEN 'LOG' ELSE 'MDS'END,
         CASE
         WHEN st.DueType = 'D'
         AND st.DueIntrv IN ( '1', '3' ) THEN
         N'Thanh Toán Ngay'
         ELSE
         N'Cho nợ'
         END,
         syc.CpnyName,
         u.FirstName,
         stt.Descr,
         ste.Descr,
         tc.StreetName,
         sw.Name,
         sd.Name,
         sta.Descr,
		 o.BranchID,
		 o.SlsperID,
		 tc.PaymentsForm,
		 CAST(o.OrderDate AS DATE),
		 o.OrderNbr,
		 --o.InvcNbr,
		 --o.InvcNote,
		 CAST(o.DateOfOrder AS DATE),
		 CAST(o.DueDate AS DATE),
		 o.CustID,
		 tc.CustName,
		 tc.Channel,
		 tc.ShopType,
		 tc.attn,
		 tc.Phone,
		 PhoneCustInvc,
		ISNULL(atr.Descr,''),
		ISNULL(uu.FirstName,''),
	   ISNULL(am.FirstName,''),
	   ISNULL(rm.FirstName,''),
	   ISNULL(g.GroupID,'CS')
--ORDER BY o.BranchID,o.SlsperID,o.OrderNbr,CONVERT(VARCHAR(20),o.DateOfOrder,103),CONVERT(VARCHAR(20), o.OrderDate,103) ASC	 
DROP TABLE #ReturnOrder;
DROP TABLE #WithOutOrderNbr;
--DROP TABLE #WithOutSubChannel;

GO
