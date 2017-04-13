library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.ram74ls189_datatypes.all;
use work.vga_bitmap_pkg.ALL;

-- This is the top level

entity bcomp is

    generic (
                SIMULATION : boolean := false;
                FREQ       : integer := 25000000 -- Input clock frequency
            );
    port (
             -- Clock
             clk_i     : in  std_logic;  -- 25 MHz

             -- Input switches, buttons, and PMOD's
             sw_i      : in  std_logic_vector (7 downto 0);
             btn_i     : in  std_logic_vector (3 downto 0);
             pmod_i    : in  std_logic_vector (15 downto 0);

             -- Output LEDs
             led_o     : out std_logic_vector (7 downto 0);

             -- Output 7-segment display
             seg_ca_o  : out std_logic_vector (6 downto 0);
             seg_dp_o  : out std_logic;
             seg_an_o  : out std_logic_vector (3 downto 0);

             -- Output to VGA monitor
             vga_hs_o  : out std_logic;
             vga_vs_o  : out std_logic;
             vga_col_o : out std_logic_vector(7 downto 0)
         );

end bcomp;

architecture Structural of bcomp is

    -- The main internal clock
    signal clk  : std_logic;

    -- Interpretation of input buttons and switches.
    alias btn_clk          : std_logic is btn_i(0); -- Singlestep clock
    alias btn_write        : std_logic is btn_i(1); -- Used for programming the RAM
    alias btn_reset        : std_logic is btn_i(2); -- Global reset

    alias sw_clk_free      : std_logic is sw_i(0);  -- Clock source
    alias sw_runmode       : std_logic is sw_i(1);  -- Used for programming the RAM
    alias led_select       : std_logic_vector (3 downto 0)
                                       is sw_i(5 downto 2);
    alias sw_disp_two_comp : std_logic is sw_i(6);  -- Display two's complement

    -- Used for programming the RAM.
    alias pmod_address     : std_logic_vector (3 downto 0)
                                    is pmod_i(11 downto 8);
    alias pmod_data        : std_logic_vector (7 downto 0)
                                    is pmod_i( 7 downto 0);

    -- Data bus
    signal data     : std_logic_vector (7 downto 0);

    -- Address bus
    signal addr_cpu : std_logic_vector (3 downto 0);
    signal addr_ram : std_logic_vector (3 downto 0);

    -- Chip select
    signal cs_out   : std_logic;
    signal cs_ram   : std_logic;
    signal wr       : std_logic;
    signal hlt      : std_logic;

    -- Debug output
    signal led_array     : std_logic_vector (VGA_ROWS*8-1 downto 0);
    signal content_high  : ram_type;
    signal content_low   : ram_type;
    signal led_array_cpu : std_logic_vector (8*8-1 downto 0);
    signal ram_value     : std_logic_vector (7 downto 0);
    signal disp_value    : std_logic_vector (7 downto 0);

begin

    -- This entire array is displayed on the VGA monitor
    led_array <= content_high(15) & content_low(15) & 
                 content_high(14) & content_low(14) & 
                 content_high(13) & content_low(13) & 
                 led_array_cpu &
                 disp_value &                -- OUT
                 "0000" & addr_ram &         -- ADDR
                 ram_value;                  -- RAM

    -- Select a subset to show on the onboard LED's
    led_o <= led_array(conv_integer(led_select)*8+7 downto conv_integer(led_select)*8);

    -- This multiplexer is used when programming the RAM from the external PMOD's.
    addr_ram <= pmod_address when sw_runmode = '0' else addr_cpu;

    -- Instantiate Clock module
    inst_clock_module : entity work.clock_module
    generic map (
                    SIMULATION => SIMULATION
                )
    port map (
                 clk_i       => clk_i       , -- External crystal
                 sw_i        => sw_clk_free ,
                 btn_i       => btn_clk     ,
                 hlt_i       => hlt         ,
                 clk_deriv_o => clk           -- Main internal clock
             );

    -- Instantiate CPU module
    inst_cpu_module : entity work.cpu_module
    port map (
                 clk_i       => clk           ,
                 rst_i       => btn_reset     ,
                 addr_o      => addr_cpu      ,
                 data_io     => data          ,
                 cs_out_o    => cs_out        ,
                 cs_ram_o    => cs_ram        ,
                 wr_o        => wr            ,
                 hlt_o       => hlt           ,
                 led_array_o => led_array_cpu    -- Debug output
             );

    -- Instantiate RAM module
    -- The initial contents correspond to the following program
    -- 0x00  0x71  LDI 0x01
    -- 0x01  0x4E  STA [0x0E]  y = 1
    -- 0x02  0x70  LDI 0x00    x = 0
    -- 0x03  0x50  OUT
    -- 0x04  0x2E  ADD [0x0E]
    -- 0x05  0x4F  STA [0x0F]  z = x+y
    -- 0x06  0x1E  LDA [0x0E]
    -- 0x07  0x4D  STA [0x0D]  x = y
    -- 0x08  0x1F  LDA [0x0F]
    -- 0x09  0x4E  STA [0x0E]  y = z
    -- 0x0A  0x1D  LDA [0x0D]
    -- 0x0B  0x80  JC  0x00
    -- 0x0C  0x63  JMP 0x03
    -- 0x0D        x
    -- 0x0E        y
    -- 0x0F        z
    inst_ram_module : entity work.ram_module
    generic map (
                    INITIAL_HIGH => (
                        "0111", "0100", "0111", "0101", "0010", "0100", "0001", "0100",
                        "0001", "0100", "0001", "1000", "0110", "0000", "0000", "0000"),
                    INITIAL_LOW => (
                        "0001", "1110", "0000", "0000", "1110", "1111", "1110", "1101",
                        "1111", "1110", "1101", "0000", "0011", "0000", "0000", "0000")
                )
    port map (
                 clk_i          => clk          ,
                 wr_i           => wr           ,
                 enable_i       => cs_ram       ,
                 data_io        => data         ,
                 address_i      => addr_ram     ,

                 runmode_i      => sw_runmode   ,  -- Programming mode
                 sw_data_i      => pmod_data    ,  -- Programming mode
                 wr_button_i    => btn_write    ,  -- Programming mode

                 data_led_o     => ram_value    ,  -- Debug output
                 content_high_o => content_high ,  -- Debug output
                 content_low_o  => content_low     -- Debug output
             );

    -- Instantiate VGA module
    inst_vga_module : entity work.vga_module
    port map (
                 clk_i       => clk_i      , -- 25 MHz crystal clock
                 led_array_i => led_array  ,
                 vga_HS_o    => vga_hs_o   ,
                 vga_VS_o    => vga_vs_o   ,
                 vga_col_o   => vga_col_o
             );

    -- Instantiate Peripheral module
    inst_peripheral_module : entity work.peripheral_module
    port map (
                 clk_i      => clk_i            ,  -- 25 MHz crystal clock
                 rst_i      => btn_reset        ,
                 data_i     => data             ,
                 cs_i       => cs_out           ,
                 mode_i     => sw_disp_two_comp ,
                 seg_ca_o   => seg_ca_o         ,
                 seg_dp_o   => seg_dp_o         ,
                 seg_an_o   => seg_an_o         ,
                 data_led_o => disp_value          -- Debug output
             );

end Structural;

