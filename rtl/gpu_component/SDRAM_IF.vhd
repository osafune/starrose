----------------------------------------------------------------------
-- TITLE : SuperJ-7 SDRAM Interface (AMETHYST Edition)
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--   ALTER DATUM : 2003/03/10 -> 2003/04/04 (HERSTELLUNG)
--               : 2003/05/04 (FESTSTELLUNG)
--               : 2003/07/05
--               : 2003/08/12 MRSオペコードをgeneric文で設定
--               : 2004/03/07 CL=3に対応
--
--     DATUM     : 2006/10/09 -> 2006/11/26 1chipMSX対応 (HERSTELLUNG)
--
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity SDRAM_IF is
	generic(
		WRITEBURST	: string := "BURST";
--		WRITEBURST	: string := "SINGLE";
--		CASLATENCY	: string := "CL3";
		CASLATENCY	: string := "CL2";
		BURSTTYPE	: string := "SEQUENTIAL";
--		BURSTTYPE	: string := "INTERLEAVE";
		BURSTLENGTH	: string := "1"
--		BURSTLENGTH	: string := "2"
--		BURSTLENGTH	: string := "4"
--		BURSTLENGTH	: string := "8"
--		BURSTLENGTH	: string := "FULLPAGE"
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
end SDRAM_IF;

architecture RTL of SDRAM_IF is

	signal adr_col_sig	: std_logic_vector(8 downto 0);
	signal col_inc_sig	: std_logic_vector(8 downto 0);
	signal col_in_sig	: std_logic_vector(8 downto 0);
	signal adr_col_reg	: std_logic_vector(8 downto 0);
	signal row_in_sig	: std_logic_vector(14 downto 0);
	signal adr_row_reg	: std_logic_vector(14 downto 0);
	signal row_inc_sig	: std_logic_vector(14 downto 0);
	signal row_out_sig	: std_logic_vector(14 downto 0);
	signal sdr_cmd_reg	: std_logic_vector(3 downto 0);

	signal mrs_ena_sig	: std_logic;
	signal row_inc_dly	: std_logic;
	signal row_ena_sig	: std_logic;
	signal dout_ena_sig	: std_logic;
	signal dout_ena_reg	: std_logic;
	signal latch_dout	: std_logic;
	signal writereq_sig	: std_logic;
	signal read_ena_sig	: std_logic;
	signal read_ena_reg	: std_logic_vector(4 downto 0);

	signal adr_out_reg	: std_logic_vector(12 downto 0);
	signal adr_out_sig	: std_logic_vector(12 downto 0);
	signal bank_out_reg	: std_logic_vector(1 downto 0);
	signal cmd_out_reg	: std_logic_vector(2 downto 0);
	signal dat_out_reg	: std_logic_vector(15 downto 0);
	signal dat_in_reg	: std_logic_vector(15 downto 0);
	signal dqm_out_reg	: std_logic_vector(1 downto 0);
	signal cs_out_reg	: std_logic;

	signal MRS_OPCODE	: std_logic_vector(9 downto 0);

begin

	----- MRSオペコード生成 -----------

	GEN_WBL_BURST : if (WRITEBURST = "BURST") generate
		MRS_OPCODE(9) <= '0';
	end generate;
	GEN_WBL_SINGLE : if (WRITEBURST = "SINGLE") generate
		MRS_OPCODE(9) <= '1';
	end generate;

	GEN_CAS_CL2 : if (CASLATENCY = "CL2") generate
		MRS_OPCODE(6 downto 4) <= "010";
		read_ena  <= read_ena_reg(3);
	end generate;
	GEN_CAS_CL3 : if (CASLATENCY = "CL3") generate
		MRS_OPCODE(6 downto 4) <= "011";
		read_ena  <= read_ena_reg(4);
	end generate;

	GEN_BT_SEQUENTIAL : if (BURSTTYPE = "SEQUENTIAL") generate
		MRS_OPCODE(3) <= '0';
	end generate;
	GEN_BT_INTERLEAVE : if (BURSTTYPE = "INTERLEAVE") generate
		MRS_OPCODE(3) <= '1';
	end generate;

	GEN_BL_1 : if (BURSTLENGTH = "1") generate
		MRS_OPCODE(2 downto 0) <= "000";
	end generate;
	GEN_BL_2 : if (BURSTLENGTH = "2") generate
		MRS_OPCODE(2 downto 0) <= "001";
	end generate;
	GEN_BL_4 : if (BURSTLENGTH = "4") generate
		MRS_OPCODE(2 downto 0) <= "010";
	end generate;
	GEN_BL_8 : if (BURSTLENGTH = "8") generate
		MRS_OPCODE(2 downto 0) <= "011";
	end generate;
	GEN_BL_FULLPAGE : if (WRITEBURST = "BURST" and BURSTLENGTH = "FULLPAGE") generate
		MRS_OPCODE(2 downto 0) <= "111";
	end generate;

	MRS_OPCODE(8 downto 7) <= "00";


	----- ポート出力 -----------

	sdr_addr  <= adr_out_reg;
	sdr_bank  <= bank_out_reg;
	sdr_cke   <= not sdr_init;
	sdr_cs    <= cs_out_reg;
	sdr_ras   <= cmd_out_reg(2);
	sdr_cas   <= cmd_out_reg(1);
	sdr_we    <= cmd_out_reg(0);
	sdr_data  <= dat_out_reg when dout_ena_reg='1' else (others=>'Z');
	sdr_dqm   <= dqm_out_reg;
	readdata  <= dat_in_reg;
	write_done<= latch_dout;
	write_req <= writereq_sig;

	mrs_ena_sig <= '1' when  sdr_cmd_reg(2 downto 0)="000" else '0';	-- OPCODE Enable (MRS command)
	row_ena_sig <= '1' when  sdr_cmd_reg(2 downto 0)="011" else '0';	-- ROW address Enable (ACT command)
	read_ena_sig<= '1' when  sdr_cmd_reg(2 downto 0)="101" else '0';	-- READ command detect
	latch_dout  <= '1' when  sdr_cmd_reg(2 downto 0)="100" else '0';	-- DATA latch signal generate
	dout_ena_sig<= '1' when (sdr_cmd_reg(2 downto 0)="100" or sdr_cmd_in(2 downto 0)="100") else '0';	-- DATA output Enable
	writereq_sig<= '1' when  sdr_cmd_in(2 downto 0) ="100" else '0';	-- WRITE command detect

	adr_col_sig <= address(9 downto 1);
	col_inc_sig <= adr_col_reg + 1;
	col_in_sig  <= col_inc_sig when sel_col_inc='1' else adr_col_sig;

	row_in_sig <= address(24 downto 10);
	row_inc_sig(14) <= adr_row_reg(14);
	row_inc_sig(13 downto 0) <= adr_row_reg(13 downto 0) + 1;
	row_out_sig <= row_inc_sig when row_inc_dly='1' else adr_row_reg;

	adr_out_sig(8 downto 0) <= row_out_sig(9 downto 1) when row_ena_sig='1' else adr_col_reg;
	adr_out_sig(9)  <= row_out_sig(10);
	adr_out_sig(10) <= row_out_sig(11) when row_ena_sig='1' else sdr_cmd_reg(3);
	adr_out_sig(11) <= row_out_sig(12);
	adr_out_sig(12) <= row_out_sig(13);


	process (clk,sdr_init) begin
		if (sdr_init='1') then
			cs_out_reg  <= '1';
			dqm_out_reg <= (others=>'1');
			sdr_cmd_reg <= (others=>'1');
			cmd_out_reg <= (others=>'1');
			read_ena_reg<= (others=>'0');
			dat_in_reg  <= (others=>'0');

		elsif (clk'event and clk='1') then
			cs_out_reg  <= '0';

			adr_col_reg <= col_in_sig;
			adr_row_reg <= row_in_sig;

			cmd_out_reg <= sdr_cmd_reg(2 downto 0);

			sdr_cmd_reg <= sdr_cmd_in;
			row_inc_dly <= sel_row_inc;

			dat_in_reg  <= sdr_data;
			read_ena_reg(4)<= read_ena_reg(3);
			read_ena_reg(3)<= read_ena_reg(2);
			read_ena_reg(2)<= read_ena_reg(1);
			read_ena_reg(1)<= read_ena_reg(0);
			read_ena_reg(0)<= read_ena_sig;

			dout_ena_reg <= dout_ena_sig;

			if (mrs_ena_sig='1') then
				adr_out_reg <= "000" & MRS_OPCODE;
				bank_out_reg<= (others=>'0');
			else
				adr_out_reg <= adr_out_sig;
				bank_out_reg<= row_out_sig(14) & row_out_sig(0);
			end if;

			if (latch_dout='1') then
				dat_out_reg <= writedata;
			end if;
			if (latch_dout='1') then
				dqm_out_reg <= writedqm;
			elsif (read_ena_sig='1') then
				dqm_out_reg <= (others=>'0');
			else
				dqm_out_reg <= (others=>'1');
			end if;

		end if;
	end process;


end RTL;



----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
