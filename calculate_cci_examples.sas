/*******************************************************************************
DATA
*******************************************************************************/

/* Population:
id:         ID variable. 
index_date: Variable with the date on which we want to calculate the CCI.
male:       Auxiliary variable
outcome:    Auxiliary variable
*/

data pop;
  length id index_date male outcome 8;
  format index_date yymmdd10.;
  informat index_date yymmdd10.;
  input id index_date male outcome;
  datalines;
  1 2000-01-01 1 1
  2 2000-01-01 0 0
  3 2000-01-01 0 1
  4 2000-01-01 1 1
  ;
run;


/* Diagnosis data:
id:             ID variable. 
diag_date:      Date of diagnosis
diag_code_icd:  ICD diagnosis code.
diag_code_sks:  SKS variation of ICD code in diag_code_icd, where ICD-10 codes
                have a "D" prefix, as is the case in data from the Danish National
                Patient Registry.
*/

data diag;
  length id diag_date 8 diag_code_icd diag_code_sks $5;
  format diag_date yymmdd10.;
  informat diag_date yymmdd10.;
  input id diag_date diag_code_icd diag_code_sks;
  datalines;
  1 1995-01-01 C70 DC70
  1 1999-01-01 1234 1234
  2 2001-01-01 C70 DC70
  3 1999-01-01 195 195
  4 1999-06-01 I21 DI21
  ;
run;

/*******************************************************************************
EXAMPLE - STANDARD USE
*******************************************************************************/

/* The macro is set up to assume reasonable variable names. Here, we only need
to specify that diagnoses codes are in the variable diag_code_icd/diag_code_sks.
By default the macro will use all diagnoses up to 200 years prior to the index date
to calculate the CCI, effectively using all information on diagnoses. */
%calculate_cci(
  pop_ds = pop,
  diag_ds = diag,
  out_ds = example_standard,
  diag_code = diag_code_icd
);


/*******************************************************************************
EXAMPLE - USE OF MACRO PARAMETERS
*******************************************************************************/

/* 
1) In many cases, the lookback period is set to a fixed period, which we can 
specify by using the lookback_length and lookback_unit parameters. Here we 
choose to use a 1 year lookback period which, we can specify using 
"lookback_length = 1" and "lookback_unit = year".
2) In some cases we don't want to include auxiliary variables from the 
<pop_ds> input datatset. We can achieve that by specifying "keep_pop_vars = n". 
3) It is sometime convenient to have access to the individual disease groups 
used to calculate the CCI. We can keep the 19 individual variables used in the 
definition by using "keep_cci_vars = y". 
4) In some scenarios, it is desirable to be able to exclude one or more of the
disease groups from the CCI calculations. We can do this by using the 
exclude_groups parameter. Here we exclude Metastatic solid tumour and AIDS from 
the calculation by using "exclude_groups = 18 19". The definition and
corresponding number for each group can be found in the "CODES" section of the 
macro. 
5) Here, we use the diag_code_sks variable to show that the macro handles
SKS codes from eg the Danish National Registry of Patients automatically.
*/
%calculate_cci(
  pop_ds = pop,
  diag_ds = diag,
  out_ds = example_parms,
  diag_code = diag_code_sks,
  lookback_length = 1,
  lookback_unit = year,
  exclude_groups = 18 19,
  keep_pop_vars = n,
  keep_cci_vars = y
);


/*******************************************************************************
EXAMPLE - OVERWRITE CODE DEFINTIONS
*******************************************************************************/

/* 

WARNING: THIS IMPLEMENTATION IS EXPERIMENTAL, AND IS LIKELY TO NOT WORK AS
INTENDED IF USED INCORRECTLY. IT IS NOT ADVISED TO USE THIS FUNCTIONALITY 
UNLESS YOU HAVE READ AND UNDERSTOOD THE SOURCE CODE.

The codes used to define the disease groups in the macro are reasonable, but
there is no official consensus on what the "correct codes" are. Modifications 
to one or more definition is often required/requested in studies, and this 
can be accommodated using the codes_ds parameter, to specify an additional
input dataset with definitions that will overwrite the default definitions 
used in the macro. */

data codes;
  length group 8 var $10 value $100;
  group = 1;
  var = "icd10";
  value = "I22";
  output;
  group = 5;
  var = "label";
  value = "New dementia def";
  output;
run;

%calculate_cci(
  pop_ds = pop,
  diag_ds = diag,
  codes_ds = codes,
  out_ds = example_codes,
  diag_code = diag_code_icd
);
