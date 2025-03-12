library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use ieee.math_real.round;


entity uart is
  port (
    -- sync
    rstn_i : in std_logic;
    clk_i  : in std_logic;

    -- configuration
    baud_div_i : in std_logic_vector(15 downto 0);
    parity_i   : in std_logic;
    rtscts_i   : in std_logic;

    -- transmit interface
    tready_o : out std_logic;
    tstart_i : in  std_logic;
    tdata_i  : in  std_logic_vector(7 downto 0);
    tdone_o  : out std_logic;

    -- receive interface
    rready_i : in  std_logic;
    rdone_o  : out std_logic;
    rdata_o  : out std_logic_vector(7 downto 0);
    rerr_o   : out std_logic;

    -- serial ports
    uart_rx_i  : in  std_logic;
    uart_tx_o  : out std_logic;
    uart_cts_i : in  std_logic;
    uart_rts_o : out std_logic

  );
end uart;

architecture arch of uart is
  -- baud_div_i = ceil( FREQUENCY / BAUD_RATE ) - 1
  signal baud_div_max_w : std_logic_vector(15 downto 0);
  signal baud_div_mid_w : std_logic_vector(15 downto 0);

  -----------------------------------------------------------
  -------------------- TRANSMIT FSM -------------------------
  -----------------------------------------------------------
  constant TX_IDLE     : std_logic_vector(2 downto 0) := "000";
  constant TX_WAIT_CTS : std_logic_vector(2 downto 0) := "001";
  constant TX_START    : std_logic_vector(2 downto 0) := "010";
  constant TX_DATA     : std_logic_vector(2 downto 0) := "011";
  constant TX_PARITY   : std_logic_vector(2 downto 0) := "100";
  constant TX_STOP     : std_logic_vector(2 downto 0) := "101";
  signal tx_curr_r : std_logic_vector(2 downto 0);
  signal tx_next_w : std_logic_vector(2 downto 0);

  signal tcounter_r : std_logic_vector(2 downto 0);
  signal tbaud_r    : std_logic_vector(15 downto 0);
  signal tmax_w     : std_logic;


  -----------------------------------------------------------
  -------------------- RECEIVE FSM --------------------------
  -----------------------------------------------------------
  constant RX_IDLE   : std_logic_vector(2 downto 0) := "000";
  constant RX_START  : std_logic_vector(2 downto 0) := "001";
  constant RX_DATA   : std_logic_vector(2 downto 0) := "010";
  constant RX_PARITY : std_logic_vector(2 downto 0) := "011";
  constant RX_STOP   : std_logic_vector(2 downto 0) := "100";
  signal rx_curr_r : std_logic_vector(2 downto 0);
  signal rx_next_w : std_logic_vector(2 downto 0);


  signal ctl_rbaud_clr_w : std_logic;
  signal ctl_rbaud_cnt_w : std_logic;
  signal ctl_rbit_clr_w  : std_logic;
  signal ctl_rbit_cnt_w  : std_logic;

  signal ctl_reg_rdata_w   : std_logic;
  signal ctl_reg_rparity_w : std_logic;

  signal rdata_r     : std_logic_vector(8 downto 0);
  signal rbaud_r     : std_logic_vector(15 downto 0);
  signal rbaud_max_w : std_logic;
  signal rbaud_mid_w : std_logic;
  signal rcounter_r  : std_logic_vector(2 downto 0);
  signal rbit_max_w  : std_logic;

  attribute syn_preserve : boolean;
  attribute syn_preserve of tx_curr_r : signal is true;
  attribute syn_preserve of rx_curr_r : signal is true;
  -- Synplify attributes to prevent optimization of TMR
  attribute syn_radhardlevel : string;
  attribute syn_keep         : boolean;
  attribute syn_safe_case    : boolean;
  attribute syn_noprune      : boolean;
  attribute syn_radhardlevel of rx_curr_r : signal is "tmr";
  attribute syn_keep         of rx_curr_r : signal is TRUE;
  attribute syn_safe_case    of rx_curr_r : signal is TRUE;
  attribute syn_noprune      of rx_curr_r : signal is TRUE;
  -- tx
  attribute syn_radhardlevel of tx_curr_r : signal is "tmr";
  attribute syn_keep         of tx_curr_r : signal is TRUE;
  attribute syn_safe_case    of tx_curr_r : signal is TRUE;
  attribute syn_noprune      of tx_curr_r : signal is TRUE;


