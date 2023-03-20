USE [PhaNam_eSales_PRO]
GO

/****** Object:  StoredProcedure [dbo].[Pr_AR_RawdataDebtDetSales_BI]    Script Date: 29-12-2022 1:11:43 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

---chuẩn 1154 - 1400 dòng
--select * from rptrunning where userid ='admin' ORDER BY ReportID DESC  
ALTER PROC [dbo].[Pr_AR_RawdataDebtDetSales_BI] -- Pr_AR_RawdataDebtDetSales_BI  '20221213'  
  @Date DATE                    
as               
SET NOCOUNT ON

SELECT 
DISTINCT
fromtime,
totime,
CustId,
CustName,
RefCustID,
Zone,
ZoneDescr,
Territory,
TerritoryDescr,
State,
StateDescr,
SalesSystem,
SalesSystemDescr,
Channel,
ChannelDescr,
ShoperID,
ShopType,
ShopTypeDescr,
ClassDescr,
HCOID,
HCOName,
HCOTypeID,
HCOTypeName,
Terms,
TermDescr
INTO #TableCustIDinfor
FROM dbo.vs_AR_CustomerInfoByTime WITH (NOLOCK);

 
CREATE TABLE #hoadon
(
    SlsperId VARCHAR(10),
    BranchID VARCHAR(10),
    CustId VARCHAR(50),
    doctype VARCHAR(10),
    Date DATETIME,
    OrdNbr VARCHAR(30),
    InvcNote VARCHAR(10),
    InvcNbr VARCHAR(20),
    OrigDocAmt FLOAT,
    AdjAmt FLOAT, --CASE WHEN ISNULL(ct.CancelBatNbrViettel,0) =1 THEN d.OrigDocAmt ELSE 0 END, 
    remain FLOAT,
    duedate DATETIME,
    OrigOrderNbr VARCHAR(50),
    Terms VARCHAR(10),
	Crtd_DateTime DATETIME
);
INSERT INTO #hoadon
------------- lấy hóa đơn nợ    
SELECT 
SlsperId = ISNULL(deb.SlsperID, d.SlsperId),
d.BranchID,
d.CustId,
d.DocType,
Date = d.DocDate,
d.OrdNbr,
d.InvcNote,
d.InvcNbr,
d.OrigDocAmt,
AdjAmt = 0, --CASE WHEN ISNULL(ct.CancelBatNbrViettel,0) =1 THEN d.OrigDocAmt ELSE 0 END, 
remain = 0,
d.DueDate,
OrigOrderNbr = '',
d.Terms, d.Crtd_DateTime
FROM dbo.AR_Doc d WITH (NOLOCK)
INNER JOIN Batch b WITH (NOLOCK)
ON d.BranchID = b.BranchID
AND d.BatNbr = b.BatNbr
AND b.Module = 'AR'
LEFT JOIN OM_DebtAllocateDet deb WITH (NOLOCK)
ON deb.BranchID = d.BranchID
AND deb.ARBatNbr = d.BatNbr
AND deb.CustID = d.CustId
WHERE 
d.DocType IN ( 'DM', 'IN' )
AND d.Rlsed = 1
AND d.DocDate <= @Date


-------------- Lấy Thanh Toán Công Nợ  

SELECT 
a.BranchID,
AdjdBatNbr,
AdjdRefNbr,
AdjAmt = SUM(AdjAmt)
INTO #tmp
FROM dbo.AR_Adjust a WITH (NOLOCK)
INNER JOIN Batch b WITH (NOLOCK)
ON a.BranchID = b.BranchID
AND a.BatNbr = b.BatNbr
AND b.Module = 'AR'
WHERE 
ISNULL(a.Reversal, '') = ''
AND b.Rlsed = 1
AND a.AdjgDocDate <= @Date
GROUP BY 
a.BranchID,
AdjdBatNbr,
AdjdRefNbr


INSERT INTO #hoadon
---UNION ALL
SELECT 
SlsperId = ISNULL(deb.SlsperID, d.SlsperId),
d.BranchID,
d.CustId,
d.DocType,
Date = d.DocDate,
d.OrdNbr,
d.InvcNote,
d.InvcNbr,
OrigDocAmt = 0,
AdjAmt = aj.AdjAmt,
remain = 0,
d.DueDate,
OrigOrderNbr = '',
d.Terms, d.Crtd_DateTime
FROM dbo.AR_Doc d WITH (NOLOCK)
INNER JOIN Batch b WITH (NOLOCK)
ON d.BranchID = b.BranchID
AND d.BatNbr = b.BatNbr
AND b.Module = 'AR'
INNER JOIN  #tmp aj WITH (NOLOCK)
ON aj.BranchID = d.BranchID
AND aj.AdjdBatNbr = d.BatNbr
AND d.RefNbr = aj.AdjdRefNbr
LEFT JOIN OM_DebtAllocateDet deb WITH (NOLOCK)
ON deb.BranchID = d.BranchID
AND deb.ARBatNbr = d.BatNbr
AND deb.CustID = d.CustId
WHERE d.DocType IN ( 'DM', 'IN' )
AND d.Rlsed = 1
AND d.DocDate <= @Date

--UNION ALL
INSERT INTO #hoadon
---- tra hang & điều chỉnh giảm công nợ  
SELECT 
SlsperId = ISNULL(deb.SlsperID, d.SlsperId),
d.BranchID,
d.CustId,
d.DocType,
Date = d.DocDate,
d.OrdNbr,
d.InvcNote,
d.InvcNbr,
OrigDocAmt = -1 * d.OrigDocAmt,
AdjAmt = 0, --CASE WHEN ISNULL(ct.CancelBatNbrViettel,0) =1 THEN -1*d.OrigDocAmt ELSE 0 END, 
remain = 0,
d.DueDate,
OrigOrderNbr = '',
d.Terms, d.Crtd_DateTime
FROM dbo.AR_Doc d WITH (NOLOCK)
INNER JOIN Batch b WITH (NOLOCK)
ON d.BranchID = b.BranchID
AND d.BatNbr = b.BatNbr
AND b.Module = 'AR'
LEFT JOIN OM_DebtAllocateDet deb WITH (NOLOCK)
ON deb.BranchID = d.BranchID
AND deb.ARBatNbr = d.BatNbr
AND deb.CustID = d.CustId
WHERE d.DocType IN ( 'CM', 'PP' )
AND d.Rlsed = 1
AND b.Status = 'C'
AND d.DocDate <= @Date

-------------- Lấy Cấn Trừ Công Nợ  
/* Các trường hợp khác nếu sai check lại đoạn cmt này  
UNION ALL  
SELECT   d.SlsperId, d.BranchID, d.CustId, d.doctype,  
Date = d.DocDate, d.OrdNbr, d.InvcNote, d.InvcNbr, OrigDocAmt = 0, AdjAmt = aj.AdjAmt, remain = 0  
,d.duedate, OrigOrderNbr=''  
FROM dbo.AR_Doc   d WITH (NOLOCK)   
INNER JOIN (Select a.BranchID,AdjdBatNbr,AdjdRefNbr,AdjAmt=sum(AdjAmt)   
   from dbo.AR_Adjust a WITH (NOLOCK)  
   INNER join Batch b WITH (NOLOCK) ON a.BranchID = b.BranchID and a.BatNbr = b.BatNbr and b.Module = 'AR'   
   where isnull(a.Reversal,'')='' AND b.Rlsed =1 and a.AdjgDocDate<=@StartDate   
   Group By a.BranchID,AdjdBatNbr,AdjdRefNbr) aj ON aj.BranchID = d.BranchID AND aj.AdjdBatNbr = d.BatNbr AND  d.RefNbr = aj.AdjdRefNbr  
INNER JOIN #TableBranchID tb WITH(NOLOCK) ON d.BranchID = tb.BranchID    
WHERE d.DocType IN('IN')  
AND d.Rlsed = 1  
AND d.DocDate <=@StartDate  
*/
 SELECT 
