`timescale 1ns / 1ps
`default_nettype none

module axi_crossbar_2x2 (

    input  wire        clk,
    input  wire        rst_n,

    // ================================================================
    // MASTER 0
    // ================================================================

    input  wire [31:0] m0_awaddr,
    input  wire        m0_awvalid,
    output wire        m0_awready,

    input  wire [31:0] m0_wdata,
    input  wire [3:0]  m0_wstrb,
    input  wire        m0_wvalid,
    output wire        m0_wready,

    output wire [1:0]  m0_bresp,
    output wire        m0_bvalid,
    input  wire        m0_bready,

    input  wire [31:0] m0_araddr,
    input  wire        m0_arvalid,
    output wire        m0_arready,

    output wire [31:0] m0_rdata,
    output wire [1:0]  m0_rresp,
    output wire        m0_rvalid,
    input  wire        m0_rready,

    // ================================================================
    // MASTER 1
    // ================================================================

    input  wire [31:0] m1_awaddr,
    input  wire        m1_awvalid,
    output wire        m1_awready,

    input  wire [31:0] m1_wdata,
    input  wire [3:0]  m1_wstrb,
    input  wire        m1_wvalid,
    output wire        m1_wready,

    output wire [1:0]  m1_bresp,
    output wire        m1_bvalid,
    input  wire        m1_bready,

    input  wire [31:0] m1_araddr,
    input  wire        m1_arvalid,
    output wire        m1_arready,

    output wire [31:0] m1_rdata,
    output wire [1:0]  m1_rresp,
    output wire        m1_rvalid,
    input  wire        m1_rready,

    // ================================================================
    // SLAVE 0
    // ================================================================

    output wire [31:0] s0_awaddr,
    output wire        s0_awvalid,
    input  wire        s0_awready,

    output wire [31:0] s0_wdata,
    output wire [3:0]  s0_wstrb,
    output wire        s0_wvalid,
    input  wire        s0_wready,

    input  wire [1:0]  s0_bresp,
    input  wire        s0_bvalid,
    output wire        s0_bready,

    output wire [31:0] s0_araddr,
    output wire        s0_arvalid,
    input  wire        s0_arready,

    input  wire [31:0] s0_rdata,
    input  wire [1:0]  s0_rresp,
    input  wire        s0_rvalid,
    output wire        s0_rready,

    // ================================================================
    // SLAVE 1
    // ================================================================

    output wire [31:0] s1_awaddr,
    output wire        s1_awvalid,
    input  wire        s1_awready,

    output wire [31:0] s1_wdata,
    output wire [3:0]  s1_wstrb,
    output wire        s1_wvalid,
    input  wire        s1_wready,

    input  wire [1:0]  s1_bresp,
    input  wire        s1_bvalid,
    output wire        s1_bready,

    output wire [31:0] s1_araddr,
    output wire        s1_arvalid,
    input  wire        s1_arready,

    input  wire [31:0] s1_rdata,
    input  wire [1:0]  s1_rresp,
    input  wire        s1_rvalid,
    output wire        s1_rready
);

    // ================================================================
    // ADDRESS DECODE
    //
    // bit 31 = 0 -> S0
    // bit 31 = 1 -> S1
    // ================================================================

    wire m0_aw_s1 = m0_awaddr[31];
    wire m1_aw_s1 = m1_awaddr[31];

    wire m0_ar_s1 = m0_araddr[31];
    wire m1_ar_s1 = m1_araddr[31];


    // ================================================================
    // MASTER WRITE BUFFERS
    //
    // AXI4-Lite AW and W are independent channels.
    // ================================================================

    reg        m0_aw_buf_valid;
    reg [31:0] m0_aw_buf_addr;

    reg        m0_w_buf_valid;
    reg [31:0] m0_w_buf_data;
    reg [3:0]  m0_w_buf_strb;

    reg        m1_aw_buf_valid;
    reg [31:0] m1_aw_buf_addr;

    reg        m1_w_buf_valid;
    reg [31:0] m1_w_buf_data;
    reg [3:0]  m1_w_buf_strb;


    // ================================================================
    // MASTER WRITE RESPONSE REGISTERS
    // ================================================================

    reg        m0_bvalid_reg;
    reg [1:0]  m0_bresp_reg;

    reg        m1_bvalid_reg;
    reg [1:0]  m1_bresp_reg;


    // ================================================================
    // SLAVE 0 WRITE TRANSACTION
    // ================================================================

    reg        s0_wr_active;
    reg        s0_wr_owner;

    reg [31:0] s0_wr_addr_reg;
    reg [31:0] s0_wr_data_reg;
    reg [3:0]  s0_wr_strb_reg;

    reg        s0_aw_sent;
    reg        s0_w_sent;


    // ================================================================
    // SLAVE 1 WRITE TRANSACTION
    // ================================================================

    reg        s1_wr_active;
    reg        s1_wr_owner;

    reg [31:0] s1_wr_addr_reg;
    reg [31:0] s1_wr_data_reg;
    reg [3:0]  s1_wr_strb_reg;

    reg        s1_aw_sent;
    reg        s1_w_sent;


    // ================================================================
    // MASTER WRITE ACTIVE
    //
    // Each master has at most one outstanding write.
    // ================================================================

    wire m0_write_active =
        (s0_wr_active && (s0_wr_owner == 1'b0)) ||
        (s1_wr_active && (s1_wr_owner == 1'b0));

    wire m1_write_active =
        (s0_wr_active && (s0_wr_owner == 1'b1)) ||
        (s1_wr_active && (s1_wr_owner == 1'b1));


    // ================================================================
    // MASTER AWREADY
    // ================================================================

    assign m0_awready =
        !m0_aw_buf_valid &&
        !m0_write_active &&
        !m0_bvalid_reg;

    assign m1_awready =
        !m1_aw_buf_valid &&
        !m1_write_active &&
        !m1_bvalid_reg;


    // ================================================================
    // MASTER WREADY
    //
    // W is independent from AW.
    // ================================================================

    assign m0_wready =
        !m0_w_buf_valid &&
        !m0_bvalid_reg;

    assign m1_wready =
        !m1_w_buf_valid &&
        !m1_bvalid_reg;


    // ================================================================
    // COMPLETE WRITE REQUESTS
    // ================================================================

    wire m0_complete_s0 =
        m0_aw_buf_valid &&
        m0_w_buf_valid &&
        !m0_aw_buf_addr[31];

    wire m0_complete_s1 =
        m0_aw_buf_valid &&
        m0_w_buf_valid &&
         m0_aw_buf_addr[31];

    wire m1_complete_s0 =
        m1_aw_buf_valid &&
        m1_w_buf_valid &&
        !m1_aw_buf_addr[31];

    wire m1_complete_s1 =
        m1_aw_buf_valid &&
        m1_w_buf_valid &&
        m1_aw_buf_addr[31];


    // ================================================================
    // WRITE ARBITRATION
    //
    // S0:
    //   M0 has priority over M1
    //
    // S1:
    //   M0 has priority over M1
    //
    // Different slaves can operate concurrently.
    // ================================================================

    wire s0_grant_m0 =
        !s0_wr_active &&
        m0_complete_s0;

    wire s0_grant_m1 =
        !s0_wr_active &&
        !m0_complete_s0 &&
        m1_complete_s0;

    wire s1_grant_m0 =
        !s1_wr_active &&
        m0_complete_s1;

    wire s1_grant_m1 =
        !s1_wr_active &&
        !m0_complete_s1 &&
        m1_complete_s1;


    // ================================================================
    // S0 WRITE OUTPUTS
    // ================================================================

    assign s0_awaddr = s0_wr_addr_reg;
    assign s0_wdata  = s0_wr_data_reg;
    assign s0_wstrb  = s0_wr_strb_reg;

    assign s0_awvalid =
        s0_wr_active &&
        !s0_aw_sent;

    assign s0_wvalid =
        s0_wr_active &&
        !s0_w_sent;

    assign s0_bready =
        s0_wr_active &&
        (
            (s0_wr_owner == 1'b0) ?
            m0_bready :
            m1_bready
        );


    // ================================================================
    // S1 WRITE OUTPUTS
    // ================================================================

    assign s1_awaddr = s1_wr_addr_reg;
    assign s1_wdata  = s1_wr_data_reg;
    assign s1_wstrb  = s1_wr_strb_reg;

    assign s1_awvalid =
        s1_wr_active &&
        !s1_aw_sent;

    assign s1_wvalid =
        s1_wr_active &&
        !s1_w_sent;

    assign s1_bready =
        s1_wr_active &&
        (
            (s1_wr_owner == 1'b0) ?
            m0_bready :
            m1_bready
        );


    // ================================================================
    // MASTER WRITE RESPONSES
    // ================================================================

    assign m0_bvalid = m0_bvalid_reg;
    assign m0_bresp  = m0_bresp_reg;

    assign m1_bvalid = m1_bvalid_reg;
    assign m1_bresp  = m1_bresp_reg;


    // ================================================================
    // READ TRANSACTION STATE
    //
    // IMPORTANT:
    //
    // Each slave owns one read transaction.
    //
    // owner:
    //     0 = M0
    //     1 = M1
    //
    // The owner remains latched until the slave R handshake.
    // ================================================================

    reg        s0_rd_active;
    reg        s0_rd_owner;
    reg [31:0] s0_rd_addr_reg;
    reg        s0_rd_sent;

    reg        s1_rd_active;
    reg        s1_rd_owner;
    reg [31:0] s1_rd_addr_reg;
    reg        s1_rd_sent;

    // Per-slave response holding registers.
    // A slave response is captured on the slave R handshake and held
    // until the owning master consumes it.
    reg        s0_rhold_valid;
    reg        s0_rhold_owner;
    reg [31:0] s0_rhold_data;
    reg [1:0]  s0_rhold_resp;

    reg        s1_rhold_valid;
    reg        s1_rhold_owner;
    reg [31:0] s1_rhold_data;
    reg [1:0]  s1_rhold_resp;


    // ================================================================
    // MASTER READ ACTIVE
    //
    // A master cannot issue another read until its current R handshake
    // has completed.
    // ================================================================

    wire m0_read_active =
        (s0_rd_active && (s0_rd_owner == 1'b0)) ||
        (s1_rd_active && (s1_rd_owner == 1'b0)) ||
        (s0_rhold_valid && (s0_rhold_owner == 1'b0)) ||
        (s1_rhold_valid && (s1_rhold_owner == 1'b0));

    wire m1_read_active =
        (s0_rd_active && (s0_rd_owner == 1'b1)) ||
        (s1_rd_active && (s1_rd_owner == 1'b1)) ||
        (s0_rhold_valid && (s0_rhold_owner == 1'b1)) ||
        (s1_rhold_valid && (s1_rhold_owner == 1'b1));


    // ================================================================
    // READ REQUEST DECODE
    // ================================================================

    wire s0_ar_m0 =
        m0_arvalid &&
        !m0_ar_s1;

    wire s0_ar_m1 =
        m1_arvalid &&
        !m1_ar_s1;

    wire s1_ar_m0 =
        m0_arvalid &&
        m0_ar_s1;

    wire s1_ar_m1 =
        m1_arvalid &&
        m1_ar_s1;


    // ================================================================
    // READ ARBITRATION
    //
    // Each slave independently arbitrates.
    //
    // Therefore:
    //
    //     M0 -> S0
    //     M1 -> S1
    //
    // can happen simultaneously.
    //
    // If both masters request the same slave, M0 wins.
    //
    // FIX: A slave must not be re-granted to ANY master while its
    // per-slave read-hold register is still occupied by a previous,
    // unconsumed response (regardless of which master owns it).
    // Without this interlock, a slave could be re-armed for a new
    // owner while stale data for a different master was still
    // sitting in the hold register, causing that master to later
    // observe stale/incorrect RDATA. This is enforced below via the
    // added !s0_rhold_valid / !s1_rhold_valid qualifiers.
    // ================================================================

    wire s0_ar_grant_m0 =
        !s0_rd_active &&
        !s0_rhold_valid &&
        !m0_read_active &&
        s0_ar_m0;

    wire s0_ar_grant_m1 =
        !s0_rd_active &&
        !s0_rhold_valid &&
        !m1_read_active &&
        !s0_ar_m0 &&
        s0_ar_m1;

    wire s1_ar_grant_m0 =
        !s1_rd_active &&
        !s1_rhold_valid &&
        !m0_read_active &&
        s1_ar_m0;

    wire s1_ar_grant_m1 =
        !s1_rd_active &&
        !s1_rhold_valid &&
        !m1_read_active &&
        !s1_ar_m0 &&
        s1_ar_m1;


    // ================================================================
    // MASTER ARREADY
    //
    // ARREADY means the crossbar is actually accepting the request.
    // ================================================================

    assign m0_arready =
        s0_ar_grant_m0 ||
        s1_ar_grant_m0;

    assign m1_arready =
        s0_ar_grant_m1 ||
        s1_ar_grant_m1;


    // ================================================================
    // SLAVE READ ADDRESS OUTPUTS
    // ================================================================

    assign s0_araddr = s0_rd_addr_reg;

    assign s0_arvalid =
        s0_rd_active &&
        !s0_rd_sent;

    assign s1_araddr = s1_rd_addr_reg;

    assign s1_arvalid =
        s1_rd_active &&
        !s1_rd_sent;


    // ================================================================
    // READ RESPONSE ROUTING
    //
    // Each slave has an independent response holding register.
    // The response is captured when the slave R channel handshakes,
    // then held stable until the owning master handshakes R.
    // ================================================================

    assign m0_rvalid =
        (s0_rhold_valid && (s0_rhold_owner == 1'b0)) ||
        (s1_rhold_valid && (s1_rhold_owner == 1'b0));

    assign m0_rdata =
        (s0_rhold_valid && (s0_rhold_owner == 1'b0)) ?
        s0_rhold_data :
        (s1_rhold_valid && (s1_rhold_owner == 1'b0)) ?
        s1_rhold_data :
        32'b0;

    assign m0_rresp =
        (s0_rhold_valid && (s0_rhold_owner == 1'b0)) ?
        s0_rhold_resp :
        (s1_rhold_valid && (s1_rhold_owner == 1'b0)) ?
        s1_rhold_resp :
        2'b00;

    assign m1_rvalid =
        (s0_rhold_valid && (s0_rhold_owner == 1'b1)) ||
        (s1_rhold_valid && (s1_rhold_owner == 1'b1));

    assign m1_rdata =
        (s0_rhold_valid && (s0_rhold_owner == 1'b1)) ?
        s0_rhold_data :
        (s1_rhold_valid && (s1_rhold_owner == 1'b1)) ?
        s1_rhold_data :
        32'b0;

    assign m1_rresp =
        (s0_rhold_valid && (s0_rhold_owner == 1'b1)) ?
        s0_rhold_resp :
        (s1_rhold_valid && (s1_rhold_owner == 1'b1)) ?
        s1_rhold_resp :
        2'b00;


    // ================================================================
    // SLAVE RREADY
    //
    // Only the slave that currently owns a transaction can complete it.
    //
    // The master's RREADY is directly propagated.
    // ================================================================

    assign s0_rready =
        s0_rd_active &&
        s0_rd_sent &&
        !s0_rhold_valid;

    assign s1_rready =
        s1_rd_active &&
        s1_rd_sent &&
        !s1_rhold_valid;


    // ================================================================
    // SEQUENTIAL LOGIC
    // ================================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            // ========================================================
            // MASTER 0 WRITE BUFFERS
            // ========================================================

            m0_aw_buf_valid <= 1'b0;
            m0_aw_buf_addr  <= 32'b0;

            m0_w_buf_valid  <= 1'b0;
            m0_w_buf_data   <= 32'b0;
            m0_w_buf_strb   <= 4'b0;

            m0_bvalid_reg   <= 1'b0;
            m0_bresp_reg    <= 2'b00;


            // ========================================================
            // MASTER 1 WRITE BUFFERS
            // ========================================================

            m1_aw_buf_valid <= 1'b0;
            m1_aw_buf_addr  <= 32'b0;

            m1_w_buf_valid  <= 1'b0;
            m1_w_buf_data   <= 32'b0;
            m1_w_buf_strb   <= 4'b0;

            m1_bvalid_reg   <= 1'b0;
            m1_bresp_reg    <= 2'b00;


            // ========================================================
            // SLAVE 0 WRITE
            // ========================================================

            s0_wr_active   <= 1'b0;
            s0_wr_owner    <= 1'b0;
            s0_wr_addr_reg <= 32'b0;
            s0_wr_data_reg <= 32'b0;
            s0_wr_strb_reg <= 4'b0;
            s0_aw_sent     <= 1'b0;
            s0_w_sent      <= 1'b0;


            // ========================================================
            // SLAVE 1 WRITE
            // ========================================================

            s1_wr_active   <= 1'b0;
            s1_wr_owner    <= 1'b0;
            s1_wr_addr_reg <= 32'b0;
            s1_wr_data_reg <= 32'b0;
            s1_wr_strb_reg <= 4'b0;
            s1_aw_sent     <= 1'b0;
            s1_w_sent      <= 1'b0;


            // ========================================================
            // SLAVE 0 READ
            // ========================================================

            s0_rd_active   <= 1'b0;
            s0_rd_owner    <= 1'b0;
            s0_rd_addr_reg <= 32'b0;
            s0_rd_sent     <= 1'b0;


            // ========================================================
            // SLAVE 1 READ
            // ========================================================

            s1_rd_active   <= 1'b0;
            s1_rd_owner    <= 1'b0;
            s1_rd_addr_reg <= 32'b0;
            s1_rd_sent     <= 1'b0;

            s0_rhold_valid <= 1'b0;
            s0_rhold_owner <= 1'b0;
            s0_rhold_data  <= 32'b0;
            s0_rhold_resp  <= 2'b00;

            s1_rhold_valid <= 1'b0;
            s1_rhold_owner <= 1'b0;
            s1_rhold_data  <= 32'b0;
            s1_rhold_resp  <= 2'b00;

        end
        else begin

            // ========================================================
            // MASTER 0 AW CAPTURE
            // ========================================================

            if (m0_awvalid && m0_awready) begin

                m0_aw_buf_valid <= 1'b1;
                m0_aw_buf_addr  <= m0_awaddr;

            end


            // ========================================================
            // MASTER 0 W CAPTURE
            // ========================================================

            if (m0_wvalid && m0_wready) begin

                m0_w_buf_valid <= 1'b1;
                m0_w_buf_data  <= m0_wdata;
                m0_w_buf_strb  <= m0_wstrb;

            end


            // ========================================================
            // MASTER 1 AW CAPTURE
            // ========================================================

            if (m1_awvalid && m1_awready) begin

                m1_aw_buf_valid <= 1'b1;
                m1_aw_buf_addr  <= m1_awaddr;

            end


            // ========================================================
            // MASTER 1 W CAPTURE
            // ========================================================

            if (m1_wvalid && m1_wready) begin

                m1_w_buf_valid <= 1'b1;
                m1_w_buf_data  <= m1_wdata;
                m1_w_buf_strb  <= m1_wstrb;

            end


            // ========================================================
            // START S0 WRITE FROM M0
            // ========================================================

            if (s0_grant_m0) begin

                s0_wr_active   <= 1'b1;
                s0_wr_owner    <= 1'b0;

                s0_wr_addr_reg <= m0_aw_buf_addr;
                s0_wr_data_reg <= m0_w_buf_data;
                s0_wr_strb_reg <= m0_w_buf_strb;

                s0_aw_sent     <= 1'b0;
                s0_w_sent      <= 1'b0;

                m0_aw_buf_valid <= 1'b0;
                m0_w_buf_valid  <= 1'b0;

            end
            else if (s0_grant_m1) begin

                s0_wr_active   <= 1'b1;
                s0_wr_owner    <= 1'b1;

                s0_wr_addr_reg <= m1_aw_buf_addr;
                s0_wr_data_reg <= m1_w_buf_data;
                s0_wr_strb_reg <= m1_w_buf_strb;

                s0_aw_sent     <= 1'b0;
                s0_w_sent      <= 1'b0;

                m1_aw_buf_valid <= 1'b0;
                m1_w_buf_valid  <= 1'b0;

            end


            // ========================================================
            // S0 AW HANDSHAKE
            // ========================================================

            if (s0_wr_active &&
                !s0_aw_sent &&
                s0_awvalid &&
                s0_awready) begin

                s0_aw_sent <= 1'b1;

            end


            // ========================================================
            // S0 W HANDSHAKE
            // ========================================================

            if (s0_wr_active &&
                !s0_w_sent &&
                s0_wvalid &&
                s0_wready) begin

                s0_w_sent <= 1'b1;

            end


            // ========================================================
            // S0 B RESPONSE
            // ========================================================

            if (s0_wr_active &&
                s0_bvalid &&
                s0_bready) begin

                if (s0_wr_owner == 1'b0) begin

                    m0_bvalid_reg <= 1'b1;
                    m0_bresp_reg  <= s0_bresp;

                end
                else begin

                    m1_bvalid_reg <= 1'b1;
                    m1_bresp_reg  <= s0_bresp;

                end

                s0_wr_active <= 1'b0;
                s0_aw_sent   <= 1'b0;
                s0_w_sent    <= 1'b0;

            end


            // ========================================================
            // START S1 WRITE FROM M0
            // ========================================================

            if (s1_grant_m0) begin

                s1_wr_active   <= 1'b1;
                s1_wr_owner    <= 1'b0;

                s1_wr_addr_reg <= m0_aw_buf_addr;
                s1_wr_data_reg <= m0_w_buf_data;
                s1_wr_strb_reg <= m0_w_buf_strb;

                s1_aw_sent     <= 1'b0;
                s1_w_sent      <= 1'b0;

                m0_aw_buf_valid <= 1'b0;
                m0_w_buf_valid  <= 1'b0;

            end
            else if (s1_grant_m1) begin

                s1_wr_active   <= 1'b1;
                s1_wr_owner    <= 1'b1;

                s1_wr_addr_reg <= m1_aw_buf_addr;
                s1_wr_data_reg <= m1_w_buf_data;
                s1_wr_strb_reg <= m1_w_buf_strb;

                s1_aw_sent     <= 1'b0;
                s1_w_sent      <= 1'b0;

                m1_aw_buf_valid <= 1'b0;
                m1_w_buf_valid  <= 1'b0;

            end


            // ========================================================
            // S1 AW HANDSHAKE
            // ========================================================

            if (s1_wr_active &&
                !s1_aw_sent &&
                s1_awvalid &&
                s1_awready) begin

                s1_aw_sent <= 1'b1;

            end


            // ========================================================
            // S1 W HANDSHAKE
            // ========================================================

            if (s1_wr_active &&
                !s1_w_sent &&
                s1_wvalid &&
                s1_wready) begin

                s1_w_sent <= 1'b1;

            end


            // ========================================================
            // S1 B RESPONSE
            // ========================================================

            if (s1_wr_active &&
                s1_bvalid &&
                s1_bready) begin

                if (s1_wr_owner == 1'b0) begin

                    m0_bvalid_reg <= 1'b1;
                    m0_bresp_reg  <= s1_bresp;

                end
                else begin

                    m1_bvalid_reg <= 1'b1;
                    m1_bresp_reg  <= s1_bresp;

                end

                s1_wr_active <= 1'b0;
                s1_aw_sent   <= 1'b0;
                s1_w_sent    <= 1'b0;

            end


            // ========================================================
            // MASTER B HANDSHAKES
            // ========================================================

            if (m0_bvalid_reg && m0_bready)
                m0_bvalid_reg <= 1'b0;

            if (m1_bvalid_reg && m1_bready)
                m1_bvalid_reg <= 1'b0;


            // ========================================================
            // READ ACCEPTANCE - S0
            // ========================================================

            if (s0_ar_grant_m0) begin

                s0_rd_active   <= 1'b1;
                s0_rd_owner    <= 1'b0;
                s0_rd_addr_reg <= m0_araddr;
                s0_rd_sent     <= 1'b0;

            end
            else if (s0_ar_grant_m1) begin

                s0_rd_active   <= 1'b1;
                s0_rd_owner    <= 1'b1;
                s0_rd_addr_reg <= m1_araddr;
                s0_rd_sent     <= 1'b0;

            end


            // ========================================================
            // READ ACCEPTANCE - S1
            // ========================================================

            if (s1_ar_grant_m0) begin

                s1_rd_active   <= 1'b1;
                s1_rd_owner    <= 1'b0;
                s1_rd_addr_reg <= m0_araddr;
                s1_rd_sent     <= 1'b0;

            end
            else if (s1_ar_grant_m1) begin

                s1_rd_active   <= 1'b1;
                s1_rd_owner    <= 1'b1;
                s1_rd_addr_reg <= m1_araddr;
                s1_rd_sent     <= 1'b0;

            end


            // ========================================================
            // S0 AR HANDSHAKE
            // ========================================================

            if (s0_rd_active &&
                !s0_rd_sent &&
                s0_arvalid &&
                s0_arready) begin

                s0_rd_sent <= 1'b1;

            end


            // ========================================================
            // S1 AR HANDSHAKE
            // ========================================================

            if (s1_rd_active &&
                !s1_rd_sent &&
                s1_arvalid &&
                s1_arready) begin

                s1_rd_sent <= 1'b1;

            end


            // ========================================================
            // S0 R HANDSHAKE
            //
            // Capture the response in a per-slave holding register.
            // This makes RDATA/RRESP stable independently of the slave
            // response lifetime.
            // ========================================================

            if (s0_rd_active &&
                s0_rd_sent &&
                s0_rvalid &&
                s0_rready) begin

                s0_rhold_valid <= 1'b1;
                s0_rhold_owner <= s0_rd_owner;
                s0_rhold_data  <= s0_rdata;
                s0_rhold_resp  <= s0_rresp;

                s0_rd_active   <= 1'b0;
                s0_rd_sent     <= 1'b0;

            end


            // ========================================================
            // S1 R HANDSHAKE
            // ========================================================

            if (s1_rd_active &&
                s1_rd_sent &&
                s1_rvalid &&
                s1_rready) begin

                s1_rhold_valid <= 1'b1;
                s1_rhold_owner <= s1_rd_owner;
                s1_rhold_data  <= s1_rdata;
                s1_rhold_resp  <= s1_rresp;

                s1_rd_active   <= 1'b0;
                s1_rd_sent     <= 1'b0;

            end


            // ========================================================
            // MASTER 0 R HANDSHAKE
            // ========================================================

            if (m0_rvalid && m0_rready) begin

                if (s0_rhold_valid && (s0_rhold_owner == 1'b0))
                    s0_rhold_valid <= 1'b0;

                if (s1_rhold_valid && (s1_rhold_owner == 1'b0))
                    s1_rhold_valid <= 1'b0;

            end


            // ========================================================
            // MASTER 1 R HANDSHAKE
            // ========================================================

            if (m1_rvalid && m1_rready) begin

                if (s0_rhold_valid && (s0_rhold_owner == 1'b1))
                    s0_rhold_valid <= 1'b0;

                if (s1_rhold_valid && (s1_rhold_owner == 1'b1))
                    s1_rhold_valid <= 1'b0;

            end


        end

    end

endmodule

`default_nettype wire
