library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.seg7_pkg.all;

entity seg7ctrl is
    generic(
        MAX_COUNT  : natural := 50_000
    );
    port(
        mclk        : in std_logic; --100Mhz, positive flank
        reset       : in std_logic; --asynchronous reset, active high
        d0          : in std_logic_vector(3 downto 0);
        d1          : in std_logic_vector(3 downto 0);
        abcdefg     : out std_logic_vector(6 downto 0);
        c           : out std_logic
    );
end entity seg7ctrl;

architecture behavioral of seg7ctrl is
    signal counter : natural := 0;
    signal c_reg   : std_logic := '0'; --register to store display selector

    begin 
        process(mclk, reset)
        begin
            if rising_edge(mclk) then
                if reset = '1' then
                    c_reg <= '0';
                elsif counter = MAX_COUNT -1 then
                    c_reg <= not c_reg; 
                    counter <= 0;
                else
                    counter <= counter + 1;
                end if;
                abcdefg <= bin2ssd(d0) when c_reg = '0' else bin2ssd(d1);
            end if;
        end process;
--So basically we use a counter to determine which output shall be seen, this counter is updated very quickly so the human eyes cant tell that its being updated
--Leading it to having two numbers at the same time           
        c <= c_reg;

    end architecture behavioral;
