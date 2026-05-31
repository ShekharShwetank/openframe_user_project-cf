from caravel_cocotb.caravel_interfaces import test_configure
from caravel_cocotb.caravel_interfaces import report_test
import cocotb
from cocotb.triggers import ClockCycles
from pathlib import Path
from common.common import parse_pcf, bitbang_upload_bitstream, get_signal, select_fabric, get_pcf_path, get_bitstream_path, get_gpio

@cocotb.test()
@report_test
async def counter(dut):
    caravelEnv = await test_configure(dut, timeout_cycles=5000000)
    cocotb.log.info("=" * 62)
    cocotb.log.info("OPENFRAME TESTCASE: counter (Small Fabric)")
    cocotb.log.info("=" * 62)

    proj_root = Path(__file__).resolve().parent.parent.parent.parent.parent
    fabric_type = "small"
    testname = "counter"

    await select_fabric(caravelEnv, fabric_type)

    pcf_path = get_pcf_path(proj_root, fabric_type, testname)
    bitstream_path = get_bitstream_path(proj_root, fabric_type, testname)

    pcf = parse_pcf(pcf_path)
    await bitbang_upload_bitstream(caravelEnv, bitstream_path)
    await ClockCycles(caravelEnv.clk, 100)

    # Note: These tiles match the generated constraints for small fabric counter.
    clk_gpio = get_gpio("X5Y6/A", fabric_type)  # clk1
    ena_gpio = get_gpio("X0Y5/A", fabric_type)  # ena
    rst_gpio = get_gpio("X0Y5/B", fabric_type)  # rst

    # Assert reset, deassert enable
    caravelEnv.drive_gpio(rst_gpio, 1)
    caravelEnv.drive_gpio(ena_gpio, 0)
    caravelEnv.drive_gpio(clk_gpio, 0)
    for _ in range(5):
        caravelEnv.drive_gpio(clk_gpio, 1)
        await ClockCycles(caravelEnv.clk, 5)
        caravelEnv.drive_gpio(clk_gpio, 0)
        await ClockCycles(caravelEnv.clk, 5)

    ctr = get_signal(caravelEnv, "c", pcf, fabric_type)
    cocotb.log.info(f"  counter after reset: {ctr} (expected 0)")
    assert ctr == 0, "counter reset FAIL"

    # Release reset, enable counting
    caravelEnv.drive_gpio(rst_gpio, 0)
    caravelEnv.drive_gpio(ena_gpio, 1)
    await ClockCycles(caravelEnv.clk, 10)

    for expected_val in range(1, 6):
        caravelEnv.drive_gpio(clk_gpio, 1)
        await ClockCycles(caravelEnv.clk, 5)
        caravelEnv.drive_gpio(clk_gpio, 0)
        await ClockCycles(caravelEnv.clk, 5)
        ctr = get_signal(caravelEnv, "c", pcf, fabric_type)
        cocotb.log.info(f"  counter step {expected_val}: {ctr}")
        assert ctr == expected_val, f"counter FAIL at step {expected_val}"

    caravelEnv.release_gpio(clk_gpio)
    caravelEnv.release_gpio(ena_gpio)
    caravelEnv.release_gpio(rst_gpio)
    cocotb.log.info("TEST PASSED")
