/*******************************************************************************
 *
 * Used for common defines across application code
 *
 */

#ifndef COMMON_H_
#define COMMON_H_

#include <stdint.h>
#include "mpfs_hal/mss_hal.h"
#include "drivers/mss/mss_mmuart/mss_uart.h"
#include "drivers/mss/mss_watchdog/mss_watchdog.h"

#ifndef MPFS_HAL_SHARED_MEM_ENABLED
#endif

#define ENABLE_WORKLOAD_AHA_MONT64      1  /* Montgomery multiplication                                                         */
#define ENABLE_WORKLOAD_CRC32           1  /* CRC error checking 32b                                                            */
#define ENABLE_WORKLOAD_CUBIC           1  /* Cubic root solver                                                                 */
#define ENABLE_WORKLOAD_EDN             1  /* More general filter                                                               */
#define ENABLE_WORKLOAD_HUFFBENCH       0  /* Compress/decompress              - OFF due to unsafe dynamic memory allocation    */
#define ENABLE_WORKLOAD_MATMULT         1  /* Integer matrix multiply                                                           */
#define ENABLE_WORKLOAD_MINVER          1  /* Matrix inversion                                                                  */
#define ENABLE_WORKLOAD_NBODY           1  /* Satellite N body, large data                                                      */
#define ENABLE_WORKLOAD_NETTLE_AES      1  /* Encrypt/decrypt                                                                   */
#define ENABLE_WORKLOAD_NETTLE_SHA256   1  /* Crytographic hash                                                                 */
#define ENABLE_WORKLOAD_NSICHNEU        1  /* Large - Petri net                                                                 */
#define ENABLE_WORKLOAD_PICOJPEG        0  /* JPEG                             - OFF due to memory space limitation and scope   */
#define ENABLE_WORKLOAD_QRDUINO         0  /* QR codes                         - OFF due to memory space limitation and scope   */
#define ENABLE_WORKLOAD_SGLIB_COMBINED  0  /* Simple Generic Library for C     - OFF due to unsafe dynamic memory allocation    */
#define ENABLE_WORKLOAD_SLRE            1  /* Regex                                                                             */
#define ENABLE_WORKLOAD_ST              1  /* Statistics                                                                        */
#define ENABLE_WORKLOAD_STATEMATE       1  /* State machine (car window)                                                        */
#define ENABLE_WORKLOAD_UD              1  /* LUD composition int                                                               */
#define ENABLE_WORKLOAD_WIKISORT        1  /* Merge sort                                                                        */

#define WORKLOADS   \
    (ENABLE_WORKLOAD_AHA_MONT64 + ENABLE_WORKLOAD_CRC32 + ENABLE_WORKLOAD_CUBIC + ENABLE_WORKLOAD_EDN + ENABLE_WORKLOAD_HUFFBENCH + \
    ENABLE_WORKLOAD_MATMULT + ENABLE_WORKLOAD_MINVER + ENABLE_WORKLOAD_NBODY + ENABLE_WORKLOAD_NETTLE_AES + ENABLE_WORKLOAD_NETTLE_SHA256 + \
    ENABLE_WORKLOAD_NSICHNEU + ENABLE_WORKLOAD_PICOJPEG + ENABLE_WORKLOAD_QRDUINO + ENABLE_WORKLOAD_SGLIB_COMBINED + ENABLE_WORKLOAD_SLRE + \
    ENABLE_WORKLOAD_ST + ENABLE_WORKLOAD_STATEMATE + ENABLE_WORKLOAD_UD + ENABLE_WORKLOAD_WIKISORT)

typedef struct HART_SHARED_DATA_
{
    uint64_t init_marker;
    volatile long mutex_uart0;
    mss_uart_instance_t *g_mss_uart0_lo;
} HART_SHARED_DATA;


#define LOG_MSG_SIZE        1024
#define BUFFER_DEPTH        1
#define LOG_BUFFER_SIZE     LOG_MSG_SIZE * BUFFER_DEPTH


/**
 * functions
 */
void log_from_appcore_noheader(HART_SHARED_DATA *h_shared, const char *fmt, ...) ;
void log_from_appcore(HART_SHARED_DATA *h_shared, const char *fmt, ...);
void forward_log_from_appcore(HART_SHARED_DATA *h_shared);
void log_from_moncore_noheader_nospinlock(const char *fmt, ...);
void log_from_moncore(HART_SHARED_DATA *h_shared, const char *fmt, ...); 

void print_results(HART_SHARED_DATA *h_shared, uint32_t *errors, uint32_t *execs, uint32_t *runtime, uint32_t cycle);
void run_workload(char *bench_name, void (*initialise_benchmark)(void),
	void (*warm_caches)(int), void (*benchmark)(void), int (*verify_benchmark)(int),    
    unsigned int (*get_errors)(void), unsigned int (*get_executions)(void),
    HART_SHARED_DATA *h_shared, uint8_t *workload_index, uint32_t *errors, uint32_t *execs, uint32_t *runtime);
void run_benchmark(HART_SHARED_DATA *h_shared, uint32_t *errors, uint32_t *execs, uint32_t *runtime, mss_watchdog_num_t wdt);

#endif /* COMMON_H_ */
