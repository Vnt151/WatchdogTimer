`timescale 1ns / 1ps

module tb_watchdog_fsm_core();

    // 1. Clock & Reset
    reg clk;
    reg rst_n;
    
    // 2. Ticks
    reg tick_1us;
    reg tick_1ms;
    
    // 3. Inputs
    reg en_clean;
    reg wdi_clean;
    reg [31:0] tWD_ms;
    reg [31:0] tRST_ms;
    reg [15:0] arm_delay_us;
    reg [31:0] ctrl_reg;
    reg sw_kick;
    
    // 4. Outputs
    wire [31:0] status_out;
    wire wdo_logic;
    wire enout_logic;

    // DUT Instantiation
    watchdog_fsm_core dut (
        .clk(clk), .rst_n(rst_n),
        .tick_1us(tick_1us), .tick_1ms(tick_1ms),
        .en_clean(en_clean), .wdi_clean(wdi_clean),
        .tWD_ms(tWD_ms), .tRST_ms(tRST_ms), .arm_delay_us(arm_delay_us),
        .ctrl_reg(ctrl_reg), .sw_kick(sw_kick),
        .status_out(status_out), .wdo_logic(wdo_logic), .enout_logic(enout_logic)
    );

    // Clock Generation (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Ticks Generation (Accelerated for Simulation)
    // 1us = 100 cycles @ 100MHz. 1ms = 1000us.
    integer us_cnt = 0;
    integer ms_cnt = 0;
    always @(posedge clk) begin
        tick_1us <= 0;
        tick_1ms <= 0;
        if (us_cnt == 99) begin
            tick_1us <= 1;
            us_cnt <= 0;
            if (ms_cnt == 9) begin // rut ngan 1ms xuong con 10us de chay nhanh
                tick_1ms <= 1;
                ms_cnt <= 0;
            end else ms_cnt <= ms_cnt + 1;
        end else us_cnt <= us_cnt + 1;
    end

    // --- Main Test Sequence ---
    initial begin
        // Case 1: Initial Reset
        rst_n = 0; en_clean = 0; wdi_clean = 1; sw_kick = 0;
        ctrl_reg = 0; tWD_ms = 50; tRST_ms = 20; arm_delay_us = 150;
        #100 rst_n = 1;
        $display("T=%0t | System Reset Released", $time);

        // Case 2: Enable & Arming Delay (Ignore Kicks)
        #100 en_clean = 1;
        $display("T=%0t | System Enabled (ST_ARMING). Sending dummy kicks...", $time);
        repeat(5) begin
            #500 wdi_clean = 0; #500 wdi_clean = 1; // Kick hardware
        end
        // kiem tra ENOUT phai bang 0 trong ST_ARMING
        
        // Wait for ST_MONITOR
        wait(enout_logic == 1'b1);
        $display("T=%0t | Arming Delay Done. ENOUT is HIGH (ST_MONITOR)", $time);

        // Case 3: Normal Monitoring with Hardware Kicks
        repeat(3) begin
            #200000; // Cho mot khoang < tWD
            wdi_clean = 0; #100 wdi_clean = 1;
            $display("T=%0t | Hardware Kick Received", $time);
        end

        // Case 4: Watchdog Timeout (Fault)
        $display("T=%0t | Stop kicking... Waiting for Timeout", $time);
        wait(wdo_logic == 1'b0); // doi WDO keo thap 
        $display("T=%0t | FAULT DETECTED! WDO is LOW", $time);

        // Case 5: Clear Fault via UART (CLR_FAULT bit)
        #50000 ctrl_reg[2] = 1; // Ghi bit CLR_FAULT 
        #100 ctrl_reg[2] = 0;
        wait(wdo_logic == 1'b1);
        $display("T=%0t | Fault Cleared via UART Software command", $time);

        // Case 6: Software Kick via UART
        #100000 sw_kick = 1; #10 sw_kick = 0;
        $display("T=%0t | Software Kick sent. STATUS Bit 4: %b", $time, status_out[4]);

        // Case 7: System Disable
        #100000 en_clean = 0;
        $display("T=%0t | System Disabled. Returning to IDLE", $time);

        // Case 8: Dynamic Parameter Change (Thay doi tWD khi dang chay)
        $display("T=%0t | Updating tWD_ms from 50 to 100 via UART...", $time);
        tWD_ms = 100; 
        #200000; // Cho lau hon muc 50 cu nhung thap hon 100 moi
        if (wdo_logic == 1'b1) 
        $display("T=%0t | Success: System accepted new tWD without early timeout", $time);

        #1000 $finish;
    end

endmodule