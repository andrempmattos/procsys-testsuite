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

########################################################
###################### HOW TO USE ######################
########################################################

# 0. Always check for updated version on the github repository. Hardware/firmware/Application may change!
# 1. Update the FTDI_SERIAL_HOST_BOX for the box ID. It is the FTDI4232h ID, which can be retrieve from dmesg output (it is unique for each FTDI).
# 2. Update monitoring parameters as necessary, each script has a help that can be seen by executing the python script with the -h.

########################################################
##################### SCRIPT SETUP #####################
########################################################

logs-dir:
	-mkdir -p logs
	-mkdir -p logs/uart0
	-mkdir -p logs/uart1
	-mkdir -p logs/curr
	-mkdir -p logs/cmd
	-mkdir -p logs/val
	-mkdir -p logs/dupli
	-mkdir -p logs/dupli/uart0
	-mkdir -p logs/dupli/uart1
	-mkdir -p logs/dupli/curr
	-mkdir -p logs/dupli/cmd
	-mkdir -p logs/dupli/val

venv-install:
	python3 -m venv venv
	./venv/bin/pip3 install -r requirements.txt

init-experiment: logs-dir venv-install

########################################################
################# EXPERIMENT ASSIGNMENT ################
########################################################


# development board
BOARD_ID             = bdev
FTDI_SERIAL_HOST_BOX = FT78WXMC

########################################################
###################### Monitoring ######################
########################################################


## COMMAND INTERFACE ##############################
COMMAND_SCRIPT    = ./venv/bin/python3 command.py
COMMAND_ARGS     += --ftdi-url ftdi://ftdi:4232h:$(FTDI_SERIAL_HOST_BOX)/4
COMMAND_ARGS     += --current-threshold    1000 # mA
COMMAND_ARGS     += --overcurrent-on-time  100  # ms
COMMAND_ARGS     += --overcurrent-off-time 500 # ms
COMMAND_ARGS     += --current-samplerate   5 # Hz
COMMAND_ARGS     += --i2c-frequency        50 # KHz
COMMAND_ARGS     += --sut-baudrate-0       115200 # baud rate
COMMAND_ARGS     += --sut-baudrate-1       115200 # baud rate
## COMMAND_ARGS     += -v
## COMMAND_ARGS     += --board-name           0101 # hex board name # unused
## COMMAND_ARGS     += --host-baudrate        115200 # baud rate # unused
CALL_COMMAND = $(COMMAND_SCRIPT) $(COMMAND_ARGS)

## MONITOR INTERFACES ##############################
# default monitor script template
MONITOR_SCRIPT    = ./venv/bin/python3 monitor.py
MONITOR_ARGS     += --info $(BOARD_ID)
MONITOR_ARGS     += --baudrate 115200
MONITOR_ARGS	 += --ftdi-id $(FTDI_SERIAL_HOST_BOX)
## MONITOR_ARGS     += --parity # disabled
## MONITOR_AR	GS     += --rtscts # disabled

CALL_MONITOR_UART0 = $(MONITOR_SCRIPT) $(MONITOR_ARGS) --label UART0 --ftdi-port 1 --logdir ./logs/uart0 --enable-user-input
CALL_MONITOR_UART1 = $(MONITOR_SCRIPT) $(MONITOR_ARGS) --label UART1 --ftdi-port 2 --logdir ./logs/uart1 --enable-user-input

# CURRENT_SCRIPT     = ./venv/bin/python3 current.py
CALL_CURRENT      = $(MONITOR_SCRIPT) $(MONITOR_ARGS) --label CURR --ftdi-port 3 --logdir ./logs/curr --output-parser=current

# VALIDATION CALLS
CALL_VALIDATION_UART0 = $(MONITOR_SCRIPT) --info carrier-uart0 --baudrate 115200 --ftdi-id $(FTDI_SERIAL_HOST_BOX) --logdir ./logs/val --label CARRIER-UART0 --ftdi-port 1 --enable-loopback
CALL_VALIDATION_UART1 = $(MONITOR_SCRIPT) --info carrier-uart1 --baudrate 115200 --ftdi-id $(FTDI_SERIAL_HOST_BOX) --logdir ./logs/val --label CARRIER-UART1 --ftdi-port 2 --enable-loopback
CALL_VALIDATION_I2C   = $(MONITOR_SCRIPT) $(MONITOR_ARGS) --label CARRIER-I2C --ftdi-port 3 --logdir ./logs/val --info carrier-i2c

## COMMANDS ##############################
monitor-uart0: logs-dir
	script -ac "$(CALL_MONITOR_UART0)" --flush logs/dupli/uart0/$(MPFS_EXPERIMENT)-$(BOARD_ID)-$(shell date +%Y-%m-%d_%H-%M-%S).log

monitor-uart1: logs-dir
	script -ac "$(CALL_MONITOR_UART1)" --flush logs/dupli/uart1/$(HARV_EXPERIMENT)-$(BOARD_ID)-$(shell date +%Y-%m-%d_%H-%M-%S).log

command: logs-dir
	script -ac "$(CALL_COMMAND)" --flush logs/dupli/cmd/$(BOARD_ID)-$(shell date +%Y-%m-%d_%H-%M-%S).log

current: logs-dir
	script -ac "$(CALL_CURRENT)" --flush logs/dupli/curr/$(BOARD_ID)-$(shell date +%Y-%m-%d_%H-%M-%S).log

validation-uart0:
	script -ac "$(CALL_VALIDATION_UART0)" --flush logs/dupli/val/uart0-$(shell date +%Y-%m-%d_%H-%M-%S).log

validation-uart1:
	script -ac "$(CALL_VALIDATION_UART1)" --flush logs/dupli/val/uart1-$(shell date +%Y-%m-%d_%H-%M-%S).log

validation-i2c:
	script -ac "$(CALL_VALIDATION_I2C)" --flush logs/dupli/val/i2c-$(shell date +%Y-%m-%d_%H-%M-%S).log
