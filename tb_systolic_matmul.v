`timescale 1ns / 1ps

module tb_systolic_matmul;
    reg clk;
    reg rst_n;
    
    reg load_weight;
    reg clear_acc;
    reg valid_in;
    
    reg [31:0] act_in_0, act_in_1, act_in_2, act_in_3;
    reg [31:0] weight_in_0, weight_in_1, weight_in_2, weight_in_3;
    
    wire signed [31:0] acc_out_0, acc_out_1, acc_out_2, acc_out_3;

    systolic_array_4x4 uut (
        .clk(clk),
        .rst_n(rst_n),
        .load_weight(load_weight),
        .clear_acc(clear_acc),
        .valid_in(valid_in),
        .act_in_0(act_in_0),
        .act_in_1(act_in_1),
        .act_in_2(act_in_2),
        .act_in_3(act_in_3),
        .weight_in_0(weight_in_0),
        .weight_in_1(weight_in_1),
        .weight_in_2(weight_in_2),
        .weight_in_3(weight_in_3),
        .acc_out_0(acc_out_0),
        .acc_out_1(acc_out_1),
        .acc_out_2(acc_out_2),
        .acc_out_3(acc_out_3)
    );

    always #5 clk = ~clk;

    integer errors;
    integer i;

    initial begin
        clk = 0;
        rst_n = 0;
        load_weight = 0;
        clear_acc = 0;
        valid_in = 0;
        act_in_0 = 0; act_in_1 = 0; act_in_2 = 0; act_in_3 = 0;
        weight_in_0 = 0; weight_in_1 = 0; weight_in_2 = 0; weight_in_3 = 0;
        errors = 0;

        #10 rst_n = 1;

        // 1. Clear Accumulators
        @(posedge clk); #1; clear_acc = 1;
        @(posedge clk); #1; clear_acc = 0;

        // 2. Load Weights (Columns of Matrix B)
        // We must shift them in reverse order so they land in the right columns.
        @(posedge clk); #1;
        load_weight = 1;
        // Inject Col 3 (0,0,0,1) -> 0x01000000
        weight_in_0 = 32'h01000000; 
        weight_in_1 = 32'h01000000; 
        weight_in_2 = 32'h01000000; 
        weight_in_3 = 32'h01000000; 

        @(posedge clk); #1;
        // Inject Col 2 (0,0,1,0) -> 0x00010000
        weight_in_0 = 32'h00010000; 
        weight_in_1 = 32'h00010000; 
        weight_in_2 = 32'h00010000; 
        weight_in_3 = 32'h00010000; 

        @(posedge clk); #1;
        // Inject Col 1 (0,1,0,0) -> 0x00000100
        weight_in_0 = 32'h00000100; 
        weight_in_1 = 32'h00000100; 
        weight_in_2 = 32'h00000100; 
        weight_in_3 = 32'h00000100; 

        @(posedge clk); #1;
        // Inject Col 0 (1,0,0,0) -> 0x00000001
        weight_in_0 = 32'h00000001; 
        weight_in_1 = 32'h00000001; 
        weight_in_2 = 32'h00000001; 
        weight_in_3 = 32'h00000001; 

        @(posedge clk); #1;
        load_weight = 0;
        weight_in_0 = 0; weight_in_1 = 0; weight_in_2 = 0; weight_in_3 = 0;

        // 3. Stream Activations (Rows of Matrix A)
        // We only need to stream for 1 cycle because the array ripples them to the right.
        @(posedge clk); #1;
        valid_in = 1;
        act_in_0 = 32'h04030201; // Row 0: 1, 2, 3, 4
        act_in_1 = 32'h08070605; // Row 1: 5, 6, 7, 8
        act_in_2 = 32'h0C0B0A09; // Row 2: 9, 10, 11, 12
        act_in_3 = 32'h100F0E0D; // Row 3: 13, 14, 15, 16
        
        @(posedge clk); #1;
        valid_in = 0;
        act_in_0 = 0; act_in_1 = 0; act_in_2 = 0; act_in_3 = 0;

        // 4. Wait for activations to ripple through all 4 columns
        for (i = 0; i < 4; i = i + 1) begin
            @(posedge clk); #1;
        end

        // 5. Check all 16 internal PEs
        $display("--- Full 4x4 Matmul Verification ---");
        
        // Row 0 Expected: 1, 2, 3, 4
        if (uut.gen_row[0].gen_col[0].u_pe.acc_out !== 1)  begin errors=errors+1; $display("FAIL: C[0][0] = %0d", uut.gen_row[0].gen_col[0].u_pe.acc_out); end
        if (uut.gen_row[0].gen_col[1].u_pe.acc_out !== 2)  begin errors=errors+1; $display("FAIL: C[0][1] = %0d", uut.gen_row[0].gen_col[1].u_pe.acc_out); end
        if (uut.gen_row[0].gen_col[2].u_pe.acc_out !== 3)  begin errors=errors+1; $display("FAIL: C[0][2] = %0d", uut.gen_row[0].gen_col[2].u_pe.acc_out); end
        if (uut.gen_row[0].gen_col[3].u_pe.acc_out !== 4)  begin errors=errors+1; $display("FAIL: C[0][3] = %0d", uut.gen_row[0].gen_col[3].u_pe.acc_out); end

        // Row 1 Expected: 5, 6, 7, 8
        if (uut.gen_row[1].gen_col[0].u_pe.acc_out !== 5)  begin errors=errors+1; $display("FAIL: C[1][0] = %0d", uut.gen_row[1].gen_col[0].u_pe.acc_out); end
        if (uut.gen_row[1].gen_col[1].u_pe.acc_out !== 6)  begin errors=errors+1; $display("FAIL: C[1][1] = %0d", uut.gen_row[1].gen_col[1].u_pe.acc_out); end
        if (uut.gen_row[1].gen_col[2].u_pe.acc_out !== 7)  begin errors=errors+1; $display("FAIL: C[1][2] = %0d", uut.gen_row[1].gen_col[2].u_pe.acc_out); end
        if (uut.gen_row[1].gen_col[3].u_pe.acc_out !== 8)  begin errors=errors+1; $display("FAIL: C[1][3] = %0d", uut.gen_row[1].gen_col[3].u_pe.acc_out); end

        // Row 2 Expected: 9, 10, 11, 12
        if (uut.gen_row[2].gen_col[0].u_pe.acc_out !== 9)  begin errors=errors+1; $display("FAIL: C[2][0] = %0d", uut.gen_row[2].gen_col[0].u_pe.acc_out); end
        if (uut.gen_row[2].gen_col[1].u_pe.acc_out !== 10) begin errors=errors+1; $display("FAIL: C[2][1] = %0d", uut.gen_row[2].gen_col[1].u_pe.acc_out); end
        if (uut.gen_row[2].gen_col[2].u_pe.acc_out !== 11) begin errors=errors+1; $display("FAIL: C[2][2] = %0d", uut.gen_row[2].gen_col[2].u_pe.acc_out); end
        if (uut.gen_row[2].gen_col[3].u_pe.acc_out !== 12) begin errors=errors+1; $display("FAIL: C[2][3] = %0d", uut.gen_row[2].gen_col[3].u_pe.acc_out); end

        // Row 3 Expected: 13, 14, 15, 16
        if (uut.gen_row[3].gen_col[0].u_pe.acc_out !== 13) begin errors=errors+1; $display("FAIL: C[3][0] = %0d", uut.gen_row[3].gen_col[0].u_pe.acc_out); end
        if (uut.gen_row[3].gen_col[1].u_pe.acc_out !== 14) begin errors=errors+1; $display("FAIL: C[3][1] = %0d", uut.gen_row[3].gen_col[1].u_pe.acc_out); end
        if (uut.gen_row[3].gen_col[2].u_pe.acc_out !== 15) begin errors=errors+1; $display("FAIL: C[3][2] = %0d", uut.gen_row[3].gen_col[2].u_pe.acc_out); end
        if (uut.gen_row[3].gen_col[3].u_pe.acc_out !== 16) begin errors=errors+1; $display("FAIL: C[3][3] = %0d", uut.gen_row[3].gen_col[3].u_pe.acc_out); end

        if (errors == 0) $display("TEST PASSED: Full 4x4 Matmul Correct!");
        else $display("TEST FAILED: %0d errors", errors);

        #10 $finish;
    end
endmodule
