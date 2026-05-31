import cocotb
from cocotb.triggers import ClockCycles, Timer
import re
from pathlib import Path

# ===========================================================================
# GPIO PIN MAP
# ===========================================================================
BIDIR_TO_GPIO = {
    0:  0,   1:  1,   2:  2,   3:  3,   4:  4,   5:  5,
    6:  6,   7:  7,   8:  8,   9:  9,  10: 10,
   11: 11,  12: 12,  13: 13,
   14: 15,  15: 16,  16: 17,  17: 18,  18: 19,
   19: 20,  20: 21,  21: 22,  22: 23,  23: 24,
   24: 27,  25: 28,
   26: 33,  27: 34,  28: 35,  29: 36,  30: 37,
   31: 39,  32: 40,  33: 41,  34: 42,  35: 43,
}

GPIO_SPI_CSN  = 31
GPIO_SPI_SCLK = 32
GPIO_SPI_MOSI = 30
GPIO_CFG_DONE = 14
GPIO_FPGA_SEL0 = 25
GPIO_FPGA_SEL1 = 26

SPI_HALF_PERIOD = 3

LOOKUP_SMALL = {
    "X0Y1/A" : 0, "X0Y1/B" : 1, "X0Y2/A" : 2, "X0Y2/B" : 3,
    "X0Y3/A" : 4, "X0Y3/B" : 5, "X0Y4/A" : 6, "X0Y4/B" : 7,
    "X0Y5/A" : 8, "X0Y5/B" : 9, "X0Y6/A" : 10, "X0Y6/B" : 11,
    "X5Y1/A" : 12, "X5Y1/B" : 13, "X5Y2/A" : 14, "X5Y2/B" : 15,
    "X5Y3/A" : 16, "X5Y3/B" : 17, "X5Y4/A" : 18, "X5Y4/B" : 19,
    "X5Y5/A" : 20, "X5Y5/B" : 21, "X5Y6/A" : 22, "X5Y6/B" : 23,
}

LOOKUP_LARGE = {
    "X0Y1/A" : 0, "X0Y1/B" : 1, "X0Y2/A" : 2, "X0Y2/B" : 3,
    "X0Y3/A" : 4, "X0Y3/B" : 5, "X0Y4/A" : 6, "X0Y4/B" : 7,
    "X0Y5/A" : 8, "X0Y5/B" : 9, "X0Y6/A" : 10, "X0Y6/B" : 11,
    "X0Y7/A" : 12, "X0Y7/B" : 13, "X0Y8/A" : 14, "X0Y8/B" : 15,
    "X0Y9/A" : 16, "X0Y9/B" : 17, "X0Y10/A" : 18, "X0Y10/B" : 19,
    "X0Y11/A" : 20, "X0Y11/B" : 21, "X0Y12/A" : 22, "X0Y12/B" : 23,
    "X14Y1/A" : 24, "X14Y2/A" : 25, "X14Y3/A" : 26, "X14Y4/A" : 27,
    "X14Y5/A" : 28, "X14Y6/A" : 29, "X14Y7/A" : 30, "X14Y8/A" : 31,
    "X14Y9/A" : 32, "X14Y10/A" : 33, "X14Y11/A" : 34, "X14Y12/A" : 35,
}

def get_pcf_path(proj_root, fabric_type, testname):
    return proj_root / f"ip/{fabric_type}_fabric/examples/{testname}/generated_constraints.pcf"

def get_bitstream_path(proj_root, fabric_type, testname):
    return proj_root / f"ip/{fabric_type}_fabric/examples/{testname}/{testname}.bit"

def get_gpio(tile, fabric_type):
    lookup = LOOKUP_SMALL if fabric_type == "small" else LOOKUP_LARGE
    bidir_idx = lookup[tile]
    return BIDIR_TO_GPIO[bidir_idx]

