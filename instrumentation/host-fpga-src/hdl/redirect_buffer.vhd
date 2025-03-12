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

entity redirect_buffer is
  generic (
    T2H_FIFO_SIZE  : integer := 64;
    H2T_FIFO_SIZE  : integer := 64
  );
  port (
    -- Inputs
    clk_i  : in std_logic;
    rstn_i : in std_logic;
    -- setup
    host_baud_rate_i : in std_logic_vector(15 downto 0);
    sut_baud_rate_i  : in std_logic_vector(15 downto 0);
    -- internal
    timestamp_i : in std_logic_vector(31 downto 0);
    -- uart host
    tx_host_o : out std_logic;
    rx_host_i        : in std_logic; -- To computer
    -- uart - SUT (transceivers)
    rx_sut_i : in  std_logic;
    tx_sut_o : out std_logic
  );
end entity;
architecture rtl of redirect_buffer is
    
    -- Transceiver to host
    signal t2h_uart_rdone_w      : std_logic;
    signal t2h_uart_rdata_w      : std_logic_vector(7 downto 0);
    signal t2h_fifo_valid_w      : std_logic;
    -- Transmit to UART from FIFO
    -- Transceiver to host
    -- Register tready signal
    signal t2h_tready_w          : std_logic;
    signal t2h_fifo_tdata_r      : std_logic_vector(7 downto 0);

    -- Host to transceiver
    signal h2t_uart_rdone_w      : std_logic;
    signal h2t_uart_rdata_w      : std_logic_vector(7 downto 0);
    signal h2t_fifo_valid_w      : std_logic;
    -- Transmit to UART from FIFO
    -- Register tready signal
    signal h2t_tready_w          : std_logic;
    signal h2t_fifo_tdata_r      : std_logic_vector(7 downto 0);


