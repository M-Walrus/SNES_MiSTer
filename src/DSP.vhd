library IEEE;
use IEEE.std_logic_1164.all;
library STD;
use ieee.numeric_std.all;
library work;
use work.DSP_PKG.all;


entity DSP is
	port( 
		CLK 			: in std_logic;
		RST_N 		: in std_logic; 
		ENABLE 		: in std_logic;
		PAL			: in std_logic;

		SMP_EN 		: out std_logic;
		SMP_A    	: in std_logic_vector(15 downto 0);
		SMP_DO   	: in std_logic_vector(7 downto 0);
		SMP_DI   	: out std_logic_vector(7 downto 0);
		SMP_WE  		: in std_logic;
		SMP_CE		: out std_logic;
		  
		RAM_A			: out std_logic_vector(15 downto 0);
		RAM_D			: out std_logic_vector(7 downto 0);
		RAM_Q			: in  std_logic_vector(7 downto 0);
		RAM_CE_N		: out std_logic;
		RAM_OE_N		: out std_logic;
		RAM_WE_N		: out std_logic;
		
		LRCK			: out std_logic;
		BCK			: out std_logic;
		SDAT			: out std_logic;
		
		DBG_REG     : in std_logic_vector(7 downto 0);
		DBG_DAT_IN  : in std_logic_vector(7 downto 0);
		DBG_DAT_OUT : out std_logic_vector(7 downto 0);
		DBG_DAT_WR 	: in std_logic;

		AUDIO_L		: out std_logic_vector(15 downto 0);
		AUDIO_R		: out std_logic_vector(15 downto 0);
		SND_RDY		: out std_logic
	);
end DSP;

architecture rtl of DSP is 

	signal MCLK_FREQ 		: integer;
	signal CE 				: std_logic;

	signal REGRAM 			: RegRam_t;
	signal RI 				: std_logic_vector(7 downto 0);
	signal REGN_WR 		: std_logic_vector(6 downto 0);
	signal REGN_RD 		: std_logic_vector(6 downto 0);
	signal REGS_ADDR_WR 	: std_logic_vector(6 downto 0);
	signal REGS_ADDR_RD 	: std_logic_vector(6 downto 0);
	signal REGS_DI 		: std_logic_vector(7 downto 0);
	signal REGS_DO 		: std_logic_vector(7 downto 0);
	signal REGS_WE 		: std_logic;

	signal SMP_EN_INT 	: std_logic;
	signal STEP_CNT 		: unsigned(4 downto 0);
	signal SUBSTEP_CNT 	: unsigned(1 downto 0);
	signal STEP 			: integer range 0 to 31;
	signal SUBSTEP 		: integer range 0 to 3;
	signal BRR_VOICE 		: integer range 0 to 7;
	signal VS 				: VoiceStep_r;
	signal RS 				: RamStep_t;
	signal BDS 				: BRRDecodeStep_r;
	signal INS 				: IntStep_r;
	
	signal RST_FLG 		: std_logic;
	signal MUTE_FLG 		: std_logic;
	signal ECEN_FLG 		: std_logic;
	signal WKON 			: std_logic_vector(7 downto 0);
	signal TKON				: std_logic_vector(7 downto 0);
	signal TKOFF			: std_logic_vector(7 downto 0);
	signal KON_CNT 		: KonCnt_t;
	signal TSRCN 			: std_logic_vector(7 downto 0);
	signal TDIR 			: std_logic_vector(7 downto 0);
	signal TPITCH 			: unsigned(14 downto 0);
	signal TADSR1 			: std_logic_vector(7 downto 0);
	signal TADSR2 			: std_logic_vector(7 downto 0);
	signal TNON 			: std_logic_vector(7 downto 0);
	signal TESA 			: std_logic_vector(7 downto 0);
	signal TEON 			: std_logic_vector(7 downto 0);
	signal TPMON 			: std_logic_vector(7 downto 0);
	signal ENDX 			: std_logic_vector(7 downto 0);
	signal ENDX_BUF 		: std_logic_vector(7 downto 0);
	signal OUTX_OUT 		: std_logic_vector(7 downto 0);
	signal ENVX_OUT 		: std_logic_vector(7 downto 0);
	signal TENVX 			: EnvxBuf_t;
	signal EVEN_SAMPLE 	: std_logic;
	signal BRR_DECODE_EN : std_logic;
	
	signal TOUT 			: signed(15 downto 0);
	signal NOISE 			: signed(14 downto 0);
	signal OUTL 			: std_logic_vector(15 downto 0);
	signal OUTR 			: std_logic_vector(15 downto 0);
	signal OUTPUT 			: std_logic_vector(31 downto 0);
	signal MOUT 			: Out_t;
	signal EOUT 			: Out_t;
	
	signal TDIR_ADDR 		: std_logic_vector(15 downto 0);
	signal BRR_NEXT_ADDR : std_logic_vector(15 downto 0);
	signal BRR_ADDR 		: BrrAddr_t;
	signal BRR_OFFS 		: BrrOffs_t;
	signal TBRRDAT 		: std_logic_vector(15 downto 0);
	signal TBRRHDR 		: std_logic_vector(7 downto 0);
	signal BRR_BUF 		: VoiceBrrBuf_t;
	signal BRR_END 		: std_logic_vector(7 downto 0);
	
	signal ECHO_POS 		: unsigned(14 downto 0);
	signal ECHO_ADDR 		: unsigned(15 downto 0);
	signal ECHO_BUF 		: ChEchoBuf_t;
	signal ECHO_LEN 		: unsigned(14 downto 0);
	signal ECHO_DATA_TEMP: std_logic_vector(6 downto 0);
	signal ECHO_WR_EN 	: std_logic;
	signal ECHO_FIR 		: EchoFir_t;
	signal ECHO_FFC 		: EchoFFC_t;
	signal FFC_CNT 		: unsigned(2 downto 0);
	signal ECHO_FIR_TEMP	: EchoFir17_t;
	
	signal ENV_MODE 		: ChEnvMode_t;
	signal ENV 				: Env_t;
	signal BENT_INC_MODE : std_logic_vector(7 downto 0);
	signal INTERP_POS 	: InterpPos_t;
	signal LAST_ENV 		: signed(11 downto 0);
	
	signal GCNT_BY1 		: unsigned(11 downto 0);
	signal GCNT_BY3 		: unsigned(11 downto 0);
	signal GCNT_BY5 		: unsigned(11 downto 0);
	
	type GCntMask_t is array(0 to 31) of unsigned(11 downto 0);
	constant  GCNT_MASK: GCntMask_t := (
	x"FFF", x"7FF", x"7FF",
   x"7FF", x"3FF", x"3FF",
   x"3FF", x"1FF", x"1FF",
   x"1FF", x"0FF", x"0FF",
   x"0FF", x"07F", x"07F",
   x"07F", x"03F", x"03F",
   x"03F", x"01F", x"01F",
   x"01F", x"00F", x"00F",
   x"00F", x"007", x"007",
   x"007", x"003", x"003",
            x"001",
            x"000" 
	);
	
	impure function GCOUNT_TRIGGER(
		r: integer range 0 to 31
	) 
	return std_logic is
		variable temp: unsigned(11 downto 0); 
		variable res: std_logic; 
	begin
		case r is
			when 1 | 4 | 7 | 10 | 13 | 16 | 19 | 22 | 25 | 28 | 30 =>
				temp := GCNT_BY1 and GCNT_MASK(r);
				if temp = 0 then
					res := '1';
				else
					res := '0';
				end if;
			when 2 | 5 | 8 | 11 | 14 | 17 | 20 | 23 | 26 | 29 =>
				temp := GCNT_BY3 and GCNT_MASK(r);
				if temp = 0 then
					res := '1';
				else
					res := '0';
				end if;
			when 3 | 6 | 9 | 12 | 15 | 18 | 21 | 24 | 27  =>
				temp := GCNT_BY5 and GCNT_MASK(r);
				if temp = 0 then
					res := '1';
				else
					res := '0';
				end if;
			when 31 =>
				res := '1';
			when others =>
				res := '0';
		end case;
		return res;
	end function;
	
	signal RAM_DI 			: std_logic_vector(7 downto 0);
	signal RAM_DO 			: std_logic_vector(7 downto 0);
	signal RAM_WE 			: std_logic;
	signal RAM_OE 			: std_logic;
	signal RAM_CE 			: std_logic;
	
	--debug
	signal DBG_ADDR		: std_logic_vector(15 downto 0);
	signal DBG_DAT_WRr	: std_logic;
	signal DBG_VMUTE 		: std_logic_vector(7 downto 0) := (others => '0');

