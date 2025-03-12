-- Count
-- Make this block keep time using the internal oscillator
-- Use 32 bits to store counter?

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timestamp is
  -- generic(Clock_FrequencyHz : integer);
  port (
    clk_i   : in std_logic;
    rstn_i : in std_logic;
    -- Outputs
    timestamp_ms_o : out std_logic_vector(31 downto 0)
    
  );
end entity;

architecture rtl of timestamp is
  -- Could make this generic instead
  constant CLK_FREQUENCY : integer := 50000000; -- 50 MHz clock

  -- Counting signals
  constant TICK_COUNTER : std_logic_vector(15 downto 0) := x"C34F"; -- C34F is 1 ms, 49999 in decimal
  signal tick_r : std_logic_vector(15 downto 0) := (others => '0');
  signal milisecond_r : std_logic_vector(31 downto 0) := (others => '0'); -- Will hold a total value of 49 days

begin

  count_up_p : process (clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      milisecond_r <= (others => '0');
      tick_r <= (others => '0');
    elsif rising_edge(clk_i) then
      if (unsigned(tick_r) >= unsigned(TICK_COUNTER)) then 
        milisecond_r <= std_logic_vector(unsigned(milisecond_r) + 1); -- Add one count after reaching the desired value. Keep counting up
        tick_r <= (others => '0');
      else
        -- Count up
        tick_r <= std_logic_vector(unsigned(tick_r) + 1);
      end if;
      -- Assign value to output
    end if;
  end process;

  timestamp_ms_o <= milisecond_r;

  

end architecture;