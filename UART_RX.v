`timescale 1ns / 1ps

module UART_RX(

    // system signals
    input   wire                        clk                                     , // (i) clock
    input   wire                        rst                                     , // (i) reset (high-active)

    // UART Interface
    input   wire                        uart_in                                 , // (i) UART Rx Port

    output  wire[7:0]                   uart_rx_out                             , // (o) RX Data
    output  wire                        uart_rx_done                            , // (o) RX Done
    output  wire                        uart_rx_err                               // (o) RX Error
    );

    // -------------------------------------------------------------
    // Parameter definition
    // -------------------------------------------------------------
    parameter                           P_BIT_CNT               = 9'd433        ; // 50MHz / baudrate
    parameter                           P_START_CNT             = P_BIT_CNT / 2 ; // detect middle of wave
    parameter                           P_BIT_IDX               = 4'b1000       ; // 10 bits =   1   +   8   +   1
                                                                                  //           start    data    stop
    // STATEs of STATE MACHINE
    parameter                           P_IDLE                  = 3'b000        ; // idle
    parameter                           P_START                 = 3'b001        ; // start
    parameter                           P_DATA_BITS             = 3'b010        ; // data
    parameter                           P_STOP_BIT              = 3'b011        ; // stop

    // -------------------------------------------------------------
    // Internal signal definition
    // -------------------------------------------------------------
    reg         [2:0]                   r_state                                 ; // STATE_FSM

    reg         [3:0]                   r_input_buf                             ; // UART_RX input register
    reg         [7:0]                   r_data                                  ; // UART_RX input register

    reg                                 r_err_stop                              ; // stop error
    reg                                 r_err_start                             ; // start error

    reg         [7:0]                   r_start_cnt                             ; // start bit count
    reg         [8:0]                   r_bit_cnt                               ; // bit count
    reg         [8:0]                   r_stop_cnt                              ; // stop bit count
    reg         [3:0]                   r_bit_idx                               ; // bit index

    reg         [7:0]                   r_rx_out                                ; // UART_RX output register
    reg                                 r_rx_done                               ; // UART_RX done

// =============================================================================
// RTL Body
// =============================================================================
    //             |X| < |X| < |X| < |X|
    //                                ^
    //  ...   X     X     X     X     X     X   ...
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_input_buf <= 4'b0;
        end else begin
            r_input_buf <= { r_input_buf[3:0], uart_in };
        end
    end

    //FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_state <= P_IDLE;
        end else begin
            case ( r_state )

                //idle
                //             |1| < |0| < |X| < |X|
                //                                ^
                //  ...   X     1     0     X     X     X   ...
                P_IDLE      : begin
                    if (r_input_buf[3:2] == 2'b10) begin
                        r_state <= P_START;
                    end
                end

                //start bit
                P_START     : begin
                    if (r_start_cnt == P_START_CNT) begin
                        if (!r_input_buf[2]) begin
                            r_state <= P_DATA_BITS;
                        end else if (r_err_start) begin
                            r_state <= P_IDLE;
                        end
                    end
                end

                //data bits
                P_DATA_BITS : begin
                    if (r_bit_idx == P_BIT_IDX) begin
                        r_state <= P_STOP_BIT;
                    end
                end

                //stop bit
                P_STOP_BIT  : begin
                    if (r_stop_cnt == P_BIT_CNT) begin
                        r_state <= P_IDLE;
                    end else if (r_err_stop) begin
                        r_state <= P_IDLE;
                    end
                end

                default     : begin
                    r_state <= P_IDLE;
                end

            endcase
        end
    end

    //start state
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_err_start <= 1'b0;
        end else begin
            if (r_state == P_START) begin
                if (r_start_cnt == P_START_CNT && !r_input_buf[2]) begin        // middle of start bit is low
                    r_err_start <= 1'b0;
                end else begin
                    r_err_start <= 1'b1;
                end
            end else begin
                r_err_start <= 1'b0;
            end
        end
    end

    //start counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_start_cnt <= 8'b0;
        end else begin
            if (r_state == P_START) begin
                if (r_start_cnt == P_START_CNT) begin
                    r_start_cnt <= 8'b0;
                end else begin
                    r_start_cnt <= r_start_cnt + 8'b1;
                end
            end else begin
                r_start_cnt <= 8'b0;
            end
        end
    end

    //data state
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_data  <= 8'b0;
        end else if (r_state == P_DATA_BITS) begin
            if (r_bit_idx == P_BIT_IDX) begin
                r_data  <= r_data;
            end else begin
                if (r_bit_cnt == P_BIT_CNT) begin
                    r_data <= { r_input_buf[2], r_data[7:1] };
                end else begin
                    r_data  <= r_data;
                end
            end
        end else if (r_state == P_IDLE) begin
            r_data  <= 8'b0;
        end
    end

    //bit counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_bit_cnt   <= 9'b0;
        end else begin
            if (r_state == P_DATA_BITS) begin
                if (r_bit_cnt == P_BIT_CNT) begin
                    r_bit_cnt   <= 9'b0;
                end else begin
                    r_bit_cnt   <= r_bit_cnt + 9'b1;
                end
            end
        end
    end

    //index counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_bit_idx   <= 4'b0;
        end else begin
            if (r_state == P_DATA_BITS && r_bit_idx == P_BIT_IDX) begin         // 8 bits data
                r_bit_idx   <= 4'b0;
            end else if (r_bit_cnt == P_BIT_CNT) begin
                r_bit_idx   <= r_bit_idx + 4'b1;
            end
        end
    end

    //stop state
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_err_stop  <= 1'b0;
            r_rx_out    <= 9'b0;
        end else begin
            if (r_state == P_STOP_BIT && r_stop_cnt == P_BIT_CNT) begin
                if (r_input_buf[2]) begin                                       // middle of stop bit is high
                    r_err_stop  <= 1'b0;
                    r_rx_out    <= r_data;
                end else begin
                    r_err_stop  <= 1'b1;
                    r_rx_out    <= 8'b0;
                end
            end else if (r_state == P_IDLE) begin
                r_err_stop  <= 1'b0;
                r_rx_out    <= 8'b0;
            end
        end
    end

    //stop counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_stop_cnt  <= 9'b0;
        end else begin
            if (r_state == P_STOP_BIT) begin
                if (r_stop_cnt == P_BIT_CNT) begin
                    r_stop_cnt <= 9'b0;
                end else begin
                    r_stop_cnt  <= r_stop_cnt + 9'b1;
                end
            end else begin
                r_stop_cnt  <= 9'b0;
            end
        end
    end

    //rx done
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_rx_done   <= 1'b0;
        end else begin
            if (r_state == P_STOP_BIT && r_stop_cnt == P_BIT_CNT && r_input_buf[2]) begin
                r_rx_done   <= 1'b1;
            end else begin
                r_rx_done   <= 1'b0;
            end
        end
    end

    assign uart_rx_out  = r_rx_out;
    assign uart_rx_done = r_rx_done;
    assign uart_rx_err  = r_err_stop || r_err_start;

endmodule