a.BranchID,
AdjgBatNbr,
AdjgRefNbr,
AdjAmt = SUM(AdjAmt * -1)
INTO #tmp1
FROM dbo.AR_Adjust a WITH (NOLOCK)
INNER JOIN Batch b WITH (NOLOCK)
ON a.BranchID = b.BranchID
AND a.BatNbr = b.BatNbr
AND b.Module = 'AR'
WHERE ISNULL(a.Reversal, '') = ''
AND b.Rlsed = 1
AND a.AdjgDocDate <= @Date
GROUP BY 
a.BranchID,
AdjgBatNbr,
AdjgRefNbr


INSERT INTO #hoadon
--UNION ALL
SELECT 
SlsperId = ISNULL(deb.SlsperID, d.SlsperId),
d.BranchID,
d.CustId,
d.DocType,
Date = d.DocDate,
d.OrdNbr,
d.InvcNote,
d.InvcNbr,
OrigDocAmt = 0,
AdjAmt = aj.AdjAmt,
remain = 0,
d.DueDate,
OrigOrderNbr = '',
d.Terms, d.Crtd_DateTime
FROM dbo.AR_Doc d WITH (NOLOCK)
INNER JOIN
#tmp1 aj WITH (NOLOCK)
ON aj.BranchID = d.BranchID
AND aj.AdjgBatNbr = d.BatNbr
AND d.RefNbr = aj.AdjgRefNbr
LEFT JOIN OM_DebtAllocateDet deb WITH (NOLOCK)
ON deb.BranchID = d.BranchID
AND deb.ARBatNbr = d.BatNbr
AND deb.CustID = d.CustId
WHERE d.DocType IN ( 'CM', 'PP' )
AND d.Rlsed = 1
AND d.DocDate <= @Date
------------------------ Hoàn Ứng  
SELECT a.BranchID,
AdjdBatNbr,
AdjdRefNbr,
AdjAmt = SUM(AdjAmt * -1)
INTO #tmp2
FROM dbo.AR_Adjust a WITH (NOLOCK)
INNER JOIN Batch b WITH (NOLOCK)
ON a.BranchID = b.BranchID
AND a.BatNbr = b.BatNbr
AND b.Module = 'AR'
WHERE 
ISNULL(a.Reversal, '') = ''
AND b.Rlsed = 1
AND a.AdjgDocDate <= @Date
GROUP BY
a.BranchID,
AdjdBatNbr,
AdjdRefNbr
---UNION ALL

