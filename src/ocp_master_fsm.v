/*
 * OCP Master Controller
 * Author: Michael Walton
 *
 * Default tie-off values can be found in reset logic section of the output FSM block
 */

/*
 * DESIGN NOTES
 * request group valid when we are not in IDLE state
 * response group valid whenever SResp != Null
 * datahandshake group valid whenever MDataValid == 1
 *
 * accept signals only valid for group when that group is valid
 *
 * request phase ends when SCmdAccept gets sampled as high
 * response phase ends whenever MRespAccept gets sampled as high
 * datahandshake phase ends when SDataAccept is sampled as high
 *
 */ 

// OCP 2.2 interface/*{{{*/

// Basic group
`define addr_wdth 64
`define data_wdth 8

// Simple group
`define addrspace_wdth 0
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
`define tags 0

// Thread group
`define connid_width 0
`define threads 0

// Sideband group
//`define control_wdth 0
//`define mflag_wdth 0
//`define sflag_wdth 0

// Test group
//`define scanctrl_wdth 0
//`define scanport_wdth 0
/*}}}*/

`define fifo_wdth (`data_wdth * 8)

module ocp_master_fsm(
  // Bridge interface/*{{{*/
  input wire [`addr_wdth - 1:0]         address,
  input wire                            enable,
  input wire [2:0]                      burst_seq,
  input wire                            burst_single_req, // NOT IMPLEMENTED
  input wire [9:0]                      burst_length,
  input wire                            data_valid,
  input wire                            read_request,
  input wire                            reset,
  input wire                            sys_clk,
  input wire [`data_wdth - 1:0]         valid_bytes,
  input wire [`data_wdth - 1:0]         write_data,   // Coming from PCIe side
  input wire                            write_request,
  input wire                            writeresp_enable, // NOT IMPLEMENTED

  // AXI FIFO outputs
  output reg s_aclk,
  output reg s_axis_tvalid,
  input wire s_axis_tready,
  output reg [`fifo_wdth - 1:0] s_axis_tdata,
  output reg [`data_wdth - 1:0] s_axis_tkeep,
  output reg s_axis_tlast,
  input wire axis_overflow,
  /*}}}*/

  // OCP 2.2 interface/*{{{*/
  
  // Basic group
  output wire                           Clk,
  inout wire                            EnableClk,
  output reg [`addr_wdth - 1:0]         MAddr,
  output reg [2:0]                      MCmd,
  output reg [`data_wdth - 1:0]         MData,
  output reg                            MDataValid,
  output reg                            MRespAccept,
  input wire                            SCmdAccept,
  input wire [`data_wdth - 1:0]         SData,
  input wire                            SDataAccept,
  input wire [1:0]                      SResp,

  // Simple group
  output reg [`addrspace_wdth - 1:0]    MAddrSpace,
  output reg [`data_wdth - 1:0]         MByteEn,
  output reg [`data_wdth - 1:0]         MDataByteEn,
  output reg [`mdatainfo_wdth - 1:0]    MDataInfo,
  output reg [`reqinfo_wdth - 1:0]      MReqInfo,
  input wire [`sdatainfo_wdth - 1:0]    SDataInfo,
  input wire [`respinfo_wdth - 1:0]     SRespInfo,

  // Burst group
  output reg [`atomiclength_wdth - 1:0] MAtomicLength,
  output reg [`blockheight_wdth - 1:0]  MBlockHeight,
  output reg [`blockstride_wdth - 1:0]  MBlockStride,
  output reg [`burstlength_wdth - 1:0]  MBurstLength,
  output reg                            MBurstPrecise,
  output reg [2:0]                      MBurstSeq,
  output reg                            MBurstSingleSeq,
  output reg                            MDataLast,
  output reg                            MDataRowLast,
  output reg                            MReqLast,
  output reg                            MReqRowLast,
  input wire                            SRespLast,
  input wire                            SRespRowLast,

  // Tag group
  output reg [`tags - 1:0]              MDataTagID,
  output reg [`tags - 1:0]              MTagID,
  output reg                            MTagInOrder,
  input wire [`tags - 1:0]              STagID,
  input wire                            STagInOrder,
  
  // Thread group
  output reg [`connid_width - 1:0]      MConnID,
  output reg [`threads - 1:0]           MDataThreadID,
  output reg [`threads - 1:0]           MThreadBusy,
  output reg [`threads - 1:0]           MThreadID,
  input wire [`threads - 1:0]           SDataThreadBusy,
  input wire [`threads - 1:0]           SThreadBusy,
  input wire [`threads - 1:0]           SThreadID
  
  // Sideband group
  //output reg                            ConnectCap,
  //output reg [`control_wdth - 1:0]      Control,
  //output reg                            ControlBusy,
  //output reg [1:0]                      ControlWr,
  //output reg [1:0]                      MConnect,
  //output reg                            MError,
  //output reg [`mflag_wdth - 1:0]        MFlag,
  //output reg                            MReset_n,
  //input wire                            SConnect,
  //input wire                            SError,
  //input wire [`threads - 1:0]           SFlag,
  //input wire                            SInterrupt,
  //input wire                            SReset_n,
  //output reg [`threads - 1:0]           Status,
  //output reg                            StatusBusy,
  //output reg                            StatusRd,
  //input wire                            SWait,
  
  // Test group
  //output reg                            ClkByp,
  //output reg [`scanctrl_wdth - 1:0]     Scanctrl,
  //output reg [`scanport_wdth - 1:0]     Scanin,
  //output reg [`scanport_wdth - 1:0]     Scanout,
  //output reg                            TCK,
  //output reg                            TDI,
  //output reg                            TDO,
  //output reg                            TestClk,
  //output reg                            TMS,
  //output reg                            TRST_N
  /*}}}*/
);

