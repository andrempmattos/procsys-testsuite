library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
  port (
    rstn_i            : in  std_logic;
    clk_i             : in  std_logic;

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

    -- I2C interface w testbench
    i2c_sda_io : inout std_logic;
    i2c_scl_o  : out   std_logic

  );
end entity;

architecture arch of top is
  -- =============== CONSTANTS ===============
  -- Registers Constants
  constant VERSION          : std_logic_vector(15 downto 0) := x"0003"; -- Goes to generic on registers.vhd
  constant T2H_FIFO_SIZE    : integer := 512;
  constant H2T_FIFO_SIZE    : integer := 8;
  constant REPORT_FIFO_SIZE : integer := 32;

  -- =============== SIGNALS ===============
  -- === Registers signals ===
  signal cmd_wr_en_w : std_logic;
  signal cmd_rd_en_w : std_logic;
  signal cmd_addr_w  : std_logic_vector(15 downto 0);
  signal cmd_wdata_w : std_logic_vector(15 downto 0);
  signal cmd_rdata_w : std_logic_vector(15 downto 0);

  -- setup
  signal setup_system_i2c_div_w        : std_logic_vector(15 downto 0);
  signal setup_system_baud_rate_w      : std_logic_vector(15 downto 0);
  signal setup_sut_baud_rate_0_w       : std_logic_vector(15 downto 0);
  signal setup_sut_baud_rate_1_w       : std_logic_vector(15 downto 0);
  signal setup_current_sample_rate_w   : std_logic_vector(15 downto 0);
  signal setup_current_threshold_w     : std_logic_vector(15 downto 0);
  signal setup_overcurrent_on_time_w  : std_logic_vector(15 downto 0);
  signal setup_overcurrent_off_time_w : std_logic_vector(15 downto 0);

  -- Timestamp
  signal timestamp_w   : std_logic_vector(31 downto 0);

   -- INA 219 signals
   signal ina_wen_w    : std_logic;
   signal ina_volts_w  : std_logic_vector(15 downto 0);
   signal ina_currt_w  : std_logic_vector(15 downto 0);
   signal ina_power_w  : std_logic_vector(15 downto 0);

  -- TMP100 signals  
  signal temp_wen_w : std_logic;
  signal temp_w     : std_logic_vector(15 downto 0);

  -- GPIO signals  
  signal gpio_wen_w   : std_logic;
  signal gpio_rdata_w : std_logic_vector(15 downto 0);   
  signal gpio_trist_w : std_logic_vector(15 downto 0);
  signal gpio_wdata_w : std_logic_vector(15 downto 0);
  signal ovc_gpio_wdata_w : std_logic_vector(15 downto 0);

  -- extra GPIO report signals from i2c controller
  signal i2c_ctl_gpio_i2c_wr_w : std_logic;
  signal i2c_ctl_gpio_i2c_rd_w : std_logic;

  -- controller signals
  signal overcurrent_w   : std_logic;

