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

import os
import argparse
import serial
import serial.tools.list_ports
import pyftdi.serialext
import sys
import threading
import time
from datetime import datetime, timedelta
from queue import Queue
import re
import traceback
import select

########################################################
# Global variables

logdir = None
finished = False
logging_queue = Queue()

########################################################
# ARGUMENT PARSER
parser = argparse.ArgumentParser(prog='Experiment Monitor', description='Monitors the UART output of the experiment and the current monitor information')
parser.add_argument('--label',     help='sets the label to identify the type of logging', type=str, default="UART")
parser.add_argument('--ftdi-id',   help='sets the argument for searching the USB port where the device is located', default="")
parser.add_argument('--ftdi-port', help='sets the argument for searching the USB port where the device is located', required=True)
parser.add_argument('--baudrate',  help='defines the baudrate for the UART', type=int, default=115200)
parser.add_argument('--parity',    help='enable parity for the UART port', action='store_true', default=False)
parser.add_argument('--rtscts',    help='enable RTSCTS flow control for the UART port', action='store_true', default=False)
parser.add_argument('--info',      help='board information to be added to the log files (short info)', default='')
parser.add_argument('--logdir',    help='log directory to be used', default='')
#
parser.add_argument('--output-parser', help='output parser configuration', choices=["current"], default='')
# debug-only
parser.add_argument('--enable-user-input', help='enable user input to the UART port', action='store_true', default=False)
parser.add_argument('--enable-loopback', help='enable loopback test to the UART port', action='store_true', default=False)
parser.add_argument('--enable-loopback-injected', help='enable loopback test (with injected error) to the UART port', action='store_true', default=False)
args = parser.parse_args()

ARG_LABEL = args.label.upper()
ftdi_id = args.ftdi_id
ftdi_port = args.ftdi_port
device_info = args.info
baudrate = args.baudrate
parity = args.parity
rtscts = args.rtscts
logdir = args.logdir
ARG_ENABLE_USER_INPUT = args.enable_user_input
ARG_OUTPUT_PARSER = args.output_parser
if args.enable_loopback or args.enable_loopback_injected:
    ARG_ENABLE_LOOPBACK = True
else:
    ARG_ENABLE_LOOPBACK = False
ARG_ENABLE_LOOPBACK_INJECTED = args.enable_loopback_injected

########################################################
# OUTPUT PARSING

def get_bit(value: int, bit_addr: int) -> int:
    return ((value >> bit_addr) & 0x1)

CURRENT_LSB = 100e-6
def hex_current_to_float(hex_current: str) -> float:
    # convert to hexadecimal
    int_val = int(hex_current, 16)
    # handle negative values
    int_val = (int_val & 0x7FFF) if get_bit(int_val, 15) == 0 else -(2**15 - (int_val & 0x7FFF))
    # return the current
    return int_val * CURRENT_LSB

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

COLOR_GOOD = "\033[32m"
COLOR_BAD  = "\033[41m"
COLOR_NONE = "\033[0m"

def parse_output_current(line: str) -> str:
    REGEX_CURRENT = r"[0-9a-fA-F]{8} ([0-9a-fA-F]{4}) [0-9a-fA-F]{8} ([0-9a-fA-F]{4}) [0-9a-fA-F]{8} ([0-9a-fA-F]{4})"
    # assert if value is correctly formatted
    if re.match(REGEX_CURRENT, line) is None:
        return line
    # read values into variables
    hex_current, hex_gpio_wdata, hex_gpio_rdata = re.findall(REGEX_CURRENT, line)[0]
    current_ma = hex_current_to_float(hex_current) * 1e3
    gpio_wdata = int(hex_gpio_wdata, 16)
    gpio_rdata = int(hex_gpio_rdata, 16)
    info_pwren = f"SOM {COLOR_GOOD}ON {COLOR_NONE}"   if get_bit(gpio_rdata, GPIO_PIN_SOM_PWR_EN)    else f"SOM {COLOR_BAD}OFF{COLOR_NONE}"
    info_nrst  = f"nRST {COLOR_GOOD}HIGH{COLOR_NONE}" if get_bit(gpio_rdata, GPIO_PIN_SOM_nRST)      else f"nRST {COLOR_BAD}LOW{COLOR_NONE} "
    info_pgood = f"PGOOD {COLOR_GOOD}YES{COLOR_NONE}" if get_bit(gpio_rdata, GPIO_PIN_SOM_PGOOD)     else f"PGOOD {COLOR_BAD}NO{COLOR_NONE} "
    info_wdt   = f"WDT {COLOR_GOOD}OK{COLOR_NONE}  "  if get_bit(gpio_rdata, GPIO_PIN_SETUP_WDT_WDO) else f"WDT {COLOR_BAD}FAIL{COLOR_NONE}"
    return f"{current_ma:6.2f} mA | {info_pwren} | {info_nrst} | {info_pgood} | {info_wdt}"

