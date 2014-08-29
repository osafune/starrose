----------------------------------------------------------------------
-- TITLE : SuperJ-7 Rendering Register Block - Sub Program
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--     DATUM     : 2003/04/16 -> 2003/04/20 (HERSTELLUNG)
--               : 2003/04/22 (FESTSTELLUNG)
--               : 2003/06/23 
--               : 2003/08/11 テクスチャ指定をBASEアドレス方式に仕様変更
--               : 2004/03/01 描画指定をBASEアドレス方式に仕様変更
--               : 2004/03/19 CPUアクセス割り込みレジスタを追加
--               : 2004/04/18 セルレンダリングをテクスチャフラグに変更
--               : 2004/05/06 ディザリングフラグを追加 (NEUBEARBEITUNG)
--
--               : 2006/11/26 1chipMSX対応 (NEUBEARBEITUNG)
----------------------------------------------------------------------

-- SubAddress  Register Name          Rande (BitMuster)
--         0    RenderMode              15:IE 14:IF 13:CAE 10:DE 9:DT 8:ZE 7:BF 6:SE 5:TE 4-3:BMODE 2-1:RMODE 0:RE
--         1    RenderCount             8-0: 0 ～ 511
--         2    RenderBaseLine         13-0: 0 ～ 16383
--         3    RenderXoffset           8-0: 0 ～ 511
--         4    RenderLine              8-0: 0 ～ 511
--         5    LinefillXoffset         8-0: 0 ～ 511
--         6    LinefillLine           15:DA 14:SA 13-0: 0～16383
--         7    LineFillData           15-0: 0x0000 ～ 0xFFFF
--         8    ZbufferBaseLine        13-0: 0 ～ 16383
--         9    Depth_Z                29-4: -131072.00 ～ 131071.99
--         A    Depth_dZ               28-4: -65536.00 ～ +65535.99
--         B    TextureBaseLine        13-0: 0 ～ 16383
--         C    Texture_X              20-0: 0.000 ～ 511.999
--         D    Texture_dX             21-0: -512.000 ～ +511.999
--         E    Texture_Y              20-0: 0.000 ～ 511.999
--         F    Texture_dY             21-0: -512.000 ～ +511.999

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity REGISTER_Render is
	generic(
		RENDER_BASE			: string;
		TEXTUER_BASE		: string;
		ZBUFFER_MODE		: string;
		SHADING_MODE		: string;
		USE_MEGAFUNCTION	: string
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
		texture_y		: out std_logic_vector(25 downto 0);	-- 非レジスタ出力

		zbuffer_renew	: in  std_logic;
		zbuffer_depth	: out std_logic_vector(15 downto 0);
		zbuffer_base	: out std_logic_vector(13 downto 0);

		reg_select		: in  std_logic_vector(3 downto 0);
		reg_rddata		: out std_logic_vector(31 downto 0);	-- 非レジスタ出力
		reg_wrdata		: in  std_logic_vector(31 downto 0);
		reg_uwen		: in  std_logic;
		reg_lwen		: in  std_logic;
		gpu_status		: out std_logic_vector(15 downto 0)
	);
end REGISTER_Render;

