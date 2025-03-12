"""
  Convert received Hex values to binary visualization of GPIO and then visualize by corresponding GPIO

  This script will take the received hex values from the GPIO 
  and convert convert it to a visualizable and analizable format
"""

import binascii
"""
 1. Read register x"0005"

 Examples values:
 TODO Add example values
 """

def visualize_gpio_values(gpio_in_hex):

  print(gpio_in_hex)
  port_0 = gpio_in_hex[2:4]
  port_1 = gpio_in_hex[0:2]

  print(port_0)
  print(port_1)

  converted_port_0 = convert_string_hex_to_binary(port_0) 
  converted_port_1 = convert_string_hex_to_binary(port_1)
  print(converted_port_0[0], converted_port_0[1], converted_port_0[2],  converted_port_0[3], 
        converted_port_0[4], converted_port_0[5], converted_port_0[6], converted_port_0[7])

  print("==========================================================")
  print("Port 0:")
  print("| SOM_GPIO_1 | SOM_GPIO_0 |   SOM_nRST     |   SOM_BOOTMODE  |    SOM_PGOOD    |   SOM_NOSEQ   |  SOM_PWR_EN  | SOM_JTAG_SEL |")
  print("|     {}      |     {}      |      {}         |        {}        |        {}        |      {}        |      {}       |      {}       |".format(converted_port_0[0], 
        converted_port_0[1], converted_port_0[2], converted_port_0[3], converted_port_0[4], converted_port_0[5], converted_port_0[6], converted_port_0[7]))

  print("Port 1:")
  print("|   GND      | PCIE_GPIO  | SETUP_GPIO_TEST| SETUP_BOARD_MSB | SETUP_BOARD_LSB | SETUP_WDT_WDO | SETUP_PWR_EN |  SOM_GPIO_2  |")
  print("|     {}      |     {}      |      {}         |        {}        |        {}        |      {}        |      {}       |      {}       |".format(converted_port_1[0], 
        converted_port_1[1], converted_port_1[2], converted_port_1[3], converted_port_1[4], converted_port_1[5], converted_port_1[6], converted_port_1[7]))
  print("==========================================================")


  print(converted_port_0)
  print(converted_port_1)

def convert_string_hex_to_binary(hex_string):
  scale = 16
  return bin(int(hex_string, scale))[2:].zfill(len(hex_string) * 4)

# visualize_gpio_values("1a1e")
# print("-------")
# visualize_gpio_values("1a1c")
# print("-------")
# visualize_gpio_values("7308")
# print("-------")
# visualize_gpio_values("731e")
# print("-------")
# visualize_gpio_values("731e")
# print("-------")