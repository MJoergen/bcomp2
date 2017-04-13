library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- control.vhd
-- Based on the videos here:
-- https://www.youtube.com/watch?v=9PPrrSyubG0
-- https://www.youtube.com/watch?v=35zLnS3fXeA

-- List of instructions:
-- =====================
-- 0000  NOP  No operation
-- 0001  LDA  Load memory to A
-- 0010  ADD  Add
-- 0011  SUB  Subtract
-- 0100  STA  Copy A to Ram
-- 0101  OUT  Copy A to Output
-- 0110  JMP  Jump to address
-- 0111  LDI  Load immediate to A
-- 1000  JC   Jump if carry flag set
-- 1111  HLT  Halt execution

-- All instructions take six cycles - three fetch and three execute.

entity control is

    port (
             -- System clock
             clk_i      : in  std_logic;

             -- Reset signal
             rst_i      : in  std_logic;

             -- Current instruction executing
             instruct_i : in  std_logic_vector(3 downto 0);

             -- The derived clock output
             control_o  : out std_logic_vector(16 downto 0);

             -- Debug output
             counter_o  : out std_logic_vector(1 downto 0)
         );

end control;

architecture Structural of control is

    subtype control_type is std_logic_vector(16 downto 0);

    -- Data bus
    constant control_DO_IREG   : integer := 0;  -- Instruction register output enable
    constant control_DO_AREG   : integer := 1;  -- A register output enable
    constant control_DO_ALU    : integer := 2;  -- ALU output enable
    constant control_DI_IREG   : integer := 3;  -- Instruction register load
    constant control_DI_AREG   : integer := 4;  -- A register load
    constant control_DI_BREG   : integer := 5;  -- B register load
    constant control_DI_PC     : integer := 6;  -- Program counter jump
    constant control_DI_PCC    : integer := 7;  -- B register output enable
    constant control_DB_ENABLE : integer := 8;
    -- Address bus
    constant control_AO_PC     : integer := 9;  -- Program counter output enable
    constant control_AO_IREG   : integer := 10; -- Memory address register load
    -- Chip select
    constant control_CS_RAM    : integer := 11; -- RAM output enable
    constant control_CS_OUT    : integer := 12; -- Output register load
    constant control_WR        : integer := 13; -- RAM load (write)
    -- Miscellaneous
    constant control_CE        : integer := 14; -- Program counter count enable
    constant control_SU        : integer := 15; -- ALU subtract
    constant control_HLT       : integer := 16; -- Output register load

    signal counter       : std_logic_vector(1 downto 0) := "00"; -- Four possible states
    signal micro_op_addr : integer range 0 to 3*16-1;

    ------------------------------------------
    -- List of all possible micro-instructions
    ------------------------------------------

    constant NOP : control_type := (others => '0');

    -- Common for all instructions
    constant MEM_TO_IR : control_type := (
            control_AO_PC   => '1',
            control_CE      => '1',
            control_CS_RAM  => '1',
            control_DI_IREG => '1',
            others => '0');

    -- LDA [addr]
    constant MEM_TO_AREG : control_type := (
            control_CS_RAM  => '1',
            control_AO_IREG => '1',
            control_DI_AREG => '1',
            others => '0');

    -- ADD [addr]
    constant MEM_TO_BREG : control_type := (
            control_CS_RAM  => '1',
            control_AO_IREG => '1',
            control_DI_BREG => '1',
            others => '0');
    constant ALU_TO_AREG : control_type := (
            control_DO_ALU  => '1',
            control_DI_AREG => '1',
            others => '0');

    -- SUB [addr]
    constant MEM_TO_BREG_SUB : control_type := (
            control_CS_RAM  => '1',
            control_AO_IREG => '1',
            control_SU      => '1',
            control_DI_BREG => '1',
            others => '0');

    -- STA [addr]
    constant AREG_TO_MEM : control_type := (
            control_CS_RAM    => '1',
            control_AO_IREG   => '1',
            control_DB_ENABLE => '1',
            control_DO_AREG   => '1',
            control_WR        => '1',
            others => '0');

    -- OUT
    constant AREG_TO_OUT : control_type := (
            control_DB_ENABLE => '1',
            control_DO_AREG   => '1',
            control_CS_OUT    => '1',
            others => '0');

    -- JMP
    constant IR_TO_PC : control_type := (
            control_DO_IREG => '1',
            control_DI_PC   => '1',
            others => '0');

    -- LDI
    constant IR_TO_AREG : control_type := (
            control_DO_IREG => '1',
            control_DI_AREG => '1',
            others => '0');

    -- JC
    constant IR_TO_PC_CARRY : control_type := (
            control_DO_IREG => '1',
            control_DI_PCC  => '1',
            others => '0');

    -- HLT
    constant HLT : control_type := (
            control_HLT => '1',
            others => '0');

    type micro_op_rom_type is array(0 to 3*16-1) of std_logic_vector(16 downto 0);

    constant micro_op_rom : micro_op_rom_type := (
    -- 0000  NOP
    MEM_TO_IR, NOP, NOP,

    -- 0001  LDA [addr]
    MEM_TO_IR, MEM_TO_AREG, NOP,

    -- 0010  ADD [addr]
    MEM_TO_IR, MEM_TO_BREG, ALU_TO_AREG,

    -- 0011  SUB [addr]
    MEM_TO_IR, MEM_TO_BREG_SUB, ALU_TO_AREG,

    -- 0100  STA [addr]
    MEM_TO_IR, AREG_TO_MEM, NOP,

    -- 0101  OUT
    MEM_TO_IR, AREG_TO_OUT, NOP,

    -- 0110  JMP
    MEM_TO_IR, IR_TO_PC, NOP,

    -- 0111  LDI
    MEM_TO_IR, IR_TO_AREG, NOP,

    -- 1000  JC
    MEM_TO_IR, IR_TO_PC_CARRY, NOP,

    -- 1001  HLT
    MEM_TO_IR, HLT, NOP,

    -- 1010  HLT
    MEM_TO_IR, HLT, NOP,

    -- 1011  HLT
    MEM_TO_IR, HLT, NOP,

    -- 1100  HLT
    MEM_TO_IR, HLT, NOP,

    -- 1101  HLT
    MEM_TO_IR, HLT, NOP,

    -- 1110  HLT
    MEM_TO_IR, HLT, NOP,

    -- 1111  HLT
    MEM_TO_IR, HLT, NOP);

begin

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            counter <= (others => '0');
        elsif rising_edge(clk_i) then
            if counter = 2 then
                counter <= "00";
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    micro_op_addr <= conv_integer(instruct_i)*3 + conv_integer(counter);

    control_o <= micro_op_rom(micro_op_addr);

    counter_o <= counter;

end Structural;

