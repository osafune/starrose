----------------------------------------------------------------------
-- TITLE : PROCYON Graphic Processing Unit (AMETHYST Edition)
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--   ALTER DATUM : 2003/08/12 -> 2003/08/17 (HERSTELLUNG)
--               : 2003/08/24 (FESTSTELLUNG)
--               : 2004/03/01
--
--     DATUM     : 2004/03/09 -> 2004/03/13 (HERSTELLUNG)
--               : 2004/05/06 (FESTSTELLUNG)
--
--     DATUM     : 2006/10/09 -> 2006/11/01 (HERSTELLUNG)
--
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.SuperJ7_package.all;

entity PROCYON_GPU is
	generic(
		REGISTER_READ	: string :="ENABLE";
--		REGISTER_READ	: string :="DISENABLE";

		SHADING_MODE	: string :="GOURAUD";
--		SHADING_MODE	: string :="FLAT";

		RENDER_BASE		: string :="OFFSET";
--		RENDER_BASE		: string :="PAGE";

		TEXTUER_BASE	: string :="OFFSET"
--		TEXTUER_BASE	: string :="PAGE"
	);
	port(
		clk				: in  std_logic;
		reset			: in  std_logic;

	----- SDRAMインターフェース (※必ずIOEブロックのレジスタを使うこと) -----
		sdr_addr		: out std_logic_vector(12 downto 0);
		sdr_bank		: out std_logic_vector(1 downto 0);
		sdr_cke			: out std_logic;
		sdr_cs			: out std_logic;
		sdr_ras			: out std_logic;
		sdr_cas			: out std_logic;
		sdr_we			: out std_logic;
		sdr_data		: inout std_logic_vector(15 downto 0);
		sdr_dqm			: out std_logic_vector(1 downto 0);

	----- 外部アクセスポート (CRTC,PCM,CPUリードライト) -----
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

	----- 内部レジスタインターフェース -----
		render_irq		: out std_logic;
		reg_select		: in  std_logic_vector(4 downto 0);
		reg_rddata		: out std_logic_vector(31 downto 0);	-- 非レジスタ出力(セレクタ出力)
		reg_wrdata		: in  std_logic_vector(31 downto 0);
		reg_uwen		: in  std_logic;
		reg_lwen		: in  std_logic
	);
end PROCYON_GPU;

architecture RTL of PROCYON_GPU is
	signal render_state_reg	: std_logic;
	signal filldqm_reg		: std_logic_vector(3 downto 0);

