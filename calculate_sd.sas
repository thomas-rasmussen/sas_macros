/*******************************************************************************
AUTHOR:     Thomas Boejer Rasmussen
VERSION:    0.1.1
********************************************************************************
DESCRIPTION:
Calculates standardized differences (SD) of variables between two groups.

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros

DETAILS:
The standardized difference is calculated using a commonly used variation 
of formula (1) in 

"Moving towards best practice when using inverse probability of treatment 
weighting (IPTW) using the propensity score to estimate causal treatment 
effects in observational studies (Austin 2015)",

namely

SD = abs(x_t - x_c) / sqrt((s_t^2 - s_c^2) / 2)

1) The absolute value of the numerator is used since the sign of the SD is 
not typically used when evalutating balance in any case.
2) SD not calculated as percent, ie we do not multiply with 100. This feels
like a more natural scale since the balance is typically evaluated based on
the SD being below/over 0.1, not below/over 10.

Dichotomous variables will be treated as continuous variables, and the 
sd calculated using the above formula because it is more convinient. 
Formula (2) from the article is specifically for dichotomous variables and is 
not identical to formula (1), because s^2 = n/(n-1)*p. But, as n increases the 
difference will get smaller, and even for small n, the calculated SD's seems to
be nearly identical. See tests for examples of comparisons of the two formulas
on simulated data.

Categorical variables will be handled by replacing them with a set of 
dichtomous variables where the SD is calculated for each of those instead. The
justification for this not based on any litterature, but it seems like a 
reasonable approach that is also easy to implement. 
********************************************************************************
PARAMETERS:
*** REQUIRED ***
in_ds:        (libname.)member-name of input dataset.         
out_ds:       (libname.)member-name of output dataset with calculated 
              standardized differences.
group_var:    Grouping variable. Can only take two values. 
var:          Space-separated list of variables for whcih SD's are calculated.
              Variable types is automatically guessed by the macro, but can
              also be manually specified by giving a /d (dichotomous), 
              /cont (continuous), /cat (categorical) suffix to (some or all)
              variables, eg var = var1/cont var2/d var3/cat var4
*** OPTIONAL ***
weight:       Variable with observation weights. Default is weight = _null_, 
              ie no weights are used.
where:        Condition used to to restrict the input dataset in a where-
              statement. Use the %str function as a wrapper, , eg 
              where = %str(var = "value").
by:           Space-separated list of by variables. Default is by = _null_,
              ie no by variables.    
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
%macro calculate_sd(
  in_ds       = ,
  out_ds      = ,
  group_var   = ,
  var         = ,
  weight      = _null_,
  where       = %str(),
  by          = _null_,
  print_notes = n,
  verbose     = n,
  del         = y
) / minoperator mindelimiter = ' ';

%put calculate_sd: start execution;

/* Find value of notes option, save it, then disable notes */
%local opt_notes;
%let opt_notes = %sysfunc(getoption(notes));
options nonotes;

/* Make sure there are no intermediate dataset from from a previous 
run of the macro in the work directory before execution. */
proc datasets nolist nodetails;
  delete __sd_:;
run;
quit;


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
%let parms = in_ds out_ds group_var var weight by del;   
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

/* var: parse variable names and optional variable types. */
%if &verbose = y %then %do;
  %put calculate_sd: - Specified variables (and variable types);
  %put calculate_sd:   var = &var;
%end;

%local tmp var_type i i_var i_type i_tmp;
%let tmp = &var;
%let var = ;
%do i = 1 %to %sysfunc(countw(&tmp, %str( )));
  %let i_tmp = %scan(&tmp, &i, %str( ));
  %let i_var = %scan(&i_tmp, 1, /);
  %let i_type = %scan(&i_tmp, 2, /);
  /* If not variable type has been specified, set to u (unknown). */
  %if &i_type = %then %let i_type = u;
  %let var = &var &i_var;
  %let var_type = &var_type &i_type;
