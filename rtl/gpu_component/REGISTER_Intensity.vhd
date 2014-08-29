----------------------------------------------------------------------
-- TITLE : SuperJ-7 Intensity Register Block - Sub Program
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--     DATUM     : 2003/04/08 -> 2003/04/14 (HERSTELLUNG)
--               : 2003/04/22 (FESTSTELLUNG)
--               : 2003/06/05 
--               : 2003/08/10 generic文でパラメータ化
--               : 2004/04/17 セルレンダリング機能を削除
--
--               : 2006/11/26 1chipMSX対応
--               : 2006/12/05 FreeRunCounter追加 (NEUBEARBEITUNG)
----------------------------------------------------------------------

-- SubAddress  Register Name          Range (12bitFIXED DEC)
--         0    Intensity              -8.000 ～  7.999
--         1    Intensity (delta)      -8.000 ～ +7.999
--         2    Lightcolor-R            0.000 ～  1.000
--         3    Lightcolor-G            0.000 ～  1.000
--         4    Lightcolor-B            0.000 ～  1.000
--         5    Ambientcolor-R          0.000 ～  1.000
--         6    Ambientcolor-G          0.000 ～  1.000
--         7    Ambientcolor-B          0.000 ～  1.000
--         8        N / A
--         9        N / A
--         A        N / A
--         B        N / A
--         C        N / A
--         D        N / A
--         E    FreeRunCounter          １クロック毎にカウントアップ
--         F    GPUversion              SuperJ7_pacage.vhd内で宣言

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.SuperJ7_package.all;

entity REGISTER_Intensity is
	generic(
		SHADING_MODE		: string := "GOURAUD";
		USE_MEGAFUNCTION	: string := "ON"
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
		reg_rddata	: out std_logic_vector(31 downto 0);	-- 非レジスタ出力
		reg_wrdata	: in  std_logic_vector(31 downto 0);
		reg_uwen	: in  std_logic;
		reg_lwen	: in  std_logic
	);
end REGISTER_Intensity;

architecture RTL of REGISTER_Intensity is
	signal rddata_out_reg	: std_logic_vector(31 downto 0);
	signal wrdatau_sig		: std_logic_vector(31 downto 16);
	signal wrdatal_sig		: std_logic_vector(15 downto 0);
	signal rddatau_sig		: std_logic_vector(31 downto 16);
	signal rddatal_sig		: std_logic_vector(15 downto 0);
	signal version_sig		: std_logic_vector(15 downto 0);
	signal frc_count_reg	: std_logic_vector(31 downto 0);

	signal inten_reg		: std_logic_vector(15 downto 0);
	signal inten_d_reg		: std_logic_vector(15 downto 0);
	signal light_r_reg		: std_logic_vector(12 downto 0);
	signal light_g_reg		: std_logic_vector(12 downto 0);
	signal light_b_reg		: std_logic_vector(12 downto 0);
	signal ambient_r_reg	: std_logic_vector(12 downto 0);
	signal ambient_g_reg	: std_logic_vector(12 downto 0);
	signal ambient_b_reg	: std_logic_vector(12 downto 0);
	signal latch_isrc_sig	: std_logic;
	signal latch_iinc_sig	: std_logic;
	signal latch_rcol_sig	: std_logic;
	signal latch_gcol_sig	: std_logic;
	signal latch_bcol_sig	: std_logic;
	signal latch_ramb_sig	: std_logic;
	signal latch_gamb_sig	: std_logic;
	signal latch_bamb_sig	: std_logic;

	signal cmd_count		: std_logic_vector(2 downto 0);
	signal command_sig		: std_logic_vector(6 downto 0);
	signal light_sel_reg	: std_logic_vector(1 downto 0);
	signal ambient_sel_reg	: std_logic_vector(1 downto 0);
	signal latch_rout_reg	: std_logic;
	signal latch_gout_reg	: std_logic;
	signal latch_bout_reg	: std_logic;

	signal sat_i_dec		: std_logic_vector(11 downto 0);
	signal sat_i_int		: std_logic;
	signal lightcol_sig		: std_logic_vector(12 downto 0);
	signal ambientcol_sig	: std_logic_vector(12 downto 0);
	signal col_add_sig		: std_logic_vector(13 downto 0);
	signal col_sat_sig		: std_logic_vector(12 downto 0);
	signal inten_rout_reg	: std_logic_vector(12 downto 0);
	signal inten_gout_reg	: std_logic_vector(12 downto 0);
	signal inten_bout_reg	: std_logic_vector(12 downto 0);

	signal color_mul_reg	: std_logic_vector(5 downto 0);
	signal inten_mul_reg	: std_logic_vector(5 downto 0);
	signal ans_mul_sig		: std_logic_vector(9 downto 0);
	signal ans_mul_reg		: std_logic_vector(10 downto 0);

