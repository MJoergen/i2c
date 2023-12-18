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

   pure function get_rtc_mask(board : string) return std_logic_vector is
   begin
      if board = "MEGA65_R3" then
         return X"FF_FF_FF_FF_FF_FF_FF_00";
      else
         return X"FF_FF_FF_FF_FF_FF_FF_FF";
      end if;
   end function get_rtc_mask;

   --                                                              WD YY MM DD HH MM SS ss
   constant C_RESET_RTC_VALUE : std_logic_vector(63 downto 0) := X"00_00_01_01_00_00_00_00";
   constant C_INIT_RTC_VALUE  : std_logic_vector(63 downto 0) := X"06_23_12_17_08_22_45_72" and get_rtc_mask(G_BOARD);
   constant C_NEXT_RTC_VALUE  : std_logic_vector(63 downto 0) := std_logic_vector(unsigned(C_INIT_RTC_VALUE) + X"0000000000000001");
   constant C_NEW_RTC_VALUE   : std_logic_vector(63 downto 0) := X"04_24_03_20_11_43_51_77" and get_rtc_mask(G_BOARD);
   constant C_NEW2_RTC_VALUE  : std_logic_vector(63 downto 0) := std_logic_vector(unsigned(C_NEW_RTC_VALUE) + X"0000000000000001");

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
         wait until rising_edge(clk);
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

      -- Simulation model already has the initial time
      assert rtc_sim_value = unsigned(C_INIT_RTC_VALUE)
         report "Incorrect rtc_sim_value start. Got: " & to_hstring(rtc_sim_value) &
         ", expected: " & to_hstring(C_INIT_RTC_VALUE);

      -- Timer value reported to core is not yet initialized
      assert rtc = "0" & X"40" & C_RESET_RTC_VALUE(63 downto 8)
         report "Incorrect rtc start. Got: " & to_hstring(rtc) &
         ", expected: " & to_hstring("0" & X"40" & C_RESET_RTC_VALUE(63 downto 8));

      -- Verify values after reset
      cpu_verify(X"00", X"0000"); -- 100ths
      cpu_verify(X"01", X"0000"); -- Seconds
      cpu_verify(X"02", X"0000"); -- Minutes
      cpu_verify(X"03", X"0000"); -- Hours
      cpu_verify(X"04", X"0001"); -- DayOfMongth
      cpu_verify(X"05", X"0001"); -- Month
      cpu_verify(X"06", X"0000"); -- Year since 2000
      cpu_verify(X"07", X"0000"); -- DayOfWeek
      cpu_verify(X"08", X"0001"); -- Internal clock is running
      cpu_verify(X"09", X"0001"); -- I2C is busy (read in progress)

      -- Wait for initial read to complete
      wait for 200 us;
      wait until rising_edge(clk);

      -- Verify simulation model unchanged
      assert rtc_sim_value = unsigned(C_INIT_RTC_VALUE)
         report "Incorrect rtc_sim_value 1. Got: " & to_hstring(rtc_sim_value) &
         ", expected: " & to_hstring(C_INIT_RTC_VALUE);

      -- Verify timer value reported to core is correctly read from RTC
      assert rtc = "1" & X"40" & C_INIT_RTC_VALUE(63 downto 8)
         report "Incorrect rtc 1. Got: " & to_hstring(rtc) &
         ", expected: " & to_hstring("0" & X"40" & C_INIT_RTC_VALUE(63 downto 8));

      -- Verify internal timer correctly read from RTC
      cpu_verify(X"00", X"00" & C_INIT_RTC_VALUE( 7 downto  0)); -- 100ths
      cpu_verify(X"01", X"00" & C_INIT_RTC_VALUE(15 downto  8)); -- Seconds
      cpu_verify(X"02", X"00" & C_INIT_RTC_VALUE(23 downto 16)); -- Minutes
      cpu_verify(X"03", X"00" & C_INIT_RTC_VALUE(31 downto 24)); -- Hours
      cpu_verify(X"04", X"00" & C_INIT_RTC_VALUE(39 downto 32)); -- DayOfMongth
      cpu_verify(X"05", X"00" & C_INIT_RTC_VALUE(47 downto 40)); -- Month
      cpu_verify(X"06", X"00" & C_INIT_RTC_VALUE(55 downto 48)); -- Year since 2000
      cpu_verify(X"07", X"00" & C_INIT_RTC_VALUE(63 downto 56)); -- DayOfWeek
      cpu_verify(X"08", X"0001");                                -- Internal clock is running
      cpu_verify(X"09", X"0000");                                -- I2C is idle

      -- Verify write not possible when timer is running
      cpu_write( X"00", X"FFFF");
      cpu_write( X"01", X"FFFF");
      cpu_write( X"02", X"FFFF");
      cpu_write( X"03", X"FFFF");
      cpu_write( X"04", X"FFFF");
      cpu_write( X"05", X"FFFF");
      cpu_write( X"06", X"FFFF");
      cpu_write( X"07", X"FFFF");
      cpu_verify(X"00", X"00" & C_INIT_RTC_VALUE( 7 downto  0)); -- 100ths
      cpu_verify(X"01", X"00" & C_INIT_RTC_VALUE(15 downto  8)); -- Seconds
      cpu_verify(X"02", X"00" & C_INIT_RTC_VALUE(23 downto 16)); -- Minutes
      cpu_verify(X"03", X"00" & C_INIT_RTC_VALUE(31 downto 24)); -- Hours
      cpu_verify(X"04", X"00" & C_INIT_RTC_VALUE(39 downto 32)); -- DayOfMongth
      cpu_verify(X"05", X"00" & C_INIT_RTC_VALUE(47 downto 40)); -- Month
      cpu_verify(X"06", X"00" & C_INIT_RTC_VALUE(55 downto 48)); -- Year since 2000
      cpu_verify(X"07", X"00" & C_INIT_RTC_VALUE(63 downto 56)); -- DayOfWeek
      cpu_verify(X"08", X"0001");                                -- Internal clock is running
      cpu_verify(X"09", X"0000");                                -- I2C is idle

      -- Verify timer value reported to core is unchanged
      assert rtc = "1" & X"40" & C_INIT_RTC_VALUE(63 downto 8)
         report "Incorrect rtc 1. Got: " & to_hstring(rtc) &
         ", expected: " & to_hstring("0" & X"40" & C_INIT_RTC_VALUE(63 downto 8));

      -- Verify read from RTC not possible when timer is running
      cpu_write( X"09", X"0002");                                -- Initiate read from RTC
      cpu_verify(X"08", X"0001");                                -- Internal clock is running
      cpu_verify(X"09", X"0000");                                -- I2C is idle

      -- Verify write to RTC not possible when timer is running
      cpu_write( X"09", X"0004");                                -- Initiate write to RTC
      cpu_verify(X"08", X"0001");                                -- Internal clock is running
      cpu_verify(X"09", X"0000");                                -- I2C is idle

      -- Verify timer is running
      wait for 1 ms;
      wait until rising_edge(clk);
      cpu_verify(X"00", X"00" & C_NEXT_RTC_VALUE( 7 downto  0)); -- 100ths
      cpu_verify(X"01", X"00" & C_NEXT_RTC_VALUE(15 downto  8)); -- Seconds
      cpu_verify(X"02", X"00" & C_NEXT_RTC_VALUE(23 downto 16)); -- Minutes
      cpu_verify(X"03", X"00" & C_NEXT_RTC_VALUE(31 downto 24)); -- Hours
      cpu_verify(X"04", X"00" & C_NEXT_RTC_VALUE(39 downto 32)); -- DayOfMongth
      cpu_verify(X"05", X"00" & C_NEXT_RTC_VALUE(47 downto 40)); -- Month
      cpu_verify(X"06", X"00" & C_NEXT_RTC_VALUE(55 downto 48)); -- Year since 2000
      cpu_verify(X"07", X"00" & C_NEXT_RTC_VALUE(63 downto 56)); -- DayOfWeek
      cpu_verify(X"08", X"0001");                                -- Internal clock is running
      cpu_verify(X"09", X"0000");                                -- I2C is idle

      -- Verify timer can be stopped
      cpu_write( X"08", X"0000");                                -- Stop internal timer
      cpu_verify(X"08", X"0000");                                -- Internal clock is stopped
      cpu_verify(X"09", X"0000");                                -- I2C is idle

      -- Verify timer is stopped
      wait for 1 ms;
      wait until rising_edge(clk);
      cpu_verify(X"00", X"00" & C_NEXT_RTC_VALUE( 7 downto  0)); -- 100ths
      cpu_verify(X"01", X"00" & C_NEXT_RTC_VALUE(15 downto  8)); -- Seconds
      cpu_verify(X"02", X"00" & C_NEXT_RTC_VALUE(23 downto 16)); -- Minutes
      cpu_verify(X"03", X"00" & C_NEXT_RTC_VALUE(31 downto 24)); -- Hours
      cpu_verify(X"04", X"00" & C_NEXT_RTC_VALUE(39 downto 32)); -- DayOfMongth
      cpu_verify(X"05", X"00" & C_NEXT_RTC_VALUE(47 downto 40)); -- Month
      cpu_verify(X"06", X"00" & C_NEXT_RTC_VALUE(55 downto 48)); -- Year since 2000
      cpu_verify(X"07", X"00" & C_NEXT_RTC_VALUE(63 downto 56)); -- DayOfWeek
      cpu_verify(X"08", X"0000");                                -- Internal clock is stopped
      cpu_verify(X"09", X"0000");                                -- I2C is idle

      -- Verify write to local timer
      cpu_write( X"00", X"00" & C_NEW_RTC_VALUE( 7 downto  0));  -- 100ths
      cpu_write( X"01", X"00" & C_NEW_RTC_VALUE(15 downto  8));  -- Seconds
      cpu_write( X"02", X"00" & C_NEW_RTC_VALUE(23 downto 16));  -- Minutes
      cpu_write( X"03", X"00" & C_NEW_RTC_VALUE(31 downto 24));  -- Hours
      cpu_write( X"04", X"00" & C_NEW_RTC_VALUE(39 downto 32));  -- DayOfMongth
      cpu_write( X"05", X"00" & C_NEW_RTC_VALUE(47 downto 40));  -- Month
      cpu_write( X"06", X"00" & C_NEW_RTC_VALUE(55 downto 48));  -- Year since 2000
      cpu_write( X"07", X"00" & C_NEW_RTC_VALUE(63 downto 56));  -- DayOfWeek
      cpu_verify(X"00", X"00" & C_NEW_RTC_VALUE( 7 downto  0));  -- 100ths
      cpu_verify(X"01", X"00" & C_NEW_RTC_VALUE(15 downto  8));  -- Seconds
      cpu_verify(X"02", X"00" & C_NEW_RTC_VALUE(23 downto 16));  -- Minutes
      cpu_verify(X"03", X"00" & C_NEW_RTC_VALUE(31 downto 24));  -- Hours
      cpu_verify(X"04", X"00" & C_NEW_RTC_VALUE(39 downto 32));  -- DayOfMongth
      cpu_verify(X"05", X"00" & C_NEW_RTC_VALUE(47 downto 40));  -- Month
      cpu_verify(X"06", X"00" & C_NEW_RTC_VALUE(55 downto 48));  -- Year since 2000
      cpu_verify(X"07", X"00" & C_NEW_RTC_VALUE(63 downto 56));  -- DayOfWeek

      -- Verify timer value reported to core is updated
      assert rtc = "1" & X"40" & C_NEW_RTC_VALUE(63 downto 8)
         report "Incorrect rtc 1. Got: " & to_hstring(rtc) &
         ", expected: " & to_hstring("0" & X"40" & C_NEW_RTC_VALUE(63 downto 8));

      -- Verify write to RTC is possible
      cpu_write( X"09", X"0004");                                -- Initiate write to RTC
      cpu_verify(X"08", X"0000");                                -- Internal clock is stopped
      cpu_verify(X"09", X"0001");                                -- I2C is busy

      -- Verify timer cannot be started when busy
      cpu_write( X"08", X"0001");                                -- Try to start internal clock
      cpu_verify(X"08", X"0000");                                -- Internal clock is still stopped

      wait for 200 us;
      wait until rising_edge(clk);

      -- Verify transaction done
      cpu_verify(X"08", X"0000");                                -- Internal clock is stopped
      cpu_verify(X"09", X"0000");                                -- I2C is idle

      -- Verify simulation model is updated
      assert rtc_sim_value = unsigned(C_NEW_RTC_VALUE)
         report "Incorrect rtc_sim_value start. Got: " & to_hstring(rtc_sim_value) &
         ", expected: " & to_hstring(C_NEW_RTC_VALUE);

      -- Clear local timer
      cpu_write( X"00", X"0001");  -- 100ths
      cpu_write( X"01", X"0001");  -- Seconds
      cpu_write( X"02", X"0001");  -- Minutes
      cpu_write( X"03", X"0001");  -- Hours
      cpu_write( X"04", X"0001");  -- DayOfMongth
      cpu_write( X"05", X"0001");  -- Month
      cpu_write( X"06", X"0001");  -- Year since 2000
      cpu_write( X"07", X"0001");  -- DayOfWeek
      cpu_verify(X"00", X"0001");  -- 100ths
      cpu_verify(X"01", X"0001");  -- Seconds
      cpu_verify(X"02", X"0001");  -- Minutes
      cpu_verify(X"03", X"0001");  -- Hours
      cpu_verify(X"04", X"0001");  -- DayOfMongth
      cpu_verify(X"05", X"0001");  -- Month
      cpu_verify(X"06", X"0001");  -- Year since 2000
      cpu_verify(X"07", X"0001");  -- DayOfWeek

      -- Verify read from RTC is possible
      cpu_write( X"09", X"0002");                                -- Initiate read from RTC
      cpu_verify(X"08", X"0000");                                -- Internal clock is stopped
      cpu_verify(X"09", X"0001");                                -- I2C is busy

      -- Verify timer cannot be started when busy
      cpu_write( X"08", X"0001");                                -- Try to start internal clock
      cpu_verify(X"08", X"0000");                                -- Internal clock is still stopped

      wait for 200 us;
      wait until rising_edge(clk);

      -- Verify transaction done
      cpu_verify(X"08", X"0000");                                -- Internal clock is stopped
      cpu_verify(X"09", X"0000");                                -- I2C is idle

      -- Verify local timer updated
      cpu_verify(X"00", X"00" & C_NEW_RTC_VALUE( 7 downto  0));  -- 100ths
      cpu_verify(X"01", X"00" & C_NEW_RTC_VALUE(15 downto  8));  -- Seconds
      cpu_verify(X"02", X"00" & C_NEW_RTC_VALUE(23 downto 16));  -- Minutes
      cpu_verify(X"03", X"00" & C_NEW_RTC_VALUE(31 downto 24));  -- Hours
      cpu_verify(X"04", X"00" & C_NEW_RTC_VALUE(39 downto 32));  -- DayOfMongth
      cpu_verify(X"05", X"00" & C_NEW_RTC_VALUE(47 downto 40));  -- Month
      cpu_verify(X"06", X"00" & C_NEW_RTC_VALUE(55 downto 48));  -- Year since 2000
      cpu_verify(X"07", X"00" & C_NEW_RTC_VALUE(63 downto 56));  -- DayOfWeek

      -- Verify timer can be started
      cpu_write( X"08", X"0001");                                -- Start internal timer
      cpu_verify(X"08", X"0001");                                -- Internal clock is running
      cpu_verify(X"09", X"0000");                                -- I2C is idle

      -- Verify timer is running
      wait for 1 ms;
      wait until rising_edge(clk);
      cpu_verify(X"00", X"00" & C_NEW2_RTC_VALUE( 7 downto  0)); -- 100ths
      cpu_verify(X"01", X"00" & C_NEW2_RTC_VALUE(15 downto  8)); -- Seconds
      cpu_verify(X"02", X"00" & C_NEW2_RTC_VALUE(23 downto 16)); -- Minutes
      cpu_verify(X"03", X"00" & C_NEW2_RTC_VALUE(31 downto 24)); -- Hours
      cpu_verify(X"04", X"00" & C_NEW2_RTC_VALUE(39 downto 32)); -- DayOfMongth
      cpu_verify(X"05", X"00" & C_NEW2_RTC_VALUE(47 downto 40)); -- Month
      cpu_verify(X"06", X"00" & C_NEW2_RTC_VALUE(55 downto 48)); -- Year since 2000
      cpu_verify(X"07", X"00" & C_NEW2_RTC_VALUE(63 downto 56)); -- DayOfWeek
      cpu_verify(X"08", X"0001");                                -- Internal clock is running
      cpu_verify(X"09", X"0000");                                -- I2C is idle

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
      G_CLK_SPEED_HZ  => 5_000_000, -- Factor of ten in simulation time
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

