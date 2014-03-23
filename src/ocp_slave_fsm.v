/*
 * OCP Slave Controller
 *
 * For now no extensions; just simple R/W FSM
 */

module ocp_slave_fsm(
  // Inputs
  input wire clock,
  input wire reset,
  input wire [2:0] MCmd,

  // Outputs
  output reg SCmdAccept,
  output reg [1:0] SResp,
);

reg [3:0] state;
reg [3:0] next;

// State transition block
always @(posedge clock) begin
end

// State transision logic block
always @(state or read_request or write_request or SCmdAccept or SResp) begin
  next <= 4'b0;
end

// Output logic block
always @(posedge clock) begin
  if (reset) begin
  end
end
endmodule
