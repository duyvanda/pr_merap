SELECT DISTINCT
od.BranchID,
od.OrderNbr,
od.OMOrder,
PaymentsForm = CASE WHEN od.PaymentsForm IN ( 'B', 'C' ) THEN 'TM' ELSE 'CK' END,
Terms = od.TermsID,
CustName =  CASE WHEN cl.CustName = '' THEN c.CustName ELSE ISNULL(cl.CustName, c.CustName) END,
Channel = CASE WHEN cl.Channel = '' THEN c.Channel ELSE ISNULL(cl.Channel, c.Channel) END,
ShopType = CASE WHEN cl.ShopType = '' THEN c.ShopType ELSE ISNULL(cl.ShopType, c.ShopType) END,
Territory = CASE WHEN cl.Territory = '' THEN c.Territory ELSE ISNULL(cl.Territory, c.Territory) END,
StreetName = CASE WHEN cl.Addr1 = '' THEN c.Addr1 ELSE ISNULL(cl.Addr1, c.Addr1) END,
Ward = CASE WHEN cl.Ward = '' THEN c.Ward ELSE ISNULL(cl.Ward, c.Ward) END,
District = CASE WHEN cl.District = '' THEN c.District ELSE ISNULL(cl.District, c.District) END,
State = CASE WHEN cl.State = '' THEN c.State ELSE ISNULL(cl.State, c.State) END,
attn = CASE WHEN cl.Attn = '' THEN c.Attn ELSE ISNULL(cl.Attn, c.Attn) END,
Phone = CASE WHEN cl.Phone = '' THEN c.Phone ELSE ISNULL(cl.Phone, c.Phone) END,
PhoneCustInvc = aci.Phone
INTO #TCustomer
FROM #TOrder od WITH (NOLOCK)
INNER JOIN dbo.AR_Customer c
ON c.CustId = od.CustID
LEFT JOIN dbo.AR_CustomerInvoice aci WITH (NOLOCK)
ON aci.CustIDInvoice = od.InvoiceCustID
LEFT JOIN dbo.AR_HistoryCustClassID cl
ON cl.Version = od.Version;