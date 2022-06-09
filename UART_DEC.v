`timescale 1ns / 1ps

module UART_DEC (
    // system signals
    input   wire                        clk                                     , // (i) clock
    input   wire                        rst                                     , // (i) reset (high-active)

    // UART_DEC
    input   wire                        uart_rx_done                            , // (i) UART_DEC start
    input   wire[7:0]                   uart_rx_out                             , // (i) UART_DEC data in

    // UART_DEC state
    output  wire                        uart_dec_write                          , // (o) UART_DEC is write
    output  wire                        uart_dec_read                           , // (o) UART_DEC is read
    output  wire                        uart_dec_fail                           , // (o) UART_DEC fail

    // UART_DEC ignal
    output  wire                        uart_dec_space                          , // (o) signal spcae
    output  wire                        uart_dec_enter_cr                       , // (o) signal enter cr
    output  wire                        uart_dec_enter_lf                       , // (o) signal enter lf

    // UART_DEC data
    output  wire                        uart_dec_done                           , // (o) UART_DEC done
    output  wire[3:0]                   uart_dec_out                              // (o) UART_DEC data out
    );

    // -------------------------------------------------------------
    // Internal signal definition
    // -------------------------------------------------------------
    reg                                 r_write                                 ; // write register
    reg                                 r_read                                  ; // read register
    reg                                 r_space                                 ; // space register
    reg                                 r_enter_cr                              ; // enter cr register
    reg                                 r_enter_lf                              ; // enter lf register

    reg                                 r_done                                  ; // UART_DEC done register
    reg                                 r_fail                                  ; // UART_DEC fail register

    reg         [3:0]                   r_data_out                              ; // UART_DEC output register

// =============================================================================
// RTL Body
// =============================================================================
    //decoding
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_data_out  <= 4'h0;
            r_done      <= 1'b0;
            r_write     <= 1'b0;
            r_read      <= 1'b0;
            r_space     <= 1'b0;
            r_enter_cr  <= 1'b0;
            r_enter_lf  <= 1'b0;
            r_fail      <= 1'b0;
        end else if (uart_rx_done) begin
            case ( uart_rx_out )
                8'h30: begin r_data_out[3:0] <= 4'h0; end
                8'h31: begin r_data_out[3:0] <= 4'h1; end
                8'h32: begin r_data_out[3:0] <= 4'h2; end
                8'h33: begin r_data_out[3:0] <= 4'h3; end
                8'h34: begin r_data_out[3:0] <= 4'h4; end
                8'h35: begin r_data_out[3:0] <= 4'h5; end
                8'h36: begin r_data_out[3:0] <= 4'h6; end
                8'h37: begin r_data_out[3:0] <= 4'h7; end
                8'h38: begin r_data_out[3:0] <= 4'h8; end
                8'h39: begin r_data_out[3:0] <= 4'h9; end
                8'h41: begin r_data_out[3:0] <= 4'hA; end
                8'h42: begin r_data_out[3:0] <= 4'hB; end
                8'h43: begin r_data_out[3:0] <= 4'hC; end
                8'h44: begin r_data_out[3:0] <= 4'hD; end
                8'h45: begin r_data_out[3:0] <= 4'hE; end
                8'h46: begin r_data_out[3:0] <= 4'hF; end
                8'h57: begin r_write         <= 1'b1; end
                8'h52: begin r_read          <= 1'b1; end
                8'h20: begin r_space         <= 1'b1; end
                8'h0D: begin r_enter_cr      <= 1'b1; end
                8'h0A: begin r_enter_lf      <= 1'b1; end
                default: begin r_fail        <= 1'b1; end
            endcase
            r_done <= 1'b1;
        end else begin
            r_data_out  <= 4'h0;
            r_done      <= 1'b0;
            r_write     <= 1'b0;
            r_read      <= 1'b0;
            r_space     <= 1'b0;
            r_enter_cr  <= 1'b0;
            r_enter_lf  <= 1'b0;
            r_fail      <= 1'b0;
        end
    end

    assign uart_dec_out         = r_data_out;
    assign uart_dec_done        = r_done;
    assign uart_dec_write       = r_write;
    assign uart_dec_read        = r_read;
    assign uart_dec_space       = r_space;
    assign uart_dec_enter_cr    = r_enter_cr;
    assign uart_dec_enter_lf    = r_enter_lf;
    assign uart_dec_fail        = r_fail;

endmodule