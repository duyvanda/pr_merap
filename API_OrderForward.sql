USE [PhaNam_eSales_PRO]
GO

/****** Object:  StoredProcedure [dbo].[Api_OrderForward]    Script Date: 18/03/2022 9:34:35 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

  
ALTER PROC [dbo].[Api_OrderForward] -- Api_OrderForward '20220307'  
 @DateGetData AS Date   
AS   
  
--USE PhaNam_eSales_PRO_INTERNAL  
  
---DECLARE @DateGetData AS Date  ='20220117'  
IF @DateGetData = ''  
SET @DateGetData = CAST(GetDate() AS DATE)
  
/*Lấy danh sách các đơn hàng xuất bán và đơn tra CO trong cùng 1 ngày*/  
  
SELECT co.BranchID,COOrDer=co.OrderNbr, INOrderNbr=ino.OrderNbr,OrigOrderNbr=ino.OrigOrderNbr  
INTO #WithOutOrderNbr  
FROM dbo.OM_SalesOrd co WITH (NOLOCK)   
INNER JOIN dbo.OM_SalesOrd ino WITH(NOLOCK) ON ino.BranchID = co.BranchID AND co.InvcNbr=ino.InvcNbr AND co.InvcNote=ino.InvcNote AND ino.OrderDate = co.OrderDate  
WHERE co.OrderType in ('CO' ,'HK')  
AND ino.OrderType in ('IN' ,'IO','EP','NP')  
AND co.Status='C'   
AND CAST(co.OrderDate AS DATE)= @DateGetData  
  
SELECT DISTINCT bat.BranchID, bat.BatNbr,it.RefNbr, bat.Module, bat.JrnlType,it.TranDate  
INTO #TBatNbr  
FROM dbo.IN_Trans it WITH(NOLOCK)  
INNER JOIN dbo.Batch bat WITH (NOLOCK) ON bat.BatNbr = it.BatNbr AND bat.BranchID = it.BranchID and bat.module='IN'  
WHERE it.InvtMult=-1 AND it.Rlsed=1  --- Ngochb chỉnh lấy Rlsed từ In_Trans trường hợp trùng batnbr   
AND CAST(it.TranDate AS DATE)=@DateGetData   
--AND bat.BatNbr='IN5518' AND bat.BranchID='MR0001'  
  
  
/*Đơn OM, lấy ra thông tin đơn bán, chưa bao gồm dòng trả chiết khấu*/  
/*Trường hợp đặc biệt  
+ Đơn NI ( Xuất vật tư, xuất kho không hóa đơn)  
*/  
  
/*Promotype  
AC: Tích lũy trả ngay => lấy giá trị tham gia tích lũy  
PR: Chương trình khuyến mãi  
SP: Chính sách bán hàng  
*/  
  
SELECT DISTINCT ord.BranchID, ord.OrderNbr,d.InvtID,d.LineRef,dis.FreeItemID, sq.TypeDiscount  
, DiscAmt=    CASE WHEN dis.DiscType='L' then d.DiscAmt  
         WHEN dis.DiscType='G' THEN d.GroupDiscAmt1  
         WHEN dis.DiscType='D' THEN d.DocDiscAmt  
       END  
       
, DiscPct =  CASE WHEN dis.DiscType='L' then d.DiscPct  
         WHEN dis.DiscType='G' THEN d.GroupDiscPct1  
         WHEN dis.DiscType='D' THEN d.DocDiscAmt -- Chưa biết tính như thế nào  
    END   
,sq.DiscIDPN ,sq.DiscID, sq.DiscSeq,dis.SOLineRef  
INTO #TOrdDisc1  
FROM #TBatNbr bat  
INNER JOIN dbo.OM_SalesOrd ord WITH (NOLOCK) ON ord.BranchID = bat.BranchID AND bat.BatNbr=ord.INBatNbr  
INNER JOIN dbo.OM_SalesOrdDet d WITH (NOLOCK) ON d.BranchID = ord.BranchID AND d.OrderNbr = ord.OrderNbr  
INNER JOIN dbo.OM_OrdDisc dis WITH (NOLOCK) ON dis.BranchID=d.BranchID AND dis.OrderNbr=d.OrderNbr AND d.LineRef IN (SELECT part FROM dbo.fr_SplitStringMAX(dis.GroupRefLineRef,','))  
INNER JOIN dbo.OM_DiscSeq sq WITH (NOLOCK) ON sq.DiscID=dis.DiscID AND sq.DiscSeq=dis.DiscSeq  
WHERE bat.JrnlType='OM' --AND dis.FreeItemID=''  
  
  
  
SELECT DISTINCT d.BranchID, d.OrderNbr,d.InvtID,d.LineRef, d.TypeDiscount  
, d.DiscAmt  
, d.DiscPct   
,d.DiscIDPN ,d.DiscID, d.DiscSeq   
INTO #TOrdDisc  
FROM #TOrdDisc1 d  
WHERE d.FreeItemID=''  
  
--- Lấy danh sách sản phẩm khuyến mãi  
CREATE TABLE #TDiscFreeItem (BranchID VARCHAR(30),OrderNbr VARCHAR(30),FreeItemID VARCHAR(30),TypeDiscount VARCHAR(30), DiscAmt FLOAT,DiscPct FLOAT  
,DiscIDPN VARCHAR(30),DiscID VARCHAR(30), DiscSeq VARCHAR(30),SOLineRef VARCHAR(30)  
 )  
INSERT INTO #TDiscFreeItem  
(  
    BranchID,  
    OrderNbr,  
    FreeItemID,  
    TypeDiscount,  
 DiscAmt,  
 DiscPct,  
    DiscIDPN,  
    DiscID,  
 DiscSeq,  
    SOLineRef  
)  
  
SELECT DISTINCT dis.BranchID, dis.OrderNbr,dis.FreeItemID, dis.TypeDiscount,0,0  
  
,dis.DiscIDPN ,dis.DiscID, dis.DiscSeq ,dis.SOLineRef  
  
FROM #TOrdDisc1 dis  
INNER JOIN dbo.OM_SalesOrdDet d ON dis.BranchID=d.BranchID AND dis.OrderNbr=d.OrderNbr AND dis.FreeItemID=d.InvtID AND dis.SOLineRef=d.LineRef  
WHERE FreeItemID<>'' AND d.FreeItem=1  
  
  
--UNION ALL  -- Trường hợp tách hóa đơn, chỉ có sản phẩm khuyến mãi 1 hóa đơn. Chưa đẩy vào OM_OrdDisc nên dùng cách này/ SOlineref<> Lineref  
INSERT INTO #TDiscFreeItem  
(  
    BranchID,  
    OrderNbr,  
    FreeItemID,  
    TypeDiscount,  
    DiscAmt,  
    DiscPct,  
    DiscIDPN,  
    DiscID,  
    DiscSeq,  
    SOLineRef  
)  
  