%end;

%if &verbose = y %then %do;
  %put calculate_sd: - Variables and corresponding types after parsing:;
  %put calculate_sd:   var = &var;
  %put calculate_sd:   var_type = &var_type;
%end;

/* var: check valid variable types have been specified. */
%local i i_type;
%do i = 1 %to %sysfunc(countw(&var_type, %str( )));
  %let i_type = %scan(&var_type, &i, %str( ));
  %if (&i_type in u d cont cat) = 0 %then %do;
    %put ERROR: "&i_type" is not a valid variable type!;
    %put ERROR: Use /d (dichotomous), /cat (categorical), or /cont (continuous);
    %goto end_of_macro;    
  %end;
%end;

/* Check specified variable names are valid, exists in the input dataset, 
and that none of the specified variables have a "__" prefix. */
%local var_list i i_var j j_var ds_id rc;
%let var_list = var group_var;
%if &weight ne _null_ %then %let var_list = &var_list weight;
%if &by ne _null_ %then %let var_list = &var_list by;
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

/* Outcome dataset needs to be a valid (libname.)member-name.
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

/* group_var: check only one variable specified. */
%if %eval(%sysfunc(countw(&group_var, %str( ))) > 1) %then %do;
  %put ERROR: Only one <group_var> variable can be specified!;
  %goto end_of_macro;
%end;

/* group_var: check has at most two values. */
proc sort data = &in_ds out = __sd_group_var_val1(keep = &group_var) nodupkeys;
  by &group_var;
run;

%local group_var_nval;
proc sql noprint;
  select count(*) into :group_var_nval 
    from __sd_group_var_val1;
quit;

%if %eval(&group_var_nval > 2) %then %do;
  %put ERROR: The variable "&group_var" specified in <group_var> takes more;
  %put ERROR: than two different values!;
  %goto end_of_macro; 
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

/* weight: check only one variable specified */
%if %sysfunc(countw(&weight, %str( ))) ne 1 %then %do;
  %put ERROR: Only one <weight> variable can be specified!;
  %goto end_of_macro;
%end;

/* weight: check numerical variable */
%if &weight ne _null_ %then %do;
  %local w_var_type;
  data __sd_w_var_type;
    set &in_ds(obs = 1 keep = &weight);
    w_var_type = vtype(&weight);
    call symput("w_var_type", w_var_type);
  run;

  %if &w_var_type ne N %then %do;
    %put ERROR: <weight> must be a numerical variable!;
    %goto end_of_macro;
  %end;
%end;

/* weight: check no negative weights */
%if &weight ne _null_ %then %do;
  %local min_w;
  proc sql noprint;
    select min(&weight) into :min_w
      from &in_ds;

  %if %sysevalf(&min_w < 0) %then %do;
    %put ERROR: <weight> variable has negative values!;
    %goto end_of_macro;
  %end;
%end;

/* by: check no duplicates. */
%local i i_var j cnt;
%do i = 1 %to %sysfunc(countw(&by, %str( )));
  %let i_var = %scan(&by, &i, %str( ));
  %let cnt = 0;
  %do j = 1 %to %sysfunc(countw(&by, %str( )));
    %if &i_var = %scan(&by, &j, %str( )) 
      %then %let cnt = %eval(&cnt + 1);
  %end;
  %if %sysevalf(&cnt > 1) %then %do;
    %put ERROR: Variable "&i_var" is included multiple times in <by>;
    %goto end_of_macro;
  %end;
%end;

/* del: Check del parameter has valid value. */          
%if %eval(&del in n y) = 0 %then %do;
  %put ERROR: <del> does not have a valid value!;
  %goto end_of_macro;
%end;


/******************************************************************************
LOAD INPUT DATA
******************************************************************************/

%if &verbose = y %then %do;
  %put calculate_sd: *** Load data ***;
%end;

