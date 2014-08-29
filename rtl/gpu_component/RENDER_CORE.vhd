----------------------------------------------------------------------
-- TITLE : SuperJ-7 Rendering Processing Unit (AMETHYST Edition)
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--   ALTER DATUM : 2003/03/30 -> 2003/04/22 (HERSTELLUNG)
--               : 2003/05/05 (FESTSTELLUNG)
--               : 2003/06/04 アドレスセレクタを上位階層へ移動
--               : 2003/07/31 データセレクタを上位階層へ移動
--               : 2003/08/12 generic文でパラメータ化
--               : 2003/08/13 輝度レジスタの読み込み時に飽和させるようにした (NEUBEARBEITUNG)
--
--     DATUM     : 2004/03/07 -> 2004/03/12 (HERSTELLUNG)
--               : 2004/04/18 単色シェーディングに対応 
--               : 2004/05/06 ディザリング実装 (NEUBEARBEITUNG)
--
--     DATUM     : 2006/10/07 -> 2006/11/26 (HERSTELLUNG) 1chipMSX対応 
--               : 2006/10/07 誤差拡散ディザリング削除
--               : 2006/11/26 16bit化 (NEUBEARBEITUNG)
--
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use work.SuperJ7_package.all;

entity RENDER_CORE is
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
		pixel_color		: in  std_logic_vector(15 downto 0) :=(others=>'X');

		shading_ena		: in  std_logic :='0';
		dithering_ena	: in  std_logic :='0';
		dithering_type	: in  std_logic :='0';
		intensity_renew	: in  std_logic;
		intensity_r		: in  std_logic_vector(12 downto 0);
		intensity_g		: in  std_logic_vector(12 downto 0);
		intensity_b		: in  std_logic_vector(12 downto 0)
	);
end RENDER_CORE;

architecture RTL of RENDER_CORE is

	signal render_x_reg		: std_logic_vector(8 downto 0);
	signal render_x_alt		: std_logic_vector(8 downto 0);
	signal render_y_reg		: std_logic_vector(13 downto 0);

	signal command_reg		: std_logic_vector(3 downto 0);
	signal render_cmd_sig	: std_logic_vector(16 downto 0);
	signal pause_reg		: std_logic;
	signal sel_dout_reg		: std_logic_vector(1 downto 0);
	signal sel_din0_reg		: std_logic;
	signal sel_din1_reg		: std_logic;
	signal sel_mul_reg		: std_logic;
	signal sel_vrm_reg		: std_logic;
	signal latch_vrm_reg	: std_logic;
	signal latch_zf_reg		: std_logic;
	signal latch_pix_reg	: std_logic;
	signal latch_out_reg	: std_logic;
	signal sel_tex_reg		: std_logic;
	signal sel_inv_reg		: std_logic;
	signal latch_stp_reg	: std_logic;

	signal latch_sdrv_reg	: std_logic;
	signal latch_sdrp_reg	: std_logic;
	signal sel_hpix_reg		: std_logic;
	signal sdr_pixel_reg	: std_logic_vector(15 downto 0);
	signal sdr_vram_sig		: std_logic_vector(15 downto 0);
	signal sdr_data_sig		: std_logic_vector(15 downto 0);

	signal dqm_out_reg		: std_logic;

	component RENDER_Texture
	port(
		clk				: in  std_logic;
		reset			: in  std_logic;
		render_mode		: in  std_logic_vector(1 downto 0);

		cmd_pause		: in  std_logic;
		cmd_sel_din0	: in  std_logic;
		cmd_sel_din1	: in  std_logic;
		cmd_sel_mul		: in  std_logic;
		cmd_sel_vrm		: in  std_logic;
		cmd_latch_vrm	: in  std_logic;
		cmd_latch_zf	: in  std_logic;
		cmd_latch_pix	: in  std_logic;
		cmd_latch_out	: in  std_logic;
		cmd_sel_tex		: in  std_logic;
		cmd_sel_inv		: in  std_logic;
		cmd_latch_stp	: in  std_logic;

		tex_x_ref		: in  std_logic_vector(4 downto 0);
		tex_y_ref		: in  std_logic_vector(4 downto 0);
		inten_r_ref		: in  std_logic_vector(5 downto 0);
		inten_g_ref		: in  std_logic_vector(5 downto 0);
		inten_b_ref		: in  std_logic_vector(5 downto 0);
		dither_ref		: in  std_logic_vector(5 downto 0);

		vram_din		: in  std_logic_vector(15 downto 0);
		pixel_din		: in  std_logic_vector(15 downto 0);
		pixel_dout		: out std_logic_vector(15 downto 0);
		pixel_wen		: out std_logic		-- 非レジスタ出力
	);
	end component;
	signal inten_r_reg		: std_logic_vector(5 downto 0);
	signal inten_g_reg		: std_logic_vector(5 downto 0);
	signal inten_b_reg		: std_logic_vector(5 downto 0);
	signal tex_x_reg		: std_logic_vector(4 downto 0);
	signal tex_y_reg		: std_logic_vector(4 downto 0);
	signal texdata_wen		: std_logic;
	signal data_wen_sig		: std_logic;
	signal render_mode_sig	: std_logic_vector(1 downto 0);
	signal texture_data		: std_logic_vector(15 downto 0);
	signal texture_dqm		: std_logic_vector(1 downto 0);
	signal biliner_ena_reg	: std_logic;
	signal shading_ena_reg	: std_logic;
	signal dithering_ena_reg: std_logic;
	signal dither_ref_reg	: std_logic_vector(5 downto 0);
	signal dither_ref_sig	: std_logic_vector(5 downto 0);

