----------------------------------------------------------------------
-- TITLE : SuperJ-7 Render Command ROM (AMETHYST Edition)
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--   ALTER DATUM : 2003/05/05 -> 2003/05/06 (HERSTELLUNG)
--               : 2003/07/01 (FESTSTELLUNG)
--               : 2003/08/07 IDLE時のアドレスを00に固定
--               : 2003/08/13 レンダリングサイクルを11クロック/pixに変更
--								→ PROCYON32では9クロック/pixへ戻した
--
--     DATUM     : 2006/10/09 -> 2006/11/28 (HERSTELLUNG)
--               : 2006/10/15 SDRAM初期化シーケンスを修正
--               : 2006/11/26 描画サイクルを修正 (FESTSTELLUNG)
--
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use work.SuperJ7_package.all;

entity SEQUENCER_CommandRom is
	port(
		inst_pointer	: in  std_logic_vector(6 downto 0);
		command_data	: out std_logic_vector(15 downto 0)
	);
end SEQUENCER_CommandRom;

architecture RTL of SEQUENCER_CommandRom is
	signal pointer_sig	: std_logic_vector(6 downto 0);

	subtype INSTRUCTION is std_logic_vector(15 downto 0);
	signal instruction_sig : INSTRUCTION;
	signal inst00,inst01,inst02,inst03,inst04,inst05,inst06,inst07 : INSTRUCTION;
	signal inst08,inst09,inst0A,inst0B,inst0C,inst0D,inst0E,inst0F : INSTRUCTION;
	signal inst10,inst11,inst12,inst13,inst14,inst15,inst16,inst17 : INSTRUCTION;
	signal inst18,inst19,inst1A,inst1B,inst1C,inst1D,inst1E,inst1F : INSTRUCTION;
	signal inst20,inst21,inst22,inst23,inst24,inst25,inst26,inst27 : INSTRUCTION;
	signal inst28,inst29,inst2A,inst2B,inst2C,inst2D,inst2E,inst2F : INSTRUCTION;
	signal inst30,inst31,inst32,inst33,inst34,inst35,inst36,inst37 : INSTRUCTION;
	signal inst38,inst39,inst3A,inst3B,inst3C,inst3D,inst3E,inst3F : INSTRUCTION;
	signal inst40,inst41,inst42,inst43,inst44,inst45,inst46,inst47 : INSTRUCTION;
	signal inst48,inst49,inst4A,inst4B,inst4C,inst4D,inst4E,inst4F : INSTRUCTION;
	signal inst50,inst51,inst52,inst53,inst54,inst55,inst56,inst57 : INSTRUCTION;
	signal inst58,inst59,inst5A,inst5B,inst5C,inst5D,inst5E,inst5F : INSTRUCTION;
	signal inst60,inst61,inst62,inst63,inst64,inst65,inst66,inst67 : INSTRUCTION;
	signal inst68,inst69,inst6A,inst6B,inst6C,inst6D,inst6E,inst6F : INSTRUCTION;
	signal inst70,inst71,inst72,inst73,inst74,inst75,inst76,inst77 : INSTRUCTION;
	signal inst78,inst79,inst7A,inst7B,inst7C,inst7D,inst7E,inst7F : INSTRUCTION;

begin


--==== インストラクションコード ======================================

--           row col sdr_cmd    addr_sel  rend_cmd    ITRL	=== SDRAMイニシャライズ ===
	inst00 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";
	inst01 <= "XX" & CMD_PALL & "XX"    & PAUSE    & "0000";	-- 全バンクプリチャージ
	inst02 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   tRP待ち
	inst03 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";
	inst04 <= "XX" & CMD_PALL & "XX"    & PAUSE    & "0000";	-- 全バンクプリチャージ
	inst05 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   tRP待ち
	inst06 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";

