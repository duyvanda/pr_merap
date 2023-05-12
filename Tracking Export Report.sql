SELECT [Mã Báo Cáo]=r.ReportNbr,[Tên Báo Cáo]=ISNULL(e.Name,c.Descr),r.UserID,[Tên Người Dùng]=u.FirstName,u.Position,[Ngày Xem Báo Cáo]=r.ReportDate
, [(Param)String_1]=CASE WHEN expa.StringCap00<>'' THEN CASE WHEN r.StringParm00='' THEN dbo.fr_GetLang(1,expa.StringCap00) +':'+'ALL' ELSE dbo.fr_GetLang(1,expa.StringCap00)+':'+r.StringParm00 end ELSE CASE WHEN cp.StringCap00 <> '' THEN CASE WHEN r.StringParm00='' THEN dbo.fr_GetLang(1,cp.StringCap00)+':'+'ALL' ELSE dbo.fr_GetLang(1,cp.StringCap00)+':'+r.StringParm00 end ELSE '' END end 
, [(Param)String_2]=CASE WHEN expa.StringCap01<>'' THEN CASE WHEN r.StringParm01='' THEN dbo.fr_GetLang(1,expa.StringCap01)+':'+'ALL' ELSE dbo.fr_GetLang(1,expa.StringCap01)+':'+r.StringParm01 END  ELSE CASE WHEN cp.StringCap01 <> '' THEN CASE WHEN  r.StringParm01='' THEN dbo.fr_GetLang(1,cp.StringCap01)+':'+'ALL' ELSE dbo.fr_GetLang(1,cp.StringCap01)+':'+r.StringParm01 end ELSE '' END end 
, [(Param)String_3]=CASE WHEN expa.StringCap02<>'' THEN CASE WHEN r.StringParm02='' THEN dbo.fr_GetLang(1,expa.StringCap02)+':'+'ALL' ELSE dbo.fr_GetLang(1,expa.StringCap02)+':'+r.StringParm02 END  ELSE CASE WHEN cp.StringCap02 <> '' THEN CASE WHEN  r.StringParm02='' THEN dbo.fr_GetLang(1,cp.StringCap02)+':'+'ALL' ELSE dbo.fr_GetLang(1,cp.StringCap02)+':'+r.StringParm02 end ELSE '' END end 
, [(Param)String_4]=CASE WHEN expa.StringCap03<>'' THEN CASE WHEN r.StringParm03='' THEN dbo.fr_GetLang(1,expa.StringCap03)+':'+'ALL' ELSE dbo.fr_GetLang(1,expa.StringCap03)+':'+r.StringParm03 END ELSE CASE WHEN cp.StringCap03 <> '' THEN CASE WHEN  r.StringParm03='' THEN dbo.fr_GetLang(1,cp.StringCap03)+':'+'ALL' ELSE dbo.fr_GetLang(1,cp.StringCap03)+':'+r.StringParm03 end ELSE '' END end 
,[(Param)Date_1]=CASE WHEN expa.DateCap00<>'' THEN dbo.fr_GetLang(1,expa.DateCap00)+':'+CONVERT(VARCHAR,r.DateParm00, 103)  ELSE CASE WHEN cp.DateCap00 <> '' THEN  dbo.fr_GetLang(1,cp.DateCap00)+':'+CONVERT(VARCHAR,r.DateParm00, 103) ELSE '' END end 
,[(Param)Date_2]=CASE WHEN expa.DateCap01<>'' THEN dbo.fr_GetLang(1,expa.DateCap01)+':'+CONVERT(VARCHAR,r.DateParm01, 103)  ELSE CASE WHEN cp.DateCap01 <> '' THEN dbo.fr_GetLang(1,cp.DateCap01)+':'+CONVERT(VARCHAR,r.DateParm01, 103) ELSE '' END end 
,[(Param)Date_3]=CASE WHEN expa.DateCap02<>'' THEN dbo.fr_GetLang(1,expa.DateCap02)+':'+CONVERT(VARCHAR,r.DateParm02, 103)  ELSE CASE WHEN cp.DateCap02 <> '' THEN  dbo.fr_GetLang(1,cp.DateCap02)+':'+CONVERT(VARCHAR,r.DateParm02, 103) ELSE '' END end 
,[(Param)Date_4]=CASE WHEN expa.DateCap03<>'' THEN dbo.fr_GetLang(1,expa.DateCap03)+':'+CONVERT(VARCHAR,r.DateParm03, 103)  ELSE CASE WHEN cp.DateCap03 <> '' THEN  dbo.fr_GetLang(1,cp.DateCap03)+':'+CONVERT(VARCHAR,r.DateParm03, 103) ELSE '' END end 
 
FROM dbo.RPTRunning r WITH (NOLOCK)
INNER JOIN dbo.Users u WITH (NOLOCK) ON r.UserID=u.UserName
LEFT JOIN SYS_ReportExport e WITH (NOLOCK) ON e.ReportNbr = r.ReportNbr
LEFT JOIN dbo.SYS_ReportExportParm expa WITH (NOLOCK) ON expa.ReportNbr=e.ReportNbr
LEFT JOIN dbo.SYS_ReportControl c WITH (NOLOCK) ON c.ReportNbr=r.ReportNbr
LEFT JOIN dbo.SYS_ReportParm cp WITH (NOLOCK) ON cp.ReportNbr=c.ReportNbr
WHERE r.ReportNbr NOT IN ('OM20890','OM45400','OM32700','IN11500','AR10200','AR10100')
ORDER BY ReportID DESC