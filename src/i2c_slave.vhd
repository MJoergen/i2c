-- Copyright (c) 2006 Frank Buss (fb@frank-buss.de)
-- See license.txt for license
--
-- I2C slave
--
-- Usage:
--
-- Master starts transfer:
--   transfer_started_o is true until next stop bit
--   read_mode_o is true (until next start or stop bit is detected), if the master wants to read data
--
-- If read_mode_o is set:
--   You can set data_out_i while data_out_requested_o is high (which is high for the time the fireset
--   acknowlege is written and for the next bytes for the time the acknowledge from master is sampled)
--   This byte will be written to the I2C master.
--
-- If read mode is cleared:
--   data_in_o is valid when data_in_valid_o is true (this is true, while the acknowledge is written)
--
-- Special timeout behaviour:
-- When the slave writes a 0 bit and the master doesn't respond with a clock, or if the slave
-- missed a clock pulse, then the slave would block the bus until the next stop bit.
-- A timeout counter avoids this: If the clock is not received within the next 1 ms after writing
-- a bit to the bus, SDA will be released and the write state machine will be resetted to idle.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_slave is
  generic (
    G_CLOCK_FREQ         : natural := 1e7;
    G_I2C_ADDRESS        : unsigned(6 downto 0) := b"0000000"
  );
  port (
    -- global signals
    clk_i                : in    std_logic;
    rst_i                : in    std_logic;

    -- byte to send to master
    data_out_i           : in    unsigned(7 downto 0);

    -- last received byte from master
    data_in_o            : out   unsigned(7 downto 0);

    -- true, if master wants to read this device
    read_mode_o          : out   boolean;

    -- true, if start was detected
    start_detected_o     : out   boolean;

    -- true, if stop was detected
    stop_detected_o      : out   boolean;

    -- true, if a valid address was received and acknolwedged
    transfer_started_o   : out   boolean;

    -- true, if data_write has to be filled to send the next byte
    data_out_requested_o : out   boolean;

    -- true, if the master sent a byte. Now data_received is valid.
    data_in_valid_o      : out   boolean;

    -- I2C SDA and SCL signals
    sda_io               : inout std_logic;
    scl_i                : in    std_logic);
end entity i2c_slave;

architecture rtl of i2c_slave is
  -- 4 bits are sampled to detect filter spikes
  -- sample rate: 1 us per 4 bits = 4 mbits/s
  constant C_SAMPLE_CYCLES : natural := G_CLOCK_FREQ / 4e6;
  signal sample_cycles_counter : natural range 0 to (C_SAMPLE_CYCLES - 1) := 0;

  -- write timeout counter
  constant C_WRITE_TIMEOUT : natural := G_CLOCK_FREQ / 1e3;
  signal write_timeout_counter : natural range 0 to C_WRITE_TIMEOUT := 0;

  -- signals for filtering input
  signal sda_sampled      : unsigned(3 downto 0) := (others => '1');
  signal scl_sampled      : unsigned(3 downto 0) := (others => '1');
  signal sda_falling_edge : boolean := false;
  signal sda_rising_edge  : boolean := false;
  signal scl_falling_edge : boolean := false;
  signal scl_rising_edge  : boolean := false;

  -- IO buffer
  signal sda_out : std_logic := '1';
  signal sda_in  : std_logic := '0';

  -- filtered input
  signal sda_in_delayed : std_logic := '1';
  signal scl_delayed    : std_logic := '1';

  -- signals calculated from input
  signal start_detected_delayed : boolean := false;
  signal stop_detected_delayed  : boolean := false;
  signal read_mode_received     : boolean := false;

  -- control signals
  signal read_byte  : boolean := false;
  signal write_byte : boolean := false;
  signal read_ack   : boolean := false;
  signal write_ack  : boolean := false;

  -- IO shift registers
  signal input_shift        : unsigned(7 downto 0) := (others => '0');
  signal input_shift_count  : natural range 0 to 7 := 0;
  signal output_shift       : unsigned(7 downto 0) := (others => '0');
  signal output_shift_count : natural range 0 to 7 := 0;

  type read_state_type is (
    idle,
    read_bit,
    wait_scl_falling,
    read_end);
  signal read_state : read_state_type := idle;

  type write_state_type is (
    idle,
    write_bit,
    wait_scl_rising,
    wait_scl_falling,
    write_end);

  signal write_state : write_state_type := idle;

  type control_state_type is (
    idle,
    wait_for_address,
    start_write_ack,
    wait_for_write_ack,
    start_read_byte,
    wait_for_read_byte,
    start_write_byte,
    wait_for_write_byte,
    start_read_ack,
    wait_for_read_ack);

  signal control_state : control_state_type := idle;

