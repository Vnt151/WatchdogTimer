module config_subsystem (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        uart_rx,
    output wire        uart_tx,
    
    input  wire [31:0] status_in,
    output wire [31:0] tWD_out,
    output wire [31:0] tRST_out,
    output wire [15:0] arm_delay_out,
    output wire [31:0] ctrl_out,
    output wire        sw_kick_out   // BỔ SUNG: Dây dẫn tín hiệu Kick ảo ra ngoài
);

    // ==========================================
    // DÂY KẾT NỐI NỘI BỘ GIỮA UART VÀ PARSER
    // ==========================================
    
    // Chiều RX (Nhận)
    wire [7:0] rx_data_wire;
    wire       rx_valid_wire;

    // Chiều TX (Gửi) - MỚI BỔ SUNG
    wire [7:0] tx_data_wire;
    wire       tx_req_wire;
    wire       tx_ready_wire;

    // ==========================================
    // KHỞI TẠO CÁC MODULE
    // ==========================================

    // Gọi khối Transceiver vật lý
    uart_transceiver u_uart (
        .clk        (clk),
        .rst_n      (rst_n),
        .uart_rx    (uart_rx),
        .uart_tx    (uart_tx),
        
        // Cắm dây chiều nhận
        .rx_data    (rx_data_wire),
        .rx_valid   (rx_valid_wire),
        
        // Cắm dây chiều gửi (ĐÃ CẬP NHẬT)
        .tx_data    (tx_data_wire),
        .tx_req     (tx_req_wire),
        .tx_ready   (tx_ready_wire)
    );

    // Gọi khối Não bộ Parser
    regfile_and_parser u_parser (
        .clk           (clk),
        .rst_n         (rst_n),
        
        // Cắm dây chiều nhận
        .rx_data       (rx_data_wire),
        .rx_valid      (rx_valid_wire),
        
        // Cắm dây chiều gửi (ĐÃ CẬP NHẬT)
        .tx_data       (tx_data_wire),
        .tx_req        (tx_req_wire),
        .tx_ready      (tx_ready_wire),
        
        // Giao tiếp với lõi FSM
        .status_in     (status_in),
        .tWD_out       (tWD_out),
        .tRST_out      (tRST_out),
        .arm_delay_out (arm_delay_out),
        .ctrl_out      (ctrl_out),
        .sw_kick_out   (sw_kick_out) // Xuất tín hiệu kick ra
    );

endmodule