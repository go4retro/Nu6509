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
                input phi2_6509,
                input r_w,
                input [15:0]address_6502,
                inout [7:0]data_6502,
                inout [7:0]data_6509,
                input _rdy,
                input be,
                input vpa,
                input vda,
                input _so,
                input e,
                output sync,
                output mx,
                output _abort,
                output reg [7:0]address_bank
               );
 


reg [7:0]data_6502_out;
reg [7:0]data_6509_out;
wire [7:0]data_0000;
wire [7:0]data_0001;
wire [7:0]data_bank;
wire [7:0]data_baddr;
wire flag_opcode;
wire data_cycle1;
wire data_cycle2;
wire data_cycle3;
wire data_cycle4;
wire data_cycle5;wire flag_ext;
wire flag_full;
wire sel_bank;
wire ce_bank;
wire oe_bank;
wire we_bank;
reg flag_816;
reg [2:0]ctr;

/* This Verilog attempts to implement the circuit by Dr. Jefyll in this post:
   http://forum.6502.org/viewtopic.php?p=17597&sid=0966e1fa047d491a969a4693b5fed5fd#p17597
*/

assign ce_bank =                          address_6502[15:1] == 0;
assign we_bank =                          ce_bank & !r_w;assign oe_bank =                          r_w & ce_bank;

assign sync =                             ((ctr == 7) & flag_816 ? (vpa & vda) : vpa);
assign mx =                               ((ctr == 7) & !flag_816 ? _so : 'bz);
assign _abort =                           ((ctr == 7) & flag_816 ? _so : 'bz);
assign flag_ext =                         flag_816 & !e;
assign data_6509 =                        data_6509_out;
assign data_6502 =                        data_6502_out;


// Normal bank register (called Execution bank in MOS documentation)
register #(.WIDTH(8), .RESET(4'b1111))    reg_0000(phi2_6509, !_reset, we_bank & !address_6502[0], data_6502, data_0000);
// Indirect bank register (used for LDA Indirect, Y and STA Indirect, Y)
register #(.WIDTH(8), .RESET(4'b1111))    reg_0001(phi2_6509, !_reset, we_bank & address_6502[0], data_6502, data_0001);
// is this cycle an opcode?
register #(.WIDTH(1))                     reg_opcode(phi2_6509, !_reset, _rdy, sync & data_6502[7] & !data_6502[6] & (data_6502[4:0] == 5'b10001), flag_opcode);
register #(.WIDTH(1))                     reg_clock1(phi2_6509, !_reset, _rdy, address_6502[0], data_cycle1);
// compute the outcome of our combinatorial decision and store
register #(.WIDTH(1))                     reg_clock2(phi2_6509, !_reset, _rdy, flag_opcode & (data_cycle1 ^ address_6502[0]), data_cycle2);
// shift
register #(.WIDTH(1))                     reg_clock3(phi2_6509, !_reset, _rdy, data_cycle2, data_cycle3);
// shift
register #(.WIDTH(1))                     reg_clock4(phi2_6509, !_reset, _rdy, data_cycle3, data_cycle4);
// shift
register #(.WIDTH(1))                     reg_clock5(phi2_6509, !_reset, _rdy, data_cycle4, data_cycle5);// bank selection
assign sel_bank =                         (data_cycle5 & !sync) | data_cycle4;
// '816 bank address
register #(.WIDTH(8))                     reg_bank(!phi2_6509, !_reset, 1, data_6502, data_baddr);

always @(*)
begin
   case({flag_ext, flag_full, sel_bank})
      3'b000:
         address_bank = {4'b0000,data_0000[3:0]};
      3'b001:
         address_bank = {4'b0000,data_0001[3:0]};
      3'b010:
         address_bank = data_0000;
      3'b011:
         address_bank = data_0001;
      default:
         address_bank = data_baddr;
   endcase
end

assign data_bank = (address_6502[0] ? data_0001 : data_0000);

always @(*)
begin
   if(oe_bank & !flag_ext & !flag_full)
      data_6502_out = {4'b0000, data_bank[3:0]};
   else if(oe_bank & !flag_ext & flag_full)
      data_6502_out = data_bank;
   else if(r_w & _rdy & phi2_6509)
      data_6502_out = data_6509;
   else
      data_6502_out = 8'bz;
end

always @(*)
begin
   if(!r_w & _rdy & phi2_6509 & be)
      data_6509_out = data_6502;
   else
      data_6509_out = 8'bz;
end

always @(posedge phi2_6509)
begin
   if(ctr < 7)
      ctr <= ctr + 1;
   else if(ctr == 7)
      flag_816 <= e;
end

// to enable extended values, write $55,$aa,$00,$01 to $0001
// to disable extended values, write $55,$aa,$00,$00 to $0001
fsm_flag						                  flag_fsm1(
                                                    we_bank & address_6502[0] & phi2_6509 & !flag_ext, 
                                                    !_reset, 
                                                    data_6502, 
                                                    flag_full
                                                   );

endmodule
module fsm_flag(
                input clock, 
                input reset, 
                input [7:0]data, 
                output reg flag
               );

reg [1:0]state;

always @(negedge clock, posedge reset)
begin
  if(reset)
		state <= 0;
  else 
		case(state)
         0:
				if(data == 8'h55)
					state <= 1;
			1:
				if(data == 8'haa)
					state <= 2;
				else
					state <= 0;
         2:
				if(data == 8'h00)
					state <= 3;
				else
					state <= 0;
			3:
            begin
               flag <= data[0];
               state <= 0;
            end
			default:
               state <= 0;
		endcase
end
endmodule




