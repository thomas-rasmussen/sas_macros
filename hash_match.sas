/*******************************************************************************
AUTHOR:     Thomas Boejer Rasmussen
VERSION:    0.3.1
********************************************************************************
DESCRIPTION:
Matching using a hash-table merge approach. The input dataset is expected to be 
a source population with the date, if any, each person is to be matched with a 
set of controls from the source population that fulfills specified matching 
criterias. Controls are selected by randomly picking potential controls until 
the desired amount of controls have been found or the limit of maximum tries
is reached.

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros
********************************************************************************
PARAMETERS:
*** REQUIRED ***
in_ds:          (libname.)member-name of input dataset with source population.         
out_pf:         (libname.)member-name prefix of output datasets. The following
                datasets are created by the macro:
                <out_pf>_matches: Matched population. Note that the matched
                population also includes matched sets where only some of the
                desired number of controls could be found.
                <out_pf>_incomp_info: Information on cases for which 
                incomplete, ie no or only some matches could be found.
                <out_pf>_match_info: Miscellaneous information and 
                diagnostics on the results of the matching procedure.
match_date:     Date, if any, the person/case is to be matched with
                a set of controls. Must be a numeric variable.
*** OPTIONAL ***
match_exact:    Space-separated list of (exact) matching variables. Default 
                is match_exact = _null_, ie no matching variables are used. 
match_inexact:  Inexact matching conditions. Use the %str function to 
                specify conditions, eg. 
                match_inexact = %str(
                  abs(<var1> - _ctrl_<var1>) <= 5 and <var2> ne _ctrl_<var2>
                )
                Here <var1> and <var2> are variables from the input dataset, 
                and _ctrl_<var1> and _ctrl_<var2> are variables created by the 
                macro. The <var> variables corresponds to case values, and 
                _ctrl_<var> corresponds to (potential) control values.
                Default is match_inexact = %str(), eg no (inexact) matching 
                conditions are specified.
                Note that care should be taken when using this parameter.
                Misspelling a variable name will not result in errors, and
                it might not be obvious from the output that an error in
                the specification has been made. Always check that the 
                matching conditions are actually fulfilled in the output data.
                See examples.
n_controls:     Number of controls to match to each case. 
                Default is n_controls = 10.
replace:        Match with replacement:
                - Yes: replace = y (default)
                - No:  replace = n  
                Note: Matching without replacement is less efficient (but
                still fast) when the control to case ratio is small. The
                reason for this is very technical and has to do with how 
                controls are selected at random from the hash-table during
                matching. See code for more information.
keep_add_vars:  Space-separated list of additional variables from the input 
                to include in the output datasets. Variables 
                specified in other macro parameters are automatically kept 
                and does not need to be specified, the exception being the
                variable specified in <match_date> that's not included in its
                original form in the output, and any variables used in 
                <where>. All variables from the input dataset can be kept 
                using keep_add_vars = _all_.
                Default is keep_add_vars = _null_, ie keep no additional 
                variables.
where:          Condition used to to restrict the input dataset in a where-
                statement. Use the %str function as a wrapper, , eg 
                where = %str(var = "value").
by:             Space-separated list of by variables. Default is by = _null_,
                ie no by variables. 
limit_tries:    The maximum number of tries to find all matches for each
                case is defined as
                  max_tries = min(<n_controls> * n_99pct, <limit_tries>)
                where 
                  n_99pct = round(k*[log(k)- ln(-ln(p))]), p = 0.99
                is the approximate number of tries needed to have a 
                99% probability (100 * p), to have tried all potential 
                controls (k) at least once. We multiply this approximate 
                number with <n_controls>, and we take the minimum of this 
                number and <limit_tries>. This approach ensures that we are 
                reasonably sure that we have considered all potential 
                controls for each individual match that is made, and that we 
                can set a upper limit. Must be a positive integer.
                Default is limit_tries = 10**6. 
                n_99pct formula is from 
                https://math.stackexchange.com/questions/1155615/
                probability-of-picking-each-of-m-elements-at-least-once-after-
                n-trials.
seed:           Seed used for random number generation. Default is seed = 0,
                ie a random seed is used.
print_notes:    Print notes in log?
                - Yes: print_notes = y
                - No:  print_notes = n (default)
verbose:        Print info on what is happening during macro execution
                to the log:
                - Yes: verbose = y
                - No:  verbose = n (default)
del:            Delete intermediate datasets created by the macro:
                - Yes: del = y (default)
                - no:  del = n              
******************************************************************************/
%macro hash_match(
  in_ds         = ,
  out_pf        = ,
  match_date    = ,
  match_exact   = _null_,
  match_inexact = %str(),
  n_controls    = 10,
  replace       = y,
  keep_add_vars = _null_,
  where         = %str(),
  by            = _null_,
  limit_tries   = 10**6,
  seed          = 0,
  print_notes   = n,
  verbose       = n,
  del           = y
) / minoperator mindelimiter = ' ';

%put hash_match: start execution;


/* find value of notes option, save it, then disable notes */
%local opt_notes;
%let opt_notes = %sysfunc(getoption(notes));
options nonotes;