/* Load input data and make variables to facilitate the analyses. */
data __sd_dat1;
  set &in_ds;
  where &where;
  %if &weight = _null_ %then %do; 
    __w = 1; 
  %end;
  %else %do; 
    __w = &weight; 
    drop &weight;
  %end;
  __w2 = __w**2;
  %if &by = _null_ %then %do; __by = "dummy"; %end;
  keep __: &group_var &var %if &by ne _null_ %then %do; &by %end;;
run;

/* If the specified where-condition results in any warnings or errors,
the macro is terminated. */
%if &syserr ne 0 %then %do;
  %put ERROR- The specified "where" condition:;
  %put ERROR- &where;
  %put ERROR- produced a warning or an error. Macro terminated!;
  %goto end_of_macro; 
%end;

%if &verbose = y %then %do;
  %put calculate_sd: - Input data succesfully loaded;
%end;

/* Make a new grouping variable to facilite the analyses. */
proc sort data = __sd_dat1 out = __sd_group1(keep = &group_var) nodupkeys;
  by &group_var;
run;

data __sd_group2;
  set __sd_group1;
  __group_var = _n_;
run;

proc sql;
  create table __sd_dat2(drop = &group_var) as 
    select a.*, b.__group_var
    from __sd_dat1 as a
    left join
    __sd_group2 as b
    on a.&group_var = b.&group_var;
quit;

%if %eval(&verbose = y and &by = _null_) %then %do;
  %put calculate_sd: - No by variables specified. Create dummy by variable;
  %put calculate_sd:   by = __by;
%end;
%if &by = _null_ %then %let by = __by;


/******************************************************************************
DETERMINE VARIABLE TYPES
******************************************************************************/

%if &verbose = y %then %do;
  %put calculate_sd: *** Determine variable types ***;
%end;

/* Find information on the variables specified in <var>. */
%local i i_var;
proc sql;
  create table __sd_type1 as
    select
      %do i = 1 %to %sysfunc(countw(&var, %str( )));
        %let i_var = %scan(&var, &i, %str( ));
        count(distinct(&i_var)) as __&i._nvalues,
        nmiss(&i_var) as __&i._nmiss,
        cats(min(&i_var)) as __&i._min,
        cats(max(&i_var)) as __&i._max,
      %end;
      1 as __dummy
      from __sd_dat2;
quit;

data __sd_type2;
set __sd_dat2(obs = 1);
  %do i = 1 %to %sysfunc(countw(&var, %str( )));
    %let i_var = %scan(&var, &i, %str( ));
    __&i._vt = vtype(&i_var);
    keep __&i._vt;
  %end;
  __dummy = 1;
  keep __dummy;
run;

data __sd_type3; 
  merge __sd_type1 __sd_type2;
  by __dummy;
run;

/* Determine variable types */
%local i i_var i_type;
data __sd_type4; 
  set __sd_type3;
  %do i = 1 %to %sysfunc(countw(&var, %str( )));
    %let i_var = %scan(&var, &i, %str( ));
    %let i_type = %scan(&var_type, &i, %str( ));
    format __&i._type $4.;
    /* If unknown (u) variable type we guess the type based on the data */
    %if &i_type = u %then %do;
      
      /* If character, assume categorical variable */
      if __&i._vt = "C" then __&i._type = "cat";
      /* Else, if the variable only takes the values zero and/or one (besides 
      missing values) then we will assume it's dichotomous. */
      else if 1 <= __&i._nvalues <= 2 and __&i._min in ("0" "1") 
        and __&i._max in ("0" "1") then __&i._type = "d";  
      /* Else, if the number of distinct values is <= 20, assume 
      that the variable is categorical. */
      else if __&i._nvalues <= 20 then __&i._type = "cat"; 
      /* Else we assume the variable is continuous. */
      else __&i._type = "cont";
    %end;
    %else %do;
      __&i._type = "&i_type";
    %end;
    /* Correction of nvalues if there are categorical variables
    with empty string values. */
    if __&i._type = "cat" and __&i._nmiss > 0 
      then __&i._nvalues = __&i._nvalues + 1; 
  %end;

  /* Make sure that the data is compatible with variable types in case
  they have been manually specified. */
  %do i = 1 %to %sysfunc(countw(&var, %str( )));
    if __&i._type = "d" and 
      (__&i._min ^in ("0" "1") or __&i._max ^in ("0" "1") or __&i._vt = "C")
      then __&i._fail = 1;
    if __&i._type = "cont" and __&i._vt = "C" then __&i._fail = 1;
  %end;
