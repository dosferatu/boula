/* This module is the test bench for the control module */



module control_tb();

        // Set up needed registers/nets for hooking up the control module
        //  Register
        reg [7:0]       fc_ph;  // Posted Header
        reg [11:0]      fc_pd;  // Posted Data
        reg [7:0]       fc_nph; // Non-posted Header
        reg [11:0]      fc_npd; // Non-posted Data
        reg [7:0]       fc_cplh;// Completion Header
        reg [11:0]      fc_cpld;// Completion Data



        // initial clock
