DECLARE @LangID SMALLINT=1;
DECLARE @FromDate DATETIME ='2022-01-01';
DECLARE @ToDate DATETIME ='2022-12-31';

DECLARE @BranchID  VARCHAR(30)='MR0001';
DECLARE @AccumulateID VARCHAR(50)='CSBH2204OTC-14QD/MR-KS-STO';

DECLARE @AccumulateSelected1 nvarchar(400)= dbo.fr_Language('AccumulateSelected1', @langid);
DECLARE @Selected BIT = 1;

DECLARE @AccumulateSelected0 nvarchar(400)= dbo.fr_Language('AccumulateSelected0', @langid);
DECLARE @ApplyType VARCHAR(5)=(select TOP 1 ApplyType from OM_Accumulated a WITH(NOLOCK) WHERE a.AccumulateID=@AccumulateID);


with #ReturnOrd as
(
    SELECT DISTINCT o.BranchID, o.OrderNbr ,OrigOrderNbrCM
    --INTO #ReturnOrd
    FROM 
    (
        -- Đơn Trả CO WHERE THEO pdasaleord od.OriOrderNbrUp
        SELECT DISTINCT o.BranchID, o.OrigOrderNbr AS OrderNbr,oc.OrigOrderNbr AS OrigOrderNbrCM
        --INTO #ReturnOrd
        FROM dbo.OM_SalesOrd o WITH(NOLOCK)
        INNER JOIN dbo.OM_PDASalesOrd od WITH(NOLOCK) ON od.BranchID = o.BranchID AND o.OrigOrderNbr = od.OrderNbr
        INNER JOIN dbo.OM_SalesOrd oc WITH(NOLOCK) ON oc.BranchID = od.BranchID AND oc.OrderNbr = od.OriOrderNbrUp
                        
        WHERE o.Status ='C' AND o.OrderType IN ('CO') AND o.BranchID=@BranchID and (od.OrderDate BETWEEN @FromDate AND @ToDate)
        --AND o.OrderNbr='HD092021-09682'	
        UNION
        -- Đơn Trả IR WHERE THEO pdasaleord od.OrigOrderNbr
        SELECT DISTINCT o.BranchID, o.OrigOrderNbr AS OrderNbr,oc.OrigOrderNbr AS OrigOrderNbrCM
        --INTO #ReturnOrd
        FROM dbo.OM_SalesOrd o WITH(NOLOCK)
        INNER JOIN dbo.OM_PDASalesOrd od WITH(NOLOCK) ON od.BranchID = o.BranchID AND o.OrigOrderNbr = od.OrderNbr
        INNER JOIN dbo.OM_SalesOrd oc WITH(NOLOCK) ON oc.BranchID = od.BranchID AND oc.OrderNbr = od.OrigOrderNbr
        --INNER JOIN #tblAccumulatedResult b  WITH(NOLOCK) ON b.CustID = o.CustID AND (od.OrderDate BETWEEN b.FromDate AND b.ToDate)
        WHERE o.Status ='C'AND o.OrderType IN ('IR') AND o.BranchID=@BranchID and (od.OrderDate BETWEEN @FromDate AND @ToDate)
    ) o	
)
-- Đơn Bán