architecture RTL of REGISTER_Render is
	signal wrdatau_sig		: std_logic_vector(31 downto 16);
	signal wrdatal_sig		: std_logic_vector(15 downto 0);
	signal rddatau_sig		: std_logic_vector(31 downto 16);
	signal rddatal_sig		: std_logic_vector(15 downto 0);
	signal rmode_sig		: std_logic_vector(15 downto 0);
	signal floffs_sig		: std_logic_vector(15 downto 0);

	signal render_ena_reg	: std_logic;
	signal fill_mode_reg	: std_logic_vector(1 downto 0);
	signal blend_mode_reg	: std_logic_vector(1 downto 0);
	signal texture_ena_reg	: std_logic;
	signal shading_ena_reg	: std_logic;
	signal dithering_ena_reg: std_logic;
	signal dither_type_reg	: std_logic;
	signal biliner_ena_reg	: std_logic;
	signal zbuffer_ena_reg	: std_logic;
	signal irq_ena_reg		: std_logic;
	signal render_irq_reg	: std_logic;
	signal cpuint_ena_reg	: std_logic;

	signal rboffs_reg		: std_logic_vector(13 downto 0);
	signal rcount_reg		: std_logic_vector(8 downto 0);
	signal rxoffs_reg		: std_logic_vector(8 downto 0);
	signal rloffs_reg		: std_logic_vector(8 downto 0);
	signal fxoffs_reg		: std_logic_vector(8 downto 0);
	signal floffs_reg		: std_logic_vector(13 downto 0);
	signal area_src_reg		: std_logic;
	signal area_dst_reg		: std_logic;
	signal filldata_reg		: std_logic_vector(15 downto 0);
	signal rendy_out_sig	: std_logic_vector(13 downto 0);

	signal tboffs_reg		: std_logic_vector(13 downto 0);
	signal texture_x_reg	: std_logic_vector(20 downto 0);
	signal texture_dx_reg	: std_logic_vector(21 downto 0);
	signal texture_y_reg	: std_logic_vector(20 downto 0);
	signal texture_dy_reg	: std_logic_vector(21 downto 0);
	signal texx_out_reg		: std_logic_vector(20 downto 0);
	signal texx_out_sig		: std_logic_vector(20 downto 0);
	signal texy_out_reg		: std_logic_vector(25 downto 0);
	signal texy_out_sig		: std_logic_vector(25 downto 0);
	signal texy_tmp_sig		: std_logic_vector(25 downto 0);

	signal zboffs_reg		: std_logic_vector(13 downto 0);
	signal zbuff_base_reg	: std_logic_vector(13 downto 0);
	signal zbuffer_z_reg	: std_logic_vector(29 downto 0);
	signal zbuffer_dz_reg	: std_logic_vector(29 downto 0);
	signal zbuff_sat_sig	: std_logic_vector(15 downto 0);
	signal zbuff_depth_reg	: std_logic_vector(15 downto 0);

	signal latch_mode_sig	: std_logic;
	signal latch_rcnt_sig	: std_logic;
	signal latch_rbo_sig	: std_logic;
	signal latch_rxo_sig	: std_logic;
	signal latch_rlo_sig	: std_logic;
	signal latch_fxo_sig	: std_logic;
	signal latch_flo_sig	: std_logic;
	signal latch_data_sig	: std_logic;
	signal latch_zbo_sig	: std_logic;
	signal latch_tbo_sig	: std_logic;
	signal latch_txu_sig	: std_logic;
	signal latch_txl_sig	: std_logic;
	signal latch_tdxu_sig	: std_logic;
	signal latch_tdxl_sig	: std_logic;
	signal latch_tyu_sig	: std_logic;
	signal latch_tyl_sig	: std_logic;
	signal latch_tdyu_sig	: std_logic;
	signal latch_tdyl_sig	: std_logic;
	signal latch_zu_sig		: std_logic;
	signal latch_zl_sig		: std_logic;
	signal latch_dzu_sig	: std_logic;
	signal latch_dzl_sig	: std_logic;
	signal latch_mzu_sig	: std_logic;
	signal latch_mzl_sig	: std_logic;

	signal exstex_x_sig		: std_logic_vector(31 downto 0);
	signal exstex_dx_sig	: std_logic_vector(31 downto 0);
	signal add_ansx_sig		: std_logic_vector(31 downto 0);
	signal exstex_y_sig		: std_logic_vector(31 downto 0);
	signal exstex_dy_sig	: std_logic_vector(31 downto 0);
	signal add_ansy_sig		: std_logic_vector(31 downto 0);
	signal exstex_z_sig		: std_logic_vector(31 downto 0);
	signal exstex_dz_sig	: std_logic_vector(31 downto 0);
	signal add_ansz_sig		: std_logic_vector(31 downto 0);

begin

