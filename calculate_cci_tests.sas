/*******************************************************************************
BASIC TESTS
*******************************************************************************/

data pop;
  length id 8 id_chr $1 index_date 8 index_date_chr $10 aux_num aux_chr $1;
  format index_date yymmdd10.;
  informat index_date yymmdd10.;
  input id id_chr index_date index_date_chr aux_num aux_chr;
  datalines;
  1 1 2000-01-01 2000-01-01 1 0
  ;
run;

data diag;
  length id 8 id_chr $1 diag_date 8 diag_date_chr $10 diag_code $10;
  format diag_date yymmdd10.;
  informat diag_date yymmdd10.;
  input id id_chr diag_date diag_date_chr diag_code;
  datalines;
  1 1 1999-01-01 1999-01-01 DI23
  ;
run;


/* Check that the macro gives an error if any of the required macro parameters 
are not specified. */
%calculate_cci();
%calculate_cci(pop_ds = pop);
%calculate_cci(pop_ds = pop, diag_ds = diag);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test);

/* Check that the macro gives an error if any of the optional macro parameters
are set to not being specified. */
%macro _test1;
%local opt_vars i i_var;
%let opt_vars = codes_ds id index_date diag_code diag_date code_type      
                lookback_period lookback_unit exclude_groups keep_pop_vars  
                keep_cci_vars print_notes verbose del;          

%do i = 1 %to %sysfunc(countw(&opt_vars, %str( )));
  %let i_var = %scan(&opt_vars, &i, %str( ));
  %calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, &i_var = );
%end;
%mend _test1;
%_test1;


/* Uncertain what if any, tests are appropriate for checking the names
of input/output datasets. For now, we stick with conventions used in other 
macros. */


/*** <pop_ds> ***/

/* Check error if dataset does not exist */
%calculate_cci(pop_ds = abc, diag_ds = diag, out_ds = test);

/* Check empty dataset not accepted */
data tmp;
  set pop(obs = 0);
run;
%calculate_cci(pop_ds = tmp, diag_ds = diag, out_ds = test);

/* Check error if dataset includes protected variable names */
data tmp;
  set pop;
  cci_name = id;
run;
%calculate_cci(pop_ds = tmp, diag_ds = diag, out_ds = test);
data tmp;
  set pop;
  __name = id;
run;
%calculate_cci(pop_ds = tmp, diag_ds = diag, out_ds = test);


/*** <diag_ds> ***/

/* Check error if dataset does not exist */
%calculate_cci(pop_ds = pop, diag_ds = abc, out_ds = test);

/* Check empty dataset not accepted */
data tmp;
  set diag(obs = 0);
run;
%calculate_cci(pop_ds = pop, diag_ds = tmp, out_ds = test);

/* Check error if dataset includes protected variable names */
data tmp;
  set diag;
  cci_name = id;
run;
%calculate_cci(pop_ds = pop, diag_ds = tmp, out_ds = test);
data tmp;
  set diag;
  __name = id;
run;

%calculate_cci(pop_ds = pop, diag_ds = tmp, out_ds = test);



/*** <out_ds> ***/

/* No checks. */


/*** <codes_ds> ***/

/* Experimental feature. No tests implemented for now. */


/*** <id> ***/

/* Check character id variable (and non-default name) works. */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, id = id_chr);

/* Check error if invalid variable name. */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, id = 1abc);

/* Check error if variable does not exist. */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, id = abc);

/* Check error if id variable missing from only one of the input datasets */
data tmp;
  set pop;
  drop id;
run;
%calculate_cci(pop_ds = tmp, diag_ds = diag, out_ds = test);
data tmp;
  set diag;
  drop id;
run;
%calculate_cci(pop_ds = pop, diag_ds = tmp, out_ds = test);

/* check error if multiple variables are specified */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, id = id id_chr);


/*** <index_date> ***/

/* Check non-default name works*/
data tmp;
  set pop;
  index_date1 = index_date;
run;
%calculate_cci(
  pop_ds = tmp,
  diag_ds = diag,
  out_ds = test,
  index_date = index_date1
);

/* Check character index_date results in error*/
%calculate_cci(
  pop_ds = tmp,
  diag_ds = diag,
  out_ds = test,
  index_date = index_date_chr
);

/* Check error if invalid variable name. */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, index_date = 1abc);

/* Check error if variable does not exist. */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, index_date = abc);

/* check error if multiple variables are specified */
%calculate_cci(
  pop_ds = pop,
  diag_ds = diag,
  out_ds = test,
  index_date = index_date index_date_chr
);


