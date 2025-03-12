/*
 * File: tasks.h
 * Description: Tasks creation and implementation. 
 * Authors: andrempmattos, Douglasas, benmezger
 * Date: 2022-06-26
 */

#ifndef TASKS_H
#define TASKS_H


#include <drivers/mss/mss_watchdog/mss_watchdog.h>

/* FreeRTOS includes. */
#include <FreeRTOS.h>
#include <task.h>
#include <queue.h>

#include "common.h"

#define ENABLE_WORKLOAD_AHA_MONT64      1  /* Montgomery multiplication                                                         */
#define ENABLE_WORKLOAD_CRC32           1  /* CRC error checking 32b                                                            */
#define ENABLE_WORKLOAD_CUBIC           1  /* Cubic root solver                                                                 */
#define ENABLE_WORKLOAD_EDN             1  /* More general filter                                                               */
#define ENABLE_WORKLOAD_HUFFBENCH       0  /* Compress/decompress              - OFF due to unsafe dynamic memory allocation    */
#define ENABLE_WORKLOAD_MATMULT         1  /* Integer matrix multiply                                                           */
#define ENABLE_WORKLOAD_MINVER          0  /* Matrix inversion                                                                  */
#define ENABLE_WORKLOAD_NBODY           0  /* Satellite N body, large data                                                      */
#define ENABLE_WORKLOAD_NETTLE_AES      0  /* Encrypt/decrypt                                                                   */
#define ENABLE_WORKLOAD_NETTLE_SHA256   0  /* Crytographic hash                                                                 */
#define ENABLE_WORKLOAD_NSICHNEU        0  /* Large - Petri net                                                                 */
#define ENABLE_WORKLOAD_PICOJPEG        0  /* JPEG                             - OFF due to memory space limitation and scope   */
#define ENABLE_WORKLOAD_QRDUINO         0  /* QR codes                         - OFF due to memory space limitation and scope   */
#define ENABLE_WORKLOAD_SGLIB_COMBINED  0  /* Simple Generic Library for C     - OFF due to unsafe dynamic memory allocation    */
#define ENABLE_WORKLOAD_SLRE            0  /* Regex                            - OFF due to eNVM limitation with FreeRTOS       */
#define ENABLE_WORKLOAD_ST              0  /* Statistics                       - OFF due to eNVM limitation with FreeRTOS       */
#define ENABLE_WORKLOAD_STATEMATE       0  /* State machine (car window)                                                        */
#define ENABLE_WORKLOAD_UD              0  /* LUD composition int              - OFF due to eNVM limitation with FreeRTOS       */
#define ENABLE_WORKLOAD_WIKISORT        0  /* Merge sort                       - OFF due to eNVM limitation with FreeRTOS       */

#define WORKLOADS   \
    (ENABLE_WORKLOAD_AHA_MONT64 + ENABLE_WORKLOAD_CRC32 + ENABLE_WORKLOAD_CUBIC + ENABLE_WORKLOAD_EDN + ENABLE_WORKLOAD_HUFFBENCH + \
    ENABLE_WORKLOAD_MATMULT + ENABLE_WORKLOAD_MINVER + ENABLE_WORKLOAD_NBODY + ENABLE_WORKLOAD_NETTLE_AES + ENABLE_WORKLOAD_NETTLE_SHA256 + \
    ENABLE_WORKLOAD_NSICHNEU + ENABLE_WORKLOAD_PICOJPEG + ENABLE_WORKLOAD_QRDUINO + ENABLE_WORKLOAD_SGLIB_COMBINED + ENABLE_WORKLOAD_SLRE + \
    ENABLE_WORKLOAD_ST + ENABLE_WORKLOAD_STATEMATE + ENABLE_WORKLOAD_UD + ENABLE_WORKLOAD_WIKISORT)

/* Task definitions */
#define EMBENCH_TASK_STACK_SIZE         2*configMINIMAL_STACK_SIZE
#define EMBENCH_TASK_PRIORITY           1
#define HOUSEKEEPING_TASK_STACK_SIZE    2*configMINIMAL_STACK_SIZE
#define HOUSEKEEPING_TASK_PRIORITY      2

static uint16_t embench_tasks_stack[WORKLOADS] = {512,512,512,512,512};

/* Struct */
typedef struct
{
   uint32_t errors;
   uint32_t execs; 
   uint32_t runtime;
} queue_message_t;

typedef struct
{
   HART_SHARED_DATA *h_shared;
   QueueHandle_t queue_handle;
   mss_watchdog_num_t wdt;
} workload_task_parameters_t;

/* Function prototypes */
int create_tasks(HART_SHARED_DATA *h_shared);
int create_queues(HART_SHARED_DATA *h_shared);
int check_queues(void);
void print_results(HART_SHARED_DATA *h_shared);

void run_workload(char *bench_name, void (*initialise_benchmark)(void),
	void (*warm_caches)(int), void (*benchmark)(void), int (*verify_benchmark)(int),    
    unsigned int (*get_errors)(void), unsigned int (*get_executions)(void),
    HART_SHARED_DATA *h_shared, queue_message_t *buffer);

/* Task prototypes */
void vTask_Housekeeping(void* pvParameters);
void vTask_mont64(void* pvParameters);
void vTask_crc32(void* pvParameters);
void vTask_cubic(void* pvParameters);
void vTask_edn(void* pvParameters);
void vTask_matmult(void* pvParameters);
// void vTask_minver(void* pvParameters);
void vTask_nbody(void* pvParameters);
// void vTask_aes(void* pvParameters);
// void vTask_sha256(void* pvParameters);
// void vTask_nsichneu(void* pvParameters);
// void vTask_statemate(void* pvParameters);

/* Global variables */

static QueueHandle_t embench_queue_handle[WORKLOADS] = {NULL};

static workload_task_parameters_t task_parameters[WORKLOADS];

static void* embench_task_implementation[WORKLOADS] = {
    vTask_mont64, vTask_crc32, vTask_cubic, vTask_edn, vTask_matmult, vTask_nbody//, vTask_aes, 
    //vTask_sha256, vTask_statemate
};

/* Task handles */
static xTaskHandle task_housekeeping;
        
static xTaskHandle embench_task_handle[WORKLOADS] = {NULL};

/* Task names */
static char embench_task_name[WORKLOADS][10] =
{
    "mont64", "crc32", "cubic", "edn", "matmult", "nbody"//, "aes", "sha256", "statemate"
};



#endif /* TASKS_H */