-- シーケンスユニットのコンポーネント宣言とシグナル宣言
--
	component SEQUENCER_UNIT
	port(
		clk				: in  std_logic;
		reset			: in  std_logic;

		----- 外部割り込みスレーブ信号 -----------
		crtcread_addr	: in  std_logic_vector(24 downto 1)	:=(others=>'X');
		crtcread_req	: in  std_logic						:='0';
		crtcread_dena	: out std_logic;
		crtcread_data	: out std_logic_vector(15 downto 0);

		pcmread_addr	: in  std_logic_vector(24 downto 1)	:=(others=>'X');
		pcmread_req		: in  std_logic						:='0';
		pcmread_dena	: out std_logic;
		pcmread_data	: out std_logic_vector(15 downto 0);

		cpuint_ena		: in  std_logic;
		cpu_req			: in  std_logic;
		cpu_done		: out std_logic;
		cpu_address		: in  std_logic_vector(24 downto 2);
		cpu_read		: in  std_logic;
		cpu_rddata		: out std_logic_vector(31 downto 0);
		cpu_write		: in  std_logic;
		cpu_wrdata		: in  std_logic_vector(31 downto 0);
		cpu_byteenable	: in  std_logic_vector(3 downto 0);

		----- SDRAMデータ信号 -----------
		sdr_rddata_ena	: in  std_logic;
		sdr_rddata		: in  std_logic_vector(15 downto 0);
		ext_address		: out std_logic_vector(24 downto 1);
		ext_wrdata		: out std_logic_vector(15 downto 0);
		ext_wrdqm		: out std_logic_vector(1 downto 0);

		sdramif_rinc	: out std_logic;
		sdramif_cinc	: out std_logic;
		sdramif_cmd		: out std_logic_vector(3 downto 0);
		sdr_wrdata_req	: out std_logic;

		----- レンダリングエンジン制御信号 -----------
		render_adsel	: out std_logic_vector(1 downto 0);
		render_rinitsel	: out std_logic_vector(2 downto 0);
		render_cmd		: out std_logic_vector(3 downto 0);

		register_init	: out std_logic;
		render_cyc1st	: out std_logic;
		render_cyclast	: out std_logic;
		register_renew	: out std_logic;
		texture_renew	: out std_logic;
		texture_latch	: out std_logic;
		zbuffer_renew	: out std_logic;

		reg_renderena	: in  std_logic;
		reg_rmode		: in  std_logic_vector(1 downto 0);
		reg_zbuffena	: in  std_logic						:='0';
		reg_rcount		: in  std_logic_vector(8 downto 0);
		render_done		: out std_logic;
		zbuff_stp_ena	: out std_logic
	);
	end component;
	signal extaddress_sig	: std_logic_vector(24 downto 1);
	signal extwrdata_sig	: std_logic_vector(15 downto 0);
	signal extwrdqm_sig		: std_logic_vector(1 downto 0);
	signal sdram_rinc_sig	: std_logic;
	signal sdram_cinc_sig	: std_logic;
	signal sdram_cmd_sig	: std_logic_vector(3 downto 0);
	signal sdr_writereq_sig	: std_logic;

	signal rend_adsel_sig	: std_logic_vector(1 downto 0);
	signal rend_rinitsel_sig: std_logic_vector(2 downto 0);
	signal rend_cmd_sig		: std_logic_vector(3 downto 0);
	signal reg_init_sig		: std_logic;
	signal rend_cyc1st_sig	: std_logic;
	signal rend_cyclast_sig	: std_logic;
	signal reg_renew_sig	: std_logic;
	signal tex_renew_sig	: std_logic;
	signal tex_latch_sig	: std_logic;

	signal render_done_sig	: std_logic;

	signal test_cpureq_reg	: std_logic;
	signal test_cpudone_sig	: std_logic;
	signal test_cpudone_reg	: std_logic;
	signal test_cpuaddr_reg	: std_logic_vector(24 downto 2);
	signal test_cpuread_reg	: std_logic;
	signal test_cpurdata_sig: std_logic_vector(31 downto 0);
	signal test_cpurdata_reg: std_logic_vector(31 downto 0);
	signal test_cpuwrite_reg: std_logic;
	signal test_cpuwdata_reg: std_logic_vector(31 downto 0);
	signal test_cpubena_reg	: std_logic_vector(3 downto 0);


-- SDRAMインターフェースユニットのコンポーネント宣言とシグナル宣言
--
	component SDRAM_IF
	generic(
		WRITEBURST	: string;
		CASLATENCY	: string;
		BURSTTYPE	: string;
		BURSTLENGTH	: string
	);
	port(
		clk			: in  std_logic;
		sdr_init	: in  std_logic;

		sdr_cmd_in	: in  std_logic_vector(3 downto 0);
		sel_col_inc	: in  std_logic;
		sel_row_inc	: in  std_logic;

		address		: in  std_logic_vector(24 downto 1);
		readdata	: out std_logic_vector(15 downto 0);
		writedata	: in  std_logic_vector(15 downto 0);
		writedqm	: in  std_logic_vector(1 downto 0);
		read_ena	: out std_logic;
		write_done	: out std_logic;
		write_req	: out std_logic;

		sdr_addr	: out std_logic_vector(12 downto 0);
		sdr_bank	: out std_logic_vector(1 downto 0);
		sdr_cke		: out std_logic;
		sdr_cs		: out std_logic;
		sdr_ras		: out std_logic;
		sdr_cas		: out std_logic;
		sdr_we		: out std_logic;
		sdr_data	: inout std_logic_vector(15 downto 0);
		sdr_dqm		: out std_logic_vector(1 downto 0)
	);
	end component;
	signal sdr_address_sig	: std_logic_vector(24 downto 1);
	signal sdr_rddata_sig	: std_logic_vector(15 downto 0);
	signal sdr_wrdata_sig	: std_logic_vector(15 downto 0);
	signal sdr_wrdqm_sig	: std_logic_vector(1 downto 0);
	signal sdr_readena_sig	: std_logic;


