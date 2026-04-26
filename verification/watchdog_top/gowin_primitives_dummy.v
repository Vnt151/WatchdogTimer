// module gia lap de ModelSim khong bao loi thieu linh kien OSCO
module OSCO (
    output OSCOUT,
    input  OSCEN
);
    // testbench da dung lenh force 
    // fieu khien tin hieu OSCOUT (thong qua clk_25mhz)
    parameter FREQ_DIV = 10;
    parameter REGULATOR_EN = 1'b0;
endmodule