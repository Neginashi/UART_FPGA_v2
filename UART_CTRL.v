`timescale 1ns / 1ps

module UART_CTRL (
    // system signals
    input   wire                        clk                                     , // (i) clock
    input   wire                        rst                                     , // (i) reset (high-active)

    // UART_DEC
    input   wire[3:0]                   uart_dec_out                            , // (i) UART_DEC data in

    input   wire                        uart_dec_done                           , // (i) UART_DEC start in

    input   wire                        uart_dec_write                          , // (i) signal write
    input   wire                        uart_dec_read                           , // (i) signal read
    input   wire                        uart_dec_space                          , // (i) signal space
    input   wire                        uart_dec_enter_cr                       , // (i) signal enter cr
    input   wire                        uart_dec_enter_lf                       , // (i) signal enter lf

    input   wire                        uart_dec_fail                           , // (i) UART_DEC fail in

    // UART_REG
    input   wire                        uart_reg_read_out                       , // (i) UART_REG read signal
    input   wire                        uart_reg_write_out                      , // (i) UART_REG write signal
    input   wire[31:0]                  uart_reg_data_out                       , // (i) UART_REG data

    // UART_TX
    output  wire                        uart_ctrl_read                          , // (o) UART_CTRL read
    output  wire                        uart_ctrl_write                         , // (o) UART_CTRL write

    output  wire[31:0]                  uart_ctrl_data                          , // (o) UART_CTRL data out
    output  wire[7:0]                   uart_ctrl_addr                          , // (o) UART_CTRL data out

    // UART_ENC
    output  wire                        uart_ctrl_o                             , // (o) O signal
    output  wire                        uart_ctrl_k                             , // (o) K signal

    output  wire                        uart_ctrl_f                             , // (o) F signal
    output  wire                        uart_ctrl_a                             , // (o) A signal
    output  wire                        uart_ctrl_i                             , // (o) I signal
    output  wire                        uart_ctrl_l                             , // (o) L signal

    output  wire                        uart_ctrl_num                           , // (o) number signal
    output  wire[3:0]                   uart_ctrl_data_tx                       , // (o) UART_CTRL data

    output  wire                        uart_ctrl_enter                         , // (o) enter signal
    output  wire                        uart_ctrl_right                           // (o) right signal
    );

    // -------------------------------------------------------------
    // Parameter definition
    // -------------------------------------------------------------
    // STATEs of RECEIVE STATE MACHINE
    parameter                           P_IDLE_RX               = 8'b0000_0001  ; // idle
    parameter                           P_WRITE_RX              = 8'b0000_0010  ; // write
    parameter                           P_READ_RX               = 8'b0000_0100  ; // read
    parameter                           P_ADDR_W_RX             = 8'b0000_1000  ; // addr_w
    parameter                           P_ADDR_R_RX             = 8'b0001_0000  ; // addr_r
    parameter                           P_DATA_RX               = 8'b0010_0000  ; // data
    parameter                           P_ENTER_RX              = 8'b0100_0000  ; // enter
    parameter                           P_FAIL_RX               = 8'b1000_0000  ; // fail

    // STATEs of TRANSFER STATE MACHINE
    parameter                           P_RESET_TX              = 5'b0_0001     ; // reset
    parameter                           P_IDLE_TX               = 5'b0_0010     ; // idle
    parameter                           P_WRITE_TX              = 5'b0_0100     ; // write
    parameter                           P_READ_TX               = 5'b0_1000     ; // read
    parameter                           P_FAIL_TX               = 5'b1_0000     ; // fail

    //time count
    parameter                           TIME_CNT                = 13'd4780      ; //1 data time count
    // -------------------------------------------------------------
    // Internal signal definition
    // -------------------------------------------------------------
    // state machine
    reg         [7:0]                   r_ctrl_state_rx                         ; // FSM receive
    reg         [7:0]                   r_ctrl_state_tx                         ; // FSM transfer

    //reset
    reg                                 r_ctrl_reset                            ; // reset

    // state address write
    reg         [7:0]                   r_addr_w                                ; // write address
    reg         [1:0]                   r_addr_w_cnt                            ; // write address count
    reg                                 r_ctrl_write                            ; // state write register

    // state address read
    reg         [7:0]                   r_addr_r                                ; // read address
    reg         [1:0]                   r_addr_r_cnt                            ; // read address count
    reg                                 r_ctrl_read                             ; // state read register

    // state data write
    reg         [31:0]                  r_data_w                                ; // write data
    reg         [3:0]                   r_data_w_cnt                            ; // write data count

    // state fail
    reg                                 r_addr_fail                             ; // address fail
    reg                                 r_ctrl_fail                             ; // UART_CTRL fail register

    // state send
    reg                                 r_ctrl_read_1                           ; // state read register
    reg                                 r_ctrl_write_1                          ; // state write register
    reg                                 r_ctrl_fail_1                           ; // state fail register
    reg         [7:0]                   r_ctrl_addr_1                           ; // addr register
    reg         [31:0]                  r_ctrl_data_1                           ; // data register

    //transfer clock count
    reg         [12:0]                  r_clk_cnt                               ; // clock count

    //reset
    reg                                 r_rst_cnt                               ; // reset count

    reg                                 r_rst_enter                             ; // enter signal
    reg                                 r_rst_right                             ; // right signal

    //write
    reg                                 r_w_cnt                                 ; // write count

    reg                                 r_w_o                                   ; // O signal
    reg                                 r_w_k                                   ; // K signal

    //read
    reg         [2:0]                   r_r_cnt                                 ; // read count

    reg                                 r_num                                   ; // number signal
    reg         [31:0]                  r_data_buf                              ; // data buffer
    reg         [3:0]                   r_r_data                                ; // data out register

    //fail
    reg         [1:0]                   r_fail_cnt                              ; // fail count

    reg                                 r_fail_f                                ; // F signal
    reg                                 r_fail_a                                ; // A signal
    reg                                 r_fail_i                                ; // I signal
    reg                                 r_fail_l                                ; // L signal
// =============================================================================
// RTL Body
// =============================================================================

    // FSM receive
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_ctrl_state_rx <= P_IDLE_RX;
        end else if (uart_dec_done) begin
            case ( r_ctrl_state_rx )

                // idle
                P_IDLE_RX : begin
                    if (uart_dec_fail) begin
                        r_ctrl_state_rx <= P_FAIL_RX;
                    end else if (uart_dec_write) begin
                        r_ctrl_state_rx <= P_WRITE_RX;
                    end else if (uart_dec_read) begin
                        r_ctrl_state_rx <= P_READ_RX;
                    end else begin
                        r_ctrl_state_rx <= P_FAIL_RX;
                    end
                end

                // write
                P_WRITE_RX : begin
                    if (uart_dec_fail) begin
                        r_ctrl_state_rx <= P_FAIL_RX;
                    end else if (uart_dec_space) begin
                        r_ctrl_state_rx <= P_ADDR_W_RX;
                    end else begin
                        r_ctrl_state_rx <= P_FAIL_RX;
                    end
                end

                // read
                P_READ_RX : begin
                    if (uart_dec_fail) begin
                        r_ctrl_state_rx <= P_FAIL_RX;
                    end else if (uart_dec_space) begin
                        r_ctrl_state_rx <= P_ADDR_R_RX;
                    end else begin
                        r_ctrl_state_rx <= P_FAIL_RX;
                    end
                end

                // address write
                P_ADDR_W_RX : begin
                    if (uart_dec_fail) begin
                        r_ctrl_state_rx <= P_FAIL_RX;
                    end else if (r_addr_w_cnt == 2'b10) begin
                        if (uart_dec_space) begin
                            r_ctrl_state_rx <= P_DATA_RX;
                        end else begin
                            r_ctrl_state_rx <= P_FAIL_RX;
                        end
                    end else if (uart_dec_enter_cr || uart_dec_read || uart_dec_write) begin
                        r_ctrl_state_rx <= P_FAIL_RX;
                    end
                end

                // address read
                P_ADDR_R_RX : begin
                    if (uart_dec_fail) begin
                        r_ctrl_state_rx <= P_FAIL_RX;
                    end else if (r_addr_r_cnt == 2'b10) begin
                            r_ctrl_state_rx <= P_ENTER_RX;
                    end else begin
                        if (uart_dec_enter_cr || uart_dec_read || uart_dec_write) begin
                            r_ctrl_state_rx <= P_FAIL_RX;
                        end
                    end
                end

                // data write
                P_DATA_RX : begin
                    if (uart_dec_fail) begin
                        r_ctrl_state_rx <= P_FAIL_RX;
                    end else if (r_data_w_cnt == 4'b1000) begin
                            r_ctrl_state_rx <= P_ENTER_RX;
                    end else begin
                        if (uart_dec_enter_cr || uart_dec_space || uart_dec_read || uart_dec_write) begin
                            r_ctrl_state_rx <= P_FAIL_RX;
                        end
                    end
                end

                // enter
                P_ENTER_RX : begin
                    if (uart_dec_enter_lf) begin
                        r_ctrl_state_rx <= P_IDLE_RX;
                    end else begin
                        r_ctrl_state_rx <= P_FAIL_RX;
                    end
                end

                // fail
                P_FAIL_RX : begin
                    if (uart_dec_enter_lf) begin
                        r_ctrl_state_rx <= P_IDLE_RX;
                    end else begin
                        r_ctrl_state_rx <= P_FAIL_RX;
                    end
                end

                default : begin
                    r_ctrl_state_rx <= P_IDLE_RX;
                end
            endcase
        end
    end

    // reset
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_ctrl_reset <= 1'b1;
        end else begin
            r_ctrl_reset <= 1'b0;
        end
    end

    // address write
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_addr_w        <= 8'b0;
            r_ctrl_write    <= 1'b0;
        end else begin
            if (r_ctrl_state_rx == P_ADDR_W_RX && uart_dec_done) begin
                r_ctrl_write <= 1'b1;
                if (r_addr_w_cnt == 2'b10) begin
                    r_addr_w <= r_addr_w;
                end else begin
                    r_addr_w <= { r_addr_w[3:0], uart_dec_out };
                end
            end else if (r_ctrl_state_rx == P_IDLE_RX) begin
                r_addr_w        <= 8'b0;
                r_ctrl_write    <= 1'b0;
            end
        end
    end

    // address write counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_addr_w_cnt <= 2'b0;
        end else begin
            if (r_ctrl_state_rx == P_ADDR_W_RX && uart_dec_done) begin
                if (r_addr_w_cnt == 2'b10) begin
                    r_addr_w_cnt <= 2'b0;
                end else begin
                    r_addr_w_cnt <= r_addr_w_cnt + 2'b1;
                end
            end
        end
    end

    // address read
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_addr_r    <= 8'b0;
            r_ctrl_read <= 1'b0;
        end else begin
            if (r_ctrl_state_rx == P_ADDR_R_RX && uart_dec_done) begin
                r_ctrl_read <= 1'b1;
                if (r_addr_r_cnt == 2'b10) begin
                    r_addr_r <= r_addr_r;
                end else begin
                    r_addr_r <= { r_addr_r[3:0], uart_dec_out };
                end
            end else if (r_ctrl_state_rx == P_IDLE_RX) begin
                r_addr_r    <= 8'b0;
                r_ctrl_read <= 1'b0;
            end
        end
    end

    // address read counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_addr_r_cnt <= 2'b0;
        end else begin
            if (r_ctrl_state_rx == P_ADDR_R_RX && uart_dec_done) begin
                if (r_addr_r_cnt == 2'b10) begin
                    r_addr_r_cnt <= 2'b0;
                end else begin
                    r_addr_r_cnt <= r_addr_r_cnt + 2'b1;
                end
            end
        end
    end

    // data write
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_data_w <= 32'b0;
        end else begin
            if (r_ctrl_state_rx == P_DATA_RX && uart_dec_done) begin
                if (r_data_w_cnt == 4'b1000) begin
                    r_data_w <= r_data_w;
                end else begin
                    r_data_w <= { r_data_w[27:0], uart_dec_out };
                end
            end else if (r_ctrl_state_rx == P_IDLE_RX) begin
                r_data_w <= 32'b0;
            end
        end
    end

    // data write counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_data_w_cnt <= 4'b0;
        end else begin
            if (r_ctrl_state_rx == P_DATA_RX && uart_dec_done) begin
                if (r_data_w_cnt == 4'b1000) begin
                    r_data_w_cnt <= 4'b0;
                end else begin
                    r_data_w_cnt <= r_data_w_cnt + 4'b1;
                end
            end
        end
    end

    // address judge
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_addr_fail <= 1'b0;
        end else begin
            if (r_ctrl_state_rx == P_ADDR_R_RX || r_ctrl_state_rx == P_ADDR_W_RX) begin
                if ((r_addr_r | r_addr_w) <= 2'b10 && (r_addr_r | r_addr_w) >= 2'b1) begin
                    r_addr_fail <= 1'b0;
                end else begin
                    r_addr_fail <= 1'b1;
                end
            end else if (r_ctrl_state_rx == P_IDLE_RX) begin
                r_addr_fail <= 1'b0;
            end
        end
    end

    // state fail
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_ctrl_fail <= 1'b0;
        end else if (r_ctrl_state_rx == P_FAIL_RX) begin
            r_ctrl_fail <= 1'b1;
        end else if (r_ctrl_state_rx == P_IDLE_RX) begin
            r_ctrl_fail <= 1'b0;
        end
    end

    // fail send
    always @(posedge clk or posedge rst) begin                                  // send fail after enter lf
        if (rst) begin
            // reset
            r_ctrl_fail_1  <= 1'b0;
        end else if ((r_ctrl_state_rx == P_ENTER_RX || r_ctrl_state_rx == P_FAIL_RX) && uart_dec_enter_lf) begin
            if (r_ctrl_fail || r_addr_fail) begin
                r_ctrl_fail_1  <= 1'b1;
            end else begin
                r_ctrl_fail_1  <= 1'b0;
            end
        end else begin
            r_ctrl_fail_1 <= 1'b0;
        end
    end

    // write/read send
    always @(posedge clk or posedge rst) begin                                  // send write/read data after enter lf
        if (rst) begin
            // reset
            r_ctrl_read_1   <= 'b0;
            r_ctrl_write_1  <= 'b0;
            r_ctrl_addr_1   <= 'b0;
            r_ctrl_data_1   <= 'b0;
        end else begin
            if (r_ctrl_state_rx == P_ENTER_RX && uart_dec_enter_lf && !r_ctrl_fail) begin
                r_ctrl_read_1   <= r_ctrl_read;
                r_ctrl_write_1  <= r_ctrl_write;
                r_ctrl_addr_1   <= r_addr_w | r_addr_r;
                r_ctrl_data_1   <= r_data_w;
            end else begin
                r_ctrl_read_1   <= 'b0;
                r_ctrl_write_1  <= 'b0;
                r_ctrl_addr_1   <= 'b0;
                r_ctrl_data_1   <= 'b0;
            end
        end
    end

    assign uart_ctrl_read       = r_ctrl_read_1;
    assign uart_ctrl_write      = r_ctrl_write_1;

    assign uart_ctrl_data       = r_ctrl_data_1;
    assign uart_ctrl_addr       = r_ctrl_addr_1;

    // FSM transfer
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_ctrl_state_tx <= P_IDLE_TX;
        end else begin
            case ( r_ctrl_state_tx )

                P_IDLE_TX  : begin
                    if (r_ctrl_reset) begin
                        r_ctrl_state_tx <= P_RESET_TX;
                    end else if (r_ctrl_fail_1) begin
                        r_ctrl_state_tx <= P_FAIL_TX;
                    end else if (uart_reg_write_out) begin
                        r_ctrl_state_tx <= P_WRITE_TX;
                    end else if (uart_reg_read_out) begin
                        r_ctrl_state_tx <= P_READ_TX;
                    end else begin
                        r_ctrl_state_tx <= P_IDLE_TX;
                    end
                end

                P_WRITE_TX : begin
                    if (r_w_cnt == 1'b1 && r_clk_cnt == TIME_CNT) begin
                        r_ctrl_state_tx <= P_RESET_TX;
                    end
                end

                P_READ_TX  : begin
                    if (r_r_cnt == 3'b111 && r_clk_cnt == TIME_CNT) begin
                        r_ctrl_state_tx <= P_RESET_TX;
                    end
                end

                P_FAIL_TX  : begin
                    if (r_fail_cnt == 2'b11 && r_clk_cnt == TIME_CNT) begin
                        r_ctrl_state_tx <= P_RESET_TX;
                    end
                end

                P_RESET_TX : begin
                    if (r_rst_cnt == 1'b1 && r_clk_cnt == TIME_CNT) begin
                        r_ctrl_state_tx <= P_IDLE_TX;
                    end
                end

                default    : begin
                    r_ctrl_state_tx <= P_IDLE_TX;
                end

            endcase
        end
    end

    // clock counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_clk_cnt <= 13'b0;
        end else begin
            if (r_ctrl_state_tx == P_RESET_TX ||
                r_ctrl_state_tx == P_FAIL_TX  ||
                r_ctrl_state_tx == P_WRITE_TX ||
                r_ctrl_state_tx == P_READ_TX  ) begin
                if (r_clk_cnt == TIME_CNT) begin
                    r_clk_cnt <= 13'b0;
                end else begin
                    r_clk_cnt <= r_clk_cnt + 13'b1;
                end
            end
        end
    end

    // reset
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_rst_enter <= 1'b0;
            r_rst_right <= 1'b0;
        end else begin
            if (r_ctrl_state_tx == P_RESET_TX) begin
                if (r_rst_cnt == 1'b0 && r_clk_cnt == TIME_CNT) begin
                    r_rst_enter <= 1'b1;
                    r_rst_right <= 1'b0;
                end else if (r_rst_cnt == 1'b1 && r_clk_cnt == TIME_CNT) begin
                    r_rst_enter <= 1'b0;
                    r_rst_right <= 1'b1;
                end else begin
                    r_rst_enter <= 1'b0;
                    r_rst_right <= 1'b0;
                end
            end else begin
                r_rst_enter <= 1'b0;
                r_rst_right <= 1'b0;
            end
        end
    end

    // reset counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_rst_cnt <= 1'b0;
        end else begin
            if (r_ctrl_state_tx == P_RESET_TX && r_clk_cnt == TIME_CNT) begin
                if (r_rst_cnt == 1'b1) begin
                    r_rst_cnt <= 1'b0;
                end else begin
                    r_rst_cnt <= r_rst_cnt + 1'b1;
                end
            end
        end
    end

    // write
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_w_o <= 1'b0;
            r_w_k <= 1'b0;
        end else begin
            if (r_ctrl_state_tx == P_WRITE_TX) begin
                if (r_w_cnt == 1'b0 && r_clk_cnt == TIME_CNT) begin
                    r_w_o <= 1'b1;
                    r_w_k <= 1'b0;
                end else if (r_w_cnt == 1'b1 && r_clk_cnt == TIME_CNT) begin
                    r_w_o <= 1'b0;
                    r_w_k <= 1'b1;
                end else begin
                    r_w_o <= 1'b0;
                    r_w_k <= 1'b0;
                end
            end else begin
                r_w_o <= 1'b0;
                r_w_k <= 1'b0;
            end
        end
    end

    // write counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_w_cnt <= 1'b0;
        end else begin
            if (r_ctrl_state_tx == P_WRITE_TX && r_clk_cnt == TIME_CNT) begin
                if (r_w_cnt == 1'b1) begin
                    r_w_cnt <= 1'b0;
                end else begin
                    r_w_cnt <= r_w_cnt + 1'b1;
                end
            end
        end
    end

    // data buffer
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_data_buf <= 32'b0;
        end else begin
            if (uart_reg_read_out) begin
                r_data_buf <= uart_reg_data_out;
            end

            if (r_ctrl_state_tx == P_READ_TX && r_clk_cnt == TIME_CNT) begin
                r_data_buf  <= r_data_buf << 4;
            end
        end
    end

    // read
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_r_data    <= 3'b0;
            r_num       <= 1'b0;
        end else begin
            if (r_ctrl_state_tx == P_READ_TX && r_clk_cnt == TIME_CNT) begin
                r_r_data    <= r_data_buf[31:28];
                r_num       <= 1'b1;
            end else begin
                r_r_data    <= 3'b0;
                r_num       <= 1'b0;
            end
        end
    end

    // read counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_r_cnt <= 3'b0;
        end else begin
            if (r_ctrl_state_tx == P_READ_TX && r_clk_cnt == TIME_CNT) begin
                if (r_r_cnt == 3'b111) begin
                    r_r_cnt <= 3'b0;
                end else begin
                    r_r_cnt <= r_r_cnt + 3'b1;
                end
            end
        end
    end

    // fail
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_fail_f <= 1'b0;
            r_fail_a <= 1'b0;
            r_fail_i <= 1'b0;
            r_fail_l <= 1'b0;
        end else begin
            if (r_ctrl_state_tx == P_FAIL_TX && r_clk_cnt == TIME_CNT) begin
                if (r_fail_cnt == 2'b0) begin
                    r_fail_f <= 1'b1;
                    r_fail_a <= 1'b0;
                    r_fail_i <= 1'b0;
                    r_fail_l <= 1'b0;
                end else if (r_fail_cnt == 2'b1 && r_clk_cnt == TIME_CNT) begin
                    r_fail_f <= 1'b0;
                    r_fail_a <= 1'b1;
                    r_fail_i <= 1'b0;
                    r_fail_l <= 1'b0;
                end else if (r_fail_cnt == 2'b10 && r_clk_cnt == TIME_CNT) begin
                    r_fail_f <= 1'b0;
                    r_fail_a <= 1'b0;
                    r_fail_i <= 1'b1;
                    r_fail_l <= 1'b0;
                end else if (r_fail_cnt == 2'b11 && r_clk_cnt == TIME_CNT) begin
                    r_fail_f <= 1'b0;
                    r_fail_a <= 1'b0;
                    r_fail_i <= 1'b0;
                    r_fail_l <= 1'b1;
                end else begin
                    r_fail_f <= 1'b0;
                    r_fail_a <= 1'b0;
                    r_fail_i <= 1'b0;
                    r_fail_l <= 1'b0;
                end
            end else begin
                r_fail_f <= 1'b0;
                r_fail_a <= 1'b0;
                r_fail_i <= 1'b0;
                r_fail_l <= 1'b0;
            end
        end
    end

    // fail counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_fail_cnt <= 1'b0;
        end else begin
            if (r_ctrl_state_tx == P_FAIL_TX && r_clk_cnt == TIME_CNT) begin
                if (r_fail_cnt == 2'b11) begin
                    r_fail_cnt <= 2'b0;
                end else begin
                    r_fail_cnt <= r_fail_cnt + 1'b1;
                end
            end
        end
    end

    assign uart_ctrl_o          = r_w_o;
    assign uart_ctrl_k          = r_w_k;

    assign uart_ctrl_f          = r_fail_f;
    assign uart_ctrl_a          = r_fail_a;
    assign uart_ctrl_i          = r_fail_i;
    assign uart_ctrl_l          = r_fail_l;

    assign uart_ctrl_num        = r_num;
    assign uart_ctrl_data_tx    = r_r_data;

    assign uart_ctrl_enter      = r_rst_enter;
    assign uart_ctrl_right      = r_rst_right;

endmodule