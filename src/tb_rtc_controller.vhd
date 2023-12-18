library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_rtc_controller is
   generic (
      G_BOARD : string
   );
end entity tb_rtc_controller;

architecture simulation of tb_rtc_controller is

   signal clk               : std_logic := '1';
   signal rst               : std_logic := '1';
   signal running           : std_logic := '1';

   signal rtc               : std_logic_vector(64 downto 0);
   signal cpu_qnice_wait    : std_logic;
   signal cpu_qnice_ce      : std_logic;
   signal cpu_qnice_we      : std_logic;
   signal cpu_qnice_addr    : std_logic_vector( 7 downto 0);
   signal cpu_qnice_wr_data : std_logic_vector(15 downto 0);
   signal cpu_qnice_rd_data : std_logic_vector(15 downto 0);
   signal cpu_i2c_wait      : std_logic;
   signal cpu_i2c_ce        : std_logic;
   signal cpu_i2c_we        : std_logic;
   signal cpu_i2c_addr      : std_logic_vector( 7 downto 0);
   signal cpu_i2c_wr_data   : std_logic_vector(15 downto 0);
   signal cpu_i2c_rd_data   : std_logic_vector(15 downto 0);
   signal rtc_sim_value     : unsigned(63 downto 0);

   --                                                              WD YY MM DD HH MM SS ss
   constant C_RESET_RTC_VALUE : std_logic_vector(63 downto 0) := X"00_00_01_01_00_00_00_00";
   constant C_INIT_RTC_VALUE  : std_logic_vector(63 downto 0) := X"06_23_12_17_08_22_45_79";

