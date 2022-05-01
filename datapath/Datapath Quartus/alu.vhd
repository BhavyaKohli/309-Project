library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all ;

entity ALU is
	generic(
		operand_width : integer:=16;
		sel_line : integer:=2
	);
	port (
		alu_x	: in std_logic_vector(operand_width-1 downto 0);
		alu_y	: in std_logic_vector(operand_width-1 downto 0);
		sel	: in std_logic_vector(sel_line-1 downto 0);
		alu_c 	: in std_logic;
		alu_o	: out std_logic_vector(operand_width-1 downto 0);
		c 	: out std_logic;                             
		z 	: out std_logic
	);
end ALU;

architecture alu_arch of ALU is
signal temp_op : std_logic_vector(operand_width-1 downto 0):= (others=>'0');

	function sub(
		alu_x : in std_logic_vector(operand_width-1 downto 0); 
		alu_y : in std_logic_vector(operand_width-1 downto 0)
	)
		return std_logic_vector is
			-- declaring and initializing variables using aggregates 
			variable diff	: std_logic_vector(operand_width-1 downto 0):= (others=>'0');
				
			variable carry 	: std_logic:= '1'; 
			variable nb		: std_logic:= '1';

		begin
			differ: for i in 0 to 15 loop
				nb:= NOT alu_y(i);
				diff(i) := (alu_x(i) XOR  nb ) XOR carry;
				carry :=  (alu_x(i) AND nb) OR ((alu_x(i) XOR nb) AND carry) ;
			end loop;

		return diff;
	end sub;

	function add(
		alu_x : in std_logic_vector(operand_width-1 downto 0); 
		alu_y : in std_logic_vector(operand_width-1 downto 0)
	)
		return std_logic_vector is
		   	variable sum 	: std_logic_vector (operand_width-1 downto 0):= (others=>'0');
			variable carry 	: std_logic:= '0';
		begin
			adding: for i in 0 to 15 loop
				sum(i) := (alu_x(i) XOR  alu_y(i) ) XOR carry;
				carry :=  (alu_x(i) AND alu_y(i)) OR ((alu_x(i) XOR alu_y(i)) AND carry) ;
			end loop;

		return sum;
	end add;

	function addl(
		alu_x : in std_logic_vector(operand_width-1 downto 0); 
		alu_y : in std_logic_vector(operand_width-1 downto 0)
	)
		return std_logic_vector is
			variable sum 	: std_logic_vector (operand_width-1 downto 0):= (others=>'0');
			variable B1 	: std_logic_vector(operand_width-1 downto 0):= (others=>'0'); 
			variable carry 	: std_logic:= '0';
		begin
			B1:= alu_y(14 downto 0)&'0';
			adding: for i in 0 to 15 loop
				sum(i) := (alu_x(i) XOR  B1(i) ) XOR carry;
				carry :=  (alu_x(i) AND B1(i)) OR ((alu_x(i) XOR B1(i)) AND carry) ;
			end loop;

		return sum;
	end addl;
	 
	function AnandB(
		alu_x : in std_logic_vector(operand_width-1 downto 0); 
		alu_y : in std_logic_vector(operand_width-1 downto 0)
	)
		return std_logic_vector is
			variable AnB : std_logic_vector(operand_width-1 downto 0):= (others=>'0');
		begin
		   	bitnr: for i in 0 to operand_width-1 loop
				AnB(i) := alu_x(i) nand alu_y(i);
			end loop;
		
	  return AnB;
   end AnandB;
		 
begin
	alu : process (alu_x, alu_y, sel, alu_c)
	begin
	if sel = "00" then
		temp_op <= add(alu_x,alu_y);
		alu_o<=temp_op;
		
		if(alu_x(15) = alu_y(15)) then
			c <= alu_x(15);	
		else
			c <= not(temp_op(15));
		end if;
		
	elsif sel = "01" then
		temp_op<= addl(alu_x,alu_y) ;
		alu_o<=temp_op;
		if(alu_x(15) = alu_y(14)) then
			c <= alu_x(15);	
		else
			c <= not(temp_op(15));
		end if;
	elsif sel = "10" then
		temp_op<= AnandB(alu_x,alu_y);
		alu_o<=temp_op;
		c<=alu_c;
	else 
		temp_op<=sub(alu_x,alu_y); 
		alu_o<=temp_op;
		c<=alu_c;
	end if;	
		
	if (temp_op = "0000000000000000") then 
		z <= '1';
	else 
		z <= '0';
	end if;
	end process ; --alu
end alu_arch ; -- alu_arch