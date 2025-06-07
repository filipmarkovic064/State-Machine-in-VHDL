
-- library IEEE;
-- use IEEE.std_logic_1164.all;
-- use IEEE.numeric_std.all;

-- entity pulse_width_modulator is
--   generic (
--     MCLK_FREQ : integer := 100_000_000;  -- Master clock frequency (Hz)
--     PWM_FREQ  : integer := 2000;       -- Desired PWM frequency (Hz)
--     MIN_OFF   : integer := 255;        -- Minimum off time (in clock cycles)
--     MIN_ON    : integer := 4080        -- Minimum on time (in clock cycles)
--   );
--   port (
--     mclk       : in  std_logic;
--     reset      : in  std_logic;
--     duty_cycle : in  std_logic_vector(7 downto 0);  -- 8-bit two's complement (-128 to 127)
--     DIR        : out std_logic;  -- Motor direction output (for H-bridge)
--     EN         : out std_logic   -- PWM enable output (drives the motor power)
--   );
-- end entity pulse_width_modulator;

-- architecture Behavioral of pulse_width_modulator is

--   constant PWM_PERIOD : integer := MCLK_FREQ / PWM_FREQ;  -- e.g. 50000 cycles

--   -- Four-state FSM with Idle (dead-time) states:
--   type state_type is (Forward_Idle, Forward, Reverse_Idle, Reverse);
--   signal pwm_state : state_type := Reverse_Idle;  -- default on reset

--   -- Internal signals.
--   signal pwm_counter           : integer range 0 to PWM_PERIOD - 1 := 0;
--   signal duty_cycle_reg        : std_logic_vector(7 downto 0) := (others => '0');
--   -- A one-cycle registered change flag.
--   signal duty_cycle_changed_reg: std_logic := '0';
--   signal scaled_duty           : integer range 0 to PWM_PERIOD := 0;

--   -- Registers for outputs (now driven inside the FSM process).
--   signal en_reg  : std_logic := '0';
--   signal dir_reg : std_logic := '0';

-- begin

--   process(mclk, reset)
--   begin
--     if reset = '1' then
--       duty_cycle_reg         <= (others => '0');
--       duty_cycle_changed_reg <= '0';
--     elsif rising_edge(mclk) then
--       if duty_cycle /= duty_cycle_reg then
--          duty_cycle_changed_reg <= '1';
--       else
--          duty_cycle_changed_reg <= '0';
--       end if;
--       duty_cycle_reg <= duty_cycle;
--     end if;
--   end process;

--   process(mclk, reset)
--   begin
--     if reset = '1' then
--       pwm_counter <= 0;
--     elsif rising_edge(mclk) then
--       if duty_cycle_changed_reg = '1' then
--          pwm_counter <= 0;
--       elsif pwm_counter = PWM_PERIOD - 1 then
--          pwm_counter <= 0;
--       else
--          pwm_counter <= pwm_counter + 1;
--       end if;
--     end if;
--   end process;

--   process(mclk, reset)
--     variable abs_duty  : integer;
--     variable temp_duty : integer;
--   begin
--     if reset = '1' then
--       pwm_state   <= Reverse_Idle;
--       scaled_duty <= 0;
--       en_reg      <= '0';
--       dir_reg     <= '0';
--     elsif rising_edge(mclk) then
--       if duty_cycle_changed_reg = '1' then
--          -- On a duty cycle change, force dead time (EN off)
--          scaled_duty <= 0;
--          en_reg <= '0';
--          -- Immediately update DIR based on the new sign.
--          if to_integer(signed(duty_cycle)) > 0 then
--            pwm_state <= Forward_Idle;
--            dir_reg <= '1';
--          else
--            pwm_state <= Reverse_Idle;
--            dir_reg <= '0';
--          end if;
--       else
--          case pwm_state is
--            when Forward =>
--              if to_integer(signed(duty_cycle)) > 0 then
--                 abs_duty  := to_integer(abs(signed(duty_cycle)));
--                 temp_duty := (abs_duty * PWM_PERIOD) / 128;
--                 if (temp_duty > 0) and (temp_duty < MIN_ON) then
--                    temp_duty := MIN_ON;
--                 elsif (temp_duty < PWM_PERIOD) and ((PWM_PERIOD - temp_duty) < MIN_OFF) then
--                    temp_duty := PWM_PERIOD - MIN_OFF;
--                 end if;
--                 scaled_duty <= temp_duty;
--                 if pwm_counter < temp_duty then
--                    en_reg <= '1';
--                 else
--                    en_reg <= '0';
--                 end if;
--                 -- Ensure DIR remains active.
--                 dir_reg <= '1'; 
--              else
--                 pwm_state   <= Forward_Idle;
--                 scaled_duty <= 0;
--                 en_reg      <= '0';
--              end if;

--            when Reverse =>
--              if duty_cycle(7) = '1' then
--                 abs_duty  := to_integer(abs(signed(duty_cycle)));
--                 temp_duty := (abs_duty * PWM_PERIOD) / 128;
--                 if (temp_duty > 0) and (temp_duty < MIN_ON) then
--                    temp_duty := MIN_ON;
--                 elsif (temp_duty < PWM_PERIOD) and ((PWM_PERIOD - temp_duty) < MIN_OFF) then
--                    temp_duty := PWM_PERIOD - MIN_OFF;
--                 end if;
--                 scaled_duty <= temp_duty;
--                 if pwm_counter < temp_duty then
--                    en_reg <= '1';
--                 else
--                    en_reg <= '0';
--                 end if;
--                 dir_reg <= '0';
--              else
--                 pwm_state   <= Reverse_Idle;
--                 scaled_duty <= 0;
--                 en_reg      <= '0';
--              end if;

