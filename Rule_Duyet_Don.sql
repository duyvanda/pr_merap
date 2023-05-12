USE [PhaNam_eSales_PRO]
GO

/****** Object:  StoredProcedure [dbo].[API_GetOM205Order]    Script Date: 19-04-2023 2:31:54 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[API_GetOM205Order] -- [API_GetOM205Order] 'admin'    
 @UserID AS VARCHAR(30) = 'ADMIN'
AS     
--SET NOCOUNT ON;  
--Cap nhat InvoiceCustID     
---------------------------------------------------------    
----///--------// x? Lý tru?c khi 4D duy?t
IF OBJECT_ID('tempdb..#TOrderList') IS NOT NULL
    DROP TABLE #TOrderList;
IF OBJECT_ID('tempdb..#ErrorOrder') IS NOT NULL
    DROP TABLE #ErrorOrder;
IF OBJECT_ID('tempdb..#ErrorList') IS NOT NULL
    DROP TABLE #ErrorList;

	DECLARE @CurrentDate DATE = GETDATE()
DECLARE @PDASalesOrd TABLE
(BranchID VARCHAR(50) NOT NULL, 
 OrderNbr VARCHAR(50) NOT NULL, 
 CustId VARCHAR(50) NOT NULL
 PRIMARY KEY(BranchID, OrderNbr)
)
INSERT INTO @PDASalesOrd
SELECT DISTINCT
       o.BranchID,
       o.OrderNbr,
       c.CustId
FROM dbo.OM_PDASalesOrd o WITH (NOLOCK)
    INNER JOIN dbo.OM_OrderType t WITH (NOLOCK) ON t.OrderType = o.OrderType 
    INNER JOIN dbo.AR_Customer c WITH (NOLOCK) ON c.CustId = o.CustID --AND c.BranchID = o.BranchID    
WHERE o.Status = 'H' --AND o.OrderType in ( 'IN','IO')   
      AND
      (
          c.BatchExpForm = ''
          OR c.BatchExpForm = 'LC'
      )
	  AND (c.Channel != 'INS' OR ISNULL(o.ContractID,'') != '')-- exclude case channel ='INS' and contract='' 
	--  AND CAST(o.OrderDate AS DATE) = @CurrentDate -- Ch? duy?t don ngày hi?n t?i
      AND o.InvoiceCustID = ''
      AND c.Status = 'A'
      AND t.INDocType <> 'NA'; --Duyet tay khi INDocType = 'NA'  	
	  
--Neu ton tai 1 dong     
SELECT CustIDInvoice = COUNT(d.CustIDInvoice), d.CustID
INTO #CustList
FROM
(
    SELECT DISTINCT
           c.CustIDInvoice,
           c.CustID
    FROM @PDASalesOrd t
        INNER JOIN AR_Customer_InvoiceCustomer c WITH (NOLOCK) ON c.CustID = t.CustId
    WHERE c.Active = 1 
) d
GROUP BY d.CustID
HAVING COUNT(d.CustIDInvoice) = 1;
--- when InvoiceCust ='' then update custinvoice with value from ar_cust_invoice
UPDATE o
SET o.InvoiceCustID = c.CustIDInvoice
FROM #CustList l
    INNER JOIN AR_Customer_InvoiceCustomer c WITH (NOLOCK) ON c.CustID = l.CustID AND c.Active = 1
    INNER JOIN @PDASalesOrd p ON p.CustId = l.CustID
    INNER JOIN OM_PDASalesOrd o WITH (NOLOCK) ON o.BranchID = p.BranchID AND o.OrderNbr = p.OrderNbr --AND o.CustID = p.CustId
WHERE o.Status = 'H'
	  --AND CAST(o.OrderDate AS DATE) = @CurrentDate -- Ch? duy?t don ngày hi?n t?i
      AND o.InvoiceCustID = ''

DROP TABLE #CustList;
--DROP TABLE @PDASalesOrd;
----------------- Get list order into temp table check before call 4D tool
SELECT DISTINCT
       o.BranchID,
       o.OrderNbr,
       c.CustId       
	   ,o.Crtd_DateTime
	   , Rownum = ROW_NUMBER() OVER (ORDER BY O.BranchID, O.OrderNbr ASC)  
	   , master.dbo.fn_varbintohexstr(o.tstamp) tstamp
	INTO #TOrderList
FROM dbo.OM_PDASalesOrd o -- @PDASalesOrd p INNER JOIN dbo.OM_PDASalesOrd o WITH (NOLOCK) ON o.BranchID = p.BranchID AND o.OrderNbr = p.OrderNbr
    INNER JOIN dbo.AR_Customer c WITH (NOLOCK) ON c.CustId = o.CustID --AND c.BranchID = o.BranchID        
    INNER JOIN dbo.OM_UserDefault d  WITH (NOLOCK) ON d.DfltBranchID = o.BranchID AND d.UserID = @UserID
    INNER JOIN dbo.OM_OrderType t	 WITH (NOLOCK) ON t.OrderType = o.OrderType
	LEFT JOIN API_HistoryOM205 h WITH (NOLOCK) ON o.OrderNbr = h.OrderNbr AND o.BranchID = h.BranchID
WHERE o.Status = 'H'
      AND --o.OrderType in ( 'IN','IO') AND     
    c.GenOrders <> ''
      AND
      (
          c.BatchExpForm = ''
          OR c.BatchExpForm = 'LC'
      )
	  AND (c.Channel != 'INS' OR ISNULL(o.ContractID,'') !='')-- exclude case channel ='INS' and contract='' 
	--  AND CAST(o.OrderDate AS DATE) = @CurrentDate -- Ch? duy?t don ngày hi?n t?i
      AND o.InvoiceCustID <> ''
	 
      AND ISNULL(h.Status, '') <> 'C'
      AND o.LoadDebtResChedul = 0
      AND c.Status = 'A'
	  
      AND t.INDocType <> 'NA'; --Duyet tay  
 
	
--- Temp table All order with error message 
	CREATE TABLE #ErrorOrder
	(
		BranchID VARCHAR(30) NOT NULL,
		OrderNbr VARCHAR(30) NOT NULL,
		Message VARCHAR(30),
		Param01 NVARCHAR(2000),
		Param02 NVARCHAR(2000),
		Param03 NVARCHAR(2000),
		Param04 NVARCHAR(2000)
		PRIMARY KEY(BranchID, OrderNbr)
	);
	--- Temp table each order with error message 
	CREATE TABLE #ErrorList
	(
		Message VARCHAR(30),
		Param01 NVARCHAR(2000),
		Param02 NVARCHAR(2000),
		Param03 NVARCHAR(2000),
		Param04 NVARCHAR(2000)

	);
	DECLARE @OrdNbr VARCHAR(30) = '';
	DECLARE @BranchID VARCHAR(30) = '';
	DECLARE @MaxRow INT = 0;
    SELECT @MaxRow = MAX(Rownum) FROM #TOrderList 
	DECLARE @IntFlag INT = 1;	
	WHILE (@IntFlag <= @MaxRow)
		BEGIN
			SET @OrdNbr  = ''
			SET @BranchID = '';
			SELECT @OrdNbr = OrderNbr,
				   @BranchID = BranchID
			FROM #TOrderList
			WHERE Rownum = @IntFlag;

			--- Temp table each order with error message, reponse from store check
			INSERT INTO #ErrorList
			(
				Message,
				Param01,
				Param02,
				Param03,
				Param04
			)
			EXECUTE dbo.[OM20500_ppCheckSave] @CpnyID = @BranchID,   -- varchar(30)
											  @UserName = @UserID,   -- varchar(30)
											  @LangID = 0,           -- smallint
											  @OrdNbrList = @OrdNbr, -- varchar(maxR)
											  @BranchID = @BranchID; -- varchar(30)
	
			---//---- Insert log when invalid data
			IF EXISTS (SELECT 1 FROM #ErrorList)
			BEGIN
				--- insert into table all order with error message, reponse from store check
				INSERT INTO #ErrorOrder
				(
					BranchID,
					OrderNbr,
					Message,
					Param01,
					Param02,
					Param03,
					Param04
				)
				SELECT @BranchID,
					   @OrdNbr,
					   Message,
					   Param01,
					   Param02,
					   Param03,
					   Param04
				FROM #ErrorList;

				DECLARE @Status as varchar(2),
				@ErrorMessage AS NVARCHAR(Max),
				@LogProcess AS NVARCHAR(max)

				SELECT @Status='E', @ErrorMessage=Param01, @LogProcess=N'Invalid data at stored procedures'
				FROM #ErrorList
				EXEC dbo.API_LogOM205Order @BranchID = @BranchID,      -- varchar(30)
										   @OrderNbr = @OrdNbr,      -- varchar(15)
										   @Status = @Status,        -- varchar(2)
										   @ErrorMessage = @ErrorMessage, -- nvarchar(max)
										   @LogProcess = @LogProcess    -- nvarchar(max)
	
				DELETE #ErrorList;
			END	
			SET @IntFlag = @IntFlag + 1;
		END;

--- list order after check, exclusion error order
SELECT i.BranchID,
       i.OrderNbr,
       CustId, i.tstamp
FROM #TOrderList i --WITH (NOLOCK)
LEFT JOIN #ErrorOrder o WITH (NOLOCK) ON o.BranchID = i.BranchID AND o.OrderNbr = i.OrderNbr
WHERE o.OrderNbr IS NULL
ORDER BY Crtd_DateTime --20210930 TRUNGHT thêm orderby theo crtd_Datetime


IF OBJECT_ID('tempdb..#TOrderList') IS NOT NULL
    DROP TABLE #TOrderList;
IF OBJECT_ID('tempdb..#ErrorOrder') IS NOT NULL
    DROP TABLE #ErrorOrder;
IF OBJECT_ID('tempdb..#ErrorList') IS NOT NULL
    DROP TABLE #ErrorList;

GO


