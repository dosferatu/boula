/* This module manages the control of the bridge.  It includes the
 *  checking of flow control credits and any necessary reset logic.
 */
 
 module bridge_control (
        // Inputs to modules
        input           Ctrl_CLK,       // Clock that all things are synchronous to
        input           Ctrl_RST,       // Reset signal from the core block to the bridge
        input           Ctrl_Link_Up,   // Signals Link up of core block with PCIe partner
        input [7:0]     Ctrl_fc_ph,     // Posted Header
        input [11:0]    Ctrl_fc_pd,     // Posted Data
        input [7:0]     Ctrl_fc_nph,    // Non-posted Header
        input [11:0]    Ctrl_fc_npd,    // Non-posted Data
        input [7:0]     Ctrl_fc_cplh,   // Completion Header
        input [11:0]    Ctrl_fc_cpld,   // Completion Data

        // Outputs of module
        output reg [2:0] Ctrl_fc_sel,    // Selection of desired flow control type
        output           Ctrl_Rx_Ready,  // Signals to Rx Bridge that it is ok to receive
        output           Ctrl_Tx_Ready,  // Signals to Tx Bridge that it is ok to transmit
        output           Ctrl_OCP_Ready, // Signals to OCP Controller that it is ok to operate
        output           Ctrl_Bridge_RST,// Signals to Bridge that a reset is needed
        output [5:0]     Ctrl_Tx_FC      // Signals for Flow Credits to transmit bridge module
        );


        // Establish parameters needed for parameterizaion of the control module
        parameter MAX_PAYLOAD = 1024;   // This is maximum size of a single TLP in bytes


        // Setup needed local parameters for bridge control
        //  States of the FSM for getting flow credit information
        localparam      IDLE    = 2'b00; // Sits and waits for something to happen
        localparam      REQ_FC  = 2'b01; // Requests flow credit information for TLP
        localparam      WAIT1   = 2'b10; // Causing a wait of a one cycle to get the FC info
        localparam      STR_FC  = 2'b11; // Updates flow credits into appropriate register
        //  FC_SEL Options
        localparam      RXAVAIL = 3'b000;// Receiver flow control credits available
        localparam      TXAVAIL = 3'b100;// Transmit flow control credits available


        // Other control module parameters/registers for necessary control
        // oeprations.
        reg [1:0]       current;
        reg [1:0]       next;
        reg             bridge_ready;
        reg [7:0]       Tx_fc_ph;
        reg [11:0]      Tx_fc_pd;
        reg [7:0]       Tx_fc_nph;
        reg [11:0]      Tx_fc_npd;
        reg [7:0]       Tx_fc_cplh;
        reg [11:0]      Tx_fc_cpld;


        // Set reset value for system
        //  Ctrl_RST (user_reset_out is active high, so it is asserted when
        //  a reset is required.  Therefore, we will use active low for all
        //  module resets so the reset in the control module will just be
        //  inverted.
        assign Ctrl_Bridge_RST = ~Ctrl_RST;


        // Set ready state for the rest of the bridge dependent on
        //  Ctrl_Link_Up and Ctrl_RST.  Ctrl_Link_Up should be asserted and
        //  Ctrl_RST should be deasserted before anything in the module should
        //  begin working
        always @(Ctrl_Link_Up, Ctrl_RST) begin
                if (Ctrl_Link_Up & !Ctrl_RST)   begin bridge_ready = 1'b1; end  // Bridge can operate
                else                            begin bridge_ready = 1'b0; end  // Bridge should be idle
        end


        // Set up all of the buffer values for processing packets
        //  Control should signal that it is not ok to transmit a given packet
        //  type once less than one maximum size packet can fit.
        


        // Set ready logic for the signals going to each of the bridge modules
        assign Ctrl_Rx_Ready    = bridge_ready; // ****** This needs more once FC is set up
        assign Ctrl_Tx_Ready    = bridge_ready; // ****** This needs more once FC is set up
        assign Ctrl_OCP_Ready   = bridge_ready; // This is good to go

       
        // Initialize Flow Credit Select register
        initial begin
                Ctrl_fc_sel = 3'b100;   // Set to request Tx available buffer space
        end
        
        
        // Clock in the value for each of the buffers
        always @(Ctrl_CLK) begin
               Tx_fc_ph         = Ctrl_fc_pd;
               Tx_fc_pd         = Ctrl_fc_pd;
               Tx_fc_nph        = Ctrl_fc_nph;
               Tx_fc_npd        = Ctrl_fc_npd;
               Tx_fc_cplh       = Ctrl_fc_cplh;
               Tx_fc_cpld       = Ctrl_fc_cpld;
        end
end module
