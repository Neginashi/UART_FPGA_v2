// =================================================================================================
// RTL Header
// =================================================================================================
`timescale 1ns / 1ps

module FPGA_TOP(
    // board clock & reset signals
    input   wire                        clk_50m                                 , // (i) FPGA osc clock 50MHz
    input   wire                        rst_n                                   , // (i) FPGA reset (Low-active)

    // uart in/out
    input   wire                        uart_in                                 , // (i) UART Rx Port
    output  wire                        uart_out                                  // (o) UART Tx Port
    );

    // -------------------------------------------------------------------------
    // Internal Signal Definition
    // -------------------------------------------------------------------------
    // clock & reset
    wire                                s_clk_50m                               ; // System Clk
    reg         [31:0]                  r_sys_rst                               ; // Reset 32 clks
    wire                                s_sys_rst                               ; // System Reset(Active High)
    wire                                s_rst                                   ; // ~rst_n

    //UART_RX
    wire        [7:0]                   s_uart_rx_out                           ; // uart rx data out
    wire                                s_uart_rx_done                          ; // uart rx data done

    //UART_DEC;
    wire        [3:0]                   s_uart_dec_out                          ; // uart dec data
    wire                                s_uart_dec_done                         ; // uart dec done
    wire                                s_uart_dec_write                        ; // uart dec write
    wire                                s_uart_dec_read                         ; // uart dec read
    wire                                s_uart_dec_space                        ; // uart dec space
    wire                                s_uart_dec_enter_cr                     ; // uart dec enter cr
    wire                                s_uart_dec_enter_lf                     ; // uart dec enter lf
    wire                                s_uart_dec_fail                         ; // uart dec fail

    // UART_CTRL
    wire                                s_uart_ctrl_read                        ; // uart ctrl read
    wire                                s_uart_ctrl_write                       ; // uart ctrl write

    wire        [31:0]                  s_uart_ctrl_data                        ; // uart ctrl data out
    wire        [7:0]                   s_uart_ctrl_addr                        ; // uart ctrl address out

    wire                                s_uart_ctrl_o                           ; // O signal
    wire                                s_uart_ctrl_k                           ; // K signal

    wire                                s_uart_ctrl_f                           ; // F signal
    wire                                s_uart_ctrl_a                           ; // A signal
    wire                                s_uart_ctrl_i                           ; // I signal
    wire                                s_uart_ctrl_l                           ; // L signal

    wire                                s_uart_ctrl_num                         ; // number signal
    wire        [3:0]                   s_uart_ctrl_data_tx                     ; // uart ctrl data

    wire                                s_uart_ctrl_enter                       ; // enter signal
    wire                                s_uart_ctrl_right                       ; // right signal

    // UART_REG
    wire                                s_uart_reg_read_out                     ; // uart reg read
    wire                                s_uart_reg_write_out                    ; // uart reg write
    wire        [31:0]                  s_uart_reg_data_out                     ; // uart reg data

    // UART_ENC
    wire                                s_uart_enc_start_out                    ; // uart enc start
    wire        [7:0]                   s_uart_enc_data_out                     ; // uart enc data


// =============================================================================
// RTL Body
// =============================================================================

    // -------------------------------------------------------------------------
    // Clock & reset module Inst.
    // -------------------------------------------------------------------------
    BUFG  U_CLK_50M (
        .I                              ( clk_50m               ),
        .O                              ( s_clk_50m             )
    );

    // -------------------------------------------------------------------------
    // System Reset(Active High)
    // -------------------------------------------------------------------------
    assign s_rst        = ~rst_n ;

    always @(posedge s_clk_50m or posedge s_rst) begin
        if (s_rst) begin
            r_sys_rst <= 32'hFFFF_FFFF ;
        end else begin
            r_sys_rst <= { r_sys_rst[30:0], 1'b0 } ;
        end
    end

    assign s_sys_rst    = r_sys_rst[31] ;

    // -------------------------------------------------------------------------
    // UART_RX module Inst.
    // -------------------------------------------------------------------------
    UART_RX UART_RX(
        // clock & reset
        .clk                            ( s_clk_50m             ),
        .rst                            ( s_sys_rst             ),

        .uart_in                        ( uart_in               ),

        //output
        .uart_rx_out                    ( s_uart_rx_out         ),              // uart rx 8 bits data out
        .uart_rx_done                   ( s_uart_rx_done        )               // uart rx data done
        //.uart_rx_err                    (s_rx_out_err)
        );

    // -------------------------------------------------------------------------
    // UART_DEC module Inst.
    // -------------------------------------------------------------------------
    UART_DEC UART_DEC(
        // clock & reset
        .clk                            ( s_clk_50m             ),
        .rst                            ( s_sys_rst             ),

        .uart_rx_done                   ( s_uart_rx_done        ),
        .uart_rx_out                    ( s_uart_rx_out         ),

        // UART_DEC data
        .uart_dec_out                   ( s_uart_dec_out        ),              // uart dec 4 bits data
        .uart_dec_done                  ( s_uart_dec_done       ),              // uart dec done

        // UART_DEC state
        .uart_dec_write                 ( s_uart_dec_write      ),              // uart dec write
        .uart_dec_read                  ( s_uart_dec_read       ),              // uart dec read
        .uart_dec_fail                  ( s_uart_dec_fail       ),              // uart dec fail

        // UART_DEC signal
        .uart_dec_space                 ( s_uart_dec_space      ),              // uart dec space
        .uart_dec_enter_cr              ( s_uart_dec_enter_cr   ),              // uart dec enter cr
        .uart_dec_enter_lf              ( s_uart_dec_enter_lf   )               // uart dec enter lf
        );

    // -------------------------------------------------------------------------
    // UART_CTRL module Inst.
    // -------------------------------------------------------------------------
    UART_CTRL UART_CTRL(
        // clock & reset
        .clk                            ( s_clk_50m             ),
        .rst                            ( s_sys_rst             ),

        // UART_DEC
        .uart_dec_out                   ( s_uart_dec_out        ),
        .uart_dec_done                  ( s_uart_dec_done       ),
        .uart_dec_write                 ( s_uart_dec_write      ),
        .uart_dec_read                  ( s_uart_dec_read       ),
        .uart_dec_space                 ( s_uart_dec_space      ),
        .uart_dec_enter_cr              ( s_uart_dec_enter_cr   ),
        .uart_dec_enter_lf              ( s_uart_dec_enter_lf   ),
        .uart_dec_fail                  ( s_uart_dec_fail       ),

        // UART_REG
        .uart_reg_read_out              ( s_uart_reg_read_out   ),
        .uart_reg_write_out             ( s_uart_reg_write_out  ),
        .uart_reg_data_out              ( s_uart_reg_data_out   ),

        // UART_TX
        .uart_ctrl_read                 ( s_uart_ctrl_read      ),              // uart ctrl read
        .uart_ctrl_write                ( s_uart_ctrl_write     ),              // uart ctrl write
        .uart_ctrl_data                 ( s_uart_ctrl_data      ),              // uart ctrl 32 bits data out
        .uart_ctrl_addr                 ( s_uart_ctrl_addr      ),              // uart ctrl 8 bits address out

        // UART_ENC
        // OK signal
        .uart_ctrl_o                    ( s_uart_ctrl_o         ),              // O signal
        .uart_ctrl_k                    ( s_uart_ctrl_k         ),              // K signal

        // FAIL signal
        .uart_ctrl_f                    ( s_uart_ctrl_f         ),              // F signal
        .uart_ctrl_a                    ( s_uart_ctrl_a         ),              // A signal
        .uart_ctrl_i                    ( s_uart_ctrl_i         ),              // I signal
        .uart_ctrl_l                    ( s_uart_ctrl_l         ),              // L signal

        // DATA signal
        .uart_ctrl_num                  ( s_uart_ctrl_num       ),              // number signal
        .uart_ctrl_data_tx              ( s_uart_ctrl_data_tx   ),              // uart ctrl 4 bits data

        // RESET signal
        .uart_ctrl_enter                ( s_uart_ctrl_enter     ),              // enter signal
        .uart_ctrl_right                ( s_uart_ctrl_right     )               // right signal
        );
    // -------------------------------------------------------------------------
    // UART_REG module Inst.
    // -------------------------------------------------------------------------
    UART_REG UART_REG(
        // clock & reset
        .clk                            ( s_clk_50m             ),
        .rst                            ( s_sys_rst             ),

        // UART_CTRL state
        .uart_ctrl_read                 ( s_uart_ctrl_read      ),
        .uart_ctrl_write                ( s_uart_ctrl_write     ),

        // UART_CTRL data
        .uart_ctrl_data                 ( s_uart_ctrl_data      ),
        .uart_ctrl_addr                 ( s_uart_ctrl_addr      ),

        // UART_DEC state
        .uart_reg_read_out              ( s_uart_reg_read_out   ),              // uart reg read
        .uart_reg_write_out             ( s_uart_reg_write_out  ),              // uart reg write
        .uart_reg_data_out              ( s_uart_reg_data_out   )               // uart reg 32 bits data
        );

    // -------------------------------------------------------------------------
    // UART_ENC module Inst.
    // -------------------------------------------------------------------------
    UART_ENC UART_ENC(
        // clock & reset
        .clk                            ( s_clk_50m             ),
        .rst                            ( s_sys_rst             ),

        // OK signal
        .uart_ctrl_o                    ( s_uart_ctrl_o         ),
        .uart_ctrl_k                    ( s_uart_ctrl_k         ),

        // FAIL signal
        .uart_ctrl_f                    ( s_uart_ctrl_f         ),
        .uart_ctrl_a                    ( s_uart_ctrl_a         ),
        .uart_ctrl_i                    ( s_uart_ctrl_i         ),
        .uart_ctrl_l                    ( s_uart_ctrl_l         ),

        // DATA signal
        .uart_ctrl_num                  ( s_uart_ctrl_num       ),
        .uart_ctrl_data_tx              ( s_uart_ctrl_data_tx   ),

        // RESET signal
        .uart_ctrl_enter                ( s_uart_ctrl_enter     ),
        .uart_ctrl_right                ( s_uart_ctrl_right     ),

        // output
        .uart_enc_start_out             ( s_uart_enc_start_out  ),              // uart enc start
        .uart_enc_data_out              ( s_uart_enc_data_out   )               // uart enc 8 bits data
        );

    // -------------------------------------------------------------------------
    // UART_TX module Inst.
    // -------------------------------------------------------------------------
    UART_TX UART_TX(
        // clock & reset
        .clk                            ( s_clk_50m             ),
        .rst                            ( s_sys_rst             ),

        .uart_enc_start_out             ( s_uart_enc_start_out  ),
        .uart_enc_data_out              ( s_uart_enc_data_out   ),

        //output
        .uart_out                       ( uart_out              )
        );

endmodule
