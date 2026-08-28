`timescale 1ns / 1ps
module simd_unit (
    input  wire [31:0] rs1,
    input  wire [31:0] rs2,
    input  wire signed [31:0] rd_current,   // CHANGED: signed, matches acc_out
    output wire signed [31:0] simd_result    // CHANGED: signed
);
    wire signed [7:0] rs1_l0 = rs1[7:0];
    wire signed [7:0] rs1_l1 = rs1[15:8];
    wire signed [7:0] rs1_l2 = rs1[23:16];
    wire signed [7:0] rs1_l3 = rs1[31:24];

    wire signed [7:0] rs2_l0 = rs2[7:0];
    wire signed [7:0] rs2_l1 = rs2[15:8];
    wire signed [7:0] rs2_l2 = rs2[23:16];
    wire signed [7:0] rs2_l3 = rs2[31:24];

    wire signed [15:0] mul0 = rs1_l0 * rs2_l0;
    wire signed [15:0] mul1 = rs1_l1 * rs2_l1;
    wire signed [15:0] mul2 = rs1_l2 * rs2_l2;
    wire signed [15:0] mul3 = rs1_l3 * rs2_l3;

    assign simd_result = rd_current + mul0 + mul1 + mul2 + mul3;
endmodule