/* Make sure there are no intermediate dataset from from a previous 
run of the macro in the work directory before execution. */
proc datasets nolist nodetails;
  delete __hm_:;
run;
quit;

/*******************************************************************************
INPUT PARAMETER CHECKS 
*******************************************************************************/

/* verbose input checks. */
%if &verbose = %then %do;
  %put ERROR: Macro parameter "verbose" not specified!;
  %goto end_of_macro;  
%end;
%else %if (&verbose in y n) = 0 %then %do;
  %put ERROR: "verbose" does not have a valid value!;
  %goto end_of_macro;  
%end;
%else %if &verbose = y %then %do;
  %put hash_match: *** Input checks ***;
%end;

/* print_notes input checks. */
%if &print_notes = %then %do;
  %put ERROR: Macro parameter "print_notes" not specified!;
  %goto end_of_macro;  
%end;
%else %if (&print_notes in y n) = 0 %then %do;
  %put ERROR: "print_notes" does not have a valid value!;
  %goto end_of_macro;  
%end;
%else %if &print_notes = y %then %do;
  options notes;
%end;

/* Check that macro parameters are not empty. */
%local parms i i_parm;
%let parms = 
  in_ds out_pf match_date match_exact n_controls replace
  keep_add_vars by limit_tries seed del;   
%do i = 1 %to %sysfunc(countw(&parms, %str( )));
  %let i_parm = %scan(&parms, &i, %str( ));
  %if &&&i_parm = %then %do;
    %put ERROR: Macro parameter "&i_parm" not specified!;
    %goto end_of_macro;    
  %end;
%end;

/* Check input dataset exists. */
%if %sysfunc(exist(&in_ds)) = 0 %then %do;
  %put ERROR: Specified "in_ds" dataset "&in_ds" does not exist!;
  %goto end_of_macro;
%end;

/* Check input dataset is not empty. */
%local ds_id rc;
%let ds_id = %sysfunc(open(&in_ds));
%if  %sysfunc(attrn(&ds_id, nobs)) = 0 %then %do;
  %let rc = %sysfunc(close(&ds_id));
  %put ERROR: Specified "in_ds" dataset "&in_ds" is empty!;
  %goto end_of_macro;
%end;
%let rc = %sysfunc(close(&ds_id));

/* Check specified variable names are valid, exists in the input dataset, 
that none of the specified variables have a "__" or "_ctrl_ prefix,
and that each variable name has length of 25 or less. */

%local vars i i_var j j_var ds_id rc;
%let vars = match_date match_exact by keep_add_vars;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  /* Regular expression: variable must start with a letter or underscore,
  followed by 0-24 letters, numbers or underscores. The whole regular 
  expression is case-insensitive. */
  %do j = 1 %to %sysfunc(countw(&&&i_var, %str( )));
    %let j_var = %scan(&&&i_var, &j, %str( ));
    %if %sysfunc(prxmatch('^[\w][\w\d]{0,24}$', &j_var)) = 0 %then %do;
      %put ERROR: Specified variable "&j_var" in "&i_var" has length greater than 25;
      %put ERROR: which is not allowed!;
      %goto end_of_macro; 
    %end;
  %end;
  %do j = 1 %to %sysfunc(countw(&&&i_var, %str( )));
    %let j_var = %scan(&&&i_var, &j, %str( ));
    %if %sysfunc(nvalid(&j_var)) = 0 %then %do;
      %put ERROR: Variable "&j_var" specified in "&i_var";
      %put ERROR: is not a valid SAS variable name!;
      %goto end_of_macro;
    %end;
    %if (%lowcase(&j_var) in _null_ _all_) = 0 %then %do;
      %let ds_id = %sysfunc(open(&in_ds));
      %if %sysfunc(varnum(&ds_id, &j_var)) = 0 %then %do;
        %let rc = %sysfunc(close(&ds_id));
        %put ERROR: Variable "&j_var" specified in "&i_var" does;
        %put ERROR: not exist in the input dataset "&in_ds"!;
        %goto end_of_macro; 
      %end;
    %end;
    %let rc = %sysfunc(close(&ds_id));
    /* Note that "dummy" has been included in %qsubstr call so that a 
    variable name of length one can be handled correctly. */
    %if %sysevalf(%qsubstr(&j_var dummy, 1, 2) = __ or 
        %qsubstr(&j_var dummy, 1, 2) = _ctrl_) %then %do;
      %put ERROR: Variable "&j_var" specified in "&i_var" has a "__" or "_ctrl_" prefix;
      %put ERROR: This is not allowed to make sure that input variables are not;
      %put ERROR: overwritten by temporary variables created by the macro!;
      %goto end_of_macro; 
    %end;
  %end; /* End of j-loop */
%end; /*End of i-loop */

/* Identify which variables from the input dataset are specified
in "match_inexact". */
%if &verbose = y %then %do;
  %put hash_match: - Identify variables in;
  %put hash_match:   match_inexact = &match_inexact;
%end;

data  __hm_empty;
  set &in_ds(obs = 0);
run;

%local all_vars;
proc sql noprint;
  select distinct name into :all_vars separated by " "
    from sashelp.vcolumn
    where libname = "WORK" and memname = "__HM_EMPTY";
