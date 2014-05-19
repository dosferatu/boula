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

`define fifo_wdth 64

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
  input wire [`fifo_wdth - 1:0] m_axis_tdata,
  input wire [`data_wdth - 1:0] m_axis_tkeep,
  input wire m_axis_tlast,
  input wire axis_underflow,
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
  output reg                            writeresp_enable
  /*}}}*/
);

// Declarations/*{{{*/

// State encodings
localparam IDLE     = 2'b00;
localparam REQUEST  = 2'b01;
localparam PROC     = 2'b10;
localparam EXEC     = 2'b11;

// MBurstSeq encoding for OCP 2.2
localparam INCR  = 3'b000;   // Incrementing
localparam DFLT1 = 3'b001;   // Custom (packed)
localparam WRAP  = 3'b010;   // Wrapping
localparam DFLT2 = 3'b011;   // Custom (not packed)
localparam XOR   = 3'b100;   // Exclusive OR
localparam STRM  = 3'b101;   // Streaming
localparam UNKN  = 3'b110;   // Unknown
localparam BLCK  = 3'b111;   // 2-dimensional Block

// Format encoding for PCI Express 2.0
localparam MRD    = 3'b000; // 3DW header, no data
localparam MRDLK  = 3'b001; // 4DW header, no data
localparam MWR    = 3'b010; // 3DW header, with data
localparam MWR2   = 3'b011; // 4DW header, with data
localparam PRFX   = 3'b100; // TLP Prefix

// Transaction encodings to generate OCP requests
localparam MEMORY_READ            = 3'b000;
localparam MEMORY_READ_LOCKED     = 3'b001;
localparam MEMORY_WRITE           = 3'b010;
localparam IO_READ                = 3'b011;
localparam IO_WRITE               = 3'b100;

reg [3:0] state;
reg [3:0] next;

// Translation registers

/*
 * NEED TO MUX IN TO THESE FOR SELECTION WHEN CALCULATING OUTPUTS
 *
 * Each stage in the PROC state we will use a counter set from the info
 * from the first header packet telling us how many total header packets
 * in order to know how many registers (maximum 4) to concatenate.
 */
reg [63:0] tlp_header_0;
reg [63:0] tlp_header_1;
reg [63:0] tlp_header_2;
reg [63:0] tlp_header_3;

reg [2:0] tlp_format;
reg [4:0] tlp_type;
reg [1:0] address_type;

reg [1:0] header_counter;
reg [9:0] data_counter;
reg [1:0] tlp_header_length;
reg [9:0] tlp_data_length;
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
        next[REQUEST] <= 1'b1;   // Data is in the AXI FIFO for us
      end
      
      else begin
        next[IDLE] <= 1'b1;
      end
      end

    state[REQUEST]: begin
      next[PROC] <= 1'b1;     // Calculate the request type
    end

    state[PROC]: begin
      if (header_counter == tlp_header_length) begin
        next[PROC] <= 1'b1;   // Header slices left to process
      end

      else begin
        next[EXEC] <= 1'b1;   // Ready to present the request to the OCP bus
      end
    end

    state[EXEC]: begin
      if (m_axis_tlast | (data_counter == tlp_data_length)) begin
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
    // AXI FIFO input
    m_aclk              <= 1'b0;
    m_axis_tready       <= 1'b0;

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

    // Bridge internals/*{{{*/

    header_counter <= 2'b0;
    data_counter <= 2'b0;
    tlp_data_length <= 10'b0;
    tlp_format <= 3'b0;
    tlp_header_length <= 2'b0;
    tlp_type <= 5'b0;
    tlp_header_0 <= 64'b0;
    tlp_header_1 <= 64'b0;
    tlp_header_2 <= 64'b0;
    tlp_header_3 <= 64'b0;
  end
  /*}}}*/
  /*}}}*/

  else begin
    case (1'b1)
      // IDLE/*{{{*/
      next[IDLE]: begin
        // AXI FIFO input
        m_aclk              <= 1'b0;
        m_axis_tready <= 1'b1;  // Notify the AXI FIFO we are ready for more data

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

        // Bridge internals/*{{{*/
        
        header_counter <= 2'b0;
        data_counter <= 2'b0;
        tlp_data_length <= 10'b0;
        tlp_format <= 3'b0;
        tlp_header_length <= 2'b0;
        tlp_type <= 5'b0;
        tlp_header_0 <= 64'b0;
        tlp_header_1 <= 64'b0;
        tlp_header_2 <= 64'b0;
        tlp_header_3 <= 64'b0;
      end
      /*}}}*/
      /*}}}*/

      // REQUEST/*{{{*/
      next[REQUEST]: begin
        // AXI FIFO input
        m_aclk              <= 1'b0;
        m_axis_tready <= 1'b0;  // Notify the AXI FIFO we are ready for more data

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

        // Bridge internals/*{{{*/
        
        case(m_axis_tdata[7:5])
          MRD: begin
            tlp_header_length <= 2'b10;
          end

          MRDLK: begin
            tlp_header_length <= 2'b11;
          end

          MWR: begin
            tlp_header_length <= 2'b10;
          end

          MWR2: begin
            tlp_header_length <= 2'b11;
          end

          PRFX: begin
            tlp_header_length <= 2'b10;
          end

          default: begin
            tlp_header_length <= 2'b0;
          end
        endcase
        
        data_counter <= 10'b0;
        header_counter <= 2'b0;
        tlp_data_length <= m_axis_tdata[31:24];
        tlp_format <= m_axis_tdata[7:5];
        tlp_type <= m_axis_tdata[4:0];
        tlp_header_0 <= m_axis_tdata;
        tlp_header_1 <= 64'b0;
        tlp_header_2 <= 64'b0;
        tlp_header_3 <= 64'b0;
      end
      /*}}}*/
      /*}}}*/

      // PROC/*{{{*/
      next[PROC]: begin
        // AXI FIFO input
        //m_aclk              <= 1'b0;
        m_axis_tready       <= 1'b1;

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

        // Bridge internals/*{{{*/
        
        data_counter <= 10'b0;
        header_counter <= m_axis_tvalid ? header_counter + 1'b1 : data_counter;
        tlp_data_length <= tlp_data_length;
        tlp_format <= m_axis_tdata[7:5];
        tlp_header_length <= tlp_header_length;
        tlp_type <= m_axis_tdata[4:0];
        tlp_header_0 <= m_axis_tdata;

        /*
         * Assign the next header packet if FIFO has valid data.
         * If there's no valid data ready then do nothing.
         */
        if (m_axis_tvalid) begin
          case (header_counter)
            0: begin
              tlp_header_0 <= tlp_header_0;
              tlp_header_1 <= 64'b0;
              tlp_header_2 <= 64'b0;
              tlp_header_3 <= 64'b0;
            end

            1: begin
              tlp_header_0 <= tlp_header_0;
              tlp_header_1 <= m_axis_tdata;
              tlp_header_2 <= 64'b0;
              tlp_header_3 <= 64'b0;
            end

            2: begin
              tlp_header_0 <= tlp_header_0;
              tlp_header_1 <= tlp_header_1;
              tlp_header_2 <= m_axis_tdata;
              tlp_header_3 <= 64'b0;
            end

            3: begin
              tlp_header_0 <= tlp_header_0;
              tlp_header_1 <= tlp_header_1;
              tlp_header_2 <= tlp_header_2;
              tlp_header_3 <= m_axis_tdata;
            end

            default: begin
              tlp_header_0 <= tlp_header_0;
              tlp_header_1 <= 64'b0;
              tlp_header_2 <= 64'b0;
              tlp_header_3 <= 64'b0;
            end
          endcase
        end

        else begin
          tlp_header_0 <= tlp_header_0;
          tlp_header_1 <= tlp_header_1;
          tlp_header_2 <= tlp_header_2;
          tlp_header_3 <= tlp_header_3;
        end
      end
      /*}}}*/
      /*}}}*/

      // EXEC/*{{{*/
      next[EXEC]: begin
        // AXI FIFO input
        m_aclk              <= 1'b0;
        m_axis_tready       <= 1'b0;

        // OCP 2.2 Interface/*{{{*/

        address             <= {`addr_wdth{1'b0}};  // Set this using the base address register + counter offset
        enable              <= 1'b1;
        burst_seq           <= INCR;
        burst_single_req    <= 1'b0;
        burst_length        <= 1'b1;
        data_valid          <= 1'b0;
        read_request        <= ~(tlp_format & 3'b010);
        ocp_reset           <= 1'b0;
        sys_clk             <= 1'b0;
        write_data          <= {`data_wdth{1'b0}};
        write_request       <= tlp_format & 3'b010; // Check if bit 2 is clear in the format register
        writeresp_enable    <= 1'b0;
        /*}}}*/

        // Bridge internals/*{{{*/
        
        data_counter <= m_axis_tvalid ? data_counter + 1'b1 : data_counter;
        header_counter <= 2'b0;
        tlp_data_length <= tlp_data_length;
        tlp_format <= tlp_format;
        tlp_header_length <= tlp_header_length;
        tlp_type <= tlp_type;
        tlp_header_0 <= tlp_header_0;
        tlp_header_1 <= tlp_header_1;
        tlp_header_2 <= tlp_header_2;
        tlp_header_3 <= tlp_header_3;
      end
      /*}}}*/
      /*}}}*/

      // DEFAULT/*{{{*/
      default: begin
        // AXI FIFO input
        m_aclk              <= 1'b0;
        m_axis_tready       <= 1'b0;

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

        // Bridge internals/*{{{*/
        
        header_counter <= 2'b0;
        data_counter <= 10'b0;
        tlp_data_length <= 10'b0;
        tlp_format <= 3'b0;
        tlp_header_length <= 2'b0;
        tlp_type <= 5'b0;
        tlp_header_0 <= m_axis_tdata;
        tlp_header_1 <= 64'b0;
        tlp_header_2 <= 64'b0;
        tlp_header_3 <= 64'b0;
      end
      /*}}}*/
      /*}}}*/
    endcase
  end
end
/*}}}*/
endmodule
