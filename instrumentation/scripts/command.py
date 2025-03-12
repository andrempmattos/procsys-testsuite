# MIT License

# Copyright (c) 2025 André M. P. Mattos, Douglas A. Santos

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#!/usr/bin/python3

import argparse
import serial
import pyftdi.serialext
from datetime import datetime
import time

# configuration of box
CLOCK_FRQ = 50e6
FTDI_SERIAL_HOST_BOX = {
    # "host00": "FT78WXTY",
    # "host01": "FT78WXTY",
    # "host02": "FT78WXTY",
}

parser = argparse.ArgumentParser(
    prog='command.py',
    description='Monitor for COMMAND interface of som-exp-host box. Opens the FTDI port that corresponds to the command interface of the som-exp-host box to send commands and monitor the experiment.',
    epilog='Script prepared for the experiment in PSI 09/2024'
)
parser.add_argument('--version', action='version', version='%(prog)s 0.1')
parser.add_argument("--box",                  action="store", default="",     choices=FTDI_SERIAL_HOST_BOX.keys())
parser.add_argument("--board-name",           action="store", default="0xA1", help="Board name hexadecimal identifier to be written to the host box (0x0000 - 0xFFFF)")
parser.add_argument("--i2c-frequency",        action="store", default=100,    help="Frequency to operate the I2C peripherals in KHz (100 KHz)")
parser.add_argument("--host-baudrate",        action="store", default=115200, help="Baud rate to communicate between host box and computer (115200)")
parser.add_argument("--sut-baudrate-0",       action="store", default=115200, help="Baud rate to communicate between host box and SUT's UART interface 0 (115200)")
parser.add_argument("--sut-baudrate-1",       action="store", default=115200, help="Baud rate to communicate between host box and SUT's UART interface 1 (115200)")
parser.add_argument("--current-samplerate",   action="store", default=2,      help="Current sampling rate in Hz")
parser.add_argument("--current-threshold",    action="store", default=1000,   help="Maximum current threshold in mA (1000 mA)")
parser.add_argument("--overcurrent-on-time",  action="store", default=50,     help="ON-time after overcurrent (50 ms)")
parser.add_argument("--overcurrent-off-time", action="store", default=200,    help="OFF-time after overcurrent (200 ms)")
parser.add_argument("--ftdi-url",             action='store', default=None,   help="Used to connect to any custom not-configured FTDI (!!overrides --box)")
parser.add_argument("-v", "--verbose",        action='store_true', default=False, help="Set verbose communication mode")

# parse arguments
args = parser.parse_args()

# convert arguments
SEL_HOST_BOX         = args.box
SEL_FTDI_URL         = args.ftdi_url
ARG_BOARD_NAME       = int(args.board_name, 16)
I2C_FREQUENCY        = int(args.i2c_frequency) * 1e3 # convert to KHz
HOST_BAUDRATE        = int(args.host_baudrate)
SUT_BAUDRATE_0       = int(args.sut_baudrate_0)
SUT_BAUDRATE_1       = int(args.sut_baudrate_1)
CURRENT_SAMPLERATE   = float(args.current_samplerate)
CURRENT_THRESHOLD    = float(args.current_threshold) / 1e3
OVERCURRENT_ON_TIME  = float(args.overcurrent_on_time) / 1e3
OVERCURRENT_OFF_TIME = float(args.overcurrent_off_time) / 1e3

####################################################################################################################################

"""
 1. For this function, the value of the current register must be read
 2. The read value must be multiplied by the Current_LSB value

 Example values:
  Currently the register reads x0e3a = 0.3334 A
  """
# CURRENT_LSB = 2 / 2**15 # in Amperes
CURRENT_LSB = 100e-6 # In the datasheet they round to this value, and not use the actual LSB value
def convert_current(current_in_hex : int) -> float:
    return current_in_hex * CURRENT_LSB
def convert_current_hex(current : float) -> int:
    return round(current / CURRENT_LSB)

####################################################################################################################################

