USE [PhaNam_eSales_PRO]
GO

/****** Object:  StoredProcedure [dbo].[pr_OM_RawDataPofileCust]    Script Date: 12-01-2023 10:33:12 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--SELECT * FROM dbo.RPTRunning ORDER BY ReportID DESC
ALTER PROC [dbo].[pr_OM_RawDataPofileCust] --  pr_OM_RawDataPofileCust  1745      
    @RPTID SMALLINT
AS

--DECLARE @RPTID SMALLINT =11242;

DECLARE @ReportName NVARCHAR(100);
DECLARE @ReportNbr VARCHAR(10);
DECLARE @StartDate DATETIME;
DECLARE @EndDate DATETIME;
DECLARE @LogCom VARCHAR(10);
DECLARE @CpnyID VARCHAR(MAX);
DECLARE @TCpnyID TABLE
(
    CpnyID VARCHAR(MAX)
);
DECLARE @SlsPerID VARCHAR(MAX);
DECLARE @Status VARCHAR(50);
DECLARE @TSlsPerID TABLE
(
    SlsPerID VARCHAR(MAX)
);
DECLARE @Branch TABLE
(
    CpnyID VARCHAR(MAX)
);
DECLARE @UserID VARCHAR(50);
DECLARE @Cc VARCHAR(200);
SET @Cc =
(
    SELECT TOP 1
           TextVal
    FROM dbo.vs_SYS_Configurations
    WHERE Code = 'ImagePublic'
);
SELECT @ReportName = ReportName,
       @ReportNbr = ReportNbr,
       @StartDate = DateParm00,
       @EndDate = DateParm01,
       @LogCom = LoggedCpnyID,
       @SlsPerID = StringParm00,
       @Status = StringParm02,
       @UserID = UserID
FROM RPTRunning WITH (NOLOCK)
WHERE ReportID = @RPTID;

SELECT sod.BranchID,
       sod.CustId,
       state = sod.State,
       statename = stae.Descr,
       distrist = sod.District,
       distname = disc.Name,
       sod.Ward,
       Wardname = wa.[Name],
       addr = sod.Addr1 + ', ' + wa.Name + ', ' + disc.Name + ', ' + stae.Descr
INTO #delivery
FROM dbo.AR_SOAddress sod WITH (NOLOCK)
    INNER JOIN SI_State stae WITH (NOLOCK)
        ON stae.State = sod.State
    INNER JOIN SI_District disc WITH (NOLOCK)
        ON disc.District = sod.District
    INNER JOIN SI_Ward wa WITH (NOLOCK)
        ON wa.Ward = sod.Ward
           AND wa.State = sod.State
           AND wa.District = sod.District;

DECLARE @CompanyString VARCHAR(MAX);
SELECT @CompanyString = CpnyID
FROM vs_User WITH (NOLOCK)
WHERE UserName = @UserID;


IF NOT EXISTS
(
    SELECT ReportID
    FROM RPTRunningParm0 WITH (NOLOCK)
    WHERE ReportID = @RPTID
)
BEGIN
    INSERT INTO @TCpnyID
    SELECT DISTINCT
           c.CpnyID
    FROM vs_Company c WITH (NOLOCK)
    WHERE c.CpnyID IN (
                          SELECT Branch FROM fr_StrtoTable(@CompanyString)
                      );
END;
ELSE
BEGIN
    INSERT INTO @TCpnyID
    SELECT rp.StringParm
    FROM RPTRunningParm0 rp WITH (NOLOCK)
    WHERE rp.ReportID = @RPTID;
END;


SELECT DISTINCT
       a.CustId,
       b.Descr
INTO #BusinessTemp
FROM dbo.AR_Customer a WITH (NOLOCK)
    LEFT JOIN dbo.AR_BusinessScope b WITH (NOLOCK)
        ON (b.Code) IN (
                           SELECT part FROM dbo.fr_SplitString(a.BusinessScope, ',')
                       )
WHERE a.BusinessScope <> '';



SELECT CustId,
       Descr = STUFF(
               (
                   SELECT ', ' + Descr
                   FROM #BusinessTemp t1
                   WHERE t1.CustId = t2.CustId
                   FOR XML PATH('')
               ),
               1,
               1,
               ''
                    )
INTO #BusinessScope
FROM #BusinessTemp t2
GROUP BY CustId;


SELECT CustID,
       NumPic = COUNT(ImageID)
INTO #NumPic
FROM dbo.AR_Customer_BusinessImage
GROUP BY CustID;

SELECT BranchID = c.BranchID,
       ComName = co.CpnyName,
       ComAdd = co.Address,
       ComTel = co.Tel,
       ZoneID = sz.Code,
       ZoneName = sz.Descr,
       SlsperID = ISNULL(c.SlsperId, ''),
       SlsName = s.Name,
       CustID = c.CustId,
       MaKHCu = c.RefCustID,
	   [Mã Khách Hàng Chung]=ge.PubCust,
       [Khách Hàng Chung] = ge.CustName,
       CustName = c.CustName,
	   [Chủ NT Trên GPKD]= ISNULL(c.BusinessName,''),
       custaddress = ISNULL(c.Addr1 + ', ', '') --+ ISNULL(c.Addr2 + ', ', '')
                     + ISNULL(w.Name + ', ', '') + ISNULL(di.Name + ', ', '') + CASE c.State
                                                                                    WHEN '13' THEN
                                                                                        ''
                                                                                    WHEN '15' THEN
                                                                                        ''
                                                                                    WHEN '24' THEN
                                                                                        ''
                                                                                    WHEN '30' THEN
                                                                                        ''
                                                                                    WHEN '28' THEN
                                                                                        N'Thành Phố' + ' '
                                                                                    ELSE
                                                                                        N'Tỉnh' + ' '
                                                                                END + ISNULL(si.Descr, ''),
       [Mã Khách Hàng Thuế] = m.CustIDInvoice,
       [Mã Khách Hàng Thuế Cũ] = i.OldCustIDInvoice,
       [Tên Khách Hàng Thuế] = i.CustNameInvoice,
       [Mã Số Thuế] = i.TaxID,
       [Địa Chỉ Khách Hàng Thuế] = CONCAT(i.ApartNumber, ', ', iWard.Name, ', ', iDis.Name, ', ', iState.Descr),
       Contact = ISNULL(c.Attn, ''),
       [Email Khách Hàng Thuế] = ISNULL(i.EmailInvoice, ''),
       [Người Mua Hàng] = ISNULL(c.ShoperID, ''),
       [Thời Hạn Thanh Toán] = ISNULL(c.Terms, ''),
       [Khu Vực] = st1.Descr,
       [Mã Tỉnh/TP] = c.State,
       [Tỉnh/TP] = si.Descr,
       [Mã Quận/Huyện] = c.District,
       [Quận/Huyện] = di.Name,
       [Mã Phường/Xã] = c.Ward,
       [Phường/Xã] = w.Name,
       [Số Nhà Và Tên Đường] = c.Addr1,
       [Mã Tỉnh/TP GH] = del.state,
       [Tỉnh/TP GH] = del.statename,
       [Mã Quận/Huyện GH] = del.distrist,
       [Quận/Huyện GH] = del.distname,
       [Mã Phường/Xã GH] = del.Ward,
       [Phường/Xã GH] = del.Wardname,
       --[Địa Chỉ GH] = del.addr,
       --[Địa Chỉ GH]=(Case when Isnull(c.Addr1, '') = '' then '' else c.Addr1 + ', ' + c.Addr2  + ', ' end
       --	+ Case when Isnull(w.Name, '') = '' then '' else w.Name + ', ' end
       --	+ Case when Isnull(di.Name, '') = '' then '' else di.Name + ', ' end
       --	+ Case when Isnull(si.Descr, '') = '' then '' else si.Descr + N', Việt Nam' end),
       --  [Địa Chỉ GH]=  CASE when ISNULL(c.Addr2,'')= '' THEN c.Addr1 ELSE c.Addr1 +', '+c.Addr2 end--- + Tên Đường
       --+ ISNULL(', ' + NULLIF(w.Name,''), '') --- + phường Xã
       --+ ISNULL(', ' + NULLIF(ISNULL(di.[Name], ''),''), '') ---- + Quận Huyện
       --+ ISNULL(', ' + NULLIF(ISNULL(case when si.code='1' then si.[Descr] else case when si.state='28' then N'Thành phố ' else N'Tỉnh ' end+ si.[Descr] end, ''),''), '') ---- + Tỉnh/Thành Phố
       --+ ISNULL(', ' + NULLIF(ISNULL(Stc.[descr], ''),''), ''),
       [Địa Chỉ GH] = del.addr,
       Tel = c.Phone,
       --GeneralCustID=c.CustIDPublic,
       --CustIDPublicName=ge.GeneralCustName,
       [Mã HTBH] = c.SalesSystem,
       [Tên HTBH] = ss.Descr,
       ChannelID = c.Channel,
       ChannelName = ch.Descr,
       [Kênh Phụ] = c.ShopType,
       [Tên Kênh Phụ] = sty.Descr,
       HCOID = c.HCOID,
       HCOName = hco.HCOName,
       HCOTypeID = c.HCOTypeID,
       [Tên Loại HCO] = hcoty.HCOTypeName,
       [Phân Hạng HCO] = c.ClassId,
       [Tên Phân Hạng HCO] = cl.Descr,
       [Kiểm Tra Nợ] = CASE c.CheckTerm
                           WHEN N'N' THEN
                               N'Không Kiểm Tra'
                           WHEN N'D' THEN
                               N'Kiểm Tra Nợ Quá Hạn'
                           ELSE
                               ''
                       END,
       [Hạn Thanh Toán] = c.Terms,
       [Số Ngày Được Nợ] = CAST(CASE
                                    WHEN Te.DueType = 'F' THEN
                                        Te.DueIntrv + 30
                                    WHEN Te.TermsID = 'O1' THEN
                                        30
                                    WHEN Te.TermsID IS NULL THEN
                                        0
                                    ELSE
                                        Te.DueIntrv
                                END AS INT),
       [Tên Hạn Thanh Toán] = Te.Descr,
       --[Hình Thức Thanh Toán]=c.Paymentsform,
       [Tên Hình Thức Thanh Toán] = pa.Descr,
       --[Mã Tự Động Tạo HĐ]=c.GenOrders,
       [Tên Tự Động Tạo HĐ] = ord.Descr,
       --[Hình Thức Xuất Lô]=c.BatchExpForm,
       [Tên Hình Thức Xuất Lô] = ex.Descr,
       CreateUser = c.Crtd_User,
       CreateDate = c.Crtd_Datetime,
       Status = CASE
                    WHEN c.Status = 'A' THEN
                        N'Đang Hoạt Động'
                    WHEN c.Status = 'I' THEN
                        N'Ngưng Hoạt Động'
                    WHEN c.Status = 'H' THEN
                        N'Chờ Xử Lý'
                END,
       Longitude = ISNULL(Cusl.Lng, 0),
       Latitude = ISNULL(Cusl.Lat, 0),
       [HTT theo giá trị] = CASE
                                WHEN c.Terms = '12' THEN
                                    '120'
                                WHEN c.Terms = '18' THEN
                                    '180'
                                ELSE
                                    ISNULL(c.Terms, '')
                            END,
       [Người Chỉnh Sửa] = us.FirstName,
       [Phạm Vi Kinh Doanh] = bs.Descr,
       [Loại MST] = atx.Descr,
       [Phân Loại Thuế Khoán] = ass.Descr,
       [Số Lượng Hình Upload] = ISNULL(np.NumPic, 0),
       [Mã DLPP] = ISNULL(dlpp.CustId, ''),
       [Tên DLPP] = ISNULL(dlpp.CustName, ''),
       [Lý Do Ngưng Hoạt Động] = ISNULL(c.InActive, ''),
       [Hồ Sơ Pháp Lý] = ISNULL(c.Fax, ''),
       [Phụ Trách Khoa Dược] = ISNULL(c.ChargePhar, ''),
       [Phụ Trách Thanh Toán] = ISNULL(c.ChargePayment, ''),
	   [Phụ Trách Nhận Hàng]= ISNULL(c.ChargeReceive,''),
	   [Tên Trên Giấy GDP/GPP]= ISNULL(c.LegalName,''),
	   [Thời Gian Hiệu Lực GDP/GPP]= ISNULL(c.LegalDate,''),
	   [Loại Hình Kinh Doanh]=mtb.Descr,
	   [Số Giấy GPP]=c.OriCustID,
	   [Số Giấy Đủ ĐKKDD]=c.GeneralCustID,
	   [Ngày Cấp Đủ ĐKKDD]= ISNULL(c.EstablishDate,''),
	   [Ghi Chú Điều Chỉnh]=c.BillMarket
FROM AR_Customer c WITH (NOLOCK)
    LEFT JOIN AR_Customer dlpp
        ON c.AgencyID = dlpp.CustId
           AND dlpp.IsAgency = 1
    LEFT JOIN dbo.AR_CustomerLocation Cusl WITH (NOLOCK)
        ON Cusl.BranchID = c.BranchID
           AND Cusl.CustID = c.CustId

    LEFT JOIN dbo.AR_Customer_InvoiceCustomer m WITH (NOLOCK)
        ON m.CustID = c.CustId
           AND m.Active = 1
    LEFT JOIN dbo.AR_CustomerInvoice i WITH (NOLOCK)
        ON m.CustIDInvoice = i.CustIDInvoice
    LEFT JOIN dbo.SI_State iState WITH (NOLOCK)
        ON i.State = iState.State
    LEFT JOIN dbo.SI_District iDis WITH (NOLOCK)
        ON i.DistrictID = iDis.District
           AND iDis.State = i.State
    LEFT JOIN dbo.SI_Ward iWard WITH (NOLOCK)
        ON i.Ward = iWard.Ward
           AND i.DistrictID = iWard.District
           AND i.State = iWard.State
    LEFT JOIN dbo.AR_CustClass cl WITH (NOLOCK)
        ON cl.ClassId = c.ClassId
    LEFT JOIN AR_Salesperson s WITH (NOLOCK)
        ON s.BranchID = c.BranchID
           AND s.SlsperId = c.SlsperId
    LEFT JOIN vs_Company co WITH (NOLOCK)
        ON c.BranchID = co.CpnyID
    LEFT JOIN dbo.SI_Territory st WITH (NOLOCK)
        ON st.Territory = co.Territory
    LEFT JOIN dbo.SI_Territory st1 WITH (NOLOCK)
        ON st1.Territory = c.Territory
    LEFT JOIN dbo.SI_Zone sz WITH (NOLOCK)
        ON sz.Code = st.Zone
    LEFT JOIN dbo.AR_ShopType sty WITH (NOLOCK)
        ON sty.Code = c.ShopType
    LEFT JOIN dbo.AR_Channel ch WITH (NOLOCK)
        ON ch.Code = c.Channel
    LEFT JOIN dbo.SI_District di WITH (NOLOCK)
        ON c.District = di.District
           AND c.State = di.State
    LEFT JOIN dbo.SI_State si WITH (NOLOCK)
        ON si.State = c.State
    INNER JOIN SI_Country stc WITH (NOLOCK)
        ON stc.CountryID = si.Country
    LEFT JOIN dbo.SI_Ward w WITH (NOLOCK)
        ON w.Ward = c.Ward
           AND w.State = c.State
           AND w.District = c.District
    LEFT JOIN dbo.SYS_SalesSystem ss WITH (NOLOCK)
        ON c.SalesSystem = ss.Code
    LEFT JOIN dbo.AR_HCO hco WITH (NOLOCK)
        ON c.HCOID = hco.HCOID
    LEFT JOIN dbo.AR_HCOType hcoty WITH (NOLOCK)
        ON c.HCOTypeID = hcoty.HCOTypeID
    LEFT JOIN dbo.SI_Terms Te WITH (NOLOCK)
        ON c.Terms = Te.TermsID
    LEFT JOIN dbo.AR_MasterPayments pa WITH (NOLOCK)
        ON c.PaymentsForm = pa.Code
    LEFT JOIN dbo.AR_MasterAutoGenOrder ord WITH (NOLOCK)
        ON c.GenOrders = ord.Code
    LEFT JOIN dbo.AR_PublicCust ge WITH (NOLOCK)
        ON c.CustIdPublic = ge.PubCust
    LEFT JOIN dbo.AR_MasterBatchExpForm ex WITH (NOLOCK)
        ON c.BatchExpForm = ex.Code
    LEFT JOIN #delivery del WITH (NOLOCK)
        ON del.CustId = c.CustId
           AND del.BranchID = c.BranchID
    LEFT JOIN Users us WITH (NOLOCK)
        ON UserName = c.LUpd_User
    LEFT JOIN #BusinessScope bs WITH (NOLOCK)
        ON bs.CustId = c.CustId
    LEFT JOIN dbo.AR_TaxDeclaration atx WITH (NOLOCK)
        ON atx.Code = c.TaxDeclaration
    LEFT JOIN AR_StockSales ass WITH (NOLOCK)
        ON ass.Code = c.StockSales
    LEFT JOIN #NumPic np WITH (NOLOCK)
        ON np.CustID = c.CustId
	LEFT JOIN dbo.AR_MasterBusinessType mtb WITH (NOLOCK) ON mtb.Code=c.Market
WHERE c.BranchID IN (
                        SELECT * FROM @TCpnyID
                    );

DROP TABLE #delivery;

DROP TABLE #BusinessScope;
DROP TABLE #NumPic;

GO