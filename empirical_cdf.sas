/*******************************************************************************
AUTHOR:     Thomas Boejer Rasmussen
VERSION:    0.1.0
********************************************************************************
DESCRIPTION:
Calculates the empirical cumulative distribution function (CDF) of variables.

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros

DETAILS:
The (weighted) empirical CDF is calculated as

CDF(x) = 1 / sum(w_i) * sum(w_i * I(x_i<=x))

where w_i are weights, and I() is the indicator function.
 
https://v8doc.sas.com/sashtml/insight/chap38/sect25.htm
********************************************************************************
PARAMETERS:
*** REQUIRED ***
in_ds:        (libname.)member-name of input dataset.         
out_ds:       (libname.)member-name of output dataset with calculated 
              standardized differences.
var:          Space-separated list of variables for whcih SD's are calculated.
              Variable types is automatically guessed by the macro, but can
              also be manually specified by giving a /d (dichotomous), 
              /cont (continuous), /cat (categorical) suffix to (some or all)
              variables, eg var = var1/cont var2/d var3/cat var4
*** OPTIONAL ***
strata:       Space-separated list of variables used to divide the data into
              strata before calculating the empirical CDF. 
              Default is strata = _null_, ie no strata variables.   
weight:       Variable with observation weights. Default is weight = _null_, 
              ie no weights are used.
where:        Condition used to to restrict the input dataset in a where-
              statement. Use the %str function as a wrapper, , eg 
              where = %str(var = "value").
n_xvalues:    Number of x-values for which CDF(x) is calculated. The x-values 
              include the minimum and maximum value of the variable, and evenly-
              spaced values inbetweeen. Default is n_xvalues = 100. 
              Must be an integer >=2.    
print_notes:  Print notes in log?
              - Yes: print_notes = y
              - No:  print_notes = n (default)
verbose:      Print info on what is happening during macro execution
              to the log:
              - Yes: verbose = y
              - No:  verbose = n (default)
del:          Delete intermediate datasets created by the macro:
              - Yes: del = y (default)
              - no:  del = n            
******************************************************************************/
%macro empirical_cdf(
  in_ds       = ,
  out_ds      = ,
  var         = ,
  strata      = _null_, 
  weight      = _null_,
  where       = %str(),
  n_xvalues   = 100,
  print_notes = n,
  verbose     = n,
  del         = y
) / minoperator mindelimiter = ' ';

%put empirical_cdf: start execution;

/* Find value of notes option, save it, then disable notes */
%local opt_notes;
%let opt_notes = %sysfunc(getoption(notes));
options nonotes;

/* Make sure there are no intermediate dataset from from a previous 
run of the macro in the work directory before execution. */
proc datasets nolist nodetails;
  delete __cdf_:;
run;
quit;


/*******************************************************************************
Input parameter checks 
*******************************************************************************/

/* verbose: check parameter not empty. */
%if &verbose = %then %do;
  %put ERROR: Macro parameter <verbose> not specified!;
  %goto end_of_macro;  
%end;

/* verbose: check parameter has valid value. */
%if (&verbose in y n) = 0 %then %do;
  %put ERROR: <verbose> does not have a valid value!;
  %goto end_of_macro;  
%end;

%if &verbose = y %then %do;
  %put calculate_sd: *** Input checks ***;
%end;

/* print_notes: check parameter not empty. */
%if &print_notes = %then %do;
  %put ERROR: Macro parameter <print_notes> not specified!;
  %goto end_of_macro;  
%end;

/*print_notes: check parameter has valid value. */
%if (&print_notes in y n) = 0 %then %do;
  %put ERROR: <print_notes> does not have a valid value!;
  %goto end_of_macro;  
%end;

%if &print_notes = y %then %do;
  options notes;
%end;   

