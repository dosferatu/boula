/*
 * Rx_Header Module
 * Author: Benjamin Huntsman
 *
 * This module controls the receiving and appropriate transimission of the
 * TLP Header.  This module is instantiated in the Rx_Engine and will control
 * the loading of the TLP header into the Tx_Header_FIFO and into registers
 * that will be holding the header data for translation into OCP Signals.
 */

module rx_fsm(
    // Command Signals /*{{{*/
    input wire rx_reset,
    /*}}}*/

    // PCIe Core AXI Interface/*{{{*/
    input wire rx_clk,                       // clock for entire bridge
    input wire rx_valid,                     // 
    input wire [keep_width - 1:0] rx_keep,
    input wire rx_last,
    output reg rx_ready,
    /*}}}*/

    // Tx AXI FIFO/*{{{*/
    output wire tx_header_fifo_valid,
    input  wire tx_header_fifo_ready
    /*}}}*/

    // OCP Registers/*{{{*/
    input wire ocp_ready;           // Indicates that the OCP interface is ready for transmission of data
    input wire optype;              // Indicates that the header will be 4DW, not 3DW and if data is present or not
    output reg [2:0] ocp_reg_ctl;   // Controls the inputs to the OCP registers for translation and data
    );

    // Declarations/*{{{*/

    // Parameters for parameterization of module
    parameter keep_width = 8;

    // State encodings
    localparam IDLE     = 3'b000;
    localparam H1       = 3'b001;
    localparam H2       = 3'b010;
    localparam DATA3    = 3'b011;
    localparam DATA4    = 3'b100;
    localparam HOLD     = 3'b101;
   
    // State Registers
    reg [3:0] state;
    reg [3:0] next;
    /*}}}*/


    // Begin FSM Blocks/*{{{*/
    // State transition logic/*{{{*/
    always @(posedge clk) begin
        if (reset) begin
            state       <= 4'b0;        // Reset state value to zero
            state[IDLE] <= 1'b1; end    // Set to RESET state
        else begin
            state <= next; end          // Transition to next state
    end
    /*}}}*/

    // Next state logic/*{{{*/
    always @(state) begin
        next <= 4'b0;

        case (1'b1)
            // IDLE/*{{{*/
            //  System Idles while waiting for valid TLP to be presented
            //  Stays until rx_valid and tx_header_fifo_ready asserted
            state[IDLE]: begin
                if (rx_valid && tx_header_fifo_ready) begin // TLP ready to receive
                    next[H1]    = 1'b1; end     
                else begin                                  // Not valid so stay
                    next[IDLE]  = 1'b1; end     
            end
            /*}}}*/

            // H1/*{{{*/
            //  First header slice transmitted
            //  Stays unless PCIe Core holds valid high and tx header fifo is
            //  ready
            state[H1]: begin
                if (rx_valid && tx_header_fifo_ready) begin // Received first slice, move to second
                    next[H2]    = 1'b1; end     
                else begin                                  // Not valid so stay
                    next[H1]    = 1'b1; end    
            end
            /*}}}*/

            // H2/*{{{*/
            // Second header slice transmitted
            state[H2]: begin
                if (rx_valid && ocp_ready && optype[1]) begin
                    if (optype[0] == 0) begin               // Mem write 3 DW, transmit data
                        next[DATA3] = 1'b1; end
                    else begin                              // Mem write 4 DW, transmit data
                        next[DATA4] = 1'b1; end
                end
                else if (rx_valid && rx_last) begin         // Read op, only header
                    next[IDLE]  = 1'b1; end   
                else begin                                  // Not valid so stay
                    next[H2]    = 1'b1; end    
            end
            /*}}}*/

            // Data transmission/*{{{*/
            // Controls transmission of data on a 96 bit shift register
            state[DATA3]: begin
                if (rx_valid && ocp_ready && rx_last) begin // Written last data, finish operation
                    next[IDLE]  = 1'b1; end   
                else if (rx_valid && ocp_ready && ~rx_last) begin   // Still data left to transmit and ok to transmit
                    next[DATA3] = 1'b1; end   
                else begin                                  // Still not done and something isn't ready
                    next[HOLD]  = 1'b1; end   
            end
            state[DATA4]: begin
                if (rx_valid && ocp_ready && rx_last) begin // Written last data, finish operation
                    next[IDLE]  = 1'b1; end   
                else if (rx_valid && ocp_ready && ~rx_last) begin  // Still data left to transmit and ok to transmit
                    next[DATA4] = 1'b1; end   
                else begin                                  // Still not done and something isn't ready
                    next[HOLD]  = 1'b1; end   
            end
            //*}}}*/

            default: begin 
                    next[IDLE]  = 1'b1; end                 // If nothing matches return to default
        endcase
    end
    /*}}}*/

    // Output logic/*{{{*/
    always @(posedge rx_clk) begin
        case (1'b1)
            // IDLE/*{{{*/
            //  System Idles while waiting for valid TLP to be presented
            //  All outputs should be set to default
            state[IDLE]: begin
                if (rx_valid && tx_header_fifo_ready) begin // TLP ready to receive
                    end     
                else begin                                  // Not valid so stay
                    next[IDLE]  = 1'b1; end     
            end
            /*}}}*/

            // H1/*{{{*/
            //  First header slice transmitted
            //  Stays unless PCIe Core holds valid high and tx header fifo is
            //  ready
            state[H1]: begin
                if (rx_valid && tx_header_fifo_ready) begin // Received first slice, move to second
                    next[H2]    = 1'b1; end     
                else begin                                  // Not valid so stay
                    next[H1]    = 1'b1; end    
            end
            /*}}}*/

            // H2/*{{{*/
            // Second header slice transmitted
            state[H2]: begin
                if (rx_valid && ocp_ready && optype[1]) begin
                    if (optype[0] == 0) begin               // Mem write 3 DW, transmit data
                        next[DATA3] = 1'b1; end
                    else begin                              // Mem write 4 DW, transmit data
                        next[DATA4] = 1'b1; end
                end
                else if (rx_valid && rx_last) begin         // Read op, only header
                    next[IDLE]  = 1'b1; end   
                else begin                                  // Not valid so stay
                    next[H2]    = 1'b1; end    
            end
            /*}}}*/

            // Data transmission/*{{{*/
            // Controls transmission of data on a 96 bit shift register
            state[DATA3]: begin
                if (rx_valid && ocp_ready && rx_last) begin // Written last data, finish operation
                    next[IDLE]  = 1'b1; end   
                else if (rx_valid && ocp_ready && ~rx_last) begin   // Still data left to transmit and ok to transmit
                    next[DATA3] = 1'b1; end   
                else begin                                  // Still not done and something isn't ready
                    next[HOLD]  = 1'b1; end   
            end
            state[DATA4]: begin
                if (rx_valid && ocp_ready && rx_last) begin // Written last data, finish operation
                    next[IDLE]  = 1'b1; end   
                else if (rx_valid && ocp_ready && ~rx_last) begin  // Still data left to transmit and ok to transmit
                    next[DATA4] = 1'b1; end   
                else begin                                  // Still not done and something isn't ready
                    next[HOLD]  = 1'b1; end   
            end
            //*}}}*/

            default: begin 
                    next[IDLE]  = 1'b1; end                 // If nothing matches return to default
        endcase
case (1'b1)
            // IDLE/*{{{*/
            //  Then it asserts rx_ready for transmission to begin
            next[IDLE]: begin
                rx_ready         = 1'b0; // Core AXI Interface - Bridge not ready
                tx_header_fifo_valid    = 1'b0; // Tx header FIFO - No data 
                ocp_reg_ctl             = 3'b0; // OCP Register Control
            end
            /*}}}*/

            // First TLP Header Slice/*{{{*/
            //  
            next[H1]: begin
                if (rx_valid && tx_header_fifo_ready) begin
                    // AXI Inteface/*{{{*/
                    rx_ready         = 1'b0;
                    /*}}}*/

                    // Tx Header FIFO/*{{{*/
                    tx_header_fifo_valid    = 1'b0;
                    /*}}}*/

                    // OCP Register controls/*{{{*/
                ocp_reg_ctl             = 3'b0;
                /*}}}*/
            end
            /*}}}*/

            // Second TLP Header Slice/*{{{*/
            next[H2]: begin
                // AXI Inteface/*{{{*/
                rx_ready         = 1'b0;
                /*}}}*/

                // Tx Header FIFO/*{{{*/
                tx_header_fifo_valid    = 1'b0;
                /*}}}*/

                // OCP Register controls/*{{{*/
                ocp_reg_ctl             = 3'b0;
                /*}}}*/
            end
            /*}}}*/

            // Transmit data/*{{{*/
            next[DATA]: begin
                // AXI Inteface/*{{{*/
                rx_ready         = 1'b0;
                /*}}}*/

                // Tx Header FIFO/*{{{*/
                tx_header_fifo_valid    = 1'b0;
                /*}}}*/

                // OCP Register controls/*{{{*/
                ocp_reg_ctl             = 3'b0;
                /*}}}*/
            end
            /*}}}*/
           endcase
       end
   end
   /*}}}*/
   endmodule
