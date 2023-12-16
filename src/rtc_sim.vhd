library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rtc_sim is
   generic (
      G_BOARD : string
   );
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;
      cpu_wait_o    : out std_logic;
      cpu_ce_i      : in  std_logic;
      cpu_we_i      : in  std_logic;
      cpu_addr_i    : in  std_logic_vector( 7 downto 0);
      cpu_wr_data_i : in  std_logic_vector(15 downto 0);
      cpu_rd_data_o : out std_logic_vector(15 downto 0);
      rtc_o         : out unsigned(63 downto 0)
   );
end entity rtc_sim;

architecture simulation of rtc_sim is

   signal sda_out : std_logic_vector(7 downto 0);
   signal scl_out : std_logic_vector(7 downto 0);
   signal sda_in  : std_logic_vector(7 downto 0);
   signal scl_in  : std_logic_vector(7 downto 0);
   signal sda     : std_logic;
   signal scl     : std_logic;

begin

  ----------------------------------------------
  -- Instantiate QNICE-to-I2C interface mapper
  ----------------------------------------------

  i_i2c_controller : entity work.i2c_controller
    generic map (
      G_I2C_CLK_DIV => 40
    )
    port map (
      clk_i         => clk_i,
      rst_i         => rst_i,
      cpu_wait_o    => cpu_wait_o,
      cpu_ce_i      => cpu_ce_i,
      cpu_we_i      => cpu_we_i,
      cpu_addr_i    => cpu_addr_i,
      cpu_wr_data_i => cpu_wr_data_i,
      cpu_rd_data_o => cpu_rd_data_o,
      scl_in_i      => scl_in,
      sda_in_i      => sda_in,
      scl_out_o     => scl_out,
      sda_out_o     => sda_out
    ); -- i_i2c_controller

  sda <= sda_out(0) when sda_out(0) = '0' else 'H';
  scl <= scl_out(0) when scl_out(0) = '0' else 'H';
  sda_in(0) <= sda;
  scl_in(0) <= scl;

  -- Pull-up
  scl <= 'H';
  sda <= 'H';


  ------------------------------------
  -- Instantiate I2C slave device
  ------------------------------------

  i2c_mem_sim_inst : entity work.i2c_mem_sim
     generic map (
       G_INIT        => X"88_77_66_55_44_33_22_11",
       G_CLOCK_FREQ  => 50e6,
       G_I2C_ADDRESS => b"1010001"     -- MEGA65_R5
     )
     port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        mem07_o => rtc_o,
        sda_io  => sda,
        scl_io  => scl
     ); -- i2c_mem_sim_inst

end architecture simulation;