--           row col sdr_cmd    addr_sel  rend_cmd    ITRL	=== SDRAMリフレッシュ要求 ===
	inst07 <= "XX" & CMD_REF  & "XX"    & PAUSE    & "0000";	-- オートリフレッシュ発行 (1回目)
	inst08 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   以下、tRC待ち
	inst09 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";
	inst0A <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";
	inst0B <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";
	inst0C <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";
	inst0D <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";

	inst0E <= "XX" & CMD_REF  & "XX"    & PAUSE    & "0000";	-- オートリフレッシュ発行 (2回目)
	inst0F <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   以下、tRC待ち
	inst10 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";
	inst11 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";
	inst12 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";
	inst13 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   → addr:7Fへジャンプ(IDLEへ戻る)

	inst14 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";
	inst15 <= "XX" & CMD_MRS  & "XX"    & PAUSE    & "0000";	-- モードレジスタセット
	inst16 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   以下、MRS待ち
	inst17 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   → addr:7Fへジャンプ(IDLEへ戻る)

--           row col sdr_cmd    addr_sel  rend_cmd    ITRL	=== レンダリングステート ===
	inst18 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "1000";	-- レンダラ初期化
	inst19 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";

	inst1A <= "00" & CMD_ACT  & ADR_TEX & PAUSE    & "0000";	-- バンクオープン
	inst1B <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   tRRD待ち
	inst1C <= "00" & CMD_ACT  & ADR_VRM & PAUSE    & "0000";

	inst1D <= "00" & CMD_RD   & ADR_TEX & CYCLE1   & "0000";	-- レンダリングサイクル
	inst1E <= "01" & CMD_RD   & ADR_TEX & CYCLE2   & "0000";
	inst1F <= "01" & CMD_RD   & ADR_TEX & CYCLE3   & "0000";
	inst20 <= "01" & CMD_RD   & ADR_TEX & CYCLE4   & "0001";
	inst21 <= "00" & CMD_RD   & ADR_VRM & CYCLE5   & "0000";
	inst22 <= "00" & CMD_PRE  & ADR_TEX & CYCLE6   & "0100";
	inst23 <= "XX" & CMD_NOP  & "XX"    & CYCLE7   & "0000";	--   → addr:2Aへ条件分岐
	inst24 <= "00" & CMD_ACT  & ADR_TEX & CYCLE8   & "0000";
	inst25 <= "00" & CMD_WR   & ADR_ALT & CYCLE9   & "0010";	--   → addr:1Dへジャンプ
	inst26 <= (others=>'X');
	inst27 <= (others=>'X');
	inst28 <= (others=>'X');
	inst29 <= (others=>'X');

	inst2A <= "XX" & CMD_NOP  & "XX"    & CYCLE8   & "0000";	-- バンククローズ
	inst2B <= "00" & CMD_WR   & ADR_ALT & CYCLE9   & "0000";
	inst2C <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0010";	--   tRDL待ち
	inst2D <= "00" & CMD_PRE  & ADR_ALT & PAUSE    & "0000";	--   → addr:7Fへジャンプ(IDLEへ戻る)
	inst2E <= (others=>'X');
	inst2F <= (others=>'X');

--	32bitモードのインストラクションコード
--	inst1A <= "00" & CMD_ACT  & ADR_TEX & PAUSE    & "0000";	-- バンクオープン
--	inst1B <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   tRRD待ち
--	inst1C <= "10" & CMD_ACT  & ADR_TEX & PAUSE    & "0000";
--	inst1D <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   tRRD待ち
--	inst1E <= "00" & CMD_ACT  & ADR_VRM & PAUSE    & "0000";
--
--	inst1F <= "00" & CMD_RD   & ADR_TEX & CYCLE1   & "0000";	-- レンダリングサイクル
--	inst20 <= "00" & CMD_RD   & ADR_VRM & CYCLE2   & "0000";
--	inst21 <= "10" & CMD_RD   & ADR_TEX & CYCLE3   & "0000";
--	inst22 <= "00" & CMD_PRE  & ADR_TEX & CYCLE4   & "0001";
--	inst23 <= "10" & CMD_PRE  & ADR_TEX & CYCLE5   & "0100";
--	inst24 <= "XX" & CMD_NOP  & "XX"    & CYCLE6   & "0000";	--   → addr:2Aへ条件分岐
--	inst25 <= "00" & CMD_ACT  & ADR_TEX & CYCLE7   & "0000";
--	inst26 <= "00" & CMD_WR   & ADR_ALT & CYCLE8   & "0000";
--	inst27 <= "10" & CMD_ACT  & ADR_TEX & CYCLE9   & "0010";	--   → addr:1Fへジャンプ
--	inst28 <= (others=>'X');
--	inst29 <= (others=>'X');
--
--	inst2A <= "XX" & CMD_NOP  & "XX"    & CYCLE7   & "0000";	-- バンククローズ
--	inst2B <= "00" & CMD_WR   & ADR_ALT & CYCLE8   & "0000";
--	inst2C <= "XX" & CMD_NOP  & "XX"    & CYCLE9   & "0010";	--   tRDL待ち
--	inst2D <= "00" & CMD_PRE  & ADR_ALT & PAUSE    & "0000";	--   → addr:7Fへジャンプ(IDLEへ戻る)
--	inst2E <= (others=>'X');
--	inst2F <= (others=>'X');

