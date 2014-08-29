-- ===================================================================
-- TITLE : STARROSE GPU with ILI9325 LCDC Interface
--
--     DESIGN : S.OSAFUNE (J-7SYSTEM Works)
--     DATE   : 2014/05/29 -> 2014/05/xx
--            : 2014/05/xx (FIXED)
--
-- ===================================================================
-- *******************************************************************
--   Copyright (C) 2014, J-7SYSTEM Works.  All rights Reserved.
--
-- * This module is a free sourcecode and there is NO WARRANTY.
-- * No restriction on use. You can use, modify and redistribute it
--   for personal, non-profit or commercial products UNDER YOUR
--   RESPONSIBILITY.
-- * Redistributions of source code must retain the above copyright
--   notice.
-- *******************************************************************


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

entity gpu_component is
	port(
	--==== Avalonバス信号線 ==========================================
		csi_clk				: in  std_logic;
		csi_reset			: in  std_logic;

		----- AvalonMMスレーブ信号(GPU) -----------
		avs_s1_address		: in  std_logic_vector(6 downto 2);
		avs_s1_read			: in  std_logic;
		avs_s1_readdata		: out std_logic_vector(31 downto 0);
		avs_s1_write		: in  std_logic;
		avs_s1_writedata	: in  std_logic_vector(31 downto 0);

		ins_s1_irq			: out std_logic;

		----- AvalonMMスレーブ信号(LCDC) -----------
		avs_s2_address		: in  std_logic_vector(3 downto 2);
		avs_s2_read			: in  std_logic;
		avs_s2_readdata		: out std_logic_vector(31 downto 0);
		avs_s2_write		: in  std_logic;
		avs_s2_writedata	: in  std_logic_vector(31 downto 0);

		ins_s2_irq			: out std_logic;

		----- AvalonMMスレーブ信号(Memory) -----------
		avs_s3_chipselect	: in  std_logic;
		avs_s3_address		: in  std_logic_vector(24 downto 0);
		avs_s3_read			: in  std_logic;
		avs_s3_readdata		: out std_logic_vector(31 downto 0);
		avs_s3_write		: in  std_logic;
		avs_s3_writedata	: in  std_logic_vector(31 downto 0);
		avs_s3_byteenable	: in  std_logic_vector(3 downto 0);
		avs_s3_waitrequest	: out std_logic;


	--==== SDRAM信号線(256Mbit) ======================================
		coe_sdr_cke			: out std_logic;
		coe_sdr_cs_n		: out std_logic;
		coe_sdr_ras_n		: out std_logic;
		coe_sdr_cas_n		: out std_logic;
		coe_sdr_we_n		: out std_logic;
		coe_sdr_ba			: out std_logic_vector(1 downto 0);
		coe_sdr_a			: out std_logic_vector(12 downto 0);
		coe_sdr_dq			: inout std_logic_vector(15 downto 0);
		coe_sdr_dqm			: out std_logic_vector(1 downto 0);


	--==== ILI9325信号線(i80-8bit接続) ===============================
		coe_lcd_rst_n		: out std_logic;
		coe_lcd_cs_n		: out std_logic;
		coe_lcd_rs			: out std_logic;
		coe_lcd_wr_n		: out std_logic;
		coe_lcd_d			: inout std_logic_vector(7 downto 0)
	);
end gpu_component;

architecture RTL of gpu_component is

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
	signal crtc_bus_rx_sig	: std_logic_vector(24 downto 0);
	signal crtc_bus_tx_sig	: std_logic_vector(16 downto 0);
	signal spu_bus_rx_sig	: std_logic_vector(24 downto 0);
	signal spu_bus_tx_sig	: std_logic_vector(16 downto 0);
	signal mem_bus_rx_sig	: std_logic_vector(61 downto 0);
	signal mem_bus_tx_sig	: std_logic_vector(32 downto 0);

	component lcdc_component_gpu
	port(
		csi_clk				: in  std_logic;
		csi_reset			: in  std_logic;

		avs_s1_address		: in  std_logic_vector(3 downto 2);
		avs_s1_read			: in  std_logic;
		avs_s1_readdata		: out std_logic_vector(31 downto 0);
		avs_s1_write		: in  std_logic;
		avs_s1_writedata	: in  std_logic_vector(31 downto 0);

		ins_s1_irq			: out std_logic;

		coe_gpucrtc_send	: out std_logic_vector(24 downto 0);
		coe_gpucrtc_recv	: in  std_logic_vector(16 downto 0);

		coe_lcd_rst_n		: out std_logic;
		coe_lcd_cs_n		: out std_logic;
		coe_lcd_rs			: out std_logic;
		coe_lcd_wr_n		: out std_logic;
		coe_lcd_d			: inout std_logic_vector(7 downto 0)
	);
	end component;


