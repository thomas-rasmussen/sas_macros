/*******************************************************************************
AUTHOR:     Thomas Bøjer Rasmussen
VERSION:    0.0.3
********************************************************************************
DESCRIPTION:
Smooth time periods.

DETAILS:
Combines datalines with time periods in continuation of each other.

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros
********************************************************************************
PARAMETERS:
*** REQUIRED ***
data:             (libname.)member-name of input dataset.
out:              (libname.)member-name of output dataset.
*** OPTIONAL ***
start:            Name of variable with start times. Must be numeric.
                  By default it is assumed <data> has a variable called "start"
                  that is to be used.
end:              Name of variable with end times. Must be numeric.
                  By default it is assumed <data> has a variable called "start"
                  that is to be used.
by:               Space-separated list of by-variables. Smoothing is done
                  in strata of values of the given variables.
                  Defaults to by = null, ie no variables.
where:            Condition(s) used to restrict the input dataset in a
                  WHERE statement. Use the %str function as a wrapper, eg
                  where = %str(var1 = "value" and var2 < var3).
max_gap:          Maximum allowed time gap between the end of one period
                  and the start of another period when smoothing.
                  Defaults to 1 time unit. Must be a non-negative
                  numeric value. Note the the time unit is given in days for
                  date variables and seconds for datetime variables.
auto_remove:      Automatically remove datalines where <start> and/or
                  <end> is missing?
                  - Yes: auto_remove = y
                  - No: auto_remove = n (default)
                  If auto_remove = n, missing values triggers an error.
keep_first:       Space-separated list of variables for which the value at
                  the start of a smoothed period is kept in the output.
                  Variable names will be given a "__first_" prefix in the
                  output, and must therefore have a length of at most 24
                  characters. Defaults to keep_first = null, ie no variables.
keep_last:        Space-separated list of variables for which the value at
                  the end of a smoothed period is kept in the output.
                  Variable names will be given a "__last_" prefix in the
                  output, and must therefore have a length of at most 25
                  characters. Defaults to keep_last = null, ie no variables.
print_notes:      Print notes in log during macro execution?
                  - Yes: print_notes = y
                  - No:  print_notes = n (default)
                  Only intended to be used during development of macro.
verbose:          Print info about what is happening during macro execution
                  to the log?
                  - Yes: verbose = y
                  - No:  verbose = n (default)
                  Only intended to be used during development of macro.
del:              Delete intermediate datasets created by the macro after
                  macro execution?
                  - Yes: del = y (default)
                  - No:  del = n
                  Only intended to be used during development of macro.
******************************************************************************/
%macro smooth_periods(
  data        = ,
  out         = ,
  start       = start,
  end         = end,
  by          = null,
  where       = %str(),
  max_gap     = 1,
  auto_remove = n,
  keep_first  = null,
  keep_last   = null,
  print_notes = n,
  verbose     = n,
  del         = y
  ) / minoperator mindelimiter = ' ';

%put smooth_periods: start execution %sysfunc(compress(%sysfunc(datetime(), datetime32.)));

/* Find value of notes options */
%local opt_notes;
%let opt_notes = %sysfunc(getoption(notes));

/* Disable notes while doing input checks */
options nonotes;


/*******************************************************************************
INPUT PARAMETER CHECKS 
*******************************************************************************/

/* verbose: check parameter not empty. */
%if &verbose = %then %do;
  %put ERROR: Macro parameter <verbose> not specified!;
  %goto end_of_macro;  
%end;

/* verbose: check parameter has valid value. */
%if (&verbose in y n) = 0 %then %do;
  %put ERROR: <verbose> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: verbose = y (Yes);
  %put ERROR: verbose = n (No);
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;  
%end;

%if &verbose = y %then %do;
  %put smooth_periods: *** Input parameter checks ***;
%end;

/* print_notes: check parameter not empty. */
%if &print_notes = %then %do;
  %put ERROR: Macro parameter <print_notes> not specified!;
  %goto end_of_macro;  
%end;

/* print_notes: check parameter has valid value. */
%if (&print_notes in y n) = 0 %then %do;
  %put ERROR: <print_notes> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: print_notes = y (Yes);
  %put ERROR: print_notes = n (No);
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;  
%end;

%if &print_notes = y %then %do;
  options notes;
%end;   

/* Check remaining macro parameters (except <where>) not empty. */
%local tmp i i_tmp;
%let tmp = data out start end by max_gap auto_remove keep_first
           keep_last del;                 
%do i = 1 %to %sysfunc(countw(&tmp, %str( )));
  %let i_tmp = %scan(&tmp, &i, %str( ));
  %if %bquote(&&&i_tmp) = %then %do;
    %put ERROR: Macro parameter <&i_tmp> not specified!;
    %goto end_of_macro;    
  %end;
%end;

/* data: check dataset exists */
%if %sysfunc(exist(&data)) = 0 %then %do;
  %put ERROR: Specified <data> dataset "&data" does not exist!;
  %goto end_of_macro;
%end;