quit;

%local match_inexact_vars i i_var;
%let match_inexact_vars = ;
%do i = 1 %to %sysfunc(countw(&all_vars, %str( )));
  %let i_var = %lowcase(%scan(&all_vars, &i, %str( )));
  %if %sysfunc(prxmatch("&i_var", %lowcase(&match_inexact))) %then
    %let match_inexact_vars = &match_inexact_vars &i_var;
%end;

%if &verbose = y %then %do;
  %put hash_match:   Variables identified:;
  %put hash_match:   &match_inexact_vars;
%end;

/* Outcome dataset prefix needs to be a valid (libname.)member-name, 
where the member-name part can have a length of 20 at the most, to make sure 
that the output dataset names are not too long.

Regular expression: (lib-name.)member-name, where the libname is
optional. The libname must start with a letter, followed by 0-7 letters, 
numbers or underscores and must end with a ".". Member-name part must start
with a letter or underscore, and is followed by 0-19 letters ,numbers or 
underscores. The whole regular expression is case-insensitive. */
%if %sysfunc(prxmatch('^([a-z][\w\d]{0,7}\.)*[\w][\w\d]{0,19}$', &out_pf)) = 0 
  %then %do;
  %put ERROR: Specified "out_pf" output prefix "&out_pf" is either invalid;
  %put ERROR: or the member-name part has length greater than 20;
  %put ERROR: which is not allowed!;
  %goto end_of_macro; 
%end;

/* match_date input checks: check that only one variable is specified, and
that the variable is numeric. */
%if %eval(%sysfunc(countw(&match_date, %str( ))) > 1) %then %do;
  %put ERROR: Only one variable can be specified in "&match_date"!;
  %goto end_of_macro; 
%end;
%local var_vt;
data _null_;
  set &in_ds(obs = 1);
  call symput("var_vt", vtype(&match_date));  
run;
%if &var_vt ne N %then %do;
  %put ERROR: The variable specified in "match_date" must be numeric!;
  %goto end_of_macro;
%end;

/* match_exact check: Check no duplicates. */
%local i i_var j cnt;
%do i = 1 %to %sysfunc(countw(&match_exact, %str( )));
  %let i_var = %scan(&match_exact, &i, %str( ));
  %let cnt = 0;
  %do j = 1 %to %sysfunc(countw(&match_exact, %str( )));
    %if &i_var = %scan(&match_exact, &j, %str( )) 
      %then %let cnt = %eval(&cnt + 1);
  %end;
  %if %sysevalf(&cnt > 1) %then %do;
    %put ERROR: Variable "&i_var" is included multiple times in;
    %put ERROR: match_exact = &match_exact;
    %goto end_of_macro;
  %end;
%end;

/* Check n_control is a positive integer.
Regular expression: starts with a number 1-9, followed by, and ends with,
one or more digits (so that 0 is not allowed, but eg 10 is). */
%if %sysfunc(prxmatch('^[1-9]\d*$', &n_controls)) = 0 %then %do;
  %put ERROR: "n_controls" must be a positive integer!;
  %goto end_of_macro; 
%end;

/* by check: Check no duplicates. */
%local i i_var j cnt;
%do i = 1 %to %sysfunc(countw(&by, %str( )));
  %let i_var = %scan(&by, &i, %str( ));
  %let cnt = 0;
  %do j = 1 %to %sysfunc(countw(&by, %str( )));
    %if &i_var = %scan(&by, &j, %str( )) 
      %then %let cnt = %eval(&cnt + 1);
  %end;
  %if %sysevalf(&cnt > 1) %then %do;
    %put ERROR: Variable "&i_var" is included multiple times in;
    %put ERROR: by = &by;
    %goto end_of_macro;
  %end;
%end;

/* limit_tries check: Check positive integer. limit_tries is likely to be a 
large number which is easier to write on the form "10 ** x", so we evaluate 
the expression given in limit_tries before checking that it is an integer.
Regular expression: Starts with a number 1-9, followed by, and ends with,
one or more digits (so that 0 is not allowed, but eg 10 is). */
%if %sysfunc(prxmatch('^[1-9]\d*$', %sysevalf(&limit_tries))) = 0 %then %do;
  %put ERROR: "limit_tries" must be a positive integer!;
  %goto end_of_macro; 
%end;

/* Check seed is an integer. */
%if %sysfunc(prxmatch('^-*\d*$', &seed)) = 0 %then %do;
  %put ERROR: "seed" must be an integer!;
  %goto end_of_macro; 
%end;

/* Check that the replace and del macro parameters are specified 
correctly. */
%local parms i i_parm;
%let parms = replace del;            
%do i = 1 %to %sysfunc(countw(&parms, %str( )));
  %let i_parm = %scan(&parms, &i, %str( ));
  %if %eval(&&&i_parm in n y) = 0 %then %do;
    %put ERROR: "&i_parm" does not have a valid value!;
    %goto end_of_macro;
  %end;
%end;

%if &verbose = y %then %do;
  %put hash_match: - Input value of keep_add_vars:; 
  %put hash_match:   keep_add_vars = &keep_add_vars;
