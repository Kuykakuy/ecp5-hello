module blink_pwm (
    input  wire clk,       // Clock 25 MHz
    input  wire rst_n,     // Active low reset
    output wire led        // LED open-drain ativo em 0
);

    // -------------------------------
    // Parâmetros
    // -------------------------------
    localparam integer FADE_STEPS = 100;        // Número de passos do fade
    localparam integer FADE_DELAY = 250_000;    // Ciclos de 25MHz entre passos (~10ms)
    localparam integer PWM_MAX = 255;           // Contador PWM lento

    // -------------------------------
    // Registros
    // -------------------------------
    reg [31:0] fade_counter;    // Contador para cada passo do fade
    reg [6:0]  brightness;      // Brilho atual (1 a FADE_STEPS)
    reg        fade_up;         // Direção do fade
    reg [7:0]  pwm_counter;     // Contador PWM lento

    // -------------------------------
    // Atualiza o brilho lentamente
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fade_counter <= 0;
            brightness   <= 1;  // começa mínimo 1
            fade_up      <= 1;
        end else begin
            if (fade_counter < FADE_DELAY - 1) begin
                fade_counter <= fade_counter + 1;
            end else begin
                fade_counter <= 0;
                if (fade_up)
                    brightness <= brightness + 1;
                else if (brightness > 1)
                    brightness <= brightness - 1;

                if (brightness == FADE_STEPS)
                    fade_up <= 0;
                else if (brightness == 1)
                    fade_up <= 1;
            end
        end
    end

    // -------------------------------
    // Contador PWM lento (~1kHz)
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_counter <= 0;
        else
            pwm_counter <= pwm_counter + 1;
    end

    // -------------------------------
    // Saída LED open-drain sem blink
    // -------------------------------
    assign led = (brightness > 1 && pwm_counter < (brightness * (PWM_MAX / FADE_STEPS))) ? 1'b0 : 1'bz;

endmodule
