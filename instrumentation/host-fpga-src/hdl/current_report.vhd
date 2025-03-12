-- Receive data and add timestamp
-- FIFO to receive and process data
--
-- Inputs
--  data_in - Data of std_logic_vector of size ???
--  write_en - Enable read operation on FIFO
--  read_address - index to select from registers
--  reset - reset index count
-- Outputs
--  full - to check before writing
--  empty - nothing to be read
--  data_out - The read data

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity current_report is
  generic (
    REPORT_FIFO_SIZE  : integer := 64
  );
  port (
    -- Inputs
    clk_i        : in std_logic;
    rstn_i       : in std_logic;
    -- parameters
    baud_rate_i   : in std_logic_vector(15 downto 0);
    sample_rate_i : in std_logic_vector(15 downto 0);
    curr_th_i     : in std_logic_vector(15 downto 0);
    -- uart interface
    rx_host_i : in  std_logic;
    tx_host_o : out std_logic;
    -- reporting
    timestamp_i  : in std_logic_vector(31 downto 0);
    -- reporting ina
    ina_wen_i    : in std_logic;
    curr_rdata_i : in std_logic_vector(15 downto 0);
    -- reporting gpio
    gpio_i2c_wr_i    : in std_logic;
    gpio_i2c_rd_i    : in std_logic;
    gpio_i2c_wdata_i : in std_logic_vector(15 downto 0);
    gpio_i2c_rdata_i : in std_logic_vector(15 downto 0);

    -- overcurrent
    overcurrent_o : out std_logic
  );
end entity;

architecture rtl of current_report is

  signal current_timestamp_w : std_logic_vector(31 downto 0);
  signal current_w           : std_logic_vector(15 downto 0);
  signal log_overcurrent_w   : std_logic;

  signal gpio_wtimestamp_w : std_logic_vector(31 downto 0);
  signal gpio_wdata_w      : std_logic_vector(15 downto 0);
  signal gpio_rtimestamp_w : std_logic_vector(31 downto 0);
  signal gpio_rdata_w      : std_logic_vector(15 downto 0);
  signal log_gpio_w        : std_logic;

  constant REPORT_SIZE : integer := 144;

  signal sample_counter_r : std_logic_vector(31 downto 0);
  signal sample_max_w     : std_logic;

  signal fifo_write_w : std_logic;
  signal fifo_wdata_w : std_logic_vector(REPORT_SIZE-1 downto 0);
  signal fifo_full_w  : std_logic;
  signal fifo_empty_w : std_logic;
  signal fifo_valid_w : std_logic;
  signal fifo_read_w  : std_logic;
  signal fifo_rdata_w : std_logic_vector(REPORT_SIZE-1 downto 0);

