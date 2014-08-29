----------------------------------------------------------------------
-- TITLE : SuperJ-7 CRTC Video Sync Generator - Sub Program
--
--     VERFASSER : S.OSAFUNE (J-7SYSTEM Works)
--     DATUM     : 2003/06/26 -> 2003/06/27 (HERSTELLUNG)
--               : 2003/06/30 (FESTSTELLUNG)
--               : 2003/08/06 DACクロックを反転・fifo_reqのブランクマスクを廃止
--               : 2003/08/08 generic文を追加
--               : 2006/12/06 レジスタセレクタビットを修正
--               : 2007/01/09 スキャンイネーブル信号を追加
--               : 2007/02/28 DACクロックデューティを調整 (NEUBEARBEITUNG)
----------------------------------------------------------------------

-- SubAddress  Register Name          Rande (BitMuster)
--         0    HTotal                  9-0: 0 ～ 1023 
--         1    HSyncEnd                6-0: 0 ～ 127
--         2    HViewStart              9-0: 0 ～ 1023
--         3    HViewEnd                9-0: 0 ～ 1023
--         4    VTotal                  9-0: 0 ～ 1023
--         5    VSyncEnd                4-0: 0 ～ 31
--         6    VViewStart              9-0: 0 ～ 1023
--         7    VViewEnd                9-0: 0 ～ 1023

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use work.SuperJ7_package.all;

