library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Configuration register
-- Input Port register
--  Before a read, a write operation is sent with the command byte

-- I2C Address x20

-- Has 2 8 bit configuration register
-- At power on the IO bits are configured as inputs
-- Requires pull up or pull downs on IOs configured as inputs and undriven

-- Modes
--  Power on reset: reset contidion, register reset to default mode, I/O configured as inputs (high impedance)
--  Powered up: Ready to accept I2C requests and programming

-- Reading/writing from a register
--  Send device address
--  Send register pointer address
--  The address of the device is set to x20 and the last bit of the target address defines the operation, 1 to read and 0 to write
--  After address is acknowledge, the controller sends a command byte, the last 3 bits define which register we can access. See Table 7-3
--  Configuration Port 0 is set to 00000110 with command byte x06
--  Configuration Port 1 is set to 00000111 with command byte x07
--  Input Port 0 and Input Port 1 shows incoming logic levels of pins. Register 0 and 1
--  Output Port 0 and Input Port 1 shows outgoing logic levels of pins. Register 2 and 3
--  Polarity inversion registers. Allow polarity inversion of pins. Registers 4 and 5. A written 0 maintains the original Polarity
--  Configuration Registers. Register 6 and 7. If a bit in this register is set to 1 = pin is input, set to 0 = pin is output.

-- I/O
-- 1 = input
-- 0 = output
-- Register 6 should be set to, MSB to LSB - 00001000
-- P00 - SOM_JTAG_SEL    - Output       - 0
-- P01 - SOM_PWR_EN      - Output       - 0
-- P02 - SOM_NOSEQ       - Output       - 0
-- P03 - SOM_PGOOD       - Input        - 1
-- P04 - SOM_BOOTMODE    - Output       - 0
-- P05 - SOM_nRST        - Output       - 0
-- P06 - SOM_GPIO_0      - Input/Output - 0
-- P07 - SOM_GPIO_1      - Input/Output - 0
-- Register 7 should be set to, MSB to LSB - 10011100
-- P10 - SOM_GPIO_2      - Input/Output - 0
-- P11 - SETUP_PWR_EN    - Output       - 0
-- P12 - SETUP_WDT_WDO   - Input        - 1
-- P13 - SETUP_ID_LSB    - Input        - 1
-- P14 - SETUP_ID_MSB    - Input        - 1
-- P15 - SETUP_GPIO_TEST - Input/Output - 0
-- P16 - PCIE_GPIO       - Input/Output - 0
-- P17 - Pulldown        - Not used     - 1
 
entity i2c_gpio is
  port (
    -- Sync
    clk_i           : in std_logic;
    rstn_i          : in std_logic;
    -- Inputs
    gpio_setup_en_i : in std_logic; -- Enable write setup configuration
    gpio_read_en_i  : in std_logic; -- Enable read from GPIO
    gpio_write_en_i : in std_logic; -- Enable write to GPIO
    gpio_trist_i    : in std_logic_vector(15 downto 0);
    gpio_data_i     : in std_logic_vector(15 downto 0); -- Inputo to write to gpio
    -- Outputs
    gpio_done_o     : out std_logic;
    gpio_wreg_o     : out std_logic;
    gpio_data_o     : out std_logic_vector(15 downto 0);
    -- I2C Interface
    i2c_done_i          : in  std_logic;
    i2c_busy_i          : in  std_logic;
    i2c_write_o         : out std_logic;
    i2c_read_o          : out std_logic;
    i2c_rdata_i         : in  std_logic_vector(7 downto 0);
    i2c_wdata_o         : out std_logic_vector(7 downto 0)
  );