########################################################
# LOGGING THREAD

output_logfile = None
def create_new_output_logfile():
    global output_logfile, device_info, logging_queue
    # close file if it is already 
    if output_logfile is not None:
        output_logfile.close()
    # create output file
    if logdir is not None:
        filepath = os.path.join(logdir, f'{device_info}-{datetime.now().strftime("%FT%H-%M-%S-%f")}.log')
    else:
        filepath = os.path.join('logs', f'{device_info}-{datetime.now().strftime("%FT%H-%M-%S-%f")}.log')
    output_logfile = open(filepath, 'a+')
    # put information to logging queue
    logging_queue.put([datetime.now(), 'INFO', f"Logging to file {filepath}"])

def logging():
    global logging_queue, output_logfile, device_info
    # iterate by there is data in the FIFO
    while not finished or not logging_queue.empty():
        # ensure that thread doens't overwhelm computer
        if logging_queue.empty():
            time.sleep(0.01)
        # read data from queue
        dt, label, raw_data = logging_queue.get()

        # select output printing color
        parsed_data = raw_data
        if label == ARG_LABEL:
            label = f"\033[92m[{ARG_LABEL}]\033[0m"

            # check if there is a parser as parameter
            if ARG_OUTPUT_PARSER == "current":
                parsed_data = parse_output_current(raw_data)

        elif label == "INFO":
            label = "\033[96m[INFO]\033[0m"
        elif label == "ONOFF":
            label = "\033[33m[ONOFF]\033[0m"
        elif label == "OVRCUR":
            label = "\033[41m[OVRCUR]\033[0m"
        elif label == "WARN":
            label = "\033[93m[WARN]\033[0m"
        elif label == "EXC":
            label = "\033[91m[EXC]\033[0m"
        else:
            label = f"[{label}]"
        
        # mount log line
        parsed_log_line = f"{dt.isoformat()} {device_info} {label} {parsed_data}"
        raw_log_line    = f"{dt.isoformat()} {device_info} {label} {raw_data}"
        
        # append to to logfile and output
        output_logfile.write(raw_log_line+'\n')
        output_logfile.flush()
        
        # print to output
        print(parsed_log_line)
        sys.stdout.flush()

        # if it is not from processor (action)
        if ARG_LABEL not in label:
            # log action to file
            with open(f"logs/{device_info}-actions.log", 'a+') as action_log:
                action_log.write(raw_log_line+'\n')
                action_log.flush()

# create first output file
create_new_output_logfile()
# start logging thread
logging_thread = threading.Thread(
    target=logging,
    daemon=True
)
logging_thread.start()

########################################################
# FIND TTY PORT

def get_tty_port(ftdi_id: str, ftdi_port: str) -> str:
    serial_port = None
    serial_url = f"ftdi://ftdi:4232h:{ftdi_id}/{ftdi_port}"
    serial_port = pyftdi.serialext.serial_for_url(url=serial_url, do_not_open=True)
    info = f"set serial to {serial_url}"
    logging_queue.put([datetime.now(), 'INFO', info])
    return serial_port

serial_device = get_tty_port(ftdi_id=ftdi_id, ftdi_port=ftdi_port)
if serial_device is None:
    logging_queue.put([datetime.now(), 'EXC', f"Couldn't find serial port with hwid = {ftdi_id}/{ftdi_port}"])
    finished = True
    logging_thread.join()
    exit(1)

# configure and open serial port
serial_device.baudrate = baudrate
serial_device.timeout = 0.1
serial_device.stopbits = serial.STOPBITS_ONE
serial_device.parity = serial.PARITY_EVEN if parity else serial.PARITY_NONE
serial_device.rtscts = rtscts
serial_device.open()
# log serial device
logging_queue.put([datetime.now(), 'INFO', f"Serial port: {serial_device}"])