--           row col sdr_cmd    addr_sel  rend_cmd    ITRL	=== バッファロードステート ===
--	inst30 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "1000";	-- ロード初期化
--	inst31 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";
--
--	inst32 <= "00" & CMD_ACT  & ADR_VRM & PFILL    & "0000";	-- バンクオープン
--	inst33 <= "XX" & CMD_NOP  & "XX"    & PFILL    & "0000";
--
--	inst34 <= "00" & CMD_RD   & ADR_VRM & PFILL    & "0010";	-- バッファロードサイクル
--																--   → addr:34へ条件分岐
--	inst35 <= "XX" & CMD_NOP  & "XX"    & PFILL    & "0000";	-- バンククローズ
--	inst36 <= "XX" & CMD_NOP  & "XX"    & PFILL    & "0000";	--   tRAS待ち(サイクル数が1の時)
--	inst37 <= "00" & CMD_PRE  & ADR_VRM & PFILL    & "0000";
--	inst38 <= "XX" & CMD_NOP  & "XX"    & PFILL    & "0000";	--   → addr:7Fへジャンプ(IDLEへ戻る)
	inst30 <= (others=>'X');
	inst31 <= (others=>'X');
	inst32 <= (others=>'X');
	inst33 <= (others=>'X');
	inst34 <= (others=>'X');
	inst35 <= (others=>'X');
	inst36 <= (others=>'X');
	inst37 <= (others=>'X');
	inst38 <= (others=>'X');
	inst39 <= (others=>'X');
	inst3A <= (others=>'X');

--           row col sdr_cmd    addr_sel  rend_cmd    ITRL	=== バッファストアステート ===
--	inst3B <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "1000";	-- ストア初期化
--	inst3C <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";
--
--	inst3D <= "00" & CMD_ACT  & ADR_VRM & WBACK    & "0000";	-- バンクオープン
--	inst3E <= "XX" & CMD_NOP  & "XX"    & WBACK    & "0000";	--   tRCD待ち
--
--	inst3F <= "00" & CMD_WR   & ADR_VRM & WBACK    & "0010";	-- バッファロードサイクル
--																--   → addr:3Fへ条件分岐
--	inst40 <= "XX" & CMD_NOP  & "XX"    & WBACK    & "0000";	-- バンククローズ
--	inst41 <= "XX" & CMD_NOP  & "XX"    & WBACK    & "0000";	--   tRAS待ち(サイクル数が1の時)
--	inst42 <= "00" & CMD_PRE  & ADR_VRM & WBACK    & "0000";	--   → addr:7Fへジャンプ(IDLEへ戻る)
	inst3B <= (others=>'X');
	inst3C <= (others=>'X');
	inst3D <= (others=>'X');
	inst3E <= (others=>'X');
	inst3F <= (others=>'X');
	inst40 <= (others=>'X');
	inst41 <= (others=>'X');
	inst42 <= (others=>'X');
	inst43 <= (others=>'X');