def parse_pcf(pcf_path):
    signals = {}
    with open(pcf_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            match = re.match(r"set_io\s+(\w+)(?:\[(\d+)\])?\s+(X\d+Y\d+\/\w+)", line)
            if match:
                sig_name = match.group(1)
                idx = int(match.group(2)) if match.group(2) is not None else 0
                tile = match.group(3)
                if sig_name == "io":
                    continue
                if sig_name not in signals:
                    signals[sig_name] = {}
                signals[sig_name][idx] = tile
    return signals

def set_signal(env, sig_name, val, signals, fabric_type):
    bits = signals[sig_name]
    lookup = LOOKUP_SMALL if fabric_type == "small" else LOOKUP_LARGE
    for idx in sorted(bits.keys()):
        bidir_idx = lookup[bits[idx]]
        # Drive the internal wire directly to bypass pad/analog issues in simulation
        if hasattr(env, "dut") and hasattr(env.dut, "uut"):
            if hasattr(env.dut.uut, "user_project"):
                env.dut.uut.user_project.u_chip_core.bidir_in[bidir_idx].value = (val >> idx) & 1
            else:
                env.dut.uut.u_chip_core.bidir_in[bidir_idx].value = (val >> idx) & 1
        elif hasattr(env, "dut"):
            env.dut.u_chip_core.bidir_in[bidir_idx].value = (val >> idx) & 1
        else:
            env.uut.u_chip_core.bidir_in[bidir_idx].value = (val >> idx) & 1

def get_signal(env, sig_name, signals, fabric_type):
    bits = signals[sig_name]
    val = 0
    lookup = LOOKUP_SMALL if fabric_type == "small" else LOOKUP_LARGE
    for idx in sorted(bits.keys()):
        bidir_idx = lookup[bits[idx]]
        # Read the internal wire directly to bypass pad/analog issues in simulation
        bit_val = 0
        if hasattr(env, "dut") and hasattr(env.dut, "uut"):
            if hasattr(env.dut.uut, "user_project"):
                bit_val = int(env.dut.uut.user_project.u_chip_core.bidir_out[bidir_idx].value)
            else:
                bit_val = int(env.dut.uut.u_chip_core.bidir_out[bidir_idx].value)
        elif hasattr(env, "dut"):
            bit_val = int(env.dut.u_chip_core.bidir_out[bidir_idx].value)
        else:
            bit_val = int(env.uut.u_chip_core.bidir_out[bidir_idx].value)
        val |= (bit_val << idx)
    return val

def release_signal(env, sig_name, signals, fabric_type):
    bits = signals[sig_name]
    lookup = LOOKUP_SMALL if fabric_type == "small" else LOOKUP_LARGE
    for idx in sorted(bits.keys()):
        bidir_idx = lookup[bits[idx]]
        if hasattr(env, "dut") and hasattr(env.dut, "uut"):
            if hasattr(env.dut.uut, "user_project"):
                env.dut.uut.user_project.u_chip_core.bidir_in[bidir_idx]._release()
            else:
                env.dut.uut.u_chip_core.bidir_in[bidir_idx]._release()
        elif hasattr(env, "dut"):
            env.dut.u_chip_core.bidir_in[bidir_idx]._release()
        else:
            env.uut.u_chip_core.bidir_in[bidir_idx]._release()

async def system_clock_runner(env, gpio_pin=38):
    while True:
        env.drive_gpio(gpio_pin, 1)
        await Timer(12, units="ns")
        env.drive_gpio(gpio_pin, 0)
        await Timer(13, units="ns")

async def select_fabric(env, fabric_type):
    cocotb.start_soon(system_clock_runner(env, 38))
    
    if fabric_type == "small":
        env.drive_gpio(GPIO_FPGA_SEL0, 1)
        env.drive_gpio(GPIO_FPGA_SEL1, 0)
    elif fabric_type == "medium":
        env.drive_gpio(GPIO_FPGA_SEL0, 0)
        env.drive_gpio(GPIO_FPGA_SEL1, 1)
    else:  # large
        env.drive_gpio(GPIO_FPGA_SEL0, 0)
        env.drive_gpio(GPIO_FPGA_SEL1, 0)
    await ClockCycles(env.clk, 10)
    await env.reset()

async def bitbang_upload_bitstream(env, bitstream_path):
    cocotb.log.info(f"--- Uploading bitstream: {bitstream_path} ---")

    env.drive_gpio(GPIO_SPI_CSN, 1)
    env.drive_gpio(GPIO_SPI_SCLK, 0)
    env.drive_gpio(GPIO_SPI_MOSI, 0)
    await ClockCycles(env.clk, 20)

    env.drive_gpio(GPIO_SPI_CSN, 0)
    await ClockCycles(env.clk, 10)

    with open(bitstream_path, 'rb') as f:
        data = f.read(4)
        while data:
            word = int.from_bytes(data, byteorder='big')
            for i in range(32):
                bit = (word >> (31 - i)) & 1
                env.drive_gpio(GPIO_SPI_MOSI, bit)
                await ClockCycles(env.clk, SPI_HALF_PERIOD)
                env.drive_gpio(GPIO_SPI_SCLK, 1)
                await ClockCycles(env.clk, SPI_HALF_PERIOD)
                env.drive_gpio(GPIO_SPI_SCLK, 0)
                await ClockCycles(env.clk, SPI_HALF_PERIOD)
            data = f.read(4)

    await ClockCycles(env.clk, 20)
    env.drive_gpio(GPIO_SPI_CSN, 1)
    await ClockCycles(env.clk, 20)
    cocotb.log.info("Bitstream upload complete!")
