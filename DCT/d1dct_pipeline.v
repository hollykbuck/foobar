module d1dct_pipeline #(
    parameter                       DIN_WIDTH      = 32                 ,
    parameter                       WINDOW_WIDTH   = 64*32              ,
    parameter                       M1             = 35'h0000_0000      , // cos(pi/16)*sqrt(2) * 2^16
    parameter                       M2             = 35'h0000_0000      , // cos(pi/16)*sqrt(2) * 2^16
    parameter                       M3             = 35'h0000_0000      , // cos(pi/16)*sqrt(2) * 2^16
    parameter                       M4             = 35'h0000_0000        // cos(pi/16)*sqrt(2) * 2^16
)(
    input                           clk                 ,
    input                           rst_n               ,
    input  [WINDOW_WIDTH-1:0]       wind_in             ,
    input                           wind_valid          , 

    output [8*(DIN_WIDTH+5)-1:0]    d1dct_out           ,
    output                          d1dct_valid         
);

reg [4:0] rd1dct_valid;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd1dct_valid <= 0;
    end else begin
        rd1dct_valid <= {rd1dct_valid[3:0], wind_valid};
    end
end

assign d1dct_valid = rd1dct_valid[4];

// unpack

wire [WINDOW_WIDTH-1:(WINDOW_WIDTH/DIN_WIDTH-8)*DIN_WIDTH]                              wind_line1;
wire [(WINDOW_WIDTH/DIN_WIDTH-8)*DIN_WIDTH-1:(WINDOW_WIDTH/DIN_WIDTH-16)*DIN_WIDTH]     wind_line2;
wire [(WINDOW_WIDTH/DIN_WIDTH-16)*DIN_WIDTH-1:(WINDOW_WIDTH/DIN_WIDTH-24)*DIN_WIDTH]    wind_line3;
wire [(WINDOW_WIDTH/DIN_WIDTH-24)*DIN_WIDTH-1:(WINDOW_WIDTH/DIN_WIDTH-32)*DIN_WIDTH]    wind_line4;
wire [(WINDOW_WIDTH/DIN_WIDTH-32)*DIN_WIDTH-1:(WINDOW_WIDTH/DIN_WIDTH-40)*DIN_WIDTH]    wind_line5;
wire [(WINDOW_WIDTH/DIN_WIDTH-40)*DIN_WIDTH-1:(WINDOW_WIDTH/DIN_WIDTH-48)*DIN_WIDTH]    wind_line6;
wire [(WINDOW_WIDTH/DIN_WIDTH-48)*DIN_WIDTH-1:(WINDOW_WIDTH/DIN_WIDTH-56)*DIN_WIDTH]    wind_line7;
wire [(WINDOW_WIDTH/DIN_WIDTH-56)*DIN_WIDTH-1:(WINDOW_WIDTH/DIN_WIDTH-64)*DIN_WIDTH]    wind_line8;

// 1D DCT input
wire [DIN_WIDTH-1:0] dct_a0 = wind_line1[8*DIN_WIDTH-1:8*DIN_WIDTH-DIN_WIDTH];
wire [DIN_WIDTH-1:0] dct_a1 = wind_line1[7*DIN_WIDTH-1:7*DIN_WIDTH-DIN_WIDTH];
wire [DIN_WIDTH-1:0] dct_a2 = wind_line1[6*DIN_WIDTH-1:6*DIN_WIDTH-DIN_WIDTH];
wire [DIN_WIDTH-1:0] dct_a3 = wind_line1[5*DIN_WIDTH-1:5*DIN_WIDTH-DIN_WIDTH];
wire [DIN_WIDTH-1:0] dct_a4 = wind_line1[4*DIN_WIDTH-1:4*DIN_WIDTH-DIN_WIDTH];
wire [DIN_WIDTH-1:0] dct_a5 = wind_line1[3*DIN_WIDTH-1:3*DIN_WIDTH-DIN_WIDTH];
wire [DIN_WIDTH-1:0] dct_a6 = wind_line1[2*DIN_WIDTH-1:2*DIN_WIDTH-DIN_WIDTH];
wire [DIN_WIDTH-1:0] dct_a7 = wind_line1[1*DIN_WIDTH-1:1*DIN_WIDTH-DIN_WIDTH];

// piepeline1 : step1

