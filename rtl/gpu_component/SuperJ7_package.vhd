----------------------------------------------------------------------
-- TITLE : PROCYON GPU constant declare (AMETHYST Edition)
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--   ALTER DATUM : 2003/05/04 -> 2003/05/19 (HERSTELLUNG)
--               : 2003/08/11 (FESTSTELLUNG)
--
--     DATUM     : 2004/03/09 -> 2004/04/18 (HERSTELLUNG)
--               : 2004/11/19 (FESTSTELLUNG)
--               : 2005/06/14 NiosII 100MHz改造(FESTSTELLUNG)
--
--     DATUM     : 2006/10/07 -> 2006/10/29 (HERSTELLUNG)
--               : 2006/11/28 1chipMSX対応改修 (FESTSTELLUNG)
--
--     DATUM     : 2008/06/25 -> 2008/06/29 (HERSTELLUNG)
--               : 2008/07/01 AMETHYST対応改修 (FESTSTELLUNG)
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

package SuperJ7_package is

-- PROCYON_GPU.vhd : Build version define
--
	constant GPU_VER	: bit_vector(15 downto 0) := X"099D";		-- GPU version 0.99 rev.D


-- SDRAM_IF.vhd  : SDRAM command define
--														AP,RAS,CAS,WE
	constant CMD_MRS	: std_logic_vector(3 downto 0) := "X000";	-- Mode register set
	constant CMD_REF	: std_logic_vector(3 downto 0) := "X001";	-- Auto refresh
	constant CMD_ACT	: std_logic_vector(3 downto 0) := "X011";	-- Bank active
	constant CMD_RD		: std_logic_vector(3 downto 0) := "0101";	-- Read
	constant CMD_RDA	: std_logic_vector(3 downto 0) := "1101";	-- Read with auto bank precharge
	constant CMD_WR		: std_logic_vector(3 downto 0) := "0100";	-- Write
	constant CMD_WRA	: std_logic_vector(3 downto 0) := "1100";	-- Write with auto bank precharge
	constant CMD_PRE	: std_logic_vector(3 downto 0) := "0010";	-- Bank precharge
	constant CMD_PALL	: std_logic_vector(3 downto 0) := "1010";	-- All bank precharge
	constant CMD_NOP	: std_logic_vector(3 downto 0) := "X111";	-- No operation command

--	constant REFRESHINT	: std_logic_vector(11 downto 0) := CONV_STD_LOGIC_VECTOR(50,12);
								-- テスト 
--	constant REFRESHINT	: std_logic_vector(11 downto 0) := CONV_STD_LOGIC_VECTOR(3100,12);
								-- 128M/64Mbit SDRAM  (64ms/4096)/(1/100.23MHz)*2 = 3132以下 

	constant REFRESHINT	: std_logic_vector(11 downto 0) := CONV_STD_LOGIC_VECTOR(1560,12);
								-- 256M/512Mbit SDRAM (64ms/8192)/(1/100MHz)*2 = 1562以下 
--	constant REFRESHINT	: std_logic_vector(11 downto 0) := CONV_STD_LOGIC_VECTOR(1400,12);
								-- 256M/512Mbit SDRAM (64ms/8192)/(1/90MHz)*2 = 1406以下 
--	constant REFRESHINT	: std_logic_vector(11 downto 0) := CONV_STD_LOGIC_VECTOR(1300,12);
								-- 256M/512Mbit SDRAM (64ms/8192)/(1/83MHz)*2 = 1302以下 
--	constant REFRESHINT	: std_logic_vector(11 downto 0) := CONV_STD_LOGIC_VECTOR(1170,12);
								-- 256M/512Mbit SDRAM (64ms/8192)/(1/75MHz)*2 = 1174以下 


-- RENDER_UNIT.vhd : RENDER command define
--
	constant PAUSE		: std_logic_vector(3 downto 0) := "1111";	-- Pause
	constant CYCLE1		: std_logic_vector(3 downto 0) := "0000";	-- Render Cycle-1
	constant CYCLE2		: std_logic_vector(3 downto 0) := "0001";	-- Render Cycle-2
	constant CYCLE3		: std_logic_vector(3 downto 0) := "0010";	-- Render Cycle-3
	constant CYCLE4		: std_logic_vector(3 downto 0) := "0011";	-- Render Cycle-4
	constant CYCLE5		: std_logic_vector(3 downto 0) := "0100";	-- Render Cycle-5
	constant CYCLE6		: std_logic_vector(3 downto 0) := "0101";	-- Render Cycle-6
	constant CYCLE7		: std_logic_vector(3 downto 0) := "0110";	-- Render Cycle-7
	constant CYCLE8		: std_logic_vector(3 downto 0) := "0111";	-- Render Cycle-8
	constant CYCLE9		: std_logic_vector(3 downto 0) := "1000";	-- Render Cycle-9
	constant CYCLE0		: std_logic_vector(3 downto 0) := "1100";	-- Render Cycle-10
	constant PFILL		: std_logic_vector(3 downto 0) := "1001";	-- Z-Buffer Prefill
	constant WBACK		: std_logic_vector(3 downto 0) := "1010";	-- Z-Buffer Writeback
	constant LFILL		: std_logic_vector(3 downto 0) := "1011";	-- Linefill