INSERT INTO #hoadon
SELECT 
SlsperId = ISNULL(deb.SlsperID, d.SlsperId),
d.BranchID,
d.CustId,
d.DocType,
Date = d.DocDate,
d.OrdNbr,
d.InvcNote,
d.InvcNbr,
OrigDocAmt = 0,
AdjAmt = aj.AdjAmt,
remain = 0,
d.DueDate,
OrigOrderNbr = '',
d.Terms, d.Crtd_DateTime
FROM dbo.AR_Doc d WITH (NOLOCK)
INNER JOIN
#tmp2 aj
ON aj.BranchID = d.BranchID
AND aj.AdjdBatNbr = d.BatNbr
AND d.RefNbr = aj.AdjdRefNbr
LEFT JOIN OM_DebtAllocateDet deb WITH (NOLOCK)
ON deb.BranchID = d.BranchID
AND deb.ARBatNbr = d.BatNbr
AND deb.CustID = d.CustId
WHERE
d.DocType IN ( 'CM', 'PP' )
AND d.Rlsed = 1
AND d.DocDate <= @Date;


SELECT P.BranchID,
       vs.CpnyName,                         --vs.Address,    
       [Mã NVGH] = ISNULL(ib.SlsperID, P.SlsperId),
       [Tên NVGH] = ISNULL(u.FirstName, u2.FirstName),
       [Người Tạo Đơn] = u1.FirstName,      --case when a.Crtd_User='PHUCPM' then a.SlsPerID else  a.Crtd_User end,   
       [Ma KH] = P.CustId,
       MaKHCu = c.RefCustID,
       CustName = c.CustName,
                                            --custaddress = ISNULL(c.Addr1 + ', ', '') + ISNULL(c.Addr2 + ', ', '')  
                                            --         + ISNULL(c.Ward + ', ', '') + ISNULL(di.Name + ', ', '')  
                                            --         + ISNULL(sat.Descr, '') ,  
       [Khu Vực] = ISNULL(tt.Descr, ''),
       [Tỉnh/TP] = ISNULL(ci.StateDescr, ''),
                                            --[Quận/Huyện] = ISNULL(di.Name, ''),  
                                            --[Phường/Xã] =ISNULL( w.Name, ''),  
       Tel = ISNULL(c.Phone, ''),
                                            --[Tên HTBH]=ISNULL(ci.SalesSystemDescr, ''),  
       ChannelName = ISNULL(ci.ChannelDescr, ''),
       [Mã Kênh Phụ] = ISNULL(c.ShopType, ''),
       [Tên Kênh Phụ] = ISNULL(ci.ShopTypeDescr, ''),
       HCOName = ISNULL(ci.HCOName, ''),
       [Tên Loại HCO] = ISNULL(ci.HCOTypeName, ''),
                                            --[Tên Phân Hạng HCO]=ISNULL(ci.ClassDescr, '') ,  
                                            --OrdNbr =  (p.branchid +'-'+right(cast('0'+cast(Month(P.Date) as varchar(2)) as varchar(4)),2)+'.'+cast(Year(P.Date) as varchar(4))+'-'+ P.OrdNbr),  
                                            --OrdNbr =  P.OrdNbr, --PhucPM thay thế dòng trên chỉ lấy số đơn hàng do chị Q yêu cầu  
       OrdNbr = ISNULL(o.OrigOrderNbr, ''), --Ngochb thay thế dòng trên  lấy số đơn hàng PDA  
       P.InvcNote,
       P.InvcNbr,
       P.doctype,
       [Ngày Hóa Đơn] = P.Date,
       [Thời Hạn Nợ] = CASE
                           WHEN Ter.DueType = 'D' THEN
                               CAST(Ter.DueIntrv AS VARCHAR)
                           WHEN Ter.TermsID = 'O1' THEN
                               '30'
                           ELSE
                               ''
                       END,
       [Tên Thời Hạn Nợ] = ISNULL(Ter.Descr, ''),
       [Hình Thức TT] = Payments.Descr,
       [Hạn Thanh Toán] = CASE
                              WHEN P.Terms = 'O1' THEN
                                  DATEADD(DAY, 30, P.Date)
                              ELSE
                                  P.duedate
                          END,
       [Số Tiền Nợ Gốc] = SUM(P.OrigDocAmt),
       [Số Tiền Đã Thanh Toán] = SUM(P.AdjAmt),
       [Số Dư Chứng Từ] = SUM(P.OrigDocAmt) - SUM(P.AdjAmt)
