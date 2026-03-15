module D1DCT #(
    parameter                       DIN_WIDTH      = 32                 ,
    parameter                       WINDOW_WIDTH   = 64*32              ,
    parameter                       M1             = 35'h0000_0000      , // cos(pi/16)*sqrt(2) * 2^16
    parameter                       M2             = 35'h0000_0000      , // cos(pi/16)*sqrt(2) * 2^16
    parameter                       M3             = 35'h0000_0000      , // cos(pi/16)*sqrt(2) * 2^16
    parameter                       M4             = 35'h0000_0000        // cos(pi/16)*sqrt(2) * 2^16
)(
    input                           clk                 ,
    input                           rst_n               ,
    input  [WINDOW_WIDTH-1:0]       wind_in             ,
    input                           wind_valid          , 

    output [64*(DIN_WIDTH+5)-1:0]   d1dct_out           ,
    output                          d1dct_valid         
);

wire [8*(DIN_WIDTH+5)-1:0]  d1dct_out_line1     ;
wire                        d1dct_valid_line1   ;
wire [8*(DIN_WIDTH+5)-1:0]  d1dct_out_line2     ;
wire                        d1dct_valid_line2   ;
wire [8*(DIN_WIDTH+5)-1:0]  d1dct_out_line3     ;
wire                        d1dct_valid_line3   ;
wire [8*(DIN_WIDTH+5)-1:0]  d1dct_out_line4     ;
wire                        d1dct_valid_line4   ;
wire [8*(DIN_WIDTH+5)-1:0]  d1dct_out_line5     ;
wire                        d1dct_valid_line5   ;
wire [8*(DIN_WIDTH+5)-1:0]  d1dct_out_line6     ;
wire                        d1dct_valid_line6   ;
wire [8*(DIN_WIDTH+5)-1:0]  d1dct_out_line7     ;
wire                        d1dct_valid_line7   ;
wire [8*(DIN_WIDTH+5)-1:0]  d1dct_out_line8     ;
wire                        d1dct_valid_line8   ;

assign d1dct_out   = {d1dct_out_line1, d1dct_out_line2, d1dct_out_line3, d1dct_out_line4, d1dct_out_line5, d1dct_out_line6, d1dct_out_line7, d1dct_out_line8};
assign d1dct_valid = d1dct_valid_line1;

