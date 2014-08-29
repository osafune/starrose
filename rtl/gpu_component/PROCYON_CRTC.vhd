----------------------------------------------------------------------
-- TITLE : PROCYON CRT Controler Unit (AMETHYST Edition)
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--   ALTER DATUM : 2003/06/26 -> 2003/07/05 (HERSTELLUNG)
--               : 2003/08/08 (FESTSTELLUNG)
--               : 2003/08/11 generic文でパラメータ化 (NEUBEARBEITUNG)
--
--     DATUM     : 2004/03/13 -> 2004/03/13 (HERSTELLUNG)
--               : 2004/12/04 輝度初期値を256→0に変更
--               : 2005/07/01 VSYNC割り込みのバグフィクス (NEUBEARBEITUNG)
--
--     DATUM     : 2006/10/07 -> 2006/11/26 (HERSTELLUNG) 1chipMSX対応 
--               : 2006/12/06 レジスタリードバックラッチを追加
--               : 2006/12/24 レジスタアドレスデコーダの修正
--               : 2007/01/09 走査イネーブルビット追加 (NEUBEARBEITUNG)
--
--     DATUM     : 2008/06/25 -> 2008/06/30 (HERSTELLUNG) AMETHYST対応 
--
----------------------------------------------------------------------

-- SubAddress  Register Name          Rande (BitMuster)
--         0    SyncIrq          ○     15:VIE 14:VIE 13:VIC 12:HIC 9-0:LINENUM
--         1    SyncMode         ×     15:ST 14:SOG 13:SCENA 10:VD 9-4:PBLOCK 3-0:DOTDIV
--         2    VramXoffset      △     8-0: 0 ～ 511
--         3    VramYoffset      △    13-0: 0 ～ 16383
--         4    GammaAddr        ×     7-3: 0 ～ 31
--         5    GammaRData       ×     9-2: 0 ～ 255
--              BrightR          ×     9-0: 0 ～ 512	-- CALC指定
--         6    GammaGData       ×     9-2: 0 ～ 256
--              BrightG          ×     9-0: 0 ～ 512	-- CALC指定
--         7    GammaBData       ×     9-2: 0 ～ 255
--              BrightB          ×     9-0: 0 ～ 512	-- CALC指定
--         8    HTotal           ×     9-0: 0 ～ 1023 
--         9    HSyncEnd         ×     6-0: 0 ～ 127
--         A    HViewStart       ×     9-0: 0 ～ 1023
--         B    HViewEnd         ×     9-0: 0 ～ 1023
--         C    VTotal           ×     9-0: 0 ～ 1023
--         D    VSyncEnd         ×     4-0: 0 ～ 31
--         E    VViewStart       ×     9-0: 0 ～ 1023
--         F    VViewEnd         ×     9-0: 0 ～ 1023

-- ○：リード／ライトとも必須
-- △：ライトのみ必須
-- ×：固定値でも構わない

-- γテーブルはドット毎、VRAMオフセットは16ピクセル毎で即時更新。
-- ドット分周比・横ピクセル数・縦倍角・水平同期周りは、変更後１Ｈは不安定。
-- CSYNC/HSYNC切り替え・垂直同期周りは、変更後１インターは不安定。


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.SuperJ7_package.all;

