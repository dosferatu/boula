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
*/ 
//`include "const.vh"
`define MDATA_WIDTH 8
`define SDATA_WIDTH 8
`define MADDR_WIDTH 64

module ocp_master_fsm(
  // Bridge interface/*{{{*/
  input wire [`MADDR_WIDTH - 1:0] address,
  //input wire                      data_valid,
  input wire                      read_request,
  input wire                      reset,
  input wire [`MDATA_WIDTH - 1:0] write_data,   // Coming from PCIe side
  input wire                      write_request,

  output reg [`SDATA_WIDTH - 1:0] read_data,    // Coming from OCP bus
  /*}}}*/

  // OCP 3.0 interface/*{{{*/
  input wire                      Clk,
  input wire                      EnableClk,
  input wire                      SCmdAccept,
  input wire [`SDATA_WIDTH - 1:0] SData,
  //input wire                      SDataAccept,
  input wire [1:0]                SResp,

  output reg [`MADDR_WIDTH - 1:0] MAddr,
  output reg [2:0]                MCmd,
  output reg [`MDATA_WIDTH - 1:0] MData
  //output reg                      MDataValid
  /*}}}*/
);

// Declarations/*{{{*/

// MCmd states
parameter IDLE  = 3'b000;
parameter WR    = 3'b001;
parameter RD    = 3'b010;
parameter RDEX  = 3'b011;
parameter RDL   = 3'b100;
parameter WRNP  = 3'b101;
parameter WRC   = 3'b110;
parameter BCST  = 3'b111;

// SResp states
parameter NULL  = 2'b00;
parameter DVA   = 2'b01;
parameter FAIL  = 2'b10;
parameter ERR   = 2'b11;

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
      read_data <= `SDATA_WIDTH'bx;
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
      read_data <= `SDATA_WIDTH'bx;
    end

    default: begin
      read_data <= `SDATA_WIDTH'bx;
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
    MAddr <= `MADDR_WIDTH'bx;
    MCmd <= IDLE;
    MData <= `MDATA_WIDTH'bx;
  end

  else begin
    MCmd <= IDLE;

    // Handle Master outputs/*{{{*/
    case (1'b1)
      next[IDLE]: begin
        MAddr <= `MADDR_WIDTH'bx;
        MCmd <= IDLE;
        MData <= `MDATA_WIDTH'bx;
      end

      next[WR]: begin
        MAddr <= address;
        MCmd <= WR;
        MData <= write_data;
      end

      next[RD]: begin
        MAddr <= address;
        MCmd <= RD;
        MData <= `MDATA_WIDTH'bx;
      end

      default: begin
        MAddr <= `MADDR_WIDTH'bx;
        MCmd <= IDLE;
        MData <= `MDATA_WIDTH'bx;
      end
    endcase
    /*}}}*/
  end
end
/*}}}*/
endmodule