SELECT DISTINCT ord.BranchID, ord.OrderNbr,pdis.FreeItemID, sq.TypeDiscount  
, DiscAmt=0  
, DiscPct=0  
,sq.DiscIDPN ,sq.DiscID, sq.DiscSeq,SOLineRef=d.LineRef  
FROM #TBatNbr bat  
INNER JOIN dbo.OM_SalesOrd ord WITH (NOLOCK) ON ord.BranchID = bat.BranchID AND bat.BatNbr=ord.INBatNbr  
INNER JOIN dbo.OM_SalesOrdDet d WITH (NOLOCK) ON d.BranchID = ord.BranchID AND d.OrderNbr = ord.OrderNbr  
INNER JOIN dbo.OM_PDAOrdDisc pdis WITH (NOLOCK) ON pdis.BranchID=d.BranchID AND pdis.OrderNbr=d.OrigOrderNbr AND d.InvtID=pdis.FreeItemID AND d.FreeItem=1 AND d.OriginalLineRef=pdis.SOLineRef  
INNER JOIN dbo.OM_DiscSeq sq WITH (NOLOCK) ON sq.DiscID=pdis.DiscID AND sq.DiscSeq=pdis.DiscSeq  
LEFT JOIN #TDiscFreeItem dis WITH (NOLOCK) ON  dis.BranchID=d.BranchID AND dis.FreeItemID=d.InvtID AND d.OrderNbr=dis.OrderNbr AND d.FreeItem=1 AND dis.SOLineRef=d.LineRef  
WHERE dis.OrderNbr IS NULL  
--) U  
  
/* Lấy giá trị trả tích lũy*/ ---KhoaHNT đổi sang lấy giống hóa đơn để fix lỗi trả có 2 mức thuế  
  
/* Lấy giá trị trả tích lũy*/ ---KhoaHNT đổi sang lấy giống hóa đơn để fix lỗi trả có 2 mức thuế  
  
--SELECT BranchID,OrderNbr, AccumulateID,k.AccumulatedName,AccumulateReward=SUM(AccumulateReward)  
--INTO #DiscAccumulated   
--FROM (  
--SELECT ord.BranchID, ord.OrderNbr,AccumulateReward=soa.Amt,soa.AccumulateID, AccumulatedName= al.Descr  
--FROM #TBatNbr bat  
--INNER JOIN dbo.OM_SalesOrd ord WITH (NOLOCK) ON ord.BranchID = bat.BranchID AND bat.BatNbr=ord.INBatNbr  
--INNER JOIN dbo.OM_SalesOrdAccumulate soa WITH(NOLOCK) ON soa.BranchID = ord.BranchID AND soa.OrderNbr=ord.OrderNbr  
--INNER JOIN dbo.OM_Accumulated al WITH (NOLOCK) ON al.AccumulateID = soa.AccumulateID  
--) K  
--GROUP BY K.BranchID,  
--         K.OrderNbr,  
--         K.AccumulateID,  
--         K.AccumulatedName  
  
  
  
  
  
  
SELECT  ---- Thông Tin Header  
    T1.BranchID,   
    T1.OrderNbr,   
    T1.OrderDate,   
   -- T1.SalesOrderType,   
  --  T1.InvoiceCustID,  
 --   T5.RoundType,  
--    T5.Decimal,  
  --  T1.CustID,  
    TaxRegNbr = T1.TaxRegNbr,  
   -- CustInvcName = T1.CustInvcName,  
  --  CustInvcEmail = COALESCE (T51.EmailInvoice,''),  --- ngochb đổi qua trường địa chỉ mail mới  
  ---  Buyer = CONVERT(NVARCHAR(200), case c.ShoperID WHEN '' then N'-' else c.ShoperID end),  
   -- CustInvcApartNumber = COALESCE (T51.ApartNumber, N''),  
 --   CustInvcStreetName = COALESCE (T51.StreetName, N''),  
 --   CustInvcCountry = T51.CountryID,  
 --   CustInvcState = T51.State,  
 --   CustInvcDistrictID = T51.DistrictID,  
 ---   CustInvcWard = T51.Ward,  
 --   CustInvcAddress = CONVERT(NVARCHAR(MAX), N''),  
 --   CustInvcPhone = COALESCE (T51.Phone, ''),  
--    CustInvcBankAccount = COALESCE (T51.BankAccount, ''),  
   --- PaymentMethod = COALESCE (T12.Descr, T1.PaymentsForm,'') ,  
    T1.ContractID,  
    InvoicePattern = T1.Patter,  
    InvoiceSerial = T1.InvcNote,  
    --- Thông tin hóa đơn điều chỉnh, thay thế nếu có  
   -- OldKey = COALESCE (T10.BranchID + T10.OrderNbr, T8.BranchID + T8.OrderNbr, ''),  
  --  OldOrderNumber = COALESCE(T10.InvcNbr, T8.InvcNbr, ''),   
  --  OldOrderDate = COALESCE(CONVERT(VARCHAR,NULLIF(T10.OrderDate,'1900-01-01'),103),CONVERT(VARCHAR,NULLIF(T8.OrderDate,'1900-01-01'),103), ''),  
    ---- HAILH Modified On 01/09/2020: Thêm Field Kiểu dữ liệu datetime để trả ra cho mẫu in hóa đơn AJ, mode = 3  
   -- OldOrderDatetime = COALESCE(T10.OrderDate,T8.OrderDate,'1900-01-01'),  
  --  OldPatter = COALESCE(T10.Patter,T8.Patter,''),  
  --  OldInvcNote = COALESCE(T10.InvcNote, T8.InvcNote,''),  
   -- AjustTaxRegNbr = CASE WHEN T1.TaxRegNbr <> COALESCE(T8.TaxRegNbr,'') THEN T1.TaxRegNbr ELSE '' END,  
  --  AjustCustInvcName = CASE WHEN T1.CustInvcName <> COALESCE(T8.CustInvcName,'') THEN T1.CustInvcName ELSE N'' END,  
    ---- Thông tin detail  
    LineRef = COALESCE(T2.LineRef,''), InvtID =  COALESCE(T2.InvtID,''), Descr =  COALESCE(T2.Descr,''),   
    SlsUnitID = T2.SlsUnit,  
   -- SlsUnit= COALESCE(T6.[FromUnitDescr], T2.SlsUnit, ''),  
    LineQty = COALESCE(T2.LineQty, 0), SlsPrice = COALESCE(T2.SlsPrice, 0), FreeItem = COALESCE(T2.FreeItem,0),   
    LineAmt = COALESCE(T2.LineQty * T2.SlsPrice, 0),  
    ---- HAILH Modified On 13/11/2020: Bổ sung lấy BeforeVATPrice theo dữ liệu đã lưu  
  --  BeforeVATPrice = CASE WHEN COALESCE(T2.FreeItem,0) = 1 THEN 0 ELSE COALESCE(NULLIF(T2.BeforeVATPrice,''),T2.BeforeVATAmount/COALESCE(NULLIF(T2.LineQty,0), T3.QTY, 1),0) END ,   
    BeforeVATAmount =  CASE WHEN COALESCE(T2.FreeItem,0) = 1 THEN 0 ELSE COALESCE(T2.BeforeVATAmount,0) END,   
    AfterVATPrice = CASE WHEN COALESCE(T2.FreeItem,0) = 1 THEN 0 ELSE COALESCE(T2.AfterVATPrice,0) END,   
    AfterVATAmount = CASE WHEN COALESCE(T2.FreeItem,0) = 1 THEN 0 ELSE COALESCE(T2.AfterVATAmount,0) END,  
    VATAmount = CASE WHEN COALESCE(T2.FreeItem,0) = 1 THEN 0 ELSE COALESCE(T2.AfterVATAmount,0) - COALESCE(T2.BeforeVATAmount,0) END, ---- Thay thế bằng cột tiền thuế trên màn hình hóa đơn (Hiện tại chưa lưu)  
   -- T3.InvtMult,  
    ---- Thông tin Lot  
  --  LotSerNbr = COALESCE(T3.LotSerNbr, ''),   
    ---- HAILH Modified On 04/08/2020: Bổ sung lấy Hạn Dùng theo format cài đặt ở Danh Mục Sản Phẩm  
   -- ExpDate= COALESCE(FORMAT(T3.ExpDate, T11.FormatHSD), ''),   
  --  LotQty = COALESCE(T3.Qty, T2.LineQty, 0),  
    ---- Thông tin tax  
    TaxRate = COALESCE(T4.TaxRate,0),  
    ---- TUANTA Modified On 28/10/2020: Thêm Thông Tin Lý Do  
    ReasonCode = T1.ReasonCode,  
    SlsperID = T1.SlsperID  
 INTO  #SalesOrder  
 FROM  OM_SalesOrd T1 WITH(NOLOCK)  
