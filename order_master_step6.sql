DECLARE @from DATE = '2022-05-10'
DECLARE @to DATE = '2022-05-01'

select
d.BranchID,
d.OrderNbr,
case when d.DeliveryUnit = 'CW' then N'Chành Xe'
when d.DeliveryUnit = 'PN' then N'Pha Nam' end dvvc,
d.SlsperID as manvgh,
[Status] = 'Đã Giao Hàng',
so.CustID,
so.InvcNbr,
so.InvcNote,
pso.Remark,
pso.Crtd_DateTime as post_time,
pso.Crtd_User as post_user,
ho.ErrorMessage as pending_reason,
pso.LUpd_DateTime as approve_time,
pso.LUpd_User as approve_user,
iv.LUpd_DateTime as invoice_time,
iv.LUpd_User as invoice_user,
d.Crtd_DateTime as booked_time,
d.Crtd_User as booked_user,
ready_to_ship_time = d.Crtd_DateTime,
d.Crtd_User as rts_user,
d.LUpd_DateTime as delivered_time,
d.SlsperID as delivered_user,
datediff(minute, pso.Crtd_DateTime, pso.LUpd_DateTime) as leadtime_t0_minute,
datediff(minute, pso.LUpd_DateTime, iv.LUpd_DateTime) as leadtime_t1_minute,
datediff(minute, iv.LUpd_DateTime, d.Crtd_DateTime) as leadtime_t2_minute,
datediff(minute, d.Crtd_DateTime, d.Crtd_DateTime) as leadtime_t3_minute,
datediff(minute, d.Crtd_DateTime, d.LUpd_DateTime) as leadtime_t4_minute,
datediff(minute, pso.Crtd_DateTime, d.LUpd_DateTime) as leadtime_full_minute

from OM_Delivery d
--split ra theo nhieu sku va hd
LEFT JOIN OM_SalesOrd so ON
d.BranchID = so.BranchID and
d.OrderNbr = so.OrigOrderNbr
LEFT JOIN OM_Issuebookdet ibd ON
d.BranchID = ibd.BranchID and
d.OrderNbr = ibd.OrderNbr
LEFT JOIN OM_Issuebook ib ON
ibd.BranchID = ib.BranchID and
ibd.BatNbr = ib.BatNbr
LEFT JOIN OM_PDASalesOrd pso ON
d.BranchID = so.BranchID and
d.OrderNbr = pso.OrderNbr
LEFT JOIN OM_Invoice iv on
so.BranchID = iv.BranchID and
so.InvcNbr = iv.InvcNbr and
so.InvcNote = iv.InvcNote and
so.ARRefNbr = iv.RefNbr
LEFT JOIN API_HistoryOM205 ho ON
d.BranchID = ho.BranchID and
d.OrderNbr = ho.OrderNbr
and ho.Status = 'E'
where d.Status in ('C','E')
and Cast(d.LUpd_DateTime as date) >= @from
--and Cast(d.Crtd_DateTime as date) >= '2022-04-01'
and datediff(minute, pso.LUpd_DateTime, iv.LUpd_DateTime) >= 0
Order By d.LUpd_DateTime DESC