begin

  timestamp_u : entity work.timestamp
  port map (
    clk_i          => clk_i,
    rstn_i         => rstn_i,
    timestamp_ms_o => timestamp_w
  );

  -- Add redirect buffer to test with SMF2000 and FTDI
  -- UART 0
  redirect_buffer_uart0_u : entity work.redirect_buffer
  generic map (
    T2H_FIFO_SIZE => T2H_FIFO_SIZE,
    H2T_FIFO_SIZE => H2T_FIFO_SIZE
  )
  port map (
    clk_i            => clk_i,
    rstn_i           => rstn_i,
    rx_sut_i         => uart_dut_rx_0_i,
    rx_host_i        => uart_host_rx_0_i,
    host_baud_rate_i => setup_system_baud_rate_w,
    sut_baud_rate_i  => setup_sut_baud_rate_0_w,
    timestamp_i      => timestamp_w,
    tx_sut_o         => uart_dut_tx_0_o,
    tx_host_o        => uart_host_tx_0_o
  );

  -- Add redirect buffer to test with SMF2000 and FTDI
  -- UART 1
  redirect_buffer_uart1_u : entity work.redirect_buffer
  generic map (
    T2H_FIFO_SIZE => T2H_FIFO_SIZE,
    H2T_FIFO_SIZE => H2T_FIFO_SIZE
  )
  port map (
    clk_i            => clk_i,
    rstn_i           => rstn_i,
    rx_sut_i         => uart_dut_rx_1_i,
    rx_host_i        => uart_host_rx_1_i,
    host_baud_rate_i => setup_system_baud_rate_w,
    sut_baud_rate_i  => setup_sut_baud_rate_1_w,
    timestamp_i      => timestamp_w,
    tx_sut_o         => uart_dut_tx_1_o,
    tx_host_o        => uart_host_tx_1_o
  );

  -- Current UART
  -- Add redirect buffer to test with SMF2000 and FTDI
  -- Will add two redirect buffers, one for each UART channel
  current_report_u : entity work.current_report
  generic map (
    REPORT_FIFO_SIZE => REPORT_FIFO_SIZE
  )
  port map (
    clk_i  => clk_i,
    rstn_i => rstn_i,
    -- config
    baud_rate_i   => setup_system_baud_rate_w,
    sample_rate_i => setup_current_sample_rate_w,
    curr_th_i     => setup_current_threshold_w,
    -- report
    timestamp_i   => timestamp_w,
    -- ina report
    ina_wen_i     => ina_wen_w,
    curr_rdata_i  => ina_currt_w,
    -- gpio report
    gpio_i2c_wr_i    => i2c_ctl_gpio_i2c_wr_w,
    gpio_i2c_rd_i    => i2c_ctl_gpio_i2c_rd_w,
    gpio_i2c_wdata_i => ovc_gpio_wdata_w,
    gpio_i2c_rdata_i => gpio_rdata_w,
    -- host uart
    rx_host_i => uart_current_rx_i,
    tx_host_o => uart_current_tx_o,
    -- overcurrent
    overcurrent_o => overcurrent_w
  );

  overcurrent_handler_u : entity work.overcurrent_handler
  port map (
    rstn_i          => rstn_i,
    clk_i           => clk_i,
    on_time_i       => setup_overcurrent_on_time_w,
    off_time_i      => setup_overcurrent_off_time_w,
    overcurrent_i   => overcurrent_w,
    gpio_wdata_i    => gpio_wdata_w,
    gpio_wdata_o    => ovc_gpio_wdata_w
  );
  
  cmd_u : entity work.cmd
  port map (
    rstn_i  => rstn_i,
    clk_i   => clk_i,
    tx_o    => uart_cmd_tx_o,
    rx_i    => uart_cmd_rx_i,
    wr_en_o => cmd_wr_en_w,
    rd_en_o => cmd_rd_en_w,
    addr_o  => cmd_addr_w,
    wdata_o => cmd_wdata_w,
    rdata_i => cmd_rdata_w
  );

  -- Register instance
  registers_u : entity work.registers
  generic map (
    VERSION => VERSION
  )
  port map (
    rstn_i        => rstn_i,
    clk_i         => clk_i,
    -- CMD interface
    wr_en_i       => cmd_wr_en_w,
    rd_en_i       => cmd_rd_en_w,
    addr_i        => cmd_addr_w,
    wdata_i       => cmd_wdata_w,
    rdata_o       => cmd_rdata_w,

    -- setup
    system_i2c_div_o       => setup_system_i2c_div_w,
    system_baud_rate_o     => setup_system_baud_rate_w,
    sut_baud_rate_0_o      => setup_sut_baud_rate_0_w,
    sut_baud_rate_1_o      => setup_sut_baud_rate_1_w,
    current_sample_rate_o  => setup_current_sample_rate_w,
    current_threshold_o    => setup_current_threshold_w,
    overcurrent_on_time_o  => setup_overcurrent_on_time_w,
    overcurrent_off_time_o => setup_overcurrent_off_time_w,

    -- internal
    timestamp_i   => timestamp_w,

    -- temperature peripheral
    temp_wen_i    => temp_wen_w,
    temp_i        => temp_w,

    -- gpio peripheral
    gpio_wen_i      => gpio_wen_w,
    gpio_i          => gpio_rdata_w,
    gpio_trist_o    => gpio_trist_w,
    gpio_wdata_o    => gpio_wdata_w, -- Direction connection to the gpio write register

    -- ina peripheral
    ina_wen_i     => ina_wen_w,
    volts_i       => ina_volts_w,
    currt_i       => ina_currt_w,
    power_i       => ina_power_w
  );

  i2c_controller_u : entity work.i2c_controller
  port map (
    clk_i        => clk_i,
    rstn_i       => rstn_i,
    -- i2c interface
    i2c_sda_io   => i2c_sda_io,
    i2c_scl_o    => i2c_scl_o,
    -- setup
    i2c_baud_div_i => setup_system_i2c_div_w,
    -- peripherals
    temp_wen_o   => temp_wen_w,
    temp_o       => temp_w,
    gpio_wen_o   => gpio_wen_w,
    gpio_rdata_o => gpio_rdata_w,
    gpio_trist_i => gpio_trist_w,
    gpio_wdata_i => ovc_gpio_wdata_w,
    ina_wen_o    => ina_wen_w,
    ina_volts_o  => ina_volts_w,
    ina_currt_o  => ina_currt_w,
    ina_power_o  => ina_power_w,
    -- extra report signals
    gpio_i2c_wr_o => i2c_ctl_gpio_i2c_wr_w,
    gpio_i2c_rd_o => i2c_ctl_gpio_i2c_rd_w
  );
  
end architecture;