entity CRTC_VideoSyncGen is
	generic(
		DEFAULT_MODE	: string;
		SYNC_REGISTER	: string;

		INIT_DOTCOUNT	: integer := 0;
		INIT_LINENUM	: integer := 0
	);
	port(
		crtc_clk	: in  std_logic;
		reset		: in  std_logic;
		dotscan_ena	: in  std_logic := '1';

		fifo_reset	: out std_logic;
		dotdiv_ref	: in  std_logic_vector(3 downto 0);

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
end CRTC_VideoSyncGen;

architecture RTL of CRTC_VideoSyncGen is
	type STATE is (SCAN_RESET,PIX_READ,PIX_WAIT,PIX_LATCH);
	signal pixel_state : STATE;

	signal dotscanref_reg: std_logic;
	signal dotcount_reg  : std_logic_vector(9 downto 0);
	signal linecount_reg : std_logic_vector(9 downto 0);
	signal dotdivref_reg : std_logic_vector(3 downto 0);
	signal dotdiv_reg    : std_logic_vector(3 downto 0);
	signal waitcount_reg : std_logic_vector(3 downto 0);
	signal daccount_reg  : std_logic_vector(2 downto 0);
	signal fiforeq_reg   : std_logic;
	signal fiforeset_reg : std_logic;
	signal daclatch_reg  : std_logic;
	signal hsync_reg     : std_logic;
	signal vsync_reg     : std_logic;
	signal hblank_reg    : std_logic;
	signal vblank_reg    : std_logic;

	signal rddatal_sig   : std_logic_vector(15 downto 0);
	signal regselect_sig : std_logic_vector(2 downto 0);
	signal htotal_reg    : std_logic_vector(9 downto 0);	-- 水平トータルドット数 
	signal hsyncend_reg  : std_logic_vector(6 downto 0);	-- HSYNC終了ドット 
	signal hviewsta_reg  : std_logic_vector(9 downto 0);	-- 表示開始ドット 
	signal hviewend_reg  : std_logic_vector(9 downto 0);	-- 表示終了ドット 
	signal vtotal_reg    : std_logic_vector(9 downto 0);	-- 垂直トータルライン数 
	signal vsyncend_reg  : std_logic_vector(4 downto 0);	-- VSYNC終了ライン 
	signal vviewsta_reg  : std_logic_vector(9 downto 0);	-- 表示開始ライン 
	signal vviewend_reg  : std_logic_vector(9 downto 0);	-- 表示終了ライン 

	signal INIT_HTOTAL		: integer;
	signal INIT_HSYNCEND	: integer;
	signal INIT_HVIEWSTA	: integer;
	signal INIT_HVIEWEND	: integer;
	signal INIT_VTOTAL		: integer;
	signal INIT_VSYNCEND	: integer;
	signal INIT_VVIEWSTA	: integer;
	signal INIT_VVIEWEND	: integer;
begin

--==== 初期値シグナル設定 ============================================

GEN_31kHz512x480 : if (DEFAULT_MODE = "31kHz512x480") generate

	INIT_HTOTAL   <= HTOTAL_31kHz512x480;
	INIT_HSYNCEND <= HSYNCEND_31kHz512x480;
	INIT_HVIEWSTA <= HVIEWSTA_31kHz512x480;
	INIT_HVIEWEND <= HVIEWEND_31kHz512x480;
	INIT_VTOTAL   <= VTOTAL_31kHz512x480;
	INIT_VSYNCEND <= VSYNCEND_31kHz512x480;
	INIT_VVIEWSTA <= VVIEWSTA_31kHz512x480;
	INIT_VVIEWEND <= VVIEWEND_31kHz512x480;

end generate;
GEN_31kHz384x240 : if (DEFAULT_MODE = "31kHz384x240") generate

	INIT_HTOTAL   <= HTOTAL_31kHz384x240;
	INIT_HSYNCEND <= HSYNCEND_31kHz384x240;
	INIT_HVIEWSTA <= HVIEWSTA_31kHz384x240;
	INIT_HVIEWEND <= HVIEWEND_31kHz384x240;
	INIT_VTOTAL   <= VTOTAL_31kHz384x240;
	INIT_VSYNCEND <= VSYNCEND_31kHz384x240;
	INIT_VVIEWSTA <= VVIEWSTA_31kHz384x240;
	INIT_VVIEWEND <= VVIEWEND_31kHz384x240;

end generate;
GEN_31kHz320x240 : if (DEFAULT_MODE = "31kHz320x240") generate

	INIT_HTOTAL   <= HTOTAL_31kHz320x240;
	INIT_HSYNCEND <= HSYNCEND_31kHz320x240;
	INIT_HVIEWSTA <= HVIEWSTA_31kHz320x240;
	INIT_HVIEWEND <= HVIEWEND_31kHz320x240;
	INIT_VTOTAL   <= VTOTAL_31kHz320x240;
	INIT_VSYNCEND <= VSYNCEND_31kHz320x240;
	INIT_VVIEWSTA <= VVIEWSTA_31kHz320x240;
	INIT_VVIEWEND <= VVIEWEND_31kHz320x240;

end generate;

GEN_15kHz512x240 : if (DEFAULT_MODE = "15kHz512x240") generate

	INIT_HTOTAL   <= HTOTAL_15kHz512x240;
	INIT_HSYNCEND <= HSYNCEND_15kHz512x240;
	INIT_HVIEWSTA <= HVIEWSTA_15kHz512x240;
	INIT_HVIEWEND <= HVIEWEND_15kHz512x240;
	INIT_VTOTAL   <= VTOTAL_15kHz512x240;
	INIT_VSYNCEND <= VSYNCEND_15kHz512x240;
	INIT_VVIEWSTA <= VVIEWSTA_15kHz512x240;
	INIT_VVIEWEND <= VVIEWEND_15kHz512x240;

end generate;
GEN_15kHz384x240 : if (DEFAULT_MODE = "15kHz384x240") generate

	INIT_HTOTAL   <= HTOTAL_15kHz384x240;
	INIT_HSYNCEND <= HSYNCEND_15kHz384x240;
	INIT_HVIEWSTA <= HVIEWSTA_15kHz384x240;
	INIT_HVIEWEND <= HVIEWEND_15kHz384x240;
	INIT_VTOTAL   <= VTOTAL_15kHz384x240;
	INIT_VSYNCEND <= VSYNCEND_15kHz384x240;
	INIT_VVIEWSTA <= VVIEWSTA_15kHz384x240;
	INIT_VVIEWEND <= VVIEWEND_15kHz384x240;

end generate;
GEN_15kHz320x240 : if (DEFAULT_MODE = "15kHz320x240") generate

	INIT_HTOTAL   <= HTOTAL_15kHz320x240;
	INIT_HSYNCEND <= HSYNCEND_15kHz320x240;
	INIT_HVIEWSTA <= HVIEWSTA_15kHz320x240;
	INIT_HVIEWEND <= HVIEWEND_15kHz320x240;
	INIT_VTOTAL   <= VTOTAL_15kHz320x240;
	INIT_VSYNCEND <= VSYNCEND_15kHz320x240;
	INIT_VVIEWSTA <= VVIEWSTA_15kHz320x240;
	INIT_VVIEWEND <= VVIEWEND_15kHz320x240;

end generate;
GEN_15kHz288x240 : if (DEFAULT_MODE = "15kHz288x240") generate

	INIT_HTOTAL   <= HTOTAL_15kHz288x240;
	INIT_HSYNCEND <= HSYNCEND_15kHz288x240;
	INIT_HVIEWSTA <= HVIEWSTA_15kHz288x240;
	INIT_HVIEWEND <= HVIEWEND_15kHz288x240;
	INIT_VTOTAL   <= VTOTAL_15kHz288x240;
	INIT_VSYNCEND <= VSYNCEND_15kHz288x240;
	INIT_VVIEWSTA <= VVIEWSTA_15kHz288x240;
	INIT_VVIEWEND <= VVIEWEND_15kHz288x240;

end generate;
GEN_LTA042B010F : if (DEFAULT_MODE = "LTA042B010F") generate

	INIT_HTOTAL   <= HTOTAL_LTA042B010F;
	INIT_HSYNCEND <= HSYNCEND_LTA042B010F;
	INIT_HVIEWSTA <= HVIEWSTA_LTA042B010F;
	INIT_HVIEWEND <= HVIEWEND_LTA042B010F;
	INIT_VTOTAL   <= VTOTAL_LTA042B010F;
	INIT_VSYNCEND <= VSYNCEND_LTA042B010F;
	INIT_VVIEWSTA <= VVIEWSTA_LTA042B010F;
	INIT_VVIEWEND <= VVIEWEND_LTA042B010F;

end generate;



--==== 同期信号生成部 ================================================

	----- ポート出力 ----------
		fifo_reset<= fiforeset_reg;
		hsync     <= hsync_reg;
		vsync     <= vsync_reg;
		hblank    <= hblank_reg;
		vblank    <= vblank_reg;
		linenum   <= linecount_reg;
		fifo_req  <= fiforeq_reg;
		dac_latch <= daclatch_reg;


	----- ドットクロック・同期信号生成 ----------
	process (crtc_clk,reset) begin
		if (reset='1') then
			pixel_state <= SCAN_RESET;
			dotdivref_reg  <= (others=>'0');
			dotscanref_reg <= '0';

		elsif(crtc_clk'event and crtc_clk='1') then
			dotdivref_reg <= dotdiv_ref;			-- dotdiv_refを同期化 
			dotscanref_reg<= dotscan_ena;			-- dotscanを同期化 

			case pixel_state is
			when SCAN_RESET =>
				if (dotscanref_reg='1') then
					pixel_state <= PIX_READ;
				else
					pixel_state <= SCAN_RESET;
				end if;
				dotcount_reg <= CONV_STD_LOGIC_VECTOR(INIT_DOTCOUNT,10);
				linecount_reg<= CONV_STD_LOGIC_VECTOR(INIT_LINENUM,10);
				fiforeq_reg  <= '0';
				fiforeset_reg<= '1';
--				daclatch_reg <= '0';
				hsync_reg    <= '1';
				vsync_reg    <= '1';
				hblank_reg   <= '1';
				vblank_reg   <= '1';


			when PIX_READ =>
				pixel_state   <= PIX_WAIT;
				waitcount_reg <= "0000";
				dotdiv_reg    <= dotdivref_reg;
				fiforeq_reg   <= '1';
--				daclatch_reg  <= '0';

				if (dotcount_reg=0) then
					fiforeset_reg<= '1';
					hsync_reg    <= '0';
					hblank_reg   <= '1';

					if (linecount_reg=0) then
						vsync_reg <= '0';
					elsif (linecount_reg=vsyncend_reg) then
						vsync_reg <= '1';
					end if;
					if((linecount_reg=0)or(linecount_reg=vviewend_reg))then
						vblank_reg <= '1';
					elsif (linecount_reg=vviewsta_reg) then
						vblank_reg <= '0';
					end if;

				else
					fiforeset_reg <= '0';

					if (dotcount_reg=hsyncend_reg) then
						hsync_reg <= '1';
					end if;
					if (dotcount_reg=hviewend_reg) then
						hblank_reg <= '1';
					elsif (dotcount_reg=hviewsta_reg) then
						hblank_reg <= '0';
					end if;

				end if;


			when PIX_WAIT =>
				fiforeq_reg   <= '0';
				waitcount_reg <= waitcount_reg + 1;

				if (waitcount_reg=dotdiv_reg) then
					pixel_state <= PIX_LATCH;
				else
					pixel_state <= PIX_WAIT;
				end if;


			when PIX_LATCH=>
				if (dotscanref_reg='1') then
					pixel_state <= PIX_READ;
				else
					pixel_state <= SCAN_RESET;
				end if;
--				daclatch_reg <= '1';

--				if (dotcount_reg<htotal_reg) then
--					dotcount_reg <= dotcount_reg + 1;
--				else
--					dotcount_reg <= (others=>'0');
--					if (linecount_reg<vtotal_reg) then
--						linecount_reg <= linecount_reg + 1;
--					else
--						linecount_reg <= (others=>'0');
--					end if;
--				end if;
				if (dotcount_reg=htotal_reg) then
					dotcount_reg <= (others=>'0');
					if (linecount_reg=vtotal_reg) then
						linecount_reg <= (others=>'0');
					else
						linecount_reg <= linecount_reg + 1;
					end if;
				else
					dotcount_reg <= dotcount_reg + 1;
				end if;

			when others=>
			end case;


			case pixel_state is
			when SCAN_RESET =>
				daclatch_reg <= '0';
				daccount_reg <= (others=>'0');

			when PIX_LATCH=>
				daclatch_reg <= '1';
				daccount_reg <= dotdiv_reg(3 downto 1);

			when others=>
				if (daccount_reg = 0) then
					daclatch_reg <= '0';
				else
					daccount_reg <= daccount_reg - '1';
				end if;

			end case;


		end if;
	end process;


--==== ＣＲＴＣレジスタ部 ============================================

	regselect_sig<= reg_select;

	----- レジスタ読み出し ----------
	reg_rddata   <= rddatal_sig;

	with regselect_sig select rddatal_sig <=
		"000000" & htotal_reg		when "000",
	 "000000000" & hsyncend_reg		when "001",
		"000000" & hviewsta_reg		when "010",
		"000000" & hviewend_reg		when "011",
		"000000" & vtotal_reg		when "100",
	"00000000000"& vsyncend_reg		when "101",
		"000000" & vviewsta_reg		when "110",
		"000000" & vviewend_reg		when "111",
		(others=>'X')				when others;


	----- レジスタ書き込み ----------
GEN_VARIABLE_REG : if (SYNC_REGISTER = "VARIABLE") generate

	process (crtc_clk,reset) begin				-- レジスタ可変の場合 
		if (reset='1') then
			htotal_reg   <= CONV_STD_LOGIC_VECTOR(INIT_HTOTAL,10);
			hsyncend_reg <= CONV_STD_LOGIC_VECTOR(INIT_HSYNCEND,7);
			hviewsta_reg <= CONV_STD_LOGIC_VECTOR(INIT_HVIEWSTA,10);
			hviewend_reg <= CONV_STD_LOGIC_VECTOR(INIT_HVIEWEND,10);
			vtotal_reg   <= CONV_STD_LOGIC_VECTOR(INIT_VTOTAL,10);
			vsyncend_reg <= CONV_STD_LOGIC_VECTOR(INIT_VSYNCEND,5);
			vviewsta_reg <= CONV_STD_LOGIC_VECTOR(INIT_VVIEWSTA,10);
			vviewend_reg <= CONV_STD_LOGIC_VECTOR(INIT_VVIEWEND,10);

		elsif(crtc_clk'event and crtc_clk='1') then
			if (reg_wen='1') then
				case regselect_sig is
				when "001" => hsyncend_reg <= reg_wrdata(6 downto 0);
				when "010" => hviewsta_reg <= reg_wrdata(9 downto 0);
				when "011" => hviewend_reg <= reg_wrdata(9 downto 0);
				when "100" => vtotal_reg   <= reg_wrdata(9 downto 0);
				when "101" => vsyncend_reg <= reg_wrdata(4 downto 0);
				when "110" => vviewsta_reg <= reg_wrdata(9 downto 0);
				when "111" => vviewend_reg <= reg_wrdata(9 downto 0);
				when others=> htotal_reg   <= reg_wrdata(9 downto 0);
				end case;
			end if;

		end if;
	end process;

end generate;
GEN_FIXED_REG : if (SYNC_REGISTER /= "VARIABLE") generate

	htotal_reg   <= CONV_STD_LOGIC_VECTOR(INIT_HTOTAL,10);		-- レジスタ固定の場合 
	hsyncend_reg <= CONV_STD_LOGIC_VECTOR(INIT_HSYNCEND,7);
	hviewsta_reg <= CONV_STD_LOGIC_VECTOR(INIT_HVIEWSTA,10);
	hviewend_reg <= CONV_STD_LOGIC_VECTOR(INIT_HVIEWEND,10);
	vtotal_reg   <= CONV_STD_LOGIC_VECTOR(INIT_VTOTAL,10);
	vsyncend_reg <= CONV_STD_LOGIC_VECTOR(INIT_VSYNCEND,5);
	vviewsta_reg <= CONV_STD_LOGIC_VECTOR(INIT_VVIEWSTA,10);
	vviewend_reg <= CONV_STD_LOGIC_VECTOR(INIT_VVIEWEND,10);

end generate;


end RTL;



----------------------------------------------------------------------
--   (C)2003-2007 Copyright J-7SYSTEM Works.  All rights Reserved.  --
----------------------------------------------------------------------
