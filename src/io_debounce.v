module io_debounce (
    input  wire clk,         // Clock hệ thống (27MHz)
    input  wire rst_n,       // Reset cứng (Active-low)
    input  wire tick_1ms,    // Dây "Tick" mượn từ sys_timebase
    input  wire s1_wdi_in,   // Nút S1 vật lý (WDI)
    input  wire s2_en_in,    // Nút S2 vật lý (EN)
    output reg  wdi_clean,   // Tín hiệu S1 đã lọc sạch
    output reg  en_clean     // Tín hiệu S2 đã lọc sạch
);

    parameter DEBOUNCE_TIME = 5'd20; // Chờ 20ms để nút thực sự ổn định

    // =========================================================================
    // 1. KHỐI ĐỒNG BỘ HÓA (2-Stage Synchronizer)
    // Mục đích: Đưa tín hiệu bên ngoài vào miền Clock của FPGA, tránh lỗi Metastability
    // =========================================================================
    reg s1_sync1, s1_sync2;
    reg s2_sync1, s2_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Nút nhấn trên board thường kéo lên VCC (Active-low), nên mặc định là 1
            s1_sync1 <= 1'b1; s1_sync2 <= 1'b1; 
            s2_sync1 <= 1'b1; s2_sync2 <= 1'b1;
        end else begin
            // Dịch bit qua 2 D-FlipFlop
            s1_sync1 <= s1_wdi_in;
            s1_sync2 <= s1_sync1;
            
            s2_sync1 <= s2_en_in;
            s2_sync2 <= s2_sync1;
        end
    end

    // =========================================================================
    // 2. KHỐI LỌC NHIỄU (Debounce Counters)
    // Mục đích: Nếu tín hiệu thay đổi, chờ đủ 20ms mới công nhận
    // =========================================================================
    
    reg [4:0] count_s1;
    reg [4:0] count_s2;

    // Lọc nhiễu cho S1 (WDI)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_s1  <= 5'd0;
            wdi_clean <= 1'b1;
        end else begin
            if (s1_sync2 == wdi_clean) begin
                // Nếu tín hiệu đã giống nhau -> Ổn định, xóa bộ đếm
                count_s1 <= 5'd0;
            end else if (tick_1ms) begin
                // Tín hiệu đang thay đổi, bắt đầu đếm số mili-giây
                if (count_s1 == DEBOUNCE_TIME - 1) begin
                    wdi_clean <= s1_sync2; // Đủ 20ms -> Chốt trạng thái mới!
                    count_s1  <= 5'd0;
                end else begin
                    count_s1 <= count_s1 + 1'b1;
                end
            end
        end
    end

    // Lọc nhiễu cho S2 (EN) - Logic y hệt S1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_s2  <= 5'd0;
            en_clean  <= 1'b1;
        end else begin
            if (s2_sync2 == en_clean) begin
                count_s2 <= 5'd0;
            end else if (tick_1ms) begin
                if (count_s2 == DEBOUNCE_TIME - 1) begin
                    en_clean <= s2_sync2;
                    count_s2 <= 5'd0;
                end else begin
                    count_s2 <= count_s2 + 1'b1;
                end
            end
        end
    end

endmodule