run;

%if &verbose = y %then %do;
  %put calculate_sd: - Variable types before automatic guessing:;
  %put calculate_sd:   var_type = &var_type;
%end;

/* Update var_type macro variable. */
%local i_type;
%let var_type = ;
%do i = 1 %to %sysfunc(countw(&var, %str( )));
  %local __&i._type;
  proc sql noprint;
    select __&i._type into :__&i._type
      from __sd_type4;
  quit;
  %let var_type = &var_type &&__&i._type;
%end;

%if &verbose = y %then %do;
  %put calculate_sd: - Variable types after automatic guessing:;
  %put calculate_sd:   var_type = &var_type;
%end;

/* Terminate macro if incompatible variable types
have been selected. */
%do i = 1 %to %sysfunc(countw(&var, %str( )));
  %let i_var = %scan(&var, &i, %str( ));
  %let i_type = %scan(&var_type, &i, %str( ));
  %local __&i._fail;
  proc sql noprint;
    select __&i._fail into :__&i._fail
    from __sd_type4;
  quit;

  %if &&__&i._fail = 1 %then %do;
    %put ERROR: Variable type "&i_type" for variable "&i_var" in <var>;
    %put ERROR: is not compatible with the data!;
    %goto end_of_macro;   
  %end;
%end;


/******************************************************************************
Replace categorical variables
******************************************************************************/

%if &verbose = y %then %do;
  %put calculate_sd: *** Replace categorical variables ***:;
  %put calculate_sd: - Variables before replacing categorical variables:;
  %put calculate_sd:   &var;
%end;

%local i i_var i_type tmp;
%let tmp = &var;
%let var = ;
%do i = 1 %to %sysfunc(countw(&var_type, %str( )));
  %let i_var = %scan(&tmp, &i, %str( ));
  %let i_type = %scan(&var_type, &i, %str( ));
  %if &i_type = cat %then %do;
    /* Find distrinct variable values. */
    proc sort data = __sd_dat2(keep = &i_var) out = __sd_cat1 nodupkeys;
      by &i_var;
    run;

    proc sql noprint;
      select count(*) into :n_cats
      from __sd_cat1;
    quit;

    /* Add set of dichotomous variables. */
    data __sd_cat2;
      set __sd_cat1;
      %do j = 1 %to &n_cats;
        __&i._cat_&j = (_n_ = &j);
      %end;
    run;

    /* Make dataset with variable names and corresponding labels
    to be used in the output. */
    data __sd_cat_label_&i.;
      set __sd_cat2;
      length __var __label $200;
      %do j = 1 %to &n_cats;
        if __&i._cat_&j = 1 then do;
          __var = "__&i._cat_&j";
          __label = "&i_var: " || left(&i_var);
          keep __var __label;
          output;
        end;
      %end;
    run;

    /* Merge dichomous variables to the data */
    proc sort data = __sd_dat2;
      by &i_var;
    run;

    data __sd_dat2;
      merge __sd_dat2 __sd_cat2;
      by &i_var;
    run;

    %local tmp_vars j;
    %let tmp_vars = ;
    %do j = 1 %to &n_cats;
      %let tmp_vars = &tmp_vars __&i._cat_&j;
    %end;
    %let var = &var &tmp_vars; 
  %end;
  %else %do;
    %let var = &var &i_var;
  %end;