-- PROCYON_GPU.vhd : InitAddress Selector define
--
		-- ラインフィル      00		RMODEレジスタの設定値
		-- ラインコピー      01
		-- レンダリング      1X
	constant RMODE_LFILL: std_logic_vector(1 downto 0) := "00";		-- Linefille Mode
	constant RMODE_LCOPY: std_logic_vector(1 downto 0) := "01";		-- Linecopy Mode
	constant RMODE_REND	: std_logic_vector(1 downto 0) := "1X";		-- Rendering Mode

		-- レンダリング     000   '1' & RLOFFS & RXOFFS
		-- ラインフィル     001   '1' & RLOFFS & RXOFFS
		-- Z値ライトバック  010   '1' & ZBOFFS & RXOFFS
		-- Z値プリロード    011   '1' & ZBOFFS & RXOFFS
		-- ラインライト     100    DA & RLOFFS & RXOFFS
		-- ラインロード     101    SA & FLOFFS & FXOFFS
	constant RENDER		: std_logic_vector(2 downto 0) := "000";	-- Texture Rendering Mode
	constant LNFILL		: std_logic_vector(2 downto 0) := "001";	-- Linefille Rendering Mode
	constant ZBWBACK	: std_logic_vector(2 downto 0) := "010";	-- Z-Buffer Writeback Mode
	constant ZBPLOAD	: std_logic_vector(2 downto 0) := "011";	-- Z-Buffer Preload Mode
	constant LNWBACK	: std_logic_vector(2 downto 0) := "100";	-- Linecopy buffer Writeback Mode
	constant LNPLOAD	: std_logic_vector(2 downto 0) := "101";	-- Linecopy buffer Preload Mode
	constant HALT		: std_logic_vector(2 downto 0) := "111";	-- Rendering State Halt

		-- 外部入力アドレス          00
		-- テクスチャアドレス        01
		-- レンダリングアドレス      10
		-- レンダリングアドレス(alt) 11
	constant ADR_EXT	: std_logic_vector(1 downto 0) := "00";		-- Extern address
	constant ADR_TEX	: std_logic_vector(1 downto 0) := "01";		-- Texture address
	constant ADR_VRM	: std_logic_vector(1 downto 0) := "10";		-- VRAM access address
	constant ADR_ALT	: std_logic_vector(1 downto 0) := "11";		-- Rendering address (for Write)


-- GPU_REGISTER.vhd : Comment
--
-- SubAddress  Register Name          Rande (BitMuster)
--
--        00    RenderMode              15:IE 14:IF 13:CAE 10:DE 9:DT 8:ZE 7:BF 6:SE 5:TE 4-3:BMODE 2-1:RMODE 0:RE
--        01    RenderCount             8-0: 0 ～ 511
--        02    RenderBaseLine         13-0: 0 ～ 16383
--        03    RenderXoffset           8-0: 0 ～ 511
--        04    RenderLine              8-0: 0 ～ 511
--        05    LinefillXoffset         8-0: 0 ～ 511
--        06    LinefillLine           15:DA 14:SA 13-0: 0～16383
--        07    LineFillData           15-0: 0x0000 ～ 0xFFFF
--        08    ZbufferBaseLine        13-0: 0 ～ 16383
--        09    Depth_Z                29-4: -131072.00 ～ 131071.99
--        0A    Depth_dZ               28-4: -65536.00 ～ +65535.99
--        0B    TextureBaseLine        13-0: 0 ～ 16383
--        0C    Texture_X              20-0: 0.000 ～ 511.999
--        0D    Texture_dX             21-0: -512.000 ～ +511.999
--        0E    Texture_Y              20-0: 0.000 ～ 511.999
--        0F    Texture_dY             21-0: -512.000 ～ +511.999
--
--        10    Intensity              15-0: -8.000 ～  7.999
--        11    Intensity_d            15-0: -8.000 ～ +7.999
--        12    Lightcolor-R           12-0:  0.000 ～  1.000
--        13    Lightcolor-G           12-0:  0.000 ～  1.000
--        14    Lightcolor-B           12-0:  0.000 ～  1.000
--        15    Ambientcolor-R         12-0:  0.000 ～  1.000
--        16    Ambientcolor-G         12-0:  0.000 ～  1.000
--        17    Ambientcolor-B         12-0:  0.000 ～  1.000
--        18        N / A
--        19        N / A
--        1A        N / A
--        1B        N / A
--        1C        N / A
--        1D        N / A
--        1E    FreeRunCounter         31-0: 0 ～ 4G-1
--        1F    GPUversion             14-0: v0.00.rev0 ～ v7.99.revF (BCD)


