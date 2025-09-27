// EXAMPLE ICMP ECHO SERVER TOP MODULE

module top (
    // RGMII PHY interface (RTL8211FD)
    input  wire          rgmii_rx_clk,
    output wire          rgmii_tx_clk,
    output wire          rgmii_mdc,
    output wire          rgmii_mdio,
    output wire          rgmii_rst_n,
    input  wire          rgmii_rx_ctl,
    input  wire    [3:0] rgmii_rxd,
    output wire          rgmii_tx_ctl,
    output wire    [3:0] rgmii_txd,

    // System interface
    input  wire          osc25m,
    input  wire          button,
    output wire          led
);



    //------------------------------------------------------------------
    // PLL instantiation: 25 MHz -> 125 MHz
    //------------------------------------------------------------------
    wire clk_125mhz;
    wire pll_locked;

    pll u_pll (
        .clkin  (osc25m),
        .clock  (clk_125mhz),
        .locked (pll_locked)
    );



    //------------------------------------------------------------------
    // Reset logic
    //------------------------------------------------------------------
    reg [3:0] locked_reset = 4'b1111;
    wire sys_reset = ~pll_locked | locked_reset[3] | ~button;

    always @(posedge clk_125mhz or negedge pll_locked) begin
        if (!pll_locked)
            locked_reset <= 4'b1111;
        else
            locked_reset <= {locked_reset[2:0], 1'b0};
    end



    //------------------------------------------------------------------
    // LiteEth core instantiation - With LED blink on traffic
    //------------------------------------------------------------------
    wire ethphy_sink_valid; // NEW: traffic indicator (led Sink)

    liteeth_core u_liteeth_core (
        // RGMII clocks
        .rgmii_clocks_rx    (rgmii_rx_clk),   // RX clock from PHY
        .rgmii_clocks_tx    (rgmii_tx_clk),   // TX clock to PHY

        // RGMII management interface
        .rgmii_mdc          (),             // Management data clock
        .rgmii_mdio         (),             // Management data I/O
        .rgmii_rst_n        (rgmii_rst_n),  // Active-low reset to PHY

        // RGMII data interface
        .rgmii_rx_ctl       (rgmii_rx_ctl),   // RX control
        .rgmii_rx_data      (rgmii_rxd),      // RX data bus
        .rgmii_tx_ctl       (rgmii_tx_ctl),   // TX control
        .rgmii_tx_data      (rgmii_txd),      // TX data bus

        // System interface
        .sys_clock          (clk_125mhz),     // System clock (from PLL)
        .sys_reset          (sys_reset),      // System reset

        // Optional / unused signals
        .rgmii_int_n        (1'b1),           // No interrupt (active-low input tied high)

        // Exported signals (custom)
        .ethphy_sink_valid  (ethphy_sink_valid) // Exported traffic valid signal
    );



    //------------------------------------------------------------------
    // LED blink on traffic
    //------------------------------------------------------------------
    parameter LED_BLINK_TIME = 24'd6_250_000; // ~50ms at 125MHz

    reg [23:0] led_counter = 24'd0;
    reg        led_reg     = 1'b1; // led off (active low open-drain)

    always @(posedge clk_125mhz or posedge sys_reset) begin
        if (sys_reset) begin
            led_counter <= 0;
            led_reg     <= 1'b1;
        end

        else if (ethphy_sink_valid) begin
            led_counter <= LED_BLINK_TIME; // restart counter
            led_reg     <= 1'b0;           // led on
        end

        else if (led_counter != 0) begin
            led_counter <= led_counter - 1;
            if (led_counter == 1)
                led_reg <= 1'b1;           // led off
        end
    end

    assign led = led_reg;
    
endmodule
