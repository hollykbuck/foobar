`timescale 1ns/1ps

module tb_stage_analysis();
    localparam QUANT_DIN_WIDTH = 32;
    localparam QUANT_DOUT_WIDTH = 12;
    localparam ZIGZAG_DIN_WIDTH = 12;

    reg clk;
    reg rst_n;

    reg [7:0] r;
    reg [7:0] g;
    reg [7:0] b;
    reg rgb_valid_in;
    wire [7:0] y;
    wire [7:0] cb;
    wire [7:0] cr;
    wire rgb_valid_out;

    reg [64*(QUANT_DIN_WIDTH+20)-1:0] quant_in;
    reg quant_valid_in;
    reg [1:0] quant_component_type;
    wire [64*QUANT_DOUT_WIDTH-1:0] quant_out;
    wire quant_valid_out;

    reg [64*ZIGZAG_DIN_WIDTH-1:0] zigzag_in;
    reg zigzag_valid_in;
    wire [64*ZIGZAG_DIN_WIDTH-1:0] zigzag_out;
    wire zigzag_valid_out;

    integer rgb_file;
    integer quant_file;
    integer zigzag_file;
    integer idx;
    integer mon_idx;

    rgb2ycbcr rgb2ycbcr_u (
        .clk(clk),
        .rst_n(rst_n),
        .r(r),
        .g(g),
        .b(b),
        .valid_in(rgb_valid_in),
        .y(y),
        .cb(cb),
        .cr(cr),
        .valid_out(rgb_valid_out)
    );

    quantizer #(
        .DIN_WIDTH(QUANT_DIN_WIDTH),
        .DOUT_WIDTH(QUANT_DOUT_WIDTH)
    ) quantizer_u (
        .clk(clk),
        .rst_n(rst_n),
        .dct_in(quant_in),
        .dct_valid(quant_valid_in),
        .component_type(quant_component_type),
        .quant_out(quant_out),
        .quant_valid(quant_valid_out)
    );

    zigzag #(
        .DIN_WIDTH(ZIGZAG_DIN_WIDTH)
    ) zigzag_u (
        .clk(clk),
        .rst_n(rst_n),
        .quant_in(zigzag_in),
        .quant_valid(zigzag_valid_in),
        .zigzag_out(zigzag_out),
        .zigzag_valid(zigzag_valid_out)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic set_quant_coeff;
        input integer coeff_idx;
        input signed [QUANT_DIN_WIDTH+19:0] coeff_val;
        begin
            quant_in[(coeff_idx+1)*(QUANT_DIN_WIDTH+20)-1 -: (QUANT_DIN_WIDTH+20)] = coeff_val;
        end
    endtask

    task automatic set_zigzag_coeff;
        input integer coeff_idx;
        input signed [ZIGZAG_DIN_WIDTH-1:0] coeff_val;
        begin
            zigzag_in[(coeff_idx+1)*ZIGZAG_DIN_WIDTH-1 -: ZIGZAG_DIN_WIDTH] = coeff_val;
        end
    endtask

    initial begin
        rgb_file = $fopen("tests/stage_rgb2ycbcr.txt", "w");
        quant_file = $fopen("tests/stage_quantizer.txt", "w");
        zigzag_file = $fopen("tests/stage_zigzag.txt", "w");

        rst_n = 1'b0;
        r = 8'd0;
        g = 8'd0;
        b = 8'd0;
        rgb_valid_in = 1'b0;
        quant_in = 'b0;
        quant_valid_in = 1'b0;
        quant_component_type = 2'd0;
        zigzag_in = 'b0;
        zigzag_valid_in = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // RGB2YCbCr samples match the image pattern and a few corners.
        rgb_valid_in = 1'b1;
        r = 8'd0;   g = 8'd5;   b = 8'd10;  @(posedge clk);
        r = 8'd15;  g = 8'd20;  b = 8'd25;  @(posedge clk);
        r = 8'd120; g = 8'd125; b = 8'd130; @(posedge clk);
        r = 8'd240; g = 8'd245; b = 8'd250; @(posedge clk);
        rgb_valid_in = 1'b0;
        repeat (4) @(posedge clk);

        // Quantizer samples include negative coefficients to expose sign rounding behavior.
        for (idx = 0; idx < 64; idx = idx + 1) begin
            set_quant_coeff(idx, $signed((idx - 20) * 17));
        end
        $display("QUANT_IN=%h", quant_in);
        quant_component_type = 2'd0;
        @(negedge clk);
        quant_valid_in = 1'b1;
        @(posedge clk);
        @(negedge clk);
        quant_valid_in = 1'b0;
        @(posedge clk);

        // Zigzag samples use a known ramp.
        for (idx = 0; idx < 64; idx = idx + 1) begin
            set_zigzag_coeff(idx, idx);
        end
        $display("ZIGZAG_IN=%h", zigzag_in);
        @(negedge clk);
        zigzag_valid_in = 1'b1;
        @(posedge clk);
        @(negedge clk);
        zigzag_valid_in = 1'b0;
        @(posedge clk);

        $fclose(rgb_file);
        $fclose(quant_file);
        $fclose(zigzag_file);
        $display("Stage analysis vectors written.");
        $finish;
    end

    always @(negedge clk) begin
        if (rgb_valid_out) begin
            $fdisplay(rgb_file, "%0d %0d %0d", y, cb, cr);
        end
        if (quant_valid_out) begin
            $display("QUANT_OUT=%h", quant_out);
            for (mon_idx = 0; mon_idx < 64; mon_idx = mon_idx + 1) begin
                $fdisplay(
                    quant_file,
                    "%0d",
                    $signed(quant_out[(mon_idx+1)*QUANT_DOUT_WIDTH-1 -: QUANT_DOUT_WIDTH])
                );
            end
        end
        if (zigzag_valid_out) begin
            $display("ZIGZAG_OUT=%h", zigzag_out);
            for (mon_idx = 0; mon_idx < 64; mon_idx = mon_idx + 1) begin
                $fdisplay(
                    zigzag_file,
                    "%0d",
                    $signed(zigzag_out[(mon_idx+1)*ZIGZAG_DIN_WIDTH-1 -: ZIGZAG_DIN_WIDTH])
                );
            end
        end
    end
endmodule
