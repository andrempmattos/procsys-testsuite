library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- TODO Connect incoming UART from transceivers
-- TODO Connect outgoing UART to computer 

-- Procedure
-- Place data into input
-- Set write enable to one
-- Wait one clk cycle
-- Set write enable to 0
-- Data is stored in address
-- Read:
--  Set read enable to 1
--  Each cycle should give one data
entity fifo is
  generic (
    FIFO_SIZE  : integer;
    DATA_WIDTH : integer
  );
  port (
    write_i     : in std_logic;
    data_i      : in std_logic_vector(DATA_WIDTH-1 downto 0);
    read_i      : in std_logic;

    clk_i       : in std_logic;
    rstn_i      : in std_logic;

    full_o      : out std_logic;
    empty_o     : out std_logic;
    valid_o     : out std_logic;
    rem_size_o  : out std_logic_vector(31 downto 0);
    data_o      : out std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end fifo;

architecture arch_fifo of fifo is

  type fifo_t is array(natural range <>) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal fifo_r  : fifo_t(FIFO_SIZE-1 downto 0);

  signal first_addr_r  : integer range 0 to FIFO_SIZE-1;
  signal insert_addr_r : integer range 0 to FIFO_SIZE-1;
  signal size_r        : integer range 0 to FIFO_SIZE;

  signal next_first_addr_w : integer range 0 to FIFO_SIZE-1;
  signal next_insert_addr_w  : integer range 0 to FIFO_SIZE-1;

  signal full_w        : std_logic;
  signal empty_w       : std_logic;

  -- Attributes to fix Synplify bugs
  attribute syn_preserve : boolean;
  attribute syn_preserve of arch_fifo : architecture is true;

begin

  next_first_addr_w  <= first_addr_r+1  when first_addr_r  /= FIFO_SIZE-1 else 0;
  next_insert_addr_w <= insert_addr_r+1 when insert_addr_r /= FIFO_SIZE-1 else 0;

  p_MAIN : process(clk_i, rstn_i)
    variable new_size_v : integer range 0 to FIFO_SIZE;
  begin
    if rstn_i = '0' then
      first_addr_r  <= 0;
      insert_addr_r <= 0;
      size_r        <= 0;
      valid_o       <= '0';

    elsif rising_edge(clk_i) then

      new_size_v := size_r;
      -- Read FIFO if not empty
      if read_i = '1' and empty_w = '0' then
        valid_o <= '1';
        data_o  <= fifo_r(first_addr_r);
        first_addr_r <= next_first_addr_w;
        new_size_v := new_size_v - 1;
      else
        valid_o <= '0';
      end if;
      -- Write to FIFO if not full
      if write_i = '1' and full_w = '0' then
        fifo_r(insert_addr_r) <= data_i;
        insert_addr_r <= next_insert_addr_w;
        new_size_v := new_size_v + 1;
      end if;

      size_r <= new_size_v;

    end if;
  end process;

  empty_w       <= '1' when size_r = 0         else '0';
  full_w        <= '1' when size_r = FIFO_SIZE else '0';
      
  empty_o <= empty_w;
  full_o  <= full_w;

  rem_size_o <= std_logic_vector(to_unsigned(FIFO_SIZE - size_r, 32));

end arch_fifo;
