`timescale 1ns / 1ps

module tb_top_module;

    reg clk;
    reg reset;
    reg BTNC;
    reg BTNL;
    reg [15:0] SW;

    wire [1:0] LED;
    wire [6:0] SEG;
    wire [7:0] AN;
    wire DP;

    // Instantiate top module
    top_module uut (
        .clk(clk),
        .reset(reset),     // change if your top uses BTNL directly
        .BTNC(BTNC),
        .BTNL(BTNL),
        .SW(SW),
        .LED(LED),
        .SEG(SEG),
        .AN(AN),
        .DP(DP)
    );

    // Clock generation (100 MHz -> 10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // task for button press pulse
    task access_addr(input [15:0] addr);
    begin
        SW = addr;
        #10;
        BTNC = 1;
        #10;
        BTNC = 0;
        #40;
    end
    endtask

    initial begin
        $display("Starting top module simulation");

        reset = 1;
        BTNC = 0;
        BTNL = 0;
        SW = 16'h0000;

        #20;
        reset = 0;

        // -------- fill same set --------
        access_addr(16'h0000); // miss
        access_addr(16'h0010); // miss
        access_addr(16'h0020); // miss
        access_addr(16'h0030); // miss

        // -------- should hit --------
        access_addr(16'h0010); // hit

        // -------- force eviction --------
        access_addr(16'h0040); // miss + evict LRU

        // -------- verify old evicted address --------
        access_addr(16'h0000); // should miss if evicted

        #100;
        $display("Done");
        $finish;
    end

endmodule
