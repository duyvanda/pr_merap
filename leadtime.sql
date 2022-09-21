select
a.BranchID,
a.OrderNbr,
b.CustID,
case when d.DeliveryUnit = 'CW' then N'Chành Xe'
when d.DeliveryUnit = 'PN' then N'Pha Nam' end DVVC,
a.SlsperID as MaNVGH,
a.Crtd_DateTime,
a.LUpd_DateTime,
[Status] = 'Đã Giao Hàng',
datediff(minute, a.Crtd_DateTime, a.LUpd_DateTime) as leadtime_minute
from OM_Delivery a
LEFT JOIN OM_SalesOrd b ON
a.BranchID = b.BranchID and
a.OrderNbr = b.OrigOrderNbr
LEFT JOIN OM_Issuebookdet c ON
a.BranchID = c.BranchID and
a.OrderNbr = c.OrderNbr
LEFT JOIN OM_Issuebook d ON
c.BranchID = d.BranchID and
c.BatNbr = d.BatNbr
where a.Status = 'C'
and Cast(a.Crtd_DateTime as date) >= '2022-04-01'