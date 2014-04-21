/*
 * AXI to OCP translation block
 * Author: Michael Walton
 *
 * This module translates the PCIe TLP header in to a valid
 * OCP transaction request.
 */

// OCP 2.2 interface/*{{{*/

// Basic group
`define addr_wdth 64
`define data_wdth 8

// Simple group
//`define addrspace_wdth 0
`define mdatainfo_wdth 0
`define reqinfo_wdth 0
`define respinfo_wdth 0
`define sdatainfo_wdth 0

// Burst group
`define atomiclength_wdth 0
`define burstlength_wdth 10
`define blockheight_wdth 10
`define blockstride_wdth 10

// Tag group
//`define tags 0

// Thread group
//`define connid_width 0
//`define threads 0

// Sideband group
//`define control_wdth 0
//`define mflag_wdth 0
//`define sflag_wdth 0

// Test group
//`define scanctrl_wdth 0
//`define scanport_wdth 0
/*}}}*/

/*
 * DESIGN NOTES:
 * message requests use a sub-field to specify the message routing mechanism
 *
 * combinational logic is going to be used to translate the bridge to avoid
 * extra clocks being introduced in to the pipeline
 */

module axi2ocp(
  input wire clk,
  input wire reset,

  // AXI FIFO/*{{{*/
  output reg m_aclk,
  input wire m_axis_tvalid,
  output reg m_axis_tready,
  input wire [63:0] m_axis_tdata,
  input wire [7:0] m_axis_tkeep,
  input wire m_axis_tlast,
  input wire axis_overflow,
  /*}}}*/
  
  // OCP 2.2 Interface/*{{{*/
  output reg [`addr_wdth - 1:0]         address,
  output reg                            enable,
  output reg [2:0]                      burst_seq,
  output reg                            burst_single_req,
  output reg [9:0]                      burst_length,
  output reg                            data_valid,
  output reg                            read_request,
  output reg                            ocp_reset,
  output reg                            sys_clk,
  output reg [`data_wdth - 1:0]         write_data,
  output reg                            write_request,
  output reg                            writeresp_enable,
  /*}}}*/

  // Header FIFO output/*{{{*/
  output reg s_aclk, // input s_aclk
  output reg s_aresetn, // input s_aresetn
  output reg s_axis_tvalid, // input s_axis_tvalid
  input wire s_axis_tready, // output s_axis_tready
  output reg [63:0] s_axis_tdata, // input [63 : 0] s_axis_tdata
  output reg [7:0] s_axis_tkeep, // input [7 : 0] s_axis_tkeep
  output reg s_axis_tlast, // input s_axis_tlast
  input wire axis_underflow // output axis_underflow
  /*}}}*/
);

// Declarations/*{{{*/

// State encodings
localparam IDLE   = 2'b00;
localparam PROC   = 2'b01;
localparam EXEC   = 2'b10;

// MBurstSeq encoding for OCP 2.2
localparam INCR  = 3'b000;   // Incrementing
localparam DFLT1 = 3'b001;   // Custom (packed)
localparam WRAP  = 3'b010;   // Wrapping
localparam DFLT2 = 3'b011;   // Custom (not packed)
localparam XOR   = 3'b100;   // Exclusive OR
localparam STRM  = 3'b101;   // Streaming
localparam UNKN  = 3'b110;   // Unknown
localparam BLCK  = 3'b111;   // 2-dimensional Block

reg [3:0] state;
reg [3:0] next;

reg [1:0] counter;

/*
 * NEED TO MUX IN TO THESE FOR SELECTION WHEN CALCULATING OUTPUTS
 *
 * Each stage in the PROC state we will use a counter set from the info
 * from the first header packet telling us how many total header packets
 * in order to know how many registers (maximum 4) to concatenate.
 */
reg [63:0] header_0;
reg [63:0] header_1;
reg [63:0] header_2;
reg [63:0] header_3;
/*}}}*/



