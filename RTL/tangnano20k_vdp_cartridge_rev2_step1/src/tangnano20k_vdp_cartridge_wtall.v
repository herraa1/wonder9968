// -----------------------------------------------------------------------------
//	tangnano20k_vdp_cartridge_wtall.v
//	Copyright (C) 2025 Albert Herranz
//
//  Based on Shinobu Hashimoto port of HRA! TangCartMSX:
//	tangnano20k_vdp_cartridge_tncart_rev1.v
//	Copyright (C)2025 Takayuki Hara (HRA!)
//	
//	 Permission is hereby granted, free of charge, to any person obtaining a 
//	copy of this software and associated documentation files (the "Software"), 
//	to deal in the Software without restriction, including without limitation 
//	the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//	and/or sell copies of the Software, and to permit persons to whom the 
//	Software is furnished to do so, subject to the following conditions:
//	
//	The above copyright notice and this permission notice shall be included in 
//	all copies or substantial portions of the Software.
//	
//	The Software is provided "as is", without warranty of any kind, express or 
//	implied, including but not limited to the warranties of merchantability, 
//	fitness for a particular purpose and noninfringement. In no event shall the 
//	authors or copyright holders be liable for any claim, damages or other 
//	liability, whether in an action of contract, tort or otherwise, arising 
//	from, out of or in connection with the Software or the use or other dealings 
//	in the Software.
// -----------------------------------------------------------------------------

