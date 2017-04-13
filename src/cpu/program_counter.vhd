library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- program_counter.vhd

entity program_counter is

    port (
             -- Clock input
             clk_i       : in std_logic;
             clr_i       : in std_logic;

             -- Control inputs
             count_i     : in std_logic; -- Increment value
             load_i      : in std_logic; -- Store new value

             -- Data bus connection
             addr_i      : in std_logic_vector(3 downto 0);

             -- Address bus connection
             addr_o      : out std_logic_vector(3 downto 0)
         );

end program_counter;

architecture Structural of program_counter is

    signal addr : std_logic_vector(3 downto 0);

begin
    
    process(clk_i, clr_i)
    begin
        if clr_i = '1' then
            addr <= (others => '0');
        elsif rising_edge(clk_i) then
            if load_i = '1' then
                addr <= addr_i;
            elsif count_i = '1' then
                addr <= addr + "0001";
            end if;
        end if;
    end process;

    addr_o <= addr;

end Structural;

