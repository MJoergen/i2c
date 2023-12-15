library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_rtcF83 is
end entity tb_rtcF83;

architecture sim of tb_rtcF83 is

  signal clk                : std_logic := '1';
  signal rst                : std_logic := '1';
  signal running            : std_logic := '1';

  signal cpu_wait           : std_logic;
  signal cpu_ce             : std_logic;
  signal cpu_we             : std_logic;
  signal cpu_addr           : std_logic_vector( 7 downto 0);
  signal cpu_wr_data        : std_logic_vector(15 downto 0);
  signal cpu_rd_data        : std_logic_vector(15 downto 0);
  signal scl_in             : std_logic;
  signal sda_in             : std_logic;
  signal scl_tri            : std_logic;
  signal sda_tri            : std_logic;
  signal scl_out            : std_logic;
  signal sda_out            : std_logic;

  signal sda                : std_logic := 'H';
  signal scl                : std_logic := '1';

  component rtcF83 is
    generic (
      CLOCK_RATE : integer;
      HAS_RAM    : integer
    );
    port (
      clk   : in  std_logic;
      ce    : in  std_logic;
      reset : in  std_logic;
      RTC   : in  std_logic_vector(64 downto 0);
      scl_i : in  std_logic;
      sda_i : in  std_logic;
      sda_o : out std_logic
    );
  end component rtcF83;

  signal dev_sda : std_logic := 'H';
  signal RTC     : std_logic_vector(64 downto 0);

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
      scl_tri_o     => scl_tri,
      sda_tri_o     => sda_tri,
      scl_out_o     => scl_out,
      sda_out_o     => sda_out
    ); -- i_i2c_controller

  sda <= sda_out when sda_tri = '0' and sda_out = '0' else 'H';
  scl <= scl_out when scl_tri = '0' and scl_out = '0' else '1';
  sda_in <= sda;
  scl_in <= scl;


  ------------------------------------
  -- Instantiate I2C slave device
  ------------------------------------

  i_rtcF83 : component rtcF83
    generic map (
      CLOCK_RATE => 1000000,
      HAS_RAM    => 1
    )
    port map (
      clk   => clk,
      ce    => '1',
      reset => rst,
      RTC   => RTC,
      scl_i => scl,
      sda_i => sda,
      sda_o => dev_sda
    ); -- i_rtcF83

  sda <= '0' when dev_sda = '0' else 'H';


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
      cpu_verify(X"84", X"0001"); -- Status: IDLE
      cpu_write( X"00", addr & data); -- Data
      cpu_write( X"80", X"02" & i2c(6 downto 0) & "0"); -- Config
      wait for 3 us;
      wait until rising_edge(clk);
      cpu_verify(X"84", X"0002"); -- Status: BUSY
      wait for 60 us;
      wait until rising_edge(clk);
      cpu_verify(X"84", X"0001"); -- Status: IDLE
    end procedure i2c_write;

    procedure i2c_verify (
      i2c  : in std_logic_vector(7 downto 0);
      addr : in std_logic_vector(7 downto 0);
      data : in std_logic_vector(7 downto 0)) is
    begin
      cpu_verify(X"84", X"0001"); -- Status: IDLE
      cpu_write( X"00", addr & X"00");
      cpu_write( X"80", X"01" & i2c(6 downto 0) & "0");
      wait for 3 us;
      wait until rising_edge(clk);
      cpu_verify(X"84", X"0002"); -- Status: BUSY
      wait for 40 us;
      wait until rising_edge(clk);
      cpu_verify(X"84", X"0001"); -- Status: IDLE
      cpu_write( X"80", X"01" & i2c(6 downto 0) & "1");
      wait for 3 us;
      wait until rising_edge(clk);
      cpu_verify(X"84", X"0002"); -- Status: BUSY
      wait for 40 us;
      wait until rising_edge(clk);
      cpu_verify(X"84", X"0001"); -- Status: IDLE
      cpu_verify(X"00", data & X"00");
    end procedure i2c_verify;

    procedure i2c_verify2 (
      i2c  : in std_logic_vector(7 downto 0);
      addr : in std_logic_vector(7 downto 0);
      data : in std_logic_vector(15 downto 0)) is
    begin
      cpu_verify(X"84", X"0001"); -- Status: IDLE
      cpu_write( X"00", addr & X"00");
      cpu_write( X"80", X"01" & i2c(6 downto 0) & "0");
      wait for 3 us;
      wait until rising_edge(clk);
      cpu_verify(X"84", X"0002"); -- Status: BUSY
      wait for 40 us;
      wait until rising_edge(clk);
      cpu_verify(X"84", X"0001"); -- Status: IDLE
      cpu_write( X"80", X"02" & i2c(6 downto 0) & "1");
      wait for 3 us;
      wait until rising_edge(clk);
      cpu_verify(X"84", X"0002"); -- Status: BUSY
      wait for 60 us;
      wait until rising_edge(clk);
      cpu_verify(X"84", X"0001"); -- Status: IDLE
      cpu_verify(X"00", data);
    end procedure i2c_verify2;

  begin

    cpu_ce <= '0';
    cpu_we <= '0';
    wait until rst = '0';
    wait for 3 us;
    wait until rising_edge(clk);

    RTC <= "1" & X"12345678" & X"87654321";
    wait until rising_edge(clk);
    RTC <= "0" & X"12345678" & X"87654321";
    wait until rising_edge(clk);

    -- Verify communication with the I2C device
    i2c_verify2(X"50", X"01", X"349A");

    wait for 3 us;
    running <= '0';
    report "Test completed";
    wait;
  end process master_proc;

end architecture sim;

