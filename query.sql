-- Create  or replace table `view_report.f_leadtime_new_detail1`
-- partition by date(ngaytaodon)
-- cluster by
-- tenkhachhang,
-- statedescr,
-- territorydescr,
-- nguoigiaohang
-- as

-----Tạo đơn hàng 
WITH
  data_so_huy_co as 
  (
    select branchid,ordernbr,custid,invcnbr,invcnote,orderdate from `biteam.sync_dms_so` where ordertype in ('CO','HK') and status ='C' 
  ),
  /* 
  Phát hành lại nhưng cùng 1 mã đơn hàng origordernbr, cùng ordertype ='IN'
  */
  data_huyhd_phathanhlai as 
(
  with data_huy_hoadon as (
select origordernbr,count(distinct invcnbr),count(distinct status) from `biteam.sync_dms_so` 
where crtd_datetime >="2021-05-01" --and ordertype ='IN'
group by 1 having count(distinct invcnbr) >1 and count(distinct status) >1
)
select 
  b.*,

dense_rank() over (partition by a.origordernbr order by b.origordernbr,b.status asc) as loc_dh
from data_huy_hoadon a
 JOIN `biteam.sync_dms_so` b on a.origordernbr =b.origordernbr
order by a.origordernbr,b.crtd_datetime desc
),

/*
Phát hành lại hóa đơn nhưng khác mã đơn hàng origordernbr, ordertype in( RP )
*/
  data_so_taolai as (select *
            from `biteam.sync_dms_so` where Status = 'C'  and  OrderType IN ('CO','DI','DM','IN','IR','LO','OO')
             and salesordertype in('RP')-- and OrderDate <'2022-08-02'
         ),

  data_so_huy as 
         (
           select OrderNbr,BranchID,CustID,InvoiceCustID,Version,OrigOrderNbr,ARBatNbr ,ARRefNbr,OrderDate ,PaymentsForm ,InvcNbr,InvcNote,OrderType
            from `biteam.sync_dms_so` where Status = 'V' --and OrderDate <'2022-08-02'
         ),

        data_so_mapping as 
        (
          select 
              a.branchid,
              ifnull(b.ordernbr,a.ordernbr) as ordernbr, 
              IFNULL(b.OrigOrderNbr,a.OrigOrderNbr) as OrigOrderNbr,
              a.custid,
              a.ordertype,
              a.arbatnbr,
              a.arrefnbr,
              a.inbatnbr,
              a.inrefnbr,
              a.invcnbr,
              a.invcnote,
              a.status as status_so,
              a.slsperid as slsperid_so,
              a.orderdate as orderdate_so,
              a.crtd_user as crtd_user_so,
              a.crtd_datetime as crtd_datetime_so,
              a.lupd_user as lupd_user_so,
              a.lupd_datetime as lupd_datetime_so,
              a.remark as remark_so

           from data_so_taolai a
          JOIN data_so_huy b 
          on a.branchid =b.branchid
          and a.ARBatNbr =b.ARBatNbr
          and a.ARRefNbr =b.ARRefNbr
        )
,

  pda_so AS (
  SELECT
  distinct
    branchid,
    ordernbr,
    custid,
    crtd_prog,
    status as status_pda_so,
    slsperid as slsperid_pda_so,
    crtd_user AS crtd_user_pda_so,
    crtd_datetime AS crtd_datetime_pda_so,
    lupd_datetime AS lupd_datetime_pda_so,
    lupd_user AS lupd_user_pda_so,
    remark AS remark_pda_so,
    deliverytime
  FROM
    `spatial-vision-343005.biteam.sync_dms_pda_so`
  WHERE
    DATE(crtd_datetime) >= "2021-05-01" and ordertype ='IN'

    )
    ,

    -- Duyệt đơn hàng
  dms_so AS (
  SELECT
  distinct
    branchid,
    ordernbr,
    origordernbr,
    custid,
    ordertype,
    arbatnbr,
    arrefnbr,
    inbatnbr,
    inrefnbr,
    invcnbr,
    invcnote,
    status as status_so,
    slsperid as slsperid_so,
    orderdate as orderdate_so,
    crtd_user as crtd_user_so,
    crtd_datetime as crtd_datetime_so,
    lupd_user as lupd_user_so,
    lupd_datetime as lupd_datetime_so,
    remark as remark_so
  FROM
    `spatial-vision-343005.biteam.sync_dms_so`
  WHERE
    DATE(crtd_datetime) >= "2021-05-01" --and ordertype ='IN'
    and origordernbr not in (select distinct origordernbr from data_huyhd_phathanhlai)
    and ordernbr not in (select distinct ordernbr from data_so_taolai)
    and origordernbr not in (select distinct origordernbr from data_so_mapping)

UNION ALL
select     
    b.branchid,
    b.ordernbr,
    b.origordernbr,
    b.custid,
    b.ordertype,
    b.arbatnbr,
    b.arrefnbr,
    b.inbatnbr,
    b.inrefnbr,
    b.invcnbr,
    b.invcnote,
    b.status as status_so,
    b.slsperid as slsperid_so,
    b.orderdate as orderdate_so,
    b.crtd_user as crtd_user_so,
    b.crtd_datetime as crtd_datetime_so,
    b.lupd_user as lupd_user_so,
    b.lupd_datetime as lupd_datetime_so,
    b.remark as remark_so
  from data_huyhd_phathanhlai b where loc_dh = 1

  UNION ALL 
  select * from data_so_mapping
    ),
  

mapping_so as
(
select a.*,
Case when c.ordernbr is not null then 'Hủy HĐ' else 'Không hủy HĐ' end as ordernbr_co, c.orderdate as orderdate_co
from dms_so a
LEFT JOIN data_so_huy_co c on c.invcnbr =a.invcnbr and c.branchid =a.branchid  and a.invcnote =c.invcnote and a.custid = c.custid
and a.ordertype in ('IN', 'IO', 'EP', 'NP')
),


    --Duyệt hóa đơn
