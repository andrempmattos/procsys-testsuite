library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Convert hex to utf-8 chars
entity utf8_hex is
  port
  (
    data_i     : in std_logic_vector(3 downto 0);
    utf_data_o : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of utf8_hex is

begin
  utf_data_o <= x"30" when data_i = x"0" else
                x"31" when data_i = x"1" else
                x"32" when data_i = x"2" else
                x"33" when data_i = x"3" else
                x"34" when data_i = x"4" else
                x"35" when data_i = x"5" else
                x"36" when data_i = x"6" else
                x"37" when data_i = x"7" else
                x"38" when data_i = x"8" else
                x"39" when data_i = x"9" else
                x"61" when data_i = x"a" or data_i = x"A"else
                x"62" when data_i = x"b" or data_i = x"B"else
                x"63" when data_i = x"c" or data_i = x"C"else
                x"64" when data_i = x"d" or data_i = x"D"else
                x"65" when data_i = x"e" or data_i = x"E"else
                x"66" when data_i = x"f" or data_i = x"F"; --when data_i = x"f"; -- x"66" is ff         

end architecture;