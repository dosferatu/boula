/*
 * HEADER GOES HERE
 */
//`include "const.vh"
`define MDATA_WIDTH 8
`define SDATA_WIDTH 8
`define MADDR_WIDTH 64

`include "ocp_master_fsm.v"

module ocp_master_fsm_tb();
  // Bridge interface/*{{{*/
  reg [`MADDR_WIDTH - 1:0]  address;
  reg [9:0]                 burst_length;
  reg [2:0]                 burst_seq;
  reg                       data_valid;
  reg                       read_request;
  reg                       reset;
  reg [`MDATA_WIDTH - 1:0]  write_data;   // Coming from PCIe side
  reg                       write_request;

  wire [`MDATA_WIDTH - 1:0] read_data;    // Coming from OCP bus
  /*}}}*/

  // OCP 3.0 interface/*{{{*/

  // Basic group
  reg                       clk;
  wire                      Clk;
  reg                       EnableClk;
  reg [`SDATA_WIDTH - 1:0]  SData;
  reg [1:0]                 SResp;
  wire [`MADDR_WIDTH - 1:0] MAddr;
  wire [2:0]                MCmd;
  wire [`MDATA_WIDTH - 1:0] MData;

  // Simple group
  reg                       SCmdAccept;
  reg                       SDataAccept;

  // Burst group
  wire [9:0]                MBurstLength;
  wire                      MReqLast;
  //wire                      MDataValid;
  /*}}}*/

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

ocp_master_fsm U0(
  .address(address),
  .burst_length(burst_length),
  .burst_seq(burst_seq),
  //.data_valid(data_valid),
  .read_request(read_request),
  .reset(reset),
  .write_data(write_data),
  .write_request(write_request),
  .read_data(read_data),
  .sys_clk(clk),
  .Clk(Clk),
  .EnableClk(EnableClk),
  .SCmdAccept(SCmdAccept),
  .SData(SData),
  //.SDataAccept(SDataAccept),
  .SResp(SResp),
  .MAddr(MAddr),
  .MBurstLength(MBurstLength),
  .MCmd(MCmd),
  .MData(MData),
  //.MDataValid(MDataValid)
  .MReqLast(MReqLast)
);
/*}}}*/

// Master controller initialization/*{{{*/
initial begin
  // Bridge simulation initialization
  address       <= `MADDR_WIDTH'bx;
  burst_length  <= 1'b1;
  burst_seq     <= 2'b00;
  data_valid    <= 1'b0;
  read_request  <= 1'b0;
  reset         <= 1'b1;
  write_data    <= `MDATA_WIDTH'bx;
  write_request <= 1'b0;

  // OCP interface initialization
  clk           <= 1'b0;
  EnableClk     <= 1'b0;
  SCmdAccept    <= 1'b0;
  SData         <= `SDATA_WIDTH'bx;
  SDataAccept   <= 1'b0;
  SResp         <= NULL;
  
  // Start the clock with a 10 unit period
  forever begin
    #10 clk <= ~clk;
  end
end
/*}}}*/

// Test bench stimuli/*{{{*/
initial begin
  #20 reset <= 1'b0;
  EnableClk <= 1'b1;

  // Perform a simple write to the slave/*{{{*/
  
  // WR state
  // Request phase
  #50 address <= 64'hFFFFFFFFFFFFFFFF;
  read_request <= 1'b0;
  write_data <= `MDATA_WIDTH'hFF;
  write_request <= 1'b1;
  #20 SCmdAccept <= 1'b1;

  // Response phase
  SResp <= NULL;
  SData <= `SDATA_WIDTH'bx;


  // IDLE state
  // Request phase
  #20 address <= 64'bx;
  read_request <= 1'b0;
  write_data <= `MDATA_WIDTH'bx;
  write_request <= 1'b0;
  SCmdAccept <= 1'b0;

  // Response phase
  SResp <= NULL;
  SData <= `SDATA_WIDTH'bx;
/*}}}*/


  // Perform a simple read request to the slave/*{{{*/
  
  // RD state
  // Request phase
  #60 address <= 64'hFFFFFFFFFFFFFFFF;
  read_request <= 1'b1;
  write_data <= `MDATA_WIDTH'bx;
  write_request <= 1'b0;
  #20 SCmdAccept <= 1'b1;

  // Response phase
  SResp <= NULL;
  SData <= `SDATA_WIDTH'bx;


  // IDLE state
  // Request phase
  #20 address <= 64'bx;
  read_request <= 1'b0;
  write_data <= `MDATA_WIDTH'bx;
  write_request <= 1'b0;
  SCmdAccept <= 1'b0;

  // Response phase
  SResp <= DVA;
  SData <= `SDATA_WIDTH'hFF;
  #20 SResp <= NULL;
  SData <= `SDATA_WIDTH'bx;
/*}}}*/


  // Perform a burst write to the slave/*{{{*/

  // WR state
  // Request phase (Data 1)
  #60 address <= 64'b0;
  burst_length <= 10'h4;
  read_request <= 1'b0;
  write_data <= `MDATA_WIDTH'h0;
  write_request <= 1'b1;
  #20 SCmdAccept <= 1'b1;

  // insert burst stuff here
  #20 address <= 64'h4;
  burst_length <= 10'h4;
  write_data <= `MDATA_WIDTH'h1;
  write_request <= 1'b0;
  
  #20 address <= 64'h8;
  burst_length <= 10'h4;
  write_data <= `MDATA_WIDTH'h2;
  write_request <= 1'b0;
  
  #20 address <= 64'hC;
  burst_length <= 10'h4;
  write_data <= `MDATA_WIDTH'h3;
  write_request <= 1'b0;

  #20 address <= 64'b0;
  burst_length <= 10'b0;
  write_data <= `MDATA_WIDTH'b0;
  write_request <= 1'b0;
  /*}}}*/
end
/*}}}*/
endmodule
