WITH #TOrdDisc1 as
(
SELECT DISTINCT
top 10000
ord.BranchID,
ord.OrderNbr,
d.InvtID,
d.LineRef,
dis.FreeItemID,
dis.FreeItemQty,
dis.DiscType,
sq.TypeDiscount,
DiscAmt=
CASE WHEN dis.DiscType='L' then d.DiscAmt  
         WHEN dis.DiscType='G' THEN d.GroupDiscAmt1  
         WHEN dis.DiscType='D' THEN d.DocDiscAmt  
END,    
DiscPct 
=  CASE WHEN dis.DiscType='L' then d.DiscPct  
         WHEN dis.DiscType='G' THEN d.GroupDiscPct1  
         WHEN dis.DiscType='D' THEN d.DocDiscAmt -- Chưa biết tính như thế nào  
END,
sq.DiscIDPN ,
sq.DiscID,
sq.DiscSeq,
dis.SOLineRef
FROM OM_SalesOrdDet d  
INNER JOIN dbo.OM_SalesOrd ord WITH (NOLOCK) ON ord.BranchID = d.BranchID AND d.OrderNbr=ord.OrderNbr  
-- INNER JOIN dbo.OM_SalesOrdDet d WITH (NOLOCK) ON d.BranchID = ord.BranchID AND d.OrderNbr = ord.OrderNbr  
INNER JOIN dbo.OM_OrdDisc dis WITH (NOLOCK) ON dis.BranchID=d.BranchID AND dis.OrderNbr=d.OrderNbr AND d.LineRef IN (SELECT part FROM dbo.fr_SplitStringMAX(dis.GroupRefLineRef,','))  
INNER JOIN dbo.OM_DiscSeq sq WITH (NOLOCK) ON sq.DiscID=dis.DiscID AND sq.DiscSeq=dis.DiscSeq
)

SELECT DISTINCT 
d.BranchID,
d.OrderNbr,
d.InvtID,
d.LineRef,
d.FreeItemID,
d.FreeItemQty,
d.TypeDiscount,
d.DiscType,
d.TypeDiscount,
d.DiscAmt,
d.DiscPct,
d.DiscIDPN ,
d.DiscID,
d.DiscSeq   
-- INTO #TOrdDisc  
FROM #TOrdDisc1 d  
WHERE d.FreeItemID=''