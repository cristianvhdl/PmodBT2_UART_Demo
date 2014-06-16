----------------------------------------------------------------------------
--	UART_Demo.vhd -- PmodBT2_UART_Demo.vhd
----------------------------------------------------------------------------
-- Author:  Marshall Wingerson
--          Copyright 2013 Digilent, Inc.
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
-- The PmodBT2 UART Demo is a stripped down version from Sam Bobrowicz's 
-- Nexys 3 GPIO Demo to demonstrate and help troubleshoot connecting and 
-- communication with the PmodBT2 an FPGA. 
--
-- The demo is targeted for the Digilent Anvyl board with a PmodBT2 in 
-- Pmod header G.  The PmodBT2 needs to have JP4 jumpered to force it into 
-- 9600 baud rate.
-- 
-- When the FPGA is programmed, LD0 should blink rapidly and the message
-- "Button press Detected" will be in printed to a hyperterminal when BTN0
-- is pressed.  Demo was tested using Tera Term hyperterminal.
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
-- Revision History:
--  06/12/2014(MarshallW): Created using Xilinx ISE 14.7 
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--The IEEE.std_logic_unsigned contains definitions that allow 
--std_logic_vector types to be used with the + operator to instantiate a 
--counter.
use IEEE.std_logic_unsigned.all;

entity GPIO_demo is
    Port ( BTN : in  STD_LOGIC;
           CLK : in  STD_LOGIC;
           LED : out  STD_LOGIC;
			  RTS : out STD_LOGIC;
           UART_TXD : out  STD_LOGIC;
			  UART_RXD : in STD_LOGIC;
			  CTS : in STD_LOGIC;
			  STATUS : in STD_LOGIC;
			  RESET: out STD_LOGIC);
end GPIO_demo;


architecture Behavioral of GPIO_demo is

component UART_TX_CTRL
Port(
	SEND : in std_logic;
	DATA : in std_logic_vector(7 downto 0);
	CLK : in std_logic;          
	READY : out std_logic;
	UART_TX : out std_logic
	);
end component;

--The type definition for the UART state machine type. Here is a description of what
--occurs during each state:
-- RST_REG     -- Do Nothing. This state is entered after configuration or a user reset.
--                The state is set to LD_INIT_STR.
-- LD_INIT_STR -- The Welcome String is loaded into the sendStr variable and the strIndex
--                variable is set to zero. The welcome string length is stored in the StrEnd
--                variable. The state is set to SEND_CHAR.
-- SEND_CHAR   -- uartSend is set high for a single clock cycle, signaling the character
--                data at sendStr(strIndex) to be registered by the UART_TX_CTRL at the next
--                cycle. Also, strIndex is incremented (behaves as if it were post 
--                incremented after reading the sendStr data). The state is set to RDY_LOW.
-- RDY_LOW     -- Do nothing. Wait for the READY signal from the UART_TX_CTRL to go low, 
--                indicating a send operation has begun. State is set to WAIT_RDY.
-- WAIT_RDY    -- Do nothing. Wait for the READY signal from the UART_TX_CTRL to go high, 
--                indicating a send operation has finished. If READY is high and strEnd = 
--                StrIndex then state is set to WAIT_BTN, else if READY is high and strEnd /=
--                StrIndex then state is set to SEND_CHAR.
-- WAIT_BTN    -- Do nothing. Wait for a button press on BTNU, BTNL, BTND, or BTNR. If a 
--                button press is detected, set the state to LD_BTN_STR.
-- LD_BTN_STR  -- The Button String is loaded into the sendStr variable and the strIndex
--                variable is set to zero. The button string length is stored in the StrEnd
--                variable. The state is set to SEND_CHAR.
type UART_STATE_TYPE is (RST_REG, LD_INIT_STR, SEND_CHAR, RDY_LOW, WAIT_RDY, WAIT_BTN, LD_BTN_STR);

--The CHAR_ARRAY type is a variable length array of 8 bit std_logic_vectors. 
--Each std_logic_vector contains an ASCII value and represents a character in
--a string. The character at index 0 is meant to represent the first
--character of the string, the character at index 1 is meant to represent the
--second character of the string, and so on.
type CHAR_ARRAY is array (integer range<>) of std_logic_vector(7 downto 0);

constant TMR_CNTR_MAX : std_logic_vector(26 downto 0) := "101111101011110000100000000"; --"100,000,000 = clk cycles per second
constant TMR_VAL_MAX : std_logic_vector(3 downto 0) := "1001"; --9

constant MAX_STR_LEN : integer := 27;

constant WELCOME_STR_LEN : natural := 23;
constant BTN_STR_LEN : natural := 24;

--Welcome string definition. Note that the values stored at each index
--are the ASCII values of the indicated character.		PmodBT2 Demo
constant WELCOME_STR : CHAR_ARRAY(0 to 22) := (X"0A",  --\n
															  X"0D",  --\r
															  X"50",  --P
															  X"4D",  --M
															  X"4F",  --O
															  X"44",  --D
															  X"42",  --B
															  X"54",  --T
															  X"32",  --2
															  X"20",  -- 
															  X"55",  --U
															  X"41",  --A
															  X"52",  --R
															  X"54",  --T
															  X"20",  -- 
															  X"44",  --D
															  X"45",  --E
															  X"4D",  --M
															  X"4F",  --O
															  X"21",  --!
															  X"0A",  --\n
															  X"0A",  --\n
															  X"0D"); --\r
															  
