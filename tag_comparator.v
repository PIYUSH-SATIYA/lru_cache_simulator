module tag_comparator(
    input [11:0] tag_in,
    input [47:0] tag_stored,
    input [3:0] valid_bits,

    output reg hit,
    output reg [1:0] hit_way
);

    wire [11:0] tag0 = tag_stored[11:0];
    wire [11:0] tag1 = tag_stored[23:12];
    wire [11:0] tag2 = tag_stored[35:24];
    wire [11:0] tag3 = tag_stored[47:36];

    always @(*) begin
        hit = 0;
        hit_way = 2'b00;

        if (valid_bits[0] && (tag_in == tag0)) begin
            hit = 1;
            hit_way = 2'b00;
        end
        else if (valid_bits[1] && (tag_in == tag1)) begin
            hit = 1;
            hit_way = 2'b01;
        end
        else if (valid_bits[2] && (tag_in == tag2)) begin
            hit = 1;
            hit_way = 2'b10;
        end
        else if (valid_bits[3] && (tag_in == tag3)) begin
            hit = 1;
            hit_way = 2'b11;
        end
    end

endmodule
