
`default_nettype none

//======================================================
// ECM - CONTROL SECUENCIAL DE INYECTORES
// Autor: Julio Cesar Barajas Cortes
// Institucion: ITCG
// Tiny Tapeout GF - Reloj de 50 MHz
//======================================================

module tt_um_control_inyectores (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire iny1;
    wire iny2;
    wire iny3;
    wire iny4;
    wire bomba;

    wire star_habilitado;

    // Habilitacion general y reset
    assign star_habilitado = ui_in[1] & rst_n;

    // Modulo principal ECM
    control_inyectores #(
        .CLK_HZ(50000000)
    ) controlador (
        .clk(clk),
        .ckp(ui_in[0]),
        .Star(star_habilitado),
        .inyector1(iny1),
        .inyector2(iny2),
        .inyector3(iny3),
        .inyector4(iny4),
        .bomba(bomba)
    );

    // Salidas del ECM
    assign uo_out[0] = iny1;
    assign uo_out[1] = iny2;
    assign uo_out[2] = iny3;
    assign uo_out[3] = iny4;
    assign uo_out[4] = bomba;
    assign uo_out[7:5] = 3'b000;

    // Pines bidireccionales no utilizados
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    // Entradas no utilizadas
    wire _unused = &{
        ena,
        ui_in[7:2],
        uio_in,
        1'b0
    };

endmodule


//======================================================
// MODULO DE CONTROL DE INYECTORES
//======================================================

module control_inyectores #(
    parameter integer CLK_HZ = 50000000
)(
    input  wire clk,
    input  wire ckp,
    input  wire Star,

    output wire inyector1,
    output wire inyector2,
    output wire inyector3,
    output wire inyector4,
    output wire bomba
);

    //==================================================
    // TEMPORIZADORES
    //==================================================

    // Inyeccion de 3 ms
    localparam integer T_INYECCION =
        (CLK_HZ / 1000) * 3;

    // Cebado de bomba durante 2 segundos
    localparam integer T_CEBADO =
        2 * CLK_HZ;

    // Ausencia de CKP durante 3 segundos
    localparam integer T_SIN_CKP =
        3 * CLK_HZ;

    //==================================================
    // ANCHOS DE CONTADORES
    //==================================================

    localparam integer W_INY =
        (T_INYECCION > 1) ?
        $clog2(T_INYECCION + 1) : 1;

    localparam integer W_CEBADO =
        (T_CEBADO > 1) ?
        $clog2(T_CEBADO + 1) : 1;

    localparam integer W_SINCKP =
        (T_SIN_CKP > 1) ?
        $clog2(T_SIN_CKP + 1) : 1;

    //==================================================
    // CONSTANTES AJUSTADAS AL ANCHO DE LOS CONTADORES
    //==================================================

    // 150000 ciclos a 50 MHz = 3 ms
    localparam [W_INY-1:0] T_INY_AJUSTADO =
        W_INY'(T_INYECCION);

    // 100000000 ciclos a 50 MHz = 2 s
    localparam [W_CEBADO-1:0] LIM_CEBADO =
        W_CEBADO'(T_CEBADO - 1);

    // 150000000 ciclos a 50 MHz = 3 s
    localparam [W_SINCKP-1:0] LIM_SINCKP =
        W_SINCKP'(T_SIN_CKP - 1);

    //==================================================
    // SINCRONIZACION DE CKP
    //==================================================

    reg ckp_meta;
    reg ckp_sync;
    reg ckp_anterior;

    wire pulso_ckp;

    assign pulso_ckp =
        ckp_sync && !ckp_anterior;

    //==================================================
    // SECUENCIA DE INYECTORES
    //==================================================

    reg [4:0] contador_ckp;
    reg [1:0] turno;

    reg [W_INY-1:0] tiempo_iny1;
    reg [W_INY-1:0] tiempo_iny2;
    reg [W_INY-1:0] tiempo_iny3;
    reg [W_INY-1:0] tiempo_iny4;

    //==================================================
    // CONTROL DE BOMBA
    //==================================================

    reg [W_SINCKP-1:0] contador_sin_ckp;
    reg ckp_vigente;

    reg [W_CEBADO-1:0] contador_cebado;

    reg iniciado;
    reg cebado;

    //==================================================
    // SALIDAS
    //==================================================

    assign inyector1 =
        Star && (tiempo_iny1 != 0);

    assign inyector2 =
        Star && (tiempo_iny2 != 0);

    assign inyector3 =
        Star && (tiempo_iny3 != 0);

    assign inyector4 =
        Star && (tiempo_iny4 != 0);

    assign bomba =
        Star && (!iniciado || cebado || ckp_vigente);

    //==================================================
    // LOGICA SECUENCIAL
    //==================================================

    always @(posedge clk or negedge Star) begin

        if (!Star) begin

            // Reinicio del sincronizador CKP
            ckp_meta         <= 1'b0;
            ckp_sync         <= 1'b0;
            ckp_anterior     <= 1'b0;

            // Reinicio de secuencia
            contador_ckp     <= 5'd0;
            turno            <= 2'd0;

            // Reinicio de temporizadores
            tiempo_iny1      <= 0;
            tiempo_iny2      <= 0;
            tiempo_iny3      <= 0;
            tiempo_iny4      <= 0;

            // Reinicio de bomba
            contador_sin_ckp <= 0;
            ckp_vigente      <= 1'b0;

            contador_cebado  <= 0;
            iniciado         <= 1'b0;
            cebado           <= 1'b0;

        end else begin

            //==========================================
            // SINCRONIZACION CKP
            //==========================================

            ckp_meta     <= ckp;
            ckp_sync     <= ckp_meta;
            ckp_anterior <= ckp_sync;

            //==========================================
            // TEMPORIZADORES DE INYECCION
            //==========================================

            if (tiempo_iny1 != 0)
                tiempo_iny1 <= tiempo_iny1 - 1'b1;

            if (tiempo_iny2 != 0)
                tiempo_iny2 <= tiempo_iny2 - 1'b1;

            if (tiempo_iny3 != 0)
                tiempo_iny3 <= tiempo_iny3 - 1'b1;

            if (tiempo_iny4 != 0)
                tiempo_iny4 <= tiempo_iny4 - 1'b1;

            //==========================================
            // SECUENCIA CADA 30 PULSOS CKP
            //==========================================

            if (pulso_ckp) begin

                if (contador_ckp == 5'd29) begin

                    contador_ckp <= 5'd0;

                    case (turno)

                        2'd0:
                            tiempo_iny1 <= T_INY_AJUSTADO;

                        2'd1:
                            tiempo_iny2 <= T_INY_AJUSTADO;

                        2'd2:
                            tiempo_iny3 <= T_INY_AJUSTADO;

                        2'd3:
                            tiempo_iny4 <= T_INY_AJUSTADO;

                    endcase

                    turno <= turno + 1'b1;

                end else begin

                    contador_ckp <= contador_ckp + 1'b1;

                end
            end

            //==========================================
            // CONTROL DE ACTIVIDAD CKP
            //==========================================

            if (pulso_ckp) begin

                contador_sin_ckp <= 0;
                ckp_vigente      <= 1'b1;

            end else if (ckp_vigente) begin

                if (contador_sin_ckp >= LIM_SINCKP) begin

                    contador_sin_ckp <= 0;
                    ckp_vigente      <= 1'b0;

                end else begin

                    contador_sin_ckp <=
                        contador_sin_ckp + 1'b1;

                end
            end

            //==========================================
            // CEBADO DE BOMBA
            //==========================================

            if (!iniciado) begin

                iniciado        <= 1'b1;
                cebado          <= 1'b1;
                contador_cebado <= 0;

            end else if (cebado) begin

                if (contador_cebado >= LIM_CEBADO) begin

                    cebado <= 1'b0;

                end else begin

                    contador_cebado <=
                        contador_cebado + 1'b1;

                end
            end

        end
    end

endmodule

`default_nettype wire
