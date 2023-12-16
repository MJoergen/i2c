library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_mem_sim is
   generic (
     G_DEBUG       : boolean := false;
     G_INIT        : std_logic_vector(63 downto 0) := X"0000000000000000";
     G_CLOCK_FREQ  : natural := 1e7;
     G_I2C_ADDRESS : unsigned(6 downto 0) := b"0000000"
   );
   port (
      -- TB signals
      clk_i   : in    std_logic;
      rst_i   : in    std_logic;
      mem07_o : out   unsigned(63 downto 0);

      -- I2C signals
      sda_io  : inout std_logic;
      scl_io  : inout std_logic
   );
end entity i2c_mem_sim;

architecture sim of i2c_mem_sim is

  signal data_out           : unsigned(7 downto 0);
  signal data_in            : unsigned(7 downto 0);
  signal read_mode          : boolean;
  signal start_detected     : boolean;
  signal stop_detected      : boolean;
  signal transfer_started   : boolean;
  signal data_out_requested : boolean;
  signal data_in_valid      : boolean;
  signal addr               : unsigned(7 downto 0);

  type state_t is (IDLE_ST, WAIT_FOR_END_ST,
  WAIT_FOR_WR_ADDR_ST, WAIT_FOR_WR_ADDR_END_ST, WAIT_FOR_WR_DATA_ST,
  WAIT_FOR_RD_ADDR_ST, WAIT_FOR_RD_ADDR_END_ST, WAIT_FOR_RD_DATA_ST,
  WAIT_FOR_RD_DATA_ACK_ST);
  signal state : state_t := IDLE_ST;

  type ram_t is array (natural range <>) of unsigned(7 downto 0);
  signal ram : ram_t(0 to 255) := (
    0 => unsigned(G_INIT( 7 downto  0)),
    1 => unsigned(G_INIT(15 downto  8)),
    2 => unsigned(G_INIT(23 downto 16)),
    3 => unsigned(G_INIT(31 downto 24)),
    4 => unsigned(G_INIT(39 downto 32)),
    5 => unsigned(G_INIT(47 downto 40)),
    6 => unsigned(G_INIT(55 downto 48)),
    7 => unsigned(G_INIT(63 downto 56)),
    others => X"AA"
  );

begin

  mem07_o <= ram(7) & ram(6) & ram(5) & ram(4) & ram(3) & ram(2) & ram(1) & ram(0);

  i_i2c_slave : entity work.i2c_slave
  generic map (
    G_CLOCK_FREQ  => G_CLOCK_FREQ,
    G_I2C_ADDRESS => G_I2C_ADDRESS
  )
  port map (
    clk_i                => clk_i,
    rst_i                => rst_i,
    data_out_i           => data_out,
    data_in_o            => data_in,
    read_mode_o          => read_mode,
    start_detected_o     => start_detected,
    stop_detected_o      => stop_detected,
    transfer_started_o   => transfer_started,
    data_out_requested_o => data_out_requested,
    data_in_valid_o      => data_in_valid,
    sda_io               => sda_io,
    scl_i                => scl_io
  );

  fsm_proc : process (clk_i)
  begin
     if rising_edge(clk_i) then
        case state is
           when IDLE_ST =>
              if transfer_started then
                 if read_mode then
                    state <= WAIT_FOR_RD_DATA_ST;
                 else
                    state <= WAIT_FOR_WR_ADDR_ST;
                 end if;
              end if;

           when WAIT_FOR_WR_ADDR_ST =>
              if data_in_valid then
                 addr <= data_in;
                 state <= WAIT_FOR_WR_ADDR_END_ST;
              end if;

           when WAIT_FOR_WR_ADDR_END_ST =>
              if not data_in_valid then
                 state <= WAIT_FOR_WR_DATA_ST;
              end if;

           when WAIT_FOR_WR_DATA_ST =>
              if data_in_valid then
                 if G_DEBUG then
                    report "I2C_MEM_SIM : Write " & to_hstring(data_in) & " to address " & to_hstring(addr);
                 end if;
                 ram(to_integer(addr)) <= data_in;
                 state <= WAIT_FOR_END_ST;
              end if;
              if not transfer_started then
                 state <= IDLE_ST;
              end if;

           when WAIT_FOR_RD_DATA_ST =>
              if data_out_requested then
                 data_out <= ram(to_integer(addr));
                 if G_DEBUG then
                    report "I2C_MEM_SIM : Reading " & to_hstring(ram(to_integer(addr))) & " from address " & to_hstring(addr);
                 end if;
                 addr <= addr + 1;
                 state <= WAIT_FOR_RD_DATA_ACK_ST;
              end if;
              if not transfer_started then
                 state <= IDLE_ST;
              end if;

           when WAIT_FOR_RD_DATA_ACK_ST =>
              if not data_out_requested then
                 state <= WAIT_FOR_RD_DATA_ST;
              end if;

           when WAIT_FOR_END_ST =>
              if not transfer_started then
                 state <= IDLE_ST;
              end if;

           when others =>
              null;
        end case;

        if rst_i = '1' then
           state <= IDLE_ST;
        end if;
     end if;
  end process fsm_proc;

end architecture sim;

