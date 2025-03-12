#!/usr/bin/python3

import serial
import serial.tools.list_ports
import sys
import threading
import time
from datetime import datetime, timedelta
from queue import Queue
import os

finished = False
logging_queue = Queue()

def get_tty_port(req_hwid: str) -> str:
    ports  = serial.tools.list_ports.comports()
    found_port = None
    for port, desc, hwid in sorted(ports):
        info = f"{port} {desc} {hwid}"
        logging_queue.put([datetime.now(), 'INFO', info])
        if found_port is None and req_hwid in info:
            found_port = port
    return found_port

def monitor_output():
    global finished, serial_device
    global logging_queue
    logging_queue.put([datetime.now(), 'INFO', "Listening serial..."])
    line = ""
    try:
        while not finished:
            dat = serial_device.read(1)
            if dat is not None and dat:
                try:
                    dec = dat.decode('utf-8')
                except UnicodeDecodeError as err:
                    dec = 'x' + dat.hex().upper() + '\n'
                if dec.isprintable():
                    line += dec
                if dec == '\n':
                    logging_queue.put([datetime.now(), 'UART', line])
                    line = ""

    except Exception as exc:
        logging_queue.put([datetime.now(), 'EXC', exc])
        finished = True
    finally:
        if line:
            logging_queue.put([datetime.now(), 'UART-FIN', line])

def logging():
    global port_arg
    global logging_queue
    logfile = None
    execution_started = False
    while not finished or not logging_queue.empty():
        dt, label, data = logging_queue.get()
        log_line = None
        # processor logging
        if label == "UART":
            label = "\033[92m[UART]\033[0m"
            log_line = f"{dt.isoformat()} {label} {data}"
            if "INIT" in data and logfile is not None and execution_started:
                logfile.close()
                logfile = None
            if logfile is None:
                filepath = os.path.join("out", f"{datetime.now().isoformat().replace(':','')}.log")
                logfile = open(filepath, 'w+')
                logging_queue.put([datetime.now(), 'INFO', f"Logging to file {filepath}"])
                execution_started = False
            execution_started = True if "INIT" in data else execution_started
            logfile.write(log_line+'\n')
            logfile.flush()
        # actions log
        else:
            if label == "INFO":
                label = "\033[96m[INFO]\033[0m"
            elif label == "WARN":
                label = "\033[93m[WARN]\033[0m"
            elif label == "EXC":
                label = "\033[91m[EXC]\033[0m"
            else:
                label = f"[{label}]"
            log_line = f"{dt.isoformat()} {port_arg.replace('/', '')} {label} {data}"
        print(log_line)
        sys.stdout.flush()

logging_thread = threading.Thread(
    target=logging,
    daemon=True
)
logging_thread.start()

port_arg = sys.argv[1]
baudrate = int(sys.argv[2])
parity = 0
rtscts = False

if '/dev/tty' in port_arg or 'COM' in port_arg:
    tty_port = port_arg
else:
    tty_port = get_tty_port(req_hwid=port_arg)
    if tty_port is None:
        finished = True
        logging_queue.put([datetime.now(), 'EXC', f"Couldn't find serial port with hwid = {port_arg}"])
        logging_thread.join()

if tty_port is not None:
    logging_queue.put([datetime.now(), 'INFO', f"Serial port: {tty_port}"])

    serial_device = serial.Serial()
    serial_device.baudrate = baudrate
    serial_device.port = tty_port
    serial_device.timeout = 0.1
    serial_device.stopbits = serial.STOPBITS_ONE
    serial_device.parity = serial.PARITY_EVEN if parity == "even" else serial.PARITY_NONE
    serial_device.rtscts = rtscts

    serial_device.open()

    read_thread = threading.Thread(
        target=monitor_output,
        daemon=True
    )

    try:
        read_thread.start()
        while not finished:
            time.sleep(0.1) 
            # if select.select([sys.stdin,],[],[],0.0)[0]:
            data = input()
            data = data + '\n'
            serial_device.write(data.encode('utf-8'))
            serial_device.flush()
        read_thread.join()

    except KeyboardInterrupt:
        logging_queue.put([datetime.now(), 'INFO', 'Closed by user'])
    except Exception as err:
        logging_queue.put([datetime.now(), 'EXC', err])
    finally:
        logging_queue.put([datetime.now(), 'INFO', 'Closing serial'])
        finished = True
        # read_thread.join()
        if serial_device.isOpen():
            serial_device.close()
        logging_thread.join()