begin


--==== GPUインスタンス ===============================================

	U0 : PROCYON_GPU
	generic map(
--		REGISTER_READ	=> "ENABLE",
		REGISTER_READ	=> "DISENABLE",
		SHADING_MODE	=> "GOURAUD",
		RENDER_BASE		=> "OFFSET",
		TEXTUER_BASE	=> "OFFSET"
	)
	port map(
		clk				=> csi_clk,
		reset			=> csi_reset,

		sdr_addr		=> coe_sdr_a,
		sdr_bank		=> coe_sdr_ba,
		sdr_cke			=> coe_sdr_cke,
		sdr_cs			=> coe_sdr_cs_n,
		sdr_ras			=> coe_sdr_ras_n,
		sdr_cas			=> coe_sdr_cas_n,
		sdr_we			=> coe_sdr_we_n,
		sdr_data		=> coe_sdr_dq,
		sdr_dqm			=> coe_sdr_dqm,

		crtcread_addr	=> crtc_bus_rx_sig(24 downto 1),
		crtcread_req	=> crtc_bus_rx_sig(0),
		crtcread_dena	=> crtc_bus_tx_sig(16),
		crtcread_data	=> crtc_bus_tx_sig(15 downto 0),
		pcmread_addr	=> spu_bus_rx_sig(24 downto 1),
		pcmread_req		=> spu_bus_rx_sig(0),
		pcmread_dena	=> spu_bus_tx_sig(16),
		pcmread_data	=> spu_bus_tx_sig(15 downto 0),

		cpu_req			=> mem_bus_rx_sig(25),
		cpu_done		=> mem_bus_tx_sig(32),
		cpu_address		=> mem_bus_rx_sig(24 downto 2),
		cpu_read		=> mem_bus_rx_sig(0),
		cpu_rddata		=> mem_bus_tx_sig(31 downto 0),
		cpu_write		=> mem_bus_rx_sig(1),
		cpu_wrdata		=> mem_bus_rx_sig(61 downto 30),
		cpu_byteenable	=> mem_bus_rx_sig(29 downto 26),

		render_irq		=> ins_s1_irq,
		reg_select		=> avs_s1_address,
		reg_rddata		=> avs_s1_readdata,
		reg_wrdata		=> avs_s1_writedata,
		reg_uwen		=> avs_s1_write,
		reg_lwen		=> avs_s1_write
	);



--==== LCDCインスタンス ==============================================

	U1 : lcdc_component_gpu
	port map(
		csi_clk				=> csi_clk,
		csi_reset			=> csi_reset,

		avs_s1_address		=> avs_s2_address,
		avs_s1_read			=> avs_s2_read,
		avs_s1_readdata		=> avs_s2_readdata,
		avs_s1_write		=> avs_s2_write,
		avs_s1_writedata	=> avs_s2_writedata,
		ins_s1_irq			=> ins_s2_irq,

		coe_gpucrtc_send	=> crtc_bus_rx_sig,
		coe_gpucrtc_recv	=> crtc_bus_tx_sig,

		coe_lcd_rst_n		=> coe_lcd_rst_n,
		coe_lcd_cs_n		=> coe_lcd_cs_n,
		coe_lcd_rs			=> coe_lcd_rs,
		coe_lcd_wr_n		=> coe_lcd_wr_n,
		coe_lcd_d			=> coe_lcd_d
	);



--==== SPUインスタンス ===============================================

	spu_bus_rx_sig(24 downto 1) <= (others=>'X');
	spu_bus_rx_sig(0) <= '0';



--==== メモリインスタンス ============================================

	mem_bus_rx_sig(0)			<= avs_s3_read  when avs_s3_chipselect= '1' else '0';
	mem_bus_rx_sig(1)			<= avs_s3_write when avs_s3_chipselect= '1' else '0';
	mem_bus_rx_sig(24 downto 2)	<= avs_s3_address(24 downto 2);
	mem_bus_rx_sig(25)			<= avs_s3_chipselect;
	mem_bus_rx_sig(29 downto 26)<= avs_s3_byteenable;
	mem_bus_rx_sig(61 downto 30)<= avs_s3_writedata;

	avs_s3_readdata				<= mem_bus_tx_sig(31 downto 0);
	avs_s3_waitrequest			<= not mem_bus_tx_sig(32);



end RTL;