--Button press string definition.
constant BTN_STR : CHAR_ARRAY(0 to 23) :=     (X"42",  --B
															  X"75",  --u
															  X"74",  --t
															  X"74",  --t
															  X"6F",  --o
															  X"6E",  --n
															  X"20",  -- 
															  X"70",  --p
															  X"72",  --r
															  X"65",  --e
															  X"73",  --s
															  X"73",  --s
															  X"20",  --
															  X"64",  --d
															  X"65",  --e
															  X"74",  --t
															  X"65",  --e
															  X"63",  --c
															  X"74",  --t
															  X"65",  --e
															  X"64",  --d
															  X"21",  --!
															  X"0A",  --\n
															  X"0D"); --\r

--This is used to determine when the 7-segment display should be
--incremented
signal tmrCntr : std_logic_vector(26 downto 0) := (others => '0');

--This counter keeps track of which number is currently being displayed
--on the 7-segment.
signal tmrVal : std_logic_vector(3 downto 0) := (others => '0');

--Contains the current string being sent over uart.
signal sendStr : CHAR_ARRAY(0 to (MAX_STR_LEN - 1));

--Contains the length of the current string being sent over uart.
signal strEnd : natural;

--Contains the index of the next character to be sent over uart
--within the sendStr variable.
signal strIndex : natural;

--Used to determine when a button press has occured
signal btnReg : std_logic := '0';
signal btnDetect : std_logic;

--UART_TX_CTRL control signals
signal uartRdy : std_logic;
signal uartSend : std_logic := '0';
signal uartData : std_logic_vector (7 downto 0):= "00000000";
signal uartTX : std_logic;

--Current uart state signal
signal uartState : UART_STATE_TYPE := RST_REG;

--temp variable to help with blink
signal blinkCounter: std_logic_vector(21 downto 0) := "0000000000000000000000";
signal LEDReg: std_logic := '1';

begin

blinky : process(CLK)
begin
	if(rising_edge(CLK)) then
		if(blinkCounter < "01111111111111111111111") then
			blinkCounter <= blinkCounter + 1;
		else
			blinkCounter <= "0000000000000000000000";
			
			if(LEDReg = '1') then
				LEDReg <= '0';
			else 
				LEDReg <= '1';
			end if;
		end if;
	end if;
end process;

LED <= LEDReg;



RESET <= '1';
RTS <= '1';




--begin

--btn_reg_process : process (CLK)
--begin
--	if (rising_edge(CLK)) then
--		btnReg <= btnDeBnc(3 downto 0);
--	end if;
--end process;

--btnDetect goes high for a single clock cycle when a btn press is
--detected. This triggers a UART message to begin being sent.
--btnDetect <= '1' when ((btnReg(0)='0' and btnDeBnc(0)='1') or
--								(btnReg(1)='0' and btnDeBnc(1)='1') or
--								(btnReg(2)='0' and btnDeBnc(2)='1') or
--								(btnReg(3)='0' and btnDeBnc(3)='1')  ) else
--				  '0';

btn_reg_process: process(CLK)
begin
	if(rising_edge(CLK))then
		btnReg <= BTN;
	end if;
end process;
		
btnDetect <= '1' when (BTN='1' and btnReg = '0')  else
				  '0';

--Next Uart state logic (states described above)
next_uartState_process : process (CLK)
begin
	if (rising_edge(CLK)) then
--		if (BTN = '1') then
--			uartState <= RST_REG;
--		else	
			case uartState is 
			when RST_REG =>
				uartState <= LD_INIT_STR;
			when LD_INIT_STR =>
				uartState <= SEND_CHAR;
			when SEND_CHAR =>
				uartState <= RDY_LOW;
			when RDY_LOW =>
				uartState <= WAIT_RDY;
			when WAIT_RDY =>
				if (uartRdy = '1') then
					if (strEnd = strIndex) then
						uartState <= WAIT_BTN;
					else
						uartState <= SEND_CHAR;
					end if;
				end if;
			when WAIT_BTN =>
				if (btnDetect = '1') then
					uartState <= LD_BTN_STR;
				end if;
			when LD_BTN_STR =>
				uartState <= SEND_CHAR;
			when others=> --should never be reached
				uartState <= RST_REG;
			end case;
--		end if ;
	end if;
end process;

--Loads the sendStr and strEnd signals when a LD state is
--is reached.
string_load_process : process (CLK)
begin
	if (rising_edge(CLK)) then
		if (uartState = LD_INIT_STR) then
			sendStr(0 to 22) <= WELCOME_STR;
			strEnd <= WELCOME_STR_LEN;
		elsif (uartState = LD_BTN_STR) then
			sendStr(0 to 23) <= BTN_STR;
			strEnd <= BTN_STR_LEN;
		end if;
	end if;
end process;

--Conrols the strIndex signal so that it contains the index
--of the next character that needs to be sent over uart
char_count_process : process (CLK)
begin
	if (rising_edge(CLK)) then
		if (uartState = LD_INIT_STR or uartState = LD_BTN_STR) then
			strIndex <= 0;
		elsif (uartState = SEND_CHAR) then
			strIndex <= strIndex + 1;
		end if;
	end if;
end process;

--Controls the UART_TX_CTRL signals
char_load_process : process (CLK)
begin
	if (rising_edge(CLK)) then
		if (uartState = SEND_CHAR) then
			uartSend <= '1';
			uartData <= sendStr(strIndex);
		else
			uartSend <= '0';
		end if;
	end if;
end process;


--Component used to send a byte of data over a UART line.
Inst_UART_TX_CTRL: UART_TX_CTRL port map(
		SEND => uartSend,
		DATA => uartData,
		CLK => CLK,
		READY => uartRdy,
		UART_TX => uartTX 
	);

UART_TXD <= uartTX;

end Behavioral;