--           row col sdr_cmd    addr_sel  rend_cmd    ITRL	=== ラインフィルステート ===
	inst44 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "1000";	-- フィル初期化
	inst45 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";

	inst46 <= "00" & CMD_ACT  & ADR_VRM & LFILL    & "0000";	-- バンクオープン
	inst47 <= "XX" & CMD_NOP  & "XX"    & LFILL    & "0000";	--   tRCD待ち

	inst48 <= "00" & CMD_WR   & ADR_VRM & LFILL    & "0010";	-- ラインフィルサイクル
																--   → addr:48へ条件分岐
	inst49 <= "XX" & CMD_NOP  & "XX"    & LFILL    & "0000";	-- バンククローズ
	inst4A <= "XX" & CMD_NOP  & "XX"    & LFILL    & "0000";	--   tRAS待ち(サイクル数が1の時)
	inst4B <= "00" & CMD_PRE  & ADR_VRM & LFILL    & "0000";	--   → addr:7Fへジャンプ(IDLEへ戻る)

--           row col sdr_cmd    addr_sel  rend_cmd    ITRL	=== バーストリードステート ===
	inst4C <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	-- 初期化 (不要？)
	inst4D <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";

	inst4E <= "00" & CMD_ACT  & ADR_EXT & PAUSE    & "0000";	-- バンクオープン
	inst4F <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   tRCD待ち
	inst50 <= "00" & CMD_RD   & ADR_EXT & PAUSE    & "0000";	-- バーストリード開始
	inst51 <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";	--   → addr:60へ条件分岐(2バースト)
	inst52 <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";	--			2バーストは未使用 
	inst53 <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";	--   → addr:60へ条件分岐(4バースト)
	inst54 <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";	--			PCMリードサイクル 
	inst55 <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";
	inst56 <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";
	inst57 <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";	--   → addr:60へ条件分岐(8バースト)
	inst58 <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";	--			CRTCリードサイクル 
	inst59 <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";
	inst5A <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";
	inst5B <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";
	inst5C <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";
	inst5D <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";
	inst5E <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";
	inst5F <= "01" & CMD_RD   & ADR_EXT & PAUSE    & "0000";

	inst60 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   2バースト時のtRAS待ち
	inst61 <= "00" & CMD_PRE  & ADR_EXT & PAUSE    & "0000";	-- バンククローズ
	inst62 <= (others=>'X');									--   → addr:7Fへジャンプ(IDLEへ戻る)
	inst63 <= (others=>'X');

--           row col sdr_cmd    addr_sel  rend_cmd    ITRL	=== ライトステート ===
	inst64 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	-- ライト初期化 (不要？)
	inst65 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";

	inst66 <= "00" & CMD_ACT  & ADR_EXT & PAUSE    & "0000";	-- ＣＰＵライト
	inst67 <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   tRCD待ち
	inst68 <= "00" & CMD_WR   & ADR_EXT & PAUSE    & "0000";
	inst69 <= "01" & CMD_WR   & ADR_EXT & PAUSE    & "0000";
	inst6A <= "XX" & CMD_NOP  & "XX"    & PAUSE    & "0000";	--   tRDL,tRAS待ち
	inst6B <= "00" & CMD_PRE  & ADR_EXT & PAUSE    & "0000";	--   → addr:7Fへジャンプ(IDLEへ戻る)

--           row col sdr_cmd    addr_sel  rend_cmd    ITRL	=== メイン分岐ステート ===
	inst7F <= "00" & CMD_NOP  & "00"    & PAUSE    & "0000";

	inst6C <= (others=>'X');
	inst6D <= (others=>'X');
	inst6E <= (others=>'X');
	inst6F <= (others=>'X');
	inst70 <= (others=>'X');
	inst71 <= (others=>'X');
	inst72 <= (others=>'X');
	inst73 <= (others=>'X');
	inst74 <= (others=>'X');
	inst75 <= (others=>'X');
	inst76 <= (others=>'X');
	inst77 <= (others=>'X');
	inst78 <= (others=>'X');
	inst79 <= (others=>'X');
	inst7A <= (others=>'X');
	inst7B <= (others=>'X');
	inst7C <= (others=>'X');
	inst7D <= (others=>'X');
	inst7E <= (others=>'X');



