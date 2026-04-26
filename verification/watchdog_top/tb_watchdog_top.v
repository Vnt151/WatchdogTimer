`timescale 1ns / 1ps

module tb_watchdog_top();

    // tin hieu ket noi voi DUT
    reg  s1_wdi;
    reg  s2_en;
    reg  uart_rx;
    wire uart_tx;
    wire led3_wdo;
    wire led4_enout;

    // tham so thoi gian mo phong
    localparam CLK_PERIOD  = 40;        // 25MHz = 40ns
    localparam BAUD_PERIOD = 104166;    // 9600 baud (~104.16us)

    // khoi tao module top (dut)
    watchdog_top dut (
        .s1_wdi(s1_wdi),
        .s2_en(s2_en),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .led3_wdo(led3_wdo),
        .led4_enout(led4_enout)
    );

    // giai phap cho Oscillator noi (Gowin_OSC)
    // Do primitive OSCO cua hang khong tu chay trong sim, ta phai ep xung nhip
    initial begin
        force dut.clk_25mhz = 0;
        forever #(CLK_PERIOD/2) force dut.clk_25mhz = ~dut.clk_25mhz;
    end

    // cac task ho tro gui lenh UART va kiem tra ket qua

    // gui 1 byte UART LSB first
    task uart_send_byte(input [7:0] data);
        integer i;
        begin
            uart_rx = 0; #BAUD_PERIOD; // Start bit
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                #BAUD_PERIOD;
            end
            uart_rx = 1; #BAUD_PERIOD; // Stop bit
        end
    endtask

    // gui goi tin UART theo giao thuc Parser (Header-CMD-ADDR-LEN-DATA-CHK)
    task uart_write_reg(input [7:0] addr, input [31:0] data);
        reg [7:0] chk;
        begin
            // tinh toan Checksum XOR theo logic module Parser
            chk = 8'h01 ^ addr ^ 8'h04 ^ data[7:0] ^ data[15:8] ^ data[23:16] ^ data[31:24];
            
            uart_send_byte(8'h55); // Header
            uart_send_byte(8'h01); // CMD: Write
            uart_send_byte(addr);  // ADDR
            uart_send_byte(8'h04); // LEN: 4 Bytes
            uart_send_byte(data[7:0]);
            uart_send_byte(data[15:8]);
            uart_send_byte(data[23:16]);
            uart_send_byte(data[31:24]);
            uart_send_byte(chk);   // XOR Checksum 
            $display("T=%0t | UART: Sent Write Command to Addr 0x%h, Data 0x%h", $time, addr, data);
        end
    endtask

    // kich ban kiem thu
    initial begin
        // trang thai ban dau (nut nhan board Kiwi 1P5 la Active-Low)
        s1_wdi = 1; 
        s2_en  = 1;
        uart_rx = 1;

        // buoc 1: Cho Power-On Reset (POR) noi bo 
        // mach POR dem 256 chu ky clock (~10.24us), ta doi 15us cho an toan.
        #15000;
        $display("T=%0t | POR Sequence Completed. System is now LIVE.", $time);

        // buoc 2: kich hoat he thong bang nut nhan S2 (Hardware Enable)
        // bo loc io_debounce can 20ms on dinh de chot trang thai
        $display("T=%0t | Action: Pressing S2 (Enable) for 22ms...", $time);
        s2_en = 0; #22000000; 
        s2_en = 1;
        
        // cho Arming Delay mac dinh (150us) va kiem tra LED trang thai
        wait(led4_enout == 1'b1);
        $display("T=%0t | Result: System ARMED! LED4 (ENOUT) is ON.", $time);

        // buoc 3: cau hinh tham so tWD qua UART
        // cap nhat tWD = 50ms (0x32) de quan sat Timeout nhanh hon
        #1000000;
        uart_write_reg(8'h04, 32'd50); // Addr 0x04: tWD_out
        #2000000;

        // buoc 4: thuc hien Hardware Kick (Nut nhan S1)
        $display("T=%0t | Action: Pressing S1 (Kick) for 22ms...", $time);
        s1_wdi = 0; #22000000; 
        s1_wdi = 1;
        $display("T=%0t | Result: Hardware Kick detected, timer reset.", $time);

        // buoc 5: kiem tra Timeout (Dung Kick va doi den bao loi)
        $display("T=%0t | Action: Stopping Kicks... Waiting for 50ms timeout.", $time);
        wait(led3_wdo == 1'b1); // LED3 sang khi wdo_logic = 0 (Loi) 
        $display("T=%0t | Result: FAULT DETECTED! LED3 (WDO) is ON.", $time);

        // buoc 6: xoa loi qua lenh UART (Software Clear)
        // Ghi bit 2 = 1 vao thanh ghi CTRL (Addr 0x00)
        #5000000;
        $display("T=%0t | Action: Sending Software Clear via UART...", $time);
        uart_write_reg(8'h00, 32'h00000004); 
        
        wait(led3_wdo == 1'b0); // LED3 tat khi he thong phuc hoi 
        $display("T=%0t | Result: Fault Cleared. System Recovered.", $time);

        #5000000;
        $display("T=%0t | Watchdog Top-Level Verification Successfully Finished.", $time);
        $finish;
    end

endmodule