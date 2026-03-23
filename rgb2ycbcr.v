module rgb2ycbcr (
    input clk,
    input rst_n,
    input [7:0] r,       // 红色分量
    input [7:0] g,       // 绿色分量
    input [7:0] b,       // 蓝色分量
    input valid_in,      // 输入有效

    output reg [7:0] y,  // 亮度分量
    output reg [7:0] cb, // 蓝色色度分量
    output reg [7:0] cr, // 红色色度分量
    output reg valid_out // 输出有效
);

    // 标准转换公式 (ITU-R BT.601):
    // Y  =  0.299R + 0.587G + 0.114B
    // Cb = -0.1687R - 0.3313G + 0.5B + 128
    // Cr =  0.5R - 0.4187G - 0.0813B + 128

    // 定点系数 (乘以 256):
    // Y:  77, 150, 29
    // Cb: -43, -85, 128
    // Cr: 128, -107, -21

    reg valid_delay;
    reg [15:0] y_tmp, cb_tmp, cr_tmp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_delay <= 0;
            valid_out <= 0;
            y <= 0;
            cb <= 0;
            cr <= 0;
        end else begin
            valid_delay <= valid_in;
            valid_out <= valid_delay;

            // 乘法和累加计算
            y_tmp  <= 77*r + 150*g + 29*b;
            cb_tmp <= -43*r - 85*g + 128*b + 32768; // 32768 = 128 * 256 (偏移量)
            cr_tmp <= 128*r - 107*g - 21*b + 32768; // 32768 = 128 * 256 (偏移量)
            
            // 移位取高 8 位 (除以 256)
            y <= y_tmp[15:8];
            cb <= cb_tmp[15:8];
            cr <= cr_tmp[15:8];
        end
    end

endmodule