-- レジスタユニットのコンポーネント宣言とシグナル宣言
--
	component GPU_REGISTER
	generic(
		REGISTER_READ	: string;
		SHADING_MODE	: string;
		RENDER_BASE		: string;
		TEXTUER_BASE	: string;
		ZBUFFER_MODE	: string
	);
	port(
		clk				: in  std_logic;
		reset			: in  std_logic;
		register_init	: in  std_logic;

		render_ena		: out std_logic;
		render_done		: in  std_logic;
		fill_mode		: out std_logic_vector(1 downto 0);
		render_cyc		: out std_logic_vector(8 downto 0);
		cpuint_ena		: out std_logic;

		blend_mode		: out std_logic_vector(1 downto 0);
		render_x		: out std_logic_vector(8 downto 0);
		render_y		: out std_logic_vector(13 downto 0);	-- 非レジスタ出力(加算機出力)
		linefill_x		: out std_logic_vector(8 downto 0);
		linefill_y		: out std_logic_vector(13 downto 0);
		line_sarea		: out std_logic;
		line_darea		: out std_logic;
		filldata		: out std_logic_vector(15 downto 0);

		biliner_ena		: out std_logic;
		texture_ena		: out std_logic;
		texture_renew	: in  std_logic :='0';
		texture_x		: out std_logic_vector(20 downto 0);
		texture_y		: out std_logic_vector(25 downto 0);	-- 非レジスタ出力(加算機出力)

		zbuffer_ena		: out std_logic;
		zbuffer_renew	: in  std_logic :='0';
		zbuffer_depth	: out std_logic_vector(15 downto 0);
		zbuffer_base	: out std_logic_vector(13 downto 0);

		shading_ena		: out std_logic;
		dithering_ena	: out std_logic;
		dithering_type	: out std_logic;
		intensity_renew	: in  std_logic :='0';
		intensity_r		: out std_logic_vector(12 downto 0);
		intensity_g		: out std_logic_vector(12 downto 0);
		intensity_b		: out std_logic_vector(12 downto 0);

		render_irq		: out std_logic;
		reg_select		: in  std_logic_vector(4 downto 0);
		reg_rddata		: out std_logic_vector(31 downto 0);
		reg_wrdata		: in  std_logic_vector(31 downto 0);	-- 非レジスタ出力(セレクタ出力)
		reg_uwen		: in  std_logic;
		reg_lwen		: in  std_logic
	);
	end component;
	signal cpuint_ena_sig	: std_logic;
	signal render_ena_sig	: std_logic;
	signal fillmode_sig		: std_logic_vector(1 downto 0);
	signal render_cyc_sig	: std_logic_vector(8 downto 0);
	signal render_cyc_dec	: std_logic_vector(8 downto 0);
	signal reg_rcount_sig	: std_logic_vector(8 downto 0);

	signal blend_mode_sig	: std_logic_vector(1 downto 0);
	signal render_x_sig		: std_logic_vector(8 downto 0);
	signal render_y_sig		: std_logic_vector(13 downto 0);
	signal filldata_sig		: std_logic_vector(15 downto 0);

	signal biliner_ena_sig	: std_logic;
	signal texture_ena_sig	: std_logic;
	signal texrenew_sig		: std_logic;
	signal texture_x_sig	: std_logic_vector(20 downto 0);
	signal texture_y_sig	: std_logic_vector(25 downto 0);

	signal shading_ena_sig	: std_logic;
	signal dithering_ena_sig: std_logic;
	signal dither_type_sig	: std_logic;
	signal intenrenew_sig	: std_logic;
	signal intensity_r_sig	: std_logic_vector(12 downto 0);
	signal intensity_g_sig	: std_logic_vector(12 downto 0);
	signal intensity_b_sig	: std_logic_vector(12 downto 0);