module tangnano20k_vdp_cartridge (
	input			clk27m,			// PIN04
	input			clk4m,
	input			slot_rd_n,
	input			slot_wr_n,
	output			slot_wait,
	output			slot_intr,
	output			slot_data_dir,
	inout	[7:0]	slot_d,
	output			slot_busdir_n,
	output	[2:0]	buf_cs,
	input	[7:0]	buf_d,

	input			dipsw,			//
	input	[1:0]	button,			//	PIN87, 88	KEY2, KEY1

	// HDMI
	output			O_tmds_clk_p,	//	(PIN33/34)
	output			O_tmds_clk_n,	//	dummy
	output	[2:0]	O_tmds_data_p,	//	(PIN39/40), (PIN37/38), (PIN35/36)
	output	[2:0]	O_tmds_data_n,	//	dummy

    // SDRAM
	output			O_sdram_clk,
	output			O_sdram_cke,
	output			O_sdram_cs_n,	// chip select
	output			O_sdram_ras_n,	// row address select
	output			O_sdram_cas_n,	// columns address select
	output			O_sdram_wen_n,	// write enable
	inout	[31:0]	IO_sdram_dq,	// 32 bit bidirectional data bus
	output	[10:0]	O_sdram_addr,	// 11 bit multiplexed address bus
	output	[ 1:0]	O_sdram_ba,		// two banks
	output	[ 3:0]	O_sdram_dqm		// data mask
);
	reg				ff_reset_n0 = 1'b0;
	reg				ff_reset_n1 = 1'b0;
	reg				ff_reset_n2_1 = 1'b0;
	reg				ff_reset_n2_2 = 1'b0;
	wire			reset_n;
	wire			reset_n2;

	wire			dvi_serial_clk;		//	171MHz
	wire			dvi_rgb_clk;		//	34.2MHz
	wire			dvi_clk_lock;

	wire			clk85m;				//	85.5MHz
	wire			clk85m_p;			//	85.5MHz (180deg phase shift)
	wire			clk85m_lock;

	wire			slot_reset_n;

	wire	[2:0]	w_bus_address;
	wire			w_bus_ioreq;
	wire			w_bus_write;
	wire			w_bus_valid;
	wire			w_bus_ready;
	wire	[7:0]	w_bus_wdata;
	wire	[7:0]	w_bus_rdata;
	wire			w_bus_rdata_en;

	wire			w_bus_vdp_ioreq;
	wire			w_bus_vdp_ready;
	wire	[7:0]	w_bus_vdp_rdata;
	wire			w_bus_vdp_rdata_en;

	wire			w_sdram_init_busy;

	wire	[22:2]	w_sdram_address;
	wire			w_sdram_write;
	wire			w_sdram_valid;
	wire			w_sdram_refresh;
	wire	[31:0]	w_sdram_wdata;
	wire	[3:0]	w_sdram_wdata_mask;
	wire	[31:0]	w_sdram_rdata;
	wire			w_sdram_rdata_en;

	wire			w_video_de;
	wire			w_video_hs;
	wire			w_video_vs;
	wire	[7:0]	w_video_r;
	wire	[7:0]	w_video_g;
	wire	[7:0]	w_video_b;

	wire			w_pulse0;
	wire			w_pulse1;
	wire			w_pulse2;
	wire			w_pulse3;
	wire			w_pulse4;
	wire			w_pulse5;
	wire			w_pulse6;
	wire			w_pulse7;
	wire			w_wr;
	wire			w_sending;
	wire	[7:0]	w_red;
	wire	[7:0]	w_green;
	wire	[7:0]	w_blue;
	wire			w_int_n;

	wire			ws2812_led;						// dummy

	assign slot_wait		= w_sdram_init_busy;

	always @( posedge clk85m ) begin
		ff_reset_n0		<= slot_reset_n;
		ff_reset_n1		<= ff_reset_n0;
		ff_reset_n2_1	<= ff_reset_n1;
		ff_reset_n2_2	<= ff_reset_n1;
	end

	assign reset_n	= ff_reset_n2_1;
	assign reset_n2	= ff_reset_n2_2;

	// --------------------------------------------------------------------
	//	clocks
	// --------------------------------------------------------------------

    // DVI TX IP clock requirements
	// serial_clk : rgb_clk * 5
	// rgb_clk    : video input pixel clock (10-80MHz, default 40MHz)

	// we use 2 * 85.5MHz = 171MHz for serial_clk and 171 / 5 = 34.2MHz for rgb_clk

    /* 34.2MHz = 171MHz / 5 */
    CLKDIV u_div_tmds (
        .CLKOUT(dvi_rgb_clk),    // 34.2MHz
        .HCLKIN(dvi_serial_clk), // 171MHz 
        .RESETN(dvi_clk_lock),
        .CALIB(1'b0)
    );
    defparam u_div_tmds.DIV_MODE = "5";
    defparam u_div_tmds.GSREN = "false";

    /* 171MHz = 85.5MHz * 2 */
	rPLL u_pll_tmds (
		.CLKOUT(dvi_serial_clk), // 171MHz
		.LOCK(dvi_clk_lock),
		.CLKOUTP(),
		.CLKOUTD(),
		.CLKOUTD3(),
		.RESET(1'b0),
		.RESET_P(1'b0),
		.CLKIN(clk85m),          // 85.5MHz
		.CLKFB(1'b0),
		.FBDSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
		.IDSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
		.ODSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
		.PSDA({1'b0,1'b0,1'b0,1'b0}),
		.DUTYDA({1'b0,1'b0,1'b0,1'b0}),
		.FDLY({1'b0,1'b0,1'b0,1'b0})
	);

	defparam u_pll_tmds.FCLKIN = "85.5";
	defparam u_pll_tmds.DYN_IDIV_SEL = "false";
	defparam u_pll_tmds.IDIV_SEL = 0;
	defparam u_pll_tmds.DYN_FBDIV_SEL = "false";
	defparam u_pll_tmds.FBDIV_SEL = 1;
	defparam u_pll_tmds.DYN_ODIV_SEL = "false";
	defparam u_pll_tmds.ODIV_SEL = 4;
	defparam u_pll_tmds.PSDA_SEL = "0000";
	defparam u_pll_tmds.DYN_DA_EN = "true";
	defparam u_pll_tmds.DUTYDA_SEL = "1000";
	defparam u_pll_tmds.CLKOUT_FT_DIR = 1'b1;
	defparam u_pll_tmds.CLKOUTP_FT_DIR = 1'b1;
	defparam u_pll_tmds.CLKOUT_DLY_STEP = 0;
	defparam u_pll_tmds.CLKOUTP_DLY_STEP = 0;
	defparam u_pll_tmds.CLKFB_SEL = "internal";
	defparam u_pll_tmds.CLKOUT_BYPASS = "false";
	defparam u_pll_tmds.CLKOUTP_BYPASS = "false";
	defparam u_pll_tmds.CLKOUTD_BYPASS = "false";
	defparam u_pll_tmds.DYN_SDIV_SEL = 2;
	defparam u_pll_tmds.CLKOUTD_SRC = "CLKOUT";
	defparam u_pll_tmds.CLKOUTD3_SRC = "CLKOUT";
	defparam u_pll_tmds.DEVICE = "GW2AR-18C";

    /* 85.5MHz = 27MHz * (18+1) / (5+1) = 27 * 19 / 6 = 85.5MHz */
    rPLL u_pll_base (
        .CLKOUT(clk85m),     // 85.5MHz 
        .LOCK(clk85m_lock),
        .CLKOUTP(clk85m_p),
        .CLKOUTD(),
        .CLKOUTD3(),
        .RESET(1'b0),
        .RESET_P(1'b0),
        .CLKIN(clk27m),      // 27MHz
        .CLKFB(1'b0),
        .FBDSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .IDSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .ODSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .PSDA({1'b0,1'b0,1'b0,1'b0}),
        .DUTYDA({1'b0,1'b0,1'b0,1'b0}),
        .FDLY({1'b1,1'b1,1'b1,1'b1})
    );

    defparam u_pll_base.FCLKIN = "27";
    defparam u_pll_base.DYN_IDIV_SEL = "false";
    defparam u_pll_base.IDIV_SEL = 5;
    defparam u_pll_base.DYN_FBDIV_SEL = "false";
    defparam u_pll_base.FBDIV_SEL = 18;
    defparam u_pll_base.DYN_ODIV_SEL = "false";
    defparam u_pll_base.ODIV_SEL = 8;
    defparam u_pll_base.PSDA_SEL = "1000";
    defparam u_pll_base.DYN_DA_EN = "false";
    defparam u_pll_base.DUTYDA_SEL = "1000";
    defparam u_pll_base.CLKOUT_FT_DIR = 1'b1;
    defparam u_pll_base.CLKOUTP_FT_DIR = 1'b1;
    defparam u_pll_base.CLKOUT_DLY_STEP = 0;
    defparam u_pll_base.CLKOUTP_DLY_STEP = 0;
    defparam u_pll_base.CLKFB_SEL = "internal";
    defparam u_pll_base.CLKOUT_BYPASS = "false";
    defparam u_pll_base.CLKOUTP_BYPASS = "false";
    defparam u_pll_base.CLKOUTD_BYPASS = "false";
    defparam u_pll_base.DYN_SDIV_SEL = 2;
    defparam u_pll_base.CLKOUTD_SRC = "CLKOUT";
    defparam u_pll_base.CLKOUTD3_SRC = "CLKOUT";
    defparam u_pll_base.DEVICE = "GW2AR-18C";

	// --------------------------------------------------------------------
	// MSX slot interface and auxiliary signals
	// --------------------------------------------------------------------
	msx_slot u_msx_slot (
		.clk				( clk85m					),
		.initial_busy		( w_sdram_init_busy			),
		.p_slot_reset_n		( slot_reset_n				),
		.p_slot_wr_n		( slot_wr_n					),
		.p_slot_rd_n		( slot_rd_n					),
		.p_slot_data		( slot_d					),
		.p_slot_int			( slot_intr					),
		.p_slot_data_dir	( slot_data_dir				),
		.p_busdir_n         ( slot_busdir_n			    ),
		.int_n				( w_int_n					),
		.p_buf_cs			( buf_cs					),
		.p_buf_d			( buf_d						),
		.bus_address		( w_bus_address				),
		.bus_ioreq			( w_bus_ioreq				),
		.bus_write			( w_bus_write				),
		.bus_valid			( w_bus_valid				),
		.bus_ready			( w_bus_ready				),
		.bus_wdata			( w_bus_wdata				),
		.bus_rdata			( w_bus_rdata				),
		.bus_rdata_en		( w_bus_rdata_en			),
		.dipsw				( CONFIG_BOARD::DIPSW == 2 ? dipsw : (CONFIG_BOARD::DIPSW ? 1'b1 : 1'b0))
	);

	assign w_bus_rdata		= ( w_bus_vdp_rdata_en ) ? w_bus_vdp_rdata: 8'hFF;
	assign w_bus_rdata_en	= w_bus_vdp_rdata_en;
	assign w_bus_ready		= w_bus_vdp_ready;

	// --------------------------------------------------------------------
	//	V9958 clone
	// --------------------------------------------------------------------
	vdp u_v9958 (
		.reset_n			( reset_n				),
		.clk				( clk85m				),
		.initial_busy		( w_sdram_init_busy		),
		.bus_address		( w_bus_address			),
		.bus_ioreq			( w_bus_ioreq			),
		.bus_write			( w_bus_write			),
		.bus_valid			( w_bus_valid			),
		.bus_ready			( w_bus_vdp_ready		),
		.bus_wdata			( w_bus_wdata			),
		.bus_rdata			( w_bus_vdp_rdata		),
		.bus_rdata_en		( w_bus_vdp_rdata_en	),
		.int_n				( w_int_n				),
		.vram_address		( w_sdram_address[17:2]	),
		.vram_write			( w_sdram_write			),
		.vram_valid			( w_sdram_valid			),
		.vram_wdata			( w_sdram_wdata			),
		.vram_wdata_mask	( w_sdram_wdata_mask	),
		.vram_rdata			( w_sdram_rdata			),
		.vram_rdata_en		( w_sdram_rdata_en		),
		.vram_refresh		( w_sdram_refresh		),
		.display_hs			( w_video_hs			),
		.display_vs			( w_video_vs			),
		.display_en			( w_video_de			),
		.display_r			( w_video_r				),
		.display_g			( w_video_g				),
		.display_b			( w_video_b				),
		.force_highspeed	( CONFIG_BOARD::FORCE_HIGHSPEED ? 1'b1 : 1'b0 ),
		.button				( 2'b00					),
		.pulse0				( w_pulse0				),
		.pulse1				( w_pulse1				),
		.pulse2				( w_pulse2				),
		.pulse3				( w_pulse3				),
		.pulse4				( w_pulse4				),
		.pulse5				( w_pulse5				),
		.pulse6				( w_pulse6				),
		.pulse7				( w_pulse7				)
	);

	assign w_sdram_address[22:18]	= 5'd0;

	// --------------------------------------------------------------------
	//	HDMI
	// --------------------------------------------------------------------
	DVI_TX_Top u_dvi (
		.I_rst_n			( reset_n2				),		//input I_rst_n
		.I_serial_clk		( dvi_serial_clk		),		//input I_serial_clk
		.I_rgb_clk			( dvi_rgb_clk			),		//input I_rgb_clk
		.I_rgb_vs			( w_video_vs			),		//input I_rgb_vs
		.I_rgb_hs			( w_video_hs			),		//input I_rgb_hs
		.I_rgb_de			( w_video_de			),		//input I_rgb_de
		.I_rgb_r			( w_video_r				),		//input [7:0] I_rgb_r
		.I_rgb_g			( w_video_g				),		//input [7:0] I_rgb_g
		.I_rgb_b			( w_video_b				),		//input [7:0] I_rgb_b
		.O_tmds_clk_p		( O_tmds_clk_p			),		//output O_tmds_clk_p
		.O_tmds_clk_n		( O_tmds_clk_n			),		//output O_tmds_clk_n
		.O_tmds_data_p		( O_tmds_data_p			),		//output [2:0] O_tmds_data_p
		.O_tmds_data_n		( O_tmds_data_n			)		//output [2:0] O_tmds_data_n
	);

	// --------------------------------------------------------------------
	//	SDRAM
	// --------------------------------------------------------------------
	ip_sdram #(
		.FREQ				( 85_500_000			)		//	Hz
	) u_sdram (
		.reset_n			( reset_n				),
		.clk				( clk85m				),		//	85.5MHz
		.clk_sdram			( clk85m_p				),
		.sdram_init_busy	( w_sdram_init_busy		),
		.bus_address		( w_sdram_address		),
		.bus_valid			( w_sdram_valid			),
		.bus_write			( w_sdram_write			),
		.bus_refresh		( w_sdram_refresh		),
		.bus_wdata			( w_sdram_wdata			),
		.bus_wdata_mask		( w_sdram_wdata_mask	),
		.bus_rdata			( w_sdram_rdata			),
		.bus_rdata_en		( w_sdram_rdata_en		),
		.O_sdram_clk		( O_sdram_clk			),
		.O_sdram_cke		( O_sdram_cke			),
		.O_sdram_cs_n		( O_sdram_cs_n			),		// chip select
		.O_sdram_ras_n		( O_sdram_ras_n			),		// row address select
		.O_sdram_cas_n		( O_sdram_cas_n			),		// columns address select
		.O_sdram_wen_n		( O_sdram_wen_n			),		// write enable
		.IO_sdram_dq		( IO_sdram_dq			),		// 32 bit bidirectional data bus
		.O_sdram_addr		( O_sdram_addr			),		// 11 bit multiplexed address bus
		.O_sdram_ba			( O_sdram_ba			),		// two banks
		.O_sdram_dqm		( O_sdram_dqm			)		// data mask
	);

	// --------------------------------------------------------------------
	//	Debug p LED
	// --------------------------------------------------------------------
	ip_ws2812_led u_led (
		.reset_n			( reset_n				),
		.clk				( clk85m				),
		.wr					( w_wr					),
		.sending			( w_sending				),
		.red				( w_red					),
		.green				( w_green				),
		.blue				( w_blue				),
		.ws2812_led			( ws2812_led			)
	);

	// --------------------------------------------------------------------
	//	Debugger
	// --------------------------------------------------------------------
	ip_debugger u_debugger (
		.reset_n			( reset_n				),
		.clk				( clk85m				),
		.pulse0				( w_pulse0				),
		.pulse1				( w_pulse1				),
		.pulse2				( w_pulse2				),
		.pulse3				( w_pulse3				),
		.pulse4				( w_pulse4				),
		.pulse5				( w_pulse5				),
		.pulse6				( w_pulse6				),
		.pulse7				( w_pulse7				),
		.wr					( w_wr					),
		.sending			( w_sending				),
		.red				( w_red					),
		.green				( w_green				),
		.blue				( w_blue				)
	);
endmodule
