with phanquyen as (
  with max_phanquyen as (
  select manv,max(inserted_at) as max_inserted_at from `spatial-vision-343005.biteam.d_phanquyen_phanam`
group by 1 )

select distinct a.*
from `spatial-vision-343005.biteam.d_phanquyen_phanam` a
JOIN max_phanquyen b on a.manv=b.manv and a.inserted_at =b.max_inserted_at
),
phanquyen_email as 
(
  select distinct manv, email from phanquyen
),

--Data checkin mds
dms_checkin as (
with order_checkin_final as (
    -- Lay ra duoc thong tin abc
    with order_checkin as 
    (

    SELECT 
    branchid,
    slsperid,
    deordernbr,
    de_updatetime,
    numbercico,
    inserted_at
    FROM `spatial-vision-343005.biteam.sync_dms_decheckin` 
    ),

    max_order_checkin as 
    (
    select branchid,slsperid,deordernbr,max(de_updatetime) as max_de_updatetime from
    `spatial-vision-343005.biteam.sync_dms_decheckin`  group by 1,2,3
    )

    select a.* from order_checkin a
    JOIN max_order_checkin b on a.branchid =b.branchid and a.slsperid =b.slsperid 
    and a.deordernbr =b.deordernbr and a.de_updatetime =b.max_de_updatetime 
 ),

data_checkin as 
(
select slsperid,custid,branchid,lat,lng,typ,checktype,updatetime,numbercico 
from `spatial-vision-343005.biteam.d_checkin`
where date(updatetime) >= '2022-09-01'
),

checkin_note as
(
select * from `spatial-vision-343005.biteam.sync_dms_oc`
where date(visitdate) >= '2022-09-01'
)
/*
CL = Close
IO= In outlet
PS= Program Sales
SO= Sales ord vào step ghi nhận đơn hàng
PA= Thanh toán công nợ
OO= Out outlet
DP= trưng bày
SA= Có đơn hàng
FC= Feedback customer
PO = POSM/Gimmick
SK= Stock keeping
*/
SELECT  b.*,
a.typ as checkin,a.updatetime  as time_checkin,a.lat,a.lng,
c.typ as checkout, c.updatetime as time_checkout,
e.deordernbr
FROM 
checkin_note b
LEFT JOIN
data_checkin a
 on a.slsperid =b.slsperid and a.custid =b.custid and a.branchid =b.branchid
and b.salesid =a.numbercico and a.checktype ='IO'
LEFT JOIN
data_checkin c
 on c.slsperid =b.slsperid and c.custid =b.custid and c.branchid =b.branchid
and b.salesid =c.numbercico and c.checktype ='OO'
LEFT JOIN 
order_checkin_final e
on e.slsperid = b.slsperid and e.branchid =b.branchid and e.numbercico =b.salesid 
and b.checkintype ='Giao Hàng' 
),

-- Giải trình công nợ MDS

giaitrinh_mds as
(
select a.*,row_number() over (partition by a.madh order by a.ngay desc) as row_ from `spatial-vision-343005.biteam.d_giaitrinh_mds` a
order by a.madh desc
),


