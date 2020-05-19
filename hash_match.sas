/*
TODO:
1) implement inexact matching
2) patch all problems arising from changes
3) Make new examples showing how to make the matching conds that
was made automatically earlier.
4) Clean up tests. 
5) Add tests that use regular expression to check that "where" and 
"match_inexact" is using a %str() wrapper? Maybe don't since it might not
be strictly necesary and/or other masking functions might be more
appropriate?
6) Add warning/error check in the matching phase, that termiantes like 
the "where" check.
7) Improve verbose messages, ie comming before something is about to be done
8) Revise keep_add_vars. Should default to including all generated variables
and all variables specified in the other parameters?
9) Include example showing that doing exact matching in the match_inexact 
paramter leads to worse efficiency, at least with large datasets.
10) dataset with partial matches, might not have id variable. Think about
if this is realistic in practice. Wouldnt you always make a id ne __id cond? And
if you didnt for some reason you wouldnt need the id anyway?
11) __vars that are made make name collisions possible again. Need to make list
of protected var names like obs, n etc. and chekc during inoput? 
12) bliver nødt til at lave en __match_date fra start der er &match_date, så
ting virker uanset om &match_date bruges i match_inexact eller ej.

13) Ville de give mening at tilføje en warning hvis der er __hm_ prefix 
datasæt i work directory? Med toggle til at slå fra?
14) __match_date behøver ikke inkluderes i hash_table?
*/

/*******************************************************************************
AUTHOR:     Thomas Boejer Rasmussen
VERSION:    0.3.0
LICENCE:    Creative Commons CC0 1.0 Universal  
            (https://www.tldrlegal.com/l/cc0-1.0)
********************************************************************************
DESCRIPTION:
Matching using a hash-table merge approach. The input dataset is expected to be 
a source population with the date, if any, each person becomes a case and is
to be matched with a set of controls from the source population that fulfills
a set of specified matching criterias.

Controls are selected by randomly picking potential controls among patients 
with the same value of exact matching and by variables specified in 
<match_exact> and <by>, and then further evaluating if the inexact matching 
conditions given in <match_inexact> are fulfilled. 

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros
********************************************************************************
PARAMETERS:
*** REQUIRED ***
in_ds:            (libname.)member-name of input dataset with source population.         
out_pf:           (libname.)member-name prefix of output datasets. The following
                  datasets are created by the macro:
                  <out_pdf>_matches: Matched population.
                  <out_pdf>_no_matches: Information on cases for which 
                  no (or only partial) matches could be found.
                  <out_pdf>_info: Miscellaneous information and 
                  diagnostics that can be helpful to evaluate the 
                  appropriateness of the matched population.
match_date:       Date, if any, the person/case is to be matched with
                  a set of controls. Must be a numeric variable.
*** OPTIONAL ***
match_exact:      Space-separated list of (exact) matching variables. Default 
                  is match_exact = _null_, ie no matching variables are used. 
match_inexact:    Inexact matching conditions. Use the %str function to 
                  specify conditions, eg. 
                  match_inexact = %str(
                    abs(<var1> - _ctrl_<var1>) <= 5 and <var2> ne _ctrl_<var2>
                  )
                  Here <var1> and <var2> are variables from the input dataset, 
                  and _ctrl_<var1> and _ctrl_<var2> are variables created the by the 
                  macro. The <var> variables corresponds to case values, and 
                  _ctrl_<var> corresponds to (potential) control values.
                  Default is match_inexact = %str(), eg no (inexact) matching 
                  conditions are specified.
n_controls:       Number of controls to match to each case. 
                  Default is n_controls = 10.
replace:          Match with replacement:
                  - Yes: replace = y (default)
                  - No:  replace = n  
                  Note: Matching without replacement is less efficient (but
                  still fast) when the control to case ratio is small. The
                  reason for this is very technical and has to do with how 
                  controls are selected at random from the hash-table during
                  matching. See code for more information.
where:            Condition used to to restrict the input dataset in a where-
                  statement. Use the %str function as a wrapper, , eg 
                  where = %str(var = "value").
by:               Space-separated list of by variables. Default is by = _null_,
                  ie no by variables. 
limit_tries:      The maximum number of tries to find all matches for each
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
                  can set a upper limit. Default is limit_tries = 10**6. 
                  n_99pct formula is from 
                  https://math.stackexchange.com/questions/1155615/
                  probability-of-picking-each-of-m-elements-at-least-once-after-
                  n-trials.
keep_add_vars:    Space-separated list of additional variables from the input 
                  to include in the <out_pf>_matches output dataset. Variables 
                  specified in other macro parameters are automatically kept 
                  and does not need to be specified. All variables from
                  the input dataset can be kept using keep_add_vars = _all_.
                  Default is keep_add_vars = _null_, ie keep no additional 
                  variables.
seed:             Seed used for random number generation. Default is seed = 0,
                  ie a random non-reproducible seed is used.
print_notes:      Print notes in log?
                  - Yes: print_notes = y
                  - No:  print_notes = n (default)
verbose:          Print info on what is happening during macro execution
                  to the log:
                  - Yes: verbose = y
                  - No:  verbose = n (default)
del:              Delete intermediate datasets created by the macro:
                  - Yes: del = y (default)
                  - no:  del = n              
******************************************************************************/
%macro hash_match(
  in_ds           = ,
  out_pf          = ,
  match_date      = ,
  match_exact     = _null_,
  match_inexact   = %str(),
  n_controls      = 10,
  replace         = y,
  keep_add_vars   = _null_,
  where           = %str(),
  by              = _null_,
  limit_tries       = 10**6,
  seed            = 0,
  print_notes     = n,
  verbose         = n,
  del             = y
) / minoperator mindelimiter = ' ';

