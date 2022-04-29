library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity regfile is
	port (
		rf_a1 : in std_logic_vector(2 downto 0);
		rf_a2 : in std_logic_vector(2 downto 0);
		rf_a3 : in std_logic_vector(2 downto 0);
		rf_d1 : out std_logic_vector(15 downto 0);
		rf_d2 : out std_logic_vector(15 downto 0);
		rf_d3               : in std_logic_vector(15 downto 0);
		wr_en               : in std_logic;
		clk, rst            : in std_logic
		
	);
end regfile;

architecture rf_arch of regfile is
type rf is array(7 downto 0) of std_logic_vector(15 downto 0);
signal reg : rf;

begin

	process(clk, rst)
	begin
		if(rst = '1') then
			reg <= (others => (others => '0'));
		else    
			if(clk'event and clk = '1') then	
				if (rf_a1 = "000") then
					null;
				elsif (rf_a2 = "000") then
					null;
				else 
					rf_d1 <= reg(to_integer(unsigned(rf_a1)));
					rf_d2 <= reg(to_integer(unsigned(rf_a2)));
				end if;

				if (wr_en = '1') then
					reg (to_integer(unsigned(rf_a3))) <= rf_d3;
				end if;
			end if;
		end if;
	end process;
end rf_arch;