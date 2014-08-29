----------------------------------------------------------------------
-- TITLE : SuperJ-7 Render Command Controler (AMETHYST Edition)
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--   ALTER DATUM : 2003/05/19 -> 2003/08/07 (HERSTELLUNG)
--               : 2003/08/10 (FESTSTELLUNG)
--               : 2003/08/13 レンダリングサイクルを11クロック/pixに変更
--								→ PROCYON32では9クロック/pixへ戻した
--               : 2003/08/15 パフォーマンスチェック用のカウンタを追加
--               : 2003/12/27 CPUリードを４ワード先読みキャッシュへ変更
--
--     DATUM     : 2004/03/09 -> 2004/03/17 (HERSTELLUNG)
--               : 2004/11/07 Zバッファの読み込み・書き戻しをコメントアウト (FESTSTELLUNG)
--
--     DATUM     : 2006/10/09 -> 2006/11/28 (HERSTELLUNG)
--               : 2006/10/15 SDRAM初期化シーケンスを修正
--               : 2006/11/28 レンダリングシーケンスを修正 (FESTSTELLUNG)
--
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use work.SuperJ7_package.all;

entity SEQUENCER_CommandCtrl is
	port(
		clk				: in  std_logic;
		reset			: in  std_logic;

		rdena_assign	: out std_logic;
		crtcread_req	: in  std_logic :='0';
		crtcread_ack	: out std_logic;
		pcmread_req		: in  std_logic :='0';
		pcmread_ack		: out std_logic;
		cpuread_req		: in  std_logic :='0';
		cpuread_ack		: out std_logic;
		cpuwrite_req	: in  std_logic :='0';
		cpuwrite_ack	: out std_logic;
		refresh_req		: in  std_logic :='0';
		refresh_ack		: out std_logic;
		cpuint_ena		: in  std_logic :='1';

		render_state	: in  std_logic_vector(2 downto 0) := HALT;
		state_done		: out std_logic;
		cyc_counter		: in  std_logic_vector(8 downto 0) := (others=>'0');

		sdramif_rinc	: out std_logic;
		sdramif_cinc	: out std_logic;
		sdramif_cmd		: out std_logic_vector(3 downto 0);
		sdr_wrdata_req	: out std_logic;
		render_adsel	: out std_logic_vector(1 downto 0);
		render_cmd		: out std_logic_vector(3 downto 0);

		register_init	: out std_logic;
		render_cyc1st	: out std_logic;
		render_cyclast	: out std_logic;
		register_renew	: out std_logic;
		texture_renew	: out std_logic;
		texture_latch	: out std_logic;
		zbuffer_renew	: out std_logic
	);
end SEQUENCER_CommandCtrl;

