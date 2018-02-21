module Fake6509(input _reset,
                input clock,
                input r_w,
                input [15:0]address_cpu,
                inout [7:0]data_cpu,
                input rdy,
                input sync,
                output [3:0]address_bank
               );
 
wire [8:0]data_opcode;
wire [3:0]data_0000;
wire [3:0]data_0001;
wire data_clock2;
wire data_clock3;
wire data_clock4;
wire data_clock5;
register #(.WIDTH(4), .RESET(4'b1111))    reg_0000(clock, !_reset, !r_w & address_cpu == 0, data_cpu[3:0], data_0000);
register #(.WIDTH(4), .RESET(4'b1111))    reg_0001(clock, !_reset, !r_w & address_cpu == 1, data_cpu[3:0], data_0001);
register #(.WIDTH(9))                     reg_opcode(clock, !_reset, rdy, {sync, data_cpu[7:6], data_cpu[4:0], address_cpu[0]}, data_opcode);
register #(.WIDTH(1))                     reg_clock2(clock, !_reset, rdy, (data_opcode[8:1] == 8'b11010001) & (data_opcode[0] ^ address_cpu[0]), data_clock2);
register #(.WIDTH(1))                     reg_clock3(clock, !_reset, rdy, data_clock2, data_clock3);
register #(.WIDTH(1))                     reg_clock4(clock, !_reset, rdy, data_clock3, data_clock4);
register #(.WIDTH(1))                     reg_clock5(clock, !_reset, rdy, data_clock4, data_clock5);

assign address_bank =                     ( (data_clock5 & !sync) | data_clock4 ? data_0001 : data_0000);

assign data_cpu =                         ( r_w & clock & (address_cpu[15:1] == 0) ? ( address_cpu[0] ? data_0001 : data_0000) : 8'bz);

endmodule