FROM #hoadon P WITH (NOLOCK)
INNER JOIN dbo.vs_AR_CustomerHistory c WITH(NOLOCK)
ON c.CustId = P.CustId AND p.Crtd_DateTime BETWEEN c.fromtime AND c.totime
    --INNER JOIN dbo.AR_Customer c WITH (NOLOCK)
    --    ON c.CustId = P.CustId --AND c.BranchID = P.BranchID  
    INNER JOIN dbo.SYS_Company vs WITH (NOLOCK)
        ON vs.CpnyID = P.BranchID
    LEFT JOIN OM_SalesOrd o WITH (NOLOCK)
        ON P.BranchID = o.BranchID
           AND P.OrdNbr = o.OrderNbr
    LEFT JOIN OM_PDASalesOrd a WITH (NOLOCK)
        ON o.BranchID = a.BranchID
           AND o.OrigOrderNbr = a.OrderNbr
    LEFT JOIN OM_IssueBookDet ibe WITH (NOLOCK)
        ON ibe.BranchID = a.BranchID
           AND ibe.OrderNbr = a.OrderNbr
    LEFT JOIN OM_IssueBook ib WITH (NOLOCK)
        ON ibe.BranchID = ib.BranchID
           AND ibe.BatNbr = ib.BatNbr
    LEFT JOIN Users u WITH (NOLOCK)
        ON ib.SlsperID = u.UserName
    LEFT JOIN Users u1 WITH (NOLOCK)
        ON a.SlsPerID = u1.UserName
    LEFT JOIN Users u2 WITH (NOLOCK)
        ON P.SlsperId = u2.UserName
    LEFT JOIN dbo.#TableCustIDinfor ci WITH (NOLOCK)
        ON ci.CustId = c.CustId --ci.BranchID = c.BranchID AND   
		AND p.Crtd_DateTime BETWEEN ci.fromtime AND ci.totime
    LEFT JOIN dbo.SI_District di WITH (NOLOCK)
        ON c.District = di.District
           AND c.State = di.State
    LEFT JOIN dbo.SI_State sat WITH (NOLOCK)
        ON c.State = sat.State
    LEFT JOIN dbo.SI_Territory tt WITH (NOLOCK)
        ON c.Territory = tt.Territory
    LEFT JOIN dbo.AR_GeneralCust ge WITH (NOLOCK)
        ON c.CustIdPublic = ge.GeneralCustID
    LEFT JOIN dbo.SI_Ward w WITH (NOLOCK)
        ON w.Ward = c.Ward
           AND w.District = c.District
           AND w.State = c.State
    LEFT JOIN SI_Terms Ter WITH (NOLOCK)
        ON c.Terms = Ter.TermsID
    LEFT JOIN AR_MasterPayments Payments WITH (NOLOCK)
        ON Payments.Code = c.PaymentsForm

