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
    uint16_t len = 0;
    char buf[LOG_MSG_SIZE] = {0};

    va_list args;
    va_start(args, fmt);
    len = vsprintf(buf, fmt, args);
    va_end(args);

    MSS_UART_polled_tx(&g_mss_uart0_lo, (const uint8_t*)buf, len);
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
