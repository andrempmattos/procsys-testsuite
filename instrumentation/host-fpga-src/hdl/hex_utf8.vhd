library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Convert UTF-8 to Hex
entity hex_utf8 is
  port
  (
    utf_data_i : in std_logic_vector(7 downto 0);
    data_o     : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of hex_utf8 is
-- TODO Add Capital letter conversion
begin
  data_o <= x"0" when utf_data_i = x"30" else
            x"1" when utf_data_i = x"31" else
            x"2" when utf_data_i = x"32" else
            x"3" when utf_data_i = x"33" else
            x"4" when utf_data_i = x"34" else
            x"5" when utf_data_i = x"35" else
            x"6" when utf_data_i = x"36" else
            x"7" when utf_data_i = x"37" else
            x"8" when utf_data_i = x"38" else
            x"9" when utf_data_i = x"39" else
            x"a" when utf_data_i = x"61" or utf_data_i = x"41" else
            x"b" when utf_data_i = x"62" or utf_data_i = x"42" else
            x"c" when utf_data_i = x"63" or utf_data_i = x"43" else
            x"d" when utf_data_i = x"64" or utf_data_i = x"44" else
            x"e" when utf_data_i = x"65" or utf_data_i = x"45" else
            x"f" when utf_data_i = x"66" or utf_data_i = x"46"; -- x"66" is ff         

end architecture;