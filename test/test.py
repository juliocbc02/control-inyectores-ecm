
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer


@cocotb.test()
async def test_project(dut):

    # Reloj de 50 MHz (periodo de 20 ns)
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    # Inicializar entradas
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)

    # Liberar reset
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # Activar Star (ui_in[1])
    dut.ui_in.value = 0b00000010
    await ClockCycles(dut.clk, 10)

    # Verificar cebado de bomba
    assert (int(dut.uo_out.value) & 0x10) != 0, \
        "ERROR: La bomba no se activo"

    dut._log.info("Bomba activada correctamente")

    # Generar 30 pulsos CKP
    for i in range(30):
        dut.ui_in.value = 0b00000011
        await ClockCycles(dut.clk, 5)

        dut.ui_in.value = 0b00000010
        await ClockCycles(dut.clk, 5)

    # Esperar sincronizacion
    await ClockCycles(dut.clk, 10)

    # Verificar inyector 1
    assert (int(dut.uo_out.value) & 0x01) != 0, \
        "ERROR: Inyector 1 no se activo"

    dut._log.info("Inyector 1 activado correctamente")

    # Deshabilitar Star
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 10)

    # Verificar apagado de todas las salidas
    assert int(dut.uo_out.value) == 0, \
        "ERROR: Las salidas no se apagaron"

    dut._log.info("Reset y apagado correctos")