/* Check remaining macro parameters (except where) not empty. */
%local parms i i_parm;
%let parms = in_ds out_ds var strata weight n_xvalues del;   
%do i = 1 %to %sysfunc(countw(&parms, %str( )));
  %let i_parm = %scan(&parms, &i, %str( ));
  %if %bquote(&&&i_parm) = %then %do;
    %put ERROR: Macro parameter <&i_parm> not specified!;
    %goto end_of_macro;    
  %end;
%end;

/* in_ds: check input dataset exists. */
%if %sysfunc(exist(&in_ds)) = 0 %then %do;
  %put ERROR: Specified <in_ds> dataset "&in_ds" does not exist!;
  %goto end_of_macro;
%end;

/* in_ds: check input dataset not empty. */
%local ds_id rc;
%let ds_id = %sysfunc(open(&in_ds));
%if  %sysfunc(attrn(&ds_id, nobs)) = 0 %then %do;
  %let rc = %sysfunc(close(&ds_id));
  %put ERROR: Specified <in_ds> dataset "&in_ds" is empty!;
  %goto end_of_macro;
%end;
%let rc = %sysfunc(close(&ds_id));

/* out_ds: Outcome dataset needs to be a valid (libname.)member-name.
Regular expression: (lib-name.)member-name, where the libname is
optional. The libname must start with a letter, followed by 0-7 letters, 
numbers or underscores and must end with a ".". Member-name part must start
with a letter or underscore, and is followed by 0-31 letters, numbers or 
underscores. The whole regular expression is case-insensitive. */
%if %sysfunc(prxmatch('^([a-z][\w\d]{0,7}\.)*[\w][\w\d]{0,31}$', &out_ds)) = 0 
  %then %do;
  %put ERROR: Output dataset name specified in <out_ds> is invalid.;
  %put ERROR: Must be as (libname.)member-name!;
  %goto end_of_macro; 
%end;

/* Check specified variable names are valid, exists in the input dataset, 
and that none of the specified variables have a "__" prefix. */
%local var_list i i_var j j_var ds_id rc;
%let var_list = var;
%if &weight ne _null_ %then %let var_list = &var_list weight;
%if &strata ne _null_ %then %let var_list = &var_list strata;
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var = %scan(&var_list, &i, %str( ));
  %do j = 1 %to %sysfunc(countw(&&&i_var, %str( )));
    %let j_var = %scan(&&&i_var, &j, %str( ));
    %if %sysfunc(nvalid(&j_var)) = 0 %then %do;
      %put ERROR: Variable "&j_var" specified in <&i_var>;
      %put ERROR: is not a valid SAS variable name!;
      %goto end_of_macro;
    %end;
    %let ds_id = %sysfunc(open(&in_ds));
    %if %sysfunc(varnum(&ds_id, &j_var)) = 0 %then %do;
      %let rc = %sysfunc(close(&ds_id));
      %put ERROR: Variable "&j_var" specified in <&i_var> does;
      %put ERROR: not exist in the input dataset "&in_ds"!;
      %goto end_of_macro; 
    %end;
    %let rc = %sysfunc(close(&ds_id));
    /* Note that "dummy" has been included in %qsubstr call so that a 
    variable name of length one can be handled correctly. */
    %if %qsubstr(&j_var dummy, 1, 2) = __ %then %do;
      %put ERROR: Variable "&j_var" specified in <&i_var> has a "__" prefix;
      %put ERROR: This is not allowed to make sure that input variables are not;
      %put ERROR: overwritten by temporary variables created by the macro!;
      %goto end_of_macro; 
    %end;
  %end; /* End of j-loop */
%end; /*End of i-loop */

/* var: Check numerical variables. */
%do i = 1 %to %sysfunc(countw(&var, %str( )));
  %local __&i._vt;
%end;
data __cdf_num_var1;
  set &in_ds(obs = 1);
  %do i = 1 %to %sysfunc(countw(&var, %str( )));
    %let i_var = %scan(&var, &i, %str( ));
    __&i._vt = vtype(&i_var);
    call symput("__&i._vt", __&i._vt);
    keep __&i._vt;
  %end;
