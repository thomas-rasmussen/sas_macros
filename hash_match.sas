/*******************************************************************************
AUTHOR:     Thomas Boejer Rasmussen
VERSION:    0.4.1
********************************************************************************
DESCRIPTION:
Creates a matched population from a sourcepopulation with a variable giving
the date, if any, a person becomes a case and is to be matched with a set of
controls, also from the sourcepopulation.

DETAILS:
Matching is done using a hash-table merge, where the controls are stored in the
hash-table. For each case, potential controls are picked at random from the
hash-table until the desired amount of valid controls have been found, or a
maximum limit of tries is reached.

Matching is done in the order cases appears in the input dataset. If matching
is done without replacement, presort the input data appropriately.

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros
********************************************************************************
PARAMETERS:
*** REQUIRED ***
data:           (libname.)member-name of input dataset with sourcepopulation.
out:            (libname.)member-name of output dataset with the matched
                population. Note that the matched population also includes
                matched sets where only some of the desired number of controls
                for a case could be found. Besides variables in <data> used in
                the matching, <out> contains the following variables:
                __match_id: ID variable identifying corresponding cases and
                            controls
                __match_date: Matching date. The <match_date> value for the case.
                __case: Variable identifying whether an observation in the matched
                        set is a case or a control. __case = 1 is cases and
                __case = 0 is controls.
match_date:     Timepoint, eg a date, the person is to be matched with a set of
                controls. Must be a numeric variable. Set timepoint to missing
                for controls.
*** OPTIONAL ***
out_incomplete: (libname.)member-name of output dataset with cases with an
                incomplete set of matched controls. Default value is
                out_incomplete = _null_, ie no dataset is made.
                Beside relevant variables on the cases, the dataset also
                contains the following variables:
                __match_date: Date matching was performed.
                __controls:   Number of controls that could be found.
out_info:       (libname.)member-name of output dataset with miscellaneous
                information on the results of the matching procedure.
                Default value is out_info = _null_, ie no dataset is made.
                The dataset contains the following information,
                in strata given by variables in <match_exact>:
                __n_cases:              Number of cases in strata.
                __n_full_matches:       Number of cases for which a full set
                                        of controls could be found.
                __n_some_matches:       Number of cases for which some, but
                                        not all controls, could be found. Note
                                        that information on these cases can be
                                        found in <out_incomplete>.
                __n_no_matches:         Number of cases for which no controls
                                        could be found. Note that information on
                                        these cases can be found in <out_incomplete>.
                __n_potential_controls: Number of potential controls in the
                                        strata, ie persons with the same
                                        values of variables in <match_exact>.
                __highest_tries:        Highest amount of tries that was done
                                        to find all controls for a case.
                __max_tries:            Maximum amount of tries that will be
                                        done to find all controls for a case,
                                        before giving up. See <max_tries> for
                                        more information.
                __start:                Date-time when the matching procedure
                                        started.
                __stop:                 Date-time when the matching procedure
                                        finished.
                __run_time:             Runtime of matching procedure.
                The dataset also contains information on how often controls are
                reused in matched sets / the strata:
                __p50_n_id_match:       50th percentile of number of duplicate
                                        controls in a matched set.
                __p99_n_id_match:       99th pecentile of number of duplicate
                                        controls in a matched set.
                __max_n_id_match:       Maximum number of duplicate controls in
                                        a matched set.
                __p50_n_id_strata:      50th percentile of number of duplicate
                                        controls in a strata.
                __p99_n_id_strata:      99th pecentile of number of duplicate
                                        controls in a strata.
                __max_n_id_strata:      Maximum number of duplicate controls in
                                        a strata.
                If eg __max_n_id_match = 1 and __max_n_id_strata = 2, that means
                that in each matched set there are no duplicate controls, but
                across all matched sets in the strata, at least one person is used
                twice as a control for different cases.
                If matching without replacement, all these variables are one.
match_exact:    Space-separated list of (exact) matching variables. Default 
                is match_exact = _null_, ie no matching variables are used. 
match_inexact:  Inexact matching conditions. Use the %str function to 
                specify conditions, eg. 
                match_inexact = %str(
                  abs(<var1> - _<var1>) <= 5 and <var2> ne _<var2>
                )
                Here <var1> and <var2> are variables from <data>, 
                and _<var1> and _<var2> are variables created by the 
                macro. The original variable names are used to refer to variable
                values for cases, and the corresponding variables with an
                underscore prefix are used to refers to the variable values for
                controls.
                Default is match_inexact = %str(), eg no inexact matching 
                conditions are specified. See examples for how to use this
                parameter.
inexact_vars:   Variables from <data> used in <match_inexact>.
                By default (inexact_vars = _auto_) the macro will try to guess
                what variables are used in the <match_inexact> expression. The
                algorithm doing this is conservative and might identify too many
                variables, also added to <out>. Alternatively, a space-separated
                list of variables can be provided for manual control. 
n_controls:     Number of controls to match to each case. 
                Default is n_controls = 10.
replace:        Match with replacement:
                - Yes:    replace = y (default)
                - No:     replace = n  
                - Mixed : replace = m
                Matching with "mixed" replacement (replace = m) means that
                matching is done without replacement for each case, but with
                replacement between cases, ie a person can be a control for 
                more than one case, but can only be used as a control once
                for each of them.
keep_add_vars:  Space-separated list of additional variables from <data> 
                to include in the output datasets. Variables 
                specified in other macro parameters are automatically kept 
                and does not need to be specified, the exception being the
                variable specified in <match_date> that's not included in its
                original form in the output. All variables from <data> can be
                kept by specifying keep_add_vars = _all_.
                Default is keep_add_vars = _null_, ie no additional 
                variables are kept.
max_tries:      The maximum number of tries used to find all matches for each
                case. By default (max_tries = _auto_) the maximum number of
                tries is automatically set to
                            max_tries = <n_controls> * n_99pct
                where n_99pct = round(k*[log(k)- ln(-ln(p))]), p = 0.99
                is the approximate number of tries needed to have a 
                99% probability (100 * p), to have tried all potential 
                controls (k) at least once. This approach ensures that we are 
                reasonably sure that we have considered all potential 
                controls for each individual match that is made. Alternatively,
                a positive integer can be specified. Note that if
                max_tries = _auto_, then max_tries is recalculated in each strata
                defined by <match_exact> variables, whereas a manually specified
                number is fixed across strata.
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
  data            = ,
  out             = ,
  match_date      = ,
  out_incomplete  = _null_,
  out_info        = _null_,
  match_exact     = _null_,
  match_inexact   = %str(),
  inexact_vars    = _auto_,
  n_controls      = 10,
  replace         = y,
  keep_add_vars   = _null_,
  max_tries       = _auto_,
  seed            = 0,
  print_notes     = n,
  verbose         = n,
  del             = y
) / minoperator mindelimiter = ' ';

%put hash_match: start execution %sysfunc(compress(%sysfunc(datetime(), datetime32.)));

/* Save value of notes and varinitchk options, then disable notes */
%local opt_notes opt_varinitchk;
%let opt_notes = %sysfunc(getoption(notes));
%let opt_varinitchk = %sysfunc(getoption(varinitchk));
options nonotes;