-- PROCYON_CRTC.vhd : Comment
--
-- SubAddress  Register Name          Rande (BitMuster)
--         0    SyncIrq                15:VIE 14:VIE 13:VIC 12:HIC 9-0:LINENUM
--         1    SyncMode               15:ST 14:SOG 10:VD 9-4:PBLOCK 3-0:DOTDIV
--         2    VramXoffset             8-0: 0 ～ 511
--         3    VramYoffset            13-0: 0 ～ 16383
--         4    GammaAddr               7-3: 0 ～ 31
--         5    GammaRData              9-2: 0 ～ 255
--         6    GammaGData              9-2: 0 ～ 255
--         7    GammaBData              9-2: 0 ～ 255
--         8    HTotal                  9-0: 0 ～ 1023 
--         9    HSyncEnd                6-0: 0 ～ 127
--         A    HViewStart              9-0: 0 ～ 1023
--         B    HViewEnd                9-0: 0 ～ 1023
--         C    VTotal                  9-0: 0 ～ 1023
--         D    VSyncEnd                4-0: 0 ～ 31
--         E    VViewStart              9-0: 0 ～ 1023
--         F    VViewEnd                9-0: 0 ～ 1023


	-- 512 x 480 31kHz セパレートシンク
	constant SYNCTYPE_31kHz512x480	: std_logic :='0';
	constant VDOUBLE_31kHz512x480	: std_logic :='0';
	constant READPIX_31kHz512x480	: integer := 32;
	constant DOTDIV_31kHz512x480	: integer := 0;
	constant HTOTAL_31kHz512x480	: integer := 16#0280#;
	constant HSYNCEND_31kHz512x480	: integer := 16#004D#;
	constant HVIEWSTA_31kHz512x480	: integer := 16#006F#;
	constant HVIEWEND_31kHz512x480	: integer := 16#026E#;
	constant VTOTAL_31kHz512x480	: integer := 16#020D#;
	constant VSYNCEND_31kHz512x480	: integer := 16#0003#;
	constant VVIEWSTA_31kHz512x480	: integer := 16#001F#;
	constant VVIEWEND_31kHz512x480	: integer := 16#01FE#;

	-- 384 x 240 31kHz セパレートシンク
	constant SYNCTYPE_31kHz384x240	: std_logic :='0';
	constant VDOUBLE_31kHz384x240	: std_logic :='1';
	constant READPIX_31kHz384x240	: integer := 24;
	constant DOTDIV_31kHz384x240	: integer := 1;
	constant HTOTAL_31kHz384x240	: integer := 16#01E0#;
	constant HSYNCEND_31kHz384x240	: integer := 16#0039#;
	constant HVIEWSTA_31kHz384x240	: integer := 16#0053#;
	constant HVIEWEND_31kHz384x240	: integer := 16#01D2#;
	constant VTOTAL_31kHz384x240	: integer := 16#020D#;
	constant VSYNCEND_31kHz384x240	: integer := 16#0003#;
	constant VVIEWSTA_31kHz384x240	: integer := 16#001F#;
	constant VVIEWEND_31kHz384x240	: integer := 16#01FE#;

	-- 320 x 240 31kHz セパレートシンク
	constant SYNCTYPE_31kHz320x240	: std_logic :='0';
	constant VDOUBLE_31kHz320x240	: std_logic :='1';
	constant READPIX_31kHz320x240	: integer := 20;
	constant DOTDIV_31kHz320x240	: integer := 2;
	constant HTOTAL_31kHz320x240	: integer := 16#0184#;
	constant HSYNCEND_31kHz320x240	: integer := 16#002E#;
	constant HVIEWSTA_31kHz320x240	: integer := 16#0042#;
	constant HVIEWEND_31kHz320x240	: integer := 16#0181#;
	constant VTOTAL_31kHz320x240	: integer := 16#020D#;
	constant VSYNCEND_31kHz320x240	: integer := 16#0003#;
	constant VVIEWSTA_31kHz320x240	: integer := 16#001F#;
	constant VVIEWEND_31kHz320x240	: integer := 16#01FE#;


	-- 512 x 240 15kHz コンポジットシンク
	constant SYNCTYPE_15kHz512x240	: std_logic :='1';
	constant VDOUBLE_15kHz512x240	: std_logic :='0';
	constant READPIX_15kHz512x240	: integer := 32;
	constant DOTDIV_15kHz512x240	: integer := 3;
	constant HTOTAL_15kHz512x240	: integer := 16#0280#;
	constant HSYNCEND_15kHz512x240	: integer := 16#002F#;
	constant HVIEWSTA_15kHz512x240	: integer := 16#0061#;
	constant HVIEWEND_15kHz512x240	: integer := 16#0260#;
	constant VTOTAL_15kHz512x240	: integer := 16#0106#;
	constant VSYNCEND_15kHz512x240	: integer := 16#0003#;
	constant VVIEWSTA_15kHz512x240	: integer := 16#0011#;
	constant VVIEWEND_15kHz512x240	: integer := 16#0100#;

	-- 384 x 240 15kHz コンポジットシンク
	constant SYNCTYPE_15kHz384x240	: std_logic :='1';
	constant VDOUBLE_15kHz384x240	: std_logic :='0';
	constant READPIX_15kHz384x240	: integer := 24;
	constant DOTDIV_15kHz384x240	: integer := 5;
	constant HTOTAL_15kHz384x240	: integer := 16#01E0#;
	constant HSYNCEND_15kHz384x240	: integer := 16#001C#;
	constant HVIEWSTA_15kHz384x240	: integer := 16#0052#;
	constant HVIEWEND_15kHz384x240	: integer := 16#01D1#;
	constant VTOTAL_15kHz384x240	: integer := 16#0106#;
	constant VSYNCEND_15kHz384x240	: integer := 16#0003#;
	constant VVIEWSTA_15kHz384x240	: integer := 16#0011#;
	constant VVIEWEND_15kHz384x240	: integer := 16#0100#;

	-- 320 x 240 15kHz コンポジットシンク
	constant SYNCTYPE_15kHz320x240	: std_logic :='1';
	constant VDOUBLE_15kHz320x240	: std_logic :='0';
	constant READPIX_15kHz320x240	: integer := 20;
	constant DOTDIV_15kHz320x240	: integer := 7;
	constant HTOTAL_15kHz320x240	: integer := 16#0180#;
	constant HSYNCEND_15kHz320x240	: integer := 16#001C#;
	constant HVIEWSTA_15kHz320x240	: integer := 16#003A#;
	constant HVIEWEND_15kHz320x240	: integer := 16#0179#;
	constant VTOTAL_15kHz320x240	: integer := 16#0106#;
	constant VSYNCEND_15kHz320x240	: integer := 16#0003#;
	constant VVIEWSTA_15kHz320x240	: integer := 16#0011#;
	constant VVIEWEND_15kHz320x240	: integer := 16#0100#;

	-- 288 x 240 15kHz コンポジットシンク
	constant SYNCTYPE_15kHz288x240	: std_logic :='1';
	constant VDOUBLE_15kHz288x240	: std_logic :='0';
	constant READPIX_15kHz288x240	: integer := 18;
	constant DOTDIV_15kHz288x240	: integer := 8;
	constant HTOTAL_15kHz288x240	: integer := 16#0160#;
	constant HSYNCEND_15kHz288x240	: integer := 16#0019#;
	constant HVIEWSTA_15kHz288x240	: integer := 16#0035#;
	constant HVIEWEND_15kHz288x240	: integer := 16#0154#;
	constant VTOTAL_15kHz288x240	: integer := 16#0106#;
	constant VSYNCEND_15kHz288x240	: integer := 16#0003#;
	constant VVIEWSTA_15kHz288x240	: integer := 16#0011#;
	constant VVIEWEND_15kHz288x240	: integer := 16#0100#;


	-- 400 x 96 15kHz セパレートシンク (LTA042B010F) 
	constant SYNCTYPE_LTA042B010F	: std_logic :='0';
	constant VDOUBLE_LTA042B010F	: std_logic :='0';
	constant READPIX_LTA042B010F	: integer := 25;
	constant DOTDIV_LTA042B010F		: integer := 14;
	constant HTOTAL_LTA042B010F		: integer := 16#0206#;
	constant HSYNCEND_LTA042B010F	: integer := 16#0019#;
	constant HVIEWSTA_LTA042B010F	: integer := 16#006B#;
	constant HVIEWEND_LTA042B010F	: integer := 16#01FA#;
	constant VTOTAL_LTA042B010F		: integer := 16#0072#;
	constant VSYNCEND_LTA042B010F	: integer := 16#0003#;
	constant VVIEWSTA_LTA042B010F	: integer := 16#000F#;
	constant VVIEWEND_LTA042B010F	: integer := 16#006E#;


-- コンポーネント宣言 

	component multiple_5x8
	PORT
	(
		dataa		: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
		datab		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		result		: OUT STD_LOGIC_VECTOR (12 DOWNTO 0)
	);
	end component;

	component multiple_5x5
	PORT
	(
		dataa		: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
		datab		: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
		result		: OUT STD_LOGIC_VECTOR (9 DOWNTO 0)
	);
	end component;


end SuperJ7_package;



----------------------------------------------------------------------
--   (C)2003-2008 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
