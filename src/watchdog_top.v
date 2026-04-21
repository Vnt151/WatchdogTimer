module watchdog_top (
    // Không cần clk và rst_n từ chân vật lý nữa
    input  wire s1_wdi,     // Nút nhấn S1 (WDI)
    input  wire s2_en,      // Nút nhấn S2 (EN)
    
    input  wire uart_rx,    // Chân RX từ USB-UART
    output wire uart_tx,    // Chân TX tới USB-UART
    
    output wire led3_wdo,   // LED D3 (WDO)
    output wire led4_enout  // LED D4 (ENOUT)
);

    // =========================================================================
    // 1. TẠO XUNG CLOCK 25MHz TỪ DAO ĐỘNG NỘI
    // =========================================================================
    wire clk_25mhz;
    Gowin_OSC u_osc (
        .oscen(1'b1),
        .oscout(clk_25mhz)
    );

    // =========================================================================
    // 2. POWER-ON RESET (Tự động tạo xung Reset khi mới cấp điện)
    // =========================================================================
    reg [7:0] por_cnt = 8'd0;
    reg rst_n_por = 1'b0;

    always @(posedge clk_25mhz) begin
        // Đếm 255 nhịp clock đầu tiên để giữ trạng thái Reset
        if (por_cnt != 8'hFF) begin
            por_cnt   <= por_cnt + 1'b1;
            rst_n_por <= 1'b0;
        end else begin
            rst_n_por <= 1'b1; // Sau đó thả ra để hệ thống hoạt động
        end
    end

    // =========================================================================
    // KHAI BÁO DÂY DẪN NỘI BỘ
    // =========================================================================
    wire tick_1us, tick_1ms;
    wire wdi_clean, en_clean;
    wire [31:0] tWD, tRST, ctrl_reg, status_reg;
    wire [15:0] arm_delay;
    wire wdo_internal, enout_internal;
    wire sw_kick_wire;

    // =========================================================================
    // LẮP RÁP CÁC MODULE
    // =========================================================================

    // Cấp Clock nội và Reset tự động cho tất cả module
    sys_timebase u_time (
        .clk        (clk_25mhz), 
        .rst_n      (rst_n_por),
        .tick_1us   (tick_1us), 
        .tick_1ms   (tick_1ms)
    );

    io_debounce u_deb (
        .clk        (clk_25mhz), 
        .rst_n      (rst_n_por), 
        .tick_1ms   (tick_1ms),
        .s1_wdi_in  (s1_wdi), 
        .s2_en_in   (s2_en),
        .wdi_clean  (wdi_clean), 
        .en_clean   (en_clean)
    );

    config_subsystem u_cfg (
        .clk            (clk_25mhz), 
        .rst_n          (rst_n_por),
        .uart_rx        (uart_rx), 
        .uart_tx        (uart_tx),
        .status_in      (status_reg),
        .tWD_out        (tWD), 
        .tRST_out       (tRST),
        .arm_delay_out  (arm_delay),
        .ctrl_out       (ctrl_reg),
        .sw_kick_out    (sw_kick_wire)
    );

    watchdog_fsm_core u_core (
        .clk          (clk_25mhz), 
        .rst_n        (rst_n_por),
        .tick_1us     (tick_1us), 
        .tick_1ms     (tick_1ms),
        .en_clean     (en_clean), 
        .wdi_clean    (wdi_clean),
        .sw_kick      (sw_kick_wire), 
        .ctrl_reg     (ctrl_reg),
        .tWD_ms       (tWD), 
        .tRST_ms      (tRST), 
        .arm_delay_us (arm_delay),
        .status_out   (status_reg),
        .wdo_logic    (wdo_internal),
        .enout_logic  (enout_internal)
    );

    io_buffers u_buf (
        .wdo_logic    (wdo_internal),
        .enout_logic  (enout_internal),
        .led3_wdo     (led3_wdo),
        .led4_enout   (led4_enout)
    );

endmodule