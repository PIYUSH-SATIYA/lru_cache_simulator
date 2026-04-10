module top_module #(
    parameter integer DEBOUNCE_COUNT = 500_000
)(
    input        CLK100MHZ,
    input  [15:0] SW,
    input        BTNC,
    input        BTNL,
    output [1:0] LED,
    output [6:0] SEG,
    output [7:0] AN,
    output       DP
);

    wire clk;
    assign clk = CLK100MHZ;

    wire [11:0] tag_decoded;
    wire [1:0] index_decoded;
    wire [1:0] offset_decoded;

    wire [47:0] tag_bus;
    wire [127:0] data_bus;
    wire [3:0] valid_bus;

    wire hit;
    wire [1:0] hit_way;
    wire [1:0] lru_way;

    wire write_en;
    wire [1:0] way_sel;
    wire [11:0] tag_to_write;
    wire [31:0] data_to_write;
    wire lru_update_en;
    wire [1:0] lru_used_way;
    wire cache_hit_out;
    wire cache_miss_out;

    wire access_req_db;
    wire reset_db;

    wire [7:0] seg_raw;
    wire [1:0] stats_led_unused;

    debouncer #(.STABLE_COUNT(DEBOUNCE_COUNT)) u_dbnc_access (
        .clk(clk),
        .btn_in(BTNC),
        .btn_out(access_req_db)
    );

    debouncer #(.STABLE_COUNT(DEBOUNCE_COUNT)) u_dbnc_reset (
        .clk(clk),
        .btn_in(BTNL),
        .btn_out(reset_db)
    );

    addr_decoder u_addr_dec (
        .addr(SW),
        .tag(tag_decoded),
        .index(index_decoded),
        .offset(offset_decoded)
    );

    cache_memory u_cache_mem (
        .clk(clk),
        .index(index_decoded),
        .way_sel(way_sel),
        .write_en(write_en),
        .tag_in(tag_to_write),
        .data_in(data_to_write),
        .tag_out(tag_bus),
        .data_out(data_bus),
        .valid_out(valid_bus)
    );

    tag_comparator u_tag_cmp (
        .tag_in(tag_decoded),
        .tag_stored(tag_bus),
        .valid_bits(valid_bus),
        .hit(hit),
        .hit_way(hit_way)
    );

    lru_controller u_lru (
        .clk(clk),
        .reset(reset_db),
        .update_en(lru_update_en),
        .index(index_decoded),
        .used_way(lru_used_way),
        .lru_way(lru_way)
    );

    cache_controller u_ctrl (
        .clk(clk),
        .reset(reset_db),
        .access_req(access_req_db),
        .addr_in(SW),
        .hit(hit),
        .hit_way(hit_way),
        .lru_way(lru_way),
        .tag_decoded(tag_decoded),
        .index_decoded(index_decoded),
        .write_en(write_en),
        .way_sel(way_sel),
        .tag_to_write(tag_to_write),
        .data_to_write(data_to_write),
        .lru_update_en(lru_update_en),
        .lru_used_way(lru_used_way),
        .cache_hit_out(cache_hit_out),
        .cache_miss_out(cache_miss_out)
    );

    stats_display u_stats (
        .clk(clk),
        .reset(reset_db),
        .cache_hit(cache_hit_out),
        .cache_miss(cache_miss_out),
        .seg(seg_raw),
        .an(AN),
        .led(stats_led_unused)
    );

    assign {DP, SEG} = seg_raw;

    led_blink u_led_hit (
        .clk(clk),
        .pulse(cache_hit_out),
        .led_out(LED[0])
    );

    led_blink u_led_miss (
        .clk(clk),
        .pulse(cache_miss_out),
        .led_out(LED[1])
    );

endmodule


// =============================================================================
// Helper module: debouncer
// Simple counter-based button debouncer.
// Output only changes when input has been stable for STABLE_COUNT cycles.
// =============================================================================
module debouncer #(
    parameter STABLE_COUNT = 500_000  // 5ms at 100MHz
)(
    input  clk,
    input  btn_in,
    output reg btn_out
);
    localparam integer COUNT_W = (STABLE_COUNT <= 1) ? 1 : $clog2(STABLE_COUNT);

    reg [COUNT_W-1:0] count = {COUNT_W{1'b0}};
    reg btn_prev = 1'b0;

    initial begin
        btn_out = 1'b0;
    end

    always @(posedge clk) begin
        if (btn_in !== btn_prev) begin
            // Input changed — restart stability counter
            count    <= 0;
            btn_prev <= btn_in;
        end
        else if (count < STABLE_COUNT - 1) begin
            count <= count + 1;
        end
        else begin
            // Input stable for STABLE_COUNT cycles — commit to output
            btn_out <= btn_in;
        end
    end
endmodule


// =============================================================================
// Helper module: led_blink
// Stretches a 1-cycle pulse to ~0.25 seconds so it's human-visible.
// =============================================================================
module led_blink #(
    parameter HOLD_CYCLES = 25_000_000  // 0.25s at 100MHz
)(
    input  clk,
    input  pulse,
    output reg led_out
);
    localparam integer COUNT_W = (HOLD_CYCLES <= 1) ? 1 : $clog2(HOLD_CYCLES);

    reg [COUNT_W-1:0] count = {COUNT_W{1'b0}};

    initial begin
        led_out = 1'b0;
    end

    always @(posedge clk) begin
        if (pulse) begin
            led_out <= 1'b1;
            count   <= 0;
        end
        else if (led_out) begin
            if (count < HOLD_CYCLES - 1)
                count <= count + 1'b1;
            else begin
                led_out <= 1'b0;
                count   <= {COUNT_W{1'b0}};
            end
        end
    end
endmodule
