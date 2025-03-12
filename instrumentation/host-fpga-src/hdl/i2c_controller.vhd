library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_controller is
  port (
    clk_i         : in std_logic;
    rstn_i        : in std_logic;
    -- setup
    i2c_baud_div_i : in std_logic_vector(15 downto 0);
    -- Outputs to i2c
    i2c_sda_io    : inout std_logic;
    i2c_scl_o     : out   std_logic;
    -- Outputs to registers
    temp_wen_o    : out std_logic; 
    temp_o        : out std_logic_vector(15 downto 0);
    gpio_wen_o    : out std_logic; 
    gpio_rdata_o  : out std_logic_vector(15 downto 0);
    gpio_trist_i  : in  std_logic_vector(15 downto 0);
    gpio_wdata_i  : in  std_logic_vector(15 downto 0);
    ina_wen_o     : out std_logic;
    ina_volts_o   : out std_logic_vector(15 downto 0);
    ina_currt_o   : out std_logic_vector(15 downto 0);
    ina_power_o   : out std_logic_vector(15 downto 0);
    -- output to reporter
    gpio_i2c_wr_o : out std_logic;
    gpio_i2c_rd_o : out std_logic
  );
end entity;

architecture rtl of i2c_controller is

  -- FSM
  constant IDLE                 : std_logic_vector(3 downto 0) := x"0";
  constant CFG_TEMP             : std_logic_vector(3 downto 0) := x"1";
  constant READ_TEMP            : std_logic_vector(3 downto 0) := x"2";
  constant CFG_GPIO             : std_logic_vector(3 downto 0) := x"3";
  constant WRITE_GPIO           : std_logic_vector(3 downto 0) := x"4";
  constant READ_GPIO            : std_logic_vector(3 downto 0) := x"5";
  constant CFG_INA              : std_logic_vector(3 downto 0) := x"6";
  constant READ_INA             : std_logic_vector(3 downto 0) := x"7";
  
   -- FSM Signals
  signal state_r : std_logic_vector(3 downto 0);
  signal next_w  : std_logic_vector(3 downto 0);

  -- I2C for TMP100
  signal temp_done_w            :std_logic;
  signal temp_en_w              :std_logic;
  signal temp_setup_w           :std_logic;

  signal i2c_tmp100_write_w : std_logic; 
  signal i2c_tmp100_read_w  : std_logic; 
  signal i2c_tmp100_done_w  : std_logic; 
  signal i2c_tmp100_busy_w  : std_logic; 
  signal i2c_tmp100_wdata_w : std_logic_vector(7 downto 0);  
  signal i2c_tmp100_rdata_w : std_logic_vector(7 downto 0);  

  -- I2C for GPIO
  signal gpio_done_w        :std_logic;
  signal gpio_wen_w         :std_logic;
  signal gpio_ren_w         :std_logic;
  signal gpio_setup_w       :std_logic;
  
  signal i2c_gpio_write_w   : std_logic; 
  signal i2c_gpio_read_w    : std_logic; 
  signal i2c_gpio_done_w    : std_logic; 
  signal i2c_gpio_busy_w    : std_logic; 
  signal i2c_gpio_wdata_w   : std_logic_vector(7 downto 0);  
  signal i2c_gpio_rdata_w   : std_logic_vector(7 downto 0);

  -- I2C for INA219
  signal ina_done_w         :std_logic;
  signal ina_en_w           :std_logic;
  signal ina_setup_w        :std_logic;

  signal i2c_ina_done_w     : std_logic;
  signal i2c_ina_busy_w     : std_logic;
  signal i2c_ina_write_w    : std_logic;
  signal i2c_ina_read_w     : std_logic;
  signal i2c_ina_rdata_w    : std_logic_vector(7 downto 0);
  signal i2c_ina_wdata_w    : std_logic_vector(7 downto 0);
 
  -- I2C Controller master
  signal i2c_sda_o_w        : std_logic;
  signal i2c_sdat_w         : std_logic;
  signal i2c_write_w        : std_logic; 
  signal i2c_read_w         : std_logic; 
  signal i2c_done_w         : std_logic; 
  signal i2c_busy_w         : std_logic; 
  signal i2c_ackn_w         : std_logic;
  signal i2c_addr_w         : std_logic_vector(6 downto 0);
  signal i2c_wdata_w        : std_logic_vector(7 downto 0);  
  signal i2c_rdata_w        : std_logic_vector(7 downto 0);
  