# som-exp-host configuration Registers
ADDR_VERSION              = 0x0000 # Read only
ADDR_BOARD_NAME           = 0x0001 # Read/Write
ADDR_SYSTEM_I2C_DIV       = 0x0002 # Read/Write
ADDR_SYSTEM_UART_BAUDRATE = 0x0003 # Read/Write
ADDR_SUT_UART_BAUDRATE_0  = 0x0004 # Read/Write
ADDR_SUT_UART_BAUDRATE_1  = 0x0005 # Read/Write
ADDR_CURRENT_SAMPLERATE   = 0x0006 # Read/Write
ADDR_CURRENT_THRESHOLD    = 0x0007 # Read/Write - Current threshold
ADDR_OVERCURRENT_ON_TIME  = 0x0008 # Read/Write
ADDR_OVERCURRENT_OFF_TIME = 0x0009 # Read/Write
# internal
ADDR_TIMESTAMP_H          = 0x0100 # Read only - Timestamp
ADDR_TIMESTAMP_L          = 0x0101 # Read only - Timestamp
# i2c peripherals
ADDR_GPIO_TRI_ST          = 0x0200 # To define which GPIO are Input or Output
ADDR_GPIO_READ            = 0x0201 # Read only
ADDR_GPIO_WRITE           = 0x0202 # Read/Write
ADDR_VOLTAGE              = 0x0203 # Read - Voltage.
ADDR_CURRENT              = 0x0204 # Read - Current.
ADDR_POWER                = 0x0205 # Read - Power.
ADDR_TEMPERATURE          = 0x0206 # Read only


# globals
cmd_serial_port = None

def init(skip_config : bool = False):
    global cmd_serial_port

    # ftdi selector
    cfg_sel_ftdi_serial = FTDI_SERIAL_HOST_BOX[SEL_HOST_BOX] if SEL_HOST_BOX in FTDI_SERIAL_HOST_BOX else ""
    if SEL_FTDI_URL is not None:
        cfg_serial_url = SEL_FTDI_URL
    else:
        cfg_serial_url = f"ftdi://ftdi:4232h:{cfg_sel_ftdi_serial}/4"

    # open COMMAND serial port (normally /dev/ttyUSB3)
    try:
        print(f"Opening serial port: {cfg_serial_url}")
        cmd_serial_port = pyftdi.serialext.serial_for_url(cfg_serial_url, baudrate=HOST_BAUDRATE)
    except serial.serialutil.SerialException as e:
        print(e)
        exit(1)
    # print box version
    print(f"som-exp-host version: {read_register(ADDR_VERSION)}")
    # print board id
    print(f"BOARD ID: {get_board_id()}")
    # read board name
    board_name = read_register(ADDR_BOARD_NAME)
    # check if board name is the same as the parameter, if so, the device is already configured
    if board_name == ARG_BOARD_NAME:
        skip_config = True
        print("HOST-BOX already configured")
    # check if it skip configuration flag is set
    if not skip_config:
        configure_registers()

def configure_registers():
    # setup
    cfg_system_i2c_div       = round(CLOCK_FRQ / I2C_FREQUENCY)
    cfg_host_uart_baudrate   = round(CLOCK_FRQ / HOST_BAUDRATE)
    cfg_sut_uart_baudrate_0  = round(CLOCK_FRQ / SUT_BAUDRATE_0)
    cfg_sut_uart_baudrate_1  = round(CLOCK_FRQ / SUT_BAUDRATE_1)
    cfg_current_samplerate   = round(CLOCK_FRQ / CURRENT_SAMPLERATE) >> 16
    cfg_current_threshold    = convert_current_hex(CURRENT_THRESHOLD)
    cfg_overcurrent_on_time  = round(CLOCK_FRQ * OVERCURRENT_ON_TIME) >> 16
    cfg_overcurrent_off_time = round(CLOCK_FRQ * OVERCURRENT_OFF_TIME) >> 16
    print("Configure HOST-BOX")
    # configure setup
    write_register(ADDR_BOARD_NAME,           ARG_BOARD_NAME)
    write_register(ADDR_SYSTEM_I2C_DIV,       cfg_system_i2c_div)
    ## write_register(ADDR_SYSTEM_UART_BAUDRATE, cfg_host_uart_baudrate) # ATTENTION: removed host baudrate configuration to avoid issues
    write_register(ADDR_SUT_UART_BAUDRATE_0,  cfg_sut_uart_baudrate_0)
    write_register(ADDR_SUT_UART_BAUDRATE_1,  cfg_sut_uart_baudrate_1)
    write_register(ADDR_CURRENT_SAMPLERATE,   cfg_current_samplerate)
    write_register(ADDR_CURRENT_THRESHOLD,    cfg_current_threshold)
    write_register(ADDR_OVERCURRENT_ON_TIME,  cfg_overcurrent_on_time)
    write_register(ADDR_OVERCURRENT_OFF_TIME, cfg_overcurrent_off_time)
    # init GPIO pins
    init_gpio()