begin

  -- UART redirection
  -- From transceivers to FIFO + FIFO to transceivers
  uart_transceivers_u : entity work.uart
  port map (
    rstn_i     => rstn_i,
    clk_i      => clk_i,
    baud_div_i => sut_baud_rate_i,
    parity_i   => '0',
    rtscts_i   => '0',
    tready_o   => h2t_tready_w, 
    tstart_i   => h2t_fifo_valid_w,
    tdata_i    => h2t_fifo_tdata_r, 
    tdone_o    => open,  
    rready_i   => '1',
    rdone_o    => t2h_uart_rdone_w,
    rdata_o    => t2h_uart_rdata_w,
    rerr_o     => open,
    uart_rx_i  => rx_sut_i,
    uart_tx_o  => tx_sut_o,
    uart_cts_i => '0',
    uart_rts_o => open
  );

  -- -- UART Instance to/from host computer
  uart_host_u : entity work.uart
  port map (
    rstn_i     => rstn_i,
    clk_i      => clk_i,
    baud_div_i => host_baud_rate_i,
    parity_i   => '0',
    rtscts_i   => '0',
    tready_o   => t2h_tready_w, 
    tstart_i   => t2h_fifo_valid_w,
    tdata_i    => t2h_fifo_tdata_r, 
    tdone_o    => open, --TODO Send data. Wait for done 
    rready_i   => '1',
    rdone_o    => h2t_uart_rdone_w,
    rdata_o    => h2t_uart_rdata_w,
    rerr_o     => open,
    uart_rx_i  => rx_host_i, -- From pc to uart
    uart_tx_o  => tx_host_o,
    uart_cts_i => '0',
    uart_rts_o => open
  );


  t2h_block : block
    -- FSM States
    constant FIFO_IDLE       : std_logic_vector(3 downto 0) := "0000";
    constant FIFO_TIME1      : std_logic_vector(3 downto 0) := "0001";
    constant FIFO_TIME2      : std_logic_vector(3 downto 0) := "0010";
    constant FIFO_TIME3      : std_logic_vector(3 downto 0) := "0011";
    constant FIFO_TIME4      : std_logic_vector(3 downto 0) := "0100";
    constant FIFO_TIME5      : std_logic_vector(3 downto 0) := "0101";
    constant FIFO_TIME6      : std_logic_vector(3 downto 0) := "0110";
    constant FIFO_TIME7      : std_logic_vector(3 downto 0) := "0111";
    constant FIFO_TIME8      : std_logic_vector(3 downto 0) := "1000";
    -- constant FIFO_NOTIME     : std_logic_vector(3 downto 0) := "1001";
    constant FIFO_SPACE      : std_logic_vector(3 downto 0) := "1010";
    constant FIFO_DATA       : std_logic_vector(3 downto 0) := "1011";
    constant FIFO_NEXT_BYTE  : std_logic_vector(3 downto 0) := "1100";
    -- FIFO Write FSM Signals 
    signal w_current_state_r   : std_logic_vector(3 downto 0);
    signal w_next_state_w      : std_logic_vector(3 downto 0);

    -- Signals for block
    signal t2h_read_en_w        : std_logic;
    signal t2h_fifo_empty_w     : std_logic;      
    signal t2h_fifo_tdata_w     : std_logic_vector(7 downto 0);
    signal t2h_fifo_wdata_w     : std_logic_vector(7 downto 0);
    signal t2h_fifo_write_en_w  : std_logic;
    signal t2h_uart_rdata_r     : std_logic_vector(7 downto 0);
    signal t2h_fifo_rem_size_w  : std_logic_vector(31 downto 0);

    signal fifo_nearly_full_w : std_logic;

    -- Convert hex to utf-8
    signal timestamp_utf8_rdata_w : std_logic_vector(7 downto 0); -- Timestamp to send in UTF-8
    signal timestamp_rdata_w      : std_logic_vector(3 downto 0);
    signal timestamp_rdata_r      : std_logic_vector(31 downto 0);

  begin
    -- Instantiate FIFO
    -- FIFO for transceivers get timestamp
    fifo_u : entity work.fifo
    generic map (
      FIFO_SIZE => T2H_FIFO_SIZE,
      DATA_WIDTH => 8
    )
    port map ( 
      write_i    => t2h_fifo_write_en_w,
      data_i     => t2h_fifo_wdata_w,
      read_i     => t2h_read_en_w, 
      clk_i      => clk_i,
      rstn_i     => rstn_i,
      full_o     => open, --TODO Send data. Optional = counter in registers of how many times it was full
      empty_o    => t2h_fifo_empty_w, 
      valid_o    => t2h_fifo_valid_w, 
      data_o     => t2h_fifo_tdata_w,
      rem_size_o => t2h_fifo_rem_size_w
    );

    -- set nearly full when timestamp plus minimum amount of data does not fit in the FIFO
    fifo_nearly_full_w <= '1' when unsigned(t2h_fifo_rem_size_w) < 16 else '0';

    -- Redirect and Timestamp FSM
    -- Writing to FSM
    -- Write to FIFO 
    -- Write 4x8 bit timestamp and 1x 8 bit data
    -- ======================================= WRITE TO FIFO =======================================
    current_state_p : process (clk_i, rstn_i)
    begin
      if rstn_i = '0' then
        w_current_state_r <= FIFO_IDLE;
        elsif rising_edge(clk_i) then
          w_current_state_r <= w_next_state_w;        
      end if;
    end process;

    next_state_p : process(clk_i, rstn_i)
    begin
      case w_current_state_r is
        -- IDLE
        when FIFO_IDLE =>
          if t2h_uart_rdone_w = '1' then
            if fifo_nearly_full_w = '1' then
              w_next_state_w <= FIFO_DATA;  
            else
              w_next_state_w <= FIFO_TIME1;
            end if;
          else
            w_next_state_w <= FIFO_IDLE;
          end if;
        -- TIME 1
        when FIFO_TIME1 =>
            w_next_state_w <= FIFO_TIME2;
        
        -- TIME 2
        when FIFO_TIME2 =>
            w_next_state_w <= FIFO_TIME3;
        -- TIME 3
        when FIFO_TIME3 =>
            w_next_state_w <= FIFO_TIME4;
        -- TIME 4
        when FIFO_TIME4 =>
            w_next_state_w <= FIFO_TIME5;

        -- TIME 5
        when FIFO_TIME5 =>
            w_next_state_w <= FIFO_TIME6;
        
        -- TIME 6
        when FIFO_TIME6 =>
            w_next_state_w <= FIFO_TIME7;
        -- TIME 7
        when FIFO_TIME7 =>
            w_next_state_w <= FIFO_TIME8;
        -- TIME 8
        when FIFO_TIME8 =>
            w_next_state_w <= FIFO_SPACE;

        -- when FIFO_NOTIME =>
        --     w_next_state_w <= FIFO_SPACE;

        -- Space
        when FIFO_SPACE =>
            w_next_state_w <= FIFO_DATA;

        -- DATA
        when FIFO_DATA =>
          if t2h_uart_rdata_r = x"0a" then -- If done and rdata is a line break, go to idle
            w_next_state_w <= FIFO_IDLE;
          else -- If done and rdata is not a line break
            w_next_state_w <= FIFO_NEXT_BYTE; -- Wait for next byte
          end if;

        -- NEXT BYTE
        when FIFO_NEXT_BYTE =>
          if t2h_uart_rdone_w = '1' then
            w_next_state_w <= FIFO_DATA;
          else
            w_next_state_w <= FIFO_NEXT_BYTE;
          end if;
        
          -- Others
        when others => w_next_state_w <= FIFO_IDLE;
      end case;
    end process;

    -- rdata
    rdata_p : process (clk_i)
    begin
      if rising_edge(clk_i) then
        if t2h_uart_rdone_w = '1' then
          t2h_uart_rdata_r <= t2h_uart_rdata_w;
          timestamp_rdata_r <= timestamp_i;
        end if;
      end if;
    end process;

    -- ======================================= READ FROM FIFO =======================================
    -- Process to for read_i
    read_fifo_p : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if t2h_fifo_valid_w = '1' then
          t2h_fifo_tdata_r <= t2h_fifo_tdata_w;
        end if;
      end if;
    end process;

    t2h_read_en_w <= t2h_tready_w and not t2h_fifo_empty_w and not t2h_fifo_valid_w;

    timestamp_rdata_w <=  timestamp_rdata_r(31 downto 28) when w_current_state_r = FIFO_TIME1 else
                          timestamp_rdata_r(27 downto 24) when w_current_state_r = FIFO_TIME2 else
                          timestamp_rdata_r(23 downto 20) when w_current_state_r = FIFO_TIME3 else
                          timestamp_rdata_r(19 downto 16) when w_current_state_r = FIFO_TIME4 else
                          timestamp_rdata_r(15 downto 12) when w_current_state_r = FIFO_TIME5 else
                          timestamp_rdata_r(11 downto  8) when w_current_state_r = FIFO_TIME6 else
                          timestamp_rdata_r( 7 downto  4) when w_current_state_r = FIFO_TIME7 else
                          timestamp_rdata_r( 3 downto  0);

    -- Hex to utf-8
    utf8_hex_u : entity work.utf8_hex
    port map (
      data_i => timestamp_rdata_w,
      utf_data_o => timestamp_utf8_rdata_w
    );

    -- FIFO control
    -- Write enable to  FIFO
    t2h_fifo_write_en_w <= '1' when w_current_state_r = FIFO_TIME1  else
                           '1' when w_current_state_r = FIFO_TIME2  else
                           '1' when w_current_state_r = FIFO_TIME3  else
                           '1' when w_current_state_r = FIFO_TIME4  else
                           '1' when w_current_state_r = FIFO_TIME5  else
                           '1' when w_current_state_r = FIFO_TIME6  else
                           '1' when w_current_state_r = FIFO_TIME7  else
                           '1' when w_current_state_r = FIFO_TIME8  else
                          --  '1' when w_current_state_r = FIFO_NOTIME else
                           '1' when w_current_state_r = FIFO_SPACE  else
                           '1' when w_current_state_r = FIFO_DATA   else
                           '0';
      
    t2h_fifo_wdata_w <= t2h_uart_rdata_r when w_current_state_r = FIFO_DATA   else
                        -- x"7E"            when w_current_state_r = FIFO_NOTIME else
                        x"20"            when w_current_state_r = FIFO_SPACE  else
                        timestamp_utf8_rdata_w;
  end block;

  -- Host to transceiver
  -- Small fifo
  h2t_block : block
    -- Signals for block
    signal h2t_read_en_w         : std_logic;
    signal h2t_fifo_empty_w      : std_logic;      
    signal h2t_fifo_tdata_w      : std_logic_vector(7 downto 0);
    signal h2t_fifo_wdata_w      : std_logic_vector(7 downto 0);
    signal h2t_fifo_write_en_w   : std_logic;
  begin
    -- Instantiate FIFO
    -- FIFO for transceivers get timestamp
    fifo_u : entity work.fifo
    generic map (
      FIFO_SIZE => H2T_FIFO_SIZE,
      DATA_WIDTH => 8
    )
    port map ( 
      write_i    =>h2t_uart_rdone_w,
      data_i     => h2t_uart_rdata_w,
      read_i     => h2t_read_en_w, 
      clk_i      => clk_i,
      rstn_i     => rstn_i,
      full_o     => open, --TODO Send data. Optional = counter in registers of how many times it was full
      empty_o    => h2t_fifo_empty_w, 
      valid_o    => h2t_fifo_valid_w, 
      data_o     => h2t_fifo_tdata_w,
      rem_size_o => open
    );

    -- ======================================= READ FROM FIFO =======================================
    -- Process to for read_i
    read_fifo_p : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if h2t_fifo_valid_w = '1' then
          h2t_fifo_tdata_r <= h2t_fifo_tdata_w;
        end if;
      end if;
    end process;

    h2t_read_en_w <= h2t_tready_w and not h2t_fifo_empty_w and not h2t_fifo_valid_w;

  end block;
                    
end architecture;