architecture RTL of SEQUENCER_CommandCtrl is
	signal pointer_reg	: std_logic_vector(6 downto 0);
	signal cyccount_reg	: std_logic_vector(8 downto 0);
	signal maskcount_reg: std_logic_vector(2 downto 0);
	signal fillcyc8_reg	: std_logic;
	signal cycdone_reg	: std_logic;
	signal rendexit_reg	: std_logic;
	signal fillexit_reg	: std_logic;
	signal interrupt_sig: std_logic;
	signal bstlength_reg: std_logic_vector(1 downto 0);
	signal doneout_reg	: std_logic;

	signal resetreq_reg	: std_logic;

	component SEQUENCER_CommandRom
	port(
		inst_pointer	: in  std_logic_vector(6 downto 0);
		command_data	: out std_logic_vector(15 downto 0)
	);
	end component;
	signal instdata_sig	: std_logic_vector(15 downto 0);
	signal row_inc_reg	: std_logic;
	signal col_inc_reg	: std_logic;
	signal sdr_cmd_reg	: std_logic_vector(3 downto 0);
	signal rend_adr_reg	: std_logic_vector(1 downto 0);
	signal rend_cmd_reg	: std_logic_vector(3 downto 0);
	signal rinit_reg	: std_logic;
	signal rrenew_reg	: std_logic;
	signal trenew_reg	: std_logic;
	signal tlatch_reg	: std_logic;
	signal zrenew_reg	: std_logic;
	signal wr_req_reg	: std_logic;
	signal cyc1st_reg	: std_logic;


	----- マイクロコード処理テーブル ----------
	constant ADR_RESET		: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#00#,7);
	constant ADR_REFRESH	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#07#,7);
	constant ADR_REFRESHACK	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#07#,7);
	constant ADR_REFRESHEND	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#13#,7);
	constant ADR_RESETEND	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#17#,7);

	constant ADR_RENDERINIT	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#18#,7);
	constant ADR_RENDER		: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#1A#,7);
	constant ADR_RENDERCYC	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#1D#,7);
	constant ADR_RENDERDEC	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#22#,7);
	constant ADR_RENDERBRA	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#23#,7);
	constant ADR_RENDERJMP	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#25#,7);
	constant ADR_RENDERCLS	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#2A#,7);
	constant ADR_RENDEREND	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#2D#,7);

	constant ADR_BLOADINIT	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#30#,7);
	constant ADR_BLOAD		: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#32#,7);
	constant ADR_BLOADDEC	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#34#,7);
	constant ADR_BLOADCLS	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#35#,7);
	constant ADR_BLOADEND	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#38#,7);

	constant ADR_BSTOREINIT	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#3B#,7);
	constant ADR_BSTORE		: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#3D#,7);
	constant ADR_BSTOREDEC	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#3F#,7);
	constant ADR_BSTORECLS	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#40#,7);
	constant ADR_BSTOREEND	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#42#,7);

	constant ADR_LFILLINIT	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#44#,7);
	constant ADR_LFILL		: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#46#,7);
	constant ADR_LFILLDEC	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#48#,7);
	constant ADR_LFILLCLS	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#49#,7);
	constant ADR_LFILLEND	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#4B#,7);

	constant ADR_BREAD		: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#4C#,7);
	constant ADR_BREADACK	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#4C#,7);
	constant ADR_BREADRDE	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#51#,7);
	constant ADR_BREAD2DEC	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#51#,7);
	constant ADR_BREAD4DEC	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#53#,7);
	constant ADR_BREAD8DEC	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#57#,7);
	constant ADR_BREADCLS	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#60#,7);
	constant ADR_BREADEND	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#61#,7);

	constant ADR_CWRITE		: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#64#,7);
	constant ADR_CWRITEACK	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#64#,7);
	constant ADR_CWRITEEND	: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#6B#,7);

	constant ADR_IDLE		: std_logic_vector(6 downto 0) := CONV_STD_LOGIC_VECTOR(16#7F#,7);

	constant BREAD_FULL		: std_logic_vector(1 downto 0) := "11";
--	constant BREAD_2STOP	: std_logic_vector(1 downto 0) := "10";
	constant BREAD_4STOP	: std_logic_vector(1 downto 0) := "01";
	constant BREAD_8STOP	: std_logic_vector(1 downto 0) := "00";


begin

--==== ステートコントロール ==========================================

	process (clk,reset) begin
		if (reset='1') then
			pointer_reg  <= ADR_RESET;
			resetreq_reg <= '1';

		elsif(clk'event and clk='1') then
			case pointer_reg is

	----- リセットステート -----
			when ADR_RESETEND =>
				pointer_reg  <= ADR_IDLE;
				resetreq_reg <= '0';


	----- アイドルステート -----
			when ADR_IDLE =>

				if (crtcread_req='1') then			-- CRTCドットリード要求（優先度１）
					pointer_reg  <= ADR_BREAD;
					bstlength_reg<= BREAD_FULL;

				elsif (refresh_req='1') then		-- SDRAMリフレッシュ要求（優先度２）
					pointer_reg <= ADR_REFRESH;

				elsif (pcmread_req='1') then		-- PCM波形リード要求（優先度３）
					pointer_reg  <= ADR_BREAD;
					bstlength_reg<= BREAD_4STOP;

				elsif (cpuread_req='1') then		-- CPUリード要求（優先度４）
					pointer_reg  <= ADR_BREAD;
					bstlength_reg<= BREAD_8STOP;	-- ４ワード先読みキャッシュの場合

				elsif (cpuwrite_req='1') then		-- CPUライト要求（優先度４）
					pointer_reg <= ADR_CWRITE;

				else
					case render_state is			-- レンダリング要求（優先度５）
					when RENDER =>
						if (cycdone_reg='1') then
							pointer_reg <= ADR_RENDERINIT;
						else
							pointer_reg <= ADR_RENDER;
						end if;

					when LNFILL =>
						if (cycdone_reg='1') then
							pointer_reg <= ADR_LFILLINIT;
						else
							pointer_reg <= ADR_LFILL;
						end if;

--					when ZBPLOAD | LNPLOAD =>
--						if (cycdone_reg='1') then
--							pointer_reg <= ADR_BLOADINIT;
--						else
--							pointer_reg <= ADR_BLOAD;
--						end if;
--
--					when ZBWBACK | LNWBACK =>
--						if (cycdone_reg='1') then
--							pointer_reg <= ADR_BSTOREINIT;
--						else
--							pointer_reg <= ADR_BSTORE;
--						end if;

					when others =>
						pointer_reg <= ADR_IDLE;
					end case;

				end if;


	----- リフレッシュステート -----
			when ADR_REFRESHEND =>
				if (resetreq_reg = '0') then
					pointer_reg <= ADR_IDLE;
				else
					pointer_reg <= ADR_REFRESHEND + 1;
				end if;


	----- レンダリングステート -----
			when ADR_RENDERBRA =>
				if (rendexit_reg='1') then			-- 分岐はif～else～endif文＋即値代入の方が
					pointer_reg <= ADR_RENDERCLS;	-- LE数が少なくてすむ(以下同様)
				else
					pointer_reg <= ADR_RENDERBRA + 1;
				end if;

			when ADR_RENDERJMP =>
				pointer_reg  <= ADR_RENDERCYC;

			when ADR_RENDEREND =>
				pointer_reg <= ADR_IDLE;


	----- バッファ読み込みステート -----
--			when ADR_BLOADDEC =>
--				if (fillexit_reg='1') then
--					pointer_reg <= ADR_BLOADCLS;
--				else
--					pointer_reg <= ADR_BLOADDEC;
--				end if;
--
--			when ADR_BLOADEND =>
--				pointer_reg <= ADR_IDLE;


	----- バッファ書き戻しステート -----
--			when ADR_BSTOREDEC =>
--				if (fillexit_reg='1') then
--					pointer_reg <= ADR_BSTORECLS;
--				else
--					pointer_reg <= ADR_BSTOREDEC;
--				end if;
--
--			when ADR_BSTOREEND =>
--				pointer_reg <= ADR_IDLE;


	----- ラインフィルステート -----
			when ADR_LFILLDEC =>
				if (fillexit_reg='1') then
					pointer_reg <= ADR_LFILLCLS;
				else
					pointer_reg <= ADR_LFILLDEC;
				end if;

			when ADR_LFILLEND =>
				pointer_reg <= ADR_IDLE;


	----- SDRAMバーストリードステート -----
--			when ADR_BREAD2DEC =>					-- ２回でバーストストップ(CPUリード)
--				if (bstlength_reg=BREAD_2STOP) then
--					pointer_reg <= ADR_BREADCLS;
--				else
--					pointer_reg <= ADR_BREAD2DEC + 1;
--				end if;

			when ADR_BREAD4DEC =>					-- ４回でバーストストップ(PCM波形リード)
				if (bstlength_reg=BREAD_4STOP) then
					pointer_reg <= ADR_BREADCLS;
				else
					pointer_reg <= ADR_BREAD4DEC + 1;
				end if;

			when ADR_BREAD8DEC =>					-- ８回でバーストストップ(CPUキャッシュリード)
				if (bstlength_reg=BREAD_8STOP) then
					pointer_reg <= ADR_BREADCLS;
				else
					pointer_reg <= ADR_BREAD8DEC + 1;
				end if;

			when ADR_BREADEND =>					-- 16回バースト(CRTCリード)
				pointer_reg <= ADR_IDLE;


	----- SDRAMライトステート -----
			when ADR_CWRITEEND =>
				pointer_reg <= ADR_IDLE;


			when others =>
				pointer_reg <= pointer_reg + 1;
			end case;

		end if;
	end process;



--==== ブランチコントロール ==========================================

	state_done   <= doneout_reg;
	render_cyclast<= cycdone_reg;

	rdena_assign <= '1' when  pointer_reg=ADR_BREADRDE else '0';
	crtcread_ack <= '1' when (pointer_reg=ADR_BREADACK and bstlength_reg=BREAD_FULL) else '0';
	pcmread_ack  <= '1' when (pointer_reg=ADR_BREADACK and bstlength_reg=BREAD_4STOP) else '0';
	cpuread_ack  <= '1' when (pointer_reg=ADR_BREADACK and bstlength_reg=BREAD_8STOP) else '0';
	cpuwrite_ack <= '1' when  pointer_reg=ADR_CWRITEACK  else '0';
	refresh_ack  <= '1' when  pointer_reg=ADR_REFRESHACK else '0';

	interrupt_sig<= (crtcread_req or pcmread_req or refresh_req) when cpuint_ena='0' else
					(crtcread_req or pcmread_req or refresh_req or cpuread_req or cpuwrite_req);

	process (clk,reset) begin
		if (reset='1') then
			cycdone_reg <= '1';
			doneout_reg <= '0';

		elsif (clk'event and clk='1') then

	----- レジスタの初期化と終了条件 -----
			if (rinit_reg='1') then					-- レジスタ初期化インストラクションで初期化
				cyccount_reg <= cyc_counter;
				cycdone_reg  <= '0';

			elsif (pointer_reg=ADR_RENDERBRA or pointer_reg=ADR_BLOADDEC
					or pointer_reg=ADR_BSTOREDEC or pointer_reg=ADR_LFILLDEC) then
				cyccount_reg <= cyccount_reg + 1;	-- カウントアップ
				if (cyccount_reg=511) then
					cycdone_reg <= '1';				-- サイクル終了フラグ
				end if;

			end if;

	----- ステート終了信号の生成 -----
			if (pointer_reg=ADR_RENDERCLS or pointer_reg=ADR_BLOADCLS
					or pointer_reg=ADR_BSTORECLS or pointer_reg=ADR_LFILLCLS) then
				doneout_reg <= cycdone_reg;
			else
				doneout_reg <= '0';
			end if;

	----- フィルサイクルセットアップ -----
			case pointer_reg is
			when ADR_BLOAD | ADR_BSTORE | ADR_LFILL =>
				maskcount_reg <= "000";				-- サイクルカウンタをクリア
				fillcyc8_reg  <= '0';

				if (cyccount_reg=511) then			-- 残りサイクル数が１かどうかチェック
					fillexit_reg <= '1';
				else
					fillexit_reg <= '0';
				end if;

	----- フィルサイクル -----
			when ADR_BLOADDEC | ADR_BSTOREDEC | ADR_LFILLDEC =>
				if ((interrupt_sig='1' and fillcyc8_reg='1')or cyccount_reg=510) then
					fillexit_reg <= '1';			-- 割り込み要求かサイクル終了でEXIT
				end if;
	
				maskcount_reg <= maskcount_reg + 1;
				if (maskcount_reg="111") then		-- ただし、８サイクル回るまで割り込みはマスク
					fillcyc8_reg <= '1';
				end if;

	----- レンダリングサイクルセットアップ -----
			when ADR_RENDER =>
				rendexit_reg <= '0';				-- EXITフラグをクリア

	----- レンダリングサイクル -----
			when ADR_RENDERDEC =>
				if ((interrupt_sig='1' and cyccount_reg/=511)or cycdone_reg='1') then
					rendexit_reg <= '1';			-- 割り込み要求かサイクル終了でEXIT
				end if;

			when others =>
			end case;

		end if;
	end process;



--==== コマンドデコーダ ==============================================

	sdramif_rinc  <= row_inc_reg;
	sdramif_cinc  <= col_inc_reg;
	sdramif_cmd   <= sdr_cmd_reg;
	sdr_wrdata_req<= wr_req_reg;
	render_adsel  <= rend_adr_reg;
	render_cmd    <= rend_cmd_reg;

	register_init <= rinit_reg;
	render_cyc1st <= cyc1st_reg;
	register_renew<= rrenew_reg;
	texture_renew <= trenew_reg;
	texture_latch <= tlatch_reg;
	zbuffer_renew <= zrenew_reg;


	RU : SEQUENCER_CommandRom port map(
		inst_pointer	=> pointer_reg,
		command_data	=> instdata_sig
	);


	process (clk,reset) begin
		if (reset='1') then
			sdr_cmd_reg  <= CMD_NOP;
			rend_cmd_reg <= PAUSE;
			rinit_reg    <= '0';
			cyc1st_reg   <= '0';
			rrenew_reg   <= '0';
			trenew_reg   <= '0';
			tlatch_reg   <= '0';
			zrenew_reg   <= '0';

		elsif(clk'event and clk='1') then			-- 各種制御信号の生成
			row_inc_reg  <= instdata_sig(15);
			col_inc_reg  <= instdata_sig(14);
			sdr_cmd_reg  <= instdata_sig(13 downto 10);
			rend_adr_reg <= instdata_sig(9 downto 8);
			rend_cmd_reg <= instdata_sig(7 downto 4);
			rinit_reg    <= instdata_sig(3);
			trenew_reg   <= instdata_sig(2);
			rrenew_reg   <= instdata_sig(1);
			tlatch_reg   <= instdata_sig(0);

			if (cyc1st_reg='0') then				-- Ｚバッファ更新信号の生成
				zrenew_reg <= instdata_sig(1);
			else
				zrenew_reg <= '0';
			end if;
													-- ライトリクエスト信号の生成
			if ( (instdata_sig(13 downto 10)=CMD_WR) or 
					(instdata_sig(13 downto 10)=CMD_WRA) ) then
				wr_req_reg <= '1';
			else
				wr_req_reg <= '0';
			end if;

			if (rinit_reg='1') then					-- ファーストサイクル信号の生成
				cyc1st_reg <= '1';
			elsif (rrenew_reg='1') then
				cyc1st_reg <= '0';
			end if;

		end if;
	end process;


end RTL;



----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