entity PROCYON_CRTC is
	generic(
		REGISTER_READ		: string := "ENABLE";
--		REGISTER_READ		: string := "DISENABLE";

		SYNC_REGISTER		: string := "VARIABLE";
--		SYNC_REGISTER		: string := "FIXED";

		DEFAULT_MODE		: string := "31kHz512x480";
--		DEFAULT_MODE		: string := "31kHz384x240";
--		DEFAULT_MODE		: string := "31kHz320x240";
--		DEFAULT_MODE		: string := "15kHz512x240";
--		DEFAULT_MODE		: string := "15kHz384x240";
--		DEFAULT_MODE		: string := "15kHz320x240";
--		DEFAULT_MODE		: string := "15kHz288x240";

		GAMMATABLE_TYPE		: string := "CALC"
--		GAMMATABLE_TYPE		: string := "LINER"
	);
	port(
		slave_clk	: in  std_logic;				-- 75～100MHz
		crtc_clk	: in  std_logic;				-- 60.47MHz(typ)
		reset		: in  std_logic;

	----- ピクセルリードポート -----
		fifofill_req: out std_logic;
		fifofill_ena: in  std_logic;
		fifoaddr	: out std_logic_vector(24 downto 1);
		fifodata	: in  std_logic_vector(15 downto 0);

	----- ビデオ信号出力 -----
		r_out		: out std_logic_vector(7 downto 0);
		g_out		: out std_logic_vector(7 downto 0);
		b_out		: out std_logic_vector(7 downto 0);
		blank_out	: out std_logic;
		dclk_out	: out std_logic;
		hsync_out	: out std_logic;
		vsync_out	: out std_logic;
		sogsig_out	: out std_logic;

	----- 内部レジスタインターフェース -----
		reg_irq		: out std_logic;
		reg_select	: in  std_logic_vector(3 downto 0);
		reg_rddata	: out std_logic_vector(15 downto 0);
		reg_wrdata	: in  std_logic_vector(15 downto 0);
		reg_wen		: in  std_logic
	);
end PROCYON_CRTC;

