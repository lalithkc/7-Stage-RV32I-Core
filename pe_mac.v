`timescale 1ns / 1ps
module pe_mac(
    input wire clk,
    input wire rst_n,
    input wire load_weight,
    input wire clear_acc,
    input wire valid_in,
    input wire [31:0] weight_in,
    input wire [31:0] act_in,

    output reg  [31:0] act_out,
    output reg  signed [31:0] acc_out,   // CHANGED: now signed
    output reg          valid_out,
    output wire [31:0] weight_out        // CHANGED: reg -> wire (continuous tap)
);
    reg [31:0] weight_reg;
    wire signed [31:0] next_acc;         // FIX #1: was implicitly-declared 1-bit wire

    // FIX #3 + #4: single-stage weight register, non-blocking, continuous output tap.
    // weight_out now moves 1 column per cycle in lockstep with act_out/valid_out.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            weight_reg <= 32'b0;
        else if (load_weight)
            weight_reg <= weight_in;
    end
    assign weight_out = weight_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_out   <= 32'b0;
            valid_out <= 1'b0;
        end else begin
            act_out   <= act_in;
            valid_out <= valid_in;
        end
    end

    simd_unit u_simd (
        .rs1        (act_in),
        .rs2        (weight_reg),
        .rd_current (acc_out),
        .simd_result(next_acc)           // now correctly connects a 32-bit signed wire
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin                // NOTE: added — acc_out had no reset in your original;
            acc_out <= 32'b0;            // harmless with clear_acc pulse in your TB, but cleaner
        end else if (clear_acc) begin
            acc_out <= 32'b0;
        end else if (valid_in) begin
            acc_out <= next_acc;
        end
    end
endmodule
