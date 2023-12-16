library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_rtc_master is
   generic (
      G_BOARD : string
   );
end entity tb_rtc_master;

architecture simulation of tb_rtc_master is

  signal clk         : std_logic := '1';
  signal rst         : std_logic := '1';
  signal running     : std_logic := '1';

  signal rtc_busy    : std_logic;
  signal rtc_read    : std_logic;
  signal rtc_write   : std_logic;
  signal rtc_wr_data : std_logic_vector(63 downto 0);
  signal rtc_rd_data : std_logic_vector(63 downto 0);

  signal cpu_wait    : std_logic;
  signal cpu_ce      : std_logic;
  signal cpu_we      : std_logic;
  signal cpu_addr    : std_logic_vector( 7 downto 0);
  signal cpu_wr_data : std_logic_vector(15 downto 0);
  signal cpu_rd_data : std_logic_vector(15 downto 0);

  signal rtc_value   : unsigned(63 downto 0);

begin

  clk <= running and not clk after 10 ns; -- 50 MHz
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------
  -- Main test procedure
  ----------------------------------------------

  test_proc : process

    procedure rtc_write_data (
      data : in std_logic_vector(63 downto 0)) is
    begin
      rtc_write   <= '1';
      rtc_wr_data <= data;
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      rtc_write   <= '0';
      rtc_wr_data <= (others => '0');
      assert rtc_busy = '1'
        report "Missing busy";
      wait until rtc_busy = '0';
      wait until rising_edge(clk);
      wait until rising_edge(clk);
    end procedure rtc_write_data;

    procedure rtc_verify_data (
      str  : string;
      data : in std_logic_vector(63 downto 0)) is
    begin
      assert rtc_rd_data = data
        report "Incorrect rtc_rd_data " & str & ". Got: " & to_hstring(rtc_rd_data) & ", Expected:" & to_hstring(data);
    end procedure rtc_verify_data;

  begin
    -- Verify reset value
    rtc_read  <= '0';
    rtc_write <= '0';
    wait until rst = '0';
    wait until rising_edge(clk);
    assert std_logic_vector(rtc_value) = X"88_77_66_55_44_33_22_11";
    rtc_verify_data("START", X"00_00_01_01_00_00_00_00");

    -- Verify transaction is started right after reset
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    assert rtc_busy = '1'
      report "Missing busy";

    -- Verify correct value after reset
    wait until rtc_busy = '0';
    wait until rising_edge(clk);
    rtc_verify_data("READ1", X"88_77_66_55_44_33_22_11");

    -- Verify new value can be set
    rtc_write_data(X"06_99_12_31_23_59_59_99");
    assert std_logic_vector(rtc_value) = X"06_99_12_31_23_59_59_99";

    rtc_read <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    assert rtc_busy = '1'
      report "Missing busy";
    rtc_read <= '0';
    wait until rtc_busy = '0';
    wait until rising_edge(clk);

    rtc_verify_data("READ2", X"06_99_12_31_23_59_59_99");
    assert std_logic_vector(rtc_value) = X"06_99_12_31_23_59_59_99";

    report "Test completed";
    running <= '0';
    wait;
  end process test_proc;


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  rtc_master_inst : entity work.rtc_master
    generic map (
      G_BOARD => G_BOARD
    )
    port map (
      clk_i           => clk,
      rst_i           => rst,
      rtc_busy_o      => rtc_busy,
      rtc_read_i      => rtc_read,
      rtc_write_i     => rtc_write,
      rtc_wr_data_i   => rtc_wr_data,
      rtc_rd_data_o   => rtc_rd_data,
      cpu_m_wait_i    => cpu_wait,
      cpu_m_ce_o      => cpu_ce,
      cpu_m_we_o      => cpu_we,
      cpu_m_addr_o    => cpu_addr,
      cpu_m_wr_data_o => cpu_wr_data,
      cpu_m_rd_data_i => cpu_rd_data
    ); -- rtc_master_inst


   rtc_sim_inst : entity work.rtc_sim
      generic map (
         G_BOARD => G_BOARD
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
         rtc_o         => rtc_value
      ); -- rtc_sim_inst

end architecture simulation;