dms_iv as (

select 
distinct
branchid,
	refnbr,
  	invcnbr,
    	invcnote,
      	crtd_datetime as crtd_datetime_iv,
        	lupd_user as lupd_user_iv,
          	lupd_datetime  as lupd_datetime_iv
       from      `spatial-vision-343005.biteam.sync_dms_iv`
       where crtd_datetime >='2021-05-01'
),

  -- Tạo sổ
  dms_ib AS (
  SELECT
  distinct
    branchid,
    truckid,
    batnbr,
    deliveryunit,
    slsperid as slsperid_ib,
    status as status_ib,
    issuedate as issuedate_ib,
    crtd_datetime as crtd_datetime_ib,
    crtd_user as crtd_user_ib,
    lupd_datetime as lupd_datetime_ib1,
        Case when date(approvedate) ='1900-01-01' then null else
    approvedate end as lupd_datetime_ib
    -- approvedate as lupd_datetime_ib
    
    -- đổi qua cột approvedate ngày 9/1/2023
  FROM
    `spatial-vision-343005.biteam.sync_dms_ib`
  WHERE
    DATE(crtd_datetime) >= "2021-05-01" ),

-- Chốt sổ
    dms_ibd AS (
  SELECT
  distinct
branchid,
	batnbr,
  	ordernbr,
    	status as status_ibd,
      	deliverytime as deliverytime_ibd,
        	crtd_datetime crtd_datetime_ibd,
            	crtd_user as crtd_user_ibd,
              	lupd_datetime as lupd_datetime_ibd,
                	transporters 
  FROM
    `spatial-vision-343005.biteam.sync_dms_ibd`
  WHERE
    DATE(crtd_datetime) >= "2021-05-01" ),

  mapping_ib as (
    select a.*,
    b.ordernbr,
    b.status_ibd,
    b.deliverytime_ibd,b.crtd_user_ibd,b.crtd_datetime_ibd,b.lupd_datetime_ibd,b.transporters
    from dms_ib a 
    LEFT JOIN dms_ibd b on a.branchid =b.branchid and a.batnbr =b.batnbr),    

dms_dv as (
select 
distinct
branchid,batnbr,
sequence,
ordernbr,slsperid as slsperid_dv,	status as status_dv,	
crtd_datetime as crtd_datetime_dv,crtd_user as crtd_user_dv,
delivery_date as lupd_datetime_dv,
inserted_at
 from `spatial-vision-343005.biteam.sync_dms_dv`where DATE(crtd_datetime) >= "2021-05-01"

),
-- mapping_dv as 

-- (
-- with data as (
-- select  *except(status,crtd_datetime,slsperid,lupd_datetime),status as status_dv,crtd_datetime as crtd_datetime_dv,
-- slsperid as slsperid_dv,lupd_datetime as lupd_datetime_dv ,slsperid as  crtd_user_dv ,
-- row_number() over (partition by ordernbr,branchid order by lupd_datetime desc) as loc_ 
-- from `biteam.sync_dms_delihistoryc` 
--  where 
--  status ='C' and crtd_datetime >='2022-01-01'
-- -- group by 1
-- -- having count(1) >1
-- )
-- select * from data where loc_ = 1
-- ),
max_sequence as (
select branchid,batnbr,ordernbr,max(sequence) as max_sequence ,max(crtd_datetime) as crtd_datetime
from `spatial-vision-343005.biteam.sync_dms_dv` group by 1,2,3 

),

mapping_dv as 
(
select a.* 
  from dms_dv a 
  JOIN max_sequence b on a.branchid = b.branchid and a.ordernbr = b.ordernbr and a.batnbr =b.batnbr and a.sequence = b.max_sequence
and b.crtd_datetime =a.crtd_datetime_dv
),

    --Lý do trì hoãn
  dms_error AS (
    SELECT
  distinct
    a.branchid,
    a.ordernbr,
    a.crtd_datetime as crtd_datetime_err,
    a.lupd_datetime as lupd_datetime_err,
    a.errormessage
  FROM
    `spatial-vision-343005.biteam.sync_dms_err` a
    JOIN (  SELECT
  distinct
    branchid,
    ordernbr,
    max(crtd_datetime) as max_crtd_datetime_err  FROM
    `spatial-vision-343005.biteam.sync_dms_err` group by 1,2) b 
    on a.branchid =b.branchid and a.ordernbr =b.ordernbr and a.crtd_datetime =b.max_crtd_datetime_err
  WHERE
    DATE(a.crtd_datetime) >= "2021-05-01"
 ),



/* *** Note ***
      IR','NI','OO','OC','RC': Không đi qua PDA --> crtd_datetime_so ::ngày tạo đơn
      Đi qua PDA:--> crtd_datetime_pda_so:: ngày tạo đơn 
      crtd_datetime_so :: ngày duyệt đơn
      lupd_datetime_iv :: ngày duyệt hóa đơn ( ngày chứng từ ::datetime )
          Nếu ngày chứng từ > ngày giao hàng ---> ngày chứng từ = lupd_datetime_pda_so
      lupd_datetime_ib :: ngày tạo sổ 
      lupd_datetime_ibd:: ngày chốt sổ
      lupd_datetime_dv::  ngày giao
      orderdate_so :: ngày chứng từ(date)
      --
       -- Trạng thái đơn hàng
      Status pda_so			      Status so			    Invnbr (invoice)			  Status IB		  	    			            Status DV	
      C	Đã duyệt đơn hàng		  C	Đã phát hành		blank	    K có hóa đơn	C	Đã chốt sổ	       		              A	Đã xác nhận
      E	Đóng đơn hàng	      	V	Hủy đơn hàng		no blank	Có hóa đơn	  H	Chưa xác nhận	  			              C	Đã giao hàng
      D	Đơn hàng tạm		      I	Tạo hóa đơn					                    Blank	: Chưa tạo sổ		   			        D	KH không nhận
      H	Chờ xử lý		          N	Tạo hóa đơn											                                              H	Chưa xác nhận
      V Hủy đơn hàng          H	Chờ xử lý									                                                 		L	
      blank		               	E	Đóng đơn hàng										                                             	R	Từ chối giao hàng
                              D	Đơn hàng tạm									                                                E	Không tiếp tục giao hàng
      */

