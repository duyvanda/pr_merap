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
sod.AfterVATAmount
from OM_PDASalesOrd as so WITH(NOLOCK)
INNER JOIN dbo.OM_PDASalesOrdDet sod WITH(NOLOCK) ON 
so.BranchID = sod.BranchID AND sod.OrderNbr = so.OrderNbr
INNER JOIN dbo.OM_OrderType oo WITH(NOLOCK) ON oo.OrderType = so.OrderType
where so.Crtd_DateTime >= '2022-04-01'
and so.Status not in('C','E')