DECLARE @FromDate DATE = '20220101';
DECLARE @ToDate DATE = '20220119';

SELECT
top 1
log.BranchID,
log.CpnyName,
log.[Key],
log.CustID,
log.CustName,
log.CusTaxCode,
log.ArisingDate,
log.Pattern,
log.Serial,
log.Code as InvtID,
log.LotNbr,
log.VATRate,
log.VATAmount,
log.Line,
log.OrderDate,
log.TotalNoVat,
info.Code,
info.Desc1,
omso.OrderType,
omso.[Status],
omso.InvcNbr
from Log_InvoiceInfo as log
INNER JOIN IN_InfoRegisProduct as info ON
log.Code = info.InvtID
INNER JOIN IN_Inventory as Inv ON
log.Code = Inv.InvtID
INNER JOIN OM_SalesOrd as omso ON
log.BranchID = omso.BranchID AND
log.OrderNbr = omso.OrderNbr
WHERE log.OrderDate >= @FromDate and log.OrderDate <= @ToDate
