module transpose_buffer #(
    parameter                       DIN_WIDTH      = 32                 ,
    parameter                       WINDOW_WIDTH   = 64*32              
) (
    input                           clk                 ,
    input                           rst_n               ,
    input  [64*(DIN_WIDTH+10)-1:0]  d1dct_out           ,
    input                           d1dct_valid         , 

    output reg [64*(DIN_WIDTH+10)-1:0] trans_out           ,
    output reg                        trans_valid         
);

    localparam W = DIN_WIDTH + 10;
    wire [64*W-1:0] next_trans_out;

    // Unrolled transpose logic
    genvar i, j;
    generate
        for (i = 0; i < 8; i = i + 1) begin : row
            for (j = 0; j < 8; j = j + 1) begin : col
                assign next_trans_out[(j*8+i+1)*W-1 : (j*8+i)*W] = d1dct_out[(i*8+j+1)*W-1 : (i*8+j)*W];
            end
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trans_out <= 0;
            trans_valid <= 0;
        end else begin
            trans_out <= next_trans_out;
            trans_valid <= d1dct_valid;
        end
    end

endmodule
