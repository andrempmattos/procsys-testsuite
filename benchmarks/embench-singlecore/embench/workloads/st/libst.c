/* BEEBS st benchmark

   This version, copyright (C) 2014-2019 Embecosm Limited and University of
   Bristol

   Contributor James Pallister <james.pallister@bristol.ac.uk>
   Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

   This file is part of Embench and was formerly part of the Bristol/Embecosm
   Embedded Benchmark Suite.

   SPDX-License-Identifier: GPL-3.0-or-later */

/* stats.c */

/* 2012/09/28, Jan Gustafsson <jan.gustafsson@mdh.se>
 * Changes:
 *  - time is only enabled if the POUT flag is set
 *  - st.c:30:1:  main () warning: type specifier missing, defaults to 'int':
 *    fixed
 */


/* 2011/10/18, Benedikt Huber <benedikt@vmars.tuwien.ac.at>
 * Changes:
 *  - Measurement and Printing the Results is only enabled if the POUT flag is
 *    set
 *  - Added Prototypes for InitSeedST and RandomIntegerST
 *  - Changed return type of InitSeedST from 'missing (default int)' to 'void'
 */

#include <math.h>
#include "inc/common.h"
#include <embench/support.h>

/* This scale factor will be changed to equalise the runtime of the
   benchmarks. */
#ifdef IS_SIMULATION
#define LOCAL_SCALE_FACTOR 1
#else
#define LOCAL_SCALE_FACTOR 85
#define NUMBER_OF_EXECUTIONS  (LOCAL_SCALE_FACTOR * CPU_MHZ)
#endif

#include <stdio.h>
unsigned int st_errors;
unsigned int st_executions; 

#define MAX 100

void InitSeedST (void);
int RandomIntegerST (void);
void Initialize (double[]);
void Calc_Sum_Mean (double[], double *, double *);
void Calc_Var_Stddev (double[], double, double *, double *);
void Calc_LinCorrCoef (double[], double[], double, double);


/* Statistics Program:
 * This program computes for two arrays of numbers the sum, the
 * mean, the variance, and standard deviation.  It then determines the
 * correlation coefficient between the two arrays.
 */

int SeedST;
double ArrayA_ST[MAX], ArrayB_ST[MAX];
double SumA, SumB;
double Coef;


void
st_initialise_benchmark (void)
{
  st_errors = 0;
  st_executions = 0;
}


static int st_benchmark_body (int  rpt);

void
st_warm_caches (int  heat)
{
  int  res = st_benchmark_body (heat);

  return;
}


void
st_benchmark (void)
{
  for (unsigned int i = 0; i < NUMBER_OF_EXECUTIONS; i++)
  {
    st_executions++;
    /* Execute once and check if different of correct */
    if(st_verify_benchmark(st_benchmark_body(1)) != 1)
    {
      st_errors++;
      log_from_moncore_noheader_nospinlock("\n[BENCHMARK_ERROR] st: errnum=%u itr=%u\n", st_errors, st_executions);
    }
  }
}


static int __attribute__ ((noinline))
st_benchmark_body (int rpt)
{
  int i;

  for (i = 0; i < rpt; i++)
    {
      double MeanA, MeanB, VarA, VarB, StddevA, StddevB /*, Coef */ ;

      InitSeedST ();

      Initialize (ArrayA_ST);
      Calc_Sum_Mean (ArrayA_ST, &SumA, &MeanA);
      Calc_Var_Stddev (ArrayA_ST, MeanA, &VarA, &StddevA);

      Initialize (ArrayB_ST);
      Calc_Sum_Mean (ArrayB_ST, &SumB, &MeanB);
      Calc_Var_Stddev (ArrayB_ST, MeanB, &VarB, &StddevB);

      /* Coef will have to be used globally in Calc_LinCorrCoef since it would
         be beyond the 6 registers used for passing parameters
       */
      Calc_LinCorrCoef (ArrayA_ST, ArrayB_ST, MeanA, MeanB /*, &Coef */ );
    }

  return 0;
}


void
InitSeedST ()
/*
 * Initializes the SeedST used in the random number generator.
 */
{
  SeedST = 0;
}


void
Calc_Sum_Mean (double Array[], double *Sum, double *Mean)
{
  int i;

  *Sum = 0;
  for (i = 0; i < MAX; i++)
    *Sum += Array[i];
  *Mean = *Sum / MAX;
}


double
Square (double x)
{
  return x * x;
}


void
Calc_Var_Stddev (double Array[], double Mean, double *Var, double *Stddev)
{
  int i;
  double diffs;

  diffs = 0.0;
  for (i = 0; i < MAX; i++)
    diffs += Square (Array[i] - Mean);
  *Var = diffs / MAX;
  *Stddev = sqrt (*Var);
}


void
Calc_LinCorrCoef (double ArrayA_ST[], double ArrayB_ST[], double MeanA,
		  double MeanB /*, Coef */ )
{
  int i;
  double numerator, Aterm, Bterm;

  numerator = 0.0;
  Aterm = Bterm = 0.0;
  for (i = 0; i < MAX; i++)
    {
      numerator += (ArrayA_ST[i] - MeanA) * (ArrayB_ST[i] - MeanB);
      Aterm += Square (ArrayA_ST[i] - MeanA);
      Bterm += Square (ArrayB_ST[i] - MeanB);
    }

  /* Coef used globally */
  Coef = numerator / (sqrt (Aterm) * sqrt (Bterm));
}



void
Initialize (double Array[])
/*
 * Intializes the given array with random integers.
 */
{
  register int i;

  for (i = 0; i < MAX; i++)
    Array[i] = i + RandomIntegerST () / 8095.0;
}


int
RandomIntegerST (void)
/*
 * Generates random integers between 0 and 8095
 */
{
  SeedST = ((SeedST * 133) + 81) % 8095;
  return (SeedST);
}

int
st_verify_benchmark (int unused)
{
  double expSumA = 4999.00247066090196;
  double expSumB = 4996.84311303273534;
  double expCoef = 0.999900054853619324;

  return double_eq_beebs(expSumA, SumA)
    && double_eq_beebs(expSumB, SumB)
    && double_eq_beebs(expCoef, Coef);
}

unsigned int
st_get_errors (void)
{
  return st_errors;
}

unsigned int
st_get_executions (void)
{
  return st_executions;
}


/*
   Local Variables:
   mode: C
   c-file-style: "gnu"
   End:
*/
