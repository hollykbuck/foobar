`timescale 1ns/1ps

module tb_d2dct();
    localparam DIN_WIDTH = 32;
    localparam DOUT_WIDTH = DIN_WIDTH + 20;
    localparam LINE_LEN = 8;
    localparam NUM_BLOCKS = 3;

    reg clk;
    reg rst_n;
    reg signed [DIN_WIDTH-1:0] data_in;
    reg pixel_valid;
    reg line_last;
    wire [64*DOUT_WIDTH-1:0] d2dct_out;
    wire d2dct_valid;

    integer out_file;
    integer block_idx;
    integer row_idx;
    integer col_idx;
    integer coeff_idx;

    D2DCT #(
        .DIN_WIDTH(DIN_WIDTH),
        .WINDOW_WIDTH(64*DIN_WIDTH),
        .LINE_LEN(LINE_LEN)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .pixel_valid(pixel_valid),
        .line_last(line_last),
        .d2dct_out(d2dct_out),
        .d2dct_valid(d2dct_valid)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    function automatic signed [DIN_WIDTH-1:0] sample_value;
        input integer block;
        input integer row;
        input integer col;
        begin
            case (block)
                0: sample_value = 0;
                1: sample_value = 32'sd12;
                2: sample_value = (row * 8 + col) - 32;
                default: sample_value = 0;
            endcase
        end
    endfunction

    initial begin
        out_file = $fopen("tests/d2dct_output.txt", "w");
        rst_n = 1'b0;
        data_in = 'b0;
        pixel_valid = 1'b0;
        line_last = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        for (block_idx = 0; block_idx < NUM_BLOCKS; block_idx = block_idx + 1) begin
            for (row_idx = 0; row_idx < 8; row_idx = row_idx + 1) begin
                @(negedge clk);
                for (col_idx = 0; col_idx < 8; col_idx = col_idx + 1) begin
                    pixel_valid = 1'b1;
                    line_last = (col_idx == 7);
                    data_in = sample_value(block_idx, row_idx, col_idx);
                    @(posedge clk);
                    @(negedge clk);
                end
                pixel_valid = 1'b0;
                line_last = 1'b0;
                data_in = 'b0;
                repeat (2) @(posedge clk);
            end
            repeat (12) @(posedge clk);
        end

        repeat (20) @(posedge clk);
        $fclose(out_file);
        $display("D2DCT vectors written.");
        $finish;
    end

    always @(negedge clk) begin
        if (d2dct_valid) begin
            for (coeff_idx = 0; coeff_idx < 64; coeff_idx = coeff_idx + 1) begin
                if (coeff_idx != 0) $fwrite(out_file, " ");
                $fwrite(
                    out_file,
                    "%0d",
                    $signed(d2dct_out[coeff_idx*DOUT_WIDTH +: DOUT_WIDTH])
                );
            end
            $fwrite(out_file, "\n");
        end
    end
endmodule