begin

   clk <= running and not clk after 10 ns; -- 50 MHz
   rst <= '1', '0' after 100 ns;


   ----------------------------------------------
   -- Main test procedure
   ----------------------------------------------

   test_proc : process

      procedure cpu_write (
         addr : in std_logic_vector(7 downto 0);
         data : in std_logic_vector(15 downto 0)) is
      begin
         cpu_qnice_ce      <= '1';
         cpu_qnice_we      <= '1';
         cpu_qnice_addr    <= addr;
         cpu_qnice_wr_data <= data;
         wait until rising_edge(clk);
         while cpu_qnice_wait = '1' loop
            wait until rising_edge(clk);
         end loop;
         cpu_qnice_ce      <= '0';
         cpu_qnice_we      <= '0';
         cpu_qnice_addr    <= (others => '0');
         cpu_qnice_wr_data <= (others => '0');
      end procedure cpu_write;

      procedure cpu_verify (
         addr : in std_logic_vector(7 downto 0);
         data : in std_logic_vector(15 downto 0)) is
      begin
         cpu_qnice_ce      <= '1';
         cpu_qnice_we      <= '0';
         cpu_qnice_addr    <= addr;
         wait until rising_edge(clk);
         while cpu_qnice_wait = '1' loop
            wait until rising_edge(clk);
         end loop;
         cpu_qnice_ce      <= '0';
         cpu_qnice_we      <= '0';
         cpu_qnice_addr    <= (others => '0');
         assert cpu_qnice_rd_data = data
         report "cpu_qnice: Read from address " & to_hstring(addr) & ", got: " &
         to_hstring(cpu_qnice_rd_data) & ", expected: " & to_hstring(data);
         wait until rising_edge(clk);
      end procedure cpu_verify;

   begin
      -- Set reset values
      cpu_qnice_ce      <= '0';
      cpu_qnice_we      <= '0';
      cpu_qnice_addr    <= X"00";
      cpu_qnice_wr_data <= X"0000";

      wait until rst = '0';
      wait until rising_edge(clk);

      cpu_verify(X"00", X"00" & rtc( 7 downto  0)); -- 100ths
      cpu_verify(X"01", X"00" & rtc(15 downto  8)); -- Seconds
      cpu_verify(X"02", X"00" & rtc(23 downto 16)); -- Minutes
      cpu_verify(X"03", X"00" & rtc(31 downto 24)); -- Hours
      cpu_verify(X"04", X"00" & rtc(39 downto 32)); -- DayOfMongth
      cpu_verify(X"05", X"00" & rtc(47 downto 40)); -- Month
      cpu_verify(X"06", X"00" & rtc(55 downto 48)); -- Year since 2000
      cpu_verify(X"07", X"00" & rtc(63 downto 56)); -- DayOfWeek
      cpu_verify(X"08", X"0001");                   -- Internal clock is running
      cpu_verify(X"09", X"0001");                   -- I2C is busy

      assert rtc_sim_value = unsigned(C_INIT_RTC_VALUE)
         report "Incorrect rtc_sim_value start. Got: " & to_hstring(rtc_sim_value) &
         ", expected: " & to_hstring(C_INIT_RTC_VALUE);

      assert rtc = "0" & X"40" & C_RESET_RTC_VALUE(63 downto 8)
         report "Incorrect rtc start. Got: " & to_hstring(rtc) &
         ", expected: " & to_hstring("0" & X"40" & C_RESET_RTC_VALUE(63 downto 8));


      wait for 200 us;
      wait until rising_edge(clk);

      cpu_verify(X"00", X"00" & rtc( 7 downto  0)); -- 100ths
      cpu_verify(X"01", X"00" & rtc(15 downto  8)); -- Seconds
      cpu_verify(X"02", X"00" & rtc(23 downto 16)); -- Minutes
      cpu_verify(X"03", X"00" & rtc(31 downto 24)); -- Hours
      cpu_verify(X"04", X"00" & rtc(39 downto 32)); -- DayOfMongth
      cpu_verify(X"05", X"00" & rtc(47 downto 40)); -- Month
      cpu_verify(X"06", X"00" & rtc(55 downto 48)); -- Year since 2000
      cpu_verify(X"07", X"00" & rtc(63 downto 56)); -- DayOfWeek
      cpu_verify(X"08", X"0001");                   -- Internal clock is running
      cpu_verify(X"09", X"0000");                   -- I2C is idle

      assert rtc_sim_value = unsigned(C_INIT_RTC_VALUE)
         report "Incorrect rtc_sim_value 1. Got: " & to_hstring(rtc_sim_value) &
         ", expected: " & to_hstring(C_INIT_RTC_VALUE);

      assert rtc = "1" & X"40" & C_INIT_RTC_VALUE(63 downto 8)
         report "Incorrect rtc 1. Got: " & to_hstring(rtc) &
         ", expected: " & to_hstring("0" & X"40" & C_INIT_RTC_VALUE(63 downto 8));

      wait until rising_edge(clk);
      report "Test completed";
      wait until rising_edge(clk);
      running <= '0';
      wait;
   end process test_proc;


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

   rtc_controller_inst : entity work.rtc_controller
   generic map (
      G_BOARD         => G_BOARD
   )
   port map (
      clk_i           => clk,
      rst_i           => rst,
      rtc_o           => rtc,
      cpu_s_wait_o    => cpu_qnice_wait,
      cpu_s_ce_i      => cpu_qnice_ce,
      cpu_s_we_i      => cpu_qnice_we,
      cpu_s_addr_i    => cpu_qnice_addr,
      cpu_s_wr_data_i => cpu_qnice_wr_data,
      cpu_s_rd_data_o => cpu_qnice_rd_data,
      cpu_m_wait_i    => cpu_i2c_wait,
      cpu_m_ce_o      => cpu_i2c_ce,
      cpu_m_we_o      => cpu_i2c_we,
      cpu_m_addr_o    => cpu_i2c_addr,
      cpu_m_wr_data_o => cpu_i2c_wr_data,
      cpu_m_rd_data_i => cpu_i2c_rd_data
   ); -- rtc_controller_inst

   rtc_sim_inst : entity work.rtc_sim
   generic map (
      G_INIT  => C_INIT_RTC_VALUE,
      G_BOARD => G_BOARD
   )
   port map (
      clk_i         => clk,
      rst_i         => rst,
      cpu_wait_o    => cpu_i2c_wait,
      cpu_ce_i      => cpu_i2c_ce,
      cpu_we_i      => cpu_i2c_we,
      cpu_addr_i    => cpu_i2c_addr,
      cpu_wr_data_i => cpu_i2c_wr_data,
      cpu_rd_data_o => cpu_i2c_rd_data,
      rtc_o         => rtc_sim_value
   ); -- rtc_sim_inst

end architecture simulation;