--==== レジスタ読み出しセレクタ部 ====================================

	reg_rddata(31 downto 16) <= rddatau_sig;
	reg_rddata(15 downto 0)  <= rddatal_sig;

	gpu_status <= rmode_sig;

	with reg_select select rddatal_sig <=
			rmode_sig					when "0000",
		"0000000" & rcount_reg			when "0001",
		"00" & rboffs_reg				when "0010",
		"0000000" & rxoffs_reg			when "0011",
		"0000000" & rloffs_reg			when "0100",
		"0000000" & fxoffs_reg			when "0101",
			floffs_sig					when "0110",
			filldata_reg				when "0111",
		"00" & zboffs_reg				when "1000",
		exstex_z_sig(15 downto 0)		when "1001",
		exstex_dz_sig(15 downto 0)		when "1010",
		"00" & tboffs_reg				when "1011",
		texture_x_reg(15 downto 0)		when "1100",
		texture_dx_reg(15 downto 0)		when "1101",
		texture_y_reg(15 downto 0)		when "1110",
		texture_dx_reg(15 downto 0)		when "1111",
		(others=>'X')					when others;

	with reg_select select rddatau_sig <=
		exstex_z_sig(31 downto 16)					when "1001",
		exstex_dz_sig(31 downto 16)					when "1010",
		"00000000000" & texture_x_reg(20 downto 16)	when "1100",
		exstex_dx_sig(31 downto 16)					when "1101",
		"00000000000" & texture_y_reg(20 downto 16)	when "1110",
		exstex_dy_sig(31 downto 16)					when "1111",
			(others=>'0')							when others;


	wrdatau_sig <= reg_wrdata(31 downto 16);
	wrdatal_sig <= reg_wrdata(15 downto 0);



