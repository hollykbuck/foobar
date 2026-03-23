module line_buffer #(
    parameter               DIN_WIDTH   = 32        ,
    parameter               DOUT_WIDTH  = 64*32     ,
    parameter               LINE_LEN    = 16
)(
    input                   clk                 ,
    input                   rst_n               ,
    input  [DIN_WIDTH-1:0]  data_in             ,
    input                   pixel_valid         ,
    input                   line_last           ,
    output reg [DOUT_WIDTH-1:0] data_out        ,
    output reg              data_out_valid
);

    reg [DIN_WIDTH-1:0] line_store [0:7][0:LINE_LEN-1];
    reg [15:0] row_idx;
    reg [15:0] col_idx;

    integer r;
    integer c;
    integer base_col;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_idx <= 0;
            col_idx <= 0;
            data_out <= 0;
            data_out_valid <= 0;
            for (r = 0; r < 8; r = r + 1) begin
                for (c = 0; c < LINE_LEN; c = c + 1) begin
                    line_store[r][c] <= 0;
                end
            end
        end else begin
            data_out_valid <= 0;

            if (pixel_valid) begin
                line_store[row_idx[2:0]][col_idx] <= data_in;

                if (row_idx[2:0] == 3'd7 && col_idx[2:0] == 3'd7) begin
                    base_col = col_idx - 7;
                    for (r = 0; r < 8; r = r + 1) begin
                        for (c = 0; c < 8; c = c + 1) begin
                            if (r == row_idx[2:0] && (base_col + c) == col_idx) begin
                                data_out[((64 - (r * 8 + c)) * DIN_WIDTH) - 1 -: DIN_WIDTH] <= data_in;
                            end else begin
                                data_out[((64 - (r * 8 + c)) * DIN_WIDTH) - 1 -: DIN_WIDTH] <= line_store[r][base_col + c];
                            end
                        end
                    end
                    data_out_valid <= 1;
                end

                if (line_last) begin
                    col_idx <= 0;
                    row_idx <= row_idx + 1;
                end else begin
                    col_idx <= col_idx + 1;
                end
            end
        end
    end

endmodule
