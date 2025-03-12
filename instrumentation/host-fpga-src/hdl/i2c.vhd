library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c is
  port (
    rstn_i : in std_logic;
    clk_i  : in std_logic;
    -- configuration
    baud_div_i : in std_logic_vector(15 downto 0);
    -- transmit interface
    write_i : in  std_logic;
    read_i  : in  std_logic;
    ackn_o  : out std_logic;
    done_o  : out std_logic;
    busy_o  : out std_logic;
    -- data
    addr_i  : in  std_logic_vector(6 downto 0);
    wdata_i : in  std_logic_vector(7 downto 0);
    rdata_o : out std_logic_vector(7 downto 0);
    -- i2c interface
    i2c_sda_i  : in  std_logic;
    i2c_sda_o  : out std_logic;
    i2c_sdat_o : out std_logic;
    i2c_scl_o  : out std_logic
  );
end entity;

architecture arch of i2c is
  -- states
  constant IDLE      : std_logic_vector(3 downto 0) := x"0";
  constant I2C_START : std_logic_vector(3 downto 0) := x"1";
  constant I2C_ADDR  : std_logic_vector(3 downto 0) := x"2";
  constant I2C_AACK  : std_logic_vector(3 downto 0) := x"3";
  constant I2C_WDATA : std_logic_vector(3 downto 0) := x"4";
  constant WDONE     : std_logic_vector(3 downto 0) := x"5";
  constant I2C_WACK  : std_logic_vector(3 downto 0) := x"6";
  constant I2C_RDATA : std_logic_vector(3 downto 0) := x"7";
  constant RDONE     : std_logic_vector(3 downto 0) := x"8";
  constant I2C_RACK  : std_logic_vector(3 downto 0) := x"9";
  constant I2C_STOP  : std_logic_vector(3 downto 0) := x"A";
  constant I2C_WAIT  : std_logic_vector(3 downto 0) := x"B";
  constant I2C_ACKN  : std_logic_vector(3 downto 0) := x"F";

  -- CONTROL
  signal state_r : std_logic_vector(3 downto 0);
  signal next_w  : std_logic_vector(3 downto 0);

  signal sda_in_w   : std_logic;

  signal baud_count_w : std_logic;
  signal bit_count_w  : std_logic;

  signal get_ack_w  : std_logic;
  signal get_data_w : std_logic;

  -- DATAPATH
  signal baud_counter_r     : std_logic_vector(15 downto 0);
  signal baud_counter_max_w : std_logic;
  signal baud_counter_mid_w : std_logic;

  signal baud_counter_first_half_w  : std_logic;
  signal baud_counter_second_half_w : std_logic;
  signal baud_counter_mid_quarter_w : std_logic;

  signal scl_stop_w : std_logic;

  signal bit_counter_r      : std_logic_vector(2 downto 0);
  signal bit_counter_zero_w : std_logic;

  signal addr_data_w : std_logic_vector(7 downto 0);

  signal ackn_r  : std_logic;
  signal rdata_r : std_logic_vector(7 downto 0);

  -- Attributes to fix Synplify bugs
  attribute syn_preserve : boolean;
  attribute syn_preserve of state_r : signal is true;

  signal conf_baud_count_max_w        : std_logic_vector(15 downto 0);
  signal conf_mid_baud_div_w          : std_logic_vector(15 downto 0);
  signal conf_quarter_baud_div_w      : std_logic_vector(15 downto 0);
  signal conf_threequarter_baud_div_w : std_logic_vector(15 downto 0);

