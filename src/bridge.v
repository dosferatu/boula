`include "ocp_master_fsm.v"

/*
 * PCIe 2.0 to OCP 2.2 bridge
 * Authors: Michael Walton, Benjamin Huntsman, Kevin Bedrossian
 */

module bridge(
  // PCIe 2.0 interface/*{{{*/
  input wire sys_clk,
  input wire [81:0] pci_bus,
/*}}}*/

  // OCP 2.2 interface/*{{{*/
  
  // Basic group
  output wire                             Clk,
  inout wire                              EnableClk,
  output wire [`addr_wdth - 1:0]          MAddr,
  output wire [2:0]                       MCmd,
  output wire [`data_wdth - 1:0]          MData,
  output wire                             MDataValid,
  output wire                             MRespAccept,
  input wire                              SCmdAccept,
  input wire [`data_wdth - 1:0]           SData,
  input wire                              SDataAccept,
  input wire [1:0]                        SResp,

  // Simple group
  //output wire [`addrspace_wdth - 1:0]     MAddrSpace,
  output wire [`data_wdth - 1:0]          MByteEn,
  output wire [`data_wdth - 1:0]          MDataByteEn,
  output wire [`mdatainfo_wdth - 1:0]     MDataInfo,
  output wire [`reqinfo_wdth - 1:0]       MReqInfo,
  input wire [`sdatainfo_wdth - 1:0]      SDataInfo,
  input wire [`respinfo_wdth - 1:0]       SRespInfo,

  // Burst group
  output wire [`atomiclength_wdth - 1:0]  MAtomicLength,
  output wire [`blockheight_wdth - 1:0]   MBlockHeight,
  output wire [`blockstride_wdth - 1:0]   MBlockStride,
  output wire [`burstlength_wdth - 1:0]   MBurstLength,
  output wire                             MBurstPrecise,
  output wire [2:0]                       MBurstSeq,
  output wire                             MBurstSingleSeq,
  output wire                             MDataLast,
  output wire                             MDataRowLast,
  output wire                             MReqLast,
  output wire                             MReqRowLast,
  input wire                              SRespLast,
  input wire                              SRespRowLast

  // Tag group
  //output wire [`tags - 1:0]               MDataTagID,
  //output wire [`tags - 1:0]               MTagID,
  //output wire                             MTagInOrder,
  //input wire [`tags - 1:0]                STagID,
  //input wire                              STagInOrder,
  
  // Thread group
  //output wire [`connid_width - 1:0]       MConnID,
  //output wire [`threads - 1:0]            MDataThreadID,
  //output wire [`threads - 1:0]            MThreadBusy,
  //output wire [`threads - 1:0]            MThreadID,
  //input wire [`threads - 1:0]             SDataThreadBusy,
  //input wire [`threads - 1:0]             SThreadBusy,
  //input wire [`threads - 1:0]             SThreadID,
  
  // Sideband group
  //output wire                             ConnectCap,
  //output wire [`control_wdth - 1:0]       Control,
  //output wire                             ControlBusy,
  //output wire [1:0]                       ControlWr,
  //output wire [1:0]                       MConnect,
  //output wire                             MError,
  //output wire [`mflag_wdth - 1:0]         MFlag,
  //output wire                             MReset_n,
  //input wire                              SConnect,
  //input wire                              SError,
  //input wire [`threads - 1:0]             SFlag,
  //input wire                              SInterrupt,
  //input wire                              SReset_n,
  //output wire [`threads - 1:0]            Status,
  //output wire                             StatusBusy,
  //output wire                             StatusRd,
  //input wire                              SWait,
  
  // Test group
  //output wire                             ClkByp,
  //output wire [`scanctrl_wdth - 1:0]      Scanctrl,
  //output wire [`scanport_wdth - 1:0]      Scanin,
  //output wire [`scanport_wdth - 1:0]      Scanout,
  //output wire                             TCK,
  //output wire                             TDI,
  //output wire                             TDO,
  //output wire                             TestClk,
  //output wire                             TMS,
  //output wire                             TRST_N
  /*}}}*/
);

// Declarations/*{{{*/
  reg [`addr_wdth - 1:0]         OCP_ADDRESS_OUT;
  reg [2:0]                      burst_seq;
  reg                            burst_single_req;
  reg [9:0]                      burst_length;
  reg                            data_valid;
  reg                            read_request;
  reg                            reset;
  reg [`data_wdth - 1:0]         TLP_DATA_IN;   // Coming from PCIe side
  reg                            write_request;
  reg                            writeresp_enable;

  wire [`data_wdth - 1:0]         OCP_DATA_IN;    // Coming from OCP bus
/*}}}*/

// OCP master controller/*{{{*/
ocp_master_fsm U1(
  .address(OCP_ADDRESS_OUT),                // Bridge interface
  .enable(enable),
  .burst_seq(burst_seq),
  .burst_single_req(burst_single_req),
  .burst_length(burst_length),
  .data_valid(data_valid),
  .read_data(OCP_DATA_IN),
  .read_request(read_request),
  .reset(reset),
  .sys_clk(sys_clk),
  .write_data(TLP_DATA_IN),
  .write_request(write_request),
  .writeresp_enable(writeresp_enable),

  .Clk(Clk),                                // Basic group
  .EnableClk(EnableClk),
  .MAddr(MAddr),
  .MCmd(MCmd),
  .MData(MData),
  .MDataValid(MDataValid),
  .MRespAccept(MRespAccept),
  .SCmdAccept(SCmdAccept),
  .SData(SData),
  .SDataAccept(SDataAccept),
  .SResp(SResp),

  .MByteEn(MByteEn),                      // Simple group
  .MDataByteEn(MDataByteEn),
  .MDataInfo(MDataInfo),
  .MReqInfo(MReqInfo),
  .SDataInfo(SDataInfo),
  .SRespInfo(SRespInfo),

  .MAtomicLength(MAtomicLength),          // Burst group
  .MBlockHeight(MBlockHeight),
  .MBlockStride(MBlockStride),
  .MBurstLength(MBurstLength),
  .MBurstPrecise(MBurstPrecise),
  .MBurstSeq(MBurstSeq),
  .MBurstSingleSeq(MBurstSingleSeq),
  .MDataLast(MDataLast),
  .MDataRowLast(MDataRowLast),
  .MReqLast(MReqLast),
  .MReqRowLast(MReqRowLast),
  .SRespLast(SRespLast),
  .SRespRowLast(SRespRowLast)
);
/*}}}*/
endmodule