--==== インストラクションセレクタ ====================================

	pointer_sig <= inst_pointer;
	command_data<= instruction_sig;

	with pointer_sig select instruction_sig <=
		inst00	when "0000000",
		inst01	when "0000001",
		inst02	when "0000010",
		inst03	when "0000011",
		inst04	when "0000100",
		inst05	when "0000101",
		inst06	when "0000110",
		inst07	when "0000111",
		inst08	when "0001000",
		inst09	when "0001001",
		inst0A	when "0001010",
		inst0B	when "0001011",
		inst0C	when "0001100",
		inst0D	when "0001101",
		inst0E	when "0001110",
		inst0F	when "0001111",
		inst10	when "0010000",
		inst11	when "0010001",
		inst12	when "0010010",
		inst13	when "0010011",
		inst14	when "0010100",
		inst15	when "0010101",
		inst16	when "0010110",
		inst17	when "0010111",
		inst18	when "0011000",
		inst19	when "0011001",
		inst1A	when "0011010",
		inst1B	when "0011011",
		inst1C	when "0011100",
		inst1D	when "0011101",
		inst1E	when "0011110",
		inst1F	when "0011111",
		inst20	when "0100000",
		inst21	when "0100001",
		inst22	when "0100010",
		inst23	when "0100011",
		inst24	when "0100100",
		inst25	when "0100101",
		inst26	when "0100110",
		inst27	when "0100111",
		inst28	when "0101000",
		inst29	when "0101001",
		inst2A	when "0101010",
		inst2B	when "0101011",
		inst2C	when "0101100",
		inst2D	when "0101101",
		inst2E	when "0101110",
		inst2F	when "0101111",
		inst30	when "0110000",
		inst31	when "0110001",
		inst32	when "0110010",
		inst33	when "0110011",
		inst34	when "0110100",
		inst35	when "0110101",
		inst36	when "0110110",
		inst37	when "0110111",
		inst38	when "0111000",
		inst39	when "0111001",
		inst3A	when "0111010",
		inst3B	when "0111011",
		inst3C	when "0111100",
		inst3D	when "0111101",
		inst3E	when "0111110",
		inst3F	when "0111111",

		inst40	when "1000000",
		inst41	when "1000001",
		inst42	when "1000010",
		inst43	when "1000011",
		inst44	when "1000100",
		inst45	when "1000101",
		inst46	when "1000110",
		inst47	when "1000111",
		inst48	when "1001000",
		inst49	when "1001001",
		inst4A	when "1001010",
		inst4B	when "1001011",
		inst4C	when "1001100",
		inst4D	when "1001101",
		inst4E	when "1001110",
		inst4F	when "1001111",
		inst50	when "1010000",
		inst51	when "1010001",
		inst52	when "1010010",
		inst53	when "1010011",
		inst54	when "1010100",
		inst55	when "1010101",
		inst56	when "1010110",
		inst57	when "1010111",
		inst58	when "1011000",
		inst59	when "1011001",
		inst5A	when "1011010",
		inst5B	when "1011011",
		inst5C	when "1011100",
		inst5D	when "1011101",
		inst5E	when "1011110",
		inst5F	when "1011111",
		inst60	when "1100000",
		inst61	when "1100001",
		inst62	when "1100010",
		inst63	when "1100011",
		inst64	when "1100100",
		inst65	when "1100101",
		inst66	when "1100110",
		inst67	when "1100111",
		inst68	when "1101000",
		inst69	when "1101001",
		inst6A	when "1101010",
		inst6B	when "1101011",
		inst6C	when "1101100",
		inst6D	when "1101101",
		inst6E	when "1101110",
		inst6F	when "1101111",
		inst70	when "1110000",
		inst71	when "1110001",
		inst72	when "1110010",
		inst73	when "1110011",
		inst74	when "1110100",
		inst75	when "1110101",
		inst76	when "1110110",
		inst77	when "1110111",
		inst78	when "1111000",
		inst79	when "1111001",
		inst7A	when "1111010",
		inst7B	when "1111011",
		inst7C	when "1111100",
		inst7D	when "1111101",
		inst7E	when "1111110",
		inst7F	when "1111111",

		(others=>'X') when others;


end RTL;



----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
