`timescale 1ns/1ps

module tb_dct_chain();
    reg clk;
    reg rst_n;
    reg [7:0] r_in;
    reg [7:0] g_in;
    reg [7:0] b_in;
    reg valid_in;
    reg line_en;

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

    wire [64*32-1:0] y_block;
    wire y_block_valid;

    integer out_file;
    integer row_idx;
    integer col_idx;
    integer coeff_idx;
    integer sample_idx;
    reg dumped_y;
    reg dumped_cb;
    reg dumped_cr;
    reg dumped_y_block;

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
                if (ycbcr_col_count == 7) begin
                    pending_line_last_reg <= 1;
                    ycbcr_col_count <= 0;
                end else begin
                    ycbcr_col_count <= ycbcr_col_count + 1;
                end
            end
        end
    end

    line_buffer #(
        .DIN_WIDTH(32),
        .DOUT_WIDTH(64*32),
        .LINE_LEN(8)
    ) line_buffer_y_obs (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(dct_y_in_reg),
        .pixel_valid(dct_pixel_valid_reg),
        .line_last(pending_line_last_reg),
        .data_out(y_block),
        .data_out_valid(y_block_valid)
    );

    D2DCT #(.DIN_WIDTH(32), .WINDOW_WIDTH(64*32), .LINE_LEN(8)) d2dct_y (
        .clk(clk), .rst_n(rst_n), .data_in(dct_y_in_reg),
        .pixel_valid(dct_pixel_valid_reg), .line_last(pending_line_last_reg), .d2dct_out(d2dct_out_y), .d2dct_valid(d2dct_valid_y)
    );
    D2DCT #(.DIN_WIDTH(32), .WINDOW_WIDTH(64*32), .LINE_LEN(8)) d2dct_cb (
        .clk(clk), .rst_n(rst_n), .data_in(dct_cb_in_reg),
        .pixel_valid(dct_pixel_valid_reg), .line_last(pending_line_last_reg), .d2dct_out(d2dct_out_cb), .d2dct_valid(d2dct_valid_cb)
    );
    D2DCT #(.DIN_WIDTH(32), .WINDOW_WIDTH(64*32), .LINE_LEN(8)) d2dct_cr (
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
        out_file = $fopen("tests/dct_chain_output.txt", "w");
        rst_n = 0;
        r_in = 0;
        g_in = 0;
        b_in = 0;
        valid_in = 0;
        line_en = 0;
        dumped_y = 0;
        dumped_cb = 0;
        dumped_cr = 0;
        dumped_y_block = 0;
        sample_idx = 0;

        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        for (row_idx = 0; row_idx < 8; row_idx = row_idx + 1) begin
            @(negedge clk);
            line_en = 1;
            valid_in = 1;
            for (col_idx = 0; col_idx < 8; col_idx = col_idx + 1) begin
                r_in = row_idx * 8 + col_idx;
                g_in = row_idx * 8 + col_idx + 5;
                b_in = row_idx * 8 + col_idx + 10;
                @(posedge clk);
                @(negedge clk);
            end
            valid_in = 0;
            line_en = 0;
            repeat (3) @(posedge clk);
        end

        repeat (100) @(posedge clk);
        $fclose(out_file);
        $display("DCT chain vectors written.");
        $finish;
    end

    task automatic dump_component;
        input [8*8*12-1:0] data;
        input [8*8-1:0] name0;
        begin
            $fwrite(out_file, "%0s", name0);
            for (coeff_idx = 0; coeff_idx < 64; coeff_idx = coeff_idx + 1) begin
                $fwrite(
                    out_file,
                    "%s%0d",
                    (coeff_idx == 0) ? " " : " ",
                    $signed(data[(coeff_idx+1)*12-1 -: 12])
                );
            end
            $fwrite(out_file, "\n");
        end
    endtask

    task automatic dump_block32;
        input [64*32-1:0] data;
        begin
            $fwrite(out_file, "YBLK");
            for (coeff_idx = 0; coeff_idx < 64; coeff_idx = coeff_idx + 1) begin
                $fwrite(
                    out_file,
                    " %0d",
                    $signed(data[(64 - coeff_idx) * 32 - 1 -: 32])
                );
            end
            $fwrite(out_file, "\n");
        end
    endtask

    always @(negedge clk) begin
        if (dct_pixel_valid_reg && sample_idx < 20) begin
            $fwrite(out_file, "S %0d %0d %0d\n", sample_idx, dct_y_in_reg, pending_line_last_reg);
            sample_idx = sample_idx + 1;
        end
        if (y_block_valid && !dumped_y_block) begin
            dump_block32(y_block);
            dumped_y_block <= 1;
        end
        if (zigzag_valid_y && !dumped_y) begin
            dump_component(zigzag_out_y, "Y");
            dumped_y <= 1;
        end
        if (zigzag_valid_cb && !dumped_cb) begin
            dump_component(zigzag_out_cb, "Cb");
            dumped_cb <= 1;
        end
        if (zigzag_valid_cr && !dumped_cr) begin
            dump_component(zigzag_out_cr, "Cr");
            dumped_cr <= 1;
        end
    end
endmodule