wire [DIN_WIDTH:0] dct_b0;
wire [DIN_WIDTH:0] dct_b1;
wire [DIN_WIDTH:0] dct_b2;
wire [DIN_WIDTH:0] dct_b3;
wire [DIN_WIDTH:0] dct_b4;
wire [DIN_WIDTH:0] dct_b5;
wire [DIN_WIDTH:0] dct_b6;
wire [DIN_WIDTH:0] dct_b7;

assign dct_b0 = dct_a0 + dct_a7;
assign dct_b1 = dct_a1 + dct_a6;
assign dct_b2 = dct_a3 - dct_a4;
assign dct_b3 = dct_a1 - dct_a6;
assign dct_b4 = dct_a2 + dct_a5;
assign dct_b5 = dct_a3 + dct_a4;
assign dct_b6 = dct_a2 - dct_a5;
assign dct_b7 = dct_a0 - dct_a7;

reg [DIN_WIDTH:0] rdct_b0;
reg [DIN_WIDTH:0] rdct_b1;
reg [DIN_WIDTH:0] rdct_b2;
reg [DIN_WIDTH:0] rdct_b3;
reg [DIN_WIDTH:0] rdct_b4;
reg [DIN_WIDTH:0] rdct_b5;
reg [DIN_WIDTH:0] rdct_b6;
reg [DIN_WIDTH:0] rdct_b7;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rdct_b0 <= 0;
        rdct_b1 <= 0;
        rdct_b2 <= 0;
        rdct_b3 <= 0;
        rdct_b4 <= 0;
        rdct_b5 <= 0;
        rdct_b6 <= 0;
        rdct_b7 <= 0;
    end else begin
        rdct_b0 <= dct_b0;
        rdct_b1 <= dct_b1;
        rdct_b2 <= dct_b2;
        rdct_b3 <= dct_b3;
        rdct_b4 <= dct_b4;
        rdct_b5 <= dct_b5;
        rdct_b6 <= dct_b6;
        rdct_b7 <= dct_b7;
    end
end

// pipeline2 : step2

wire [DIN_WIDTH+1:0] dct_c0;
wire [DIN_WIDTH+1:0] dct_c1;
wire [DIN_WIDTH+1:0] dct_c2;
wire [DIN_WIDTH+1:0] dct_c3;
wire [DIN_WIDTH+1:0] dct_c4;
wire [DIN_WIDTH+1:0] dct_c5;
wire [DIN_WIDTH+1:0] dct_c6;
wire [DIN_WIDTH+1:0] dct_c7;