/* Find contents of <data> */
proc contents data = &data noprint out = __sp_contents;
run;

/* Check specified variables exists in <data> */
%local data_var par_var i i_var;
proc sql noprint;
 select name into :data_var separated by " "
   from __sp_contents;
quit;
%let par_var = &by &start &end &keep_first &keep_last;

%do i = 1 %to %sysfunc(countw(&par_var, %str( )));
  %let i_var = %scan(&par_var, &i, %str( ));
  %if (%upcase(&i_var) in %upcase(&data_var null)) = 0 %then %do;
    %put ERROR: Variable "&i_var" not found in <data> dataset "&data";
    %goto end_of_macro;
  %end;
%end;
  
/* Check no variable in input has a "__" prefix */
%do i = 1 %to %sysfunc(countw(&data_var, %str( )));
  %let i_var = %scan(&data_var, &i, %str( ));
  /* Note that "dummy" has been included in %qsubstr call so that a 
  variable name of length one can be handled correctly. */
  %if %qsubstr(&i_var dummy, 1, 2) = __ %then %do;
    %put ERROR: <data> contains variable "&i_var" which has a "__" prefix.;
    %put ERROR: This is not allowed to make sure that variables in <data>;
    %put ERROR: are not overwritten by (temporary) variables created by the macro!;
    %goto end_of_macro;
  %end;
%end;

/* start: check only one variable specified */
%if %eval(%sysfunc(countw(&start, %str( ))) > 1) %then %do;
  %put ERROR: Only one variable can be specified in <start>!;
  %goto end_of_macro; 
%end;

/* start: check variable is numeric */
%local start_type;
proc sql noprint;
  select type into :start_type
    from __sp_contents
    where lowcase(name) = %lowcase("&start");
quit;

%if &start_type = 2 %then %do;
  %put ERROR: <start> variable "&start" is not numeric!;
  %goto end_of_macro;
%end;

/* end: check only one variable specified */
%if %eval(%sysfunc(countw(&end, %str( ))) > 1) %then %do;
  %put ERROR: Only one variable can be specified in <end>!;
  %goto end_of_macro; 
%end;

/* end: check variable is numeric */
%local end_type;
proc sql noprint;
  select type into :end_type
    from __sp_contents
    where lowcase(name) = %lowcase("&end");
quit;

%if &end_type = 2 %then %do;
  %put ERROR: <end> variable "&end" is not numeric!;
  %goto end_of_macro;
%end;

/* Check <start> and <end> formats are the same as a way to judge if the
variables are comparable, eg both dates. */
%local start_format end_format;
proc sql noprint;
  select format into :start_format
    from __sp_contents
    where lowcase(name) = %lowcase("&start");
  select format into :end_format
    from __sp_contents
    where lowcase(name) = %lowcase("&end");
quit;

%if &start_format ne &end_format %then %do;
  %put ERROR: Format of <start> variable is not the same as for <end>!;
  %put ERROR: It looks like the <start> and <end> variables are not comparable!;
  %goto end_of_macro;
%end;

/* max_gap: check non-negative numeric value */
%if %sysfunc(prxmatch('^\d+(\.\d+)*$', &max_gap)) = 0 %then %do;
  %put ERROR: <max_gap> must be a non-negative numeric value!;
  %goto end_of_macro; 
%end;

/* auto_remove: check parameter has valid value. */          
%if %eval(&auto_remove in n y) = 0 %then %do;
  %put ERROR: <auto_remove> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: del = y (Yes);
  %put ERROR: del = n (No);
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;
%end;

/* keep_first: check variable names are at most 24 characters long  */
%do i = 1 %to %sysfunc(countw(&keep_first, %str( )));
  %let i_var = %scan(&keep_first, &i, %str( ));
  %if %sysfunc(length(&i_var)) > 24 %then %do;
    %put ERROR: Variable "&i_var" in <keep_first> is more than 24 characters.;
    %put ERROR: See <keep_first> documentation for more information.;
    %goto end_of_macro;
  %end;
%end;

/* keep_last: check variable names are at most 25 characters long  */
%do i = 1 %to %sysfunc(countw(&keep_last, %str( )));
  %let i_var = %scan(&keep_last, &i, %str( ));
  %if %sysfunc(length(&i_var)) > 25 %then %do;
    %put ERROR: Variable "&i_var" in <keep_last> is more than 25 characters.;
    %put ERROR: See <keep_last> documentation for more information.;
    %goto end_of_macro;
  %end;
%end;

/* del: check parameter has valid value. */          
%if %eval(&del in n y) = 0 %then %do;
  %put ERROR: <del> does not have a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: del = y (Yes);
  %put ERROR: del = n (No);
  %Put ERROR: Note that the parameter is case-sensitive.;
  %goto end_of_macro;
%end;


/*******************************************************************************
PREPARE DATA
*******************************************************************************/

%if &verbose = y %then %do;
  %put smooth_periods: *** Prepare data ***;
%end;

/* Load and restrict data */
data __sp_dat;
  set &data;
  where &where;
run;

