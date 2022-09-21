select
so.BranchID,
so.OrderNbr,
so.OriOrderNbrUp,
so.CustID,
so.Crtd_DateTime,
so.LUpd_DateTime,
so.Crtd_User,
so.Status,
so.OrderType,
oo.ARDocType,
oo.Descr,
so.Crtd_Prog,
so.PaymentsForm,
so.BranchRouteID,
so.SalesRouteID,
so.InsertFrom,
so.Remark,
sod.LineQty,
sod.LineRef,
sod.SlsPerID,
sod.Invtid,
sod.FreeItem,
sod.BeforeVATPrice,
sod.AfterVATPrice,
sod.BeforeVATAmount,
sod.AfterVATAmount,
ib.DeliveryUnit
from OM_PDASalesOrd as so WITH(NOLOCK)
INNER JOIN dbo.OM_PDASalesOrdDet sod WITH(NOLOCK) ON 
so.BranchID = sod.BranchID AND sod.OrderNbr = so.OrderNbr
INNER JOIN dbo.OM_OrderType oo WITH(NOLOCK) ON oo.OrderType = so.OrderType
LEFT JOIN OM_Issuebookdet ibd ON
so.BranchID = ibd.BranchID and
so.OrderNbr = ibd.OrderNbr
LEFT JOIN OM_Issuebook ib ON
ibd.BranchID = ib.BranchID and
ibd.BatNbr = ib.BatNbr
where so.Crtd_DateTime >= '2022-04-01'
and so.Status in('C')
and ib.Status = 'C'
and ib.DeliveryUnit = 'TP'