end entity;
architecture rtl of i2c_gpio is

  -- FSM States and signals
  signal state_r               : std_logic_vector(4 downto 0);
  signal next_w                : std_logic_vector(4 downto 0);

  constant IDLE                : std_logic_vector(4 downto 0) := "00000";
  -- FSM CFG
  constant CFG_WRITE_PTR1      : std_logic_vector(4 downto 0) := "00001";
  constant CFG_WRITE_BYTE1     : std_logic_vector(4 downto 0) := "00010";
  constant CFG_WAIT1           : std_logic_vector(4 downto 0) := "00011";
  constant CFG_WRITE_PTR2      : std_logic_vector(4 downto 0) := "00100";
  constant CFG_WRITE_BYTE2     : std_logic_vector(4 downto 0) := "00101";
  -- FSM WRITE
  constant GPIO_WRITE_PTR1     : std_logic_vector(4 downto 0) := "00110"; -- Device target address       - 8 bits = 7 bits + RW bit to 0 
  constant GPIO_WRITE_BYTE1    : std_logic_vector(4 downto 0) := "00111"; -- Write data byte to register - 8 bits
  constant GPIO_WRITE_WAIT     : std_logic_vector(4 downto 0) := "01000";
  constant GPIO_WRITE_BYTE2    : std_logic_vector(4 downto 0) := "01010"; -- Write data byte to register - 8 bits
  -- FSM READ
  constant GPIO_READ_PTR1      : std_logic_vector(4 downto 0) := "01011"; -- Device target address       - 8 bits = 7 bits + RW bit to 0
  constant GPIO_READ_BYTE1     : std_logic_vector(4 downto 0) := "01100"; -- Data byte from register     - 8 bits
  constant GPIO_READ_WAIT      : std_logic_vector(4 downto 0) := "01101";
  constant GPIO_READ_PTR2      : std_logic_vector(4 downto 0) := "01110"; -- Device target address       - 8 bits = 7 bits + RW bit to 0
  constant GPIO_READ_BYTE2     : std_logic_vector(4 downto 0) := "01111"; -- Data byte from register     - 8 bits
  constant GPIO_REG_WRITE      : std_logic_vector(4 downto 0) := "10000"; -- Output to register module
  -- FSM General purpose
  constant BUSY                : std_logic_vector(4 downto 0) := "10001"; 
  constant DONE                : std_logic_vector(4 downto 0) := "10010"; 

  -- Data registers
  signal gpio_read_r           : std_logic_vector(15 downto 0);

