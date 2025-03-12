#include <stdio.h>
#include <string.h>
#include <stdarg.h>

#include "mpfs_hal/mss_hal.h"
#include "inc/common.h"

#include <embench/support.h>

/* Double buffering scheme for log messages: appcores are producers and moncore is consumer. 
 * In other words, appcores generate messages to be printed, but just send them to the moncore,
 * which actually printf the message. This avoid concurrency problems. Still, moncore can break
 * a few messages if an exception occours, but this is what we want... not delaying exceptions. 
 */

char log_buffer_0[LOG_BUFFER_SIZE] = {0};
char log_buffer_1[LOG_BUFFER_SIZE] = {0};

uint16_t log_buffer_index_0 = 0;
uint16_t log_buffer_index_1 = 0;

bool unblock_pooling = false;

int which_in_use = 0;
int which_to_save = -1;
int sessions_logged = 0;

void log_from_appcore_noheader(HART_SHARED_DATA *h_shared, const char *fmt, ...) 
{
    uint16_t len = 0;
    char buf[LOG_MSG_SIZE] = {0};

    va_list args;
    va_start(args, fmt);
    len = vsprintf(buf, fmt, args);
    va_end(args);

    spinlock(&h_shared->mutex_uart0);
    
    if(which_in_use == 0) 
    {
        sprintf(log_buffer_0 + log_buffer_index_0, buf);
        log_buffer_index_0 += len;
        sessions_logged++;
    }
    else 
    {
        sprintf(log_buffer_1 + log_buffer_index_1, buf);
        log_buffer_index_1 += len;
        sessions_logged++;
    }

    if(sessions_logged >= BUFFER_DEPTH)     // Generates data up to n * BUF_SIZE 
    {   
        which_to_save = which_in_use;
        which_in_use = (which_in_use+1)%2;
        sessions_logged = 0;
        unblock_pooling = true;   // Unblock HART0 to use this buffer
    }

    spinunlock(&h_shared->mutex_uart0);
}


void log_from_appcore(HART_SHARED_DATA *h_shared, const char *fmt, ...) 
{
    uint16_t len = 0;
    char buf[LOG_MSG_SIZE] = {0};

    len = sprintf(buf, "[HART%d] ", read_csr(mhartid));
    
    va_list args;
    va_start(args, fmt);
    len += vsprintf(buf+len, fmt, args);
    va_end(args);

    spinlock(&h_shared->mutex_uart0);
    
    if(which_in_use == 0) 
    {
        sprintf(log_buffer_0 + log_buffer_index_0, buf);
        log_buffer_index_0 += len;
        sessions_logged++;
    }
    else 
    {
        sprintf(log_buffer_1 + log_buffer_index_1, buf);
        log_buffer_index_1 += len;
        sessions_logged++;
    }

    if(sessions_logged >= BUFFER_DEPTH)     // Generates data up to n * BUF_SIZE 
    {   
        which_to_save = which_in_use;
        which_in_use = (which_in_use+1)%2;
        sessions_logged = 0;
        unblock_pooling = true;   // Unblock HART0 to use this buffer
    }

    spinunlock(&h_shared->mutex_uart0);
}

void forward_log_from_appcore(HART_SHARED_DATA *h_shared) 
{
    /* Print the accumulated messages */
    if(unblock_pooling == true) 
    {
        spinlock(&h_shared->mutex_uart0);
        
        if(which_to_save == 0) 
        {
            /* Print messages */
            MSS_UART_polled_tx(h_shared->g_mss_uart0_lo, (const uint8_t*)log_buffer_0, log_buffer_index_0);
            /* Clear array */
            memset(log_buffer_0, 0, LOG_BUFFER_SIZE);
            log_buffer_index_0 = 0;
        }
        else 
        {
            MSS_UART_polled_tx(h_shared->g_mss_uart0_lo, (const uint8_t*)log_buffer_1, log_buffer_index_1);
            /* Clear array */
            memset(log_buffer_1, 0, LOG_BUFFER_SIZE);
            log_buffer_index_1 = 0;
        }

        unblock_pooling = false;

        spinunlock(&h_shared->mutex_uart0);
    }
}


void log_from_moncore_noheader_nospinlock(const char *fmt, ...)
{
    char msg[LOG_MSG_SIZE] = {0};

    va_list args;
    va_start(args, fmt);
    vprintf(fmt, args);
    va_end(args);
}