begin

  sample_process : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if sample_cycles_counter = 0 then
        sample_cycles_counter <= C_SAMPLE_CYCLES - 1;
        sda_sampled <= sda_sampled(2 downto 0) & sda_in;
        scl_sampled <= scl_sampled(2 downto 0) & scl_i;
      else
        sample_cycles_counter <= sample_cycles_counter -1;
      end if;

      if rst_i = '1' then
        sda_sampled <= (others => '1');
        scl_sampled <= (others => '1');
        sample_cycles_counter <= 0;
      end if;
    end if;
  end process sample_process;

  -- This process provides 2 functions:
  -- If read_byte is set to true, then 8 bits are read from the I2C bus
  -- into input_shift.
  -- If read_ack is set to true, then one bit will be read from the I2C bus
  -- for the acknowledge from master into input_shift(0).
  -- Start or stop bit detection resets the state machine.
  read_process : process(clk_i)
  begin
    if rising_edge(clk_i) then
      case read_state is
        when idle =>
          if read_byte then
            input_shift_count <= 7;
            read_state <= read_bit;
          end if;
          if read_ack then
            input_shift_count <= 0;
            read_state <= read_bit;
          end if;

        when read_bit =>
          if scl_rising_edge then
            input_shift <= input_shift(6 downto 0) & sda_in_delayed;
            read_state <= wait_scl_falling;
          end if;

        when wait_scl_falling =>
          if scl_falling_edge then
            if input_shift_count = 0 then
              read_state <= read_end;
            else
              input_shift_count <= input_shift_count - 1;
              read_state <= read_bit;
            end if;
          end if;

        when read_end =>
          if (not read_byte) and (not read_ack) then
            read_state <= idle;
          end if;
      end case;

      if start_detected_delayed or stop_detected_delayed then
        read_state <= idle;
      end if;

      if rst_i = '1' then
        read_state <= idle;
        input_shift <= (others => '0');
      end if;
    end if;
  end process read_process;

  -- This process provides 2 functions:
  -- If write_byte is set to true, then 8 bits are written from data_out_i
  -- to the I2C bus.
  -- If write_ack is set to true, then one 0 bit will be written to the I2C bus
  -- for the acknowledge from slave.
  -- Start or stop bit detection resets the state machine.
  write_process: process(clk_i)
  begin
    if rising_edge(clk_i) then
      case write_state is
        when idle =>
          sda_out <= '1';
          if write_ack then
            output_shift <= x"00";
            output_shift_count <= 0;
            write_state <= write_bit;
          end if;
          if write_byte then
            output_shift <= data_out_i;
            output_shift_count <= 7;
            write_state <= write_bit;
          end if;

        when write_bit =>
          if scl_falling_edge then
            sda_out <= output_shift(7);
            report "outputting bit = " & std_logic'image(output_shift(7));
            write_timeout_counter <= C_WRITE_TIMEOUT;
            write_state <= wait_scl_rising;
          end if;

        when wait_scl_rising =>
          if scl_rising_edge then
            if output_shift_count = 0 then
              write_state <= wait_scl_falling;
            else
              output_shift_count <= output_shift_count - 1;
              output_shift <= output_shift(6 downto 0) & '0';
              write_state <= write_bit;
            end if;
          else
            if write_timeout_counter = 0 then
              write_state <= idle;
            else
              write_timeout_counter <= write_timeout_counter - 1;
            end if;
          end if;

        when wait_scl_falling =>
          if scl_falling_edge then
            write_state <= write_end;
          end if;

        when write_end =>
          report "write_end: releasing SDA";
          sda_out <= '1';
          if (not write_ack) and (not write_byte) then
            write_state <= idle;
          end if;
      end case;

      if start_detected_delayed or stop_detected_delayed then
        write_state <= idle;
      end if;

      if rst_i = '1' then
        write_state <= idle;
        output_shift <= (others => '0');
      end if;
    end if;
  end process write_process;

  -- Process for receiving and sending bytes to the I2C bus,
  -- with the proper acknowledge generators and detection.
  control_process: process(clk_i)
  begin
    if rising_edge(clk_i) then
      case control_state is
        when idle =>
          transfer_started_o   <= false;
          data_out_requested_o <= false;
          data_in_valid_o      <= false;
          read_byte            <= false;
          write_byte           <= false;
          read_ack             <= false;
          write_ack            <= false;
          read_mode_received   <= false;

        when wait_for_address =>
          if read_state = read_end then
            read_byte <= false;
            read_mode_received <= input_shift(0) = '1';
            if input_shift(7 downto 1) = G_I2C_ADDRESS then
              control_state <= start_write_ack;
            else
              control_state <= idle;
            end if;
          end if;

        when start_write_ack =>
          write_ack <= true;
          control_state <= wait_for_write_ack;

        when wait_for_write_ack =>
          if read_mode_received then
            data_out_requested_o <= true;
          end if;
          transfer_started_o <= true;
          if write_state = write_end then
            data_in_valid_o <= false;
            write_ack <= false;
            if read_mode_received then
              control_state <= start_write_byte;
            else
              control_state <= start_read_byte;
            end if;
          end if;

        when start_read_byte =>
          read_byte <= true;
          control_state <= wait_for_read_byte;

        when wait_for_read_byte =>
          if read_state = read_end then
            data_in_o <= input_shift;
            data_in_valid_o <= true;
                                                      report "Saw a byte";
            read_byte <= false;
            control_state <= start_write_ack;
          end if;

        when start_write_byte =>
          write_byte <= true;
          control_state <= wait_for_write_byte;

        when wait_for_write_byte =>
          data_out_requested_o <= false;
          if write_state = write_end then
            write_byte <= false;
            control_state <= start_read_ack;
          end if;

        when start_read_ack =>
          data_out_requested_o <= true;
          read_ack <= true;
          control_state <= wait_for_read_ack;

        when wait_for_read_ack =>
          if read_state = read_end then
            read_ack <= false;
            if input_shift(0) = '1' then
              -- no acknowledge from master, finish
              control_state <= idle;
            else
              -- acknowledge from master, send next byte
              control_state <= start_write_byte;
            end if;
          end if;
      end case;

      if start_detected_delayed then
        read_byte <= true;
        read_mode_received <= false;
        control_state <= wait_for_address;
      end if;

      if stop_detected_delayed then
        control_state <= idle;
      end if;

      if rst_i = '1' then
        control_state <= idle;
      end if;
    end if;
  end process control_process;

  -- update and sample the inout sda signal
  sda_io <= sda_out when sda_out = '0' else 'Z';
  sda_in <= '1' when sda_io /= '0' else '0';

  -- to avoid "port", copy the read_mode_o flag
  read_mode_o <= read_mode_received;

  -- check for edges (this concept is used to filter spikes)
  sda_falling_edge <= true when sda_sampled = b"1100" else false;
  sda_rising_edge  <= true when sda_sampled = b"0011" else false;
  scl_falling_edge <= true when scl_sampled = b"1100" else false;
  scl_rising_edge  <= true when scl_sampled = b"0011" else false;

  -- these signals are used to ensure that the data signals are evaluated after
  -- the edges are detected
  sda_in_delayed <= sda_sampled(2);
  scl_delayed    <= scl_sampled(2);

  -- detect start/stop condition
  start_detected_delayed <= (scl_delayed = '1') and sda_falling_edge and (not (scl_rising_edge or scl_falling_edge));
  stop_detected_delayed  <= (scl_delayed = '1') and sda_rising_edge and (not (scl_rising_edge or scl_falling_edge));

  -- copy to host
  start_detected_o <= start_detected_delayed;
  stop_detected_o  <= stop_detected_delayed;

end architecture rtl;

