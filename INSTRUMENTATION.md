# Hardware

### Available target boards

`som-25tfe` : [Available here](https://shop.trenz-electronic.de/en/TEM0007-01-CAA11-A-Microchip-PolarFire-SoC-FPGA-25T-FE-1-GByte-LPDDR4-SDRAM-4-x-5-cm?c=718) \
\> *Trenz Electronic SoM for MPFS 25T-FE  (TEM0007-01-CAA11-A: MPFS025T-FCVG484E)*

`som-250tfe` : [Available here](https://shop.trenz-electronic.de/en/TEM0007-01-CHE11-A-Microchip-PolarFire-SoC-FPGA-250T-FE-1-GByte-LPDDR4-SDRAM-4-x-5-cm?c=718) \
\> *Trenz Electronic SoM for MPFS 250T-FE (TEM0007-01-CHE11-A: MPFS250T-FCVG484E)*


#### Power comsumption estimation
| Device   	| Design                   	| Estimated power (W) 	| Current in VIN (mA) 	| Other stuff in VIN (mA) 	| Total in VIN (mA) 	|
|----------	|--------------------------	|---------------------	|---------------------	|-------------------------	|-------------------	|
| MPFS250T 	| Only HARV-SoC            	| 0.3                 	| 91                  	| 50                      	| 141               	|
| MPFS25T  	| Only HARV-SoC            	| 0.22                	| 67                  	| 50                      	| 117               	|
| MPFS250T 	| Only 5x core RISC-V      	| 1.16                	| 352                 	| 50                      	| 402               	|
| MPFS25T  	| Only 5x core RISC-V      	| 1.1                 	| 333                 	| 50                      	| 383               	|
| MPFS250T 	| Max FPGA/SoC utilization 	| 3.4                 	| 1030                	| 150                     	| 1180              	|
|          	|                          	|                     	|                     	| Reasonable assumption:  	| 700               	|
|          	|                          	|                     	|                     	| Power supply for max:   	| 3000              	|


### Supporting boards

> Supporting boards for debug and environmental experiments. Required for `som-25tfe` and `som-250tfe`

The need for the system is to test one or multiple daughterboards that use the Trenz connector specification, and to have peripheral breakouts from the daughterboard into the motherboard, since currently there is no physical interface to connect the board to the external world. Some design constraints are added, since the boards will be tested under irradiation, there is the need for most of the components in the motherboard to be radiation tolerant/insensitive, as this maximizes the daughterboard utilization and lifespan (it can be used in multiple experiments). The motherboard needs to take information from the daughterboard complex devices and relay it to a computer terminal that may be located up to 100 meters from the irradiation room.


| ID  | Requirement                                                                                              | Note                                                                                                                                                                                                     |
| --- | -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | The system should operate at a minimum frequency of 1 MHz                                                | To have a reasonable response time in case of SEL                                                                                                                                                        |
| 2   | The system should operate at a max wired distance of 100 meters                                          | Distance from the control room to the irradiation room                                                                                                                                                   |
| 3   | The system should be able to control peripheral devices in the motherboard                               |                                                                                                                                                                                                          |
| 4   | The system should be able to house/connect different daughter boards                                     | Using the Trenz connector specification                                                                                                                                                                  |
| 5   | The system should be able to measure temperature in the irradiation room                                 |                                                                                                                                                                                                          |
| 6   | The system should be able to measure voltage/current from the daughter board                             |                                                                                                                                                                                                          |
| 7   | The system shall have a RTC to keep track of time                                                        |                                                                                                                                                                                                          |
| 8   | The system shall be able to output timing/timestamp data to a terminal computer in the control room      |                                                                                                                                                                                                          |
| 9   | The system shall have a watchdog to monitor daughter board hangups, log the error and restart the system |                                                                                                                                                                                                          |
| 10  | The system shall be able to detect Latchups and cut the power as needed                                  | It should log the SEL and report back to the terminal                                                                                                                                                    |
| 11  | The motherboard shall be able to control memories or external devices                                    | These external devices could be connected directly to the PCB or via a ribbon. What is the most common connection type used to these devices? ==There is also a power budget requirement for this part== |
| 12  | All sensitive volumes of the devices shall be perpendicular to the beam                                  | To maximize cross section                                                                                                                                                                                |
| 13  | All motherboard devices shall be tolerant/inmune to ??? LET                                              | And maybe add that they should use COTS components                                                                                                                                                       |
| 14  | The PCB size should be less or equal to 5x10 cm                                                          |                                                                                                                                                                                                          |
| 15  | The system shall be able to interface with a host computer with minimal drivers                          | It should be able to plug and run into a USB 2.0 port and run from Windows/Linux                                                                                                                         |


#### SoM experiment carrier
`som-exp-carrier` : To be manufactured \
\> *Custom carrier board for Trenz Electronic SoM modules* \
\> *Fabrication files available in: `som-exp-carrier/out/fabpack_v0.1.zip`* \
\> *Designed to be used in environmental testing*


##### Component selection for `som-exp-carrier`

| Component          	        | Part Number          	                    |
|---------------------------- |------------------------------------------ |
| Power supply       	        | LP38693MP-3.3/NOPB / MIC29302AWD          |
| RS485 transceiver  	        | SN65HVD77D           	                    |
| I2C Extender       	        | P82B96DR             	                    |
| CAN for I2C       	        | TCAN1042HGVDRQ1      	                    |
| LVDS tranceivers (JTAG)     | SN65LVDT14 / SN65LVDT41                   | 
| IO Extender (I2C)           | TCAL9535                                  |
| Level shifter               | SN74AXC8T245QPWRQ1                        |
| Temperature sensor 	        | TMP100-Q1            	                    |
| Power sensor       	        | INA3221-Q1           	                    | 
| Watchdog           	        | TPS35AA38AGADDFRQ1   	                    |
| Connector: RJ45 (1x3)       | 09455511123                               |
| Connector: Power Molex      | 39-30-0020                                |
| SoM daughterboard           | LSHM-150-04.0-L-DV-A-S-K-TR               |
| SoM daughterboard           | LSHM-130-04.0-L-DV-A-S-K-TR               |
| PCIe connector (straddle)   | 10025026-10001TLF                         |
| [Extra] Housing Power Molex | 39-01-2020                                |
| [Extra] Power Molex cable   | 215325-1021                               |

Whitepapers:
LVDS: [Extending interfaces with differential protocols](https://www.ti.com/lit/an/slla142/slla142.pdf?ts=1709477472033) \
CAN: [Reference Design for I2C Range Extension: I2C with CAN](https://www.ti.com/lit/ug/tiduei0/tiduei0.pdf?ts=1706800958116&ref_url=https%253A%252F%252Fwww.google.com%252F)

#### Experiment host board
`exp-host` : To be manufactured \
\> *Custom board for interfaces and computer access in the host side* \
\> *Fabrication files available in: `exp-host/out/fabpack_v0.1.zip`* \
\> *Designed to be used in the irradiation facilities with long cables*