/* Make sure there are no intermediate datasets from a previous 
run of the macro in the work directory before execution. */
proc datasets nolist nodetails;
  delete __hm_:;
run;
quit;


/*******************************************************************************
INPUT PARAMETER CHECKS 
*******************************************************************************/

/*** verbose ***/

/* Check <verbose> has a valid value. */
%if &verbose = %then %do;
  %put ERROR: Macro parameter <verbose> not specified!;
  %goto end_of_macro;  
%end;
%else %if (&verbose in y n) = 0 %then %do;
  %put ERROR: <verbose> = &verbose is not a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: verbose = n;
  %put ERROR: verbose = y;
  %goto end_of_macro;  
%end;
%else %if &verbose = y %then %do;
  %put hash_match: *** Input checks ***;
%end;


/*** print_notes ***/

/* Check <print_notes> has a valid value. */
%if &print_notes = %then %do;
  %put ERROR: Macro parameter <print_notes> not specified!;
  %goto end_of_macro;  
%end;
%else %if (&print_notes in y n) = 0 %then %do;
  %put ERROR: <print_notes> = &print_notes is not a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: print_notes = n;
  %put ERROR: print_notes = y;
  %goto end_of_macro;  
%end;
%else %if &print_notes = y %then %do;
  options notes;
%end;


/*** Check macro parameters are not empty ***/

%local parms i i_parm;
%let parms = 
  data out match_date out_incomplete out_info match_exact inexact_vars
  n_controls replace keep_add_vars max_tries seed del;   