architecture RTL of PROCYON_CRTC is
	signal frst0_reg		: std_logic;
	signal frst1_reg		: std_logic;
	signal ffena_reg		: std_logic;
	signal hb0_reg			: std_logic;
	signal hb1_reg			: std_logic;
	signal readxaddr_reg	: std_logic_vector(5 downto 0);
	signal readyaddr_reg	: std_logic_vector(8 downto 0);
	signal readdone_reg		: std_logic;
	signal vramxaddr_reg	: std_logic_vector(8 downto 4);
	signal vramyaddr_reg	: std_logic_vector(13 downto 0);
	signal resetfall_sig	: std_logic;


	----- ＣＲＴＣモードレジスタ ----------
	signal virqena_reg		: std_logic;
	signal hirqena_reg		: std_logic;
	signal virq_reg			: std_logic;
	signal hirq_reg			: std_logic;
	signal scanena_reg		: std_logic;
	signal linenum_reg		: std_logic_vector(9 downto 0);
	signal synctype_reg		: std_logic;
	signal sogena_reg		: std_logic;
	signal vdouble_reg		: std_logic;
	signal readpix_reg		: std_logic_vector(5 downto 0);
	signal dotdiv_reg		: std_logic_vector(3 downto 0);
	signal readxoffs_reg	: std_logic_vector(8 downto 0);
	signal readyoffs_reg	: std_logic_vector(13 downto 0);
	signal latch_irq_sig	: std_logic;
	signal latch_mode_sig	: std_logic;
	signal latch_xofs_sig	: std_logic;
	signal latch_yofs_sig	: std_logic;
	signal irq_data_sig		: std_logic_vector(15 downto 0);
	signal mode_data_sig	: std_logic_vector(15 downto 0);
	signal rddata_sig		: std_logic_vector(15 downto 0);
	signal rddata_reg		: std_logic_vector(15 downto 0);


	----- 同期信号生成コンポーネント ----------
	component CRTC_VideoSyncGen
	generic(
		DEFAULT_MODE	: string;
		SYNC_REGISTER	: string;

		INIT_DOTCOUNT	: integer := 0;
		INIT_LINENUM	: integer := 0
--		INIT_LINENUM	: integer := 31		-- テスト用 
	);
	port(
		crtc_clk	: in  std_logic;
		reset		: in  std_logic;
		dotscan_ena	: in  std_logic := '1';

		fifo_reset	: out std_logic;
		dotdiv_ref	: in  std_logic_vector(3 downto 0) :="0000";

		hsync		: out std_logic;
		vsync		: out std_logic;
		hblank		: out std_logic;
		vblank		: out std_logic;
		linenum		: out std_logic_vector(9 downto 0);
		fifo_req	: out std_logic;
		dac_latch	: out std_logic;

		reg_select	: in  std_logic_vector(2 downto 0);
		reg_rddata	: out std_logic_vector(15 downto 0);
		reg_wrdata	: in  std_logic_vector(15 downto 0);
		reg_wen		: in  std_logic
	);
	end component;
	signal fiforeq_sig		: std_logic;
	signal fiforeset_sig	: std_logic;
	signal hsync_sig		: std_logic;
	signal vsync_sig		: std_logic;
	signal csync_sig		: std_logic;
	signal dsync_sig		: std_logic;
	signal hblank_sig		: std_logic;
	signal vblank_sig		: std_logic;
	signal blank_sig		: std_logic;
	signal blank_reg		: std_logic;
	signal blankout_reg		: std_logic;
	signal linenum_sig		: std_logic_vector(9 downto 0);
	signal vsg_select_reg	: std_logic_vector(2 downto 0);
	signal vsg_rddata_sig	: std_logic_vector(15 downto 0);
	signal vsg_rddata_reg	: std_logic_vector(15 downto 0);
	signal vsg_wrdata_reg	: std_logic_vector(15 downto 0);
	signal vsg_wen_reg		: std_logic;


	----- ピクセルＦＩＦＯコンポーネント ----------
	component CRTC_PixelFifo
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
	end component;
	signal fiforout_sig		: std_logic_vector(4 downto 0);
	signal fifogout_sig		: std_logic_vector(4 downto 0);
	signal fifobout_sig		: std_logic_vector(4 downto 0);
	signal fiforout_reg		: std_logic_vector(7 downto 0);
	signal fifogout_reg		: std_logic_vector(7 downto 0);
	signal fifobout_reg		: std_logic_vector(7 downto 0);
	signal fifordreq_sig	: std_logic;
	signal fifordreq_reg	: std_logic;
	signal rdena_sig		: std_logic;


	----- γ変換テーブルコンポーネント ----------
	component CRTC_BrightConv
	generic(
		USE_MEGAFUNCTION	: string :="ON"
	);
	port(
		clk			: in  std_logic;

		bright		: in  std_logic_vector(9 downto 0);
		color_in	: in  std_logic_vector(4 downto 0);
		color_out	: out std_logic_vector(7 downto 0)
	);
	end component;
	signal gammaaddr_reg	: std_logic_vector(7 downto 3);
	signal gammaawen_sig	: std_logic;
	signal gammarwen_sig	: std_logic;
	signal gammagwen_sig	: std_logic;
	signal gammabwen_sig	: std_logic;
	signal gammardat_sig	: std_logic_vector(9 downto 2);
	signal gammagdat_sig	: std_logic_vector(9 downto 2);
	signal gammabdat_sig	: std_logic_vector(9 downto 2);

	signal gadr_data_sig	: std_logic_vector(15 downto 0);
	signal grdat_data_sig	: std_logic_vector(15 downto 0);
	signal ggdat_data_sig	: std_logic_vector(15 downto 0);
	signal gbdat_data_sig	: std_logic_vector(15 downto 0);

	signal brightr_reg		: std_logic_vector(9 downto 0);
	signal brightg_reg		: std_logic_vector(9 downto 0);
	signal brightb_reg		: std_logic_vector(9 downto 0);

	signal dotrout_sig		: std_logic_vector(7 downto 0);
	signal dotgout_sig		: std_logic_vector(7 downto 0);
	signal dotbout_sig		: std_logic_vector(7 downto 0);
	signal dotrout_reg		: std_logic_vector(7 downto 0);
	signal dotgout_reg		: std_logic_vector(7 downto 0);
	signal dotbout_reg		: std_logic_vector(7 downto 0);


	signal INIT_SCANENA		: std_logic;
	signal INIT_SYNCTYPE	: std_logic;
	signal INIT_VDOUBLE		: std_logic;
	signal INIT_READPIX		: integer;
	signal INIT_DOTDIV		: integer;

begin

