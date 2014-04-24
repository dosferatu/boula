`include "ocp_master_fsm.v"
`include "axi2ocp.v"

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
  reg [2:0]                   burst_seq;
  reg                         burst_single_req;
  reg [9:0]                   burst_length;
  reg                         data_valid;
  reg                         read_request;
  reg                         reset;
  wire                       ocp_reset;
  reg                         write_request;
  reg                         writeresp_enable;

  /*
   * THIS NEEDS TO BE GROUPED NICELY SO IT DOESN'T SUCK TO READ
   */

  wire                        RX_AXI_CLK;
  wire                        RX_OCP_CLK;
  wire                        RX_SLAVE_AXI_FIFO_DATA_VALID;
  wire                        RX_SLAVE_AXI_FIFO_DATA_READY;
  wire [63:0]                 RX_SLAVE_AXI_FIFO_DATA;
  wire [7:0]                  RX_SLAVE_AXI_FIFO_DATA_KEEP;
  wire                        RX_SLAVE_AXI_FIFO_DATA_LAST;
  wire                        RX_SLAVE_AXI_FIFO_OVERFLOW;
  wire                        RX_SLAVE_AXI_FIFO_UNDERFLOW;

  wire                        RX_MASTER_AXI_FIFO_DATA_VALID;
  wire                        RX_MASTER_AXI_FIFO_DATA_READY;
  wire [63:0]                 RX_MASTER_AXI_FIFO_DATA;
  wire [7:0]                  RX_MASTER_AXI_FIFO_DATA_KEEP;
  wire                        RX_MASTER_AXI_FIFO_DATA_LAST;
  wire                        RX_MASTER_AXI_FIFO_OVERFLOW;
  wire                        RX_MASTER_AXI_FIFO_UNDERFLOW;

  wire [`addr_wdth - 1:0]     OCP_ADDRESS_OUT;
  wire                        OCP_ENABLE;
  wire                        OCP_BURST_SEQ;
  wire                        OCP_BURST_SINGLE_REQ;
  wire                        OCP_BURST_LENGTH;
  wire                        OCP_DATA_VALID;
  wire                        OCP_DATA_IN;
  wire                        OCP_DATA_OUT;
  wire                        READ_REQUEST;
  wire                        WRITE_REQUEST;
  wire [`data_wdth - 1:0]     WRITE_DATA;
  wire                        WRITE_RESPONSE_ENABLE;

  wire                        RX_MASTER_OCP_FIFO_DATA_VALID;
  wire                        RX_MASTER_OCP_FIFO_DATA_READY;
  wire [63:0]                 RX_MASTER_OCP_FIFO_DATA;
  wire [7:0]                  RX_MASTER_OCP_FIFO_DATA_KEEP;
  wire                        RX_MASTER_OCP_FIFO_DATA_LAST;
  wire                        RX_MASTER_OCP_FIFO_OVERFLOW;
  wire                        RX_MASTER_OCP_FIFO_UNDERFLOW;
    /*}}}*/

