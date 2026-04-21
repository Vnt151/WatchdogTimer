//Copyright (C)2014-2026 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.12.02_SP2 (64-bit)
//IP Version: 1.0
//Part Number: GW1N-UV1P5QN48XC7/I6
//Device: GW1N-1P5
//Device Version: C
//Created Time: Tue Apr 21 02:16:02 2026

module Gowin_OSC (oscout, oscen);

output oscout;
input oscen;

OSCO osc_inst (
    .OSCOUT(oscout),
    .OSCEN(oscen)
);

defparam osc_inst.FREQ_DIV = 10;
defparam osc_inst.REGULATOR_EN = 1'b0;

endmodule //Gowin_OSC
