----------------------------------------------------------------------
-- TITLE : PROCYON AvalonBUS Interface
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--     DATUM     : 2008/03/21 -> 2008/03/21 (HERSTELLUNG)
--               : 2008/03/24 (FESTSTELLUNG)
--
--               : 2008/06/25 メモリペリフェラルを分離
--               : 2008/07/01 FRCスナップショットを追加 (NEUBEARBEITUNG)
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

entity AvalonIF_STARROSE is
	port(
		reset			: in  std_logic;
		clk				: in  std_logic;
		crtc_clk		: in  std_logic;

	--==== Avalonバス信号線(GPU) =====================================
		address_s1		: in  std_logic_vector(6 downto 2);
		readdata_s1		: out std_logic_vector(31 downto 0);
		write_s1		: in  std_logic;
		writedata_s1	: in  std_logic_vector(31 downto 0);
		irq_s1			: out std_logic;

	--==== Avalonバス信号線(CRTC) ====================================
		address_s2		: in  std_logic_vector(5 downto 2);
		readdata_s2		: out std_logic_vector(31 downto 0);
		write_s2		: in  std_logic;
		writedata_s2	: in  std_logic_vector(31 downto 0);
		irq_s2			: out std_logic;

	--==== Avalonバス信号線(FRC) =====================================
		readdata_s3		: out std_logic_vector(31 downto 0);


	--==== 外部バーストバス信号線 ====================================
		mem_bus_rx		: in  std_logic_vector(61 downto 0) := (others=>'0');
		mem_bus_tx		: out std_logic_vector(32 downto 0);
		spu_bus_rx		: in  std_logic_vector(24 downto 0) := (others=>'0');
		spu_bus_tx		: out std_logic_vector(16 downto 0);

	--==== SDRAM信号線 ===============================================
--		SDR_CLK			: out std_logic;
		SDR_CKE			: out std_logic;
		SDR_nCS			: out std_logic;
		SDR_nRAS		: out std_logic;
		SDR_nCAS		: out std_logic;
		SDR_nWE			: out std_logic;
		SDR_BA			: out std_logic_vector(1 downto 0);
		SDR_A			: out std_logic_vector(12 downto 0);
		SDR_DQ			: inout std_logic_vector(15 downto 0);
		SDR_DQM			: out std_logic_vector(1 downto 0);

	--==== ビデオ信号出力 ============================================
		V_DCLK			: out std_logic;
--		V_BLANK			: out std_logic;
		V_R				: out std_logic_vector(4 downto 0);
		V_G				: out std_logic_vector(4 downto 0);
		V_B				: out std_logic_vector(4 downto 0);
		V_nHSYNC		: out std_logic;
		V_nVSYNC		: out std_logic
	);
end AvalonIF_STARROSE;

architecture RTL of AvalonIF_STARROSE is
	signal frc_count_reg	: std_logic_vector(31 downto 0);

	component PROCYON_GPU
	generic(
		REGISTER_READ	: string;
		SHADING_MODE	: string;
		RENDER_BASE		: string;
		TEXTUER_BASE	: string
	);
	port(
		clk				: in  std_logic;
		reset			: in  std_logic;

		sdr_addr		: out std_logic_vector(12 downto 0);
		sdr_bank		: out std_logic_vector(1 downto 0);
		sdr_cke			: out std_logic;
		sdr_cs			: out std_logic;
		sdr_ras			: out std_logic;
		sdr_cas			: out std_logic;
		sdr_we			: out std_logic;
		sdr_data		: inout std_logic_vector(15 downto 0);
		sdr_dqm			: out std_logic_vector(1 downto 0);

		crtcread_addr	: in  std_logic_vector(24 downto 1);
		crtcread_req	: in  std_logic;
		crtcread_dena	: out std_logic;
		crtcread_data	: out std_logic_vector(15 downto 0);

		pcmread_addr	: in  std_logic_vector(24 downto 1);
		pcmread_req		: in  std_logic;
		pcmread_dena	: out std_logic;
		pcmread_data	: out std_logic_vector(15 downto 0);

		cpu_req			: in  std_logic;
		cpu_done		: out std_logic;
		cpu_address		: in  std_logic_vector(24 downto 2);
		cpu_read		: in  std_logic;
		cpu_rddata		: out std_logic_vector(31 downto 0);
		cpu_write		: in  std_logic;
		cpu_wrdata		: in  std_logic_vector(31 downto 0);
		cpu_byteenable	: in  std_logic_vector(3 downto 0);

		render_irq		: out std_logic;
		reg_select		: in  std_logic_vector(4 downto 0);
		reg_rddata		: out std_logic_vector(31 downto 0);
		reg_wrdata		: in  std_logic_vector(31 downto 0);
		reg_uwen		: in  std_logic;
		reg_lwen		: in  std_logic
	);
	end component;


	component PROCYON_CRTC
	generic(
		REGISTER_READ		: string;
		SYNC_REGISTER		: string;
		DEFAULT_MODE		: string;
		GAMMATABLE_TYPE		: string
	);
	port(
		slave_clk	: in  std_logic;
		crtc_clk	: in  std_logic;
		reset		: in  std_logic;

		fifofill_req: out std_logic;
		fifofill_ena: in  std_logic;
		fifoaddr	: out std_logic_vector(24 downto 1);
		fifodata	: in  std_logic_vector(15 downto 0);

		r_out		: out std_logic_vector(7 downto 0);
		g_out		: out std_logic_vector(7 downto 0);
		b_out		: out std_logic_vector(7 downto 0);
		blank_out	: out std_logic;
		dclk_out	: out std_logic;
		hsync_out	: out std_logic;
		vsync_out	: out std_logic;
		sogsig_out	: out std_logic;

		reg_irq		: out std_logic;
		reg_select	: in  std_logic_vector(3 downto 0);
		reg_rddata	: out std_logic_vector(15 downto 0);
		reg_wrdata	: in  std_logic_vector(15 downto 0);
		reg_wen		: in  std_logic
	);
	end component;
	signal crtc_rddata_sig		: std_logic_vector(15 downto 0);
	signal crtc_readaddr_sig	: std_logic_vector(23 downto 0);
	signal crtc_readreq_sig		: std_logic;
	signal ctrc_readdata_sig	: std_logic_vector(15 downto 0);
	signal crtc_readack_sig		: std_logic;

	signal blank_out_sig	: std_logic;
	signal r_out_sig		: std_logic_vector(7 downto 0);
	signal g_out_sig		: std_logic_vector(7 downto 0);
	signal b_out_sig		: std_logic_vector(7 downto 0);

