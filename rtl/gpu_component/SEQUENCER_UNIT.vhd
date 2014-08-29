----------------------------------------------------------------------
-- TITLE : SuperJ-7 Rendering Sequencer Unit (AMETHYST Edition)
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--   ALTER DATUM : 2003/07/01 -> 2003/08/10 (HERSTELLUNG)
--               : 2003/08/12 (FESTSTELLUNG)
--               : 2003/08/25 レンダリング中のCPUライト処理で落ちるのを修正
--               : 2003/12/27 CPUリードに４ワード先読みバッファを追加
--
--     DATUM     : 2004/03/09 -> 2004/04/18 (HERSTELLUNG)
--               : 2004/11/07 CPUリードのdone信号を0waitで返せるように変更
--
--     DATUM     : 2006/11/26 -> 2006/11/26 1chipMSX対応 (HERSTELLUNG)
--
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use work.SuperJ7_package.all;

entity SEQUENCER_UNIT is
	port(
		clk				: in  std_logic;
		reset			: in  std_logic;

		----- 外部割り込みスレーブ信号 -----------
		crtcread_addr	: in  std_logic_vector(24 downto 1)	:=(others=>'X');
		crtcread_req	: in  std_logic						:='0';
		crtcread_dena	: out std_logic;
		crtcread_data	: out std_logic_vector(15 downto 0);

		pcmread_addr	: in  std_logic_vector(24 downto 1)	:=(others=>'X');
		pcmread_req		: in  std_logic						:='0';
		pcmread_dena	: out std_logic;
		pcmread_data	: out std_logic_vector(15 downto 0);

		cpuint_ena		: in  std_logic;
		cpu_req			: in  std_logic;
		cpu_done		: out std_logic;
		cpu_address		: in  std_logic_vector(24 downto 2);
		cpu_read		: in  std_logic;
		cpu_rddata		: out std_logic_vector(31 downto 0);
		cpu_write		: in  std_logic;
		cpu_wrdata		: in  std_logic_vector(31 downto 0);
		cpu_byteenable	: in  std_logic_vector(3 downto 0);

		----- SDRAMデータ信号 -----------
		sdr_rddata_ena	: in  std_logic;
		sdr_rddata		: in  std_logic_vector(15 downto 0);
		ext_address		: out std_logic_vector(24 downto 1);
		ext_wrdata		: out std_logic_vector(15 downto 0);
		ext_wrdqm		: out std_logic_vector(1 downto 0);

		sdramif_rinc	: out std_logic;
		sdramif_cinc	: out std_logic;
		sdramif_cmd		: out std_logic_vector(3 downto 0);
		sdr_wrdata_req	: out std_logic;

		----- レンダリングエンジン制御信号 -----------
		render_adsel	: out std_logic_vector(1 downto 0);
		render_rinitsel	: out std_logic_vector(2 downto 0);
		render_cmd		: out std_logic_vector(3 downto 0);

		register_init	: out std_logic;
		render_cyc1st	: out std_logic;
		render_cyclast	: out std_logic;
		register_renew	: out std_logic;
		texture_renew	: out std_logic;
		texture_latch	: out std_logic;
		zbuffer_renew	: out std_logic;

		reg_renderena	: in  std_logic;
		reg_rmode		: in  std_logic_vector(1 downto 0);
		reg_zbuffena	: in  std_logic						:='0';
		reg_rcount		: in  std_logic_vector(8 downto 0);
		render_done		: out std_logic;
		zbuff_stp_ena	: out std_logic
	);
end SEQUENCER_UNIT;

