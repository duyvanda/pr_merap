DECLARE @FromDate DATETIME ='2022-04-01 00:00:00';
DECLARE @ToDate DATETIME ='2022-04-30 00:00:00';
DECLARE @LangID SMALLINT=1;
DECLARE @AccumulateSelected1 nvarchar(400)= dbo.fr_Language('AccumulateSelected1', @langid);
DECLARE @Selected BIT = 1;

SELECT
	ot.ARDocType,--20210629 trunght lấy thêm ARDocType để kiểm tra ko kiểm tra theo OrderType
	AccumulateSelected = @AccumulateSelected1, Sel = @Selected,
	a.LineRef, a.AccumulateID,a.BranchID,a.CustID,a.OrderNbr,a.AccumulatedValue,b.OrderDate, SumDiscAmt = c.Prepay, a.tstamp, b.OrderType
FROM OM_AccumulatedResultDet a WITH(NOLOCK)
	INNER JOIN OM_PDASalesOrd b WITH(NOLOCK) ON a.BranchID = b.BranchID AND a.OrderNbr = b.OrderNbr
	INNER JOIN AR_Customer cu WITH(NOLOCK) ON a.CustID = cu.CustID AND a.BranchID = cu.BranchID
	INNER JOIN OM_OrderType ot WITH(NOLOCK) ON b.OrderType = ot.OrderType
	INNER JOIN OM_AccumulatedResult c WITH(NOLOCK) ON a.BranchID = c.BranchID AND a.AccumulateID = c.AccumulateID AND a.CustID = c.CustID AND a.LineRef = c.LineRef
WHERE c.CloseDate BETWEEN @FromDate AND @ToDate