%end;

/* keep_add_vars check: Check no duplicates. */
%local i i_var j cnt;
%do i = 1 %to %sysfunc(countw(&keep_add_vars, %str( )));
  %let i_var = %scan(&keep_add_vars, &i, %str( ));
  %let cnt = 0;
  %do j = 1 %to %sysfunc(countw(&keep_add_vars, %str( )));
    %if &i_var = %scan(&keep_add_vars, &j, %str( )) 
      %then %let cnt = %eval(&cnt + 1);
  %end;
  %if %sysevalf(&cnt > 1) %then %do;
    %put ERROR: Variable "&i_var" is included multiple times in;
    %put ERROR: keep_add_vars = &keep_add_vars;
    %goto end_of_macro;
  %end;
%end;

/* keep_add_vars check: if more than one variable is specified, make sure 
that _null_ and/or _all_ are not among the specified variables. */
%if %sysevalf(%sysfunc(countw(&keep_add_vars, %str( ))) > 1) %then %do;
  %if (_all_ in %lowcase(&keep_add_vars)) or 
      (_null_ in %lowcase(&keep_add_vars)) %then %do;
    %put ERROR: A list of variables have been specified in "keep_add_vars";
    %put ERROR: but the list contains one/both of the;
    %put ERROR: values _null_ and _all_!;
    %goto end_of_macro;
  %end;
%end;

/* keep_add_vars check: if keep_add_vars = _all_ then replace value with 
list of all variables in input dataset. */
%if &keep_add_vars = _all_ %then %do;
  data  __hm_empty;
    set &in_ds(obs = 0);
  run;

  proc sql noprint;
    select distinct name into :keep_add_vars separated by " "
      from sashelp.vcolumn
      where libname = "WORK" and memname = "__HM_EMPTY";
  quit;
%end;

/* keep_add_vars check: remove variables that are automatically
included in the output data. */
%local tmp i i_var;
%let tmp = &keep_add_vars;
%let keep_add_vars = ;
%do i = 1 %to %sysfunc(countw(&tmp, %str( )));
  %let i_var = %scan(&tmp, &i, %str( ));
  %if (&i_var in &match_exact &by &match_inexact_vars) = 0 
    %then %let keep_add_vars = &keep_add_vars &i_var;
%end;

/* If the removal of redundant variables results in the 
macro variable being empty, set it to _null_ */
%if &keep_add_vars = %then %let keep_add_vars = _null_;

%if &verbose = y %then %do;
  %put hash_match: - Modified value of "keep_add_vars" after removing;
  %put hash_match:   variables that are already automatically included:;
  %put hash_match:   &keep_add_vars;
%end;



/******************************************************************************
LOAD INPUT DATA
******************************************************************************/

%if &verbose = y %then %do;
  %put hash_match: *** Load input data ***;
  %put hash_match: - Create macro variable with all variables given in;
  %put hash_match:   "match_exact" and "by" that is used to define;
  %put hash_match:   stratas/exact matching conditions in which we;
  %put hash_match:   do the matching;
%end;

/* The stratas/exact matching conditions in which we will do matching is 
defined by the variables given in match_exact and by. */
%local match_stratas;
%let match_stratas = ;
%if &by ne _null_ %then %let match_stratas = &match_stratas &by;
%if &match_exact ne _null_ %then %let match_stratas = &match_stratas &match_exact;

/* If no exact matching or by variables are given, we will create a dummy 
strata variable to facilitate the analyses. */
%if &verbose = y and &match_stratas = %then %do;
  %put hash_match: - No exact matching variables or by variables specified.;
  %put hash_match:   Dummy matching variable __dummy_strata will be added;
  %put hash_match:   to the input data to facilitate analyses.;
%end;
%if &match_stratas = %then %let match_stratas = __dummy_strata;
%if &verbose = y %then %do;
  %put hash_match: - match_stratas = &match_stratas; 
%end;

/* Find &match_date variable format. */
%local match_date_fmt;
proc sql noprint;
  select format
    into :match_date_fmt
    from sashelp.vcolumn
    where libname = "WORK" and memname = "%upcase(&in_ds)"
      and name = "&match_date";
quit;
%if &match_date_fmt = %then %let match_date_fmt = best32.;

/* Load and restrict input data. */
%if &verbose = y %then %do;
  %put hash_match: - Loading input data;
%end;
data __hm_data1;
  format __merge_id best12. __match_date &match_date_fmt;
  set &in_ds;
  where &where;
  %if &match_stratas = __dummy_strata %then %do;
    __dummy_strata = "_null_";
    keep __dummy_strata;
  %end;
  __merge_id = _n_;
  __match_date = &match_date;
  keep __merge_id __match_date &match_stratas;
  %if &match_inexact_vars ne %then %do; keep &match_inexact_vars; %end;
  %if &keep_add_vars ne _null_ %then %do; keep &keep_add_vars; %end;
run;

/* If the specified where-condition results in any warnings or errors,
the macro is terminated. */
%if &syserr ne 0 %then %do;
  %put ERROR- The specified "where" condition:;
  %put ERROR- "&where";
  %put ERROR- produced a warning or an error. Macro terminated!;
  %goto end_of_macro; 
