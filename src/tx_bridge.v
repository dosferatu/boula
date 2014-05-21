/*
 * Tx Bridge
 * Author: Kevin Bedrossian
 *
 * This module takes header input from a header queue and
 * the appropriate data input from the OCP_master_FSM.
 * It will then output the header and then the data on the
 * Xilinx PCIe core using the AXI4 Stream interface.
 */


`define fifo_wdth 64
`define data_wdth 8

module txbridge(
  input wire clk,
  input wire reset,

  //OCP_master connections (AXI-4 stream)/*{{{*/
  input wire data_valid,
  output reg data_ready,
  input wire [`fifo_wdth - 1:0] data_data,
  input wire [`data_wdth - 1:0] data_keep,
  input wire data_last,
  /*}}}*/
  
  //AXI HEADER FIFO connections/*{{{*/
  input wire header_valid,
  output reg header_ready,
  input wire [`fifo_wdth - 1:0] header_data,
  input wire [`data_wdth - 1:0] header_keep,
  input wire header_last,
  /*}}}*/
  
  //PCIe AXI connections/*{{{*/
  output reg AXI_out_valid,
  input wire AXI_out_ready,
  output reg [`fifo_wdth - 1: 0] AXI_out_data,
  output reg [`data_wdth - 1: 0] AXI_out_keep,
  output reg AXI_out_last
  /*}}}*/
  
);

//Declarations/*{{{*/

//State encoding
localparam IDLE     = 3'b000;
localparam FIRST_DW  = 3'b001;
localparam SECOND_DW = 3'b010;
localparam HEADER   = 3'b011;
localparam DATA     = 3'b100;
localparam COMPLETE = 3'b101;

//Format encoding for PCI Express 3.0
localparam NO_DATA_3DW    = 3'b000; // 3DW header, no data
localparam NO_DATA_4DW  = 3'b001; // 4DW header, no data
localparam W_DATA_3DW    = 3'b010; // 3DW header, with data
localparam W_DATA_4DW   = 3'b011; // 4DW header, with data
localparam TLP_PRFX   = 3'b100; // TLP Prefix

//Type encoding for PCI Express 2.0
localparam MRD    = 5'b0_0000; // Memory Read Request (if format = 000 or 001)
localparam MRDLK  = 5'b0_0001; // Memory Read Request-locked 
localparam MWR    = 5'b0_0000; // Memory Write Request (if format = 010 or 011)
localparam CPL    = 5'b0_1010; // Completion packet
localparam CPLLK  = 5'b0_1011; // Completion for locked request

reg [2:0] state;
reg [2:0] next;

reg header_started;
reg is_data;
 
reg [1:0] address_type;

reg [1:0] header_counter;
reg [9:0] data_counter;
reg [1:0] header_length;
reg [9:0] data_length;
/*}}}*/

//State transition logic/*{{{*/
always @(posedge clk) begin
  if (reset) begin
    state <= IDLE;
  end

  else begin
    state <= next;
  end
end
/*}}}*/

//Next state logic/*{{{*/
always @(state) begin
  
  case (state)
    IDLE: begin
      if(header_valid & AXI_out_ready) begin
        next <= FIRST_DW;   // Data is in the AXI FIFO for us
      end
      
      else begin
        next <= IDLE;
      end
      
    end

    FIRST_DW: begin
      if (header_valid & AXI_out_ready) begin
        next <= SECOND_DW;  
      end
      else begin
        next <= FIRST_DW;
      end
    end
    
    SECOND_DW: begin  //Add an extra DW for completion packet
      if(header_valid & AXI_out_ready) begin
        next <= HEADER;
      end
      
      else begin
        next <= SECOND_DW;
      end
    end
    
    HEADER: begin
      if((header_counter == header_length) & is_data) begin
        next <= DATA;
      end
      
      else if((header_counter == header_length) & ~is_data) begin
        next <= COMPLETE;
      end
      
      else begin
        next <= HEADER;
      end      
    end

    DATA: begin
      if (data_counter == data_length) begin
        next <= COMPLETE;   //Data is finished
      end
      
      else begin
        next <= DATA;
      end
    end

    default: begin  //The "COMPLETE" state always goes to IDLE
      next <= IDLE;
    end
  endcase
end
/*}}}*/