begin

  -- ============================== FSM ============================== 
  -- Current state FSM
  current_state_p : process (clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      state_r <= IDLE;
    elsif rising_edge(clk_i) then
      state_r <= next_w;
    end if;
  end process;

  -- FSM next state
  next_state_p : process (all)
  begin
    case state_r is
      when IDLE =>
      if gpio_setup_en_i = '1' then
        next_w <= CFG_WRITE_PTR1;
      elsif gpio_write_en_i = '1' then
        next_w <= GPIO_WRITE_PTR1;
      elsif gpio_read_en_i = '1' then
        next_w <= GPIO_READ_PTR1;
      else
        next_w <= IDLE;
      end if;

      -- Write config pointer address in register 6
      when CFG_WRITE_PTR1 =>
      if i2c_done_i = '1' then
        next_w <= CFG_WRITE_BYTE1;
      else
        next_w <= CFG_WRITE_PTR1;
      end if;
      -- Write the first byte for the config register 
      when CFG_WRITE_BYTE1 =>
      if i2c_done_i = '1' then
        next_w <= CFG_WAIT1;
      else
        next_w <= CFG_WRITE_BYTE1;
      end if;

      when CFG_WAIT1 =>
      if i2c_busy_i = '0' then
        next_w <= CFG_WRITE_PTR2;
      else
        next_w <= CFG_WAIT1;
      end if;

      when CFG_WRITE_PTR2 =>
      if i2c_done_i = '1' then
        next_w <= CFG_WRITE_BYTE2;
      else
        next_w <= CFG_WRITE_PTR2;
      end if;

      when CFG_WRITE_BYTE2 =>
      if i2c_done_i = '1' then
        next_w <= BUSY;
      else
        next_w <= CFG_WRITE_BYTE2;
      end if;

      -- Reading from GPIO
      when GPIO_READ_PTR1 =>
      if i2c_done_i = '1' then
        next_w <= GPIO_READ_BYTE1;
      else
        next_w <= GPIO_READ_PTR1;
      end if;

      when GPIO_READ_BYTE1 =>
      if i2c_done_i = '1' then
        next_w <= GPIO_READ_WAIT;
      else
        next_w <= GPIO_READ_BYTE1;
      end if;

      when GPIO_READ_WAIT =>
      if i2c_busy_i = '0' then
        next_w <= GPIO_READ_PTR2;
      else
        next_w <= GPIO_READ_WAIT;
      end if;

      when GPIO_READ_PTR2 =>
      if i2c_done_i = '1' then
        next_w <= GPIO_READ_BYTE2;
      else
        next_w <= GPIO_READ_PTR2;
      end if;     

      when GPIO_READ_BYTE2 =>
      if i2c_done_i = '1' then
        next_w <= GPIO_REG_WRITE;
      else
        next_w <= GPIO_READ_BYTE2;
      end if;

      when GPIO_REG_WRITE =>
        next_w <= BUSY;

      -- Writing
      when GPIO_WRITE_PTR1 =>
      if i2c_done_i = '1' then
        next_w <= GPIO_WRITE_BYTE1;
      else
        next_w <= GPIO_WRITE_PTR1;
      end if;

      when GPIO_WRITE_BYTE1 =>
      if i2c_done_i = '1' then
        next_w <= GPIO_WRITE_WAIT;
      else
        next_w <= GPIO_WRITE_BYTE1;
      end if;

      when GPIO_WRITE_WAIT =>
      if i2c_busy_i = '0' then
        next_w <= GPIO_WRITE_BYTE2;
      else
        next_w <= GPIO_WRITE_WAIT;
      end if;  

      when GPIO_WRITE_BYTE2 =>
      if i2c_done_i = '1' then
        next_w <= BUSY;
      else
        next_w <= GPIO_WRITE_BYTE2;
      end if;

      -- Busy
      when BUSY =>
      if i2c_busy_i = '0' then
        next_w <= DONE;
      else
        next_w <= BUSY;
      end if;

      -- Done
      when DONE =>
        next_w <= IDLE;


      when others =>
      next_w <= IDLE;
    end case;
    
  end process;

  -- Add assignments for i2c write enable
  i2c_write_o <= '1' when state_r = CFG_WRITE_PTR1      else -- CFG CONFIG
                 '1' when state_r = CFG_WRITE_BYTE1     else
                 '1' when state_r = CFG_WRITE_PTR2      else
                 '1' when state_r = CFG_WRITE_BYTE2     else
                 '1' when state_r = GPIO_WRITE_PTR1     else -- GPIO WRITE
                 '1' when state_r = GPIO_WRITE_BYTE1    else 
                 '1' when state_r = GPIO_WRITE_BYTE2    else 
                 '1' when state_r = GPIO_READ_PTR1      else -- GPIO READ
                 '1' when state_r = GPIO_READ_PTR2      else 
                 '0';

  -- Add assignments for i2c read enable
  i2c_read_o <= '1' when state_r = GPIO_READ_BYTE1    else
                '1' when state_r = GPIO_READ_BYTE2    else
                '0'; 

  -- Add assignment for i2c done
  gpio_done_o <= '1' when state_r = DONE else '0';

  i2c_wdata_o <= x"06"                     when state_r = CFG_WRITE_PTR1      else
                 gpio_trist_i(7 downto 0)  when state_r = CFG_WRITE_BYTE1     else
                 x"07"                     when state_r = CFG_WRITE_PTR2      else                      
                 gpio_trist_i(15 downto 8) when state_r = CFG_WRITE_BYTE2     else
                 x"02"                     when state_r = GPIO_WRITE_PTR1     else -- Write to Port 0
                 gpio_data_i(7  downto 0)  when state_r = GPIO_WRITE_BYTE1    else
                 gpio_data_i(15 downto 8)  when state_r = GPIO_WRITE_BYTE2    else
                 x"00"                     when state_r = GPIO_READ_PTR1      else
                 x"01"                     when state_r = GPIO_READ_PTR2      else
                 x"00";

  -- Create process to select the parts of the read data
  -- 16 bit transfered data must be selected in 2 parts
  process (clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      gpio_read_r  <= x"0000";
    elsif rising_edge(clk_i) then
      if i2c_done_i = '1' then
        if state_r = GPIO_READ_BYTE1 then
          gpio_read_r(7 downto 0)  <= i2c_rdata_i; -- Read 00 gpios
        elsif state_r = GPIO_READ_BYTE2 then
          gpio_read_r(15 downto 8) <= i2c_rdata_i; -- Read 10 gpios
        end if;
      end if;
    end if;
  end process;
  
  gpio_data_o <= gpio_read_r;
  gpio_wreg_o <= '1' when state_r = GPIO_REG_WRITE else '0';

end architecture;