%end;
%if &verbose = y %then %do;
  %put hash_match: - Input data succesfully loaded;
%end;


/******************************************************************************
PREPARE DATA
******************************************************************************/

%if &verbose = y %then %do;
  %put hash_match: *** Prepare data for matching ***;
  %put hash_match: - Create composite strata variable based on unique;
  %put hash_match:   combinations of values of the variables:;
  %put hash_match:   &match_stratas;
%end;

/* Find unique strata values and make a new composite strata variable. */
proc sort data = __hm_data1(keep = &match_stratas) out = __hm_stratas1 
    nodupkeys; 
  by &match_stratas;
run;

data __hm_stratas2;
  set __hm_stratas1;
  __strata = _n_;
run;

%local n_strata;
proc sql noprint;
  select count(*) into :n_strata
    from __hm_stratas2;
quit;

/* Add composite strata variable to data. */
%local i i_strata;
proc sql;
  create table __hm_data2 as
    select a.*, b.__strata
      from __hm_data1 as a
      left join 
      __hm_stratas2 as b
  on
  %do i = 1 %to %sysfunc(countw(&match_stratas, %str( )));
    %let i_strata = %scan(&match_stratas, &i, %str( ));
    %if &i = 1 %then %do;
      a.&i_strata = b.&i_strata
    %end;
    %else %do;
      and a.&i_strata = b.&i_strata
    %end;
  %end; 
  ;
quit;

%if &verbose = y %then %do;
  %put hash_match: - Create an index for fast subsetting of data;
  %put hash_match:   during matching.;
%end;

/* Create index. */
proc sort data = __hm_data2(keep = __merge_id __match_date __strata &match_inexact_vars) 
    out = __hm_data3(index = (__strata));
	by __strata;
run;


/******************************************************************************
MATCHING
******************************************************************************/

%if &verbose = y %then %do;
  %put hash_match: *** Matching ***;
%end;

/* Find 10 approximately evenly spaced out strata values, and calculate the 
percentage of progress that have been made at that point in the matching 
process. */
data __hm_progress;
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
    from __hm_progress;
quit;

/* Disable notes in log irrespective of the value of the
print_notes parameter. */
options nonotes;

/* Find the length and type of variables. */
%local i i_var;
%do i = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
  %let i_var = %scan(&match_inexact_vars, &i, %str( ));
  %local &i_var._type &i_var._length &i_var._format;
  proc sql noprint;
    select type, length, format
      into :&i_var._type, :&i_var._length, :&i_var._format
      from sashelp.vcolumn
      where libname = "WORK" and memname = "__HM_DATA3"
        and name = "&i_var";
  quit;
  %let &i_var._type = %sysfunc(compress(&&&i_var._type));
  %let &i_var._length = %sysfunc(compress(&&&i_var._length));
  %if &&&i_var._type = char %then %let &i_var._length = $&&&i_var._length; 

  %if &&&i_var._format = %then %do;
    %if &&&i_var._type = char %then %let &i_var._format = &&&i_var._length..;
    %else %if &&&i_var._type = num %then %let &i_var._format = best32.;
  %end;
%end;

