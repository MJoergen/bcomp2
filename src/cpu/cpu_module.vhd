library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- cpu_module.vhd

entity cpu_module is

    port (
             -- Clock input from crystal.
             clk_i       : in    std_logic;

             rst_i       : in    std_logic;

             addr_o      : out   std_logic_vector (3 downto 0);

             data_io     : inout std_logic_vector (7 downto 0);

             cs_out_o    : out   std_logic;
             cs_ram_o    : out   std_logic;
             wr_o        : out   std_logic;
             hlt_o       : out   std_logic;

             led_array_o : out   std_logic_vector(8*8-1 downto 0)
         );

end cpu_module;

architecture Structural of cpu_module is

    -- Data bus
    signal data_in       : std_logic_vector (7 downto 0);
    signal data          : std_logic_vector (7 downto 0);
    signal areg_value    : std_logic_vector (7 downto 0);
    signal breg_value    : std_logic_vector (7 downto 0);
    signal alu_value     : std_logic_vector (7 downto 0);

    -- Address bus
    signal pc_value      : std_logic_vector (3 downto 0);

    -- Communication between blocks
    signal ireg_value    : std_logic_vector (7 downto 0);
    signal carry         : std_logic;
    signal carry_reg     : std_logic; -- Registered value of carry
    signal pc_load       : std_logic;

    -- Debug outputs connected to LEDs
    signal counter       : std_logic_vector (1 downto 0); -- from Control module.

    -- Control signals
    signal control       : std_logic_vector (16 downto 0);

    -- Data bus
    alias  control_DO_IREG   : std_logic is control(0);   -- Instruction register output enable
    alias  control_DO_AREG   : std_logic is control(1);   -- A register output enable
    alias  control_DO_ALU    : std_logic is control(2);   -- ALU output enable
    alias  control_DI_IREG   : std_logic is control(3);   -- Instruction register load
    alias  control_DI_AREG   : std_logic is control(4);   -- A register load
    alias  control_DI_BREG   : std_logic is control(5);   -- B register load
    alias  control_DI_PC     : std_logic is control(6);   -- Program counter jump
    alias  control_DI_PCC    : std_logic is control(7);   -- Jump if carry
    alias  control_DB_ENABLE : std_logic is control(8);   -- Databus enable
    -- Address bus
    alias  control_AO_PC     : std_logic is control(9);   -- Program counter output enable
    alias  control_AO_IREG   : std_logic is control(10);  -- Instruction register output enable
    -- Chip select
    alias  control_CS_RAM    : std_logic is control(11);  -- RAM output enable
    alias  control_CS_OUT    : std_logic is control(12);  -- Output register load
    alias  control_WR        : std_logic is control(13);  -- RAM load (write)
    -- Miscellaneous
    alias  control_CE        : std_logic is control(14);  -- Program counter count enable
    alias  control_SU        : std_logic is control(15);  -- ALU subtract
    alias  control_HLT       : std_logic is control(16);  -- Halt clock

begin

    led_array_o <= ireg_value &                  -- IREG
                   control(15 downto 0) &        -- CONH & CONL
                   clk_i & '0' & counter & pc_value &  -- PC
                   breg_value &                  -- BREG
                   areg_value &                  -- AREG
                   alu_value &                   -- ALU
                   data_io;                      -- BUS

    data_in <= data_io when control_CS_RAM = '1' else
               data;

    data_io <= data when control_DB_ENABLE = '1' else
               "ZZZZZZZZ";

    addr_o <= pc_value               when control_AO_PC = '1'   else
              ireg_value(3 downto 0) when control_AO_IREG = '1' else
              "ZZZZ";


    hlt_o    <= control_HLT;
    cs_out_o <= control_CS_OUT;
    cs_ram_o <= control_CS_RAM;
    wr_o     <= control_WR;

    pc_load <= control_DI_PC or (control_DI_PCC and carry_reg);

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if control_DO_ALU = '1' then
                carry_reg <= carry;
            end if;
        end if;
    end process;

    -- Instantiate Control module
    inst_control : entity work.control
    port map (
                 clk_i       => clk_i      ,
                 rst_i       => rst_i      ,
                 instruct_i  => ireg_value(7 downto 4) ,
                 control_o   => control    ,
                 counter_o   => counter       -- Debug output
             );

    -- Instantiate Program counter
    inst_program_counter : entity work.program_counter
    port map (
                 clk_i       => clk_i       ,
                 clr_i       => rst_i       ,
                 data_io     => data        ,
                 load_i      => pc_load     ,
                 enable_i    => '0'         ,
                 count_i     => control_CE  ,
                 led_o       => pc_value      -- Debug output
             );

    -- Instantiate Instruction register
    inst_instruction_register : entity work.instruction_register
    port map (
                 clk_i       => clk_i      ,
                 clr_i       => rst_i      ,
                 load_i      => control_DI_IREG ,
                 enable_i    => control_DO_IREG ,
                 data_in     => data_in    ,
                 data_out    => data    ,
                 reg_o       => ireg_value   -- to instruction decoder
             );

    -- Instantiate A-register
    inst_a_register : entity work.register_8bit
    port map (
                 clk_i       => clk_i      ,
                 clr_i       => rst_i      ,
                 load_i      => control_DI_AREG ,
                 enable_i    => control_DO_AREG ,
                 data_in     => data_in    ,
                 data_out    => data    ,
                 reg_o       => areg_value   -- to ALU
             );

    -- Instantiate B-register
    inst_b_register : entity work.register_8bit
    port map (
                 clk_i       => clk_i      ,
                 clr_i       => rst_i      ,
                 load_i      => control_DI_BREG ,
                 enable_i    => '0'        ,
                 data_in     => data_in    ,
                 data_out    => open       ,
                 reg_o       => breg_value   -- to ALU
             );

    -- Instantiate ALU
    inst_alu : entity work.alu
    port map (
                 sub_i       => control_SU ,
                 enable_i    => control_DO_ALU ,
                 areg_i      => areg_value ,
                 breg_i      => breg_value ,
                 result_o    => data    ,
                 carry_o     => carry      ,
                 led_o       => alu_value    -- Debug output
             );


end Structural;

