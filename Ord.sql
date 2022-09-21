DECLARE @fromdate DATE = '2022-04-21';
DECLARE @todate DATE = '2022-04-21';

SELECT
a.BranchID , a.OrderNbr  ,so.SlsPerID , a.OrderDate , 
		Status =	CASE		
					WHEN  ISNULL(so.status,'') = ''
					THEN (
							CASE	WHEN a.Status = 'C' THEN N'Đã Duyệt Đơn Hàng'
									WHEN a.Status = 'H' THEN N'Chờ Xử Lý'
									WHEN a.Status = 'E' THEN N'Đóng Đơn Hàng'
									WHEN a.Status = 'D' THEN N'Đơn Hàng Tạm' 
									WHEN a.Status = 'V' THEN N'Hủy Đơn Hàng' END )
					ELSE (
							CASE	WHEN so.Status = 'C' THEN N'Đã Phát Hành'
									WHEN so.Status = 'I' THEN N'Tạo Hóa Đơn'
									WHEN so.Status = 'N' THEN N'Tạo Hóa Đơn'
									WHEN so.Status = 'H' THEN N'Chờ Xử Lý'
									WHEN so.Status = 'D' THEN N'Đơn Hàng Tạm' 
									WHEN so.Status = 'E' THEN N'Đóng Đơn Hàng' 
									WHEN so.Status = 'V' THEN N'Hủy Hóa Đơn' END )				
					END , 
		a.CustID ,
		so.invtid,  Lotsernbr= so.Lotsernbr, ExpDate=so.ExpDate,
		VATAmount = Sum(  so.VATAmount), 
		BeforeVATAmount = Sum( so.BeforeVATAmount), 
		AfterVATAmount = SUM(so.AfterVATAmount), 
		a.Crtd_User , a.Crtd_DateTime , a.ContractID , a.DeliveryID , a.ShipDate , a.OrdAmt, OrdQty=so.Qty, InvcNbr = ISNULL(so.InvcNbr,''), InvcNote= ISNULL(so.InvcNote,''),
		PNOrderNbr = ISNULL(p.PNOrderNbr,'') , 
                       ChietKhau= Sum(so.ChietKhau),
					   a.OrderType, ContractNbr=ISNULL(ctr.ContractNbr,''),
		Note = a.Remark
FROM  dbo.OM_PDASalesOrd a WITH(NOLOCK)
--INNER JOIN dbo.RPTRunningParm0 r WITH(NOLOCK) ON r.StringParm = a.BranchID AND r.ReportID = @RPTID
--INNER JOIN(Select * from dbo.OM_PDASalesOrdDet   WITH(NOLOCK))b ON b.BranchID = a.BranchID AND b.OrderNbr = a.OrderNbr
LEFT JOIN dbo.API_PostHistory p WITH(NOLOCK) ON a.BranchID = p.DmsBranchID and a.OrderNbr=p.DmsOrderNbr
INNER JOIN (Select distinct o.BranchID, o.OrigOrderNbr, status= min(status) ,o.InvcNbr,o.InvcNote,b.SlsPerID,b.Invtid, Qty= isnull(l.Qty,b.LineQty) ,Lotsernbr=isnull(l.Lotsernbr,''), ExpDate=CAST(isnull(l.ExpDate,'') as varchar (20)) , ChietKhau=( o.OrdDiscAmt+ o.VolDiscAmt),
		BeforeVATAmount = SUM(CASE WHEN b.FreeItem = 1 THEN 0  ELSE (CASE WHEN oo.ARDocType in( 'IN','DM','CS') THEN 1  WHEN oo.ARDocType in( 'NA') THEN 0
                     ELSE -1 END ) *b.BeforeVATAmount END ), 
					 AfterVATAmount = SUM(CASE WHEN b.FreeItem = 1 THEN 0  ELSE (CASE WHEN oo.ARDocType in( 'IN','DM','CS') THEN 1  WHEN oo.ARDocType in( 'NA') THEN 0
                     ELSE -1 END ) *b.AfterVATAmount END ), 
					 VATAmount = SUM(CASE WHEN b.FreeItem = 1 THEN 0  ELSE (CASE WHEN oo.ARDocType in( 'IN','DM','CS') THEN 1  WHEN oo.ARDocType in( 'NA') THEN 0
                     ELSE -1 END ) *b.VATAmount END) 
			from dbo.OM_SalesOrd o  WITH(NOLOCK)  
			inner join OM_SalesOrddet b  WITH(NOLOCK) on  o.BranchID = b.BranchID AND o.OrderNbr = b.OrderNbr
			left join OM_lottrans l  WITH(NOLOCK) on  l.BranchID = b.BranchID AND l.OrderNbr = b.OrderNbr and l.omlineref=b.lineref
			INNER JOIN dbo.OM_OrderType oo WITH(NOLOCK) ON oo.OrderType = o.OrderType
			group by o.BranchID,o.OrigOrderNbr,o.InvcNbr,o.InvcNote, o.OrdDiscAmt,b.SlsPerID, o.VolDiscAmt,b.Invtid ,isnull(l.Lotsernbr,''),isnull(l.Qty,b.LineQty), isnull(l.ExpDate,'')) so ON so.BranchID = a.BranchID AND so.OrigOrderNbr = a.OrderNbr
