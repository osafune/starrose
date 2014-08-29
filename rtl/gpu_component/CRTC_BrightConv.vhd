----------------------------------------------------------------------
-- TITLE : SuperJ-7 CRT Bright Control (AMETHYST Edition)
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--     DATUM     : 2004/03/19 -> 2004/08/15 (HERSTELLUNG)
--               : 2004/08/15 (FESTSTELLUNG)
--               : 2006/10/07 (NEUBEARBEITUNG)
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use work.SuperJ7_package.all;

entity CRTC_BrightConv is
	generic(
		USE_MEGAFUNCTION	: string :="ON"
	);
	port(
		clk			: in  std_logic;

		bright		: in  std_logic_vector(9 downto 0);
		color_in	: in  std_logic_vector(4 downto 0);
		color_out	: out std_logic_vector(7 downto 0)
	);
end CRTC_BrightConv;

architecture RTL of CRTC_BrightConv is
	signal mul_a_reg	: std_logic_vector(4 downto 0);
	signal mul_b_reg	: std_logic_vector(7 downto 0);
	signal mul_ans_sig	: std_logic_vector(12 downto 0);
	signal colorout_reg	: std_logic_vector(7 downto 0);
	signal satflag_reg	: std_logic;
	signal fullflag_reg	: std_logic;

begin

	color_out <= colorout_reg;

	GEN_USE_MF : if (USE_MEGAFUNCTION="ON") generate
		MU : multiple_5x8 PORT MAP (
			dataa	 => mul_a_reg,
			datab	 => mul_b_reg,
			result	 => mul_ans_sig
		);

	end generate;
	GEN_UNUSE_MF : if (USE_MEGAFUNCTION/="ON") generate
		mul_ans_sig <= mul_a_reg * mul_b_reg;

	end generate;

	process (clk) begin
		if(clk'event and clk='1') then

			mul_b_reg   <= bright(7 downto 0);
			satflag_reg <= bright(8);
			fullflag_reg<= bright(9);

			if (fullflag_reg='0') then
				if (satflag_reg='0') then
					mul_a_reg   <= color_in;
					colorout_reg<= mul_ans_sig(12 downto 5);
				else
					mul_a_reg   <= 31 - color_in;
					colorout_reg<= mul_ans_sig(12 downto 5) + (color_in & color_in(4 downto 2));
				end if;
			else
				colorout_reg <= (others=>'1');
			end if;

		end if;
	end process;


end RTL;



----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
