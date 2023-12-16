library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_i2c_controller is
end entity tb_i2c_controller;

architecture sim of tb_i2c_controller is

  constant REG_I2C_DATA     : std_logic_vector(7 downto 0) := X"00";
  constant REG_I2C_CONFIG   : std_logic_vector(7 downto 0) := X"F0";
  constant REG_I2C_STATUS   : std_logic_vector(7 downto 0) := X"F1";
  constant C_I2C_ADDRESS    : std_logic_vector(7 downto 0) := X"51";

  signal clk                : std_logic := '1';
  signal rst                : std_logic := '1';
  signal running            : std_logic := '1';

  signal cpu_wait           : std_logic;
  signal cpu_ce             : std_logic;
  signal cpu_we             : std_logic;
  signal cpu_addr           : std_logic_vector( 7 downto 0);
  signal cpu_wr_data        : std_logic_vector(15 downto 0);
  signal cpu_rd_data        : std_logic_vector(15 downto 0);
  signal scl_in             : std_logic_vector( 7 downto 0) := (others => 'H');
  signal sda_in             : std_logic_vector( 7 downto 0) := (others => 'H');
  signal scl_out            : std_logic_vector( 7 downto 0) := (others => 'H');
  signal sda_out            : std_logic_vector( 7 downto 0) := (others => 'H');

  signal sda                : std_logic := 'H';
  signal scl                : std_logic := 'H';