begin


  -- i2c instance
  i2c_u : entity work.i2c
  port map (
    rstn_i     => rstn_i,
    clk_i      => clk_i,
    baud_div_i => i2c_baud_div_i,
    write_i    => i2c_write_w,
    read_i     => i2c_read_w,
    ackn_o     => i2c_ackn_w,
    done_o     => i2c_done_w,
    busy_o     => i2c_busy_w,
    addr_i     => i2c_addr_w,
    wdata_i    => i2c_wdata_w,
    rdata_o    => i2c_rdata_w,
    i2c_sda_i  => i2c_sda_io,
    i2c_sda_o  => i2c_sda_o_w,
    i2c_sdat_o => i2c_sdat_w,
    i2c_scl_o  => i2c_scl_o 
  );
  i2c_sda_io <= 'Z' when i2c_sdat_w = '1' else i2c_sda_o_w;

  current_p : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      state_r <= IDLE;
    elsif rising_edge(clk_i) then
      state_r <= next_w;
    end if;
  end process;
  
  next_p : process(all)
  begin
    case state_r is

      -- Idle, default state
      when IDLE =>
          next_w <= CFG_TEMP;
      -- ================== CONFIG ==================
      -- Config TEMP100
      when CFG_TEMP =>
        if temp_done_w = '1' then
          next_w <= CFG_GPIO;
        else
          next_w <= CFG_TEMP;
        end if;
      -- Config GPIO
      when CFG_GPIO =>
        if gpio_done_w = '1' then
          next_w <= CFG_INA;
        else
          next_w <= CFG_GPIO;
        end if;
      -- Config INA
      when CFG_INA =>
        if ina_done_w = '1' then
          next_w <= READ_TEMP;
        else
          next_w <= CFG_INA;
        end if;

      -- ================== READ ==================
      -- Read TEMP100
      when READ_TEMP =>
        if temp_done_w = '1' then
          next_w <= READ_GPIO;
        else
          next_w <= READ_TEMP;
        end if;

      -- GPIO
      when READ_GPIO =>
        if gpio_done_w = '1' then
          next_w <= WRITE_GPIO;
        else
          next_w <= READ_GPIO;
        end if;

      when WRITE_GPIO =>
        if gpio_done_w = '1' then
          next_w <= READ_INA;
        else
          next_w <= WRITE_GPIO;
        end if;

      -- Read INA
      when READ_INA =>
        if ina_done_w = '1' then
          next_w <= CFG_TEMP;
        else
          next_w <= READ_INA;
        end if;     

      when others => 
          next_w <= IDLE;

    end case;
  end process;

  temp_en_w     <= '1' when state_r = READ_TEMP  else '0';
  temp_setup_w  <= '1' when state_r = CFG_TEMP   else '0';
  gpio_setup_w  <= '1' when state_r = CFG_GPIO   else '0';
  gpio_wen_w    <= '1' when state_r = WRITE_GPIO else '0';
  gpio_ren_w    <= '1' when state_r = READ_GPIO  else '0';
  ina_setup_w   <= '1' when state_r = CFG_INA    else '0';
  ina_en_w      <= '1' when state_r = READ_INA   else '0';
  
  -- Read Temp
  i2c_tmp100_u : entity work.i2c_tmp100
  port map (
    clk_i            => clk_i,
    rstn_i           => rstn_i,
    read_temp_en_i   => temp_en_w,
    write_setup_en_i => temp_setup_w,
    done_o           => temp_done_w,
    temperature_o    => temp_o,
    i2c_done_i       => i2c_tmp100_done_w,
    i2c_busy_i       => i2c_tmp100_busy_w,
    i2c_write_o      => i2c_tmp100_write_w,
    i2c_read_o       => i2c_tmp100_read_w,
    i2c_rdata_i      => i2c_tmp100_rdata_w,
    i2c_wdata_o      => i2c_tmp100_wdata_w
  );
  temp_wen_o <= temp_done_w;

  -- GPIO
  i2c_gpio_u : entity work.i2c_gpio
  port map (
    clk_i           => clk_i,
    rstn_i          => rstn_i,
    gpio_setup_en_i => gpio_setup_w,
    gpio_read_en_i  => gpio_ren_w,
    gpio_write_en_i => gpio_wen_w,
    gpio_trist_i    => gpio_trist_i,
    gpio_data_i     => gpio_wdata_i,
    gpio_done_o     => gpio_done_w,
    gpio_wreg_o     => gpio_wen_o,
    gpio_data_o     => gpio_rdata_o,
    i2c_done_i      => i2c_gpio_done_w,
    i2c_busy_i      => i2c_gpio_busy_w,
    i2c_write_o     => i2c_gpio_write_w,
    i2c_read_o      => i2c_gpio_read_w,
    i2c_rdata_i     => i2c_gpio_rdata_w,
    i2c_wdata_o     => i2c_gpio_wdata_w
  );

  -- INA
  i2c_ina_u : entity work.i2c_ina
  port map (
    clk_i            => clk_i,
    rstn_i           => rstn_i,
    read_curr_en_i   => ina_en_w,
    write_setup_en_i => ina_setup_w,
    ina_done_o       => ina_done_w,
    volt_data_o      => ina_volts_o,
    curr_data_o      => ina_currt_o,
    powr_data_o      => ina_power_o,
    ina_wreg_o       => ina_wen_o,
    i2c_done_i       => i2c_ina_done_w,
    i2c_busy_i       => i2c_ina_busy_w,
    i2c_write_o      => i2c_ina_write_w,
    i2c_read_o       => i2c_ina_read_w,
    i2c_rdata_i      => i2c_ina_rdata_w,
    i2c_wdata_o      => i2c_ina_wdata_w
  );

  -- I2C Control Signals Mux
  i2c_write_w <= i2c_tmp100_write_w when state_r = CFG_TEMP or state_r = READ_TEMP else 
                 i2c_gpio_write_w   when state_r = CFG_GPIO or state_r = READ_GPIO or state_r = WRITE_GPIO else       
                 i2c_ina_write_w    when state_r = CFG_INA  or state_r = READ_INA  else
                 '0';
  i2c_read_w  <= i2c_tmp100_read_w when state_r = CFG_TEMP or state_r = READ_TEMP else 
                 i2c_gpio_read_w   when state_r = CFG_GPIO or state_r = READ_GPIO or state_r = WRITE_GPIO else       
                 i2c_ina_read_w    when state_r = CFG_INA  or state_r = READ_INA  else
                '0';
  i2c_addr_w  <= "1001000" when state_r = CFG_TEMP or state_r = READ_TEMP else 
                 "0100000" when state_r = CFG_GPIO or state_r = READ_GPIO or state_r = WRITE_GPIO else
                 "1000000" when state_r = CFG_INA  or state_r = READ_INA  else        
                 (others => '0'); 
  i2c_wdata_w <= i2c_tmp100_wdata_w when state_r = CFG_TEMP or state_r = READ_TEMP else 
                 i2c_gpio_wdata_w   when state_r = CFG_GPIO or state_r = READ_GPIO or state_r = WRITE_GPIO else
                 i2c_ina_wdata_w    when state_r = CFG_INA  or state_r = READ_INA  else                    
                 (others => '0'); 
  -- TMP100
  i2c_tmp100_rdata_w <= i2c_rdata_w;
  i2c_tmp100_done_w  <= i2c_done_w; 
  i2c_tmp100_busy_w  <= i2c_busy_w;

  -- GPIO
  i2c_gpio_rdata_w <= i2c_rdata_w;
  i2c_gpio_done_w  <= i2c_done_w; 
  i2c_gpio_busy_w  <= i2c_busy_w;

  -- INA
  i2c_ina_rdata_w  <= i2c_rdata_w;
  i2c_ina_done_w   <= i2c_done_w ;
  i2c_ina_busy_w   <= i2c_busy_w ;

  -- extra gpio signals for loggin gpio changes
  gpio_i2c_wr_o <= i2c_done_w and gpio_wen_w;
  gpio_i2c_rd_o <= i2c_done_w and gpio_ren_w;

end architecture;