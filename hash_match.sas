/*******************************************************************************
AUTHOR:     Thomas Boejer Rasmussen
VERSION:    0.2.1
LICENCE:    Creative Commons CC0 1.0 Universal  
            (https://www.tldrlegal.com/l/cc0-1.0)
********************************************************************************
DESCRIPTION:
Matching using a hash-table merge approach. The input dataset is expected to
be a source population with the following information on each person:
- A unique id.
- Start and end of follow-up period where the person is eligible to be a 
case/control (exposed/unexposed) and free of whatever other relevant diseases 
and events.
- Index date. Date the person becomes a case (exposed). 
- Information on any matching variables. 

Matching is done for each case on the date they become cases,
ie on the index date.

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros
********************************************************************************
PARAMETERS:
*** REQUIRED ***
in_ds:            (libname.)member-name of input dataset on source population.         
out_pf:           (libname.)member-name prefix of output datasets. The following
                  datasets are created by the macro:
                  <out_pdf>_matches: Matched population.
                  <out_pdf>_no_matches: Information on cases for which 
                  no (or only partial) matches could be found.
                  <out_pdf>_info: Miscellaneous helpful information and 
                  diagnostics that can be helpful to evaluate the 
                  appropriateness of the matched cohort.
id_var:           Person id. Missing values not allowed. Must
                  be unique in stratas defined by variables given in <by>. 
fu_start:         Start of follow-up. Must be a numeric variable.
                  Missing values not allowed.
fu_end:           End of follow-up. Must be a numeric variable.
                  Missing values not allowed.
                  fu_end must also fullfil <fu_start> <= <fu_end>.
index_var:        Date, if any, the person becomes a case. Must be a 
                  numeric variable.
*** OPTIONAL ***
match_vars:       Space-separated list of matching variables. Default is 
                  match_vars = _null_, ie no matching variables are used. 
n_controls:       Number of controls to match to each case. 
                  Default is n_controls = 10.
replace:          Match with replacement:
                  - Yes: replace = y (default)
                  - No:  replace = n  
where:            Condition used to to restrict the input dataset in a where-
                  statement, eg where = %str(var = "value"). 
by:               Space-separated list of by variables. Default is by = _null_,
                  ie no by variables. 
max_tries:        The number of tries used to find all matches for each
                  case is defined as
                    n = min(<n_controls> * n_99pct, <max_tries>)
                  where 
                    n_99pct = round(k*[log(k)- ln(-ln(p))]), p = 0.99
                  is the approximate number of tries needed to have a 
                  99% probability (p), to have tried all potential controls (k).
                  We multiply this approximate number with <n_matches>, since
                  we want to be reasonably sure we can find all the matches we
                  want, and we take the minimum of this number and <max_tries>,
                  to set a limit for very large stratas. 
                  Default is max_tries = 10**6. 
                  n_99pct formula is from 
                  https://math.stackexchange.com/questions/1155615/
                  probability-of-picking-each-of-m-elements-at-least-once-after-
                  n-trials.
ctrl_until_case:  Are cases allowed to be controls until they become cases:
                  - Yes: ctrl_until_case = y (default)
                  - No:  ctrl_until_case = n
keep_add_vars:    Space-separated list of additional variables from the input 
                  to include in the <out_pf>_matches output dataset. Variables 
                  specified in the required macro parameters are automatically 
                  kept and does not need to be specified. All variables from
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
  id_var          = ,
  fu_start        = ,
  fu_end          = ,
  index_var       = ,
  match_vars      = _null_,
  n_controls      = 10,
  replace         = y,
  where           = %str(),
  by              = _null_,
  max_tries       = 10**6,
  ctrl_until_case = y,
  keep_add_vars   = _null_,
  seed            = 0,
  print_notes     = n,
  verbose         = n,
  del             = y
) / minoperator mindelimiter = ' ';

%put hash_match: start execution;

%local opt_notes;
/* Find value of notes option, save it, then change then disable
notes during parameter checks. */
%let opt_notes = %sysfunc(getoption(notes));
options nonotes;