Left join OM_OriginalContract ctr WITH (NOLOCK) ON  a.ContractID=ctr.ContractID
WHERE CAST(a.OrderDate AS DATE) BETWEEN @fromdate AND @todate
GROUP BY 
CASE WHEN ISNULL(so.status, '') = '' THEN
         ( CASE WHEN a.Status = 'C' THEN N'Đã Duyệt Đơn Hàng'
         WHEN a.Status = 'H' THEN N'Chờ Xử Lý'
         WHEN a.Status = 'E' THEN N'Đóng Đơn Hàng'
		 WHEN a.Status = 'D' THEN N'Đơn Hàng Tạm'
		 WHEN a.Status = 'V' THEN N'Hủy Đơn Hàng'
         END
         )
         ELSE ( CASE WHEN so.Status = 'C' THEN N'Đã Phát Hành'
         WHEN so.Status = 'I' THEN N'Tạo Hóa Đơn'
         WHEN so.Status = 'N' THEN N'Tạo Hóa Đơn'
         WHEN so.Status = 'H' THEN N'Chờ Xử Lý'
		 WHEN so.Status = 'D' THEN N'Đơn Hàng Tạm'
         WHEN so.Status = 'E' THEN N'Đóng Đơn Hàng'
		 WHEN so.Status = 'V' THEN N'Hủy Hóa Đơn' 
         END
         )
         END , so.Qty,
         a.BranchID , ISNULL(so.InvcNbr,'') ,ISNULL(so.InvcNote,''),so.invtid, so.ExpDate, so.Lotsernbr,
         a.OrderNbr ,
         so.SlsPerID ,
         a.OrderDate ,
         a.CustID ,
         a.Crtd_User ,
         a.Crtd_DateTime ,
 a.ContractID ,
         a.DeliveryID ,
         a.ShipDate ,
         a.OrdAmt,
		 a.OrderType,  ISNULL(ctr.ContractNbr,''),ISNULL(p.PNOrderNbr,'') ,
		 a.Remark
Union All

SELECT  
a.BranchID , a.OrderNbr  ,b.SlsPerID , a.OrderDate , 
		Status =	CASE		
					WHEN  ISNULL(so.status,'') = ''
					THEN (
							CASE	WHEN a.Status = 'C' THEN N'Đã Duyệt Đơn Hàng'
									WHEN a.Status = 'H' THEN N'Chờ Xử Lý'
									WHEN a.Status = 'E' THEN N'Đóng Đơn Hàng' 
									WHEN a.Status = 'D' THEN N'Đơn Hàng Tạm'
									WHEN a.Status = 'V' THEN N'Hủy Đơn Hàng' END )
					ELSE (
							CASE	WHEN so.Status = 'C' THEN N'Đã Phát Hành'
									WHEN so.Status = 'I' THEN N'Tạo Hóa Đơn'
									WHEN so.Status = 'N' THEN N'Tạo Hóa Đơn'
									WHEN so.Status = 'H' THEN N'Chờ Xử Lý'
									WHEN so.Status = 'D' THEN N'Đơn Hàng Tạm'
									WHEN so.Status = 'E' THEN N'Đóng Đơn Hàng' 
									WHEN so.Status = 'V' THEN N'Hủy Hóa Đơn' END )				
					END , 
		a.CustID ,b.invtid, Lotsernbr='', ExpDate='',
		VATAmount = Sum((CASE WHEN b.FreeItem = 1 THEN 0  ELSE (CASE WHEN oo.ARDocType in( 'IN','DM','CS') THEN 1  WHEN oo.ARDocType in( 'NA') THEN 0
                     ELSE -1 END ) * (b.AfterVATAmount -b.BeforeVATAmount) END )), 
		BeforeVATAmount = Sum(CASE WHEN b.FreeItem = 1 THEN 0  ELSE (CASE WHEN oo.ARDocType in( 'IN','DM','CS') THEN 1  WHEN oo.ARDocType in( 'NA') THEN 0
                            ELSE -1 END ) *ROUND(b.lineQty*(b.SlsPrice/(1+isnull(v.TaxRate,0)/100)),0) END ), 
		AfterVATAmount = SUM(CASE WHEN b.FreeItem = 1 THEN 0  ELSE (CASE WHEN oo.ARDocType in( 'IN','DM','CS') THEN 1  WHEN oo.ARDocType in( 'NA') THEN 0
                          ELSE -1 END ) * (b.LineQty*b.SlsPrice) END ), 
		a.Crtd_User , a.Crtd_DateTime , a.ContractID , a.DeliveryID , a.ShipDate , a.OrdAmt,  OrdQty=b.Lineqty, InvcNbr = ISNULL(so.InvcNbr,''), InvcNote= ISNULL(so.InvcNote,''),
		PNOrderNbr = ISNULL(p.PNOrderNbr,'') , 
                       ChietKhau= Sum(b.DocDiscAmt + b.DiscAmt + b.GroupDiscAmt1 + b.GroupDiscAmt2),
					   a.OrderType, ContractNbr=ISNULL(ctr.ContractNbr,''),
		Note=a.Remark
