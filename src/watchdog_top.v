module watchdog_top (
    input  wire clk,        // Clock 27MHz từ board Kiwi
    input  wire rst_n,      // Reset hệ thống
    input  wire s1_wdi,     // Nút nhấn S1 (WDI)
    input  wire s2_en,      // Nút nhấn S2 (EN)
    
    input  wire uart_rx,    // Chân RX từ USB-UART
    output wire uart_tx,    // Chân TX tới USB-UART
    
    output wire led3_wdo,   // LED D3 (WDO)
    output wire led4_enout  // LED D4 (ENOUT)
);

    // =========================================================================
    // KHAI BÁO DÂY DẪN NỘI BỘ
    // =========================================================================
    wire tick_1us, tick_1ms;
    wire wdi_clean, en_clean;
    wire [31:0] tWD, tRST, ctrl_reg, status_reg;
    wire [15:0] arm_delay;
    wire wdo_internal, enout_internal;
    
    wire sw_kick_wire; // Dây nối tín hiệu Kick ảo từ PC xuống FSM

    // =========================================================================
    // LẮP RÁP CÁC MODULE
    // =========================================================================

    // 1. Tạo nhịp thời gian hệ thống
    sys_timebase u_time (
        .clk        (clk), 
        .rst_n      (rst_n),
        .tick_1us   (tick_1us), 
        .tick_1ms   (tick_1ms)
    );

    // 2. Chống dội nút nhấn vật lý
    io_debounce u_deb (
        .clk        (clk), 
        .rst_n      (rst_n), 
        .tick_1ms   (tick_1ms),
        .s1_wdi_in  (s1_wdi), 
        .s2_en_in   (s2_en),
        .wdi_clean  (wdi_clean), 
        .en_clean   (en_clean)
    );

    // 3. Hệ thống cấu hình UART
    config_subsystem u_cfg (
        .clk            (clk), 
        .rst_n          (rst_n),
        .uart_rx        (uart_rx), 
        .uart_tx        (uart_tx),
        .status_in      (status_reg),
        .tWD_out        (tWD), 
        .tRST_out       (tRST),
        .arm_delay_out  (arm_delay),
        .ctrl_out       (ctrl_reg),
        .sw_kick_out    (sw_kick_wire)  // Cắm dây xuất Kick ảo
    );

    // 4. Lõi xử lý Watchdog FSM
    watchdog_fsm_core u_core (
        .clk          (clk), 
        .rst_n        (rst_n),
        .tick_1us     (tick_1us), 
        .tick_1ms     (tick_1ms),
        .en_clean     (en_clean), 
        .wdi_clean    (wdi_clean),
        .sw_kick      (sw_kick_wire),   // Nhận dây Kick ảo
        .ctrl_reg     (ctrl_reg),
        .tWD_ms       (tWD), 
        .tRST_ms      (tRST), 
        .arm_delay_us (arm_delay),
        .status_out   (status_reg),
        .wdo_logic    (wdo_internal),
        .enout_logic  (enout_internal)
    );

    // 5. Đệm ngõ ra Open-Drain điều khiển LED
    io_buffers u_buf (
        .wdo_logic    (wdo_internal),
        .enout_logic  (enout_internal),
        .led3_wdo     (led3_wdo),
        .led4_enout   (led4_enout)
    );

endmodule