/*
 * OCP Master Controller
 *
 * For now no extensions; just simple R/W FSM
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
* ***IF MRespAccept NOT CONFIGURED THEN ASSUMED TO BE 1 AND RESPONSE PHASE IS
* 1 CYCLE LONG
*
* datahandshake phase ends when SDataAccept is sampled as high
*
* Tie off values can be found in reset logic section of the output FSM block
*/ 
`include "counter.v"

// OCP 3.0 interface/*{{{*/

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
`define burstlength_wdth 8
`define blockheight_wdth 8
`define blockstride_wdth 8

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

module ocp_master_fsm(
  // Bridge interface/*{{{*/
  input wire [`addr_wdth - 1:0]         address,
  input wire                            burst_mode,
  input wire [9:0]                      burst_length,
  input wire                            data_valid,
  input wire                            read_request,
  input wire                            reset,
  input wire [`data_wdth - 1:0]         write_data,   // Coming from PCIe side
  input wire                            write_request,

  output reg [`data_wdth - 1:0]         read_data,    // Coming from OCP bus
  /*}}}*/


  // OCP 3.0 interface/*{{{*/
  
  // Basic group
  input wire                            Clk,
  input wire                            EnableClk,
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
  //output reg [`addrspace_wdth - 1:0]    MAddrSpace,
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
  input wire                            SRespRowLast

  // Tag group
  //output reg [`tags - 1:0]              MDataTagID,
  //output reg [`tags - 1:0]              MTagID,
  //output reg                            MTagInOrder,
  //input wire [`tags - 1:0]              STagID,
  //input wire                            STagInOrder,
  
  // Thread group
  //output reg [`connid_width - 1:0]      MConnID,
  //output reg [`threads - 1:0]           MDataThreadID,
  //output reg [`threads - 1:0]           MThreadBusy,
  //output reg [`threads - 1:0]           MThreadID,
  //input wire [`threads - 1:0]           SDataThreadBusy,
  //input wire [`threads - 1:0]           SThreadBusy,
  //input wire [`threads - 1:0]           SThreadID,
  
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

// OCP 3.0 Encodings/*{{{*/

// MCmd encoding
parameter IDLE  = 3'b000;
parameter WR    = 3'b001;
parameter RD    = 3'b010;
parameter RDEX  = 3'b011;
parameter RDL   = 3'b100;
parameter WRNP  = 3'b101;
parameter WRC   = 3'b110;
parameter BCST  = 3'b111;

// SResp encoding
parameter NULL  = 2'b00;
parameter DVA   = 2'b01;
parameter FAIL  = 2'b10;
parameter ERR   = 2'b11;

// MBurstSeq encoding
parameter INCR  = 3'b000;   // Incrementing
parameter DFLT1 = 3'b001;   // Custom (packed)
parameter WRAP  = 3'b010;   // Wrapping
parameter DFLT2 = 3'b011;   // Custom (not packed)
parameter XOR   = 3'b100;   // Exclusive OR
parameter STRM  = 3'b101;   // Streaming
parameter UNKN  = 3'b110;   // Unknown
parameter BLCK  = 3'b111;   // 2-dimensional Block

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

reg [2:0] state;
reg [2:0] next;
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
always @(state or read_request or write_request or SCmdAccept or SResp or SData) begin
  next <= 3'b0;

  // Handle slave response/*{{{*/
  case (SResp)
    // No response
    NULL: begin
      read_data <= {`data_wdth{1'bx}};
    end

    // Data valid / accept
    DVA: begin
      read_data <= SData;
    end

    // Request failed
    FAIL: begin
      read_data <= SData;
    end

    // Response error
    ERR: begin
      read_data <= {`data_wdth{1'bx}};
    end

    default: begin
      read_data <= {`data_wdth{1'bx}};
    end
  endcase
/*}}}*/

  // Handle read or write requests/*{{{*/
  case (1'b1)
    /*
     * Handle read or write request
     *
     * This is the request phase. This means that all signals
     * included in this group that we are using must be active
     * during this phase.
     */
    state[IDLE]: begin
      if (read_request) begin
        next[RD] <= 1'b1;
      end

      else if (write_request) begin
        next[WR] <= 1'b1;
      end

      else begin
        next[IDLE] <= 1'b1;
      end
    end

    // Wait for SCmdAccept to be set
    state[WR]: begin
      if (SCmdAccept) begin
        next[IDLE] <= 1'b1;
      end

      else begin
        next[WR] <= 1'b1;
      end
    end

    // Wait for SCmdAccept to be set
    state[RD]: begin
      if (SCmdAccept) begin
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
  if (reset) begin
    // Basic group
    MAddr             <= {`addr_wdth{1'bx}};
    MCmd              <= IDLE;
    MData             <= {`data_wdth{1'bx}};
    MDataValid        <= 1'bx;
    MRespAccept       <= 1'b1;

    // Simple group
    //MAddrSpace        <= {`addrspace_wdth{1'b1}};
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
    //MDataTagID        <= 1'b0;
    //MTagID            <= 1'b0;
    //MTagInOrder       <= 1'b0;
    
    // Thread group
    //MConnID           <= 1'b0;
    //MDataThreadID     <= 1'b0;
    //MThreadBusy       <= 1'b0;
    //MThreadID         <= 1'b0;
    
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

  else begin
    MCmd <= IDLE;

    // Handle Master outputs/*{{{*/
    case (1'b1)
      next[IDLE]: begin
        // Basic group
        MAddr             <= {`addr_wdth{1'b0}};
        MCmd              <= IDLE;
        MData             <= {`data_wdth{1'b0}};
        MDataValid        <= 1'bx;
        MRespAccept       <= 1'b1;

        // Simple group
        //MAddrSpace        <= {`addrspace_wdth{1'b0}};
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
        //MDataTagID        <= 1'b0;
        //MTagID            <= 1'b0;
        //MTagInOrder       <= 1'b0;

        // Thread group
        //MConnID           <= 1'b0;
        //MDataThreadID     <= 1'b0;
        //MThreadBusy       <= 1'b0;
        //MThreadID         <= 1'b0;

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

      next[WR]: begin
        // Basic group
        MAddr             <= address;
        MCmd              <= WR;
        MData             <= write_data;
        MDataValid        <= 1'bx;
        MRespAccept       <= 1'b1;

        // Simple group
        //MAddrSpace        <= {`addrspace_wdth{1'b0}};
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
        //MDataTagID        <= 1'b0;
        //MTagID            <= 1'b0;
        //MTagInOrder       <= 1'b0;

        // Thread group
        //MConnID           <= 1'b0;
        //MDataThreadID     <= 1'b0;
        //MThreadBusy       <= 1'b0;
        //MThreadID         <= 1'b0;

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

      next[RD]: begin
        // Basic group
        MAddr             <= address;
        MCmd              <= RD;
        MData             <= {`data_wdth{1'b0}};
        MDataValid        <= 1'bx;
        MRespAccept       <= 1'b1;

        // Simple group
        //MAddrSpace        <= {`addrspace_wdth{1'b0}};
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
        //MDataTagID        <= 1'b0;
        //MTagID            <= 1'b0;
        //MTagInOrder       <= 1'b0;

        // Thread group
        //MConnID           <= 1'b0;
        //MDataThreadID     <= 1'b0;
        //MThreadBusy       <= 1'b0;
        //MThreadID         <= 1'b0;

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

      default: begin
        // Basic group
        MAddr             <= {`addr_wdth{1'b0}};
        MCmd              <= IDLE;
        MData             <= {`data_wdth{1'b0}};
        MDataValid        <= 1'bx;
        MRespAccept       <= 1'b1;

        // Simple group
        //MAddrSpace        <= {`addrspace_wdth{1'b0}};
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
        //MDataTagID        <= 1'b0;
        //MTagID            <= 1'b0;
        //MTagInOrder       <= 1'b0;

        // Thread group
        //MConnID           <= 1'b0;
        //MDataThreadID     <= 1'b0;
        //MThreadBusy       <= 1'b0;
        //MThreadID         <= 1'b0;

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
    endcase
    /*}}}*/
  end
end
/*}}}*/
endmodule
