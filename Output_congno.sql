SELECT 
[Mã Chi Nhánh/Cty] = o.BranchID,
[Tên Chi Nhánh/Cty] = syc.CpnyName,
[Quản Lý MDS] = uu.FirstName,
[Mã Nhân Viên] = o.SlsperID,
[Tên Nhân Viên] = u.FirstName,

[Vai Trò] = CASE
WHEN u.UserTypes LIKE '%LOG%' THEN'LOG'
WHEN u.Position IN ( 'D', 'SD', 'AD', 'RD' ) AND u.UserTypes NOT LIKE '%LOG%' THEN 'MDS'
WHEN u.UserTypes LIKE '%CS%' THEN 'CS' 
WHEN u.Position IN ( 'S', 'SS', 'AM', 'RM' ) THEN 'P.BH' 
ELSE u.Position END,

[Hình Thức Thanh Toán] = tc.PaymentsForm,
[Tên Khách Hàng] = tc.CustName,
[Mã Kênh] = tc.Channel,
[Mã Kênh Phụ] = tc.ShopType,
[Người Liên Hệ] = tc.attn,
[Số Điện Thoại] = tc.Phone,
[Số Điện Thoại (KH Thuế)] = tc.PhoneCustInvc,

[Khu Vực] = ste.Descr,
[Tỉnh/Thành] = sta.Descr,
[Phường/Xã] = sw.Name,
[Đơn Vị Giao Hàng] = ISNULL(atr.Descr, ''),


[Hạn Thanh Toán] = CASE WHEN st.DueType = 'D' AND st.DueIntrv IN ( '1', '3' ) THEN N'Thanh Toán Ngay' ELSE N'Cho nợ' END,
[Ngày Nghiệp Vụ] = CONVERT(VARCHAR(20), o.OrderDate, 103),
[Mã Đơn Hàng] = o.OrderNbr,
[Số Hóa Đơn] = '',
[Ký Hiệu Hóa Đơn] = '',
[Ngày Đơn Hàng] = CONVERT(VARCHAR(20), o.DateOfOrder, 103),
[Tháng] = RIGHT('0' + CAST(MONTH(o.DateOfOrder) AS VARCHAR(2)), 2),
[Năm] = YEAR(o.DateOfOrder),

[Thời Hạn Thanh Toán] = ISNULL(stt.Descr, o.TermsID),
[Ngày Đến Hạn] = CONVERT(VARCHAR(20), o.DueDate, 103),                 -- CASE WHEN o.TermsID='O1' THEN dbo.fr_GetDueDateOverLapping(o.BranchID,o.OMOrder,@UserID) ELSE o.DueDate end,
[Mã Khách Hàng] = o.CustID,
[Số Nhà Và Tên Đường] = StreetName,
[Quận/Huyện] = sd.Name,

[Thời Gian Giao Hàng (HH:MM)] = MAX(o.DeliveryTime),
[Đầu Kỳ (ĐH)] = IIF(SUM(OpeiningOrderAmt) > 0, 1, 0),                  --CountOpeningOrder),
[Đầu Kỳ (Số Tiền)] = SUM(OpeiningOrderAmt),
[Chốt Sổ (ĐH)] = IIF(SUM(OrdAmtRelease) > 0, 1, 0),                    --SUM(CountOrdRelease),
[Chốt sổ (Số Tiền)] = SUM(OrdAmtRelease),
[Giao Thành Công (ĐH)] = IIF(SUM(DeliveredOrderAmt) > 0, 1, 0),        -- SUM(DeliveredOrder),
[Giao Thành Công (Số Tiền)] = SUM(DeliveredOrderAmt),
[Hủy Hóa Đơn - Trả Hàng (ĐH)] = IIF(SUM(o.ReturnOrdAmt) > 0, 1, 0),    -- SUM(K.CountReturnOrd),
[Hủy Hóa Đơn - Trả Hàng (Số Tiền)] = SUM(o.ReturnOrdAmt),
[Xác Nhận Thu Nợ (Số Tiền)] = SUM(o.ReceiveAmt),
[Lý Do Không Thu Nợ Được] = MAX(o.Reason),
[Tạo Bảng Kê (ĐH)] = IIF(SUM(DebConfirmAmt) > 0, 1, 0),                -- SUM(CountDebtConfirm),
[Tạo Bảng Kê (Số Tiền)] = SUM(DebConfirmAmt),
[Xác Nhận TT Công Nợ (ĐH)] = IIF(SUM(DebConfirmAmtRelease) > 0, 1, 0), -- SUM(CountDebtConfirmRelease),
[Xác Nhận TT Công Nợ (Số Tiền)] = SUM(DebConfirmAmtRelease),
[Dư Nợ Cuối Kỳ] = SUM(OpeiningOrderAmt) + SUM(OrdAmtRelease) - SUM(o.ReturnOrdAmt)
                    - SUM(DebConfirmAmtRelease)