// State transition logic/*{{{*/
always @(posedge clk) begin
  if (reset) begin
    state <= 4'b0;
    state[IDLE] <= 1'b1;
  end

  else begin
    state <= next;
  end
end
/*}}}*/

// Next state logic/*{{{*/
always @(state) begin
  next <= 4'b0;

  case (1'b1)
    state[IDLE]: begin
      if (m_axis_tvalid) begin
        next[PROC] <= 1'b1;   // Data is in the AXI FIFO for us
      end

      else begin
        next[IDLE] <= 1'b1;
      end
    end

    state[PROC]: begin
      if (counter) begin
        next[PROC] <= 1'b1;   // Header slices left to process
      end

      else begin
        next[EXEC] <= 1'b1;   // Ready to present the request to the OCP bus
      end
    end

    state[EXEC]: begin
      if (m_axis_tlast | ~counter) begin
        next[IDLE] <= 1'b1;   // We've either written the last data, or requested the last read
      end

      else begin
        next[EXEC] <= 1'b1;   // Still data left in the FIFO for us to gather
      end
    end

    default: begin
      next[IDLE] <= 1'b1;
    end
  endcase
end
/*}}}*/

// Output logic/*{{{*/
always @(posedge clk) begin
  // RESET/*{{{*/
  if (reset) begin
    // FIFO lines/*{{{*/
    
    // AXI FIFO input
    m_aclk              <= 1'b0;
    m_axis_tready       <= 1'b0;

    // Header FIFO output
    s_aclk              <= 1'b0;
    s_aresetn           <= 1'b0;
    s_axis_tvalid       <= 1'b0;
    s_axis_tdata        <= 64'bx;
    s_axis_tkeep        <= 8'b0;
    s_axis_tlast        <= 1'b0;
    /*}}}*/

    // OCP 2.2 Interface/*{{{*/
    
    address             <= {`addr_wdth{1'b0}};
    enable              <= 1'b0;
    burst_seq           <= INCR;
    burst_single_req    <= 1'b0;
    burst_length        <= 1'b1;
    data_valid          <= 1'b0;
    read_request        <= 1'b0;
    ocp_reset           <= 1'b0;
    sys_clk             <= 1'b0;
    write_data          <= {`data_wdth{1'b0}};
    write_request       <= 1'b0;
    writeresp_enable    <= 1'b0;
    /*}}}*/

    counter <= 2'b0;
    header_0 <= 64'b0;
    header_1 <= 64'b0;
    header_2 <= 64'b0;
    header_3 <= 64'b0;
  end
/*}}}*/

  else begin
    case (1'b1)
      // IDLE/*{{{*/
      next[IDLE]: begin
        // FIFO lines/*{{{*/

        // AXI FIFO input
        m_aclk              <= 1'b0;
        m_axis_tready <= 1'b1;  // Notify the AXI FIFO we are ready for more data

        // Header FIFO output
        s_aclk              <= 1'b0;
        s_aresetn           <= 1'b0;
        s_axis_tvalid       <= 1'b0;
        s_axis_tdata        <= 64'bx;
        s_axis_tkeep        <= 8'b0;
        s_axis_tlast        <= 1'b0;
        /*}}}*/

        // OCP 2.2 Interface/*{{{*/

        address             <= {`addr_wdth{1'b0}};
        enable              <= 1'b1;
        burst_seq           <= INCR;
        burst_single_req    <= 1'b0;
        burst_length        <= 1'b1;
        data_valid          <= 1'b0;
        read_request        <= 1'b0;
        ocp_reset           <= 1'b0;
        sys_clk             <= 1'b0;
        write_data          <= {`data_wdth{1'b0}};
        write_request       <= 1'b0;
        writeresp_enable    <= 1'b0;
        /*}}}*/

        counter <= 2'b0;
        header_0 <= 64'b0;
        header_1 <= 64'b0;
        header_2 <= 64'b0;
        header_3 <= 64'b0;
      end
      /*}}}*/

      // PROC/*{{{*/
      next[PROC]: begin
        // FIFO lines/*{{{*/

        // AXI FIFO input
        m_aclk              <= 1'b0;
        m_axis_tready       <= 1'b0;

        // Header FIFO output
        s_aclk              <= 1'b0;
        s_aresetn           <= 1'b0;
        s_axis_tvalid       <= 1'b0;
        s_axis_tdata        <= 64'bx;
        s_axis_tkeep        <= 8'b0;
        s_axis_tlast        <= 1'b0;
        /*}}}*/

        // OCP 2.2 Interface/*{{{*/

        address             <= {`addr_wdth{1'b0}};
        enable              <= 1'b1;
        burst_seq           <= INCR;
        burst_single_req    <= 1'b0;
        burst_length        <= 1'b1;
        data_valid          <= 1'b0;
        read_request        <= 1'b0;
        ocp_reset           <= 1'b0;
        sys_clk             <= 1'b0;
        write_data          <= {`data_wdth{1'b0}};
        write_request       <= 1'b0;
        writeresp_enable    <= 1'b0;
        /*}}}*/

        counter <= 2'b0;
        header_0 <= 64'b0;
        header_1 <= 64'b0;
        header_2 <= 64'b0;
        header_3 <= 64'b0;
      end
      /*}}}*/

      // EXEC/*{{{*/
      next[EXEC]: begin
        // FIFO lines/*{{{*/

        // AXI FIFO input
        m_aclk              <= 1'b0;
        m_axis_tready       <= 1'b0;

        // Header FIFO output
        s_aclk              <= 1'b0;
        s_aresetn           <= 1'b0;
        s_axis_tvalid       <= 1'b0;
        s_axis_tdata        <= 64'bx;
        s_axis_tkeep        <= 8'b0;
        s_axis_tlast        <= 1'b0;
        /*}}}*/

        // OCP 2.2 Interface/*{{{*/

        address             <= {`addr_wdth{1'b0}};
        enable              <= 1'b1;
        burst_seq           <= INCR;
        burst_single_req    <= 1'b0;
        burst_length        <= 1'b1;
        data_valid          <= 1'b0;
        read_request        <= 1'b0;
        ocp_reset           <= 1'b0;
        sys_clk             <= 1'b0;
        write_data          <= {`data_wdth{1'b0}};
        write_request       <= 1'b0;
        writeresp_enable    <= 1'b0;
        /*}}}*/

        counter <= 2'b0;
        header_0 <= 64'b0;
        header_1 <= 64'b0;
        header_2 <= 64'b0;
        header_3 <= 64'b0;
      end
      /*}}}*/

      // DEFAULT/*{{{*/
      default: begin
        // FIFO lines/*{{{*/

        // AXI FIFO input
        m_aclk              <= 1'b0;
        m_axis_tready       <= 1'b0;

        // Header FIFO output
        s_aclk              <= 1'b0;
        s_aresetn           <= 1'b0;
        s_axis_tvalid       <= 1'b0;
        s_axis_tdata        <= 64'bx;
        s_axis_tkeep        <= 8'b0;
        s_axis_tlast        <= 1'b0;
        /*}}}*/

        // OCP 2.2 Interface/*{{{*/

        address             <= {`addr_wdth{1'b0}};
        enable              <= 1'b0;
        burst_seq           <= INCR;
        burst_single_req    <= 1'b0;
        burst_length        <= 1'b1;
        data_valid          <= 1'b0;
        read_request        <= 1'b0;
        ocp_reset           <= 1'b0;
        sys_clk             <= 1'b0;
        write_data          <= {`data_wdth{1'b0}};
        write_request       <= 1'b0;
        writeresp_enable    <= 1'b0;
        /*}}}*/

        counter <= 2'b0;
        header_0 <= 64'b0;
        header_1 <= 64'b0;
        header_2 <= 64'b0;
        header_3 <= 64'b0;
      end
      /*}}}*/
    endcase
  end
end
/*}}}*/
endmodule
