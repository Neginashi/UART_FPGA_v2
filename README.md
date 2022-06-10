# UART_FPGA_v2


WRITE:

input: W XX YYYYYYYY ( XX: address, YY: data, XX = 01~02, Y = 1'h0 ~ 1'hA )

output: OK ( no errors in the format ) 
        FAIL ( errors in the format )
        
        
READ:

input: R XX ( XX: address, XX = 01~02 )

output: YYYYYYYY ( YYYYYYYY: data )
