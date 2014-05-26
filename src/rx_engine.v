// This module will have the registers that will hold the TLP Header slices
//  to be translated into OCP and will manage the shifting of data out of a 96
//  bit shift register in accordance with the controls from the rx_fsm.

module rx_engine(
    // Command Signals
    
    // PCIe Core AXI Interface
    
    // Tx Header FIFO
    
    // OCP Interface
    );
    
    // Declarations
    
    // Parameters for parameterization of the module
    parameter axi_width = 64;
    
    // OCP Registers for holding TLP Header
    reg [axi_width - 1:0] header1;
    reg [axi_width - 1:0] header2;

    // Instantiation of rx_fsm for controlling flow of TLP
    rx_fsm rx_control(...);

    // OCP Translation logic
    
endmodule
    