/*******************************************************************************
INPUT PARAMETER CHECKS 
*******************************************************************************/
%local  vars i i_var j j_var ds_id rc var_vt tmp_keep_add_vars;

%let vars = 
  in_ds out_pf id_var index_var match_vars fu_start fu_end where by 
  ctrl_until_case keep_add_vars replace n_controls max_tries seed 
  print_notes verbose del;               

/* Check that none of the macro parameters are empty (except possibly where). */
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %if (&i_var in where) = 0 and %sysevalf(&&&i_var = ) %then %do;
  %put ERROR: Macro parameter "&i_var" not specified!;
  %goto end_of_macro;    
  %end;
%end;
 
/* Remove single and double quotes from macro parameters where they are not 
supposed to be used, but might have been used anyway. */
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %if (&i_var in where ) = 0 %then %do;
    %let &i_var = %sysfunc(tranwrd(&&&i_var, %nrstr(%"), %str( )));
    %let &i_var = %sysfunc(tranwrd(&&&i_var, %nrstr(%'), %str( )));
  %end;
%end;

/* Make sure all relevant macro parameter values are in lowercase. */
%let vars = ctrl_until_case replace print_notes del;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %let &i_var = %lowcase(&&&i_var);
%end;


/* ctrl_until_case, replace, print_notes, verbose 
and del checks */

/* Check that y/n macro parameters are specified correctly */
%let vars = ctrl_until_case replace print_notes verbose del;            
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %if %eval(&&&i_var in n y) = 0 %then %do;
    %put ERROR: "&i_var" does not have a valid value!;
    %goto end_of_macro;
  %end;
%end;

/* Enable notes if specified*/
%if &print_notes = y %then %do; 
  options notes;
%end;         
 
%if &verbose = y %then %do;
  %put hash_match: *** Input checks ***;
%end;

/* Check that all specified variable names are valid, exists in the input
dataset, and that none of the specified variables have a "__" prefix. 
Note that "dummy" has been included in %qsubstr call so that the scenario
of one variable with a very short name can be handles correctly. */
%let vars = id_var index_var fu_start fu_end match_vars by keep_add_vars;
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
    %if %eval(%qsubstr(&j_var dummy, 1, 2) = __) %then %do;
      %put ERROR: Variable "&j_var" specified in "&i_var" has a "__" prefix;
      %put ERROR: This is not allowed to make sure that input variables are not;
      %put ERROR: overwritten by temporary variables created by the macro!;
      %goto end_of_macro; 
    %end;
  %end; /* End of j-loop */
%end; /*End of i-loop */


/*** in_ds checks ***/

/* Check input dataset exists. */
%if %sysfunc(exist(&in_ds)) = 0 %then %do;
  %put ERROR: Specified "in_ds" dataset "&in_ds" does not exist!;
  %goto end_of_macro;
%end;

/* Check input dataset is not empty. */
%let ds_id = %sysfunc(open(&in_ds));
%if  %sysfunc(attrn(&ds_id, nobs)) = 0 %then %do;
  %let rc = %sysfunc(close(&ds_id));
  %put ERROR: Specified "in_ds" dataset "&in_ds" is empty!;
  %goto end_of_macro;
%end;
%let rc = %sysfunc(close(&ds_id));


/*** out_pf checks ***/

/* prefix needs to be a valid (libname.)member-name, where the member-name
part can have a length of 23 at the most, to make sure that the added 
surfix of the output dataset names are not too long. */

/* Regular expression: (lib-name.)member-name, where the libname is
optional. The libname must start with a letter, followed by 0-7 letters, 
numbers or underscores and must end with a ".". Member-name part must start
with a letter or underscore, and is followed by 0-22 letters ,numbers or 
undrscores. The whole regular expression is case-insentitive. */
%if %sysfunc(prxmatch('^([a-z][\w\d]{0,7}\.)*[\w][\w\d]{0,22}$', &out_pf)) = 0 
  %then %do;
  %put ERROR: Specified "out_pf" output prefix "&out_pf" is;
  %put ERROR: either invalid or the member-name part has length greater than 23;
  %put ERROR: which is not allowed!;
  %goto end_of_macro; 
%end;


/*** id_var ***/

/* Check only one variable specified in "id_var". */
%if %eval(%sysfunc(countw(&id_var, %str( ))) > 1) %then %do;
  %put ERROR: Only one variable can be specified in "id_var"!;
  %goto end_of_macro; 
%end;


/*** index_var, fu_start, and fu_end checks ***/

/* Check for each macro parameter that only one variable is specified, and
that the variable is numeric. */
%let vars = index_var fu_start fu_end;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %if %eval(%sysfunc(countw(&&&i_var, %str( ))) > 1) %then %do;
      %put ERROR: Only one variable can be specified in "&i_var"!;
      %goto end_of_macro; 
  %end;
  data _null_;
    set &in_ds(obs = 1);
    call symput("var_vt", vtype(&&&i_var));  
  run;
  %if &var_vt ne N %then %do;
    %put ERROR: The variable specified in "&i_var" must be numeric!;
    %goto end_of_macro;
  %end;
%end; /* End of i-loop */


/*** n_controls and max_tries checks ***/

/* Check that macro parameter value is a positive integer. "max_tries" is
likely to be a large number which is easier to write on the form "10 ** x", so
we evaluate the expression given in &max_tries before checking that it is an
integer.
Regular expression: Starts with a number 1-9, followed by, and ends with,
one or more digits (so that eg. 0 is not allowed, but 10 is) */
%if %sysfunc(prxmatch('^[1-9]\d*$', &n_controls)) = 0 %then %do;
  %put ERROR: "n_controls" must be a positive integer!;
  %goto end_of_macro; 
%end;
%if %sysfunc(prxmatch('^[1-9]\d*$', %sysevalf(&max_tries))) = 0 %then %do;
  %put ERROR: "max_tries" must be a positive integer!;
  %goto end_of_macro; 
%end;


/*** seed checks ***/

/* Must be an integer */
%if %sysfunc(prxmatch('^-*\d*$', &seed)) = 0 %then %do;
  %put ERROR: "seed" must be an integer!;
  %goto end_of_macro; 
%end;


/*** keep_add_vars checks ***/

%if &verbose = y %then %do;
  %put hash_match: - Input value of "keep_add_vars": &keep_add_vars;
%end;

/* If more than one variable is specified, make sure that _null_ and/or
_all_ are not among the specified variables. */
%if %sysevalf(%sysfunc(countw(&keep_add_vars, %str( ))) > 1) %then %do;
  %if (_all_ in %lowcase(&keep_add_vars)) or 
      (_null_ in %lowcase(&keep_add_vars)) %then %do;
    %put ERROR: A list of variables have been specified in "keep_add_vars";
    %put ERROR: but the list contains one/both of the protected;
    %put ERROR: values _null_ and _all_!;
    %goto end_of_macro;
  %end;
%end;

/* If keep_add_vars = _all_ then replace with all variables input dataset.
This will be automatically adjusted in the next step. */
%if &keep_add_vars = _all_ %then %do;
  data  __hm_empty;
    set __data1(obs = 0);
  run;

  proc sql noprint;
    select distinct name into :keep_add_vars separated by " "
      from sashelp.vcolumn
      where libname = "WORK" and memname = "__HM_EMPTY";
  quit;
%end;

/* Check that if a list of variables are specified and already 
automatically included variables are included in the list, that they are
remove them from the list. */

%let tmp_keep_add_vars = &keep_add_vars;
%let keep_add_vars = ;
%do i = 1 %to %sysfunc(countw(&tmp_keep_add_vars, %str( )));
  %let i_var = %scan(&tmp_keep_add_vars, &i, %str( ));
  %if (&i_var in &id_var &fu_start &fu_end &index_var &match_vars &by) = 0 
    %then %let keep_add_vars = &keep_add_vars &i_var;
%end;

/* If the removal of redundant variables from the list results in the 
macro variable being empty, set it to _null_ */
%if &keep_add_vars = %then %let keep_add_vars = _null_;

%if &verbose = y %then %do;
  %put hash_match: - Value of "keep_add_vars" after checks: &keep_add_vars;
%end;

%if &verbose = y %then %do;
  %put hash_match: - All initial input checks completed;
%end;

/******************************************************************************
LOAD INPUT DATA
******************************************************************************/

%local match_stratas;

%if &verbose = y %then %do;
  %put hash_match: *** Load input data ***;
  %put hash_match: - Creating macro variable "match_stratas" including all;
  %put hash_match:   variables given in "match_vars" and "by";
%end;
/* The stratas in which we will do matching is defined by the variables given
in &match_vars and &by. */
%let match_stratas = ;
%if &by ne _null_ %then %let match_stratas = &match_stratas &by;
%if &match_vars ne _null_ %then %let match_stratas = &match_stratas &match_vars;

/* If no matching or by variables are given, we will create a dummy strata
variable to facilitate the analyses. */
%if &verbose = y and &match_stratas = %then %do;
  %put hash_match: - No matching variables specified.;
  %put hash_match:   Dummy matching variable __dummy_strata will be added;
  %put hash_match:   to the input data and "match_stratas" to facilitate analyses.;
%end;
%if &match_stratas = %then %let match_stratas = __dummy_strata;
%if &verbose = y %then %do;
  %put hash_match: - match_stratas = &match_stratas; 
%end;
/* Load and restrict input data, and rename variables to facilitate the
analyses*/
data __hm_data1(rename = (
    &fu_start = __start
    &fu_end  = __end
    &index_var = __index
    &id_var = __id
  ));
  set &in_ds;
  where &where;
  %if &match_stratas = __dummy_strata %then %do;
    __dummy_strata = "_null_";
  %end;
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
  %put hash_match: - Input data succesfully loaded, where statement;
  %put hash_match:   did not produce any warnings or errors.;
  %put hash_match: - Renamed variables:;
  %put hash_match:   &fu_start -> __start;
  %put hash_match:   &fu_end -> __end;
  %put hash_match:   &index_var -> __index;
  %put hash_match:   &id_var -> __id;
%end;

/******************************************************************************
CHECK INPUT DATA
******************************************************************************/
%local miss_id miss_start miss_end end_start;

/* Check that __id values are unique (in stratas of by-variables values if
specified). */
%if &verbose = y %then %do;
  %put hash_match: *** Check input data ***;
  %put hash_match: - Checking that __id values are unique;
%end;
proc sort data = __hm_data1 nodupkeys 
    dupout = __hm_dup_id(keep = %if &by ne _null_ %then %do; &by %end; __id);
  by %if &by ne _null_ %then %do; &by %end; __id;
run;

proc sql noprint;
  select count(*) 
    into :n_dups
    from __hm_dup_id;
quit;

%if %sysevalf(&n_dups > 0) %then %do;
  %put ERROR- id variable "id_var" contain dublicate values!;
  %if &by ne _null_ %then %do;
    %put ERROR- in one or more stratas defined by variables: &by..;
  %end;
  %goto end_of_macro;
%end;

/* Check that __id, __start, and __end does not contain missing values, and that
__start <= __end for all ids. */
%if &verbose = y %then %do;
  %put hash_match: - Checking that __id, __start, and __end does not contain;
  %put hash_match:   missing values, and that __start <= __end for all ids;
%end;
data __hm_check_data1;
  set __hm_data1(keep = __start __end __id);
  __miss_id = missing(__id);
  __miss_start = (__start = .);
  __miss_end = (__end = .);
  __end_start = (__end < __start);
  output;
run;

proc means data = __hm_check_data1 noprint;
  output out = __hm_check_data2
    sum(__miss_id __miss_start __miss_end __end_start) = 
      __miss_id __miss_start __miss_end __end_start
    / noinherit;
run;

proc sql noprint;
  select __miss_id, __miss_start, __miss_end, __end_start 
    into :miss_id, :miss_start, :miss_end, :end_start 
    from __hm_check_data2;
quit;

%if %sysevalf(&miss_id > 0) %then %do;
  %put ERROR- Variable "&id_var" has &miss_id observations with missing values!; 
  %goto end_of_macro;
%end;
%if %sysevalf(&miss_start > 0) %then %do;
  %put ERROR- Variable "&fu_start" has &miss_start observations with missing values!;
  %goto end_of_macro;
%end;
%if %sysevalf(&miss_end > 0) %then %do;
  %put ERROR- Variable "&fu_end" has &miss_end observations with missing values!;
  %goto end_of_macro;
%end;
%if %sysevalf(&end_start > 0) %then %do;
  %put ERROR- There are &end_start persons have "&fu_end" < "&fu_start"!; 
  %goto end_of_macro;
%end;


/******************************************************************************
PREPARE DATA
******************************************************************************/
%local i i_strata n_strata;

%if &verbose = y %then %do;
  %put hash_match: *** Prepare data for hash-table matching ***;
  %put hash_match: - Creating a composite strata variable based on the unique;
  %put hash_match:   combinations of the values of the variables:;
  %put hash_match:     &match_stratas;
%end;

/* Find strata values and make a new composite strata variable. */
proc sort data = __hm_data1(keep = &match_stratas) 
    out = __hm_stratas1 nodupkeys; 
  by &match_stratas;
run;

data __hm_stratas2;
  set __hm_stratas1;
  __strata = _n_;
run;

proc sql noprint;
  select count(*) into :n_strata
    from __hm_stratas2;
quit;


/* replace matching variables in data with the new composite strata variable.*/
%if &verbose = y %then %do;
  %put hash_match: - Replacing the specified matching/by variables;
  %put hash_match:     &match_stratas;
  %put hash_match:   with the composite variable __strata in the data;
%end;
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
  %put hash_match: - Sort data accoring to __strata, and create an index;
  %put hash_match:   on __strata for fast subsetting of the data;
%end;
/* Restrict and sort data, and then create index. */
proc sort 
    data = __hm_data2(keep = __id __index __start __end __strata) 
    out = __hm_data3(index = (__strata));
	by __strata;
run;

/******************************************************************************
MATCH
******************************************************************************/
%local  points progress opt_notes_value vars n_strata_cases n_stratat_controls 
        max_cnt strata_time_all i strata_start strata_end strata_time 
        strata_median j j_point j_pct est_finish max_attempts;

/* Determine the points in the matching procedure where information is 
printed to the log, based on the total number of stratas. */
%if &verbose = y %then %do;
  %put hash_match: *** Matching ***;
%end;
data __hm_progress_points;
  do i = 1 to 10;
    point = ceil(i * &n_strata / 10);
    progress = compress(put(point / &n_strata, percent10.));
    output;
  end;
  drop i;
run;

proc sql noprint;
  select distinct point, progress
    into :points separated by "$" 
         ,:progress separated by "$"
    from __hm_progress_points;
quit;

/* Disble notes in log */
options nonotes;

/* Make sure there are no dataset from matching process from a previous run 
of´the macro in the work directory, before we do the matching. */
proc datasets nolist nodetails;
  delete __hm_data_strata __hm_cases __hm_potential_controls
         __hm_matches __hm_not_full_matches_id
         __hm_all_matches1 __hm_all_not_full_matches_id1
         __hm_info1 __hm_strata_info;
run;
quit;

/* Find the length of some of the input variables. */
%let vars = __id __index __start __end;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %local &i_var._type &i_var._length;
  proc sql noprint;
    select type, length 
      into :&i_var._type, :&i_var._length
      from sashelp.vcolumn
      where libname = "WORK" and memname = "__HM_DATA3"
        and name = "&i_var";
  quit;
  %let &i_var._type = %sysfunc(compress(&&&i_var._type));
  %let &i_var._length = %sysfunc(compress(&&&i_var._length));
  %if &&&i_var._type = char %then %let &i_var._length = $&&&i_var._length;
%end;

/* Find matches in each strata. */
%do i = 1 %to &n_strata;
  
  %if &i = 1 %then %do;
    %put Matching progress:;
    %put %sysfunc(datetime(), datetime32.): %str(  0%%);
  %end;

  %let strata_start = %sysfunc(datetime());

  /* Restrict data strata. */
  data __hm_data_strata;
    set __hm_data3;
    where __strata = &i;
  run;

  /* Find cases in strata */
  data __hm_cases;
    set __hm_data_strata;
    where __start <= __index <= __end;
    drop __start __end;
  run;

  /* Make a dataset with potential controls, and add a
  variable with the observation number. */
  data __hm_potential_controls(rename=(
          __id = __id_ctrl
          __index = __index_ctrl
          __start = __start_ctrl
          __end = __end_ctrl
          )); 
    set __hm_data_strata;
    %if &ctrl_until_case = n %then %do;
      where __index = .;
    %end;
    format __obs 10.;
    __obs=_n_;
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

  /* If both cases and controls in strata, find controls for each case using a 
  hash-table merge. */
  %if &n_strata_controls > 0 and &n_strata_cases > 0 %then %do;
    data __hm_matches(drop = __n)
         __hm_not_full_matches_id(keep = __id __strata __index __n);
    	call streaminit(&seed.);
    	length	__obs 8 __id_ctrl &__id_length __index_ctrl &__index_length 
              __start_ctrl &__start_length __end_ctrl &__end_length;
    	/* Load potential controls hash object */	
    	if _n_ = 1 then do;
    		declare hash h(dataset: "__hm_potential_controls");
    		declare hiter iter("h");
    		h.defineKey("__obs");
    		h.defineData(
    			"__obs", "__id_ctrl", "__index_ctrl", "__start_ctrl", "__end_ctrl"
    			);
    		h.defineDone();
    		call missing(__obs, __id_ctrl, __index_ctrl, __start_ctrl, __end_ctrl);

        /* Initalize a match id variable */
        __match_id = 0; 

        /* formula from link in start of file */
        retain __nobs __k __p __max_attempts;
   	    __nobs = h.num_items;
        __k = __nobs;
        __p = 0.99;
        __max_attempts = min(
          &n_controls * round(__k*(log(__k) - log(-log(__p)))), 
          &max_tries
        );
        call symput("max_attempts", put(__max_attempts, best12.));

        /* Make variable to keep track of the actual max number of tries 
        needed to find all &n_controls matches. */
        retain __max_cnt;
          __max_cnt = .;
    	end;

    	/* Open case dataset */
    	set __hm_cases;

      /* initialize utility variables */
    	__stop = 0;
    	__n = 0;
    	__cnt = 0;
      __match_id + 1;

    	do while (__stop = 0);
    		__cnt+1;
    		/* Pick a random potential control */
          __rand_obs = max(1, round(rand("uniform") * __nobs));
      		__rc = h.find(key:__rand_obs);
    		/* Check if key exists in hash table and if valid control */
        if __rc = 0 and __id ne __id_ctrl
          and __start_ctrl <= __index <= __end_ctrl
          and (__index_ctrl = . or __index < __index_ctrl)     
    		/* If the control is valid we add one to the counter 
    		keeping track of the number of found valid controls
    		and output the obervation */
    		then do;
    			__n+1; 	
          /* If matching without replacemnt, remove matched control
          from hash-table. */
          %if &replace = n %then %do;
            __rc = h.remove(key: __rand_obs);
          %end;
          /* Output matched control */
          output __hm_matches;
    		end;
    		/* When we have found 10 valid controls we stop the loop */ 
    		if __n = &n_controls then __stop = 1;
    		/* Exit condition to avoid infinite loops. */
        if __cnt > __max_attempts then __stop = 1;
        /* If we have not found the wanted number of controls for a case
        we output the id value to a dataset */
        if __stop = 1 and __n < &n_controls then output __hm_not_full_matches_id;
        if __stop = 1 then do;
          /* Update maximum number of tries needed to find all controls */
          __max_cnt = max(__cnt, __max_cnt);
          call symput("max_cnt", put(__max_cnt, best12.));
        end;
      end;
      keep __id_ctrl __index_ctrl __match_id __id __index __strata __n;
    run;
  %end;
  /* Else make empty dataset */
  %else %do;
    data __hm_matches;
      format __index_ctrl __match_id best12.;
      set __hm_cases(obs = 0);
      __id_ctrl = __id;
    run;

    data __hm_not_full_matches_id;
      set __hm_cases(keep = __id __strata __index);
      __n = 0;
    run;
  %end;

  /* Append matches from strata to dataset */
  proc append base = __hm_all_matches1 data = __hm_matches;
  run;

  /* Append ids for which not all matches could be found */
  proc append base = __hm_all_not_full_matches_id1
      data = __hm_not_full_matches_id;
  run;

  %let strata_end = %sysfunc(datetime());
  %let strata_time = %sysevalf(&strata_end - &strata_start);

  %if &i = 1 %then %let strata_time_all = &strata_time;
  %else %let strata_time_all = &strata_time_all, &strata_time;
  %let strata_median = %sysfunc(median(&strata_time_all));
  %let est_finish = 
    %left(%qsysfunc(
      putn(
        %sysevalf(&strata_end + &strata_median * (&n_strata - &i)), 
        datetime32.
      )
    ));

  /* Make dataset with strata information */
  %if &n_strata_cases  = 0 or &n_strata_controls = 0 %then %do;
    %let max_attempts = .;
    %let max_cnt = .;
  %end;
  data __hm_strata_info;
    format __strata __n_cases __n_potential_controls best12. 
           __start __end datetime32. __time_sec 20.2;
    __strata = &i;
    __n_cases = &n_strata_cases;
    __n_potential_controls = &n_strata_controls;
    __start = &strata_start;
    __end = &strata_end;
    __time_sec = &strata_time;
    __max_attempts = &max_attempts;
    __max_cnt = &max_cnt;
  run;
      
  /* Append strata diagnostics */
  proc append base = __hm_info1 data = __hm_strata_info;
  run;
  
  /* Print progress information to the log */
  %do j = 1 %to %sysfunc(countw(&points, $));
    %let j_point = %scan(&points, &j, $);
    %let j_pct = %scan(&progress, &j, $);
    %if &i = &j_point %then %do;
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
%local i i_strata;

%if &verbose = y %then %do;
  %put hash_match: *** Make output dataset with matched data ***;
%end;

proc sort data = __hm_all_matches1;
  by __strata __match_id __id __id_ctrl;
run;

/* Cases */
data __hm_all_matches2_cases;
	set __hm_all_matches1(
    rename = (__match_id = temp) 
    drop = __id_ctrl __index_ctrl
  );
	length __match_id 8 __case 3;
	format __match_id 10. __case 1.;
	by __strata temp;
	retain __match_id;
	if _n_ = 1 then __match_id = 0;
	if first.temp then do;
		__match_id + 1;
		__case = 1;
		output;
	end;
  drop temp;
run;

/* Controls */
data __hm_all_matches2_controls(
    rename = (
      __id_ctrl = __id 
      __index_ctrl = __index
      )
  );
	set __hm_all_matches1(rename = (__match_id = temp));
	length __match_id 8 __case 3;
	format __match_id 10. __case 1.;
	by __strata temp;
	retain __match_id;
	if _n_ = 1 then __match_id = 0;
	if first.temp then do;
		__match_id = __match_id + 1;
	end;	
	__case = 0;
  drop temp __id __index ;
run;

data __hm_all_matches3;
	set __hm_all_matches2_cases __hm_all_matches2_controls;
run;

proc sort data = __hm_all_matches3;
  by __match_id descending __case;
run;

data __hm_all_matches4;
  set __hm_all_matches3;
  by __match_id;
  format __match_date date9.;
  retain __match_date;
  if first.__match_id then __match_date = __index;
run;

/* merge variables back to matched data */
proc sql;
  create table __hm_all_matches5 as
    select a.__match_id, a.__match_date, a.__case, a.__id,
           a.__index, a.__strata, b.__start, b.__end
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
        __index = &index_var __id = &id_var   
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
        __index = &index_var __id = &id_var   
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