%do i = 1 %to %sysfunc(countw(&parms, %str( )));
  %let i_parm = %scan(&parms, &i, %str( ));
  %if %quote(&&&i_parm) = %then %do;
    %put ERROR: Macro parameter <&i_parm> not specified!;
    %goto end_of_macro;    
  %end;
%end;


/*** data ***/

/* Check dataset exists. */
%if %sysfunc(exist(&data)) = 0 %then %do;
  %put ERROR: Specified <data> dataset "&data" does not exist!;
  %goto end_of_macro;
%end;

/* Check not empty. */
%local ds_id rc;
%let ds_id = %sysfunc(open(&data));
%if  %sysfunc(attrn(&ds_id, nobs)) = 0 %then %do;
  %let rc = %sysfunc(close(&ds_id));
  %put ERROR: Specified <data> dataset "&data" is empty!;
  %goto end_of_macro;
%end;
%let rc = %sysfunc(close(&ds_id));


/*** <match_inexact> ***/

/* Identify variables from <data> specified in <match_inexact>. */
%if &verbose = y %then %do;
  %put hash_match: - Identify variables in;
  %put hash_match:   <match_inexact> = &match_inexact;
%end;

data  __hm_empty;
  set &data(obs = 0);
run;

%local all_data_vars;
proc sql noprint;
  select distinct name into :all_data_vars separated by " "
    from sashelp.vcolumn
    where libname = "WORK" and memname = "__HM_EMPTY";
quit;

%local match_inexact_vars i i_var;
%let match_inexact_vars = ;
%do i = 1 %to %sysfunc(countw(&all_data_vars, %str( )));
  %let i_var = %lowcase(%scan(&all_data_vars, &i, %str( )));
  %if %sysfunc(prxmatch("&i_var", %lowcase(&match_inexact))) %then
    %let match_inexact_vars = &match_inexact_vars &i_var;
%end;

%if &verbose = y %then %do;
  %put hash_match:   Variables identified:;
  %put hash_match:   &match_inexact_vars;
%end;

/* If <inexact_vars> is not specified, override with identified variables. */
%if %eval(&verbose = y and &inexact_vars = _auto_) %then %do;
  %put hash_match:   <inexact_vars> = _auto_. Override with:;
  %put hash_match:   &match_inexact_vars;
%end;

%if &inexact_vars = _auto_ %then %let inexact_vars = &match_inexact_vars;


/*** Check variables names ***/

/* Check specified variable names are valid, exists in <data>, that none of the
specified variables have a "__" prefix, and that each variable name has length
31 or less. */
%local vars i i_var j j_var ds_id rc;
%let vars = match_date match_exact keep_add_vars inexact_vars;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  /* Check valid name */
  %do j = 1 %to %sysfunc(countw(&&&i_var, %str( )));
    %let j_var = %scan(&&&i_var, &j, %str( ));
    %if %sysfunc(nvalid(&j_var)) = 0 %then %do;
      %put ERROR: Variable "&j_var" specified in <&i_var>;
      %put ERROR: is not a valid SAS variable name!;
      %goto end_of_macro;
    %end;
  %end;
  /* Check variable exists in <data>. */
  %do j = 1 %to %sysfunc(countw(&&&i_var, %str( )));
    %let j_var = %scan(&&&i_var, &j, %str( ));
    %if (%lowcase(&j_var) in _null_ _all_) = 0 %then %do;
      %let ds_id = %sysfunc(open(&data));
      %if %sysfunc(varnum(&ds_id, &j_var)) = 0 %then %do;
        %let rc = %sysfunc(close(&ds_id));
        %put ERROR: Variable "&j_var" specified in <&i_var> does;
        %put ERROR: not exist in <data>!;
        %goto end_of_macro; 
      %end;
      %let rc = %sysfunc(close(&ds_id));
    %end;
  %end;
  /* Check length 31 at most. */
  /* Regular expression: variable must start with a letter or underscore,
  followed by 0-30 letters, numbers or underscores. The whole regular 
  expression is case-insensitive. */
  %do j = 1 %to %sysfunc(countw(&&&i_var, %str( )));
    %let j_var = %scan(&&&i_var, &j, %str( ));
    %if %sysfunc(prxmatch('^[a-zA-Z_][\w]{0,30}$', &j_var)) = 0 %then %do;
      %put ERROR: Specified variable "&j_var" in <&i_var> has length greater than 31.;
      %put ERROR: This is not allowed to make sure variable names created by the macro;
      %put ERROR: are valid!;
      %goto end_of_macro; 
    %end;
  %end;
  %do j = 1 %to %sysfunc(countw(&&&i_var, %str( )));
    %let j_var = %scan(&&&i_var, &j, %str( ));
    /* Note that "dummy" has been included in %qsubstr call so that a 
    variable name of length one can be handled correctly. */
    %if %sysevalf(%qsubstr(&j_var dummy, 1, 2) = __) %then %do;
      %put ERROR: Variable "&j_var" specified in <&i_var> has a "__" prefix;
      %put ERROR: This is not allowed to make sure that input variables are not;
      %put ERROR: overwritten by temporary variables created by the macro!;
      %goto end_of_macro; 
    %end;
  %end;