// Declarations/*{{{*/

// OCP 2.2 Encodings/*{{{*/

// MCmd encoding
localparam IDLE  = 3'b000;
localparam WR    = 3'b001;
localparam RD    = 3'b010;
localparam RDEX  = 3'b011;
localparam RDL   = 3'b100;
localparam WRNP  = 3'b101;
localparam WRC   = 3'b110;
localparam BCST  = 3'b111;

// SResp encoding
localparam NULL  = 2'b00;
localparam DVA   = 2'b01;
localparam FAIL  = 2'b10;
localparam ERR   = 2'b11;

// MBurstSeq encoding
localparam INCR  = 3'b000;   // Incrementing
localparam DFLT1 = 3'b001;   // Custom (packed)
localparam WRAP  = 3'b010;   // Wrapping
localparam DFLT2 = 3'b011;   // Custom (not packed)
localparam XOR   = 3'b100;   // Exclusive OR
localparam STRM  = 3'b101;   // Streaming
localparam UNKN  = 3'b110;   // Unknown
localparam BLCK  = 3'b111;   // 2-dimensional Block

// MConnect encoding (master connection state)
//parameter M_OFF   = 2'b00;  // Not connected
//parameter M_WAIT  = 2'b01;  // Matches prior state
//parameter M_DISC  = 2'b10;  // Not connected
//parameter M_CON   = 2'b11;  // Connected

// SConnect encoding (slave connection vote)
//parameter S_DISC  = 1'b0;   // Vote to disconnect
//parameter S_CON   = 1'b1;   // Vote to connect

// SWait encoding (slave connection change delay)
//parameter S_OK    = 1'b0;   // Allow connection status change
//parameter S_WAIT  = 1'b0;   // Delay connection status change

// MReset_n signal
//parameter MRESET_ACTIVE   = 1'b0;
//parameter MRESET_INACTIVE = 1'b1;

// SReset_n signal
//parameter SRESET_ACTIVE   = 1'b0;
//parameter SRESET_INACTIVE = 1'b1;
/*}}}*/

reg [3:0] state;
reg [3:0] next;

reg [9:0] burst_count;  // For incrementing (INCR) type burst sequences
assign EnableClk = enable;
assign Clk = sys_clk & enable;
/*}}}*/

// State transition logic/*{{{*/
always @(posedge Clk) begin
  if (EnableClk) begin
    if (reset) begin
      state <= 3'b0;
      state[IDLE] <= 1'b1;
    end

    else begin
      state <= next;
    end
  end

  else begin
    state <= state;
  end
end
/*}}}*/

