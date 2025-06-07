library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_level_system is
  generic (
            DC_WIDTH   : natural := 8
          );
  port (
          mclk     : in  std_logic;
          reset   : in  std_logic;
          sa, sb  : in  std_logic;
          dir_out : out std_logic;
          en_out  : out std_logic;
          c       : out std_logic;
          abcdefg : out std_logic_vector(6 downto 0)
        );
end entity;

architecture rtl of top_level_system is

  signal duty_cycle : std_logic_vector(DC_WIDTH-1 downto 0);
  signal internal_dir, internal_en    : std_ulogic;
  signal sa_sync_int, sb_sync_int : std_ulogic;
  signal pos_inc_int, pos_dec_int : std_ulogic;
  signal velocity_internal : signed(7 downto 0);

  component quadrature_decoder is
    port(
    mclk, reset        : in std_ulogic;
    sa, sb            : in std_ulogic;
    pos_inc, pos_dec  : out std_ulogic
  );
  end component;

  component seg7ctrl is 
    port ( 
           mclk : in std_logic; -- 100MHz, positive flank
           reset : in std_logic; -- Asynchronous reset, active high
           d0 : in std_logic_vector(3 downto 0); 
           d1 : in std_logic_vector(3 downto 0); 
           abcdefg : out std_logic_vector(6 downto 0); 
           c : out std_logic 
         ); 
  end component; 

  component velocity_reader is
    port(
          mclk      : in std_logic; 
          reset     : in std_logic; 
          pos_inc   : in std_logic;
          pos_dec   : in std_logic;
          velocity  : out signed(7 downto 0) -- rpm value updated every 1/100 s 
        );
  end component;

  component input_synchronizer is
    port(
    mclk, sa, sb : in std_ulogic;
    sa_sync, sb_sync : out std_ulogic
  );
  end component;

  component self_test_module
    port (
           mclk        : in  std_logic;
           reset      : in  std_logic;
           duty_cycle : out std_logic_vector(DC_WIDTH-1 downto 0)
         );
  end component;

  component pwm
    port (
           mclk       : in  std_logic;
           reset      : in  std_logic;
           duty_cycle : in  std_logic_vector(dc_width-1 downto 0);
           dir        : out std_logic;
           en         : out std_logic
         );
  end component;

  component output_synchronizer
    port (
           mclk      : in  std_logic;
           dir       : in  std_logic;
           en        : in  std_logic;
           dir_sync  : out std_logic;
           en_sync   : out std_logic
         );
  end component;

begin

  input_sync_int : input_synchronizer
  port map (
             mclk       => mclk,
             sa         => sa,
             sb         => sb,
             sa_sync    => sa_sync_int,
             sb_sync    => sb_sync_int 
           );

  quad_inst : quadrature_decoder
  port map(
            mclk       => mclk, 
            sa        => sa_sync_int,
            sb        => sb_sync_int,
            reset     => reset,   
            pos_inc   => pos_inc_int, 
            pos_dec   => pos_dec_int
          );

  vr : velocity_reader
  port map(
            mclk      => mclk,
            reset     => reset,
            pos_inc   => pos_inc_int,
            pos_dec   => pos_dec_int,
            velocity  => velocity_internal
          );

  seg7ctrl_inst : seg7ctrl
  port map (
             mclk       => mclk,
             reset      => reset,
             c          => c,
             abcdefg    => abcdefg,
             d0         => std_logic_vector(velocity_internal(7 downto 4)),
             d1         => std_logic_vector(velocity_internal(3 downto 0))
           );

  self_test_inst : self_test_module
  port map (
             mclk        => mclk,
             reset      => reset,
             duty_cycle => duty_cycle
           );

  pwm_inst : pwm
  port map (
             mclk        => mclk,
             reset       => reset,
             duty_cycle  => duty_cycle,
             dir         => internal_dir,
             en          => internal_en
           );

  sync_inst : output_synchronizer
  port map (
             mclk      => mclk,
             dir       => internal_dir,
             en        => internal_en,
             dir_sync  => dir_out,
             en_sync   => en_out
           );

end architecture;
