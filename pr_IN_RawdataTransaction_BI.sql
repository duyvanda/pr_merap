USE [PhaNam_eSales_PRO]
GO

/****** Object:  StoredProcedure [dbo].[pr_IN_RawdataTransaction_BI]    Script Date: 15/12/2021 3:21:01 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[pr_IN_RawdataTransaction_BI] -- pr_IN_RawdataTransaction_BI '20211201','20211201'
  @StartDate DATE , @EndDate DATE                 
as      
SET NOCOUNT ON     
 --declare @RPTID nvarchar(50) ='64'
 --Declare @ReportDate as smalldatetime                  
 --Declare @ReportName nvarchar(50)                  
 --declare @StartDate as smalldatetime                  
 --declare @EndDate as smalldatetime                  
 --declare @StringParm00 as nvarchar(1000)                  
 --Declare @UserID as varchar(15)                  
 --declare @AppPath varchar(400)                 
 --Declare @LogonID varchar(100)     
 --DECLARE @StringBranch VARCHAR(max)             
 --Declare #TableBranchID TABLE (BranchID VARCHAR(30))  

 --SELECT @ReportDate  =  ReportDate, @ReportName  =  ReportName, @StartDate  =   DateParm00, @EndDate =  DateParm01,                   
 -- @StringParm00  =  StringParm00, @UserID  =  UserID, @AppPath  =  AppPath, @LogonID = LoggedCpnyID                  
 --FROM RPTRunning rpt WITH (NOLOCK)                 
 --WHERE ReportID  =  @RPTID   

 

 --SELECT SiteID=StringParm 
 --INTO #TableSiteID
 --FROM RPTRunningParm0 WITH (NOLOCK)  WHERE ReportID  =  @RPTID  

 -- SELECT InvtID=StringParm 
 --INTO #TableInvtID
 --FROM RPTRunningParm1 WITH (NOLOCK)  WHERE ReportID  =  @RPTID  

 --SELECT @StringBranch = u.CpnyID
 --FROM dbo.vs_User u WITH(NOLOCK)
 --WHERE u.UserName = @UserID


 --SELECT BranchID  = com.CpnyID 
 --INTO #TableBranchID
 --FROM  dbo.SYS_Company com WITH(NOLOCK)
 --WHERE  com.CpnyID IN (SELECT part FROM dbo.fr_SplitStringMAX(@StringBranch,','))
 --AND (com.CpnyID LIKE (CASE WHEN @StringParm00 = '' THEN '%' END ) OR com.CpnyID IN (SELECT part FROM dbo.fr_SplitStringMAX(@StringParm00,',')))
                  
 SELECT  
	[Mã Cty/CN] = xnt.IDCodeOffice,
	[Tên Cty/CN] = CpnyName,
	[Trạng Thái] = Case when xnt.Status='C' then N'Xử Lý Hoàn Tất' 
						when xnt.Status='H' then N'Chờ Xử Lý' 
						when xnt.Status='V' then N'Đã Hủy' else N'' end ,
	[Nghiệp Vụ] = xnt.TranType,
	[Mã Chứng Từ] = xnt.BatNbr,
	[Mã Kho] = xnt.CodeWarehouse,
	[Tên Kho] = xnt.NameWarehouse,
	[Số Đơn Hàng] = xnt.OrderNbr,
	[Số Đơn Hàng CSM] = xnt.OrderNbrCSM,
	[Số Ký Hiệu] = xnt.Symbols,
	[Số Hóa Đơn] = xnt.InvoiceNumber,
	[Ngày Hóa Đơn] = convert(varchar, xnt.DateInvoice,103),
	[Ngày Giao Dịch] = convert(varchar, xnt.TranDate,103),
	[Mã Đối Tượng] = xnt.IDCodeCus,
	[Tên Đối Tượng] = xnt.CustomerName,
	[Mã KH Xuất HĐ] = xnt.IDCodeCusInvoice,
	[Tên KH Xuất HĐ] = xnt.CustomerNameInvoice,
	[Mã Sản Phẩm] = xnt.ProductCode,
	[Tên Sản Phẩm] = xnt.ProductName,
	[Số Lot] = xnt.LotNo,
	[Ngày Hết Hạn] = convert(varchar, xnt.ExpiredDate,103),
	[Đơn Vị] = xnt.Unit,
	[Số Lượng] = xnt.Quantity * TypeCode,
	
	[Giá] = xnt.ProductPrice,
	[Thành Tiền] = xnt.Amount ,
	[Loại Nhập Xuất] = Case when typecode=1 then N'Nhập' else N'Xuất' end,
	[Ghi Chú] = xnt.Note
	--[Người Tạo] = xnt.CreateUser  

   FROM                   
   (                  
--1.Lô nhập PO
SELECT
IDCodeOffice  = t.BranchID,  --Mã công ty 
t.BatNbr,
CodeWarehouse  = t.SiteID,  --Mã kho 
NameWarehouse  = s.Name,  --Tên kho 
TranType= Case when r.RcptType='R' then N'Nhập Mua Hàng' else N'Xuất Trả NCC' end ,
TypeCode  = Case when r.RcptType='R' then 1 else -1 end ,--[HQ] Phân loại nghiệp vụ: 1 nhap -1 xuat
OrderNbr = '' ,--  Số Đơn Hàng
OrderNbrCSM = '' ,--  Số Đơn Hàng CSM
Symbols  = invc.InvcNote,  --Ký hiệu 
InvoiceNumber  = invc.InvcNbr,  --Số hóa đơn 
DateInvoice  = invc.InvcDate,  --Ngày hóa đơn 
TranDate  = t.TranDate,  --Ngày tạo 
IDCodeCus  = r.VendID,  --Mã khách hàng => Mã Nhà cung cấp
CustomerName  = v.[Name],  --Tên khách hàng  => Tên Nhà cung cấp
IDCodeCusInvoice  = '',  --Mã khách hàng xuất hóa đơn => de rong
CustomerNameInvoice  = '',  --Khách hàng xuất hóa đơn => de rong
ProductCode  = t.InvtID,  --Mã sản phẩm 
ProductName  = i.Descr,  --Tên sản phẩm 
LotNo  = l.LotSerNbr,  --Số lô 
ExpiredDate  = l.ExpDate,  --Hạn dùng 
Unit  = t.UnitDescr,  --đơn vị 
Quantity  = ISNULL(l.Qty, t.Qty),  --Số lượng 
ProductPrice  = t.UnitCost,  --Giá sản phẩm 
Amount  = ISNULL(l.Qty, t.Qty) * t.UnitCost,  --Thành tiền
CreateUser = t.Crtd_User,
r.Status,
Note=r.Descr
FROM PO_Trans t  WITH (NOLOCK)
INNER JOIN IN_Inventory i  WITH (NOLOCK) ON t.InvtId = i.InvtId
INNER JOIN IN_Site s WITH (NOLOCK)  ON t.SiteID = s.SiteID
INNER JOIN SYS_Company c WITH (NOLOCK)  ON t.BranchID = c.CpnyID
LEFT JOIN PO_LotTrans l WITH (NOLOCK)  ON t.BranchID = l.BranchID AND t.BatNbr = l.BatNbr AND t.LineRef = l.POTranLineRef
INNER JOIN PO_Receipt r WITH (NOLOCK)  ON t.BranchID = r.BranchID AND t.BatNbr = r.BatNbr
INNER JOIN PO_Invoice invc WITH (NOLOCK)  ON r.BranchID = invc.BranchID AND r.BatNbr = invc.BatNbr AND r.RcptNbr = invc.RcptNbr 
INNER JOIN AP_Vendor v WITH (NOLOCK)  ON r.VendID = v.VendID
----INNER JOIN SI_Tax tax WITH (NOLOCK)  ON t.TaxID00 = tax.TaxID
--INNER JOIN #TableBranchID tb WITH(NOLOCK) ON tb.BranchID = t.BranchID
--INNER JOIN #TableSiteID st WITH(NOLOCK) ON t.SiteID = st.SiteID   
--INNER JOIN #TableInvtID it WITH(NOLOCK) ON t.InvtID = it.InvtID 
WHERE  --r.Status = 'C' AND   
CAST(t.TranDate AS DATE) BETWEEN CAST(@StartDate AS DATE) AND CAST(@EndDate AS DATE) 
--select * from PO_Trans
--2.Cac Lo Chuyển Kho ---
UNION ALL
SELECT
IDCodeOffice  = t.BranchID,  --Mã công ty 
t.Batnbr,
CodeWarehouse  = t.SiteID,  --Mã kho 
NameWarehouse  = s.Name,  --Tên kho 
TranType= Case when t.TranType='RC' then N'Nhập Kho' when t.TranType in ('IN','II') then N'Xuất Kho' when t.TranType='TR' then N'Chuyển Kho' when t.TranType='AJ' then N'Điều Chỉnh Kho' end ,
TypeCode  = t.InvtMult , --[HQ] Phân loại nghiệp vụ: 1 nhap -1 xuat
OrderNbr = '' ,--  Số Đơn Hàng
OrderNbrCSM = '' ,--  Số Đơn Hàng CSM
Symbols  = ISNULL(tr.InvcNote,''),  --Ký hiệu 
InvoiceNumber  = ISNULL(tr.InvcNbr,''),  --Số hóa đơn 
DateInvoice  = '',  --Ngày hóa đơn 
TranDate  = t.TranDate,  --Ngày tạo 
IDCodeCus  = '',  --Mã khách hàng => Mã Nhà cung cấp
CustomerName  = '',  --Tên khách hàng  => Tên Nhà cung cấp
IDCodeCusInvoice  = '',  --Mã khách hàng xuất hóa đơn 
CustomerNameInvoice  = '',  --Khách hàng xuất hóa đơn 
ProductCode  = t.InvtID,  --Mã sản phẩm 
ProductName  = i.Descr,  --Tên sản phẩm 
LotNo  = l.LotSerNbr,  --Số lô 
ExpiredDate  = l.ExpDate,  --Hạn dùng 
Unit  = t.UnitDesc,  --đơn vị 
Quantity  =ISNULL(l.Qty, t.Qty),  --Số lượng 
ProductPrice  = t.UnitPrice,  --Giá sản phẩm 
Amount  =  ISNULL(l.Qty, t.Qty) * t.UnitPrice,   --Thành tiền 
CreateUser = t.Crtd_User,
b.Status,
Note=b.Descr
FROM IN_Trans t WITH (NOLOCK) 
LEFT JOIN IN_Transfer tr WITH (NOLOCK) ON tr.BatNbr = t.BatNbr and tr.BranchID = t.BranchID
INNER JOIN IN_Inventory i  WITH (NOLOCK) ON t.InvtId = i.InvtId
INNER JOIN IN_Site s  WITH (NOLOCK) ON t.SiteID = s.SiteID
INNER JOIN SYS_Company c  WITH (NOLOCK) ON t.BranchID = c.CpnyID
INNER JOIN Batch b  WITH (NOLOCK) ON t.BranchID = b.BranchID AND t.BatNbr = b.BatNbr and b.Module='IN'
LEFT JOIN IN_LotTrans l  WITH (NOLOCK) ON t.BranchID = l.BranchID AND t.BatNbr = l.BatNbr AND t.RefNbr = l.RefNbr AND t.LineRef = l.INTranLineRef
--INNER JOIN #TableBranchID tb WITH(NOLOCK) ON t.BranchID = tb.BranchID  
--INNER JOIN #TableSiteID st WITH(NOLOCK) ON t.SiteID = st.SiteID   
--INNER JOIN #TableInvtID it WITH(NOLOCK) ON t.InvtID = it.InvtID                
WHERE  --b.Status = 'C'  and t.Rlsed=1 and
 CAST(t.TranDate AS DATE) BETWEEN CAST(@StartDate AS DATE) AND CAST(@EndDate AS DATE) 
AND b.JrnlType = 'IN' 

--2.Cac Lo Bán Hàng ---
UNION ALL

SELECT
IDCodeOffice  = t.BranchID,  --Mã công ty 
t.batnbr,
CodeWarehouse  = t.SiteID,  --Mã kho 
NameWarehouse  = s.Name,  --Tên kho 
TranType= Case when t.TranType IN ('IN','II') then N'Xuất Bán' else N'KH Trả Hàng' end ,
TypeCode  = t.InvtMult ,--[HQ] Phân loại nghiệp vụ: 1 nhap -1 xuat
OrderNbr = o.OrigOrderNbr, -- Số Đơn Hàng
OrderNbrCSM = api.PNOrderNbr ,--  Số Đơn Hàng CSM
Symbols  = o.InvcNote,  --Ký hiệu 
InvoiceNumber  = o.InvcNbr,  --Số hóa đơn 
DateInvoice  = o.OrderDate,  --Ngày hóa đơn 
TranDate  = t.TranDate,  --Ngày tạo 
IDCodeCus  = o.CustID,  --Mã khách hàng => Mã Nhà cung cấp
CustomerName  = Cus.CustName,  --Tên khách hàng  => Tên Nhà cung cấp
IDCodeCusInvoice  = o.InvoiceCustID,  --Mã khách hàng xuất hóa đơn 
CustomerNameInvoice  = o.CustInvcName,  --Khách hàng xuất hóa đơn 
ProductCode  = t.InvtID,  --Mã sản phẩm 
ProductName  = i.Descr,  --Tên sản phẩm 
LotNo  = l.LotSerNbr,  --Số lô 
ExpiredDate  = l.ExpDate,  --Hạn dùng 
Unit  = t.UnitDesc,  --đơn vị 
Quantity  =ISNULL(l.Qty, t.Qty),  --Số lượng 
ProductPrice  = t.UnitPrice,  --Giá sản phẩm 
Amount  = ISNULL(l.Qty, t.Qty) * t.UnitPrice, --Thành tiền 
 CreateUser = t.Crtd_User,
 b.Status,
 Note=b.Descr
FROM IN_Trans t WITH (NOLOCK) 
INNER JOIN IN_Inventory i  WITH (NOLOCK) ON t.InvtId = i.InvtId
INNER JOIN IN_Site s  WITH (NOLOCK) ON t.SiteID = s.SiteID
INNER JOIN SYS_Company c  WITH (NOLOCK) ON t.BranchID = c.CpnyID
INNER JOIN Batch b  WITH (NOLOCK) ON t.BranchID = b.BranchID AND t.BatNbr = b.BatNbr AND b.JrnlType = 'OM' and b.Module='IN'
INNER JOIN OM_SalesOrd o  WITH (NOLOCK) ON t.BranchID = o.BranchID AND t.BatNbr = o.INBatNbr AND t.RefNbr = o.ARRefNbr
Left JOIN API_PostHistory api  WITH (NOLOCK) ON api.DmsBranchID = o.BranchID AND api.DmsOrderNbr=o.OrigOrderNbr
INNER JOIN AR_Customer Cus  WITH (NOLOCK) ON o.CustID=Cus.CustID
LEFT JOIN IN_LotTrans l  WITH (NOLOCK) ON t.BranchID = l.BranchID AND t.BatNbr = l.BatNbr AND t.RefNbr = l.RefNbr AND t.LineRef = l.INTranLineRef
--INNER JOIN #TableBranchID tb WITH(NOLOCK) ON t.BranchID = tb.BranchID  
--INNER JOIN #TableSiteID st WITH(NOLOCK) ON t.SiteID = st.SiteID   
--INNER JOIN #TableInvtID it WITH(NOLOCK) ON t.InvtID = it.InvtID 
WHERE  --b.Status = 'C' and t.Rlsed=1 AND
 CAST(T.TranDate AS DATE) BETWEEN CAST(@StartDate AS DATE) AND CAST(@EndDate AS DATE) 


 )AS xnt                     
  INNER JOIN dbo.IN_Site s  WITH(NOLOCK)ON xnt.CodeWarehouse = s.SiteId     
  INNER JOIN dbo.IN_Inventory  i WITH(NOLOCK)  ON i.InvtID  =  xnt.ProductCode  and i.LotSerTrack='L'
  inner join IN_UnitConversion un WITH(NOLOCK) ON  i.StkUnit=un.FromUnit  and un.UnitType=1
  LEFT JOIN dbo.IN_UnitConversion ut WITH(NOLOCK) ON ut.InvtID =i.InvtID AND  i.StkUnit = ut.ToUnit AND ut.MultDiv = 'M' AND ut.CnvFact > 1
  INNER JOIN dbo.IN_ProductClass pc WITH(NOLOCK)  ON pc.ClassID  =  i.ClassID       
  --LEFT JOIN  dbo.vs_User  u  WITH(NOLOCK) ON u.UserName  =  @UserID          
  INNER JOIN vs_Company c  WITH(NOLOCK) ON c.CpnyID  =  xnt.IDCodeOffice      
 Order by   xnt.IDCodeOffice,  xnt.TranDate,  typecode, xnt.TranType, xnt.BatNbr, xnt.ProductCode
  --WHERE xnt.InvtID LIKE (CASE WHEN @StringParm00 = '' THEN '%' ELSE @StringParm00 END)  



--DROP TABLE #TableBranchID
--DROP TABLE #TableSiteID
--DROP TABLE #TableInvtID


GO