// PCIe 2.0 Coregen module/*{{{*/
PCIe pcie (

  //-------------------------------------------------------
  // 1. PCI Express (pci_exp) Interface
  //-------------------------------------------------------

  // Tx
  //.pci_exp_txp                         ( pci_exp_txp ),
  //.pci_exp_txn                         ( pci_exp_txn ),

  // Rx
  //.pci_exp_rxp                         ( pci_exp_rxp ),
  //.pci_exp_rxn                         ( pci_exp_rxn ),

  //-------------------------------------------------------
  // 2. Transaction (TRN) Interface
  //-------------------------------------------------------

  // Common
  //.user_clk_out                        ( user_clk ),
  //.user_reset_out                      ( user_reset_int1 ),
  //.user_lnk_up                         ( user_lnk_up_int1 ),

  // Tx
  //.s_axis_tx_tready                    ( s_axis_tx_tready ),
  //.s_axis_tx_tdata                     ( s_axis_tx_tdata ),
  //.s_axis_tx_tkeep                     ( s_axis_tx_tkeep ),
  //.s_axis_tx_tuser                     ( s_axis_tx_tuser ),
  //.s_axis_tx_tlast                     ( s_axis_tx_tlast ),
  //.s_axis_tx_tvalid                    ( s_axis_tx_tvalid ),
  //.tx_cfg_gnt                          ( tx_cfg_gnt ),
  //.tx_cfg_req                          ( tx_cfg_req ),
  //.tx_buf_av                           ( tx_buf_av ),
  //.tx_err_drop                         ( tx_err_drop ),

  // Rx
  //.m_axis_rx_tdata                     ( m_axis_rx_tdata ),
  //.m_axis_rx_tkeep                     ( m_axis_rx_tkeep ),
  //.m_axis_rx_tlast                     ( m_axis_rx_tlast ),
  //.m_axis_rx_tvalid                    ( m_axis_rx_tvalid ),
  //.m_axis_rx_tready                    ( m_axis_rx_tready ),
  //.m_axis_rx_tuser                     ( m_axis_rx_tuser ),
  //.rx_np_ok                            ( rx_np_ok ),

  // Flow Control
  //.fc_cpld                             ( fc_cpld ),
  //.fc_cplh                             ( fc_cplh ),
  //.fc_npd                              ( fc_npd ),
  //.fc_nph                              ( fc_nph ),
  //.fc_pd                               ( fc_pd ),
  //.fc_ph                               ( fc_ph ),
  //.fc_sel                              ( fc_sel ),


  //-------------------------------------------------------
  // 3. Configuration (CFG) Interface
  //-------------------------------------------------------

  //.cfg_do                              ( cfg_do ),
  //.cfg_rd_wr_done                      ( cfg_rd_wr_done),
  //.cfg_di                              ( cfg_di ),
  //.cfg_byte_en                         ( cfg_byte_en ),
  //.cfg_dwaddr                          ( cfg_dwaddr ),
  //.cfg_wr_en                           ( cfg_wr_en ),
  //.cfg_rd_en                           ( cfg_rd_en ),

  //.cfg_err_cor                         ( cfg_err_cor ),
  //.cfg_err_ur                          ( cfg_err_ur ),
  //.cfg_err_ecrc                        ( cfg_err_ecrc ),
  //.cfg_err_cpl_timeout                 ( cfg_err_cpl_timeout ),
  //.cfg_err_cpl_abort                   ( cfg_err_cpl_abort ),
  //.cfg_err_cpl_unexpect                ( cfg_err_cpl_unexpect ),
  //.cfg_err_posted                      ( cfg_err_posted ),
  //.cfg_err_locked                      ( cfg_err_locked ),
  //.cfg_err_tlp_cpl_header              ( cfg_err_tlp_cpl_header ),
  //.cfg_err_cpl_rdy                     ( cfg_err_cpl_rdy ),
  //.cfg_interrupt                       ( cfg_interrupt ),
  //.cfg_interrupt_rdy                   ( cfg_interrupt_rdy ),
  //.cfg_interrupt_assert                ( cfg_interrupt_assert ),
  //.cfg_interrupt_di                    ( cfg_interrupt_di ),
  //.cfg_interrupt_do                    ( cfg_interrupt_do ),
  //.cfg_interrupt_mmenable              ( cfg_interrupt_mmenable ),
  //.cfg_interrupt_msienable             ( cfg_interrupt_msienable ),
  //.cfg_interrupt_msixenable            ( cfg_interrupt_msixenable ),
  //.cfg_interrupt_msixfm                ( cfg_interrupt_msixfm ),
  //.cfg_turnoff_ok                      ( cfg_turnoff_ok ),
  //.cfg_to_turnoff                      ( cfg_to_turnoff ),
  //.cfg_trn_pending                     ( cfg_trn_pending ),
  //.cfg_pm_wake                         ( cfg_pm_wake ),
  //.cfg_bus_number                      ( cfg_bus_number ),
  //.cfg_device_number                   ( cfg_device_number ),
  //.cfg_function_number                 ( cfg_function_number ),
  //.cfg_status                          ( cfg_status ),
  //.cfg_command                         ( cfg_command ),
  //.cfg_dstatus                         ( cfg_dstatus ),
  //.cfg_dcommand                        ( cfg_dcommand ),
  //.cfg_lstatus                         ( cfg_lstatus ),
  //.cfg_lcommand                        ( cfg_lcommand ),
  //.cfg_dcommand2                       ( cfg_dcommand2 ),
  //.cfg_pcie_link_state                 ( cfg_pcie_link_state ),
  //.cfg_dsn                             ( cfg_dsn ),
  //.cfg_pmcsr_pme_en                    ( cfg_pmcsr_pme_en ),
  //.cfg_pmcsr_pme_status                ( cfg_pmcsr_pme_status ),
  //.cfg_pmcsr_powerstate                ( cfg_pmcsr_powerstate ),

  //-------------------------------------------------------
  // 4. Physical Layer Control and Status (PL) Interface
  //-------------------------------------------------------

  //.pl_initial_link_width               ( pl_initial_link_width ),
  //.pl_lane_reversal_mode               ( pl_lane_reversal_mode ),
  //.pl_link_gen2_capable                ( pl_link_gen2_capable ),
  //.pl_link_partner_gen2_supported      ( pl_link_partner_gen2_supported ),
  //.pl_link_upcfg_capable               ( pl_link_upcfg_capable ),
  //.pl_ltssm_state                      ( pl_ltssm_state ),
  //.pl_received_hot_rst                 ( pl_received_hot_rst ),
  //.pl_sel_link_rate                    ( pl_sel_link_rate ),
  //.pl_sel_link_width                   ( pl_sel_link_width ),
  //.pl_directed_link_auton              ( pl_directed_link_auton ),
  //.pl_directed_link_change             ( pl_directed_link_change ),
  //.pl_directed_link_speed              ( pl_directed_link_speed ),
  //.pl_directed_link_width              ( pl_directed_link_width ),
  //.pl_upstream_prefer_deemph           ( pl_upstream_prefer_deemph ),

  //-------------------------------------------------------
  // 5. System  (SYS) Interface
  //-------------------------------------------------------

  //.sys_clk                             ( sys_clk_c ),
  //.sys_reset                           ( !sys_reset_n_c )

);
/*}}}*/

