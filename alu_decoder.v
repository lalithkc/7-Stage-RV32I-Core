`timescale 1ns / 1ps

module alu_decoder (
    input  wire [1:0] ALUOp,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    input  wire [6:0] opcode, // Needed to differentiate R-type (funct7) vs I-type (no funct7)
    output reg  [3:0] ALU_ctrl
);

    // ALU Control Encoding (from earlier step)
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
    localparam ALU_PASSB = 4'b1010; // Used for LUI (Pass immediate straight through)

    always @(*) begin
        case (ALUOp)
            2'b00: ALU_ctrl = ALU_ADD;   // LOAD/STORE: Address calculation
            2'b01: ALU_ctrl = ALU_SUB;   // BRANCH: Subtraction for equality check
            2'b11: ALU_ctrl = ALU_PASSB; // LUI: Pass immediate
            2'b10: begin                 // R-type / I-type: Check funct3
                case (funct3)
                    3'b000: begin
                        // ADD or SUB? 
                        // If R-type (opcode 0110011) and funct7[5] is 1, it's SUB. Otherwise ADD.
                        if (opcode == 7'b0110011 && funct7[5] == 1'b1)
                            ALU_ctrl = ALU_SUB;
                        else
                            ALU_ctrl = ALU_ADD;
                    end
                    3'b001: ALU_ctrl = ALU_SLL;
                    3'b010: ALU_ctrl = ALU_SLT;
                    3'b011: ALU_ctrl = ALU_SLTU;
                    3'b100: ALU_ctrl = ALU_XOR;
                    3'b101: begin
                        // SRL or SRA?
                        if (opcode == 7'b0110011 && funct7[5] == 1'b1)
                            ALU_ctrl = ALU_SRA;
                        else
                            ALU_ctrl = ALU_SRL;
                    end
                    3'b110: ALU_ctrl = ALU_OR;
                    3'b111: ALU_ctrl = ALU_AND;
                    default: ALU_ctrl = ALU_ADD;
                endcase
            end
            default: ALU_ctrl = ALU_ADD;
        endcase
    end

endmodule
