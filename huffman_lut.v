module huffman_lut (
    input [3:0] dc_category,
    input [7:0] ac_run_size,
    input       is_chroma,

    output [15:0] dc_code,
    output [4:0]  dc_len,
    output [15:0] ac_code,
    output [4:0]  ac_len
);

    // RAM to store Huffman tables
    // Each entry is 24 bits: [23:8] code, [7:0] length
    reg [23:0] huff_mem [0:1023];

    initial begin
        $readmemh("huffman_tables.hex", huff_mem);
    end

    // Mapping logic
    // Addr: [is_chroma][is_ac][run][size/category]
    // DC address: {is_chroma, 1'b0, 4'b0, dc_category}
    // AC address: {is_chroma, 1'b1, ac_run_size}
    
    wire [9:0] dc_addr = {is_chroma, 1'b0, 4'b0, dc_category};
    wire [9:0] ac_addr = {is_chroma, 1'b1, ac_run_size};

    wire [23:0] dc_entry = huff_mem[dc_addr];
    wire [23:0] ac_entry = huff_mem[ac_addr];

    assign dc_code = dc_entry[23:8];
    assign dc_len  = dc_entry[4:0];
    
    assign ac_code = ac_entry[23:8];
    assign ac_len  = ac_entry[4:0];

endmodule
