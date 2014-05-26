/*
 * Rx_Header Module
 * Author: Benjamin Huntsman
 *
 * This module controls the receiving and appropriate transimission of the
 * TLP Header.  This module is instantiated in the Rx_Engine and will control
 * the loading of the TLP header into the Tx_Header_FIFO and into registers
 * that will be holding the header data for translation into OCP Signals.
 */

module rx_header_fsm(
    // Command Signals /*{{{*/
    input wire rx_header_reset,
    /*}}}*/

    // PCIe Core AXI Interface/*{{{*/
    input wire rx_header_clk,
    input wire rx_header_valid,
    input wire [keep_width - 1:0] rx_header_keep,
    input wire rx_header_last,
    output reg rx_header_ready,
    /*}}}*/

    // Tx AXI FIFO/*{{{*/
    output wire tx_header_fifo_valid,
    input  wire tx_header_fifo_ready
    /*}}}*/

    // OCP Registers/*{{{*/
    output reg [2:0] ocp_reg_ctl;
    );

    // Declarations/*{{{*/

    // Parameters for parameterization of module
    parameter keep_width = 8;

    // Control registers for flow of data through module
    reg isdata; // Indicates that data is present in the TLP
    reg is4;    // Indicates that 64 bit addressing is used so the header is 4DW, not 3DW

    // State encodings
    localparam IDLE     = 3'b000;
    localparam H1       = 3'b001;
    localparam H2       = 3'b010;
    localparam DATA3    = 3'b011;
    localparam DATA4    = 3'b100;
    
    // Format encoding for PCI Express 2.0
    localparam MRD3 = 3'b000; // 3DW header, no data
    localparam MRD4 = 3'b001; // 4DW header, no data
    localparam MWR3 = 3'b010; // 3DW header, with data
    localparam MWR4 = 3'b011; // 4DW header, with data

    // State Registers
    reg [3:0] state;
    reg [3:0] next;
    /*}}}*/


    // Begin FSM Blocks/*{{{*/
    // State transition logic/*{{{*/
    always @(posedge clk) begin
        if (reset) begin
            state <= 4'b0;          // Reset state value to zero
            state[RESET] <= 1'b1;   // Set to RESET state
        end
        else begin
            state <= next;              // Transition to next state
        end
    end
    /*}}}*/

    // Next state logic/*{{{*/
    always @(state) begin
        next <= 4'b0;

        case (1'b1)
            // IDLE/*{{{*/
            //  System Idles while waiting for valid TLP to be presented
            //  Stays until rx_header_valid and tx_header_fifo_ready asserted
            state[IDLE]: begin
                if (rx_header_valid && tx_header_fifo_ready) begin
                    next[H1]    = 1'b1; end     // TLP ready to receive
                else begin
                    next[IDLE]  = 1'b1; end     // Not valid so stay
            end
            /*}}}*/

            // H1/*{{{*/
            //  First header slice transmitted
            //  Stays unless PCIe Core holds valid high and tx header fifo is
            //  ready
            state[H1]: begin
                if (rx_header_valid && tx_header_fifo_ready) begin
                    next[H2]    = 1'b1; end     // Received first slice, move to second
                else begin 
                    next[H1]    = 1'b1; end     // Not valid so stay
            end
            /*}}}*/

            // H2/*{{{*/
            // Second header slice transmitted
            state[H2]: begin
                if (rx_header_valid && tx_header_fifo_ready && isdata) begin
                    next[DATA]  = 1'b1; end     // Header complete and data present (write op)
                else if(rx_header_valid && tx_header_fifo_ready && ~isdata) begin
                    next[IDLE]  = 1'b1; end     // Header complete and no data (read op)
                else begin 
                    next[H2]    = 1'b1; end     // Not valid so stay
            end
            /*}}}*/

            // Data transmission/*{{{*/
            // Controls transmission of data on a 96 bit shift register
            state[DATA3]: begin
                if (rx_header_valid && tx_header_fifo_ready && rx_header_last) begin
                    next[IDLE]  = 1'b1; end     // Written last data, finish operation
                else if (rx_header_valid && tx_header_fifo_ready && isdata) begin
                    next[DATA3]  = 1'b1; end     // Still data left to transmit
            end
            state[DATA4]: begin
                if (rx_header_valid && rx_header_last) begin
                    next[IDLE]  = 1'b1; end     // Written last data, finish operation
                else begin
                    next[DATA]  = 1'b1; end     // Still data left to transmit
            end
            //*}}}*/

            default: begin 
                    next[IDLE]  = 1'b1; end     // If nothing matches return to default
        endcase
    end
    /*}}}*/

    // Output logic/*{{{*/
    always @(posedge rx_header_clk) begin
        case (1'b1)
            // IDLE/*{{{*/
            //  Then it asserts rx_header_ready for transmission to begin
            next[IDLE]: begin
                rx_header_ready         = 1'b0; // Core AXI Interface - Bridge not ready
                tx_header_fifo_valid    = 1'b0; // Tx header FIFO - No data 
                ocp_reg_ctl             = 3'b0; // OCP Register Control
            end
            /*}}}*/

            // First TLP Header Slice/*{{{*/
            //  
            next[H1]: begin
                if (rx_header_valid && tx_header_fifo_ready) begin
                    // AXI Inteface/*{{{*/
                    rx_header_ready         = 1'b0;
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
                rx_header_ready         = 1'b0;
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
                rx_header_ready         = 1'b0;
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
