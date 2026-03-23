`timescale 1ns/1ps

module tb_jpeg_top();
    parameter DIN_WIDTH = 8;
    parameter LINE_LEN  = 16; 
    parameter TOTAL_BLOCKS = 4;
    parameter PIXEL_COUNT = 256;

    reg clk, rst_n;
    reg [7:0] r, g, b;
    reg valid_in, line_en;
    reg start_image;
    wire [7:0] jpeg_out;
    wire jpeg_valid;
    wire image_done;
    reg image_done_seen;

    jpeg_top #(
        .DIN_WIDTH(DIN_WIDTH),
        .LINE_LEN(LINE_LEN),
        .TOTAL_BLOCKS(TOTAL_BLOCKS)
    ) uut (
        .clk(clk), .rst_n(rst_n), .r_in(r), .g_in(g), .b_in(b),
        .valid_in(valid_in), .line_en(line_en), .start_image(start_image),
        .jpeg_out(jpeg_out), .jpeg_valid(jpeg_valid), .image_done(image_done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer out_file;
    integer pixel_idx;
    reg [23:0] pixel_mem [0:PIXEL_COUNT-1];
    reg [1023:0] pixel_path;
    reg [1023:0] output_path;

    initial begin
        pixel_path = "tests/generated/ramp_pixels.hex";
        output_path = "tests/sim_output.txt";
        if (!$value$plusargs("PIXELS=%s", pixel_path)) begin
            $display("Using default pixel file: %0s", pixel_path);
        end
        if (!$value$plusargs("OUTPUT=%s", output_path)) begin
            $display("Using default output file: %0s", output_path);
        end
        $display("Loading pixels from: %0s", pixel_path);
        $readmemh(pixel_path, pixel_mem);
        out_file = $fopen(output_path, "w");
        if (out_file == 0) begin
            $display("ERROR: failed to open output file: %0s", output_path);
            $finish;
        end
    end

    always @(posedge clk) begin
        if (jpeg_valid) begin
            $fdisplay(out_file, "%h", jpeg_out);
            $display("[%t] JPEG Output Byte: %h", $time, jpeg_out);
        end
        if (image_done) begin
            image_done_seen <= 1'b1;
        end
    end

    integer i, j;
    initial begin
        rst_n = 0; r = 0; g = 0; b = 0; valid_in = 0; line_en = 0; start_image = 0; image_done_seen = 0;
        #100; rst_n = 1; #100;

        $display("Sending start_image...");
        start_image = 1; #10; start_image = 0;
        #5000;

        $display("Starting image data injection (16x16)...");
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
            #5000; // Increased delay to allow backend to finish processing
        end

        $display("Waiting for image_done...");
        // Use a loop with timeout to avoid hanging if signal never comes
        repeat (500000) begin // Increased to 500,000 cycles
            @(posedge clk);
            if (image_done_seen) begin
                $display("image_done detected at %t!", $time);
                #100;
                $fclose(out_file);
                $display("Test complete. Results saved to %0s", output_path);
                $finish; // Use finish instead of stop for automation
            end
        end
        
        $display("TIMEOUT: image_done not detected after 500,000 cycles.");
        $fclose(out_file);
        $finish;
    end

endmodule