FROM #TOrder o
INNER JOIN #TCustomer tc
ON tc.BranchID = o.BranchID
    AND tc.OrderNbr = o.OrderNbr
    AND tc.OMOrder = o.OMOrder
INNER JOIN dbo.Users u WITH (NOLOCK)
ON u.UserName = o.SlsperID
INNER JOIN dbo.SYS_Company syc WITH (NOLOCK)
ON o.BranchID = syc.CpnyID
INNER JOIN dbo.SI_Territory ste WITH (NOLOCK)
ON ste.Territory = tc.Territory
INNER JOIN dbo.SI_State sta WITH (NOLOCK)
ON sta.State = tc.State
INNER JOIN dbo.SI_District sd WITH (NOLOCK)
ON sd.District = tc.District
    AND sd.State = tc.State

--left join
LEFT JOIN dbo.SI_Ward sw WITH (NOLOCK)
ON sw.Ward = tc.Ward
AND sw.State = tc.State
AND sw.District = tc.District

LEFT JOIN dbo.AR_Transporter atr WITH (NOLOCK)
ON o.DeliveryUnit = atr.Code

LEFT JOIN #TSlsperID ts WITH (NOLOCK)
ON ts.SlsperID = o.SlsperID
AND ts.BranchID = o.BranchID

LEFT JOIN dbo.Users uu WITH (NOLOCK)
ON uu.UserName = ts.SupID

LEFT JOIN dbo.SI_Terms st WITH (NOLOCK)
ON st.TermsID = tc.Terms

LEFT JOIN dbo.SI_Terms stt WITH (NOLOCK)
ON stt.TermsID = o.TermsID

WHERE tc.ShopType + '_' + tc.PaymentsForm NOT IN (
                                                SELECT SubChannel FROM #WithOutSubChannel
                                            )
GROUP BY CASE
        WHEN u.UserTypes LIKE '%LOG%' THEN
            'LOG'
        WHEN u.Position IN ( 'D', 'SD', 'AD', 'RD' )
            AND u.UserTypes NOT LIKE '%LOG%' THEN
            'MDS'
        WHEN u.UserTypes LIKE '%CS%' THEN
            'CS'
        WHEN u.Position IN ( 'S', 'SS', 'AM', 'RM' ) THEN
            'P.BH'
        ELSE
            u.Position
    END,
    CASE
        WHEN st.DueType = 'D'
            AND st.DueIntrv IN ( '1', '3' ) THEN
            N'Thanh Toán Ngay'
        ELSE
            N'Cho nợ'
    END,
    syc.CpnyName,
    uu.FirstName,
    u.FirstName,
    ISNULL(stt.Descr, o.TermsID),
    ste.Descr,
    tc.StreetName,
    sw.Name,
    sd.Name,
    sta.Descr,
    o.BranchID,
    o.SlsperID,
    tc.PaymentsForm,
    CONVERT(VARCHAR(20), o.OrderDate, 103),
    o.OrderNbr,
    --o.InvcNbr,
    --o.InvcNote,
    CONVERT(VARCHAR(20), o.DateOfOrder, 103),
    CONVERT(VARCHAR(20), o.DueDate, 103),
    o.CustID,
    tc.CustName,
    tc.Channel,
    tc.ShopType,
    tc.attn,
    tc.Phone,
    PhoneCustInvc,
    ISNULL(atr.Descr, ''),
    RIGHT('0' + CAST(MONTH(o.DateOfOrder) AS VARCHAR(2)), 2),
    YEAR(o.DateOfOrder)
--CASE WHEN o.TermsID='O1' THEN dbo.fr_GetDueDateOverLapping(o.BranchID,o.OMOrder,@UserID) ELSE o.DueDate end
ORDER BY o.BranchID,
    o.SlsperID,
    o.OrderNbr,
    CONVERT(VARCHAR(20), o.DateOfOrder, 103),
    CONVERT(VARCHAR(20), o.OrderDate, 103) ASC;