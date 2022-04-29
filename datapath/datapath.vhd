library std;
use std.standard.all;
library ieee;
use ieee.std_logic_1164.all;

entity switch is
	generic ( nbits : integer := 16 );
	port (
		x : in std_logic_vector(nbits-1 downto 0);
		s : in std_logic;
		y : out std_logic_vector(nbits-1 downto 0)
	);
end entity switch;

architecture switch_arch of switch is
	begin
	process (s)
	begin
		if (s = '1') then
			y <= x;
		else 
			null;
		end if;
	end process;
end switch_arch;

library std;
use std.standard.all;

library work;
use work.muxes.all;

library work;
use work.rij.all;

library ieee;
use ieee.std_logic_1164.all;

entity Datapath is
    port(
        clk, rst: in std_logic;
        di_en, t1_en, cz_en, alu_en: in std_logic_vector(1 downto 0);
        cb, ao_en, do_en: in std_logic; -- removed "z, inc_en"
        ir_en, pc_en: in std_logic_vector(2 downto 0);
        mux: in std_logic_vector(3 downto 0);
        rf_en: in std_logic_vector(4 downto 0);
        co: out std_logic;
        zo: out std_logic;
        ir_data: out std_logic_vector(15 downto 0)
        );

		-- di, t1, alu, cz_en		: out std_logic_vector(1 downto 0);
		-- cb, ao, do, w, rf_en	: out std_logic;
		-- ir, pc				: out std_logic_vector(2 downto 0);
		-- mux					: out std_logic_vector(3 downto 0);
		-- rf					: out std_logic_vector(4 downto 0)

end entity Datapath;

architecture datapath_arch of Datapath is
signal one : std_logic := '1';
signal zero : std_logic := '0';
signal zero_3bit : std_logic_vector(2 downto 0) := "000";
signal dummy_16bit : std_logic_vector(15 downto 0) := (others => '0');
signal pc_o, pc_i : std_logic_vector(15 downto 0); --program counter
signal inc_o : std_logic_vector(15 downto 0); --incrementer
signal rf_a3_o, rf_a2_i, rf_a1_i : std_logic_vector(2 downto 0) := "000"; --register file
signal rf_d1_o, rf_d2_o, rf_d3_i : std_logic_vector(15 downto 0); --register file
signal rf_wren : std_logic;
signal bus_a_o, bus_a_i: std_logic_vector(15 downto 0); --bus a
signal bus_b_o, bus_b_i: std_logic_vector(15 downto 0); --bus b
signal alu_a, alu_b, alu_o, t1_o : std_logic_vector(15 downto 0); --alu
signal memi_o, ir_o : std_logic_vector(15 downto 0); --instrction register
signal alu_s1, alu_s0, c_o, z_o, carry_f, zero_f : std_logic; --alu select lines and carry output and flags
signal rblock_o, iblock_o, jblock_o: std_logic; --rij block
signal ao_o: std_logic_vector(15 downto 0); --address out
signal memd_o, di_o: std_logic_vector(15 downto 0); --data in
signal do_o: std_logic_vector(15 downto 0);-- data out
signal mux_rfa3_sel : std_logic;
signal mux_rfa3_out : std_logic_vector(2 downto 0);
signal sw1_rfa1_sel, sw2_rfa3_sel : std_logic;
signal rfa3_pre_1, rfa3_pre_2 : std_logic_vector(2 downto 0);
signal rfa3_4x1_s1, rfa3_4x1_s0 : std_logic;

component switch is
	generic( nbits : integer := 16 );
	port (
		x : in std_logic_vector(nbits-1 downto 0);
		s : in std_logic;
		y : out std_logic_vector(nbits-1 downto 0)
	);
end component switch;

component mem is
	generic (
		mem_data_width : integer := 16; -- number of bits per word
		mem_width : integer := 16 -- number of address bits; N = 2^A
	); 
	
	port (
		address		: in std_logic_vector(mem_width-1 downto 0); 
		data_in		: in std_logic_vector(mem_data_width-1 downto 0);
		write_in	: in std_logic; 
		clk			: in std_logic; 
		data_out	: out std_logic_vector(mem_data_width-1 downto 0)
	);
end component mem;

component incrementer is
    port (
        clk, rst, en : in std_logic;
        din          : in std_logic_vector(15 downto 0);
        dout         : out std_logic_vector(15 downto 0)
    );
end component incrementer;

