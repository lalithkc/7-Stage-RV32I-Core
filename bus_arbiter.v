`timescale 1ns / 1ps

module bus_arbiter (
    input  wire        clk,
    input  wire        rst,

    // ============================================================
    // Core 0 / Cache 0 Interface
    // ============================================================
    input  wire        req0,
    input  wire        we0,
    input  wire [31:0] addr0,
    input  wire [31:0] wdata0,

    output reg         ack0,
    output wire [31:0] rdata0,

    // ============================================================
    // Core 1 / Cache 1 Interface
    // ============================================================
    input  wire        req1,
    input  wire        we1,
    input  wire [31:0] addr1,
    input  wire [31:0] wdata1,

    output reg         ack1,
    output wire [31:0] rdata1,

    // ============================================================
    // Snoop Broadcast
    // ============================================================
    output reg         snoop_valid0,
    output reg         snoop_we0,
    output reg  [31:0] snoop_addr0,

    output reg         snoop_valid1,
    output reg         snoop_we1,
    output reg  [31:0] snoop_addr1,

    // ============================================================
    // Main Memory Interface
    // ============================================================
    output reg         mem_req,
    output reg         mem_we,
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,

    input  wire [31:0] mem_rdata,
    input  wire        mem_rvalid
);

    // ============================================================
    // States
    // ============================================================

    localparam IDLE       = 4'd0;

    localparam WRITE0     = 4'd1;
    localparam READ0_ISS  = 4'd2;
    localparam READ0_WAIT = 4'd3;
    localparam RESP0      = 4'd4;

    localparam WRITE1     = 4'd5;
    localparam READ1_ISS  = 4'd6;
    localparam READ1_WAIT = 4'd7;
    localparam RESP1      = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;

    // ============================================================
    // Latched transaction
    // ============================================================

    reg [31:0] addr_latched;
    reg [31:0] wdata_latched;

    // ============================================================
    // 1. Sequential State Register
    // ============================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            state         <= IDLE;
            addr_latched  <= 32'b0;
            wdata_latched <= 32'b0;

        end
        else begin

            state <= next_state;

            // Latch transaction parameters in IDLE
            if (state == IDLE) begin

                if (req0) begin
                    addr_latched  <= addr0;
                    wdata_latched <= wdata0;
                end
                else if (req1) begin
                    addr_latched  <= addr1;
                    wdata_latched <= wdata1;
                end

            end

        end

    end

    // ============================================================
    // 2. Combinational Next-State Logic
    // ============================================================

    always @(*) begin

        next_state = state;

        case (state)

            // =================================================
            // IDLE
            // =================================================

            IDLE: begin

                // Core 0 has priority
                if (req0) begin
                    if (we0)
                        next_state = WRITE0;
                    else
                        next_state = READ0_ISS;
                end

                else if (req1) begin
                    if (we1)
                        next_state = WRITE1;
                    else
                        next_state = READ1_ISS;
                end

            end


            // =================================================
            // CORE 0 WRITE
            // =================================================

            WRITE0: begin
                next_state = IDLE;
            end


            // =================================================
            // CORE 0 READ ISSUE
            //
            // mem_req is asserted for one cycle.
            // =================================================

            READ0_ISS: begin
                next_state = READ0_WAIT;
            end


            // =================================================
            // CORE 0 READ WAIT
            // =================================================

            READ0_WAIT: begin

                if (mem_rvalid)
                    next_state = RESP0;

            end


            // =================================================
            // CORE 0 RESPONSE
            // =================================================

            RESP0: begin
                next_state = IDLE;
            end


            // =================================================
            // CORE 1 WRITE
            // =================================================

            WRITE1: begin
                next_state = IDLE;
            end


            // =================================================
            // CORE 1 READ ISSUE
            // =================================================

            READ1_ISS: begin
                next_state = READ1_WAIT;
            end


            // =================================================
            // CORE 1 READ WAIT
            // =================================================

            READ1_WAIT: begin

                if (mem_rvalid)
                    next_state = RESP1;

            end


            // =================================================
            // CORE 1 RESPONSE
            // =================================================

            RESP1: begin
                next_state = IDLE;
            end


            default: begin
                next_state = IDLE;
            end

        endcase

    end


    // ============================================================
    // 3. Combinational Output Logic
    // ============================================================

    always @(*) begin

        // --------------------------------------------------------
        // Defaults
        // --------------------------------------------------------

        ack0 = 1'b0;
        ack1 = 1'b0;

        mem_req   = 1'b0;
        mem_we    = 1'b0;
        mem_addr  = addr_latched;
        mem_wdata = wdata_latched;

        snoop_valid0 = 1'b0;
        snoop_we0    = 1'b0;
        snoop_addr0  = 32'b0;

        snoop_valid1 = 1'b0;
        snoop_we1    = 1'b0;
        snoop_addr1  = 32'b0;


        case (state)

            // ====================================================
            // CORE 0 WRITE
            // ====================================================

            WRITE0: begin

                mem_req = 1'b1;
                mem_we  = 1'b1;

                ack0 = 1'b1;

                // Notify Core 1
                snoop_valid1 = 1'b1;
                snoop_we1    = 1'b1;
                snoop_addr1  = addr_latched;

            end


            // ====================================================
            // CORE 0 READ ISSUE
            // ====================================================

            READ0_ISS: begin

                mem_req = 1'b1;
                mem_we  = 1'b0;

            end


            // ====================================================
            // CORE 0 READ WAIT
            // ====================================================

            READ0_WAIT: begin

                mem_req = 1'b0;

            end


            // ====================================================
            // CORE 0 RESPONSE
            // ====================================================

            RESP0: begin

                ack0 = 1'b1;

            end


            // ====================================================
            // CORE 1 WRITE
            // ====================================================

            WRITE1: begin

                mem_req = 1'b1;
                mem_we  = 1'b1;

                ack1 = 1'b1;

                // Notify Core 0
                snoop_valid0 = 1'b1;
                snoop_we0    = 1'b1;
                snoop_addr0  = addr_latched;

            end


            // ====================================================
            // CORE 1 READ ISSUE
            // ====================================================

            READ1_ISS: begin

                mem_req = 1'b1;
                mem_we  = 1'b0;

            end


            // ====================================================
            // CORE 1 READ WAIT
            // ====================================================

            READ1_WAIT: begin

                mem_req = 1'b0;

            end


            // ====================================================
            // CORE 1 RESPONSE
            // ====================================================

            RESP1: begin

                ack1 = 1'b1;

            end

        endcase

    end


    // ============================================================
    // Read data
    //
    // mem_rdata is held by main_memory until the next read.
    // Only the core receiving ack uses it.
    // ============================================================

    assign rdata0 = mem_rdata;
    assign rdata1 = mem_rdata;

endmodule
