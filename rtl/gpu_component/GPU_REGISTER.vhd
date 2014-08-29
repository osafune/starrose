----------------------------------------------------------------------
-- TITLE : SuperJ-7 Register Processing Unit (AMETHYST Edition)
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--     DATUM     : 2003/04/22 -> 2003/04/27 (HERSTELLUNG)
--               : 2003/04/28 (FESTSTELLUNG)
--               : 2003/08/10 generic文でパラメータ化
--               : 2004/03/01 RENDERバッファのオフセットを追加・MIPMAPを削除
--               : 2004/03/19 CPUアクセス割り込みレジスタを追加
--               : 2004/04/18 セルレンダリング機能を削除
--               : 2004/05/06 ディザリングを追加 (NEUBEARBEITUNG)
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
--use work.SuperJ7_package.all;

entity GPU_REGISTER is
	generic(
		REGISTER_READ	: string :="ENABLE";
--		REGISTER_READ	: string :="DISENABLE";

		SHADING_MODE	: string :="GOURAUD";
--		SHADING_MODE	: string :="FLAT";

		RENDER_BASE		: string :="OFFSET";
--		RENDER_BASE		: string :="PAGE";

		TEXTUER_BASE	: string :="OFFSET";
--		TEXTUER_BASE	: string :="PAGE";

--		ZBUFFER_MODE	: string :="NORMAL"
--		ZBUFFER_MODE	: string :="PIXELBUFFER"
		ZBUFFER_MODE	: string :="UNUSED"
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
		reg_rddata		: out std_logic_vector(31 downto 0);	-- 非レジスタ出力(セレクタ出力)
		reg_wrdata		: in  std_logic_vector(31 downto 0);
		reg_uwen		: in  std_logic;
		reg_lwen		: in  std_logic
	);
end GPU_REGISTER;

architecture RTL of GPU_REGISTER is
	signal reg_rddata_sig	: std_logic_vector(31 downto 0);

	component REGISTER_Render
	generic(
		RENDER_BASE			: string;
		TEXTUER_BASE		: string;
		ZBUFFER_MODE		: string;
		SHADING_MODE		: string;
		USE_MEGAFUNCTION	: string := "ON"
	);
	port(
		clk				: in  std_logic;
		reset			: in  std_logic;
		render_irq		: out std_logic;
		cpuint_ena		: out std_logic;

		render_done		: in  std_logic;
		render_ena		: out std_logic;
		fill_mode		: out std_logic_vector(1 downto 0);
		blend_mode		: out std_logic_vector(1 downto 0);
		texture_ena		: out std_logic;
		shading_ena		: out std_logic;
		dithering_ena	: out std_logic;
		dithering_type	: out std_logic;
		biliner_ena		: out std_logic;
		zbuffer_ena		: out std_logic;

		render_cyc		: out std_logic_vector(8 downto 0);
		render_x		: out std_logic_vector(8 downto 0);
		render_y		: out std_logic_vector(13 downto 0);
		linefill_x		: out std_logic_vector(8 downto 0);
		linefill_y		: out std_logic_vector(13 downto 0);
		line_sarea		: out std_logic;
		line_darea		: out std_logic;
		filldata		: out std_logic_vector(15 downto 0);

		texture_renew	: in  std_logic;
		texture_x		: out std_logic_vector(20 downto 0);
		texture_y		: out std_logic_vector(25 downto 0);

		zbuffer_renew	: in  std_logic;
		zbuffer_depth	: out std_logic_vector(15 downto 0);
		zbuffer_base	: out std_logic_vector(13 downto 0);

		reg_select		: in  std_logic_vector(3 downto 0);
		reg_rddata		: out std_logic_vector(31 downto 0);
		reg_wrdata		: in  std_logic_vector(31 downto 0);
		reg_uwen		: in  std_logic;
		reg_lwen		: in  std_logic;
		gpu_status		: out std_logic_vector(15 downto 0)
	);
	end component;
	signal gpustatus_sig	: std_logic_vector(15 downto 0);
	signal render_ena_sig	: std_logic;
	signal shade_mode_sig	: std_logic;
	signal rr_select_sig	: std_logic_vector(3 downto 0);
	signal rr_rddata_sig	: std_logic_vector(31 downto 0);
	signal rr_uwen_sig		: std_logic;
	signal rr_lwen_sig		: std_logic;


	component REGISTER_Intensity
	generic(
		SHADING_MODE		: string;
		USE_MEGAFUNCTION	: string :="ON"
	);
	port(
		clk			: in  std_logic;
		reset		: in  std_logic;

		init		: in  std_logic;
		renew		: in  std_logic;

		intensity_r	: out std_logic_vector(12 downto 0);
		intensity_g	: out std_logic_vector(12 downto 0);
		intensity_b	: out std_logic_vector(12 downto 0);

		reg_select	: in  std_logic_vector(3 downto 0);
		reg_rddata	: out std_logic_vector(31 downto 0);
		reg_wrdata	: in  std_logic_vector(31 downto 0);
		reg_uwen	: in  std_logic;
		reg_lwen	: in  std_logic
	);
	end component;
	signal ri_select_sig	: std_logic_vector(3 downto 0);
	signal ri_rddata_sig	: std_logic_vector(31 downto 0);
	signal ri_uwen_sig		: std_logic;
	signal ri_lwen_sig		: std_logic;

