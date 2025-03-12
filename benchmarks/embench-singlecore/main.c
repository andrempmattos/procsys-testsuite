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

#include "mpfs_hal/mss_hal.h"

#include "drivers/mss/mss_watchdog/mss_watchdog.h"
#include "drivers/mss/mss_sys_services/mss_sys_services.h"

#include "inc/common.h"

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

    /* Temperature/voltage sensors */
    uint32_t tvs_out0 = 0, tvs_out1 = 0;
    uint16_t volt_1v0 = 0, volt_1v8 = 0, volt_2v5 = 0, temperature = 0;  

	/* Benchmark variables */
	uint32_t errors[WORKLOADS] = {0};
	uint32_t execs[WORKLOADS] = {0};
	uint32_t runtime[WORKLOADS] = {0};
	uint32_t run_cycle = 0;

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
        log_from_appcore(hart_share, "[BENCHMARK_START] run_cycle: %d\n", run_cycle);
        
        /* Print TVS information */
        tvs_out0 = MSS_SCBCTRL->TVS_OUTPUT0;
        tvs_out1 = MSS_SCBCTRL->TVS_OUTPUT1;
        volt_1v0 = (tvs_out0 & 0x00007FFF) >> 3; 
        volt_1v8 = (tvs_out0 & 0x7FFF0000) >> 19;
        volt_2v5 = (tvs_out1 & 0x00007FFF) >> 3;
        temperature = ((tvs_out1 & 0x7FFF0000) >> 20) - 273;
        if ((volt_1v0 != 0) || (volt_1v8 != 0) || (volt_2v5 != 0))  
        {
            log_from_appcore(hart_share, "[TVS] (volt_1v0 = %umV) (volt_1v8 = %umV) (volt_2v5 = %umV) (temp = %uC)\n\n", 
                volt_1v0, volt_1v8, volt_2v5, temperature);
        }  
        else {
            log_from_appcore(hart_share, "[TVS] Reading TVS built-in sensor failed\n\n");
        }
            
		
		/* Call benchmark suite */
		run_benchmark(hart_share, errors, execs, runtime, MSS_WDOG1_LO);
        
        /* Print results */
		print_results(hart_share, errors, execs, runtime, run_cycle++);
    }

}

/* HART1 Software interrupt handler */
void Software_h1_IRQHandler(void)
{
    uint64_t hart_id = read_csr(mhartid);
}