%put hash_match: start execution;

%put %bquote(&match_inexact);

/* find value of notes option, save it, then disable notes */
%local opt_notes;
%let opt_notes = %sysfunc(getoption(notes));
options nonotes;

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
and that none of the specified variables have a "__" or "_ctrl_ prefix. */
%local vars i i_var j j_var ds_id rc;
%let vars = match_date match_exact by keep_add_vars;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
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
  %put hash_match:   match_inexact_vars = &match_inexact_vars;
%end;

/* Outcome dataset prefix needs to be a valid (libname.)member-name, 
where the member-name part can have a length of 23 at the most, to make sure 
that the output dataset names are not too long.

Regular expression: (lib-name.)member-name, where the libname is
optional. The libname must start with a letter, followed by 0-7 letters, 
numbers or underscores and must end with a ".". Member-name part must start
with a letter or underscore, and is followed by 0-22 letters ,numbers or 
underscores. The whole regular expression is case-insentitive. */
%if %sysfunc(prxmatch('^([a-z][\w\d]{0,7}\.)*[\w][\w\d]{0,22}$', &out_pf)) = 0 
  %then %do;
  %put ERROR: Specified "out_pf" output prefix "&out_pf" is either invalid;
  %put ERROR: or the member-name part has length greater than 23;
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

/* Check n_control is a positive integer.
Regular expression: starts with a number 1-9, followed by, and ends with,
one or more digits (so that 0 is not allowed, but eg 10 is). */
%if %sysfunc(prxmatch('^[1-9]\d*$', &n_controls)) = 0 %then %do;
  %put ERROR: "n_controls" must be a positive integer!;
  %goto end_of_macro; 
%end;

