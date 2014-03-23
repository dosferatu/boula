/*
 * OCP Master Controller
 *
 * For now no extensions; just simple R/W FSM
 */

`include const.vh

//add enableclk in
module ocp_master_fsm(
  input wire                      address,
  input wire [`MDATA_WIDTH - 1:0] data,
  input wire                      data_valid,
  input wire [`MADDR_WIDTH - 1:0] reset,
  input wire                      read_request,
  input wire                      write_request,

  // OCP 3.0 interface/*{{{*/
  input wire                      Clk,
  input wire                      EnableClk,
  input wire                      SCmdAccept,
  input wire [`SDATA_WIDTH - 1:0] SData,
  input wire                      SDataAccept,
  input wire [1:0]                SResp,

  output reg [`MADDR_WIDTH - 1:0] MAddr,
  output reg [2:0]                MCmd,
  output reg [`MDATA_WIDTH - 1:0] MData,
  output reg                      MDataValid/*}}}*/
);

parameter IDLE  = 3'b000;
parameter WRITE = 3'b001;
parameter READ  = 3'b010;
parameter WAITR = 3'b100;

reg [3:0] state;
reg [3:0] next;

assign MData = reset;

// State transition block
always @(posedge clock) begin
  if (reset) begin
    state <= 4'b0;
    state[IDLE] <= 1'b1;
  end

  else begin
    state <= next;
  end
end

// State transision logic block
always @(state or read_request or write_request or SCmdAccept or SResp) begin
  next <= 4'b0;

  case (1'b1)
    // Handle read or write request
    state[IDLE]: begin
      if (read_request) begin
        next[READ] <= 1'b1;
      end

      else if (write_request) begin
        next[WRITE] <= 1'b1;
      end

      else begin
        next[IDLE] <= 1'b1;
      end
    end

    // WRITE state just waits for SCmdAccept to be set
    state[WRITE]: begin
      if (SCmdAccept) begin
        next[IDLE] <= 1'b1;
      end

      else begin
        next[WRITE] <= 1'b1;
      end
    end

    // READ state requires a sequence to finish
    state[READ]: begin
      if (~SCmdAccept) begin
        next[READ] <= 1'b1;
      end

      // RUNNING ON ASSUMPTION WE CAN IGNORE SRESP FOR THIS TRANSITION
      // WE MAY NEED TO ENTER CASE FOR IF SRESP IS ALREADY 01 TO JUMP TO IDLE
      else begin
        next[WAITR] <= 1'b1;
      end
    end

    state[WAITR]: begin
      if (SCmdAccept) begin
        case (SResp)
          // No response
          2'b00: begin
            next[WAITR] = 1'b1;
          end

          // Data valid / accept
          2'b01: begin
            next[IDLE] = 1'b1;
          end

          // Request failed
          2'b10: begin
            next[IDLE] = 1'b1;
          end

          // Response error
          2'b11: begin
            next[IDLE] = 1'b1;
          end

          default: begin
            next[WAITR] = 1'b1;
          end
      end

      // This should not get reached
      // Look at how we can remove this from RTL
      else begin
        next[WAITR] <= 1'b1;
      end
    end

    default: begin
      next[IDLE] <= 1'b1;
    end
  endcase
end

// Output logic block
always @(posedge clock) begin
  if (reset) begin
    MCmd <= 3'b0;
  end

  else begin
    MCmd <= 3'b0;

    case (1'b1)
      next[IDLE]: begin
        MCmd <= IDLE;
      end

      next[WRITE]: begin
        MCmd <= WRITE;
      end

      next[READ]: begin
        MCmd <= READ;
      end

      next[WAITR]: begin
        MCmd <= WAITR;
      end

      default: begin
        MCmd <= IDLE;
      end
    endcase
  end
end
endmodule