--- INNER JOIN dbo.AR_Customer c WITH(NOLOCK) ON t1.CustID=c.CustId  
 LEFT JOIN OM_SalesOrdDet T2 WITH(NOLOCK)  
  ON  T1.BranchID = T2.BranchID   
    AND T1.OrderNbr = T2.OrderNbr   
-- LEFT JOIN OM_LotTrans T3 WITH(NOLOCK)   
 -- ON  T1.BranchID = T3.BranchID   
---    AND T1.OrderNbr = T3.OrderNbr   
 --   AND T2.LineRef = T3.OMLineRef  
      
 LEFT JOIN SI_Tax T4 WITH(NOLOCK)   
  ON  T2.TaxId00=T4.TaxID    
-- LEFT JOIN AR_Customer_InvoiceCustomer T5 WITH(NOLOCK)  
 -- ON  T1.CustID = T5.CustID  
  --  AND T1.InvoiceCustID = T5.CustIDInvoice  
-- LEFT JOIN AR_CustomerInvoice T51 WITH(NOLOCK)  
 -- ON  T5.CustIDInvoice = T51.CustIDInvoice  
-- LEFT JOIN IN_UnitConversion T6 WITH(NOLOCK)  
--  ON  T6.UnitType = '3'  
--    AND T2.InvtID = T6.InvtID  
--    AND T2.SlsUnit = T6.FromUnit  
 LEFT JOIN OM_Master_SalesOrderType T7 WITH(NOLOCK)   
  ON  T1.SalesOrderType = T7.OrderType  
 --LEFT JOIN OM_SalesOrd T8 WITH(NOLOCK)  
--  ON  T1.BranchID = T8.BranchID  
--    AND   
    ---- TuanTA modified on 19/06/2020 :Nếu là UP or DP thì join từ ReplForOrdNbr Ngược lại join từ OrigOrderNbr  
    ---- TuanTA modified on 15/09/2020 :Nếu là loại Chọn Từ Chi Tiết HĐ thì lấy ReplForOrdNbr Join Thẳng Tới OrderNbr Hóa Đơn  
    -- "OrigType  
    -- 1 Từ Hóa Đơn  
    -- 2 Từ Chi Tiết Hóa Đơn  
    -- 3 Từ Đơn Hàng  
--    CASE   
 --    WHEN T7.OrigType = 2 AND T1.ReplForOrdNbr = T8.OrderNbr THEN 1  
 --    WHEN T7.OrigType <> 2 AND T1.OrigOrderNbr = T8.OrderNbr THEN 1  
 --   ELSE 0  
 --   END = 1  
 ---- HAILH Modified on 31/07/2020: Bổ sung flow cho quy trình đơn trả hàng, đơn hàng điều chỉnh Lô  
 LEFT JOIN OM_PDASalesOrd T9 WITH(NOLOCK)  
  ON  T1.BranchID = T9.BranchID  
    AND T1.OrigOrderNbr = T9.OrderNbr  
 LEFT JOIN OM_SalesOrd T10 WITH(NOLOCK)  
  ON  T9.BranchID = T10.BranchID  
    AND (T9.OrigOrderNbr = T10.OrderNbr OR T9.OriOrderNbrUp = T10.OrderNbr)  
 ---- HAILH Modified On 04/08/2020: Bổ sung lấy Hạn Dùng theo format cài đặt ở Danh Mục Sản Phẩm  
 --LEFT JOIN IN_Inventory T11 WITH(NOLOCK)  
 -- ON  T2.InvtID = T11.InvtID  
  
 ---- HAILH Modified on 27/08/2020: Bổ sung lấy thông tin hình thức thanh toán  
 --LEFT JOIN AR_MasterPayments T12 WITH(NOLOCK)  
--  ON  T1.PaymentsForm = T12.Code  
 WHERE  T1.OrderDate=@DateGetData  
  
  SELECT  T1.BranchID,   
    T1.OrderNbr,   
    T1.AccumulateID,   
    T1.Amt,   
    T3.Crtd_DateTime AS RegisFrom,   
    T2.PurchaseAgreement,  
    T3.PurchaseAgreementID,  
    SUM(T4.LineAmt) AS LineAmt,  
    T1.LineRef  
 INTO  #Accumulated  
 FROM  OM_SalesOrdAccumulate T1 WITH(NOLOCK)  
 LEFT JOIN OM_Accumulated T2 WITH(NOLOCK)  
  ON  T1.AccumulateID = T2.AccumulateID  
 LEFT JOIN   OM_AccumulatedRegis T3 WITH(NOLOCK)  
  ON  T1.AccumulateID = T3.AccumulateID AND T1.CustID = T3.CustID AND T3.BranchID = T1.BranchID --20220112 LangHX where thêm branch  
 LEFT JOIN   #SalesOrder AS T4  
  ON  T1.BranchID = T4.BranchID AND T1.OrderNbr = T4.OrderNbr  
 WHERE   
    T3.Status = 'C' --20220112 LangHX where thêm Status  
 GROUP BY    T1.BranchID,   
    T1.OrderNbr,   
    T1.AccumulateID,   
    T1.Amt,   
    T3.Crtd_DateTime,   
    T2.PurchaseAgreement,  
    T3.PurchaseAgreementID,  
    T1.LineRef  
  
----- Bo sung lay danh sach cac dong tich luy  
 SELECT  T11.BranchID,T11.OrderNbr, T12.AccumulateID,  T11.TaxRate, T12.RegisFrom, T12.PurchaseAgreement, T12.PurchaseAgreementID,   
    Amt = ROUND(SUM(T11.LineAmt / T12.LineAmt * T12.Amt),0)  
    , ROW_NUMBER () OVER (PARTITION BY T12.AccumulateID ORDER BY T12.LineRef) AS RowNum,  
    T12.LineRef  
 INTO  #AccumulateAmount  
 FROM  #SalesOrder T11 WITH(NOLOCK)  
 INNER JOIN #Accumulated T12 WITH(NOLOCK)   
  ON  T11.BranchID = T12.BranchID   
    AND T11.OrderNbr = T12.OrderNbr  
 WHERE  T11.OrderDate=@DateGetData ---AND T11.FreeItem=0  
 Group by T11.OrderNbr, T12.AccumulateID,  T11.TaxRate, T12.RegisFrom, T12.PurchaseAgreement, T12.Amt, T12.PurchaseAgreementID, T12.LineRef,T11.BranchID  
  
 -- Update Dong tich luy dau tien theo gia tri da lam tron  
 UPDATE  T1  
 SET   T1.Amt = T2.Amt - ( SELECT ISNULL(SUM (T11.Amt),0)   
         FROM #AccumulateAmount T11   
         WHERE T1.AccumulateID = T11.AccumulateID AND T1.LineRef = T11.LineRef AND T1.OrderNbr=T11.OrderNbr  
           AND T11.RowNum <> T1.RowNum  
         )  
 FROM  #AccumulateAmount T1  
 LEFT JOIN #Accumulated T2   
  ON  T1.AccumulateID = T2.AccumulateID AND T2.BranchID = T1.BranchID AND T2.OrderNbr = T1.OrderNbr  
 WHERE  T1.RowNum = 1  
  
 ----SELECT * FROM #AccumulateAmount WHERE OrderNbr='HD0-0122-02960'  
  
 SELECT BranchID,OrderNbr, a.AccumulateID,AccumulatedName=b.Descr,AccumulateReward=a.Amt,DiscountVat=a.TaxRate,a.RowNum  
 INTO #DiscAccumulated  
 FROM #AccumulateAmount a WITH(NOLOCK)  
 LEFT JOIN dbo.OM_Accumulated b WITH(NOLOCK) ON b.AccumulateID=a.AccumulateID  
  