FROM  dbo.OM_PDASalesOrd a WITH(NOLOCK)
--INNER JOIN dbo.RPTRunningParm0 r WITH(NOLOCK) ON r.StringParm = a.BranchID AND r.ReportID = @RPTID
INNER JOIN dbo.OM_PDASalesOrdDet  b WITH(NOLOCK) ON b.BranchID = a.BranchID AND b.OrderNbr = a.OrderNbr
LEFT JOIN dbo.API_PostHistory p WITH(NOLOCK) ON a.BranchID = p.DmsBranchID and a.OrderNbr=p.DmsOrderNbr
LEFT JOIN dbo.OM_SalesOrd so  WITH(NOLOCK)  ON so.BranchID = a.BranchID AND so.OrigOrderNbr = a.OrderNbr
Left join OM_OriginalContract ctr WITH (NOLOCK) ON  a.ContractID=ctr.ContractID
INNER JOIN dbo.OM_OrderType oo WITH(NOLOCK) ON oo.OrderType = a.OrderType
LEFT join SI_Tax v  WITH(NOLOCK) on b.TaxID00=v.TaxID
WHERE so.OrigOrderNbr is null  --   a.OrderNbr ='DH032021-00271' and 
AND CAST(a.OrderDate AS DATE) BETWEEN @fromdate AND @todate 

GROUP BY 
CASE WHEN ISNULL(so.status, '') = '' THEN
         ( CASE WHEN a.Status = 'C' THEN N'Đã Duyệt Đơn Hàng'
         WHEN a.Status = 'H' THEN N'Chờ Xử Lý'
         WHEN a.Status = 'E' THEN N'Đóng Đơn Hàng'
		 WHEN a.Status = 'D' THEN N'Đơn Hàng Tạm'
		 WHEN a.Status = 'V' THEN N'Hủy Đơn Hàng'
         END
         )
         ELSE ( CASE WHEN so.Status = 'C' THEN N'Đã Phát Hành'
         WHEN so.Status = 'I' THEN N'Tạo Hóa Đơn'
         WHEN so.Status = 'N' THEN N'Tạo Hóa Đơn'
         WHEN so.Status = 'H' THEN N'Chờ Xử Lý'
		 WHEN so.Status = 'D' THEN N'Đơn Hàng Tạm'
         WHEN so.Status = 'E' THEN N'Đóng Đơn Hàng'
		 WHEN so.Status = 'V' THEN N'Hủy Hóa Đơn' 
         END
         )
         END , b.Lineqty,
         a.BranchID , ISNULL(so.InvcNbr,'') ,ISNULL(so.InvcNote,''),b.invtid,
         a.OrderNbr ,
         b.SlsPerID ,
         a.OrderDate ,
         a.CustID ,
         a.Crtd_User ,
         a.Crtd_DateTime ,
		 a.ContractID ,
         a.DeliveryID ,
         a.ShipDate ,
         a.OrdAmt,
		 a.OrderType,  ISNULL(ctr.ContractNbr,''),ISNULL(p.PNOrderNbr,'') ,
		 a.Remark