component ALU is 
    generic (
        operand_width : integer:=16;
        sel_line : integer:=2
    );
    port (
        alu_x : in std_logic_vector(operand_width-1 downto 0);
        alu_y : in std_logic_vector(operand_width-1 downto 0);
        sel   : in std_logic_vector(sel_line-1 downto 0);
        alu_c : in std_logic;
        alu_o : out std_logic_vector(operand_width-1 downto 0);
        c     : out std_logic;
        z     : out std_logic
    );
end component ALU;

component ir is
    port(
        clk, rst, en  	: in std_logic;
        din               : in std_logic_vector(15 downto 0);
        dout              : out std_logic_vector(15 downto 0)
        );
end component ir;

component regfile is 
    port(
        rf_a1 : in std_logic_vector(2 downto 0);
		rf_a2 : in std_logic_vector(2 downto 0);
		rf_a3 : in std_logic_vector(2 downto 0);
		rf_d1 : out std_logic_vector(15 downto 0);
		rf_d2 : out std_logic_vector(15 downto 0);
		rf_d3               : in std_logic_vector(15 downto 0);
		wr_en               : in std_logic;
		clk, rst            : in std_logic
		
    );
end component regfile;

component R_block is
	port (
	i : in std_logic_vector(3 downto 0);
	o : out std_logic
);
end component R_block;

component I_block is
	port (
		i : in std_logic_vector(3 downto 0);
		o : out std_logic
	);
end component I_block;

component J_block is
	port (
		i : in std_logic_vector(3 downto 0);
		o : out std_logic
	);
end component J_block;

component reg is
	generic ( nbits : integer := 16 );
	port (
		clk, rst, en : in std_logic;
		din          : in std_logic_vector(nbits-1 downto 0);
		dout         : out std_logic_vector(nbits-1 downto 0)
	);
end component reg;

component int_bus is
	generic ( data_length : integer := 16 );
	port (
		clk, rst : in std_logic;
		din      : in std_logic_vector(data_length-1 downto 0);
		dout     : out std_logic_vector(15 downto 0)
	);
end component int_bus;

-- component ir is
-- 	port (
-- 		clk			: in std_logic;
-- 		irwrite		: in std_logic;
-- 		inp			: in std_logic_vector(15 downto 0);
-- 		opcode		: out std_logic_vector(3 downto 0); --15-12
-- 		imm6		: out std_logic_vector(5 downto 0); --5-0
-- 		ra			: out std_logic_vector(2 downto 0); --b-9
-- 		rb			: out std_logic_vector(2 downto 0); --8-6
-- 		rc			: out std_logic_vector(2 downto 0); --5-3
-- 		cz			: out std_logic_vector(1 downto 0); --1-0 -- 0 is z and 1 is c
-- 		imm9		: out std_logic_vector(8 downto 0); --8-0
-- 		imm8		: out std_logic_vector(7 downto 0)  --7-0
-- 	);
-- end component ir;

