library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_rtc_wrapper is
  generic (
    G_BOARD : string
  );
end entity tb_rtc_wrapper;

architecture simulation of tb_rtc_wrapper is

  signal clk         : std_logic := '1';
  signal rst         : std_logic := '1';
  signal running     : std_logic := '1';

  signal rtc         : std_logic_vector(64 downto 0);

  signal rtc_wait    : std_logic;
  signal rtc_ce      : std_logic;
  signal rtc_we      : std_logic;
  signal rtc_addr    : std_logic_vector( 7 downto 0);
  signal rtc_wr_data : std_logic_vector(15 downto 0);
  signal rtc_rd_data : std_logic_vector(15 downto 0);

  signal i2c_wait    : std_logic;
  signal i2c_ce      : std_logic;
  signal i2c_we      : std_logic;
  signal i2c_addr    : std_logic_vector(27 downto 0);
  signal i2c_wr_data : std_logic_vector(15 downto 0);
  signal i2c_rd_data : std_logic_vector(15 downto 0);

  signal scl_in      : std_logic_vector( 7 downto 0) := (others => 'H');
  signal sda_in      : std_logic_vector( 7 downto 0) := (others => 'H');
  signal scl_out     : std_logic_vector( 7 downto 0) := (others => 'H');
  signal sda_out     : std_logic_vector( 7 downto 0) := (others => 'H');
  signal scl         : std_logic;
  signal sda         : std_logic;

  signal mem07       : unsigned(63 downto 0);
  signal mem07_load  : std_logic;

   pure function get_i2c_address(board : string) return unsigned is
   begin
      if board = "MEGA65_R3" then
         return b"1101111";
      else
         return b"1010001";
      end if;
   end function get_i2c_address;

   constant C_I2C_ADDRESS : unsigned(6 downto 0) := get_i2c_address(G_BOARD);

   -- Call this after reading from RTC
   pure function board2int(board : string; arg : std_logic_vector) return std_logic_vector is
   begin
     if board = "MEGA65_R3" then
       return arg(55 downto 0) & X"00";
     else
       -- Valid for R4 and R5
       return arg(39 downto 32) & arg(63 downto 40) & arg(31 downto 0);
     end if;
   end function board2int;

   -- Call this before writing to RTC
   pure function int2board(board : string; arg : std_logic_vector) return std_logic_vector is
   begin
     if board = "MEGA65_R3" then
       return X"00" & arg(63 downto 8);
     else
       -- Valid for R4 and R5
       return arg(55 downto 32) & arg(63 downto 56) & arg(31 downto 0);
     end if;
   end function int2board;

   constant C_RTC_RESET : std_logic_vector(63 downto 0) := X"0000010100000000";
   constant C_RTC_INIT  : std_logic_vector(63 downto 0) := X"1122334455667788";
   constant C_RTC_NEW   : std_logic_vector(63 downto 0) := X"8877665544332211";

