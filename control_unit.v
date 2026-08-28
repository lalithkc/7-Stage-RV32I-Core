`timescale 1ns / 1ps

module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    
    output reg        RegWrite,
    output reg        MemRead,
    output reg        MemWrite,
    output reg        Branch,
    output reg        Jump,
    output reg        ALUSrc,
    output reg        MemtoReg,
    output reg [2:0]  ImmType,
    output reg [1:0]  ALUOp
);

    // Opcodes
    localparam OP_IMM   = 7'b0010011;
    localparam OP       = 7'b0110011;
    localparam LUI      = 7'b0110111;
    localparam AUIPC    = 7'b0010111;
    localparam JAL      = 7'b1101111;
    localparam JALR     = 7'b1100111;
    localparam BRANCH   = 7'b1100011;
    localparam LOAD     = 7'b0000011;
    localparam STORE    = 7'b0100011;
    localparam CUSTOM_0 = 7'b0001011;

    // ImmType encoding
    localparam IMM_I = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_S = 3'b011;
    localparam IMM_U = 3'b100;
    localparam IMM_J = 3'b101;

    // ALUOp encoding
    localparam ALU_ADD   = 2'b00;
    localparam ALU_SUB   = 2'b01;
    localparam ALU_FUNC  = 2'b10;
    localparam ALU_PASSB = 2'b11;

    always @(*) begin
        RegWrite  = 1'b0;
        MemRead   = 1'b0;
        MemWrite  = 1'b0;
        Branch    = 1'b0;
        Jump      = 1'b0;
        ALUSrc    = 1'b0;
        MemtoReg  = 1'b0;
        ImmType   = 3'b000;
        ALUOp     = 2'b00;

        case (opcode)
            OP_IMM: begin
                RegWrite  = 1'b1;
                ALUSrc    = 1'b1;       // Use immediate
                ImmType   = IMM_I;
                ALUOp     = ALU_FUNC;   // ALU operation determined by funct3
            end

            OP: begin
                RegWrite  = 1'b1;
                ALUSrc    = 1'b0;       // Use register rs2
                ImmType   = 3'b000;     // No immediate
                ALUOp     = ALU_FUNC;   // ALU operation determined by funct3/funct7
            end

            LUI: begin
                RegWrite  = 1'b1;
                ALUSrc    = 1'b1;
                ImmType   = IMM_U;
                ALUOp     = ALU_PASSB;  // Pass immediate directly to ALU output
            end

            AUIPC: begin
                RegWrite  = 1'b1;
                ALUSrc    = 1'b1;
                ImmType   = IMM_U;
                ALUOp     = ALU_ADD;    // Add PC + Immediate
            end

            JAL: begin
                RegWrite  = 1'b1;       // Write PC+4 to rd
                Jump      = 1'b1;
                ImmType   = IMM_J;
            end

            JALR: begin
                RegWrite  = 1'b1;       // Write PC+4 to rd
                Jump      = 1'b1;
                ImmType   = IMM_I;
            end

            BRANCH: begin
                Branch    = 1'b1;
                ALUSrc    = 1'b0;       // Compare rs1 and rs2
                ImmType   = IMM_B;
                ALUOp     = ALU_SUB;    // ALU subtracts to check for zero/equality
            end

            LOAD: begin
                RegWrite  = 1'b1;
                MemRead   = 1'b1;
                ALUSrc    = 1'b1;       // Address = rs1 + immediate
                MemtoReg  = 1'b1;       // Write memory data to register
                ImmType   = IMM_I;
                ALUOp     = ALU_ADD;    // Calculate address
            end

            STORE: begin
                MemWrite  = 1'b1;
                ALUSrc    = 1'b1;       // Address = rs1 + immediate
                ImmType   = IMM_S;
                ALUOp     = ALU_ADD;    // Calculate address
            end

            // ==========================================
            // SIMD Custom-0 Opcode Space
            // ==========================================
            CUSTOM_0: begin
                case (funct3)
                    3'b000: begin // SIMD_MUL (Accumulate)
                        RegWrite  = 1'b1;
                        ALUSrc    = 1'b0;       // Use rs2
                        ALUOp     = 2'b10;      // Bypass standard ALU, use SIMD unit
                    end
                    3'b001: begin // SIMD_LOAD
                        RegWrite  = 1'b1;
                        MemRead   = 1'b1;
                        ALUSrc    = 1'b1;       // Address = rs1 + imm
                        ImmType   = IMM_I;
                        ALUOp     = ALU_ADD;    // Calculate address
                    end
                    3'b010: begin // SIMD_STORE
                        MemWrite  = 1'b1;
                        ALUSrc    = 1'b1;       // Address = rs1 + imm
                        ImmType   = IMM_S;
                        ALUOp     = ALU_ADD;    // Calculate address
                    end
                    default: begin
                        // NOP
                    end
                endcase
            end
            default: begin
                // Everything remains 0 (Illegal instruction / NOP)
            end
        endcase
    end

endmodule
