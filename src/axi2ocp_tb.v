`include"axi2ocp.v"
/*
 * AXI to OCP translation block test bench
 * Author: Michael Walton
 *
 * This module validates the AXI to OCP translation block
 */

module axi2ocp_tb();
// Declarations/*{{{*/

// axi2ocp hookups
reg clk;
reg reset;

// AXI FIFO/*{{{*/
reg m_aclk;
wire s_aclk;
reg m_axis_tvalid;
wire m_axis_tready;
reg [`fifo_wdth - 1:0] m_axis_tdata;
reg [`data_wdth - 1:0] m_axis_tkeep;
reg m_axis_tlast;
wire s_axis_tvalid;
reg s_axis_tready;
wire [`fifo_wdth - 1:0] s_axis_tdata;
wire [`data_wdth - 1:0] s_axis_tkeep;
wire s_axis_tlast;
wire axis_overflow;
wire axis_underflow;
/*}}}*/

// OCP 2.2 Interface/*{{{*/
wire [`addr_wdth - 1:0]         address;
wire                            enable;
wire [2:0]                      burst_seq;
wire                            burst_single_req;
wire [9:0]                      burst_length;
wire                            data_valid;
wire                            read_request;
wire                            ocp_reset;
wire                            sys_clk;
wire [`data_wdth - 1:0]         write_data;
wire                            write_request;
wire                            writeresp_enable;
/*}}}*/
/*}}}*/

// AXI FIFO containing simulation data/*{{{*/
FIFO axi_rx_fifo (
  .m_aclk(m_aclk),
  .s_aclk(s_aclk),
  .s_aresetn(reset),
  .s_axis_tvalid(s_axis_tvalid),
  .s_axis_tready(s_axis_tready),
  .s_axis_tdata(s_axis_tdata),
  .s_axis_tkeep(s_axis_tkeep),
  .s_axis_tlast(s_axis_tlast),
  .m_axis_tvalid(m_axis_tvalid),
  .m_axis_tready(m_axis_tready),
  .m_axis_tdata(m_axis_tdata),
  .m_axis_tkeep(m_axis_tkeep),
  .m_axis_tlast(m_axis_tlast),
  .axis_overflow(axis_overflow),
  .axis_underflow(axis_underflow)
);/*}}}*/

axi2ocp U0(/*{{{*/
  .clk(clk),
  .reset(reset),
  
  // AXI FIFO/*{{{*/
  .m_aclk(m_aclk),
  .m_axis_tvalid(m_axis_tvalid),
  .m_axis_tready(m_axis_tready),
  .m_axis_tdata(m_axis_tdata),
  .m_axis_tkeep(m_axis_tkeep),
  .m_axis_tlast(m_axis_tlast),
  .axis_underflow(axis_underflow),
  /*}}}*/
  
  // OCP 2.2 Interface/*{{{*/
  .address(address),
  .enable(enable),
  .burst_seq(burst_seq),
  .burst_single_req(burst_single_req),
  .burst_length(burst_length),
  .data_valid(data_valid),
  .read_request(read_request),
  .ocp_reset(ocp_reset),
  .sys_clk(sys_clk),
  .write_data(write_data),
  .write_request(write_request),
  .writeresp_enable(writeresp_enable)
  /*}}}*/
);/*}}}*/

// Begin test stimuli/*{{{*/
initial begin
  clk               <= 0;
  reset             <= 1;

  // FIFO initialization
  m_aclk            <= 1'b0;
  m_axis_tvalid     <= 1'b0;
  m_axis_tdata      <= `fifo_wdth'bx;
  m_axis_tkeep      <= `data_wdth'bx;
  m_axis_tlast      <= 1'b0;
  //axis_underflow <= 1'b0;

  forever begin
    #10 clk         <= ~clk;
  end
end

initial begin
  // Simulate an idle queue/*{{{*/

  #20 reset         <= 0;

  // FIFO initialization
  m_aclk            <= 1'b0;
  m_axis_tvalid     <= 1'b0;
  m_axis_tdata      <= `fifo_wdth'bx;
  m_axis_tkeep      <= `data_wdth'bx;
  m_axis_tlast      <= 1'b0;
  //axis_underflow <= 1'b0;/*}}}*/

  
  // Simulate a read from a 64-bit address for 10 bytes worth of data/*{{{*/
  // TLP consists of just a header, which will be in 4 parts we will
  // need to pull from the FIFO.
  // Fmt: 001     - 4 DW header, no data
  // Type: 0 0000 - Memory read request
  // Header 1: 0010 0000 0000 0000 0000 0000 0000 0000
  // Header 2
  // Header 3: eeee eeee eeee eeee eeee eeee eeee eeee Test addr1
  // Header 4: ffff ffff ffff ffff ffff ffff ffff ffff Test addr2

  // Header 1 of 4
  #100 m_axis_tvalid     <= 1'b1;
  m_axis_tdata      <= `fifo_wdth'h20000000;
  m_axis_tkeep      <= {`data_wdth{'b1}};
  m_axis_tlast      <= 1'b0;
  //axis_underflow <= 1'b0;
  
  // Header 2 of 4
  #100 m_axis_tvalid     <= 1'b1;
  m_axis_tdata      <= `fifo_wdth'b0; // FILL IN WITH READ R INF
  m_axis_tkeep      <= {`data_wdth{'b1}};
  m_axis_tlast      <= 1'b0;
  //axis_underflow <= 1'b0;
  
  // Header 3 of 4
  #100 m_axis_tvalid     <= 1'b1;
  m_axis_tdata      <= `fifo_wdth'heeeeeeee;
  m_axis_tkeep      <= {`data_wdth{'b1}};
  m_axis_tlast      <= 1'b0;
  //axis_underflow <= 1'b0;
  
  // Header 4 of 4
  #100 m_axis_tvalid     <= 1'b1;
  m_axis_tdata      <= `fifo_wdth'hffffffff;
  m_axis_tkeep      <= {`data_wdth{'b1}};
  m_axis_tlast      <= 1'b1;
  //axis_underflow <= 1'b0;

  // WAIT FOR BRIDGE TO FINISH TRANSLATING THE READ REQUEST HERE/*}}}*/


  // Simulate a write to a 64-bit address for 13 bytes

end/*}}}*/
endmodule