--==== コントロールレジスタ部 ========================================

	render_irq    <= render_irq_reg when irq_ena_reg='1' else '0';
	cpuint_ena    <= cpuint_ena_reg;

	render_ena    <= render_ena_reg;
	fill_mode     <= fill_mode_reg;
	blend_mode    <= blend_mode_reg;
	texture_ena   <= texture_ena_reg;
	shading_ena   <= shading_ena_reg;
	dithering_ena <= dithering_ena_reg;
	dithering_type<= dither_type_reg;
	biliner_ena   <= biliner_ena_reg;

	render_cyc    <= rcount_reg;
	render_x      <= rxoffs_reg;
	render_y      <= rendy_out_sig;
	linefill_x    <= fxoffs_reg;
	linefill_y    <= floffs_reg;
	line_sarea    <= area_src_reg;
	line_darea    <= area_dst_reg;
	filldata      <= filldata_reg;


	latch_mode_sig <= reg_lwen when reg_select="0000" else '0';
	latch_rcnt_sig <= reg_lwen when reg_select="0001" else '0';
	latch_rbo_sig  <= reg_lwen when reg_select="0010" else '0';
	latch_rxo_sig  <= reg_lwen when reg_select="0011" else '0';
	latch_rlo_sig  <= reg_lwen when reg_select="0100" else '0';
	latch_fxo_sig  <= reg_lwen when reg_select="0101" else '0';
	latch_flo_sig  <= reg_lwen when reg_select="0110" else '0';
	latch_data_sig <= reg_lwen when reg_select="0111" else '0';


	rmode_sig <= irq_ena_reg & render_irq_reg & cpuint_ena_reg & "00" &
					dithering_ena_reg & dither_type_reg & zbuffer_ena_reg &
					biliner_ena_reg & shading_ena_reg & texture_ena_reg &
					blend_mode_reg & fill_mode_reg & render_ena_reg;

	floffs_sig<= area_dst_reg & area_src_reg & floffs_reg;


	GEN_REND_BASE : if (RENDER_BASE="OFFSET") generate

		rendy_out_sig <= rboffs_reg +("00000" & rloffs_reg );

	end generate;
	GEN_REND_PAGE : if (RENDER_BASE/="OFFSET") generate

		rendy_out_sig <= rboffs_reg(13 downto 9) & rloffs_reg;

	end generate;


	GEN_ENA_ZBUFFER : if (ZBUFFER_MODE="NORMAL") generate

		zbuffer_ena <= zbuffer_ena_reg;

	end generate;
	GEN_DISENA_ZBUFFER : if (ZBUFFER_MODE/="NORMAL") generate

		zbuffer_ena <= '0';

	end generate;

	process (clk,reset) begin
		if (reset='1') then
			render_ena_reg <= '0';
			render_irq_reg <= '0';
			irq_ena_reg    <= '0';
			cpuint_ena_reg <= '0';

		elsif (clk'event and clk='1') then
			if (render_done='1') then
				render_ena_reg <= '0';
				render_irq_reg <= '1';
			elsif (latch_mode_sig='1') then
				render_ena_reg <= wrdatal_sig(0);
				if (wrdatal_sig(14)='0') then
					render_irq_reg <= '0';
				end if;
			end if;

			if (latch_mode_sig='1') then
				fill_mode_reg    <= wrdatal_sig(2 downto 1);
				blend_mode_reg   <= wrdatal_sig(4 downto 3);
				texture_ena_reg  <= wrdatal_sig(5);
				shading_ena_reg  <= wrdatal_sig(6);
				biliner_ena_reg  <= wrdatal_sig(7);
				zbuffer_ena_reg  <= wrdatal_sig(8);
				dither_type_reg  <= wrdatal_sig(9);
				dithering_ena_reg<= wrdatal_sig(10);
				cpuint_ena_reg   <= wrdatal_sig(13);
				irq_ena_reg      <= wrdatal_sig(15);
			end if;

			if (latch_rcnt_sig='1') then
				rcount_reg <= wrdatal_sig(8 downto 0);
			end if;

			if (latch_rbo_sig='1') then
				rboffs_reg <= wrdatal_sig(13 downto 0);
			end if;
			if (latch_rxo_sig='1') then
				rxoffs_reg <= wrdatal_sig(8 downto 0);
			end if;
			if (latch_rlo_sig='1') then
				rloffs_reg <= wrdatal_sig(8 downto 0);
			end if;

			if (latch_fxo_sig='1') then
				fxoffs_reg <= wrdatal_sig(8 downto 0);
			end if;
			if (latch_flo_sig='1') then
				floffs_reg  <= wrdatal_sig(13 downto 0);
				area_src_reg<= wrdatal_sig(14);
				area_dst_reg<= wrdatal_sig(15);
			end if;

			if (latch_data_sig='1') then
				filldata_reg <= wrdatal_sig;
			end if;

		end if;
	end process;



--==== テクスチャレジスタ部 ==========================================

	texture_x <= texture_x_reg;
	texture_y <= texy_out_sig;

	texy_tmp_sig <= "00000" & texture_y_reg;

	GEN_TEX_BASE : if (TEXTUER_BASE="OFFSET") generate

		texy_out_sig <= texy_tmp_sig +(tboffs_reg & "000000000000");

	end generate;
	GEN_TEX_PAGE : if (TEXTUER_BASE/="OFFSET") generate

		texy_out_sig <= tboffs_reg(13 downto 9) & texy_tmp_sig(20 downto 0);

	end generate;


	latch_tbo_sig  <= reg_lwen when reg_select="1011" else '0';
	latch_txu_sig  <= reg_uwen when reg_select="1100" else '0';
	latch_txl_sig  <= reg_lwen when reg_select="1100" else '0';
	latch_tdxu_sig <= reg_uwen when reg_select="1101" else '0';
	latch_tdxl_sig <= reg_lwen when reg_select="1101" else '0';
	latch_tyu_sig  <= reg_uwen when reg_select="1110" else '0';
	latch_tyl_sig  <= reg_lwen when reg_select="1110" else '0';
	latch_tdyu_sig <= reg_uwen when reg_select="1111" else '0';
	latch_tdyl_sig <= reg_lwen when reg_select="1111" else '0';

	exstex_x_sig(31 downto 21) <= (others=>'0');
	exstex_x_sig(20 downto 0)  <= texture_x_reg;
	exstex_dx_sig(31 downto 21)<= (others=>texture_dx_reg(21));
	exstex_dx_sig(20 downto 0) <= texture_dx_reg(20 downto 0);

	exstex_y_sig(31 downto 21)<= (others=>'0');
	exstex_y_sig(20 downto 0) <= texture_y_reg(20 downto 0);
	exstex_dy_sig(31 downto 21)<= (others=>texture_dy_reg(21));
	exstex_dy_sig(20 downto 0) <= texture_dy_reg(20 downto 0);

	add_ansx_sig <= exstex_x_sig + exstex_dx_sig;
	add_ansy_sig <= exstex_y_sig + exstex_dy_sig;


	process (clk) begin
		if (clk'event and clk='1') then

			if (latch_tbo_sig='1') then
				tboffs_reg <= wrdatal_sig(13 downto 0);
			end if;

			if (texture_renew='1') then
				texture_x_reg <= add_ansx_sig(20 downto 0);
			else
				if (latch_txu_sig='1') then
					texture_x_reg(20 downto 16)<= wrdatau_sig(20 downto 16);
				end if;
				if (latch_txl_sig='1') then
					texture_x_reg(15 downto 0) <= wrdatal_sig;
				end if;
			end if;
			if (latch_tdxu_sig='1') then
				texture_dx_reg(21 downto 16)<= wrdatau_sig(21 downto 16);
			end if;
			if (latch_tdxl_sig='1') then
				texture_dx_reg(15 downto 0) <= wrdatal_sig;
			end if;

			if (texture_renew='1') then
				texture_y_reg <= add_ansy_sig(20 downto 0);
			else
				if (latch_tyu_sig='1') then
					texture_y_reg(20 downto 16)<= wrdatau_sig(20 downto 16);
				end if;
				if (latch_tyl_sig='1') then
					texture_y_reg(15 downto 0) <= wrdatal_sig;
				end if;
			end if;
			if (latch_tdyu_sig='1') then
				texture_dy_reg(21 downto 16)<= wrdatau_sig(21 downto 16);
			end if;
			if (latch_tdyl_sig='1') then
				texture_dy_reg(15 downto 0) <= wrdatal_sig;
			end if;

		end if;
	end process;



--==== Ｚバッファレジスタ部 ==========================================

	GEN_USE_ZBUFF : if (ZBUFFER_MODE/="UNUSED") generate

		zbuffer_base  <= zbuff_base_reg;
		zbuffer_depth <= zbuff_depth_reg;

		latch_zbo_sig <= reg_lwen when reg_select="1000" else '0';
		latch_zu_sig  <= reg_uwen when reg_select="1001" else '0';
		latch_zl_sig  <= reg_lwen when reg_select="1001" else '0';
		latch_dzu_sig <= reg_uwen when reg_select="1010" else '0';
		latch_dzl_sig <= reg_lwen when reg_select="1010" else '0';

		exstex_z_sig(31 downto 29) <= (others=>zbuffer_z_reg(29));
		exstex_z_sig(28 downto 0)  <= zbuffer_z_reg(28 downto 4) & "0000";
		exstex_dz_sig(31 downto 29)<= (others=>zbuffer_dz_reg(29));
		exstex_dz_sig(28 downto 0) <= zbuffer_dz_reg(28 downto 4) & "0000";

		add_ansz_sig <= exstex_z_sig + exstex_dz_sig;

		with zbuffer_z_reg(29 downto 28) select zbuff_sat_sig <=
			zbuffer_z_reg(27 downto 12)	when "00",		-- case     0 >= Z >  65536
			(others=>'1')				when "01",		-- case 65536 >= Z > 131072
			(others=>'0')				when others;	-- case     0  < Z

		process (clk) begin
			if (clk'event and clk='1') then
				zbuff_depth_reg <= zbuff_sat_sig;
				zbuff_base_reg  <= zboffs_reg + ("00000" & rloffs_reg);

				if (latch_zbo_sig='1') then
					zboffs_reg <= wrdatal_sig(13 downto 0);
				end if;

				if (zbuffer_renew='1') then
					zbuffer_z_reg <= add_ansz_sig(29 downto 0);
				else
					if (latch_zu_sig='1') then
						zbuffer_z_reg(29 downto 16)<= wrdatau_sig(29 downto 16);
					end if;
					if (latch_zl_sig='1') then
						zbuffer_z_reg(15 downto 0)<= wrdatal_sig;
					end if;
				end if;
				if (latch_dzu_sig='1') then
					zbuffer_dz_reg(29 downto 16)<= wrdatau_sig(29 downto 16);
				end if;
				if (latch_dzl_sig='1') then
					zbuffer_dz_reg(15 downto 0) <= wrdatal_sig;
				end if;

			end if;
		end process;

	end generate;
	GEN_UNUSE_ZBUFF : if (ZBUFFER_MODE="UNUSED") generate

		zbuffer_base  <= (others=>'X');
		zbuffer_depth <= (others=>'X');

	end generate;


end RTL;



----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
