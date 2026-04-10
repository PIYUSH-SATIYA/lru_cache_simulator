`timescale 1ns / 1ps

module tb_top_module;

    // board-like inputs
    reg CLK100MHZ;
    reg BTNC;
    reg BTNL;
    reg [15:0] SW;

    // outputs
    wire [1:0] LED;
    wire [6:0] SEG;
    wire [7:0] AN;
    wire DP;

    // DUT
    top_module #(
        .DEBOUNCE_COUNT(2)
    ) uut (
        .CLK100MHZ(CLK100MHZ),
        .BTNC(BTNC),
        .BTNL(BTNL),
        .SW(SW),
        .LED(LED),
        .SEG(SEG),
        .AN(AN),
        .DP(DP)
    );

    // 100 MHz clock => 10 ns period
    initial begin
        CLK100MHZ = 0;
        forever #5 CLK100MHZ = ~CLK100MHZ;
    end

    // button press helper
    task press_center(input [15:0] addr);
    begin
        SW = addr;
        #40;
        BTNC = 1;
        #40;
        BTNC = 0;
        #80;
    end
    endtask

    initial begin
        // initial state
        BTNC = 0;
        BTNL = 1;   // reset active
        SW   = 16'h0000;

        // release reset
        #60;
        BTNL = 0;

        // fill same set
        press_center(16'h0000); // miss
        press_center(16'h0010); // miss
        press_center(16'h0020); // miss
        press_center(16'h0030); // miss

        // should hit
        press_center(16'h0010);

        // force eviction
        press_center(16'h0040);

        // verify eviction victim
        press_center(16'h0000);

        #200;
        $finish;
    end

endmodule