begin

--==== アドレスセレクタ部 ============================================

	GEN_READENA : if (REGISTER_READ = "ENABLE") generate		-- レジスタデータリード有効

		reg_rddata <= reg_rddata_sig;

		with reg_select(4) select reg_rddata_sig <=
			rr_rddata_sig	when '0',		-- address 00～0F  REGISTER_Render reg
			ri_rddata_sig	when others;	-- address 10～1F  REGISTER_Intensity reg

	end generate;
	GEN_READDIS : if (REGISTER_READ /= "ENABLE") generate		-- レジスタデータリード無効

		reg_rddata(31 downto 16) <= (others=>'0');
		reg_rddata(15 downto 0)  <= gpustatus_sig;

	end generate;

	render_ena <= render_ena_sig;

	rr_uwen_sig <= reg_uwen when (reg_select(4)='0' and render_ena_sig='0') else
					'0';
	rr_lwen_sig <= reg_lwen when (reg_select(4)='0' and render_ena_sig='0') else
					'0';
	rr_select_sig <= reg_select(3 downto 0);

	ri_uwen_sig <= reg_uwen when (reg_select(4)='1' and render_ena_sig='0') else
					'0';
	ri_lwen_sig <= reg_lwen when (reg_select(4)='1' and render_ena_sig='0') else
					'0';
	ri_select_sig <= reg_select(3 downto 0);



--==== レンダリングレジスタ部 ========================================

	RR : REGISTER_Render 
	generic map(
		RENDER_BASE		=> RENDER_BASE,
		TEXTUER_BASE	=> TEXTUER_BASE,
		ZBUFFER_MODE	=> ZBUFFER_MODE,
		SHADING_MODE	=> SHADING_MODE
	)
	port map(
		clk				=> clk,
		reset			=> reset,
		render_irq		=> render_irq,
		cpuint_ena		=> cpuint_ena,

		render_done		=> render_done,
		render_ena		=> render_ena_sig,
		fill_mode		=> fill_mode,
		blend_mode		=> blend_mode,
		texture_ena		=> texture_ena,
		shading_ena		=> shading_ena,
		dithering_ena	=> dithering_ena,
		dithering_type	=> dithering_type,
		biliner_ena		=> biliner_ena,
		zbuffer_ena		=> zbuffer_ena,

		render_cyc		=> render_cyc,
		render_x		=> render_x,
		render_y		=> render_y,
		linefill_x		=> linefill_x,
		linefill_y		=> linefill_y,
		line_sarea		=> line_sarea,
		line_darea		=> line_darea,
		filldata		=> filldata,

		texture_renew	=> texture_renew,
		texture_x		=> texture_x,
		texture_y		=> texture_y,

		zbuffer_renew	=> zbuffer_renew,
		zbuffer_depth	=> zbuffer_depth,
		zbuffer_base	=> zbuffer_base,

		reg_select		=> rr_select_sig,
		reg_rddata		=> rr_rddata_sig,
		reg_wrdata		=> reg_wrdata,
		reg_uwen		=> rr_uwen_sig,
		reg_lwen		=> rr_lwen_sig,
		gpu_status		=> gpustatus_sig
	);



--==== 輝度レジスタ部 ================================================

	RI : REGISTER_Intensity 
	generic map(
		SHADING_MODE	=> SHADING_MODE
	)
	port map(
		clk				=> clk,
		reset			=> reset,

		init			=> register_init,
		renew			=> intensity_renew,

		intensity_r		=> intensity_r,
		intensity_g		=> intensity_g,
		intensity_b		=> intensity_b,

		reg_select		=> ri_select_sig,
		reg_rddata		=> ri_rddata_sig,
		reg_wrdata		=> reg_wrdata,
		reg_uwen		=> ri_uwen_sig,
		reg_lwen		=> ri_lwen_sig
	);



end RTL;


----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