begin
	
	MCLK_FREQ <= MCLK_PAL_FREQ when PAL = '1' else MCLK_NTSC_FREQ;
	
	CEGen : entity work.CEGen
	port map(
		CLK      => CLK,
		RST_N    => RST_N and ENABLE,
		IN_CLK   => MCLK_FREQ,
		OUT_CLK  => ACLK_FREQ,
		CE       => CE
	);
	
	SMP_EN <= SMP_EN_INT;
	SMP_CE <= CE;

	process( RST_N, CLK )
	begin
		if RST_N = '0' then
			STEP_CNT <= (others => '0');
			SUBSTEP_CNT <= (others => '0');
		elsif rising_edge(CLK) then
			if ENABLE = '1' and CE = '1' then
				SUBSTEP_CNT <= SUBSTEP_CNT + 1;
				if SUBSTEP_CNT = 3 then
					STEP_CNT <= STEP_CNT + 1;
				end if;
			end if;
		end if;
	end process;

	SMP_EN_INT <= ENABLE when SUBSTEP = 3 else '0';
	
	STEP <= to_integer(STEP_CNT);
	SUBSTEP <= to_integer(SUBSTEP_CNT);
	
	REGS_ADDR_WR <= DBG_REG(6 downto 0) when ENABLE = '0' else REGN_WR;
	REGS_ADDR_RD <= DBG_REG(6 downto 0) when ENABLE = '0' else REGN_RD;					
	REGS_DI <= DBG_DAT_IN when ENABLE = '0' else 
				  SMP_DO 	 when SUBSTEP = 3 else
				  ENVX_OUT   when REGN_WR(3 downto 0) = x"8" else 
				  OUTX_OUT   when REGN_WR(3 downto 0) = x"9" else
				  SMP_DO;
						
	REGS_WE <= DBG_DAT_WR when ENABLE = '0' and DBG_REG(7) = '0' else
				  '1' 		 when SMP_WE = '0' and SMP_A = x"00F3" and SUBSTEP = 3 else
				  '1' 		 when REGN_WR(3 downto 1) = "100" and SUBSTEP = 0 else
				  '0';

	REGS_DO <= REGRAM(to_integer(unsigned(REGS_ADDR_RD)));
	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			REGRAM <= (others=>(others=>'0'));
		elsif rising_edge(CLK) then
			if ENABLE = '1' and CE = '1' then
				if REGS_WE = '1' then
					REGRAM(to_integer(unsigned(REGS_ADDR_WR))) <= REGS_DI;
				end if;
			end if;
		end if;
	end process;

	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			RI <= (others=>'0');
		elsif rising_edge(CLK) then
			if ENABLE = '1' and CE = '1' then
				if SMP_EN_INT = '1' and SMP_WE = '0' then
					if SMP_A = x"00F2" then
						RI <= SMP_DO;
					end if;
				end if;
			end if;
		end if;
	end process;

	process(SMP_A, SMP_WE, RAM_DI, REGS_DO, RI, ENDX)
	begin
		if SMP_A = x"00F2" then
			SMP_DI <= RI;
		elsif SMP_A = x"00F3" then
			if RI(6 downto 0) = "1111100" then	--ENDX
				SMP_DI <= ENDX;
			else
				SMP_DI <= REGS_DO;
			end if;
		else
			SMP_DI <= RAM_DI;
		end if;
	end process;
	
	process(STEP, SUBSTEP, TADSR1, RI)
		variable REG : std_logic_vector(7 downto 0);
	begin
		REG := RA_TBL(STEP, SUBSTEP);
		if SUBSTEP = 3 then
			REGN_RD <= RI(6 downto 0);
		elsif REG(3 downto 0) = x"6" then
			REGN_RD <= REG(6 downto 1) & not TADSR1(7);
		else
			REGN_RD <= REG(6 downto 0);
		end if;
		
		if SUBSTEP = 3 then
			REGN_WR <= RI(6 downto 0);
		else
			REGN_WR <= RA_TBL(STEP, SUBSTEP)(6 downto 0);
		end if;
	end process;
	
	VS <= VS_TBL(STEP,SUBSTEP);
	RS <= RS_TBL(STEP,SUBSTEP);
	BRR_VOICE <= BRR_VOICE_TBL(STEP);
	BDS <= BDS_TBL(STEP,SUBSTEP);
	INS <= IS_TBL(STEP,SUBSTEP);
	
	process(CLK, RST_N, RS, BRR_VOICE, STEP, SMP_A, SMP_WE, SMP_DO, KON_CNT, TDIR_ADDR, BRR_ADDR, BRR_OFFS,
			  ECHO_WR_EN, ECHO_ADDR, EOUT, ENABLE, DBG_ADDR, DBG_REG, DBG_DAT_IN, DBG_DAT_WR)
		variable ADDR_INC : unsigned(1 downto 0);
		variable LR: integer range 0 to 1;
	begin
		RAM_DO <= x"00";
		if ENABLE = '0' then
			RAM_A <= DBG_ADDR;
			RAM_DO <= DBG_DAT_IN;
			RAM_WE <= DBG_DAT_WR;
			RAM_OE <= not DBG_DAT_WR;
			if DBG_REG = x"80" then
				RAM_CE <= '1';
			else
				RAM_CE <= '0';
			end if;
		else
			case RS is
				when RS_SRCNL =>
					if KON_CNT(BRR_VOICE) = 0 then
						ADDR_INC := "10";
					else
						ADDR_INC := "00";
					end if;
					
					RAM_A <= std_logic_vector(unsigned(TDIR_ADDR) + ADDR_INC + 0);
					RAM_WE <= '0';
					RAM_OE <= '1';
					RAM_CE <= '1';
					
				when RS_SRCNH =>
					if KON_CNT(BRR_VOICE) = 0 then
						ADDR_INC := "10";
					else
						ADDR_INC := "00";
					end if;
					
					RAM_A <= std_logic_vector(unsigned(TDIR_ADDR) + ADDR_INC + 1);
					RAM_WE <= '0';
					RAM_OE <= '1';
					RAM_CE <= '1';
					
				when RS_BRRH =>
					RAM_A <= std_logic_vector(unsigned(BRR_ADDR(BRR_VOICE)));
					RAM_WE <= '0';
					RAM_OE <= '1';
					RAM_CE <= '1';
					
				when RS_BRR1 =>
					RAM_A <= std_logic_vector(unsigned(BRR_ADDR(BRR_VOICE)) + BRR_OFFS(BRR_VOICE) + 1);
					RAM_WE <= '0';
					RAM_OE <= '1';
					RAM_CE <= '1';
					
				when RS_BRR2 =>
					RAM_A <= std_logic_vector(unsigned(BRR_ADDR(BRR_VOICE)) + BRR_OFFS(BRR_VOICE) + 2);
					RAM_WE <= '0';
					RAM_OE <= '1';
					RAM_CE <= '1';
				
				when RS_ECHORDL | RS_ECHORDH =>
					if STEP = 22 then
						ADDR_INC := "00";
					else
						ADDR_INC := "10";
					end if;
					
					if RS = RS_ECHORDL then
						RAM_A <= std_logic_vector(ECHO_ADDR + ADDR_INC + 0);
					else
						RAM_A <= std_logic_vector(ECHO_ADDR + ADDR_INC + 1);
					end if;
					RAM_WE <= '0';
					RAM_OE <= '1';
					RAM_CE <= '1';
					
				when RS_ECHOWRL | RS_ECHOWRH =>
					if STEP = 29 then
						ADDR_INC := "00";
						LR := 0;
					else
						ADDR_INC := "10";
						LR := 1;
					end if;
					
					if RS = RS_ECHOWRL then
						RAM_A <= std_logic_vector(ECHO_ADDR + ADDR_INC + 0);
						RAM_DO <= std_logic_vector(EOUT(LR)(7 downto 0));
					else
						RAM_A <= std_logic_vector(ECHO_ADDR + ADDR_INC + 1);
						RAM_DO <= std_logic_vector(EOUT(LR)(15 downto 8));
					end if;
	
					
					if ECHO_WR_EN = '1' then
						RAM_CE <= '1';
						RAM_OE <= '0';
						RAM_WE <= '1';
					else
						RAM_CE <= '0';
						RAM_OE <= '0';
						RAM_WE <= '0';
					end if;
					
				when RS_SMP =>
					RAM_A <= SMP_A;
					RAM_WE <= not SMP_WE;
					RAM_OE <= SMP_WE;
					RAM_DO <= SMP_DO;
					RAM_CE <= '1';			
					
				when others =>
					RAM_A <= (others => '0');
					RAM_WE <= '0';
					RAM_OE <= '0';
					RAM_CE <= '0';
			end case;
		end if;
		
		if RST_N = '0' then
			BRR_NEXT_ADDR <= (others => '0');
			TBRRHDR <= (others => '0');
			TBRRDAT <= (others => '0');
			ECHO_BUF <= (others => (others => (others => '0')));
			ECHO_DATA_TEMP <= (others => '0');
		elsif rising_edge(CLK) then
			if ENABLE = '1' and CE = '1' then
				case RS is
					when RS_SRCNL =>
						BRR_NEXT_ADDR(7 downto 0) <= RAM_DI;
						
					when RS_SRCNH =>
						BRR_NEXT_ADDR(15 downto 8) <= RAM_DI;
				
					when RS_BRRH =>
						TBRRHDR <= RAM_DI;
						
					when RS_BRR1 =>
						TBRRDAT(15 downto 8) <= RAM_DI;
						
					when RS_BRR2 =>
						TBRRDAT(7 downto 0) <= RAM_DI;
				
					when RS_ECHORDL | RS_ECHORDH =>
						if STEP = 22 then
							LR := 0;
						else
							LR := 1;
						end if;
					
						if RS = RS_ECHORDL then
							ECHO_DATA_TEMP <= RAM_DI(7 downto 1);
						else
							for i in 0 to 6 loop
								ECHO_BUF(LR)(i) <= ECHO_BUF(LR)(i+1);
							end loop;
							ECHO_BUF(LR)(7) <= RAM_DI & ECHO_DATA_TEMP;
						end if;

					when others => null;
				end case;
			end if;
		end if;
	end process;
	
	RAM_D <= RAM_DO;
	RAM_DI <= RAM_Q;

	RAM_WE_N <= not RAM_WE;
	RAM_OE_N <= not RAM_OE;
	RAM_CE_N <= not RAM_CE;
	
	process(CLK, RST_N)
		variable FILTER : std_logic_vector(1 downto 0);
		variable SCALE : unsigned(3 downto 0);
		variable SOUT : signed(15 downto 0);
		variable P0, P1 : signed(15 downto 0);
		variable SR: signed(15 downto 0);
		variable SF: signed(16 downto 0);
		variable S: std_logic_vector(15 downto 0);
	begin
		if RST_N = '0' then
			BRR_BUF <= (others => (others => (others => '0')));
		elsif rising_edge(CLK) then
			if ENABLE = '1' and CE = '1' then
				if BDS.S /= BDS_IDLE and BRR_DECODE_EN = '1' then
					FILTER := TBRRHDR(3 downto 2);
					SCALE := unsigned(TBRRHDR(7 downto 4));
										
					case BDS.S is
						when BDS_SMPL0 =>
							S := (15 downto 3 => TBRRDAT(15), 2 => TBRRDAT(14), 1 => TBRRDAT(13), 0 => TBRRDAT(12));
						when BDS_SMPL1 =>
							S := (15 downto 3 => TBRRDAT(11), 2 => TBRRDAT(10), 1 => TBRRDAT(9),  0 => TBRRDAT(8));
						when BDS_SMPL2 =>
							S := (15 downto 3 => TBRRDAT(7),  2 => TBRRDAT(6),  1 => TBRRDAT(5),  0 => TBRRDAT(4));
						when BDS_SMPL3 =>
							S := (15 downto 3 => TBRRDAT(3),  2 => TBRRDAT(2),  1 => TBRRDAT(1),  0 => TBRRDAT(0));
						when others => null;
					end case;
					
					if SCALE <= 12 then
						SR := shift_right(shift_left(signed(S), to_integer(SCALE)), 1);
					else
						SR := signed(S and x"F800");
					end if;
					
					P0 := BRR_BUF(BDS.V)(11);
					P1 := shift_right(BRR_BUF(BDS.V)(10), 1);
					
					case FILTER is
						when "00" => 
							SF := (resize(SR, 17));
						when "01" => 
							SF := (resize(SR + shift_right(P0, 1) + shift_right((0-P0), 5), 17));
						when "10" => 
							SF := (resize(SR + (P0*1) + shift_right(0 - (P0 + (P0*2)),6) - P1 + shift_right(P1, 4), 17));
						when others => 
							SF := (resize(SR + (P0*1) + shift_right(0 - (P0 + (P0*4) + (P0*8)),7) - P1 + shift_right(((P1*2) + P1),4) , 17));
					end case;

					SOUT := shift_left(CLAMP16(SF), 1);
					
					for i in 0 to 10 loop
						BRR_BUF(BDS.V)(i) <= BRR_BUF(BDS.V)(i+1);
					end loop;
					BRR_BUF(BDS.V)(11) <= SOUT;
				end if;
			end if;
		end if;
	end process;


	process(CLK, RST_N)
		variable GSUM, OUT_TEMP : signed(15 downto 0);
		variable SUM012, SUM3 : signed(16 downto 0);
		variable VOL_TEMP : signed(16 downto 0);
		variable BB_POS : unsigned(3 downto 0);
		variable NEW_INTERP_POS : unsigned(15 downto 0);
		variable GTBL_POS : unsigned(7 downto 0);
		variable ENV_TEMP, ENV_TEMP2 : signed(12 downto 0);
		variable ENV_RATE : unsigned(4 downto 0);
		variable GAIN_MODE : unsigned(2 downto 0);
		variable NEW_KON_CNT : unsigned(2 downto 0);
		variable NOISE_RATE : unsigned(4 downto 0);
		variable NEW_NOISE : unsigned(14 downto 0);
	begin
		if RST_N = '0' then
			BRR_ADDR <= (others => (others => '0'));
			BRR_OFFS <= (others => (others => '0'));
			INTERP_POS <= (others => (others => '0'));
			TDIR <= (others => '0');
			TDIR_ADDR <= (others => '0');
			TADSR1 <= (others => '0');
			TSRCN <= (others => '0');
			TPITCH <= (others => '0');
			ENV <= (others => (others => '0'));
			ENV_MODE <= (others => EM_RELEASE);
			BENT_INC_MODE <= (others => '0');
			TOUT <= (others => '0');
			TKON <= (others => '0');
			TKOFF <= (others => '0');
			KON_CNT <= (others => (others => '0'));
			WKON <= (others => '0');
			RST_FLG <= '1';
			MUTE_FLG <= '1';
			ECEN_FLG <= '1';
			EVEN_SAMPLE <= '1';
			OUTL <= (others => '0');
			OUTR <= (others => '0');
			MOUT <= (others => (others => '0'));
			EOUT <= (others => (others => '0'));
			TESA <= (others => '0');
			TNON <= (others => '0');
			NOISE <= "100000000000000";
			TEON <= (others => '0');
			ECHO_POS <= (others => '0');
			ECHO_ADDR <= (others => '0');
			ECHO_LEN <= (others => '0');
			ECHO_FFC <= (others => (others => '0'));
			ECHO_FIR <= (others => (others => '0'));
			FFC_CNT <= (others => '0');
			ECHO_WR_EN <= '0';
			ENDX <= (others => '0');
			ENDX_BUF <= (others => '0');
			OUTX_OUT <= (others => '0');
			TENVX <= (others => (others => '0'));
			ENVX_OUT <= (others => '0');
			BRR_DECODE_EN <= '0';
			BRR_END <= (others => '0');
		elsif rising_edge(CLK) then
			if ENABLE = '0' then 
				if DBG_DAT_WR = '1' and DBG_REG(7) = '0' then 
					if DBG_REG(6 downto 0) = "1101100" then		--5C FLG
						RST_FLG <= DBG_DAT_IN(7);
						MUTE_FLG <= DBG_DAT_IN(6);
						ECEN_FLG <= DBG_DAT_IN(5);
					elsif DBG_REG(6 downto 0) = "1001100" then	--4C KON
						WKON <= DBG_DAT_IN;
					elsif DBG_REG(6 downto 0) = "1011101" then	--5D DIR
						TDIR <= DBG_DAT_IN;
					elsif DBG_REG(6 downto 0) = "1101101" then	--6D ESA
						TESA <= DBG_DAT_IN;
					end if;
				end if;
			elsif CE = '1' then 
				if SMP_EN_INT = '1' and SMP_A = x"00F3" and SMP_WE = '0' then
					if RI(6 downto 0) = "1001100" then		--KON
						WKON <= SMP_DO;
					elsif RI(6 downto 0) = "1101100" then	--FLG
						RST_FLG <= SMP_DO(7);
						MUTE_FLG <= SMP_DO(6);
						ECEN_FLG <= SMP_DO(5);
					elsif RI(6 downto 0) = "1111100" then	--ENDX
						ENDX_BUF <= (others => '0');
						ENDX <= (others => '0');
					elsif RI(3 downto 0) = "1000" then	--ENVX
						ENVX_OUT <= (others => '0');
					elsif RI(3 downto 0) = "1001" then	--OUTX
						OUTX_OUT <= (others => '0');
					end if;
				end if;
				
				NEW_KON_CNT := KON_CNT(INS.V) - 1;	
				case INS.S is
					when IS_ENV =>
						LAST_ENV <= ENV(INS.V);

						if KON_CNT(INS.V) /= 0 then
							if KON_CNT(INS.V) = 5 then
								BRR_ADDR(INS.V) <= BRR_NEXT_ADDR;
								BRR_OFFS(INS.V) <= (others => '0');
							end if;
									
							INTERP_POS(INS.V) <= (others => '0');
							if NEW_KON_CNT(1 downto 0) /= "00" then
								INTERP_POS(INS.V) <= x"4000";
							end if;

							ENV(INS.V) <= (others => '0');
							LAST_ENV <= (others => '0');
							TPITCH <= (others => '0');
						else
							if TPMON(INS.V) = '1' then
								TPITCH <= unsigned(signed(TPITCH) + resize(shift_right(shift_right(TOUT, 5) * signed(TPITCH), 10), TPITCH'length));
							end if;
						end if;
						
						if RST_FLG = '1' or (TBRRHDR(1 downto 0) = "01" and KON_CNT(INS.V) /= 5) then
							ENV_MODE(INS.V) <= EM_RELEASE;
							ENV(INS.V) <= (others => '0');
						end if;
						
						if EVEN_SAMPLE = '1' and TKON(INS.V) = '1' then
							KON_CNT(INS.V) <= "101";
						elsif KON_CNT(INS.V) /= 0 then
							KON_CNT(INS.V) <= NEW_KON_CNT;
						end if;
						
						if EVEN_SAMPLE = '1' then
							if TKON(INS.V) = '1' then
								ENV_MODE(INS.V) <= EM_ATTACK;
							elsif TKOFF(INS.V) = '1' then
								ENV_MODE(INS.V) <= EM_RELEASE;
							end if;
						end if;
						
						TENVX(INS.V) <= "0" & std_logic_vector(ENV(INS.V)(10 downto 4));
						
					when IS_ENV2 =>							
						BB_POS := "0" & unsigned(INTERP_POS(INS.V)(14 downto 12));
						GTBL_POS := unsigned(INTERP_POS(INS.V)(11 downto 4));

						SUM012 := resize( shift_right((GTBL(to_integer("0" & not GTBL_POS)) * BRR_BUF(INS.V)(to_integer(BB_POS + 0))), 11), 17 ) + 
									 resize( shift_right((GTBL(to_integer("1" & not GTBL_POS)) * BRR_BUF(INS.V)(to_integer(BB_POS + 1))), 11), 17 ) + 
									 resize( shift_right((GTBL(to_integer("1" &     GTBL_POS)) * BRR_BUF(INS.V)(to_integer(BB_POS + 2))), 11), 17 );
						SUM3   := resize( shift_right((GTBL(to_integer("0" &     GTBL_POS)) * BRR_BUF(INS.V)(to_integer(BB_POS + 3))), 11), 17 );
						GSUM := CLAMP16( resize(SUM012(15)&SUM012(15 downto 0) + SUM3, 17) );
						
						if TNON(INS.V) = '0' then
							OUT_TEMP := GSUM and x"FFFE";
						else
							OUT_TEMP := NOISE & "0";
						end if;
						
						--env apply
						TOUT <= resize( shift_right(OUT_TEMP * LAST_ENV, 11), TOUT'length ) and x"FFFE";
						
						--envelope
						if KON_CNT(INS.V) = 0 then
							if ENV_MODE(INS.V) = EM_RELEASE then
								ENV_TEMP2 := resize(ENV(INS.V), ENV_TEMP2'length) - 8;
								if ENV_TEMP2 < 0 then
									ENV_TEMP2 := (others => '0');
								end if;
								ENV(INS.V) <= resize(ENV_TEMP2, ENV(INS.V)'length);
								ENV_RATE := (others => '1');
							else
								if TADSR1(7) = '1' then
									if ENV_MODE(INS.V) = EM_DECAY or ENV_MODE(INS.V) = EM_SUSTAIN then
										ENV_TEMP := resize(ENV(INS.V), ENV_TEMP'length) - shift_right(ENV(INS.V) - 1, 8) - 1;
										if ENV_MODE(INS.V) = EM_DECAY then
											ENV_RATE := ("1" & unsigned(TADSR1(6 downto 4)) & "0") ;
										else
											ENV_RATE := unsigned(TADSR2(4 downto 0));
										end if;
									else
										ENV_RATE := (unsigned(TADSR1(3 downto 0)) & "1");
										if ENV_RATE /= 31 then
											ENV_TEMP := resize(ENV(INS.V), ENV_TEMP'length) + x"020";
										else
											ENV_TEMP := resize(ENV(INS.V), ENV_TEMP'length) + x"400";
										end if;
									end if;
								else
									GAIN_MODE := unsigned(TADSR2(7 downto 5));
									if GAIN_MODE(2) = '0' then
										ENV_TEMP := signed(resize(unsigned(TADSR2(6 downto 0)) & "0000", ENV_TEMP'length));
										ENV_RATE := (others => '1');
									else
										ENV_RATE := unsigned(TADSR2(4 downto 0));
										if GAIN_MODE(1 downto 0) = "00" then
											ENV_TEMP := resize(ENV(INS.V), ENV_TEMP'length) - x"020";
										elsif GAIN_MODE(1 downto 0) = "01" then
											ENV_TEMP := resize(ENV(INS.V), ENV_TEMP'length) - shift_right(ENV(INS.V) - 1, 8) - 1;
										elsif GAIN_MODE(1 downto 0) = "10" then
											ENV_TEMP := resize(ENV(INS.V), ENV_TEMP'length) + x"020";
										else 
											if BENT_INC_MODE(INS.V) = '0' then
												ENV_TEMP := resize(ENV(INS.V), ENV_TEMP'length) + x"020";
											else
												ENV_TEMP := resize(ENV(INS.V), ENV_TEMP'length) + x"008";
											end if;
										end if;
									end if;
								end if;
								
								if unsigned(ENV_TEMP(10 downto 0)) >= x"600" or ENV_TEMP(12 downto 11) /= "00" then
									BENT_INC_MODE(INS.V) <= '1';
								else
									BENT_INC_MODE(INS.V) <= '0';
								end if;
								
								if unsigned(ENV_TEMP(10 downto 8)) = unsigned(TADSR2(7 downto 5)) and ENV_MODE(INS.V) = EM_DECAY then
									ENV_MODE(INS.V) <= EM_SUSTAIN;
								end if;

								if ENV_TEMP(12 downto 11) /= "00" then
									if ENV_TEMP < 0 then
										ENV_TEMP2 := (others => '0');
									else
										ENV_TEMP2 := "0011111111111";
									end if;
									if ENV_MODE(INS.V) = EM_ATTACK then
										ENV_MODE(INS.V) <= EM_DECAY;
									end if;
								else
									ENV_TEMP2 := ENV_TEMP;
								end if;
									
								if GCOUNT_TRIGGER(to_integer(ENV_RATE)) = '1' then
									ENV(INS.V) <= resize(ENV_TEMP2, ENV(INS.V)'length);
								end if;
							end if;								
						else
							ENV(INS.V) <= (others => '0');
							BENT_INC_MODE(INS.V) <= '0';
						end if;
												
					when others => null;
				end case;
				
				case VS.S is
					when VS_ADSR1 =>
						TADSR1 <= REGS_DO;
						
						if VS.V = 0 then
							ECHO_ADDR <= (unsigned(TESA) & x"00") + ECHO_POS;
						end if;
						
					when VS_PITCHL =>
						TPITCH(7 downto 0) <= unsigned(REGS_DO);
						
					when VS_PITCHH =>
						TPITCH(14 downto 8) <= "0" & unsigned(REGS_DO(5 downto 0));
						OUTX_OUT <= std_logic_vector(TOUT(15 downto 8));
						
					when VS_ADSR2 =>
						TADSR2 <= REGS_DO;
					
					when VS_SRCN =>
						TSRCN <= REGS_DO;
						TDIR_ADDR <= std_logic_vector((unsigned(TDIR)&x"00") + (unsigned(TSRCN)&"00"));
						
					when VS_VOLL =>
						VOL_TEMP := resize(shift_right(TOUT * signed(REGS_DO), 7), VOL_TEMP'length);
						MOUT(0) <= CLAMP16(resize(MOUT(0), VOL_TEMP'length) + VOL_TEMP);
						if TEON(VS.V) = '1' then
							EOUT(0) <= CLAMP16(resize(EOUT(0), VOL_TEMP'length) + VOL_TEMP);
						end if;
						
						BRR_END <= (others => '0');
						BRR_DECODE_EN <= '0';
						if INTERP_POS(VS.V)(15 downto 14) /= "00" then -- >= 4000
							BRR_DECODE_EN <= '1';
							BRR_OFFS(VS.V) <= BRR_OFFS(VS.V) + 2;
							if BRR_OFFS(VS.V) = 6 then
								if TBRRHDR(0) = '1' then
									BRR_ADDR(VS.V) <= BRR_NEXT_ADDR;
									BRR_END(VS.V) <= '1';
								else
									BRR_ADDR(VS.V) <= std_logic_vector(unsigned(BRR_ADDR(VS.V)) + 9);
								end if;
							end if;
						end if;
						
						NEW_INTERP_POS := ("00"&INTERP_POS(VS.V)(13 downto 0)) + ("0"&TPITCH);
						if NEW_INTERP_POS(15) = '0' then
							INTERP_POS(VS.V) <= NEW_INTERP_POS;
						else
							INTERP_POS(VS.V) <= x"7FFF";
						end if;
						
					when VS_VOLR =>
						VOL_TEMP := resize(shift_right(TOUT * signed(REGS_DO), 7), VOL_TEMP'length);
						MOUT(1) <= CLAMP16(resize(MOUT(1), VOL_TEMP'length) + VOL_TEMP);
						if TEON(VS.V) = '1' then
							EOUT(1) <= CLAMP16(resize(EOUT(1), VOL_TEMP'length) + VOL_TEMP);
						end if;
						
						ENDX_BUF <= ENDX or BRR_END;
						if KON_CNT(VS.V) = 5 then
							ENDX_BUF(VS.V) <= '0';
						end if;
					
					when VS_MVOLL =>
						MOUT(0) <= resize(shift_right(MOUT(0) * signed(REGS_DO), 7),MOUT(0)'length);
					
					when VS_MVOLR =>
						MOUT(1) <= resize(shift_right(MOUT(1) * signed(REGS_DO), 7),MOUT(1)'length);
					
					when VS_EVOLL =>
						if MUTE_FLG = '1' then
							OUTL <= (others => '0');
						else
							OUTL <= std_logic_vector(CLAMP16(resize(MOUT(0), 17) + resize(shift_right(ECHO_FIR(0) * signed(REGS_DO), 7), 17)));
						end if;
						MOUT(0) <= (others => '0');
					
					when VS_EVOLR =>
						if MUTE_FLG = '1' then
							OUTR <= (others => '0');
						else
							OUTR <= std_logic_vector(CLAMP16(resize(MOUT(1), 17) + resize(shift_right(ECHO_FIR(1) * signed(REGS_DO), 7), 17)));
						end if;
						MOUT(1) <= (others => '0');
						ECHO_FIR(0) <= (others => '0'); ECHO_FIR_TEMP(0) <= (others => '0');
						ECHO_FIR(1) <= (others => '0'); ECHO_FIR_TEMP(1) <= (others => '0');
						
					when VS_DIR =>
						TDIR <= REGS_DO;
								
					when VS_KON =>
						if EVEN_SAMPLE = '1' then
							WKON <= WKON and (not TKON);
						end if;
						
					when VS_KOFF =>
						if EVEN_SAMPLE = '1' then
							TKON <= WKON;
							TKOFF <= REGS_DO or DBG_VMUTE; 
						end if;
						
					when VS_PMON => 
						TPMON <= REGS_DO(7 downto 1) & "0";
					
					when VS_NON =>
						TNON <= REGS_DO;
						
					when VS_FLG =>
						NOISE_RATE := unsigned(REGS_DO(4 downto 0));
						NEW_NOISE := (((NOISE(0) xor NOISE(1)) & "00000000000000") or ("0" & unsigned(NOISE(14 downto 1))));
						if GCOUNT_TRIGGER(to_integer(NOISE_RATE)) = '1' then
							NOISE <= signed(NEW_NOISE);
						end if;
						
						EOUT(0) <= (others => '0');
						EOUT(1) <= (others => '0');
						
					when VS_EON =>
						TEON <= REGS_DO;
						ECHO_WR_EN <= not ECEN_FLG;
						
					when VS_EDL =>
						if ECHO_POS = 0 then
							ECHO_LEN <= unsigned(REGS_DO(3 downto 0)) & "00000000000";
						end if;
						
					when VS_ESA =>
						TESA <= REGS_DO;
						EVEN_SAMPLE <= not EVEN_SAMPLE;
						
						if ECHO_POS + 4 >= ECHO_LEN then
							ECHO_POS <= (others => '0');
						else
							ECHO_POS <= ECHO_POS + 4;
						end if;
						ECHO_WR_EN <= not ECEN_FLG;
					
					when VS_FIR0 | VS_FIR1 | VS_FIR2 | VS_FIR3 | VS_FIR4 | VS_FIR5 | VS_FIR6 | VS_FIR7 =>
						ECHO_FFC(VS.V) <= signed(REGS_DO);
								
					when VS_EFB =>
						EOUT(0) <= CLAMP16(resize(EOUT(0), 17) + resize(shift_right(ECHO_FIR(0) * signed(REGS_DO), 7), 17)) and x"FFFE";
						EOUT(1) <= CLAMP16(resize(EOUT(1), 17) + resize(shift_right(ECHO_FIR(1) * signed(REGS_DO), 7), 17)) and x"FFFE";
					
					when VS_ENVX =>
						
					when VS_OUTX =>
						ENDX <= ENDX_BUF;
						ENVX_OUT <= TENVX(VS.V);
						
					when VS_ECHO =>
						
					when others => null;
				end case;
				
				if (STEP = 24) or	(STEP = 25) then
					ECHO_FIR_TEMP(0) <= ECHO_FIR_TEMP(0) + resize(shift_right(signed(ECHO_BUF(0)(to_integer(FFC_CNT))) * ECHO_FFC(to_integer(FFC_CNT)), 6), 16);
					ECHO_FIR_TEMP(1) <= ECHO_FIR_TEMP(1) + resize(shift_right(signed(ECHO_BUF(1)(to_integer(FFC_CNT))) * ECHO_FFC(to_integer(FFC_CNT)), 6), 16);
					if FFC_CNT = 7 then
						ECHO_FIR(0) <= CLAMP16(resize(ECHO_FIR_TEMP(0), 17) + resize(shift_right(signed(ECHO_BUF(0)(to_integer(FFC_CNT))) * ECHO_FFC(to_integer(FFC_CNT)), 6), 17)) and x"FFFE";
						ECHO_FIR(1) <= CLAMP16(resize(ECHO_FIR_TEMP(1), 17) + resize(shift_right(signed(ECHO_BUF(1)(to_integer(FFC_CNT))) * ECHO_FFC(to_integer(FFC_CNT)), 6), 17)) and x"FFFE";
					end if;
					FFC_CNT <= FFC_CNT + 1;
				end if;
			end if;	
		end if;
	end process;
	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			GCNT_BY1 <= (others => '0');
			GCNT_BY3 <= x"410";
			GCNT_BY5 <= x"218";
		elsif rising_edge(CLK) then
			if ENABLE = '1' and CE = '1' then
				if STEP = 30 and SUBSTEP = 1 then
					if GCNT_BY3(1 downto 0) = "00" then
						GCNT_BY3(1 downto 0) <= "10";
					else
						GCNT_BY3 <= GCNT_BY3 + 1;
					end if;
					
					if GCNT_BY5(2 downto 0) = "000" then
						GCNT_BY5(2 downto 0) <= "100";
					else
						GCNT_BY5 <= GCNT_BY5 + 1;
					end if;
					
					GCNT_BY1 <= GCNT_BY1 + 1;
				end if;
			end if;
		end if;
	end process;
	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			OUTPUT <= (others => '0');
			SND_RDY <= '0';
			AUDIO_L <= (others => '0');
			AUDIO_R <= (others => '0');
		elsif rising_edge(CLK) then
			SND_RDY <= '0';
			if ENABLE = '1' and CE = '1' then
				if SUBSTEP = 3 then
					OUTPUT <= OUTPUT(30 downto 0) & "0";
					if STEP = 31 then
						OUTPUT <= OUTL & OUTR;
						AUDIO_L <= OUTL;
						AUDIO_R <= OUTR;
						SND_RDY <= '1';
					end if;
				end if;
			end if;
		end if;
	end process;
	
	LRCK <= not STEP_CNT(4);
	BCK <= SUBSTEP_CNT(1);
	SDAT <= OUTPUT(31);
	
	
	--debug
	process( CLK, RST_N, DBG_ADDR, DBG_REG, REGS_DO, RAM_DI )
	begin
		if DBG_REG(7) = '0' then
			DBG_DAT_OUT <= REGS_DO;
		else
			case DBG_REG is
				when x"80" => DBG_DAT_OUT <= RAM_DI;
				when x"81" => DBG_DAT_OUT <= DBG_ADDR(7 downto 0);
				when x"82" => DBG_DAT_OUT <= DBG_ADDR(15 downto 8);
				when others => DBG_DAT_OUT <= x"55";
			end case;
		end if;
			
		if RST_N = '0' then
			DBG_ADDR <= (others => '0');
			DBG_DAT_WRr <= '0';
		elsif rising_edge(CLK) then
			DBG_DAT_WRr <= DBG_DAT_WR;
			if DBG_DAT_WR = '1' and DBG_DAT_WRr = '0' then
				case DBG_REG is
					when x"81" => DBG_ADDR(7 downto 0) <= DBG_DAT_IN;
					when x"82" => DBG_ADDR(15 downto 8) <= DBG_DAT_IN;
					when x"83" => DBG_VMUTE <= DBG_DAT_IN;
					when others => null;
				end case;
			end if;
		end if;
	end process;

end rtl;