SELECT tx.BranchID, tx.OrderNbr, tx.TaxRate   
INTO #TaxOrder  
FROM (   
SELECT ord.BranchID, ord.OrderNbr, tx.TaxRate, RowNumber = ROW_NUMBER() OVER (PARTITION BY ord.BranchID, ord.OrderNbr ORDER BY d.InvtID ASC)  
FROM #TBatNbr bat  
INNER JOIN dbo.OM_SalesOrd ord WITH (NOLOCK) ON ord.BranchID = bat.BranchID AND bat.BatNbr=ord.INBatNbr  
INNER JOIN dbo.OM_SalesOrdDet d WITH (NOLOCK) ON d.BranchID = ord.BranchID AND d.OrderNbr = ord.OrderNbr  
LEFT JOIN dbo.SI_Tax tx WITH (NOLOCK) ON d.TaxCat=tx.CatExcept00 AND d.TaxID00=tx.TaxID  
) tx  
WHERE tx.RowNumber=1  
  
  
CREATE TABLE #temptable ( [DateAddOrder] date, [IDCodeOrder] varchar(15), [DateAddInvoice] smalldatetime, [Symbols] varchar(30), [InvoiceNumber] varchar(30), [IDCodeCus] varchar(50), [IDCodeCusTx] varchar(30), [IDCodeCusTxName] nvarchar(200), [RefIDCodeCusTx] varchar(30), [ProductCode] varchar(30), [LotNo] varchar(25), [DateEx] smalldatetime,
 [IDCodeW] varchar(10), [Quantity] float(8), [ProductPriceDt] float(8), [IntoMoney] float(8), [BeforeVATPrice] float(8), [BeforeVATAmount] float(8), [VATAmount] float(8), [GeneralDiscount] float(8), [PolicyDiscount] float(8), [CumulativeDiscount] float(8), [GeneralDiscountPrice] float(8), [PolicyDiscountPrice] float(8), [CumulativeDiscountPrice] float(8), 
 [GeneralIDCodePromo] varchar(50), [PolicyIDCodePromo] nvarchar(50), [CumulativeIDCodePromo] varchar(50), [CodeSales] varchar(30), [IDCodeDeliverer] varchar(30), [DateOfDebit] varchar(10), [CodeChannel] varchar(30), [IDCodeOffice] varchar(30), [IDCodeWareHouse] varchar(10), [DiscountVat] float(8), 
 [RoundVAT] nvarchar(200), [RoundInvoice] nvarchar(200), [Area] nvarchar(200), [ManagerTeamSup] nvarchar(250), [ManagerAsm] nvarchar(250), [ManagerDirector] nvarchar(250), [TypeOrder] int, [IDCodeOfficeTo] varchar(30), 
 [IDCodeWarehouseTo] varchar(1), [OrderType] varchar(2), [ChannelType] varchar(6), [Note] nvarchar(200), [TaxRegNbr] nvarchar(200), [HCOTypeID] varchar(30) )  
