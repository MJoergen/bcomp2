library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- register_8bit.vhd
-- This entity implements the feature described in the video
-- https://www.youtube.com/watch?v=CiMaWbz_6E8
-- The load and enable pins here are active high, whereas in the video
-- they are active low.
-- The signals 'load_i' and 'enable_i' may not be set high simultaneously.

entity register_8bit is

    port (
             -- Clock input
             clk_i       : in std_logic;

             -- Control inputs
             load_i      : in std_logic; -- called AI or BI or II.
             enable_i    : in std_logic; -- called AO or BO or IO.
             clr_i       : in std_logic;

             -- Data bus connection
             data_in     : in std_logic_vector(7 downto 0);
             data_out    : out std_logic_vector(7 downto 0);

             -- To ALU or Instruction decoder
             reg_o       : out std_logic_vector(7 downto 0)
         );


end register_8bit;

architecture Structural of register_8bit is

    signal data : std_logic_vector(7 downto 0);

begin
    -- pragma synthesis_off
    assert (load_i and enable_i) /= '1';
    -- pragma synthesis_on
    
    process(clk_i, clr_i)
    begin
        if clr_i = '1' then
            data <= (others => '0');
        elsif rising_edge(clk_i) then
            if load_i = '1' then
                data <= data_in;
            end if;
        end if;
    end process;

    reg_o <= data;
    data_out <= data when (enable_i = '1') else "ZZZZZZZZ";

end Structural;

