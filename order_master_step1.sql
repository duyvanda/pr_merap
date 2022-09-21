select
pso.BranchID,
pso.OrderNbr,
pso.OriOrderNbrUp,
pso.CustID,
pso.Crtd_DateTime,
pso.LUpd_DateTime,
pso.Crtd_User,
pso.Status,
pso.OrderType,
oo.ARDocType,
oo.Descr,
pso.Crtd_Prog,
pso.PaymentsForm,
pso.BranchRouteID,
pso.SalesRouteID,
pso.InsertFrom,
pso.Remark,
psod.LineQty,
psod.LineRef,
psod.SlsPerID,
psod.Invtid,
psod.FreeItem,
psod.BeforeVATPrice,
psod.AfterVATPrice,
psod.BeforeVATAmount,
psod.AfterVATAmount
from OM_PDASalesOrd as pso WITH(NOLOCK)
INNER JOIN dbo.OM_PDASalesOrdDet psod WITH(NOLOCK) ON 
psod.BranchID = pso.BranchID AND psod.OrderNbr = pso.OrderNbr
INNER JOIN dbo.OM_OrderType oo WITH(NOLOCK) ON oo.OrderType = pso.OrderType
where pso.Crtd_DateTime >= '2022-04-01'
and pso.Status in('H')