begin

--==== アドレス生成部 ================================================
--
-- addr_render1はレンダリング時にVRAMのリードアドレスを出力する。
-- addr_render2はレンダリング時にVRAMのライトアドレスを出力するのみ。
-- addr_textureはレンダリング時にテクスチャリードアドレスを出力する。

	addr_render1 <= '1' & render_y_reg & render_x_reg;
	addr_render2 <= '1' & render_y_reg & render_x_alt;
	addr_texture <= '0' & texture_y(25 downto 12) & texture_x(19 downto 12) & '0';

	process (clk) begin
		if (clk'event and clk='1') then

			if (register_init='1') then
				render_x_reg <= render_x;
				render_y_reg <= render_y;

			elsif (coladdr_renew='1') then
				render_x_reg <= render_x_reg + 1;
				render_x_alt <= render_x_reg;
			end if;

		end if;
	end process;

	--	ディザリングパターン生成 
	dither_ref_sig(5) <= render_x_alt(0) xor render_y_reg(0);
	dither_ref_sig(4) <= render_x_alt(1) xor render_y_reg(5);
	dither_ref_sig(3) <= render_x_alt(2) xor render_y_reg(1);
	dither_ref_sig(2) <= render_x_alt(3) xor render_y_reg(4);
	dither_ref_sig(1) <= render_x_alt(4) xor render_y_reg(3);
	dither_ref_sig(0) <= render_x_alt(5) xor render_y_reg(2);


--==== レンダリングコマンドデコーダ部 ================================

	select_data  <= sel_dout_reg;

	with command_reg select render_cmd_sig <=
	--                         bit  Nodename
	--   +-------------------- 16 pause
	--   |+---------------- 15-14 select_dout (00:Render / 01:Z-buffer / 10:Linefill / 11:ExtData)
	--   ||      +---------------- 13 select_din0   X X_X 1 1 1 1 0 X  ‥‥
	--   ||      |+--------------- 12 select_din1   0 X_0 X 1 1 1 1 1  ‥‥
	--   ||      ||+-------------- 11 select_mul    1 X_0 X 1 1 1 1 1  ‥‥
	--   ||      |||+------------- 10 select_vram   X 0_X 1 X X 0 X 0  ‥‥
	--   ||      ||||+------------  9 latch_vram    0 0_0 0 0 0 0 1 0  ‥‥
	--   ||      |||||+-----------  8 latch_zf      0 0_0 1 0 0 0 0 0  ‥‥
	--   ||      ||||||+----------  7 latch_pix     0 0_0 0 1 0 0 0 0  ‥‥
	--   ||      |||||||+---------  6 latch_out     0 0_0 0 0 1 0 0 0  ‥‥
	--   ||      ||||||||+--------  5 sel_tex_xy    1 X_X X 0 0 0 0 1  ‥‥
	--   ||      |||||||||+-------  4 sel_tex_inv   0 X_X X 1 0 1 0 1  ‥‥
	--   ||      ||||||||||+------  3 latch_stp     0 0_0 0 0 0 0 1 0  ‥‥
	--   ||      |||||||||||     +----  2 latch_sdrvram
	--   |++     |||||||||||     |+---  1 latch_Hpixel
	--   |||     |||||||||||     ||+--  0 select_Hpixel
		"000" & "X01X0000100" & "00X"	when CYCLE1,--"0000",	-- Render Cycle-1
		"000" & "XXX00000XX0" & "00X"	when CYCLE2,--"0001",	-- Render Cycle-2
		"000" & "X00X0000XX0" & "00X"	when CYCLE3,--"0010",	-- Render Cycle-3
		"000" & "1XX10100XX0" & "010"	when CYCLE4,--"0011",	-- Render Cycle-4
		"000" & "111X0010010" & "101"	when CYCLE5,--"0100",	-- Render Cycle-5
		"000" & "111X0001000" & "010"	when CYCLE6,--"0101",	-- Render Cycle-6
		"000" & "11100000010" & "001"	when CYCLE7,--"0110",	-- Render Cycle-7
		"000" & "011X1000001" & "00X"	when CYCLE8,--"0111",	-- Render Cycle-8
		"000" & "X1100000110" & "00X"	when CYCLE9,--"1000",	-- Render Cycle-9

		"010" & "XXXXXXXXXXX" & "00X"	when LFILL,--"1011",	-- Linefill

		"111" & "XXXXXXXXXXX" & "00X"	when others;	-- Pause


	process (clk) begin
		if (clk'event and clk='1') then
			command_reg   <= render_cmd;

			pause_reg     <= render_cmd_sig(16);
			sel_dout_reg  <= render_cmd_sig(15 downto 14);

			sel_din0_reg  <= render_cmd_sig(13);
			sel_din1_reg  <= render_cmd_sig(12);
			sel_mul_reg   <= render_cmd_sig(11);
			sel_vrm_reg   <= render_cmd_sig(10);
			latch_vrm_reg <= render_cmd_sig(9);
			latch_zf_reg  <= render_cmd_sig(8);
			latch_pix_reg <= render_cmd_sig(7);
			latch_out_reg <= render_cmd_sig(6);
			sel_tex_reg   <= render_cmd_sig(5);
			sel_inv_reg   <= render_cmd_sig(4);
			latch_stp_reg <= render_cmd_sig(3);

--			latch_sdrv_reg<= render_cmd_sig(2);		-- 32bitバス用の信号 
--			latch_sdrp_reg<= render_cmd_sig(1);
--			sel_hpix_reg  <= render_cmd_sig(0);
		end if;
	end process;



--==== テクスチャレンダリング処理部 ==================================

	data_render <= texture_data;
	dqm_render  <= (others=>dqm_out_reg);

	sdr_vram_sig <= sdr_read_data;
	sdr_data_sig <= sdr_read_data when texture_ena='1' else pixel_color;

	process (clk) begin
		if (clk'event and clk='1') then

			if (register_init='1') then
				dqm_out_reg <= '1';

			elsif (latch_out_reg='1') then
				if(texdata_wen='1' and cyc1st_flag='0') then
					dqm_out_reg <= '0';
				else
					dqm_out_reg <= '1';
				end if;
			end if;


			if (register_init='1') then
				biliner_ena_reg <= biliner_ena;

			elsif (texture_renew='1') then
				if (biliner_ena_reg='1') then
					tex_x_reg  <= texture_x(11 downto 7);
					tex_y_reg  <= texture_y(11 downto 7);
				else
					tex_x_reg  <= "00000";
					tex_y_reg  <= "00000";
				end if;
			end if;


			if (register_init='1') then
				shading_ena_reg   <= shading_ena;
				dithering_ena_reg <= dithering_ena and shading_ena;

			elsif (intensity_renew='1') then
				if (shading_ena_reg='1' and intensity_r(12)='0') then
					inten_r_reg<= '0' & intensity_r(11 downto 7);
				else
					inten_r_reg<= "100000";
				end if;

				if (shading_ena_reg='1' and intensity_g(12)='0') then
					inten_g_reg<= '0' & intensity_g(11 downto 7);
				else
					inten_g_reg<= "100000";
				end if;

				if (shading_ena_reg='1' and intensity_b(12)='0') then
					inten_b_reg<= '0' & intensity_b(11 downto 7);
				else
					inten_b_reg<= "100000";
				end if;

				if (dithering_ena_reg='1') then
--					if (dithering_type='1') then
--						dither_ref_reg <= lfsr_rand_sig;
--					else
						dither_ref_reg <= dither_ref_sig;
--					end if;
				else
					dither_ref_reg <= "100000";
				end if;

			end if;

		end if;
	end process;

	TU : RENDER_Texture port map (
		clk				=> clk,
		reset			=> reset,
		render_mode		=> render_mode,

		cmd_pause		=> pause_reg,
		cmd_sel_din0	=> sel_din0_reg,
		cmd_sel_din1	=> sel_din1_reg,
		cmd_sel_mul		=> sel_mul_reg,
		cmd_sel_vrm		=> sel_vrm_reg,
		cmd_latch_vrm	=> latch_vrm_reg,
		cmd_latch_zf	=> latch_zf_reg,
		cmd_latch_pix	=> latch_pix_reg,
		cmd_latch_out	=> latch_out_reg,
		cmd_sel_tex		=> sel_tex_reg,
		cmd_sel_inv		=> sel_inv_reg,
		cmd_latch_stp	=> latch_stp_reg,

		tex_x_ref		=> tex_y_reg,		-- 入力ピクセル列のxy順が入れ替わるため
		tex_y_ref		=> tex_x_reg,		-- 　　　　　　　　　　合成順も入れ換える
		inten_r_ref		=> inten_r_reg,
		inten_g_ref		=> inten_g_reg,
		inten_b_ref		=> inten_b_reg,
		dither_ref		=> dither_ref_reg,

		vram_din		=> sdr_vram_sig,
		pixel_din		=> sdr_data_sig,
		pixel_dout		=> texture_data,
		pixel_wen		=> texdata_wen
	);


end RTL;



----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
