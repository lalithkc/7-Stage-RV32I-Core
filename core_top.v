`timescale 1ns / 1ps

module core_top (
    input  wire        clk,
    input  wire        rst,
    
    // Instruction Memory Interface (External)
    input  wire [31:0] instr_in1,
    input  wire [31:0] instr_in2,
    output wire [31:0] pc_out,
    
    // Shared Bus Interface (To Arbiter)
    output wire        bus_req,
    output wire        bus_we,
    output wire [31:0] bus_addr,
    output wire [31:0] bus_wdata,
    input  wire [31:0] bus_rdata,
    input  wire        bus_ack,
    
    // Snoop Interface (From Arbiter)
    input  wire        snoop_valid,
    input  wire        snoop_we,
    input  wire [31:0] snoop_addr
);

    localparam NOP = 32'h00000013; 

    // IF/ID Declarations
    reg [31:0] if_id_pc1,    if_id_pc2;
    reg [31:0] if_id_instr1, if_id_instr2;
    reg        if_id_pred1;
    reg [31:0] if_id_pred_target1, if_id_pred_target2;
    reg        if_id_valid1, if_id_valid2;

    // IF Stage
    reg  [31:0] pc;
    wire [31:0] next_pc;
    wire        take_pc_redirect;
    wire [31:0] redirect_pc;
    wire        btb_hit;
    wire        btb_predict_taken;
    wire [31:0] btb_target_pc;
    wire        btb_take = btb_hit && btb_predict_taken;
    wire        issue1_ok;
    wire        issue2_ok;
    wire        mem_stall; 
    wire        stall_front_end = (if_id_valid1 && !issue1_ok) || mem_stall; 

    assign next_pc = (take_pc_redirect) ? redirect_pc :
                     (btb_take)         ? btb_target_pc : 
                     (issue1_ok && issue2_ok) ? (pc + 8) :
                     (issue1_ok && !issue2_ok) ? (pc + 4) :
                     pc; 
    assign pc_out  = pc;

    always @(posedge clk or posedge rst) begin
        if (rst) pc <= 32'b0;
        else if (!stall_front_end) pc <= next_pc; 
    end

    // IF/ID Pipeline Register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            if_id_pc1 <= 0; if_id_instr1 <= NOP; if_id_pred1 <= 0; if_id_pred_target1 <= 0; if_id_valid1 <= 0;
            if_id_instr2 <= NOP; if_id_valid2 <= 0;
        end else if (take_pc_redirect) begin
            if_id_pc1 <= 0; if_id_instr1 <= NOP; if_id_pred1 <= 0; if_id_pred_target1 <= 0; if_id_valid1 <= 0;
            if_id_instr2 <= NOP; if_id_valid2 <= 0;
        end else if (!stall_front_end) begin
            if_id_pc1 <= pc;
            if_id_instr1 <= instr_in1;
            if_id_pred1 <= btb_take;
            if_id_pred_target1 <= btb_take ? btb_target_pc : (pc + 4);
            if_id_valid1 <= 1;

            if (btb_take) begin
                if_id_instr2 <= NOP;
                if_id_valid2 <= 0;
            end else begin
                if_id_instr2 <= instr_in2;
                if_id_valid2 <= 1;
            end
        end
    end

    // ID Stage
    wire        cu1_RegWrite, cu1_MemRead, cu1_MemWrite, cu1_Branch, cu1_Jump, cu1_ALUSrc, cu1_MemtoReg;
    wire [2:0]  cu1_ImmType; wire [1:0] cu1_ALUOp;
    control_unit cu1 (.opcode(if_id_instr1[6:0]), .funct3(if_id_instr1[14:12]),
        .RegWrite(cu1_RegWrite), .MemRead(cu1_MemRead), .MemWrite(cu1_MemWrite), .Branch(cu1_Branch),
        .Jump(cu1_Jump), .ALUSrc(cu1_ALUSrc), .MemtoReg(cu1_MemtoReg), .ImmType(cu1_ImmType), .ALUOp(cu1_ALUOp));
    wire        cu2_RegWrite, cu2_MemRead, cu2_MemWrite, cu2_Branch, cu2_Jump, cu2_ALUSrc;
    wire [2:0]  cu2_ImmType; wire [1:0] cu2_ALUOp;
    control_unit cu2 (.opcode(if_id_instr2[6:0]), .funct3(if_id_instr2[14:12]),
        .RegWrite(cu2_RegWrite), .MemRead(cu2_MemRead), .MemWrite(cu2_MemWrite), .Branch(cu2_Branch),
        .Jump(cu2_Jump), .ALUSrc(cu2_ALUSrc), .MemtoReg(), .ImmType(cu2_ImmType), .ALUOp(cu2_ALUOp));

    wire [31:0] imm1_I, imm1_S, imm1_B, imm1_U, imm1_J, sel_imm1;
    imm_gen ig1 (.instruction(if_id_instr1), .imm_I(imm1_I), .imm_S(imm1_S), .imm_B(imm1_B), .imm_U(imm1_U), .imm_J(imm1_J));
    assign sel_imm1 = (cu1_ImmType == 3'b001) ? imm1_I : (cu1_ImmType == 3'b010) ? imm1_B :
                      (cu1_ImmType == 3'b011) ? imm1_S : (cu1_ImmType == 3'b100) ? imm1_U : (cu1_ImmType == 3'b101) ? imm1_J : 32'b0;

    wire [31:0] imm2_I, imm2_S, imm2_B, imm2_U, imm2_J, sel_imm2;
    imm_gen ig2 (.instruction(if_id_instr2), .imm_I(imm2_I), .imm_S(imm2_S), .imm_B(imm2_B), .imm_U(imm2_U), .imm_J(imm2_J));
    assign sel_imm2 = (cu2_ImmType == 3'b001) ? imm2_I : (cu2_ImmType == 3'b010) ? imm2_B :
                      (cu2_ImmType == 3'b011) ? imm2_S : (cu2_ImmType == 3'b100) ? imm2_U : (cu2_ImmType == 3'b101) ? imm2_J : 32'b0;

    wire [31:0] rf_rdata1_1, rf_rdata2_1, rf_rdata1_2, rf_rdata2_2, rf_rdata_rd1;
    wire        wb1_RegWrite, wb2_RegWrite; 
    wire [4:0]  wb1_rd_addr, wb2_rd_addr; 
    wire [31:0] wb1_wdata, wb2_wdata;
    
    reg_file rf (
        .clk(clk), .rst(rst),
        .we1(wb1_RegWrite), .waddr1(wb1_rd_addr), .wdata1(wb1_wdata),
        .we2(wb2_RegWrite), .waddr2(wb2_rd_addr), .wdata2(wb2_wdata),
        .raddr1(if_id_instr1[19:15]), .rdata1(rf_rdata1_1),
        .raddr2(if_id_instr1[24:20]), .rdata2(rf_rdata2_1),
        .raddr3(if_id_instr2[19:15]), .rdata3(rf_rdata1_2),
        .raddr4(if_id_instr2[24:20]), .rdata4(rf_rdata2_2),
        .raddr5(if_id_instr1[11:7]),  .rdata5(rf_rdata_rd1) 
    );

    wire inst2_is_ctrl = cu2_Branch || cu2_Jump;
    wire is_simd_mul_id1 = (if_id_instr1[6:0] == 7'b0001011) && (if_id_instr1[14:12] == 3'b000);
    wire pipe2_supported = !(cu2_MemRead || cu2_MemWrite || cu2_Branch || cu2_Jump);

    // ID/EX Registers
    reg        id_ex1_RegWrite, id_ex1_MemRead, id_ex1_MemWrite, id_ex1_Branch, id_ex1_Jump, id_ex1_ALUSrc, id_ex1_MemtoReg;
    reg [1:0]  id_ex1_ALUOp; reg [31:0] id_ex1_pc, id_ex1_rs1_data, id_ex1_rs2_data, id_ex1_imm, id_ex1_rd_data;
    reg [4:0]  id_ex1_rs1_addr, id_ex1_rs2_addr, id_ex1_rd_addr; reg [2:0] id_ex1_funct3; reg [6:0] id_ex1_funct7, id_ex1_opcode; 
    reg        id_ex1_pred_taken; reg [31:0] id_ex1_pred_target;

    reg        id_ex2_RegWrite, id_ex2_MemRead, id_ex2_ALUSrc;
    reg [1:0]  id_ex2_ALUOp; reg [31:0] id_ex2_rs1_data, id_ex2_rs2_data, id_ex2_imm;
    reg [4:0]  id_ex2_rs1_addr, id_ex2_rs2_addr, id_ex2_rd_addr; reg [2:0] id_ex2_funct3; reg [6:0] id_ex2_funct7, id_ex2_opcode; 

    wire flush_id_ex1 = !issue1_ok || take_pc_redirect;
    wire flush_id_ex2 = !issue2_ok || take_pc_redirect;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_ex1_RegWrite<=0; id_ex1_MemRead<=0; id_ex1_MemWrite<=0; id_ex1_Branch<=0; id_ex1_Jump<=0; 
            id_ex1_ALUSrc<=0; id_ex1_MemtoReg<=0; id_ex1_ALUOp<=0;
            id_ex1_pc<=0; id_ex1_rs1_data<=0; id_ex1_rs2_data<=0; id_ex1_imm<=0; id_ex1_rd_data<=0; 
            id_ex1_rs1_addr<=0; id_ex1_rs2_addr<=0; id_ex1_rd_addr<=0; 
            id_ex1_funct3<=0; id_ex1_funct7<=0; id_ex1_opcode<=0; id_ex1_pred_taken<=0; id_ex1_pred_target<=0;

            id_ex2_RegWrite<=0; id_ex2_MemRead<=0;
            id_ex2_ALUSrc<=0; id_ex2_ALUOp<=0;
            id_ex2_rs1_data<=0; id_ex2_rs2_data<=0; id_ex2_imm<=0; 
            id_ex2_rs1_addr<=0; id_ex2_rs2_addr<=0; id_ex2_rd_addr<=0; 
            id_ex2_funct3<=0; id_ex2_funct7<=0; id_ex2_opcode<=0; 
        end else if (!mem_stall) begin 
            if (flush_id_ex1) begin
                id_ex1_RegWrite<=0; id_ex1_MemRead<=0; id_ex1_MemWrite<=0; id_ex1_Branch<=0; id_ex1_Jump<=0; 
                id_ex1_ALUSrc<=0; id_ex1_MemtoReg<=0; id_ex1_ALUOp<=0;
                id_ex1_pc<=0; id_ex1_rs1_data<=0; id_ex1_rs2_data<=0; id_ex1_imm<=0; id_ex1_rd_data<=0; 
                id_ex1_rs1_addr<=0; id_ex1_rs2_addr<=0; id_ex1_rd_addr<=0; 
                id_ex1_funct3<=0; id_ex1_funct7<=0; id_ex1_opcode<=0; id_ex1_pred_taken<=0; id_ex1_pred_target<=0;
            end else begin
                id_ex1_RegWrite<=cu1_RegWrite; id_ex1_MemRead<=cu1_MemRead; id_ex1_MemWrite<=cu1_MemWrite; 
                id_ex1_Branch<=cu1_Branch; id_ex1_Jump<=cu1_Jump; id_ex1_ALUSrc<=cu1_ALUSrc; 
                id_ex1_MemtoReg<=cu1_MemtoReg; id_ex1_ALUOp<=cu1_ALUOp;
                id_ex1_pc<=if_id_pc1; id_ex1_rs1_data<=rf_rdata1_1; id_ex1_rs2_data<=rf_rdata2_1; id_ex1_imm<=sel_imm1;
                id_ex1_rd_data<=rf_rdata_rd1; 
                id_ex1_rs1_addr<=if_id_instr1[19:15]; id_ex1_rs2_addr<=if_id_instr1[24:20]; id_ex1_rd_addr<=if_id_instr1[11:7]; 
                id_ex1_funct3<=if_id_instr1[14:12]; id_ex1_funct7<=if_id_instr1[31:25]; id_ex1_opcode<=if_id_instr1[6:0]; 
                id_ex1_pred_taken<=if_id_pred1; id_ex1_pred_target<=if_id_pred_target1;
            end

            if (flush_id_ex2) begin
                id_ex2_RegWrite<=0; id_ex2_MemRead<=0;
                id_ex2_ALUSrc<=0; id_ex2_ALUOp<=0;
                id_ex2_rs1_data<=0; id_ex2_rs2_data<=0; id_ex2_imm<=0; 
                id_ex2_rs1_addr<=0; id_ex2_rs2_addr<=0; id_ex2_rd_addr<=0; 
                id_ex2_funct3<=0; id_ex2_funct7<=0; id_ex2_opcode<=0; 
            end else begin
                id_ex2_RegWrite<=cu2_RegWrite; id_ex2_MemRead<=cu2_MemRead; 
                id_ex2_ALUSrc<=cu2_ALUSrc; 
                id_ex2_ALUOp<=cu2_ALUOp;
                id_ex2_rs1_data<=rf_rdata1_2; id_ex2_rs2_data<=rf_rdata2_2; id_ex2_imm<=sel_imm2;
                id_ex2_rs1_addr<=if_id_instr2[19:15]; id_ex2_rs2_addr<=if_id_instr2[24:20]; id_ex2_rd_addr<=if_id_instr2[11:7]; 
                id_ex2_funct3<=if_id_instr2[14:12]; id_ex2_funct7<=if_id_instr2[31:25]; id_ex2_opcode<=if_id_instr2[6:0];
            end
        end
    end

    // Backend Regs
    reg [31:0] ex_mem1_alu_result, ex_mem1_rs2_data, ex_mem1_pc_plus_4;
    reg [4:0]  ex_mem1_rd_addr; reg [6:0] ex_mem1_opcode;
    reg        ex_mem1_RegWrite, ex_mem1_MemRead, ex_mem1_MemWrite, ex_mem1_MemtoReg;
    reg [31:0] ex_mem1_alu_result2; reg [4:0] ex_mem1_rd_addr2; 
    reg        ex_mem1_RegWrite2;

    reg [31:0] mem1_mem2_alu_result, mem1_mem2_rs2_data, mem1_mem2_pc_plus_4;
    reg [4:0]  mem1_mem2_rd_addr; reg [6:0] mem1_mem2_opcode;
    reg        mem1_mem2_RegWrite, mem1_mem2_MemRead, mem1_mem2_MemWrite, mem1_mem2_MemtoReg;
    reg [31:0] mem1_mem2_alu_result2; reg [4:0] mem1_mem2_rd_addr2;
    reg        mem1_mem2_RegWrite2;

    // EX Stage
    wire [3:0]  alu1_ctrl; wire [3:0]  alu2_ctrl; 
    alu_decoder alu_dec1 (.ALUOp(id_ex1_ALUOp), .funct3(id_ex1_funct3), .funct7(id_ex1_funct7), .opcode(id_ex1_opcode), .ALU_ctrl(alu1_ctrl));
    alu_decoder alu_dec2 (.ALUOp(id_ex2_ALUOp), .funct3(id_ex2_funct3), .funct7(id_ex2_funct7), .opcode(id_ex2_opcode), .ALU_ctrl(alu2_ctrl));

    wire [1:0] forwardA1, forwardB1, forwardA2, forwardB2;
    forwarding_unit fu (
        .id_ex1_rs1_addr(id_ex1_rs1_addr), .id_ex1_rs2_addr(id_ex1_rs2_addr),
        .id_ex2_rs1_addr(id_ex2_rs1_addr), .id_ex2_rs2_addr(id_ex2_rs2_addr),
        .ex_mem1_RegWrite(ex_mem1_RegWrite), .ex_mem1_RegWrite2(ex_mem1_RegWrite2),
        .ex_mem1_rd_addr(ex_mem1_rd_addr), .ex_mem1_rd_addr2(ex_mem1_rd_addr2),
        .mem1_mem2_RegWrite(mem1_mem2_RegWrite),
        .mem1_mem2_rd_addr(mem1_mem2_rd_addr),
        .forwardA1(forwardA1), .forwardB1(forwardB1),
        .forwardA2(forwardA2), .forwardB2(forwardB2)
    );

    wire [31:0] fwd_data_ex1_p1 = ex_mem1_alu_result;  
    wire [31:0] fwd_data_ex1_p2 = ex_mem1_alu_result2; 
    wire [31:0] fwd_data_mem1_p1 = mem1_mem2_alu_result; 
    
    wire [31:0] alu1_in1_fwd = (forwardA1 == 2'b01) ? fwd_data_ex1_p1 :
                               (forwardA1 == 2'b10) ? fwd_data_ex1_p2 :
                               (forwardA1 == 2'b11) ? fwd_data_mem1_p1 : id_ex1_rs1_data;
    wire [31:0] alu1_in2_fwd = (forwardB1 == 2'b01) ? fwd_data_ex1_p1 :
                               (forwardB1 == 2'b10) ? fwd_data_ex1_p2 :
                               (forwardB1 == 2'b11) ? fwd_data_mem1_p1 : id_ex1_rs2_data;
                               
    wire [31:0] alu1_in1 = alu1_in1_fwd;
    wire [31:0] alu1_in2 = (id_ex1_ALUSrc) ? id_ex1_imm : alu1_in2_fwd;
    wire [31:0] alu1_result;
    alu alu1 (.A(alu1_in1), .B(alu1_in2), .ALU_ctrl(alu1_ctrl), .Result(alu1_result));

    wire [31:0] simd_result1;
    wire        is_simd_mul1 = (id_ex1_opcode == 7'b0001011) && (id_ex1_funct3 == 3'b000);
    simd_unit simd1 (.rs1(id_ex1_rs1_data), .rs2(id_ex1_rs2_data), .rd_current(id_ex1_rd_data), .simd_result(simd_result1));
    wire [31:0] ex1_final_result = is_simd_mul1 ? simd_result1 : alu1_result;

    // Unified Branch/Jump Resolution
    wire [31:0] branch_rs1 = alu1_in1_fwd;
    wire [31:0] branch_rs2 = alu1_in2_fwd;

    wire br1_eq = (branch_rs1 == branch_rs2);
    wire br1_lt = ($signed(branch_rs1) < $signed(branch_rs2));
    wire br1_ltu = (branch_rs1 < branch_rs2);
    reg br1_cond_met;

    always @(*) begin
        case (id_ex1_funct3)
            3'b000: br1_cond_met = br1_eq;                        // BEQ
            3'b001: br1_cond_met = !br1_eq;                       // BNE
            3'b100: br1_cond_met = br1_lt;                        // BLT
            3'b101: br1_cond_met = !br1_lt;                       // BGE
            3'b110: br1_cond_met = br1_ltu;                       // BLTU
            3'b111: br1_cond_met = !br1_ltu;                      // BGEU
            default: br1_cond_met = 1'b0;
        endcase
    end
    wire actual_redirect1 = (id_ex1_Branch && br1_cond_met) || id_ex1_Jump;
    wire [31:0] resolved_target1 = (id_ex1_opcode == 7'b1100111) ? ((id_ex1_rs1_data + id_ex1_imm) & ~32'b1) : (id_ex1_pc + id_ex1_imm);

    btb btb_inst (
        .clk(clk), .rst(rst),
        .lookup_pc(pc),
        .btb_hit(btb_hit), .btb_predict_taken(btb_predict_taken), .btb_target_pc(btb_target_pc),
        .update_en(id_ex1_Branch || id_ex1_Jump), .update_pc(id_ex1_pc),
        .update_taken(actual_redirect1), .update_target(resolved_target1) 
    );

    wire dir_mispredict1  = (actual_redirect1 != id_ex1_pred_taken);
    wire target_mispredict1 = actual_redirect1 && (resolved_target1 != id_ex1_pred_target);
    assign take_pc_redirect = dir_mispredict1 || target_mispredict1; 
    assign redirect_pc = (actual_redirect1) ? resolved_target1 : (id_ex1_pc + 32'd4);

    wire [31:0] alu2_in1_fwd = (forwardA2 == 2'b01) ? fwd_data_ex1_p1 :
                               (forwardA2 == 2'b10) ? fwd_data_ex1_p2 :
                               (forwardA2 == 2'b11) ? fwd_data_mem1_p1 : id_ex2_rs1_data;
    wire [31:0] alu2_in2_fwd = (forwardB2 == 2'b01) ? fwd_data_ex1_p1 :
                               (forwardB2 == 2'b10) ? fwd_data_ex1_p2 :
                               (forwardB2 == 2'b11) ? fwd_data_mem1_p1 : id_ex2_rs2_data;
    wire [31:0] alu2_in1 = alu2_in1_fwd;
    wire [31:0] alu2_in2 = (id_ex2_ALUSrc) ? id_ex2_imm : alu2_in2_fwd;
    wire [31:0] alu2_result; 
    alu alu2 (.A(alu2_in1), .B(alu2_in2), .ALU_ctrl(alu2_ctrl), .Result(alu2_result));
    wire [31:0] ex2_final_result = alu2_result; 

    // Backend Reg Updates
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_mem1_RegWrite <= 0; ex_mem1_MemRead <= 0; ex_mem1_MemWrite <= 0; ex_mem1_MemtoReg <= 0;
            ex_mem1_alu_result <= 0; ex_mem1_rs2_data <= 0; ex_mem1_pc_plus_4 <= 0; ex_mem1_rd_addr <= 0; ex_mem1_opcode <= 0;
            ex_mem1_RegWrite2 <= 0; ex_mem1_alu_result2 <= 0; ex_mem1_rd_addr2 <= 0;
        end else if (!mem_stall) begin 
            ex_mem1_RegWrite <= id_ex1_RegWrite; ex_mem1_MemRead <= id_ex1_MemRead; ex_mem1_MemWrite <= id_ex1_MemWrite; ex_mem1_MemtoReg <= id_ex1_MemtoReg;
            ex_mem1_alu_result <= ex1_final_result; 
            ex_mem1_rs2_data <= alu1_in2_fwd; 
            ex_mem1_pc_plus_4 <= id_ex1_pc + 32'd4; ex_mem1_rd_addr <= id_ex1_rd_addr; ex_mem1_opcode <= id_ex1_opcode;
            ex_mem1_RegWrite2 <= id_ex2_RegWrite; ex_mem1_alu_result2 <= ex2_final_result; ex_mem1_rd_addr2 <= id_ex2_rd_addr;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem1_mem2_RegWrite <= 0; mem1_mem2_MemRead <= 0; mem1_mem2_MemWrite <= 0; mem1_mem2_MemtoReg <= 0;
            mem1_mem2_alu_result <= 0; mem1_mem2_rs2_data <= 0; mem1_mem2_pc_plus_4 <= 0; mem1_mem2_rd_addr <= 0; mem1_mem2_opcode <= 0;
            mem1_mem2_RegWrite2 <= 0; mem1_mem2_alu_result2 <= 0; mem1_mem2_rd_addr2 <= 0;
        end else if (!mem_stall) begin 
            mem1_mem2_RegWrite <= ex_mem1_RegWrite; mem1_mem2_MemRead <= ex_mem1_MemRead; 
            mem1_mem2_MemWrite <= ex_mem1_MemWrite; 
            mem1_mem2_MemtoReg <= ex_mem1_MemtoReg;
            mem1_mem2_alu_result <= ex_mem1_alu_result; mem1_mem2_rs2_data <= ex_mem1_rs2_data; 
            mem1_mem2_pc_plus_4 <= ex_mem1_pc_plus_4; mem1_mem2_rd_addr <= ex_mem1_rd_addr; 
            mem1_mem2_opcode <= ex_mem1_opcode;
            mem1_mem2_RegWrite2 <= ex_mem1_RegWrite2; mem1_mem2_alu_result2 <= ex_mem1_alu_result2; mem1_mem2_rd_addr2 <= ex_mem1_rd_addr2;
        end
    end

    // Internal L1 Cache
    wire [31:0] cache_rdata;
    wire        mem_req_core = mem1_mem2_MemRead || mem1_mem2_MemWrite;

    cache u_cache (
        .clk(clk), .rst(rst),
        .core_req(mem_req_core), .core_we(mem1_mem2_MemWrite),
        .core_addr(mem1_mem2_alu_result), .core_wdata(mem1_mem2_rs2_data),
        .core_rdata(cache_rdata), .core_stall(mem_stall), 
        .bus_req(bus_req), .bus_we(bus_we), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata), .bus_ack(bus_ack),
        .snoop_valid(snoop_valid), .snoop_we(snoop_we), .snoop_addr(snoop_addr)
    );

    // MEM2/WB Reg
    reg [31:0] mem2_wb_alu_result, mem2_wb_mem_data, mem2_wb_pc_plus_4;
    reg [4:0]  mem2_wb_rd_addr; reg [6:0] mem2_wb_opcode;
    reg        mem2_wb_RegWrite, mem2_wb_MemRead, mem2_wb_MemtoReg;
    reg [31:0] mem2_wb_alu_result2; reg [4:0] mem2_wb_rd_addr2;
    reg        mem2_wb_RegWrite2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem2_wb_RegWrite <= 0; mem2_wb_MemRead <= 0; mem2_wb_MemtoReg <= 0; mem2_wb_alu_result <= 0; mem2_wb_mem_data <= 0; mem2_wb_pc_plus_4 <= 0; mem2_wb_rd_addr <= 0; mem2_wb_opcode <= 0;
            mem2_wb_RegWrite2 <= 0; mem2_wb_alu_result2 <= 0; mem2_wb_rd_addr2 <= 0;
        end else if (!mem_stall) begin 
            mem2_wb_RegWrite <= mem1_mem2_RegWrite; mem2_wb_MemRead <= mem1_mem2_MemRead; mem2_wb_MemtoReg <= mem1_mem2_MemtoReg; 
            mem2_wb_alu_result <= mem1_mem2_alu_result; mem2_wb_mem_data <= cache_rdata; mem2_wb_pc_plus_4 <= mem1_mem2_pc_plus_4; mem2_wb_rd_addr <= mem1_mem2_rd_addr; mem2_wb_opcode <= mem1_mem2_opcode;
            mem2_wb_RegWrite2 <= mem1_mem2_RegWrite2; mem2_wb_alu_result2 <= mem1_mem2_alu_result2; mem2_wb_rd_addr2 <= mem1_mem2_rd_addr2;
        end
    end

    // WB Stage
    wire is_jump1 = (mem2_wb_opcode == 7'b1101111) || (mem2_wb_opcode == 7'b1100111);
    assign wb1_wdata = (is_jump1) ? mem2_wb_pc_plus_4 : (mem2_wb_MemtoReg) ? mem2_wb_mem_data : mem2_wb_alu_result;
    assign wb1_RegWrite = mem2_wb_RegWrite;
    assign wb1_rd_addr  = mem2_wb_rd_addr;
    assign wb2_wdata = mem2_wb_alu_result2; 
    assign wb2_RegWrite = mem2_wb_RegWrite2;
    assign wb2_rd_addr  = mem2_wb_rd_addr2;

    // Scoreboard
    scoreboard sb (
        .clk(clk), .rst(rst),
        .valid1(if_id_valid1), .rs1_1(if_id_instr1[19:15]), .rs2_1(if_id_instr1[24:20]), 
        .rd_1(if_id_instr1[11:7]), .regWrite1(cu1_RegWrite), .is_simd1(is_simd_mul_id1),
        .valid2(if_id_valid2), .rs1_2(if_id_instr2[19:15]), .rs2_2(if_id_instr2[24:20]), 
        .rd_2(if_id_instr2[11:7]), .regWrite2(cu2_RegWrite), .inst2_is_ctrl(inst2_is_ctrl),
        .pipe2_supported(pipe2_supported),
        .issue1_ok(issue1_ok), .issue2_ok(issue2_ok),
        .ex_valid1(id_ex1_RegWrite), .ex_MemRead1(id_ex1_MemRead), .ex_rd1(id_ex1_rd_addr),
        .mem2_valid1(mem2_wb_RegWrite), .mem2_MemRead1(mem2_wb_MemRead), .mem2_rd1(mem2_wb_rd_addr),
        .wb_valid1(wb1_RegWrite), .wb_rd1(wb1_rd_addr),
        .ex_valid2(id_ex2_RegWrite), .ex_MemRead2(id_ex2_MemRead), .ex_rd2(id_ex2_rd_addr),
        .mem2_valid2(mem2_wb_RegWrite2), .mem2_MemRead2(1'b0), .mem2_rd2(mem2_wb_rd_addr2),
        .wb_valid2(wb2_RegWrite), .wb_rd2(wb2_rd_addr)
    );

endmodule
