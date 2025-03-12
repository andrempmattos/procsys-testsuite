library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- I2C Address x40

-- Configuration operations
--  Normal operation is MODE register = 111
--  There is a bus voltage averaging register, configuration register BADC bits
--  Filtering option for current measurement
--  Programming: Resolution of the current register x04, Calibration and Power register
--  By default: no programming is required if we only want the 12 bit resolution, 320 mV
-- Read operations
--  Read current every ???

entity i2c_ina is
  port (
    -- Sync
    clk_i            : in std_logic;
    rstn_i           : in std_logic;
    -- Inputs
    read_curr_en_i   : in std_logic;
    write_setup_en_i : in std_logic;
    -- Outputs
    ina_done_o           : out std_logic;
    volt_data_o      : out std_logic_vector(15 downto 0); -- Will read bus voltage register, address x02
    curr_data_o      : out std_logic_vector(15 downto 0);
    powr_data_o      : out std_logic_vector(15 downto 0);
    ina_wreg_o       : out std_logic;
    -- I2C Interface
    i2c_done_i       : in  std_logic;
    i2c_busy_i       : in  std_logic;
    i2c_write_o      : out std_logic;
    i2c_read_o       : out std_logic;
    i2c_rdata_i      : in  std_logic_vector(7 downto 0);
    i2c_wdata_o      : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of i2c_ina is

  -- FSM States
  constant IDLE                : std_logic_vector(4 downto 0) := "00000";
  constant CFG_WRITE_PTR       : std_logic_vector(4 downto 0) := "00001"; -- Pointer address x00 - R/W
  constant CFG_WRITE_MSB       : std_logic_vector(4 downto 0) := "00010";
  constant CFG_WRITE_WAIT1     : std_logic_vector(4 downto 0) := "00011";
  constant CFG_WRITE_LSB       : std_logic_vector(4 downto 0) := "00100"; 
  constant CFG_WRITE_WAIT2     : std_logic_vector(4 downto 0) := "00101";
  constant CALIBR_WRITE_PTR    : std_logic_vector(4 downto 0) := "00110"; -- Pointer address x05 - R/W - Optional
  constant CALIBR_WRITE_MSB    : std_logic_vector(4 downto 0) := "00111";
  constant CALIBR_WRITE_WAIT1  : std_logic_vector(4 downto 0) := "01000";
  constant CALIBR_WRITE_LSB    : std_logic_vector(4 downto 0) := "01001";
  constant VOLT_WRITE_PTR      : std_logic_vector(4 downto 0) := "01010";
  constant VOLT_READ_MSB       : std_logic_vector(4 downto 0) := "01011"; -- Voltage register is 16 bit
  constant VOLT_WAIT1          : std_logic_vector(4 downto 0) := "01100";
  constant VOLT_READ_LSB       : std_logic_vector(4 downto 0) := "01101"; -- Read MSB first, LSB second
  constant VOLT_WAIT2          : std_logic_vector(4 downto 0) := "01110";  
  constant CURR_WRITE_PTR      : std_logic_vector(4 downto 0) := "01111";
  constant CURR_READ_MSB       : std_logic_vector(4 downto 0) := "10000"; -- Current register is 16 bit
  constant CURR_WAIT1          : std_logic_vector(4 downto 0) := "10001";
  constant CURR_READ_LSB       : std_logic_vector(4 downto 0) := "10010";
  constant CURR_WAIT2          : std_logic_vector(4 downto 0) := "10011";
  constant POWR_WRITE_PTR      : std_logic_vector(4 downto 0) := "10100";
  constant POWR_READ_MSB       : std_logic_vector(4 downto 0) := "10101"; -- Power register is 16 bit
  constant POWR_WAIT1          : std_logic_vector(4 downto 0) := "10110";
  constant POWR_READ_LSB       : std_logic_vector(4 downto 0) := "10111";
  constant BUSY                : std_logic_vector(4 downto 0) := "11000";
  constant DONE                : std_logic_vector(4 downto 0) := "11001"; 
  constant INA_REG_WRITE       : std_logic_vector(4 downto 0) := "11010"; -- Output to register module


  -- Signal
  signal state_r  : std_logic_vector(4 downto 0);
  signal next_w   : std_logic_vector(4 downto 0);

  -- Data registers
  signal voltage_r   : std_logic_vector(15 downto 0);
  signal current_r   : std_logic_vector(15 downto 0);
  signal power_r     : std_logic_vector(15 downto 0);

begin
  -- FSM current state
  current_state_p : process (clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      state_r <= IDLE;
    elsif rising_edge(clk_i) then
      state_r <= next_w;
    end if;
  end process;

  -- ============================== FSM ============================== 
  -- FSM next state
  next_state_p : process(all)
  begin
    case state_r is
      -- Idle
      when IDLE =>
      if write_setup_en_i = '1' then
        next_w <= CFG_WRITE_PTR;
      elsif read_curr_en_i = '1' then
        next_w <= VOLT_WRITE_PTR;
      else 
        next_w <= IDLE;
      end if;

      -- Write Config Pointer address
      when CFG_WRITE_PTR =>
      if i2c_done_i = '1' then
        next_w <= CFG_WRITE_MSB;
      else
        next_w <= CFG_WRITE_PTR;
      end if;
      -- Write configuration MSB
      when CFG_WRITE_MSB =>
      if i2c_done_i = '1' then
        next_w <= CFG_WRITE_LSB;
      else
        next_w <= CFG_WRITE_MSB;
      end if;
      -- Write configuration Wait 1
      -- when CFG_WRITE_WAIT1 =>
      -- if i2c_busy_i = '0' then
      --   next_w <= CFG_WRITE_LSB;
      -- else
      --   next_w <= CFG_WRITE_WAIT1;
      -- end if;
      -- Write configuration LSB
      when CFG_WRITE_LSB =>
      if i2c_done_i = '1' then
        next_w <= CFG_WRITE_WAIT2;
      else
        next_w <= CFG_WRITE_LSB;
      end if;
      -- Write configuration Wait 2
      when CFG_WRITE_WAIT2 =>
      if i2c_busy_i = '0' then
        next_w <= CALIBR_WRITE_PTR;
      else
        next_w <= CFG_WRITE_WAIT2;
      end if;

      -- Write calibration
      when CALIBR_WRITE_PTR =>
      if i2c_done_i = '1' then
        next_w <= CALIBR_WRITE_MSB;
      else
        next_w <= CALIBR_WRITE_PTR;
      end if;

      when CALIBR_WRITE_MSB =>
      if i2c_done_i = '1' then
        next_w <= CALIBR_WRITE_LSB;
      else
        next_w <= CALIBR_WRITE_MSB;
      end if;

      -- when CALIBR_WRITE_WAIT1 =>
      -- if i2c_busy_i = '0' then
      --   next_w <= CALIBR_WRITE_LSB;
      -- else
      --   next_w <= CALIBR_WRITE_WAIT1;
      -- end if;

      when CALIBR_WRITE_LSB =>
      if i2c_done_i = '1' then
        next_w <= BUSY;
      else
        next_w <= CALIBR_WRITE_LSB;
      end if;

      -- Read voltage registers
      when VOLT_WRITE_PTR =>
      if i2c_done_i = '1' then
        next_w <= VOLT_WAIT1;
      else
        next_w <= VOLT_WRITE_PTR;
      end if;

      when VOLT_WAIT1 =>
      if i2c_busy_i = '0' then -- Not busy
        next_w <= VOLT_READ_MSB;
      else
        next_w <= VOLT_WAIT1;
      end if;

      when VOLT_READ_MSB =>
      if i2c_done_i = '1' then
        next_w <= VOLT_READ_LSB;
      else
        next_w <= VOLT_READ_MSB;
      end if;

      when VOLT_READ_LSB =>
      if i2c_done_i = '1' then
        next_w <= VOLT_WAIT2;
      else
        next_w <= VOLT_READ_LSB;
      end if;

      when VOLT_WAIT2 =>
      if i2c_busy_i = '0' then
        next_w <= CURR_WRITE_PTR;
      else
        next_w <= VOLT_WAIT2;
      end if;

      -- Read (electrical) current register
      when CURR_WRITE_PTR =>
      if i2c_done_i = '1' then
        next_w <= CURR_WAIT1;
      else
        next_w <= CURR_WRITE_PTR;
      end if;

      when CURR_WAIT1 =>
      if i2c_busy_i = '0' then -- Not busy
        next_w <= CURR_READ_MSB;
      else
        next_w <= CURR_WAIT1;
      end if;

      when CURR_READ_MSB =>
      if i2c_done_i = '1' then
        next_w <= CURR_READ_LSB;
      else
        next_w <= CURR_READ_MSB;
      end if;

      when CURR_READ_LSB =>
      if i2c_done_i = '1' then
        next_w <= CURR_WAIT2;
      else
        next_w <= CURR_READ_LSB;
      end if;

      when CURR_WAIT2 =>
      if i2c_busy_i = '0' then -- Not busy
        next_w <= POWR_WRITE_PTR;
      else
        next_w <= CURR_WAIT2;
      end if;

      -- Read power register
      when POWR_WRITE_PTR =>
      if i2c_done_i = '1' then
        next_w <= POWR_WAIT1;
      else
        next_w <= POWR_WRITE_PTR;
      end if;

      when POWR_WAIT1 =>
      if i2c_busy_i = '0' then -- Not busy
        next_w <= POWR_READ_MSB;
      else
        next_w <= POWR_WAIT1;
      end if;

      when POWR_READ_MSB =>
      if i2c_done_i = '1' then
        next_w <= POWR_READ_LSB;
      else
        next_w <= POWR_READ_MSB;
      end if;

      when POWR_READ_LSB =>
      if i2c_done_i = '1' then
        next_w <= INA_REG_WRITE;
      else
        next_w <= POWR_READ_LSB;
      end if;

      -- Register write
      when INA_REG_WRITE =>
        next_w <= BUSY;

      -- Busy
      when BUSY =>
      if i2c_busy_i = '0' then
        next_w <= DONE;
      else
        next_w <= BUSY;
      end if;

      -- Done with configuration, calibration or read
      when DONE =>
        next_w <= IDLE;

      when others => 
        next_w <= IDLE;
    
      end case;
  end process;

  -- ==============================  Assigments ==============================  
  -- Write setup and calibration enable
  i2c_write_o      <= '1' when state_r = CFG_WRITE_PTR    else
                      '1' when state_r = CFG_WRITE_MSB    else
                      '1' when state_r = CFG_WRITE_LSB    else
                      '1' when state_r = CALIBR_WRITE_PTR else
                      '1' when state_r = CALIBR_WRITE_MSB else
                      '1' when state_r = CALIBR_WRITE_LSB else
                      '1' when state_r = VOLT_WRITE_PTR   else
                      '1' when state_r = CURR_WRITE_PTR   else
                      '1' when state_r = POWR_WRITE_PTR   else
                      '0';
  -- Read enable
  i2c_read_o       <= '1' when state_r = VOLT_READ_MSB    else
                      '1' when state_r = VOLT_READ_LSB    else
                      '1' when state_r = CURR_READ_MSB    else   
                      '1' when state_r = CURR_READ_LSB    else
                      '1' when state_r = POWR_READ_MSB    else
                      '1' when state_r = POWR_READ_LSB    else
                      '0';
  -- Done
  ina_done_o       <= '1' when state_r = DONE             else
                      '0';
  -- Write data
 i2c_wdata_o       <= x"00" when state_r = CFG_WRITE_PTR      else
                      x"39" when state_r = CFG_WRITE_MSB      else 
                      x"9F" when state_r = CFG_WRITE_LSB      else
                      x"05" when state_r = CALIBR_WRITE_PTR   else
                      x"50" when state_r = CALIBR_WRITE_MSB   else -- Value was calculated to be 0x5761, before it was 0x5000
                      x"00" when state_r = CALIBR_WRITE_LSB   else
                      x"02" when state_r = VOLT_WRITE_PTR     else
                      x"04" when state_r = CURR_WRITE_PTR     else
                      x"03" when state_r = POWR_WRITE_PTR     else
                      x"00";


 
 
  -- Register data
  register_data_p : process (clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      voltage_r <= x"0000";
      current_r <= x"0000";
      power_r   <= x"0000";
    elsif rising_edge(clk_i) then
      if i2c_done_i = '1' then
        if state_r = VOLT_READ_MSB then
          voltage_r (15 downto 8) <= i2c_rdata_i;
        elsif state_r = VOLT_READ_LSB then
          voltage_r (7 downto  0) <= i2c_rdata_i;
        
        elsif state_r = CURR_READ_MSB then
          current_r (15 downto 8) <= i2c_rdata_i;
          --pragma translate_off
          current_r (15 downto 8) <= x"0A";
          --pragma translate_on
        elsif state_r = CURR_READ_LSB then
          current_r (7 downto  0) <= i2c_rdata_i;
          --pragma translate_off
          current_r (7 downto  0) <= x"00";
          --pragma translate_on

        elsif state_r = POWR_READ_MSB then
          power_r   (15 downto 8) <= i2c_rdata_i;
        elsif state_r = POWR_READ_LSB then
          power_r   (7 downto  0) <= i2c_rdata_i;
        end if;
      end if;
    end if;
  end process;

  volt_data_o <= voltage_r; -- Will read bus voltage register, address x02
  curr_data_o <= current_r; -- All 3 outputs = 16 bits
  powr_data_o <= power_r  ;
  ina_wreg_o  <= '1' when state_r = INA_REG_WRITE else '0'; 

end architecture;