begin

--==== レジスタリード/ライトセレクタ部 ===============================

	reg_rddata(31 downto 16) <= rddatau_sig;
	reg_rddata(15 downto 0)  <= rddatal_sig;

	rddatau_sig <= frc_count_reg(31 downto 16) when reg_select="1110" else
					(others=>rddatal_sig(15));
	version_sig <= TO_stdlogicvector(GPU_VER);

	GEN_SEL_GOURAUD : if (SHADING_MODE="GOURAUD") generate

		with reg_select select rddatal_sig <=
				inten_reg			when "0000",
				inten_d_reg			when "0001",
			"000" & light_r_reg		when "0010",
			"000" & light_g_reg		when "0011",
			"000" & light_b_reg		when "0100",
			"000" & ambient_r_reg	when "0101",
			"000" & ambient_g_reg	when "0110",
			"000" & ambient_b_reg	when "0111",
		frc_count_reg(15 downto 0)	when "1110",
				version_sig			when "1111",
				(others=>'0')		when others;

	end generate;
	GEN_SEL_FLAT : if (SHADING_MODE="FLAT") generate

		with reg_select select rddatal_sig <=
			"000" & light_r_reg		when "0010",
			"000" & light_g_reg		when "0011",
			"000" & light_b_reg		when "0100",
		frc_count_reg(15 downto 0)	when "1110",
				version_sig			when "1111",
				(others=>'0')		when others;

	end generate;


	----- レジスタ書き込み処理 -----------

	wrdatau_sig <= reg_wrdata(31 downto 16);
	wrdatal_sig <= reg_wrdata(15 downto 0);

	latch_rcol_sig <= reg_lwen when reg_select="0010" else '0';
	latch_gcol_sig <= reg_lwen when reg_select="0011" else '0';
	latch_bcol_sig <= reg_lwen when reg_select="0100" else '0';

	process (clk) begin
		if (clk'event and clk='1') then
			if (latch_rcol_sig='1') then
				light_r_reg <= wrdatal_sig(12 downto 0);
			end if;
			if (latch_gcol_sig='1') then
				light_g_reg <= wrdatal_sig(12 downto 0);
			end if;
			if (latch_bcol_sig='1') then
				light_b_reg <= wrdatal_sig(12 downto 0);
			end if;
		end if;
	end process;

	process (clk,reset) begin
		if (reset='1') then
			frc_count_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			frc_count_reg <= frc_count_reg + 1;
		end if;
	end process;


	GEN_REG_GOURAUD : if (SHADING_MODE="GOURAUD") generate

		latch_isrc_sig <= reg_lwen when reg_select="0000" else '0';
		latch_iinc_sig <= reg_lwen when reg_select="0001" else '0';
		latch_ramb_sig <= reg_lwen when reg_select="0101" else '0';
		latch_gamb_sig <= reg_lwen when reg_select="0110" else '0';
		latch_bamb_sig <= reg_lwen when reg_select="0111" else '0';

		process (clk) begin
			if (clk'event and clk='1') then

				if (renew='1') then
					inten_reg <= inten_reg + inten_d_reg;
				elsif (latch_isrc_sig='1') then
					inten_reg <= wrdatal_sig;
				end if;
				if (latch_iinc_sig='1') then
					inten_d_reg <= wrdatal_sig;
				end if;

				if (latch_ramb_sig='1') then
					ambient_r_reg <= wrdatal_sig(12 downto 0);
				end if;
				if (latch_gamb_sig='1') then
					ambient_g_reg <= wrdatal_sig(12 downto 0);
				end if;
				if (latch_bamb_sig='1') then
					ambient_b_reg <= wrdatal_sig(12 downto 0);
				end if;

			end if;
		end process;

	end generate;


--==== 輝度演算ステート制御部 ========================================

	GEN_CTRL_GOURAUD : if (SHADING_MODE="GOURAUD") generate

		with cmd_count select command_sig <=
			"01XX000"	when "001",
			"1000100"	when "010",
			"XX01010"	when "011",
			"XX10001"	when "100",
			"00XX000"	when others;

		process (clk,reset) begin
			if (reset='1') then
				cmd_count <= "000";

			elsif (clk'event and clk='1') then
				if (renew='1' or init='1') then
					cmd_count  <= "001";
				else
					if (cmd_count/="000") then
						if (cmd_count = "100") then
							cmd_count <= "000";
						else
							cmd_count <= cmd_count + 1;
						end if;
					end if;
				end if;

				light_sel_reg  <= command_sig(6 downto 5);
				ambient_sel_reg<= command_sig(4 downto 3);
				latch_rout_reg <= command_sig(2);
				latch_gout_reg <= command_sig(1);
				latch_bout_reg <= command_sig(0);

			end if;
		end process;

	end generate;



--==== 輝度演算処理部 ================================================

	GEN_CALC_GOURAUD : if (SHADING_MODE="GOURAUD") generate

	----- 法線内積飽和処理 -----------

		sat_i_dec <= inten_reg(11 downto 0) when inten_reg(15 downto 12)="0000" else
					 (others=>'0');
		sat_i_int <= '1' when (inten_reg(15)='0' and inten_reg(14 downto 12)/="000") else
					 '0';

	----- 色要素セレクト -----------

		with light_sel_reg select lightcol_sig <=
			light_r_reg		when "00",
			light_g_reg		when "01",
			light_b_reg		when "10",
			(others=>'X')	when others;

		with ambient_sel_reg select ambientcol_sig <=
			ambient_r_reg	when "00",
			ambient_g_reg	when "01",
			ambient_b_reg	when "10",
			(others=>'X')	when others;

	----- アンビエント加算と飽和処理 -----------

		col_add_sig <= ('0' & ans_mul_reg & "00") + ('0' & ambientcol_sig);

		col_sat_sig <= col_add_sig(12 downto 0) when col_add_sig(13 downto 12)="00" else
						(12=>'1',others=>'0');

	----- 乗算コンポーネント -----------

		process (clk) begin
			if (clk'event and clk='1') then
				inten_mul_reg <= sat_i_int & sat_i_dec(11 downto 7);
				color_mul_reg <= lightcol_sig(12 downto 7);

				if (color_mul_reg(5)='1') then
					ans_mul_reg(10 downto 5)<= inten_mul_reg;
					ans_mul_reg(4 downto 0) <= (others=>'0');
				elsif (inten_mul_reg(5)='1') then
					ans_mul_reg(10 downto 5)<= color_mul_reg;
					ans_mul_reg(4 downto 0) <= (others=>'0');
				else
					ans_mul_reg(10) <= '0';
					ans_mul_reg(9 downto 0) <= ans_mul_sig;
				end if;
			end if;
		end process;

		GEN_USE_MF : if (USE_MEGAFUNCTION="ON") generate

			MU : multiple_5x5 PORT MAP (
				dataa	 => inten_mul_reg(4 downto 0),
				datab	 => color_mul_reg(4 downto 0),
				result	 => ans_mul_sig
			);

		end generate;
		GEN_UNUSE_MF : if (USE_MEGAFUNCTION/="ON") generate

			MU : ans_mul_sig <= inten_mul_reg(4 downto 0) * color_mul_reg(4 downto 0);

		end generate;

	----- 各色輝度出力 -----------

		intensity_r <= inten_rout_reg;
		intensity_g <= inten_gout_reg;
		intensity_b <= inten_bout_reg;

		process (clk) begin
			if (clk'event and clk='1') then

				if (latch_rout_reg='1') then
					inten_rout_reg <= col_sat_sig;
				end if;
				if (latch_gout_reg='1') then
					inten_gout_reg <= col_sat_sig;
				end if;
				if (latch_bout_reg='1') then
					inten_bout_reg <= col_sat_sig;
				end if;

			end if;
		end process;


	end generate;
	GEN_CALC_FLAT : if (SHADING_MODE="FLAT") generate

		intensity_r <= light_r_reg(12 downto 0);
		intensity_g <= light_g_reg(12 downto 0);
		intensity_b <= light_b_reg(12 downto 0);

	end generate;


end RTL;



----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
