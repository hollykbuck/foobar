`timescale 1ns/1ps

module tb_d1dct_pipeline();
    localparam DIN_WIDTH = 32;
    localparam DOUT_WIDTH = DIN_WIDTH + 10;
    localparam NUM_VECTORS = 5;

    reg clk;
    reg rst_n;
    reg [8*DIN_WIDTH-1:0] wind_in;
    reg wind_valid;
    wire [8*DOUT_WIDTH-1:0] d1dct_out;
    wire d1dct_valid;

    integer out_file;
    integer vec_idx;
    integer coeff_idx;

    d1dct_pipeline #(
        .DIN_WIDTH(DIN_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .wind_in(wind_in),
        .wind_valid(wind_valid),
        .d1dct_out(d1dct_out),
        .d1dct_valid(d1dct_valid)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic set_input_coeff;
        input integer idx;
        input signed [DIN_WIDTH-1:0] coeff;
        begin
            wind_in[(8-idx)*DIN_WIDTH-1 -: DIN_WIDTH] = coeff;
        end
    endtask

    task automatic load_vector;
        input integer idx;
        integer i;
        begin
            wind_in = 'b0;
            case (idx)
                0: begin
                    for (i = 0; i < 8; i = i + 1) set_input_coeff(i, 0);
                end
                1: begin
                    for (i = 0; i < 8; i = i + 1) set_input_coeff(i, 32'sd5);
                end
                2: begin
                    set_input_coeff(0, 32'sd32);
                    for (i = 1; i < 8; i = i + 1) set_input_coeff(i, 0);
                end
                3: begin
                    set_input_coeff(0, -32'sd28);
                    set_input_coeff(1, -32'sd20);
                    set_input_coeff(2, -32'sd12);
                    set_input_coeff(3, -32'sd4);
                    set_input_coeff(4, 32'sd4);
                    set_input_coeff(5, 32'sd12);
                    set_input_coeff(6, 32'sd20);
                    set_input_coeff(7, 32'sd28);
                end
                4: begin
                    set_input_coeff(0, 32'sd11);
                    set_input_coeff(1, -32'sd7);
                    set_input_coeff(2, 32'sd3);
                    set_input_coeff(3, -32'sd19);
                    set_input_coeff(4, 32'sd23);
                    set_input_coeff(5, -32'sd5);
                    set_input_coeff(6, 32'sd2);
                    set_input_coeff(7, -32'sd13);
                end
            endcase
        end
    endtask

    initial begin
        out_file = $fopen("tests/d1dct_pipeline_output.txt", "w");
        rst_n = 1'b0;
        wind_in = 'b0;
        wind_valid = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        for (vec_idx = 0; vec_idx < NUM_VECTORS; vec_idx = vec_idx + 1) begin
            load_vector(vec_idx);
            @(negedge clk);
            wind_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            wind_valid = 1'b0;
            repeat (3) @(posedge clk);
        end

        $fclose(out_file);
        $display("D1DCT pipeline vectors written.");
        $finish;
    end

    always @(negedge clk) begin
        if (d1dct_valid) begin
            for (coeff_idx = 0; coeff_idx < 8; coeff_idx = coeff_idx + 1) begin
                if (coeff_idx != 0) $fwrite(out_file, " ");
                $fwrite(
                    out_file,
                    "%0d",
                    $signed(d1dct_out[(8-coeff_idx)*DOUT_WIDTH-1 -: DOUT_WIDTH])
                );
            end
            $fwrite(out_file, "\n");
        end
    end
endmodule
