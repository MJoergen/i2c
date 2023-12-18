library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- RTC format:
-- Bits  7 -  0 : 1/100 Seconds (BCD format, 0x00-0x99)
-- Bits 15 -  8 : Seconds       (BCD format, 0x00-0x60)
-- Bits 23 - 16 : Minutes       (BCD format, 0x00-0x59)
-- Bits 31 - 24 : Hours         (BCD format, 0x00-0x23)
-- Bits 39 - 32 : DayOfMonth    (BCD format, 0x01-0x31)
-- Bits 47 - 40 : Month         (BCD format, 0x01-0x12)
-- Bits 55 - 48 : Year          (BCD format, 0x00-0x99)
-- Bits 63 - 56 : DayOfWeek     (0x00-0x06)

entity rtc_sim is
   generic (
      G_INIT  : std_logic_vector(63 downto 0);
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

   signal sda_out : std_logic_vector(7 downto 0) := (others => 'H');
   signal scl_out : std_logic_vector(7 downto 0) := (others => 'H');
   signal sda_in  : std_logic_vector(7 downto 0) := (others => 'H');
   signal scl_in  : std_logic_vector(7 downto 0) := (others => 'H');
   signal sda     : std_logic;
   signal scl     : std_logic;
   signal rtc     : unsigned(63 downto 0);

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

   constant C_INIT : std_logic_vector(63 downto 0) := int2board(G_BOARD, G_INIT);

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
       G_INIT        => C_INIT,
       G_CLOCK_FREQ  => 50e6,
       G_I2C_ADDRESS => C_I2C_ADDRESS
     )
     port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        mem07_o => rtc,
        sda_io  => sda,
        scl_io  => scl
     ); -- i2c_mem_sim_inst

  rtc_o <= unsigned(board2int(G_BOARD, std_logic_vector(rtc)));

end architecture simulation;

