/* Support header for BEEBS.

   Copyright (C) 2014 Embecosm Limited and the University of Bristol
   Copyright (C) 2019 Embecosm Limited

   Contributor James Pallister <james.pallister@bristol.ac.uk>

   Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

   This file is part of Embench and was formerly part of the Bristol/Embecosm
   Embedded Benchmark Suite.

   SPDX-License-Identifier: GPL-3.0-or-later */

#ifndef SUPPORT_H
#define SUPPORT_H

#include "board.h"
#include "chip.h"

#include <aha-mont64/mont64.h>
#include <crc32/crc_32.h>
#include <cubic/basicmath_small.h>
#include <edn/libedn.h>
#include <huffbench/libhuffbench.h>
#include <matmult-int/matmult-int.h>
#include <minver/libminver.h>
#include <nbody/nbody.h>
#include <nettle-aes/nettle-aes.h>
#include <nettle-sha256/nettle-sha256.h>
#include <nsichneu/libnsichneu.h>
//#include <picojpeg/picojpeg_test.h>
//#include <qrduino/qrtest.h>
#include <sglib-combined/combined.h>
#include <slre/libslre.h>
#include <st/libst.h>
#include <statemate/libstatemate.h>
#include <ud/libud.h>
#include <wikisort/libwikisort.h>

#define WARMUP_HEAT 1

/* Standard functions implemented for each board */

void initialise_board(void);
void start_trigger(void);
void stop_trigger(void);
unsigned long get_runtime(void);

/* Local simplified versions of library functions */

#include <beebsc/beebsc.h>

#endif /* SUPPORT_H */

/*
   Local Variables:
   mode: C
   c-file-style: "gnu"
   End:
*/
