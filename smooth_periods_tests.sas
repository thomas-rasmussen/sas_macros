/*******************************************************************************
BASIC TESTS
*******************************************************************************/
data dat;
  input id start end var1 var2;
  datalines;
  1 1 2 1 2
  1 3 4 2 3
  2 1 2 1 2
  2 4 5 2 3
  ;
run;

data dat;
  set dat;
  start_char = put(start, 1.);
  end_char = put(end, 1.);
  start1 = start;
  end1 = end;
  id_char = put(id, 1.);
  var_name_that_is_24_byte = 1;
  var_name_that_is_25_bytes = 1;
  var_name_that_is_26_bytes_ = 1;
run;

/* Check that the macro gives an error if any of the macro parameters 
(except "where") are missing. */
%smooth_periods();
%smooth_periods(data = dat);
%smooth_periods(data = dat, out = );

%macro test1;
%local opt_vars i i_var;
%let opt_vars = start end by max_gap auto_remove keep_first keep_last
                print_notes verbose del;
%do i = 1 %to %sysfunc(countw(&opt_vars, %str( )));
  %let i_var = %scan(&opt_vars, &i, %str( ));
  %smooth_periods(data = dat, out = out, &i_var = );
%end;
%mend test1;
%test1;

/*** data ***/

/* check non-existing dataset triggers error */
%smooth_periods(data = abc, out = out);

/* check empty input, results in empty output with start and end variable */
data dat_empty;
  set dat(obs = 0);
run;

%smooth_periods(data = dat_empty, out = out);

/* Check specified variable names are case-insentive. Note that since
the specified variable names are used to (re)create the variables in the
output, the letter casing used in the parameters determine the letter casing
of the variables in the output. */
%smooth_periods(
  data = DAT,
  out = OUt,
  start = STart,
  end = END,
  by = ID,
  keep_first = VAR1,
  keep_last = VAR2
);

/* Test that if the input dataset has any variables with a "__" prefix, an
error is triggerd. */
data dat_prefix;
  set dat;
  __var = 1;
run;
%smooth_periods(data = dat_prefix, out = out);


/*** <start> ***/

/* Check multiple variables triggers error */
%smooth_periods(data = dat, out = out, start = start start1);

/* Check variable not in <data> triggers error */
%smooth_periods(data = dat, out = out, start = abc);

/* Check non-numeric variable triggers error  */
%smooth_periods(data = dat, out = out, start = start_char);

/* Check non-default name works */
%smooth_periods(data = dat, out = out, start = start1);


/*** <end> ***/

/* Check multiple variables triggers error */
%smooth_periods(data = dat, out = out, end = end end1);

/* Check variable not in <data> triggers error */
%smooth_periods(data = dat, out = out, end = abc);

/* Check non-numeric variable triggers error  */
%smooth_periods(data = dat, out = out, end = end_char);

/* Check non-default name works */
%smooth_periods(data = dat, out = out, end = end1);


/*** <by> ***/

/* Check variable not in <data> triggers error */
%smooth_periods(data = dat, out = out, by = abc);

/* Check multiple by variables works */
%smooth_periods(data = dat, out = out, by = id id1);


/*** <where> ***/

/* Check insertion of WHERE statement works as intended */
%smooth_periods(data = dat, out = out, where = %str(id < 2));

/* Check WHERE statement resulting in error terminates the macro */
%smooth_periods(data = dat, out = out, where = %str(abc < 2));


/*** <max_gap> ***/

/* Check invalid input triggers error */
%smooth_periods(data = dat, out = out, max_gap = abc);
%smooth_periods(data = dat, out = out, max_gap = -1);
%smooth_periods(data = dat, out = out, max_gap = "1");

/* Check valid input does not trigger error */
%smooth_periods(data = dat, out = out, max_gap = 0.5);
%smooth_periods(data = dat, out = out, max_gap = 3);
%smooth_periods(data = dat, out = out, max_gap = 0);


/*** <auto_remove> ***/

/* Check invalid input triggers error */
%smooth_periods(data = dat, out = out, auto_remove = abc);

/* Check results using data with missing values */
data dat_miss;
  set dat end = eof;
  output;
  if eof then do;
    start = .;
    output;
  end;
run;

%smooth_periods(data = dat_miss, out = out);
%smooth_periods(data = dat_miss, out = out, auto_remove = y);


