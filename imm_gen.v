`timescale 1ns/1ps

module imm_gen(instruction, imm_I, imm_S, imm_B, imm_U, imm_J);

input [31:0] instruction;
output [31:0] imm_I, imm_S, imm_B, imm_U, imm_J;

assign imm_I = {{20{instruction[31]}},instruction[31:20]};
assign imm_S = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
assign imm_B = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
assign imm_U = {instruction[31:12], 12'b0};
assign imm_J = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0}; 

endmodule
