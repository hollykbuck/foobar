module transpose_buffer #(
    parameter                       DIN_WIDTH      = 32                 ,
    parameter                       WINDOW_WIDTH   = 64*32              ,
) (
    input                           clk                 ,
    input                           rst_n               ,
    input  [8*(DIN_WIDTH+5)-1:0]    d1dct_out           ,
    input                           d1dct_valid         , 

    output [8*(DIN_WIDTH+5)-1:0]    trans_out           ,
    output                          trans_valid         
);













endmodule
