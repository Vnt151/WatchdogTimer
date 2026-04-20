module sys_timebase (
    input  wire clk,        // Clock hệ thống (Giả sử 27 MHz)
    input  wire rst_n,      // Reset cứng (Active-low)
    output reg  tick_1us,   // Xung báo hiệu đã qua 1 micro-giây
    output reg  tick_1ms    // Xung báo hiệu đã qua 1 mili-giây
);

    // Ở 27 MHz, 1 us = 27 chu kỳ clock. Đếm từ 0 đến 26 là đủ 27 nhịp.
    parameter CYCLES_PER_US = 27; 
    
    reg [4:0] count_us; // Bộ đếm cho 1us (cần đếm đến 26, dùng 5 bit)
    reg [9:0] count_ms; // Bộ đếm cho 1ms (cần đếm đến 999, dùng 10 bit)

    // 1. Tạo xung Tick 1 Micro-giây
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_us <= 5'd0;
            tick_1us <= 1'b0;
        end else begin
            if (count_us == CYCLES_PER_US - 1) begin
                count_us <= 5'd0;
                tick_1us <= 1'b1; // Bật lên 1 nhịp clock
            end else begin
                count_us <= count_us + 1'b1;
                tick_1us <= 1'b0; // Trở về 0 ngay lập tức
            end
        end
    end

    // 2. Tạo xung Tick 1 Mili-giây (Dựa vào xung 1us ở trên)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_ms <= 10'd0;
            tick_1ms <= 1'b0;
        end else begin
            tick_1ms <= 1'b0; // Mặc định luôn là 0
            if (tick_1us == 1'b1) begin // Cứ mỗi 1us thì mới vào đếm
                if (count_ms == 10'd999) begin // Đủ 1000 us = 1 ms
                    count_ms <= 10'd0;
                    tick_1ms <= 1'b1; // Bật lên 1 nhịp clock
                end else begin
                    count_ms <= count_ms + 1'b1;
                end
            end
        end
    end

endmodule