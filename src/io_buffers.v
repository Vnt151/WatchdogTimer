module io_buffers (
    input  wire wdo_logic,    //0: Báo lỗi, 1: Bình thường
    input  wire enout_logic,  //(0: Disable, 1: Enable)
    
    output wire led3_wdo,     
    output wire led4_enout    
);

    // =========================================================================
    // XUẤT TÍN HIỆU PUSH-PULL ĐỂ ĐIỀU KHIỂN LED TRÊN BOARD KIWI 1P5
    // Đèn LED của board nối xuống GND, nên cần xuất mức '1' để đèn sáng.
    // =========================================================================

    // 1. Đèn D4 (ENOUT): Sáng khi hệ thống Sẵn sàng (Enable)
    // enout_logic = 1 (Enable) -> Xuất 1 -> Đèn D4 SÁNG
    assign led4_enout = enout_logic; 

    // 2. Đèn D3 (WDO): Sáng khi hệ thống BÁO LỖI (Timeout)
    // wdo_logic = 0 (Lỗi) -> Cần xuất 1 để đèn sáng cảnh báo -> Phép Đảo logic (~)
    assign led3_wdo = ~wdo_logic;

endmodule