/* Find matches in each strata. */
%local i;
%do i = 1 %to &n_strata;
  
  %if &i = 1 %then %do;
    %put Matching progress:;
    %put %sysfunc(datetime(), datetime32.): %str(  0%%);
  %end;

  %local time_start;
  %let time_start = %sysfunc(datetime());

  /* Restrict data to strata. */
  data __hm_strata_data;
    set __hm_data3(where = (__strata = &i));
  run;

  /* Find cases in strata. */
  data __hm_strata_cases;
    set __hm_strata_data(where = (__match_date ne .));
  run;

  /* Make a dataset with potential controls. */
  %local j j_var;
  data __hm_strata_controls; 
    set __hm_strata_data;
    __hash_key = _n_;
    rename 
      __strata = _ctrl___strata
      __merge_id = _ctrl___merge_id
      ;
    %do j = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
      %let j_var = %scan(&match_inexact_vars, &j, %str( ));
      rename &j_var = _ctrl_&j_var;
    %end;
  run;

  /* Find number of cases and controls in strata. */
  proc sql noprint;
    select count(*) 
      into :n_strata_cases
      from __hm_strata_cases;
    select count(*) 
      into :n_strata_controls
      from __hm_strata_controls;
  quit;

  /* If there are both cases and potential controls in the strata, 
  find controls for each case. */
  %if &n_strata_controls > 0 and &n_strata_cases > 0 %then %do;

    /* Calculate the number of tries to find controls for
    each case. See limit_tries documentation. */
    %local max_tries;
    data _null_;
   	  k = &n_strata_controls;
      p = 0.99;
      max_tries = min(
        &n_controls * round(k*(log(k) - log(-log(p)))), 
        &limit_tries
      );
      call symput("max_tries", put(max_tries, best12.));
    run;

    %local j j_var;
    data __hm_strata_matches(drop = __hash_key __stop __controls __tries __rand_obs __rc __highest_tries)
         __hm_strata_incomp_info(keep = __merge_id __match_date __strata __controls &match_inexact_vars);
    	call streaminit(&seed);
    	length	__hash_key _ctrl___merge_id 8 
        %do j = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
          %let j_var = %scan(&match_inexact_vars, &j, %str( ));
          _ctrl_&j_var &&&j_var._length
        %end;
        ;
    	format	__hash_key _ctrl___merge_id best12. 
        %do j = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
          %let j_var = %scan(&match_inexact_vars, &j, %str( ));
          _ctrl_&j_var &&&j_var._format
        %end;
        ;
    	/* Load potential controls into hash object. */	
    	if _n_ = 1 then do;
    		declare hash h(dataset: "__hm_strata_controls");
    		declare hiter iter("h");
    		h.defineKey("__hash_key");
    		h.defineData(
    			"__hash_key", "_ctrl___merge_id"
          %do j = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
            %let j_var = %scan(&match_inexact_vars, &j, %str( ));
            , "_ctrl_&j_var"
          %end;
    		);
    		h.defineDone();
    		call missing(
          __hash_key, _ctrl___merge_id
          %do j = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
            %let j_var = %scan(&match_inexact_vars, &j, %str( ));
            , _ctrl_&j_var
          %end;
        );

        /* Initialize the match id variable */
        retain __match_id 0;

        /* Make variable to keep track of the actual highest number of 
        tries needed to find all matches for a case. */
        retain __highest_tries .;
    	end;

    	/* Open case dataset */
    	set __hm_strata_cases;

      /* initialize utility variables */
    	__stop = 0;
    	__controls = 0;
    	__tries = 0;
      __match_id + 1;

    	do while (__stop = 0);
    		__tries + 1;
    		/* Pick a random potential control. This is ineffective when 
        we match without replacement, since more and more keys wont exist. 
        But since we can't pick a random item from a hash-table directly, it 
        is not possible to do this is in a more efficient way? */
          __rand_obs = max(1, round(rand("uniform") * &n_strata_controls));
      		__rc = h.find(key:__rand_obs);
    		/* Check if key exists and if valid control. */
        if __rc = 0 
          %if %bquote(&match_inexact) ne %then %do;
            and &match_inexact
          %end;
    		then do;
    			__controls + 1; 	
          /* If matching without replacemnt, remove matched control
          from hash-table. */
          %if &replace = n %then %do;
            __rc = h.remove(key: __rand_obs);
          %end;
          /* Output matched control. */
          output __hm_strata_matches;
    		end;
    		/* When we have found n_control valid controls or we reach the
        maximum number of tries we stop the loop. */ 
    		if __controls >= &n_controls or __tries >= &max_tries then __stop = 1;
   
        /* If we have not found the wanted number of controls for a case
        we output info on the case to a dataset. */
        if __stop = 1 then do;
          if __controls < &n_controls then output __hm_strata_incomp_info;
          /* Update maximum number of tries needed to find all controls */
          __highest_tries = max(__tries, __highest_tries);
          call symput("highest_tries", put(__highest_tries, best12.));
        end;
      end;
    run;

    /* If the matching results in any warnings or errors,
    the macro is terminated. */
    %if &syserr ne 0 %then %do;
      %put ERROR- Matching resulted in a warning or error!;
      %put ERROR- Check if specified "match_inexact" condition:;
      %put ERROR- match_inexact = &match_inexact;
      %put ERROR- is valid.;
      %goto end_of_macro; 
    %end;
  %end;
  /* If no cases or no potential controls create an empty dataset. */
  %else %do;
    data __hm_strata_matches;
      length
        %do j = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
          %let j_var = %scan(&match_inexact_vars, &j, %str( ));
          _ctrl_&j_var &&&j_var._length
        %end;
      ;
      format _ctrl___merge_id __match_id best12.
        %do j = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
          %let j_var = %scan(&match_inexact_vars, &j, %str( ));
          _ctrl_&j_var &&&j_var._format
        %end;
      ;
      set __hm_strata_cases(obs = 0);
    run;

    data __hm_strata_incomp_info;
      length
        %do j = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
          %let j_var = %scan(&match_inexact_vars, &j, %str( ));
          &j_var &&&j_var._length
        %end;
        ;
    	format __controls best12.
        %do j = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
          %let j_var = %scan(&match_inexact_vars, &j, %str( ));
          &j_var &&&j_var._format
        %end;
        ;
        set __hm_strata_cases(obs = 0);
    run;
  %end;

  /* In some weird cases, using proc append to automatically create the
  base dataset if it does not exist will fail. Therefore we will explictly
  define it here, to make sure everything works as intended. */
  %if &i = 1 %then %do;
    data __hm_all_matches1;
      set __hm_strata_matches;
    run;
    
    data __hm_all_incomp_info1;
      set __hm_strata_incomp_info;
    run;
  %end;
  %else %do;
    /* Append matches from strata to dataset with all matches. */
    proc append base = __hm_all_matches1 data = __hm_strata_matches;
    run;

    /* Append cases for which not all matches could be found. */
    proc append base = __hm_all_incomp_info1 data = __hm_strata_incomp_info;
    run;
  %end;

  %local time_stop duration;
  %let time_stop = %sysfunc(datetime());
  %let duration = %sysevalf(&time_stop - &time_start);

  /* Estimate time until all matching is done, based on the median
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

  /* Make dataset with strata information. */
  %local highest_tries;
  %if &n_strata_cases  = 0 or &n_strata_controls = 0 %then %do;
    %let highest_tries = .;
    %let max_tries = .;
  %end;
  data __hm_strata_info;
    format __strata __n_cases __n_potential_controls best12. 
           __start __stop __run_time $20.;
    __strata = &i;
    __n_cases = &n_strata_cases;
    __n_potential_controls = &n_strata_controls;
    __start = compress(put(&time_start, datetime32.));
    __stop = compress(put(&time_stop, datetime32.));
    __run_time = compress(put(&duration, time13.));
    __max_tries = &max_tries;
    __highest_tries = &highest_tries;
    output;
  run;

  /* Append strata diagnostics. */
  %if &i = 1 %then %do;
    data __hm_all_info1;
      set __hm_strata_info;
    run;
  %end;
  %else %do;
    proc append base = __hm_all_info1 data = __hm_strata_info;
    run;
  %end;
 
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

