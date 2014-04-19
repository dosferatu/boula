module fifo_tb();
// Declarations/*{{{*/
// Slave side
reg                         s_aclk;
reg                         s_aresetn;
reg                         s_axis_tvalid;
wire                        s_axis_tready;
reg [63:0]                  s_axis_tdata;
reg [7:0]                   s_axis_tkeep;
reg                         s_axis_tlast;

// Master side
reg                         m_aclk;
wire                        m_aresetn;
wire                        m_axis_tvalid;
reg                         m_axis_tready;
wire [63:0]                 m_axis_tdata;
wire [7:0]                  m_axis_tkeep;
wire                        m_axis_tlast;

wire                        axis_overflow;
wire                        axis_underflow;
/*}}}*/

// FIFO module/*{{{*/
FIFO F0 (
  .m_aclk(m_aclk), // input m_aclk
  .s_aclk(s_aclk), // input s_aclk
  .s_aresetn(s_aresetn), // input s_aresetn
  .s_axis_tvalid(s_axis_tvalid), // input s_axis_tvalid
  .s_axis_tready(s_axis_tready), // output s_axis_tready
  .s_axis_tdata(s_axis_tdata), // input [63 : 0] s_axis_tdata
  .s_axis_tkeep(s_axis_tkeep), // input [7 : 0] s_axis_tkeep
  .s_axis_tlast(s_axis_tlast), // input s_axis_tlast
  .m_axis_tvalid(m_axis_tvalid), // output m_axis_tvalid
  .m_axis_tready(m_axis_tready), // input m_axis_tready
  .m_axis_tdata(m_axis_tdata), // output [63 : 0] m_axis_tdata
  .m_axis_tkeep(m_axis_tkeep), // output [7 : 0] m_axis_tkeep
  .m_axis_tlast(m_axis_tlast), // output m_axis_tlast
  .axis_overflow(axis_overflow), // output axis_overflow
  .axis_underflow(axis_underflow) // output axis_underflow
);
/*}}}*/

// This is to ensure we simulate our reads from the slave end of the FIFO only
// when there is valid data to be read from the queue to avoid underflows.
always @(m_axis_tvalid) begin
  m_axis_tready <= m_axis_tvalid;
end

// Testbench initialization/*{{{*/
initial begin
  s_aclk            <= 1'b0;
  m_aclk            <= 1'b0;
  s_aresetn         <= 1'b0;
  s_axis_tvalid     <= 1'b0;
  m_axis_tready     <= 1'b0;
  s_axis_tdata      <= 64'b0;
  s_axis_tkeep      <= 8'b0;
  s_axis_tlast      <= 1'b0;
end
/*}}}*/

// Master domain clock
initial begin
  forever begin
    #10 s_aclk <= ~s_aclk;
  end
end

// Slave domain clock
initial begin
  forever begin
    #5 m_aclk <= ~m_aclk;
  end
end

// Test bench stimuli/*{{{*/
initial begin
  #10 s_aresetn     <= 1'b1;  // Slave will be ready 3 s_aclk ticks after reset

  // Test writing a single data slice to the slave specifying valid bytes with tkeep
  #60 s_axis_tvalid <= 1'b1;  // Wait until slave is ready to avoid overflow
  s_axis_tdata      <= 64'hFFFFFFFFFFFFFFFF;
  s_axis_tkeep      <= 8'hCF;
  s_axis_tlast      <= 1'b1;

  #20 s_axis_tvalid <= 1'b0;  // Keep the valid signal asserted for at least 1 clock
  s_axis_tdata      <= 64'b0;
  s_axis_tkeep      <= 8'b0;
  s_axis_tlast      <= 1'b0;


  // Test writing multiple data slices to the slave specifying valid bytes with tkeep and last slice with tlast
  #20 s_axis_tvalid <= 1'b1;  // Wait until slave is ready to avoid overflow
  s_axis_tdata      <= 64'h1111111111111111;
  s_axis_tkeep      <= 8'hFF;

  #20 s_axis_tdata  <= 64'h2222222222222222;
  s_axis_tkeep      <= 8'hFF;

  #20 s_axis_tdata  <= 64'h3333333333333333;
  s_axis_tkeep      <= 8'hFF;

  #20 s_axis_tdata  <= 64'h4444444444444444;
  s_axis_tkeep      <= 8'hFF;
  s_axis_tlast      <= 1'b1;

  #20 s_axis_tvalid <= 1'b0;
  s_axis_tdata      <= 64'b0;
  s_axis_tkeep      <= 8'b0;
  s_axis_tlast      <= 1'b0;
end
/*}}}*/
endmodule