architecture RTL of SEQUENCER_UNIT is
	type CACHEMEM_STATE is (CPU_IDLE,CPU_WRITE1,CPU_WRITE2,CPU_NEGATE,
							MEM_FILL1,MEM_FILL2,MEM_FILL3,MEM_FILL4,
							MEM_FILL5,MEM_FILL6,MEM_FILL7,MEM_FILL8);
	signal cache_state	: CACHEMEM_STATE;
	signal cache_mem0,cache_mem1,cache_mem2,cache_mem3	: std_logic_vector(31 downto 0);
	signal cacheaddr_reg: std_logic_vector(24 downto 4);
	signal cachefill_reg: std_logic;

	signal cpurirq_reg	: std_logic;
	signal cpuwirq_reg	: std_logic;
	signal cpudone_reg	: std_logic;
	signal cpurdena_sig	: std_logic;
	signal wrdatsel_reg	: std_logic;
	signal extwrdata_reg: std_logic_vector(31 downto 0);
	signal extwrdqm_reg	: std_logic_vector(3 downto 0);

	signal refirq_reg	: std_logic;
	signal refcount_reg	: std_logic_vector(11 downto 0);

	signal rdena_reg	: std_logic;
	signal rdenafall_sig: std_logic;
	signal crtcirq_reg	: std_logic;
	signal crtcirq_done	: std_logic;
	signal pcmirq_reg	: std_logic;
	signal pcmirq_done	: std_logic;
	signal denamask_reg	: std_logic_vector(1 downto 0);
	signal denamask_next: std_logic_vector(1 downto 0);
	signal extaddr_reg	: std_logic_vector(24 downto 1);

	constant DIS_RDENA	: std_logic_vector(1 downto 0) := "11";
	constant CRTC_RDENA	: std_logic_vector(1 downto 0) := "00";
	constant PCM_RDENA	: std_logic_vector(1 downto 0) := "01";
	constant CPU_RDENA	: std_logic_vector(1 downto 0) := "10";

	signal render_state : std_logic_vector(2 downto 0);
	signal renderena_alt: std_logic;
	signal statedone_sig: std_logic;
	signal doneout_reg	: std_logic;
	signal zbstpena_reg	: std_logic;


	component SEQUENCER_CommandCtrl
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

		render_state	: in  std_logic_vector(2 downto 0);
		state_done		: out std_logic;
		cyc_counter		: in  std_logic_vector(8 downto 0);

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
	end component;
	signal rdenaassign_sig	: std_logic;
	signal wrdatareq_sig	: std_logic;
	signal crtcreadack_sig	: std_logic;
	signal pcmreadack_sig	: std_logic;
	signal cpureadack_sig	: std_logic;
	signal cpuwriteack_sig	: std_logic;
	signal refreshack_sig	: std_logic;


begin

