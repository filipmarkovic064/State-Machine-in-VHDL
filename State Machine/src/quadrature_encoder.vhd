library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity quadrature_decoder is
  port(
    mclk     : in  std_logic;
    reset    : in  std_logic;
    sa       : in  std_logic;      -- Synchronized input from input_synchronizer
    sb       : in  std_logic;      -- Synchronized input from input_synchronizer
    pos_inc  : out std_logic;      -- One-cycle pulse when position increases
    pos_dec  : out std_logic       -- One-cycle pulse when position decreases
    --error    : out std_logic
  );
end entity quadrature_decoder;

architecture Behavioral of quadrature_decoder is

  -- Define states corresponding to the 4 valid encoder combinations.
  type state_type is (S0, S1, S2, S3);
  signal current_state : state_type := S0;  -- initialize to S0 ("00")
  
  -- For convenience, form a 2-bit vector from sa and sb.
  signal encoder : std_logic_vector(1 downto 0);
  
begin

  encoder <= sa & sb;

  process(mclk, reset)
    variable next_state : state_type;
  begin
    if reset = '1' then
      current_state <= S0; --Easier than picking based on SA/SB, can always just swap to the correct state later
      pos_inc <= '0';
      pos_dec <= '0';
    elsif rising_edge(mclk) then
      -- Clear the pulses by default.
      pos_inc <= '0';
      pos_dec <= '0';
      --I ignored the portions where it says that errors will happen because the text said this will never happen
      case current_state is
        when S0 =>
          if encoder = "01" then
            pos_inc <= '1';        -- valid forward transition: 00 -> 01
            next_state := S1;
          elsif encoder = "10" then
            pos_dec <= '1';        -- valid reverse transition: 00 -> 10
            next_state := S3;
          else
            next_state := S0;       -- no valid transition
          end if;
          
        when S1 =>
          if encoder = "11" then
            pos_inc <= '1';        -- 01 -> 11: forward
            next_state := S2;
          elsif encoder = "00" then
            pos_dec <= '1';        -- 01 -> 00: reverse
            next_state := S0;
          else
            next_state := S1;
          end if;
          
        when S2 =>
          if encoder = "10" then
            pos_inc <= '1';        -- 11 -> 10: forward
            next_state := S3;
          elsif encoder = "01" then
            pos_dec <= '1';        -- 11 -> 01: reverse
            next_state := S1;
          else
            next_state := S2;
          end if;
          
        when S3 =>
          if encoder = "00" then
            pos_inc <= '1';        -- 10 -> 00: forward
            next_state := S0;
          elsif encoder = "11" then
            pos_dec <= '1';        -- 10 -> 11: reverse
            next_state := S2;
          else
            next_state := S3;
          end if;
  
      end case;
      current_state <= next_state;
    end if;
  end process;

end architecture Behavioral;
