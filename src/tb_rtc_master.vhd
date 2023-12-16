library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity tb_rtc_master is
end entity tb_rtc_master;

architecture simulation of tb_rtc_master is

  signal clk           : std_logic := '1';
  signal rst           : std_logic := '1';
  signal running       : std_logic := '1';

  signal rtc_busy      : std_logic;
  signal rtc_read      : std_logic;
  signal rtc_write     : std_logic;
  signal rtc_wr_data   : std_logic_vector(63 downto 0);
  signal rtc_rd_data   : std_logic_vector(63 downto 0);
  signal cpu_m_wait    : std_logic;
  signal cpu_m_ce      : std_logic;
  signal cpu_m_we      : std_logic;
  signal cpu_m_addr    : std_logic_vector( 7 downto 0);
  signal cpu_m_wr_data : std_logic_vector(15 downto 0);
  signal cpu_m_rd_data : std_logic_vector(15 downto 0);

  signal scl_in        : std_logic_vector( 7 downto 0) := (others => 'H');
  signal sda_in        : std_logic_vector( 7 downto 0) := (others => 'H');
  signal scl_out       : std_logic_vector( 7 downto 0) := (others => 'H');
  signal sda_out       : std_logic_vector( 7 downto 0) := (others => 'H');
  signal scl           : std_logic;
  signal sda           : std_logic;

begin

  clk <= running and not clk after 10 ns; -- 50 MHz
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------
  -- Main test procedure
  ----------------------------------------------

  test_proc : process
    constant C_RTC_EXP_START : std_logic_vector(63 downto 0) := X"00_00_01_01_00_00_00_00";
    constant C_RTC_EXP_END   : std_logic_vector(63 downto 0) := X"77_66_55_44_33_22_11_00";
  begin
    rtc_read  <= '0';
    rtc_write <= '0';
    wait until rst = '0';
    wait until rising_edge(clk);
    assert rtc_rd_data = C_RTC_EXP_START
      report "Incorrect rtc start. Got: " & to_hstring(rtc_rd_data) & ", Expected:" & to_hstring(C_RTC_EXP_START);

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    assert rtc_busy = '1'
      report "Missing busy";

    wait until rtc_busy = '0';
    wait until rising_edge(clk);
    assert rtc_rd_data = C_RTC_EXP_END
      report "Incorrect rtc end. Got: " & to_hstring(rtc_rd_data) & ", Expected:" & to_hstring(C_RTC_EXP_END);

    report "Test completed";
    running <= '0';
    wait;
  end process test_proc;


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  rtc_master_inst : entity work.rtc_master
    generic map (
      G_BOARD => "MEGA65_R5"
    )
    port map (
      clk_i           => clk,
      rst_i           => rst,
      rtc_busy_o      => rtc_busy,
      rtc_read_i      => rtc_read,
      rtc_write_i     => rtc_write,
      rtc_wr_data_i   => rtc_wr_data,
      rtc_rd_data_o   => rtc_rd_data,
      cpu_m_wait_i    => cpu_m_wait,
      cpu_m_ce_o      => cpu_m_ce,
      cpu_m_we_o      => cpu_m_we,
      cpu_m_addr_o    => cpu_m_addr,
      cpu_m_wr_data_o => cpu_m_wr_data,
      cpu_m_rd_data_i => cpu_m_rd_data
    ); -- rtc_master_inst


  ----------------------------------------------
  -- Instantiate QNICE-to-I2C interface mapper
  ----------------------------------------------

  i_i2c_controller : entity work.i2c_controller
    generic map (
      G_I2C_CLK_DIV => 40
    )
    port map (
      clk_i         => clk,
      rst_i         => rst,
      cpu_wait_o    => cpu_m_wait,
      cpu_ce_i      => cpu_m_ce,
      cpu_we_i      => cpu_m_we,
      cpu_addr_i    => cpu_m_addr,
      cpu_wr_data_i => cpu_m_wr_data,
      cpu_rd_data_o => cpu_m_rd_data,
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
        clk_i  => clk,
        rst_i  => rst,
        sda_io => sda,
        scl_io => scl
     ); -- i2c_mem_sim_inst

end architecture simulation;

