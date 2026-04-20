module io_buffers (
    input  wire wdo_logic,    // Logic từ FSM (0: Báo lỗi, 1: Bình thường)
    input  wire enout_logic,  // Logic từ FSM (0: Disable, 1: Enable)
    
    output wire led3_wdo,     // Chân vật lý nối ra LED D3
    output wire led4_enout    // Chân vật lý nối ra LED D4
);

    // =========================================================================
    // MÔ PHỎNG OPEN-DRAIN BẰNG TRI-STATE BUFFER
    // Nếu logic = 0 -> Kéo chân vật lý xuống 0 (LED sáng nếu mắc Pull-up)
    // Nếu logic = 1 -> Nhả chân vật lý ra mức Trở kháng cao 'z' (High-Z)
    // =========================================================================

    assign led3_wdo   = (wdo_logic == 1'b0)   ? 1'b0 : 1'bz;
    assign led4_enout = (enout_logic == 1'b0) ? 1'b0 : 1'bz;

endmodule