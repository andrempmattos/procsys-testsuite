library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_smf2000 is
  port (
    dev_rstn_i : in std_logic;
    clk12_i    : in std_logic;

    -- CMD Interface
    uart_cmd_tx_o     : out std_logic;
    uart_cmd_rx_i     : in  std_logic;

    -- UART 0
    -- From FTDI to FPGA
    uart_host_tx_0_o  : out std_logic;
    uart_host_rx_0_i  : in  std_logic;
    -- From FPGA to ICs
    uart_dut_tx_0_o   : out std_logic;
    uart_dut_rx_0_i   : in  std_logic;
    -- UART 1
    -- From FTDI to FPGA
    uart_host_tx_1_o  : out std_logic;
    uart_host_rx_1_i  : in  std_logic;
    -- From FPGA to ICs
    uart_dut_tx_1_o   : out std_logic;
    uart_dut_rx_1_i   : in  std_logic;

    -- Current UART 
    uart_current_tx_o : out std_logic;
    uart_current_rx_i : in  std_logic;

    -- GPIO
    -- user_btn_i : in    std_logic
    -- leds_o     : out   std_logic_vector(7 downto 0)

    -- I2C TESTING
    i2c_scl_o  : out std_logic;
    i2c_sda_io : inout std_logic

  );
end entity;

architecture arch of top_smf2000 is

  -- LIBERO IPs
  component SYSRESET
  port(
    DEVRST_N         : in  std_logic;
    POWER_ON_RESET_N : out std_logic
  );
  end component;
  component OSC_C0
  port(
    RCOSC_25_50MHZ_O2F : out std_logic
  );
  end component;
  component FCCC_C0
  port(
    CLK0 : in  std_logic;
    GL0  : out std_logic;
    LOCK : out std_logic
  );
  end component;

  -- SYSRESET
  signal poweron_rstn_w : std_logic;
  -- OSC_C0
  signal mss_osc_w : std_logic;
  -- FCC_C0
  signal fccc_clk_w  : std_logic;
  signal fccc_lock_w : std_logic;

  -- I2C
  signal i2c_sda_o_w : std_logic;
  signal i2c_sdat_w  : std_logic;

begin

  sysreset_u : SYSRESET
  port map (
    DEVRST_N         => dev_rstn_i,
    POWER_ON_RESET_N => poweron_rstn_w
  );

  osc_c0_u : OSC_C0
  port map (
    RCOSC_25_50MHZ_O2F => mss_osc_w
  );

  fccc_u : FCCC_C0
  port map (
    CLK0 => clk12_i,
    GL0  => fccc_clk_w,
    LOCK => fccc_lock_w
  );

  -- PROJECT TOP LEVEL
  top_u : entity work.top
  port map (
    rstn_i    => poweron_rstn_w,
    clk_i     => fccc_clk_w,
    -- CMD Interface
    uart_cmd_tx_o => uart_cmd_tx_o,
    uart_cmd_rx_i => uart_cmd_rx_i,
    -- UART 0 
    -- From FTDI to FPGA
    uart_host_tx_0_o => uart_host_tx_0_o,
    uart_host_rx_0_i => uart_host_rx_0_i,
    -- From FPGA to IC
    uart_dut_tx_0_o  => uart_dut_tx_0_o,
    uart_dut_rx_0_i  => uart_dut_rx_0_i,

    -- UART 1 
    -- From FTDI to FPGA
    uart_host_tx_1_o => uart_host_tx_1_o,
    uart_host_rx_1_i => uart_host_rx_1_i,
    -- From FPGA to IC
    uart_dut_tx_1_o  => uart_dut_tx_1_o,
    uart_dut_rx_1_i  => uart_dut_rx_1_i,

    -- Current UART
    uart_current_tx_o => uart_current_tx_o, 
    uart_current_rx_i => uart_current_rx_i,
    -- I2C
    i2c_sda_io => i2c_sda_io,
    i2c_scl_o  => i2c_scl_o

  );
  
end architecture;