/* If there are no cases at all in the data, a warning is printed in the log
and the macro will not try to produce output datasets since its meaningless. */
%local n_cases_total;
proc sql noprint;
  select sum(__n_cases) 
    into :n_cases_total
    from __hm_all_info1;
quit;

%if &n_cases_total = 0 %then %do;
  %put WARNING: No cases in input dataset. Output datasets not created!;
  %goto end_of_macro;  
%end;


/******************************************************************************
MAKE OUTPUT WITH MATCHED DATA
******************************************************************************/

%if &verbose = y %then %do;
  %put hash_match  *** Create output datasets ***;
  %put hash_match: - Matched data;
%end;

proc sort data = __hm_all_matches1;
  by __strata __match_id;
run;

/* Cases */
%local i i_var;
data __hm_all_matches2_cases;
	set __hm_all_matches1(
    rename = (__match_id = tmp) 
    drop = 
      _ctrl___merge_id
      %do i = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
        %let i_var = %scan(&match_inexact_vars, &i, %str( ));
        _ctrl_&i_var
      %end;
  );
	length __match_id 8;
	format __match_id 20.;
	by __strata tmp;
	retain __match_id;
	if _n_ = 1 then __match_id = 0;
	if first.tmp then do;
		__match_id + 1;
		output;
	end;
  drop tmp;
run;

/* Controls */
%local i i_var;
data __hm_all_matches2_controls(
    rename = (
      _ctrl___merge_id = __merge_id 
      %do i = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
        %let i_var = %scan(&match_inexact_vars, &i, %str( ));
        _ctrl_&i_var = &i_var
      %end;
      )
  );
	set __hm_all_matches1(
    rename = (__match_id = tmp)
    drop = 
      __merge_id
      %do i = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
        %let i_var = %scan(&match_inexact_vars, &i, %str( ));
        &i_var
      %end;
  );
	length __match_id 8;
	format __match_id 20.;
	by __strata tmp;
	retain __match_id;
	if _n_ = 1 then __match_id = 0;
	if first.tmp then do;
		__match_id = __match_id + 1;
	end;	
  drop tmp;
run;

data __hm_all_matches3; 
	set __hm_all_matches2_cases(in = q1) 
      __hm_all_matches2_controls;
  length __case 3;
  format __match_id 20. __case 1.;
  if q1 then __case = 1;
  else __case = 0;
run;

proc sort data = __hm_all_matches3;
  by __match_id descending __case;
run;

data __hm_all_matches4;
  set __hm_all_matches3(rename = (__match_date = tmp));
  by __match_id;
  format __match_date &match_date_fmt;
  retain __match_date;
  if first.__match_id then __match_date = tmp;
  drop tmp;
run;



/* merge __strata and keep_add_vars variables back to matched 
data */
%local i i_var;
proc sql;
  create table &out_pf._matches as
    select 
    %if &match_stratas ne __dummy_strata %then %do;
      %do i = 1 %to %sysfunc(countw(&match_stratas, %str( )));
        %let i_var = %scan(&match_stratas, &i, %str( ));
        b.&i_var,
      %end;
    %end;
      a.__match_id label = "Match ID", 
      a.__match_date label = "Matching date", 
      a.__case "Case (1 = yes)"
    %if &match_inexact_vars ne %then %do;
      %do i = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
        %let i_var = %scan(&match_inexact_vars, &i, %str( ));
        , a.&i_var
      %end; 
    %end;
 
    %if &keep_add_vars ne _null_ %then %do;
      %do i = 1 %to %sysfunc(countw(&keep_add_vars, %str( )));
        %let i_var = %scan(&keep_add_vars, &i, %str( ));
          , b.&i_var
      %end;
    %end;
      from __hm_all_matches4 as a
      left join
      __hm_data2(rename = (__merge_id = __tmp)) as b
      on a.__merge_id = b.__tmp
      order by __match_id, __case descending;
quit;


/******************************************************************************
MAKE OUTPUT WITH INFO ON CASES WITH INCOMPLETE MATCHES
******************************************************************************/

