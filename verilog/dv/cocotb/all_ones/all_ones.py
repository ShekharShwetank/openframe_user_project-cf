from caravel_cocotb.caravel_interfaces import test_configure
from caravel_cocotb.caravel_interfaces import report_test
import cocotb
from cocotb.triggers import ClockCycles
from pathlib import Path
from common.common import parse_pcf, bitbang_upload_bitstream, get_signal, select_fabric, get_pcf_path, get_bitstream_path

@cocotb.test()
@report_test
async def all_ones(dut):
    caravelEnv = await test_configure(dut, timeout_cycles=5000000)
    cocotb.log.info("=" * 62)
    cocotb.log.info("OPENFRAME TESTCASE: all_ones (Small Fabric)")
    cocotb.log.info("=" * 62)

    proj_root = Path(__file__).resolve().parent.parent.parent.parent.parent
    fabric_type = "small"
    testname = "all_ones"

    await select_fabric(caravelEnv, fabric_type)

    pcf_path = get_pcf_path(proj_root, fabric_type, testname)
    bitstream_path = get_bitstream_path(proj_root, fabric_type, testname)

    pcf = parse_pcf(pcf_path)
    await bitbang_upload_bitstream(caravelEnv, bitstream_path)
    await ClockCycles(caravelEnv.clk, 100)

    ones_val = get_signal(caravelEnv, "all", pcf, fabric_type)
    expected = (1 << len(pcf["all"])) - 1
    cocotb.log.info(f"  all_ones result = 0x{ones_val:06x} (expected 0x{expected:06x})")
    assert ones_val == expected, f"all_ones FAIL: got 0x{ones_val:06x}"
    cocotb.log.info("TEST PASSED")
