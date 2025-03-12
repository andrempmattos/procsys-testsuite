/*
 * File: tasks.c
 * Description: Tasks creation and implementation.
 * Authors: andrempmattos, Douglasas, benmezger
 * Date: 2022-06-26
 */

/* Standard C libraries */
#include <stdio.h>

/* Embench includes. */
#include <embench/support.h>

/* App includes. */
#include "embench_tasks.h"

#include "mpfs_hal/mss_hal.h"
#include "drivers/mss/mss_watchdog/mss_watchdog.h"
#include "drivers/mss/mss_sys_services/mss_sys_services.h"


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
    queue_message_t *buffer
)
{
	#if (VERBOSE == 1)
		log_from_appcore_noheader(h_shared, "[HART%d] %s\n", read_csr(mhartid), bench_name);
	#endif

	initialise_benchmark();

	warm_caches(WARMUP_HEAT);

	start_trigger();
    benchmark();
	stop_trigger();

	buffer->errors = get_errors();
    buffer->execs = get_executions(); 
	buffer->runtime = get_runtime();

	#if (VERBOSE == 1)
		log_from_appcore_noheader(h_shared, "[HART%d]  errors = %d\n", read_csr(mhartid), buffer->errors);
		log_from_appcore_noheader(h_shared, "[HART%d]  execs = %d\n", read_csr(mhartid), buffer->execs);
		log_from_appcore_noheader(h_shared, "[HART%d]  runtime = %d ms\n\n", read_csr(mhartid), buffer->runtime);
	#endif
}

void print_results(HART_SHARED_DATA *h_shared)
{
    uint16_t len = 0;
    char buf[LOG_MSG_SIZE];

    queue_message_t buffer[WORKLOADS];

    uint64_t hart_id = read_csr(mhartid);

    for (int i = 0; i < WORKLOADS; i++)
    {
        xQueueReceive(embench_queue_handle[i], &buffer[i], (TickType_t)0);
        vTaskResume(embench_task_handle[i]);
    }

    len += sprintf(buf+len, "[HART%d]   num_errors = [ ", hart_id);
	for (uint8_t i = 0; i < (WORKLOADS-1); i++)
	{
        len += sprintf(buf+len, "%u, ", buffer[i].errors);
	}
	len += sprintf(buf+len, "%u ]\n", buffer[WORKLOADS-1].errors);

    len += sprintf(buf+len, "[HART%d]   num_execs = [ ", hart_id);
	for (uint8_t i = 0; i < (WORKLOADS-1); i++)
	{
        len += sprintf(buf+len, "%u, ", buffer[i].execs);
	}
	len += sprintf(buf+len, "%u ]\n", buffer[WORKLOADS-1].execs);

    len += sprintf(buf+len, "[HART%d]   runtime (ms) = [ ", hart_id);
	for (uint8_t i = 0; i < (WORKLOADS-1); i++)
	{
        len += sprintf(buf+len, "%u, ", buffer[i].runtime);
	}
	len += sprintf(buf+len, "%u ]\n\n", buffer[WORKLOADS-1].runtime);

    log_from_appcore_noheader(h_shared, buf);
}

int create_tasks(HART_SHARED_DATA *h_shared) 
{
    int err = 0;

    /* Housekeeping task */
    xTaskCreate(
        vTask_Housekeeping, 
        "housekeeping", 
        HOUSEKEEPING_TASK_STACK_SIZE, 
        h_shared, 
        HOUSEKEEPING_TASK_PRIORITY, 
        &task_housekeeping
    );

    if (task_housekeeping == NULL)
    {
        /* Error creating task */
        err = -1;
    }

    /* Embench tasks */
    for (int i = 0; i < WORKLOADS; i++)
    {
        
        log_from_appcore(h_shared, "Task %s\n", embench_task_name[i]);
        

        task_parameters[i].h_shared = h_shared;
        task_parameters[i].queue_handle = embench_queue_handle[i];
        task_parameters[i].wdt = MSS_WDOG1_LO;

        xTaskCreate(
            embench_task_implementation[i], 
            embench_task_name[i], 
            embench_tasks_stack[i], 
            &task_parameters[i],
            EMBENCH_TASK_PRIORITY, 
            &embench_task_handle[i]
        );

        if (embench_task_handle[i] == NULL)
        {
            /* Error creating task */
            err = -1;
        }
    }

    return err;
}