order_detail as (
  with dms_pda_sod as (
  SELECT
  branchid,
  ordernbr,
  freeitem,
  lineref,
  invtid,
  lineqty,
  ordertype,
  siteid,
  crtd_user,
  slsperid,
  beforevatprice,
  beforevatamount,
  aftervatprice,
  aftervatamount,
  vatamount
FROM
  `spatial-vision-343005.biteam.sync_dms_pda_sod`
WHERE
  DATE(crtd_datetime) >= "2021-05-01"
  --MR2448
),

dms_sod1 as (
  SELECT
  branchid,
  ordernbr,
  origordernbr,
  lineref,
  originallineref,
  invtid,
  lineqty,
  ordertype,
  freeitem,
  siteid,
  crtd_user,
  slsperid,
  beforevatprice,
  beforevatamount,
  aftervatprice,
  aftervatamount,
  vatamount,
  discamt,
  docdiscamt,
  groupdiscamt1
FROM
  `spatial-vision-343005.biteam.sync_dms_sod1`
WHERE
  DATE(crtd_datetime) >= "2021-05-01"
)

select 
  a.branchid,
  a.ordernbr,
  b.ordernbr as ordernbr_mapping,
  Case when b.lineref is not null then b.lineref else
  a.lineref end as lineref,
  a.invtid,
  Case when b.lineqty is not null then b.lineqty else 
  a.lineqty end as lineqty,
  b.ordertype,
  a.siteid,
  a.crtd_user,
  b.slsperid,
  a.beforevatprice ,
   Case when b.beforevatamount is not null then b.beforevatamount
        when b.freeitem = true then 0 else 
        a.beforevatamount end as beforevatamount,
  a.aftervatprice,
   Case 
   when b.aftervatamount is not null then b.aftervatamount
   when b.freeitem = true then 0 else 
  a.aftervatamount end as aftervatamount,
  a.vatamount,
  a.freeitem,
  Case when b.discamt is null then 0 else b.discamt end as discamt,
  Case when b.docdiscamt is null then 0 else b.docdiscamt end as docdiscamt,
  Case when b.groupdiscamt1 is null then 0 else b.groupdiscamt1 end as groupdiscamt1
  from dms_pda_sod a
left join dms_sod1 b on a.branchid =b.branchid and a.ordernbr =b.origordernbr and a.invtid =b.invtid and b.originallineref =a.lineref 
),

