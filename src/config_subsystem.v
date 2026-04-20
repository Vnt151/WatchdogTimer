module config_subsystem (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        uart_rx,
    output wire        uart_tx,
    
    input  wire [31:0] status_in,
    output wire [31:0] tWD_out,
    output wire [31:0] tRST_out,
    output wire [15:0] arm_delay_out,
    output wire [31:0] ctrl_out
);

    wire [7:0] rx_data_wire;
    wire       rx_valid_wire;

    // Gọi khối Transceiver
    uart_transceiver u_uart (
        .clk        (clk),
        .rst_n      (rst_n),
        .uart_rx    (uart_rx),
        .uart_tx    (uart_tx),
        .rx_data    (rx_data_wire),
        .rx_valid   (rx_valid_wire),
        // Chân gửi PC (TX) tạm thời chưa nối để tập trung vào Test RX trước
        .tx_data    (8'd0),
        .tx_req     (1'b0),
        .tx_ready   ()
    );

    // Gọi khối Parser
    regfile_and_parser u_parser (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx_data       (rx_data_wire),
        .rx_valid      (rx_valid_wire),
        .status_in     (status_in),
        .tWD_out       (tWD_out),
        .tRST_out      (tRST_out),
        .arm_delay_out (arm_delay_out),
        .ctrl_out      (ctrl_out)
    );

endmodule