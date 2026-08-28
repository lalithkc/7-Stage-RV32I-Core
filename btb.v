`timescale 1ns / 1ps

module btb (
    input  wire        clk,
    input  wire        rst,
    
    // Lookup Port (IF Stage)
    input  wire [31:0] lookup_pc,
    output wire        btb_hit,        // Did we see this branch before?
    output wire        btb_predict_taken, // Should we take the branch?
    output wire [31:0] btb_target_pc,  // Predicted target address
    
    // Update Port (EX Stage - when a branch resolves)
    input  wire        update_en,      // 1 if a branch is resolving in EX
    input  wire [31:0] update_pc,      // PC of the resolving branch
    input  wire        update_taken,   // Did the branch actually take?
    input  wire [31:0] update_target   // Actual target of the branch
);

    // BTB Parameters
    localparam NUM_ENTRIES = 64;
    localparam ADDR_BITS = $clog2(NUM_ENTRIES); // 6 bits
    
    // Storage
    reg [31:0] target_array [0:NUM_ENTRIES-1];
    reg [31:0] tag_array    [0:NUM_ENTRIES-1];
    reg        valid_array  [0:NUM_ENTRIES-1];
    reg [1:0]  counter_array[0:NUM_ENTRIES-1]; // 2-bit saturating counter
    
    integer i;
    
    // ==========================================
    // 1. Lookup Logic (Combinational)
    // ==========================================
    // We use PC[7:2] as the index (ignores the lower 2 bits since instructions are 4-byte aligned)
    wire [ADDR_BITS-1:0] lookup_index = lookup_pc[ADDR_BITS+1:2];
    wire [31:0]          lookup_tag   = lookup_pc;
    
    assign btb_hit   = valid_array[lookup_index] && (tag_array[lookup_index] == lookup_tag);
    assign btb_target_pc = target_array[lookup_index];
    
    // 2-bit Saturating Counter:
    // 00: Strongly Not Taken
    // 01: Weakly Not Taken
    // 10: Weakly Taken
    // 11: Strongly Taken
    // We predict Taken if the MSB is 1.
    assign btb_predict_taken = counter_array[lookup_index][1];

    // ==========================================
    // 2. Update Logic (Synchronous on EX resolution)
    // ==========================================
    wire [ADDR_BITS-1:0] update_index = update_pc[ADDR_BITS+1:2];
    wire [31:0]          update_tag   = update_pc;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
                valid_array[i]   <= 1'b0;
                counter_array[i] <= 2'b00; // Default to Not Taken
                target_array[i]  <= 32'b0;
                tag_array[i]     <= 32'b0;
            end
        end else if (update_en) begin
            // Update the tag and target
            tag_array[update_index]    <= update_tag;
            target_array[update_index] <= update_target;
            valid_array[update_index]  <= 1'b1;
            
            // Update the 2-bit saturating counter
            if (update_taken) begin
                // If taken, increment counter up to max (11)
                if (counter_array[update_index] != 2'b11)
                    counter_array[update_index] <= counter_array[update_index] + 1'b1;
            end else begin
                // If not taken, decrement counter down to min (00)
                if (counter_array[update_index] != 2'b00)
                    counter_array[update_index] <= counter_array[update_index] - 1'b1;
            end
        end
    end

endmodule