//Output logic/*{{{*/
always @(posedge clk) begin
  //RESET/*{{{*/
  if (reset) begin
    //AXI input
    header_ready        <= 1'b0;
    data_ready          <= 1'b0;

    //Bridge internals/*{{{*/
    is_data <= 1'b0;
    
    header_counter <= 2'b0;
    data_counter <= 2'b0;
    data_length <= 10'b0;
    header_length <= 2'b0;
    AXI_out_data <= 64'b0;
    AXI_out_last <= 1'b0;
    AXI_out_valid <= 1'b0;
  end
  /*}}}*/
  /*}}}*/

  else begin
    case (next)
      //IDLE/*{{{*/
    IDLE: begin
      //AXI input
      header_ready      <= 1'b0;
      data_ready        <= 1'b0;

      //Bridge internals/*{{{*/
      is_data           <= 1'b0;
      header_counter    <= 2'b0;
      data_counter      <= 2'b0;
      data_length   <= 10'b0;
      header_length <= 2'b0;
      AXI_out_data  <= `fifo_wdth'b0;
      AXI_out_last  <= 1'b0;
      AXI_out_valid <= 1'b0;
      AXI_out_keep <= `data_wdth'b0;
    end
    /*}}}*/
    /*}}}*/

    //FIRST_DW/*{{{*/
    FIRST_DW: begin
      //AXI input
      data_ready <= 1'b0;
      if(header_valid & AXI_out_ready) begin
        AXI_out_valid <= 1'b1;
        header_ready <= 1'b1;
      end
      else begin
        AXI_out_valid <= 1'b0;
        header_ready <= 1'b0;
      end
        
      case(header_data[31:24])
      {NO_DATA_3DW, MRD}: begin
        AXI_out_data <= {header_data[63:32], 
          W_DATA_3DW, CPL, 
          header_data[23:0]};
        is_data <= 1'b1;
        header_length <= 2'b10;
      end
      {NO_DATA_4DW, MRD}: begin
        AXI_out_data <= {header_data[63:32], 
          W_DATA_4DW, CPL, 
          header_data[23:0]};
        is_data <= 1'b1;
        header_length <= 2'b11;
      end
      {NO_DATA_3DW, MRDLK}: begin
        AXI_out_data <= {header_data[63:32], 
          W_DATA_3DW, CPLLK, 
          header_data[23:0]};
        is_data <= 1'b1;
        header_length <= 2'b10;
      end
      {NO_DATA_4DW, MRDLK}: begin
        AXI_out_data <= {header_data[63:32], 
          W_DATA_4DW, CPLLK, 
          header_data[23:0]};
        is_data <= 1'b1;
        header_length <= 2'b11;
      end
      {W_DATA_3DW, MWR}: begin
        AXI_out_data <= {header_data[63:32], 
          NO_DATA_3DW, CPL, 
          header_data[23:0]};
        is_data <= 1'b0;
        header_length <= 2'b10;
      end
      {W_DATA_4DW, MWR}: begin
        AXI_out_data <= {header_data[63:32], 
          NO_DATA_4DW, CPL, 
          header_data[23:0]};
        is_data <= 1'b0;
        header_length <= 2'b11;
      end
      default: begin
        AXI_out_data <= `fifo_wdth'b0;
        is_data <= 1'b0;
        header_length <= 2'b0;
      end
        
      endcase
      data_counter <= 10'b0;
      header_counter <= 2'b0;
      data_length <= header_data[9:0];
      AXI_out_last <= 1'b0;
      AXI_out_keep <= header_keep;
    end
    /*}}}*/

    //SECOND_DW empty placeholder at the moment/*{{{*/
    SECOND_DW: begin
      header_ready        <= 1'b0;
      data_ready          <= 1'b0;

      //Bridge internals/*{{{*/
      is_data <= is_data;
      
      header_counter <= 2'b0;
      data_counter <= 2'b0;
      data_length <= 10'b0;
      header_length <= 2'b0;
      AXI_out_data <= 64'b0;
      AXI_out_last <= 1'b0;
      AXI_out_valid <= 1'b0;
      AXI_out_keep <= {`data_wdth{1'b1}};
    end
    /*}}}*/
    /*}}}*/
    
    //HEADER/*{{{*/
    HEADER: begin
      //AXI input
      data_ready <= 1'b0;
      if(header_valid & AXI_out_ready) begin
        header_counter <= header_counter + 1'b1;
        AXI_out_valid <= 1'b1;
        header_ready <= 1'b1;
      end
      else begin
        header_counter <= header_counter;
        AXI_out_valid <= 1'b0;
        header_ready <= 1'b0;
      end
      
      is_data <= is_data;
      AXI_out_data <= header_data;
      data_counter <= 10'b0;
      data_length <= data_length;
      header_length <= header_length;
      AXI_out_last <= 1'b0;
      AXI_out_keep <= header_keep;
    end
    /*}}}*/

     //DATA/*{{{*/
    DATA: begin
      //AXI input
      header_ready <= 1'b0;
      if(data_valid & AXI_out_ready) begin
        data_counter <= data_counter + data_keep;
        AXI_out_valid <= 1'b1;
        data_ready <= 1'b1;
      end
      else begin
        data_counter <= data_counter;
        AXI_out_valid <= 1'b0;
        data_ready <= 1'b0;
      end

       //Bridge internals/*{{{*/      
      if(data_counter == data_length) begin
        AXI_out_last <= 1'b1;
      end
      else begin
        AXI_out_last <= 1'b0;
      end
      
      is_data <= is_data;
      AXI_out_data <= data_data;
      header_counter <= 2'b0;
      data_length <= data_length;
      header_length <= header_length;
      AXI_out_keep <= data_keep;
    end
    /*}}}*/
    /*}}}*/

     //DEFAULT/COMPLETE /*{{{*/
    default: begin
      // AXI input
      AXI_out_valid <= 1'b0;
      data_ready <= 1'b0;
      header_ready <= 1'b0;

       //Bridge internals/*{{{*/
      is_data <= 1'b0;
      header_counter <= 2'b0;
      data_counter <= 10'b0;
      data_length <= 10'b0;
      header_length <= 2'b0;
      AXI_out_data <= `fifo_wdth'b0;
      AXI_out_last <= 1'b0;
      AXI_out_keep <= `data_wdth'b0;
    end
    /*}}}*/
    /*}}}*/
    endcase
  end
end
/*}}}*/
endmodule