run;

%do i = 1 %to %sysfunc(countw(&var, %str( )));
  %let i_var = %scan(&var, &i, %str( ));
  %if &&__&i._vt ne N %then %do;
    %put ERROR: Variable "&i_var" in <var> is not numeric!;
    %goto end_of_macro; 
  %end;
%end;

/* var: Check no missing values. */
%do i = 1 %to %sysfunc(countw(&var, %str( )));
  %local __&i._nmiss;
%end;

proc sql noprint;
  select 
  %do i = 1 %to %sysfunc(countw(&var, %str( )));
    %let i_var = %scan(&var, &i, %str( ));
    %if &i ne 1 %then %do; , %end;
    nmiss(&i_var) 
  %end;
  into 
  %do i = 1 %to %sysfunc(countw(&var, %str( )));
    %let i_var = %scan(&var, &i, %str( ));
    %if &i ne 1 %then %do; , %end;
    :__&i._nmiss 
  %end;
  from &in_ds;
quit;

%do i = 1 %to %sysfunc(countw(&var, %str( )));
  %let i_var = %scan(&var, &i, %str( ));
  %if &&__&i._nmiss ne 0 %then %do;
    %put ERROR: Variable "&i_var" in <var> has missing values!;
    %goto end_of_macro; 
  %end;
%end;

/* var: check no duplicates. */
%local i i_var cnt j;
%do i = 1 %to %sysfunc(countw(&var, %str( )));
  %let i_var = %scan(&var, &i, %str( ));
  %let cnt = 0;
  %do j = 1 %to %sysfunc(countw(&var, %str( )));
    %if &i_var = %scan(&var, &j, %str( )) 
      %then %let cnt = %eval(&cnt + 1);
  %end;
  %if %sysevalf(&cnt > 1) %then %do;
    %put ERROR: Variable "&i_var" is included multiple times in <var>;
    %goto end_of_macro;
  %end;
%end;

/* strata: check no duplicates. */
%local i i_var j cnt;
%do i = 1 %to %sysfunc(countw(&strata, %str( )));
  %let i_var = %scan(&strata, &i, %str( ));
  %let cnt = 0;
  %do j = 1 %to %sysfunc(countw(&strata, %str( )));
    %if &i_var = %scan(&strata, &j, %str( )) 
      %then %let cnt = %eval(&cnt + 1);
  %end;
  %if %sysevalf(&cnt > 1) %then %do;
    %put ERROR: Variable "&i_var" is included multiple times in <strata>;
    %goto end_of_macro;
  %end;
%end;

/* weight: check only one variable specified */
%if %sysfunc(countw(&weight, %str( ))) ne 1 %then %do;
  %put ERROR: Only one <weight> variable can be specified!;
  %goto end_of_macro;
%end;

/* weight: check numerical variable */
%if &weight ne _null_ %then %do;
  %local w_var_type;
  data __cdf_w_var_type;
    set &in_ds(obs = 1 keep = &weight);
    w_var_type = vtype(&weight);
    call symput("w_var_type", w_var_type);
  run;

  %if &w_var_type ne N %then %do;
    %put ERROR: <weight> must be a numerical variable!;
    %goto end_of_macro;
  %end;
%end;

/* weight: check no missing or negative weights */
%if &weight ne _null_ %then %do;
  %local min_w nmiss_w;
  proc sql noprint;
    select min(&weight), nmiss(&weight) into :min_w, :nmiss_w
      from &in_ds;
  quit;

  %if %sysevalf(&nmiss_w > 0) %then %do;
    %put ERROR: <weight> variable has missing values!;
    %goto end_of_macro;
  %end;
  %if %sysevalf(&min_w < 0) %then %do;
    %put ERROR: <weight> variable has negative values!;
    %goto end_of_macro;
  %end;
%end;

