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
 
wire [8:0]data_opcode;
wire [3:0]data_0000;
wire [3:0]data_0001;
wire data_clock2;
wire data_clock3;
wire data_clock4;
wire data_clock5;
wire ce_reg;
wire oe_reg;

reg [4:0]ctr;

assign test[0] = _reset;
assign test[1] = phi2_6502;
assign test[2] = r_w;
assign test[3] = (((address_cpu == 16'h0097) & (data_cpu == 8'h00)) 
                  | ((address_cpu == 16'h03f8) & (data_cpu == 8'h00))) & !r_w & _reset;
assign test[4] = phi1_6509;
assign test[5] = phi2_6509;
assign test[6] = phi2_6502;
assign test[7] = ctr[3];


/* This Verilog attempts to implement the circuit by Dr. Jefyll in this post:
   http://forum.6502.org/viewtopic.php?p=17597&sid=0966e1fa047d491a969a4693b5fed5fd#p17597
*/
// Normal bank register (called Execution bank in MOS documentation)
register #(.WIDTH(4), .RESET(4'b1111))    reg_0000(phi2_6509, !_reset, !r_w & address_cpu == 0, data_cpu[3:0], data_0000);
// Indirect bank register (used for LDA Indirect, Y and STA Indirect, Y)
register #(.WIDTH(4), .RESET(4'b1111))    reg_0001(phi2_6509, !_reset, !r_w & address_cpu == 1, data_cpu[3:0], data_0001);
// store copy of various important signals.  
// Note: This could be reduced to saving SYNC & D7 & !D6 & D4 & !D3 & !D2 & !D1 & D0 and A0 as FLAG, and then computing A0 ^ Saved_A0 & FLAG
register #(.WIDTH(9))                     reg_opcode(phi2_6509, !_reset, rdy, {sync, data_cpu[7:6], data_cpu[4:0], address_cpu[0]}, data_opcode);
// compute the outcome of our combinatorial decision and store
register #(.WIDTH(1))                     reg_clock2(phi2_6509, !_reset, rdy, (data_opcode[8:1] == 8'b11010001) & (data_opcode[0] ^ address_cpu[0]), data_clock2);
// shift
register #(.WIDTH(1))                     reg_clock3(phi2_6509, !_reset, rdy, data_clock2, data_clock3);
// shift
register #(.WIDTH(1))                     reg_clock4(phi2_6509, !_reset, rdy, data_clock3, data_clock4);
// shift
register #(.WIDTH(1))                     reg_clock5(phi2_6509, !_reset, rdy, data_clock4, data_clock5);
// bank selection
assign address_bank =                     ( (data_clock5 & !sync) | data_clock4 ? data_0001 : data_0000);
// read bank registers in any bank
wire [3:0]data_bank =                     (address_cpu[0] ? data_0001 : (oe_reg ? 4'he : data_0000));
assign ce_reg =                           r_w & phi2_6509 & (address_cpu[15:1] == 15'b000000000000000);
assign oe_reg =                           r_w & ce_reg;
assign data_cpu =                         (oe_reg  ? {4'b1111,data_bank} : 8'bz);

reg q;
always @ (negedge phi1_6509, posedge phi2_6509)
begin
  if(phi2_6509)
		q <= 0;
  else
	   q <= 1;
end

always @ (posedge clock, negedge phi2_6509)
begin
  if(!phi2_6509)
		ctr <= 0;
  else
	   ctr <= ctr + 1;
end

  
//assign phi2_6502 = q | (phi2_6509 & !phi1_6509);
//assign phi2_6502 = !(!phi1_6509 & (ctr < 5'h0c));
assign phi2_6502 = !phi2_6509;
//assign phi2_6502 = ((ctr > 5'h00) & (ctr < 5'h0c));

endmodule




