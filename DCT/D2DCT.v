module D2DCT #(
    parameter                       DIN_WIDTH      = 32                 ,
    parameter                       WINDOW_WIDTH   = 64*32              ,
    parameter                       LINE_LEN       = 16                 
)(
    input                           clk                 ,
    input                           rst_n               ,
    input  [DIN_WIDTH-1:0]          data_in             , // 原始像素输入 (已执行 Level Shift)
    input                           pixel_valid         ,
    input                           line_last           ,

    output [64*(DIN_WIDTH+20)-1:0]  d2dct_out           , // 8x8 块的 2D DCT 系数输出
    output                          d2dct_valid         
);

// 2D DCT 实现原理: 行列分离法 (Row-Column Decomposition)
// 1. 对每一行进行 1D DCT 变换。
// 2. 将中间结果矩阵转置。
// 3. 对转置后的每一行（原矩阵的列）再进行一次 1D DCT 变换。

wire [WINDOW_WIDTH-1:0]  x8data_out                     ;
wire                     x8data_out_valid               ;

wire [64*(DIN_WIDTH+10)-1:0]   d1dct_out_w  ;
wire                          d1dct_valid_w;

wire [64*(DIN_WIDTH+10)-1:0]   trans_out_w  ;
wire                          trans_valid_w;
wire [64*(DIN_WIDTH+20)-1:0]   d2dct_internal_w;

localparam DOUT_WIDTH = DIN_WIDTH + 20;
wire [64*DOUT_WIDTH-1:0] final_pack_w;
genvar row_idx, col_idx;

// 行缓存模块：将流水线输入的像素打包成 8 像素的行向量
line_buffer #(
    .DIN_WIDTH          (DIN_WIDTH      ),
    .DOUT_WIDTH         (WINDOW_WIDTH   ),
    .LINE_LEN           (LINE_LEN       )  
)line_buffer_u(
    .clk                 (clk    ),
    .rst_n               (rst_n  ),
    .data_in             (data_in),
    .pixel_valid         (pixel_valid),
    .line_last           (line_last),
    .data_out            (x8data_out      ),
    .data_out_valid      (x8data_out_valid)
);

// 第一级：行 1D DCT
D1DCT #(
    .DIN_WIDTH          (DIN_WIDTH   ),
    .WINDOW_WIDTH       (WINDOW_WIDTH)
)D1DCT_u1(
    .clk                 (clk    ),
    .rst_n               (rst_n  ),
    .wind_in             (x8data_out      ),
    .wind_valid          (x8data_out_valid), 

    .d1dct_out           (d1dct_out_w  ),
    .d1dct_valid         (d1dct_valid_w)
);

// 转置缓冲区：存储 8x8 的第一级结果并输出转置后的矩阵
transpose_buffer #(
    .DIN_WIDTH      (DIN_WIDTH   ),
    .WINDOW_WIDTH   (WINDOW_WIDTH)
)transpose_buffer_u(
    .clk                 (clk  ),
    .rst_n               (rst_n),
    .d1dct_out           (d1dct_out_w  ),
    .d1dct_valid         (d1dct_valid_w), 

    .trans_out           (trans_out_w  ),
    .trans_valid         (trans_valid_w)
);

// 第二级：对转置后的数据再次进行 1D DCT (相当于对原矩阵的列进行变换)
D1DCT #(
    .DIN_WIDTH          (DIN_WIDTH + 10 ), // 增加位宽以保持精度
    .WINDOW_WIDTH       (64*(DIN_WIDTH+10))
)D1DCT_u2(
    .clk                 (clk    ),
    .rst_n               (rst_n  ),
    .wind_in             (trans_out_w  ),
    .wind_valid          (trans_valid_w), 

    .d1dct_out           (d2dct_internal_w  ),
    .d1dct_valid         (d2dct_valid)
);

// 重新打包输出结果，确保索引顺序符合 (u, v) 坐标系
generate
    for (row_idx = 0; row_idx < 8; row_idx = row_idx + 1) begin : pack_row
        for (col_idx = 0; col_idx < 8; col_idx = col_idx + 1) begin : pack_col
            assign final_pack_w[(row_idx*8+col_idx)*DOUT_WIDTH +: DOUT_WIDTH] =
                d2dct_internal_w[(64-(col_idx*8+row_idx))*DOUT_WIDTH-1 -: DOUT_WIDTH];
        end
    end
endgenerate

assign d2dct_out = final_pack_w;

endmodule