INSERT INTO #temptable  
(  
    DateAddOrder,  
    IDCodeOrder,  
    DateAddInvoice,  
    Symbols,  
    InvoiceNumber,  
    IDCodeCus,  
    IDCodeCusTx,  
    IDCodeCusTxName,  
    RefIDCodeCusTx,  
    ProductCode,  
    LotNo,  
    DateEx,  
    IDCodeW,  
    Quantity,  
    ProductPriceDt,  
    IntoMoney,  
    BeforeVATPrice,  
    BeforeVATAmount,  
    VATAmount,  
    GeneralDiscount,  
    PolicyDiscount,  
    CumulativeDiscount,  
    GeneralDiscountPrice,  
    PolicyDiscountPrice,  
    CumulativeDiscountPrice,  
    GeneralIDCodePromo,  
    PolicyIDCodePromo,  
    CumulativeIDCodePromo,  
    CodeSales,  
    IDCodeDeliverer,  
    DateOfDebit,  
    CodeChannel,  
    IDCodeOffice,  
    IDCodeWareHouse,  
    DiscountVat,  
    RoundVAT,  
    RoundInvoice,  
    Area,  
    ManagerTeamSup,  
    ManagerAsm,  
    ManagerDirector,  
    TypeOrder,  
    IDCodeOfficeTo,  
    IDCodeWarehouseTo,  
    OrderType,  
    ChannelType,  
    Note,  
    TaxRegNbr,  
    HCOTypeID  
)  
SELECT DISTINCT DateAddOrder =CAST(o.OrderDate AS DATE)  
, IDCodeOrder =ISNULL(ord.OrderNbr,o.OrderNbr)  
, DateAddInvoice= o.OrderDate  
, Symbols= o.InvcNote  
, InvoiceNumber= o.InvcNbr  
, IDCodeCus= CASE WHEN c.RefCustID='' THEN c.CustId ELSE c.RefCustID END -- Mặc định lấy theo mã cũ, nếu không có mã cũ lấy theo mã DMS.  
, IDCodeCusTx =o.InvoiceCustID  
, IDCodeCusTxName =cui.CustNameInvoice  
, RefIDCodeCusTx=cui.OldCustIDInvoice  
, ProductCode=d.InvtID  
, LotNo= lt.LotSerNbr  
, DateEx=lt.ExpDate  
, IDCodeW= ISNULL(s.zip,d.SiteID) -- Trường hợp sản phẩm không có lot thì sẽ lấy theo kho của orddet. -- Ngochb chỉnh lại lấy kho GE  
, Quantity= ISNULL(lt.Qty, d.LineQty) -- Trường hợp sản phẩm không có lot thì sẽ lấy theo số lượng của orddet.  
, ProductPriceDt=d.SlsPrice  
, IntoMoney=CASE WHEN ci.RoundType='TT' THEN ISNULL(lt.Qty,d.LineQty)*d.SlsPrice  ELSE ISNULL(lt.Qty,d.LineQty)*d.BeforeVATPrice END -- Nếu đơn hàng INS: LineQty* BeforeVATPrice, OTC: LineQty * Slsprice  
, BeforeVATPrice=d.BeforeVATPrice  
, BeforeVATAmount=d.BeforeVATAmount  
, VATAmount=d.VATAmount  
, GeneralDiscount=CASE WHEN dis.TypeDiscount='SP' THEN dis.DiscPct ELSE 0 END  
, PolicyDiscount = CASE WHEN dis.TypeDiscount='PR' THEN dis.DiscPct ELSE 0 END  
, CumulativeDiscount = CASE WHEN dis.TypeDiscount='AC' THEN dis.DiscPct ELSE 0 END  
, GeneralDiscountPrice = CASE WHEN dis.TypeDiscount='SP' THEN dis.DiscAmt ELSE 0 END  
, PolicyDiscountPrice = CASE WHEN dis.TypeDiscount='PR' THEN dis.DiscAmt ELSE 0 END  
, CumulativeDiscountPrice = CASE WHEN dis.TypeDiscount='AC' THEN dis.DiscAmt ELSE 0 END --CASE WHEN dis.TypeDiscount='AC' THEN dis.DiscAmt ELSE 0 END -- Tạm comment dua vao GE không xử lý được  
, GeneralIDCodePromo = CASE WHEN dis.TypeDiscount='SP' THEN dis.DiscIDPN ELSE '' END  
, PolicyIDCodePromo = CASE WHEN sr.ReasonID IS NOT NULL THEN sr.ProgramID ELSE CASE WHEN dis.TypeDiscount='PR' THEN dis.DiscIDPN ELSE '' END end  
, CumulativeIDCodePromo = CASE WHEN dis.TypeDiscount='AC' THEN dis.DiscIDPN ELSE '' END  
, CodeSales=d.SlsperID  
, IDCodeDeliverer=ib.SlsperID  
, DateOfDebit=o.Terms  
, CodeChannel =ISNULL(ch.ShopType, c.ShopType)  
, IDCodeOffice=o.BranchID  
, IDCodeWareHouse =ISNULL(s.zip,d.SiteID) -- Ngochb chỉnh lại lấy kho GE  
, DiscountVat= tx.TaxRate 
, RoundVAT= mty.Descr  
, RoundInvoice =mty.Descr  
, Area =ISNULL(ste.Descr,'')  
, ManagerTeamSup=sup.FirstName  
, ManagerAsm = am.FirstName  
, ManagerDirector= rm.FirstName  
, TypeOrder= CASE WHEN sr.ReasonID IS NOT NULL THEN 1 ELSE 0 END  
, IDCodeOfficeTo= CASE WHEN vp.BranchID IS NOT NULL THEN vp.BranchID ELSE '' END  
, IDCodeWarehouseTo=''  
, o.OrderType  
, ChannelType= CASE WHEN c.SalesSystem='1' THEN 'INS' ELSE 'Orther' END  
, Note=LOWER(o.Remark)  
, o.TaxRegNbr  
, c.HCOTypeID  
FROM dbo.OM_SalesOrd o WITH (NOLOCK)  
INNER JOIN dbo.OM_SalesOrdDet d WITH (NOLOCK) ON d.BranchID = o.BranchID AND d.OrderNbr = o.OrderNbr  
INNER JOIN IN_Site s  WITH (NOLOCK) ON d.SiteID=s.SiteID  
INNER JOIN #TBatNbr bat WITH (NOLOCK) ON bat.BranchID =o.BranchID AND bat.BatNbr=o.INBatNbr and bat.RefNbr=o.ARRefNbr --- Ngochb bổ sung join RefNbr cho trường hợp trùng BatNbr  
LEFT JOIN dbo.AR_HistoryCustClassID ch WITH(NOLOCK) ON ch.Version = o.Version AND ch.CustID = o.CustID  
INNER JOIN dbo.AR_Customer c WITH(NOLOCK) ON c.CustId=o.CustID  
LEFT JOIN dbo.AR_Customer_InvoiceCustomer ci WITH (NOLOCK) ON ci.CustID = c.CustId AND o.InvoiceCustID=ci.CustIDInvoice  
LEFT JOIN dbo.AR_CustomerInvoice cui WITH (NOLOCK) ON cui.CustIDInvoice=o.InvoiceCustID  
LEFT JOIN dbo.AR_MasterRoundType mty WITH (NOLOCK) ON mty.Code=ci.RoundType  
LEFT JOIN dbo.SI_Territory ste WITH (NOLOCK) ON ste.Territory=c.Territory  
LEFT JOIN dbo.fr_ListSaleByData('admin') lsb ON lsb.SlsperID=d.SlsperID AND lsb.BranchID=d.BranchID  
LEFT JOIN dbo.Users sup WITH (NOLOCK) ON sup.UserName=lsb.SupID  
LEFT JOIN dbo.Users am WITH (NOLOCK) ON am.UserName=lsb.ASM  
LEFT JOIN dbo.Users rm WITH (NOLOCK) ON rm.UserName=lsb.RSMID  
LEFT JOIN dbo.SI_Tax tx WITH (NOLOCK) ON d.TaxCat=tx.CatExcept00 AND d.TaxID00=tx.TaxID  
LEFT JOIN dbo.OM_IssueBookDet ibd WITH (NOLOCK) ON ibd.BranchID=o.BranchID AND ibd.OrderNbr=o.OrigOrderNbr  
LEFT JOIN dbo.OM_IssueBook ib WITH (NOLOCK) ON ib.BatNbr = ibd.BatNbr AND ib.BranchID = ibd.BranchID  
LEFT JOIN dbo.OM_LotTrans lt WITH (NOLOCK) ON lt.BranchID = d.BranchID AND lt.OrderNbr = d.OrderNbr AND lt.InvtID = d.InvtID AND lt.OMLineRef=d.LineRef  
LEFT JOIN dbo.OM_PDASalesOrd ord WITH (NOLOCK) ON o.OrigOrderNbr=ord.OrderNbr AND ord.BranchID = o.BranchID  
LEFT JOIN #TOrdDisc dis WITH (NOLOCK) ON dis.BranchID=d.BranchID AND dis.OrderNbr=d.OrderNbr AND dis.LineRef=d.LineRef  
LEFT JOIN dbo.SI_ReasonCode sr WITH (NOLOCK) ON sr.ReasonID=o.ReasonCode  
LEFT JOIN dbo.AP_VendorMap vp WITH (NOLOCK) ON vp.BranchIDMap = c.BranchID AND vp.CustID=c.CustId  
LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK) ON woo.INOrderNbr=o.OrderNbr AND woo.BranchID=o.BranchID  
  
WHERE bat.JrnlType='OM' AND d.FreeItem=0 AND woo.INOrderNbr IS NULL  --AND bat.BatNbr='IN0028' AND bat.BranchID='MR0014'  
--and o.OrderType in ('IN','IO')   
--AND o.SalesOrderType  in ('IN','IO')-- ngochb bổ sung thêm cần trao đổi thêm với chị Quỳnh để phân loại lại  
  
----UNION ALL  
  
