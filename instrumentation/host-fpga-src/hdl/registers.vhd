library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity registers is 
  generic (
    VERSION : std_logic_vector(15 downto 0)
  );
  port (
    -- Inputs
    rstn_i  : in std_logic;
    clk_i   : in std_logic;   
    -- From CMD interface
    wr_en_i : in  std_logic;
    rd_en_i : in  std_logic;
    addr_i  : in  std_logic_vector(15 downto 0);
    wdata_i : in  std_logic_vector(15 downto 0);
    rdata_o : out std_logic_vector(15 downto 0);

    -- setup
    system_i2c_div_o       : out std_logic_vector(15 downto 0);
    system_baud_rate_o     : out std_logic_vector(15 downto 0);
    sut_baud_rate_0_o      : out std_logic_vector(15 downto 0);
    sut_baud_rate_1_o      : out std_logic_vector(15 downto 0);
    current_sample_rate_o  : out std_logic_vector(15 downto 0);
    current_threshold_o    : out std_logic_vector(15 downto 0);
    overcurrent_on_time_o  : out std_logic_vector(15 downto 0);
    overcurrent_off_time_o : out std_logic_vector(15 downto 0);
    
    -- internal
    timestamp_i : in std_logic_vector(31 downto 0);
    -- i2c peripherals
    gpio_trist_o : out std_logic_vector(15 downto 0);
    gpio_wdata_o : out std_logic_vector(15 downto 0);

    -- Inputs and enable signals
    temp_wen_i      : in std_logic;
    temp_i          : in std_logic_vector(15 downto 0);
    gpio_wen_i      : in std_logic;
    gpio_i          : in std_logic_vector(15 downto 0);
    ina_wen_i       : in std_logic;
    volts_i         : in std_logic_vector(15 downto 0);
    currt_i         : in std_logic_vector(15 downto 0);
    power_i         : in std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of registers is
  ------ Registers addresses ------
  -- setup
  constant ADDR_VERSION               : std_logic_vector (15 downto 0) := x"0000"; -- Read only
  constant ADDR_BOARD_NAME            : std_logic_vector (15 downto 0) := x"0001"; -- Read/Write
  constant ADDR_SYSTEM_I2C_DIV        : std_logic_vector (15 downto 0) := x"0002"; -- Read/Write
  constant ADDR_SYSTEM_UART_BAUD_RATE : std_logic_vector (15 downto 0) := x"0003"; -- Read/Write
  constant ADDR_SUT_UART_BAUD_RATE0   : std_logic_vector (15 downto 0) := x"0004"; -- Read/Write
  constant ADDR_SUT_UART_BAUD_RATE1   : std_logic_vector (15 downto 0) := x"0005"; -- Read/Write
  constant ADDR_CURRENT_SAMPLERATE    : std_logic_vector (15 downto 0) := x"0006"; -- Read/Write
  constant ADDR_CURRENT_THRESHOLD     : std_logic_vector (15 downto 0) := x"0007"; -- Read/Write - Current threshold
  constant ADDR_OVERCURRENT_ON_TIME   : std_logic_vector (15 downto 0) := x"0008"; -- Read/Write
  constant ADDR_OVERCURRENT_OFF_TIME  : std_logic_vector (15 downto 0) := x"0009"; -- Read/Write
  -- internal
  constant ADDR_TIMESTAMP_H           : std_logic_vector (15 downto 0) := x"0100"; -- Read only - Timestamp
  constant ADDR_TIMESTAMP_L           : std_logic_vector (15 downto 0) := x"0101"; -- Read only - Timestamp
  -- i2c peripherals
  constant ADDR_GPIO_TRI_ST           : std_logic_vector (15 downto 0) := x"0200"; -- To define which GPIO are Input or Output
  constant ADDR_GPIO_READ             : std_logic_vector (15 downto 0) := x"0201"; -- Read only
  constant ADDR_GPIO_WRITE            : std_logic_vector (15 downto 0) := x"0202"; -- Read/Write
  constant ADDR_VOLTAGE               : std_logic_vector (15 downto 0) := x"0203"; -- Read - Voltage.
  constant ADDR_CURRENT               : std_logic_vector (15 downto 0) := x"0204"; -- Read - Current.
  constant ADDR_POWER                 : std_logic_vector (15 downto 0) := x"0205"; -- Read - Power.
  constant ADDR_TEMPERATURE           : std_logic_vector (15 downto 0) := x"0206"; -- Read only

  -- default values
  constant DEFAULT_BOARD_NAME           : std_logic_vector(15 downto 0) := x"CAFE";
  constant DEFAULT_SYSTEM_I2C_DIV       : std_logic_vector(15 downto 0) := x"01F4"; -- 100 kHz @ 50 MHz
  constant DEFAULT_SYSTEM_BAUDRATE      : std_logic_vector(15 downto 0) := x"01b2"; -- 115200 @ 50 MHz
  constant DEFAULT_SUT_UART_BAUDRATE    : std_logic_vector(15 downto 0) := x"01b2"; -- 115200 @ 50 MHz
  constant DEFAULT_CURRENT_SAMPLERATE   : std_logic_vector(15 downto 0) := x"017d"; -- 1/500 ms @ 50 MHz
  constant DEFAULT_CURRENT_THRESHOLD    : std_logic_vector(15 downto 0) := x"7FFF"; -- 2A
  constant DEFAULT_OVERCURRENT_ON_TIME  : std_logic_vector(15 downto 0) := x"0026"; -- 50 ms @ 50 MHz
  constant DEFAULT_OVERCURRENT_OFF_TIME : std_logic_vector(15 downto 0) := x"0099"; -- 200 ms @ 50 MHz

  constant DEFAULT_GPIO_TRISTATE : std_logic_vector(15 downto 0) := x"FFFF"; -- high impedance
  constant DEFAULT_GPIO_WRITE    : std_logic_vector(15 downto 0) := x"0000";

  -- Signals for registers
  signal version_w              : std_logic_vector(15 downto 0);
  signal board_name_r           : std_logic_vector(15 downto 0);
  signal system_i2c_div_r       : std_logic_vector(15 downto 0);
  signal system_baud_rate_r     : std_logic_vector(15 downto 0);
  signal sut_baud_rate_0_r      : std_logic_vector(15 downto 0);
  signal sut_baud_rate_1_r      : std_logic_vector(15 downto 0);
  signal current_sample_rate_r  : std_logic_vector(15 downto 0);
  signal current_threshold_r    : std_logic_vector(15 downto 0);
  signal overcurrent_on_time_r  : std_logic_vector(15 downto 0);
  signal overcurrent_off_time_r : std_logic_vector(15 downto 0);
  -- i2c peripherals
  signal gpio_tri_st_r          : std_logic_vector(15 downto 0);
  signal gpio_read_r            : std_logic_vector(15 downto 0);
  signal gpio_write_r           : std_logic_vector(15 downto 0);
  signal temperature_r          : std_logic_vector(15 downto 0);
  signal current_r              : std_logic_vector(15 downto 0);
  signal voltage_r              : std_logic_vector(15 downto 0);
  signal power_r                : std_logic_vector(15 downto 0);

begin

  -- Set rdata
  rdata_o <= VERSION                   when addr_i = ADDR_VERSION               else
             board_name_r              when addr_i = ADDR_BOARD_NAME            else
             system_i2c_div_r          when addr_i = ADDR_SYSTEM_I2C_DIV        else
             system_baud_rate_r        when addr_i = ADDR_SYSTEM_UART_BAUD_RATE else
             sut_baud_rate_0_r         when addr_i = ADDR_SUT_UART_BAUD_RATE0   else
             sut_baud_rate_1_r         when addr_i = ADDR_SUT_UART_BAUD_RATE1   else
             current_sample_rate_r     when addr_i = ADDR_CURRENT_SAMPLERATE    else
             current_threshold_r       when addr_i = ADDR_CURRENT_THRESHOLD     else
             overcurrent_on_time_r     when addr_i = ADDR_OVERCURRENT_ON_TIME   else
             overcurrent_off_time_r    when addr_i = ADDR_OVERCURRENT_OFF_TIME  else
             -- internal
             timestamp_i(31 downto 16) when addr_i = ADDR_TIMESTAMP_H else
             timestamp_i(15  downto 0) when addr_i = ADDR_TIMESTAMP_L else
             -- i2c peripherals
             gpio_tri_st_r             when addr_i = ADDR_GPIO_TRI_ST else
             gpio_read_r               when addr_i = ADDR_GPIO_READ   else
             gpio_write_r              when addr_i = ADDR_GPIO_WRITE  else
             voltage_r                 when addr_i = ADDR_VOLTAGE     else
             current_r                 when addr_i = ADDR_CURRENT     else
             power_r                   when addr_i = ADDR_POWER       else
             temperature_r             when addr_i = ADDR_TEMPERATURE else 
             x"dead";

  --Board name
  process (clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      board_name_r           <= DEFAULT_BOARD_NAME;
      system_i2c_div_r       <= DEFAULT_SYSTEM_I2C_DIV;
      system_baud_rate_r     <= DEFAULT_SYSTEM_BAUDRATE;
      sut_baud_rate_0_r      <= DEFAULT_SUT_UART_BAUDRATE;
      sut_baud_rate_1_r      <= DEFAULT_SUT_UART_BAUDRATE;
      current_sample_rate_r  <= DEFAULT_CURRENT_SAMPLERATE;
      current_threshold_r    <= DEFAULT_CURRENT_THRESHOLD;
      overcurrent_on_time_r  <= DEFAULT_OVERCURRENT_ON_TIME;
      overcurrent_off_time_r <= DEFAULT_OVERCURRENT_OFF_TIME;

    elsif rising_edge(clk_i) then
      if wr_en_i = '1' then

        if addr_i = ADDR_BOARD_NAME then
          board_name_r <= wdata_i;

        elsif addr_i = ADDR_SYSTEM_I2C_DIV then
          system_i2c_div_r <= wdata_i;

        elsif addr_i = ADDR_SYSTEM_UART_BAUD_RATE then
          system_baud_rate_r <= wdata_i;

        elsif addr_i = ADDR_SUT_UART_BAUD_RATE0 then
          sut_baud_rate_0_r <= wdata_i;

        elsif addr_i = ADDR_SUT_UART_BAUD_RATE1 then
          sut_baud_rate_1_r <= wdata_i;

        elsif addr_i = ADDR_CURRENT_SAMPLERATE then
          current_sample_rate_r <= wdata_i;

        elsif addr_i = ADDR_CURRENT_THRESHOLD then
          current_threshold_r <= wdata_i;

        elsif addr_i = ADDR_OVERCURRENT_ON_TIME then
          overcurrent_on_time_r <= wdata_i;

        elsif addr_i = ADDR_OVERCURRENT_OFF_TIME then
          overcurrent_off_time_r <= wdata_i;

        end if;
      end if;
    end if;
  end process;
  system_i2c_div_o       <= system_i2c_div_r;
  system_baud_rate_o     <= system_baud_rate_r;
  sut_baud_rate_0_o      <= sut_baud_rate_0_r;
  sut_baud_rate_1_o      <= sut_baud_rate_1_r;
  current_sample_rate_o  <= current_sample_rate_r;
  current_threshold_o    <= current_threshold_r;
  overcurrent_on_time_o  <= overcurrent_on_time_r;
  overcurrent_off_time_o <= overcurrent_off_time_r;

  -- GPIO
  process (clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      gpio_tri_st_r <= DEFAULT_GPIO_TRISTATE;
      gpio_write_r  <= DEFAULT_GPIO_WRITE;
      gpio_read_r   <= (others => '0'); 
    elsif rising_edge(clk_i) then
      -- tri-state
      if wr_en_i = '1' and addr_i = ADDR_GPIO_TRI_ST then
        gpio_tri_st_r <= wdata_i;
      end if;
      -- read interface
      if wr_en_i = '1' and addr_i = ADDR_GPIO_READ then
        gpio_read_r <= wdata_i;
      elsif gpio_wen_i = '1' then
        gpio_read_r <= gpio_i;
      end if;
      -- write interface
      if wr_en_i = '1' and addr_i = ADDR_GPIO_WRITE then
        gpio_write_r <= wdata_i;
      end if;
    end if;
  end process;
  gpio_trist_o <= gpio_tri_st_r;
  gpio_wdata_o <= gpio_write_r;
  
  -- Temperature
  process (clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      temperature_r <= (others => '0'); 
    elsif rising_edge(clk_i) then
      if wr_en_i = '1' and addr_i = ADDR_TEMPERATURE then
        temperature_r <= wdata_i;
      elsif temp_wen_i = '1' then
        temperature_r <= temp_i; 
      end if;
    end if;
  end process;

  -- INA: Voltage, Current and Power values
  process (clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      voltage_r <= (others => '0');
      current_r <= (others => '0');
      power_r   <= (others => '0');
    elsif rising_edge(clk_i) then
      if ina_wen_i = '1' then
        voltage_r <= volts_i;
        current_r <= currt_i;
        power_r   <= power_i;
      end if;
    end if;
  end process;


end architecture;
