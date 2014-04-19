`include "../gen/FIFO.v"

/*
 * AXI to OCP translation block
 * Author: Michael Walton
 *
 * This module translates the PCIe TLP header in to a valid
 * OCP transaction request.
 *
 */

/*
 * DESIGN NOTES:
 * message requests use a sub-field to specify the message routing mechanism
 *
 * combinational logic is going to be used to translate the bridge to avoid
 * extra clocks being introduced in to the pipeline
 */

module axi2ocp(
  input wire clk
  // AXI FIFO/*{{{*/
  //.s_aclk(s_aclk), // input s_aclk
  //.s_aresetn(s_aresetn), // input s_aresetn
  //.s_axis_tvalid(s_axis_tvalid), // input s_axis_tvalid
  //.s_axis_tready(s_axis_tready), // output s_axis_tready
  //.s_axis_tdata(s_axis_tdata), // input [63 : 0] s_axis_tdata
  //.s_axis_tkeep(s_axis_tkeep), // input [7 : 0] s_axis_tkeep
  //.s_axis_tlast(s_axis_tlast), // input s_axis_tlast
  //.axis_underflow(axis_underflow) // output axis_underflow
  /*}}}*/
  

  // OCP 2.2 Interface/*{{{*/
  //output reg [`addr_wdth - 1:0]         address,
  //output reg                            enable,
  //output reg [2:0]                      burst_seq,
  //output reg                            burst_single_req,
  //output reg [9:0]                      burst_length,
  //output reg                            data_valid,
  //output reg                            read_request,
  //output reg                            reset,
  //output reg                            sys_clk,
  //output reg [`data_wdth - 1:0]         write_data,   // Coming from PCIe side
  //output reg                            write_request,
  //output reg                            writeresp_enable,
  /*}}}*/

  // Header FIFO output/*{{{*/
  //.m_aclk(m_aclk), // input m_aclk
  //.m_axis_tvalid(m_axis_tvalid), // output m_axis_tvalid
  //.m_axis_tready(m_axis_tready), // input m_axis_tready
  //.m_axis_tdata(m_axis_tdata), // output [63 : 0] m_axis_tdata
  //.m_axis_tkeep(m_axis_tkeep), // output [7 : 0] m_axis_tkeep
  //.m_axis_tlast(m_axis_tlast), // output m_axis_tlast
  //.axis_overflow(axis_overflow), // output axis_overflow
  /*}}}*/
);

// Declarations/*{{{*/
/*}}}*/

// Perform combinatorial assignments here

// Work out the signals necessary for the FIFO to work with the bridge

// BEGIN FSM

//always @(state) begin
  //next <= 2'b0;
//end

// Output logic/*{{{*/
//always @(posedge clk) begin
  // Reset/*{{{*/
  //if (reset) begin
  //end

  //else begin
  //end
  /*}}}*/
/*}}}*/
endmodule
