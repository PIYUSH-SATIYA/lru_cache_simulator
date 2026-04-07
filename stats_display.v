module stats_display(
    input  wire       clk,          // 100 MHz Nexys A7 clock
    input  wire       reset,        // active-high reset
    input  wire       cache_hit,    // pulse from cache_controller
    input  wire       cache_miss,   // pulse from cache_controller

    output reg [7:0]  seg,          // {dp,g,f,e,d,c,b,a} active-low
    output reg [7:0]  an,           // active-low digit enable
    output reg [1:0]  led           // led[0]=hit, led[1]=miss
);

    //============================================================
    // Hit and Miss Counters
    //============================================================
    reg [15:0] hit_count;
    reg [15:0] miss_count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            hit_count  <= 16'd0;
            miss_count <= 16'd0;
        end
        else begin
            if (cache_hit)
                hit_count <= hit_count + 1'b1;

            if (cache_miss)
                miss_count <= miss_count + 1'b1;
        end
    end

    //============================================================
    // LED Pulse Logic
    // Keep LED ON for 2 clock cycles
    //============================================================
    reg [1:0] hit_led_timer;
    reg [1:0] miss_led_timer;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            hit_led_timer  <= 2'd0;
            miss_led_timer <= 2'd0;
            led            <= 2'b00;
        end
        else begin
            // Hit LED timer
            if (cache_hit)
                hit_led_timer <= 2'd2;
            else if (hit_led_timer != 0)
                hit_led_timer <= hit_led_timer - 1'b1;

            // Miss LED timer
            if (cache_miss)
                miss_led_timer <= 2'd2;
            else if (miss_led_timer != 0)
                miss_led_timer <= miss_led_timer - 1'b1;

            led[0] <= (hit_led_timer  != 0);
            led[1] <= (miss_led_timer != 0);
        end
    end

    //============================================================
    // Split Counters into Hex Digits
    // Digits 7:4 = hit count
    // Digits 3:0 = miss count
    //============================================================
    wire [3:0] digit [7:0];

    assign digit[0] = miss_count[3:0];
    assign digit[1] = miss_count[7:4];
    assign digit[2] = miss_count[11:8];
    assign digit[3] = miss_count[15:12];

    assign digit[4] = hit_count[3:0];
    assign digit[5] = hit_count[7:4];
    assign digit[6] = hit_count[11:8];
    assign digit[7] = hit_count[15:12];

    //============================================================
    // Display Refresh Counter
    // Uses upper 3 bits for ~763 Hz multiplexing per digit
    //============================================================
    reg [16:0] refresh_counter;

    always @(posedge clk or posedge reset) begin
        if (reset)
            refresh_counter <= 17'd0;
        else
            refresh_counter <= refresh_counter + 1'b1;
    end

    wire [2:0] scan = refresh_counter[16:14];

    reg [3:0] current_digit;

    //============================================================
    // Digit Select Logic
    //============================================================
    always @(*) begin
        an = 8'b11111111;
        current_digit = 4'h0;

        case (scan)
            3'd0: begin
                an = 8'b11111110;   // rightmost digit
                current_digit = digit[0];
            end

            3'd1: begin
                an = 8'b11111101;
                current_digit = digit[1];
            end

            3'd2: begin
                an = 8'b11111011;
                current_digit = digit[2];
            end

            3'd3: begin
                an = 8'b11110111;
                current_digit = digit[3];
            end

            3'd4: begin
                an = 8'b11101111;
                current_digit = digit[4];
            end

            3'd5: begin
                an = 8'b11011111;
                current_digit = digit[5];
            end

            3'd6: begin
                an = 8'b10111111;
                current_digit = digit[6];
            end

            3'd7: begin
                an = 8'b01111111;   // leftmost digit
                current_digit = digit[7];
            end
        endcase
    end

    //============================================================
    // Hex to Seven-Segment Decoder
    // Active-low for Nexys A7
    // seg = {dp,g,f,e,d,c,b,a}
    //============================================================
    always @(*) begin
        case (current_digit)
            4'h0: seg = 8'b11000000;
            4'h1: seg = 8'b11111001;
            4'h2: seg = 8'b10100100;
            4'h3: seg = 8'b10110000;
            4'h4: seg = 8'b10011001;
            4'h5: seg = 8'b10010010;
            4'h6: seg = 8'b10000010;
            4'h7: seg = 8'b11111000;
            4'h8: seg = 8'b10000000;
            4'h9: seg = 8'b10010000;
            4'hA: seg = 8'b10001000;
            4'hB: seg = 8'b10000011;
            4'hC: seg = 8'b11000110;
            4'hD: seg = 8'b10100001;
            4'hE: seg = 8'b10000110;
            4'hF: seg = 8'b10001110;
            default: seg = 8'b11111111;
        endcase
    end

endmodule