begin

  baud_div_max_w <= baud_div_i;
  baud_div_mid_w <= "0" & baud_div_i(15 downto 1);

  -----------------------------------------------------------
  -------------------- TRANSMIT FSM -------------------------
  -----------------------------------------------------------

  p_TX_FSM : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      tx_curr_r <= TX_IDLE;
    elsif rising_edge(clk_i) then
      tx_curr_r <= tx_next_w;
    end if;
  end process;
  p_TX_NEXT : process(all)
  begin
    case (tx_curr_r) is

      when TX_IDLE =>
        if tstart_i = '1' then
          -- if flow control disabled or cts available
          if rtscts_i = '0' or uart_cts_i = '0' then
            tx_next_w <= TX_START;
          else
            tx_next_w <= TX_WAIT_CTS;
          end if;
        else
          tx_next_w <= TX_IDLE;
        end if;

      when TX_WAIT_CTS =>
        if rtscts_i = '0' or uart_cts_i = '0' then
          tx_next_w <= TX_START;
        else
          tx_next_w <= TX_WAIT_CTS;
        end if;

      when TX_START =>
        if tmax_w = '1' then
          tx_next_w <= TX_DATA;
        else
          tx_next_w <= TX_START;
        end if;

      when TX_DATA =>
        if tmax_w = '1' and tcounter_r = "111" then
          if parity_i = '1' then
            tx_next_w <= TX_PARITY;
          else
            tx_next_w <= TX_STOP;
          end if;
        else
          tx_next_w <= TX_DATA;
        end if;

      when TX_PARITY =>
        if tmax_w = '1' then
          tx_next_w <= TX_STOP;
        else
          tx_next_w <= TX_PARITY;
        end if;

      when TX_STOP =>
        if rtscts_i = '1' and uart_cts_i = '1' then -- if flow control and not clear to send
          tx_next_w <= TX_WAIT_CTS; -- go to wait CTS and re-send byte
        elsif tmax_w = '1' then
          tx_next_w <= TX_IDLE;
        else
          tx_next_w <= TX_STOP;
        end if;

      when others => tx_next_w <= TX_IDLE;

    end case;
  end process;
  p_TX_COUNTERS : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      tbaud_r    <= (others => '0');
      tcounter_r <= (others => '0');
    elsif rising_edge(clk_i) then
      if tx_curr_r = TX_IDLE or tx_curr_r = TX_WAIT_CTS then
        tbaud_r    <= (others => '0');
        tcounter_r <= (others => '0');
      else -- transmitting data
        -- if baud counter reached divider value
        if tmax_w = '1' then
          -- restart baud counter
          tbaud_r <= (others => '0');
          -- if it's transmitting data
          if tx_curr_r = TX_DATA then
            -- increment bit counter
            tcounter_r <= std_logic_vector(unsigned(tcounter_r) + 1);
          end if;
        else
          -- increment baud counter
          tbaud_r <= std_logic_vector(unsigned(tbaud_r) + 1);
        end if;
      end if;
    end if;
  end process;

  tready_o <= '1' when tx_curr_r = TX_IDLE else '0';

  tmax_w    <= '1' when tbaud_r = baud_div_max_w else '0';
  uart_tx_o <= tdata_i(to_integer(unsigned(tcounter_r))) when tx_curr_r = TX_DATA   else
               xor_reduce(tdata_i)                       when tx_curr_r = TX_PARITY else
               '0'                                       when tx_curr_r = TX_START  else
               '1';
  tdone_o <= tmax_w when tx_curr_r = TX_STOP else '0';


  -----------------------------------------------------------
  -------------------- RECEIVE FSM --------------------------
  -----------------------------------------------------------


  p_RX_FSM : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      rx_curr_r <= RX_IDLE;
    elsif rising_edge(clk_i) then
      rx_curr_r <= rx_next_w;
    end if;
  end process;
  p_RX_NEXT : process(all)
  begin
    case (rx_curr_r) is
      when RX_IDLE =>
        -- wait start bit
        if uart_rx_i = '0' then
          rx_next_w <= RX_START;
        else
          rx_next_w <= RX_IDLE;
        end if;

      when RX_START =>
        -- wait max
        if rbaud_max_w = '1' then
          rx_next_w <= RX_DATA;
        else
          rx_next_w <= RX_START;
        end if;

      when RX_DATA =>
        if rbit_max_w = '1' and rbaud_max_w = '1' then
          if parity_i = '1' then
            rx_next_w <= RX_PARITY;
          else
            rx_next_w <= RX_STOP;
          end if;
        else
          rx_next_w <= RX_DATA;
        end if;

      when RX_PARITY =>
        if rbaud_max_w = '1' then
          rx_next_w <= RX_STOP;
        else
          rx_next_w <= RX_PARITY;
        end if;

      when RX_STOP =>
        if rbaud_mid_w = '1' then
          rx_next_w <= RX_IDLE;
        else
          rx_next_w <= RX_STOP;
        end if;

      when others => rx_next_w <= RX_IDLE;

    end case;
  end process;

  ctl_rbaud_clr_w <= '1' when rx_curr_r   = RX_IDLE else
                     '1' when rbaud_max_w = '1'     else
                     '0';
  ctl_rbaud_cnt_w <= '1' when rx_curr_r = RX_START  else
                     '1' when rx_curr_r = RX_DATA   else
                     '1' when rx_curr_r = RX_PARITY else
                     '1' when rx_curr_r = RX_STOP   else
                     '0';
  ctl_rbit_clr_w <= '1' when rx_curr_r = RX_IDLE else '0';
  ctl_rbit_cnt_w <= '1' when rx_curr_r = RX_DATA and rbaud_max_w = '1' else '0';

  ctl_reg_rdata_w   <= '1' when rx_curr_r = RX_DATA   and rbaud_mid_w = '1' else '0';
  ctl_reg_rparity_w <= '1' when rx_curr_r = RX_PARITY and rbaud_mid_w = '1' else '0';

  rdone_o <= '1' when rx_curr_r = RX_STOP and rbaud_mid_w = '1' else '0';

  p_RX_COUNTERS : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      rbaud_r    <= (others => '0');
      rcounter_r <= (others => '0');
    elsif rising_edge(clk_i) then
      -- baud rate counter
      if ctl_rbaud_clr_w = '1' then
        rbaud_r <= (others => '0');
      elsif ctl_rbaud_cnt_w = '1' then
        rbaud_r <= std_logic_vector(unsigned(rbaud_r) + 1);
      end if;
      -- received bit counter
      if ctl_rbit_clr_w = '1' then
        rcounter_r <= (others => '0');
      elsif ctl_rbit_cnt_w = '1' then
        rcounter_r <= std_logic_vector(unsigned(rcounter_r) + 1);
      end if;
    end if;
  end process;
  p_RX_DATA : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      rdata_r <= (others => '0');
    elsif rising_edge(clk_i) then
      if ctl_reg_rdata_w = '1' then
        rdata_r(to_integer(unsigned(rcounter_r))) <= uart_rx_i;
      elsif ctl_reg_rparity_w = '1' then
        rdata_r(8) <= uart_rx_i;
      end if;
    end if;
  end process;

  uart_rts_o <= not (rtscts_i and rready_i);

  rbaud_max_w <= '1' when rbaud_r = baud_div_max_w else '0';
  rbaud_mid_w <= '1' when rbaud_r = baud_div_mid_w else '0';

  rbit_max_w <= '1' when rcounter_r = "111" else '0';

  rerr_o  <= xor_reduce(rdata_r) and parity_i;
  rdata_o <= rdata_r(7 downto 0);

end architecture;
