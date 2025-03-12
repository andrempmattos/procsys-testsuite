/*******************************************************************************
 * Copyright 2019-2022 Microchip FPGA Embedded Systems Solution.
 *
 * SPDX-License-Identifier: MIT
 *
 * MPFS HAL Embedded Software example
 *
 */
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

#ifndef MPFS_HAL_SHARED_MEM_ENABLED
#endif

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
 * extern variables
 */



/**
 * functions
 */
void log_from_appcore_noheader(HART_SHARED_DATA *h_shared, const char *fmt, ...) ;
void log_from_appcore(HART_SHARED_DATA *h_shared, const char *fmt, ...);
void forward_log_from_appcore(HART_SHARED_DATA *h_shared);
void log_from_moncore_noheader_nospinlock(const char *fmt, ...);
void log_from_moncore(HART_SHARED_DATA *h_shared, const char *fmt, ...); 

#endif /* COMMON_H_ */