void log_from_moncore(HART_SHARED_DATA *h_shared, const char *fmt, ...) 
{
    uint16_t len = 0;
    char buf[LOG_MSG_SIZE] = {0};

    len = sprintf(buf, "[HART%d] ", read_csr(mhartid));
    
    va_list args;
    va_start(args, fmt);
    len += vsprintf(buf+len, fmt, args);
    va_end(args);

    spinlock(&h_shared->mutex_uart0);
    MSS_UART_polled_tx(h_shared->g_mss_uart0_lo, (const uint8_t*)buf, len);
    spinunlock(&h_shared->mutex_uart0);
}

void print_results(HART_SHARED_DATA *h_shared, uint32_t *errors, uint32_t *execs, uint32_t *runtime, uint32_t cycle)
{
    uint16_t len = 0;
    char buf[LOG_MSG_SIZE];

    uint64_t hart_id = read_csr(mhartid);

    len = sprintf(buf, "[HART%d] [BENCHMARK_END] embench_results: %u\n", hart_id, cycle);

    len += sprintf(buf+len, "[HART%d]   num_errors = [ ", hart_id);
	for (uint8_t i = 0; i < (WORKLOADS-1); i++)
	{
        len += sprintf(buf+len, "%u, ", errors[i]);
	}
	len += sprintf(buf+len, "%u ]\n", errors[WORKLOADS-1]);

    len += sprintf(buf+len, "[HART%d]   num_execs = [ ", hart_id);
	for (uint8_t i = 0; i < (WORKLOADS-1); i++)
	{
        len += sprintf(buf+len, "%u, ", execs[i]);
	}
	len += sprintf(buf+len, "%u ]\n", execs[WORKLOADS-1]);

    len += sprintf(buf+len, "[HART%d]   runtime (ms) = [ ", hart_id);
	for (uint8_t i = 0; i < (WORKLOADS-1); i++)
	{
        len += sprintf(buf+len, "%u, ", runtime[i]);
	}
	len += sprintf(buf+len, "%u ]\n\n", runtime[WORKLOADS-1]);

    log_from_appcore_noheader(h_shared, buf);
}

void run_workload
(
	char *bench_name,
	void (*initialise_benchmark)(void),
	void (*warm_caches)(int),
	void (*benchmark)(void),
	int (*verify_benchmark)(int),
    unsigned int (*get_errors)(void),
    unsigned int (*get_executions)(void),
    HART_SHARED_DATA *h_shared,
    uint8_t *workload_index,
    uint32_t *errors, 
    uint32_t *execs, 
    uint32_t *runtime
)
{
    // wdt_feed();

	#if (VERBOSE == 1)
        // spinlock(&h_shared->mutex_uart0);
		log_from_appcore_noheader(h_shared, "[HART%d] %s\n", read_csr(mhartid), bench_name);
	#endif

	initialise_benchmark();

	warm_caches(WARMUP_HEAT);

	start_trigger();
    benchmark();
	stop_trigger();

	errors[*workload_index] = get_errors();
    execs[*workload_index] = get_executions(); 
	runtime[*workload_index] = get_runtime();

	#if (VERBOSE == 1)
		log_from_appcore_noheader(h_shared, "[HART%d]  errors = %d\n", read_csr(mhartid), errors[*workload_index]);
		log_from_appcore_noheader(h_shared, "[HART%d]  execs = %d\n", read_csr(mhartid), execs[*workload_index]);
		log_from_appcore_noheader(h_shared, "[HART%d]  runtime = %d ms\n\n", read_csr(mhartid), runtime[*workload_index]);
        // spinunlock(&h_shared->mutex_uart0);
	#endif

    ++(*workload_index);
}


