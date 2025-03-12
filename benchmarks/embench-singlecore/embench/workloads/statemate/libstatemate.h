/* Support header for BEEBS.

   Copyright (C) 2014 Embecosm Limited and the University of Bristol
   Copyright (C) 2019 Embecosm Limited

   Contributor James Pallister <james.pallister@bristol.ac.uk>

   Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

   This file is part of Embench and was formerly part of the Bristol/Embecosm
   Embedded Benchmark Suite.

   SPDX-License-Identifier: GPL-3.0-or-later */

#ifndef LIBSTATEMATE_H
#define LIBSTATEMATE_H

/* Every benchmark implements this for one-off data initialization.  This is
   only used for initialization that is independent of how often benchmark ()
   is called. */

void statemate_initialise_benchmark(void);

/* Every benchmark implements this for cache warm up, typically calling
   benchmark several times. The argument controls how much warming up is
   done, with 0 meaning no warming. */

void statemate_warm_caches(int temperature);

/* Every benchmark implements this as its entry point. Don't allow it to be
   inlined! */

void statemate_benchmark(void) __attribute__ ((noinline));

/* Every benchmark must implement this to validate the result of the
   benchmark. */

int statemate_verify_benchmark(int res);

/* Custom functions to allow checking each of the N executions of the benchmark */
unsigned int statemate_get_errors(void);
unsigned int statemate_get_executions(void);

/* Local simplified versions of library functions */

#endif /* LIBSTATEMATE_H */

/*
   Local Variables:
   mode: C
   c-file-style: "gnu"
   End:
*/