/* del: Check del parameter has valid value. */          
%if %eval(&del in n y) = 0 %then %do;
  %put ERROR: <del> does not have a valid value!;
  %goto end_of_macro;
%end;

/******************************************************************************
Load input data
******************************************************************************/

%if &verbose = y %then %do;
  %put calculate_sd: *** Load data ***;
%end;

data __cdf_dat1;
  set &in_ds;
  where &where;
  %if &weight = _null_ %then %do;
    __w = 1;
  %end;
  %else %do;
    __w = &weight;
    drop &weight;
  %end;
  %if &strata = _null_ %then %do;
    __strata_dummy = "dummy";
    keep __strata_dummy;
  %end;
  %else %do;
    keep &strata;
  %end;

  keep __w &var;
run;

%if &strata = _null_ %then %let strata = __strata_dummy;

/* If the specified where-condition results in any warnings or errors,
the macro is terminated. */
%if &syserr ne 0 %then %do;
  %put ERROR- The specified <where> condition:;
  %put ERROR- &where;
  %put ERROR- produced a warning or an error. Macro terminated!;
  %goto end_of_macro; 
%end;

/* Restructure variable data on long form */
data __cdf_dat2;
  set __cdf_dat1;
  length __variable $32;
  %do i = 1 %to %sysfunc(countw(&var, %str( )));
    %let i_var = %scan(&var, &i, %str( ));
    __variable = "&i_var";
    __value = &i_var;
    output;
    drop &i_var;
  %end;
run;

/* Make a combined strata variable */
proc sort data = __cdf_dat2(drop = __w __value) out = __cdf_strata_key1 nodupkeys;
  by &strata __variable;
run;

data __cdf_strata_key2;
  set __cdf_strata_key1;
  __strata = _n_;
run;

proc sql;
  create table __cdf_dat3 as
    select b.__strata, a.__w, a.__value
    from __cdf_dat2 as a
    left join
    __cdf_strata_key2 as b
    on a.__variable = b.__variable
    %do i = 1 %to %sysfunc(countw(&strata, %str( )));
      %let i_var = %scan(&strata, &i, %str( ));
      and a.&i_var = b.&i_var
    %end;
    order by __strata, __value;
quit;
  

/******************************************************************************
Calculate empirical CDF
******************************************************************************/

%if &verbose = y %then %do;
  %put empirical_cdf: *** Calculate CDF ***;
%end;

/* Find the number of strata. */
%local n_strata;
proc sql noprint;
  select count(*) into :n_strata
  from __cdf_strata_key2;
quit;

/* Find 10 approximately evenly spaced out strata values, and calculate the 
percentage of progress that have been made at each point. */
data __cdf_progress;
  do i = 1 to 10;
    progress_strata = ceil(i * &n_strata / 10);
    progress_pct = compress(put(progress_strata / &n_strata, percent10.));
    output;
  end;
  drop i;
run;

%local progress_strata progress_pct;
proc sql noprint;
  select distinct progress_strata, progress_pct
    into :progress_strata separated by "$" 
         ,:progress_pct separated by "$"
    from __cdf_progress;
quit;

/* Disable notes in log irrespective of the value of the
print_notes parameter. */
options nonotes;

