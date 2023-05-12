DECLARE TODAY DATE DEFAULT DATE_ADD(CURRENT_DATE(), interval 2 day);
DECLARE TODAY_DT DATETIME DEFAULT DATE_ADD(CURRENT_DATETIME(), interval 2 day);
DECLARE INTERVAL_DAY INT64 DEFAULT 3;
DECLARE S_WEEK INT64 DEFAULT EXTRACT(WEEK from TODAY);
DECLARE E_WEEK INT64 DEFAULT S_WEEK+INTERVAL_DAY;
DECLARE YEAR INT64 DEFAULT EXTRACT(YEAR from TODAY);

WITH
  bang1 AS (
  SELECT
    DISTINCT matinh,
    maquanhuyen,
    CAST(maphuongxa AS int) AS maphuongxa,
    vptram,
    CONCAT(matinh,maquanhuyen,maphuongxa) AS mapping,
    TODAY,
    DATETIME_ADD(TODAY_DT, INTERVAL CAST(sogiocongthem AS int64) hour) AS ngaydathangthemgio,
  FROM
    `biteam.d_lichgiaohang`
  )
,
bang2 as 
(
  SELECT
  a.*,
  CONCAT(matinh,maquanhuyen,maphuongxa) AS mapping,
  b.weeknum,
  mod(b.weeknum,2) as odd,
  case when deuhangtuancachtuan = 'Hàng tuần'then 'OK'
  when deuhangtuancachtuan = 'Tuần lẻ'and mod(b.weeknum,2) =1 then 'OK'
  when deuhangtuancachtuan = 'Tuần chẵn'and mod(b.weeknum,2) =0 then 'OK'
  else 'Ko OK'
  end as kiemtra
FROM
  `spatial-vision-343005.biteam.d_hanh_lich_giao_hang` a
inner join `biteam.d_hanh_dummyweek` b 
on 'A'= b.abc
and b.weeknum  >= S_WEEK and b.weeknum <= E_WEEK 
where
case when deuhangtuancachtuan = 'Hàng tuần'then 'OK'
  when deuhangtuancachtuan = 'Tuần lẻ'and mod(b.weeknum,2) =1 then 'OK'
  when deuhangtuancachtuan = 'Tuần chẵn'and mod(b.weeknum,2) =0 then 'OK'
  else 'Ko OK'
  end  = 'OK'
)
,
bang3 as (
select *, 
YEAR as year,
DATE_ADD(DATE(YEAR, 1, 1), INTERVAL weeknum WEEK) as ngaytheotuan,
case when values = 2 then date_sub ( DATE_ADD(DATE(YEAR, 1, 1), INTERVAL weeknum WEEK), interval 5 day)
when values = 3 then date_sub ( DATE_ADD(DATE(YEAR, 1, 1), INTERVAL weeknum WEEK), interval 4 day)
when values = 4 then date_sub ( DATE_ADD(DATE(YEAR, 1, 1), INTERVAL weeknum WEEK), interval 3 day)
when values = 5 then date_sub ( DATE_ADD(DATE(YEAR, 1, 1), INTERVAL weeknum WEEK), interval 2 day)
when values = 6 then date_sub ( DATE_ADD(DATE(YEAR, 1, 1), INTERVAL weeknum WEEK), interval 1 day)
when values = 7 then DATE_ADD(DATE(YEAR, 1, 1), INTERVAL weeknum WEEK)
else date(1900,1,1) end as ngaygiaohang,
from bang2
UNPIVOT (values for attributes in (t2,t3,t4,t5,t6,t7) )
where values != 0
)

select * from bang2 where mapping = '191712232' 
-- and values = 6