def read_register(addr: int, signed : bool = False) -> int:
    global cmd_serial_port
    cmd = f"r{addr:04x}\n"
    cmd_serial_port.write(cmd.encode())
    data = cmd_serial_port.read_until(b'\n')
    dec = data.decode()
    if args.verbose:
        print(f"cmd: {cmd[:-1]} -> {dec[:-1]}")
    int_val = int(dec, 16)
    if signed:
        return (int_val & 0x7FFF) if ((int_val >> 15)&0x1) == 0 else -(2**15 - (int_val & 0x7FFF))
    return int_val

def write_register(addr: int, data: int) -> int:
    global cmd_serial_port
    cmd = f"w{addr:04x}{data:04x}\n"
    cmd_serial_port.write(cmd.encode())
    if args.verbose:
        print(f"cmd: {cmd[:-1]}")
    # TODO: log all writes

####################################################################################################################################

# pins connected to the i2c gpio peripheral
GPIO_PIN_SOM_JTAGSEL        = 0
GPIO_PIN_SOM_PWR_EN         = 1
GPIO_PIN_SOM_NOSEQ          = 2
GPIO_PIN_SOM_PGOOD          = 3
GPIO_PIN_SOM_BOOTMODE       = 4
GPIO_PIN_SOM_nRST           = 5
GPIO_PIN_SOM_GPIO_0         = 6
GPIO_PIN_SOM_GPIO_1         = 7
GPIO_PIN_SOM_GPIO_2         = 8
GPIO_PIN_SETUP_PWR_EN       = 9
GPIO_PIN_SETUP_WDT_WDO      = 10
GPIO_PIN_SETUP_BOARD_ID_LSB = 11
GPIO_PIN_SETUP_BOARD_ID_MSB = 12
GPIO_PIN_SETUP_GPIO_TEST    = 13
GPIO_PIN_PCIE_GPIO          = 14
GPIO_PIN_GND                = 15

def init_gpio():
    write_register(ADDR_GPIO_TRI_ST,
        # 1: input | 0: output
        (1 << GPIO_PIN_SOM_JTAGSEL       ) |
        (0 << GPIO_PIN_SOM_PWR_EN        ) |
        (1 << GPIO_PIN_SOM_NOSEQ         ) |
        (1 << GPIO_PIN_SOM_PGOOD         ) |
        (1 << GPIO_PIN_SOM_BOOTMODE      ) |
        (0 << GPIO_PIN_SOM_nRST          ) |
        (1 << GPIO_PIN_SOM_GPIO_0        ) |
        (1 << GPIO_PIN_SOM_GPIO_1        ) |
        (1 << GPIO_PIN_SOM_GPIO_2        ) |
        (1 << GPIO_PIN_SETUP_PWR_EN      ) |
        (1 << GPIO_PIN_SETUP_WDT_WDO     ) |
        (1 << GPIO_PIN_SETUP_BOARD_ID_LSB) |
        (1 << GPIO_PIN_SETUP_BOARD_ID_MSB) |
        (0 << GPIO_PIN_SETUP_GPIO_TEST   ) |
        (1 << GPIO_PIN_PCIE_GPIO         ) |
        (1 << GPIO_PIN_GND               )
    )
    # init write with all 0s
    write_register(ADDR_GPIO_WRITE, 0
        | (0 << GPIO_PIN_SOM_PWR_EN        )
        | (0 << GPIO_PIN_SOM_nRST          )
        | (0 << GPIO_PIN_SETUP_GPIO_TEST   )
    )

def get_board_id():
    board_id_msb = read_gpio_pin(GPIO_PIN_SETUP_BOARD_ID_MSB)
    board_id_lsb = read_gpio_pin(GPIO_PIN_SETUP_BOARD_ID_LSB)
    return f"{board_id_msb}{board_id_lsb}"

def config_gpio_pin(gpio_pin: int, val: int):
    reg = read_register(ADDR_GPIO_TRI_ST)
    reg = (reg & ((~(1 << gpio_pin)) & 0xFFFF)) | ((val & 0x1) << gpio_pin)
    write_register(ADDR_GPIO_TRI_ST, reg)

def write_gpio_pin(gpio_pin: int, val: int):
    reg = read_register(ADDR_GPIO_WRITE)
    reg = (reg & ((~(1 << gpio_pin)) & 0xFFFF)) | ((val & 0x1) << gpio_pin)
    write_register(ADDR_GPIO_WRITE, reg)

def read_gpio_pin(gpio_pin: int) -> int:
    reg = read_register(ADDR_GPIO_READ)
    return (reg >> gpio_pin) & 0x1

