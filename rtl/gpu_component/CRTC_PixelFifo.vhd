----------------------------------------------------------------------
-- TITLE : SuperJ-7 CRTC Pixel Buffer (AMETHYST Edition)
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--   ALTER DATUM : 2003/06/19 -> 2003/06/27 (HERSTELLUNG)
--               : 2003/07/05 (FESTSTELLUNG)
--               : 2003/08/08 (NEUBEARBEITUNG)
--
--     DATUM     : 2004/03/13 -> 2004/03/13 (HERSTELLUNG)
--               : 2004/07/27 標準VHDLの2-PORT RAMを追加
--
--               : 2006/10/07 標準VHDLのみに変更
--               : 2006/10/20 バッファ長をx2→x4に変更
--               : 2006/11/26 16bit化 (NEUBEARBEITUNG)
--
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity CRTC_PixelFifo is
	port(
		slave_clk	: in  std_logic;
		crtc_clk	: in  std_logic;
		init		: in  std_logic;

		fill_req	: out std_logic;
		data_in		: in  std_logic_vector(15 downto 0);
		wr_ena		: in  std_logic;

		r_out		: out std_logic_vector(4 downto 0);
		g_out		: out std_logic_vector(4 downto 0);
		b_out		: out std_logic_vector(4 downto 0);
		rd_ena		: in  std_logic
	);
end CRTC_PixelFifo;

architecture RTL of CRTC_PixelFifo is
	type FIFO_RAM is array (0 to 63) of std_logic_vector(15 downto 0);
	signal pixfifo : FIFO_RAM;
	signal rdaddr_reg		: std_logic_vector(5 downto 0);
	signal wraddr_reg		: std_logic_vector(5 downto 0);
	signal data_reg			: std_logic_vector((data_in'length-1)downto 0);
	signal wren_reg			: std_logic;
	signal dsel_reg			: std_logic;

	signal init_alt0		: std_logic;
	signal init_alt1		: std_logic;
	signal preadbank_0		: std_logic_vector(1 downto 0);
	signal preadbank_1		: std_logic_vector(1 downto 0);
	signal wrena_alt		: std_logic;
	signal s0init_reg		: std_logic;
	signal s1init_reg		: std_logic;
	signal cinit_reg		: std_logic;
	signal fifo_out_sig		: std_logic_vector(15 downto 0);
	signal pread_inc_sig	: std_logic_vector(5 downto 0);
	signal pread_reg		: std_logic_vector(5 downto 0);
	signal pwrite_reg		: std_logic_vector(5 downto 0);
	signal pwbank_inc_sig	: std_logic_vector(1 downto 0);
	signal prbank_inc_sig	: std_logic_vector(1 downto 0);
	signal fill_req_reg		: std_logic;

begin

	----- ポート出力 ----------

	fill_req<= fill_req_reg;
	r_out   <= fifo_out_sig(14 downto 10);
	g_out   <= fifo_out_sig(9 downto 5);
	b_out   <= fifo_out_sig(4 downto 0);


	----- 書き込みポインタとデータ要求処理 ----------

	pwbank_inc_sig <= pwrite_reg(5 downto 4) + 1;
	prbank_inc_sig <= preadbank_1 + 1;

	process (slave_clk) begin
		if (slave_clk'event and slave_clk='1') then
			init_alt0   <= init;
			init_alt1   <= init_alt0;
			preadbank_0 <= pread_reg(5 downto 4);
			preadbank_1 <= preadbank_0;
			wrena_alt   <= wr_ena;

			if (init_alt0='1' and init_alt1='0') then
				pwrite_reg  <= (others=>'0');
				fill_req_reg<= '1';

			else
				if (wr_ena='1') then
					pwrite_reg <= pwrite_reg + 1;	-- 16bit幅='1' / 32bit幅='2'
				end if;

				if (fill_req_reg='1') then
					if (wr_ena='1' and wrena_alt='0') then
						if (pwbank_inc_sig = preadbank_1) then
							fill_req_reg <= '0';
						end if;
					end if;
				else
					if (pwrite_reg(5 downto 4) = prbank_inc_sig) then
						fill_req_reg <= '1';
					end if;
				end if;

			end if;
		end if;
	end process;


	----- 読み出しポインタ処理 ----------

	pread_inc_sig <= pread_reg + 1;

	process (crtc_clk) begin
		if (crtc_clk'event and crtc_clk='1') then
			cinit_reg <= init;

			if (cinit_reg='1') then
				pread_reg <= (others=>'0');

			else
				if (rd_ena='1')then
					pread_reg <= pread_inc_sig;
				end if;

			end if;
		end if;
	end process;


	----- ＦＩＦＯ ----------

	-- リード側 

	fifo_out_sig <= pixfifo(CONV_INTEGER(rdaddr_reg));

	process (crtc_clk) begin
		if (crtc_clk'event and crtc_clk='1') then
			rdaddr_reg <= pread_reg;
		end if;
	end process;

	-- ライト側 

	process (slave_clk) begin
		if (slave_clk'event and slave_clk='1') then
			wraddr_reg <= pwrite_reg;
			data_reg   <= data_in;
			wren_reg   <= wr_ena;

			if (wren_reg='1') then
				pixfifo( CONV_INTEGER(wraddr_reg) ) <= data_reg;
			end if;

		end if;
	end process;


end RTL;



----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
