module top (
    input  wire osc25m,   // Clock 25 MHz
    input  wire button,   // Botão reset ativo em 0
    output wire led       // LED open-drain ativo em 0
);

    // -------------------------------
    // Instancia o módulo de blink PWM
    // -------------------------------
    blink_pwm u_blink_pwm (
        .clk   (osc25m),
        .rst_n (button),
        .led   (led)
    );

endmodule