%end; /* End of i-loop */

/* Create dummy dataset */
data __sd_cat_label_dummy;
  length __var __label $200;
  __var = "__dummy";
  __label = "__dummy";
run;

/* Combine all datasets with labels and variable names. */
data __sd_cat_labels;
  set __sd_cat_label_:;
run;

%if &verbose = y %then %do;
  %put calculate_sd: - Variables after replacing categorical variables:;
  %put calculate_sd:   &var;
%end;


/******************************************************************************
Calculate SD for all variables
******************************************************************************/

%if &verbose = y %then %do;
  %put calculate_sd: *** Calculate SD%str(%')s ***;
%end;

/* Restructure data */
%local i i_var;
data __sd_dat3;
  set __sd_dat2;
  length __var $50.;
  %do i = 1 %to %sysfunc(countw(&var, %str( )));
    %let i_var = %scan(&var, &i, %str( ));
    __var = "&i_var";
    __value = &i_var;
    output;
  %end;
  keep &by __group_var __w __w2 __var __value;
run;


/* Estimate means and variances, using sum_w as divisor. */
proc means data = __sd_dat3 noprint vardef = wgt nway;
  class &by __var __group_var;
  weight __w;
  output out = __sd_dat4
    mean(__value) = __value_mean
    var(__value) = __value_var
  / noinherit;
run;

/* Calculate sum of weights */
proc means data = __sd_dat3 noprint nway;
  class &by __var __group_var;
  var __w __w2;
  output out = __sd_w1
    sum(__w __w2) = __w_sum __w2_sum
  / noinherit;
run;

data __sd_dat5;
  merge __sd_dat4 __sd_w1;
  by &by __var __group_var;
  /* Make correction of variance estimate */
  __value_var = __w_sum * ((__w_sum) / (__w_sum**2 - __w2_sum)) * __value_var;
  retain __value_mean_0 __value_mean_1 __value_var_0 __value_var_1;
  if first.__var then do;
    __value_mean_0 = __value_mean;
    __value_var_0 = __value_var;
  end;
  else do;
    __value_mean_1 = __value_mean;
    __value_var_1 = __value_var;
  end;
  if last.__var;

  if __value_var_0 + __value_var_1 > 0 then 
    __sd = 
      abs(__value_mean_0 - __value_mean_1) 
      / sqrt((__value_var_0 + __value_var_1) / 2);
  else __sd = .;
  keep &by __var __sd;
run;


/******************************************************************************
Make output dataset
******************************************************************************/

%if &verbose = y %then %do;
  %put calculate_sd: *** Make output data ***;
%end;

/* Make sorting variable */
%local i i_var;
data __sd_dat6;
  set __sd_dat5;
  %do i = 1 %to %sysfunc(countw(&var, %str( )));
    %let i_var = %scan(&var, &i, %str( ));
    if __var = "&i_var" then __sort = &i;
  %end;
run;

/* Merge with labels */
proc sql;
  create table __sd_dat7 as
    select a.*, b.__label
    from __sd_dat6 as a
    left join
    __sd_cat_labels as b
    on a.__var = b.__var
    order by 
      %do i = 1 %to %sysfunc(countw(&by, %str( )));
        %let i_by = %scan(&by, &i, %str( ));
        &i_by,
      %end;
      __sort;
quit;

data &out_ds;
  retain &by;
  set __sd_dat7;
  if __label ne "" then __var = __label;
  drop __label __sort;
  %if &by = __by %then %do; drop __by; %end;
run;


%end_of_macro:


/* Delete temporary datasets created by the macro. */
%if &del ne n  %then %do;
  proc datasets nodetails nolist;
    delete __sd_:;
  run;
  quit;
%end; 


/* Restore value of notes option */
options &opt_notes;

%put calculate_sd: end execution;

%mend calculate_sd;
