module fifo #(
    parameter                       DATA_WIDTH  = 8     ,
    parameter                       DEPTH       = 16    
)(
    input wire                      clk                 ,
    input wire                      rst                 , // Note: This is active-high or active-low? 
                                                      // Looking at line_buffer, it's rst_n (active low)
    input wire                      wr_en               ,
    input wire                      rd_en               ,
    input wire [DATA_WIDTH-1:0]     din                 ,
    output reg  [DATA_WIDTH-1:0]    dout                
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [7:0] wr_ptr, rd_ptr; // Simplified ptrs

    integer i;
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            dout <= 0;
            for (i = 0; i < DEPTH; i = i + 1) mem[i] <= 0;
        end else begin
            if (wr_en) begin
                mem[wr_ptr % DEPTH] <= din;
                wr_ptr <= wr_ptr + 1;
            end
            if (rd_en) begin
                dout <= mem[rd_ptr % DEPTH];
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

endmodule
