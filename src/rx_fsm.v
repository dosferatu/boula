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
    output reg rx_heaer_ready,
    /*}}}*/

    // Tx AXI FIFO/*{{{*/
    output wire tx_fifo_ 
    );

    // Declarations/*{{{*/

    // Parameters for parameterization of module
    parameter keep_width = 8;

    // State encodings
    localparam IDLE = 2'b00;
    localparam H1   = 2'b01;
    localparam H2   = 2'b10;
    localparam DATA = 2'b11;
    
    // Format encoding for PCI Express 2.0
    localparam MRD    = 3'b000; // 3DW header, no data
    localparam MRDLK  = 3'b001; // 4DW header, no data
    localparam MWR    = 3'b010; // 3DW header, with data
    localparam MWR2   = 3'b011; // 4DW header, with data
    localparam PRFX   = 3'b100; // TLP Prefix

    // State Registers
    reg [3:0] state;
    reg [3:0] next;
    /*}}}*/


    // Begin FSM Blocks/*{{{*/
    // State transition logic/*{{{*/
    always @(posedge clk) begin
        if (reset) begin
            state <= 4'b0;              // Reset state value to zero
            state[IDLE] <= 1'b1;        // Set to IDLE state
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
            state[IDLE]: begin
                if (rx_header_valid)    next[H1]    <= 1'b1;    // TLP ready to be received from AXI-4 Stream bus
                else                    next[IDLE]  <= 1'b1;    // Not valid so stay
            end

            state[H1]: begin
                if (rx_header_valid)    next[H2]    <= 1'b1;    // Calculate the request type
                else                    next[H1]    <= 1'b1;    // Not valid so stay
            end

            state[H2]: begin
                if (rx_header_valid && isdata)
                                        next[DATA]  <= 1'b1;    // Header complete and data present (write op)
                else if(rx_header_valid && ~isdata)
                                        next[IDLE]  <= 1'b1;    // Header complete and no data (read op)
                else                    next[H2]    <= 1'b1;    // Not valid so stay
            end

            state[DATA]: begin
                if (rx_header_valid && rx_header_last)
                                        next[IDLE]  <= 1'b1;    // Written last data, finish operation
                else                    next[DATA]  <= 1'b1;    // Still data left to transmit
            end

            default:                    next[IDLE] <= 1'b1;     // If nothing matches return to default
        endcase
    end
    /*}}}*/

    // Output logic/*{{{*/
    always @(posedge clk) begin
        // RESET/*{{{*/
        if (reset) begin
            //  input
            m_aclk              <= 1'b0;
            m_axis_tready       <= 1'b0;

            // OCP 2.2 Interface/*{{{*/

            address             <= {`addr_wdth{1'b0}};
            enable              <= 1'b0;
            burst_seq           <= INCR;
            burst_single_req    <= 1'b0;
            burst_length        <= 1'b1;
            data_valid          <= 1'b0;
            read_request        <= 1'b0;
            ocp_reset           <= 1'b0;
            sys_clk             <= 1'b0;
            write_data          <= {`data_wdth{1'b0}};
            write_request       <= 1'b0;
            writeresp_enable    <= 1'b0;
            /*}}}*/

            // Bridge internals/*{{{*/

            header_counter <= 2'b0;
            data_counter <= 2'b0;
            tlp_data_length <= 10'b0;
            tlp_format <= 3'b0;
            tlp_header_length <= 2'b0;
            tlp_type <= 5'b0;
            tlp_header_0 <= 64'b0;
            tlp_header_1 <= 64'b0;
            tlp_header_2 <= 64'b0;
            tlp_header_3 <= 64'b0;
        end
        /*}}}*/
        /*}}}*/

        else begin
            case (1'b1)
                // IDLE/*{{{*/
                next[IDLE]: begin
                    // AXI FIFO input
                    m_aclk          <= 1'b0;
                    m_axis_tready   <= 1'b1;  // Ready to receive on the AXI-4 Stream Bus

                    // OCP 2.2 Interface/*{{{*/

                    address             <= {`addr_wdth{1'b0}};
                    enable              <= 1'b1;
                    burst_seq           <= INCR;
                    burst_single_req    <= 1'b0;
                    burst_length        <= 1'b1;
                    data_valid          <= 1'b0;
                    read_request        <= 1'b0;
                    ocp_reset           <= 1'b0;
                    sys_clk             <= 1'b0;
                    write_data          <= {`data_wdth{1'b0}};
                    write_request       <= 1'b0;
                    writeresp_enable    <= 1'b0;
                    /*}}}*/

                    // Bridge internals/*{{{*/

                    header_counter <= 2'b0;
                    data_counter <= 2'b0;
                    tlp_data_length <= 10'b0;
                    tlp_format <= 3'b0;
                    tlp_header_length <= 2'b0;
                    tlp_type <= 5'b0;
                    tlp_header_0 <= 64'b0;
                    tlp_header_1 <= 64'b0;
                    tlp_header_2 <= 64'b0;
                    tlp_header_3 <= 64'b0;
                end
                /*}}}*/
                /*}}}*/

                // REQUEST/*{{{*/
                next[REQUEST]: begin
                    // AXI FIFO input
                    m_aclk              <= 1'b0;
                    m_axis_tready <= 1'b0;  // Notify the AXI FIFO we are ready for more data

                    // OCP 2.2 Interface/*{{{*/

                    address             <= {`addr_wdth{1'b0}};
                    enable              <= 1'b1;
                    burst_seq           <= INCR;
                    burst_single_req    <= 1'b0;
                    burst_length        <= 1'b1;
                    data_valid          <= 1'b0;
                    read_request        <= 1'b0;
                    ocp_reset           <= 1'b0;
                    sys_clk             <= 1'b0;
                    write_data          <= {`data_wdth{1'b0}};
                    write_request       <= 1'b0;
                    writeresp_enable    <= 1'b0;
                    /*}}}*/

                    // Bridge internals/*{{{*/

                    case(m_axis_tdata[7:5])
                        MRD: begin
                            tlp_header_length <= 2'b10;
                        end

                        MRDLK: begin
                            tlp_header_length <= 2'b11;
                        end

                        MWR: begin
                            tlp_header_length <= 2'b10;
                        end

                        MWR2: begin
                            tlp_header_length <= 2'b11;
                        end

                        PRFX: begin
                            tlp_header_length <= 2'b10;
                        end

                        default: begin
                            tlp_header_length <= 2'b0;
                        end
                    endcase

                    data_counter <= 10'b0;
                    header_counter <= 2'b0;
                    tlp_data_length <= m_axis_tdata[31:24];
                    tlp_format <= m_axis_tdata[7:5];
                    tlp_type <= m_axis_tdata[4:0];
                    tlp_header_0 <= m_axis_tdata;
                    tlp_header_1 <= 64'b0;
                    tlp_header_2 <= 64'b0;
                    tlp_header_3 <= 64'b0;
                end
                /*}}}*/
                /*}}}*/

                // PROC/*{{{*/
                next[PROC]: begin
                    // AXI FIFO input
                    //m_aclk              <= 1'b0;
                    m_axis_tready       <= 1'b1;

                    // OCP 2.2 Interface/*{{{*/

                    address             <= {`addr_wdth{1'b0}};
                    enable              <= 1'b1;
                    burst_seq           <= INCR;
                    burst_single_req    <= 1'b0;
                    burst_length        <= 1'b1;
                    data_valid          <= 1'b0;
                    read_request        <= 1'b0;
                    ocp_reset           <= 1'b0;
                    sys_clk             <= 1'b0;
                    write_data          <= {`data_wdth{1'b0}};
                    write_request       <= 1'b0;
                    writeresp_enable    <= 1'b0;
                    /*}}}*/

                    // Bridge internals/*{{{*/

                    data_counter <= 10'b0;
                    header_counter <= m_axis_tvalid ? header_counter + 1'b1 : data_counter;
                    tlp_data_length <= tlp_data_length;
                    tlp_format <= m_axis_tdata[7:5];
                    tlp_header_length <= tlp_header_length;
                    tlp_type <= m_axis_tdata[4:0];
                    tlp_header_0 <= m_axis_tdata;

                    /*
                    * Assign the next header packet if FIFO has valid data.
                        * If there's no valid data ready then do nothing.
                        */
                       if (m_axis_tvalid) begin
                           case (header_counter)
                               0: begin
                                   tlp_header_0 <= tlp_header_0;
                                   tlp_header_1 <= 64'b0;
                                   tlp_header_2 <= 64'b0;
                                   tlp_header_3 <= 64'b0;
                               end

                               1: begin
                                   tlp_header_0 <= tlp_header_0;
                                   tlp_header_1 <= m_axis_tdata;
                                   tlp_header_2 <= 64'b0;
                                   tlp_header_3 <= 64'b0;
                               end

                               2: begin
                                   tlp_header_0 <= tlp_header_0;
                                   tlp_header_1 <= tlp_header_1;
                                   tlp_header_2 <= m_axis_tdata;
                                   tlp_header_3 <= 64'b0;
                               end

                               3: begin
                                   tlp_header_0 <= tlp_header_0;
                                   tlp_header_1 <= tlp_header_1;
                                   tlp_header_2 <= tlp_header_2;
                                   tlp_header_3 <= m_axis_tdata;
                               end

                               default: begin
                                   tlp_header_0 <= tlp_header_0;
                                   tlp_header_1 <= 64'b0;
                                   tlp_header_2 <= 64'b0;
                                   tlp_header_3 <= 64'b0;
                               end
                           endcase
                       end

                       else begin
                           tlp_header_0 <= tlp_header_0;
                           tlp_header_1 <= tlp_header_1;
                           tlp_header_2 <= tlp_header_2;
                           tlp_header_3 <= tlp_header_3;
                       end
                   end
                   /*}}}*/
                   /*}}}*/

                   // EXEC/*{{{*/
                   next[EXEC]: begin
                       // AXI FIFO input
                       m_aclk              <= 1'b0;
                       m_axis_tready       <= 1'b0;

                       // OCP 2.2 Interface/*{{{*/

                       address             <= {`addr_wdth{1'b0}};  // Set this using the base address register + counter offset
                       enable              <= 1'b1;
                       burst_seq           <= INCR;
                       burst_single_req    <= 1'b0;
                       burst_length        <= 1'b1;
                       data_valid          <= 1'b0;
                       read_request        <= ~(tlp_format & 3'b010);
                       ocp_reset           <= 1'b0;
                       sys_clk             <= 1'b0;
                       write_data          <= (write_request & m_axis_tvalid) ? m_axis_tdata : {`data_wdth{1'b0}};
                       write_request       <= tlp_format & 3'b010; // Check if bit 2 is clear in the format register
                       writeresp_enable    <= 1'b0;
                       /*}}}*/

                       // Bridge internals/*{{{*/

                       data_counter <= m_axis_tvalid ? data_counter + 1'b1 : data_counter;
                       header_counter <= 2'b0;
                       tlp_data_length <= tlp_data_length;
                       tlp_format <= tlp_format;
                       tlp_header_length <= tlp_header_length;
                       tlp_type <= tlp_type;
                       tlp_header_0 <= tlp_header_0;
                       tlp_header_1 <= tlp_header_1;
                       tlp_header_2 <= tlp_header_2;
                       tlp_header_3 <= tlp_header_3;
                   end
                   /*}}}*/
                   /*}}}*/

                   // DEFAULT/*{{{*/
                   default: begin
                       // AXI FIFO input
                       m_aclk              <= 1'b0;
                       m_axis_tready       <= 1'b0;

                       // OCP 2.2 Interface/*{{{*/

                       address             <= {`addr_wdth{1'b0}};
                       enable              <= 1'b0;
                       burst_seq           <= INCR;
                       burst_single_req    <= 1'b0;
                       burst_length        <= 1'b1;
                       data_valid          <= 1'b0;
                       read_request        <= 1'b0;
                       ocp_reset           <= 1'b0;
                       sys_clk             <= 1'b0;
                       write_data          <= {`data_wdth{1'b0}};
                       write_request       <= 1'b0;
                       writeresp_enable    <= 1'b0;
                       /*}}}*/

                       // Bridge internals/*{{{*/

                       header_counter <= 2'b0;
                       data_counter <= 10'b0;
                       tlp_data_length <= 10'b0;
                       tlp_format <= 3'b0;
                       tlp_header_length <= 2'b0;
                       tlp_type <= 5'b0;
                       tlp_header_0 <= m_axis_tdata;
                       tlp_header_1 <= 64'b0;
                       tlp_header_2 <= 64'b0;
                       tlp_header_3 <= 64'b0;
                   end
                   /*}}}*/
                   /*}}}*/
               endcase
           end
       end
       /*}}}*/
       endmodule