--            when Forward_Idle =>
--              -- Dead time: force EN off.
--              scaled_duty <= 0;
--              en_reg <= '0';
--              if pwm_counter = PWM_PERIOD - 1 then
--                 if to_integer(signed(duty_cycle)) > 0 then
--                    abs_duty  := to_integer(abs(signed(duty_cycle)));
--                    temp_duty := (abs_duty * PWM_PERIOD) / 128;
--                    if (temp_duty > 0) and (temp_duty < MIN_ON) then
--                       temp_duty := MIN_ON;
--                    elsif (temp_duty < PWM_PERIOD) and ((PWM_PERIOD - temp_duty) < MIN_OFF) then
--                       temp_duty := PWM_PERIOD - MIN_OFF;
--                    end if;
--                    scaled_duty <= temp_duty;
--                    pwm_state <= Forward;
--                    if pwm_counter < temp_duty then
--                       en_reg <= '1';
--                    else
--                       en_reg <= '0';
--                    end if;
--                    dir_reg <= '1';
--                 else
--                    pwm_state <= Reverse_Idle;
--                 end if;
--              end if;

--            when Reverse_Idle =>
--              scaled_duty <= 0;
--              en_reg <= '0';
--              if pwm_counter = PWM_PERIOD - 1 then
--                 if duty_cycle(7) = '1' then
--                    abs_duty  := to_integer(abs(signed(duty_cycle)));
--                    temp_duty := (abs_duty * PWM_PERIOD) / 128;
--                    if (temp_duty > 0) and (temp_duty < MIN_ON) then
--                       temp_duty := MIN_ON;
--                    elsif (temp_duty < PWM_PERIOD) and ((PWM_PERIOD - temp_duty) < MIN_OFF) then
--                       temp_duty := PWM_PERIOD - MIN_OFF;
--                    end if;
--                    scaled_duty <= temp_duty;
--                    pwm_state <= Reverse;
--                    if pwm_counter < temp_duty then
--                       en_reg <= '1';
--                    else
--                       en_reg <= '0';
--                    end if;
--                    dir_reg <= '0';
--                 else
--                    pwm_state <= Forward_Idle;
--                 end if;
--              end if;
--          end case;
--       end if;
--     end if;
--   end process;

--   EN  <= en_reg;
--   DIR <= dir_reg;

-- end architecture Behavioral;


-------------------------------- TESTER NOE HER -----------------------------------------------
library ieee;

use ieee.std_logic_1164.all;

use ieee.numeric_std.all;

 

entity pwm is

  generic(

           dc_width : natural := 8;

           counter_width  : natural := dc_width+6

         );

  port(

  mclk, reset : in std_logic;

  duty_cycle : in std_logic_vector(dc_width-1 downto 0);

  dir, en    : out std_logic

);

end entity;

 

architecture asm of pwm is

  -------------------- Initial declarations ----------------------------------

  type state is (REV_IDLE, FORW_IDLE, REVERSE, FORWARD);  -- type declaration for states

  alias duty_sign : std_logic is duty_cycle(dc_width-1);  -- alias the top bit of the duty cycle

 

  signal present_state, next_state : state;               -- signal for the present and next state in state type

  signal r_count, next_count : unsigned(counter_width-1 downto 0):= (others => '0'); -- counter for the pwm pulse

 

begin

 

  -------------------- REGISTER UPDATE PROCESS ----------------------------------

  -- Updating all register values, including counter

  register_update : process(mclk)

  begin

    if rising_edge(mclk) then

      if reset = '1' then

        present_state <= REV_IDLE;

        r_count <= (others => '0');

      else

        present_state <= next_state;

        r_count <= next_count;

      end if; -- reset

    end if; -- rising_edge

  end process; -- register_update

 

  next_count <= r_count + 1; -- single definition of next_count, no update needed

 

 

  -------------------- STATE UPDATE PROCESS ----------------------------------

  -- process for finding next state combinatoricly

  update_state: process(all) is

  begin

    -- Combine logic: Flip direction within 1 cycle of sign change

    case present_state is

 

      when REV_IDLE =>

        if duty_sign then -- if duty_sign is 1 then it is <duty_cycle < 0> in asmd

          next_state <= REVERSE;

        else

          next_state <= FORW_IDLE;

        end if;

 

      when REVERSE =>

        if duty_sign then

          next_state <= FORW_IDLE;

        else

          next_state <= REV_IDLE;

        end if;

 

      when FORW_IDLE =>

        if duty_sign then

          next_state <= REV_IDLE;

        else

          next_state <= FORWARD;

        end if;

 

      when FORWARD =>

        if duty_sign then

          next_state <= FORW_IDLE;

        else

          next_state <= FORWARD;

        end if;

    end case;

 

  end process; -- update_state

 

  -------------------- OUTPUT UPDATE PROCESS ----------------------------------

  -- output control for the pwm signal

  output_cl: process(all) is

    variable pwm_pulse : std_logic := '0';

  begin

    -- use the msbs of count for the pwm signal comparison, must add 1 bit for the unsigned absolute value of dc

    -- in order to make it 8 bits

    pwm_pulse := '0' when

          (r_count(counter_width-1 downto 6) >= unsigned(abs(signed(duty_cycle)) & '0'))

          else '1';

 

    -- control the outputs based on the state

    case present_state is

      when forw_idle =>

        en <= '0';

        dir <= '1';

      when forward =>

        en <= pwm_pulse;

        dir <= '1';

      when rev_idle =>

        en <= '0';

        dir <= '0';

      when reverse =>

        en <= pwm_pulse;

        dir <= '0';

    end case; --present_state

  end process; -- output_cl

 

end asm;