// AXI to OCP bridge module/*{{{*/
axi2ocp rx_bridge(
  .clk(RX_OCP_CLK),
  .reset(),

  // AXI FIFO/*{{{*/
  .m_aclk(RX_AXI_CLK),
  .m_axis_tvalid(RX_SLAVE_AXI_FIFO_DATA_VALID),
  .m_axis_tready(RX_SLAVE_AXI_FIFO_DATA_READY),
  .m_axis_tdata(RX_SLAVE_AXI_FIFO_DATA),
  .m_axis_tkeep(RX_SLAVE_AXI_FIFO_DATA_KEEP),
  .m_axis_tlast(RX_SLAVE_AXI_FIFO_DATA_LAST),
  .axis_underflow(RX_SLAVE_AXI_FIFO_OVERFLOW),
  /*}}}*/
  
  // OCP 2.2 Interface/*{{{*/
  .address(OCP_ADDRESS_OUT),
  .enable(OCP_ENABLE),
  .burst_seq(OCP_BURST_SEQ),
  .burst_single_req(OCP_BURST_SINGLE_REQ),
  .burst_length(OCP_BURST_LENGTH),
  .data_valid(OCP_DATA_VALID),
  .read_request(READ_REQUEST),
  .ocp_reset(ocp_reset),
  .sys_clk(),
  .write_data(OCP_DATA_OUT),
  .write_request(WRITE_REQUEST),
  .writeresp_enable(WRITE_RESPONSE_ENABLE)
  /*}}}*/
);
/*}}}*/

// OCP master controller/*{{{*/
ocp_master_fsm ocp_interface(
  .address(OCP_ADDRESS_OUT),                // Bridge interface
  .enable(OCP_ENABLE),
  .burst_seq(OCP_BURST_SEQ),
  .burst_single_req(OCP_BURST_SINGLE_REQ),
  .burst_length(OCP_BURST_LENGTH),
  .data_valid(OCP_DATA_VALID),
  .read_data(OCP_DATA_IN),
  .read_request(READ_REQUEST),
  .reset(reset),
  .sys_clk(RX_OCP_CLK),
  .write_data(OCP_DATA_OUT),
  .write_request(WRITE_REQUEST),
  .writeresp_enable(WRITE_RESPONSE_ENABLE),

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

/*
 * FINISH WIRING THE FIFOS TO WHERE THEY NEED TO GO FOR THE RX SIDE
 */

// FIFO instantiations/*{{{*/

// AXI FIFO for the Rx side of the bridge
FIFO axi_rx_fifo (
  .m_aclk(RX_AXI_CLK),
  .s_aclk(RX_AXI_CLK),
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
  .axis_overflow(RX_MASTER_AXI_FIFO_OVERFLOW),
  .axis_underflow(RX_MASTER_AXI_FIFO_UNDERFLOW)
);

// FIFO for the data coming from the OCP bus
FIFO ocp_fifo (
  .m_aclk(RX_AXI_CLK),
  .s_aclk(RX_OCP_CLK),
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
);

// FIFO for the TLP header information
FIFO header_fifo (
  .m_aclk(m_aclk),
  .s_aclk(s_aclk),
  .s_aresetn(s_aresetn),
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
);
/*}}}*/

endmodule
