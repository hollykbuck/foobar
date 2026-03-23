module bitstream_packer (
    input clk,
    input rst_n,
    input [15:0] bits_in,   // 待输入的变长比特数据
    input [4:0]  len_in,    // 输入比特的有效长度
    input        valid_in,  // 输入有效信号
    input        flush,     // 刷新信号，用于在图像结束时输出剩余比特

    output reg [7:0] byte_out,   // 输出的一个字节数据
    output reg       byte_valid, // 输出有效信号
    output reg       flush_done  // 刷新完成信号
);

    reg [63:0] buffer;      // 比特缓冲区，用于拼接变长码流
    reg [6:0]  bit_count;   // 缓冲区中当前有效比特的数量
    reg        stuff_zero;  // 字节填充标志 (JPEG 规定 0xFF 后必须跟 0x00，除非是 Marker)

    // 掩码处理，确保输入的比特数据干净
    wire [15:0] bits_masked = bits_in & (16'hFFFF >> (16 - len_in));

    // 过程变量，用于在单个时钟周期内进行多次逻辑判断
    reg [63:0] v_buffer;
    reg [6:0]  v_bit_count;
    reg        v_stuff_zero;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer <= 0;
            bit_count <= 0;
            byte_out <= 0;
            byte_valid <= 0;
            stuff_zero <= 0;
            flush_done <= 0;
        end else begin
            v_buffer = buffer;
            v_bit_count = bit_count;
            v_stuff_zero = stuff_zero;
            
            byte_valid <= 0;
            flush_done <= 0;

            // 1. 输出逻辑
            if (v_stuff_zero) begin
                // 如果上一个输出的字节是 0xFF，则在此周期插入 0x00
                byte_out <= 8'h00;
                byte_valid <= 1;
                v_stuff_zero = 0;
            end else if (v_bit_count >= 8) begin
                // 如果缓冲区中有超过 8 位，则输出最高的一个字节
                byte_out <= v_buffer[63:56];
                byte_valid <= 1;
                // 检查是否需要 Byte Stuffing
                if (v_buffer[63:56] == 8'hFF) begin
                    v_stuff_zero = 1;
                end
                // 移位缓冲区，更新计数
                v_buffer = {v_buffer[55:0], 8'b0};
                v_bit_count = v_bit_count - 8;
            end else if (flush) begin
                // 处理图像末尾的比特对齐
                if (v_bit_count > 0) begin
                    // 按照 JPEG 标准，不足一个字节的部分用 1 填充 (即 0xFF 方向)
                    byte_out <= v_buffer[63:56] | (8'hFF >> v_bit_count);
                    byte_valid <= 1;
                    v_buffer = 0;
                    v_bit_count = 0;
                end else begin
                    flush_done <= 1;
                end
            end

            // 2. 输入逻辑 (并发处理)
            if (valid_in) begin
                // 将新进入的变长比特拼接到缓冲区尾部
                v_buffer = v_buffer | ({48'b0, bits_masked} << (64 - v_bit_count - len_in));
                v_bit_count = v_bit_count + len_in;
            end

            // 3. 将更新后的状态写回寄存器
            buffer <= v_buffer;
            bit_count <= v_bit_count;
            stuff_zero <= v_stuff_zero;
        end
    end

endmodule
