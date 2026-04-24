`timescale 1ns/1ps

module tb_regfile_and_parser ();
    // khai bao cac tin hieu ket noi
    reg clk, rst_n;
    reg [7:0] rx_data;
    reg rx_valid;
    reg tx_ready;
    reg [31:0] status_in;

    wire [7:0]  tx_data;
    wire        tx_req;
    wire [31:0] tWD_out, tRST_out, ctrl_out;
    wire [15:0] arm_delay_out;
    wire        sw_kick_out;

    regfile_and_parser uut (
        .clk(clk), .rst_n(rst_n),
        .rx_data(rx_data), .rx_valid(rx_valid),
        .tx_data(tx_data), .tx_req(tx_req), .tx_ready(tx_ready),
        .status_in(status_in),
        .tWD_out(tWD_out), .tRST_out(tRST_out), .arm_delay_out(arm_delay_out),
        .ctrl_out(ctrl_out), .sw_kick_out(sw_kick_out)
    );

    initial clk = 0;
    always #5 clk = ~clk; 

    // task: gui mot goi tin RX (CMD, ADDR, LEN, DATA) va tu dong tinh Checksum
    // de khong phai viet lai nhieu lan trong cac test case
    task send_packet(
        input [7:0] cmd,
        input [7:0] addr,
        input [7:0] len,
        input [31:0] data // du lieu toi da 4 byte (32 bit) cho 1 goi tin, gui tung byte tu thap den cao
    );
        reg [7:0] chk_val;
        integer i;
        begin
            @(posedge clk);
            // gui header 0x55
            rx_data = 8'h55; rx_valid = 1; chk_val = 8'h00;
            @(posedge clk);
    
            // gui CMD
            rx_data = cmd; chk_val = chk_val ^ cmd;
            @(posedge clk);
    
            // gui ADDR
            rx_data = addr; chk_val = chk_val ^ addr;
            @(posedge clk);
    
            // gui LEN
            rx_data = len; chk_val = chk_val ^ len;
            @(posedge clk);
    
            // gui DATA (neu co)
            for (i = 0; i < len; i = i + 1) begin
                rx_data = data[i*8 +: 8]; // lay tung byte tu thap den cao
                chk_val = chk_val ^ rx_data;
                @(posedge clk);
            end
    
            // gui checksum (XOR cua tat ca byte truoc do)
            rx_data = chk_val;
            @(posedge clk);
    
            // ket thuc goi tin
            rx_valid = 0;
            rx_data = 0;
            repeat(3) @(posedge clk); // Doi FSM xu ly xong S_CHK
        end
    endtask

    // kich ban kiem thu (Test Scenarios)
    initial begin
        // trang thai ban dau
        rst_n = 0; rx_data = 0; rx_valid = 0; tx_ready = 1;
        status_in = 32'h12345678;
    
        // reset he thong
        #20 rst_n = 1;
        repeat(5) @(posedge clk);

        // case 1: ghi vao thanh ghi CTRL (Addr 0x00) gia tri 0x00000004
        // (de test bit 2 W1C tu xoa)
        $display("[%0t] TEST 1: Write to CTRL (Bit 2)", $time);
        send_packet(8'h01, 8'h00, 8'h04, 32'h00000004);
    
        // case 2: ghi vao thanh ghi tWD (Addr 0x04) gia tri 5000
        $display("[%0t] TEST 2: Write to tWD (Val: 5000)", $time);
        send_packet(8'h01, 8'h04, 8'h04, 32'd5000);

        // case 3: gui lenh KICK (CMD 0x03)
        $display("[%0t] TEST 3: Send KICK Command", $time);
        send_packet(8'h03, 8'h00, 8'h00, 32'h0);

        // case 4: lenh Get Status (CMD 0x04)
        $display("[%0t] TEST 4: Get Status", $time);
        send_packet(8'h04, 8'h00, 8'h00, 32'h0);

        // case 5: test Checksum loi (Module khong duoc ghi de)
        $display("[%0t] TEST 5: Error Checksum (Should fail)", $time);
        // test lam sai checksum
        @(posedge clk);
        rx_data = 8'h55; rx_valid = 1; @(posedge clk); // header
        rx_data = 8'h01; @(posedge clk);               // CMD write
        rx_data = 8'h08; @(posedge clk);               // ADDR tRST
        rx_data = 8'h04; @(posedge clk);               // LEN 4
        rx_data = 8'hFF; repeat(4) @(posedge clk);     // du lieu rac
        rx_data = 8'h00; @(posedge clk);               // sai checksum (phai la 0xFF ^ 0x08 ^ 0x04 = 0xF7)
        rx_valid = 0;
        #200;
        $display("[%0t] ALL TESTS FINISHED", $time);
        $finish;
    end
endmodule