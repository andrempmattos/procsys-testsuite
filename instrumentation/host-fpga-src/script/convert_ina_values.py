"""
  Convert INA219 received Hex values

  This script will take the received hex values from Bus Voltage, Current and Power from the INA 
  and convert it to decimal values.
"""

import math

"""
 1. For this function, the value of the bus voltage register must be shifted right by three bits.
 2. After shifting the number must be multiplied by the 4 mV LSB value to compute the bus voltage value

 Example values:
 x1982 will give a voltage value of 3.260 V
 x197a will give a voltage value of 3.264 V
 """
def convert_bus_voltage(volts_in_strhex):
  hexi = int("0x" + volts_in_strhex, base=16)
  volt_lsb = 4e-3 # Volts LSB = 4 mV
  
  shifted_hex_value = ((hexi >> 1)>>1)>>1 # Shift right by three bits
  volts_in_decimal = shifted_hex_value * volt_lsb
  return volts_in_decimal

"""
 1. For this function, the value of the current register must be read
 2. The read value must be multiplied by the Current_LSB value

 Example values:
  Currently the register reads x0e3a = 0.3334 A
  """
def convert_current(current_in_hex):
  current_lsb = 2 / 2**15 # in Amperes
  return current_in_hex * current_lsb

def convert_power(power_in_hex):

  return 0

"""
  The following formulas are based on pages 12-13 from the INA219 Datasheet.
  These values are used to calculate the calibration value that is written to the Calibration Register.
  The value must be such that it maximizes the accuracy of the measurement.
  
  Additional reference:
  - Following Adafruit INA219 library we can see how the calibration register value is calculated.
  - Adjusting for our shunt resistor value we get a value of x5000
"""
class Calibration:
  
  max_current = 2
  current_lsb = 100e-6 # Round the actual current LSB to a round-ish value such as 100 uA
  r_shunt     = 20e-3  # 20 mOhms

  def __init__(self):
    pass
    #self.corrected_cal_value   = self.get_corrected_full_scale_cal()

  def get_cal_value(self):                    # Equation 1
    cal_value = math.trunc(0.04096/(self.current_lsb * self.r_shunt))
    return cal_value
  
  def get_current_lsb(self):                           # Equation 2
    return self.max_current/(2**15)
  
  def get_power_lsb(self):                             # Equation 3
    return 20 * self.current_lsb
  
  def theoretical_current_register(shunt_volt_r, bus_volt_r): # Equation 4
    return (shunt_volt_r * bus_volt_r) / 4096
  
  def power_register(current_r, bus_volt_r):                  # Equation 5
    return (current_r * bus_volt_r) / 5000
  
  # TODO This requires an actual measured shunt current to eliminate system error.
  # We would need to use an external ammeter to set the value of this register
  def get_corrected_full_scale_cal():                         # Equation 6
    # meas_shunt_current = 0
    # ina219_current = 1
    return 0 #math.trunc((self.cal_value * meas_shunt_current))

# Testing 
# Format to 4 decimal places only, since register uses half-float precision (16 bits)
# Register 0x000C
# print("================Voltage values===================")
# print('{0:.4f}'.format(convert_bus_voltage(0x1982)))
# print('{0:.4f}'.format(convert_bus_voltage(0x197a)))
# print('{0:.4f}'.format(convert_bus_voltage(0x001a)))
# print('{0:.4f}'.format(convert_bus_voltage(0x0022)))
# print('{0:.4f}'.format(convert_bus_voltage(0x198a)))
# print("================Current values===================") # Register 0x000B
# print('{0:.4f}'.format(convert_current(0xfff1))) # Value when supply enable is off
# print('{0:.4f}'.format(convert_current(0xffec))) # Value when supply enable is off
# print('{0:.4f}'.format(convert_current(0x0cf3))) # Value when supply enable is off
# print('{0:.4f}'.format(convert_current(0x0cf8))) # Value when supply enable is on
# print("================ Power values ===================") # Register 0x000D
# print('{0:.4f}'.format(convert_bus_voltage(0x0000))) # Value when supply enable is off. 
# print('{0:.4f}'.format(convert_bus_voltage(0x021d))) # Value when supply enable is off. 

# calibrate = Calibration()
# cal_val = calibrate.get_cal_value()
# print("=================================================")
# print("=============== Calibration =====================")
# print("Calibration value in decimal is: ", cal_val)
# print("Calibration value in hex is    :", hex(cal_val))
# print("=================================================")