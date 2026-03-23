`timescale 1ns/1ps

module tb_top_huff_events();
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
        output_path = "tests/top_huff_events.txt";
        if (!$value$plusargs("PIXELS=%s", pixel_path)) begin
            $display("Using default pixel file: %0s", pixel_path);
        end
        if (!$value$plusargs("OUTPUT=%s", output_path)) begin
            $display("Using default output file: %0s", output_path);
        end
        $display("Loading top-huff-event pixels from: %0s", pixel_path);
        $readmemh(pixel_path, pixel_mem);
    end

    integer i, j;
    initial begin
        out_file = $fopen(output_path, "w");
        rst_n = 0; r = 0; g = 0; b = 0; valid_in = 0; line_en = 0; start_image = 0; image_done_seen = 0;
        #100; rst_n = 1; #100;

        start_image = 1; #10; start_image = 0;
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
            valid_in = 0; line_en = 0;
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
        if (uut.huff_start) begin
            $fwrite(out_file, "START %0d %0d\n", uut.block_cnt, uut.huff_component_type);
        end
        if (uut.huff_valid) begin
            $fwrite(out_file, "BITS %0d %0d %0d %0h\n", uut.block_cnt, uut.huff_component_type, uut.huff_len, uut.huff_bits);
        end
        if (uut.block_done) begin
            $fwrite(out_file, "DONE %0d %0d\n", uut.block_cnt, uut.huff_component_type);
        end
    end
endmodule