begin


--==== GPUインスタンス ===============================================

	U0 : PROCYON_GPU
	generic map (
--		REGISTER_READ	=> "ENABLE",
		REGISTER_READ	=> "DISENABLE",
		SHADING_MODE	=> "GOURAUD",
		RENDER_BASE		=> "OFFSET",
		TEXTUER_BASE	=> "OFFSET"
	)
	port map(
		clk				=> clk,
		reset			=> reset,

		sdr_addr		=> SDR_A,
		sdr_bank		=> SDR_BA,
		sdr_cke			=> SDR_CKE,
		sdr_cs			=> SDR_nCS,
		sdr_ras			=> SDR_nRAS,
		sdr_cas			=> SDR_nCAS,
		sdr_we			=> SDR_nWE,
		sdr_data		=> SDR_DQ,
		sdr_dqm			=> SDR_DQM,

		crtcread_addr	=> crtc_readaddr_sig,
		crtcread_req	=> crtc_readreq_sig,
		crtcread_dena	=> crtc_readack_sig,
		crtcread_data	=> ctrc_readdata_sig,
		pcmread_addr	=> spu_bus_rx(24 downto 1),
		pcmread_req		=> spu_bus_rx(0),
		pcmread_dena	=> spu_bus_tx(16),
		pcmread_data	=> spu_bus_tx(15 downto 0),

		cpu_req			=> mem_bus_rx(25),
		cpu_done		=> mem_bus_tx(32),
		cpu_address		=> mem_bus_rx(24 downto 2),
		cpu_read		=> mem_bus_rx(0),
		cpu_rddata		=> mem_bus_tx(31 downto 0),
		cpu_write		=> mem_bus_rx(1),
		cpu_wrdata		=> mem_bus_rx(61 downto 30),
		cpu_byteenable	=> mem_bus_rx(29 downto 26),

		render_irq		=> irq_s1,
		reg_select		=> address_s1,
		reg_rddata		=> readdata_s1,
		reg_wrdata		=> writedata_s1,
		reg_uwen		=> write_s1,
		reg_lwen		=> write_s1
	);


--==== CRTCインスタンス ==============================================
--　※レジスタの上位側８個は内部でcrtc_clkリサンプルをしているため、
--　　Avalonバスの信号はcrtc_clkのクロック幅で取りこぼしが起きないよう
--　　適当に待ち時間を入れておくこと。

	readdata_s2(31 downto 16) <= (others=>'0');
	readdata_s2(15 downto  0) <= crtc_rddata_sig;

	U1 : PROCYON_CRTC
	generic map (
--		REGISTER_READ	=> "ENABLE",
		REGISTER_READ	=> "DISENABLE",
		SYNC_REGISTER	=> "VARIABLE",
--		DEFAULT_MODE	=> "",
		DEFAULT_MODE	=> "LTA042B010F",
		GAMMATABLE_TYPE	=> "CALC"
	)
	port map(
		slave_clk	=> clk,
		crtc_clk	=> crtc_clk,
		reset		=> reset,

		fifofill_req=> crtc_readreq_sig,
		fifofill_ena=> crtc_readack_sig,
		fifoaddr	=> crtc_readaddr_sig,
		fifodata	=> ctrc_readdata_sig,

		r_out		=> r_out_sig,
		g_out		=> g_out_sig,
		b_out		=> b_out_sig,
		blank_out	=> open,
		dclk_out	=> V_DCLK,
		hsync_out	=> V_nHSYNC,
		vsync_out	=> V_nVSYNC,
		sogsig_out	=> open,

		reg_irq		=> irq_s2,
		reg_select	=> address_s2,
		reg_rddata	=> crtc_rddata_sig,
		reg_wrdata	=> writedata_s2(15 downto 0),
		reg_wen		=> write_s2
	);

	V_R <= r_out_sig(7 downto 3);
	V_G <= g_out_sig(7 downto 3);
	V_B <= b_out_sig(7 downto 3);


--==== FRCインスタンス ===============================================
-- １クロックごとにカウントアップするフリーランカウンタ 
-- GPUレジスタのリードバックを無効にしているためここに実装 

	readdata_s3 <= frc_count_reg;

	process (clk,reset) begin
		if (reset='1') then
			frc_count_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			frc_count_reg <= frc_count_reg + '1';
		end if;
	end process;



end RTL;



----------------------------------------------------------------------
--  (C)2003-2008 Copyright J-7SYSTEM Works.  All rights Reserved.   --
----------------------------------------------------------------------
