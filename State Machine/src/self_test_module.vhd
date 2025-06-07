-- library ieee;
-- use ieee.std_logic_1164.all;
-- use ieee.numeric_std.all;
-- use std.textio.all;

-- entity self_test_module is
--     generic(
--         DATA_WIDTH  : natural  := 8; -- Size of data
--         ADDR_WIDTH  : natural  := 20; -- ROM entries (20 values)
--         FILE_PATH   : string    := "pwm_values.txt";
--         MAX_COUNT   : natural  := 300_000_000); -- 3 seconds at clock speed
--     port(
--         clk        : in std_ulogic;
--         rst        : in std_ulogic;
--         output_duty: out std_ulogic_vector(DATA_WIDTH-1 downto 0));
-- end entity;

-- architecture behavioral of self_test_module is
--     -- Definition of memory array to hold PWM values
--     type pwm_memory is array(0 to ADDR_WIDTH-1) of std_ulogic_vector(DATA_WIDTH-1 downto 0);
--     signal cycle_counter : unsigned(29 downto 0) := (others => '0');
--     signal address_index : integer range 0 to ADDR_WIDTH-1 := 0;
--     signal enable       : std_ulogic := '1'; 

--     -- Impure function to initialize the ROM from a text file
--     impure function load_ROM(file_name: string) return pwm_memory is
--         file data_file: text open read_mode is file_name;
--         variable line_buffer: line;
--         variable rom_data: pwm_memory;
--     begin
--         for idx in rom_data'range loop
--             readline(data_file, line_buffer);
--             read(line_buffer, rom_data(idx));
--         end loop;
--         return rom_data;
--     end;

--     -- ROM initialization
--     constant ROM_VALUES: pwm_memory := load_ROM(FILE_PATH);

-- begin
--     process(clk, rst)
--     begin
--         if rising_edge(clk) then
--             if rst = '1' then
--                 cycle_counter <= (others => '0');
--                 address_index <= 0;
--                 output_duty <= (others => '0');
--                 enable <= '1';
--             else
--                 if (cycle_counter = MAX_COUNT - 1) and (enable = '1') then
--                     cycle_counter <= (others => '0');
--                     output_duty <= ROM_VALUES(address_index);
                    
--                     -- Update address index or disable further output
--                     if address_index = ADDR_WIDTH - 1 then
--                         enable <= '0';
--                     else
--                         address_index <= address_index + 1;
--                     end if;
--                 else
--                     if enable = '1' then
--                         cycle_counter <= cycle_counter + 1;
--                     end if;
--                 end if;
--             end if;
--         end if;
--     end process;
-- end behavioral;


--TEST STARTER HER --

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use std.textio.all;

entity self_test_module is
    generic(
        data_width: natural  := 8; -- Size of data
        addr_width: natural  := 20; -- ROM entries (20 values)
        filename  : string   := "pwm_values.txt";
        threesec  : natural  := 300_000_000); --300000000);
    port(
        mclk, reset  : in std_ulogic;
        duty_cycle   : out std_ulogic_vector(7 downto 0));
end entity;

architecture synth of self_test_module is
    -- Reading from file and storing inside ROM
    type memory_array is array(addr_width-1 downto 0) of std_ulogic_vector(data_width-1 downto 0);
    -- Signals for displaying logic of ROM elements
    signal counter    : u_unsigned(29 downto 0) := (others => '0');
    signal ROM_index  : natural    := 0;
    signal en         : std_ulogic := '1'; 

    -- Function for retrieving data
    impure function initialize_ROM(file_name: string) return memory_array is
        file init_file: text open read_mode is file_name;
        variable current_line: line;
        variable result: memory_array;
    begin
        for i in result'range loop
            readline(init_file, current_line);
            read(current_line, result(i));
        end loop;
        return result;
    end;
    
    -- initializing ROM to make it synthesizable 
    constant ROM_DATA: memory_array := initialize_ROM(filename);

begin
    process(reset, mclk)
    begin
    -- Prosess som inkrementerer ROM_index som er den som indekserer elementer
    -- i ROM_DATA. Bruke counter til å telle slik at hvert element vises 
    -- i litt tid (3 sek kun når alt funker (29-bit counter))
        if rising_edge(mclk) then
            if reset then
                counter    <= (others => '0');
                ROM_index  <= 0;
                duty_cycle  <= (others => '0');

            else
                if (counter = threesec - 1) and (en = '1') then
                    counter    <= (others => '0');
                    duty_cycle <= ROM_DATA(ROM_index);
                    if ROM_index = addr_width - 1 then
                        en <= '0';
                    else
                        ROM_index <= ROM_index + 1;
                    end if;
                elsif en = '1' then
                    counter <= counter + 1;
                end if;
            end if;
        end if;
    end process;
end synth;