/*** <diag_code> ***/

/* Check non-default name works*/
data tmp;
  set diag;
  diag_code1 = diag_code;
run;
%calculate_cci(
  pop_ds = pop,
  diag_ds = tmp,
  out_ds = test,
  diag_code = diag_code1
);

/* Check numeric variable results in error. */
%calculate_cci(
  pop_ds = pop,
  diag_ds = diag,
  out_ds = test,
  diag_code = diag_date
);

/* Check error if invalid variable name. */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, diag_code = 1abc);

/* Check error if variable does not exist. */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, diag_code = abc);

/* check error if multiple variables are specified */
%calculate_cci(
  pop_ds = pop,
  diag_ds = diag,
  out_ds = test,
  diag_code = diag_code diag_code
);


/*** <diag_date> ***/

/* Check non-default name works*/
data tmp;
  set diag;
  diag_date1 = diag_date;
run;
%calculate_cci(
  pop_ds = pop,
  diag_ds = tmp,
  out_ds = test,
  diag_date = diag_date1
);

/* Check character variable results in error. */
%calculate_cci(
  pop_ds = pop,
  diag_ds = diag,
  out_ds = test,
  diag_date = diag_date_chr
);

/* Check error if invalid variable name. */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, diag_date = 1abc);

/* Check error if variable does not exist. */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, diag_date = abc);

/* check error if multiple variables are specified */
%calculate_cci(
  pop_ds = pop,
  diag_ds = diag,
  out_ds = test,
  diag_date = diag_date diag_date
);


/*** <code_type> ***/

/* Check invalid value triggers error */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, code_type = abc);

/* Check valid values work */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, code_type = sks);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, code_type = icd);


/*** <lookback_period> ***/

/* check error if not non-negative integer input */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, lookback_period = -1);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, lookback_period = 1.9);

/* check no error if non-negative integer input */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, lookback_period = 0);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, lookback_period = 4);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, lookback_period = 01);


/*** <lookback_unit> ***/

/* Check invalid value triggers error */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, lookback_unit = "year");
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, lookback_unit = forthnight);

/* Check valid values work */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, lookback_unit = year);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, lookback_unit = month);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, lookback_unit = week);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, lookback_unit = day);


/*** <exclude_groups> ***/

/* Check valid values work */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, exclude_groups = null);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, exclude_groups = 1);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, exclude_groups = 1 4);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, exclude_groups = 01);

/* Check invalid values triggers errors */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, exclude_groups = abc);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, exclude_groups = "1" "12");
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, exclude_groups = 20);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, exclude_groups = 0);


/*** <keep_pop_vars> ***/

/* Check invalid values triggers errors */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, keep_pop_vars = abc);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, keep_pop_vars = Y);

/* Check valid values works */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, keep_pop_vars = n);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, keep_pop_vars = y);


/*** <keep_cci_vars> ***/

/* Check invalid values triggers errors */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, keep_cci_vars = abc);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, keep_cci_vars = Y);

/* Check valid values works */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, keep_cci_vars = n);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, keep_cci_vars = y);


/*** <print_note> ***/

/* Check invalid values triggers errors */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, print_notes = abc);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, print_notes = Y);

/* Check print_notes works correctly */
option notes;
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, print_notes = y);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, print_notes = n);

option nonotes;
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, print_notes = n);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, print_notes = y);

option notes;


/*** <verbose> ***/

/* Check invalid values triggers errors */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, verbose = abc);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, verbose = Y);

/* Check valid values works */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, verbose = n);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, verbose = y);


/*** <del> ***/

/* Check invalid values triggers errors */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, del = abc);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, del = Y);

/* Check valid values works */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, del = n);
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, del = y);


/*******************************************************************************
TEST ALGORITHM
*******************************************************************************/

data pop;
  length id 8 index_date 8;
  format index_date yymmdd10.;
  informat index_date yymmdd10.;
  input id index_date;
  datalines;
  1 2001-01-01
  1 2001-01-01
  2 2005-06-01
  ;
run;

data diag;
  length id 8 diag_date 8 diag_code $10;
  format diag_date yymmdd10.;
  informat diag_date yymmdd10.;
  input id diag_date diag_code;
  datalines;
  1 2000-01-01 DI23
  1 2000-05-01 42709
  1 2000-06-01 DC85
  2 2005-06-01 DI23
  ;
run;

%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test, keep_cci_vars = y);

/* Gives cci = 4 for the first patient and cci = 0 for the second patient as 
intended. Also, the first patient has a dataline for each dataline in the input 
population. */


