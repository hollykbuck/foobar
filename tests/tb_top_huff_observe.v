`timescale 1ns/1ps

module tb_top_huff_observe();
    parameter PIXEL_COUNT = 256;

    reg clk, rst_n;
    reg [7:0] r, g, b;
    reg valid_in, line_en;
    reg start_image;
    wire [7:0] jpeg_out;
    wire jpeg_valid;
    wire image_done;
    reg image_done_seen;

    integer out_file;
    integer i, j, coeff_idx;
    integer pixel_idx;
    reg [23:0] pixel_mem [0:PIXEL_COUNT-1];
    reg [1023:0] pixel_path;
    reg [1023:0] output_path;

    jpeg_top #(
        .DIN_WIDTH(8),
        .LINE_LEN(16),
        .TOTAL_BLOCKS(4)
    ) uut (
        .clk(clk), .rst_n(rst_n), .r_in(r), .g_in(g), .b_in(b),
        .valid_in(valid_in), .line_en(line_en), .start_image(start_image),
        .jpeg_out(jpeg_out), .jpeg_valid(jpeg_valid), .image_done(image_done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        pixel_path = "tests/generated/ramp_pixels.hex";
        output_path = "tests/top_huff_observe.txt";
        if (!$value$plusargs("PIXELS=%s", pixel_path)) begin
            $display("Using default pixel file: %0s", pixel_path);
        end
        if (!$value$plusargs("OUTPUT=%s", output_path)) begin
            $display("Using default output file: %0s", output_path);
        end
        $display("Loading top-huff pixels from: %0s", pixel_path);
        $readmemh(pixel_path, pixel_mem);
    end

    task automatic dump_block;
        input [64*12-1:0] data;
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
        r = 0;
        g = 0;
        b = 0;
        valid_in = 0;
        line_en = 0;
        start_image = 0;
        image_done_seen = 0;
        #100;
        rst_n = 1;
        #100;

        start_image = 1;
        #10;
        start_image = 0;
        #5000;

        for (i = 0; i < 16; i = i + 1) begin
            line_en = 1;
            for (j = 0; j < 16; j = j + 1) begin
                valid_in = 1;
                pixel_idx = i * 16 + j;
                r = pixel_mem[pixel_idx][23:16];
                g = pixel_mem[pixel_idx][15:8];
                b = pixel_mem[pixel_idx][7:0];
                #10;
            end
            valid_in = 0;
            line_en = 0;
            #5000;
        end

        repeat (500000) begin
            @(posedge clk);
            if (image_done_seen) begin
                #100;
                $fclose(out_file);
                $finish;
            end
        end

        $fclose(out_file);
        $finish;
    end

    always @(posedge clk) begin
        if (image_done) begin
            image_done_seen <= 1'b1;
        end
        if (uut.start_y) begin
            dump_block(uut.fifo_y[uut.rd_ptr_y], "Y", uut.block_cnt);
        end
        if (uut.start_cb) begin
            dump_block(uut.fifo_cb[uut.rd_ptr_cb], "Cb", uut.block_cnt);
        end
        if (uut.start_cr) begin
            dump_block(uut.fifo_cr[uut.rd_ptr_cr], "Cr", uut.block_cnt);
        end
    end
endmodule