void run_benchmark
(    
    HART_SHARED_DATA *h_shared,
    uint32_t *errors, 
    uint32_t *execs, 
    uint32_t *runtime,
    mss_watchdog_num_t wdt
) 
{
    uint8_t workload_index = 0;

    #if (ENABLE_WORKLOAD_AHA_MONT64 == 1)
        run_workload(
            "aha-mont64",
            &mont64_initialise_benchmark, &mont64_warm_caches, &mont64_benchmark, &mont64_verify_benchmark,
            &mont64_get_errors, &mont64_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_CRC32 == 1)
        run_workload(
            "crc32",
            &crc32_initialise_benchmark, &crc32_warm_caches, &crc32_benchmark, &crc32_verify_benchmark, 
            &crc32_get_errors, &crc32_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_CUBIC == 1)
        run_workload(
            "cubic",
            &cubic_initialise_benchmark, &cubic_warm_caches, &cubic_benchmark, &cubic_verify_benchmark,
            &cubic_get_errors, &cubic_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_EDN == 1)
        run_workload(
            "edn",
            &edn_initialise_benchmark, &edn_warm_caches, &edn_benchmark, &edn_verify_benchmark,
            &edn_get_errors, &edn_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_HUFFBENCH == 1)
        run_workload(
            "huffbench",
            &huffbench_initialise_benchmark, &huffbench_warm_caches, &huffbench_benchmark, &huffbench_verify_benchmark,
            &huffbench_get_errors, &huffbench_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_MATMULT == 1)
        run_workload(
            "matmult",
            &matmult_initialise_benchmark, &matmult_warm_caches, &matmult_benchmark, &matmult_verify_benchmark,
            &matmult_get_errors, &matmult_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_MINVER == 1)
        run_workload(
            "minver",
            &minver_initialise_benchmark, &minver_warm_caches, &minver_benchmark, &minver_verify_benchmark,
            &minver_get_errors, &minver_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_NBODY == 1)
        run_workload(
            "nbody",
            &nbody_initialise_benchmark, &nbody_warm_caches, &nbody_benchmark, &nbody_verify_benchmark,
            &nbody_get_errors, &nbody_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_NETTLE_AES == 1)
        run_workload(
            "nettle-aes",
            &aes_initialise_benchmark, &aes_warm_caches, &aes_benchmark, &aes_verify_benchmark,
            &aes_get_errors, &aes_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_NETTLE_SHA256 == 1)
        run_workload(
            "nettle-sha256",
            &sha256_initialise_benchmark, &sha256_warm_caches, &sha256_benchmark, &sha256_verify_benchmark,
            &sha256_get_errors, &sha256_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_NSICHNEU == 1)
        run_workload(
            "nsichneu",
            &nsichneu_initialise_benchmark, &nsichneu_warm_caches, &nsichneu_benchmark, &nsichneu_verify_benchmark,
            &nsichneu_get_errors, &nsichneu_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_PICOJPEG == 1)
        run_workload(
            "picojpeg",
            &picojpeg_initialise_benchmark, &picojpeg_warm_caches, &picojpeg_benchmark, &picojpeg_verify_benchmark,
            &picojpeg_get_errors, &picojpeg_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_QRDUINO == 1)
        run_workload(
            "qrduino",
            &qrduino_initialise_benchmark, &qrduino_warm_caches, &qrduino_benchmark, &qrduino_verify_benchmark, 
            &qrduino_get_errors, &qrduino_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_SGLIB_COMBINED == 1)
        run_workload(
            "sglib-combined",
            &sglib_initialise_benchmark, &sglib_warm_caches, &sglib_benchmark, &sglib_verify_benchmark,
            &sglib_get_errors, &sglib_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_SLRE == 1)
        run_workload(
            "slre",
            &slre_initialise_benchmark, &slre_warm_caches, &slre_benchmark, &slre_verify_benchmark,
            &slre_get_errors, &slre_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_ST == 1)
        run_workload(
            "st",
            &st_initialise_benchmark, &st_warm_caches, &st_benchmark, &st_verify_benchmark,
            &st_get_errors, &st_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_STATEMATE == 1)
        run_workload(
            "statemate",
            &statemate_initialise_benchmark, &statemate_warm_caches, &statemate_benchmark, &statemate_verify_benchmark,
            &statemate_get_errors, &statemate_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_UD == 1)
        run_workload(
            "ud",
            &ud_initialise_benchmark, &ud_warm_caches, &ud_benchmark, &ud_verify_benchmark,
            &ud_get_errors, &ud_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif

    #if (ENABLE_WORKLOAD_WIKISORT == 1)
        run_workload(
            "wikisort",
            &wikisort_initialise_benchmark, &wikisort_warm_caches, &wikisort_benchmark, &wikisort_verify_benchmark,
            &wikisort_get_errors, &wikisort_get_executions, h_shared, &workload_index, errors, execs, runtime
        );
        MSS_WD_reload(wdt);
    #endif
}







