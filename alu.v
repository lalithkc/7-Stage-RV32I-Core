`timescale 1ns / 1ps

module alu (
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [3:0]  ALU_ctrl,
    output reg  [31:0] Result
);

    // ALU Control Encoding
    localparam ALU_ADD   = 4'b0000;
    localparam ALU_SUB   = 4'b0001;
    localparam ALU_AND   = 4'b0010;
    localparam ALU_OR    = 4'b0011;
    localparam ALU_XOR   = 4'b0100;
    localparam ALU_SLL   = 4'b0101;
    localparam ALU_SRL   = 4'b0110;
    localparam ALU_SRA   = 4'b0111;
    localparam ALU_SLT   = 4'b1000;
    localparam ALU_SLTU  = 4'b1001;
    localparam ALU_PASSB = 4'b1010; // Used for LUI

    always @(*) begin
        case (ALU_ctrl)
            ALU_ADD:   Result = A + B;
            ALU_SUB:   Result = A - B;
            ALU_AND:   Result = A & B;
            ALU_OR:    Result = A | B;
            ALU_XOR:   Result = A ^ B;
            ALU_SLL:   Result = A << B[4:0];
            ALU_SRL:   Result = A >> B[4:0];
            ALU_SRA:   Result = $signed(A) >>> B[4:0]; // Arithmetic shift
            ALU_SLT:   Result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0;
            ALU_SLTU:  Result = (A < B) ? 32'd1 : 32'd0;
            ALU_PASSB: Result = B; // Passes immediate directly (for LUI)
            default:   Result = 32'b0;
        endcase
    end


endmodule
