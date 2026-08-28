`timescale 1ns / 1ps
`default_nettype none

module systolic_array_4x4 (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control
    input  wire        load_weight,
    input  wire        clear_acc,
    input  wire        valid_in,
    
    // Activation Inputs
    input  wire [31:0] act_in_0,
    input  wire [31:0] act_in_1,
    input  wire [31:0] act_in_2,
    input  wire [31:0] act_in_3,
    
    // Weight Inputs
    input  wire [31:0] weight_in_0,
    input  wire [31:0] weight_in_1,
    input  wire [31:0] weight_in_2,
    input  wire [31:0] weight_in_3,

    // Output: Signed Accumulators
    output wire signed [31:0] acc_out_0,
    output wire signed [31:0] acc_out_1,
    output wire signed [31:0] acc_out_2,
    output wire signed [31:0] acc_out_3
);

    // Internal Wires
    wire [31:0] act_w    [3:0][3:0];
    wire [31:0] weight_w [3:0][3:0];
    wire signed [31:0] acc_w [3:0][3:0];   // FIXED: signed
    wire        valid_w  [3:0][3:0];

    genvar r, c;
    generate
        for (r = 0; r < 4; r = r + 1) begin: gen_row
            for (c = 0; c < 4; c = c + 1) begin: gen_col
                
                wire [31:0] cur_act_in;
                wire [31:0] cur_weight_in;
                wire        cur_valid_in;
                
                if (c == 0) begin: gen_col_0
                    assign cur_act_in    = (r == 0) ? act_in_0 :
                                           (r == 1) ? act_in_1 :
                                           (r == 2) ? act_in_2 : act_in_3;
                                           
                    assign cur_weight_in = (r == 0) ? weight_in_0 :
                                           (r == 1) ? weight_in_1 :
                                           (r == 2) ? weight_in_2 : weight_in_3;
                                           
                    assign cur_valid_in  = valid_in;
                end else begin: gen_col_n
                    assign cur_act_in    = act_w[r][c-1];
                    assign cur_weight_in = weight_w[r][c-1];
                    assign cur_valid_in  = valid_w[r][c-1];
                end
                
                pe_mac u_pe (
                    .clk        (clk),
                    .rst_n      (rst_n),
                    .load_weight(load_weight),
                    .clear_acc  (clear_acc),
                    .valid_in   (cur_valid_in),
                    
                    .weight_in  (cur_weight_in),
                    .act_in     (cur_act_in),
                    
                    .act_out    (act_w[r][c]),
                    .valid_out  (valid_w[r][c]),
                    .weight_out (weight_w[r][c]),
                    .acc_out    (acc_w[r][c])
                );
                
            end
        end
    endgenerate

    assign acc_out_0 = acc_w[0][3];
    assign acc_out_1 = acc_w[1][3];
    assign acc_out_2 = acc_w[2][3];
    assign acc_out_3 = acc_w[3][3];

endmodule
`default_nettype wire