begin
	--buses
	bus_a:
		int_bus port map (clk, rst, bus_a_i, bus_a_o);
	bus_b:
		int_bus port map (clk, rst, bus_b_i, bus_b_o);
	
	-- PC and related signals/connections
	program_counter : 
		reg port map (clk, rst, pc_en(1), pc_i, pc_o);
	sw_pci : 
		switch port map (pc_o, pc_en(2), bus_a_i);
	bus_inc_mux : 
		mux_2to1 port map (inc_o, bus_a_o, pc_en(0), pc_i);
	incr : 
		incrementer port map (clk, rst, one, pc_i, inc_o);
	
	-- ir
	instruction_reg :
		reg port map (clk, rst, one, memi_o, ir_o);
	
	--MUX to rfa3
	buses_rfa3_sw_1:
		switch generic map (1) port map (x(0)=>one, s=>mux(3), y(0)=>mux_rfa3_sel);
	buses_rfa3_sw_c:
		switch generic map (1) port map (x(0)=>c_o, s=>mux(1), y(0)=>mux_rfa3_sel);
	buses_rfa3_sw_z:
		switch generic map (1) port map (x(0)=>z_o, s=>mux(2), y(0)=>mux_rfa3_sel);
	buses_rfa3:
		mux_2to1 generic map (3) port map (bus_a_o(2 downto 0), bus_b_o(2 downto 0), mux_rfa3_sel, mux_rfa3_out);

	--RF input selections
	rblock :
	 	R_block port map (ir_o(15 downto 12), rblock_o);
	iblock :
		I_block port map (ir_o(15 downto 12), iblock_o);
	jblock :
		J_block port map (ir_o(15 downto 12), jblock_o);
	rf_a1_selection_mux1 :
	 	mux_2to1 generic map (3) port map (zero_3bit, ir_o(11 downto 9), jblock_o, rf_a1_i);
	rf_a2_selection_mux2 :
		mux_2to1 generic map (3) port map (ir_o(8 downto 6), zero_3bit, jblock_o, rf_a2_i);
	rf_a3_selection_mux1 :
		mux_4to1 generic map (3) port map (zero_3bit, ir_o(11 downto 9), ir_o(8 downto 6), ir_o(5 downto 3), s(0)=>jblock_o, s(1)=>iblock_o, y=>rfa3_pre_1);
	
	rfa3_4x1_s0 <= mux(0);
	rfa3_4x1_s1 <= ir_en(1) and ((not ir_o(15)) and ir_o(14) and ir_o(13) and ir_o(12));
	
	rf_a3_selection_mux2 :
		mux_4to1 generic map (3) port map (x3=>zero_3bit, x2=>rfa3_pre_2, x1=>mux_rfa3_out, x0=>rfa3_pre_1, s(1)=>rfa3_4x1_s1, s(0)=>rfa3_4x1_s0, y=>rf_a3_o);
	
	sw2_rfa3_sel <= ir_en(1) and ((not ir_o(15)) and ir_o(14) and ir_o(13) and ir_o(12));
	sw1_rfa1_sel <= ir_en(1) and (not ((not ir_o(15)) and ir_o(14) and ir_o(13) and ir_o(12)));
	
	sw1_rfa1:
		switch generic map (3) port map (ir_o(11 downto 9), sw1_rfa1_sel, rf_a1_i);
	sw2_rfa3:
		switch generic map (3) port map (ir_o(11 downto 9), sw2_rfa3_sel, rfa3_pre_2);
		
	rf_wren <= rf_en(2) or rf_en(3);
	
	-- RF
	register_file :
		regfile port map (rf_a1_i, rf_a2_i, rf_a3_o, rf_d1_o, rf_d2_o, rf_d3_i, rf_wren, clk, rst);
	rf_switch_1:
		switch port map (rf_d1_o, rf_en(0), bus_a_i);
	rf_switch_2:
		switch port map (rf_d2_o, rf_en(1), bus_b_i);
	rf_switch_3:
		switch port map (bus_a_i, rf_en(3), rf_d3_i);
	rf_switch_4:
		switch port map (bus_b_i, rf_en(2), rf_d3_i);
	
	-- ALU and t1
	alu_s1 <= (((not ir_o(15)) and (not ir_o(14)) and (not ir_o(13)) and ir_o(12) and ir_o(1) and ir_o(0)) or (ir_o(15) and (not ir_o(14)) and (not ir_o(13)) and (not ir_o(11)))) and (not cb);
	alu_s0 <= ((not ir_o(14) and (not ir_o(12)) and (ir_o(15) xor ir_o(13)) and (not cb)));

	arithmetic_logical_unit : 
        ALU port map (alu_a, alu_b, sel(1)=>alu_s1, sel(0)=>alu_s0, alu_c=>c_o, alu_o=>alu_o, c=>carry_f, z=>zero_f);
	bus_a_alu :
		switch port map (bus_a_o, alu_en(0), alu_a);
	bus_b_alu :
		switch port map (bus_b_o, alu_en(1), alu_b);
	temp_reg_t1 :
		reg port map (clk, rst, one, alu_o, t1_o);
	t1_bus_a :
		switch port map (t1_o, t1_en(0), bus_a_i);
	t1_bus_b :
		switch port map (t1_o, t1_en(1), bus_b_i);

	--CZ
	carry_reg :
		reg generic map (1) port map (clk, rst, cz_en(0), din(0)=>carry_f, dout(0)=>c_o);
	zero_reg:
		reg generic map (1) port map (clk, rst, cz_en(1), din(0)=>zero_f, dout(0)=>z_o);
	
	--AO
	address_out:
		reg port map (clk, rst, ao_en, bus_a_o, ao_o);
	
	--DI
	di_switch_1:
		switch port map (di_o, di_en(0), bus_a_i);
	di_switch_2:
		switch port map (di_o, di_en(1), bus_b_i);
	data_in:
		reg port map (clk, rst, (not do_en), memd_o, di_o);
		
	--DO
	data_out:
		reg port map (clk, rst, do_en, bus_b_o, do_o);
	
	--data memory
	data_memory:
		mem	port map (ao_o, do_o, do_en, clk, memd_o);
	
	--instruction memory
	instruction_memory:
		mem port map (pc_o, dummy_16bit, zero, clk, memi_o);
	
end datapath_arch;