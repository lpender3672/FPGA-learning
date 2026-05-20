"""cocotb testbench for example_counter. Replace with tests for your DUT."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, Timer


async def reset_and_release(dut, cycles: int = 2):
    dut.rstn.value = 0
    dut.en.value   = 0
    # Let the initial signal writes propagate before the first clock edge.
    await Timer(1, unit="ns")
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)


@cocotb.test()
async def increments_when_enabled(dut):
    """q advances by one each cycle while en=1."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_and_release(dut)

    dut.en.value = 1
    for expected in range(1, 6):
        await RisingEdge(dut.clk)
        # Yield to ReadOnly so the NBA from this posedge has committed.
        await ReadOnly()
        got = int(dut.q.value)
        assert got == expected, f"expected {expected}, got {got}"


@cocotb.test()
async def holds_zero_under_reset(dut):
    """q stays at 0 while rstn=0 regardless of en."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rstn.value = 0
    dut.en.value   = 1
    await Timer(1, unit="ns")
    for _ in range(8):
        await RisingEdge(dut.clk)
        await ReadOnly()
        assert int(dut.q.value) == 0, f"q={int(dut.q.value)}"
