`timescale 1ns/1ps

module tb_block_grid_chain();
    parameter PIXEL_COUNT = 256;

    reg clk;
    reg rst_n;
    reg [7:0] r_in;
    reg [7:0] g_in;
    reg [7:0] b_in;
    reg valid_in;

    wire [7:0] y;
    wire [7:0] cb;
    wire [7:0] cr;
    wire ycbcr_valid;

    reg signed [31:0] dct_y_in_reg;
    reg signed [31:0] dct_cb_in_reg;
    reg signed [31:0] dct_cr_in_reg;
    reg dct_pixel_valid_reg;
    reg pending_line_last_reg;
    reg [15:0] ycbcr_col_count;

    wire [64*52-1:0] d2dct_out_y;
    wire d2dct_valid_y;
    wire [64*52-1:0] d2dct_out_cb;
    wire d2dct_valid_cb;
    wire [64*52-1:0] d2dct_out_cr;
    wire d2dct_valid_cr;

    wire [64*12-1:0] quant_out_y;
    wire quant_valid_y;
    wire [64*12-1:0] quant_out_cb;
    wire quant_valid_cb;
    wire [64*12-1:0] quant_out_cr;
    wire quant_valid_cr;

    wire [64*12-1:0] zigzag_out_y;
    wire zigzag_valid_y;
    wire [64*12-1:0] zigzag_out_cb;
    wire zigzag_valid_cb;
    wire [64*12-1:0] zigzag_out_cr;
    wire zigzag_valid_cr;

    integer out_file;
    integer row_idx;
    integer col_idx;
    integer coeff_idx;
    integer y_block_idx;
    integer cb_block_idx;
    integer cr_block_idx;
    integer pixel_idx;
    integer idle_row_cycles;
    integer max_blocks;
    integer flush_cycles;
    reg [23:0] pixel_mem [0:PIXEL_COUNT-1];
    reg [1023:0] pixel_path;
    reg [1023:0] output_path;

    rgb2ycbcr rgb2ycbcr_u (
        .clk(clk),
        .rst_n(rst_n),
        .r(r_in),
        .g(g_in),
        .b(b_in),
        .valid_in(valid_in),
        .y(y),
        .cb(cb),
        .cr(cr),
        .valid_out(ycbcr_valid)
    );

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
                if (ycbcr_col_count == 15) begin
                    pending_line_last_reg <= 1;
                    ycbcr_col_count <= 0;
                end else begin
                    ycbcr_col_count <= ycbcr_col_count + 1;
                end
            end
        end
    end

    D2DCT #(.DIN_WIDTH(32), .WINDOW_WIDTH(64*32), .LINE_LEN(16)) d2dct_y (
        .clk(clk), .rst_n(rst_n), .data_in(dct_y_in_reg),
        .pixel_valid(dct_pixel_valid_reg), .line_last(pending_line_last_reg), .d2dct_out(d2dct_out_y), .d2dct_valid(d2dct_valid_y)
    );
    D2DCT #(.DIN_WIDTH(32), .WINDOW_WIDTH(64*32), .LINE_LEN(16)) d2dct_cb (
        .clk(clk), .rst_n(rst_n), .data_in(dct_cb_in_reg),
        .pixel_valid(dct_pixel_valid_reg), .line_last(pending_line_last_reg), .d2dct_out(d2dct_out_cb), .d2dct_valid(d2dct_valid_cb)
    );
    D2DCT #(.DIN_WIDTH(32), .WINDOW_WIDTH(64*32), .LINE_LEN(16)) d2dct_cr (
        .clk(clk), .rst_n(rst_n), .data_in(dct_cr_in_reg),
        .pixel_valid(dct_pixel_valid_reg), .line_last(pending_line_last_reg), .d2dct_out(d2dct_out_cr), .d2dct_valid(d2dct_valid_cr)
    );

    quantizer #(.DIN_WIDTH(32), .DOUT_WIDTH(12)) quant_y (
        .clk(clk), .rst_n(rst_n), .dct_in(d2dct_out_y), .dct_valid(d2dct_valid_y),
        .component_type(2'd0), .quant_out(quant_out_y), .quant_valid(quant_valid_y)
    );
    quantizer #(.DIN_WIDTH(32), .DOUT_WIDTH(12)) quant_cb (
        .clk(clk), .rst_n(rst_n), .dct_in(d2dct_out_cb), .dct_valid(d2dct_valid_cb),
        .component_type(2'd1), .quant_out(quant_out_cb), .quant_valid(quant_valid_cb)
    );
    quantizer #(.DIN_WIDTH(32), .DOUT_WIDTH(12)) quant_cr (
        .clk(clk), .rst_n(rst_n), .dct_in(d2dct_out_cr), .dct_valid(d2dct_valid_cr),
        .component_type(2'd2), .quant_out(quant_out_cr), .quant_valid(quant_valid_cr)
    );

    zigzag #(.DIN_WIDTH(12)) zigzag_y (
        .clk(clk), .rst_n(rst_n), .quant_in(quant_out_y), .quant_valid(quant_valid_y),
        .zigzag_out(zigzag_out_y), .zigzag_valid(zigzag_valid_y)
    );
    zigzag #(.DIN_WIDTH(12)) zigzag_cb (
        .clk(clk), .rst_n(rst_n), .quant_in(quant_out_cb), .quant_valid(quant_valid_cb),
        .zigzag_out(zigzag_out_cb), .zigzag_valid(zigzag_valid_cb)
    );
    zigzag #(.DIN_WIDTH(12)) zigzag_cr (
        .clk(clk), .rst_n(rst_n), .quant_in(quant_out_cr), .quant_valid(quant_valid_cr),
        .zigzag_out(zigzag_out_cr), .zigzag_valid(zigzag_valid_cr)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        pixel_path = "tests/generated/ramp_pixels.hex";
        output_path = "tests/block_grid_chain_output.txt";
        max_blocks = 4;
        idle_row_cycles = 3;
        flush_cycles = 200;
        if (!$value$plusargs("PIXELS=%s", pixel_path)) begin
            $display("Using default pixel file: %0s", pixel_path);
        end
        if (!$value$plusargs("OUTPUT=%s", output_path)) begin
            $display("Using default output file: %0s", output_path);
        end
        $display("Loading block-grid pixels from: %0s", pixel_path);
        $readmemh(pixel_path, pixel_mem);
    end

    task automatic dump_component;
        input [8*8*12-1:0] data;
        input [8*8-1:0] name0;
        input integer block_idx;
        begin
            $fwrite(out_file, "%0s %0d", name0, block_idx);
            for (coeff_idx = 0; coeff_idx < 64; coeff_idx = coeff_idx + 1) begin
                $fwrite(out_file, " %0d", $signed(data[(coeff_idx+1)*12-1 -: 12]));
            end
            $fwrite(out_file, "\n");
        end
    endtask

    initial begin
        out_file = $fopen(output_path, "w");
        rst_n = 0;
        r_in = 0;
        g_in = 0;
        b_in = 0;
        valid_in = 0;
        y_block_idx = 0;
        cb_block_idx = 0;
        cr_block_idx = 0;

        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        for (row_idx = 0; row_idx < 16; row_idx = row_idx + 1) begin
            @(negedge clk);
            valid_in = 1;
            for (col_idx = 0; col_idx < 16; col_idx = col_idx + 1) begin
                pixel_idx = row_idx * 16 + col_idx;
                r_in = pixel_mem[pixel_idx][23:16];
                g_in = pixel_mem[pixel_idx][15:8];
                b_in = pixel_mem[pixel_idx][7:0];
                @(posedge clk);
                @(negedge clk);
            end
            valid_in = 0;
            repeat (idle_row_cycles) @(posedge clk);
        end

        repeat (flush_cycles) @(posedge clk);
        $fclose(out_file);
        $display("Block-grid DCT chain vectors written.");
        $finish;
    end

    always @(negedge clk) begin
        if (zigzag_valid_y && y_block_idx < max_blocks) begin
            dump_component(zigzag_out_y, "Y", y_block_idx);
            y_block_idx = y_block_idx + 1;
        end
        if (zigzag_valid_cb && cb_block_idx < max_blocks) begin
            dump_component(zigzag_out_cb, "Cb", cb_block_idx);
            cb_block_idx = cb_block_idx + 1;
        end
        if (zigzag_valid_cr && cr_block_idx < max_blocks) begin
            dump_component(zigzag_out_cr, "Cr", cr_block_idx);
            cr_block_idx = cr_block_idx + 1;
        end
    end
endmodule
