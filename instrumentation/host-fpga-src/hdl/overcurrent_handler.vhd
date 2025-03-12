library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity overcurrent_handler is
  port (
    rstn_i : in std_logic;
    clk_i  : in std_logic;
    -- setup
    on_time_i  : in std_logic_vector(15 downto 0);
    off_time_i : in std_logic_vector(15 downto 0);
    -- overcurrent
    overcurrent_i : in std_logic;
    -- wdata i2c
    gpio_wdata_i : in  std_logic_vector(15 downto 0);
    gpio_wdata_o : out std_logic_vector(15 downto 0)
  );
end entity;

architecture arch of overcurrent_handler is
  constant IDLE    : std_logic_vector(1 downto 0) := "00";
  constant SUT_ON  : std_logic_vector(1 downto 0) := "01";
  constant SUT_OFF : std_logic_vector(1 downto 0) := "10";
  signal state_r : std_logic_vector(1 downto 0);
  signal next_w  : std_logic_vector(1 downto 0);

  signal counter_r       : std_logic_vector(31 downto 0);
  signal on_time_done_w  : std_logic;
  signal off_time_done_w : std_logic;

  constant MASK_GPIO_WDATA_SOM_OFF : std_logic_vector(15 downto 0) := x"FFDD";
  signal sut_force_off_w : std_logic;

begin

  state_p : process (rstn_i, clk_i)
  begin
    if rstn_i = '0' then
      state_r <= IDLE;
    elsif rising_edge(clk_i) then
      state_r <= next_w;
    end if;
  end process;

  next_p : process (all)
  begin
    case (state_r) is

      when IDLE =>
        if overcurrent_i = '1' then
          next_w <= SUT_ON;
        else
          next_w <= IDLE;
        end if;

      when SUT_ON =>
        if on_time_done_w = '1' then
          next_w <= SUT_OFF;
        else
          next_w <= SUT_ON;
        end if;

      when SUT_OFF =>
        if off_time_done_w = '1' then
          next_w <= IDLE;
        else
          next_w <= SUT_OFF;
        end if;

      when others => next_w <= IDLE;
    end case;
  end process;

  counter_p : process (rstn_i, clk_i)
  begin
    if rstn_i = '0' then
      counter_r <= (others => '0');
    elsif rising_edge(clk_i) then

      case state_r is
        
        when IDLE => counter_r <= (others => '0');

        when SUT_ON =>
          if on_time_done_w = '1' then
            counter_r <= (others => '0');
          else
            counter_r <= std_logic_vector(unsigned(counter_r)+1);
          end if;

        when SUT_OFF =>
          if off_time_done_w = '1' then
            counter_r <= (others => '0');
          else
            counter_r <= std_logic_vector(unsigned(counter_r)+1);
          end if;

        when others => counter_r <= (others => '0');
      end case;
    end if;
  end process;

  on_time_done_w  <= '1' when unsigned(counter_r) >= unsigned( on_time_i & x"0000") else '0';
  off_time_done_w <= '1' when unsigned(counter_r) >= unsigned(off_time_i & x"0000") else '0';
  sut_force_off_w <= '1' when state_r = SUT_OFF else '0';

  gpio_wdata_o <= gpio_wdata_i when sut_force_off_w = '0' else (gpio_wdata_i and MASK_GPIO_WDATA_SOM_OFF); -- force GPIO_PIN_SOM_PWR_EN (pin 1) -> off
  
end architecture;
