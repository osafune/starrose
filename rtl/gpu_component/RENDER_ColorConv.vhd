----------------------------------------------------------------------
-- TITLE : SuperJ-7 Pixel Bi-Liner & Shadeing Convert - Sub Program
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--     DATUM     : 2003/02/21 -> 2003/03/05 (HERSTELLUNG)
--               : 2003/03/31 (FESTSTELLUNG)
--               : 2003/05/26 
--               : 2004/03/07 VRAM入力ポートを分離
--               : 2004/05/09 ディザリング実装 (NEUBEARBEITUNG)

--               : 2006/11/26 1chipMSX対応 (NEUBEARBEITUNG)
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.SuperJ7_package.all;

entity CONV_ColorElement is
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
end CONV_ColorElement;

architecture RTL of CONV_ColorElement is
	signal dat_buf_reg : std_logic_vector(4 downto 0);
	signal mul_a_reg   : std_logic_vector(4 downto 0);
	signal mul_b_reg   : std_logic_vector(5 downto 0);
	signal mul_ans_reg : std_logic_vector(7 downto 0);
	signal dat_buf_sig : std_logic_vector(4 downto 0);
	signal mul_a_sig   : std_logic_vector(4 downto 0);
	signal mul_b_sig   : std_logic_vector(5 downto 0);
	signal mul_trm_sig : std_logic_vector(9 downto 0);
	signal mul_ans_sig : std_logic_vector(9 downto 0);

	signal add_in_sig  : std_logic_vector(8 downto 0);
	signal add_trm_sig : std_logic_vector(5 downto 0);
	signal add_tmp_sig : std_logic_vector(7 downto 0);
	signal add_tmp_reg : std_logic_vector(7 downto 0);

	signal pix_vrm_reg : std_logic_vector(4 downto 0);
	signal pix_out_reg : std_logic_vector(4 downto 0);
	signal pix_out_sig : std_logic_vector(4 downto 0);
	signal pix_bld_reg : std_logic_vector(4 downto 0);
	signal pix_add_sig : std_logic_vector(4 downto 0);
	signal pix_add_reg : std_logic_vector(5 downto 0);
	signal pix_sub_tmp : std_logic_vector(5 downto 0);
	signal pix_sub_sig : std_logic_vector(4 downto 0);

	signal pix_zf_sig  : std_logic;
	signal pix_zf_reg  : std_logic;
	signal dither_reg  : std_logic_vector(5 downto 0);

begin

	GEN_USE_MF : if (USE_MEGAFUNCTION="ON") generate

		MU : multiple_5x5 PORT MAP (
			dataa	 => mul_a_reg,
			datab	 => mul_b_reg(4 downto 0),
			result	 => mul_trm_sig
		);

	end generate;
	GEN_UNUSE_MF : if (USE_MEGAFUNCTION/="ON") generate

		MU : mul_trm_sig <= mul_a_reg * mul_b_reg(4 downto 0);

	end generate;

	pix_zf     <= pix_zf_reg;
	pix_out    <= pix_out_reg;

	mul_ans_sig<= mul_trm_sig + ("00000" & dither_reg(5 downto 1));
	add_in_sig <= ('0' & add_tmp_reg) + ('0' & mul_ans_reg);
	add_trm_sig<= add_in_sig(8 downto 3) + ("00000" & add_in_sig(2));

	pix_sub_tmp<= ('1' & pix_vrm_reg) - ('0' & pix_bld_reg);

	process (clk) begin
		if (clk'event and clk='1') then
			if (pause='0') then

				if (select_dat1='1') then
					mul_a_reg <= dat_buf_reg;
				else
					mul_a_reg <= add_trm_sig(4 downto 0);
				end if;

				if (select_mul='1') then
					mul_b_reg <= texture;
					dither_reg<= (others =>'0');
				else
					mul_b_reg <= intensity;
					dither_reg<= dither;
				end if;

				if (mul_b_reg(5)='1') then
					mul_ans_reg <= mul_a_reg & "000";
				else
					mul_ans_reg <= mul_ans_sig(9 downto 2);
				end if;

				if (select_dat0='1') then
					dat_buf_reg <= pix_data;
				else
					dat_buf_reg <= add_trm_sig(4 downto 0);
				end if;

				if (select_vram='1') then
					add_tmp_reg <= pix_vrm_reg & "000";
				else
					add_tmp_reg <= mul_ans_reg;
				end if;


				if (latch_zf='1') then
					if (mul_a_reg="00000") then
						pix_zf_reg <= '1';
					else
						pix_zf_reg <= '0';
					end if;
				end if;

				if (latch_pix='1') then
					pix_bld_reg <= mul_ans_reg(7 downto 3);
					pix_add_reg <= add_in_sig(8 downto 3);
				end if;

				if (latch_out='1') then
					case bld_mode is
					when "00" =>
						pix_out_reg <= pix_add_reg(5 downto 1);
					when "01" =>
						if (pix_add_reg(5)='0') then
							pix_out_reg <= pix_add_reg(4 downto 0);
						else
							pix_out_reg <= "11111";
						end if;
					when "10" =>
						if (pix_sub_tmp(5)='1') then
							pix_out_reg <= pix_sub_tmp(4 downto 0);
						else
							pix_out_reg <= "00000";
						end if;
					when others =>
						pix_out_reg <= pix_bld_reg;
					end case;
				end if;

				if (latch_vram='1') then
					pix_vrm_reg <= vram_data;
				end if;

			end if;
		end if;
	end process;


end RTL;



----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