INSERT INTO #temptable  
(  
    DateAddOrder,  
    IDCodeOrder,  
    DateAddInvoice,  
    Symbols,  
    InvoiceNumber,  
    IDCodeCus,  
    IDCodeCusTx,  
    IDCodeCusTxName,  
    RefIDCodeCusTx,  
    ProductCode,  
    LotNo,  
    DateEx,  
    IDCodeW,  
    Quantity,  
    ProductPriceDt,  
    IntoMoney,  
    BeforeVATPrice,  
    BeforeVATAmount,  
    VATAmount,  
    GeneralDiscount,  
    PolicyDiscount,  
    CumulativeDiscount,  
    GeneralDiscountPrice,  
    PolicyDiscountPrice,  
    CumulativeDiscountPrice,  
    GeneralIDCodePromo,  
    PolicyIDCodePromo,  
    CumulativeIDCodePromo,  
    CodeSales,  
    IDCodeDeliverer,  
    DateOfDebit,  
    CodeChannel,  
    IDCodeOffice,  
    IDCodeWareHouse,  
    DiscountVat,  
    RoundVAT,  
    RoundInvoice,  
    Area,  
    ManagerTeamSup,  
    ManagerAsm,  
    ManagerDirector,  
    TypeOrder,  
    IDCodeOfficeTo,  
    IDCodeWarehouseTo,  
    OrderType,  
    ChannelType,  
    Note,  
    TaxRegNbr,  
    HCOTypeID  
)  
--- Lấy lên dòng sản phẩm tặng  
SELECT DateAddOrder =CAST(o.OrderDate AS DATE)  
, IDCodeOrder =ISNULL(ord.OrderNbr,o.OrderNbr)  
, DateAddInvoice= o.OrderDate  
, Symbols= o.InvcNote  
, InvoiceNumber= o.InvcNbr  
, IDCodeCus= CASE WHEN c.RefCustID='' THEN c.CustId ELSE c.RefCustID END -- Mặc định lấy theo mã cũ, nếu không có mã cũ lấy theo mã DMS.  
, IDCodeCusTx =o.InvoiceCustID  
, IDCodeCusTxName =cui.CustNameInvoice  
, RefIDCodeCusTx = cui.OldCustIDInvoice  
, ProductCode=d.InvtID  
, LotNo= lt.LotSerNbr  
, DateEx=lt.ExpDate  
, IDCodeW= ISNULL(s.zip,d.SiteID) -- Trường hợp sản phẩm không có lot thì sẽ lấy theo kho của orddet. -- Ngochb chỉnh lại lấy kho GE  
, Quantity= ISNULL(lt.Qty, d.LineQty) -- Trường hợp sản phẩm không có lot thì sẽ lấy theo số lượng của orddet.  
, ProductPriceDt=CASE WHEN d.FreeItem=1 THEN 0 ELSE d.SlsPrice end  
, IntoMoney=  CASE WHEN ci.RoundType='TT' THEN IIF(d.freeitem=1,0, ISNULL(lt.Qty,d.LineQty)*d.SlsPrice) ELSE IIF(d.freeitem=1, 0, ISNULL(lt.Qty,d.LineQty)*d.BeforeVATPrice) END -- Nếu đơn hàng INS: LineQty* BeforeVATPrice, OTC: LineQty * Slsprice  
, BeforeVATPrice=0  
, BeforeVATAmount=0  
, VATAmount=0  
, GeneralDiscount=CASE WHEN dis.TypeDiscount='SP' THEN dis.DiscPct ELSE 0 END  
, PolicyDiscount = CASE WHEN dis.TypeDiscount='PR' THEN dis.DiscPct ELSE 0 END  
, CumulativeDiscount = CASE WHEN dis.TypeDiscount='AC' THEN dis.DiscPct ELSE 0 END  
, GeneralDiscountPrice = CASE WHEN dis.TypeDiscount='SP' THEN dis.DiscAmt ELSE 0 END  
, PolicyDiscountPrice = CASE WHEN dis.TypeDiscount='PR' THEN dis.DiscAmt ELSE 0 END  
, CumulativeDiscountPrice =0 --CASE WHEN dis.TypeDiscount='AC' THEN dis.DiscAmt ELSE 0 END -- Tamj comment, dua vao GE khong xu ly duoc  
, GeneralIDCodePromo = CASE WHEN dis.TypeDiscount='SP' THEN dis.DiscIDPN ELSE '' END  
, PolicyIDCodePromo = CASE WHEN sr.ReasonID IS NOT NULL THEN sr.ProgramID ELSE CASE WHEN dis.TypeDiscount='PR' THEN dis.DiscIDPN ELSE '' END end  
, CumulativeIDCodePromo = CASE WHEN dis.TypeDiscount='AC' THEN dis.DiscIDPN ELSE '' END  
, CodeSales=d.SlsperID  
, IDCodeDeliverer=ib.SlsperID  
, DateOfDebit=o.Terms  
, CodeChannel =ISNULL(ch.ShopType, c.ShopType)  
, IDCodeOffice=o.BranchID  
, IDCodeWareHouse =ISNULL(s.zip,d.SiteID) -- Ngochb chỉnh lại lấy kho GE  
, DiscountVat= tx.TaxRate  
, RoundVAT= mty.Descr  
, RoundInvoice =mty.Descr  
, Area =ISNULL(ste.Descr,'')  
, ManagerTeamSup=sup.FirstName  
, ManagerAsm = am.FirstName  
, ManagerDirector= rm.FirstName  
, TypeOrder= CASE WHEN sr.ReasonID IS NOT NULL THEN 1 ELSE 0 END  
, IDCodeOfficeTo= CASE WHEN vp.BranchID IS NOT NULL THEN vp.BranchID ELSE '' END  
, IDCodeWarehouseTo=''  
, o.OrderType  
, ChannelType= CASE WHEN c.SalesSystem='1' THEN 'INS' ELSE 'Orther' END  
, Note=LOWER(o.Remark)  
, o.TaxRegNbr  
, c.HCOTypeID  
FROM dbo.OM_SalesOrd o WITH (NOLOCK)  
INNER JOIN dbo.OM_SalesOrdDet d WITH (NOLOCK) ON d.BranchID = o.BranchID AND d.OrderNbr = o.OrderNbr  
INNER JOIN IN_Site s  WITH (NOLOCK) ON d.SiteID=s.SiteID  
INNER JOIN #TBatNbr bat WITH (NOLOCK) ON bat.BranchID =o.BranchID AND bat.BatNbr=o.INBatNbr and bat.RefNbr=o.ARRefNbr  --- Ngochb bổ sung join RefNbr cho trường hợp trùng BatNbr  
LEFT JOIN dbo.AR_HistoryCustClassID ch WITH(NOLOCK) ON ch.Version = o.Version AND ch.CustID = o.CustID  
INNER JOIN dbo.AR_Customer c WITH(NOLOCK) ON c.CustId=o.CustID  
INNER JOIN #TDiscFreeItem dis WITH (NOLOCK) ON dis.BranchID=d.BranchID AND dis.OrderNbr=d.OrderNbr AND dis.FreeItemID=d.InvtID AND dis.SOLineRef=d.LineRef  
LEFT JOIN dbo.AR_Customer_InvoiceCustomer ci WITH (NOLOCK) ON ci.CustID = c.CustId AND o.InvoiceCustID=ci.CustIDInvoice  
LEFT JOIN dbo.AR_CustomerInvoice cui WITH (NOLOCK) ON cui.CustIDInvoice=o.InvoiceCustID  
LEFT JOIN dbo.AR_MasterRoundType mty WITH (NOLOCK) ON mty.Code=ci.RoundType  
LEFT JOIN dbo.SI_Territory ste WITH (NOLOCK) ON ste.Territory=c.Territory  
LEFT JOIN dbo.fr_ListSaleByData('admin') lsb ON lsb.SlsperID=d.SlsperID AND lsb.BranchID=d.BranchID  
LEFT JOIN dbo.Users sup WITH (NOLOCK) ON sup.UserName=lsb.SupID  
LEFT JOIN dbo.Users am WITH (NOLOCK) ON am.UserName=lsb.ASM  
LEFT JOIN dbo.Users rm WITH (NOLOCK) ON rm.UserName=lsb.RSMID  
LEFT JOIN dbo.SI_Tax tx WITH (NOLOCK) ON d.TaxCat=tx.CatExcept00 AND d.TaxID00=tx.TaxID  
LEFT JOIN dbo.OM_IssueBookDet ibd WITH (NOLOCK) ON ibd.BranchID=o.BranchID AND ibd.OrderNbr=o.OrigOrderNbr  
LEFT JOIN dbo.OM_IssueBook ib WITH (NOLOCK) ON ib.BatNbr = ibd.BatNbr AND ib.BranchID = ibd.BranchID  
LEFT JOIN dbo.OM_LotTrans lt WITH (NOLOCK) ON lt.BranchID = d.BranchID AND lt.OrderNbr = d.OrderNbr AND lt.InvtID = d.InvtID AND lt.OMLineRef=d.LineRef  
LEFT JOIN dbo.OM_PDASalesOrd ord WITH (NOLOCK) ON o.OrigOrderNbr=ord.OrderNbr AND ord.BranchID = o.BranchID  
LEFT JOIN dbo.SI_ReasonCode sr WITH (NOLOCK) ON sr.ReasonID=o.ReasonCode  
LEFT JOIN dbo.AP_VendorMap vp WITH (NOLOCK) ON vp.BranchIDMap = c.BranchID AND vp.CustID=c.CustId  
LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK) ON woo.INOrderNbr=o.OrderNbr AND woo.BranchID=o.BranchID  
  
