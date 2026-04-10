module cache_memory(
    input clk,
    input [1:0] index,
    input [1:0] way_sel,
    input write_en,
    input [11:0] tag_in,
    input [31:0] data_in,

    output reg [47:0] tag_out,
    output reg [127:0] data_out,
    output reg [3:0] valid_out
);

    reg [11:0] tags  [0:3][0:3];
    reg [31:0] data  [0:3][0:3];
    reg        valid [0:3][0:3];

    integer i, j;

    initial begin
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                tags[i][j]  = 12'b0;
                data[i][j]  = 32'b0;
                valid[i][j] = 1'b0;
            end
        end
    end

    // write path
    always @(posedge clk) begin
        if (write_en) begin
            tags[index][way_sel]  <= tag_in;
            data[index][way_sel]  <= data_in;
            valid[index][way_sel] <= 1'b1;
        end
    end

    // read selected set
    always @(*) begin
        tag_out[11:0]   = tags[index][0];
        tag_out[23:12]  = tags[index][1];
        tag_out[35:24]  = tags[index][2];
        tag_out[47:36]  = tags[index][3];

        data_out[31:0]    = data[index][0];
        data_out[63:32]   = data[index][1];
        data_out[95:64]   = data[index][2];
        data_out[127:96]  = data[index][3];

        valid_out[0] = valid[index][0];
        valid_out[1] = valid[index][1];
        valid_out[2] = valid[index][2];
        valid_out[3] = valid[index][3];
    end

endmodule