d1dct_pipeline #(
    .DIN_WIDTH          (DIN_WIDTH                              ),
    .WINDOW_WIDTH       (WINDOW_WIDTH                           ),
    .M1                 (M1                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M2                 (M2                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M3                 (M3                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M4                 (M4                                     )  // cos(pi/16)*sqrt(2) * 2^16
)d1dct_pipeline_line1(
    .clk                 (clk                                   ),
    .rst_n               (rst_n                                 ),
    .wind_in             (wind_in[64*DIN_WIDTH-1:56*DIN_WIDTH]  ),
    .wind_valid          (wind_valid                            ), 
    .d1dct_out           (d1dct_out_line1                       ),
    .d1dct_valid         (d1dct_valid_line1                     )
);

d1dct_pipeline #(
    .DIN_WIDTH          (DIN_WIDTH                              ),
    .WINDOW_WIDTH       (WINDOW_WIDTH                           ),
    .M1                 (M1                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M2                 (M2                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M3                 (M3                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M4                 (M4                                     )  // cos(pi/16)*sqrt(2) * 2^16
)d1dct_pipeline_line2(
    .clk                 (clk                                   ),
    .rst_n               (rst_n                                 ),
    .wind_in             (wind_in[56*DIN_WIDTH-1:48*DIN_WIDTH]  ),
    .wind_valid          (wind_valid                            ), 
    .d1dct_out           (d1dct_out_line2                       ),
    .d1dct_valid         (d1dct_valid_line2                     )
);

d1dct_pipeline #(
    .DIN_WIDTH          (DIN_WIDTH                              ),
    .WINDOW_WIDTH       (WINDOW_WIDTH                           ),
    .M1                 (M1                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M2                 (M2                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M3                 (M3                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M4                 (M4                                     )  // cos(pi/16)*sqrt(2) * 2^16
)d1dct_pipeline_line3(
    .clk                 (clk                                   ),
    .rst_n               (rst_n                                 ),
    .wind_in             (wind_in[48*DIN_WIDTH-1:40*DIN_WIDTH]  ),
    .wind_valid          (wind_valid                            ), 
    .d1dct_out           (d1dct_out_line3                       ),
    .d1dct_valid         (d1dct_valid_line3                     )
);

d1dct_pipeline #(
    .DIN_WIDTH          (DIN_WIDTH                              ),
    .WINDOW_WIDTH       (WINDOW_WIDTH                           ),
    .M1                 (M1                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M2                 (M2                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M3                 (M3                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M4                 (M4                                     )  // cos(pi/16)*sqrt(2) * 2^16
)d1dct_pipeline_line4(
    .clk                 (clk                                   ),
    .rst_n               (rst_n                                 ),
    .wind_in             (wind_in[40*DIN_WIDTH-1:32*DIN_WIDTH]  ),
    .wind_valid          (wind_valid                            ), 
    .d1dct_out           (d1dct_out_line4                       ),
    .d1dct_valid         (d1dct_valid_line4                     )
);

d1dct_pipeline #(
    .DIN_WIDTH          (DIN_WIDTH                              ),
    .WINDOW_WIDTH       (WINDOW_WIDTH                           ),
    .M1                 (M1                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M2                 (M2                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M3                 (M3                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M4                 (M4                                     )  // cos(pi/16)*sqrt(2) * 2^16
)d1dct_pipeline_line5(
    .clk                 (clk                                   ),
    .rst_n               (rst_n                                 ),
    .wind_in             (wind_in[32*DIN_WIDTH-1:24*DIN_WIDTH]  ),
    .wind_valid          (wind_valid                            ), 
    .d1dct_out           (d1dct_out_line5                       ),
    .d1dct_valid         (d1dct_valid_line5                     )
);

d1dct_pipeline #(
    .DIN_WIDTH          (DIN_WIDTH                              ),
    .WINDOW_WIDTH       (WINDOW_WIDTH                           ),
    .M1                 (M1                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M2                 (M2                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M3                 (M3                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M4                 (M4                                     )  // cos(pi/16)*sqrt(2) * 2^16
)d1dct_pipeline_line6(
    .clk                 (clk                                   ),
    .rst_n               (rst_n                                 ),
    .wind_in             (wind_in[24*DIN_WIDTH-1:16*DIN_WIDTH]  ),
    .wind_valid          (wind_valid                            ), 
    .d1dct_out           (d1dct_out_line6                       ),
    .d1dct_valid         (d1dct_valid_line6                     )
);

d1dct_pipeline #(
    .DIN_WIDTH          (DIN_WIDTH                              ),
    .WINDOW_WIDTH       (WINDOW_WIDTH                           ),
    .M1                 (M1                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M2                 (M2                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M3                 (M3                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M4                 (M4                                     )  // cos(pi/16)*sqrt(2) * 2^16
)d1dct_pipeline_line7(
    .clk                 (clk                                   ),
    .rst_n               (rst_n                                 ),
    .wind_in             (wind_in[16*DIN_WIDTH-1:8*DIN_WIDTH]  ),
    .wind_valid          (wind_valid                            ), 
    .d1dct_out           (d1dct_out_line7                       ),
    .d1dct_valid         (d1dct_valid_line7                     )
);

d1dct_pipeline #(
    .DIN_WIDTH          (DIN_WIDTH                              ),
    .WINDOW_WIDTH       (WINDOW_WIDTH                           ),
    .M1                 (M1                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M2                 (M2                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M3                 (M3                                     ), // cos(pi/16)*sqrt(2) * 2^16
    .M4                 (M4                                     )  // cos(pi/16)*sqrt(2) * 2^16
)d1dct_pipeline_line8(
    .clk                 (clk                                   ),
    .rst_n               (rst_n                                 ),
    .wind_in             (wind_in[8*DIN_WIDTH-1:0]              ),
    .wind_valid          (wind_valid                            ), 
    .d1dct_out           (d1dct_out_line8                       ),
    .d1dct_valid         (d1dct_valid_line8                     )
);


endmodule