begin
  -- BAUD RATE CALCULATION
  conf_baud_count_max_w         <= std_logic_vector(unsigned(baud_div_i)+1) when baud_div_i /= (15 downto 0 => '1') else (15 downto 0 => '1');
  conf_mid_baud_div_w           <= "0"  & baud_div_i(15 downto 1);
  conf_quarter_baud_div_w       <= "00" & baud_div_i(15 downto 2);
  conf_threequarter_baud_div_w  <= std_logic_vector(unsigned(conf_mid_baud_div_w) + unsigned(conf_quarter_baud_div_w));

  ---------------------------------------------------------------
  ----------------------- STATE MACHINE -------------------------
  ---------------------------------------------------------------
  current_p : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      state_r <= IDLE;
    elsif rising_edge(clk_i) then
      state_r <= next_w;
    end if;
  end process;

  next_p : process(state_r, write_i, read_i, baud_counter_max_w, bit_counter_zero_w, ackn_r)
  begin
    case state_r is

      -- wait write or read request
      when IDLE =>
        if write_i = '1' or read_i = '1' then
          next_w <= I2C_START;
        else
          next_w <= IDLE;
        end if;

      -- start i2c communication
      when I2C_START =>
        if baud_counter_max_w = '1' then
          next_w <= I2C_ADDR;
        else
          next_w <= I2C_START;
        end if;

      -- write address to i2c bus
      when I2C_ADDR =>
        if bit_counter_zero_w = '1' then
          next_w <= I2C_AACK;
        else
          next_w <= I2C_ADDR;
        end if;

      -- read address ack from slave
      when I2C_AACK =>
        if baud_counter_max_w = '1' then
          if ackn_r = '0' then
            if write_i = '1' then
              next_w <= I2C_WDATA;
            else -- read_i = '1'
              next_w <= I2C_RDATA;
            end if;
          else
            -- slave didnt respond
            next_w <= I2C_ACKN;
          end if;
        else
          next_w <= I2C_AACK;
        end if;

      -- write data to slave
      when I2C_WDATA =>
        if bit_counter_zero_w = '1' then
          next_w <= WDONE;
        else
          next_w <= I2C_WDATA;
        end if;

      when WDONE => next_w <= I2C_WACK;

      when I2C_WACK =>
        if baud_counter_max_w = '1' then
          if ackn_r = '1' then
            -- slave didnt respond
            next_w <= I2C_ACKN;
          elsif write_i = '1' then
            -- keep writing data
            next_w <= I2C_WDATA;
          else
            -- stop transmission
            next_w <= I2C_STOP;
          end if;
        else
          next_w <= I2C_WACK;
        end if;

      -- read data from slave
      when I2C_RDATA =>
        if bit_counter_zero_w = '1' then
          next_w <= RDONE;
        else
          next_w <= I2C_RDATA;
        end if;

      when RDONE => next_w <= I2C_RACK;

      when I2C_RACK =>
        if baud_counter_max_w = '1' then
          if read_i = '1' then
            -- keep receiving
            next_w <= I2C_RDATA;
          else
            -- stop receiving
            next_w <= I2C_STOP;
          end if;
        else
          next_w <= I2C_RACK;
        end if;

      -- stop i2c operation
      when I2C_STOP =>
        if baud_counter_max_w = '1' then
          next_w <= I2C_WAIT;
        else
          next_w <= I2C_STOP;
        end if;

      when I2C_WAIT =>
        if baud_counter_max_w = '1' then
          next_w <= IDLE;
        else
          next_w <= I2C_WAIT;
        end if;

      when I2C_ACKN => next_w <= I2C_STOP;

      when others => next_w <= IDLE;

    end case;
  end process;

  sda_in_w     <= '1' when state_r = IDLE      else
                  '1' when state_r = I2C_AACK  else
                  '1' when state_r = WDONE     else -- write operations
                  '1' when state_r = I2C_WACK  else -- write operations
                  '1' when state_r = I2C_RDATA else -- read operations
                  '1' when state_r = I2C_WAIT  else
                  '0';
  i2c_sdat_o <= sda_in_w;
  get_ack_w  <= baud_counter_mid_w when state_r = I2C_AACK or state_r = I2C_WACK else '0';
  get_data_w <= baud_counter_mid_w when state_r = I2C_RDATA else '0';

  baud_count_w <= '1' when state_r /= IDLE else '0';
  bit_count_w  <= '1' when state_r =  I2C_ADDR or state_r = I2C_WDATA or state_r = I2C_RDATA else '0';

  ackn_o       <= '1' when state_r =  I2C_ACKN else '0';
  done_o       <= '1' when (state_r = WDONE) or (state_r = RDONE) or (state_r = I2C_ACKN) else '0';
  busy_o       <= '1' when state_r /= IDLE     else '0';

  ---------------------------------------------------------------
  ------------------------- DATAPATH ----------------------------
  ---------------------------------------------------------------
  -- sda_io <= 'Z' when sda_in_w = '1' else sda_o_w;
  -- sda_i_w <= sda_io;
  baud_counter_p : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      baud_counter_r <= (others => '0');
      bit_counter_r  <= (others => '1');
    elsif rising_edge(clk_i) then
      if baud_count_w = '1' then
        if baud_counter_max_w = '1' then
          baud_counter_r <= (others => '0');
          if bit_count_w = '1' then
            bit_counter_r <= std_logic_vector(unsigned(bit_counter_r) - 1);
          end if;
        else
          baud_counter_r <= std_logic_vector(unsigned(baud_counter_r) + 1);
        end if;
      end if;
    end if;
  end process;
  -- baud comparison values
  baud_counter_max_w <= '1' when baud_counter_r = conf_baud_count_max_w else '0';
  bit_counter_zero_w <= baud_counter_max_w when bit_counter_r = "000" else '0';


  baud_counter_mid_w         <= '1' when baud_counter_r = conf_mid_baud_div_w else '0';
  baud_counter_first_half_w  <= '1' when unsigned(baud_counter_r)  < unsigned(conf_mid_baud_div_w) else '0';
  baud_counter_second_half_w <= not baud_counter_first_half_w;
  baud_counter_mid_quarter_w <= '1' when unsigned(baud_counter_r) >= unsigned(conf_quarter_baud_div_w)      and
                                         unsigned(baud_counter_r) <= unsigned(conf_threequarter_baud_div_w) else '0';
  
  scl_stop_w <= '1' when baud_counter_mid_quarter_w = '1' else
                '1' when baud_counter_second_half_w = '1' else
                '0';
  -- i2c interface
  i2c_scl_o <= '1'                        when state_r = IDLE       else
               '1'                        when state_r = I2C_WAIT   else
               '0'                        when state_r = I2C_ACKN   else
               baud_counter_first_half_w  when state_r = I2C_START  else
               scl_stop_w                 when state_r = I2C_STOP   else
               baud_counter_mid_quarter_w;

  addr_data_w <= addr_i & (not write_i);
  i2c_sda_o   <= '0'                                              when state_r = I2C_START else
                 addr_data_w(to_integer(unsigned(bit_counter_r))) when state_r = I2C_ADDR  else
                 wdata_i(to_integer(unsigned(bit_counter_r)))     when state_r = I2C_WDATA else
                 not read_i                                       when state_r = RDONE     else
                 not read_i                                       when state_r = I2C_RACK  else
                 baud_counter_second_half_w                       when state_r = I2C_STOP  else
                 '1';

  baud_p : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if get_ack_w = '1' then
        ackn_r <= i2c_sda_i;
      end if;
    end if;
  end process;

  rdata_p : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if get_data_w = '1' then
        rdata_r <= rdata_r(6 downto 0) & i2c_sda_i;
      end if;
    end if;
  end process;

  rdata_o <= rdata_r;

end architecture;
