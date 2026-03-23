`timescale 1ns/1ps

module tb_huffman_encoder();
    localparam DIN_WIDTH = 12;

    reg clk;
    reg rst_n;
    reg [64*DIN_WIDTH-1:0] zigzag_in;
    reg zigzag_valid;
    reg [1:0] component_type;

    wire [15:0] bits_out;
    wire [4:0] bits_len;
    wire bits_valid;
    wire block_done;

    integer fail_count;
    integer event_count;

    huffman_encoder #(.DIN_WIDTH(DIN_WIDTH)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .zigzag_in(zigzag_in),
        .zigzag_valid(zigzag_valid),
        .component_type(component_type),
        .bits_out(bits_out),
        .bits_len(bits_len),
        .bits_valid(bits_valid),
        .block_done(block_done)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic set_coeff;
        input integer idx;
        input signed [DIN_WIDTH-1:0] value;
        begin
            zigzag_in[idx*DIN_WIDTH +: DIN_WIDTH] = value;
        end
    endtask

    task automatic clear_block;
        integer k;
        begin
            for (k = 0; k < 64; k = k + 1) begin
                set_coeff(k, 'sd0);
            end
        end
    endtask

    task automatic expect_symbol;
        input [15:0] exp_bits;
        input [4:0] exp_len;
        input exp_done;
        integer wait_cycles;
        begin
            begin : wait_for_symbol
                wait_cycles = 0;
                @(posedge clk);
                while (!bits_valid) begin
                    if (block_done) begin
                        $display("ERROR: block_done asserted before symbol %0d", event_count);
                        fail_count = fail_count + 1;
                        disable wait_for_symbol;
                    end
                    wait_cycles = wait_cycles + 1;
                    if (wait_cycles > 32) begin
                        $display("ERROR: timeout waiting for symbol %0d", event_count);
                        fail_count = fail_count + 1;
                        disable wait_for_symbol;
                    end
                    @(posedge clk);
                end
            end

            if (bits_valid) begin
                if (bits_len !== exp_len || bits_out !== exp_bits) begin
                    $display(
                        "ERROR: symbol %0d mismatch exp len=%0d bits=%h got len=%0d bits=%h",
                        event_count, exp_len, exp_bits, bits_len, bits_out
                    );
                    fail_count = fail_count + 1;
                end

                if (block_done !== exp_done) begin
                    $display(
                        "ERROR: symbol %0d block_done mismatch exp=%0d got=%0d",
                        event_count, exp_done, block_done
                    );
                    fail_count = fail_count + 1;
                end

                event_count = event_count + 1;
            end
        end
    endtask

    task automatic expect_idle_cycles;
        input integer cycles;
        integer wait_cycles;
        begin
            for (wait_cycles = 0; wait_cycles < cycles; wait_cycles = wait_cycles + 1) begin
                @(posedge clk);
                if (bits_valid || block_done) begin
                    $display(
                        "ERROR: unexpected post-block activity len=%0d bits=%h valid=%0d done=%0d",
                        bits_len, bits_out, bits_valid, block_done
                    );
                    fail_count = fail_count + 1;
                end
            end
        end
    endtask

    task automatic drive_block;
        input [1:0] comp;
        begin
            component_type = comp;
            zigzag_valid = 1'b1;
            @(posedge clk);
            zigzag_valid = 1'b0;
        end
    endtask

    initial begin
        fail_count = 0;
        event_count = 0;
        rst_n = 1'b0;
        zigzag_in = 'b0;
        zigzag_valid = 1'b0;
        component_type = 2'd0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // Block 1, luma: DC=5, AC1=1, AC3=-1, rest zero.
        clear_block();
        set_coeff(0, 12'sd5);
        set_coeff(1, 12'sd1);
        set_coeff(3, -12'sd1);
        drive_block(2'd0);

        expect_symbol(16'h0004, 5'd3, 1'b0); // Luma DC category 3
        expect_symbol(16'h0005, 5'd3, 1'b0); // DC diff +5
        expect_symbol(16'h0000, 5'd2, 1'b0); // AC (0,1)
        expect_symbol(16'h0001, 5'd1, 1'b0); // +1
        expect_symbol(16'h000c, 5'd4, 1'b0); // AC (1,1)
        expect_symbol(16'hfffe, 5'd1, 1'b0); // -1 encoded as 0
        expect_symbol(16'h000a, 5'd4, 1'b1); // EOB

        // Block 2, luma: DC predictor should use previous DC=5, so diff=2.
        clear_block();
        set_coeff(0, 12'sd7);
        drive_block(2'd0);

        expect_symbol(16'h0003, 5'd3, 1'b0); // Luma DC category 2
        expect_symbol(16'h0002, 5'd2, 1'b0); // DC diff +2
        expect_symbol(16'h000a, 5'd4, 1'b1); // EOB

        // Block 3, chroma: DC=2, AC1=1 to verify chroma tables.
        clear_block();
        set_coeff(0, 12'sd2);
        set_coeff(1, 12'sd1);
        drive_block(2'd1);

        expect_symbol(16'h0002, 5'd2, 1'b0); // Chroma DC category 2
        expect_symbol(16'h0002, 5'd2, 1'b0); // DC diff +2
        expect_symbol(16'h0001, 5'd2, 1'b0); // Chroma AC (0,1)
        expect_symbol(16'h0001, 5'd1, 1'b0); // +1
        expect_symbol(16'h0000, 5'd2, 1'b1); // Chroma EOB

        // Block 4, luma: after three ZRLs, a supported (1,1) code should be emitted.
        clear_block();
        set_coeff(0, 12'sd7);
        set_coeff(50, 12'sd1);
        drive_block(2'd0);

        expect_symbol(16'h0000, 5'd2, 1'b0); // Luma DC category 0
        expect_symbol(16'h07f9, 5'd11, 1'b0); // ZRL for first 16 zeros
        expect_symbol(16'h07f9, 5'd11, 1'b0); // ZRL for second 16 zeros
        expect_symbol(16'h07f9, 5'd11, 1'b0); // ZRL for third 16 zeros
        expect_symbol(16'h000c, 5'd4, 1'b0); // AC (1,1) after 15 trailing zeros
        expect_symbol(16'h0001, 5'd1, 1'b0); // Final non-zero AC value
        expect_symbol(16'h000a, 5'd4, 1'b1); // Immediate EOB for the all-zero tail
        expect_idle_cycles(4);

        if (fail_count != 0) begin
            $display("TB FAILED with %0d errors", fail_count);
            $fatal(1);
        end

        $display("TB PASSED");
        $finish;
    end

    initial begin
        #1000000;
        $display("ERROR: global timeout");
        $fatal(1);
    end
endmodule
