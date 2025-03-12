/* Copyright (C) 2017 Embecosm Limited and University of Bristol

   Contributor Graham Markall <graham.markall@embecosm.com>

   This file is part of Embench and was formerly part of the Bristol/Embecosm
   Embedded Benchmark Suite.

   SPDX-License-Identifier: GPL-3.0-or-later */

#include "inc/common.h"

#include "support.h"
#include <stdio.h>


// unsigned long event_handler (
//     unsigned long mepc,
//     unsigned long mtval,
//     unsigned long mcause,
//     unsigned long mhartid,
//     unsigned long mstatus,
//     unsigned long sp
// ) {
//   // read event information
//   unsigned long fault_id = EH_FAULT_ID;
//   EH_FAULT_ID = 0x0; // clear fault id
//   unsigned long pc = EH_PC;
//   unsigned long instr = EH_INSTR;
//   unsigned long enc_data = EH_ENC_DATA;
//   unsigned long enc_data_ecc = EH_ENC_DATA_ECC;
//   unsigned long jallog_ptr = EH_JALLOG_PTR;
//   unsigned long jallog_size = EH_JALLOG_SIZE;
//   unsigned long jallog[jallog_size];
//   for (int i = 0; i < jallog_size; i++) {
//       jallog[i] = EH_JALLOG(i);
//   }
//   // print information
//   printf("event id 0x%04X\n", fault_id);
//   printf("pc:       0x%08X\n", pc);
//   printf("instr:    0x%08X\n", instr);
//   printf("enc_data: 0x%02X%08X\n", enc_data_ecc, enc_data);
//   printf("jal logger\n");
//   printf("jal_ptr: %d\n", jallog_ptr);
//   printf("size:    %d\n", jallog_size);
//   for (int i = 0; i < jallog_size; i++) {
//       printf("stack[%2d]: 0x%08X\n", i, jallog[i]);
//   }
//   return mepc;
// }

// unsigned long interrupt_handler (
//     unsigned long mepc,
//     unsigned long mtval,
//     unsigned long mcause,
//     unsigned long mhartid,
//     unsigned long mstatus,
//     unsigned long sp
// ) {
//     return mepc;
// }

// unsigned long trap_handler(
//     unsigned long mepc,
//     unsigned long mtval,
//     unsigned long mcause,
//     unsigned long mhartid,
//     unsigned long mstatus,
//     unsigned long sp
// ) {
//     if (mcause >> 31) {
//       // is interrupt
//       printf("interrupt 0x%08X\n", mcause);
//       return interrupt_handler(mepc, mtval, mcause, mhartid, mstatus, sp);
//     } else {
//       // is exception
//       printf("exception 0x%08X\n", mcause);
//       // if it is a fault event
//       if (mcause == 0x18) {
//           return event_handler(mepc, mtval, mcause, mhartid, mstatus, sp);
//       } else {
//         // TODO: handle exception
//       }
//     }
//     // return to bootloader
//     return 0;
// }

void
initialise_board(void)
{
	//set_harden_conf(0x37);
    //uart_init(434, 0, 1); // 115200 baud rate
    //printf("rstcause: 0x%X\n", rstcause_info());
    //printf("implementation id: 0x%x\n", mimpid_info());
}

static unsigned long start_mcycle;
static unsigned long end_mcycle;

void __attribute__ ((noinline)) __attribute__ ((externally_visible))
start_trigger(void)
{
	// unsigned long clock;
	start_mcycle = readmcycle();
	// return clock;
}

void __attribute__ ((noinline)) __attribute__ ((externally_visible))
stop_trigger(void)
{
	// unsigned long clock;
	end_mcycle = readmcycle();
	// return clock;
}

unsigned long __attribute__ ((noinline)) __attribute__ ((externally_visible))
get_runtime(void)
{
    unsigned long runtime = 0;

    runtime = (end_mcycle - start_mcycle) / (CPU_MHZ * 1000);

    return runtime;
}
