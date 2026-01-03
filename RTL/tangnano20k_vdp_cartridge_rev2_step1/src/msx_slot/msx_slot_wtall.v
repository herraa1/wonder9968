//
//	msx_slot_wtall.v
//  Copyright (C) 2025 Albert Herranz
//
//  Based on Shinobu Hashimoto port of HRA! TangCartMSX:
//	msx_slot_tncart_rev1.v
//	 MSX Slot top entity
//
//	Copyright (C) 2025 Takayuki Hara
//
//	本ソフトウェアおよび本ソフトウェアに基づいて作成された派生物は、以下の条件を
//	満たす場合に限り、再頒布および使用が許可されます。
//
//	1.ソースコード形式で再頒布する場合、上記の著作権表示、本条件一覧、および下記
//	  免責条項をそのままの形で保持すること。
//	2.バイナリ形式で再頒布する場合、頒布物に付属のドキュメント等の資料に、上記の
//	  著作権表示、本条件一覧、および下記免責条項を含めること。
//	3.書面による事前の許可なしに、本ソフトウェアを販売、および商業的な製品や活動
//	  に使用しないこと。
//
//	本ソフトウェアは、著作権者によって「現状のまま」提供されています。著作権者は、
//	特定目的への適合性の保証、商品性の保証、またそれに限定されない、いかなる明示
//	的もしくは暗黙な保証責任も負いません。著作権者は、事由のいかんを問わず、損害
//	発生の原因いかんを問わず、かつ責任の根拠が契約であるか厳格責任であるか（過失
//	その他の）不法行為であるかを問わず、仮にそのような損害が発生する可能性を知ら
//	されていたとしても、本ソフトウェアの使用によって発生した（代替品または代用サ
//	ービスの調達、使用の喪失、データの喪失、利益の喪失、業務の中断も含め、またそ
//	れに限定されない）直接損害、間接損害、偶発的な損害、特別損害、懲罰的損害、ま
//	たは結果損害について、一切責任を負わないものとします。
//
//	Note that above Japanese version license is the formal document.
//	The following translation is only for reference.
//
//	Redistribution and use of this software or any derivative works,
//	are permitted provided that the following conditions are met:
//
//	1. Redistributions of source code must retain the above copyright
//	   notice, this list of conditions and the following disclaimer.
//	2. Redistributions in binary form must reproduce the above
//	   copyright notice, this list of conditions and the following
//	   disclaimer in the documentation and/or other materials
//	   provided with the distribution.
//	3. Redistributions may not be sold, nor may they be used in a
//	   commercial product or activity without specific prior written
//	   permission.
//
//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//	FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//	COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//	LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
//	ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//	POSSIBILITY OF SUCH DAMAGE.
//
//-----------------------------------------------------------------------------

