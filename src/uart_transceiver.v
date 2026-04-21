module uart_transceiver #(
    parameter CLK_FREQ  = 25_000_000, // Tần số xung nhịp hệ thống
    parameter BAUD_RATE = 115200      // Tốc độ truyền baud
)(
    input  wire       clk,
    input  wire       rst_n,
    
    // Giao tiếp với PC (Chân vật lý)
    input  wire       uart_rx,
    output reg        uart_tx,
    
    // Giao tiếp với lõi FPGA (Khối Parser)
    output reg  [7:0] rx_data,     // Byte vừa nhận được
    output reg        rx_valid,    // Cờ báo: 1 = Có byte mới (kéo dài 1 chu kỳ clock)
    
    input  wire [7:0] tx_data,     // Byte cần gửi đi
    input  wire       tx_req,      // Lệnh yêu cầu gửi: Cấp 1 xung = gửi
    output reg        tx_ready     // Cờ báo: 1 = Sẵn sàng gửi byte mới, 0 = Đang bận gửi
);

    // Tính toán số nhịp clock cho mỗi bit UART
    localparam BIT_TIMER_MAX = CLK_FREQ / BAUD_RATE;
    localparam BIT_TIMER_HALF = BIT_TIMER_MAX / 2;

    // =========================================================================
    // KHỐI RECEIVER (NHẬN DỮ LIỆU TỪ PC)
    // =========================================================================
    reg [2:0] rx_state;
    reg [15:0] rx_timer;
    reg [2:0] rx_bit_idx;

    // Lọc nhiễu đơn giản cho ngõ vào RX bằng cách qua 2 D-FF
    reg rx_sync1, rx_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) {rx_sync2, rx_sync1} <= 2'b11;
        else {rx_sync2, rx_sync1} <= {rx_sync1, uart_rx};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= 0;
            rx_timer <= 0;
            rx_bit_idx <= 0;
            rx_data <= 8'd0;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0; // Mặc định luôn bằng 0, chỉ bật 1 nhịp khi nhận xong

            case (rx_state)
                0: begin // IDLE: Đợi Start Bit (Cạnh xuống)
                    if (rx_sync2 == 1'b0) begin
                        rx_state <= 1;
                        rx_timer <= 0;
                    end
                end
                1: begin // START BIT: Đợi đến giữa bit để lấy mẫu cho chuẩn
                    if (rx_timer == BIT_TIMER_HALF) begin
                        if (rx_sync2 == 1'b0) begin // Xác nhận đúng là start bit
                            rx_state <= 2;
                            rx_timer <= 0;
                            rx_bit_idx <= 0;
                        end else begin
                            rx_state <= 0; // Nhiễu -> quay về IDLE
                        end
                    end else rx_timer <= rx_timer + 1'b1;
                end
                2: begin // DATA BITS: Lấy mẫu từng bit
                    if (rx_timer == BIT_TIMER_MAX - 1) begin
                        rx_timer <= 0;
                        rx_data[rx_bit_idx] <= rx_sync2; // Lấy mẫu lưu vào thanh ghi
                        
                        if (rx_bit_idx == 7) rx_state <= 3;
                        else rx_bit_idx <= rx_bit_idx + 1'b1;
                    end else rx_timer <= rx_timer + 1'b1;
                end
                3: begin // STOP BIT: Hoàn tất
                    if (rx_timer == BIT_TIMER_MAX - 1) begin
                        rx_state <= 0;
                        rx_valid <= 1'b1; // Báo hiệu đã nhận xong 1 byte!
                    end else rx_timer <= rx_timer + 1'b1;
                end
                default: rx_state <= 0;
            endcase
        end
    end

    // =========================================================================
    // KHỐI TRANSMITTER (GỬI DỮ LIỆU LÊN PC)
    // =========================================================================
    reg [2:0] tx_state;
    reg [15:0] tx_timer;
    reg [2:0] tx_bit_idx;
    reg [7:0] tx_shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= 0;
            tx_timer <= 0;
            tx_bit_idx <= 0;
            tx_shift_reg <= 0;
            uart_tx <= 1'b1; // Trạng thái nghỉ của TX luôn là 1
            tx_ready <= 1'b1;
        end else begin
            case (tx_state)
                0: begin // IDLE
                    tx_ready <= 1'b1;
                    uart_tx <= 1'b1;
                    if (tx_req) begin // Nhận được lệnh gửi
                        tx_shift_reg <= tx_data;
                        tx_state <= 1;
                        tx_timer <= 0;
                        tx_ready <= 0;
                        uart_tx <= 1'b0; // Bắn Start bit (Kéo xuống 0)
                    end
                end
                1: begin // DATA BITS
                    if (tx_timer == BIT_TIMER_MAX - 1) begin
                        tx_timer <= 0;
                        uart_tx <= tx_shift_reg[0]; // Đẩy bit thấp nhất ra trước
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]}; // Dịch phải
                        
                        if (tx_bit_idx == 7) begin
                            tx_state <= 2;
                            tx_bit_idx <= 0;
                        end else tx_bit_idx <= tx_bit_idx + 1'b1;
                    end else tx_timer <= tx_timer + 1'b1;
                end
                2: begin // STOP BIT
                    if (tx_timer == BIT_TIMER_MAX - 1) begin
                        tx_timer <= 0;
                        uart_tx <= 1'b1; // Bắn Stop bit (Kéo lên 1)
                        tx_state <= 3;
                    end else tx_timer <= tx_timer + 1'b1;
                end
                3: begin // Đợi giữ Stop bit đủ lâu
                    if (tx_timer == BIT_TIMER_MAX - 1) begin
                        tx_state <= 0; // Xong 1 khung, quay về IDLE
                    end else tx_timer <= tx_timer + 1'b1;
                end
                default: tx_state <= 0;
            endcase
        end
    end

endmodule