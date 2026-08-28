`timescale 1ns / 1ps
`default_nettype none

module axi4_lite_accel (
    // AXI4-Lite Global Signals
    input  wire        clk,
    input  wire        rst_n,
    
    // AXI4-Lite Write Address Channel
    input  wire [31:0] awaddr,
    input  wire        awvalid,
    output reg         awready,
    
    // AXI4-Lite Write Data Channel
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    input  wire        wvalid,
    output reg         wready,
    
    // AXI4-Lite Write Response Channel
    output reg  [1:0]  bresp,
    output reg         bvalid,
    input  wire        bready,
    
    // AXI4-Lite Read Address Channel
    input  wire [31:0] araddr,
    input  wire        arvalid,
    output reg         arready,
    
    // AXI4-Lite Read Data Channel
    output reg  [31:0] rdata,
    output reg  [1:0]  rresp,
    output reg         rvalid,
    input  wire        rready
);

    // ---------------------------------------------------------
    // Accelerator Internal Signals
    // ---------------------------------------------------------
    reg        load_weight;
    reg        clear_acc;
    reg        valid_in;
    
    reg  [31:0] weight_in_0, weight_in_1, weight_in_2, weight_in_3;
    reg  [31:0] act_in_0, act_in_1, act_in_2, act_in_3;
    
    wire signed [31:0] acc_out_0, acc_out_1, acc_out_2, acc_out_3;

    systolic_array_4x4 u_array (
        .clk        (clk),
        .rst_n      (rst_n),
        .load_weight(load_weight),
        .clear_acc  (clear_acc),
        .valid_in   (valid_in),
        .act_in_0   (act_in_0),
        .act_in_1   (act_in_1),
        .act_in_2   (act_in_2),
        .act_in_3   (act_in_3),
        .weight_in_0(weight_in_0),
        .weight_in_1(weight_in_1),
        .weight_in_2(weight_in_2),
        .weight_in_3(weight_in_3),
        .acc_out_0  (acc_out_0),
        .acc_out_1  (acc_out_1),
        .acc_out_2  (acc_out_2),
        .acc_out_3  (acc_out_3)
    );

    // ---------------------------------------------------------
    // AXI4-Lite Write Logic (AW, W, B channels)
    // ---------------------------------------------------------
    // Fixed ready generation to avoid oscillating when valid is held high
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awready <= 1'b1;
            wready  <= 1'b1;
        end else begin
            if (awvalid && awready) awready <= 1'b0;
            else if (!awvalid)      awready <= 1'b1;
            
            if (wvalid && wready)   wready  <= 1'b0;
            else if (!wvalid)       wready  <= 1'b1;
        end
    end

    wire write_transaction = awvalid && awready && wvalid && wready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_weight <= 1'b0;
            clear_acc   <= 1'b0;
            valid_in    <= 1'b0;
            weight_in_0 <= 32'b0;
            weight_in_1 <= 32'b0;
            weight_in_2 <= 32'b0;
            weight_in_3 <= 32'b0;
            act_in_0    <= 32'b0;
            act_in_1    <= 32'b0;
            act_in_2    <= 32'b0;
            act_in_3    <= 32'b0;
        end else begin
            // Default: pulse signals go low
            load_weight <= 1'b0;
            clear_acc   <= 1'b0;
            valid_in    <= 1'b0;

            if (write_transaction) begin
                case (awaddr[5:2]) 
                    4'h0: begin clear_acc <= 1'b1; end 
                    4'h1: begin weight_in_0 <= wdata; load_weight <= 1'b1; end 
                    4'h2: begin weight_in_1 <= wdata; load_weight <= 1'b1; end 
                    4'h3: begin weight_in_2 <= wdata; load_weight <= 1'b1; end 
                    4'h4: begin weight_in_3 <= wdata; load_weight <= 1'b1; end 
                    4'h5: begin act_in_0    <= wdata; valid_in    <= 1'b1; end 
                    4'h6: begin act_in_1    <= wdata; valid_in    <= 1'b1; end 
                    4'h7: begin act_in_2    <= wdata; valid_in    <= 1'b1; end 
                    4'h8: begin act_in_3    <= wdata; valid_in    <= 1'b1; end 
                endcase
            end
        end
    end

    // Write Response
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bvalid <= 1'b0;
            bresp  <= 2'b00; 
        end else begin
            if (write_transaction) begin
                bvalid <= 1'b1;
            end else if (bready && bvalid) begin
                bvalid <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------
    // AXI4-Lite Read Logic (AR, R channels)
    // ---------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arready <= 1'b1;
        end else begin
            if (arvalid && arready) arready <= 1'b0;
            else if (!arvalid)      arready <= 1'b1;
        end
    end

    wire read_transaction = arvalid && arready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid <= 1'b0;
            rdata  <= 32'b0;
            rresp  <= 2'b00;
        end else begin
            if (read_transaction) begin
                rvalid <= 1'b1;
                case (araddr[5:2])
                    4'h9: rdata <= acc_out_0; 
                    4'hA: rdata <= acc_out_1; 
                    4'hB: rdata <= acc_out_2; 
                    4'hC: rdata <= acc_out_3; 
                    default: rdata <= 32'b0;
                endcase
            end else if (rready && rvalid) begin
                rvalid <= 1'b0;
            end
        end
    end

endmodule
`default_nettype wire
