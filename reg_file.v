`timescale 1ns / 1ps

module reg_file (
    input  wire        clk,
    input  wire        rst,
    
    // Write port 1
    input  wire        we1,
    input  wire [4:0]  waddr1,
    input  wire [31:0] wdata1,
    
    // Write port 2
    input  wire        we2,
    input  wire [4:0]  waddr2,
    input  wire [31:0] wdata2,
    
    // Read ports
    input  wire [4:0]  raddr1, raddr2, raddr3, raddr4, raddr5,
    output wire [31:0] rdata1, rdata2, rdata3, rdata4, rdata5
);

    reg [31:0] registers [0:31];
    integer i;

    // Full-cycle Synchronous Write on POSEDGE
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) registers[i] <= 32'b0;
        end else begin
            if (we1 && (waddr1 != 5'b0)) registers[waddr1] <= wdata1;
            if (we2 && (waddr2 != 5'b0) && !(we1 && waddr1 == waddr2)) registers[waddr2] <= wdata2;
        end
    end

    // Asynchronous Reads with Write-Bypass (Write-First)
    // If we are reading the same address being written this cycle, 
    // forward the write data directly to the output.
    
    // Port 1
    assign rdata1 = (raddr1 == 5'b0)             ? 32'b0 :
                    (we1 && raddr1 == waddr1)    ? wdata1 :
                    (we2 && raddr1 == waddr2)    ? wdata2 :
                                                    registers[raddr1];

    // Port 2
    assign rdata2 = (raddr2 == 5'b0)             ? 32'b0 :
                    (we1 && raddr2 == waddr1)    ? wdata1 :
                    (we2 && raddr2 == waddr2)    ? wdata2 :
                                                    registers[raddr2];

    // Port 3
    assign rdata3 = (raddr3 == 5'b0)             ? 32'b0 :
                    (we1 && raddr3 == waddr1)    ? wdata1 :
                    (we2 && raddr3 == waddr2)    ? wdata2 :
                                                    registers[raddr3];

    // Port 4
    assign rdata4 = (raddr4 == 5'b0)             ? 32'b0 :
                    (we1 && raddr4 == waddr1)    ? wdata1 :
                    (we2 && raddr4 == waddr2)    ? wdata2 :
                                                    registers[raddr4];

    // Port 5 (SIMD Accumulator)
    assign rdata5 = (raddr5 == 5'b0)             ? 32'b0 :
                    (we1 && raddr5 == waddr1)    ? wdata1 :
                    (we2 && raddr5 == waddr2)    ? wdata2 :
                                                    registers[raddr5];

endmodule