/* Calculate the empirical CDF in each strata. */
%do i = 1 %to &n_strata;

 %if &i = 1 %then %do;
    %put CDF calculations progress:;
    %put %sysfunc(datetime(), datetime32.): %str(  0%%);
  %end;

  %local time_start;
  %let time_start = %sysfunc(datetime());

  /* Restrict data to strata. */
  data __cdf_strata1;
    set __cdf_dat3;
    where __strata = &i;
  run;

  /* Calculate sum of weights, and min and max variable value. */
  proc means data = __cdf_strata1 nway noprint;
    class __strata;
    var __w __value;
    output out = __cdf_w1(drop = _type_ _freq_) 
      sum(__w) = __w_sum 
      min(__value) = __value_min
      max(__value) = __value_max
      / noinherit;
  run;


  /* Calculate evenly spread x-values */
  data __cdf_w2;
    set __cdf_w1;
    do __i = 1 to &n_xvalues;
    __x = __value_min + (__i - 1) / %eval(&n_xvalues -1) * (__value_max - __value_min);
    output;
    end;
    drop __i __value_min __value_max;
  run;

  /* Many-to-many join the merges the summed weights to the data, and makes a copy
  of the data for each x-value while at the same time restricting the copy to only
  include observations where x_i <= x. */
  proc sql;
    create table __cdf_strata2 as
      select a.*, b.__w_sum, b.__x
      from __cdf_strata1 as a
      right join __cdf_w2 as b
      on a.__strata = b.__strata and a.__value <= __x
      order by b.__x, a.__value;
  quit;

  /* Summarize data. Because of the previous merge, summing __w is now
  equivalent to calculating w_i * I(x_i_x). */
  proc means data = __cdf_strata2 noprint nway;
    class __strata __x __w_sum;
    var __w;
    output out = __cdf_strata3(drop = _type_ _freq_) 
      sum(__w) = __I_sum
      / noinherit;
  run;

  data __cdf_strata4;
    set __cdf_strata3;
    __cdf = __I_sum / __w_sum;
    drop __w_sum __I_sum;
  run;

  /* Combine results. */
  %if &i = 1 %then %do;
    data __cdf_all_strata1;
      set __cdf_strata4;
    run;
  %end;
  %else %do;
    proc append base = __cdf_all_strata1 data = __cdf_strata4;
    run;
  %end;

  %local time_stop duration;
  %let time_stop = %sysfunc(datetime());
  %let duration = %sysevalf(&time_stop - &time_start);

  /* Estimate time until all calculations are done, based on the median
  matching time in the stratas so far. */
  %local duration_all duration_median est_finish;
  %if &i = 1 %then %let duration_all = &duration;
  %else %let duration_all = &duration_all, &duration;
  %let duration_median = %sysfunc(median(&duration_all));
  %let est_finish = 
    %left(%qsysfunc(
      putn(
        %sysevalf(&time_stop + &duration_median * (&n_strata - &i)), 
        datetime32.
      )
    ));

  /* Print matching progress info to log. */
  %local j j_strata j_pct;
  %do j = 1 %to %sysfunc(countw(&progress_strata, $));
    %let j_strata = %scan(&progress_strata, &j, $);
    %let j_pct = %scan(&progress_pct, &j, $);
    %if &i = &j_strata %then %do;
      %if &i ne &n_strata %then %do;
        %put %sysfunc(datetime(), datetime32.): %str( &j_pct) (est. finish: &est_finish);
      %end;
      %else %do;
        %put %sysfunc(datetime(), datetime32.): &j_pct (est. finish: &est_finish);
      %end;
    %end;
  %end; /* End of j-loop */
%end; /* End of i-loop */

%if &print_notes = y %then %do;
  options notes;
%end;


/******************************************************************************
Make output dataset
******************************************************************************/

%if &verbose = y %then %do;
  %put empirical_cdf: *** Make output data ***;
%end;

proc sql;
  create table &out_ds(
      drop = __strata %if &strata = __strata_dummy %then %do; __strata_dummy %end;
    ) as
    select b.*, a.__x, a.__cdf
      from __cdf_all_strata1 as a
      left join
      __cdf_strata_key2 as b
      on a.__strata = b.__strata
      order by a.__strata, a.__x;
quit;


%end_of_macro:

/* Delete temporary datasets created by the macro. */
%if &del ne n  %then %do;
  proc datasets nodetails nolist;
    delete __cdf_:;
  run;
  quit;
%end; 

/* Restore value of notes option */
options &opt_notes;

%put empirical_cdf: end execution;

%mend empirical_cdf;
