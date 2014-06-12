// This module will have the registers that will hold the TLP Header slices
//  to be translated into OCP and will manage the shifting of data out of a 96
//  bit shift register in accordance with the controls from the rx_fsm.

// Definitions
`define 

module rx_engine(
    // Module Ports /*{{{*/
    // Command Signals /*{{{*/
    input wire                      rx_reset,
    input wire                      rx_enable,
    /*}}}*/

    // PCIe Core AXI Interface /*{{{*/
    input wire                      rx_clk,
    input wire                      rx_valid,
    input wire  [axi_width - 1:0]   rx_data,
    input wire  [keep_width - 1:0]  rx_keep,
    input wire                      rx_last,
    output wire                     rx_ready,
    /*}}}*/

    // Tx Header AXI FIFO /*{{{*/
    input wire                      tx_header_fifo_ready,
    output wire                     tx_header_fifo_valid,
    output wire                     tx_header_fifo_last,
    output wire [keep_width - 1:0]  tx_header_fifo_keep,
    output wire [axi_width - 1:0]   tx_header_fifo_data,
    /*}}}*/

    // OCP 2.2 Interface/*{{{*/
    input wire                       ocp_ready,
    output wire [`addr_wdth - 1:0]   address,
    output wire                      enable,
    output wire [2:0]                burst_seq,
    output wire                      burst_single_req,
    output wire [9:0]                burst_length,
    output wire                      data_valid,
    output wire                      read_request,
    output wire [axi_width - 1:0]    write_data,
    output wire                      write_request,
    output wire                      writeresp_enable
    /*}}}*/ 

    );
    /*}}}*/ 

    // Declarations /*{{{*/
    
    // Parameters for parameterization of the module
    parameter axi_width     = 64;
    parameter ocp_addr_size = 32;
    parameter keep_width    = 8;


    // OCP register control encodings
    localparam IDLE     = 3'b000;
    localparam H1       = 3'b001;
    localparam H2       = 3'b010;
    localparam DATA3    = 3'b011;
    localparam DATA4    = 3'b100;


    // MBurstSeq encoding for OCP 2.2
    localparam INCR  = 3'b000;   // Incrementing
    localparam DFLT1 = 3'b001;   // Custom (packed)
    localparam WRAP  = 3'b010;   // Wrapping
    localparam DFLT2 = 3'b011;   // Custom (not packed)
    localparam XOR   = 3'b100;   // Exclusive OR
    localparam STRM  = 3'b101;   // Streaming
    localparam UNKN  = 3'b110;   // Unknown
    localparam BLCK  = 3'b111;   // 2-dimensional Block


     // OCP Registers for holding TLP Header
    wire [2:0] ocp_reg_ctl;                         // For contolling of data flow into the registers
    reg [axi_width - 1:0]   header1;                // Holds the first slice of the header
    reg [axi_width - 1:0]   header2;                // Holds the second slice of the header
    reg [96 - 1:0]          data_shift_register;    // Shifts data in and out for transmission onto OCP

    // Others
    wire [1:0] optype;
    wire rx_vld_en;
    /*}}}*/

    // Enabling the rx receiver
    assign rx_vld_en = rx_valid & rx_enable;        // Enables receiving if valid data and control enabled

    
    // Instantiation of rx_fsm for controlling flow of TLP /*{{{*/
    rx_fsm rx_control(rx_reset, rx_clk, rx_vld_en, rx_keep, rx_last,
                      rx_ready, tx_header_fifo_ready, tx_header_fifo_valid,
                      ocp_ready, optype, ocp_reg_ctl, read_request, write_request);
    /*}}}*/

    // OCP Translation logic /*{{{*/
    initial begin
        address             <=  {header2 [ocp_addr_size - 1:2], 2'b00};
        enable              <=  1'b1;
        burst_seq           <=  
        burst_single_req    <=  
        burst_length        <= header1 [9:0]; 
        data_valid          <=  
        write_data          <= data_shft_register [64 - 1:0]; 
        writeresp_enable    <=  
    end

        /*}}}*/

    // OCP Register Control /*{{{*/
    always @(posedge rx_clk) begin
        case (ocp_reg_ctl)
            IDLE:   begin end                                       // Do nothing
            
            H1:     begin                                           // Load first slice of header
                if (rx_ready) begin                                 //  If rx module ready recieve new data
                    header1                     <= rx_data; end
                else begin
                    header1                     <= header1; end     //  Else keep current data in register
            end

            H2:     begin                                           // Load second slice of header
                if (rx_ready) begin
                    header2                     <= rx_data;         //  If rx module ready load whole slice into header register
                    data_shift_register [95:64] <= rx_data [63:32]; //  Load portion that may be data into data reg
                end
                else begin
                    header2                     <= header2;         //   Else keep current slice
                    data_shift_register [95:64] <= data_shift_register[95:64] // Else keep current data
                end   
            end   

            DATA3:  begin                                           // Load data into data reg to concatenate one slice to another
                if (rx_ready) begin
                    data_shift_register [31:0]  <= data_shift_register [95:64]; // Shift upper DW to lower DW
                    data_shift_register [95:32] <= rx_data;                     //  Load next 2 DWs into upper 2 DWs of data reg
                end
                else begin
                    data_shift_register [31:0]  <= data_shift_register [31:0];   // Keep current data
                    data_shift_register [95:32] <= data_shift_register [95:32];  // Keep current data
                end

            end

            DATA4:  begin                                           // Load data into lower 2 DWs of data reg
                if (rx_ready) begin
                    data_shift_register [63:0]  <= rx_data; end
                else begin
                    data_shift_register [63:0]  <= data_shift_register [63:0]; end
            end
        endcase
    end
/*}}}*/
endmodule