/* Check limit_tries is a positive integer. limit_tries is likely to be a large 
number which is easier to write on the form "10 ** x", so we evaluate the 
expression given in limit_tries before checking that it is an integer.
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
  %put hash_match: - Input value of "keep_add_vars": &keep_add_vars;
%end;

/* keep_add_vars check: if more than one variable is specified, make sure 
that _null_ and/or _all_ are not among the specifed variables. */
%if %sysevalf(%sysfunc(countw(&keep_add_vars, %str( ))) > 1) %then %do;
  %if (_all_ in %lowcase(&keep_add_vars)) or 
      (_null_ in %lowcase(&keep_add_vars)) %then %do;
    %put ERROR: A list of variables have been specified in "keep_add_vars";
    %put ERROR: but the list contains one/both of the protected;
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
  %if (&i_var in &match_date &match_exact &by &match_inexact_vars) = 0 
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
  %put hash_match: - Creating macro variable "match_stratas" including all;
  %put hash_match:   variables given in "match_exact" and "by" that is used;
  %put hash_match:   to define stratas/exact matching conditions in which we;
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
  %put hash_match:   to the input data and "match_stratas" to facilitate analyses.;
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
%put &match_date_fmt;
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


/******************************************************************************
PREPARE DATA
******************************************************************************/

%if &verbose = y %then %do;
  %put hash_match: *** Prepare data for matching ***;
  %put hash_match: - Creating a composite strata variable based on unique;
  %put hash_match:   combinations of values of the variables in ;
  %put hash_match:   match_stratas = &match_stratas;
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

/* Add composite strata variable to data.*/
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
  %put hash_match: - Creating an index on __strata for fast subsetting of data;
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

/*TODO add something verbose here on progress vars?*/

/* Disable notes in log irrespective of the value of the
print_notes parameter. */
options nonotes;

/* Make sure there are no intermediate dataset from from a previous 
run of the macro in the work directory before we do the matching. */
proc datasets nolist nodetails;
  delete __hm_data_strata __hm_cases __hm_potential_controls
         __hm_matches __hm_no_matches
         __hm_all_matches1 __hm_all_no_matches1
         __hm_info __hm_all_info1;
run;
quit;

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
  data __hm_data_strata;
    set __hm_data3(where = (__strata = &i));
  run;

  /* Find cases in strata. */
  data __hm_cases;
    set __hm_data_strata(where = (__match_date ne .));
  run;

  /* Make a dataset with potential controls. */
  %local j j_var;
  data __hm_potential_controls; 
    set __hm_data_strata;
    __hash_key = _n_;
    rename 
      __match_date = _ctrl___match_date 
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
      from __hm_cases;
    select count(*) 
      into :n_strata_controls
      from __hm_potential_controls;
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
    data __hm_matches(drop = __hash_key __stop __controls __tries __rand_obs __rc __highest_tries)
         __hm_no_matches(keep = __merge_id __match_date __strata &match_inexact_vars);
    	call streaminit(&seed);
    	length	__hash_key _ctrl___merge_id _ctrl___match_date 8 
        %do j = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
          %let j_var = %scan(&match_inexact_vars, &j, %str( ));
          _ctrl_&j_var &&&j_var._length
        %end;
        ;
    	format	__hash_key _ctrl___merge_id best12. _ctrl___match_date &match_date_fmt 
        %do j = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
          %let j_var = %scan(&match_inexact_vars, &j, %str( ));
          _ctrl_&j_var &&&j_var._format
        %end;
        ;
    	/* Load potential controls into hash object. */	
    	if _n_ = 1 then do;
    		declare hash h(dataset: "__hm_potential_controls");
    		declare hiter iter("h");
    		h.defineKey("__hash_key");
    		h.defineData(
    			"__hash_key", "_ctrl___merge_id", "_ctrl___match_date"
          %do j = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
            %let j_var = %scan(&match_inexact_vars, &j, %str( ));
            , "_ctrl_&j_var"
          %end;
    		);
    		h.defineDone();
    		call missing(
          __hash_key, _ctrl___merge_id, _ctrl___match_date
          %do j = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
            %let j_var = %scan(&match_inexact_vars, &j, %str( ));
            , _ctrl_&j_var
          %end;
        );

        /* Initalize a match id variable */
        retain __match_id 0;

        /* Make variable to keep track of the actual highest number of 
        tries needed to find all matches for a case. */
        retain __highest_tries .;
    	end;

    	/* Open case dataset */
    	set __hm_cases;

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
          output __hm_matches;
    		end;
    		/* When we have found n_control valid controls or we reach the
        maximum number of tries we stop the loop. */ 
    		if __controls >= &n_controls or __tries > &max_tries then __stop = 1;
   
        /* If we have not found the wanted number of controls for a case
        we output info on the case to a dataset. */
        if __stop = 1 then do;
          if __controls < &n_controls then output __hm_no_matches;
          /* Update maximum number of tries needed to find all controls */
          __highest_tries = max(__tries, __highest_tries);
          call symput("highest_tries", put(__highest_tries, best12.));
        end;
      end;
    run;
  %end;
  /* If no cases or no potential controls create an empty dataset. */
  %else %do;
    data __hm_matches;
      format __match_id best12.;
      set __hm_cases(obs = 0);
    run;

    data __hm_no_matches;
      set __hm_cases(obs = 0);
    run;
  %end;

  /* Append matches from strata to dataset with all matches. */
  proc append base = __hm_all_matches1 data = __hm_matches;
  run;

  /* Append cases for which not all matches could be found. */
  proc append base = __hm_all_no_matches1 data = __hm_no_matches;
  run;

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
  data __hm_info;
    format __strata __n_cases __n_potential_controls best12. 
           __start __stop datetime32. __time_sec 20.2;
    __strata = &i;
    __n_cases = &n_strata_cases;
    __n_potential_controls = &n_strata_controls;
    __start = &time_start;
    __stop = &time_stop;
    __time_sec = &duration;
    __max_tries = &max_tries;
    __highest_tries = &highest_tries;
    output;
  run;
      
  /* Append strata diagnostics. */
  proc append base = __hm_all_info1 data = __hm_info;
  run;
  
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
MAKE OUTPUT WITH MATCHED DATA
******************************************************************************/

