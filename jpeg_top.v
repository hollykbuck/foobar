module jpeg_top #(
    parameter DIN_WIDTH = 8,
    parameter LINE_LEN  = 16,
    parameter TOTAL_BLOCKS = 4 // (16/8) * (16/8) = 对于 16x16 图像共有 4 个 8x8 块
)(
    input clk,
    input rst_n,
    input [7:0] r_in,          // 输入红色分量
    input [7:0] g_in,          // 输入绿色分量
    input [7:0] b_in,          // 输入蓝色分量
    input valid_in,            // 输入数据有效信号
    input line_en,             // 行使能信号
    input start_image,         // 开始处理图像信号

    output reg [7:0] jpeg_out, // 输出的 JPEG 字节流
    output reg       jpeg_valid, // 输出有效信号
    output reg       image_done  // 图像处理完成信号
);

    // JPEG 序列处理状态机
    localparam IDLE         = 4'd0; // 空闲
    localparam GEN_HEADER   = 4'd1; // 生成 JPEG 文件头 (SOI, DQT, DHT, SOF, SOS)
    localparam WAIT_BLOCK   = 4'd2; // 等待足够的数据块进入 FIFO
    localparam COMPRESS_Y   = 4'd3; // 压缩亮度分量 Y
    localparam COMPRESS_CB  = 4'd4; // 压缩色度分量 Cb
    localparam COMPRESS_CR  = 4'd5; // 压缩色度分量 Cr
    localparam FLUSH        = 4'd6; // 刷新比特流缓冲区（对齐到字节）
    localparam GEN_EOI      = 4'd7; // 生成图像结束标志 (EOI: 0xFFD9)
    localparam DONE         = 4'd8; // 处理完成

    reg [3:0] state;
    reg [15:0] block_cnt;
    reg component_active;

    // --- 文件头生成模块 ---
    wire [7:0] header_data;
    wire header_valid;
    wire header_done;
    jpeg_header header_u (
        .clk(clk), .rst_n(rst_n),
        .start(state == GEN_HEADER),
        .header_data(header_data),
        .header_valid(header_valid),
        .header_done(header_done)
    );

    // --- 颜色空间转换 (CSC) 阶段 ---
    wire [7:0] y, cb, cr;
    wire ycbcr_valid;
    reg signed [31:0] dct_y_in_reg, dct_cb_in_reg, dct_cr_in_reg;
    reg dct_pixel_valid_reg;
    reg pending_line_last_reg;
    reg [15:0] ycbcr_col_count;
    rgb2ycbcr rgb2ycbcr_u (
        .clk(clk), .rst_n(rst_n), .r(r_in), .g(g_in), .b(b_in), .valid_in(valid_in),
        .y(y), .cb(cb), .cr(cr), .valid_out(ycbcr_valid)
    );

    // 预处理：减去偏移量 128 (Level Shift)，满足 DCT 输入要求 [-128, 127]
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dct_y_in_reg <= 0;
            dct_cb_in_reg <= 0;
            dct_cr_in_reg <= 0;
            dct_pixel_valid_reg <= 0;
            pending_line_last_reg <= 0;
            ycbcr_col_count <= 0;
        end else begin
            dct_y_in_reg <= $signed({24'b0, y}) - 32'sd128;
            dct_cb_in_reg <= $signed({24'b0, cb}) - 32'sd128;
            dct_cr_in_reg <= $signed({24'b0, cr}) - 32'sd128;
            dct_pixel_valid_reg <= ycbcr_valid;
            pending_line_last_reg <= 0;
            if (ycbcr_valid) begin
                if (ycbcr_col_count == LINE_LEN - 1) begin
                    pending_line_last_reg <= 1; // 标识一行结束，用于 DCT 内部行缓存控制
                    ycbcr_col_count <= 0;
                end else begin
                    ycbcr_col_count <= ycbcr_col_count + 1;
                end
            end
        end
    end

    // --- Y (亮度) 流水线 ---
    // 包含 2D DCT、量化和之字形扫描
    wire [64*52-1:0] d2dct_out_y; wire d2dct_valid_y;
    D2DCT #(.DIN_WIDTH(32), .WINDOW_WIDTH(64*32), .LINE_LEN(LINE_LEN)) d2dct_y (
        .clk(clk), .rst_n(rst_n), .data_in(dct_y_in_reg),
        .pixel_valid(dct_pixel_valid_reg), .line_last(pending_line_last_reg), .d2dct_out(d2dct_out_y), .d2dct_valid(d2dct_valid_y)
    );
    wire [64*12-1:0] quant_out_y; wire quant_valid_y;
    quantizer #(.DIN_WIDTH(32), .DOUT_WIDTH(12)) quant_y (
        .clk(clk), .rst_n(rst_n), .dct_in(d2dct_out_y), .dct_valid(d2dct_valid_y),
        .component_type(2'd0), .quant_out(quant_out_y), .quant_valid(quant_valid_y)
    );
    wire [64*12-1:0] zigzag_out_y; wire zigzag_valid_y;
    zigzag #(.DIN_WIDTH(12)) zigzag_y (
        .clk(clk), .rst_n(rst_n), .quant_in(quant_out_y), .quant_valid(quant_valid_y),
        .zigzag_out(zigzag_out_y), .zigzag_valid(zigzag_valid_y)
    );

    // --- Cb (蓝色色度) 流水线 ---
    wire [64*52-1:0] d2dct_out_cb; wire d2dct_valid_cb;
    D2DCT #(.DIN_WIDTH(32), .WINDOW_WIDTH(64*32), .LINE_LEN(LINE_LEN)) d2dct_cb (
        .clk(clk), .rst_n(rst_n), .data_in(dct_cb_in_reg),
        .pixel_valid(dct_pixel_valid_reg), .line_last(pending_line_last_reg), .d2dct_out(d2dct_out_cb), .d2dct_valid(d2dct_valid_cb)
    );
    wire [64*12-1:0] quant_out_cb; wire quant_valid_cb;
    quantizer #(.DIN_WIDTH(32), .DOUT_WIDTH(12)) quant_cb (
        .clk(clk), .rst_n(rst_n), .dct_in(d2dct_out_cb), .dct_valid(d2dct_valid_cb),
        .component_type(2'd1), .quant_out(quant_out_cb), .quant_valid(quant_valid_cb)
    );
    wire [64*12-1:0] zigzag_out_cb; wire zigzag_valid_cb;
    zigzag #(.DIN_WIDTH(12)) zigzag_cb (
        .clk(clk), .rst_n(rst_n), .quant_in(quant_out_cb), .quant_valid(quant_valid_cb),
        .zigzag_out(zigzag_out_cb), .zigzag_valid(zigzag_valid_cb)
    );

    // --- Cr (红色色度) 流水线 ---
    wire [64*52-1:0] d2dct_out_cr; wire d2dct_valid_cr;
    D2DCT #(.DIN_WIDTH(32), .WINDOW_WIDTH(64*32), .LINE_LEN(LINE_LEN)) d2dct_cr (
        .clk(clk), .rst_n(rst_n), .data_in(dct_cr_in_reg),
        .pixel_valid(dct_pixel_valid_reg), .line_last(pending_line_last_reg), .d2dct_out(d2dct_out_cr), .d2dct_valid(d2dct_valid_cr)
    );
    wire [64*12-1:0] quant_out_cr; wire quant_valid_cr;
    quantizer #(.DIN_WIDTH(32), .DOUT_WIDTH(12)) quant_cr (
        .clk(clk), .rst_n(rst_n), .dct_in(d2dct_out_cr), .dct_valid(d2dct_valid_cr),
        .component_type(2'd2), .quant_out(quant_out_cr), .quant_valid(quant_valid_cr)
    );
    wire [64*12-1:0] zigzag_out_cr; wire zigzag_valid_cr;
    zigzag #(.DIN_WIDTH(12)) zigzag_cr (
        .clk(clk), .rst_n(rst_n), .quant_in(quant_out_cr), .quant_valid(quant_valid_cr),
        .zigzag_out(zigzag_out_cr), .zigzag_valid(zigzag_valid_cr)
    );

    // --- 数据缓冲与多路复用 (使用 4 深度 FIFO) ---
    // 在进入哈夫曼编码前缓冲完成处理的 8x8 块
    reg [64*12-1:0] fifo_y [0:3], fifo_cb [0:3], fifo_cr [0:3];
    reg [1:0] wr_ptr_y, rd_ptr_y;
    reg [1:0] wr_ptr_cb, rd_ptr_cb;
    reg [1:0] wr_ptr_cr, rd_ptr_cr;
    reg [2:0] count_y, count_cb, count_cr;

    wire [1:0] huff_component_type = (state == COMPRESS_CB) ? 2'd1 :
                                     (state == COMPRESS_CR) ? 2'd2 : 2'd0;
    wire start_y  = (state == COMPRESS_Y)  && !component_active && (count_y  > 0);
    wire start_cb = (state == COMPRESS_CB) && !component_active && (count_cb > 0);
    wire start_cr = (state == COMPRESS_CR) && !component_active && (count_cr > 0);
    wire huff_start = start_y || start_cb || start_cr;
    wire block_done;
    wire consume_y  = (state == COMPRESS_Y)  && component_active && block_done;
    wire consume_cb = (state == COMPRESS_CB) && component_active && block_done;
    wire consume_cr = (state == COMPRESS_CR) && component_active && block_done;

    // FIFO 控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr_y <= 0; rd_ptr_y <= 0; count_y <= 0;
            wr_ptr_cb <= 0; rd_ptr_cb <= 0; count_cb <= 0;
            wr_ptr_cr <= 0; rd_ptr_cr <= 0; count_cr <= 0;
        end else begin
            if (zigzag_valid_y) begin
                fifo_y[wr_ptr_y] <= zigzag_out_y;
                wr_ptr_y <= wr_ptr_y + 1;
            end
            if (consume_y) begin
                rd_ptr_y <= rd_ptr_y + 1;
            end
            count_y <= count_y + (zigzag_valid_y ? 1 : 0) - (consume_y ? 1 : 0);

            if (zigzag_valid_cb) begin
                fifo_cb[wr_ptr_cb] <= zigzag_out_cb;
                wr_ptr_cb <= wr_ptr_cb + 1;
            end
            if (consume_cb) begin
                rd_ptr_cb <= rd_ptr_cb + 1;
            end
            count_cb <= count_cb + (zigzag_valid_cb ? 1 : 0) - (consume_cb ? 1 : 0);

            if (zigzag_valid_cr) begin
                fifo_cr[wr_ptr_cr] <= zigzag_out_cr;
                wr_ptr_cr <= wr_ptr_cr + 1;
            end
            if (consume_cr) begin
                rd_ptr_cr <= rd_ptr_cr + 1;
            end
            count_cr <= count_cr + (zigzag_valid_cr ? 1 : 0) - (consume_cr ? 1 : 0);
        end
    end

    // 当前需要哈夫曼编码的数据输入
    wire [64*12-1:0] huff_in = (state == COMPRESS_Y) ? fifo_y[rd_ptr_y] : 
                               (state == COMPRESS_CB) ? fifo_cb[rd_ptr_cb] : fifo_cr[rd_ptr_cr];

    // --- 哈夫曼编码模块 ---
    wire [15:0] huff_bits; wire [4:0] huff_len; wire huff_valid; 
    huffman_encoder #(.DIN_WIDTH(12)) huffman_u (
        .clk(clk), .rst_n(rst_n), .zigzag_in(huff_in), .zigzag_valid(huff_start),
        .component_type(huff_component_type), .bits_out(huff_bits), .bits_len(huff_len), 
        .bits_valid(huff_valid), .block_done(block_done)
    );

    // --- 比特流打包模块 ---
    wire [7:0] compressed_byte; wire compressed_valid; wire flush_done;
    bitstream_packer packer_u (
        .clk(clk), .rst_n(rst_n), .bits_in(huff_bits), .len_in(huff_len), .valid_in(huff_valid),
        .flush(state == FLUSH), .byte_out(compressed_byte), .byte_valid(compressed_valid),
        .flush_done(flush_done)
    );

    // --- 顶层控制逻辑 ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            block_cnt <= 0;
            component_active <= 0;
            jpeg_out <= 0;
            jpeg_valid <= 0;
            image_done <= 0;
        end else begin
            if (state != IDLE && state != WAIT_BLOCK) begin
                if (consume_y || consume_cb || consume_cr) $display("[%t] Finished Block %d Comp %d", $time, block_cnt, huff_component_type);
            end
            if (huff_start)
                component_active <= 1;
            else if (consume_y || consume_cb || consume_cr)
                component_active <= 0;

            case (state)
                IDLE: begin
                    if (start_image) begin
                        state <= GEN_HEADER;
                        $display("[%t] Starting Header Generation...", $time);
                    end
                    component_active <= 0;
                    jpeg_valid <= 0;
                    image_done <= 0;
                    block_cnt <= 0;
                end
                GEN_HEADER: begin
                    jpeg_out <= header_data;
                    jpeg_valid <= header_valid;
                    if (header_done) begin
                        state <= WAIT_BLOCK;
                        $display("[%t] Header Done. Waiting for pixel data...", $time);
                    end
                end
                WAIT_BLOCK: begin
                    jpeg_out <= compressed_byte;
                    jpeg_valid <= compressed_valid;
                    component_active <= 0;
                    // 当 Y, Cb, Cr 三个分量的 FIFO 都有数据时，按 MCU 顺序进行哈夫曼编码
                    if (count_y > 0 && count_cb > 0 && count_cr > 0) begin
                        state <= COMPRESS_Y;
                        $display("[%t] Block %d Ready for Y compression", $time, block_cnt);
                    end
                end
                COMPRESS_Y: begin
                    jpeg_out <= compressed_byte;
                    jpeg_valid <= compressed_valid;
                    if (consume_y) state <= COMPRESS_CB;
                end
                COMPRESS_CB: begin
                    jpeg_out <= compressed_byte;
                    jpeg_valid <= compressed_valid;
                    if (consume_cb) state <= COMPRESS_CR;
                end
                COMPRESS_CR: begin
                    jpeg_out <= compressed_byte;
                    jpeg_valid <= compressed_valid;
                    if (consume_cr) begin
                        if (block_cnt == TOTAL_BLOCKS - 1) begin
                            state <= FLUSH;
                            $display("[%t] All Blocks Compressed. Flushing...", $time);
                        end
                        else begin
                            block_cnt <= block_cnt + 1;
                            state <= WAIT_BLOCK;
                        end
                    end
                end
                FLUSH: begin
                    jpeg_out <= compressed_byte;
                    jpeg_valid <= compressed_valid;
                    if (flush_done) begin
                        state <= GEN_EOI;
                        $display("[%t] Flush Done. Generating EOI...", $time);
                    end
                end
                GEN_EOI: begin
                    // 简单的 EOI (End Of Image: 0xFFD9) 填充
                    jpeg_out <= 8'hFF; jpeg_valid <= 1;
                    state <= DONE;
                end
                DONE: begin
                    jpeg_out <= 8'hD9; jpeg_valid <= 1;
                    image_done <= 1;
                    state <= IDLE;
                    $display("[%t] Image Done.", $time);
                end
            endcase
        end
    end

endmodule
