# Software

This folder contains base files for the proposed reliability benchmarks based on Embench v1.0. These are not complete source files, nor ported to a specific platform, instead they provide the modified Embench as a library and a pseudo main.c to show an usage example. 

Benchmark created based on `Embench 1.0`.

| Workload       | Description                   | Branch | Memory | Compute | Floating Point | Dynamic Alloc | Included  |
|----------------| ------------------------------| -------| -------|---------|----------------|---------------|-----------|
| AHA_MONT64     | Montgomery multiplication     | low    | low    | high    | no             | no            | yes       |
| CRC32          | CRC error checking 32b        | high   | med    | low     | no             | no            | yes       |
| CUBIC          | Cubic root solver             | low    | med    | med     | yes            | no            | yes       |
| EDN            | More general filter           | low    | high   | med     | no             | no            | yes       |
| HUFFBENCH      | Compress/decompress           | med    | med    | med     | no             | yes           | no        |
| MATMULT        | Integer matrix multiply       | med    | med    | med     | no             | no            | yes       |
| MINVER         | Matrix inversion              | high   | low    | med     | yes            | no            | yes       |
| NBODY          | Satellite N body, large data  | med    | low    | high    | yes            | no            | yes       |
| NETTLE_AES     | Encrypt/decrypt               | med    | high   | low     | no             | no            | yes       |
| NETTLE_SHA256  | Crytographic hash             | low    | med    | med     | no             | no            | yes       |
| NSICHNEU       | Large - Petri net             | med    | high   | low     | no             | no            | yes       |
| PICOJPEG       | JPEG                          | med    | med    | high    | no             | no            | no        |
| QRDUINO        | QR codes                      | low    | med    | med     | no             | yes           | no        |
| SGLIB_COMBINED | Simple Generic Library for C  | high   | high   | low     | no             | yes           | no        |
| SLRE           | Regex                         | high   | med    | med     | no             | no            | yes       |
| ST             | Statistics                    | med    | low    | high    | yes            | no            | yes       |
| STATEMATE      | State machine (car window)    | high   | high   | low     | no             | no            | yes       |
| UD             | LUD composition int           | med    | low    | high    | no             | no            | yes       |
| WIKISORT       | Merge sort                    | med    | med    | med     | no             | no            | yes       |

## Keywords on UART log
- `[INIT]` marks application start
- `[INIT_HART1]` marks HART1 start
- `[BOARD]` board id
- `[APP]` application identifier
- `[VERSION]` version
- `[RST]` last reset cause
- `[HARTn]` where `n` is a number from 0 to 4. Messages usually have this header to notify the message source since channel is shared between all HARTs.
- `[BENCHMARK_START]` marks the benchmark start
- `[BENCHMARK_END]` marks the benchmark end
- `[BENCHMARK_ERROR]` represents a workload error in the specific cycle. It includes which workload failed, when it failed and the number of failures.
- `[ERROR]` used for CACHE L2 and BEU errors
- `[INJECT]` used to notify when a fault is injected
- `[TRAP]` in `mss_mtrap.c` is used for getting exceptions 
- `[WDT1]` when HART1 stop responding
- `[TVS]` temperature and voltage sensor data

## Main modifications from original benchmark

- Merge all workloads in a single executable. The original approach makes sense for performance benchmarking (individual programs), whereas it does not work for a radiation test, in which reprogramming the device is a difficult procedure.
- Add a error check/report per workload individual execution, instead of just the last. Since radiation-induced errors can occur at any time, we need to observe all workload executions performed per cycle due to the runtime equalization `LOCAL_SCALE_FACTOR * CPU_MHZ` strategy.
- Change of main entry point and scripts infrasctructure since our purpose is different. We want to have a diverse set of workloads to expose errors during execution caused by radiation instead of assesing precise/comparable performance metrics. 