--==== レンダリングシーケンサ ========================================

	U0 : SEQUENCER_CommandCtrl
	port map(
		clk				=> clk,
		reset			=> reset,

		rdena_assign	=> rdenaassign_sig,
		crtcread_req	=> crtcirq_reg,
		crtcread_ack	=> crtcreadack_sig,
		pcmread_req		=> pcmirq_reg,
		pcmread_ack		=> pcmreadack_sig,
		cpuread_req		=> cpurirq_reg,
		cpuread_ack		=> cpureadack_sig,
		cpuwrite_req	=> cpuwirq_reg,
		cpuwrite_ack	=> cpuwriteack_sig,
		refresh_req		=> refirq_reg,
		refresh_ack		=> refreshack_sig,
		cpuint_ena		=> cpuint_ena,

		render_state	=> render_state,
		state_done		=> statedone_sig,
		cyc_counter		=> reg_rcount,

		sdramif_rinc	=> sdramif_rinc,
		sdramif_cinc	=> sdramif_cinc,
		sdramif_cmd		=> sdramif_cmd,
		sdr_wrdata_req	=> wrdatareq_sig,
		render_adsel	=> render_adsel,
		render_cmd		=> render_cmd,

		register_init	=> register_init,
		render_cyc1st	=> render_cyc1st,
		render_cyclast	=> render_cyclast,
		register_renew	=> register_renew,
		texture_renew	=> texture_renew,
		texture_latch	=> texture_latch,
		zbuffer_renew	=> zbuffer_renew
	);

	sdr_wrdata_req <= wrdatareq_sig;


	----- レンダリングステートの処理 ----------

	render_rinitsel<= render_state;			-- レンダリングユニットのレジスタ初期値選択信号
	render_done    <= doneout_reg;			-- レジスタユニットの描画クリア信号
	zbuff_stp_ena  <= zbstpena_reg;			-- ラインコピー書き戻しフラグ

	process (clk,reset) begin
		if (reset='1') then
			render_state <= HALT;
			doneout_reg  <= '0';
			zbstpena_reg <= '0';

		elsif(clk'event and clk='1') then
			renderena_alt <= reg_renderena;

			case render_state is
--			when ZBPLOAD =>							-- Ｚバッファのプリフィル
--				if (statedone_sig='1') then
--					render_state <= RENDER;
--				else
--					render_state <= ZBPLOAD;
--				end if;

			when RENDER =>							-- レンダリング
				if (statedone_sig='1') then
--					if (reg_zbuffena='1') then
--						render_state <= ZBWBACK;
--					else
						render_state <= HALT;
						doneout_reg  <= '1';
--					end if;
				else
					render_state <= RENDER;
				end if;

--			when ZBWBACK =>							-- Ｚバッファのライトバック
--				if (statedone_sig='1') then
--					render_state <= HALT;
--					doneout_reg  <= '1';
--				else
--					render_state <= ZBWBACK;
--				end if;

--			when LNPLOAD =>							-- コピーバッファのプリフィル
--				if (statedone_sig='1') then
--					render_state <= LNWBACK;
--					zbstpena_reg <= '1';
--				else
--					render_state <= LNPLOAD;
--				end if;

--			when LNWBACK =>							-- コピーバッファのライトバック
--				if (statedone_sig='1') then
--					render_state <= HALT;
--					doneout_reg  <= '1';
--					zbstpena_reg <= '0';
--				else
--					render_state <= LNWBACK;
--				end if;

			when LNFILL =>							-- ラインフィル
				if (statedone_sig='1') then
					render_state <= HALT;
					doneout_reg  <= '1';
				else
					render_state <= LNFILL;
				end if;

			when others =>							-- アイドリングと各ステートへの分岐
				doneout_reg  <= '0';
				if (renderena_alt='0' and reg_renderena='1') then
					if (reg_rmode=RMODE_LFILL) then
						render_state <= LNFILL;

--					elsif (reg_rmode=RMODE_LCOPY) then
--						render_state <= LNPLOAD;

					else
--						if (reg_zbuffena='1') then
--							render_state <= ZBPLOAD;
--						else
							render_state <= RENDER;
--						end if;
					end if;
				else
					render_state <= HALT;			-- ステートレジスタがHALTから移行することで
				end if;								-- 各サイクルがスタートする

			end case;

		end if;
	end process;



--==== 割り込み処理部 ================================================

	----- ext_addressとsdr_rddata_ena出力処理 ----------

	ext_address  <= extaddr_reg;

	crtcread_dena<= sdr_rddata_ena when denamask_reg=CRTC_RDENA else '0';
	crtcread_data<= sdr_rddata;
	pcmread_dena <= sdr_rddata_ena when denamask_reg=PCM_RDENA else '0';
	pcmread_data <= sdr_rddata;
	cpurdena_sig <= sdr_rddata_ena when denamask_reg=CPU_RDENA else '0';

	process (clk,reset) begin
		if (reset='1') then
			denamask_reg <= DIS_RDENA;
			denamask_next<= DIS_RDENA;

		elsif(clk'event and clk='1') then

			if (crtcreadack_sig='1') then			-- ACKでアドレスを取得、sdr_rddata_enaの出力先を予約
				extaddr_reg  <= crtcread_addr;
				denamask_next<= CRTC_RDENA;

			elsif (pcmreadack_sig='1') then
				extaddr_reg  <= pcmread_addr;
				denamask_next<= PCM_RDENA;

			elsif (cpureadack_sig='1') then
				extaddr_reg  <= cpu_address(24 downto 4) & "000";
				denamask_next<= CPU_RDENA;

			elsif (cpuwriteack_sig='1') then
				extaddr_reg  <= cpu_address & '0';

			end if;

			if (rdenaassign_sig='1') then			-- 予約した出力先にsdr_rddata_enaをアサイン
				denamask_reg <= denamask_next;

			elsif (rdenafall_sig='1') then			-- sdr_rddata_enaの立ち下がりでクローズ
				denamask_reg <= DIS_RDENA;

			end if;

		end if;
	end process;


	----- sdr_rddata_enaの立ち下がり検出 ----------

	rdenafall_sig <= '1' when(rdena_reg='1' and sdr_rddata_ena='0') else '0';

	process (clk,reset) begin
		if (reset='1') then
			rdena_reg <= '0';

		elsif(clk'event and clk='1') then
			rdena_reg <= sdr_rddata_ena;

		end if;
	end process;


	----- リフレッシュ割り込みのフラグ処理 ----------

	process (clk,reset) begin
		if (reset='1') then
			refcount_reg <= (others=>'0');
			refirq_reg   <= '0';

		elsif(clk'event and clk='1') then
			if (refreshack_sig='1') then
				refcount_reg <= (others=>'0');
				refirq_reg   <= '0';

			else
				if (refirq_reg='0') then
					refcount_reg <= refcount_reg + 1;
					if (refcount_reg=REFRESHINT) then
						refirq_reg <= '1';
					end if;
				end if;

			end if;
		end if;
	end process;


	----- CRTC割り込み・PCM割り込みのフラグ処理 ----------

	process (clk,reset) begin
		if (reset='1') then
			crtcirq_reg  <= '0';
			crtcirq_done <= '1';
			pcmirq_reg   <= '0';
			pcmirq_done  <= '1';

		elsif(clk'event and clk='1') then

			if (crtcirq_done='1') then				-- CRTCリード要求の処理
				if (crtcread_req='1') then
					crtcirq_reg <= '1';
					crtcirq_done<= '0';
				end if;
			else
				if (crtcreadack_sig='1') then
					crtcirq_reg <= '0';
				end if;
				if (rdenafall_sig='1' and denamask_reg=CRTC_RDENA) then
					crtcirq_done <= '1';
				end if;
			end if;

			if (pcmirq_done='1') then				-- PCMリード要求の処理
				if (pcmread_req='1') then
					pcmirq_reg <= '1';
					pcmirq_done<= '0';
				end if;
			else
				if (pcmreadack_sig='1') then
					pcmirq_reg <= '0';
				end if;
				if (rdenafall_sig='1' and denamask_reg=PCM_RDENA) then
					pcmirq_done <= '1';
				end if;
			end if;

		end if;
	end process;



--==== メモリインターフェース部 ======================================
--・メモ
--　　Avalonバスと同クロックで動作させる場合は cpu_done を waitrequest_n に
--　　読み替え、CPU_NEGATEステート内のcpu_reqネゲート待ちをスキップさせる。

	cpu_done <= '1' when( ( (cpu_read='1')and(cachefill_reg='1')and(cacheaddr_reg=cpu_address(24 downto 4)) )
						or( cache_state=CPU_NEGATE )
						)
					else '0';
--	cpu_done <= cpudone_reg;

	with cpu_address(3 downto 2) select cpu_rddata <=
		cache_mem0	when "00",
		cache_mem1	when "01",
		cache_mem2	when "10",
		cache_mem3	when others;

	ext_wrdata <= extwrdata_reg(15 downto 0) when wrdatsel_reg='0' else extwrdata_reg(31 downto 16);
	ext_wrdqm  <= extwrdqm_reg(1 downto 0)   when wrdatsel_reg='0' else extwrdqm_reg(3 downto 2);

	----- ＣＰＵリードライト割り込みフラグ処理とバスサイジング ----------

	process(clk,reset)begin
		if (reset='1') then
			cache_state   <= CPU_IDLE;
--			cpudone_reg   <= '0';
			cpurirq_reg   <= '0';
			cpuwirq_reg   <= '0';
			cachefill_reg <= '0';

		elsif (clk'event and clk='1') then
			case cache_state is
			when CPU_IDLE =>
				if (crtcread_req='1') then			-- CRTC要求が入っていたら先行させる 
					cache_state <= CPU_IDLE;

				elsif (cpu_read='1') then
--					if ( (cachefill_reg='1')and(cacheaddr_reg=cpu_address(24 downto 4)) ) then
--						cache_state <= CPU_NEGATE;
--						cpudone_reg <= '1';
--					else
--						cache_state <= MEM_FILL1;
--						cpurirq_reg <= '1';
--					end if;
					if ( (cachefill_reg='0')or(cacheaddr_reg/=cpu_address(24 downto 4)) ) then
						cache_state <= MEM_FILL1;
						cpurirq_reg <= '1';
					end if;

				elsif (cpu_write='1') then
					cache_state   <= CPU_WRITE1;
					cpuwirq_reg   <= '1';
					extwrdata_reg <= cpu_wrdata;
					extwrdqm_reg  <= not cpu_byteenable;
					if (cacheaddr_reg=cpu_address(24 downto 4)) then
						cachefill_reg <= '0';
					end if;

				end if;


			when MEM_FILL1 =>
				if (cpureadack_sig='1') then		-- cpuread_ackが返ったら割り込み要求をクリア
					cpurirq_reg <= '0';
				end if;
				if (cpurdena_sig='0') then			-- データが出力され始めるまで待つ
					cache_state <= MEM_FILL1;
				else
					cache_state <= MEM_FILL2;		-- １個めのデータをラッチ
					cache_mem0(15 downto 0) <= sdr_rddata;
				end if;
			when MEM_FILL2 =>
				cache_state <= MEM_FILL3;			-- ２個めのデータをセル０の上位16ビットにラッチ
				cache_mem0(31 downto 16) <= sdr_rddata;
			when MEM_FILL3 =>
				cache_state <= MEM_FILL4;			-- ３個めのデータをセル１の下位16ビットにラッチ
				cache_mem1(15 downto 0)  <= sdr_rddata;
			when MEM_FILL4 =>
				cache_state <= MEM_FILL5;			-- ４個めのデータをセル１の上位16ビットにラッチ
				cache_mem1(31 downto 16) <= sdr_rddata;
			when MEM_FILL5 =>
				cache_state <= MEM_FILL6;			-- ５個めのデータをセル２の下位16ビットにラッチ
				cache_mem2(15 downto 0)  <= sdr_rddata;
			when MEM_FILL6 =>
				cache_state <= MEM_FILL7;			-- ６個めのデータをセル２の上位16ビットにラッチ
				cache_mem2(31 downto 16) <= sdr_rddata;
			when MEM_FILL7 =>
				cache_state <= MEM_FILL8;			-- ７個めのデータをセル３の下位16ビットにラッチ
				cache_mem3(15 downto 0)  <= sdr_rddata;
			when MEM_FILL8 =>
				cache_state <= CPU_NEGATE;			-- ８個めのデータをセル０の上位16ビットにラッチ
				cache_mem3(31 downto 16) <= sdr_rddata;
--				cpudone_reg  <= '1';
				cachefill_reg<= '1';
				cacheaddr_reg<= cpu_address(24 downto 4);


			when CPU_WRITE1 =>
				if (cpuwriteack_sig='1') then		-- cpuwrite_ackが返るまで待つ
					cache_state <= CPU_WRITE2;
					cpuwirq_reg <= '0';				-- cpuwrite_ackが返ったら割り込み要求をクリア
--				else
--					cache_state <= CPU_WRITE1;
				end if;
			when CPU_WRITE2 =>
				if (wrdatareq_sig='1') then			-- データ要求が来るまで待つ
					cache_state <= CPU_NEGATE;
					wrdatsel_reg<= '0';				-- 書き込みデータの下位16ビットを選択
--					cpudone_reg <= '1';
--				else
--					cache_state <= CPU_WRITE2;
				end if;


			when CPU_NEGATE =>
				wrdatsel_reg <= '1';				-- 書き込みデータの上位16ビットを選択
--				cpudone_reg  <= '0';
--				if (cpu_req='0') then				-- cpuアクセスが終了するまで待つ
					cache_state <= CPU_IDLE;		-- 等速でAvalonバスと接続している場合は待たない
--				else
--					cache_state <= CPU_NEGATE;
--				end if;

			end case;


		end if;
	end process;


end RTL;



----------------------------------------------------------------------
--   (C)2003-2006 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
