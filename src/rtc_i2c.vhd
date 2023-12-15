library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity rtc_i2c is
  generic (
    G_I2C_CLK_DIV : integer
  );
  port (
    clk_i         : in  std_logic;
    rst_i         : in  std_logic;

    rtc_o         : out std_logic_vector(64 downto 0);

    -- CPU slave (RTC): Connect to QNICE CPU
    rtc_wait_o    : out std_logic;
    rtc_ce_i      : in  std_logic;
    rtc_we_i      : in  std_logic;
    rtc_addr_i    : in  std_logic_vector( 7 downto 0);
    rtc_wr_data_i : in  std_logic_vector(15 downto 0);
    rtc_rd_data_o : out std_logic_vector(15 downto 0);

    -- CPU slave (I2C): Connect to QNICE CPU
    i2c_wait_o    : out std_logic;
    i2c_ce_i      : in  std_logic;
    i2c_we_i      : in  std_logic;
    i2c_addr_i    : in  std_logic_vector( 7 downto 0);
    i2c_wr_data_i : in  std_logic_vector(15 downto 0);
    i2c_rd_data_o : out std_logic_vector(15 downto 0);

    -- I2C signals
    scl_in_i      : in  std_logic_vector( 7 downto 0);
    sda_in_i      : in  std_logic_vector( 7 downto 0);
    scl_out_o     : out std_logic_vector( 7 downto 0);
    sda_out_o     : out std_logic_vector( 7 downto 0)
  );
end entity rtc_i2c;

architecture synthesis of rtc_i2c is

  signal rtc_i2c_wait    : std_logic;
  signal rtc_i2c_ce      : std_logic;
  signal rtc_i2c_we      : std_logic;
  signal rtc_i2c_addr    : std_logic_vector( 7 downto 0);
  signal rtc_i2c_wr_data : std_logic_vector(15 downto 0);
  signal rtc_i2c_rd_data : std_logic_vector(15 downto 0);

  signal i2c_rtc_wait    : std_logic;
  signal i2c_rtc_ce      : std_logic;
  signal i2c_rtc_we      : std_logic;
  signal i2c_rtc_addr    : std_logic_vector( 7 downto 0);
  signal i2c_rtc_wr_data : std_logic_vector(15 downto 0);
  signal i2c_rtc_rd_data : std_logic_vector(15 downto 0);

begin

  rtc_inst : entity work.rtc
    port map (
      clk_i         => clk_i,
      rst_i         => rst_i,
      cpu_wait_o    => rtc_wait_o,
      cpu_ce_i      => rtc_ce_i,
      cpu_we_i      => rtc_we_i,
      cpu_addr_i    => rtc_addr_i,
      cpu_wr_data_i => rtc_wr_data_i,
      cpu_rd_data_o => rtc_rd_data_o,
      rtc_o         => rtc_o,
      cpu_wait_i    => i2c_wait_o,
      cpu_ce_o      => rtc_i2c_ce,
      cpu_we_o      => rtc_i2c_we,
      cpu_addr_o    => rtc_i2c_addr,
      cpu_wr_data_o => rtc_i2c_wr_data,
      cpu_rd_data_i => i2c_rd_data_o
    ); -- rtc_inst

   qnice_arbit_inst : entity work.qnice_arbit
     port map (
       clk_i        => clk_i,
       rst_i        => rst_i,
       s0_wait_o    => i2c_wait_o,
       s0_ce_i      => i2c_ce_i,
       s0_we_i      => i2c_we_i,
       s0_addr_i    => i2c_addr_i,
       s0_wr_data_i => i2c_wr_data_i,
       s0_rd_data_o => i2c_rd_data_o,
       s1_wait_o    => rtc_i2c_wait,
       s1_ce_i      => rtc_i2c_ce,
       s1_we_i      => rtc_i2c_we,
       s1_addr_i    => rtc_i2c_addr,
       s1_wr_data_i => rtc_i2c_wr_data,
       s1_rd_data_o => rtc_i2c_rd_data,
       m_wait_i     => i2c_rtc_wait,
       m_ce_o       => i2c_rtc_ce,
       m_we_o       => i2c_rtc_we,
       m_addr_o     => i2c_rtc_addr,
       m_wr_data_o  => i2c_rtc_wr_data,
       m_rd_data_i  => i2c_rtc_rd_data
     ); -- qnice_arbit_inst


  ----------------------------------------------
  -- Instantiate QNICE-to-I2C interface mapper
  ----------------------------------------------

  i_i2c_controller : entity work.i2c_controller
    generic map (
      G_I2C_CLK_DIV => G_I2C_CLK_DIV
    )
    port map (
      clk_i         => clk_i,
      rst_i         => rst_i,
      cpu_wait_o    => i2c_rtc_wait,
      cpu_ce_i      => i2c_rtc_ce,
      cpu_we_i      => i2c_rtc_we,
      cpu_addr_i    => i2c_rtc_addr,
      cpu_wr_data_i => i2c_rtc_wr_data,
      cpu_rd_data_o => i2c_rtc_rd_data,
      scl_in_i      => scl_in_i,
      sda_in_i      => sda_in_i,
      scl_out_o     => scl_out_o,
      sda_out_o     => sda_out_o
    ); -- i_i2c_controller

end architecture synthesis;
