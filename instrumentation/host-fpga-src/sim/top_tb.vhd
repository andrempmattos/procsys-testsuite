library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;

use std.textio.all;

entity top_tb is
  generic (
    WORK_DIR : string := ""
  );
end entity;

architecture arch of top_tb is
  constant period : time := 20 ns;
  signal rstn : std_logic := '0';
  signal clk  : std_logic := '0';

  -- procedure to write msg to uart, most-signifcant byte first
  procedure write_uart(
    msg : string;
    signal p_tstart : out std_logic;
    signal p_tdata  : out std_logic_vector(7 downto 0);
    signal p_tready : in  std_logic
    ) is
  begin
    -- iterate by each char
    for i in msg'range loop
      -- wait transmit to be ready
      wait until rising_edge(clk) and p_tready = '1';
      -- set data from input string
      p_tdata <= std_logic_vector(to_unsigned(integer(character'pos(msg(i))), 8));
      -- give start signal for 1 clock cycle
      p_tstart <= '1'; wait for period; p_tstart <= '0';
    end loop;
    -- wait transmit to be ready
    wait until rising_edge(clk) and p_tready = '1';
    -- write line break
    p_tdata <= x"0a";
    -- give start signal for 1 clock cycle
    p_tstart <= '1'; wait for period; p_tstart <= '0';
  end procedure;

  -- top signals
  signal uart_cmd_tx_o      : std_logic;
  signal uart_cmd_rx_i      : std_logic;
  signal uart_host_tx_0_o   : std_logic;
  signal uart_host_rx_0_i   : std_logic;
  signal uart_dut_tx_0_o    : std_logic;
  signal uart_dut_rx_0_i    : std_logic;
  signal uart_host_tx_1_o   : std_logic;
  signal uart_host_rx_1_i   : std_logic;
  signal uart_dut_tx_1_o    : std_logic;
  signal uart_dut_rx_1_i    : std_logic;
  signal uart_current_tx_o  : std_logic;
  signal uart_current_rx_i  : std_logic;

  --i2c testing
  signal top_i2c_scl : std_logic;
  signal top_i2c_sda : std_logic;

begin
  rstn <= '1' after period;
  clk  <= not clk after period/2;

  -- define simulation time
  process
  begin
    wait for 500 ms;
    std.env.finish;
  end process;

  ---------------------------------------------------------------------
  ----------------------------- TOP-LEVEL -----------------------------

  top_u : entity work.top
  port map (
    rstn_i            => rstn,
    clk_i             => clk,
    uart_cmd_tx_o     => uart_cmd_tx_o,
    uart_cmd_rx_i     => uart_cmd_rx_i,
    uart_host_tx_0_o  => uart_host_tx_0_o,
    uart_host_rx_0_i  => uart_host_rx_0_i,
    uart_dut_tx_0_o   => uart_dut_tx_0_o,
    uart_dut_rx_0_i   => uart_dut_rx_0_i,
    uart_host_tx_1_o  => uart_host_tx_1_o,
    uart_host_rx_1_i  => uart_host_rx_1_i,
    uart_dut_tx_1_o   => uart_dut_tx_1_o,
    uart_dut_rx_1_i   => uart_dut_rx_1_i,
    uart_current_tx_o => uart_current_tx_o,
    uart_current_rx_i => uart_current_rx_i,
    i2c_sda_io        => top_i2c_sda,
    i2c_scl_o         => top_i2c_scl
  );

  process
    variable sda : std_logic := '0';
  begin
    wait until rstn = '1';
    wait;
    loop
      wait until rising_edge(top_i2c_scl) and top_i2c_sda = 'Z';
      top_i2c_sda <= sda; sda := not sda;
      wait until falling_edge(top_i2c_scl);
      top_i2c_sda <= 'Z';
    end loop;
  end process;
  
  ----------------------------------------------------------------------------
  --------------------------- CMD SIMULATION BLOCK ---------------------------
  cmd_b : block
    signal tstart : std_logic := '0';
    signal tready : std_logic;
    signal tdata  : std_logic_vector(7 downto 0);
    signal rdone  : std_logic;
    signal rdata  : std_logic_vector(7 downto 0);

  begin

    -- write to uart
    process
    begin
      -- wait reset procedure
      wait until rstn = '1'; wait for 2*period;

      -- write data with line break
      write_uart("w0001caca", tstart, tdata, tready); -- write BOARD_NAME
      wait for 1 ms;
      write_uart("r0001", tstart, tdata, tready); -- read BOARD_NAME
      wait for 1 ms;
      write_uart("w02021a1e", tstart, tdata, tready); -- turn board ON
      wait for 1 ms;
      write_uart("r0201", tstart, tdata, tready); -- read GPIO
      wait for 1 ms;
      write_uart("w02011a1c", tstart, tdata, tready); -- turn board OFF
      wait for 1 ms;
      write_uart("w00070080", tstart, tdata, tready); -- set CURRENT_TH
      wait for 1 ms;
      write_uart("w00060008", tstart, tdata, tready); -- set CURRENT_SAMPLERATE (~10 ms)
      wait for 1 ms;

      -- prevent process to loop infinitely
      wait;
    end process;
  
    uart_u : entity work.uart
    port map (
      rstn_i     => rstn,
      clk_i      => clk,
      baud_div_i => x"01B2",
      parity_i   => '0',
      rtscts_i   => '0',
      tready_o   => tready,
      tstart_i   => tstart,
      tdata_i    => tdata,
      tdone_o    => open,
      rready_i   => '1',
      rdone_o    => rdone,
      rdata_o    => rdata,
      rerr_o     => open,
      uart_rx_i  => uart_cmd_tx_o,
      uart_tx_o  => uart_cmd_rx_i,
      uart_cts_i => '0',
      uart_rts_o => open
    );

    -- print UART output to console
    process
      variable rchar        : character;
      variable rdata_buffer : string(1 to 1024);
      variable size         : integer range 0 to 1024;
    begin
      size := 0;
      loop
        wait until rising_edge(clk) and rdone = '1';
        rchar := character'val(to_integer(unsigned(rdata)));
        size := size + 1;
        rdata_buffer(size) := rchar;
        -- check if it is line break
        if rchar = lf or size = rdata_buffer'length then
          -- print line
          report lf & "[CMD] " & rdata_buffer(1 to size-1);
          -- reset string size
          size := 0;
        end if;
      end loop;
    end process;
  end block;

  
  ----------------------------------------------------------------------------
  ----------------------- REDIRECT 0 SIMULATION BLOCK ------------------------
  redirect_0_b : block
    signal tstart : std_logic := '0';
    signal tready : std_logic;
    signal tdata  : std_logic_vector(7 downto 0);
    signal rdone  : std_logic;
    signal rdata  : std_logic_vector(7 downto 0);

  begin
    process -- write to uart
    begin
      -- wait reset procedure
      wait until rstn = '1'; wait for 2*period;
      loop
        wait for 10 ms;
        write_uart("[TEST]", tstart, tdata, tready);
        for i in 0 to 50 loop
          wait for 50 us;
          write_uart("testing redirect 0", tstart, tdata, tready);
        end loop;
      end loop;
      wait;
    end process;
    -- UART instance
    uart_u : entity work.uart
    port map (
      rstn_i     => rstn,
      clk_i      => clk,
      baud_div_i => x"01B2",
      parity_i   => '0',
      rtscts_i   => '0',
      tready_o   => tready,
      tstart_i   => tstart,
      tdata_i    => tdata,
      tdone_o    => open,
      rready_i   => '1',
      rdone_o    => rdone,
      rdata_o    => rdata,
      rerr_o     => open,
      uart_rx_i  => uart_host_tx_0_o,
      uart_tx_o  => uart_dut_rx_0_i,
      uart_cts_i => '0',
      uart_rts_o => open
    );
    -- print UART output to console
    process
      variable rchar        : character;
      variable rdata_buffer : string(1 to 1024);
      variable size         : integer range 0 to 1024;
    begin
      size := 0;
      loop
        wait until rising_edge(clk) and rdone = '1';
        rchar := character'val(to_integer(unsigned(rdata)));
        size := size + 1;
        rdata_buffer(size) := rchar;
        -- check if it is line break
        if rchar = lf or size = rdata_buffer'length then
          -- print line
          report lf & "[REDIR-0] " & rdata_buffer(1 to size-1);
          -- reset string size
          size := 0;
        end if;
      end loop;
    end process;
  end block;

  
  ----------------------------------------------------------------------------
  ----------------------- REDIRECT 1 SIMULATION BLOCK ------------------------
  redirect_1_b : block
    signal tstart : std_logic := '0';
    signal tready : std_logic;
    signal tdata  : std_logic_vector(7 downto 0);
    signal rdone  : std_logic;
    signal rdata  : std_logic_vector(7 downto 0);
  begin
    process -- write to uart
    begin
      -- wait reset procedure
      wait until rstn = '1'; wait for 2*period;
      loop
        wait for 20 ms;
        write_uart("testing redirect 1", tstart, tdata, tready);
      end loop;
      wait;
    end process;
    -- UART instance
    uart_u : entity work.uart
    port map (
      rstn_i     => rstn,
      clk_i      => clk,
      baud_div_i => x"01B2",
      parity_i   => '0',
      rtscts_i   => '0',
      tready_o   => tready,
      tstart_i   => tstart,
      tdata_i    => tdata,
      tdone_o    => open,
      rready_i   => '1',
      rdone_o    => rdone,
      rdata_o    => rdata,
      rerr_o     => open,
      uart_rx_i  => uart_host_tx_1_o,
      uart_tx_o  => uart_dut_rx_1_i,
      uart_cts_i => '0',
      uart_rts_o => open
    );
    -- print UART output to console
    process
      variable rchar        : character;
      variable rdata_buffer : string(1 to 1024);
      variable size         : integer range 0 to 1024;
    begin
      size := 0;
      loop
        wait until rising_edge(clk) and rdone = '1';
        rchar := character'val(to_integer(unsigned(rdata)));
        size := size + 1;
        rdata_buffer(size) := rchar;
        -- check if it is line break
        if rchar = lf or size = rdata_buffer'length then
          -- print line
          report lf & "[REDIR-1] " & rdata_buffer(1 to size-1);
          -- reset string size
          size := 0;
        end if;
      end loop;
    end process;
  end block;

  
  ----------------------------------------------------------------------------
  ------------------------- CURRENT SIMULATION BLOCK -------------------------
  current_b : block
    signal rdone  : std_logic;
    signal rdata  : std_logic_vector(7 downto 0);
  begin
    -- UART instance
    uart_u : entity work.uart
    port map (
      rstn_i     => rstn,
      clk_i      => clk,
      baud_div_i => x"01B2",
      parity_i   => '0',
      rtscts_i   => '0',
      tready_o   => open,
      tstart_i   => '0',
      tdata_i    => (others => '0'),
      tdone_o    => open,
      rready_i   => '1',
      rdone_o    => rdone,
      rdata_o    => rdata,
      rerr_o     => open,
      uart_rx_i  => uart_current_tx_o,
      uart_tx_o  => open,
      uart_cts_i => '0',
      uart_rts_o => open
    );
    -- print UART output to console
    process
      variable rchar        : character;
      variable rdata_buffer : string(1 to 1024);
      variable size         : integer range 0 to 1024;
    begin
      size := 0;
      loop
        wait until rising_edge(clk) and rdone = '1';
        rchar := character'val(to_integer(unsigned(rdata)));
        size := size + 1;
        rdata_buffer(size) := rchar;
        -- check if it is line break
        if rchar = lf or size = rdata_buffer'length then
          -- print line
          report lf & "[CURRENT] " & rdata_buffer(1 to size-1);
          -- reset string size
          size := 0;
        end if;
      end loop;
    end process;
  end block;

end architecture;