begin

  clk <= running and not clk after 10 ns; -- 50 MHz
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------
  -- Main test procedure
  ----------------------------------------------

  test_proc : process
    procedure rtc_write (
      addr : in std_logic_vector(7 downto 0);
      data : in std_logic_vector(15 downto 0)) is
    begin
      rtc_ce      <= '1';
      rtc_we      <= '1';
      rtc_addr    <= addr;
      rtc_wr_data <= data;
      wait until rising_edge(clk);
      while rtc_wait = '1' loop
        wait until rising_edge(clk);
      end loop;
      rtc_ce      <= '0';
      rtc_we      <= '0';
      rtc_addr    <= (others => '0');
      rtc_wr_data <= (others => '0');
    end procedure rtc_write;

    procedure rtc_verify (
      addr : in std_logic_vector(7 downto 0);
      data : in std_logic_vector(15 downto 0)) is
    begin
      rtc_ce      <= '1';
      rtc_we      <= '0';
      rtc_addr    <= addr;
      wait until rising_edge(clk);
      while rtc_wait = '1' loop
        wait until rising_edge(clk);
      end loop;
      rtc_ce      <= '0';
      rtc_we      <= '0';
      rtc_addr    <= (others => '0');
      assert rtc_rd_data = data
        report "RTC: Read from address " & to_hstring(addr) & ", got: " &
               to_hstring(rtc_rd_data) & ", expected: " & to_hstring(data);
      wait until rising_edge(clk);
    end procedure rtc_verify;

    procedure i2c_write (
      addr : in std_logic_vector(27 downto 0);
      data : in std_logic_vector(15 downto 0)) is
    begin
      i2c_ce      <= '1';
      i2c_we      <= '1';
      i2c_addr    <= addr;
      i2c_wr_data <= data;
      wait until rising_edge(clk);
      while i2c_wait = '1' loop
        wait until rising_edge(clk);
      end loop;
      i2c_ce      <= '0';
      i2c_we      <= '0';
      i2c_addr    <= (others => '0');
      i2c_wr_data <= (others => '0');
    end procedure i2c_write;

    procedure i2c_verify (
      addr : in std_logic_vector(27 downto 0);
      data : in std_logic_vector(15 downto 0)) is
    begin
      i2c_ce      <= '1';
      i2c_we      <= '0';
      i2c_addr    <= addr;
      wait until rising_edge(clk);
      while i2c_wait = '1' loop
        wait until rising_edge(clk);
      end loop;
      i2c_ce      <= '0';
      i2c_we      <= '0';
      i2c_addr    <= (others => '0');
      assert i2c_rd_data = data
        report "I2C: Read from address " & to_hstring(addr) & ", got: " &
               to_hstring(i2c_rd_data) & ", expected: " & to_hstring(data);
      wait until rising_edge(clk);
    end procedure i2c_verify;

  begin
    -- Set reset values
    i2c_ce      <= '0';
    i2c_we      <= '0';
    i2c_addr    <= X"0000000";
    i2c_wr_data <= X"0000";
    rtc_ce      <= '0';
    rtc_we      <= '0';
    rtc_addr    <= X"00";
    rtc_wr_data <= X"0000";

    wait until rst = '0';
    wait until rising_edge(clk);
    assert rtc = "0" & X"40" & C_RTC_RESET(63 downto 8)
      report "Incorrect rtc reset. Got: " & to_hstring(rtc) &
             ", Expected:" & to_hstring("0" & X"40" & C_RTC_RESET(63 downto 8));

    wait for 200 us;  -- Wait until initial RTC read is done
    wait until rising_edge(clk);

    assert rtc = "1" & X"40" & C_RTC_INIT(63 downto 8)
      report "Incorrect rtc init. Got: " & to_hstring(rtc) &
             ", Expected:" & to_hstring("1" & X"40" & C_RTC_INIT(63 downto 8));

    -- Verify access to I2C controller
    i2c_write (X"0000000", X"1234");
    wait until rising_edge(clk);
    i2c_verify(X"0000000", X"1234");
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    mem07      <= unsigned(int2board(G_BOARD, C_RTC_NEW));
    mem07_load <= '1';
    wait until rising_edge(clk);
    mem07_load <= '0';
    wait until rising_edge(clk);

    -- Verify access to RTC
    rtc_write(X"08", X"0000");
    rtc_write(X"08", X"0002");
    wait until rising_edge(clk);
    rtc_verify(X"08", X"0001");
    wait for 200 us;
    wait until rising_edge(clk);
    rtc_verify(X"08", X"0000");
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    assert rtc = "0" & X"40" & C_RTC_NEW(63 downto 8)
      report "Incorrect rtc new. Got: " & to_hstring(rtc) &
             ", Expected:" & to_hstring("0" & X"40" & C_RTC_NEW(63 downto 8));

    -- Verify memorymap access to RTC
    i2c_verify(X"00" & "0" & std_logic_vector(C_I2C_ADDRESS) & X"100", X"00" & C_RTC_NEW(15 downto 8));

    wait until rising_edge(clk);
    report "Test completed";
    wait until rising_edge(clk);
    running <= '0';
    wait;
  end process test_proc;


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  rtc_wrapper_inst : entity work.rtc_wrapper
    generic map (
      G_BOARD       => G_BOARD,
      G_I2C_CLK_DIV => 40
    )
    port map (
      clk_i         => clk,
      rst_i         => rst,
      rtc_o         => rtc,
      rtc_wait_o    => rtc_wait,
      rtc_ce_i      => rtc_ce,
      rtc_we_i      => rtc_we,
      rtc_addr_i    => rtc_addr,
      rtc_wr_data_i => rtc_wr_data,
      rtc_rd_data_o => rtc_rd_data,
      i2c_wait_o    => i2c_wait,
      i2c_ce_i      => i2c_ce,
      i2c_we_i      => i2c_we,
      i2c_addr_i    => i2c_addr,
      i2c_wr_data_i => i2c_wr_data,
      i2c_rd_data_o => i2c_rd_data,
      scl_in_i      => scl_in,
      sda_in_i      => sda_in,
      scl_out_o     => scl_out,
      sda_out_o     => sda_out
    ); -- rtc_wrapper_inst


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
       G_INIT        => int2board(G_BOARD, C_RTC_INIT),
       G_CLOCK_FREQ  => 50e6,
       G_I2C_ADDRESS => C_I2C_ADDRESS
     )
     port map (
        clk_i        => clk,
        rst_i        => rst,
        mem07_o      => open,
        mem07_i      => mem07,
        mem07_load_i => mem07_load,
        sda_io       => sda,
        scl_io       => scl
     ); -- i2c_mem_sim_inst

end architecture simulation;