########################################################
# SERIAL MONITOR THREAD 

def monitor_output():
    global finished, serial_device
    global logging_queue
    logging_queue.put([datetime.now(), 'INFO', "Listening serial..."])
    line = ""
    try:
        last_print_time = None
        while not finished:
            dat = serial_device.read(1)
            if dat is not None and dat:
                last_print_time = datetime.now()
                try:
                    dec = dat.decode('utf-8')
                except UnicodeDecodeError as err:
                    dec = 'x' + dat.hex().upper() + '\n'
                if dec.isprintable():
                    line += dec
                if dec == '\n':
                    logging_queue.put([datetime.now(), ARG_LABEL, line])
                    line = ""
            elif last_print_time is not None and (datetime.now() - last_print_time) >= timedelta(minutes=2.5):
                    last_print_time = datetime.now()
                    logging_queue.put([last_print_time, 'WARN', ">=2.5 minutes without output"])

    except Exception as exc:
        print(traceback.format_exc())
        logging_queue.put([datetime.now(), 'EXC', exc])
        finished = True
    finally:
        if line:
            logging_queue.put([datetime.now(), f'{ARG_LABEL}-FIN', line])

if not ARG_ENABLE_LOOPBACK:
    read_thread = threading.Thread(
        target=monitor_output,
        daemon=True
    )
    read_thread.start()

########################################################
# MAIN LOOP

error_counter = 0
bytes_to_send = list(range(256))

try:
    while not finished:
        if ARG_ENABLE_USER_INPUT:
            if select.select([sys.stdin,],[],[],0.0)[0]:
                data = input()
                data = data + '\n'
                serial_device.write(data.encode('utf-8'))
        time.sleep(0.1)

        if ARG_ENABLE_LOOPBACK:
            logging_queue.put([datetime.now(), ARG_LABEL, ""])
            logging_queue.put([datetime.now(), 'WARN', "Flush I/O buffers from serial device"])
            serial_device.reset_input_buffer()
            serial_device.reset_output_buffer()
            logging_queue.put([datetime.now(), 'WARN', "Test byte to byte"])
            for i in bytes_to_send:
                # Sequential writes and reads per byte
                data = f'{[i]}\n' 
                serial_device.write(data.encode('utf-8'))
                
                line = []
                end_of_line = False
                timeout = False
                
                start_time = datetime.now()
                while not end_of_line and not timeout:
                    read_char = serial_device.read(1)
                    if read_char is not None:
                        try:
                            dec = read_char.decode('utf-8')
                            if dec == '\n':
                                end_of_line = True
                            else:
                                line.append(dec)
                        except UnicodeDecodeError as err:
                            line.append('[]')
                            end_of_line = True
                    stop_time = datetime.now()
                    if (stop_time - start_time) >= timedelta(milliseconds=100):
                        timeout = True

                regex = re.search(r'\[(\w+)\]', ''.join(line))
                # Injected error
                if ARG_ENABLE_LOOPBACK_INJECTED and i == 0:
                    regex = None
                if regex is not None:
                    check = int(regex.group(1), base=10)
                    # Log if wrong frame
                    if i != check:
                        error_counter += 1
                        output = f'byte_error: counter ' + \
                                 f'\033[91m{error_counter:3d}\033[0m  sent \033[96m{i:3d}\033[0m  received \033[93m{check:3d}\033[0m'
                        logging_queue.put([datetime.now(), 'EXC', f"{output}"])
                else:
                    error_counter += 1
                    output = f'byte_error: counter ' + \
                             f'\033[91m{error_counter:3d}\033[0m  sent \033[96m{i:3d}\033[0m  received \033[93mNone\033[0m'
                    logging_queue.put([datetime.now(), 'EXC', f"{output}"])

except KeyboardInterrupt:
    logging_queue.put([datetime.now(), 'INFO', 'Closed by user'])
except Exception as err:
    print(traceback.format_exc())
    logging_queue.put([datetime.now(), 'EXC', err])
finally:
    # finish scripts
    finished = True
    read_thread.join()
    # close serial port
    if serial_device.isOpen():
        logging_queue.put([datetime.now(), 'INFO', 'Closing serial'])
        serial_device.close()
    logging_thread.join()
