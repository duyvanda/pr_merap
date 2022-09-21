USE [PhaNam_eSales_PRO]
GO

/****** Object:  StoredProcedure [dbo].[pr_AR_RawdataTrackingDebtConfirm]    Script Date: 19/01/2022 3:06:09 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[API_TransferInvoiceInfo] --pr_AR_RawdataTrackingDebtConfirm 1069

@DateGetData DATE

AS

SELECT
log.BranchID,
log.CpnyName,
log.[Key],
log.CustID,
log.CustName,
log.CusTaxCode,
log.ArisingDate,
log.Pattern,
log.Serial,
log.Code as InvtID,
log.LotNbr,
log.VATRate,
log.VATAmount,
log.Line,
log.OrderDate,
log.TotalNoVat,
info.Code,
info.Desc1,
omso.OrderType,
omso.[Status],
omso.InvcNbr
from Log_InvoiceInfo as log
INNER JOIN IN_InfoRegisProduct as info ON
log.Code = info.InvtID
INNER JOIN IN_Inventory as Inv ON
log.Code = Inv.InvtID
INNER JOIN OM_SalesOrd as omso ON
log.BranchID = omso.BranchID AND
log.OrderNbr = omso.OrderNbr
WHERE log.OrderDate >= @DateGetData


