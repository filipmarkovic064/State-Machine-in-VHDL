import cocotb 
from cocotb import start_soon
from cocotb.clock import Clock
from cocotb.triggers import *

async def reset_dut(dut):
    await FallingEdge(dut.mclk)
    dut.reset.value = 1
    await RisingEdge(dut.mclk)
    dut.reset.value = 0

@cocotb.test()
async def test(dut):
    dut._log.info("Hello!")

    start_soon(Clock(dut.mclk, 10, units="ns").start())
    await reset_dut(dut)

    await ClockCycles(dut.mclk, 5)
    for i in range(100): 
        dut.sa.value = 0
        dut.sb.value = 0
        await ClockCycles(dut.mclk, 2)
        dut._log.info("11111111111111")
        dut.sa.value = 0
        dut.sb.value = 1
        await ClockCycles(dut.mclk, 2)
        dut._log.info("222222222222222222222")
        dut.sa.value = 1
        dut.sb.value = 1
        await ClockCycles(dut.mclk, 2)
        dut._log.info("3333333333333333")
        dut.sa.value = 1
        dut.sb.value = 0
        await ClockCycles(dut.mclk, 2)

    dut.sa.value = 0
    dut.sb.value = 1
    await ClockCycles(dut.mclk, 2)

    dut.sa.value = 1
    dut.sb.value = 1
    await ClockCycles(dut.mclk, 2)

    dut.sa.value = 1
    dut.sb.value = 0
    await ClockCycles(dut.mclk, 2)

    dut.sa.value = 0
    dut.sb.value = 1
    await ClockCycles(dut.mclk, 20000)

    dut._log.info("End")

