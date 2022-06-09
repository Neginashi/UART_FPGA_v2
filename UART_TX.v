`timescale 1ns / 1ps

module UART_TX (
    // system signals
    input   wire                        clk                                     , // (i) clock
    input   wire                        rst                                     , // (i) reset (high-active)

    input   wire                        uart_enc_start_out                      , // (i) UART_TX start
    input   wire[7:0]                   uart_enc_data_out                       , // (i) UART_TX data in

    output  wire                        uart_out                                  // (o) UART_TX Port
    );

    // -------------------------------------------------------------
    // Parameter definition
    // -------------------------------------------------------------
    // STATEs of STATE machine
    parameter                           P_IDLE                  = 4'b0001       ; // idle
    parameter                           P_START_BIT             = 4'b0010       ; // start bit
    parameter                           P_DATA_BITS             = 4'b0100       ; // data bits
    parameter                           P_STOP_BIT              = 4'b1000       ; // stop bit

    //count
    parameter                           P_BIT_CNT               = 9'd433        ; // bit count
    parameter                           P_STOP_CNT              = 10'd866       ; // stop count

    // -------------------------------------------------------------
    // Internal signal definition
    // -------------------------------------------------------------
    reg         [3:0]                   r_state                                 ; // FSM state

    reg         [7:0]                   r_data_buf                              ; // UART_TX data buffer

    reg         [3:0]                   r_bit_idx                               ; // bit index
    reg         [8:0]                   r_clk_cnt                               ; // clock count
    reg         [9:0]                   r_stop_cnt                              ; // stop count

    reg                                 r_out                                   ; // output register

// =============================================================================
// RTL Body
// =============================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_data_buf   <= 'b0;
        end else begin
            if (uart_enc_start_out) begin
                r_data_buf   <= uart_enc_data_out;
            end
        end
    end

    //FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_state     <= P_IDLE;
        end else begin
            case (r_state)

                default: begin
                    r_state <= P_IDLE;
                end

                // idle
                P_IDLE: begin
                    if (uart_enc_start_out) begin
                        r_state <= P_START_BIT;
                    end
                end

                //start bit
                P_START_BIT: begin
                    r_state <= P_DATA_BITS;
                end

                //data bits
                P_DATA_BITS: begin
                    if (r_clk_cnt == P_BIT_CNT) begin
                        if (r_bit_idx == 4'b1000) begin
                            r_state <= P_STOP_BIT;
                        end
                    end
                end

                //stop bit
                P_STOP_BIT: begin
                    if (r_stop_cnt == P_STOP_CNT) begin
                        r_state <= P_IDLE;
                    end
                end

            endcase
        end
    end

    //send
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_out   <= 1'b1;
        end else begin
            if (r_state == P_START_BIT) begin
                r_out   <= 1'b0;
            end else if (r_state == P_DATA_BITS) begin
                if (r_bit_idx <= 4'b111) begin
                    if (r_clk_cnt == P_BIT_CNT) begin
                        r_out   <= r_data_buf[r_bit_idx];
                    end
                end else begin
                    r_out   <= r_out;
                end
            end else if (r_state == P_STOP_BIT) begin
                r_out   <= 1'b1;
            end
        end
    end

    //data bit counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_clk_cnt   <= 9'b0;
        end else begin
            if (r_state == P_DATA_BITS) begin
                if (r_clk_cnt == P_BIT_CNT) begin                               //wait 1 bit low wave as start bit
                    r_clk_cnt   <= 9'b0;
                end else begin
                    r_clk_cnt   <= r_clk_cnt + 9'b1;
                end
            end else begin
                r_clk_cnt   <= 9'b0;
            end
        end
    end

    //stop bit counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_stop_cnt  <= 10'b0;
        end else begin
            if (r_state == P_STOP_BIT) begin
                if (r_stop_cnt == P_STOP_CNT) begin                             //stop 2 bits
                    r_stop_cnt  <= 10'b0;
                end else begin
                    r_stop_cnt  <= r_stop_cnt + 10'b1;
                end
            end else begin
                r_stop_cnt  <= 10'b0;
            end
        end
    end

    //bit index
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_bit_idx   <= 4'b0;
        end else begin
            if (r_state == P_DATA_BITS) begin
                if (r_clk_cnt == P_BIT_CNT) begin
                    if (r_bit_idx == 4'b1000) begin
                        r_bit_idx   <= 4'b0;
                    end else begin
                        r_bit_idx   <= r_bit_idx + 1'b1;
                    end
                end
            end else begin
                r_bit_idx   <= 4'b0;
            end
        end
    end

    assign uart_out = r_out;

endmodule