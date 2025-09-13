module blink (
    input   wire    clk,        // Clock 25 MHz
    input   wire    rst_n,      // Active low reset
    output  reg     led = 0     // LED output
);

    localparam integer MAX_COUNT = 6_250_000 - 1; // 250ms at 25MHz

    reg [24:0] counter = 0; // 25-bit counter

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            led <= 0; // Turn off LED on reset
        end else if (counter == MAX_COUNT) begin
            counter <= 0;
            led <= ~led; // Toggle LED state
        end else begin
            counter <= counter + 1;
        end
    end

endmodule
