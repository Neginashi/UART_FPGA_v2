`timescale 1ns / 1ps

module UART_REG (
    // system signals
    input   wire                        clk                                     , // (i) clock
    input   wire                        rst                                     , // (i) reset (high-active)

    // input signals
    input   wire                        uart_ctrl_read                          , // (o) UART_REG read
    input   wire                        uart_ctrl_write                         , // (o) UART_REG write

    input   wire[31:0]                  uart_ctrl_data                          , // (o) UART_REG data out
    input   wire[7:0]                   uart_ctrl_addr                          , // (o) UART_REG data out

    output  wire                        uart_reg_read_out                       ,
    output  wire                        uart_reg_write_out                      ,
    output  wire[31:0]                  uart_reg_data_out
    );

    // -------------------------------------------------------------
    // Internal signal definition
    // -------------------------------------------------------------
    // write
    reg                                 r_reg_write                             ;

    //read
    reg         [31:0]                  r_reg_data                              ;
    reg                                 r_reg_read                              ;

    //register 1&2
    reg         [31:0]                  r_reg_reg_1                             ; // register 1
    reg         [31:0]                  r_reg_reg_2                             ; // register 2

// =============================================================================
// RTL Body
// =============================================================================
    //write in reg
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_reg_reg_1 <= 32'b0;
            r_reg_reg_2 <= 32'b0;
            r_reg_write <= 1'b0;
        end else begin
            if (uart_ctrl_write) begin
                r_reg_write <= 1'b1;
                if (uart_ctrl_addr == 8'b01) begin
                    r_reg_reg_1 <= uart_ctrl_data;
                    r_reg_reg_2 <= r_reg_reg_2;
                end else if (uart_ctrl_addr == 8'b10) begin
                    r_reg_reg_1 <= r_reg_reg_1;
                    r_reg_reg_2 <= uart_ctrl_data;
                end
            end else begin
                r_reg_reg_1 <= r_reg_reg_1;
                r_reg_reg_2 <= r_reg_reg_2;
                r_reg_write <= 1'b0;
            end
        end
    end

    //read from reg
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset
            r_reg_data  <= 32'b0;
            r_reg_read  <= 1'b0;
        end else begin
            if (uart_ctrl_read) begin
                r_reg_read  <= 1'b1;
                if (uart_ctrl_addr == 8'b01) begin
                    r_reg_data <= r_reg_reg_1;
                end else if (uart_ctrl_addr == 8'b10) begin
                    r_reg_data <= r_reg_reg_2;
                end
            end else begin
                r_reg_data  <= 32'b0;
                r_reg_read  <= 1'b0;
            end
        end
    end

    assign uart_reg_read_out    = r_reg_read;
    assign uart_reg_write_out   = r_reg_write;
    assign uart_reg_data_out    = r_reg_data;

endmodule