%end; /*End of i-loop */


/* Furthermore, make sure that variables in &inexact_vars does not have an
underscore prefix at all. This is to ensure that it is impossible to have a
variable, eg. _match_date, where the macro makes a __match_date variable that
might produce unwanted results doing the hash-table merge. */
%do i = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
  %let i_var = %scan(&inexact_vars, &i, %str( ));
  %if %sysevalf(%qsubstr(&j_var dummy, 1, 1) = _) %then %do;
    %put ERROR: Variable "&i_var" specified in <match_inexact> / <inexact_vars>;
    %put ERROR: has a "_" prefix. This is not allowed to avoid name collisions;
    %put ERROR: with variables created by the macro!;
    %goto end_of_macro;
  %end;
%end;


/*** out ***/

/* Check valid (libname.)member-name SAS dataset name */

/* Regular expression: (lib-name.)member-name, where the libname is
optional. The libname must start with a letter, followed by 0-7 letters, 
numbers or underscores and must end with a ".". Member-name part must start
with a letter or underscore, and is followed by 0-31 letters ,numbers or 
underscores. The whole regular expression is case-insensitive. */
%if %sysfunc(prxmatch('^([a-zA-Z][\w]{0,7}\.)*[a-zA-Z_][\w]{0,31}$', &out)) = 0 
  %then %do;
  %put ERROR: Specified <out> dataset name "&out" is invalid;
  %put ERROR: <out> must be a valid (libname.)member-name SAS dataset name.;
  %goto end_of_macro; 
%end;


/*** out_incomplete/out_info ***/

/* Check valid (libname.)member-name SAS dataset name or _null_. */

/*Regular expression: (lib-name.)member-name, where the libname is
optional. The libname must start with a letter, followed by 0-7 letters, 
numbers or underscores and must end with a ".". Member-name part must start
with a letter or underscore, and is followed by 0-31 letters ,numbers or 
underscores. The whole regular expression is case-insensitive. */
%if %sysfunc(prxmatch('^([a-zA-Z][\w]{0,7}\.)*[a-zA-Z_][\w]{0,31}$', &out_incomplete)) = 0 
  and &out_incomplete ne _null_ %then %do;
  %put ERROR: Specified <out_incomplete> dataset name "&out_incomplete" is invalid;
  %put ERROR: <out_incomplete> must be a valid (libname.)member-name SAS dataset name.;
  %goto end_of_macro; 
%end;
%if %sysfunc(prxmatch('^([a-zA-Z][\w]{0,7}\.)*[a-zA-Z_][\w]{0,31}$', &out_info)) = 0 
  and &out_info ne _null_ %then %do;
  %put ERROR: Specified <out_info> dataset name "&out_info" is invalid;
  %put ERROR: <out_info> must be a valid (libname.)member-name SAS dataset name.;
  %goto end_of_macro; 
%end;


/*** match_date ***/

/* Check only one variable is specified. */
%if %eval(%sysfunc(countw(&match_date, %str( ))) > 1) %then %do;
  %put ERROR: Only one variable can be specified in <match_date>!;
  %goto end_of_macro; 
%end;

/* Check variable is numeric. */
%local var_vt;
data _null_;
  set &data(obs = 1);
  call symput("var_vt", vtype(&match_date));  
run;
%if &var_vt ne N %then %do;
  %put ERROR: <match_date> variable "&match_date" must be numeric!;
  %goto end_of_macro;
%end;

/* Check no duplicates variable names. */
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
    %put ERROR: <match_exact> = &match_exact;
    %goto end_of_macro;
  %end;
%end;


/*** n_controls ***/

