module top (
    input   wire    osc25m,  // 25MHz oscillator input
    input   wire    button,  // Button reset input (active low)
    output  wire    led      // LED output open-drain (active low)
);

    wire led_w;

    // Instantiate the led_blink module
    blink u_blink (
        .clk    (osc25m),
        .rst_n  (button),
        .led    (led_w)
    );

    // Led open-drain output
    assign led = (led_w) ? 1'bz : 1'b0; // High-Z when led_w is high, else drive low

endmodule
