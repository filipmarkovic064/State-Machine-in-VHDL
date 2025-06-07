library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity output_synchronizer is
  port(
      mclk, dir, en : in std_ulogic;
      dir_sync, en_sync : out std_ulogic
    );
end entity;

architecture rtl of output_synchronizer is
  signal en_sync_ff1, en_sync_ff2: std_ulogic := '0';
  signal dir_sync_ff1, dir_sync_ff2 : std_ulogic := '0';
  alias en_async : std_ulogic is en;
  alias dir_async : std_ulogic is dir;

begin
  update_dff : process(mclk) is
  begin
    if rising_edge(mclk) then
      en_sync_ff1 <= en_async;
      en_sync_ff2 <= en_sync_ff1;
      dir_sync_ff1 <= dir_async;
      dir_sync_ff2 <= dir_sync_ff1;
    end if;
  end process;

  dir_sync <= dir_sync_ff2;
  en_sync <= en_sync_ff2;
end rtl;