/* Check positive integer. */

/* Regular expression: starts with a number 1-9, followed by zero or
more digits (so that 0 is not allowed, but eg 10 is). */
%if %sysfunc(prxmatch('^[1-9]\d*$', &n_controls)) = 0 %then %do;
  %put ERROR: <n_controls> must be a positive integer!;
  %goto end_of_macro; 
%end;


/*** max_tries ***/

/* Check value is _auto_ or a positive integer. */
 
/* Regular expression: One of the following:
1) _auto_
2) Starts with a number 1-9, followed by zero or more digits. */
%if %sysfunc(prxmatch('^_auto_$|^[1-9]\d*$', &max_tries)) = 0 %then %do;
  %put ERROR: <max_tries> must be a positive integer or "_auto_"!;
  %goto end_of_macro; 
%end;


/*** seed ***/

/* Check integer. */
%if %sysfunc(prxmatch('^-*\d+$', &seed)) = 0 %then %do;
  %put ERROR: <seed> must be an integer!;
  %goto end_of_macro; 
%end;


/*** replace ***/

/* Check valid value. */
%if %eval(&replace in n y m) = 0 %then %do;
  %put ERROR: <replace> = &replace is not a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: replace = n;
  %put ERROR: replace = y;
  %put ERROR: replace = m;
  %goto end_of_macro;
%end;


/*** keep_add_vars ***/

%if &verbose = y %then %do;
  %put hash_match: - Input value of keep_add_vars:; 
  %put hash_match:   keep_add_vars = &keep_add_vars;
%end;

/* Check no duplicates. */
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
    %put ERROR: <keep_add_vars> = &keep_add_vars;
    %goto end_of_macro;
  %end;
%end;

/* If more than one variable is specified, make sure 
that _null_ and/or _all_ are not among the specified variables. */
%if %sysevalf(%sysfunc(countw(&keep_add_vars, %str( ))) > 1) %then %do;
  %if (_all_ in %lowcase(&keep_add_vars)) or 
      (_null_ in %lowcase(&keep_add_vars)) %then %do;
    %put ERROR: A list of variables have been specified in <keep_add_vars>;
    %put ERROR: but the list contains one/both of the;
    %put ERROR: values _null_ and _all_!;
    %goto end_of_macro;
  %end;
%end;

/* If keep_add_vars = _all_ then replace value with 
list of all variables in input dataset. */
%if &keep_add_vars = _all_ %then %do;
  data  __hm_empty;
    set &data(obs = 0);
  run;

  proc sql noprint;
    select distinct name into :keep_add_vars separated by " "
      from sashelp.vcolumn
      where libname = "WORK" and memname = "__HM_EMPTY";
  quit;
%end;

/* Remove variables that are automatically included in <out>. */
%local tmp i i_var;
%let tmp = &keep_add_vars;
%let keep_add_vars = ;
%do i = 1 %to %sysfunc(countw(&tmp, %str( )));
  %let i_var = %scan(&tmp, &i, %str( ));
  %if (&i_var in &match_exact &inexact_vars) = 0 
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


/*** del ***/

/* Check valid value. */          
%if %eval(&del in n y) = 0 %then %do;
  %put ERROR: <del> = &del is not a valid value!;
  %put ERROR: Valid values are:;
  %put ERROR: del = n;
  %put ERROR: del = y;
  %goto end_of_macro;
%end;


/******************************************************************************
LOAD INPUT DATA
******************************************************************************/

%if &verbose = y %then %do;
  %put hash_match: *** Load input data ***;
  %put hash_match: - Create macro variable with all variables given in;
  %put hash_match:   <match_exact> that is used to define strata;
  %put hash_match:   in which matching is done.;
%end;

/* The strata in which matching is done is defined by <match_exact> variables. */
%local match_stratas;
%let match_stratas = ;
%if &match_exact ne _null_ %then %let match_stratas = &match_exact;

/* If no exact matching are specified, create dummy strata variable. */
%if &verbose = y and &match_stratas = %then %do;
  %put hash_match: - No <match_exact> variables specified.;
  %put hash_match:   Add dummy matching variable __dummy_strata;
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
    where libname = "WORK" and memname = "%upcase(&data)"
      and name = "&match_date";
quit;
%if &match_date_fmt = %then %let match_date_fmt = best32.;

/* Load and restrict input data. */
%if &verbose = y %then %do;
  %put hash_match: - Loading input data;
