`timescale 1ns / 1ps

module tb_systolic_array;
    reg clk;
    reg rst_n;
    
    reg load_weight;
    reg clear_acc;
    reg valid_in;
    
    reg [31:0] act_in_0, act_in_1, act_in_2, act_in_3;
    reg [31:0] weight_in_0, weight_in_1, weight_in_2, weight_in_3;
    
    wire [31:0] acc_out_0, acc_out_1, acc_out_2, acc_out_3;

    // Instantiate the Array
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

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // 1. Initialize all signals
        clk = 0;
        rst_n = 0;
        load_weight = 0;
        clear_acc = 0;
        valid_in = 0;
        act_in_0 = 0; act_in_1 = 0; act_in_2 = 0; act_in_3 = 0;
        weight_in_0 = 0; weight_in_1 = 0; weight_in_2 = 0; weight_in_3 = 0;

        // 2. Deassert Reset
        #10 rst_n = 1;

        // 3. Clear Accumulators
        @(posedge clk); clear_acc = 1;
        @(posedge clk); clear_acc = 0;

        // 4. Load Weights into Row 0
        // Inject in reverse order so they land in the correct PE
        @(posedge clk);
        load_weight = 1;
        weight_in_0 = 32'h04040404; // W3 goes in first
        
        @(posedge clk);
        weight_in_0 = 32'h03030303; // W2 goes in second
        
        @(posedge clk);
        weight_in_0 = 32'h02020202; // W1 goes in third
        
        @(posedge clk);
        weight_in_0 = 32'h01010101; // W0 goes in last
        
        @(posedge clk);
        load_weight = 0;
        weight_in_0 = 0;

        // 5. Stream a single valid activation vector
        @(posedge clk);
        valid_in = 1;
        act_in_0 = 32'h02020202; // A0 = [2,2,2,2]
        
        @(posedge clk);
        valid_in = 0;
        act_in_0 = 0;

        // 6. Wait for the activation to ripple through all 4 PEs
        // Cycle 0: PE 0,0 computes (8)
        // Cycle 1: PE 0,1 computes (16)
        // Cycle 2: PE 0,2 computes (24)
        // Cycle 3: PE 0,3 computes (32) -> This is acc_out_0
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk); // Extra cycle to ensure registers settle

        // 7. Check Results
        $display("--- Systolic Array Test Results ---");
        $display("PE 0,3 Output (Expected 32): %d", acc_out_0);
        
        if (acc_out_0 == 32) 
            $display("Test PASSED!");
        else 
            $display("Test FAILED!");

        #10 $finish;
    end
endmodule