/*** <keep_first> ***/

/* Check multiple variables work */
%smooth_periods(data = dat, out = out, keep_first = var1 var2);

/* Check too long variable name triggers error */
%smooth_periods(data = dat, out = out, keep_first = var_name_that_is_25_bytes);

/* Check maximum allowed variable length works */
%smooth_periods(data = dat, out = out, keep_first = var_name_that_is_24_byte);


/*** <keep_last> ***/

/* Check multiple variables work */
%smooth_periods(data = dat, out = out, keep_last = var1 var2);

/* Check too long variable name triggers error */
%smooth_periods(data = dat, out = out, keep_last = var_name_that_is_26_bytes_);

/* Check maximum allowed variable length works */
%smooth_periods(data = dat, out = out, keep_last = var_name_that_is_25_bytes);


/*** <print_notes> ***/

/* check invalid values trigger error */
%smooth_periods(data = dat, out = out, print_notes = abc);

/*** <verboes> ***/

/* check invalid values trigger error */
%smooth_periods(data = dat_miss, out = out, verbose = abc);

/*** <del> ***/

/* check invalid values trigger error */
%smooth_periods(data = dat_miss, out = out, del = abc);


/*******************************************************************************
START AND END VARIABLE COMPARABILITY
*******************************************************************************/

/* Check that incomparable start/end variables triggers an error. */
data dat;
  format start yymmdd. end datetime.;
  informat start yymmdd. end datetime.;
  input id start end;
  datalines;
  1 2000-01-01 02JAN2000:00:00:00
  ;
run;

%smooth_periods(data = dat, out = out);


/*******************************************************************************
DATETIME TESTS
*******************************************************************************/

/* Check that the time unit used in smoothing when datetime variables are used
is seconds */
data dat;
  format start end datetime.;
  informat start end datetime.;
  input id start end;
  datalines;
  1 01JAN2000:00:00:00 02JAN2000:00:00:00
  1 02JAN2000:00:00:00 03JAN2000:00:00:00
  2 01JAN2000:00:00:00 02JAN2000:00:00:00
  2 02JAN2000:00:00:01 04JAN2000:00:00:00
  3 01JAN2000:00:00:00 02JAN2000:00:00:00
  3 02JAN2000:00:00:02 04JAN2000:00:00:00
  ;
run;

%smooth_periods(data = dat, out = out, by = id);


/*******************************************************************************
ERRONEOUS DATA TESTS
*******************************************************************************/

/* Test that any datalines with end < start triggers an error. */
data dat;
  input start end;
  datalines;
  2 1
  2 3
  ;
run;

%smooth_periods(data = dat, out = out);

/*******************************************************************************
OVERLAPPING PERIODS TESTS
*******************************************************************************/

/* Check that the macro correctly smooths periods with overlap */
data dat;
  input id start end;
  datalines;
  1 1 2
  1 1 3
  2 1 3
  2 2 4
  3 1 4
  3 2 4
  4 1 3
  4 2 2
  4 3 4
  ;
run;

%smooth_periods(data = dat, out = out, by = id);


/*******************************************************************************
UNSORTED DATA TESTS
*******************************************************************************/

/* Check that unsorted data is smoothed correctly */
data dat;
  input id start end var1 var2;
  datalines;
  1 2 4 2 2
  1 1 2 1 1
  2 2 3 3 3
  2 1 2 2 2
  ;
run;

%smooth_periods(
  data = dat,
  out = out,
  by = id,
  keep_first = var1,
  keep_last = var2
);


/*******************************************************************************
VERBOSE TESTS
*******************************************************************************/

/* Check text printed to log when using verbose = y */
data dat;
  input id start end;
  datalines;
  1 2 4
  1 1 2
  ;
run;

%smooth_periods(data = dat, out = out, by = id, verbose = y);


/*******************************************************************************
PERFORMANCE
*******************************************************************************/

/* make test and check results after optimization of code */

%let n_id = 10**6;
%let n_obs = 100;
data dat;
  call streaminit(1);
  do i = 1 to &n_id;
    id = i;
    do j = 1 to &n_obs;
      start = floor(10*rand("uniform"));
      end = start + floor(10*rand("uniform"));
      output;
    end;
  end;
run;

%smooth_periods(data = dat, out = out, by = id, keep_first = i, keep_last = j);
/* run-time: approx 1m20s */
