`timescale 1ns / 1ps

module scoreboard (
    input  wire        clk,
    input  wire        rst,
    
    input  wire        valid1,
    input  wire [4:0]  rs1_1, rs2_1, rd_1,
    input  wire        regWrite1,
    input  wire        is_simd1,
    
    input  wire        valid2,
    input  wire [4:0]  rs1_2, rs2_2, rd_2,
    input  wire        regWrite2,
    input  wire        inst2_is_ctrl,
    input  wire        pipe2_supported,
    
    output wire        issue1_ok,
    output wire        issue2_ok,
    
    input  wire        ex_valid1, ex_MemRead1, 
    input  wire [4:0]  ex_rd1,
    
    input  wire        mem2_valid1, mem2_MemRead1, 
    input  wire [4:0]  mem2_rd1,
    
    input  wire        wb_valid1, 
    input  wire [4:0]  wb_rd1,

    input  wire        ex_valid2, ex_MemRead2, 
    input  wire [4:0]  ex_rd2,
    
    input  wire        mem2_valid2, mem2_MemRead2, 
    input  wire [4:0]  mem2_rd2,
    
    input  wire        wb_valid2, 
    input  wire [4:0]  wb_rd2
);

    reg [31:0] busy;
    
    wire b_rs1_1 = (rs1_1 == 5'b0) ? 1'b0 : busy[rs1_1];
    wire b_rs2_1 = (rs2_1 == 5'b0) ? 1'b0 : busy[rs2_1];
    wire b_rd_1  = (rd_1 == 5'b0)  ? 1'b0 : busy[rd_1];
    
    wire inst1_raw = b_rs1_1 || b_rs2_1 || (is_simd1 && b_rd_1); 
    wire inst1_waw = b_rd_1;
    wire inst1_hazard = inst1_raw || inst1_waw;
    
    assign issue1_ok = valid1 && !inst1_hazard;
    
    wire [31:0] busy_after_inst1 = busy | (issue1_ok && regWrite1 ? (32'b1 << rd_1) : 32'b0);
    
    wire b_rs1_2 = (rs1_2 == 5'b0) ? 1'b0 : busy_after_inst1[rs1_2];
    wire b_rs2_2 = (rs2_2 == 5'b0) ? 1'b0 : busy_after_inst1[rs2_2];
    wire b_rd_2  = (rd_2 == 5'b0)  ? 1'b0 : busy_after_inst1[rd_2];
    
    wire inst2_raw = b_rs1_2 || b_rs2_2;
    wire inst2_waw = b_rd_2;
    wire inst2_war = (regWrite2 && rd_2 != 5'b0) && ((rd_2 == rs1_1) || (rd_2 == rs2_1) || (is_simd1 && rd_2 == rd_1));
    wire inst2_hazard = inst2_raw || inst2_waw || inst2_war;
    
    assign issue2_ok = valid2 && !inst2_hazard && issue1_ok && !inst2_is_ctrl && pipe2_supported; 
    
    reg [31:0] next_busy;
    always @(*) begin
        next_busy = busy;
        
        if (wb_valid1 && wb_rd1 != 5'b0) next_busy[wb_rd1] = 1'b0;
        if (mem2_valid1 && mem2_MemRead1 && mem2_rd1 != 5'b0) next_busy[mem2_rd1] = 1'b0;
        if (ex_valid1 && !ex_MemRead1 && ex_rd1 != 5'b0) next_busy[ex_rd1] = 1'b0;
        
        if (wb_valid2 && wb_rd2 != 5'b0) next_busy[wb_rd2] = 1'b0;
        if (mem2_valid2 && mem2_MemRead2 && mem2_rd2 != 5'b0) next_busy[mem2_rd2] = 1'b0;
        if (ex_valid2 && !ex_MemRead2 && ex_rd2 != 5'b0) next_busy[ex_rd2] = 1'b0;

        if (issue1_ok && regWrite1 && rd_1 != 5'b0) next_busy[rd_1] = 1'b1;
        if (issue2_ok && regWrite2 && rd_2 != 5'b0) next_busy[rd_2] = 1'b1;
    end
    
    always @(posedge clk or posedge rst) begin
        if (rst) busy <= 32'b0;
        else busy <= next_busy;
    end

endmodule
