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
        output           Ctrl_Bridge_RST,// Signals to Bridge that a reset is needed
        output [5:0]     Ctrl_Tx_FC      // Signals for Flow Credits to transmit bridge module
        );


        // Set reset value for system
        //  Ctrl_RST (user_reset_out is active high, so it is asserted when
        //  a reset is required.  Therefore, we will use active low for all
        //  module resets so the reset in the control module will just be
        //  inverted. Also reset will be connected to the user_lnk_up signal.
        assign Ctrl_Bridge_RST = ~Ctrl_RST & Ctrl_Link_Up;


        // Set up all of the buffer values for processing packets
        //  Control should signal that it is not ok to transmit a given packet
        //  type once less than one maximum size packet can fit.
        always begin
                if (Ctrl_fc_ph [7:5] == 0)      Ctrl_Tx_FC[0] <= 0;
                        else Ctrl_Tx_FC[0] <= 1;
                if (Ctrl_fc_ph[11:10] == 0)     Ctrl_Tx_FC[1] <= 0;
                        else Ctrl_Tx_FC[1] <= 1;
                if (Ctrl_fc_nph[7:5] == 0)      Ctrl_Tx_FC[2] <= 0;
                        else Ctrl_Tx_FC[2] <= 1;
                if (Ctrl_fc_npd[11:10] == 0)    Ctrl_Tx_FC[3] <= 0;
                        else Ctrl_Tx_FC[3] <= 1;
                if (Ctrl_fc_cplh[7:5] == 0)     Ctrl_Tx_FC[4] <= 0;
                        else Ctrl_Tx_FC[4] <= 1;
                if (Ctrl_fc_cpld[11:10] == 0)   Ctrl_Tx_FC[5] <= 0;
                        else Ctrl_Tx_FC[5] <= 1;
        end

       
        // Initialize Flow Credit Select register
        initial begin
                Ctrl_fc_sel = 3'b100;   // Set to request Tx available buffer space
        end
        
end module
