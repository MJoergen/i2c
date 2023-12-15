library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity tb_rtc_reader is
end entity tb_rtc_reader;

architecture simulation of tb_rtc_reader is

  signal clk         : std_logic := '1';
  signal rst         : std_logic := '1';
  signal running     : std_logic := '1';

  signal start       : std_logic;
  signal busy        : std_logic;
  signal rtc         : std_logic_vector(64 downto 0);
  signal cpu_wait    : std_logic;
  signal cpu_ce      : std_logic;
  signal cpu_we      : std_logic;
  signal cpu_addr    : std_logic_vector( 7 downto 0);
  signal cpu_wr_data : std_logic_vector(15 downto 0);
  signal cpu_rd_data : std_logic_vector(15 downto 0);

  signal scl_in      : std_logic_vector( 7 downto 0) := (others => 'H');
  signal sda_in      : std_logic_vector( 7 downto 0) := (others => 'H');
  signal scl_out     : std_logic_vector( 7 downto 0) := (others => 'H');
  signal sda_out     : std_logic_vector( 7 downto 0) := (others => 'H');
  signal scl         : std_logic;
  signal sda         : std_logic;

begin

  clk <= running and not clk after 10 ns; -- 50 MHz
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------
  -- Main test procedure
  ----------------------------------------------

  test_proc : process
    constant C_RTC_EXP : std_logic_vector(64 downto 0) := "1" & X"4077665544332211";
  begin
    start <= '0';
    wait until rst = '0';
    wait until rising_edge(clk);
    assert rtc = "0" & X"4000000101000000"
      report "Incorrect rtc start";

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    assert busy = '1'
      report "Missing busy";

    wait until busy = '0';
    wait until rising_edge(clk);
    assert rtc = C_RTC_EXP
      report "Incorrect rtc end. Got: " & to_hstring(rtc) & ", Expected:" & to_hstring(C_RTC_EXP);

    report "Test completed";
    running <= '0';
    wait;
  end process test_proc;


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  rtc_reader_inst : entity work.rtc_reader
    port map (
      clk_i         => clk,
      rst_i         => rst,
      start_i       => start,
      busy_o        => busy,
      rtc_o         => rtc,
      cpu_wait_i    => cpu_wait,
      cpu_ce_o      => cpu_ce,
      cpu_we_o      => cpu_we,
      cpu_addr_o    => cpu_addr,
      cpu_wr_data_o => cpu_wr_data,
      cpu_rd_data_i => cpu_rd_data
    ); -- rtc_reader_inst


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
      cpu_wait_o    => cpu_wait,
      cpu_ce_i      => cpu_ce,
      cpu_we_i      => cpu_we,
      cpu_addr_i    => cpu_addr,
      cpu_wr_data_i => cpu_wr_data,
      cpu_rd_data_o => cpu_rd_data,
      scl_in_i      => scl_in,
      sda_in_i      => sda_in,
      scl_out_o     => scl_out,
      sda_out_o     => sda_out
    ); -- i_i2c_controller

  sda <= sda_out(0) when sda_out(0) = '0' else 'H';
  scl <= scl_out(0) when scl_out(0) = '0' else '1';
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
       G_INIT        => X"8877665544332211",
       G_CLOCK_FREQ  => 50e6,
       G_I2C_ADDRESS => b"1010001"
     )
     port map (
        clk_i  => clk,
        rst_i  => rst,
        sda_io => sda,
        scl_io => scl
     ); -- i2c_mem_sim_inst

end architecture simulation;

