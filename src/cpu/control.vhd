library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- control.vhd

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

-- Most instructions take two cycles - one fetch and one execute.
-- Only ADD and SUB take three cycles.

entity control is

    port (
             -- System clock
             clk_i      : in  std_logic;

             -- Reset signal
             rst_i      : in  std_logic;

             -- Current instruction executing
             instruct_i : in  std_logic_vector(3 downto 0);

             -- The derived clock output
             control_o  : out std_logic_vector(17 downto 0);

             -- Debug output
             counter_o  : out std_logic_vector(1 downto 0)
         );

end control;

architecture Structural of control is

    subtype control_type is std_logic_vector(17 downto 0);

    -- Data bus
    constant control_DO_IREG   : integer :=  0;  -- Instruction register output enable
    constant control_DO_AREG   : integer :=  1;  -- A register output enable
    constant control_DO_ALU    : integer :=  2;  -- ALU output enable
    constant control_DI_IREG   : integer :=  3;  -- Instruction register load
    constant control_DI_AREG   : integer :=  4;  -- A register load
    constant control_DI_BREG   : integer :=  5;  -- B register load
    constant control_DI_PCREG  : integer :=  6;  -- Program counter load (jump)
    constant control_DB_ENABLE : integer :=  7;  -- Drive the external data bus
    constant control_RESTART   : integer :=  8; -- Begin new instruction
    -- Address bus
    constant control_AO_PC     : integer :=  9;  -- Program counter output enable
    constant control_AO_IREG   : integer := 10; -- Memory address register load
    -- Chip select
    constant control_CS_RAM    : integer := 11; -- Chip select RAM
    constant control_CS_OUT    : integer := 12; -- Chip select peripheral
    constant control_WR        : integer := 13; -- Write enable
    -- Miscellaneous
    constant control_CE        : integer := 14; -- Program counter increment
    constant control_SU        : integer := 15; -- ALU subtract
    constant control_HLT       : integer := 16; -- Output register load
    constant control_MASK      : integer := 17; -- Mask carry register

    signal control       : control_type;
    signal counter       : std_logic_vector(1 downto 0) := "00"; -- Four possible states
    signal micro_op_addr : integer range 0 to 3*16-1;

    ------------------------------------------
    -- List of all possible micro-instructions
    ------------------------------------------

    constant NOP : control_type := (
            others => '0');

    -- Not a separate micro-op, but should rather be OR'ed to the last micro-op of each instruction.
    constant RESTART : control_type := (
            control_RESTART => '1',
            others => '0');

    -- Common for all instructions
    constant FETCH : control_type := (
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
            control_DO_IREG  => '1',
            control_DI_PCREG => '1',
            others => '0');

    -- LDI
    constant IR_TO_AREG : control_type := (
            control_DO_IREG => '1',
            control_DI_AREG => '1',
            others => '0');

    -- JC
    constant IR_TO_PC_CARRY : control_type := (
            control_DO_IREG  => '1',
            control_DI_PCREG => '1',
            control_MASK     => '1',
            others => '0');

    -- HLT
    constant HLT : control_type := (
            control_HLT => '1',
            others => '0');

    type micro_op_rom_type is array(0 to 3*16-1) of std_logic_vector(17 downto 0);

    constant micro_op_rom : micro_op_rom_type := (
        FETCH,  NOP            or RESTART,  NOP,         -- 0000  NOP
        FETCH,  MEM_TO_AREG    or RESTART,  NOP,         -- 0001  LDA [addr]
        FETCH,  MEM_TO_BREG,                ALU_TO_AREG, -- 0010  ADD [addr]
        FETCH,  MEM_TO_BREG_SUB,            ALU_TO_AREG, -- 0011  SUB [addr]
        FETCH,  AREG_TO_MEM    or RESTART,  NOP,         -- 0100  STA [addr]
        FETCH,  AREG_TO_OUT    or RESTART,  NOP,         -- 0101  OUT
        FETCH,  IR_TO_PC       or RESTART,  NOP,         -- 0110  JMP
        FETCH,  IR_TO_AREG     or RESTART,  NOP,         -- 0111  LDI
        FETCH,  IR_TO_PC_CARRY or RESTART,  NOP,         -- 1000  JC
        FETCH,  HLT            or RESTART,  NOP,         -- 1001  HLT
        FETCH,  HLT            or RESTART,  NOP,         -- 1010  HLT
        FETCH,  HLT            or RESTART,  NOP,         -- 1011  HLT
        FETCH,  HLT            or RESTART,  NOP,         -- 1100  HLT
        FETCH,  HLT            or RESTART,  NOP,         -- 1101  HLT
        FETCH,  HLT            or RESTART,  NOP,         -- 1110  HLT
        FETCH,  HLT            or RESTART,  NOP);        -- 1111  HLT

begin

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            counter <= (others => '0');
        elsif rising_edge(clk_i) then
            if (counter = 2) or (control(control_RESTART) = '1') then
                counter <= "00";
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    micro_op_addr <= conv_integer(instruct_i)*3 + conv_integer(counter);
    control <= micro_op_rom(micro_op_addr);

    control_o <= control;
    counter_o <= counter;

end Structural;