%if &verbose = y %then %do;
  %put hash_match: *** Create output dataset with matched data ***;
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
      _ctrl___match_date
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
      %do i = 1 %to %sysfunc(countw(&match_inexact_vars, %str( )));
        %let i_var = %scan(&match_inexact_vars, &i, %str( ));
        _ctrl_&i_var = &i_var
      %end;
      )
  );
	set __hm_all_matches1(
    rename = (__match_id = tmp)
    drop = 
      __match_date
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



/* merge strata and keep_add_vars variables back to matched 
data */
proc sql;
  create table __hm_all_matches5 as
    select a.__match_id, a.__match_date, a.__case, a.__strata
      %if &keep_add_vars ne _null_ %then %do;
        %do i = 1 %to %sysfunc(countw(&keep_add_vars, %str( )));
          %let i_var = %scan(&keep_add_vars, &i, %str( ));
            ,b.&i_var
        %end;
      %end;
      from __hm_all_matches4 as a
      left join
      __hm_data2(rename = (__strata = __temp)) as b
      on a.__strata = b.__temp and a.__id = b.__id;
quit;



proc sql;
  create table &out_pf._matches(
      rename = (
        __index = &match_date __id = &id_var   
        __start = &fu_start
        __end = &fu_end
      ) drop = __strata) as
    select 
    %if &match_stratas ne __dummy_strata %then %do;
      %do i = 1 %to %sysfunc(countw(&match_stratas, %str( )));
        %let i_strata = %scan(&match_stratas, &i, %str( ));
        b.&i_strata,
      %end;
    %end;
    a.*
    from __hm_all_matches5 as a
    left join __hm_stratas2 as b
    on a.__strata = b.__strata
    order by __match_id, __case descending, a.__id;
quit;



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







/******************************************************************************
MAKE OUTPUT WITH INFO ON PERSON WITH NO/PARTIAL MATCHES
******************************************************************************/
%local i i_strata;

%if &verbose = y %then %do;
  %put hash_match: *** Make output dataset with info on ids with no/partial matches ***;
%end;

proc sql;
  create table __hm_all_not_full_matches_id2 as
    select a.*, b.__start, b.__end
      from __hm_all_not_full_matches_id1 as a
      left join
      __hm_data2(rename = (__strata = __temp)) as b
      on a.__strata = b.__temp and a.__id = b.__id;
quit;

proc sql;
  create table &out_pf._no_matches(
      rename = (
        __index = &match_date __id = &id_var   
        __start = &fu_start
        __end = &fu_end 
    )) as
    select
    %if &match_stratas ne __dummy_strata %then %do;
      %do i = 1 %to %sysfunc(countw(&match_stratas, %str( )));
        %let i_strata = %scan(&match_stratas, &i, %str( ));
        b.&i_strata,
      %end;
    %end;
    a.__id, a.__start, a.__end, a.__index, a.__n label = "Number of matched controls"
      from __hm_all_not_full_matches_id2 as a
      left join
      __hm_stratas2 as b
      on a.__strata = b.__strata
      order by a.__id;
quit;


/******************************************************************************
MAKE OUTPUT WITH INFO
******************************************************************************/

%if &verbose = y %then %do;
  %put hash_match: *** Make output dataset with info ***;
%end;

/* Count times id used as control in each matched set in each strata, and then
summarize distribution by percentiles. */
proc means data = __hm_all_matches2_controls nway noprint;
  class __strata __match_id __id;
  output out = __hm_n_id_match_1(drop = _freq_ _type_) 
    n(__strata) = n_id_match / noinherit;
run;

proc means data = __hm_n_id_match_1 nway noprint;
  class __strata;
  output out = __hm_n_id_match_2(drop = _freq_ _type_)
    min(n_id_match) =
    p25(n_id_match) = 
    p50(n_id_match) =
    p75(n_id_match) =
    max(n_id_match) = / noinherit autoname;
run;

/* Count times id used as control in each strata. Summarize distribution
by percentiles. */
proc means data = __hm_n_id_match_1 nway noprint;
  class __strata __id;
  output out = __hm_n_id_strata_1(drop = _freq_ _type_) 
    sum(n_id_match) = n_id_strata / noinherit;
quit;

proc means data = __hm_n_id_strata_1 nway noprint;
  class __strata;
  output out = __hm_n_id_strata_2(drop = _freq_ _type_)
    min(n_id_strata) =
    p25(n_id_strata) = 
    p50(n_id_strata) =
    p75(n_id_strata) =
    max(n_id_strata) = / noinherit autoname;
run;

/* find info on how many matches were made */
data __hm_n_no_matches1;
  set __hm_all_not_full_matches_id1;
  partial_match  = (__n > 0);
  no_match = (partial_match = 0);
run;

proc means data = __hm_n_no_matches1 noprint nway;
  class __strata;
  output out = __hm_n_no_matches2(drop = _type_ _freq_)
    sum(partial_match no_match) = n_partial_match n_no_match
    / noinherit autoname;   
run;

data __hm_info2;
  merge __hm_info1 __hm_n_no_matches2;
  by __strata;
  if n_partial_match = . then n_partial_match = 0;
  if n_no_match = . then n_no_match = 0;
  n_full_match = __n_cases - n_partial_match - n_no_match;
run;

data &out_pf._info;
  merge __hm_stratas2 
        __hm_info2 
        __hm_n_id_match_2 
        __hm_n_id_strata_2;
  drop __strata __start __end 
      %if &match_stratas = __dummy_strata %then %do; __dummy_strata %end; 
      ;
  label 
    __n_cases = "Number of cases"
    __n_potential_controls = "Number of potential controls"
    __time_sec = "Run-time in seconds"
    __max_attempts = "Maximum attempts that will be attempted to find all matches for a case"
    __max_cnt = "Actual largest needed attempts needed to find all matches for a case"
    n_partial_match = "Number of cases where only a partial amount of controls could be found"
    n_no_match = "Number of cases for which no controls could be found"
    n_full_match = "Number of cases for which all controls could be found"
  ;
run;


%end_of_macro:


/* Delete temporary datasets created by the macro, also when 
"del" has not be specified as either y or n. */
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
