from caravel_cocotb.caravel_interfaces import test_configure
from caravel_cocotb.caravel_interfaces import report_test
import cocotb
from cocotb.triggers import ClockCycles
from pathlib import Path
import random
from common.common import parse_pcf, bitbang_upload_bitstream, set_signal, get_signal, release_signal, select_fabric, get_pcf_path, get_bitstream_path, GPIO_CFG_DONE

@cocotb.test()
@report_test
async def addition(dut):
    caravelEnv = await test_configure(dut, timeout_cycles=5000000)
    cocotb.log.info("=" * 62)
    cocotb.log.info("OPENFRAME TESTCASE: addition (Small Fabric)")
    cocotb.log.info("=" * 62)

    proj_root = Path(__file__).resolve().parent.parent.parent.parent.parent
    fabric_type = "small"
    testname = "addition"

    cocotb.log.info("[STEP 1] Fabric Selection")
    await select_fabric(caravelEnv, fabric_type)
    cocotb.log.info(f"  Selected fabric: {fabric_type}")

    cocotb.log.info("[STEP 2] PCF File Analysis")
    pcf_path = get_pcf_path(proj_root, fabric_type, testname)
    bitstream_path = get_bitstream_path(proj_root, fabric_type, testname)
    pcf = parse_pcf(pcf_path)
    cocotb.log.info(f"  Total PCF signals: {len(pcf)}")

    cocotb.log.info("[STEP 3] Bitstream Upload")
    cocotb.log.info(f"  Bitstream path: {bitstream_path}")
    await bitbang_upload_bitstream(caravelEnv, bitstream_path)
    
    cocotb.log.info("[STEP 4] Wait for Configuration Done")
    cfg_done_val = caravelEnv.monitor_gpio(GPIO_CFG_DONE)
    cocotb.log.info(f"  cfg_done right after upload: {cfg_done_val}")
    
    # Wait some cycles and check again
    await ClockCycles(caravelEnv.clk, 200)
    cfg_done_val = caravelEnv.monitor_gpio(GPIO_CFG_DONE)
    cocotb.log.info(f"  cfg_done after settling: {cfg_done_val}")
    
    if cfg_done_val == 0:
        cocotb.log.error("CONFIGURATION FAILED: cfg_done is still 0!")

    cocotb.log.info("[STEP 5] Drive Test Inputs")
    na = len(pcf["a"])
    nb = len(pcf["b"])
    for i in range(5):
        va = random.randint(0, (1 << na) - 1)
        vb = random.randint(0, (1 << nb) - 1)
        expected = va + vb
        
        cocotb.log.info(f"  Setting a = {va}, b = {vb}")
        set_signal(caravelEnv, "a", va, pcf, fabric_type)
        set_signal(caravelEnv, "b", vb, pcf, fabric_type)
        
        cocotb.log.info("[STEP 6] Wait for Combinatorial Settling")
        await ClockCycles(caravelEnv.clk, 100)
        
        # Deep debug logs
        u_chip = caravelEnv.dut.uut.user_project.u_chip_core
        cocotb.log.info(f"DEBUG: fpga_select_sync = {u_chip.fpga_select_sync.value}")
        cocotb.log.info(f"DEBUG: rst_n_sync = {u_chip.rst_n_sync.value}")
        cocotb.log.info(f"DEBUG: bidir_in = {u_chip.bidir_in.value}")
        cocotb.log.info(f"DEBUG: small_io_west_in_i = {u_chip.small_io_west_in_i.value}")
        cocotb.log.info(f"DEBUG: small_io_east_out_o = {u_chip.small_io_east_out_o.value}")
        cocotb.log.info(f"DEBUG: fpga_out = {u_chip.fpga_out.value}")
        cocotb.log.info(f"DEBUG: bidir_out = {u_chip.bidir_out.value}")
        cocotb.log.info(f"DEBUG: bidir_oe = {u_chip.bidir_oe.value}")
        
        result = get_signal(caravelEnv, "c", pcf, fabric_type)
        cocotb.log.info(f"  addition[{i}]: {va} + {vb} = {result} (expected {expected})")
        assert result == expected, f"addition FAIL at step {i}"
    
    release_signal(caravelEnv, "a", pcf, fabric_type)
    release_signal(caravelEnv, "b", pcf, fabric_type)
    cocotb.log.info("TEST PASSED")
