module quantizer #(
    parameter DIN_WIDTH = 32,
    parameter DOUT_WIDTH = 12
)(
    input clk,
    input rst_n,
    input [64*(DIN_WIDTH+20)-1:0] dct_in, // 8x8 块的 DCT 系数输入
    input dct_valid,                     // 输入有效信号
    input [1:0] component_type,          // 分量类型: 0-Y, 1-Cb, 2-Cr

    output reg [64*DOUT_WIDTH-1:0] quant_out, // 量化后的系数
    output reg quant_valid                    // 输出有效信号
);

    // 标准 JPEG 亮度 (Luminance) 量化表，缩放到质量因子 45。
    // 量化原理: q_out = round(dct_in / q_table)
    wire [7:0] q_table_y [0:63];
    assign q_table_y[0]  = 18;  assign q_table_y[1]  = 12;  assign q_table_y[2]  = 11;  assign q_table_y[3]  = 18;
    assign q_table_y[4]  = 27;  assign q_table_y[5]  = 44;  assign q_table_y[6]  = 57;  assign q_table_y[7]  = 68;
    assign q_table_y[8]  = 13;  assign q_table_y[9]  = 13;  assign q_table_y[10] = 16;  assign q_table_y[11] = 21;
    assign q_table_y[12] = 29;  assign q_table_y[13] = 64;  assign q_table_y[14] = 67;  assign q_table_y[15] = 61;
    assign q_table_y[16] = 16;  assign q_table_y[17] = 14;  assign q_table_y[18] = 18;  assign q_table_y[19] = 27;
    assign q_table_y[20] = 44;  assign q_table_y[21] = 63;  assign q_table_y[22] = 77;  assign q_table_y[23] = 62;
    assign q_table_y[24] = 16;  assign q_table_y[25] = 19;  assign q_table_y[26] = 24;  assign q_table_y[27] = 32;
    assign q_table_y[28] = 57;  assign q_table_y[29] = 97;  assign q_table_y[30] = 89;  assign q_table_y[31] = 69;
    assign q_table_y[32] = 20;  assign q_table_y[33] = 24;  assign q_table_y[34] = 41;  assign q_table_y[35] = 62;
    assign q_table_y[36] = 75;  assign q_table_y[37] = 121; assign q_table_y[38] = 114; assign q_table_y[39] = 85;
    assign q_table_y[40] = 27;  assign q_table_y[41] = 39;  assign q_table_y[42] = 61;  assign q_table_y[43] = 71;
    assign q_table_y[44] = 90;  assign q_table_y[45] = 115; assign q_table_y[46] = 125; assign q_table_y[47] = 102;
    assign q_table_y[48] = 54;  assign q_table_y[49] = 71;  assign q_table_y[50] = 87;  assign q_table_y[51] = 97;
    assign q_table_y[52] = 114; assign q_table_y[53] = 134; assign q_table_y[54] = 133; assign q_table_y[55] = 112;
    assign q_table_y[56] = 80;  assign q_table_y[57] = 102; assign q_table_y[58] = 105; assign q_table_y[59] = 109;
    assign q_table_y[60] = 124; assign q_table_y[61] = 111; assign q_table_y[62] = 114; assign q_table_y[63] = 110;

    // 标准 JPEG 色度 (Chrominance) 量化表，缩放到质量因子 45。
    wire [7:0] q_table_c [0:63];
    assign q_table_c[0]  = 19;  assign q_table_c[1]  = 20;  assign q_table_c[2]  = 27;  assign q_table_c[3]  = 52;
    assign q_table_c[4]  = 110; assign q_table_c[5]  = 110; assign q_table_c[6]  = 110; assign q_table_c[7]  = 110;
    assign q_table_c[8]  = 20;  assign q_table_c[9]  = 23;  assign q_table_c[10] = 29;  assign q_table_c[11] = 73;
    assign q_table_c[12] = 110; assign q_table_c[13] = 110; assign q_table_c[14] = 110; assign q_table_c[15] = 110;
    assign q_table_c[16] = 27;  assign q_table_c[17] = 29;  assign q_table_c[18] = 62;  assign q_table_c[19] = 110;
    assign q_table_c[20] = 110; assign q_table_c[21] = 110; assign q_table_c[22] = 110; assign q_table_c[23] = 110;
    assign q_table_c[24] = 52;  assign q_table_c[25] = 73;  assign q_table_c[26] = 110; assign q_table_c[27] = 110;
    assign q_table_c[28] = 110; assign q_table_c[29] = 110; assign q_table_c[30] = 110; assign q_table_c[31] = 110;
    assign q_table_c[32] = 110; assign q_table_c[33] = 110; assign q_table_c[34] = 110; assign q_table_c[35] = 110;
    assign q_table_c[36] = 110; assign q_table_c[37] = 110; assign q_table_c[38] = 110; assign q_table_c[39] = 110;
    assign q_table_c[40] = 110; assign q_table_c[41] = 110; assign q_table_c[42] = 110; assign q_table_c[43] = 110;
    assign q_table_c[44] = 110; assign q_table_c[45] = 110; assign q_table_c[46] = 110; assign q_table_c[47] = 110;
    assign q_table_c[48] = 110; assign q_table_c[49] = 110; assign q_table_c[50] = 110; assign q_table_c[51] = 110;
    assign q_table_c[52] = 110; assign q_table_c[53] = 110; assign q_table_c[54] = 110; assign q_table_c[55] = 110;
    assign q_table_c[56] = 110; assign q_table_c[57] = 110; assign q_table_c[58] = 110; assign q_table_c[59] = 110;
    assign q_table_c[60] = 110; assign q_table_c[61] = 110; assign q_table_c[62] = 110; assign q_table_c[63] = 110;

    reg [64*DOUT_WIDTH-1:0] next_quant_out;
    integer i;
    reg signed [DIN_WIDTH+19:0] dct_coeff;
    reg [7:0] q_val;
    reg signed [DIN_WIDTH+20:0] q_val_signed;
    reg signed [DIN_WIDTH+20:0] round_bias;
    reg signed [DIN_WIDTH+20:0] rounded_coeff;

    always @* begin
        next_quant_out = 0;
        for (i = 0; i < 64; i = i + 1) begin
            dct_coeff = dct_in[i*(DIN_WIDTH+20) +: (DIN_WIDTH+20)];
            q_val = (component_type == 0) ? q_table_y[i] : q_table_c[i];
            q_val_signed = $signed({1'b0, q_val});
            
            // 舍入偏移量: q/2
            round_bias = $signed({2'b00, q_val[7:1]});
            
            // 执行带舍入的除法: (x + q/2) / q 对于正数, (x - q/2) / q 对于负数
            rounded_coeff = (dct_coeff >= 0) ? (dct_coeff + round_bias) : (dct_coeff - round_bias);
            next_quant_out[i*DOUT_WIDTH +: DOUT_WIDTH] = rounded_coeff / q_val_signed;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            quant_out <= 0;
            quant_valid <= 0;
        end else begin
            quant_out <= next_quant_out;
            quant_valid <= dct_valid;
        end
    end

endmodule
