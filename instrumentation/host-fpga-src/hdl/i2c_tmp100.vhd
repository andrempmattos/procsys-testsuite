library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- I2C Address x48
entity i2c_tmp100 is
  port (
    clk_i               : in std_logic;
    rstn_i              : in std_logic;
    -- Inputs
    read_temp_en_i      :  in std_logic;
    write_setup_en_i    :  in std_logic;
    -- Outputs
    done_o              : out std_logic;
    temperature_o       : out std_logic_vector(15 downto 0);
    -- I2C interface
    i2c_done_i          : in  std_logic;
    i2c_busy_i          : in  std_logic;
    i2c_write_o         : out std_logic;
    i2c_read_o          : out std_logic;
    i2c_rdata_i         : in  std_logic_vector(7 downto 0);
    i2c_wdata_o         : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of i2c_tmp100 is

  -- FSM States
  constant IDLE                 : std_logic_vector(3 downto 0) := x"0";
  constant CFG_WRITE_PTR        : std_logic_vector(3 downto 0) := x"1";
  constant CFG_WRITE            : std_logic_vector(3 downto 0) := x"2";
  constant TMP_WRITE_PTR        : std_logic_vector(3 downto 0) := x"3";
  constant TMP_WAIT             : std_logic_vector(3 downto 0) := x"5";
  constant TMP_READ_BYTE1       : std_logic_vector(3 downto 0) := x"6";
  constant TMP_READ_BYTE2       : std_logic_vector(3 downto 0) := x"7";
  constant BUSY                 : std_logic_vector(3 downto 0) := x"8";
  constant DONE                 : std_logic_vector(3 downto 0) := x"9";

  -- signal
  signal state_r : std_logic_vector(3 downto 0);
  signal next_w  : std_logic_vector(3 downto 0);

  -- Temperature register
  signal temperature_r      : std_logic_vector(15 downto 0);

begin

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

      -- wait write or read request
      when IDLE =>
        if write_setup_en_i = '1' then
          next_w <= CFG_WRITE_PTR;
        elsif read_temp_en_i = '1' then
          next_w <= TMP_WRITE_PTR;
        else
          next_w <= IDLE;
        end if;

      when CFG_WRITE_PTR =>
        if i2c_done_i = '1' then
          next_w <= CFG_WRITE;
        else
          next_w <= CFG_WRITE_PTR;
        end if;

      when CFG_WRITE =>
        if i2c_done_i = '1' then
          next_w <= BUSY;
        else
          next_w <= CFG_WRITE;
        end if;

      when BUSY =>
        if i2c_busy_i = '0' then
          next_w <= DONE;
        else
          next_w <= BUSY;
        end if;

        -- Set done = 1
      when DONE =>
          next_w <= IDLE;

        -- Read Temp
      when TMP_WRITE_PTR =>
        if i2c_done_i = '1' then
          next_w <= TMP_WAIT;
        else
          next_w <= TMP_WRITE_PTR;
        end if;

      when TMP_WAIT =>
        if i2c_busy_i = '0' then -- Not busy
          next_w <= TMP_READ_BYTE1;
        else
          next_w <= TMP_WAIT;
        end if;

      when TMP_READ_BYTE1 =>
        if i2c_done_i = '1' then
          next_w <= TMP_READ_BYTE2;
        else
          next_w <= TMP_READ_BYTE1;
        end if;

      when TMP_READ_BYTE2 =>
        if i2c_done_i = '1' then
          next_w <= BUSY;
        else
          next_w <= TMP_READ_BYTE2;
        end if;

      when others => 
          next_w <= IDLE;

    end case;
  end process;

i2c_write_o <= '1' when state_r = CFG_WRITE_PTR        else
               '1' when state_r = CFG_WRITE            else
               '1' when state_r = TMP_WRITE_PTR        else
               '0';
                
i2c_read_o  <= '1' when state_r = TMP_READ_BYTE1       else
               '1' when state_r = TMP_READ_BYTE2       else
               '0';

done_o      <= '1' when state_r = DONE                 else
               '0';

i2c_wdata_o <= x"01" when state_r = CFG_WRITE_PTR        else
               x"60" when state_r = CFG_WRITE            else -- TODO Move data to be written (x60) to a constant
               x"00" when state_r = TMP_WRITE_PTR        else
               x"00";

process (clk_i, rstn_i)
begin
    if rstn_i = '0' then
      temperature_r <= x"0000";
    elsif rising_edge(clk_i) then
      if i2c_done_i = '1' then
        if state_r = TMP_READ_BYTE1 then
          temperature_r(15 downto 8) <= i2c_rdata_i; -- MSB
        elsif state_r = TMP_READ_BYTE2 then
          temperature_r(7 downto 0)  <= i2c_rdata_i; -- LSB
        end if;
    end if;
  end if;
end process;

temperature_o <= temperature_r;

end architecture;