// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * openframe_project_wrapper
 *
 * This wrapper enumerates all of the pins available to the
 * user for the user openframe project.
 *
 * Written by Tim Edwards
 * March 27, 2023
 * Efabless Corporation
 *
 *-------------------------------------------------------------
 */

module openframe_project_wrapper (
`ifdef USE_POWER_PINS
    inout vdda,		// User area 0 3.3V supply
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa,		// User area 0 analog ground
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd,		// Common 1.8V supply
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd,		// Common digital ground
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground
    inout vddio,	// Common 3.3V ESD supply
    inout vssio,	// Common ESD ground
`endif

    /* Signals exported from the frame area to the user project */
    /* The user may elect to use any of these inputs.		*/

    input	 porb_h,	// power-on reset, sense inverted, 3.3V domain
    input	 porb_l,	// power-on reset, sense inverted, 1.8V domain
    input	 por_l,		// power-on reset, noninverted, 1.8V domain
    input	 resetb_h,	// master reset, sense inverted, 3.3V domain
    input	 resetb_l,	// master reset, sense inverted, 1.8V domain
    input [31:0] mask_rev,	// 32-bit user ID, 1.8V domain

    /* GPIOs.  There are 44 GPIOs (19 left, 19 right, 6 bottom). */
    /* These must be configured appropriately by the user project. */

    /* Basic bidirectional I/O.  Input gpio_in_h is in the 3.3V domain;  all
     * others are in the 1.8v domain.  OEB is output enable, sense inverted.
     */
    input  [`OPENFRAME_IO_PADS-1:0] gpio_in,
    input  [`OPENFRAME_IO_PADS-1:0] gpio_in_h,
    output [`OPENFRAME_IO_PADS-1:0] gpio_out,
    output [`OPENFRAME_IO_PADS-1:0] gpio_oeb,
    output [`OPENFRAME_IO_PADS-1:0] gpio_inp_dis,	// a.k.a. ieb

    /* Pad configuration.  These signals are usually static values.
     * See the documentation for the sky130_fd_io__gpiov2 cell signals
     * and their use.
     */
    output [`OPENFRAME_IO_PADS-1:0] gpio_ib_mode_sel,
    output [`OPENFRAME_IO_PADS-1:0] gpio_vtrip_sel,
    output [`OPENFRAME_IO_PADS-1:0] gpio_slow_sel,
    output [`OPENFRAME_IO_PADS-1:0] gpio_holdover,
    output [`OPENFRAME_IO_PADS-1:0] gpio_analog_en,
    output [`OPENFRAME_IO_PADS-1:0] gpio_analog_sel,
    output [`OPENFRAME_IO_PADS-1:0] gpio_analog_pol,
    output [`OPENFRAME_IO_PADS-1:0] gpio_dm2,
    output [`OPENFRAME_IO_PADS-1:0] gpio_dm1,
    output [`OPENFRAME_IO_PADS-1:0] gpio_dm0,

    /* These signals correct directly to the pad.  Pads using analog I/O
     * connections should keep the digital input and output buffers turned
     * off.  Both signals connect to the same pad.  The "noesd" signal
     * is a direct connection to the pad;  the other signal connects through
     * a series resistor which gives it minimal ESD protection.  Both signals
     * have basic over- and under-voltage protection at the pad.  These
     * signals may be expected to attenuate heavily above 50MHz.
     */
    inout  [`OPENFRAME_IO_PADS-1:0] analog_io,
    inout  [`OPENFRAME_IO_PADS-1:0] analog_noesd_io,

    /* These signals are constant one and zero in the 1.8V domain, one for
     * each GPIO pad, and can be looped back to the control signals on the
     * same GPIO pad to set a static configuration at power-up.
     */
    input  [`OPENFRAME_IO_PADS-1:0] gpio_loopback_one,
    input  [`OPENFRAME_IO_PADS-1:0] gpio_loopback_zero
);
        // Internal wires
        wire spi_csn, spi_sclk, spi_mosi;
        wire spi_miso, cfg_done, config_busy;
        wire spi_sclk_o, spi_sclk_en_o, spi_cs_n_o, spi_cs_n_en_o;
        wire spi_mosi_o, spi_mosi_en_o, spi_miso_o, spi_miso_en_o;
        wire [35:0] bidir_in, bidir_out, bidir_oe;
        wire [1:0] fpga_select;  // Routed from GPIO 42-43

        chip_core #(.NUM_BIDIR_PADS(36)) u_chip_core (
            .clk_i(gpio_in[38]),     // Connected directly to input
            .rst_ni(resetb_l),
            .spi_mode_i(1'b1),           // Passive SPI receiver
            .fpga_select_i(fpga_select), // Dynamic select via GPIO 42-43
            .spi_sclk_i(spi_sclk), .spi_sclk_o(spi_sclk_o), .spi_sclk_en_o(spi_sclk_en_o),
            .spi_cs_n_i(spi_csn), .spi_cs_n_o(spi_cs_n_o), .spi_cs_n_en_o(spi_cs_n_en_o),
            .spi_mosi_i(spi_mosi), .spi_mosi_o(spi_mosi_o), .spi_mosi_en_o(spi_mosi_en_o),
            .spi_miso_i(1'b0), .spi_miso_o(spi_miso), .spi_miso_en_o(spi_miso_en_o),
            .config_busy_o(config_busy), .config_done_o(cfg_done),
            .bidir_in(bidir_in), .bidir_out(bidir_out), .bidir_oe(bidir_oe)
        );

	(* keep *) vccd1_connection vccd1_connection_inst ();
	(* keep *) vssd1_connection vssd1_connection_inst ();

        // CF_gpio_config modes
        // 0: analog
        // 1: input
        // 2: input pull down
        // 3: input pull up
        // 4: output
        // 5: bidirectional

        // GPIO 0: spi_csn (Mode 3: input pull-up)
        CF_gpio_config #(.MODE(3'd3)) gpio_csn_config (
          .io_out(), .io_in(spi_csn), .io_oeb(),
          .gpio_zero(gpio_loopback_zero[0]), .gpio_one(gpio_loopback_one[0]),
          .gpio_in(gpio_in[0]), .gpio_dm({gpio_dm2[0], gpio_dm1[0], gpio_dm0[0]}),
          .gpio_inp_dis(gpio_inp_dis[0]), .gpio_oeb_out(gpio_oeb[0]), .gpio_out_val(gpio_out[0]),
          .gpio_analog_en(gpio_analog_en[0]), .gpio_analog_sel(gpio_analog_sel[0]),
          .gpio_analog_pol(gpio_analog_pol[0]), .gpio_ib_mode_sel(gpio_ib_mode_sel[0]),
          .gpio_vtrip_sel(gpio_vtrip_sel[0]), .gpio_slow_sel(gpio_slow_sel[0]),
          .gpio_holdover(gpio_holdover[0])
        );

        // GPIO 1: spi_sclk (Mode 1: input)
        CF_gpio_config #(.MODE(3'd1)) gpio_sclk_config (
          .io_out(), .io_in(spi_sclk), .io_oeb(),
          .gpio_zero(gpio_loopback_zero[1]), .gpio_one(gpio_loopback_one[1]),
          .gpio_in(gpio_in[1]), .gpio_dm({gpio_dm2[1], gpio_dm1[1], gpio_dm0[1]}),
          .gpio_inp_dis(gpio_inp_dis[1]), .gpio_oeb_out(gpio_oeb[1]), .gpio_out_val(gpio_out[1]),
          .gpio_analog_en(gpio_analog_en[1]), .gpio_analog_sel(gpio_analog_sel[1]),
          .gpio_analog_pol(gpio_analog_pol[1]), .gpio_ib_mode_sel(gpio_ib_mode_sel[1]),
          .gpio_vtrip_sel(gpio_vtrip_sel[1]), .gpio_slow_sel(gpio_slow_sel[1]),
          .gpio_holdover(gpio_holdover[1])
        );

        // GPIO 2: spi_mosi (Mode 1: input)
        CF_gpio_config #(.MODE(3'd1)) gpio_mosi_config (
          .io_out(), .io_in(spi_mosi), .io_oeb(),
          .gpio_zero(gpio_loopback_zero[2]), .gpio_one(gpio_loopback_one[2]),
          .gpio_in(gpio_in[2]), .gpio_dm({gpio_dm2[2], gpio_dm1[2], gpio_dm0[2]}),
          .gpio_inp_dis(gpio_inp_dis[2]), .gpio_oeb_out(gpio_oeb[2]), .gpio_out_val(gpio_out[2]),
          .gpio_analog_en(gpio_analog_en[2]), .gpio_analog_sel(gpio_analog_sel[2]),
          .gpio_analog_pol(gpio_analog_pol[2]), .gpio_ib_mode_sel(gpio_ib_mode_sel[2]),
          .gpio_vtrip_sel(gpio_vtrip_sel[2]), .gpio_slow_sel(gpio_slow_sel[2]),
          .gpio_holdover(gpio_holdover[2])
        );

        // GPIO 3: spi_miso (Mode 4: output)
        CF_gpio_config #(.MODE(3'd4)) gpio_miso_config (
          .io_out(spi_miso), .io_in(), .io_oeb(1'b0),
          .gpio_zero(gpio_loopback_zero[3]), .gpio_one(gpio_loopback_one[3]),
          .gpio_in(gpio_in[3]), .gpio_dm({gpio_dm2[3], gpio_dm1[3], gpio_dm0[3]}),
          .gpio_inp_dis(gpio_inp_dis[3]), .gpio_oeb_out(gpio_oeb[3]), .gpio_out_val(gpio_out[3]),
          .gpio_analog_en(gpio_analog_en[3]), .gpio_analog_sel(gpio_analog_sel[3]),
          .gpio_analog_pol(gpio_analog_pol[3]), .gpio_ib_mode_sel(gpio_ib_mode_sel[3]),
          .gpio_vtrip_sel(gpio_vtrip_sel[3]), .gpio_slow_sel(gpio_slow_sel[3]),
          .gpio_holdover(gpio_holdover[3])
        );

        // GPIO 4: cfg_done (Mode 4: output)
        CF_gpio_config #(.MODE(3'd4)) gpio_cfg_done_config (
          .io_out(cfg_done), .io_in(), .io_oeb(1'b0),
          .gpio_zero(gpio_loopback_zero[4]), .gpio_one(gpio_loopback_one[4]),
          .gpio_in(gpio_in[4]), .gpio_dm({gpio_dm2[4], gpio_dm1[4], gpio_dm0[4]}),
          .gpio_inp_dis(gpio_inp_dis[4]), .gpio_oeb_out(gpio_oeb[4]), .gpio_out_val(gpio_out[4]),
          .gpio_analog_en(gpio_analog_en[4]), .gpio_analog_sel(gpio_analog_sel[4]),
          .gpio_analog_pol(gpio_analog_pol[4]), .gpio_ib_mode_sel(gpio_ib_mode_sel[4]),
          .gpio_vtrip_sel(gpio_vtrip_sel[4]), .gpio_slow_sel(gpio_slow_sel[4]),
          .gpio_holdover(gpio_holdover[4])
        );

        // GPIO 5-37: bidir[0:32] (Mode 5: bidirectional)
        genvar i;
        generate
          for (i = 5; i <= 37; i = i + 1) begin : gpio_bidir_0_32
            CF_gpio_config #(.MODE(3'd5)) u_cfg (
              .io_out(bidir_out[i-5]), .io_in(bidir_in[i-5]), .io_oeb(~bidir_oe[i-5]),
              .gpio_zero(gpio_loopback_zero[i]), .gpio_one(gpio_loopback_one[i]),
              .gpio_in(gpio_in[i]), .gpio_dm({gpio_dm2[i], gpio_dm1[i], gpio_dm0[i]}),
              .gpio_inp_dis(gpio_inp_dis[i]), .gpio_oeb_out(gpio_oeb[i]), .gpio_out_val(gpio_out[i]),
              .gpio_analog_en(gpio_analog_en[i]), .gpio_analog_sel(gpio_analog_sel[i]),
              .gpio_analog_pol(gpio_analog_pol[i]), .gpio_ib_mode_sel(gpio_ib_mode_sel[i]),
              .gpio_vtrip_sel(gpio_vtrip_sel[i]), .gpio_slow_sel(gpio_slow_sel[i]),
              .gpio_holdover(gpio_holdover[i])
            );
          end
        endgenerate

        // GPIO 38: clk (Mode 1: input)
        CF_gpio_config #(.MODE(3'd1)) gpio_clk_config (
          .io_out(), .io_in(), .io_oeb(), // clk uses gpio_in[38] directly
          .gpio_zero(gpio_loopback_zero[38]), .gpio_one(gpio_loopback_one[38]),
          .gpio_in(gpio_in[38]), .gpio_dm({gpio_dm2[38], gpio_dm1[38], gpio_dm0[38]}),
          .gpio_inp_dis(gpio_inp_dis[38]), .gpio_oeb_out(gpio_oeb[38]), .gpio_out_val(gpio_out[38]),
          .gpio_analog_en(gpio_analog_en[38]), .gpio_analog_sel(gpio_analog_sel[38]),
          .gpio_analog_pol(gpio_analog_pol[38]), .gpio_ib_mode_sel(gpio_ib_mode_sel[38]),
          .gpio_vtrip_sel(gpio_vtrip_sel[38]), .gpio_slow_sel(gpio_slow_sel[38]),
          .gpio_holdover(gpio_holdover[38])
        );

        // GPIO 39-41: bidir[33:35] (Mode 5: bidirectional)
        genvar j;
        generate
          for (j = 39; j <= 41; j = j + 1) begin : gpio_bidir_33_35
            CF_gpio_config #(.MODE(3'd5)) u_cfg (
              .io_out(bidir_out[j-6]), .io_in(bidir_in[j-6]), .io_oeb(~bidir_oe[j-6]),
              .gpio_zero(gpio_loopback_zero[j]), .gpio_one(gpio_loopback_one[j]),
              .gpio_in(gpio_in[j]), .gpio_dm({gpio_dm2[j], gpio_dm1[j], gpio_dm0[j]}),
              .gpio_inp_dis(gpio_inp_dis[j]), .gpio_oeb_out(gpio_oeb[j]), .gpio_out_val(gpio_out[j]),
              .gpio_analog_en(gpio_analog_en[j]), .gpio_analog_sel(gpio_analog_sel[j]),
              .gpio_analog_pol(gpio_analog_pol[j]), .gpio_ib_mode_sel(gpio_ib_mode_sel[j]),
              .gpio_vtrip_sel(gpio_vtrip_sel[j]), .gpio_slow_sel(gpio_slow_sel[j]),
              .gpio_holdover(gpio_holdover[j])
            );
          end
        endgenerate

        // GPIO 42: fpga_select[0] (Mode 1: input)
        CF_gpio_config #(.MODE(3'd1)) gpio_fpga_sel0_config (
          .io_out(), .io_in(fpga_select[0]), .io_oeb(),
          .gpio_zero(gpio_loopback_zero[42]), .gpio_one(gpio_loopback_one[42]),
          .gpio_in(gpio_in[42]), .gpio_dm({gpio_dm2[42], gpio_dm1[42], gpio_dm0[42]}),
          .gpio_inp_dis(gpio_inp_dis[42]), .gpio_oeb_out(gpio_oeb[42]), .gpio_out_val(gpio_out[42]),
          .gpio_analog_en(gpio_analog_en[42]), .gpio_analog_sel(gpio_analog_sel[42]),
          .gpio_analog_pol(gpio_analog_pol[42]), .gpio_ib_mode_sel(gpio_ib_mode_sel[42]),
          .gpio_vtrip_sel(gpio_vtrip_sel[42]), .gpio_slow_sel(gpio_slow_sel[42]),
          .gpio_holdover(gpio_holdover[42])
        );

        // GPIO 43: fpga_select[1] (Mode 1: input)
        CF_gpio_config #(.MODE(3'd1)) gpio_fpga_sel1_config (
          .io_out(), .io_in(fpga_select[1]), .io_oeb(),
          .gpio_zero(gpio_loopback_zero[43]), .gpio_one(gpio_loopback_one[43]),
          .gpio_in(gpio_in[43]), .gpio_dm({gpio_dm2[43], gpio_dm1[43], gpio_dm0[43]}),
          .gpio_inp_dis(gpio_inp_dis[43]), .gpio_oeb_out(gpio_oeb[43]), .gpio_out_val(gpio_out[43]),
          .gpio_analog_en(gpio_analog_en[43]), .gpio_analog_sel(gpio_analog_sel[43]),
          .gpio_analog_pol(gpio_analog_pol[43]), .gpio_ib_mode_sel(gpio_ib_mode_sel[43]),
          .gpio_vtrip_sel(gpio_vtrip_sel[43]), .gpio_slow_sel(gpio_slow_sel[43]),
          .gpio_holdover(gpio_holdover[43])
        );

endmodule	// openframe_project_wrapper