begin

  current_read_b : block
    signal timestamp_r : std_logic_vector(31 downto 0);
    signal current_r   : std_logic_vector(15 downto 0);
    -- overcurrent logic
    signal overcurrent_w          : std_logic;
    signal previous_overcurrent_r : std_logic;
    signal log_overcurrent_r      : std_logic;
  begin
    current_p : process (rstn_i, clk_i)
    begin
      if rstn_i = '0' then
        current_r <= (others => '0');
        -- overcurrent logic
        previous_overcurrent_r <= '0';
        log_overcurrent_r      <= '0';
      elsif rising_edge(clk_i) then
        -- filter ina done
        if ina_wen_i = '1' then
          -- register timestamp and data
          timestamp_r <= timestamp_i;
          current_r   <= curr_rdata_i;
          -- check current over threshold
          if overcurrent_w = '1' then
            -- check if previous was also an overcurrent
            if previous_overcurrent_r = '0' then
              log_overcurrent_r <= '1';
              --pragma translate_off
              report "OVERCURRENT BEING REPORTED" severity WARNING;
              --pragma translate_on
            end if;
            -- save over current as previous for comparison
            previous_overcurrent_r <= '1';
          else
            previous_overcurrent_r <= '0';
          end if;
        else
          log_overcurrent_r <= '0';
        end if;
      end if;
    end process;
    overcurrent_w       <= '1' when signed(curr_rdata_i) > signed(curr_th_i) else '0';
    current_timestamp_w <= timestamp_r;
    current_w           <= current_r;
    log_overcurrent_w   <= log_overcurrent_r;
    -- set output
    overcurrent_o <= overcurrent_w;
  end block;

  gpio_read_b : block
    signal timestamp_wr_r : std_logic_vector(31 downto 0);
    signal gpio_wdata_r   : std_logic_vector(15 downto 0);
    signal timestamp_rd_r : std_logic_vector(31 downto 0);
    signal gpio_rdata_r   : std_logic_vector(15 downto 0);
    signal log_wr_gpio_r  : std_logic;
    signal log_rd_gpio_r  : std_logic;
  begin
    current_p : process (rstn_i, clk_i)
    begin
      if rstn_i = '0' then
        timestamp_wr_r <= (others => '0');
        gpio_wdata_r   <= (others => '0');
        timestamp_rd_r <= (others => '0');
        gpio_rdata_r   <= (others => '0');
        log_wr_gpio_r   <= '0';
        log_rd_gpio_r   <= '0';
      elsif rising_edge(clk_i) then

        if gpio_i2c_wr_i = '1' then
          -- register timestamp and data
          timestamp_wr_r <= timestamp_i;
          gpio_wdata_r   <= gpio_i2c_wdata_i;
          -- if wdata changed, set log signal
          if gpio_i2c_wdata_i /= gpio_wdata_r then
            log_wr_gpio_r <= '1';
          end if;
        else
          log_wr_gpio_r <= '0'; -- unset log signal
        end if;

        if gpio_i2c_rd_i = '1' then
          -- register timestamp and data
          timestamp_rd_r <= timestamp_i;
          gpio_rdata_r   <= gpio_i2c_rdata_i;
          -- if rdata changed, set log signal
          if gpio_i2c_rdata_i /= gpio_rdata_r then
            log_rd_gpio_r <= '1';
          end if;
        else
          log_rd_gpio_r <= '0'; -- unset log signal
        end if;
      end if;
    end process;
    gpio_wtimestamp_w <= timestamp_wr_r;
    gpio_wdata_w      <= gpio_wdata_r;
    gpio_rtimestamp_w <= timestamp_rd_r;
    gpio_rdata_w      <= gpio_rdata_r;
    log_gpio_w        <= log_wr_gpio_r or log_rd_gpio_r;
  end block;

  sample_rate_p : process (rstn_i, clk_i)
  begin
    if rstn_i = '0' then
      sample_counter_r <= (others => '0');
    elsif rising_edge(clk_i) then
      if sample_max_w = '1' then
        if fifo_full_w = '0' then -- wait fifo not full to restart counting
          sample_counter_r <= (others => '0');
        end if;
      else
        sample_counter_r <= std_logic_vector(unsigned(sample_counter_r)+1);
      end if;
    end if;
  end process;
  sample_max_w <= '1' when unsigned(sample_counter_r) >= unsigned(sample_rate_i & x"0000") else '0';

  fifo_write_w <= '0' when fifo_full_w       = '1' else -- do NOT attempt when fifo is full
                  '1' when sample_max_w      = '1' else -- write when sample rate reach max-value comparison
                  '1' when log_overcurrent_w = '1' else -- log overcurrents
                  '1' when log_gpio_w        = '1' else -- log gpio changes
                  '0';
  fifo_wdata_w <= current_timestamp_w & current_w & gpio_wtimestamp_w & gpio_wdata_w & gpio_rtimestamp_w & gpio_rdata_w;

  -- Instantiate FIFO
  -- FIFO for transceivers get timestamp
  fifo_u : entity work.fifo
  generic map (
    FIFO_SIZE  => REPORT_FIFO_SIZE,
    DATA_WIDTH => REPORT_SIZE
  )
  port map ( 
    write_i    => fifo_write_w,
    data_i     => fifo_wdata_w,
    read_i     => fifo_read_w,
    clk_i      => clk_i,
    rstn_i     => rstn_i,
    full_o     => fifo_full_w,
    empty_o    => fifo_empty_w,
    valid_o    => fifo_valid_w,
    data_o     => fifo_rdata_w,
    rem_size_o => open
  );

  uart_report_b : block
    -- state machine
    constant IDLE      : std_logic_vector(2 downto 0) := "000";
    constant DATA      : std_logic_vector(2 downto 0) := "001";
    constant NEXT_CHAR : std_logic_vector(2 downto 0) := "010";
    constant SPACE     : std_logic_vector(2 downto 0) := "011";
    constant BREAK     : std_logic_vector(2 downto 0) := "100";
    -- fsm signals
    signal state_r : std_logic_vector(2 downto 0);
    signal next_w  : std_logic_vector(2 downto 0);
    -- attributes to fix Synplify bugs
    attribute syn_preserve : boolean;
    attribute syn_preserve of state_r : signal is true;
    -- char counter
    constant CHAR_COUNT_MAX     : integer := (REPORT_SIZE/4)-1;
    constant CHAR_COUNTER_WIDTH : integer := integer(ceil(log2(real(CHAR_COUNT_MAX))));
    constant CHAR_FIRST   : std_logic_vector(CHAR_COUNTER_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(CHAR_COUNT_MAX,    CHAR_COUNTER_WIDTH));
    constant CHAR_SPACE0  : std_logic_vector(CHAR_COUNTER_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(CHAR_COUNT_MAX-7,  CHAR_COUNTER_WIDTH));
    constant CHAR_SPACE1  : std_logic_vector(CHAR_COUNTER_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(CHAR_COUNT_MAX-11, CHAR_COUNTER_WIDTH));
    constant CHAR_SPACE2  : std_logic_vector(CHAR_COUNTER_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(CHAR_COUNT_MAX-19, CHAR_COUNTER_WIDTH));
    constant CHAR_SPACE3  : std_logic_vector(CHAR_COUNTER_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(CHAR_COUNT_MAX-23, CHAR_COUNTER_WIDTH));
    constant CHAR_SPACE4  : std_logic_vector(CHAR_COUNTER_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(CHAR_COUNT_MAX-31, CHAR_COUNTER_WIDTH));
    constant CHAR_LAST    : std_logic_vector(CHAR_COUNTER_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(0,                 CHAR_COUNTER_WIDTH));
    signal char_counter_r : std_logic_vector(CHAR_COUNTER_WIDTH-1 downto 0);
    signal clr_counter_w  : std_logic;
    signal char_count_w   : std_logic;
    signal char_last_w    : std_logic;
    signal char_space_w   : std_logic;
    -- selectors
    signal print_data_r : std_logic_vector(REPORT_SIZE-1 downto 0);
    -- conversion
    signal hex_data_w : std_logic_vector(3 downto 0);
    signal utf_data_w : std_logic_vector(7 downto 0);
    -- uart
    signal uart_tstart_w : std_logic;
    signal uart_tdata_w  : std_logic_vector(7 downto 0);
    signal uart_tdone_w  : std_logic;
  begin
    state_p : process (rstn_i, clk_i)
    begin
      if rstn_i = '0' then
        state_r <= IDLE;
      elsif rising_edge(clk_i) then
        state_r <= next_w;
      end if;
    end process;

    next_p : process (all)
    begin
      case (state_r) is

        when IDLE =>
          if fifo_empty_w = '0' then
            next_w <= DATA;
          else
            next_w <= IDLE;
          end if;
        
        when DATA =>
          if uart_tdone_w = '1' then
            if char_last_w = '1' then
              next_w <= BREAK;
            elsif char_space_w = '1' then
              next_w <= SPACE;
            else
              next_w <= NEXT_CHAR;
            end if;
          else
            next_w <= DATA;
          end if;

        when NEXT_CHAR => next_w <= DATA;

        when SPACE =>
          if uart_tdone_w = '1' then
            next_w <= NEXT_CHAR;
          else
            next_w <= SPACE;
          end if;

        when BREAK =>
          if uart_tdone_w = '1' then
            next_w <= IDLE;
          else
            next_w <= BREAK;
          end if;

        when others => next_w <= IDLE;
      end case;
    end process;

    clr_counter_w <= '1' when state_r = IDLE else '0';
    char_count_w  <= '1' when state_r = NEXT_CHAR else '0';
    uart_tstart_w <= '1' when state_r = DATA  else
                     '1' when state_r = BREAK else
                     '1' when state_r = SPACE else
                     '0';

    -- set fifo read when there is data and sender is waiting
    fifo_read_w <= '1' when state_r = IDLE and fifo_empty_w = '0' else '0';
    
    print_data_p : process (clk_i)
    begin
      if rising_edge(clk_i) then
        if fifo_valid_w = '1' then
          print_data_r <= fifo_rdata_w;
        end if;
      end if;
    end process;

    char_counter_p : process (rstn_i, clk_i)
    begin
      if rstn_i = '0' then
        char_counter_r <= CHAR_FIRST;
      elsif rising_edge(clk_i) then
        if clr_counter_w = '1' then
          char_counter_r <= CHAR_FIRST;
        elsif char_count_w = '1' then
          char_counter_r <= std_logic_vector(unsigned(char_counter_r)-1);
        end if;
      end if;
    end process;
    char_last_w  <= '1' when char_counter_r = CHAR_LAST  else '0';
    char_space_w <= '1' when char_counter_r = CHAR_SPACE0 else
                    '1' when char_counter_r = CHAR_SPACE1 else
                    '1' when char_counter_r = CHAR_SPACE2 else
                    '1' when char_counter_r = CHAR_SPACE3 else
                    '1' when char_counter_r = CHAR_SPACE4 else
                    '0';

    hex_data_w <= print_data_r(to_integer(unsigned(char_counter_r&"00"))+3 downto to_integer(unsigned(char_counter_r&"00")));

    -- Hex to utf-8
    utf8_hex_u : entity work.utf8_hex
    port map (
      data_i     => hex_data_w,
      utf_data_o => utf_data_w
    );

    uart_tdata_w <= utf_data_w when state_r = DATA  else
                    x"0A"      when state_r = BREAK else
                    x"20"      when state_r = SPACE else
                    x"0A";

    -- UART Instance to host computer
    uart_u : entity work.uart
    port map (
      rstn_i     => rstn_i,
      clk_i      => clk_i,
      baud_div_i => baud_rate_i,
      parity_i   => '0',
      rtscts_i   => '0',
      tready_o   => open, 
      tstart_i   => uart_tstart_w,
      tdata_i    => uart_tdata_w,
      tdone_o    => uart_tdone_w, --TODO Send data. Wait for done 
      rready_i   => '1',
      rdone_o    => open, -- unused interface
      rdata_o    => open, --
      rerr_o     => open,
      uart_rx_i  => rx_host_i,
      uart_tx_o  => tx_host_o,
      uart_cts_i => '0',
      uart_rts_o => open
    );
  end block;
                    
end architecture;