%end;
data __hm_data1;
  format __merge_id best12. __match_date &match_date_fmt;
  set &data;
  %if &match_stratas = __dummy_strata %then %do;
    __dummy_strata = "_null_";
    keep __dummy_strata;
  %end;
  __merge_id = _n_;
  __match_date = &match_date;
  keep __merge_id __match_date &match_stratas;
  %if &inexact_vars ne %then %do; keep &inexact_vars; %end;
  %if &keep_add_vars ne _null_ %then %do; keep &keep_add_vars; %end;
run;


/******************************************************************************
PREPARE DATA
******************************************************************************/

%if &verbose = y %then %do;
  %put hash_match: *** Prepare data for matching ***;
  %put hash_match: - Create composite strata variable based on unique;
  %put hash_match:   combinations of values of <match_exact> variables:;
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
proc sort data = __hm_data2(keep = __merge_id __match_date __strata &inexact_vars) 
    out = __hm_data3(index = (__strata));
  by __strata;
run;


/******************************************************************************
MATCHING
******************************************************************************/

/* Set varinitchk option to throw an error if a variable is uninitialized.
This will help catch cases where the user has specified a variable in
<match_inexact> that does not exist in <data>. */
options varinitchk = error;

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

/* Find the length and type of variables used in inexact matching */
%local i i_var;
%do i = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
  %let i_var = %scan(&inexact_vars, &i, %str( ));
  %local var_&i._type var_&i._length var_&i._format;
  proc sql noprint;
    select type, length, format
      into :var_&i._type, :var_&i._length, :var_&i._format
      from sashelp.vcolumn
      where libname = "WORK" and memname = "__HM_DATA3"
        and lowcase(name) = lowcase("&i_var");
  quit;
  %let var_&i._type = %sysfunc(compress(&&var_&i._type));
  %let var_&i._length = %sysfunc(compress(&&var_&i._length));
  %if &&var_&i._type = char %then %let var_&i._length = $&&var_&i._length; 

  %if &&var_&i._format = %then %do;
    %if &&var_&i._type = char %then %let var_&i._format = $&&var_&i._length..;
    %else %if &&var_&i._type = num %then %let var_&i._format = best32.;
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
  proc sql;
    create table __hm_strata_cases as
      select *
        from __hm_strata_data
        where __match_date ne .
        order by __merge_id;
  quit;

  /* Make a dataset with potential controls. */
  %local j j_var;
  data __hm_strata_controls; 
    set __hm_strata_data;
    __hash_key = _n_;
    rename 
      __strata = __strata_ctrl
      __merge_id = __merge_id_ctrl
      ;
    %do j = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
      %let j_var = %scan(&inexact_vars, &j, %str( ));
      rename &j_var = _&j_var;
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

    /* If max_tries = _auto_, calculate the number of tries to find 
    controls for each case in this strata. See max_tries documentation. */
    %local max_tries_strata;
    %if &max_tries = _auto_ %then %do;
      data _null_;
        k = &n_strata_controls;
        p = 0.99;
        max_tries_strata = &n_controls * round(k*(log(k) - log(-log(p))));
        call symput("max_tries_strata", put(max_tries_strata, best12.));
      run;
    %end;
    /* Else set the maximum number of tries to specifid number. */
    %else %do;
      %let max_tries_strata = &max_tries;
    %end;

    %local j j_var;
    data  __hm_strata_matches(
            drop = __hash_key __stop __controls __tries __rand_obs __rc 
                   __highest_tries 
                   %if &replace = m %then %do; __list_controls %end;           
          )
          __hm_strata_out_incomplete(
            keep = __merge_id __match_date __strata __controls 
                   &inexact_vars
          );
      call streaminit(&seed);
      length  __hash_key __merge_id_ctrl 8 
        %do j = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
          %let j_var = %scan(&inexact_vars, &j, %str( ));
          _&j_var &&var_&j._length
        %end;
        %if &replace = m %then %do;
          __list_controls $%eval(&n_controls * 20)
        %end;
        ;
      format  __hash_key __merge_id_ctrl best12. 
        %do j = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
          %let j_var = %scan(&inexact_vars, &j, %str( ));
          _&j_var &&var_&j._format
        %end;
        ;
      /* Load potential controls into hash object. */ 
      if _n_ = 1 then do;
        declare hash h(dataset: "__hm_strata_controls");
        declare hiter iter("h");
        h.defineKey("__hash_key");
        h.defineData(
          "__hash_key", "__merge_id_ctrl"
          %do j = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
            %let j_var = %scan(&inexact_vars, &j, %str( ));
            , "_&j_var"
          %end;
        );
        h.defineDone();
        call missing(
          __hash_key, __merge_id_ctrl
          %do j = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
            %let j_var = %scan(&inexact_vars, &j, %str( ));
            , _&j_var
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
      %if &replace = m %then %do; __list_controls = ""; %end;  

      do while (__stop = 0);
        __tries + 1;
        /* Pick a random potential control. This is ineffective when 
        we match without replacement, since more and more keys wont exist. 
        But since we can't pick a random item from a hash-table directly, it 
        is not possible to do this is in a more efficient way? */
          __rand_obs = ceil(rand("uniform") * &n_strata_controls);
          __rc = h.find(key:__rand_obs);
        /* Check if key exists and if valid control. */
        if __rc = 0 
          %if &replace = m %then %do;
            and findw(__list_controls, put(__rand_obs, best12.), " ", "er") = 0
          %end;
          %if %bquote(&match_inexact) ne %then %do;
            and (&match_inexact)
          %end;
        then do;
          __controls + 1;   
          /* If matching without replacement, remove matched control
          from hash-table. */
          %if &replace = n %then %do;
            __rc = h.remove(key: __rand_obs);
          %end;
          /* If matching with mixed replacement, add id to list of
          ids already used as controls */
          %if &replace = m %then %do;
            __list_controls = catx(" ", __list_controls, put(__rand_obs, best12.));
          %end;
          /* Output matched control. */
          output __hm_strata_matches;
        end;
        /* When we have found n_control valid controls or we reach the
        maximum number of tries we stop the loop. */ 
        if __controls >= &n_controls or __tries >= &max_tries_strata then __stop = 1;
   
        /* If we have not found the wanted number of controls for a case
        we output info on the case to a dataset. */
        if __stop = 1 then do;
          if __controls < &n_controls then output __hm_strata_out_incomplete;
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
      %put ERROR- Possible explanations:;
      %put ERROR- 1) <match_inexact> contains syntax errors.;
      %put ERROR- 2) <inexact_vars> has been explicitly specified;
      %put ERROR-    but does not include all variables used;
      %put ERROR-    in <match_inexact>.;
      %put ERROR- 3) The hash-table could not fit in memory.;
      %goto end_of_macro; 
    %end;
  %end;
  /* If no cases or no potential controls create an empty dataset. */
  %else %do;
    options varinitchk = note;
    data __hm_strata_matches;
      length __merge_id_ctrl __match_id 8
        %do j = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
          %let j_var = %scan(&inexact_vars, &j, %str( ));
          _&j_var &&var_&j._length
        %end;
      ;
      format __merge_id_ctrl __match_id best12.
        %do j = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
          %let j_var = %scan(&inexact_vars, &j, %str( ));
          _&j_var &&var_&j._format
        %end;
      ;
      set __hm_strata_cases(obs = 0);
    run;

    data __hm_strata_out_incomplete;
      length __controls 8
        %do j = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
          %let j_var = %scan(&inexact_vars, &j, %str( ));
          &j_var &&var_&j._length
        %end;
        ;
      format __controls best12.
        %do j = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
          %let j_var = %scan(&inexact_vars, &j, %str( ));
          &j_var &&var_&j._format
        %end;
        ;
        set __hm_strata_cases(obs = 0);
    run;
    options varinitchk = error;
  %end;

  /* In some weird cases, using proc append to automatically create the
  base dataset if it does not exist will fail. Therefore we will explictly
  define it here, to make sure everything works as intended. */
  %if &i = 1 %then %do;
    data __hm_all_matches1;
      set __hm_strata_matches;
    run;
    
    data __hm_all_out_incomplete1;
      set __hm_strata_out_incomplete;
    run;
  %end;
  %else %do;
    /* Append matches from strata to dataset with all matches. */
    proc append base = __hm_all_matches1 data = __hm_strata_matches;
    run;

    /* Append cases for which not all matches could be found. */
    proc append base = __hm_all_out_incomplete1 data = __hm_strata_out_incomplete;
    run;
  %end;

  %local time_stop duration;
  %let time_stop = %sysfunc(datetime());
  %let duration = %sysevalf(&time_stop - &time_start);

  /* Estimate time until all matching is done, based on the median
  matching time in the stratas so far. */
  %local duration_median est_finish;
  %if &i = 1 %then %do;
    data __hm_durations;
      length duration 8;
      duration = &duration;
      output;
    run;
  %end;
  %else %do;
    data __hm_durations;
      set __hm_durations;
      if _n_ = 1 then do;
        output;
        duration = &duration;
      end;
      output;
    run;
  %end;
  /* NOTE: Calculating the median and saving it in a macro variable 
  is easily done as below, but this causes SAS to run out of RAM when
  there are many strata. SAS is allocating memory that is not freed up
  in each iteration? It is unclear why this happens. To circumvent
  the problem, another less elegant approach is used. */
