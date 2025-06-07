library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--Double flip flop same design as output_sync
entity input_synchronizer is
  port(
    mclk     : in std_ulogic;
    sa       : in std_ulogic;
    sb       : in std_ulogic;
    sa_sync  : out std_ulogic;
    sb_sync  : out std_ulogic
  );
end entity;

architecture rtl of input_synchronizer is
  signal sa_sync_ff1, sa_sync_ff2 : std_ulogic := '0';
  signal sb_sync_ff1, sb_sync_ff2 : std_ulogic := '0';
  alias sa_async : std_ulogic is sa;
  alias sb_async : std_ulogic is sb;
begin
  update_ff: process(mclk)
  begin
    if rising_edge(mclk) then
      sa_sync_ff1 <= sa_async;
      sa_sync_ff2 <= sa_sync_ff1;
      sb_sync_ff1 <= sb_async;
      sb_sync_ff2 <= sb_sync_ff1;
    end if;
  end process;
  
  sa_sync <= sa_sync_ff2;
  sb_sync <= sb_sync_ff2;
  
end architecture rtl;
