----------------------------------------------------------------------
-- TITLE : SuperJ-7 Texture Rendering Engine (AMETHYST Edition)
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--   ALTER DATUM : 2003/03/07 -> 2003/03/30 (HERSTELLUNG)
--               : 2003/03/31 (FESTSTELLUNG)
--               : 2003/05/26 
--               : 2003/08/13 色要素並びをGRB→RGBへ変更
--               : 2004/03/07 VRAMポート分離へ変更 (NEUBEARBEITUNG)
--
--     DATUM     : 2004/03/09 -> 2004/03/09 (HERSTELLUNG)
--               : 2004/05/06 誤差拡散ディザ実装 (NEUBEARBEITUNG)
--
--     DATUM     : 2006/10/07 -> 2006/11/26 (HERSTELLUNG) 1chipMSX対応 
--               : 2006/10/07 誤差拡散ディザ削除 (NEUBEARBEITUNG)
--
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity RENDER_Texture is
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
end RENDER_Texture;

architecture RTL of RENDER_Texture is

	component CONV_ColorElement
	generic(
		USE_MEGAFUNCTION	: string :="ON"
	);
	port(
		clk			: in  std_logic;
		pause		: in  std_logic;
		bld_mode	: in  std_logic_vector(1 downto 0);
		texture		: in  std_logic_vector(5 downto 0);
		intensity	: in  std_logic_vector(5 downto 0);
		dither		: in  std_logic_vector(5 downto 0);

		pix_data	: in  std_logic_vector(4 downto 0);
		vram_data	: in  std_logic_vector(4 downto 0);
		pix_out		: out std_logic_vector(4 downto 0);
		pix_zf		: out std_logic;

		select_dat0	: in  std_logic;	-- '1':pix_data    / '0':add_trm_sig -> dat_buf_reg
		select_dat1	: in  std_logic;	-- '1':dat_buf_reg / '0':add_trm_sig -> mul_a_reg
		select_mul	: in  std_logic;	-- '1':Texture     / '0':Intensity   -> mul_b_reg
		select_vram	: in  std_logic;	-- '1':mul_ans_reg / '0':pix_vrm_reg -> add_tmp_reg
		latch_zf	: in  std_logic;	-- '1':(latch)pix_zf_reg
		latch_pix	: in  std_logic;	-- '1':(latch)pix_bld_reg,pix_add_reg
		latch_out	: in  std_logic;	-- '1':(latch)pix_out_reg
		latch_vram	: in  std_logic		-- '1':(latch)pix_vrm_reg
	);
	end component;
	signal pix_r_out		: std_logic_vector(4 downto 0);
	signal pix_r_zf			: std_logic;
	signal pix_g_out		: std_logic_vector(4 downto 0);
	signal pix_g_zf			: std_logic;
	signal pix_b_out		: std_logic_vector(4 downto 0);
	signal pix_b_zf			: std_logic;

	signal sub_in_sig		: std_logic_vector(4 downto 0);
	signal sub_32_sig		: std_logic_vector(5 downto 0);
	signal tex_bl_sig		: std_logic_vector(5 downto 0);

	signal pix_dout_sig		: std_logic_vector(15 downto 0);
	signal pix_dqm_sig		: std_logic;
	signal pix_stp_sig		: std_logic;
	signal pix_stp_reg		: std_logic;
	signal stp_tmp_reg		: std_logic_vector(3 downto 0);

	signal bld_mode_sig		: std_logic_vector(1 downto 0);
	signal bld_mode_reg		: std_logic_vector(1 downto 0);

begin

	pixel_dout <= '0' & pix_r_out & pix_g_out & pix_b_out;
	pixel_wen  <= '0' when(pix_stp_reg='1' and pix_r_zf='1' and pix_g_zf='1' and pix_b_zf='1')
				else '1';

	R : CONV_ColorElement port map (
		clk			=> clk,
		pause		=> cmd_pause,
		bld_mode	=> bld_mode_reg,
		texture		=> tex_bl_sig,
		intensity	=> inten_r_ref,
		dither		=> dither_ref,
		pix_data	=> pixel_din(14 downto 10),
		vram_data	=> vram_din(14 downto 10),
		pix_out		=> pix_r_out,
		pix_zf		=> pix_r_zf,
		select_dat0	=> cmd_sel_din0,
		select_dat1	=> cmd_sel_din1,
		select_mul	=> cmd_sel_mul,
		select_vram	=> cmd_sel_vrm,
		latch_zf	=> cmd_latch_zf,
		latch_pix	=> cmd_latch_pix,
		latch_out	=> cmd_latch_out,
		latch_vram	=> cmd_latch_vrm
	);
	G : CONV_ColorElement port map (
		clk			=> clk,
		pause		=> cmd_pause,
		bld_mode	=> bld_mode_reg,
		texture		=> tex_bl_sig,
		intensity	=> inten_g_ref,
		dither		=> dither_ref,
		pix_data	=> pixel_din(9 downto 5),
		vram_data	=> vram_din(9 downto 5),
		pix_out		=> pix_g_out,
		pix_zf		=> pix_g_zf,
		select_dat0	=> cmd_sel_din0,
		select_dat1	=> cmd_sel_din1,
		select_mul	=> cmd_sel_mul,
		select_vram	=> cmd_sel_vrm,
		latch_zf	=> cmd_latch_zf,
		latch_pix	=> cmd_latch_pix,
		latch_out	=> cmd_latch_out,
		latch_vram	=> cmd_latch_vrm
	);
	B : CONV_ColorElement port map (
		clk			=> clk,
		pause		=> cmd_pause,
		bld_mode	=> bld_mode_reg,
		texture		=> tex_bl_sig,
		intensity	=> inten_b_ref,
		dither		=> dither_ref,
		pix_data	=> pixel_din(4 downto 0),
		vram_data	=> vram_din(4 downto 0),
		pix_out		=> pix_b_out,
		pix_zf		=> pix_b_zf,
		select_dat0	=> cmd_sel_din0,
		select_dat1	=> cmd_sel_din1,
		select_mul	=> cmd_sel_mul,
		select_vram	=> cmd_sel_vrm,
		latch_zf	=> cmd_latch_zf,
		latch_pix	=> cmd_latch_pix,
		latch_out	=> cmd_latch_out,
		latch_vram	=> cmd_latch_vrm
	);

	sub_in_sig  <= tex_y_ref  when cmd_sel_tex='1' else tex_x_ref;
	sub_32_sig  <= 32 - ('0' & sub_in_sig);
	tex_bl_sig  <= sub_32_sig when cmd_sel_inv='1' else ('0' & sub_in_sig);


	process (clk) begin
		if (clk'event and clk='1') then
			if (cmd_pause='0') then
				if (pix_stp_reg='0') then
					bld_mode_reg <= "11";
				else
					bld_mode_reg <= render_mode;
				end if;

				stp_tmp_reg(3) <= stp_tmp_reg(2);
				stp_tmp_reg(2) <= stp_tmp_reg(1);
				stp_tmp_reg(1) <= stp_tmp_reg(0);
				stp_tmp_reg(0) <= pixel_din(15);
				if (cmd_latch_stp='1') then
					if (tex_y_ref(4)='0') then
						if (tex_x_ref(4)='0') then
							pix_stp_reg <= stp_tmp_reg(3);
						else
							pix_stp_reg <= stp_tmp_reg(2);
						end if;
					else
						if (tex_x_ref(4)='0') then
							pix_stp_reg <= stp_tmp_reg(1);
						else
							pix_stp_reg <= stp_tmp_reg(0);
						end if;
					end if;
				end if;

			end if;
		end if;
	end process;


end RTL;



----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