/*  proc sql noprint;*/
/*    select median(duration) into :duration_median*/
/*      from __hm_durations;*/
/*  quit;*/
  proc means data = __hm_durations noprint;
    output out = __hm_durations_median median(duration) = duration_median;
  run;
  data _null_;
    set __hm_durations_median;
    call symput("duration_median", put(duration_median, best12.));
  run;

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
    %let max_tries_strata = .;
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
    __max_tries = &max_tries_strata;
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

/* Restore value of varinitchk option */
options varinitchk = &opt_varinitchk;


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
      __merge_id_ctrl
      %do i = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
        %let i_var = %scan(&inexact_vars, &i, %str( ));
        _&i_var
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
      __merge_id_ctrl = __merge_id 
      %do i = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
        %let i_var = %scan(&inexact_vars, &i, %str( ));
        _&i_var = &i_var
      %end;
      )
  );
  set __hm_all_matches1(
    rename = (__match_id = tmp)
    drop = 
      __merge_id
      %do i = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
        %let i_var = %scan(&inexact_vars, &i, %str( ));
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
  create table &out as
    select 
    %if &match_stratas ne __dummy_strata %then %do;
      %do i = 1 %to %sysfunc(countw(&match_stratas, %str( )));
        %let i_var = %scan(&match_stratas, &i, %str( ));
        b.&i_var,
      %end;
    %end;
      a.__match_id, 
      a.__match_date, 
      a.__case
    %if &inexact_vars ne %then %do;
      %do i = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
        %let i_var = %scan(&inexact_vars, &i, %str( ));
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

%if &out_incomplete ne _null_ %then %do;
  %if &verbose = y %then %do;
    %put hash_match: - Info on cases with incomplete matches;
  %end;

  /* merge __strata and keep_add_vars variables back to matched 
  data */
  %local i i_var;
  proc sql;
    create table &out_incomplete as
      select  
      %if &match_stratas ne __dummy_strata %then %do;
        %do i = 1 %to %sysfunc(countw(&match_stratas, %str( )));
          %let i_var = %scan(&match_stratas, &i, %str( ));
          b.&i_var,
        %end;
      %end;
        a.__match_date,
        a.__controls
      %if &inexact_vars ne %then %do;
        %do i = 1 %to %sysfunc(countw(&inexact_vars, %str( )));
          %let i_var = %scan(&inexact_vars, &i, %str( ));
          , a.&i_var
        %end; 
      %end;
      %if &keep_add_vars ne _null_ %then %do;
        %do i = 1 %to %sysfunc(countw(&keep_add_vars, %str( )));
          %let i_var = %scan(&keep_add_vars, &i, %str( ));
            , b.&i_var
        %end;
      %end;
        from __hm_all_out_incomplete1 as a
        left join
        __hm_data2(rename = (__merge_id = __tmp)) as b
        on a.__merge_id = b.__tmp
        order by b.__strata, a.__merge_id;
  quit;
%end;


/******************************************************************************
MAKE OUTPUT WITH INFO
******************************************************************************/

%if &out_info ne _null_ %then %do;
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
    set __hm_all_out_incomplete1;
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
  data &out_info;
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

    drop __strata;
    %if &match_stratas = __dummy_strata %then %do; drop __dummy_strata; %end; 
  run;
%end;


%end_of_macro:


/* Delete temporary datasets created by the macro. */
%if &del ne n  %then %do;
  proc datasets nodetails nolist;
    delete __hm_:;
  run;
  quit;
%end; 

/* Restore value of options */
options &opt_notes;
options varinitchk = &opt_varinitchk;

%put hash_match: end execution   %sysfunc(compress(%sysfunc(datetime(), datetime32.)));

%mend hash_match;