GROUP BY ISNULL(c.Addr1 + ', ', '') + ISNULL(c.Addr2 + ', ', '') + ISNULL(c.Ward + ', ', '')
         + ISNULL(di.Name + ', ', '') + ISNULL(sat.Descr, ''),
         (P.BranchID + '-' + RIGHT(CAST('0' + CAST(MONTH(P.Date) AS VARCHAR(2)) AS VARCHAR(4)), 2) + '.'
          + CAST(YEAR(P.Date) AS VARCHAR(4)) + '-' + P.OrdNbr
         ),
         P.BranchID,
         vs.CpnyName,
         vs.Address,
         ISNULL(ib.SlsperID, P.SlsperId),
         ISNULL(u.FirstName, u2.FirstName),
         P.CustId,
         c.RefCustID,
         c.CustName,
         ci.StateDescr,
         ISNULL(tt.Descr, ''),
         ISNULL(Ter.Descr, ''),
         Payments.Descr,
         P.Terms,
         CASE
             WHEN Ter.DueType = 'D' THEN
                 CAST(Ter.DueIntrv AS VARCHAR)
             WHEN Ter.TermsID = 'O1' THEN
                 '30'
             ELSE
                 ''
         END,
         di.Name,
         w.Name,
         c.Phone,
         ci.SalesSystemDescr,
         ci.ChannelDescr,
         c.ShopType,
         ci.ShopTypeDescr,
         ci.HCOName,
         ci.HCOTypeName,
         ci.ClassDescr,
         P.InvcNote,
         P.InvcNbr,
         P.doctype,
         P.Date,
         CASE
             WHEN P.Terms = 'O1' THEN
                 DATEADD(DAY, 30, P.Date)
             ELSE
                 P.duedate
         END,
         u1.FirstName,
         o.OrigOrderNbr
HAVING SUM(P.OrigDocAmt) <> 0
    --   AND SUM(P.OrigDocAmt) - SUM(P.AdjAmt) <> 0
ORDER BY P.BranchID,
         P.CustId,
         P.Date DESC,
         P.InvcNbr ASC;

DROP TABLE #TableCustIDinfor;
DROP TABLE #hoadon;
DROP TABLE #tmp;
DROP TABLE #tmp1;
DROP TABLE #tmp2;
--DROP TABLE #ar_customerhistory
GO


