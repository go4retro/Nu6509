/*
    Fake6509 - Adapter to use 6502 in 6509-based system
    Copyright Jim Brain and RETRO Innovations, 2017-18

    This program is free software; you can redistribute it and/or modify 
    it under the terms of the GNU General Public License as published by 
    the Free Software Foundation; either version 2 of the License, or 
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

    Fake6509.v: Routines to support mapping the 6509-specific bank
    functionality onto the 6502.
    
*/

module Fake6509(input _reset,
                input phi1_6509,
                input phi2_6509,
                output phi2_6502,
                input r_w,
                input [15:0]address_cpu,
                inout [7:0]data_cpu,
                input rdy,
                input sync,
                output [3:0]address_bank,
                output [7:0]test,
                input clock
               );
 
wire [3:0]data_0000;
wire [3:0]data_0001;
wire [1:0]data_cycle1;
wire data_cycle2;
wire data_cycle3;
wire data_cycle4;
wire data_cycle5;
wire sel_bank;
wire ce_bank;
wire oe_bank;
wire we_bank;


assign test[0] = 0;
assign test[1] = 0;
assign test[2] = 0;
assign test[3] = 0;
assign test[4] = 0;
assign test[5] = 0;
assign test[6] = 0;
assign test[7] = 0;

assign phi2_6502 =                        phi1_6509;

/* This Verilog attempts to implement the circuit by Dr. Jefyll in this post:
   http://forum.6502.org/viewtopic.php?p=17597&sid=0966e1fa047d491a969a4693b5fed5fd#p17597
*/

assign ce_bank =                          address_cpu[15:1] == 0;
assign we_bank =                          ce_bank & !r_w;
// Normal bank register (called Execution bank in MOS documentation)
register #(.WIDTH(4), .RESET(4'b1111))    reg_0000(phi2_6502, !_reset, we_bank & !address_cpu[0], data_cpu[3:0], data_0000);
// Indirect bank register (used for LDA Indirect, Y and STA Indirect, Y)
register #(.WIDTH(4), .RESET(4'b1111))    reg_0001(phi2_6502, !_reset, we_bank & address_cpu[0], data_cpu[3:0], data_0001);
// store copy of various important signals.  
register #(.WIDTH(2))                     reg_opcode(phi2_6502, !_reset, rdy, {sync & data_cpu[7] & !data_cpu[6] & (data_cpu[4:0] == 5'b10001), address_cpu[0]}, data_cycle1);
// compute the outcome of our combinatorial decision and store
register #(.WIDTH(1))                     reg_clock2(phi2_6502, !_reset, rdy, data_cycle1[1] & (data_cycle1[0] ^ address_cpu[0]), data_cycle2);
// shift
register #(.WIDTH(1))                     reg_clock3(phi2_6502, !_reset, rdy, data_cycle2, data_cycle3);
// shift
register #(.WIDTH(1))                     reg_clock4(phi2_6502, !_reset, rdy, data_cycle3, data_cycle4);
// shift
register #(.WIDTH(1))                     reg_clock5(phi2_6502, !_reset, rdy, data_cycle4, data_cycle5);
// bank selection
assign sel_bank =                         (data_cycle5 & !sync) | data_cycle4;
assign address_bank =                     ( sel_bank ? data_0001 : data_0000);
// read bank registers in any bank.
wire [3:0]data_bank =                     (address_cpu[0] ? data_0001 : data_0000);
assign oe_bank =                          r_w & phi2_6502 & ce_bank;
assign data_cpu =                         (oe_bank  ? {4'b1111,data_bank} : 8'bz);

endmodule




