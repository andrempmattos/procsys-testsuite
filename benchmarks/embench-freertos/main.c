/**
 * u54_1.c
 *  
 *  @brief Code running on U54 core 1 (HART1)
 *    
 *   @date 01 Jun 2024 
 *   @author Andre Mattos
 * 
 */
#include <stdio.h>
#include <string.h>

#include <mpfs_hal/mss_hal.h>
#include <drivers/mss/mss_watchdog/mss_watchdog.h>
#include <drivers/mss/mss_sys_services/mss_sys_services.h>

#include "inc/common.h"
#include "inc/hooks.h"
#include "inc/embench_tasks.h"

/* Kernel includes. */
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "timers.h"
#include "semphr.h"

/**
 * The task that periodically checks that all the standard demo tasks are
 * still executing and error free.
 */
static void prvCheckTask( void *pvParameters );

mss_watchdog_config_t wd1lo_config;

/** 
 * @brief Main function for the HART1(U54_1 processor). Application code running on HART1 is placed here.
 * The HART1 goes into WFI. HART0 brings it out of WFI when it raises the first Software interrupt to this HART.
 * @return
 */
void main(void)
{
	HLS_DATA* hls = (HLS_DATA*)(uintptr_t)get_tp_reg();
    HART_SHARED_DATA * hart_share = (HART_SHARED_DATA *)hls->shared_mem;

    /* Clear pending software interrupt in case there was any.
       Enable only the software interrupt so that the E51 core can bring this
       core out of WFI by raising a software interrupt. */
    clear_soft_interrupt();
    set_csr(mie, MIP_MSIP);

    /* Put this hart into WFI. */
    do
    {
        __asm("wfi");
    }while(0 == (read_csr(mip) & MIP_MSIP));

    /* The hart is out of WFI, clear the SW interrupt. Here onwards Application
       can enable and use any interrupts as required */
    clear_soft_interrupt();

    /* Watchdog config */
    MSS_WD_get_config(MSS_WDOG1_LO, &wd1lo_config);
    wd1lo_config.forbidden_en = MSS_WDOG_DISABLE;
    wd1lo_config.time_val = 0x862000u;
    wd1lo_config.timeout_val = 0x3e8u;
    /* (0x862000 - 0x3e8) * ( 1/150MHz/256) = ~15s after system reset */
    MSS_WD_configure(MSS_WDOG1_LO, &wd1lo_config);

    log_from_appcore_noheader(hart_share, "\n[INIT_HART1]\n\n");

	while(1) 
    {
        prvSetupHardware();

        log_from_appcore(hart_share, "Creating queues...\n" );
        if (create_queues(hart_share) != 0)
        {
            log_from_appcore(hart_share, "Queues creation failed!\n");
        }
        else {
            log_from_appcore(hart_share, "Queues created successfully!\n");
        }

        log_from_appcore(hart_share, "Creating tasks...\n");
        if (create_tasks(hart_share) != 0)
        {
            log_from_appcore(hart_share, "Tasks creation failed!\n");
        }
        else {
            log_from_appcore(hart_share, "Tasks created successfully!\n");
        }

        log_from_appcore(hart_share, "[FREERTOS] Start scheduler \n");
        vTaskStartScheduler();
    }

}

/* HART1 Software interrupt handler */
void Software_h1_IRQHandler(void)
{
    uint64_t hart_id = read_csr(mhartid);
}

static void prvCheckTask( void *pvParameters )
{
    /* Demo start marker. */
    while (1)
    {
        log_from_appcore(pvParameters, "FreeRTOS Demo Start\n" );
        MSS_WD_reload(MSS_WDOG1_LO);
        vTaskDelay(500/portTICK_PERIOD_MS);
    }
    
}
