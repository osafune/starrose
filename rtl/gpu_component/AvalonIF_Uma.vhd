----------------------------------------------------------------------
-- TITLE : STARROSE AvalonBUS Interface (Memory)
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--     DATUM     : 2006/12/07 -> 2006/12/07 (HERSTELLUNG)
--
--               : 2008/03/21 (FESTSTELLUNG)
--               : 2008/06/25 メモリペリフェラルを分離 (NEUBEARBEITUNG)
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

entity AvalonIF_Uma is
	port(
		reset			: in  std_logic;
		clk				: in  std_logic;

	--==== Avalonバス信号線(メモリ) ===================================
		chipselect		: in  std_logic;
		address			: in  std_logic_vector(24 downto 2);
		read			: in  std_logic;
		readdata		: out std_logic_vector(31 downto 0);
		write			: in  std_logic;
		writedata		: in  std_logic_vector(31 downto 0);
		byteenable		: in  std_logic_vector(3 downto 0);
		waitrequest		: out std_logic;

	--==== 外部信号線(メモリ) =========================================
		mem_tx			: out std_logic_vector(61 downto 0);
		mem_rx			: in  std_logic_vector(32 downto 0)
	);
end AvalonIF_Uma;

architecture RTL of AvalonIF_Uma is

begin

	mem_tx(0)			<= read  when chipselect= '1' else '0';
	mem_tx(1)			<= write when chipselect= '1' else '0';
	mem_tx(24 downto 2)	<= address;
	mem_tx(25)			<= chipselect;
	mem_tx(29 downto 26)<= byteenable;
	mem_tx(61 downto 30)<= writedata;

	readdata			<= mem_rx(31 downto 0);
	waitrequest			<= not mem_rx(32);

end RTL;



----------------------------------------------------------------------
--  (C)2003-2008 Copyright J-7SYSTEM Works.  All rights Reserved.   --
----------------------------------------------------------------------
