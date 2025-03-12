library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cmd is
  port (
    rstn_i : in std_logic;
    clk_i  : in std_logic;
      
    -- RX TX
    rx_i   : in std_logic;
    tx_o   : out std_logic;

    -- Register interface
    wr_en_o : out std_logic;
    rd_en_o : out std_logic;
    addr_o  : out std_logic_vector(15 downto 0);
    wdata_o : out std_logic_vector(15 downto 0);
    rdata_i : in  std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of cmd is

  -- UART 2 states
  constant IDLE         : std_logic_vector (4 downto 0) := "00000";
  constant WRITE_LF     : std_logic_vector (4 downto 0) := "00001";

  constant WADDR3  : std_logic_vector (4 downto 0) := "00010";
  constant WADDR2  : std_logic_vector (4 downto 0) := "00011";
  constant WADDR1  : std_logic_vector (4 downto 0) := "00100";
  constant WADDR0  : std_logic_vector (4 downto 0) := "00101";
  constant WDATA3  : std_logic_vector (4 downto 0) := "00110";
  constant WDATA2  : std_logic_vector (4 downto 0) := "00111";
  constant WDATA1  : std_logic_vector (4 downto 0) := "01000";
  constant WDATA0  : std_logic_vector (4 downto 0) := "01001";
  constant REG_WRITE  : std_logic_vector (4 downto 0) := "01010"; -- Actual write to register

  constant RADDR3  : std_logic_vector (4 downto 0) := "01011";
  constant RADDR2  : std_logic_vector (4 downto 0) := "01100";
  constant RADDR1  : std_logic_vector (4 downto 0) := "01101";
  constant RADDR0  : std_logic_vector (4 downto 0) := "01110";
  constant REG_READ: std_logic_vector (4 downto 0) := "01111"; -- Actual READ to register
  constant RDATA3  : std_logic_vector (4 downto 0) := "10000";
  constant RDATA2  : std_logic_vector (4 downto 0) := "10001";
  constant RDATA1  : std_logic_vector (4 downto 0) := "10010";
  constant RDATA0  : std_logic_vector (4 downto 0) := "10011";

  -- FSM Signal
  signal state_r   : std_logic_vector(4 downto 0);
  signal next_w    : std_logic_vector(4 downto 0);

  -- UART signals
  signal uart_rdone_w  : std_logic;
  signal uart_rdata_w  : std_logic_vector(7 downto 0);
  signal uart_tstart_w : std_logic;
  signal uart_tdata_w  : std_logic_vector(7 downto 0);
  signal uart_tdone_w  : std_logic;

  -- Write
  signal en_waddr_w   : std_logic_vector(3 downto 0); -- Vector for selecting 4 bit addresses all states - Write
  signal en_wdata_w   : std_logic_vector(3 downto 0); -- Vector containing data - Write
  signal en_wreg_w    : std_logic;

  -- Read
  signal en_raddr_w   : std_logic_vector(3 downto 0); -- Vector for selecting 4 bit addresses all states - Read
  signal en_rdata_w   : std_logic_vector(3 downto 0); -- Vector containing data - Read
  signal en_rreg_w    : std_logic;

  -- Address register
  signal addr_r      : std_logic_vector(15 downto 0);

  -- Data register
  signal data_r     : std_logic_vector(15 downto 0);

  -- Converted signals
  signal converted_rdata_w : std_logic_vector (3 downto 0);
  signal selected_wdata_w  : std_logic_vector(3 downto 0);
  signal utf8_tdata_w      : std_logic_vector(7 downto 0);
  signal write_lf_w        : std_logic;

  -- 
  signal reg_data_w     : std_logic_vector(15 downto 0); -- Actual data from registers


begin
  -- FSM UART
  
  -- State Machine
  -- Current state
  current_state_p : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      state_r <= IDLE;
    elsif rising_edge(clk_i) then
      state_r <= next_w;
    end if;
  end process current_state_p;

  -- Next state
  next_state_p : process(all)
  begin
    case state_r is
      when IDLE =>
        if uart_rdone_w = '1' and uart_rdata_w = x"72" then -- Read register
          next_w <= RADDR3;
        elsif uart_rdone_w = '1' and uart_rdata_w = x"77" then
          next_w <= WADDR3;
        else
          next_w <= IDLE;
        end if;

      -- ============================================== READ ==============================================
      when RADDR3 =>
      if uart_rdone_w = '1' then
        next_w <= RADDR2;
      else
        next_w <= RADDR3;
      end if;

      when RADDR2 =>
      if uart_rdone_w = '1' then
        next_w <= RADDR1;
      else
        next_w <= RADDR2;
      end if;

      when RADDR1 =>
      if uart_rdone_w = '1' then
        next_w <= RADDR0;
      else
        next_w <= RADDR1;
      end if;

      when RADDR0 =>
      if uart_rdone_w = '1' then
        next_w <= REG_READ;
      else
        next_w <= RADDR0;
      end if;

      when REG_READ =>
        next_w <= RDATA3;

      -- Start sending data
      when RDATA3 =>
      if uart_tdone_w = '1' then
        next_w <= RDATA2;
      else
        next_w <= RDATA3;
      end if;

      when RDATA2 =>
      if uart_tdone_w = '1' then
        next_w <= RDATA1;
      else
        next_w <= RDATA2;
      end if;

      when RDATA1 =>
      if uart_tdone_w = '1' then
        next_w <= RDATA0;
      else
        next_w <= RDATA1;
      end if;

      when RDATA0 =>
      if uart_tdone_w = '1' then
        next_w <= WRITE_LF;
      else
        next_w <= RDATA0;
      end if;

      when WRITE_LF =>
        if uart_tdone_w = '1' then
          next_w <= IDLE;
        else
          next_w <= WRITE_LF;
        end if;

        -- ============================================== WRITE ==============================================
      when WADDR3 =>
      if uart_rdone_w = '1' then
        next_w <= WADDR2;
      else
        next_w <= WADDR3;
      end if;

      when WADDR2 =>
      if uart_rdone_w = '1' then
        next_w <= WADDR1;
      else
        next_w <= WADDR2;
      end if;

      when WADDR1 =>
      if uart_rdone_w = '1' then
        next_w <= WADDR0;
      else
        next_w <= WADDR1;
      end if;

      when WADDR0 =>
      if uart_rdone_w = '1' then
        next_w <= WDATA3;
      else
        next_w <= WADDR0;
      end if;

      -- Start sending data
      when WDATA3 =>
      if uart_rdone_w = '1' then
        next_w <= WDATA2;
      else
        next_w <= WDATA3;
      end if;

      when WDATA2 =>
      if uart_rdone_w = '1' then
        next_w <= WDATA1;
      else
        next_w <= WDATA2;
      end if;

      when WDATA1 =>
      if uart_rdone_w = '1' then
        next_w <= WDATA0;
      else
        next_w <= WDATA1;
      end if;

      when WDATA0 =>
      if uart_rdone_w = '1' then
        next_w <= REG_WRITE;
      else
        next_w <= WDATA0;
      end if;

      when REG_WRITE =>
        next_w <= IDLE;


      when others => next_w <= IDLE;
      end case;
  end process next_state_p;

  uart_tstart_w <= '1' when state_r = RDATA3 else
                   '1' when state_r = RDATA2 else
                   '1' when state_r = RDATA1 else
                   '1' when state_r = RDATA0 else 
                   '1' when state_r = WRITE_LF else
                   '0';
  
  -- Write
  en_waddr_w   <= "1000" when state_r = WADDR3 and uart_rdone_w = '1' else
                  "0100" when state_r = WADDR2 and uart_rdone_w = '1' else
                  "0010" when state_r = WADDR1 and uart_rdone_w = '1' else
                  "0001" when state_r = WADDR0 and uart_rdone_w = '1' else
                  "0000"; -- Vector for selecting 4 bit addresses all states - Write

  en_wdata_w   <= "1000" when state_r = WDATA3 and uart_rdone_w = '1' else
                  "0100" when state_r = WDATA2 and uart_rdone_w = '1' else
                  "0010" when state_r = WDATA1 and uart_rdone_w = '1' else
                  "0001" when state_r = WDATA0 and uart_rdone_w = '1' else
                  "0000"; -- Vector containing data - Write

  en_wreg_w    <= '1' when state_r = REG_WRITE else '0'; -- Read


  write_lf_w <= '1' when state_r = WRITE_LF else '0';

  -- Read
  en_raddr_w   <= "1000" when state_r = RADDR3 and uart_rdone_w = '1' else
                  "0100" when state_r = RADDR2 and uart_rdone_w = '1' else
                  "0010" when state_r = RADDR1 and uart_rdone_w = '1' else
                  "0001" when state_r = RADDR0 and uart_rdone_w = '1' else
                  "0000"; -- Vector for selecting 4 bit addresses all states - Read

  en_rdata_w   <= "1000" when state_r = RDATA3 else
                  "0100" when state_r = RDATA2 else
                  "0010" when state_r = RDATA1 else
                  "0001" when state_r = RDATA0 else
                  "0000"; -- Vector containing data - Read

  en_rreg_w    <= '1' when state_r = REG_READ else '0';

  -- Transmit interface
  utf8_hex_u : entity work.utf8_hex
  port map (
    data_i => selected_wdata_w,
    utf_data_o => utf8_tdata_w -- Converted data to uart input
  );

  -- Takes from UART and convert to hex to write to register
  hex_utf8_u : entity work.hex_utf8
  port map (
    utf_data_i => uart_rdata_w, -- Output from uart
    data_o => converted_rdata_w
  );

  -- 
  uart_tdata_w <= x"0a" when write_lf_w = '1' else utf8_tdata_w;

  -- Compare en_rdata_w corresponding bit 
  selected_wdata_w <= data_r(15 downto 12) when en_rdata_w(3) = '1' else 
                      data_r(11 downto 8)  when en_rdata_w(2) = '1' else
                      data_r(7 downto 4)   when en_rdata_w(1) = '1' else
                      data_r(3 downto 0); -- when en_rdata_w(0) = '1'

  -- Get address process
  get_address_p : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if en_waddr_w(3) = '1' or en_raddr_w(3) = '1' then
        addr_r(15 downto 12) <= converted_rdata_w;
      end if;
      if en_waddr_w(2) = '1' or en_raddr_w(2) = '1' then
        addr_r(11 downto 8) <= converted_rdata_w;
      end if;
      if en_waddr_w(1) = '1' or en_raddr_w(1) = '1' then
        addr_r(7 downto 4) <= converted_rdata_w;
      end if;
      if en_waddr_w(0) = '1' or en_raddr_w(0) = '1' then
        addr_r(3 downto 0) <= converted_rdata_w;
      end if;
    end if;
  end process;  

  -- Get data process
  -- Read the corresponding portion of the data register
  get_data_p : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if en_rreg_w = '1' then
        data_r <= reg_data_w;
      else
        if en_wdata_w(3) = '1' then
          data_r(15 downto 12) <= converted_rdata_w;
        end if;
        if en_wdata_w(2) = '1' then
          data_r(11 downto 8) <= converted_rdata_w;
        end if;
        if en_wdata_w(1) = '1' then
          data_r(7 downto 4) <= converted_rdata_w;
        end if;
        if en_wdata_w(0) = '1' then
          data_r(3 downto 0) <= converted_rdata_w;
        end if;
      end if;
    end if;
  end process;     
  
  uart_u_1 : entity work.uart
  port map (
    rstn_i     => rstn_i,
    clk_i      => clk_i,
    baud_div_i => x"01B2",
    parity_i   => '0',
    rtscts_i   => '0',
    tready_o   => open,
    tstart_i   => uart_tstart_w,
    tdata_i    => uart_tdata_w,
    tdone_o    => uart_tdone_w,
    rready_i   => '1',
    rdone_o    => uart_rdone_w,
    rdata_o    => uart_rdata_w,
    rerr_o     => open,
    uart_rx_i  => rx_i,
    uart_tx_o  => tx_o,
    uart_cts_i => '0',
    uart_rts_o => open
  );

  -- Read/Write to ports
  reg_data_w <= rdata_i;
  wr_en_o <= en_wreg_w;
  rd_en_o <= en_rreg_w;
  wdata_o <= data_r;
  addr_o  <= addr_r;

   

end architecture;