dms_checkin as 
(
with order_checkin as (
  with order_checkin as (

  SELECT 
  branchid,
  	slsperid,
    	deordernbr,
      	de_updatetime,
        	numbercico,
          	inserted_at
 FROM `spatial-vision-343005.biteam.sync_dms_decheckin` ),

 max_order_checkin as (
select branchid,slsperid,deordernbr,max(de_updatetime) as max_de_updatetime from
`spatial-vision-343005.biteam.sync_dms_decheckin`  group by 1,2,3

 )

 select a.* from order_checkin a
 JOIN max_order_checkin b on a.branchid =b.branchid and a.slsperid =b.slsperid 
 and a.deordernbr =b.deordernbr and a.de_updatetime =b.max_de_updatetime ),

 data_checkin as (
  select slsperid,custid,branchid,lat,lng,typ,checktype,updatetime,numbercico 
  from `spatial-vision-343005.biteam.d_checkin`
  where updatetime >'2021-05-01'
),

sales_checkin as 
(
	select * from `spatial-vision-343005.biteam.sync_dms_sacheckin`
),

checkin_note as (
  select * from (
  select custid,
  	visitdate,
    	noteid,
      	slsperid,
				branchid,
        	note,
          	descr,
            	salesid,
              	distance,
                	checkintype,
                  	imagefilename,
                    	inserted_at,
											row_number() over(partition by slsperid,salesid order by branchid desc) as row_
   from `spatial-vision-343005.biteam.sync_dms_oc`
  where date(visitdate) >= "2022-01-01"  ) a where row_=1 
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



SELECT  
distinct
b.*,
a.typ as checkin,
Case when a.updatetime is null then b.visitdate else 
a.updatetime  end as time_checkin,
a.lat,a.lng,
c.typ as checkout, 
c.updatetime  as time_checkout,
--c.lat as lat_out, c.lng as lng_out,
-- d.typ as action, d.updatetime as time_action ,

-- Case when d.typ ='PA' and e.deordernbr is not null then 'Giao hàng'
-- 		 when d.typ like 'DE%'  then 'Giao hàng'
-- 		 when d.typ ='PA' and e.deordernbr is  null then 'Thanh toán công nợ'
-- 		 when d.typ ='CL' then 'Close'
-- 		 when d.typ ='IO' then 'In outlet'
-- 		 when d.typ ='PS' then 'Program Sales'
-- 		 when d.typ ='SO' then 'Sales ord vào step ghi nhận đơn hàng'
-- 		 when d.typ ='OO' then 'Out outlet'
-- 		 when d.typ ='DP' then 'trưng bày'
-- 		 when d.typ ='SA' then 'Có đơn hàng'
-- 		 when d.typ ='FC' then 'Feedback customer'
-- 		 when d.typ ='PO' then 'POSM/Gimmick'
-- 		 when d.typ ='SK' then 'Stock keeping'
-- else null end as phanloai_checkin,
--d.lat as lat_action, d.lng as lng_action
-- Case when d.typ like 'DE%' then substr(d.typ, 3)
-- else
-- e.deordernbr end as deordernbr,
Case when b.checkintype ='Bán Hàng' then f.saordernbr
		 when b.checkintype ='Giao Hàng' then e.deordernbr
		 else null end as ordernbr,
e.deordernbr,
f.saordernbr,
f.ordamt,
h.tencvbh as mds,
h.tenquanlytt,
h.tenquanlykhuvuc,
h.tenquanlyvung,
k.custname,
k.statedescr,
k.territorydescr,
k.address,
k.classid,
k.hcotypeid,
g.role
FROM 
checkin_note b
LEFT JOIN
data_checkin a
 on a.slsperid =b.slsperid and a.custid =b.custid --and a.branchid =b.branchid
and b.salesid =a.numbercico and a.checktype ='IO'
LEFT JOIN
data_checkin c
 on c.slsperid =b.slsperid and c.custid =b.custid --and c.branchid =b.branchid
and b.salesid =c.numbercico and c.checktype ='OO'
-- LEFT JOIN
-- data_checkin d
--  on d.slsperid =b.slsperid and d.custid =b.custid and d.branchid =b.branchid
-- and b.salesid =d.numbercico and d.checktype ='MaxAction'
LEFT JOIN 
order_checkin e
on e.slsperid = b.slsperid --and e.branchid =b.branchid 
and e.numbercico =b.salesid 
and b.checkintype ='Giao Hàng'--and (d.typ ='PA' or d.typ like 'DE%')
LEFT JOIN 
sales_checkin f on f.numbercico = b.salesid and f.slsperid = b.slsperid --and f.branchid =b.branchid 
and b.checkintype ='Bán Hàng'
--and a.checktype ='MaxAction' 
--Position=CASE WHEN s.Position IN ('S','SS','AM','RM') THEN 'P.BH' 
--WHEN s.Position IN ('D','SD','AD','RD') THEN 'MDS' ELSE s.Position END
LEFT JOIN `spatial-vision-343005.biteam.d_dms_master_users` g on g.username = b.slsperid  
LEFT JOIN `spatial-vision-343005.biteam.d_users` h on h.manv = b.slsperid
LEFT JOIN `spatial-vision-343005.biteam.d_master_khachhang` k on k.custid = b.custid and k.branchid = b.branchid 
where --g.role in ('MDS','LOG') and 
k.custname is not null --and b.salesid='e5ac84d6-d866-49c5-b3e-82d6ef270bf8'

),


result as (
SELECT
    Case when a.crtd_prog= 'eCom'then 'Y'
    else 'N' end as check_ecom,
    b.ordernbr_co,
    a.branchid,
    a.ordernbr,
    b.invcnbr,
    d.truckid,
    b.ordernbr as origordernbr,
    a.custid,b.ordertype,
    Case when b.status_so ='C' then 'Đã phát hành'
         when b.status_so ='V' then 'Hủy hóa đơn'
         when b.status_so ='I' then 'Tạo hóa đơn'
         when b.status_so ='N' then 'Tạo hóa đơn'
         when b.status_so ='H' then 'Chờ xử lý'
         when b.status_so ='E' then 'Đóng đơn hàng'
         when b.status_so ='D' then 'Đơn hàng tạm'
         else null end as status_so, --Chưa dùng

    b.orderdate_so,
    b.crtd_user_so, 
    b.crtd_datetime_so,b.lupd_datetime_so,b.remark_so,
    Case when a.status_pda_so ='C' then 'Đã duyệt đơn hàng'
         when a.status_pda_so ='E' then 'Đóng đơn hàng'
         when a.status_pda_so ='D' then 'Đơn hàng tạm'
         when a.status_pda_so ='H' then 'Chờ xử lý duyệt đơn hàng'
         when a.status_pda_so ='V' then 'Hủy đơn hàng'
         when a.status_pda_so ='X' then 'Đóng đơn hàng tạm'
         else null end as status_pda_so, -- Trạng thái đơn hàng
    a.slsperid_pda_so, -- Người bán hàng
    b.slsperid_so,
    a.crtd_datetime_pda_so as ngaytaodon, -- Ngày tạo đơn
    a.crtd_user_pda_so, -- Người tạo đơn
    Case when  a.status_pda_so in ('C','V','E') then
    a.lupd_datetime_pda_so  else null end as ngayduyetdon, -- Ngày duyệt đơn
    a.crtd_datetime_pda_so,
    a.lupd_datetime_pda_so, 
    Case when a.status_pda_so in('C','E','V') then
    a.lupd_user_pda_so else null end as lupd_user_pda_so, -- Người duyệt đơn
    a.remark_pda_so,
    a.deliverytime,
    -- c.refnbr,c.invcnbr,
    -- Case when c.invcnbr is not null or c.invcnbr <> '' then 'Đã phát hành HĐ'
    --     else 'Chưa phát hành HĐ' end as status_iv,
    Case when b.status_so ='C' then 'Đã phát hành hóa đơn'
         when b.status_so ='V' then 'Hủy hóa đơn'
         when b.status_so ='I' then 'Tạo hóa đơn'
         when b.status_so ='N' then 'Tạo hóa đơn'
         when b.status_so ='H' then 'Chờ xử lý hóa đơn'
         when b.status_so ='E' then 'Đóng đơn hàng'
         when b.status_so ='D' then 'Đơn hàng tạm'
         when b.status_so is null and a.status_pda_so ='C' then 'Chưa tạo HĐ ảo'
         when b.status_so is null and 
               a.status_pda_so ='E' then 'Đóng đơn hàng'
         when b.status_so is null and a.status_pda_so ='D' then 'Đơn hàng tạm'
         when b.status_so is null and  a.status_pda_so ='H' then 'Chờ xử lý duyệt đơn hàng'
         when b.status_so is null and  a.status_pda_so ='V' then 'Hủy đơn hàng' 
         when b.status_so is null and  a.status_pda_so ='X' then 'Đóng đơn hàng tạm' 
         else null end as status_iv, -- Trạng thái phát hành hóa đơn
    -- c.crtd_datetime_iv,
    -- Case when b.status_so in ('C') then  
    Case when b.status_so = 'C' then b.orderdate_so 
    else null end as ngayphathanhhd, -- Ngày phát hành hóa đơn
    -- Case when b.status_so in('C') then 
    b.lupd_user_so  as lupd_user_so, -- Người phát hành hóa đơn

    Case  
          when  d.status_ib ='C' then 'Đã chốt sổ'
          when  d.status_ib ='H' then 'Chưa xác nhận chốt sổ'
          else null end as status_ib, -- Trạng thái tạo sổ
      
    d.crtd_user_ib as crtd_user_ib, -- Người tạo sổ
    d.slsperid_ib,
    d.crtd_datetime_ib as ngaytaoso, -- Ngày tạo sổ
    d.lupd_datetime_ib,
        Case when d.status_ib ='C' and d.deliveryunit ='TP'  then d.crtd_user_ib
            when d.status_ib ='C' then e.crtd_user_dv 
    else null end as crtd_user_dv,  -- Người chốt sổ
     Case when d.status_ib ='C' and d.deliveryunit ='TP' then ifnull(d.lupd_datetime_ib,ifnull(e.crtd_datetime_dv,d.lupd_datetime_ib1))
          when d.status_ib ='C' and e.status_dv <> 'C' then ifnull(d.lupd_datetime_ib,ifnull(e.crtd_datetime_dv,d.lupd_datetime_ib1)) --e.crtd_datetime_dv
          when d.status_ib ='C' and e.status_dv ='C' then ifnull(d.lupd_datetime_ib,ifnull(e.crtd_datetime_dv,d.lupd_datetime_ib1)) --and d.lupd_datetime_ib <= e.crtd_datetime_dv 
          -- when d.status_ib ='C' and e.status_dv ='C' and d.lupd_datetime_ib > e.crtd_datetime_dv then e.crtd_datetime_dv
      else null end as ngaychotso, -- Ngày chốt sổ

    d.batnbr,
    -- d.deliverytime_ibd,d.crtd_user_ibd,d.crtd_datetime_ibd,
    case when d.deliveryunit = 'CW' then 'Chành Xe'
          when d.deliveryunit = 'PN' then 'Pha Nam' 
          when d.deliveryunit = 'TP' then 'NVC' else null end as deliveryunit,

    Case when e.status_dv ='C' then 'Đã giao hàng'
         when d.status_ib ='C'  and d.deliveryunit ='TP' then 'Đã giao hàng'
         when e.status_dv ='A' then 'Đã xác nhận - Sẵn sàng giao' -- Đã chốt sổ
        when e.status_dv ='D' then 'KH không nhận'
         when e.status_dv ='H' then 'Chưa xác nhận' -- Chưa chốt sổ
        when e.status_dv ='R' then 'Từ chối giao hàng'
        when e.status_dv ='E' then 'Không tiếp tục giao hàng'
        
        else null end as status_dv,	 -- Trạng thái giao hàng
    e.crtd_datetime_dv,
    -- Case when  e.status_dv in ('C','A','D','R','E') then 'Đã chốt sổ'
    --      else 'Chưa chốt sổ' end as status_ibd, -- Trạng thái chốt sổ
    -- Case when e.status_dv in ('C','A','D','R','E') then e.crtd_user_dv 
    -- else null end as crtd_user_dv,  -- Người chốt sổ
    -- Case when e.status_dv in ('C','A','D','R','E') and d.crtd_datetime_ib <= e.crtd_datetime_dv then e.crtd_datetime_dv
    --     when e.status_dv in ('C','A','D','R','E') and d.crtd_datetime_ib > e.crtd_datetime_dv then d.crtd_datetime_ib
    --   else null end as ngaychotso, -- Ngày chốt sổ
    Case when e.status_dv in ('C','D','R','E','A','H','L') then 
    e.slsperid_dv else null end as slsperid_dv, -- Người giao hàng
    Case when e.status_dv in ('C') then 
    e.lupd_datetime_dv else null end as ngaygiaohang, -- Ngày giao hàng
    f.crtd_datetime_err,f.lupd_datetime_err, f.errormessage,
   (select max(inserted_at) from `biteam.sync_dms_so`) as inserted_at
FROM
   pda_so a  
LEFT JOIN mapping_so b on a.ordernbr = b.origordernbr and a.branchid =b.branchid
-- LEFT JOIN dms_iv c on b.branchid = c.branchid and b.arrefnbr = c.refnbr and b.invcnbr =c.invcnbr
LEFT JOIN mapping_ib d on d.branchid = a.branchid and a.ordernbr = d.ordernbr
LEFT JOIN mapping_dv e on e.branchid = a.branchid and e.ordernbr = a.ordernbr and d.batnbr =e.batnbr
-- LEFT JOIN mapping_dv1 e on e.branchid = a.branchid and e.ordernbr = a.ordernbr and d.batnbr =e.batnbr
LEFT JOIN dms_error f on f.branchid = a.branchid and f.ordernbr = a.ordernbr
-- where b.status_so <> 'V'
-- and a.status_pda_so <> 'V'
),

/* 
CW:: Chành xe
PN:: Pha nam
TP:: Giao NVC

ngaytaodon --t0->duyệt đơn --t1->phát hành hđ --t2-> tạo sổ --t3-> chốt sổ --t4-> giao hàng

phát hành hd --t3_1->chốt sổ

      Crtd_User_so as post_user,
      LUpd_User_pda as approve_user,
      LUpd_User_iv as invoice_user,
      Crtd_User_dv as booked_user,
      Crtd_User_dv as rts_user,
      SlsperID_dv as delivered_user,
*/

--  select * from result --where ordernbr ='DH6-0222-00879'

result1 as (

select 
distinct a.*,

--Update trạng thái đơn hàng theo rule của a Duy (https://docs.google.com/spreadsheets/d/1TpCkVTaQr-FSmPGz1wBhZbS0xNGtgm7uMmtB0d9VyAU/edit#gid=1390105566)
-- coalesce(a.status_dv,a.status_ib,a.status_iv,a.status_pda_so) as trangthaidon,
Case when a.status_pda_so ='Đóng đơn hàng' then 'Đóng đơn hàng'
     when a.status_pda_so ='Đóng đơn hàng tạm' then 'Đóng đơn hàng'
     when a.status_iv ='Đã phát hành hóa đơn' and a.ordernbr_co ='Hủy HĐ' and status_dv is null then 'Hủy hóa đơn'
     when a.status_iv ='Hủy hóa đơn' then 'Hủy hóa đơn'
     when a.status_iv ='Đã phát hành hóa đơn' and status_ib = 'Đã chốt sổ' and status_dv ='Đã giao hàng' and status_pda_so = 'Đã duyệt đơn hàng' 
     then 'Đã giao hàng'
     when a.status_iv ='Đã phát hành hóa đơn' and status_ib = 'Đã chốt sổ' and status_dv ='Không tiếp tục giao hàng' then 'Không tiếp tục giao hàng'
     when a.status_iv ='Đã phát hành hóa đơn' and status_ib = 'Đã chốt sổ' and status_dv ='Chưa xác nhận' then 'Đã chốt sổ'
     when a.status_iv ='Đã phát hành hóa đơn' and status_ib = 'Đã chốt sổ' and status_dv ='Đã xác nhận' then 'Xác nhận (Nhận hàng)'
     when a.status_iv ='Đã phát hành hóa đơn' and status_ib = 'Đã chốt sổ' and status_dv not in ('Đã giao hàng','Không tiếp tục giao hàng')
      then 'Xác nhận (Nhận hàng)'
     when a.status_iv ='Đã phát hành hóa đơn' and status_ib = 'Đã chốt sổ' then 'Đã chốt sổ'
     when a.status_iv ='Đã phát hành hóa đơn' and (status_ib not in ( 'Đã chốt sổ' ) or status_ib is null ) then 'Đã phát hành hóa đơn'
     when a.status_iv not in ('Đã phát hành hóa đơn','Hủy hóa đơn') and status_pda_so ='Đã duyệt đơn hàng' then 'Đã duyệt đơn hàng'
     when a.status_iv not in ('Đã phát hành hóa đơn','Hủy hóa đơn') and status_pda_so not in ('Đã duyệt đơn hàng') then 'Tạo mới'


else null 
end as trangthaidon,


 Case when ngayduyetdon is null  then null
      else round(datetime_diff(ngayduyetdon,ngaytaodon,minute)/60,2) end as t0,
 Case when ngayphathanhhd is null then null
      else round(datetime_diff(ngayphathanhhd,ngayduyetdon,minute)/60,2) end as t1,
 Case when ngaytaoso is null then null
      else round(datetime_diff(ngaytaoso,ngayphathanhhd,minute)/60,2) end as t2,
  Case when ngaychotso is null then null
      else round(datetime_diff(ngaychotso,ngaytaoso,minute)/60,2) end as t3,  
  Case when ngaychotso is null then null
      else round(datetime_diff(ngaychotso,ngayduyetdon,minute)/60,2) end as t3_1,      
  Case when ngaygiaohang is null then null
      else round(datetime_diff(ngaygiaohang,ngaychotso,minute)/60,2) end as t4,
  Case when status_ib='Đã chốt sổ' and a.deliveryunit ='NVC' 
      then round(datetime_diff(ngaychotso,ngaytaodon,minute)/60,2)
      when ngaygiaohang is null then null
      else round(datetime_diff(ngaygiaohang,ngaytaodon,minute)/60,2) end as full_leadtime ,  

  Case when extract(DAYOFWEEK from ngaytaodon) >= 2 and 
            extract(DAYOFWEEK from ngaytaodon) <5 then datetime_add(ngaytaodon,interval 36 hour) --đơn hàng từ thứ 2 đến thứ 4
       when extract(DAYOFWEEK from ngaytaodon) = 5 and 
            extract(hour from ngaytaodon) < 12 then datetime_add(ngaytaodon,interval 36 hour) -- đơn hàng ngày thứ 5 trước 12h trưa

       when extract(DAYOFWEEK from ngaytaodon) = 5 and 
            extract(hour from ngaytaodon) >= 12 then datetime_add(ngaytaodon,interval 72 hour) -- đơn hàng ngày thứ 5 sau 12h trưa
       when extract(DAYOFWEEK from ngaytaodon) = 6 and 
            extract(hour from ngaytaodon) < 12 then datetime_add(ngaytaodon,interval 72 hour) -- đơn hàng ngày thứ 6 trước 12h trưa

       when extract(DAYOFWEEK from ngaytaodon) = 6 and 
            extract(hour from ngaytaodon) >= 12 then datetime_add(ngaytaodon,interval 84 hour)  -- đơn hàng ngày thứ 6 sau 12h trưa
       when extract(DAYOFWEEK from ngaytaodon) = 7 and 
            extract(hour from ngaytaodon) < 12 then datetime_add(ngaytaodon,interval 84 hour) -- đơn hàng ngày thứ 7 trước 12h

       when extract(DAYOFWEEK from ngaytaodon) = 7 and 
            extract(hour from ngaytaodon) >= 12 then datetime_add( datetime_trunc(ngaytaodon,day) , interval 84 hour)
            -- đơn hàng ngày thứ 7 sau 12h

       when extract(DAYOFWEEK from ngaytaodon) = 1 then datetime_add( datetime_trunc(ngaytaodon,day) , interval 60 hour)
       -- đơn hàng ngày chủ nhật
       
  else null end as ship_on_time_sla,

  Case when b.firstname is null then a.crtd_user_pda_so else
  b.firstname end as nguoitaodon,

  Case when c.firstname is null then a.lupd_user_pda_so else
  c.firstname end as nguoiduyetdon,

  Case when d.firstname is null then a.lupd_user_so else
  d.firstname end as nguoiphathanhhd,

  Case when e.firstname is null then  a.crtd_user_ib else
  e.firstname end as nguoitaoso,
  Case when f.firstname is null then  a.crtd_user_dv else
  f.firstname end as nguoichotso,
  Case when g.firstname is null then  a.slsperid_dv else
  g.firstname end as nguoigiaohang,
  Case when k1.firstname is null then  a.slsperid_pda_so else
  k1.firstname end as nguoibanhang,
  -- -- Thông tin khách hàng
  h.custname as tenkhachhang,
  -- h.branchid,
  
  Case when a.branchid in('MR0001','HCM001') then 'Hồ Chí Minh'
       when a.branchid ='MR0003' then 'CÔNG TY TNHH MTV DƯỢC PHA NAM HÀ NỘI'
       when a.branchid in('MR0014','KHA014') then 'Khánh Hòa'
       when a.branchid in('MR0015','DNI015') then 'Đồng Nai'
       when a.branchid ='MR0011' then 'Hải Phòng'
       when a.branchid in('MR0012','NAN012') then 'Nghệ An'
       when a.branchid in('MR0010','HNI010') then 'Hà Nội'
       when a.branchid in('MR0013','DNG013') then 'Đà Nẵng'
       when a.branchid in('MR0016','CTO016') then 'Cần Thơ'
  else h.branchname  
  end as branchname_filter,
  concat(a.branchid,'-',a.ordernbr) as filter_order ,
  h.branchname,
  h.terms,
  h.paymentsform,
  h.channel, --kênh
  h.statedescr, --tỉnh
  h.territorydescr, --khu vuc
  h.active,
  h.phone,
  h.attn as nglienhe,
   k.lineref,
  -- h.custid,
  h.refcustid,
  h.classid,
  h.hcotypeid,
  h.address as addr1,
  h.shoptype, --kênh phụ
  h.districtdescr,
  h.wardname,
  k.invtid,
  k.lineqty,
  Case when k.freeitem = true then 'Hàng tặng'
  else 'Hàng bán' end as freeitem,
  k.siteid,
  k.beforevatprice,
  k.beforevatamount,
  k.aftervatprice,
  k.aftervatamount,
  k.vatamount,
  Case when k.discamt is null then 0 else k.discamt end as discamt,
  Case when k.docdiscamt is null then 0 else k.docdiscamt end as docdiscamt,
  Case when k.groupdiscamt1 is null then 0 else k.groupdiscamt1 end as groupdiscamt1,
  j.lotsernbr,
  j.expdate,
  o.descr1 as tensp_viettat,
  o.descr as tensp_daydu,
  o.status as status_product,
  o.stkunit as unit_product,
  ot.descr as thongtinxe,
  Case when rd.ordernbr=a.ordernbr and a.branchid =rd.branchid and rd.custid = a.custid then rd.deliveryunit
      when dr.ordernbr=a.ordernbr and a.branchid =dr.branchid and dr.custid = a.custid then dr.deliveryunit
      else null end as deliveryunit_code,
  k.slsperid,
  k2.discidpn as ma_chuongtrinh,
  k2.descr as ten_chuongtrinh,
  k2.typediscount as loai_chuongtrinh,
  Case when typediscount in ("['AC', 'AC']" ,"['AC']","['AC', 'AC', 'AC']" ) then 'Chính sách tích lũy'
        when typediscount in ("['PR', 'PR', 'PR']","['PR']","['PR', 'PR']") then 'Chính sách khuyến mãi'
        when typediscount in ("['SP', 'SP', 'SP']","['SP', 'SP']","['SP']") then 'Chính sách bán hàng' 
       when typediscount like '%PR%' and typediscount like '%SP%' then "Chính sách khuyến mãi + bán hàng"
       when typediscount like '%PR%' and typediscount like '%AC%' then "Chính sách khuyến mãi + tích lũy"
       when typediscount like '%SP%' and typediscount like '%AC%' then "Chính sách bán hàng + tích lũy"
       when typediscount like '%SP%' and typediscount like '%AC%' and typediscount like '%PR%' then "Chính sách bán hàng + tích lũy + khuyễn mãi"
       else null end as loai_chinhsach,

  Case when typediscount1 ='AC' and typediscount2 is null and typediscount3 is null  then  k2.descr1
        when typediscount1 ='AC' and typediscount2 <> 'AC' and typediscount3 is null  then  k2.descr1
       when typediscount1 ='AC' and typediscount2 ='AC' and typediscount3 is null then concat(k2.descr1,', ',k2.descr2)
       when typediscount1 ='AC' and typediscount2 ='AC' and typediscount3 ='AC' then concat(k2.descr1,', ',k2.descr2,', ',k2.descr3)
       when typediscount1 <>'AC' and typediscount2 ='AC' and typediscount3 is null then k2.descr2
       when typediscount1 <>'AC' and typediscount2 ='AC' and typediscount3 ='AC' then concat(k2.descr2,', ',k2.descr3)
        when typediscount1 <>'AC' and typediscount2 <>'AC' and typediscount3 ='AC' then k2.descr3
       else null end as chinhsach_tichluy,
   Case when typediscount1 ='SP' and typediscount2 is null and typediscount3 is null  then  k2.descr1
        when typediscount1 ='SP' and typediscount2 <> 'SP' and typediscount3 is null  then  k2.descr1
       when typediscount1 ='SP' and typediscount2 ='SP' and typediscount3 is null then concat(k2.descr1,', ',k2.descr2)
       when typediscount1 ='SP' and typediscount2 ='SP' and typediscount3 ='SP' then concat(k2.descr1,', ',k2.descr2,', ',k2.descr3)
       when typediscount1 <>'SP' and typediscount2 ='SP' and typediscount3 is null then k2.descr2
       when typediscount1 <>'SP' and typediscount2 ='SP' and typediscount3 ='SP' then concat(k2.descr2,', ',k2.descr3)
        when typediscount1 <>'SP' and typediscount2 <>'SP' and typediscount3 ='SP' then k2.descr3
       else null end as chinhsach_banhang,
    Case when typediscount1 ='PR' and typediscount2 is null and typediscount3 is null  then  k2.descr1
        when typediscount1 ='PR' and typediscount2 <> 'PR' and typediscount3 is null  then  k2.descr1
       when typediscount1 ='PR' and typediscount2 ='PR' and typediscount3 is null then concat(k2.descr1,', ',k2.descr2)
       when typediscount1 ='PR' and typediscount2 ='PR' and typediscount3 ='PR' then concat(k2.descr1,', ',k2.descr2,', ',k2.descr3)
       when typediscount1 <>'PR' and typediscount2 ='PR' and typediscount3 is null then k2.descr2
       when typediscount1 <>'PR' and typediscount2 ='PR' and typediscount3 ='PR' then concat(k2.descr2,', ',k2.descr3)
        when typediscount1 <>'PR' and typediscount2 <>'PR' and typediscount3 ='PR' then k2.descr3
       else null end as chinhsach_khuyenmai, 

 from result a
LEFT JOIN `spatial-vision-343005.biteam.d_dms_master_users` b on a.crtd_user_pda_so = b.username
LEFT JOIN `spatial-vision-343005.biteam.d_dms_master_users` c on c.username = a.lupd_user_pda_so
LEFT JOIN `spatial-vision-343005.biteam.d_dms_master_users` d on d.username = a.lupd_user_so
LEFT JOIN `spatial-vision-343005.biteam.d_dms_master_users` e on e.username = a.crtd_user_ib
LEFT JOIN `spatial-vision-343005.biteam.d_dms_master_users` f on f.username = a.crtd_user_dv
LEFT JOIN `spatial-vision-343005.biteam.d_dms_master_users` g on g.username = a.slsperid_dv
LEFT JOIN `spatial-vision-343005.biteam.d_dms_master_users` k1 on k1.username = a.slsperid_pda_so
LEFT JOIN `spatial-vision-343005.biteam.d_master_khachhang` h on h.custid = a.custid --and h.branchid =a.branchid
-- LEFT JOIN order_detail l on l.branchid =a.branchid and l.ordernbr_mapping =a.origordernbr 
-- LEFT JOIN `spatial-vision-343005.biteam.d_dms_master_invtid` m on m.invtid = l.invtid
-- LEFT JOIN `spatial-vision-343005.biteam.sync_dms_lt` n on n.branchid = l.branchid and l.ordernbr_mapping = n.ordernbr and n.omlineref = l.lineref
-- LEFT JOIN `spatial-vision-343005.biteam.sync_dms_ot` ot on ot.branchid=a.branchid and ot.code=a.truckid
-- LEFT JOIN `spatial-vision-343005.biteam.sync_dms_rd` rd on rd.ordernbr=a.ordernbr and a.branchid =rd.branchid and rd.custid = a.custid
-- LEFT JOIN `spatial-vision-343005.biteam.sync_dms_dr` dr on dr.ordernbr=a.ordernbr and a.branchid =dr.branchid and dr.custid = a.custid
LEFT JOIN order_detail k on k.branchid =a.branchid and k.ordernbr =a.ordernbr -- k.ordernbr =a.ordernbr --k.ordernbr_mapping =a.origordernbr
LEFT JOIN `spatial-vision-343005.biteam.sync_dms_omorddics` k2 on k2.branchid =k.branchid and k.ordernbr_mapping =k2.ordernbr
 and k2.glineref = k.lineref
LEFT JOIN `spatial-vision-343005.biteam.d_dms_master_invtid` o on o.invtid = k.invtid
LEFT JOIN `spatial-vision-343005.biteam.sync_dms_lt` j on j.branchid = k.branchid and k.ordernbr_mapping = j.ordernbr and j.omlineref = k.lineref
LEFT JOIN `spatial-vision-343005.biteam.sync_dms_rd` rd on rd.ordernbr=a.ordernbr and a.branchid =rd.branchid and rd.custid = a.custid
LEFT JOIN `spatial-vision-343005.biteam.sync_dms_dr` dr on dr.ordernbr=a.ordernbr and a.branchid =dr.branchid and dr.custid = a.custid
LEFT JOIN `spatial-vision-343005.biteam.sync_dms_ot` ot on ot.branchid=a.branchid and ot.code=ifnull(ifnull(dr.truckid,rd.truckid),a.truckid)


where (a.ordertype ='IN' or a.ordertype is null) 
),
--and a.ordernbr ='DH6-0222-00879'
-- where a.status_so in ('Hủy hóa đơn','Đóng đơn hàng') and a.origordernbr ='HD0-0122-01442'

phanquyen as (
  with max_phanquyen as (
  select manv,max(inserted_at) as max_inserted_at from `spatial-vision-343005.biteam.d_phanquyen_phanam`
group by 1 )

select distinct a.*
from `spatial-vision-343005.biteam.d_phanquyen_phanam` a
JOIN max_phanquyen b on a.manv=b.manv and a.inserted_at =b.max_inserted_at
where a.trangthaihoatdong ='Còn hoạt động'
)

-- select ordernbr,count(1) from result1 where ngaytaodon >'2022-08-01' group by 1
-- select count (*) from result1 

select a.*,
Case when ngaygiaohang is not null and ngaygiaohang <= ship_on_time_sla then 'Giao hàng đúng hạn'
     when ngaygiaohang is not null and ngaygiaohang > ship_on_time_sla then 'Trễ hạn giao hàng'
     when ngaygiaohang is null and deliveryunit ='NVC' and ngaychotso <= ship_on_time_sla then 'Giao hàng đúng hạn'
     when ngaygiaohang is null and deliveryunit ='NVC' and ngaychotso > ship_on_time_sla then 'Trễ hạn giao hàng'
     when ngaygiaohang is null and ship_on_time_sla < datetime_add(current_timestamp(),interval 7 hour) 
     and trangthaidon not in ('Đã giao hàng')
     then 'Trễ hạn giao hàng'
    else null end as check_sot,

ard.deliveryunitname,gh.note as note_gh,gh.descr as ghichu_gh ,
Case when f.email is null then 'bimerap.main@gmail.com' else f.email end as sup_mds_email
from result1 a
LEFT JOIN `spatial-vision-343005.biteam.sync_dms_ard`ard on a.deliveryunit_code = ard.deliveryunitid and ard.branchid =a.branchid
LEFT JOIN dms_checkin gh on gh.slsperid = a.slsperid_dv --and gh.branchid = a.branchid 
and gh.deordernbr = a.ordernbr and gh.custid = a.custid
LEFT JOIN `spatial-vision-343005.biteam.d_users` c on c.manv =ifnull(a.slsperid_dv,a.crtd_user_dv)
 LEFT JOIN phanquyen f on c.supid = f.manv 
--  where a.ordernbr ='DH2-0322-00677'
--where ngaytaodon <'2022-11-01 10:10:00'