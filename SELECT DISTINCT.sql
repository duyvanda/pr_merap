SELECT DISTINCT 
ord.BranchID,
ord.OrderNbr,
pdis.FreeItemID,
d.LineQty,
pdis.FreeItemQty,
sq.TypeDiscount,
DiscAmt=0,
DiscPct=0,
sq.DiscIDPN,
sq.DiscID,
sq.DiscSeq,
SOLineRef=d.LineRef
FROM OM_SalesOrdDet d  
INNER JOIN dbo.OM_SalesOrd ord WITH (NOLOCK) ON ord.BranchID = d.BranchID AND d.OrderNbr=ord.OrderNbr  
-- INNER JOIN dbo.OM_SalesOrdDet d WITH (NOLOCK) ON d.BranchID = ord.BranchID AND d.OrderNbr = ord.OrderNbr  
INNER JOIN dbo.OM_PDAOrdDisc pdis WITH (NOLOCK) ON pdis.BranchID=d.BranchID AND pdis.OrderNbr=d.OrigOrderNbr AND d.InvtID=pdis.FreeItemID AND d.FreeItem=1 AND d.OriginalLineRef=pdis.SOLineRef  
INNER JOIN dbo.OM_DiscSeq sq WITH (NOLOCK) ON sq.DiscID=pdis.DiscID AND sq.DiscSeq=pdis.DiscSeq  
-- LEFT JOIN #TDiscFreeItem dis WITH (NOLOCK) ON  dis.BranchID=d.BranchID AND dis.FreeItemID=d.InvtID AND d.OrderNbr=dis.OrderNbr AND d.FreeItem=1 AND dis.SOLineRef=d.LineRef  
--NOTE: left join xong KHONG out put
-- WHERE dis.OrderNbr IS NULL

WHERE d.OrderNbr = 'HD052021-00754'

