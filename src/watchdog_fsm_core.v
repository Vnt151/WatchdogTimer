module watchdog_fsm_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1us,
    input  wire        tick_1ms,
    
    // Tín hiệu vật lý (Từ nút nhấn)
    input  wire        en_clean,
    input  wire        wdi_clean,
    
    // Tín hiệu phần mềm (Từ UART)
    input  wire [31:0] tWD_ms,
    input  wire [31:0] tRST_ms,
    input  wire [15:0] arm_delay_us,
    input  wire [31:0] ctrl_reg,     // CHỨA BIT EN_SW VÀ CLR_FAULT
    input  wire        sw_kick,      // XUNG KICK TỪ UART
    
    output reg  [31:0] status_out,
    output reg         wdo_logic,
    output reg         enout_logic
);

    localparam ST_IDLE    = 2'd0;
    localparam ST_ARMING  = 2'd1;
    localparam ST_MONITOR = 2'd2;
    localparam ST_FAULT   = 2'd3;

    reg [1:0] current_state, next_state;
    reg [31:0] timer_ms;
    reg [15:0] timer_us;

    // =========================================================================
    // XỬ LÝ NGUỒN TÍN HIỆU KÉP (HARDWARE OR SOFTWARE)
    // =========================================================================
    // Enable = Nút S2 GẠT XUỐNG (0->1 do active low) HOẶC Bit 0 của CTRL = 1
    wire final_en = en_clean | ctrl_reg[0];
    
    // Kick = Nút S1 CẠNH XUỐNG HOẶC Lệnh KICK từ UART
    reg wdi_clean_d; 
    wire wdi_falling_edge = (wdi_clean_d == 1'b1) && (wdi_clean == 1'b0);
    wire final_kick = wdi_falling_edge | sw_kick;

    // Theo dõi nguồn kick cuối cùng (0 = Cứng, 1 = Mềm) cho STATUS bit 4
    reg last_kick_src;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= ST_IDLE;
            wdi_clean_d   <= 1'b1; 
            last_kick_src <= 1'b0;
        end else begin
            current_state <= next_state;
            wdi_clean_d   <= wdi_clean;
            if (final_kick) last_kick_src <= sw_kick ? 1'b1 : 1'b0;
        end
    end

    // =========================================================================
    // NEXT STATE LOGIC
    // =========================================================================
    always @(*) begin
        next_state = current_state;

        if (final_en == 1'b0) begin
            next_state = ST_IDLE;
        end else begin
            case (current_state)
                ST_IDLE:    if (final_en) next_state = ST_ARMING;
                ST_ARMING:  if (timer_us >= arm_delay_us) next_state = ST_MONITOR;
                ST_MONITOR: if (timer_ms >= tWD_ms) next_state = ST_FAULT;
                ST_FAULT:   begin
                    // Thoát lỗi nếu hết thời gian tRST HOẶC bị ghi đè CLR_FAULT (bit 2)
                    if (timer_ms >= tRST_ms || ctrl_reg[2] == 1'b1) 
                        next_state = ST_MONITOR; 
                end
            endcase
        end
    end

    // =========================================================================
    // OUTPUTS & TIMERS
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || final_en == 1'b0) begin
            wdo_logic   <= 1'b1;
            enout_logic <= 1'b0;
            timer_us    <= 16'd0;
            timer_ms    <= 32'd0;
        end else begin
            if (current_state != next_state) begin
                timer_us <= 16'd0;
                timer_ms <= 32'd0;
            end 
            else begin
                case (current_state)
                    ST_ARMING: begin
                        wdo_logic   <= 1'b1;
                        enout_logic <= 1'b0;
                        if (tick_1us) timer_us <= timer_us + 1'b1;
                    end
                    ST_MONITOR: begin
                        wdo_logic   <= 1'b1;
                        enout_logic <= 1'b1;
                        if (final_kick) timer_ms <= 32'd0; 
                        else if (tick_1ms) timer_ms <= timer_ms + 1'b1;
                    end
                    ST_FAULT: begin
                        wdo_logic   <= 1'b0;
                        enout_logic <= 1'b1;
                        if (tick_1ms) timer_ms <= timer_ms + 1'b1;
                    end
                endcase
            end
        end
    end

    // =========================================================================
    // CẬP NHẬT THANH GHI STATUS THEO CHUẨN ĐỀ BÀI (MỤC 5.2)
    // =========================================================================
    always @(*) begin
        status_out[0] = (current_state != ST_IDLE); // bit0: EN_EFFECTIVE
        status_out[1] = (current_state == ST_FAULT);  // bit1: FAULT_ACTIVE
        status_out[2] = enout_logic;                  // bit2: ENOUT
        status_out[3] = wdo_logic;                    // bit3: WDO
        status_out[4] = last_kick_src;                // bit4: LAST KICK SRC
        status_out[31:5] = 27'd0;
    end

endmodule