-- Phân quyền MDS, mapping giải trình vs checkin
bang_cong_no as (

SELECT 
a.branchid ||' - ' || a.ordernbr as filter_order,
a.branchid,a.ordernbr,
a.slsperid,
Case
    when b.nhanvien_thaythe is not null then b.nhanvien_thaythe 
    else b.manv end as slsperid_new,
a.slspername,
a.dateoforder as ngaydatdon,
a.channels as kenh,
a.subchannel as kenhphu,
a.vptt,
Case 
    when deli_last_updated ='1900-01-01 00:00:00' then datetime_sub((select timestamp(transaction_date) from `spatial-vision-343005.biteam.d_current_table`) ,interval 1 day ) 
    else deli_last_updated end as ngaygiaohang,
n.time_checkin as last_checkin,
n.time_checkout as last_checkout,
n.lat,
n.lng,
n.distance,
n.note as lydo,
n.descr as ghichu,
a.custid,
a.custname,
h.statedescr as tinh,
h.districtdescr as quan_huyen,
h.territorydescr as khu_vuc,
h.address,
h.attn as ng_lienhe,
h.phone,
a.terms,
a.paymentsform,
a.inchargename,
a.tienchotso,
a.tiengiaothanhcong,
a.tiennocongty,
a.tienthuquyxacnhan,
a.duedate,
Case when trangthaigiaohang ='NaN' then 'Chưa Xác Nhận' else a.trangthaigiaohang end as trangthaigiaohang,
Case 
    when trangthaigiaohang ='Đã giao hàng' and a.terms in ('Thu tiền ngay không có VP PN','Thu tiền ngay có VP PN','Gối Đầu 30 Pha Nam') then date_add(date(a.deli_last_updated) , interval 1 day)	 	
    when trangthaigiaohang not in ('Đã giao hàng') and a.terms in ('Thu tiền ngay không có VP PN','Gối Đầu 30 Pha Nam' ) then date_add(date(dateoforder) , interval 2 day) 
    when trangthaigiaohang not in ('Đã giao hàng') and a.terms in ('Thu tiền ngay có VP PN') then date_add(date(dateoforder) , interval 1 day) 
    else date(duedate) end as ngaytoihan1,

Case 
    when 
	( a.terms not in ('Thu tiền ngay có VP PN','Thu tiền ngay không có VP PN','Gối Đầu 30 Pha Nam') 
    and date(duedate) <= (select date(transaction_date) from `spatial-vision-343005.biteam.d_current_table`) )
	or

	( a.trangthaigiaohang = 'Đã giao hàng'and a.terms in ('Thu tiền ngay không có VP PN','Thu tiền ngay có VP PN','Gối Đầu 30 Pha Nam') 
	 and date_add(date(a.deli_last_updated) , interval 1 day) <= (select date(transaction_date) from `spatial-vision-343005.biteam.d_current_table`) 
	 )

	or ( trangthaigiaohang not in ('Đã giao hàng') and a.terms in ('Thu tiền ngay không có VP PN','Gối Đầu 30 Pha Nam')
	and date_add(date(dateoforder) , interval 2 day) <= (select date(transaction_date) from `spatial-vision-343005.biteam.d_current_table`) ) 

	or (trangthaigiaohang not in ('Đã giao hàng') and a.terms in ('Thu tiền ngay có VP PN')
	and date_add(date(dateoforder) , interval 1 day) <= (select date(transaction_date) from `spatial-vision-343005.biteam.d_current_table`) )
	
	then 'Đã tới hạn' else 'Chưa tới hạn' end as no_toi_han,

h.hcotypeid as mahco,
m.sdt,
m.giaitrinh,
m.ngay,
k.giaitrinh as giaitrinhtruocdo,
k.ngay as ngaytruocdo,
a.inserted_at  as updated_at
from `spatial-vision-343005.biteam.f_tracking_debt` a
LEFT JOIN phanquyen b on Left(a.slsperid,6) = b.manv
-- LEFT JOIN `spatial-vision-343005.biteam.d_kh` b on a.custid = b.custid
LEFT JOIN `spatial-vision-343005.biteam.d_master_khachhang` h on h.custid = a.custid
LEFT JOIN dms_checkin n on n.branchid = a.branchid and n.custid =a.custid and a.slsperid = n.slsperid and a.ordernbr = n.deordernbr 
LEFT JOIN giaitrinh_mds m on m.madh = a.ordernbr  and m.row_ = 1
LEFT JOIN giaitrinh_mds k on k.madh = a.ordernbr  and k.row_ = 2
where 
debtincharge_v2 ='MDS'  and tiennocongty > 1000 and a.slsperid <> 'GH001' 
and concat(a.branchid,a.ordernbr) not in ('MR0015DH072021-00313','MR0015DH102021-01252') --tracking debt lỗi còn 2 đơn này
),

result as (
select a.*except(slspername),
c.supid as ma_sup,
c.tencvbh as slspername,
c.tenquanlytt,c.tenquanlyvung,c.tenquanlykhuvuc,
Case when trim(upper(f.manv)) = trim(upper(c.asm)) then f.email else 'nhanvt92@gmail.com'end as email_mng,
Case when trim(upper(e.manv)) = trim(upper(c.supid))  then e.email else 'bimerap.main@gmail.com' end as email_sup,
Case when trim(upper(d.manv)) = trim(upper(a.slsperid_new)) then d.email else 'bimerap.main@gmail.com' end as email_staff
    from bang_cong_no a 
LEFT JOIN `spatial-vision-343005.biteam.d_users` c on c.manv =a.slsperid_new
LEFT JOIN phanquyen_email d on trim(upper(d.manv)) = trim(upper(a.slsperid_new))
LEFT JOIN phanquyen_email e on trim(upper(e.manv)) = trim(upper(c.supid)) 
LEFT JOIN phanquyen_email f on trim(upper(f.manv)) = trim(upper(c.asm)) 
)

select * from result 
	
	--where slspername like '%Khải%'