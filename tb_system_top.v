`timescale 1ns / 1ps

module tb_system_top();
    reg clk;
    reg rst;
    
    wire [31:0] pc0, pc1;
    reg  [31:0] imem0 [0:255];
    reg  [31:0] imem1 [0:255];
    wire [31:0] i1_0, i2_0, i1_1, i2_1;
    
    system_top dut (
        .clk(clk), .rst(rst),
        .instr_in1_c0(i1_0), .instr_in2_c0(i2_0), .pc_out_c0(pc0),
        .instr_in1_c1(i1_1), .instr_in2_c1(i2_1), .pc_out_c1(pc1)
    );

    always #5 clk = ~clk;
    initial begin
        $dumpfile("system_top.vcd");
        $dumpvars(0, tb_system_top);
    end
    assign i1_0 = imem0[pc0[9:2]];
    assign i2_0 = imem0[pc0[9:2] + 1];
    assign i1_1 = imem1[pc1[9:2]];
    assign i2_1 = imem1[pc1[9:2] + 1];

    integer i;
    reg pass0, pass1;

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            imem0[i] = 32'h00000013; 
            imem1[i] = 32'h00000013;
        end
        
        // ==========================================
        // Core 0 Program (ALUs grouped, Stores grouped)
        // ==========================================
        imem0[0] = 32'h00500093; // addi x1, x0, 5
        imem0[1] = 32'h00100113; // addi x2, x0, 1
        imem0[2] = 32'h00102023; // sw x1, 0(x0)       (mem[0] = 5)
        imem0[3] = 32'h00202223; // sw x2, 4(x0)       (mem[4] = 1 -> PASS0)
        imem0[4] = 32'h0000006f; // jal x0, 0          (Infinite loop)

        // ==========================================
        // Core 1 Program (ALUs grouped, Stores grouped)
        // ==========================================
        imem1[0] = 32'h00a00093; // addi x1, x0, 10
        imem1[1] = 32'h00100113; // addi x2, x0, 1
        imem1[2] = 32'h00102423; // sw x1, 8(x0)       (mem[8] = 10)
        imem1[3] = 32'h00202623; // sw x2, 12(x0)      (mem[12] = 1 -> PASS1)
        imem1[4] = 32'h0000006f; // jal x0, 0          (Infinite loop)

        pass0 = 0; 
        pass1 = 0;
        
        clk = 0;
        rst = 1;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 0;
        
        #20000;
        $display("[MULTI-CORE TEST] ERROR: Simulation timed out.");
        $finish;
    end

    integer cycle_count;
    initial begin
        cycle_count = 0;
        pass0 = 0;
        pass1 = 0;
        forever begin
            @(posedge clk);
            if (!rst) begin
                cycle_count = cycle_count + 1;
                
                if (dut.u_main_mem.mem_we) begin
                    $display("[%0t] MEM WRITE: addr=0x%08h, data=0x%08h", $time, dut.u_main_mem.mem_addr, dut.u_main_mem.mem_wdata);
                    if (dut.u_main_mem.mem_addr == 32'h00000004 && dut.u_main_mem.mem_wdata == 32'h1) pass0 = 1;
                    if (dut.u_main_mem.mem_addr == 32'h0000000c && dut.u_main_mem.mem_wdata == 32'h1) pass1 = 1;
                end
                
                if (pass0 && pass1) begin
                    $display("==================================================");
                    $display("[MULTI-CORE TEST] PASS: Both cores successfully wrote to SRAM!");
                    $display("==================================================");
                    $finish;
                end
                
                if (cycle_count > 2000) begin
                    $display("[MULTI-CORE TEST] ERROR: Timed out waiting for memory writes.");
                    $finish;
                end
            end
        end
    end

endmodule
