module huffman_encoder #(
    parameter DIN_WIDTH = 12
)(
    input clk,
    input rst_n,
    input [64*DIN_WIDTH-1:0] zigzag_in, // 之字形扫描输入
    input zigzag_valid,                // 输入有效
    input [1:0] component_type,         // 分量类型: 0-Y, 1-Cb, 2-Cr

    output reg [15:0] bits_out,         // 哈夫曼编码后的位
    output reg [4:0]  bits_len,         // 哈夫曼编码后的长度
    output reg        bits_valid,       // 输出有效
    output reg        block_done        // 一个 8x8 块处理完成
);

    // RLE (游程编码) 和 VLC (变长编码) 状态机
    localparam IDLE     = 3'd0;
    localparam DC_VLC   = 3'd1; // 输出 DC 系数的哈夫曼编码 (Category)
    localparam DC_VAL   = 3'd2; // 输出 DC 系数的实际差分值位
    localparam AC_SCAN  = 3'd3; // 扫描 AC 系数寻找非零值 (RLE)
    localparam AC_VLC   = 3'd4; // 输出 AC 系数的哈夫曼编码 (Run/Size)
    localparam AC_VAL   = 3'd5; // 输出 AC 系数的实际值位
    localparam EOB_STEP = 3'd6; // 输出块结束标志 (EOB: End Of Block)

    reg [2:0] state;
    reg [5:0] ac_idx;
    reg [3:0] run_count;
    reg [64*DIN_WIDTH-1:0] block_reg;
    reg [1:0] comp_type_reg;

    // 获取系数所属的分类 (Category)，决定其哈夫曼编码
    function [3:0] get_category;
        input signed [15:0] val;
        reg [15:0] abs_val;
        begin
            abs_val = (val < 0) ? -val : val;
            if (abs_val == 0) get_category = 0;
            else if (abs_val < 2)    get_category = 1;
            else if (abs_val < 4)    get_category = 2;
            else if (abs_val < 8)    get_category = 3;
            else if (abs_val < 16)   get_category = 4;
            else if (abs_val < 32)   get_category = 5;
            else if (abs_val < 64)   get_category = 6;
            else if (abs_val < 128)  get_category = 7;
            else if (abs_val < 256)  get_category = 8;
            else if (abs_val < 512)  get_category = 9;
            else if (abs_val < 1024) get_category = 10;
            else if (abs_val < 2048) get_category = 11;
            else                     get_category = 12;
        end
    endfunction

    // 计算实际值的位表示 (JPEG 标准: 正数取原码，负数取反)
    function [15:0] get_value_bits;
        input signed [15:0] val;
        input [3:0] category;
        begin
            if (val > 0) get_value_bits = val[15:0];
            else         get_value_bits = val - 1; // 负数在 JPEG 中使用特殊的位表示
        end
    endfunction

    // 检查剩余的 AC 系数是否全为零
    function has_nonzero_tail;
        input [64*DIN_WIDTH-1:0] block;
        input [5:0] start_idx;
        integer idx;
        begin
            has_nonzero_tail = 1'b0;
            for (idx = start_idx; idx < 64; idx = idx + 1) begin
                if ($signed(block[idx*DIN_WIDTH +: DIN_WIDTH]) != 0) begin
                    has_nonzero_tail = 1'b1;
                end
            end
        end
    endfunction

    // DC 差分编码 (DPCM)
    reg signed [DIN_WIDTH-1:0] last_dc_y, last_dc_cb, last_dc_cr;
    reg signed [DIN_WIDTH:0] dc_diff;
    
    wire [3:0] dc_cat = get_category(dc_diff);
    wire [15:0] dc_val_bits = get_value_bits(dc_diff, dc_cat);

    // AC 信号
    wire signed [DIN_WIDTH-1:0] current_ac = block_reg[ac_idx*DIN_WIDTH +: DIN_WIDTH];
    wire [3:0] ac_cat = get_category(current_ac);
    wire [15:0] ac_val_bits = get_value_bits(current_ac, ac_cat);
    wire ac_tail_has_nonzero = has_nonzero_tail(block_reg, ac_idx);

    // 哈夫曼查找表 (LUT) 接口
    reg [3:0] lut_dc_cat;
    reg [7:0] lut_ac_rs;
    wire [15:0] dc_huff_code, ac_huff_code;
    wire [4:0]  dc_huff_len, ac_huff_len;

    huffman_lut lut_u (
        .dc_category(lut_dc_cat),
        .ac_run_size(lut_ac_rs),
        .is_chroma(comp_type_reg != 0),
        .dc_code(dc_huff_code), .dc_len(dc_huff_len),
        .ac_code(ac_huff_code), .ac_len(ac_huff_len)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            last_dc_y <= 0; last_dc_cb <= 0; last_dc_cr <= 0;
            bits_valid <= 0;
            block_done <= 0;
            ac_idx <= 1;
            run_count <= 0;
        end else begin
            block_done <= 0;
            case (state)
                IDLE: begin
                    if (zigzag_valid) begin
                        block_reg <= zigzag_in;
                        comp_type_reg <= component_type;
                        
                        // DC DPCM: 计算与上一个块 DC 系数的差值
                        case (component_type)
                            0: begin dc_diff <= $signed(zigzag_in[DIN_WIDTH-1:0]) - last_dc_y;  last_dc_y <= zigzag_in[DIN_WIDTH-1:0]; end
                            1: begin dc_diff <= $signed(zigzag_in[DIN_WIDTH-1:0]) - last_dc_cb; last_dc_cb <= zigzag_in[DIN_WIDTH-1:0]; end
                            2: begin dc_diff <= $signed(zigzag_in[DIN_WIDTH-1:0]) - last_dc_cr; last_dc_cr <= zigzag_in[DIN_WIDTH-1:0]; end
                        endcase
                        lut_dc_cat <= get_category($signed(zigzag_in[DIN_WIDTH-1:0]) - ((component_type==0)?last_dc_y:((component_type==1)?last_dc_cb:last_dc_cr)));
                        state <= DC_VLC;
                    end
                    bits_valid <= 0;
                end

                DC_VLC: begin
                    // 输出 DC 哈夫曼编码
                    bits_out <= dc_huff_code;
                    bits_len <= dc_huff_len;
                    bits_valid <= 1;
                    state <= DC_VAL;
                end

                DC_VAL: begin
                    // 输出 DC 实际值位
                    if (dc_cat == 0) begin
                        state <= AC_SCAN;
                        bits_valid <= 0;
                    end else begin
                        bits_out <= dc_val_bits;
                        bits_len <= dc_cat;
                        bits_valid <= 1;
                        state <= AC_SCAN;
                    end
                    ac_idx <= 1;
                    run_count <= 0;
                end

                AC_SCAN: begin
                    bits_valid <= 0;
                    if (current_ac == 0) begin
                        if (!ac_tail_has_nonzero) begin
                            // 剩余全部为零，发送 EOB
                            lut_ac_rs <= 8'h00; 
                            state <= EOB_STEP;
                        end else begin
                            // 零游程计数
                            run_count <= run_count + 1;
                            if (run_count == 15) begin
                                // 达到最大游程 16 个零 (ZRL: Zero Run Length)
                                lut_ac_rs <= 8'hF0;
                                state <= AC_VLC;
                            end else begin
                                ac_idx <= ac_idx + 1;
                            end
                        end
                    end else begin
                        // 发现非零系数，发送 (Run, Size) 哈夫曼编码
                        lut_ac_rs <= {run_count, ac_cat};
                        state <= AC_VLC;
                    end
                end

                AC_VLC: begin
                    bits_out <= ac_huff_code;
                    bits_len <= ac_huff_len;
                    bits_valid <= 1;
                    if (lut_ac_rs == 8'hF0) begin // ZRL
                        run_count <= 0;
                        ac_idx <= ac_idx + 1;
                        state <= AC_SCAN;
                    end else begin
                        state <= AC_VAL;
                    end
                end

                AC_VAL: begin
                    // 输出 AC 实际值位
                    bits_out <= ac_val_bits;
                    bits_len <= ac_cat;
                    bits_valid <= 1;
                    run_count <= 0;
                    if (ac_idx == 63) begin
                        block_done <= 1;
                        state <= IDLE;
                    end else begin
                        ac_idx <= ac_idx + 1;
                        state <= AC_SCAN;
                    end
                end

                EOB_STEP: begin
                    // 输出块结束标志 (End Of Block: 00)
                    bits_out <= ac_huff_code;
                    bits_len <= ac_huff_len;
                    bits_valid <= 1;
                    block_done <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