, #SalesOrdC as
(
    SELECT DISTINCT o.BranchID, o.OrigOrderNbr AS OrderNbr
    --INTO #SalesOrdC
    FROM OM_SalesOrd o WITH(NOLOCK)
    INNER JOIN dbo.OM_PDASalesOrd od WITH(NOLOCK) ON od.BranchID = o.BranchID AND o.OrigOrderNbr = od.OrderNbr
    --INNER JOIN #tblAccumulatedResult b  WITH(NOLOCK) ON b.CustID = o.CustID AND (od.OrderDate BETWEEN b.FromDate AND b.ToDate)
    LEFT JOIN OM_AccumulatedResultDet ad WITH(NOLOCK) ON od.BranchID =ad.BranchID AND od.OrderNbr=ad.OrderNbr
    WHERE o.OrderType ='IN' 
    AND ad.BranchID IS NULL --20211030 trunght loại các đơn đã có trong OM_AccumulatedResultDet
    AND o.BranchID = @BranchID AND o.Status = 'C'
    and (od.OrderDate BETWEEN @FromDate AND @ToDate)
)
---20210927 TRUNGHT VIẾT LẠI LẤY ĐƠN DET
-- Đơn Trả
SELECT T.ARDocType,T.AccumulateSelected,T.LineRef,T.AccumulateID,T.BranchID,T.CustID,T.OrderNbr,
T.AccumulatedValue,T.OrderDate,T.tstamp,T.Sel,T.OrderType,SumDiscAmt = SUM(ROUND(t.SumDiscAmt,0)) FROM 
(
    SELECT
        ot.ARDocType,--20210629 trunght lấy thêm ARDocType để kiểm tra ko kiểm tra theo OrderType
        AccumulateSelected = CASE WHEN d.Selected = @Selected 
                                THEN @AccumulateSelected1
                                ELSE @AccumulateSelected0 
                            END, 
        LineRef ='', 
        d.AccumulateID,
        a.BranchID,a.CustID,a.OrderNbr
        ,AccumulatedValue =  SUM (
                        CASE WHEN @ApplyType = 'A' THEN c.LineQty * c.SlsPrice * -1 
                        ELSE (
                                CASE WHEN c.UnitMultDiv = 'M' THEN c.LineQty * UnitRate 
                                ELSE c.LineQty / c.UnitRate 
                                END
                        ) END)--a.LineAmt--20210927 TRUNGHT SUM lại tránh bị double 2 dòng accumulate giống nhau
        ,a.OrderDate,
        SumDiscAmt = ROUND(od.DiscAmt,0) * -1,  --- Ngochb bỏ sum do trùng kết quả
        d.tstamp,
        Sel=d.Selected,
        a.OrderType
    FROM OM_PDASalesOrd a WITH(NOLOCK)
    INNER JOIN OM_PDASalesOrdDet c WITH(NOLOCK) ON c.BranchID = a.BranchID AND c.OrderNbr = a.OrderNbr AND c.FreeItem = 0
    INNER JOIN OM_AccumulatedInvtSetup T11 ON T11.AccumulateID = @AccumulateID AND T11.InvtID = c.InvtID
    INNER JOIN #ReturnOrd oc ON oc.OrderNbr = a.OrderNbr AND oc.BranchID = a.BranchID
    INNER JOIN OM_OrderType ot WITH(NOLOCK) ON a.OrderType = ot.OrderType		
    INNER JOIN OM_AccumulatedOrderApproval d WITH(NOLOCK) ON d.OrderNbr = a.OrderNbr AND d.BranchID = a.BranchID AND d.AccumulateID = @AccumulateID	
    LEFT JOIN OM_PDAOrdDisc od WITH(NOLOCK) ON od.OrderNbr = a.OrderNbr AND od.BranchID = a.BranchID AND c.LineRef IN (SELECT part FROM dbo.fr_SplitStringMAX(od.GroupRefLineRef,','))
    WHERE a.BranchID = @BranchID AND a.Status = 'C' AND ot.ARDocType ='CM'
    GROUP BY od.DiscAmt,ot.ARDocType,d.AccumulateID,a.BranchID,a.CustID,a.OrderNbr,a.LineAmt,a.OrderDate, d.tstamp, d.Selected, a.OrderType --- Ngochb bỏ sum do trùng kết quả
)T
--LEFT JOIN OM_PDAOrdDisc od WITH(NOLOCK) ON od.OrderNbr = T.OrderNbr AND od.BranchID = T.BranchID --AND T.LineRef IN (SELECT part FROM dbo.fr_SplitStringMAX(od.GroupRefLineRef,','))
GROUP BY T.ARDocType,T.AccumulateSelected,T.LineRef,T.AccumulateID,T.BranchID,T.CustID,T.OrderNbr,T.AccumulatedValue,T.OrderDate,T.tstamp,T.Sel,T.OrderType
UNION ALL
--ĐƠN BÁN
SELECT T.ARDocType,T.AccumulateSelected,T.LineRef,T.AccumulateID,T.BranchID,T.CustID,T.OrderNbr,
T.AccumulatedValue,T.OrderDate,T.tstamp,T.Sel,T.OrderType,SumDiscAmt = SUM(ROUND(t.SumDiscAmt,0))
FROM
(
    SELECT
            ot.ARDocType,--20210629 trunght lấy thêm ARDocType để kiểm tra ko kiểm tra theo OrderType
        AccumulateSelected = CASE WHEN d.Selected = @Selected 
                            THEN @AccumulateSelected1
                            ELSE @AccumulateSelected0 
                        END, 
        LineRef ='', 
        d.AccumulateID,
        a.BranchID,a.CustID,a.OrderNbr
        ,AccumulatedValue = SUM (
                        CASE WHEN @ApplyType = 'A' THEN c.LineQty * c.SlsPrice 
                        ELSE (
                                CASE WHEN c.UnitMultDiv = 'M' THEN c.LineQty * UnitRate 
                                ELSE c.LineQty / c.UnitRate 
                                END
                        ) END)--a.LineAmt--20210927 TRUNGHT SUM lại tránh bị double 2 dòng accumulate giống nhau
        ,a.OrderDate,
        SumDiscAmt = ROUND(ISNULL(od.DiscAmt,0),0),--SUM(ROUND(ISNULL(od.DiscAmt,0),0)),  --- Ngochb bỏ sum do trùng kết quả
        d.tstamp,
        Sel=d.Selected,
        a.OrderType

    FROM OM_PDASalesOrd a WITH(NOLOCK)
    INNER JOIN OM_PDASalesOrdDet c WITH(NOLOCK) ON c.BranchID = a.BranchID AND c.OrderNbr = a.OrderNbr AND c.FreeItem = 0
    INNER JOIN OM_AccumulatedInvtSetup T11 ON T11.AccumulateID = @AccumulateID AND T11.InvtID = c.InvtID
    INNER JOIN #SalesOrdC oc ON oc.OrderNbr = a.OrderNbr AND oc.BranchID = a.BranchID
    INNER JOIN OM_OrderType ot WITH(NOLOCK) ON a.OrderType = ot.OrderType		
    INNER JOIN OM_AccumulatedOrderApproval d WITH(NOLOCK) ON d.OrderNbr = a.OrderNbr AND d.BranchID = a.BranchID AND d.AccumulateID = @AccumulateID	
    LEFT JOIN OM_PDAOrdDisc od WITH(NOLOCK) ON od.OrderNbr = a.OrderNbr AND od.BranchID = a.BranchID AND c.LineRef IN (SELECT part FROM dbo.fr_SplitStringMAX(od.GroupRefLineRef,','))
    WHERE a.BranchID = @BranchID AND a.Status = 'C' AND ot.ARDocType ='IN'
    GROUP BY ISNULL(od.DiscAmt,0),ot.ARDocType,d.AccumulateID,a.BranchID,a.CustID,a.OrderNbr,a.LineAmt,a.OrderDate, d.tstamp, d.Selected, a.OrderType--,od.DiscAmt --- Ngochb bỏ sum do trùng kết quả
    --ORDER BY d.Selected DESC
)T
--LEFT JOIN OM_PDAOrdDisc od WITH(NOLOCK) ON od.OrderNbr = T.OrderNbr AND od.BranchID = T.BranchID --AND T.LineRef IN (SELECT part FROM dbo.fr_SplitStringMAX(od.GroupRefLineRef,','))
GROUP BY T.ARDocType,T.AccumulateSelected,T.LineRef,T.AccumulateID,T.BranchID,T.CustID,T.OrderNbr,T.AccumulatedValue,T.OrderDate,T.tstamp,T.Sel,T.OrderType
--DROP TABLE #tblAccumulatedResult
--DROP TABLE #tblOrderDet
--DROP TABLE #SalesOrdC
--DROP TABLE #ReturnOrd
--where CustID = 'MSPC0044'