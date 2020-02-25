Library IEEE;
   use IEEE.std_logic_1164.all;
   use ieee.numeric_std.all;
 

entity clock_manager is
	port
	(
		-- Input ports
		clk				: in	std_logic;
		locked_in		: in	std_logic;
		active_clock	: in	std_logic;
		clkloss			: in	std_logic;
		clkbad0			: in	std_logic;
		clkbad1			: in	std_logic;
		-- Output ports
		clkswitch		: out	std_logic;
		locked			: out	std_logic;
		sync_reset		: out	std_logic;
		LED_status		: out	std_logic_vector(2 downto 0)
	);
end clock_manager;


architecture RTL of clock_manager is
type PLL_STATE_TYPE is (NOT_LOCKED, CHECKING, INTERNAL, SWITCHING, EXTERNAL);
signal pll_state : PLL_STATE_TYPE;

begin
	
manage_pll_proc:process(locked_in, clk) is 
		variable last_active_clock	:	std_logic;
		variable check_count	:	unsigned(7 downto 0) := X"00";
	begin 
		if(locked_in = '0') then
			pll_state <= NOT_LOCKED;
			locked <= '0';
			sync_reset <= '1';
		elsif(rising_edge(clk)) then
			clkswitch <= '0';
			locked <= '0';
			sync_reset <= '1';
			case pll_state is
				when NOT_LOCKED =>
					check_count := to_unsigned(0,check_count'length);
					pll_state <= CHECKING;
				when CHECKING =>
					if active_clock /= last_active_clock then
						check_count := to_unsigned(0,check_count'length);
					elsif check_count > 31 then
						check_count := to_unsigned(0,check_count'length);
						if active_clock = '0' then
							pll_state <= EXTERNAL;
						else
							pll_state <= INTERNAL;
						end if;
					else
						check_count := check_count + 1;
					end if;
				when INTERNAL =>
					locked <= '1';
					sync_reset <= '0';
					if active_clock = '0' then
						pll_state <= CHECKING;
					else
						if clkbad0 = '0' then
							if check_count > 7 then
								pll_state <= SWITCHING;
								clkswitch <= '1';
								check_count := to_unsigned(0,check_count'length);
							else
								check_count := check_count + 1;
							end if;
						else
							check_count := to_unsigned(0,check_count'length);
						end if;
					end if;
				when SWITCHING =>
					clkswitch <= '1'; -- hold it high one more clock
					pll_state <= CHECKING;
				when EXTERNAL =>
					locked <= '1';
					sync_reset <= '0';
					if active_clock = '1' then
						pll_state <= CHECKING;
					end if;
				when others =>
					pll_state <= NOT_LOCKED;
			end case;
			last_active_clock := active_clock;
		end if;
	end process;
	
led_driver_proc	: process(locked_in,clk) is
	variable led_count		: unsigned(27 downto 0);
begin
	if locked_in = '0' then
		LED_status <= "000";
		led_count := to_unsigned(0,led_count'length);
	elsif rising_edge(clk) then
		case pll_state is
			when NOT_LOCKED =>
				LED_Status <= "000";
				led_count := to_unsigned(0,led_count'length);
			when CHECKING =>
				LED_Status <= "011";
				led_count := to_unsigned(0,led_count'length);
			when INTERNAL =>
				if led_count = 125000000 then
					LED_status <= "001";
					led_count := to_unsigned(0,led_count'length);
				elsif led_count >= 62500000 then
					LED_status <= "010";
					led_count := led_count + 1;
				else
					LED_status <= "001";
					led_count := led_count + 1;
				end if;
			when SWITCHING =>
				LED_STATUS <= "111";
				led_count := to_unsigned(0,led_count'length);
			when EXTERNAL =>
				if led_count = 125000000 then
					LED_status <= "101";
					led_count := to_unsigned(0,led_count'length);
				elsif led_count >= 62500000 then
					LED_status <= "110";
					led_count := led_count + 1;
				else
					LED_status <= "101";
					led_count := led_count + 1;
				end if;
			when others =>
				LED_status <= "000";
		end case;
	end if;
end process;
end RTL;