assign dct_c0 = rdct_b0 + rdct_b5;
assign dct_c1 = rdct_b1 - rdct_b4;
assign dct_c2 = rdct_b2 + rdct_b6;
assign dct_c3 = rdct_b1 + rdct_b4;
assign dct_c4 = rdct_b0 - rdct_b5;
assign dct_c5 = rdct_b3 + rdct_b7;
assign dct_c6 = rdct_b3 + rdct_b6;
assign dct_c7 = {1'b0, rdct_b7};

reg [DIN_WIDTH+1:0] rdct_c0;
reg [DIN_WIDTH+1:0] rdct_c1;
reg [DIN_WIDTH+1:0] rdct_c2;
reg [DIN_WIDTH+1:0] rdct_c3;
reg [DIN_WIDTH+1:0] rdct_c4;
reg [DIN_WIDTH+1:0] rdct_c5;
reg [DIN_WIDTH+1:0] rdct_c6;
reg [DIN_WIDTH+1:0] rdct_c7;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rdct_c0 <= 0;
        rdct_c1 <= 0;
        rdct_c2 <= 0;
        rdct_c3 <= 0;
        rdct_c4 <= 0;
        rdct_c5 <= 0;
        rdct_c6 <= 0;
        rdct_c7 <= 0;
    end else begin
        rdct_c0 <= dct_c0;
        rdct_c1 <= dct_c1;
        rdct_c2 <= dct_c2;
        rdct_c3 <= dct_c3;
        rdct_c4 <= dct_c4;
        rdct_c5 <= dct_c5;
        rdct_c6 <= dct_c6;
        rdct_c7 <= dct_c7;
    end
end

// pipeline3 : step3

wire [DIN_WIDTH+2:0] dct_d0;
wire [DIN_WIDTH+2:0] dct_d1;
wire [DIN_WIDTH+2:0] dct_d2;
wire [DIN_WIDTH+2:0] dct_d3;
wire [DIN_WIDTH+2:0] dct_d4;
wire [DIN_WIDTH+2:0] dct_d5;
wire [DIN_WIDTH+2:0] dct_d6;
wire [DIN_WIDTH+2:0] dct_d7;
wire [DIN_WIDTH+2:0] dct_d8;

assign dct_d0 = rdct_c0 + rdct_c3;
assign dct_d1 = rdct_c0 - rdct_c3;
assign dct_d2 = {1'b0, rdct_c2};
assign dct_d3 = rdct_c1 + rdct_c4;
assign dct_d4 = rdct_c2 - rdct_c5;
assign dct_d5 = {1'b0, rdct_c4};
assign dct_d6 = {1'b0, rdct_c5};
assign dct_d7 = {1'b0, rdct_c6};
assign dct_d8 = {1'b0, rdct_c7};

reg [DIN_WIDTH+2:0] rdct_d0;
reg [DIN_WIDTH+2:0] rdct_d1;
reg [DIN_WIDTH+2:0] rdct_d2;
reg [DIN_WIDTH+2:0] rdct_d3;
reg [DIN_WIDTH+2:0] rdct_d4;
reg [DIN_WIDTH+2:0] rdct_d5;
reg [DIN_WIDTH+2:0] rdct_d6;
reg [DIN_WIDTH+2:0] rdct_d7;
reg [DIN_WIDTH+2:0] rdct_d8;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rdct_d0 <= 0;
        rdct_d1 <= 0;
        rdct_d2 <= 0;
        rdct_d3 <= 0;
        rdct_d4 <= 0;
        rdct_d5 <= 0;
        rdct_d6 <= 0;
        rdct_d7 <= 0;
        rdct_d8 <= 0;
    end else begin
        rdct_d0 <= dct_d0;
        rdct_d1 <= dct_d1;
        rdct_d2 <= dct_d2;
        rdct_d3 <= dct_d3;
        rdct_d4 <= dct_d4;
        rdct_d5 <= dct_d5;
        rdct_d6 <= dct_d6;
        rdct_d7 <= dct_d7;
        rdct_d8 <= dct_d8;
    end
end


// pipeline4 : step4
// multiply and truncate
wire [DIN_WIDTH+2:0] dct_e0;
wire [DIN_WIDTH+2:0] dct_e1;
wire [DIN_WIDTH+2:0] dct_e2;
wire [DIN_WIDTH+2:0] dct_e3;
wire [DIN_WIDTH+2:0] dct_e4;
wire [DIN_WIDTH+2:0] dct_e5;
wire [DIN_WIDTH+2:0] dct_e6;
wire [DIN_WIDTH+2:0] dct_e7;
wire [DIN_WIDTH+2:0] dct_e8;

assign  dct_e0 = {1'b0, dct_d0};
assign  dct_e1 = {1'b0, dct_d1};
assign  dct_e2 = M3 * dct_d2;
assign  dct_e3 = M1 * dct_d7;
assign  dct_e4 = M4 * dct_d6;
assign  dct_e5 = {1'b0, dct_d5};
assign  dct_e6 = M1 * dct_d3;
assign  dct_e7 = M2 * dct_d4;
assign  dct_e8 = {1'b0, dct_d8};

reg [DIN_WIDTH+2:0] rdct_e0;
reg [DIN_WIDTH+2:0] rdct_e1;
reg [DIN_WIDTH+2:0] rdct_e2;
reg [DIN_WIDTH+2:0] rdct_e3;
reg [DIN_WIDTH+2:0] rdct_e4;
reg [DIN_WIDTH+2:0] rdct_e5;
reg [DIN_WIDTH+2:0] rdct_e6;
reg [DIN_WIDTH+2:0] rdct_e7;
reg [DIN_WIDTH+2:0] rdct_e8;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rdct_e0 <= 0;
        rdct_e1 <= 0;
        rdct_e2 <= 0;
        rdct_e3 <= 0;
        rdct_e4 <= 0;
        rdct_e5 <= 0;
        rdct_e6 <= 0;
        rdct_e7 <= 0;
        rdct_e8 <= 0;
    end else begin
        rdct_e0 <= dct_e0;
        rdct_e1 <= dct_e1;
        rdct_e2 <= dct_e2;
        rdct_e3 <= dct_e3;
        rdct_e4 <= dct_e4;
        rdct_e5 <= dct_e5;
        rdct_e6 <= dct_e6;
        rdct_e7 <= dct_e7;
        rdct_e8 <= dct_e8;
    end
end


// pipeline5 : step5
wire [DIN_WIDTH+3:0] dct_f0;
wire [DIN_WIDTH+3:0] dct_f1;
wire [DIN_WIDTH+3:0] dct_f2;
wire [DIN_WIDTH+3:0] dct_f3;
wire [DIN_WIDTH+3:0] dct_f4;
wire [DIN_WIDTH+3:0] dct_f5;
wire [DIN_WIDTH+3:0] dct_f6;
wire [DIN_WIDTH+3:0] dct_f7;

assign  dct_f0 = {1'b0, dct_e0};
assign  dct_f1 = {1'b0, dct_e1};
assign  dct_f2 = dct_e5 + dct_e6;
assign  dct_f3 = dct_e5 - dct_e6;
assign  dct_f4 = dct_e3 + dct_e8;
assign  dct_f5 = dct_e8 - dct_e3;
assign  dct_f6 = dct_e2 + dct_e7;
assign  dct_f7 = dct_e4 + dct_e7;

reg [DIN_WIDTH+3:0] rdct_f0;
reg [DIN_WIDTH+3:0] rdct_f1;
reg [DIN_WIDTH+3:0] rdct_f2;
reg [DIN_WIDTH+3:0] rdct_f3;
reg [DIN_WIDTH+3:0] rdct_f4;
reg [DIN_WIDTH+3:0] rdct_f5;
reg [DIN_WIDTH+3:0] rdct_f6;
reg [DIN_WIDTH+3:0] rdct_f7;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rdct_f0 <= 0;
        rdct_f1 <= 0;
        rdct_f2 <= 0;
        rdct_f3 <= 0;
        rdct_f4 <= 0;
        rdct_f5 <= 0;
        rdct_f6 <= 0;
        rdct_f7 <= 0;
    end else begin
        rdct_f0 <= dct_f0;
        rdct_f1 <= dct_f1;
        rdct_f2 <= dct_f2;
        rdct_f3 <= dct_f3;
        rdct_f4 <= dct_f4;
        rdct_f5 <= dct_f5;
        rdct_f6 <= dct_f6;
        rdct_f7 <= dct_f7;
    end
end

// pipeline6 : step6
wire [DIN_WIDTH+4:0] dct_s0;
wire [DIN_WIDTH+4:0] dct_s1;
wire [DIN_WIDTH+4:0] dct_s2;
wire [DIN_WIDTH+4:0] dct_s3;
wire [DIN_WIDTH+4:0] dct_s4;
wire [DIN_WIDTH+4:0] dct_s5;
wire [DIN_WIDTH+4:0] dct_s6;
wire [DIN_WIDTH+4:0] dct_s7;

assign  dct_s0 = {1'b0, dct_f0};
assign  dct_s1 = dct_f4 + dct_f7;
assign  dct_s2 = {1'b0, dct_f2};
assign  dct_s3 = dct_f5 - dct_f6;
assign  dct_s4 = {1'b0, dct_f1};
assign  dct_s5 = dct_f5 + dct_f6;
assign  dct_s6 = {1'b0, dct_f3};
assign  dct_s7 = dct_f4 - dct_f7;

reg [DIN_WIDTH+4:0] rdct_s0;
reg [DIN_WIDTH+4:0] rdct_s1;
reg [DIN_WIDTH+4:0] rdct_s2;
reg [DIN_WIDTH+4:0] rdct_s3;
reg [DIN_WIDTH+4:0] rdct_s4;
reg [DIN_WIDTH+4:0] rdct_s5;
reg [DIN_WIDTH+4:0] rdct_s6;
reg [DIN_WIDTH+4:0] rdct_s7;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rdct_s0 <= 0;
        rdct_s1 <= 0;
        rdct_s2 <= 0;
        rdct_s3 <= 0;
        rdct_s4 <= 0;
        rdct_s5 <= 0;
        rdct_s6 <= 0;
        rdct_s7 <= 0;
    end else begin
        rdct_s0 <= dct_s0;
        rdct_s1 <= dct_s1;
        rdct_s2 <= dct_s2;
        rdct_s3 <= dct_s3;
        rdct_s4 <= dct_s4;
        rdct_s5 <= dct_s5;
        rdct_s6 <= dct_s6;
        rdct_s7 <= dct_s7;
    end
end

assign d1dct_out   = {rdct_s0, rdct_s1, rdct_s2, rdct_s3, rdct_s4, rdct_s5, rdct_s6, rdct_s7};
assign d1dct_valid = 



endmodule
