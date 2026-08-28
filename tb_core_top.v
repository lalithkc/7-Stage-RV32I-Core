`timescale 1ns / 1ps

module tb_core_top();
    reg clk;
    reg rst;
    
    wire [31:0] pc_out;
    reg  [31:0] instr_mem [0:1023];
    wire [31:0] instr_in1, instr_in2;
    
    wire [31:0] dmem_addr, dmem_wdata;
    wire        dmem_we;
    reg  [31:0] data_mem [0:1023];
    wire [31:0] dmem_rdata;
    
    integer i;

    core_top dut (
        .clk(clk), .rst(rst),
        .pc_out(pc_out),
        .instr_in1(instr_in1), .instr_in2(instr_in2),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), 
        .dmem_we(dmem_we), .dmem_rdata(dmem_rdata)
    );

    always #5 clk = ~clk;

    assign instr_in1 = instr_mem[pc_out[11:2]];
    assign instr_in2 = instr_mem[pc_out[11:2] + 1];

    always @(posedge clk) begin
        if (dmem_we) begin
            data_mem[dmem_addr[11:2]] <= dmem_wdata;
            
            // FIX: Look for 0xFFFFFFFC (sign-extended 0xFFC)
            if (dmem_addr == 32'hFFFFFFFC) begin
                if (dmem_wdata == 32'h00000001) begin
                    $display("[TEST RESULT] PASS: Wrote 1 to 0xFFFFFFFC");
                end else begin
                    $display("[TEST RESULT] FAIL: Wrote %d to 0xFFFFFFFC (Expected 1)", dmem_wdata);
                end
                $finish;
            end
        end
    end
    
    assign dmem_rdata = data_mem[dmem_addr[11:2]];

    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            instr_mem[i] = 32'h00000013; 
            data_mem[i] = 32'b0;
        end
        
        // ==========================================
        // Brutal Test Program (Corrected SIMD Hex)
        // ==========================================
        instr_mem[0]  = 32'h00500093; // addi x1, x0, 5
        instr_mem[1]  = 32'h00a00113; // addi x2, x0, 10
        instr_mem[2]  = 32'h002081b3; // add x3, x1, x2       
        instr_mem[3]  = 32'h001181b3; // add x3, x3, x1       
        instr_mem[4]  = 32'h00302023; // sw x3, 0(x0)
        instr_mem[5]  = 32'h00002203; // lw x4, 0(x0)
        instr_mem[6]  = 32'h00220233; // add x4, x4, x2       
        instr_mem[7]  = 32'h01420463; // beq x4, x4, 8        
        instr_mem[8]  = 32'h06300293; // addi x5, x0, 99      
        instr_mem[9]  = 32'h02a00313; // addi x6, x0, 42      
        instr_mem[10] = 32'h00000013; // nop
        instr_mem[11] = 32'h00100393; // addi x7, x0, 1
        instr_mem[12] = 32'h00200413; // addi x8, x0, 2
        instr_mem[13] = 32'h00100493; // addi x9, x0, 1
        instr_mem[14] = 32'h0094840b; // custom-0 x9, x8, x9  (SIMD MAC 1)
        instr_mem[15] = 32'h0094840b; // custom-0 x9, x8, x9  (SIMD MAC 2)
        instr_mem[16] = 32'h008000ef; // jal x1, 8            
        instr_mem[17] = 32'h06300393; // addi x7, x0, 99      
        instr_mem[18] = 32'h02800313; // addi x6, x0, 40      
        instr_mem[19] = 32'h003202b3; // add x5, x4, x3
        instr_mem[20] = 32'h006282b3; // add x5, x5, x6
        instr_mem[21] = 32'h008282b3; // add x5, x5, x8
        instr_mem[22] = 32'hf5228293; // addi x5, x5, -174
        instr_mem[23] = 32'h00028463; // beq x5, x0, 8        
        instr_mem[24] = 32'h00000313; // addi x6, x0, 0       
        instr_mem[25] = 32'hfe702e23; // sw x7, 0xFFC(x0)     
        instr_mem[26] = 32'h00100393; // addi x7, x0, 1       
        instr_mem[27] = 32'hfe702e23; // sw x7, 0xFFC(x0)     
        instr_mem[28] = 32'h00000013; // nop


        clk = 0;
        rst = 1;
        #15 rst = 0; 
        
        #200000;
        $display("[TEST RESULT] ERROR: Simulation timed out.");
        $finish;
    end



endmodule