/* If the WHERE condition(s) results in any warnings or errors,
the macro is terminated. */
%if &syserr ne 0 %then %do;
  %put ERROR- The specified <where> condition:;
  %put ERROR- &where;
  %put ERROR- produced a warning/error. Macro terminated!;
  %goto end_of_macro; 
%end;

%if &verbose = y %then %do;
  %put smooth_periods: - Input data succesfully loaded;
%end;

/* Check <data> for missing start and end values and if 
end < start for any dataline. */
%local start_miss end_miss end_lt_start;
%let start_miss = 0;
%let end_miss = 0;
%let end_lt_start = 0;
data __sp_dat;
  set __sp_dat;
  if &start = . then call symputx("start_miss", "1");
  if &end = . then call symputx("end_miss", "1");
  if &end ne . and &start ne . and &end < &start
    then call symputx("end_lt_start", "1");
  %if &auto_remove = y %then %do;
    if &start = . or &end = . then delete;
  %end;
run;

%if &end_lt_start = 1 %then %do;
  %put ERROR: "&end" < "&start" for one or more datalines!;
%end;

%if &auto_remove = n and (&start_miss = 1 or &end_miss = 1) %then %do;
  %put ERROR: <start> and/or <end> has missing values!;
  %goto end_of_macro;
%end;

/* Save original macro parameter values, then remove "null"'s  */
%local by_ori keep_first_ori keep_last_ori;
%let by_ori = &by;
%let keep_first_ori = &keep_first;
%let keep_last_ori = &keep_last;

%if &by = null %then %let by = ;
%if &keep_first = null %then %let keep_first = ;
%if &keep_last = null %then %let keep_last = ;

%if &verbose = y %then %do;
  %put smooth_periods: by variables - &by;
  %put smooth_periods: keep_first variables - &keep_first;
  %put smooth_periods: keep_last variables - &keep_last;
%end;

/* Restrict, sort and remove duplicates from data */
proc sort nodupkeys
    data = __sp_dat(keep = &by &start &end &keep_first &keep_last);
  by &by &start &end;
run;

/*******************************************************************************
SMOOTH
*******************************************************************************/

%if &verbose = y %then %do;
  %put smooth_periods: *** Smooth ***;
%end;

/* Find last variable in by-list */
%local last_by n_by;
%if &by ne %then %do;
  %let n_by = %sysfunc(countw(&by, %str( )));
  %let last_by = %scan(&by, &n_by, %str( ));
%end;

%local i i_var;
data __sp_dat;
  set __sp_dat;
  retain __tmp_start __tmp_end;
  %do i = 1 %to %sysfunc(countw(&keep_first, %str( )));
    %let i_var = %scan(&keep_first, &i, %str( ));
    retain __first_&i_var;
  %end;
  by &by &start &end;
  %if &by ne %then %do; if first.&last_by then do; %end;
  %else %do; if _n_ = 1 then do; %end;
      __tmp_start = &start;
      __tmp_end = &end;
      %do i = 1 %to %sysfunc(countw(&keep_first, %str( )));
        %let i_var = %scan(&keep_first, &i, %str( ));
        __first_&i_var = &i_var;
      %end;
  end;
  else if __tmp_start <= &start <= __tmp_end + &max_gap then do;
      __tmp_end = max(__tmp_end, &end);
  end;
  else if __tmp_end + &max_gap < &start then do;
    __tmp_start = &start;
    __tmp_end = &end;
    %do i = 1 %to %sysfunc(countw(&keep_first, %str( )));
    %let i_var = %scan(&keep_first, &i, %str( ));
      __first_&i_var = &i_var;
    %end;     
  end;
run;

data &out;
  /* Use retain statement to set order of variables */
  retain &by &start &end &keep_first;
  retain
    %do i = 1 %to %sysfunc(countw(&keep_first, %str( )));
      %let i_var = %scan(&keep_first, &i, %str( ));
      __first_&i_var
    %end;
   ;
  retain
    %do i = 1 %to %sysfunc(countw(&keep_last, %str( )));
      %let i_var = %scan(&keep_last, &i, %str( ));
      __last_&i_var
    %end;
  ;
  set __sp_dat;
  by &by __tmp_start;
  %if &by ne %then %do; if last.&last_by or last.__tmp_start; %end;
  %else %do; if last.__tmp_start; %end;
  %do i = 1 %to %sysfunc(countw(&keep_last, %str( )));
    %let i_var = %scan(&keep_last, &i, %str( ));
    __last_&i_var = &i_var;
  %end;
  &start = __tmp_start;
  &end = __tmp_end;
  drop __tmp_start __tmp_end &keep_first &keep_last;
run;


%end_of_macro:

/* Delete temporary datasets created by the macro, also when 
<del> has not be specified as either y or n. */
%if &del ne n  %then %do;
  proc datasets nodetails nolist;
    delete __sp_:;
  run;
  quit;
%end;

/* Restore value of notes option */
options &opt_notes;

%put smooth_periods: end execution   %sysfunc(compress(%sysfunc(datetime(), datetime32.)));

%mend smooth_periods;
