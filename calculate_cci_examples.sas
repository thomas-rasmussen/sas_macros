/*******************************************************************************
SIMUALATE DATA
*******************************************************************************/

/* Simulate population:
id:         ID variable. 
index_date: Variable with the date on which we want to calculate the CCI.
male:       Auxiliary variable
outcome:    Auxiliary variable
*/
data pop;
  format id 8. index_date yymmdd10. male outcome 1.;
  call streaminit(1);
  do id = 1 to 10**4;
    index_date = 365 * 20 + ceil(rand("uniform", -1, 1)* 5000);
    male = rand("bernoulli", 0.5);
    outcome = rand("bernoulli", 0.1);
    output;
  end;
run;

/* Simulate diagnosis data:
id:             ID variable. 
diag_date:      Date of diagnosis
diag_code:      Diagnosis code. Note that the macro expects both ICD-8 and
                ICD-10 codes to be included in the same variable.
diag_code_sks:  Variation of diag_code where ICD-10 codes have a "D" prefix
                as is the case in data from the Danish National Patient 
                Registry.
*/

data diag;
  format id 8. diag_date yymmdd10. diag_code diag_code_icd10 $10.;
  call streaminit(2);
  do id = 1 to 10**4;
    do j = 1 to 10;
      diag_date = 365 * 10 + ceil(rand("uniform", -1, 1)* 10000);
      if rand("uniform") < 0.8 then do;
        sample_letter = substr("ABCDEFGH", ceil(rand("uniform")*8), 1);
        sample_number1 = substr("0123456789", ceil(rand("uniform")*10), 1);
        sample_number2 = substr("0123456789", ceil(rand("uniform")*10), 1);
        diag_code_icd10 = compress(sample_letter || sample_number1 || sample_number2);
        diag_code = "D" || diag_code_icd10;
        output;
      end;
      else do;
        diag_code_icd10 = compress(put(ceil(10000 * rand("uniform")), 10.));
        diag_code = diag_code;
        output;
      end;
    end;
  end;
  drop j sample_:;
run;

/*******************************************************************************
EXAMPLE - STANDARD USE
*******************************************************************************/

/* The macro is set up to assume all the variable names are as we have defined 
them here. By default the macro will use all diagnoses prior to the index date 
to calculate the CCI. Or more precisely, all data up to 200 years before the 
index date. */
%calculate_cci(
  pop_ds = pop,
  diag_ds = diag,
  out_ds = example_standard
);


/*******************************************************************************
EXAMPLE - USE OF MACRO PARAMETERS
*******************************************************************************/

/* 
1) In many cases, the lookback period is set to a fixed period, which we can 
specify by using the lookback_length and lookback_unit parameters. Here we 
choose to use a 6 month lookback period which we can specify using 
"lookback_length = 6" and "lookback_unit = month".
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
5) We will here explicitly use the diag_code_icd10 variable to show that
the macro indeed handles SKS/icd10 codes automatically.
*/
%calculate_cci(
  pop_ds = pop,
  diag_ds = diag,
  out_ds = example_parms,
  diag_code = diag_code_icd10,
  lookback_length = 6,
  lookback_unit = month,
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
  value = "I21 I22";
  output;
  group = 5;
  var = "icd8";
  value = "29009 2901 29309";
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
  out_ds = example_codes
);