--==== 初期値シグナル設定 ============================================

	GEN_31kHz512x480 : if (DEFAULT_MODE = "31kHz512x480") generate

		INIT_SCANENA  <= '1';
		INIT_SYNCTYPE <= SYNCTYPE_31kHz512x480;
		INIT_VDOUBLE  <= VDOUBLE_31kHz512x480;
		INIT_READPIX  <= READPIX_31kHz512x480;
		INIT_DOTDIV   <= DOTDIV_31kHz512x480;

	end generate;
	GEN_31kHz384x240 : if (DEFAULT_MODE = "31kHz384x240") generate

		INIT_SCANENA  <= '1';
		INIT_SYNCTYPE <= SYNCTYPE_31kHz384x240;
		INIT_VDOUBLE  <= VDOUBLE_31kHz384x240;
		INIT_READPIX  <= READPIX_31kHz384x240;
		INIT_DOTDIV   <= DOTDIV_31kHz384x240;

	end generate;
	GEN_31kHz320x240 : if (DEFAULT_MODE = "31kHz320x240") generate

		INIT_SCANENA  <= '1';
		INIT_SYNCTYPE <= SYNCTYPE_31kHz320x240;
		INIT_VDOUBLE  <= VDOUBLE_31kHz320x240;
		INIT_READPIX  <= READPIX_31kHz320x240;
		INIT_DOTDIV   <= DOTDIV_31kHz320x240;

	end generate;

	GEN_15kHz512x240 : if (DEFAULT_MODE = "15kHz512x240") generate

		INIT_SCANENA  <= '1';
		INIT_SYNCTYPE <= SYNCTYPE_15kHz512x240;
		INIT_VDOUBLE  <= VDOUBLE_15kHz512x240;
		INIT_READPIX  <= READPIX_15kHz512x240;
		INIT_DOTDIV   <= DOTDIV_15kHz512x240;

	end generate;
	GEN_15kHz384x240 : if (DEFAULT_MODE = "15kHz384x240") generate

		INIT_SCANENA  <= '1';
		INIT_SYNCTYPE <= SYNCTYPE_15kHz384x240;
		INIT_VDOUBLE  <= VDOUBLE_15kHz384x240;
		INIT_READPIX  <= READPIX_15kHz384x240;
		INIT_DOTDIV   <= DOTDIV_15kHz384x240;

	end generate;
	GEN_15kHz320x240 : if (DEFAULT_MODE = "15kHz320x240") generate

		INIT_SCANENA  <= '1';
		INIT_SYNCTYPE <= SYNCTYPE_15kHz320x240;
		INIT_VDOUBLE  <= VDOUBLE_15kHz320x240;
		INIT_READPIX  <= READPIX_15kHz320x240;
		INIT_DOTDIV   <= DOTDIV_15kHz320x240;

	end generate;
	GEN_15kHz288x240 : if (DEFAULT_MODE = "15kHz288x240") generate

		INIT_SCANENA  <= '1';
		INIT_SYNCTYPE <= SYNCTYPE_15kHz288x240;
		INIT_VDOUBLE  <= VDOUBLE_15kHz288x240;
		INIT_READPIX  <= READPIX_15kHz288x240;
		INIT_DOTDIV   <= DOTDIV_15kHz288x240;

	end generate;
	GEN_LTA042B010F : if (DEFAULT_MODE = "LTA042B010F") generate

		INIT_SCANENA  <= '1';
		INIT_SYNCTYPE <= SYNCTYPE_LTA042B010F;
		INIT_VDOUBLE  <= VDOUBLE_LTA042B010F;
		INIT_READPIX  <= READPIX_LTA042B010F;
		INIT_DOTDIV   <= DOTDIV_LTA042B010F;

	end generate;

	GEN_SCANOFF : if (DEFAULT_MODE = "") generate

		INIT_SCANENA  <= '0';
		INIT_SYNCTYPE <= '0';
		INIT_VDOUBLE  <= '0';
		INIT_READPIX  <= 0;
		INIT_DOTDIV   <= 0;

	end generate;