%if &verbose = y %then %do;
  %put hash_match: - Info on cases with incomplete matches;
%end;

/* merge __strata and keep_add_vars variables back to matched 
data */
%local i i_var;
proc sql;
  create table &out_pf._incomp_info as
    select  
    %if &match_stratas ne __dummy_strata %then %do;
      %do i = 1 %to %sysfunc(countw(&match_stratas, %str( )));
        %let i_var = %scan(&match_stratas, &i, %str( ));
        b.&i_var,
      %end;
    %end;
      a.__match_date label = "Matching date",
      a.__controls label = "Number of matched controls"
    %if &match_inexact_vars ne %then %do;
      %do i = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
        %let i_var = %scan(&match_inexact_vars, &i, %str( ));
        , a.&i_var
      %end; 
    %end;
    %if &keep_add_vars ne _null_ %then %do;
      %do i = 1 %to %sysfunc(countw(&keep_add_vars, %str( )));
        %let i_var = %scan(&keep_add_vars, &i, %str( ));
          , b.&i_var
      %end;
    %end;
      from __hm_all_incomp_info1 as a
      left join
      __hm_data2(rename = (__merge_id = __tmp)) as b
      on a.__merge_id = b.__tmp
      order by b.__strata, a.__merge_id;
quit;


/******************************************************************************
MAKE OUTPUT WITH INFO
******************************************************************************/

%if &verbose = y %then %do;
  %put hash_match: - Matching info;
%end;

/* Count the number of times each person has been used as control in each 
matched set in each strata, and then summarize distribution by percentiles. */
proc means data = __hm_all_matches2_controls nway noprint;
  class __strata __match_id __merge_id;
  output out = __hm_info_cnt_match1(drop = _freq_ _type_) 
    n(__strata) = __cnt_id / noinherit;
run;

proc means data = __hm_info_cnt_match1 nway noprint;
  class __strata;
  output out = __hm_info_cnt_match2(drop = _freq_ _type_)
    p50(__cnt_id) = __p50_n_id_match
    p99(__cnt_id) = __p99_n_id_match
    max(__cnt_id) = __max_n_id_match
      / noinherit;
run;

/* Count times id used as control in each strata. Summarize distribution
by percentiles. */
proc means data = __hm_info_cnt_match1 nway noprint;
  class __strata __merge_id;
  output out = __hm_info_cnt_strata1(drop = _freq_ _type_) 
    sum(__cnt_id) = __cnt_id / noinherit;
quit;

proc means data = __hm_info_cnt_strata1 nway noprint;
  class __strata;
  output out = __hm_info_cnt_strata2(drop = _freq_ _type_)
    p50(__cnt_id) = __p50_n_id_strata
    p99(__cnt_id) = __p99_n_id_strata
    max(__cnt_id) = __max_n_id_strata
      / noinherit;
run;

/* find info on how many incomplete matches were made */
data __hm_info_incomp1;
  set __hm_all_incomp_info1;
  __some_matches  = (__controls > 0);
  __no_matches = (__controls = 0);
  keep __strata __some_matches __no_matches;
run;

proc means data = __hm_info_incomp1 noprint nway;
  class __strata;
  output out = __hm_info_incomp2(drop = _type_ _freq_)
    sum(__some_matches __no_matches) = __n_some_matches __n_no_matches
    / noinherit;   
run;

%local i i_var;
data &out_pf._match_info;
  /* Use retain statement to order variables */
  retain 
    %do i = 1 %to %sysfunc(countw(&match_stratas, %str( )));
      %let i_var = %scan(&match_stratas, &i, %str( ));
      &i_var
    %end;
    __n_cases __n_full_matches __n_some_matches __n_no_matches
    __n_potential_controls __highest_tries __max_tries
    __start __stop __run_time
  ;
  merge 
    __hm_stratas2 
    __hm_all_info1 
    __hm_info_incomp2
    __hm_info_cnt_match2
    __hm_info_cnt_strata2;
  by __strata;

  /* Set values to zero for empty stratas. */
  if __n_some_matches = . then __n_some_matches = 0;
  if __n_no_matches = . then __n_no_matches = 0;
  __n_full_matches = __n_cases - __n_some_matches - __n_no_matches;

  label 
    __n_cases = "Number of cases"
    __n_potential_controls = "Number of potential controls"
    __run_time = "Run-time (tt:mm:ss)"
    __max_tries = "Maximum attempts that will be attempted to find all matches for a case"
    __highest_tries = "Actual largest needed attempts needed to find all matches for a case"
    __n_some_matches = "Number of cases where only a some, not all, controls could be found"
    __n_no_matches = "Number of cases for which no controls could be found"
    __n_full_matches = "Number of cases for which all controls could be found"
  ;
  drop __strata;
  %if &match_stratas = __dummy_strata %then %do; drop __dummy_strata; %end; 
run;



%end_of_macro:


/* Delete temporary datasets created by the macro. */
%if &del ne n  %then %do;
  proc datasets nodetails nolist;
    delete __hm_:;
  run;
  quit;
%end; 

/* Restore value of notes option */
options &opt_notes;

%put hash_match: end execution;

%mend hash_match;
