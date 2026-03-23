module jpeg_header (
    input clk,
    input rst_n,
    input start,
    output reg [7:0] header_data,
    output reg       header_valid,
    output reg       header_done
);

    localparam HEADER_LAST_ADDR = 10'd622;

    reg [9:0] rom_addr;
    reg [7:0] header_rom [0:HEADER_LAST_ADDR];

    initial begin
        $readmemh("jpeg_header.hex", header_rom);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rom_addr <= 0;
            header_valid <= 0;
            header_done <= 0;
            header_data <= 0;
        end else if (start && !header_done) begin
            header_data <= header_rom[rom_addr];
            header_valid <= 1;
            if (rom_addr == HEADER_LAST_ADDR) begin
                header_done <= 1;
            end else begin
                rom_addr <= rom_addr + 1;
            end
        end else begin
            header_valid <= 0;
        end
    end

endmodule