--==== レジスタ読み出しセレクタ部 ====================================

	GEN_READENA : if (REGISTER_READ = "ENABLE") generate	-- レジスタデータリード有効 

		reg_rddata <= rddata_reg when reg_select(3)='0' else vsg_rddata_reg;

		with reg_select(2 downto 0) select rddata_sig <=
				irq_data_sig			when "000",
				mode_data_sig			when "001",
			"0000000" & readxoffs_reg	when "010",
			"00" & readyoffs_reg		when "011",
				gadr_data_sig			when "100",
				grdat_data_sig			when "101",
				ggdat_data_sig			when "110",
				gbdat_data_sig			when "111",
			(others=>'X')				when others;

		process(slave_clk)begin
			if(slave_clk'event and slave_clk='1')then
				rddata_reg    <= rddata_sig;
				vsg_rddata_reg<= vsg_rddata_sig;
			end if;
		end process;

	end generate;
	GEN_READDIS : if (REGISTER_READ /= "ENABLE") generate	-- レジスタデータリード無効 

		reg_rddata <= irq_data_sig;

	end generate;



--==== モードレジスタ部 ==============================================

	reg_irq <= (virqena_reg and virq_reg)or(hirqena_reg and hirq_reg);

	latch_irq_sig <= reg_wen when reg_select="0000" else '0';
	latch_mode_sig<= reg_wen when reg_select="0001" else '0';
	latch_xofs_sig<= reg_wen when reg_select="0010" else '0';
	latch_yofs_sig<= reg_wen when reg_select="0011" else '0';

	irq_data_sig  <= virqena_reg & hirqena_reg & virq_reg & hirq_reg &
						"00" & linenum_reg;
	mode_data_sig <= synctype_reg & sogena_reg & scanena_reg & "00" & vdouble_reg &
						readpix_reg & dotdiv_reg;

	process (slave_clk,reset) begin
		if (reset='1') then
			virqena_reg <= '0';
			hirqena_reg <= '0';
			virq_reg    <= '0';
			hirq_reg    <= '0';
			synctype_reg<= INIT_SYNCTYPE;
			sogena_reg  <= '0';
			scanena_reg <= INIT_SCANENA;
			vdouble_reg <= INIT_VDOUBLE;
			readpix_reg <= CONV_STD_LOGIC_VECTOR(INIT_READPIX,6);
			dotdiv_reg  <= CONV_STD_LOGIC_VECTOR(INIT_DOTDIV,4);

		elsif (slave_clk'event and slave_clk='1') then
			if (resetfall_sig='1') then
				if (linenum_sig=0) then				-- 割り込み要求信号 
					virq_reg <= '1';
				end if;
				hirq_reg   <= '1';
				linenum_reg<= linenum_sig;
			elsif (latch_irq_sig='1') then
				if (reg_wrdata(13)='0') then
					virq_reg <= '0';
				end if;
				if (reg_wrdata(12)='0') then
					hirq_reg <= '0';
				end if;
			end if;

			if (latch_irq_sig='1') then
				virqena_reg <= reg_wrdata(15);		-- 割り込みイネーブル信号 
				hirqena_reg <= reg_wrdata(14);
			end if;

			if (latch_mode_sig='1') then
				synctype_reg<= reg_wrdata(15);		-- 同期信号タイプ(1:CSYNC / 0:HSYNC)
				sogena_reg  <= reg_wrdata(14);		-- SyncOnGreen有効(1:SOG有効 / 0:SOG無効)
				scanena_reg <= reg_wrdata(13);		-- 画面走査(1:走査開始 / 0:走査停止)
				vdouble_reg <= reg_wrdata(10);		-- 垂直解像度(1:２倍 / 0:等倍)
				readpix_reg <= reg_wrdata(9 downto 4);	-- ピクセルブロック数 
				dotdiv_reg  <= reg_wrdata(3 downto 0);	-- ドットクロック分周比 
			end if;

			if (latch_xofs_sig='1') then			-- VRAM読み出しｘ座標 
				readxoffs_reg <= reg_wrdata(8 downto 0);
			end if;

			if (latch_yofs_sig='1') then			-- VRAM読み出しｙ座標 
				readyoffs_reg <= reg_wrdata(13 downto 0);
			end if;

		end if;
	end process;



--==== 同期信号生成部 ================================================

	hsync_out <= hsync_sig when synctype_reg='0' else csync_sig;
--	hsync_out <= hsync_sig;
--	vsync_out <= vsync_sig when synctype_reg='0' else '1';
	vsync_out <= vsync_sig;
	dclk_out  <= dsync_sig;
	sogsig_out<= csync_sig when sogena_reg='1' else '0';

	csync_sig <= not(hsync_sig xor vsync_sig);
	blank_sig <= hblank_sig or vblank_sig;

	resetfall_sig <= '1' when(frst0_reg='0' and frst1_reg='1') else '0';

	process (slave_clk,reset) begin					-- fiforeset_sig立ち下がり検出 
		if (reset='1') then
			frst0_reg   <= '0';
			frst1_reg   <= '0';
		elsif (slave_clk'event and slave_clk='1') then
			frst0_reg <= fiforeset_sig;
			frst1_reg <= frst0_reg;
		end if;
	end process;


	process(crtc_clk,reset)begin
		if (reset='1') then
			vsg_wen_reg <= '0';

		elsif (crtc_clk'event and crtc_clk='1') then
			vsg_select_reg <= reg_select(2 downto 0);
			vsg_wrdata_reg <= reg_wrdata;

			if (reg_select(3)='1') then
				vsg_wen_reg <= reg_wen;
			else
				vsg_wen_reg <= '0';
			end if;
		end if;
	end process;

	U0 : CRTC_VideoSyncGen
	generic map(
		DEFAULT_MODE	=> DEFAULT_MODE,
		SYNC_REGISTER	=> SYNC_REGISTER
	)
	port map(
		crtc_clk	=> crtc_clk,
		reset		=> reset,
		dotscan_ena	=> scanena_reg,

		fifo_reset	=> fiforeset_sig,
		dotdiv_ref	=> dotdiv_reg,

		hsync		=> hsync_sig,
		vsync		=> vsync_sig,
		hblank		=> hblank_sig,
		vblank		=> vblank_sig,
		linenum		=> linenum_sig,
		fifo_req	=> fiforeq_sig,
		dac_latch	=> dsync_sig,

		reg_select	=> vsg_select_reg,
		reg_rddata	=> vsg_rddata_sig,
		reg_wrdata	=> vsg_wrdata_reg,
		reg_wen		=> vsg_wen_reg
	);



--==== ピクセルＦＩＦＯ部 ============================================

	fifofill_req<= fifordreq_reg;
	fifoaddr    <= '1' & vramyaddr_reg & vramxaddr_reg & readxoffs_reg(3 downto 0);

	process (slave_clk,reset) begin
		if (reset='1') then
			hb0_reg      <= '1';
			hb1_reg      <= '1';
			ffena_reg    <= '0';
			readdone_reg <= '1';
			fifordreq_reg<= '0';

		elsif (slave_clk'event and slave_clk='1') then
			ffena_reg <= fifofill_ena;
			hb0_reg   <= hblank_sig;
			hb1_reg   <= hb0_reg;

			if (readdone_reg='0') then						-- fifofill_reqを条件マスク 
				fifordreq_reg <= fifordreq_sig;
			else
				fifordreq_reg <= '0';
			end if;

			if (resetfall_sig='1') then						-- fiforesetの立ち下がり 
				readxaddr_reg <= (others=>'0');

				if (vblank_sig='1') then
					readyaddr_reg <= (others=>'1');
					readdone_reg  <= '1';
				else
					readyaddr_reg <= readyaddr_reg + 1;
					readdone_reg  <= '0';
				end if;

			else
--				if (ffena_reg='1' and fifofill_ena='0') then
--					readxaddr_reg <= readxaddr_reg + 1;		-- fifofill_enaの立ち下がりでカウント 
--				end if;
				if (ffena_reg='0' and fifofill_ena='1') then
					readxaddr_reg <= readxaddr_reg + 1;		-- fifofill_enaの立ち上がりでカウント 
				end if;
				if((readxaddr_reg=readpix_reg)or(hb0_reg='1' and hb1_reg='0'))then
					readdone_reg <= '1';					-- 規定ピクセル数を読み出すか、hblankがアサート 
				end if;										-- されたらライン読み出し終了 

			end if;
															-- アドレスを生成 
			vramxaddr_reg <= readxoffs_reg(8 downto 4) + readxaddr_reg(4 downto 0);
			if (vdouble_reg='0') then
				vramyaddr_reg <= readyoffs_reg + ("00000" & readyaddr_reg);
			else
				vramyaddr_reg <= readyoffs_reg + ("000000" & readyaddr_reg(8 downto 1));
			end if;

		end if;
	end process;


	rdena_sig <= fiforeq_sig when blank_sig='0' else '0';

	U1 : CRTC_PixelFifo port map(
		slave_clk	=> slave_clk,
		crtc_clk	=> crtc_clk,
		init		=> fiforeset_sig,

		data_in		=> fifodata,
		wr_ena		=> fifofill_ena,

		r_out		=> fiforout_sig,
		g_out		=> fifogout_sig,
		b_out		=> fifobout_sig,
		rd_ena		=> rdena_sig,

		fill_req	=> fifordreq_sig
	);



--==== ガンマテーブル部 ==============================================

	GEN_CALC_BRIGHTNESS : if (GAMMATABLE_TYPE = "CALC") generate
													-- 明るさ演算をリアルタイムで行う 
													-- 2クロックレイテンシ 
		gammarwen_sig <= reg_wen when reg_select="0101" else '0';
		gammagwen_sig <= reg_wen when reg_select="0110" else '0';
		gammabwen_sig <= reg_wen when reg_select="0111" else '0';

		gadr_data_sig <= (others=>'X');
		grdat_data_sig<= "000000" & brightr_reg;
		ggdat_data_sig<= "000000" & brightg_reg;
		gbdat_data_sig<= "000000" & brightb_reg;

		process (slave_clk,reset) begin
			if (reset='1') then
--				brightr_reg <= (8=>'1',others=>'0');
--				brightg_reg <= (8=>'1',others=>'0');
--				brightb_reg <= (8=>'1',others=>'0');
				brightr_reg <= (others=>'0');
				brightg_reg <= (others=>'0');
				brightb_reg <= (others=>'0');

			elsif (slave_clk'event and slave_clk='1') then
				if (gammarwen_sig='1') then
					brightr_reg <= reg_wrdata(9 downto 0);
				end if;
				if (gammagwen_sig='1') then
					brightg_reg <= reg_wrdata(9 downto 0);
				end if;
				if (gammabwen_sig='1') then
					brightb_reg <= reg_wrdata(9 downto 0);
				end if;

			end if;
		end process;

		BR : CRTC_BrightConv port map (				-- R明るさ演算 
			clk			=> crtc_clk,
			bright		=> brightr_reg,
			color_in	=> fiforout_sig,
			color_out	=> dotrout_sig
		);
		BG : CRTC_BrightConv port map (				-- G明るさ演算 
			clk			=> crtc_clk,
			bright		=> brightg_reg,
			color_in	=> fifogout_sig,
			color_out	=> dotgout_sig
		);
		BB : CRTC_BrightConv port map (				-- B明るさ演算 
			clk			=> crtc_clk,
			bright		=> brightb_reg,
			color_in	=> fifobout_sig,
			color_out	=> dotbout_sig
		);

	end generate;
	GEN_UNUSE_GAMMATABLE : if (GAMMATABLE_TYPE = "LINER") generate
													-- γテーブルを使用しない場合 
													-- 0クロックレイテンシ 
		dotrout_sig <= fiforout_sig & fiforout_sig(4 downto 2);
		dotgout_sig <= fifogout_sig & fifogout_sig(4 downto 2);
		dotbout_sig <= fifobout_sig & fifobout_sig(4 downto 2);

	end generate;



--==== ピクセル出力部 ================================================

	blank_out <= blankout_reg;

	r_out <= dotrout_reg;
	g_out <= dotgout_reg;
	b_out <= dotbout_reg;

	process (crtc_clk,reset) begin
		if (reset='1') then
			blank_reg   <= '1';
			blankout_reg<= '1';

		elsif (crtc_clk'event and crtc_clk='1') then
			if (fiforeq_sig='1') then
				blank_reg <= blank_sig;

				if (blank_reg='0') then
					dotrout_reg <= dotrout_sig;
					dotgout_reg <= dotgout_sig;
					dotbout_reg <= dotbout_sig;
					blankout_reg<= '0';
				else
					dotrout_reg <= (others=>'0');
					dotgout_reg <= (others=>'0');
					dotbout_reg <= (others=>'0');
					blankout_reg<= '1';
				end if;

			end if;
		end if;
	end process;


end RTL;



----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