// Next state logic/*{{{*/
always @(state or read_request or write_request or MReqLast or SCmdAccept or SResp or SData or s_axis_tready) begin
//always @(*) begin
  next <= 3'b0;

  // Handle slave response/*{{{*/
  case (SResp)
    // No response
    NULL: begin
      s_aclk <= Clk;
      s_axis_tvalid <= 1'b1;
      
      // Ignore s_axis_tready
      s_axis_tdata <= {`fifo_wdth{1'bx}};
      s_axis_tkeep <= {`data_wdth{1'b0}};
    end

    // Data valid / accept
    DVA: begin
      s_aclk <= Clk;
      s_axis_tvalid <= 1'b1;
      
      // Wait for ready
      if (s_axis_tready) begin
        s_axis_tdata <= SData;
        s_axis_tkeep <= {`data_wdth{1'b1}};
      end

      else begin
        s_axis_tdata <= {`fifo_wdth{1'bx}};
        s_axis_tkeep <= {`data_wdth{1'b0}};
      end
    end

    // Request failed
    FAIL: begin
      s_aclk <= Clk;
      s_axis_tvalid <= 1'b1;

      // Wait for ready
      if (s_axis_tready) begin
        s_axis_tdata <= SData;
        s_axis_tkeep <= {`data_wdth{1'b1}};
      end

      else begin
        s_axis_tdata <= {`fifo_wdth{1'bx}};
        s_axis_tkeep <= {`data_wdth{1'b0}};
      end
    end

    // Response error
    ERR: begin
      s_aclk <= 1'b0;
      s_axis_tvalid <= 1'b0;

      // Ignore s_axis_tready
      s_axis_tdata <= {`fifo_wdth{1'bx}};
      s_axis_tkeep <= {`data_wdth{1'b0}};
    end

    default: begin
      s_aclk <= Clk;
      s_axis_tvalid <= 1'b1;

      // Ignore s_axis_tready
      s_axis_tdata <= {`fifo_wdth{1'bx}};
      s_axis_tkeep <= {`data_wdth{1'b1}};
    end
  endcase
/*}}}*/

  // Handle read or write requests/*{{{*/
  case (1'b1)
    state[IDLE]: begin
      case (1'b1)
        read_request: begin
          next[RD] <= 1'b1;
        end

        write_request: begin
          next[WR] <= 1'b1;
        end

        default: begin
          next[IDLE] <= 1'b1;
        end
      endcase
    end

    // Wait for SCmdAccept to be set
    state[WR]: begin
      if (SCmdAccept & MReqLast) begin
        next[IDLE] <= 1'b1;
      end

      else begin
        next[WR] <= 1'b1;
      end
    end

    // Wait for SCmdAccept to be set
    state[RD]: begin
      if (SCmdAccept & MReqLast) begin
        next[IDLE] <= 1'b1;
      end

      else begin
        next[RD] <= 1'b1;
      end
    end

    default: begin
      next[IDLE] <= 1'b1;
    end
  endcase
  /*}}}*/
end
/*}}}*/

// Output logic/*{{{*/
always @(posedge Clk) begin
  // Reset/*{{{*/
  if (reset) begin
    burst_count <= `burstlength_wdth'b0;

    // OCP 2.2 Interface

    // Basic group
    MAddr             <= {`addr_wdth{1'bx}};
    MCmd              <= IDLE;
    MData             <= {`data_wdth{1'bx}};
    MDataValid        <= 1'bx;
    //MRespAccept       <= 1'b1;
    MRespAccept       <= s_axis_tready;

    // Simple group
    MAddrSpace        <= {`addrspace_wdth{1'b1}};
    MByteEn           <= {`data_wdth{1'b1}};
    MDataByteEn       <= {`data_wdth{1'b1}};
    MDataInfo         <= 1'b0;
    MReqInfo          <= 1'b0;

    // Burst group
    MAtomicLength     <= 1'b1;
    MBlockHeight      <= 1'b1;
    MBlockStride      <= 1'b0;
    MBurstLength      <= 1'b1;
    MBurstPrecise     <= 1'b1;
    MBurstSeq         <= INCR;
    MBurstSingleSeq   <= 1'b0;
    MDataLast         <= 1'bx;
    MDataRowLast      <= 1'bx;
    MReqLast          <= 1'bx;
    MReqRowLast       <= 1'bx;

    // Tag group
    MDataTagID        <= 1'b0;
    MTagID            <= 1'b0;
    MTagInOrder       <= 1'b0;

    // Thread group
    MConnID           <= 1'b0;
    MDataThreadID     <= 1'b0;
    MThreadBusy       <= 1'b0;
    MThreadID         <= 1'b0;

    // Sideband group
    //ConnectCap        <= 1'bx;
    //Control           <= 1'b0;
    //ControlBusy       <= 1'b0;
    //ControlWr         <= 1'bx;
    //MConnect          <= M_CON;
    //MError            <= 1'b0;
    //MFlag             <= 1'b0;
    //MReset_n          <= 1'b1;
    //Status            <= 1'b0;
    //StatusBusy        <= 1'b0;
    //StatusRd          <= 1'bx;

    // Test group
    //ClkByp            <= 1'bx;
    //Scanctrl          <= 1'bx;
    //Scanin            <= 1'bx;
    //Scanout           <= 1'bx;
    //TCK               <= 1'bx;
    //TDI               <= 1'bx;
    //TDO               <= 1'bx;
    //TestClk           <= 1'bx;
    //TMS               <= 1'bx;
    //TRST_N            <= 1'bx;
  end
  /*}}}*/

  else begin
    MCmd <= IDLE;

    // Handle Master outputs/*{{{*/
    case (1'b1)
      // IDLE/*{{{*/
      next[IDLE]: begin
        burst_count <= `burstlength_wdth'b0;

        // OCP 2.2 Interface

        // Basic group
        MAddr             <= {`addr_wdth{1'b0}};
        MCmd              <= IDLE;
        MData             <= {`data_wdth{1'b0}};
        MDataValid        <= 1'bx;
        //MRespAccept       <= 1'b1;
        MRespAccept       <= s_axis_tready;

        // Simple group
        MAddrSpace        <= {`addrspace_wdth{1'b0}};
        MByteEn           <= {`data_wdth{1'b1}};
        MDataByteEn       <= {`data_wdth{1'b1}};
        MDataInfo         <= 1'b0;
        MReqInfo          <= 1'b0;

        // Burst group
        MAtomicLength     <= 1'b1;
        MBlockHeight      <= 1'b1;
        MBlockStride      <= 1'b0;
        MBurstLength      <= burst_length;
        MBurstPrecise     <= 1'b1;
        MBurstSeq         <= INCR;
        MBurstSingleSeq   <= 1'b0;
        MDataLast         <= 1'bx;
        MDataRowLast      <= 1'bx;
        MReqLast          <= 1'bx;
        MReqRowLast       <= 1'bx;

        // Tag group
        MDataTagID        <= 1'b0;
        MTagID            <= 1'b0;
        MTagInOrder       <= 1'b0;

        // Thread group
        MConnID           <= 1'b0;
        MDataThreadID     <= 1'b0;
        MThreadBusy       <= 1'b0;
        MThreadID         <= 1'b0;

        // Sideband group
        //ConnectCap        <= 1'bx;
        //Control           <= 1'b0;
        //ControlBusy       <= 1'b0;
        //ControlWr         <= 1'bx;
        //MConnect          <= M_CON;
        //MError            <= 1'b0;
        //MFlag             <= 1'b0;
        //MReset_n          <= 1'b1;
        //Status            <= 1'b0;
        //StatusBusy        <= 1'b0;
        //StatusRd          <= 1'bx;

        // Test group
        //ClkByp            <= 1'bx;
        //Scanctrl          <= 1'bx;
        //Scanin            <= 1'bx;
        //Scanout           <= 1'bx;
        //TCK               <= 1'bx;
        //TDI               <= 1'bx;
        //TDO               <= 1'bx;
        //TestClk           <= 1'bx;
        //TMS               <= 1'bx;
        //TRST_N            <= 1'bx;
      end
      /*}}}*/

      // WRITE/*{{{*/
      next[WR]: begin
        burst_count <= (SCmdAccept & (burst_count < burst_length)) ? burst_count + 1'b1 : burst_count;

        // OCP 2.2 Interface

        // Basic group
        MAddr             <= address;
        MCmd              <= WR;
        MData             <= write_data;
        MDataValid        <= 1'bx;
        //MRespAccept       <= 1'b1;
        MRespAccept       <= s_axis_tready;

        // Simple group
        MAddrSpace        <= {`addrspace_wdth{1'b0}};
        //MByteEn           <= {`data_wdth{1'b1}};
        MByteEn           <= valid_bytes;
        MDataByteEn       <= {`data_wdth{1'b1}};
        MDataInfo         <= 1'b0;
        MReqInfo          <= 1'b0;

        // Burst group
        MAtomicLength     <= 1'b1;
        MBlockHeight      <= 1'b1;
        //MBlockHeight      <= (burst_seq == BLCK) ? <row_length> : 1'b1;
        MBlockStride      <= 1'b0;
        MBurstLength      <= burst_length;
        MBurstPrecise     <= 1'b1;
        MBurstSeq         <= burst_seq;
        //MBurstSingleSeq   <= burst_single_req;
        MBurstSingleSeq   <= 1'b0;
        MDataLast         <= 1'bx;
        MDataRowLast      <= 1'bx;
        //MReqLast          <= (burst_count == (burst_length - 1'b1)) ? 1'b1 : 1'b0;
        MReqLast          <= (burst_count == (burst_length - 1'b1)) | burst_single_req;
        MReqRowLast       <= 1'bx;

        // Tag group
        MDataTagID        <= 1'b0;
        MTagID            <= 1'b0;
        MTagInOrder       <= 1'b0;

        // Thread group
        MConnID           <= 1'b0;
        MDataThreadID     <= 1'b0;
        MThreadBusy       <= 1'b0;  // SET THIS ACCORDING TO FIFO READY
        MThreadID         <= 1'b0;

        // Sideband group
        //ConnectCap        <= 1'bx;
        //Control           <= 1'b0;
        //ControlBusy       <= 1'b0;
        //ControlWr         <= 1'bx;
        //MConnect          <= M_CON;
        //MError            <= 1'b0;
        //MFlag             <= 1'b0;
        //MReset_n          <= 1'b1;
        //Status            <= 1'b0;
        //StatusBusy        <= 1'b0;
        //StatusRd          <= 1'bx;

        // Test group
        //ClkByp            <= 1'bx;
        //Scanctrl          <= 1'bx;
        //Scanin            <= 1'bx;
        //Scanout           <= 1'bx;
        //TCK               <= 1'bx;
        //TDI               <= 1'bx;
        //TDO               <= 1'bx;
        //TestClk           <= 1'bx;
        //TMS               <= 1'bx;
        //TRST_N            <= 1'bx;
      end
      /*}}}*/

      // READ/*{{{*/
      next[RD]: begin
        burst_count <= (SCmdAccept & (burst_count < burst_length)) ? burst_count + 1'b1 : burst_count;

        // OCP 2.2 Interface

        // Basic group
        MAddr             <= address;
        MCmd              <= RD;
        MData             <= {`data_wdth{1'b0}};
        MDataValid        <= 1'bx;
        //MRespAccept       <= 1'b1;
        MRespAccept       <= s_axis_tready;

        // Simple group
        MAddrSpace        <= {`addrspace_wdth{1'b0}};
        //MByteEn           <= {`data_wdth{1'b1}};
        MByteEn           <= valid_bytes;
        MDataByteEn       <= write_request ? valid_bytes : {`data_wdth{1'b1}};
        MDataInfo         <= 1'b0;
        MReqInfo          <= 1'b0;

        // Burst group
        MAtomicLength     <= 1'b1;
        MBlockHeight      <= 1'b1;
        //MBlockHeight      <= (burst_seq == BLCK) ? <row_length> : 1'b1;
        MBlockStride      <= 1'b0;
        //MBlockStride      <= (burst_sq == BLCK) ? <diff between rows> : 1'b0;
        MBurstLength      <= burst_length;
        MBurstPrecise     <= 1'b1;
        MBurstSeq         <= burst_seq;
        //MBurstSingleSeq   <= burst_single_req;
        MBurstSingleSeq   <= 1'b0;
        MDataLast         <= 1'bx;
        MDataRowLast      <= 1'bx;
        MReqLast          <= (burst_count == (burst_length - 1'b1)) | burst_single_req;
        MReqRowLast       <= 1'bx;

        // Tag group
        MDataTagID        <= 1'b0;
        MTagID            <= 1'b0;
        MTagInOrder       <= 1'b0;

        // Thread group
        MConnID           <= 1'b0;
        MDataThreadID     <= 1'b0;
        MThreadBusy       <= 1'b0;  // SET THIS ACCORDING TO FIFO READY
        MThreadID         <= 1'b0;

        // Sideband group
        //ConnectCap        <= 1'bx;
        //Control           <= 1'b0;
        //ControlBusy       <= 1'b0;
        //ControlWr         <= 1'bx;
        //MConnect          <= M_CON;
        //MError            <= 1'b0;
        //MFlag             <= 1'b0;
        //MReset_n          <= 1'b1;
        //Status            <= 1'b0;
        //StatusBusy        <= 1'b0;
        //StatusRd          <= 1'bx;

        // Test group
        //ClkByp            <= 1'bx;
        //Scanctrl          <= 1'bx;
        //Scanin            <= 1'bx;
        //Scanout           <= 1'bx;
        //TCK               <= 1'bx;
        //TDI               <= 1'bx;
        //TDO               <= 1'bx;
        //TestClk           <= 1'bx;
        //TMS               <= 1'bx;
        //TRST_N            <= 1'bx;
      end
      /*}}}*/

      // DEFAULT CASE (RESET)/*{{{*/
      default: begin
        burst_count <= `burstlength_wdth'b0;

        // OCP 2.2 Interface

        // Basic group
        MAddr             <= {`addr_wdth{1'b0}};
        MCmd              <= IDLE;
        MData             <= {`data_wdth{1'b0}};
        MDataValid        <= 1'bx;
        //MRespAccept       <= 1'b1;
        MRespAccept       <= s_axis_tready;

        // Simple group
        MAddrSpace        <= {`addrspace_wdth{1'b0}};
        MByteEn           <= {`data_wdth{1'b1}};
        MDataByteEn       <= {`data_wdth{1'b1}};
        MDataInfo         <= 1'b0;
        MReqInfo          <= 1'b0;

        // Burst group
        MAtomicLength     <= 1'b1;
        MBlockHeight      <= 1'b1;
        MBlockStride      <= 1'b0;
        MBurstLength      <= 1'b1;
        MBurstPrecise     <= 1'b1;
        MBurstSeq         <= INCR;
        MBurstSingleSeq   <= 1'b0;
        MDataLast         <= 1'bx;
        MDataRowLast      <= 1'bx;
        MReqLast          <= 1'bx;
        MReqRowLast       <= 1'bx;

        // Tag group
        MDataTagID        <= 1'b0;
        MTagID            <= 1'b0;
        MTagInOrder       <= 1'b0;

        // Thread group
        MConnID           <= 1'b0;
        MDataThreadID     <= 1'b0;
        MThreadBusy       <= 1'b0;
        MThreadID         <= 1'b0;

        // Sideband group
        //ConnectCap        <= 1'bx;
        //Control           <= 1'b0;
        //ControlBusy       <= 1'b0;
        //ControlWr         <= 1'bx;
        //MConnect          <= M_CON;
        //MError            <= 1'b0;
        //MFlag             <= 1'b0;
        //MReset_n          <= 1'b1;
        //Status            <= 1'b0;
        //StatusBusy        <= 1'b0;
        //StatusRd          <= 1'bx;

        // Test group
        //ClkByp            <= 1'bx;
        //Scanctrl          <= 1'bx;
        //Scanin            <= 1'bx;
        //Scanout           <= 1'bx;
        //TCK               <= 1'bx;
        //TDI               <= 1'bx;
        //TDO               <= 1'bx;
        //TestClk           <= 1'bx;
        //TMS               <= 1'bx;
        //TRST_N            <= 1'bx;
      end
      /*}}}*/
    endcase
    /*}}}*/
  end
end
/*}}}*/
endmodule
