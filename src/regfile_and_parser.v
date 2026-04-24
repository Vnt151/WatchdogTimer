module regfile_and_parser (
    input  wire        clk,
    input  wire        rst_n,

    // Giao tiếp RX
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,
    
    // GIAO TIẾP TX (MỚI BỔ SUNG)
    output reg  [7:0]  tx_data,
    output reg         tx_req,
    input  wire        tx_ready,
    
    // Giao tiếp FSM Core
    input  wire [31:0] status_in,
    output wire [31:0] tWD_out,
    output wire [31:0] tRST_out,
    output wire [15:0] arm_delay_out,
    output wire [31:0] ctrl_out,
    output reg         sw_kick_out  // TÍN HIỆU KICK ẢO (MỚI BỔ SUNG)
);

    reg [31:0] reg_ctrl;
    reg [31:0] reg_twd;
    reg [31:0] reg_trst;
    reg [15:0] reg_arm_delay;

    assign ctrl_out      = reg_ctrl;
    assign tWD_out       = reg_twd;
    assign tRST_out      = reg_trst;
    assign arm_delay_out = reg_arm_delay;

    localparam S_IDLE = 3'd0;
    localparam S_CMD  = 3'd1;
    localparam S_ADDR = 3'd2;
    localparam S_LEN  = 3'd3;
    localparam S_DATA = 3'd4;
    localparam S_CHK  = 3'd5;

    reg [2:0] state;
    reg [7:0] cmd, addr, len;
    reg [7:0] cal_chk;
    reg [7:0] payload [0:3];
    reg [2:0] byte_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            reg_ctrl      <= 32'd0;
            reg_twd       <= 32'd1600;
            reg_trst      <= 32'd200;
            reg_arm_delay <= 16'd150;
            tx_req        <= 1'b0;
            sw_kick_out   <= 1'b0;
        end else begin
            // Xóa các xung điều khiển ảo sau 1 nhịp clock
            tx_req <= 1'b0;      
            sw_kick_out <= 1'b0; 
            
            // Xóa bit CLR_FAULT (bit 2 của CTRL) theo chuẩn Write-1-to-clear
            if (reg_ctrl[2] == 1'b1) reg_ctrl[2] <= 1'b0;

            if (rx_valid) begin
                case (state)
                    S_IDLE: begin
                        if (rx_data == 8'h55) begin
                            state   <= S_CMD;
                            cal_chk <= 8'h00;
                        end
                    end
                    S_CMD: begin
                        cmd     <= rx_data;
                        cal_chk <= cal_chk ^ rx_data;
                        state   <= S_ADDR;
                    end
                    S_ADDR: begin
                        addr    <= rx_data;
                        cal_chk <= cal_chk ^ rx_data;
                        state   <= S_LEN;
                    end
                    S_LEN: begin
                        len     <= rx_data;
                        cal_chk <= cal_chk ^ rx_data;
                        if (rx_data > 0 && rx_data <= 4) begin
                            byte_cnt <= 0;
                            state    <= S_DATA;
                        end else begin
                            state <= S_CHK; // Lệnh không có data (như Kick, Đọc)
                        end
                    end
                    S_DATA: begin
                        payload[byte_cnt] <= rx_data;
                        cal_chk <= cal_chk ^ rx_data;
                        if (byte_cnt == len - 1) state <= S_CHK;
                        else byte_cnt <= byte_cnt + 1'b1;
                    end
                    S_CHK: begin
                        if (rx_data == cal_chk) begin 
                            // 1. LỆNH GHI (WRITE)
                            if (cmd == 8'h01) begin 
                                case (addr)
                                    8'h00: reg_ctrl      <= {payload[3], payload[2], payload[1], payload[0]};
                                    8'h04: reg_twd       <= {payload[3], payload[2], payload[1], payload[0]};
                                    8'h08: reg_trst      <= {payload[3], payload[2], payload[1], payload[0]};
                                    8'h0C: reg_arm_delay <= {payload[1], payload[0]};
                                endcase
                                tx_data <= 8'hAA; // Trả ACK báo ghi thành công
                                tx_req  <= 1'b1;
                            end
                            // 2. LỆNH KICK QUA UART
                            else if (cmd == 8'h03) begin
                                sw_kick_out <= 1'b1; // Phát xung kick ảo
                                tx_data <= 8'hAA;    // Trả ACK
                                tx_req  <= 1'b1;
                            end
                            // 3. LỆNH GET_STATUS
                            else if (cmd == 8'h04) begin
                                tx_data <= status_in[7:0]; // Trả 8 bit STATUS lên PC
                                tx_req  <= 1'b1;
                            end
                        end
                        state <= S_IDLE; 
                    end
                endcase
            end
        end
    end
endmodule