-- レンダリングユニットのコンポーネント宣言とシグナル宣言
--

	component RENDER_CORE
	port(
		clk				: in  std_logic;
		reset			: in  std_logic;

		addr_render1	: out std_logic_vector(24 downto 1);
		addr_render2	: out std_logic_vector(24 downto 1);
		addr_texture	: out std_logic_vector(24 downto 1);
		data_render		: out std_logic_vector(15 downto 0);
		dqm_render		: out std_logic_vector(1 downto 0);
		select_data		: out std_logic_vector(1 downto 0);

		sdr_read_data	: in  std_logic_vector(15 downto 0);

		render_mode		: in  std_logic_vector(1 downto 0);
		render_cmd		: in  std_logic_vector(3 downto 0);

		register_init	: in  std_logic;
		cyc1st_flag		: in  std_logic;

		coladdr_renew	: in  std_logic;
		render_x		: in  std_logic_vector(8 downto 0);
		render_y		: in  std_logic_vector(13 downto 0);

		biliner_ena		: in  std_logic :='0';
		texture_ena		: in  std_logic :='1';
		texture_renew	: in  std_logic;
		texture_x		: in  std_logic_vector(20 downto 0);
		texture_y		: in  std_logic_vector(25 downto 0);
		pixel_color		: in  std_logic_vector(15 downto 0) := (others=>'X');

		shading_ena		: in  std_logic :='0';
		dithering_ena	: in  std_logic :='0';
		dithering_type	: in  std_logic :='0';
		intensity_renew	: in  std_logic;
		intensity_r		: in  std_logic_vector(12 downto 0);
		intensity_g		: in  std_logic_vector(12 downto 0);
		intensity_b		: in  std_logic_vector(12 downto 0)
	);
	end component;
	signal addr_render1_sig	: std_logic_vector(24 downto 1);
	signal addr_render2_sig	: std_logic_vector(24 downto 1);
	signal addr_texture_sig	: std_logic_vector(24 downto 1);
	signal data_render_sig	: std_logic_vector(15 downto 0);
	signal dqm_render_sig	: std_logic_vector(1 downto 0);
	signal select_data_sig	: std_logic_vector(1 downto 0);
	signal render_x_init	: std_logic_vector(8 downto 0);
	signal render_y_init	: std_logic_vector(13 downto 0);

begin


