module zigzag #(
    parameter DIN_WIDTH = 12
)(
    input clk,
    input rst_n,
    input [64*DIN_WIDTH-1:0] quant_in, // 量化后的 8x8 块系数
    input quant_valid,                // 输入有效信号

    output reg [64*DIN_WIDTH-1:0] zigzag_out, // 之字形扫描排序后的系数
    output reg zigzag_valid                   // 输出有效信号
);

    // 之字形扫描索引映射表
    // 作用: 将 8x8 矩阵中的低频系数排在前面，高频系数排在后面。
    // 这有利于后续的游程编码 (RLE)，因为高频区域通常有很多连续的零。
    function [5:0] get_zigzag_index;
        input [5:0] i;
        case (i)
            0: get_zigzag_index = 0;   1: get_zigzag_index = 1;   2: get_zigzag_index = 8;   3: get_zigzag_index = 16;
            4: get_zigzag_index = 9;   5: get_zigzag_index = 2;   6: get_zigzag_index = 3;   7: get_zigzag_index = 10;
            8: get_zigzag_index = 17;  9: get_zigzag_index = 24;  10: get_zigzag_index = 32; 11: get_zigzag_index = 25;
            12: get_zigzag_index = 18; 13: get_zigzag_index = 11; 14: get_zigzag_index = 4;  15: get_zigzag_index = 5;
            16: get_zigzag_index = 12; 17: get_zigzag_index = 19; 18: get_zigzag_index = 26; 19: get_zigzag_index = 33;
            20: get_zigzag_index = 40; 21: get_zigzag_index = 48; 22: get_zigzag_index = 41; 23: get_zigzag_index = 34;
            24: get_zigzag_index = 27; 25: get_zigzag_index = 20; 26: get_zigzag_index = 13; 27: get_zigzag_index = 6;
            28: get_zigzag_index = 7;  29: get_zigzag_index = 14; 30: get_zigzag_index = 21; 31: get_zigzag_index = 28;
            32: get_zigzag_index = 35; 33: get_zigzag_index = 42; 34: get_zigzag_index = 49; 35: get_zigzag_index = 56;
            36: get_zigzag_index = 57; 37: get_zigzag_index = 50; 38: get_zigzag_index = 43; 39: get_zigzag_index = 36;
            40: get_zigzag_index = 29; 41: get_zigzag_index = 22; 42: get_zigzag_index = 15; 43: get_zigzag_index = 23;
            44: get_zigzag_index = 30; 45: get_zigzag_index = 37; 46: get_zigzag_index = 44; 47: get_zigzag_index = 51;
            48: get_zigzag_index = 58; 49: get_zigzag_index = 59; 50: get_zigzag_index = 52; 51: get_zigzag_index = 45;
            52: get_zigzag_index = 38; 53: get_zigzag_index = 31; 54: get_zigzag_index = 39; 55: get_zigzag_index = 46;
            56: get_zigzag_index = 53; 57: get_zigzag_index = 60; 58: get_zigzag_index = 61; 59: get_zigzag_index = 54;
            60: get_zigzag_index = 47; 61: get_zigzag_index = 55; 62: get_zigzag_index = 62; 63: get_zigzag_index = 63;
            default: get_zigzag_index = 0;
        endcase
    endfunction

    reg [64*DIN_WIDTH-1:0] next_zigzag_out;
    integer i;

    always @* begin
        next_zigzag_out = 0;
        for (i = 0; i < 64; i = i + 1) begin
            // 根据映射表重新排列系数
            next_zigzag_out[i*DIN_WIDTH +: DIN_WIDTH] =
                quant_in[get_zigzag_index(i)*DIN_WIDTH +: DIN_WIDTH];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            zigzag_out <= 0;
            zigzag_valid <= 0;
        end else begin
            zigzag_out <= next_zigzag_out;
            zigzag_valid <= quant_valid;
        end
    end

endmodule
