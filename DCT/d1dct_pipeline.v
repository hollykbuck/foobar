module d1dct_pipeline #(
    parameter DIN_WIDTH = 32
)(
    input clk,
    input rst_n,
    input [8*DIN_WIDTH-1:0] wind_in,
    input wind_valid,

    output [8*(DIN_WIDTH+10)-1:0] d1dct_out,
    output d1dct_valid
);

    localparam DOUT_WIDTH = DIN_WIDTH + 10;
    localparam SUM_WIDTH = DIN_WIDTH + 20;

    // Orthonormal 1D DCT matrix coefficients scaled by 1024.
    localparam signed [9:0] C00 = 10'sd362;
    localparam signed [9:0] C01 = 10'sd362;
    localparam signed [9:0] C02 = 10'sd362;
    localparam signed [9:0] C03 = 10'sd362;
    localparam signed [9:0] C04 = 10'sd362;
    localparam signed [9:0] C05 = 10'sd362;
    localparam signed [9:0] C06 = 10'sd362;
    localparam signed [9:0] C07 = 10'sd362;

    localparam signed [9:0] C10 = 10'sd502;
    localparam signed [9:0] C11 = 10'sd426;
    localparam signed [9:0] C12 = 10'sd284;
    localparam signed [9:0] C13 = 10'sd100;
    localparam signed [9:0] C14 = -10'sd100;
    localparam signed [9:0] C15 = -10'sd284;
    localparam signed [9:0] C16 = -10'sd426;
    localparam signed [9:0] C17 = -10'sd502;

    localparam signed [9:0] C20 = 10'sd473;
    localparam signed [9:0] C21 = 10'sd196;
    localparam signed [9:0] C22 = -10'sd196;
    localparam signed [9:0] C23 = -10'sd473;
    localparam signed [9:0] C24 = -10'sd473;
    localparam signed [9:0] C25 = -10'sd196;
    localparam signed [9:0] C26 = 10'sd196;
    localparam signed [9:0] C27 = 10'sd473;

    localparam signed [9:0] C30 = 10'sd426;
    localparam signed [9:0] C31 = -10'sd100;
    localparam signed [9:0] C32 = -10'sd502;
    localparam signed [9:0] C33 = -10'sd284;
    localparam signed [9:0] C34 = 10'sd284;
    localparam signed [9:0] C35 = 10'sd502;
    localparam signed [9:0] C36 = 10'sd100;
    localparam signed [9:0] C37 = -10'sd426;

    localparam signed [9:0] C40 = 10'sd362;
    localparam signed [9:0] C41 = -10'sd362;
    localparam signed [9:0] C42 = -10'sd362;
    localparam signed [9:0] C43 = 10'sd362;
    localparam signed [9:0] C44 = 10'sd362;
    localparam signed [9:0] C45 = -10'sd362;
    localparam signed [9:0] C46 = -10'sd362;
    localparam signed [9:0] C47 = 10'sd362;

    localparam signed [9:0] C50 = 10'sd284;
    localparam signed [9:0] C51 = -10'sd502;
    localparam signed [9:0] C52 = 10'sd100;
    localparam signed [9:0] C53 = 10'sd426;
    localparam signed [9:0] C54 = -10'sd426;
    localparam signed [9:0] C55 = -10'sd100;
    localparam signed [9:0] C56 = 10'sd502;
    localparam signed [9:0] C57 = -10'sd284;

    localparam signed [9:0] C60 = 10'sd196;
    localparam signed [9:0] C61 = -10'sd473;
    localparam signed [9:0] C62 = 10'sd473;
    localparam signed [9:0] C63 = -10'sd196;
    localparam signed [9:0] C64 = -10'sd196;
    localparam signed [9:0] C65 = 10'sd473;
    localparam signed [9:0] C66 = -10'sd473;
    localparam signed [9:0] C67 = 10'sd196;

    localparam signed [9:0] C70 = 10'sd100;
    localparam signed [9:0] C71 = -10'sd284;
    localparam signed [9:0] C72 = 10'sd426;
    localparam signed [9:0] C73 = -10'sd502;
    localparam signed [9:0] C74 = 10'sd502;
    localparam signed [9:0] C75 = -10'sd426;
    localparam signed [9:0] C76 = 10'sd284;
    localparam signed [9:0] C77 = -10'sd100;

    reg signed [DIN_WIDTH-1:0] x0, x1, x2, x3, x4, x5, x6, x7;
    reg s1_valid;

    reg signed [DOUT_WIDTH-1:0] out0, out1, out2, out3, out4, out5, out6, out7;
    reg out_valid;

    function automatic signed [DOUT_WIDTH-1:0] round_shift_10;
        input signed [SUM_WIDTH-1:0] value;
        reg signed [SUM_WIDTH-1:0] biased;
        begin
            if (value >= 0)
                biased = value + 11'sd512;
            else
                biased = value - 11'sd512;
            round_shift_10 = biased >>> 10;
        end
    endfunction

    wire signed [SUM_WIDTH-1:0] sum0 =
        x0 * C00 + x1 * C01 + x2 * C02 + x3 * C03 +
        x4 * C04 + x5 * C05 + x6 * C06 + x7 * C07;
    wire signed [SUM_WIDTH-1:0] sum1 =
        x0 * C10 + x1 * C11 + x2 * C12 + x3 * C13 +
        x4 * C14 + x5 * C15 + x6 * C16 + x7 * C17;
    wire signed [SUM_WIDTH-1:0] sum2 =
        x0 * C20 + x1 * C21 + x2 * C22 + x3 * C23 +
        x4 * C24 + x5 * C25 + x6 * C26 + x7 * C27;
    wire signed [SUM_WIDTH-1:0] sum3 =
        x0 * C30 + x1 * C31 + x2 * C32 + x3 * C33 +
        x4 * C34 + x5 * C35 + x6 * C36 + x7 * C37;
    wire signed [SUM_WIDTH-1:0] sum4 =
        x0 * C40 + x1 * C41 + x2 * C42 + x3 * C43 +
        x4 * C44 + x5 * C45 + x6 * C46 + x7 * C47;
    wire signed [SUM_WIDTH-1:0] sum5 =
        x0 * C50 + x1 * C51 + x2 * C52 + x3 * C53 +
        x4 * C54 + x5 * C55 + x6 * C56 + x7 * C57;
    wire signed [SUM_WIDTH-1:0] sum6 =
        x0 * C60 + x1 * C61 + x2 * C62 + x3 * C63 +
        x4 * C64 + x5 * C65 + x6 * C66 + x7 * C67;
    wire signed [SUM_WIDTH-1:0] sum7 =
        x0 * C70 + x1 * C71 + x2 * C72 + x3 * C73 +
        x4 * C74 + x5 * C75 + x6 * C76 + x7 * C77;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x0 <= 0;
            x1 <= 0;
            x2 <= 0;
            x3 <= 0;
            x4 <= 0;
            x5 <= 0;
            x6 <= 0;
            x7 <= 0;
            s1_valid <= 0;
        end else begin
            x0 <= $signed(wind_in[8*DIN_WIDTH-1 : 7*DIN_WIDTH]);
            x1 <= $signed(wind_in[7*DIN_WIDTH-1 : 6*DIN_WIDTH]);
            x2 <= $signed(wind_in[6*DIN_WIDTH-1 : 5*DIN_WIDTH]);
            x3 <= $signed(wind_in[5*DIN_WIDTH-1 : 4*DIN_WIDTH]);
            x4 <= $signed(wind_in[4*DIN_WIDTH-1 : 3*DIN_WIDTH]);
            x5 <= $signed(wind_in[3*DIN_WIDTH-1 : 2*DIN_WIDTH]);
            x6 <= $signed(wind_in[2*DIN_WIDTH-1 : 1*DIN_WIDTH]);
            x7 <= $signed(wind_in[1*DIN_WIDTH-1 : 0*DIN_WIDTH]);
            s1_valid <= wind_valid;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out0 <= 0;
            out1 <= 0;
            out2 <= 0;
            out3 <= 0;
            out4 <= 0;
            out5 <= 0;
            out6 <= 0;
            out7 <= 0;
            out_valid <= 0;
        end else begin
            out0 <= round_shift_10(sum0);
            out1 <= round_shift_10(sum1);
            out2 <= round_shift_10(sum2);
            out3 <= round_shift_10(sum3);
            out4 <= round_shift_10(sum4);
            out5 <= round_shift_10(sum5);
            out6 <= round_shift_10(sum6);
            out7 <= round_shift_10(sum7);
            out_valid <= s1_valid;
        end
    end

    assign d1dct_out = {out0, out1, out2, out3, out4, out5, out6, out7};
    assign d1dct_valid = out_valid;

endmodule