/*******************************************************************************
TEST OVERWRITING CODE DEFINITIONS
*******************************************************************************/

data pop;
  length id 8 index_date 8;
  format index_date yymmdd10.;
  informat index_date yymmdd10.;
  input id index_date;
  datalines;
  1 2001-01-01
   ;
run;

data diag;
  length id 8 diag_date 8 diag_code $10;
  format diag_date yymmdd10.;
  informat diag_date yymmdd10.;
  input id diag_date diag_code;
  datalines;
  1 2000-01-01 DI23
  1 2000-05-01 42709
  1 2000-06-01 DC85
  ;
run;

data codes;
  length var value $50;
  group = 1;
  var = "icd10";
  value = "I21 I22";
  output;
  group = 2;
  var = "icd8";
  value = "42710 42711 42719 42899 78249";
  output;
run;

%calculate_cci(
  pop_ds = pop,
  diag_ds = diag,
  codes_ds = codes,
  out_ds = test,
  keep_cci_vars = y
);

/* Codes definitions correctly overwritten leading to cci = 2  instead
of cci = 4. */


/*******************************************************************************
TEST LOOKBACK PARAMETERS
*******************************************************************************/

data pop;
  length id 8 index_date 8;
  format index_date yymmdd10.;
  informat index_date yymmdd10.;
  input id index_date;
  datalines;
  1 2001-01-01
  2 2000-02-29
  3 2000-02-29
   ;
run;

data diag;
  length id 8 diag_date 8 diag_code $10;
  format diag_date yymmdd10.;
  informat diag_date yymmdd10.;
  input id diag_date diag_code;
  datalines;
  1 2000-01-01 DI23
  1 2000-12-01 DI50
  1 2000-12-25 DI70
  1 2000-12-31 DI6
  2 1999-02-28 DI23
  3 1999-03-1 DI23
  ;
run;

%calculate_cci(
  pop_ds = pop, 
  diag_ds = diag,
  out_ds = test, 
  keep_cci_vars = y,
  lookback_period = 1,
  lookback_unit = year
);

%calculate_cci(
  pop_ds = pop, 
  diag_ds = diag,
  out_ds = test, 
  keep_cci_vars = y,
  lookback_period = 1,
  lookback_unit = month
);

%calculate_cci(
  pop_ds = pop, 
  diag_ds = diag,
  out_ds = test, 
  keep_cci_vars = y,
  lookback_period = 1,
  lookback_unit = week
);

%calculate_cci(
  pop_ds = pop, 
  diag_ds = diag,
  out_ds = test, 
  keep_cci_vars = y,
  lookback_period = 1,
  lookback_unit = day
);


/*******************************************************************************
PERFORMANCE
*******************************************************************************/

%let n_id = 10**5;
%let n_diag = 100;
data pop;
  format id 8. index_date yymmdd10.;
  call streaminit(1);
  do id = 1 to &n_id;
    index_date = 365 * 20 + ceil(rand("uniform", -1, 1)* 5000);
    output;
  end;
run;

data diag;
  format id 8. diag_date yymmdd10. diag_code $10. ;
  call streaminit(2);
  do id = 1 to &n_id;
    do j = 1 to &n_diag;
      diag_date = 365 * 10 + ceil(rand("uniform", -1, 1)* 10000);
      if rand("uniform") < 0.8 then do;
        sample_letter = substr("ABCDEFGH", ceil(rand("uniform")*8), 1);
        sample_number1 = substr("0123456789", ceil(rand("uniform")*10), 1);
        sample_number2 = substr("0123456789", ceil(rand("uniform")*10), 1);
        diag_code = "D" || compress(sample_letter || sample_number1 || sample_number2);
        output;
      end;
      else do;
        diag_code = compress(put(ceil(10000 * rand("uniform")), 10.));
        output;
      end;
    end;
  end;
  drop j sample_:;
run;

/* Tests run on dedicated SAS server:
Processor: Intel(R) Xeon(R) CPU E5-2643 @ 3.40HGz 3.39 GHz (12 processors)
Installed memory (RAM): 256 GB
*/

/* n_id = 10**4 n_diag = 100 */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test);
/* run-time: 4s */

/* n_id = 10**5 n_diag = 10 */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test);
/* run-time: 5s */

/* n_id = 10**5 n_diag = 100 */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test);
/* run-time: 42s */

/* n_id = 10**6 n_diag = 10 */
%calculate_cci(pop_ds = pop, diag_ds = diag, out_ds = test);
/* run-time: 46s */
