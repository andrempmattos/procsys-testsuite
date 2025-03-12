# Sample project for SMF2000

## Requirements
> These applications must be in the PATH
- `Make`
- `Vivado`
- `Libero`

## Simulation commands

### Run simulation based on `sim/top_tb.vhd` using Vivado
```
make vivado-simulate
```
Generates output file `out/uart.log`
### Open simulation result based on `sim/top_tb_behav.wcfg`
```
make vivado-open-sim
```

## Synthesis commands
Synthesize the project for SMF2000 board
> all files for this project are in `fpga/` folder
```
make libero-project
make libero-bitstream
make libero-fpga
make uart
```