def toggle_gpio_pin(gpio_pin: int):
    reg = read_register(ADDR_GPIO_WRITE)
    val = 0 if (reg >> gpio_pin) & 0x1 else 1
    reg = (reg & ((~(1 << gpio_pin)) & 0xFFFF)) | ((val & 0x1) << gpio_pin)
    write_register(ADDR_GPIO_WRITE, reg)

####################################################################################################################################

init()

try:
    while True:
        user_input = input('> ').replace('\n', '')

        print(datetime.now().isoformat(), user_input)

        if user_input == "help":
            print("---------------------------------------------------------------")
            print("| cmd     | description                                       |")
            print("---------------------------------------------------------------")
            print("| config  | reconfigure the host box                          |")
            print("| 1       | turn SUT ON                                       |")
            print("| 0       | turn SUT OFF                                      |")
            print("| pwr     | power cycle SUT, (PWR_EN=0 & nRST=0 for 1 second) |")
            print("| rst     | reset SUT, (nRST=0 for 1 second)                  |")
            print("| s       | reset SETUP, (SETUP_PWR_EN=0 for 1 second)        |")
            print("| r       | read the GPIO configuration registers             |")
            print("| ?       | print device current status                       |")
            print("| t       | toggle i2c test led                               |")
            print("| c       | read the device current and print it in mA        |")
            print("| noseq-0 | set NOSEQ of SoM to 0                             |")
            print("| noseq-1 | set NOSEQ of SoM to 1                             |")
            print("| noseq-z | set NOSEQ of SoM to input (high impedance)        |")
            print("---------------------------------------------------------------")

        elif user_input == "config":
            configure_registers()

        elif user_input == "1":
            print("turn on")
            write_gpio_pin(GPIO_PIN_SOM_PWR_EN, 1)
            write_gpio_pin(GPIO_PIN_SOM_nRST, 1)

        elif user_input == "0":
            print("turn off")
            write_gpio_pin(GPIO_PIN_SOM_PWR_EN, 0)
            write_gpio_pin(GPIO_PIN_SOM_nRST, 0)

        elif user_input == "pwr":
            write_gpio_pin(GPIO_PIN_SOM_PWR_EN, 0)
            write_gpio_pin(GPIO_PIN_SOM_nRST,   0)
            time.sleep(1)
            write_gpio_pin(GPIO_PIN_SOM_PWR_EN, 1)
            write_gpio_pin(GPIO_PIN_SOM_nRST,   1)

        elif user_input == "rst":
            write_gpio_pin(GPIO_PIN_SOM_nRST, 0)
            time.sleep(1)
            write_gpio_pin(GPIO_PIN_SOM_nRST, 1)

        elif user_input == "s":
            write_gpio_pin(GPIO_PIN_SETUP_PWR_EN, 0)
            config_gpio_pin(GPIO_PIN_SETUP_PWR_EN, 0)
            time.sleep(1)
            write_gpio_pin(GPIO_PIN_SETUP_PWR_EN, 1)

        elif user_input == "r":
            print(f"t_regs: {read_register(ADDR_GPIO_TRI_ST):04X}")
            print(f"w_regs: {read_register(ADDR_GPIO_WRITE):04X}")
            print(f"r_regs: {read_register(ADDR_GPIO_READ):04X}")

        elif user_input == "?":
            print("SUT", 'ON' if read_gpio_pin(GPIO_PIN_SOM_PWR_EN) else 'OFF', end='')
            print(" | ", end='')
            print("nRST", 'HI' if read_gpio_pin(GPIO_PIN_SOM_nRST) else 'LO', end='')
            print(" | ", end='')
            print("PGOOD", 'YES' if read_gpio_pin(GPIO_PIN_SOM_PGOOD) else 'NO')

        elif user_input == "t":
            toggle_gpio_pin(GPIO_PIN_SETUP_GPIO_TEST)

        elif user_input == "c":
            hex_curr = read_register(ADDR_CURRENT, signed=True)
            print(f"current: {hex_curr:04x}")
            print(f"current: {convert_current(hex_curr)*1e3:.02f} mA")

        elif user_input == "noseq-z":
            config_gpio_pin(GPIO_PIN_SOM_NOSEQ, 1) # config as input

        elif user_input == "noseq-0":
            write_gpio_pin(GPIO_PIN_SOM_NOSEQ, 0) # set to 0
            config_gpio_pin(GPIO_PIN_SOM_NOSEQ, 0) # config as output

        elif user_input == "noseq-1":
            write_gpio_pin(GPIO_PIN_SOM_NOSEQ, 1) # set to 1
            config_gpio_pin(GPIO_PIN_SOM_NOSEQ, 0) # config as output

except KeyboardInterrupt:
    pass