begin

  clk <= running and not clk after 10 ns; -- 50 MHz
  rst <= '1', '0' after 100 ns;

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

  sda <= '0' when sda_out(0) = '0' else 'H';
  scl <= '0' when scl_out(0) = '0' else 'H';
  sda_in(0) <= sda;
  scl_in(0) <= scl;

  -- Pull-up
  scl <= 'H';
  sda <= 'H';

  -- A simple I2C memory
  i_i2c_mem_sim : entity work.i2c_mem_sim
     generic map (
       G_CLOCK_FREQ  => 24_000_000,
       G_I2C_ADDRESS => unsigned(C_I2C_ADDRESS(6 downto 0))
     )
     port map (
        clk_i  => clk,
        rst_i  => rst,
        sda_io => sda,
        scl_io => scl
     ); -- i_i2c_mem_sim

  ------------------------------------
  -- This simulates the I2C master
  ------------------------------------

  master_proc : process
    procedure cpu_write (
      addr : in std_logic_vector(7 downto 0);
      data : in std_logic_vector(15 downto 0)) is
    begin
      cpu_ce      <= '1';
      cpu_we      <= '1';
      cpu_addr    <= addr;
      cpu_wr_data <= data;
      wait until rising_edge(clk);
      while cpu_wait = '1' loop
        wait until rising_edge(clk);
      end loop;
      cpu_ce      <= '0';
      cpu_we      <= '0';
      cpu_addr    <= (others => '0');
      cpu_wr_data <= (others => '0');
    end procedure cpu_write;

    procedure cpu_verify (
      addr : in std_logic_vector(7 downto 0);
      data : in std_logic_vector(15 downto 0)) is
    begin
      cpu_ce      <= '1';
      cpu_we      <= '0';
      cpu_addr    <= addr;
      wait until rising_edge(clk);
      cpu_ce      <= '0';
      cpu_we      <= '0';
      cpu_addr    <= (others => '0');
      wait until falling_edge(clk);
      while cpu_wait = '1' loop
        wait until rising_edge(clk);
        wait until falling_edge(clk);
      end loop;
      assert cpu_rd_data = data
        report "Read from address " & to_hstring(addr) & ", got: " & to_hstring(cpu_rd_data) & ", expected: " & to_hstring(data);
      wait until rising_edge(clk);
    end procedure cpu_verify;

    procedure i2c_write (
      i2c  : in std_logic_vector(7 downto 0);
      addr : in std_logic_vector(7 downto 0);
      data : in std_logic_vector(7 downto 0)) is
    begin
      cpu_verify(REG_I2C_STATUS, X"0001"); -- Status: IDLE
      cpu_write( REG_I2C_DATA, addr & data); -- Data
      cpu_write( REG_I2C_CONFIG, X"02" & i2c(6 downto 0) & "0"); -- Config
      wait for 3 us;
      wait until rising_edge(clk);
      cpu_verify(REG_I2C_STATUS, X"0002"); -- Status: BUSY
      wait for 60 us;
      wait until rising_edge(clk);
      cpu_verify(REG_I2C_STATUS, X"0001"); -- Status: IDLE
    end procedure i2c_write;

    procedure i2c_verify (
      i2c  : in std_logic_vector(7 downto 0);
      addr : in std_logic_vector(7 downto 0);
      data : in std_logic_vector(7 downto 0)) is
    begin
      cpu_verify(REG_I2C_STATUS, X"0001"); -- Status: IDLE
      cpu_write( REG_I2C_DATA, addr & X"00");
      cpu_write( REG_I2C_CONFIG, X"01" & i2c(6 downto 0) & "0");
      wait for 3 us;
      wait until rising_edge(clk);
      cpu_verify(REG_I2C_STATUS, X"0002"); -- Status: BUSY
      wait for 40 us;
      wait until rising_edge(clk);
      cpu_verify(REG_I2C_STATUS, X"0001"); -- Status: IDLE
      cpu_write( REG_I2C_CONFIG, X"01" & i2c(6 downto 0) & "1");
      wait for 3 us;
      wait until rising_edge(clk);
      cpu_verify(REG_I2C_STATUS, X"0002"); -- Status: BUSY
      wait for 40 us;
      wait until rising_edge(clk);
      cpu_verify(REG_I2C_STATUS, X"0001"); -- Status: IDLE
      cpu_verify(REG_I2C_DATA, data & X"00");
    end procedure i2c_verify;

    procedure i2c_verify2 (
      i2c  : in std_logic_vector(7 downto 0);
      addr : in std_logic_vector(7 downto 0);
      data : in std_logic_vector(15 downto 0)) is
    begin
      cpu_verify(REG_I2C_STATUS, X"0001"); -- Status: IDLE
      cpu_write( REG_I2C_DATA, addr & X"00");
      cpu_write( REG_I2C_CONFIG, X"01" & i2c(6 downto 0) & "0");
      wait for 3 us;
      wait until rising_edge(clk);
      cpu_verify(REG_I2C_STATUS, X"0002"); -- Status: BUSY
      wait for 40 us;
      wait until rising_edge(clk);
      cpu_verify(REG_I2C_STATUS, X"0001"); -- Status: IDLE
      cpu_write( REG_I2C_CONFIG, X"02" & i2c(6 downto 0) & "1");
      wait for 3 us;
      wait until rising_edge(clk);
      cpu_verify(REG_I2C_STATUS, X"0002"); -- Status: BUSY
      wait for 60 us;
      wait until rising_edge(clk);
      cpu_verify(REG_I2C_STATUS, X"0001"); -- Status: IDLE
      cpu_verify(REG_I2C_DATA, data);
    end procedure i2c_verify2;

  begin

    cpu_ce <= '0';
    cpu_we <= '0';
    wait until rst = '0';
    wait for 3 us;
    wait until rising_edge(clk);

    -- Verify the I2C buffer RAM
    cpu_write( X"00", X"2233");
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    cpu_write( X"01", X"4455");
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    cpu_write( X"02", X"6677");
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    cpu_write( X"03", X"8899");
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    cpu_verify(X"00", X"2233");
    cpu_verify(X"01", X"4455");
    cpu_verify(X"02", X"6677");
    cpu_verify(X"03", X"8899");

    -- Verify communication with the I2C device
    i2c_write(  C_I2C_ADDRESS, X"12", X"34");   -- MEM[0x12] := 0x34
    i2c_write(  C_I2C_ADDRESS, X"13", X"78");   -- MEM[0x13] := 0x78
    i2c_verify( C_I2C_ADDRESS, X"12", X"34");   -- MEM[0x12] == 0x34
    i2c_verify( C_I2C_ADDRESS, X"13", X"78");   -- MEM[0x13] == 0x78
    i2c_write(  C_I2C_ADDRESS, X"13", X"9A");   -- MEM[0x13] := 0x9A
    i2c_verify2(C_I2C_ADDRESS, X"12", X"349A"); -- MEM[0x12-0x13] == 0x349A

    wait for 3 us;
    running <= '0';
    report "Test completed";
    wait;
  end process master_proc;

end architecture sim;