module msx_slot(
	input			clk,
	input			initial_busy,
	//	MSX Slot Signal
	input			p_slot_wr_n,
	input			p_slot_rd_n,
	inout	[7:0]	p_slot_data,
	output			p_slot_int,				//	1: Normal, 0: Interrupt for WonderTANG! 1.01c
											//	0: Normal, 1: Interrupt for rest of WonderTANG! boards
	output			p_slot_data_dir,		//	1: MSX→Cartridge (Write/Idle), 0: Cartridge→MSX (Read)
	output			p_busdir_n,		  	    //  1: MSX→Cartridge (Write), 0: Cartridge→MSX (Read)
	output			p_slot_reset_n,
	output [2:0]	p_buf_cs,
	input [7:0]		p_buf_d,
	//	Local BUS
	input			int_n,
	output	[2:0]	bus_address,
	output			bus_ioreq,
	output			bus_write,
	output			bus_valid,
	input			bus_ready,
	output	[7:0]	bus_wdata,
	input	[7:0]	bus_rdata,
	input			bus_rdata_en,
	input			dipsw
);
	localparam CS_RESET = 0;	localparam BIT_RESET = 4;
	localparam CS_IOREQ = 0;	localparam BIT_IOREQ = 1;
	localparam CS_A0    = 1;	localparam BIT_A0    = 0;
	localparam CS_A1    = 1;	localparam BIT_A1    = 1;
	localparam CS_A2    = 1;	localparam BIT_A2    = 2;
	localparam CS_A3    = 1;	localparam BIT_A3    = 3;
	localparam CS_A4    = 1;	localparam BIT_A4    = 4;
	localparam CS_A5    = 1;	localparam BIT_A5    = 5;
	localparam CS_A6    = 1;	localparam BIT_A6    = 6;
	localparam CS_A7    = 1;	localparam BIT_A7    = 7;

	reg				ff_pre_slot_ioreq_n	= 1'b1;
	reg				ff_pre_slot_wr_n	= 1'b1;
	reg				ff_pre_slot_rd_n	= 1'b1;

	reg		[7:0]	ff_slot_address;
	reg		[7:0]	ff_slot_data;
	reg		[2:0]	ff_bus_address = 3'd0;
	reg		[7:0]	ff_bus_data;
	wire			w_active;
	reg				ff_initial_busy		= 1'b1;
	reg				ff_iorq_wr			= 1'b0;
	reg				ff_iorq_rd			= 1'b0;
	reg				ff_active			= 1'b0;
	reg				ff_write			= 1'b0;
	reg				ff_valid			= 1'b0;
	reg				ff_ioreq			= 1'b0;
	reg		[7:0]	ff_rdata			= 8'd0;
	reg				ff_rdata_en			= 1'b0;
	wire	[7:0]	w_io_address;

	assign w_io_address	= (dipsw == 1'b0) ? 8'h88: 8'h98;

	// --------------------------------------------------------------------
	//	Initial busy latch
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !p_slot_reset_n ) begin
			ff_initial_busy	<= 1'b1;
		end
		else begin
			ff_initial_busy	<= initial_busy;
		end
	end

	// --------------------------------------------------------------------
	//	chip select
	// --------------------------------------------------------------------
    reg [1:0] ff_buf_cs = 2'b10;

    always @( posedge clk ) begin
        if( ff_state == 2'd0 ) begin
            if( w_start_cond ) begin
                ff_buf_cs <= 2'b01;
            end
        end
        else if( ff_state == 2'd3 ) begin
            ff_buf_cs <= 2'b10;
        end
    end

    assign p_buf_cs[2] = ff_buf_cs[0];	// RESET, IOREQ
    assign p_buf_cs[1] = ff_buf_cs[1];	// A0~7
    assign p_buf_cs[0] = 1'b1;			// A8~15

	// --------------------------------------------------------------------
	//	スキャン開始条件
	// --------------------------------------------------------------------
    wire w_start_cond = ~w_slot_ioreq_n & ~(w_slot_rd_n & w_slot_wr_n);
    wire w_start_cond_wr = ~w_slot_ioreq_n & ~w_slot_wr_n;

	// --------------------------------------------------------------------
	//	スキャン遷移状態
	// --------------------------------------------------------------------
    reg [1:0] ff_state = 2'd0;

    always @( posedge clk ) begin
        if( ff_state == 2'd0 ) begin
            if( w_start_cond ) begin
                ff_state <= ff_state + 1'd1;
            end
        end
        else begin
            ff_state <= ff_state + 1'd1;
        end
    end

	// --------------------------------------------------------------------
	//	信号入力
	// --------------------------------------------------------------------
	wire [1:0] w_ena;
    assign w_ena[0] = (ff_state == 2'd0);
    assign w_ena[1] = (ff_state == 2'd1) || (ff_state == 2'd2);

	wire w_slot_rd_n;
	wire w_slot_wr_n;
	wire w_slot_reset_n;
	wire w_slot_ioreq_n;
	wire [7:0] w_slot_address;

    cart_sig_input u_rd_n    (.clk(clk), .ena(1'b1           ), .in(p_slot_rd_n       ), .out(w_slot_rd_n      ));
    cart_sig_input u_wr_n    (.clk(clk), .ena(1'b1           ), .in(p_slot_wr_n       ), .out(w_slot_wr_n      ));
    cart_sig_input u_ioreq_n (.clk(clk), .ena(w_ena[CS_IOREQ]), .in(p_buf_d[BIT_IOREQ]), .out(w_slot_ioreq_n   ));
    cart_sig_input u_reset_n (.clk(clk), .ena(w_ena[CS_RESET]), .in(p_buf_d[BIT_RESET]), .out(w_slot_reset_n   ));
    cart_sig_input u_addr_0  (.clk(clk), .ena(w_ena[CS_A0   ]), .in(p_buf_d[BIT_A0   ]), .out(w_slot_address[0]));
    cart_sig_input u_addr_1  (.clk(clk), .ena(w_ena[CS_A1   ]), .in(p_buf_d[BIT_A1   ]), .out(w_slot_address[1]));
    cart_sig_input u_addr_2  (.clk(clk), .ena(w_ena[CS_A2   ]), .in(p_buf_d[BIT_A2   ]), .out(w_slot_address[2]));
    cart_sig_input u_addr_3  (.clk(clk), .ena(w_ena[CS_A3   ]), .in(p_buf_d[BIT_A3   ]), .out(w_slot_address[3]));
    cart_sig_input u_addr_4  (.clk(clk), .ena(w_ena[CS_A4   ]), .in(p_buf_d[BIT_A4   ]), .out(w_slot_address[4]));
    cart_sig_input u_addr_5  (.clk(clk), .ena(w_ena[CS_A5   ]), .in(p_buf_d[BIT_A5   ]), .out(w_slot_address[5]));
    cart_sig_input u_addr_6  (.clk(clk), .ena(w_ena[CS_A6   ]), .in(p_buf_d[BIT_A6   ]), .out(w_slot_address[6]));
    cart_sig_input u_addr_7  (.clk(clk), .ena(w_ena[CS_A7   ]), .in(p_buf_d[BIT_A7   ]), .out(w_slot_address[7]));

	// --------------------------------------------------------------------
	//	スキャン開始時の RD/WR 要求を保持
	// --------------------------------------------------------------------
	reg ff_iorq_rd_pre = 1'b0;
	reg ff_iorq_wr_pre = 1'b0;

    always @( posedge clk ) begin
		if( ff_state == 2'd0 && w_start_cond ) begin
			ff_iorq_rd_pre	<= ~w_slot_rd_n & ~w_slot_ioreq_n;
            ff_iorq_wr_pre	<= ~w_slot_wr_n & ~w_slot_ioreq_n;
        end
    end

	// --------------------------------------------------------------------
	//	スキャン完了時に RD/WR 要求を通知
	// --------------------------------------------------------------------
    always @(posedge clk) begin
		if( !w_slot_reset_n ) begin
			ff_iorq_wr		<= 1'b0;
		end
		else if( ff_initial_busy ) begin
			//	hold
		end
		else if( ff_state == 2'd0 ) begin
            if( w_slot_ioreq_n | w_slot_wr_n ) begin
                ff_iorq_wr	<= 1'b0;
            end
        end
        else if( ff_state == 2'd3 ) begin
            ff_iorq_wr		<= ff_iorq_wr_pre;
        end
    end

    always @(posedge clk) begin
		if( !w_slot_reset_n ) begin
			ff_iorq_rd		<= 1'b0;
		end
		else if( ff_initial_busy ) begin
			//	hold
		end
		else if( ff_state == 2'd0 ) begin
            if( w_slot_ioreq_n | w_slot_rd_n ) begin
                ff_iorq_rd	<= 1'b0;
            end
        end
        else if( ff_state == 2'd3 ) begin
            ff_iorq_rd		<= ff_iorq_rd_pre;
        end
    end

	// --------------------------------------------------------------------
	//	スキャン開始時にデータは確定済み
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( ff_state == 2'd0 && w_start_cond_wr ) begin
			ff_slot_data		<= p_slot_data;
		end
	end

	// --------------------------------------------------------------------
	//	スキャン完了するまでアドレスは確定しない
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( ff_state == 2'd3 ) begin
			ff_slot_address		<= w_slot_address;
		end
	end

	// --------------------------------------------------------------------
	//	reset
	// --------------------------------------------------------------------
	assign p_slot_reset_n = w_slot_reset_n;

	// --------------------------------------------------------------------
	//	Transaction active signal
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !p_slot_reset_n ) begin
			ff_active <= 1'b0;
		end
		else begin
			ff_active <= w_active;
		end
	end

	assign w_active		= ff_iorq_wr | ff_iorq_rd;

	// --------------------------------------------------------------------
	//	Address latch
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !p_slot_reset_n ) begin
			ff_valid	<= 1'b0;
			ff_ioreq	<= 1'b0;
			ff_write	<= 1'b1;
		end
		else if( ff_valid ) begin
			if( bus_ready || !ff_ioreq ) begin
				ff_valid	<= 1'b0;
			end
		end
		else if( !ff_active && w_active ) begin
			if( { ff_slot_address[7:3], 3'd0 } == w_io_address ) begin
				ff_bus_address	<= ff_slot_address[2:0];
				ff_bus_data		<= ff_slot_data;
				ff_ioreq		<= ff_iorq_wr | ff_iorq_rd;
				ff_valid		<= 1'b1;
			end
			else begin
				ff_ioreq	<= 1'b0;
			end
			ff_write	<= ff_iorq_wr;
		end
		else if( !ff_active ) begin
			ff_ioreq	<= 1'b0;
			ff_write	<= 1'b1;
		end
	end

	// --------------------------------------------------------------------
	//	Read data
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !p_slot_reset_n ) begin
			ff_rdata	<= 8'h00;
			ff_rdata_en	<= 1'b0;
		end
		else if( !ff_ioreq ) begin
			ff_rdata	<= 8'h00;
			ff_rdata_en	<= 1'b0;
		end
		else if( bus_rdata_en ) begin
			ff_rdata	<= bus_rdata;
			ff_rdata_en	<= 1'b1;
		end
	end

	assign bus_ioreq		= ff_ioreq;
	assign bus_address		= ff_bus_address;
	assign bus_wdata		= ff_bus_data;
	assign bus_write		= ff_write;
	assign bus_valid		= ff_valid;
	assign p_slot_data		= (ff_ioreq & ff_iorq_rd) ? ff_rdata: 8'hZZ;
	assign p_slot_int		= (CONFIG_BOARD::BOARD_ID == BOARD_ID::WonderTANG_101c) ? int_n : ~int_n;

	// 1: Cartridge <- CPU (Write or Idle), 0: Cartridge -> CPU (Read)
	assign p_slot_data_dir	= ~(ff_ioreq & ff_iorq_rd);
	// active low on I/O read, high otherwise
	assign p_busdir_n		= ~(ff_ioreq & ff_iorq_rd);
endmodule

module cart_sig_input (
	input clk,
    input  in,
    input  ena,
    output  out
)/* synthesis syn_preserve=1 */;
	reg ff_out = 1'b1;
    reg ff_pre = 1'b1;

    assign out = ff_out;

    always @(posedge clk) begin
    	if(ena) begin
        	if(ff_pre & in) begin
            	ff_out <= ff_pre;
            end
        	else if(~ff_pre & ~in) begin
            	ff_out <= ff_pre;
            end
            ff_pre <= in;
        end
    end
endmodule
