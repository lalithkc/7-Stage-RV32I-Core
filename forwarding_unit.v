`timescale 1ns / 1ps

module forwarding_unit (
    // Sources (The instructions currently in EX)
    input  wire [4:0] id_ex1_rs1_addr, id_ex1_rs2_addr,
    input  wire [4:0] id_ex2_rs1_addr, id_ex2_rs2_addr,
    
    // Destinations 1 cycle ahead (EX/MEM1)
    input  wire        ex_mem1_RegWrite,  ex_mem1_RegWrite2,
    input  wire [4:0]  ex_mem1_rd_addr,   ex_mem1_rd_addr2,
    
    // Destinations 2 cycles ahead (MEM1/MEM2)
    input  wire        mem1_mem2_RegWrite,
    input  wire [4:0]  mem1_mem2_rd_addr,
    
    // Forwarding Selects for ALU 1
    output reg  [1:0]  forwardA1, forwardB1,
    
    // Forwarding Selects for ALU 2
    output reg  [1:0]  forwardA2, forwardB2
);

    // Priority 1: EX/MEM1 (Newest data)
    // Priority 2: MEM1/MEM2
    // 00: Use Register File data
    // 01: Use EX/MEM1 Pipe 1
    // 10: Use EX/MEM1 Pipe 2
    // 11: Use MEM1/MEM2 Pipe 1 (Pipe 2 MEM1/MEM2 is omitted for brevity, can be added if 4-way mux is used)
    
    always @(*) begin
        // ALU 1, Operand A (rs1)
        if (ex_mem1_RegWrite && ex_mem1_rd_addr != 0 && ex_mem1_rd_addr == id_ex1_rs1_addr)
            forwardA1 = 2'b01;
        else if (ex_mem1_RegWrite2 && ex_mem1_rd_addr2 != 0 && ex_mem1_rd_addr2 == id_ex1_rs1_addr)
            forwardA1 = 2'b10;
        else if (mem1_mem2_RegWrite && mem1_mem2_rd_addr != 0 && mem1_mem2_rd_addr == id_ex1_rs1_addr)
            forwardA1 = 2'b11;
        else
            forwardA1 = 2'b00;

        // ALU 1, Operand B (rs2)
        if (ex_mem1_RegWrite && ex_mem1_rd_addr != 0 && ex_mem1_rd_addr == id_ex1_rs2_addr)
            forwardB1 = 2'b01;
        else if (ex_mem1_RegWrite2 && ex_mem1_rd_addr2 != 0 && ex_mem1_rd_addr2 == id_ex1_rs2_addr)
            forwardB1 = 2'b10;
        else if (mem1_mem2_RegWrite && mem1_mem2_rd_addr != 0 && mem1_mem2_rd_addr == id_ex1_rs2_addr)
            forwardB1 = 2'b11;
        else
            forwardB1 = 2'b00;

        // ALU 2, Operand A (rs1)
        if (ex_mem1_RegWrite && ex_mem1_rd_addr != 0 && ex_mem1_rd_addr == id_ex2_rs1_addr)
            forwardA2 = 2'b01;
        else if (ex_mem1_RegWrite2 && ex_mem1_rd_addr2 != 0 && ex_mem1_rd_addr2 == id_ex2_rs1_addr)
            forwardA2 = 2'b10;
        else if (mem1_mem2_RegWrite && mem1_mem2_rd_addr != 0 && mem1_mem2_rd_addr == id_ex2_rs1_addr)
            forwardA2 = 2'b11;
        else
            forwardA2 = 2'b00;

        // ALU 2, Operand B (rs2)
        if (ex_mem1_RegWrite && ex_mem1_rd_addr != 0 && ex_mem1_rd_addr == id_ex2_rs2_addr)
            forwardB2 = 2'b01;
        else if (ex_mem1_RegWrite2 && ex_mem1_rd_addr2 != 0 && ex_mem1_rd_addr2 == id_ex2_rs2_addr)
            forwardB2 = 2'b10;
        else if (mem1_mem2_RegWrite && mem1_mem2_rd_addr != 0 && mem1_mem2_rd_addr == id_ex2_rs2_addr)
            forwardB2 = 2'b11;
        else
            forwardB2 = 2'b00;
    end

endmodule