--==== シーケンスユニット ============================================

	U0 : SEQUENCER_UNIT
	port map(
		clk				=> clk,
		reset			=> reset,

		crtcread_addr	=> crtcread_addr,
		crtcread_req	=> crtcread_req,
		crtcread_dena	=> crtcread_dena,
		crtcread_data	=> crtcread_data,

		pcmread_addr	=> pcmread_addr,
		pcmread_req		=> pcmread_req,
		pcmread_dena	=> pcmread_dena,
		pcmread_data	=> pcmread_data,

		cpuint_ena		=> cpuint_ena_sig,
		cpu_req			=> cpu_req,
		cpu_done		=> cpu_done,
		cpu_address		=> cpu_address,
		cpu_read		=> cpu_read,
		cpu_rddata		=> cpu_rddata,
		cpu_write		=> cpu_write,
		cpu_wrdata		=> cpu_wrdata,
		cpu_byteenable	=> cpu_byteenable,

		sdr_rddata_ena	=> sdr_readena_sig,
		sdr_rddata		=> sdr_rddata_sig,
		ext_address		=> extaddress_sig,
		ext_wrdata		=> extwrdata_sig,
		ext_wrdqm		=> extwrdqm_sig,

		sdramif_rinc	=> sdram_rinc_sig,
		sdramif_cinc	=> sdram_cinc_sig,
		sdramif_cmd		=> sdram_cmd_sig,
		sdr_wrdata_req	=> open,

		render_adsel	=> rend_adsel_sig,
		render_rinitsel	=> rend_rinitsel_sig,
		render_cmd		=> rend_cmd_sig,

		register_init	=> reg_init_sig,
		render_cyc1st	=> rend_cyc1st_sig,
		render_cyclast	=> open,
		register_renew	=> reg_renew_sig,
		texture_renew	=> tex_renew_sig,
		texture_latch	=> tex_latch_sig,

		reg_renderena	=> render_ena_sig,
		reg_rmode		=> fillmode_sig,
		reg_rcount		=> render_cyc_sig,
		render_done		=> render_done_sig
	);

	process (clk) begin
		if (clk'event and clk='1') then
			if (reg_init_sig='1') then
				if (rend_rinitsel_sig=RENDER) then
					render_state_reg <= '1';
				else
					render_state_reg <= '0';
				end if;
			end if;
		end if;
	end process;


	----- 32bitバーストアクセス時のサイクル処理 -----
--											-- サイクル数を半分にする(32bitアライン補正込み)
--	reg_rcount_sig <= ('1' & render_cyc_dec(8 downto 1)) when(fillmode_sig(1)='0' and render_x_sig(0)='1')
--				else  ('1' & render_cyc_sig(8 downto 1)) when(fillmode_sig(1)='0' and render_x_sig(0)='0')
--				else  render_cyc_sig;
--	render_cyc_dec <= render_cyc_sig - 1;
--
--	process (clk) begin						-- 書き込みマスク生成
--		if (clk'event and clk='1') then
--			if (rend_cyclast_sig='1' and render_x_sig(0)/=render_cyc_sig(0)) then
--				filldqm_reg <= "1100";
--			elsif (rend_cyc1st_sig='1' and render_x_sig(0)='1') then
--				filldqm_reg <= "0011";
--			else
--				filldqm_reg <= "0000";
--			end if;
--		end if;
--	end process;



--==== SDRAMインターフェース =========================================

	U1 : SDRAM_IF
	generic map(
		WRITEBURST		=> "BURST",
		CASLATENCY		=> "CL2",
		BURSTTYPE		=> "SEQUENTIAL",
		BURSTLENGTH		=> "1"
	)
	port map(
		clk				=> clk,
		sdr_init		=> reset,

		sdr_cmd_in		=> sdram_cmd_sig,
		sel_col_inc		=> sdram_cinc_sig,
		sel_row_inc		=> sdram_rinc_sig,

		address			=> sdr_address_sig,
		readdata		=> sdr_rddata_sig,
		writedata		=> sdr_wrdata_sig,
		writedqm		=> sdr_wrdqm_sig,
		read_ena		=> sdr_readena_sig,

		sdr_addr		=> sdr_addr,
		sdr_bank		=> sdr_bank,
		sdr_cke			=> sdr_cke,
		sdr_cs			=> sdr_cs,
		sdr_ras			=> sdr_ras,
		sdr_cas			=> sdr_cas,
		sdr_we			=> sdr_we,
		sdr_data		=> sdr_data,
		sdr_dqm			=> sdr_dqm
	);

	with rend_adsel_sig select sdr_address_sig <=
		addr_texture_sig	when ADR_TEX,		-- テクスチャアドレス選択
		addr_render1_sig	when ADR_VRM,		-- レンダリングアドレス選択
		addr_render2_sig	when ADR_ALT,		-- レンダリングアドレス(1回前)選択
		extaddress_sig		when others;		-- 外部入力アドレス選択

	with select_data_sig select sdr_wrdata_sig <=
		data_render_sig		when "00",
		(others=>'X')		when "01",
		filldata_sig		when "10",
		extwrdata_sig		when others;

	with select_data_sig select sdr_wrdqm_sig <=
		dqm_render_sig		when "00",
		(others=>'1')		when "01",
		(others=>'0')		when "10",
		extwrdqm_sig		when others;



--==== レジスタユニット ==============================================

	U2 : GPU_REGISTER
	generic map(
		REGISTER_READ	=> REGISTER_READ,
		SHADING_MODE	=> SHADING_MODE,
		RENDER_BASE		=> RENDER_BASE,
		TEXTUER_BASE	=> TEXTUER_BASE,
		ZBUFFER_MODE	=> "UNUSED"
	)
	port map(
		clk				=> clk,
		reset			=> reset,
		register_init	=> reg_init_sig,

		render_ena		=> render_ena_sig,
		render_done		=> render_done_sig,
		fill_mode		=> fillmode_sig,
		render_cyc		=> render_cyc_sig,
		cpuint_ena		=> cpuint_ena_sig,

		blend_mode		=> blend_mode_sig,
		render_x		=> render_x_sig,
		render_y		=> render_y_sig,
		filldata		=> filldata_sig,

		biliner_ena		=> biliner_ena_sig,
		texture_ena		=> texture_ena_sig,
		texture_renew	=> texrenew_sig,
		texture_x		=> texture_x_sig,
		texture_y		=> texture_y_sig,

		shading_ena		=> shading_ena_sig,
		dithering_ena	=> dithering_ena_sig,
		dithering_type	=> dither_type_sig,
		intensity_renew	=> intenrenew_sig,
		intensity_r		=> intensity_r_sig,
		intensity_g		=> intensity_g_sig,
		intensity_b		=> intensity_b_sig,

		render_irq		=> render_irq,
		reg_select		=> reg_select,
		reg_rddata		=> reg_rddata,
		reg_wrdata		=> reg_wrdata,
		reg_uwen		=> reg_uwen,
		reg_lwen		=> reg_lwen
	);

	texrenew_sig  <= tex_renew_sig   when render_state_reg='1' else '0';
	intenrenew_sig<= reg_renew_sig   when render_state_reg='1' else '0';



--==== レンダリングユニット ==========================================

	U3 : RENDER_CORE
	port map(
		clk				=> clk,
		reset			=> reset,

		addr_render1	=> addr_render1_sig,
		addr_render2	=> addr_render2_sig,
		addr_texture	=> addr_texture_sig,
		data_render		=> data_render_sig,
		dqm_render		=> dqm_render_sig,
		select_data		=> select_data_sig,

		sdr_read_data	=> sdr_rddata_sig,

		render_mode		=> blend_mode_sig,
		render_cmd		=> rend_cmd_sig,

		register_init	=> reg_init_sig,
		cyc1st_flag		=> rend_cyc1st_sig,

		coladdr_renew	=> reg_renew_sig,
		render_x		=> render_x_sig,
		render_y		=> render_y_sig,

		biliner_ena		=> biliner_ena_sig,
		texture_ena		=> texture_ena_sig,
		texture_renew	=> tex_latch_sig,
		texture_x		=> texture_x_sig,
		texture_y		=> texture_y_sig,
		pixel_color		=> filldata_sig,

		shading_ena		=> shading_ena_sig,
		dithering_ena	=> dithering_ena_sig,
		dithering_type	=> dither_type_sig,
		intensity_renew	=> reg_renew_sig,
		intensity_r		=> intensity_r_sig,
		intensity_g		=> intensity_g_sig,
		intensity_b		=> intensity_b_sig
	);


end RTL;



----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