int create_queues(HART_SHARED_DATA *h_shared)
{
    int err = 0;

    for (int i = 0; i < WORKLOADS; i++)
    {
        embench_queue_handle[i] = xQueueCreate(1, sizeof(queue_message_t));

        log_from_appcore(h_shared, "Queue %d: %p\n", i, embench_queue_handle[i]);
        
        if (embench_queue_handle[i] == NULL)
        {
            return -1;
        }
    }

    return 0;
}

int check_queues(void) {

    int valid = 0;
    queue_message_t buffer;

    for (int i = 0; i < WORKLOADS; i++)
    {
        if (xQueuePeek(embench_queue_handle[i], (void*)&buffer, (TickType_t)0) == pdPASS)
        {
            valid++;
        }
    }

    if (valid == WORKLOADS) 
    {
        return 0;
    }
    else 
    {
        return -1;
    }
}

/* Housekeeping task with highest priority */
void vTask_Housekeeping(void* pvParameters) 
{
    uint32_t execution_cycle = 0;

    /* Temperature/voltage sensors */
    uint32_t tvs_out0 = 0, tvs_out1 = 0;
    uint16_t volt_1v0 = 0, volt_1v8 = 0, volt_2v5 = 0, temperature = 0;  
    
    log_from_appcore(pvParameters, "[BENCHMARK_START] run_cycle: %d\n\n", execution_cycle);
    /* Print TVS information */
    tvs_out0 = MSS_SCBCTRL->TVS_OUTPUT0;
    tvs_out1 = MSS_SCBCTRL->TVS_OUTPUT1;
    volt_1v0 = (tvs_out0 & 0x00007FFF) >> 3; 
    volt_1v8 = (tvs_out0 & 0x7FFF0000) >> 19;
    volt_2v5 = (tvs_out1 & 0x00007FFF) >> 3;
    temperature = ((tvs_out1 & 0x7FFF0000) >> 20) - 273;
    if ((volt_1v0 != 0) || (volt_1v8 != 0) || (volt_2v5 != 0))  
    {
        log_from_appcore(pvParameters, "[TVS] (volt_1v0 = %umV) (volt_1v8 = %umV) (volt_2v5 = %umV) (temp = %uC)\n\n", 
            volt_1v0, volt_1v8, volt_2v5, temperature);
    }  
    else {
        log_from_appcore(pvParameters, "[TVS] Reading TVS built-in sensor failed\n\n");
    }
    
    while (1) 
    {
        // log_from_appcore(pvParameters, "[FREERTOS] Housekeeping heartbeat\n");
        
        if (check_queues() == 0)
        {
            log_from_appcore(pvParameters, "[BENCHMARK_END] embench_results: %d\n", execution_cycle);
            print_results(pvParameters);
            log_from_appcore(pvParameters, "[BENCHMARK_START] run_cycle: %d\n", ++execution_cycle);

            /* Print TVS information */
            tvs_out0 = MSS_SCBCTRL->TVS_OUTPUT0;
            tvs_out1 = MSS_SCBCTRL->TVS_OUTPUT1;
            volt_1v0 = (tvs_out0 & 0x00007FFF) >> 3; 
            volt_1v8 = (tvs_out0 & 0x7FFF0000) >> 19;
            volt_2v5 = (tvs_out1 & 0x00007FFF) >> 3;
            temperature = ((tvs_out1 & 0x7FFF0000) >> 20) - 273;
            if ((volt_1v0 != 0) || (volt_1v8 != 0) || (volt_2v5 != 0))  
            {
                log_from_appcore(pvParameters, "[TVS] (volt_1v0 = %umV) (volt_1v8 = %umV) (volt_2v5 = %umV) (temp = %uC)\n\n", 
                    volt_1v0, volt_1v8, volt_2v5, temperature);
            }  
            else {
                log_from_appcore(pvParameters, "[TVS] Reading TVS built-in sensor failed\n\n");
            }
        }

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

/* aha-mont64 task */
void vTask_mont64(void* pvParameters) 
{
	workload_task_parameters_t *parameters = pvParameters;

    QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
    while (1) 
    {
        log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: aha-mont64\n");

        queue_message_t buffer;

        run_workload(
            "aha-mont64",
            &mont64_initialise_benchmark, &mont64_warm_caches, &mont64_benchmark, &mont64_verify_benchmark, 
            &mont64_get_errors, &mont64_get_executions, parameters->h_shared, &buffer
        );
        
        xQueueSend(result_queue, (void *)&buffer, 0);

        MSS_WD_reload(parameters->wdt);
        log_from_appcore(parameters->h_shared, "[FREERTOS] End of: aha-mont64\n");
        
        vTaskSuspend(NULL);
    }
}

/* crc32 task */
void vTask_crc32(void* pvParameters) 
{
	workload_task_parameters_t *parameters = pvParameters;

    QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
    while (1) 
    {
        log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: crc32\n");

        queue_message_t buffer;

        run_workload(
            "crc32",
            &crc32_initialise_benchmark, &crc32_warm_caches, &crc32_benchmark, &crc32_verify_benchmark, 
            &crc32_get_errors, &crc32_get_executions, parameters->h_shared, &buffer
        );
        
        xQueueSend(result_queue, (void *)&buffer, 0);

        MSS_WD_reload(parameters->wdt);
        log_from_appcore(parameters->h_shared, "[FREERTOS] End of: crc32\n");
        
        vTaskSuspend(NULL);
    }
}

/* cubic task */
void vTask_cubic(void* pvParameters) 
{
	workload_task_parameters_t *parameters = pvParameters;

    QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
    while (1) 
    {
        log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: cubic\n");

        queue_message_t buffer;

        run_workload(
            "cubic",
            &cubic_initialise_benchmark, &cubic_warm_caches, &cubic_benchmark, &cubic_verify_benchmark, 
            &cubic_get_errors, &cubic_get_executions, parameters->h_shared, &buffer
        );
        
        xQueueSend(result_queue, (void *)&buffer, 0);

        MSS_WD_reload(parameters->wdt);
        log_from_appcore(parameters->h_shared, "[FREERTOS] End of: cubic\n");
        
        vTaskSuspend(NULL);
    }
}

/* edn task */
void vTask_edn(void* pvParameters) 
{
	workload_task_parameters_t *parameters = pvParameters;

    QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
    while (1) 
    {
        log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: edn\n");

        queue_message_t buffer;

        run_workload(
            "edn",
            &edn_initialise_benchmark, &edn_warm_caches, &edn_benchmark, &edn_verify_benchmark, 
            &edn_get_errors, &edn_get_executions, parameters->h_shared, &buffer
        );
        
        xQueueSend(result_queue, (void *)&buffer, 0);

        MSS_WD_reload(parameters->wdt);
        log_from_appcore(parameters->h_shared, "[FREERTOS] End of: edn\n");
        
        vTaskSuspend(NULL);
    }
}

// /* matmult task */
void vTask_matmult(void* pvParameters) 
{
	workload_task_parameters_t *parameters = pvParameters;

    QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
    while (1) 
    {
        log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: matmult\n");

        queue_message_t buffer;

        run_workload(
            "matmult",
            &matmult_initialise_benchmark, &matmult_warm_caches, &matmult_benchmark, &matmult_verify_benchmark, 
            &matmult_get_errors, &matmult_get_executions, parameters->h_shared, &buffer
        );
        
        xQueueSend(result_queue, (void *)&buffer, 0);

        MSS_WD_reload(parameters->wdt);
        log_from_appcore(parameters->h_shared, "[FREERTOS] End of: matmult\n");
        
        vTaskSuspend(NULL);
    }
}

// /* minver task */
// void vTask_minver(void* pvParameters) 
// {
// 	workload_task_parameters_t *parameters = pvParameters;

//     QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
//     while (1) 
//     {
//         log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: minver\n");

//         queue_message_t buffer;

//         run_workload(
//             "minver",
//             &minver_initialise_benchmark, &minver_warm_caches, &minver_benchmark, &minver_verify_benchmark, 
//             &minver_get_errors, &minver_get_executions, parameters->h_shared, &buffer
//         );
        
//         xQueueSend(result_queue, (void *)&buffer, 0);

//         MSS_WD_reload(parameters->wdt);
//         log_from_appcore(parameters->h_shared, "[FREERTOS] End of: minver\n");
        
//         vTaskSuspend(NULL);
//     }
// }


///////////////////////////////////////////////////////////////////////////////
/* nbody task */
void vTask_nbody(void* pvParameters) 
{
	workload_task_parameters_t *parameters = pvParameters;

    QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
    while (1) 
    {
        log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: nbody\n");

        queue_message_t buffer;

        run_workload(
            "nbody",
            &nbody_initialise_benchmark, &nbody_warm_caches, &nbody_benchmark, &nbody_verify_benchmark, 
            &nbody_get_errors, &nbody_get_executions, parameters->h_shared, &buffer
        );
        
        xQueueSend(result_queue, (void *)&buffer, 0);

        MSS_WD_reload(parameters->wdt);
        log_from_appcore(parameters->h_shared, "[FREERTOS] End of: nbody\n");
        
        vTaskSuspend(NULL);
    }
}

/* aes task */
void vTask_aes(void* pvParameters) 
{
	workload_task_parameters_t *parameters = pvParameters;

    QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
    while (1) 
    {
        log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: aes\n");

        queue_message_t buffer;

        run_workload(
            "aes",
            &aes_initialise_benchmark, &aes_warm_caches, &aes_benchmark, &aes_verify_benchmark, 
            &aes_get_errors, &aes_get_executions, parameters->h_shared, &buffer
        );
        
        xQueueSend(result_queue, (void *)&buffer, 0);

        MSS_WD_reload(parameters->wdt);
        log_from_appcore(parameters->h_shared, "[FREERTOS] End of: aes\n");
        
        vTaskSuspend(NULL);
    }
}

/* sha256 task */
void vTask_sha256(void* pvParameters) 
{
	workload_task_parameters_t *parameters = pvParameters;

    QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
    while (1) 
    {
        log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: sha256\n");

        queue_message_t buffer;

        run_workload(
            "sha256",
            &sha256_initialise_benchmark, &sha256_warm_caches, &sha256_benchmark, &sha256_verify_benchmark, 
            &sha256_get_errors, &sha256_get_executions, parameters->h_shared, &buffer
        );
        
        xQueueSend(result_queue, (void *)&buffer, 0);

        MSS_WD_reload(parameters->wdt);
        log_from_appcore(parameters->h_shared, "[FREERTOS] End of: sha256\n");
        
        vTaskSuspend(NULL);
    }
}

/////////////////////////////////////////////////
/* nsichneu task */
void vTask_nsichneu(void* pvParameters) 
{
	workload_task_parameters_t *parameters = pvParameters;

    QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
    while (1) 
    {
        log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: nsichneu\n");

        queue_message_t buffer;

        run_workload(
            "nsichneu",
            &nsichneu_initialise_benchmark, &nsichneu_warm_caches, &nsichneu_benchmark, &nsichneu_verify_benchmark, 
            &nsichneu_get_errors, &nsichneu_get_executions, parameters->h_shared, &buffer
        );
        
        xQueueSend(result_queue, (void *)&buffer, 0);

        MSS_WD_reload(parameters->wdt);
        log_from_appcore(parameters->h_shared, "[FREERTOS] End of: nsichneu\n");
        
        vTaskSuspend(NULL);
    }
}


///////////////////////////////////////////
/* slre task */
// void vTask_slre(void* pvParameters) 
// {
// 	workload_task_parameters_t *parameters = pvParameters;

//     QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
//     while (1) 
//     {
//         log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: slre\n");

//         queue_message_t buffer;

//         run_workload(
//             "slre",
//             &slre_initialise_benchmark, &slre_warm_caches, &slre_benchmark, &slre_verify_benchmark, 
//             &slre_get_errors, &slre_get_executions, parameters->h_shared, &buffer
//         );
        
//         xQueueSend(result_queue, (void *)&buffer, 0);

//         MSS_WD_reload(parameters->wdt);
//         log_from_appcore(parameters->h_shared, "[FREERTOS] End of: slre\n");
        
//         vTaskSuspend(NULL);
//     }
// }

/////////////////////////////////////////
/* st task */
// void vTask_st(void* pvParameters) 
// {
// 	workload_task_parameters_t *parameters = pvParameters;

//     QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
//     while (1) 
//     {
//         log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: st\n");

//         queue_message_t buffer;

//         run_workload(
//             "st",
//             &st_initialise_benchmark, &st_warm_caches, &st_benchmark, &st_verify_benchmark, 
//             &st_get_errors, &st_get_executions, parameters->h_shared, &buffer
//         );
        
//         xQueueSend(result_queue, (void *)&buffer, 0);

//         MSS_WD_reload(parameters->wdt);
//         log_from_appcore(parameters->h_shared, "[FREERTOS] End of: st\n");
        
//         vTaskSuspend(NULL);
//     }
// }

/* statemate task */
void vTask_statemate(void* pvParameters) 
{
	workload_task_parameters_t *parameters = pvParameters;

    QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
    while (1) 
    {
        log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: statemate\n");

        queue_message_t buffer;

        run_workload(
            "statemate",
            &statemate_initialise_benchmark, &statemate_warm_caches, &statemate_benchmark, &statemate_verify_benchmark, 
            &statemate_get_errors, &statemate_get_executions, parameters->h_shared, &buffer
        );
        
        xQueueSend(result_queue, (void *)&buffer, 0);

        MSS_WD_reload(parameters->wdt);
        log_from_appcore(parameters->h_shared, "[FREERTOS] End of: statemate\n");
        
        vTaskSuspend(NULL);
    }
}

/////////////////////////////////////
/* ud task */
// void vTask_ud(void* pvParameters) 
// {
// 	workload_task_parameters_t *parameters = pvParameters;

//     QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
//     while (1) 
//     {
//         log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: ud\n");

//         queue_message_t buffer;

//         run_workload(
//             "ud",
//             &ud_initialise_benchmark, &ud_warm_caches, &ud_benchmark, &ud_verify_benchmark, 
//             &ud_get_errors, &ud_get_executions, parameters->h_shared, &buffer
//         );
        
//         xQueueSend(result_queue, (void *)&buffer, 0);

//         MSS_WD_reload(parameters->wdt);
//         log_from_appcore(parameters->h_shared, "[FREERTOS] End of: ud\n");
        
//         vTaskSuspend(NULL);
//     }
// }

/////////////////////////////////////
/* wikisort task */
// void vTask_wikisort(void* pvParameters) 
// {
// 	workload_task_parameters_t *parameters = pvParameters;

//     QueueHandle_t result_queue = (QueueHandle_t) parameters->queue_handle;
//     while (1) 
//     {
//         log_from_appcore(parameters->h_shared, "[FREERTOS] Start of: wikisort\n");

//         queue_message_t buffer;

//         run_workload(
//             "wikisort",
//             &wikisort_initialise_benchmark, &wikisort_warm_caches, &wikisort_benchmark, &wikisort_verify_benchmark, 
//             &wikisort_get_errors, &wikisort_get_executions, parameters->h_shared, &buffer
//         );
        
//         xQueueSend(result_queue, (void *)&buffer, 0);

//         MSS_WD_reload(parameters->wdt);
//         log_from_appcore(parameters->h_shared, "[FREERTOS] End of: wikisort\n");
        
//         vTaskSuspend(NULL);
//     }
// }