WHERE bat.JrnlType='OM' AND d.FreeItem=1  AND woo.INOrderNbr IS NULL  
--and o.OrderType in ('IN','IO')   
--AND o.SalesOrderType  in ('IN','IO')-- ngochb bổ sung thêm cần trao đổi thêm với chị Quỳnh để phân loại lại  
--- Lấy lên giá trị trả tích lũy ở dòng mới  
  
---UNION ALL  
INSERT INTO #temptable  
(  
    DateAddOrder,  
    IDCodeOrder,  
    DateAddInvoice,  
    Symbols,  
    InvoiceNumber,  
    IDCodeCus,  
    IDCodeCusTx,  
    IDCodeCusTxName,  
    RefIDCodeCusTx,  
    ProductCode,  
    LotNo,  
    DateEx,  
    IDCodeW,  
    Quantity,  
    ProductPriceDt,  
    IntoMoney,  
    BeforeVATPrice,  
    BeforeVATAmount,  
    VATAmount,  
    GeneralDiscount,  
    PolicyDiscount,  
    CumulativeDiscount,  
    GeneralDiscountPrice,  
    PolicyDiscountPrice,  
    CumulativeDiscountPrice,  
    GeneralIDCodePromo,  
    PolicyIDCodePromo,  
    CumulativeIDCodePromo,  
    CodeSales,  
    IDCodeDeliverer,  
    DateOfDebit,  
    CodeChannel,  
    IDCodeOffice,  
    IDCodeWareHouse,  
    DiscountVat,  
    RoundVAT,  
    RoundInvoice,  
    Area,  
    ManagerTeamSup,  
    ManagerAsm,  
    ManagerDirector,  
    TypeOrder,  
    IDCodeOfficeTo,  
    IDCodeWarehouseTo,  
    OrderType,  
    ChannelType,  
    Note,  
    TaxRegNbr,  
    HCOTypeID  
)  
SELECT DateAddOrder =CAST(o.OrderDate AS DATE)  
, IDCodeOrder =ISNULL(ord.OrderNbr,o.OrderNbr)  
, DateAddInvoice= o.OrderDate  
, Symbols= o.InvcNote  
, InvoiceNumber= o.InvcNbr  
, IDCodeCus= CASE WHEN c.RefCustID='' THEN c.CustId ELSE c.RefCustID END -- Mặc định lấy theo mã cũ, nếu không có mã cũ lấy theo mã DMS.  
, IDCodeCusTx =o.InvoiceCustID  
, IDCodeCusTxName =cui.CustNameInvoice  
, RefIDCodeCusTx= cui.OldCustIDInvoice  
, ProductCode=''--d.AccumulateID  
, LotNo= ''--lt.LotSerNbr  
, DateEx='' --lt.ExpDate  
, IDCodeW= ''--ISNULL(lt.SiteID,d.SiteID) -- Trường hợp sản phẩm không có lot thì sẽ lấy theo kho của orddet.  
, Quantity=0--ISNULL(lt.Qty, d.LineQty) -- Trường hợp sản phẩm không có lot thì sẽ lấy theo số lượng của orddet.  
, ProductPriceDt=0-- CASE WHEN d.FreeItem=1 THEN 0 ELSE d.SlsPrice end  
, IntoMoney= CAST(ROUND((d.AccumulateReward/ (1+CAST(d.DiscountVat AS FLOAT)/100)),0) AS FLOAT)---khoahnt fix tra tich luy có 2 loại tax --CASE WHEN c.SalesSystem='1' THEN IIF(d.freeitem=1,0, ISNULL(lt.Qty,d.LineQty)*d.BeforeVATPrice) ELSE IIF(d.freeitem=1, 0, ISNULL(lt.Qty,d.LineQty)*d.SlsPrice) END -- Nếu đơn hàng INS: LineQty* BeforeVATPrice, OTC: LineQty * Slsprice  
, BeforeVATPrice=0  
, BeforeVATAmount=0  
, VATAmount=CAST(d.AccumulateReward-CAST(ROUND((d.AccumulateReward/ (1+CAST(d.DiscountVat AS FLOAT)/100)),0) AS FLOAT) AS FLOAT) ---khoahnt GE yêu cầu lấy tiền thuế theo hóa đơn  
, GeneralDiscount=0--CASE WHEN dis.TypeDiscount='SP' THEN dis.DiscPct ELSE 0 END  
, PolicyDiscount = 0--CASE WHEN dis.TypeDiscount='PR' THEN dis.DiscPct ELSE 0 END  
, CumulativeDiscount = 0--CASE WHEN dis.TypeDiscount='AC' THEN dis.DiscPct ELSE 0 END  
, GeneralDiscountPrice = 0--CASE WHEN dis.TypeDiscount='SP' THEN dis.DiscAmt ELSE 0 END  
, PolicyDiscountPrice = 0--CASE WHEN dis.TypeDiscount='PR' THEN dis.DiscAmt ELSE 0 END  
, CumulativeDiscountPrice = 0 --CASE WHEN dis.TypeDiscount='AC' THEN dis.DiscAmt ELSE 0 END  
, GeneralIDCodePromo = ''--CASE WHEN dis.TypeDiscount='SP' THEN dis.DiscIDPN ELSE '' END  
, PolicyIDCodePromo = ''--CASE WHEN sr.ReasonID IS NOT NULL THEN sr.ProgramID ELSE CASE WHEN dis.TypeDiscount='PR' THEN dis.DiscIDPN ELSE '' END end  
, CumulativeIDCodePromo = d.AccumulateID --CASE WHEN dis.TypeDiscount='AC' THEN dis.DiscIDPN ELSE '' END  
, CodeSales=o.SlsperID  
, IDCodeDeliverer=ib.SlsperID  
, DateOfDebit=o.Terms  
, CodeChannel =ISNULL(ch.ShopType, c.ShopType)  
, IDCodeOffice=o.BranchID  
, IDCodeWareHouse =''--ISNULL(lt.SiteID,d.SiteID)  
, DiscountVat=CAST(d.DiscountVat AS FLOAT)--tx.TaxRate---tx.TaxRate  
, RoundVAT= mty.Descr  
, RoundInvoice =mty.Descr  
, Area = ISNULL(ste.Descr,'')  
, ManagerTeamSup=sup.FirstName  
, ManagerAsm = am.FirstName  
, ManagerDirector= rm.FirstName  
, TypeOrder= CASE WHEN sr.ReasonID IS NOT NULL THEN 1 ELSE 0 END  
, IDCodeOfficeTo= CASE WHEN vp.BranchID IS NOT NULL THEN vp.BranchID ELSE '' END  
, IDCodeWarehouseTo=''  
, o.OrderType  
, ChannelType= CASE WHEN c.SalesSystem='1' THEN 'INS' ELSE 'Orther' END  
, Note=LOWER(o.Remark)  
, o.TaxRegNbr  
, c.HCOTypeID  
FROM dbo.OM_SalesOrd o WITH (NOLOCK)  
INNER JOIN #TBatNbr bat WITH (NOLOCK) ON bat.BranchID =o.BranchID AND bat.BatNbr=o.INBatNbr  and bat.RefNbr=o.ARRefNbr  --- Ngochb bổ sung join RefNbr cho trường hợp trùng BatNbr  
INNER JOIN #DiscAccumulated d WITH (NOLOCK) ON d.BranchID = o.BranchID AND d.OrderNbr = o.OrderNbr  
LEFT JOIN dbo.AR_HistoryCustClassID ch WITH(NOLOCK) ON ch.Version = o.Version AND ch.CustID = o.CustID  
INNER JOIN dbo.AR_Customer c WITH(NOLOCK) ON c.CustId=o.CustID  
--INNER JOIN #TDiscFreeItem dis WITH (NOLOCK) ON dis.BranchID=d.BranchID AND dis.OrderNbr=d.OrderNbr AND dis.FreeItemID=d.InvtID  
LEFT JOIN dbo.AR_Customer_InvoiceCustomer ci WITH (NOLOCK) ON ci.CustID = c.CustId AND o.InvoiceCustID=ci.CustIDInvoice  
LEFT JOIN dbo.AR_CustomerInvoice cui WITH (NOLOCK) ON cui.CustIDInvoice=o.InvoiceCustID  
LEFT JOIN dbo.AR_MasterRoundType mty WITH (NOLOCK) ON mty.Code=ci.RoundType  
LEFT JOIN dbo.SI_Territory ste WITH (NOLOCK) ON ste.Territory=c.Territory  
LEFT JOIN dbo.fr_ListSaleByData('admin') lsb ON lsb.SlsperID=o.SlsperID AND lsb.BranchID=d.BranchID  
LEFT JOIN dbo.Users sup WITH (NOLOCK) ON sup.UserName=lsb.SupID  
LEFT JOIN dbo.Users am WITH (NOLOCK) ON am.UserName=lsb.ASM  
LEFT JOIN dbo.Users rm WITH (NOLOCK) ON rm.UserName=lsb.RSMID  
LEFT JOIN #TaxOrder tx WITH (NOLOCK) ON o.OrderNbr=tx.OrderNbr AND o.BranchID=tx.BranchID  
LEFT JOIN dbo.OM_IssueBookDet ibd WITH (NOLOCK) ON ibd.BranchID=o.BranchID AND ibd.OrderNbr=o.OrigOrderNbr  
LEFT JOIN dbo.OM_IssueBook ib WITH (NOLOCK) ON ib.BatNbr = ibd.BatNbr AND ib.BranchID = ibd.BranchID  
--LEFT JOIN dbo.OM_LotTrans lt WITH (NOLOCK) ON lt.BranchID = d.BranchID AND lt.OrderNbr = d.OrderNbr AND lt.InvtID = d.InvtID AND lt.OMLineRef=d.LineRef  
LEFT JOIN dbo.OM_PDASalesOrd ord WITH (NOLOCK) ON o.OrigOrderNbr=ord.OrderNbr AND ord.BranchID = o.BranchID  
LEFT JOIN dbo.SI_ReasonCode sr WITH (NOLOCK) ON sr.ReasonID=o.ReasonCode  
LEFT JOIN dbo.AP_VendorMap vp WITH (NOLOCK) ON vp.BranchIDMap = c.BranchID AND vp.CustID=c.CustId  
LEFT JOIN #WithOutOrderNbr woo WITH (NOLOCK) ON woo.INOrderNbr=o.OrderNbr AND woo.BranchID=o.BranchID  
WHERE bat.JrnlType='OM'  AND woo.INOrderNbr IS NULL  
  
