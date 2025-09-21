// Module: pll
// Description: Simple PLL module to generate a 10 MHz clock from a 25 MHz input
// Usage: generate pll.v file with: make pll PLL_CLOCK_IN=25 PLL_CLOCK_OUT=10
// NOTE: Make sure the pll.v file is in the same directory as this top.v file

module top (
    // Parameters for testing PLL
    input   wire    osc25m,     // Input clock
    input   wire    button,     // Active low reset
    output  wire    led         // LED output to test the clock generated with PLL   
);

    wire pll_clock;     // Output clock from PLL
    wire pll_locked;    // PLL lock status

    // PLL instance
    pll pll_inst (
        .clkin  (osc25m),
        .clock  (pll_clock),
        .locked (pll_locked)
    );

    reg [3:0] locked_reset = 4'b1111;
    wire reset = locked_reset[3] | ~button;

    always @(posedge pll_clock or negedge pll_locked) begin
        if (!pll_locked)
            locked_reset <= 4'b1111;
        else
            locked_reset <= {locked_reset[2:0], 1'b0}; 
    end

    // Simple LED toggle to visualize the PLL clock output
    reg [23:0] counter = 24'd0; // 24-bit counter
    always @(posedge pll_clock or posedge reset) begin
        if (reset) begin
            counter <= 24'd0;
            led <= 1'b0;
        end else if (counter == 24'd10_000_000) begin
            counter <= 24'd0;
            led <= ~led; // Toggle LED state
        end else begin
            counter <= counter + 1;
        end
    end

endmodule