/* --------------Main Query-----------------*/   
/*Sản phẩm bán của   
1.đơn bán  
2.đơn xuất khác (có reason)  
3. đơn nội bộ  
*/  
SELECT DateAddOrder   
, IDCodeOrder  
, DateAddInvoice  
, Symbols  
, InvoiceNumber  
, IDCodeCus=ISNULL(IDCodeCus,'') -- Mặc định lấy theo mã cũ, nếu không có mã cũ lấy theo mã DMS.  
, IDCodeCusTx= ISNULL(IDCodeCusTx,'')  
, IDCodeCusTxName =ISNULL(IDCodeCusTxName,'')  
, RefIDCodeCusTx=ISNULL(RefIDCodeCusTx,'')  
, ProductCode  
, LotNo--lt.LotSerNbr  
, DateEx --lt.ExpDate  
, IDCodeW -- Trường hợp sản phẩm không có lot thì sẽ lấy theo kho của orddet.  
, Quantity -- Trường hợp sản phẩm không có lot thì sẽ lấy theo số lượng của orddet.  
, ProductPriceDt  
, IntoMoney-- Nếu đơn hàng INS: LineQty* BeforeVATPrice, OTC: LineQty * Slsprice  
, BeforeVATPrice  
, BeforeVATAmount  
, VATAmount =ISNULL(VATAmount,0)  
, GeneralDiscount  
, PolicyDiscount  
, CumulativeDiscount  
, GeneralDiscountPrice  
, PolicyDiscountPrice   
, CumulativeDiscountPrice  
, GeneralIDCodePromo  
, PolicyIDCodePromo   
, CumulativeIDCodePromo  
, CodeSales  
, IDCodeDeliverer  
, DateOfDebit  
, CodeChannel  
, IDCodeOffice  
, IDCodeWareHouse  
, DiscountVat  
, RoundVAT  
, RoundInvoice  
, Area  
, ManagerTeamSup  
, ManagerAsm  
, ManagerDirector  
, TypeOrder= CASE WHEN OrderType IN ('IN','IO') THEN 0   
      WHEN OrderType IN ('EP','NP') AND apv.VendID IS NOT NULL THEN 0  ELSE 1 END  
, IDCodeOfficeTo  
, IDCodeWarehouseTo  
, ChannelType  
, Note=k.note  
,k.TaxRegNbr  
, HCOTypeID  
FROM #temptable K WITH(NOLOCK)  
LEFT JOIN dbo.AP_Vendor apv WITH (NOLOCK) ON apv.VendID=k.IDCodeCus AND apv.ClassID<>'NB'  
----WHERE K.CodeChannel IN (SELECT ChannelCode FROM #TChannel)  
----WHERE k.InvoiceNumber='0030723'  
ORDER BY K.IDCodeOffice, K.IDCodeOrder, K.ProductCode ASC, K.IntoMoney DESC  
  
  
  
DROP TABLE #DiscAccumulated  
DROP TABLE #TBatNbr  
DROP TABLE #TDiscFreeItem  
DROP TABLE #TOrdDisc1  
DROP TABLE #TOrdDisc  
DROP TABLE #TaxOrder  
DROP TABLE #WithOutOrderNbr  
DROP TABLE #temptable  
DROP TABLE #SalesOrder  
DROP TABLE #AccumulateAmount  
DROP TABLE #Accumulated  
--DROP TABLE #AccumulateAmount  
--DROP TABLE #Accumulated  
--DROP TABLE #SalesOrder  
  
--DROP TABLE #TOrdDisc2  
--DROP TABLE #TChannel  

---SELECT DateGetData = FORMAT(@DateGetData,'yyyy-MM-dd')
GO

