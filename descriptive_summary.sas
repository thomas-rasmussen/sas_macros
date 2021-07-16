/*******************************************************************************
AUTHOR:     Thomas Boejer Rasmussen
VERSION:    0.1.0
DATE:       2020-03-28
********************************************************************************
DESCRIPTION:
Produces a descriptive summary of variables in a dataset. See the accompanying 
examples for how the output dataset is intended to be used with proc report. 

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros
********************************************************************************
PARAMETERS:
*** REQUIRED ***
in_ds:            (libname.)member-name of input dataset or a filepath enclosed
                  in quotes.
out_ds:           (libname.)member-name of output dataset or a filepath enclosed
                  in quotes. The output dataset is on long format with the
                  following variables:
                  - __var: Variable name. A variable __n counting number of
                    observations are added to the list of variables specified
                    in "var_list" (see below). Furthermore categorical 
                  variables have a line for each value and an added title line.
                  - __label: Variable labels. 
                  - __stat_char: variable statistics as a formatted text string.
                  - __stat_num1 - __stat_num3: numerical variables with raw
                    summary statistics.
                  - __report_dummy: dummy variable intended to be used with
                    proc report to make the final table. See examples.
                  If any by or strata variables are specified these are also
                  included in the output dataset. If a strata variable is
                  provided, an overall strata is also added.
var_list:         List of patient characteristic variables.     
*** OPTIONAL ***
by:               Space-separated list of by variables. Input data does not
                  need to be sorted according to the specified by-variables. 
strata:           Stratification variable. Overall strata is added to data.
                  Can not contain missing values / empty strings as these are 
                  used to denote overall stratas. A stratification variable
                  is not allowed to be also included in "by".
where:            Condition used to to restrict the input dataset in a where-
                  statement, eg where = %str(var = "value").
var_types:        Space-separated list of variable types associated with 
                  variables in var_list. Variable types are automatically 
                  guessed from the input data if the default value 
                  var_types = auto is given. To manually overwrite this, 
                  specify the type of each variable (see examples):
                  - dichotomous: d
                  - categorical: cat
                  - continuous: cont
                  The algorithm guessing the types works as follows:
                  1) If character variable: categorical
                  2) Else, if numeric and one or two distinct values that
                     are zero and/or one: dichotomous
                  3) Else, if numeric and "cat_groups_max" or fewer
                     distinct values: categorical. (see "cat_groups_max" below)
                  4) Else: continuous.
var_stats:        Statistics to calculate for each variable in var_list. If the 
                  default value var_stats = auto is given, the statistics are 
                  automatically chosen based on the value of stat_cont and 
                  stat_d (see below). Alternatively, the statistics for each 
                  variable can be provided manually. The chosen statistics must 
                  be compatible with the variable type of the variable, see 
                  stat_cont and stat_d for possible values (see examples). 
                  If var_stats is used manually, use stat_d to control the 
                  statistics for the calculated "__n" variable.
stats_cont:       Statistics to calculate for continuous variables.
                  - Median (Q1-Q3): stat_cont = median_q1q3 (default)
                  - Mean (standard error): stat_cont = mean_stderr. 
stats_d:          Statistics to calculate for dichotomous and categorical 
                  variables:
                  - N (%): stats_d = n_pct (default)
                  - % (N): stats_d = pct_n 
                  Note: Can also be used to manually control the statistics to 
                  use for the calculated "__n" variable, when var_stats is 
                  manually specified.
weight:           Variable with observation weights. Default is weight = null, 
                  eg no weights used.
cat_groups_max:   If var_types = auto then cat_groups_max specify the maximum
                  number of distinct values a numerical categorical variable 
                  can take before being deemed a continuous variable. See 
                  var_types documentation. Default is cat_groups_max = 20. 
decimals_d:       Decimals to show for n statistics. Default is decimal_d = 0.
decimals_cont:    Decimals to show for median/mean/stedrr/Q1/Q3 statistics.
                  Default is decimal_cont = 1.
decimals_pct:     Decimals to show for percentages. Default is decimal_pct = 1.
decimal_mark:     Symbol used as decimal separator:
                  - ".": decimal_mark = point (default)
                  - ",": decimal_mark = comma
                  - " ": demimal_mark = space
big_mark:         Symbol used as digit group separator:
                  - ".": big_mark = point
                  - ",": big_mark = comma (default)
                  - " ": big_mark = space
                  - "":  big_mark = remove
overall_pos:      Position of overall stratas in output:
                  - First: overall_pos = first (default)
                  - Last:  overall_pos = last 
add_pct_symbol:   Add percentage symbols in percentage statistics: 
                  - Yes: inc_pct_symbol = y
                  - No:  inc_pct_symbol = n (default)
add_num_comp:     Add numeric variables to output with each component of the
                  statistics:
                  - Yes: add_num_comp = y (default)
                  - No:  add_num_comp = n
report_dummy:     Include variable "__report_dummy" intented to be used to 
                  finalize tables with proc report (see examples):
                  - Yes: inc_report_dummy = y (default)
                  - No:  inc_report_dummy = n
allow_d_miss:     Allow dichotomous variables to have missing values: 
                  - Yes: allow_d_miss = y
                  - No:  allow_d_miss = n (default)
                  Note that if allow_d_miss = y missing observations are 
                  still included in percentages calculations.
allow_cont_miss:  Allow continuous variables to have missing values:
                  - Yes: allow_d_miss = y
                  - No:  allow_d_miss = n (default)
print:            Print macro variable values during execution of macro:
                  - Yes: print_mv = y
                  - No:  print_mv = n (default)
del:              Delete intermediate datasets created by the macro:
                  - Yes: del = y (default)
                  - no:  del = n 
******************************************************************************/
%macro descriptive_summary(
  in_ds           = ,
  out_ds          = ,
  var_list        = ,
  by              = null,
  strata          = null,
  where           = %str(),
  var_types       = auto,
  var_stats       = auto,
  stats_cont      = median_q1q3,
  stats_d         = n_pct,
  weight          = null,
  cat_groups_max  = 20,
  decimals_d      = 0,
  decimals_cont   = 1,
  decimals_pct    = 1,
  decimal_mark    = point,
  big_mark        = comma,
  overall_pos     = first,
  add_pct_symbol  = n,
  add_num_comp    = y,
  report_dummy    = y,
  allow_d_miss    = n,
  allow_cont_miss = n,
  print           = n,
  del             = y
) / minoperator mindelimiter = ' ';


/*******************************************************************************
INPUT PARAMETER CHECKS 
*******************************************************************************/
%local  vars i i_var ds_id rc cnt j j_var weight_vt;

/* Check that none of the macro parameters (except possibly where) are empty. */
%let vars =  
  in_ds out_ds var_list by strata var_types var_stats stats_cont stats_d weight          
  cat_groups_max decimals_d decimals_cont decimals_pct decimal_mark big_mark        
  add_pct_symbol add_num_comp report_dummy allow_d_miss allow_cont_miss 
  overall_pos print del;   
 
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %if %sysevalf(&&&i_var = ) %then %do;
  %put ERROR: Macro parameter "&i_var" not specified!;
  %goto end_of_macro;    
  %end;
%end;
 
/* Remove single and double quotes from macro parameters where they are not 
supposed to be used, but might have been used anyway, ie all macro parameters
except for where */
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %if (&i_var in where in_ds out_ds) = 0 %then %do;
    %let &i_var = %sysfunc(tranwrd(&&&i_var, %nrstr(%"), %str( )));
    %let &i_var = %sysfunc(tranwrd(&&&i_var, %nrstr(%'), %str( )));
  %end;
%end;

/* Make sure all relevant macro parameters are in lowercase. */
%let vars =  
  var_types var_stats stats_cont stats_d decimal_mark big_mark        
  add_pct_symbol add_num_comp report_dummy allow_d_miss allow_cont_miss 
  overall_pos print del;   

%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %let &i_var = %lowcase(&&&i_var);
%end;


/*** in_ds checks ***/

/* Load first observation of input dataset and use this dataset for the 
following checks. This is done to avoid errors/warnings when the input dataset 
is given as a filepath, while at the same time giving meaningful errors in the 
log, that results in the macro being terminated. */
data __ds_in_ds_obs;
  set &in_ds(obs = 1);
run;

/* Check input dataset exists. */
%if %sysfunc(exist(__ds_in_ds_obs)) = 0 %then %do;
  %put ERROR: Specified input dataset (in_ds = &in_ds) does not exist or is empty!;
  %goto end_of_macro;
%end;

/* Check input dataset is not empty. */
%let ds_id = %sysfunc(open(__ds_in_ds_obs));
%if  %sysfunc(attrn(&ds_id, nobs)) = 0 %then %do;
  %let rc = %sysfunc(close(&ds_id));
  %put ERROR: Input dataset (in_ds = &in_ds) does not exist or is empty!;
  %goto end_of_macro;
%end;
%let rc = %sysfunc(close(&ds_id));

/* Check that none of the specified variables has a "__" prefix. Note
that "dummy_var" has been included in %qsubstr call so that the scenario
of one variable with a very short name can be handles correctly. */
%let vars = var_list strata by weight;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %do j = 1 %to %sysfunc(countw(&&&i_var, %str( )));
    %let j_var = %scan(&&&i_var, &j, %str( ));
    %if %eval(%qsubstr(&j_var dummy_var, 1, 2) = __) %then %do;
      %put ERROR: "&i_var" contains variable "&j_var" with a "__" prefix:;
      %put ERROR: This is not allowed to make sure that input variables are not;
      %put ERROR: overwritten by temporary variables created by the macro!;
      %goto end_of_macro; 
    %end;
  %end;
%end; /* End of i-loop */


/*** "var_list" checks ***/

/* Check variables specified in var_list exists in input dataset. */
%let ds_id = %sysfunc(open(__ds_in_ds_obs));
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var = %scan(&var_list, &i, %str( ));
  %if %sysfunc(nvalid(&i_var)) = 0 %then %do;
    %let rc = %sysfunc(close(&ds_id));
    %put ERROR: Variable name "&i_var" specified in;
    %put ERROR: var_list = &var_list;
    %put ERROR: is not a valid SAS variable name!;
    %goto end_of_macro;
  %end;
  %if %sysfunc(varnum(&ds_id, &i_var)) = 0 %then %do;
    %let rc = %sysfunc(close(&ds_id));
    %put ERROR: Variable "&i_var" specified in;
    %put ERROR: var_list = &var_list;
    %put ERROR: does not exist in the input dataset "in_ds = &in_ds"!;
    %goto end_of_macro; 
  %end;
%end;
%let rc = %sysfunc(close(&ds_id));

/* Check that there are no duplicates in "var_list" */
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var = %scan(&var_list, &i, %str( ));
  %let cnt = 0;
  %do j = 1 %to %sysfunc(countw(&var_list, %str( )));
    %if &i_var = %scan(&var_list, &j, %str( )) 
      %then %let cnt = %eval(&cnt + 1);
  %end;
  %if %sysevalf(&cnt > 1) %then %do;
    %put ERROR: Variable "&i_var" is included multiple times in;
    %put ERROR: var_list = &var_list!;
    %goto end_of_macro;
  %end;
%end;

/*** "by" checks ***/

/* Check by variables have valid names and exists in input dataset */
%if %lowcase(&by) ne null %then %do;
  %let ds_id = %sysfunc(open(&in_ds));
  %do i = 1 %to %sysfunc(countw(&by, %str( )));
    %let i_var = %scan(&by, &i, %str( ));
    %if %sysfunc(nvalid(&i_var)) = 0 %then %do;
      %let rc = %sysfunc(close(&ds_id));
      %put ERROR: Variable name "&i_var" specified in "by = &by";
      %put ERROR: is not a valid SAS variable name!;
      %goto end_of_macro;
    %end;
    %if %sysfunc(varnum(&ds_id, &i_var)) = 0 %then %do;
      %put ERROR: Variable "&i_var" specified in "by = &by" does not exist!;
      %let rc = %sysfunc(close(&ds_id));
      %goto end_of_macro; 
    %end;
  %end;
  %let rc = %sysfunc(close(&ds_id));
%end;

/* Check that there are no duplicates in by */
%do i = 1 %to %sysfunc(countw(&by, %str( )));
  %let i_var = %scan(&by, &i, %str( ));
  %let cnt = 0;
  %do j = 1 %to %sysfunc(countw(&by, %str( )));
    %if &i_var = %scan(&by, &j, %str( )) 
      %then %let cnt = %eval(&cnt + 1);
  %end;
  %if %sysevalf(&cnt > 1) %then %do;
    %put ERROR: Variable "&i_var" is included multiple times in "by = &by"!;
    %goto end_of_macro;
  %end;
%end;

/* Make sure "strata" variable is not included in "by". This would not be 
possible since the macro would try to produce an output dataset with multiple 
columns with the same name. */
%if %lowcase(&strata) ne null %then %do;
  %if &strata in &by %then %do;
    %put ERROR: The specified variable "strata = &strata";
    %put ERROR: is also included in "by = &by";
    %put ERROR: This is not allowed!;
    %goto end_of_macro;
  %end;
%end;


/*** "strata" checks ***/

/* Check only one variable in "strata". */
%if %eval(%sysfunc(countw(&strata, %str( ))) > 1) %then %do;
  %put ERROR: Only one variable can be specified in "strata = &strata"!;
  %goto end_of_macro; 
%end;

/* Check "strata" variable exists in input data. */
%if %lowcase(&strata) ne null %then %do;
  %if %sysfunc(nvalid(&strata)) = 0 %then %do;
    %put ERROR: Variable name specified in "strata = &strata";
    %put ERROR: is not a valid SAS variable name!;
    %goto end_of_macro;
  %end;
  %let ds_id = %sysfunc(open(&in_ds));
  %if %sysfunc(varnum(&ds_id, &strata)) = 0 %then %do;
    %let rc = %sysfunc(close(&ds_id));
    %put ERROR: Variable specified in "strata = &strata" does;
    %put ERROR: not exist in the input dataset "in_ds = &in_ds"!;
    %goto end_of_macro; 
  %end;
  %let rc = %sysfunc(close(&ds_id));
%end;


/*** "var_types" checks ***/

/* Check manually specified variable types are valid */
%if &var_types ne auto %then %do;
  %do i = 1 %to %sysfunc(countw(&var_types, %str( )));
    %let i_var = %scan(&var_types, &i, %str( ));
    %if %eval(&i_var in d cat cont) = 0 %then %do;
      %put ERROR: "var_types = &var_types";
      %put ERROR: contains invalid value "&i_var";
      %goto end_of_macro; 
    %end;
  %end;
%end;

/* If variable types have been specified manually, check that the number of 
manually specified variable types matches the number of variables in 
"var_list". */
%if &var_types ne auto %then %do;
  %if %sysfunc(countw(&var_types, %str( ))) ne 
      %sysfunc(countw(&var_list, %str( ))) %then %do;
    %put ERROR: Then number of variables in "var_types" (%sysfunc(countw(&var_types, %str( ))));
    %put ERROR: does not match the number of variables in "var_list" (%sysfunc(countw(&var_list, %str( ))))!;
    %goto end_of_macro; 
  %end;
%end;


/*** "var_stats" checks ***/

/* Check manually specified variable types are valid. */
%if &var_stats ne auto %then %do;
  %do i = 1 %to %sysfunc(countw(&var_stats, %str( )));
    %let i_var = %scan(&var_stats, &i, %str( ));
    %if %eval(&i_var in n_pct pct_n median_q1q3 mean_stderr) = 0 %then %do;
      %put ERROR: "var_stats = &var_stats";
      %put ERROR: contains invalid value "&i_var";
      %goto end_of_macro; 
    %end;
  %end;
%end;

/* If variable statistics have been specified manually, check that the number
of manually specified variable statistics matches the number of variables in 
"var_list". */
%if &var_stats ne auto %then %do;
  %if %sysfunc(countw(&var_stats, %str( ))) ne 
      %sysfunc(countw(&var_list, %str( ))) %then %do;
    %put ERROR: Then number of variables in "var_stats" (%sysfunc(countw(&var_stats, %str( ))));
    %put ERROR: does not match the number of variables in "var_list" (%sysfunc(countw(&var_list, %str( ))))!;
    %goto end_of_macro; 
  %end;
%end;


/*** "stats_cont" checks ***/

/* Check that "stats_cont" has a valid value. */
%if %eval(&stats_cont in median_q1q3 mean_stderr) = 0  %then %do;
  %put ERROR: "stats_cont" has invalid value  "&stats_cont";
  %goto end_of_macro; 
%end;


/*** "stats_d" checks ***/

/* Check that "stats_d" has a valid value. */
%if %eval(&stats_d in n_pct pct_n) = 0  %then %do;
  %put ERROR: "stats_d" has invalid value  "&stats_d";
  %goto end_of_macro; 
%end;


/*** "weight" checks ***/

/* Check only one variable specified in "weight". */
%if %eval(%sysfunc(countw(&weight, %str( ))) > 1) %then %do;
  %put ERROR: Only one variable can be specified in "weight = &weight"!;
  %goto end_of_macro; 
%end;

/* Check "weight" variable exists in input data. */
%if %lowcase(&weight) ne null %then %do;
  %if %sysfunc(nvalid(&weight)) = 0 %then %do;
    %put ERROR: Variable name specified in "weight = &weight";
    %put ERROR: is not a valid SAS variable name!;
    %goto end_of_macro;
  %end;
  %let ds_id = %sysfunc(open(&in_ds));
  %if %sysfunc(varnum(&ds_id, &weight)) = 0 %then %do;
    %let rc = %sysfunc(close(&ds_id));
    %put ERROR: Variable specified in "weight = &weight" does;
    %put ERROR: not exist in the input dataset "in_ds = &in_ds"!;
    %goto end_of_macro; 
  %end;
  %let rc = %sysfunc(close(&ds_id));
%end;

/* Check that if a "weight" variable is specifed, that the variable
is numeric. */
%if %lowcase(&weight) ne null %then %do;
  data _null_;
    set __ds_in_ds_obs;
    call symput("weight_vt", vtype(&weight));  
  run;

  %if &weight_vt ne N %then %do;
    %put ERROR: The variable specified in "weight = &weight" is not numeric!;
    %goto end_of_macro;
  %end;
%end;

/*** "cat_groups_max" checks ***/

/* Check that "cat_groups_max" is specified as a positive integer.
Regular expression: Starts with a number 1-9, followed by, and ends with,
one or more digits (so that eg. 0 is not allowed, but 10 is)*/
%if %sysfunc(prxmatch('^[1-9]\d*$', &cat_groups_max)) = 0 %then %do;
  %put ERROR: "cat_groups_max" must be a positive integer!;
  %goto end_of_macro; 
%end;


/*** "decimals_d", "decimals_cont", and "decimals_pct" checks ***/

/* Check that the parameters specifying how many decimals to display are
corrrectly given as non-negative integers */
%if %sysfunc(prxmatch('^\d+$', &decimals_d)) = 0 %then %do;
  %put ERROR: "decimals_d" must be a non-negative integer!;
  %goto end_of_macro; 
%end;
%if %sysfunc(prxmatch('^\d+$', &decimals_cont)) = 0 %then %do;
  %put ERROR: "decimals_cont" must be a non-negative integer!;
  %goto end_of_macro; 
%end;
%if %sysfunc(prxmatch('^\d+$', &decimals_pct)) = 0 %then %do;
  %put ERROR: "decimals_pct" must be a non-negative integer!;
  %goto end_of_macro; 
%end;


/*** "decimal_mark" and "big_mark" checks ***/

/* Check that "decimal_mark" and "big_mark" has valid values. */
%if ^(&decimal_mark in point comma space) %then %do;
  %put ERROR: "decimal_mark" does not have a valid value!;
  %goto end_of_macro;  
%end;
%if ^(&big_mark in point comma space remove) %then %do;
  %put ERROR: "big_mark" does not have a valid value!;
  %goto end_of_macro;  
%end;


/*** "overall_pos" checks ***/

/* Check that "overall_pos" has a valid value. */
%if %eval(&overall_pos in first last) = 0 %then %do;
  %put ERROR: "overall_pos" does not have a valid value!;
  %goto end_of_macro; 
%end;


/*** "add_pct_symbol", "add_num_comp", "report_dummy", "allow_d_miss",    
"allow_cont_miss", "print", and "del"  checks ***/

/* Check that y/n macro parameters are specified correctly */
%let vars = 
  add_pct_symbol add_num_comp report_dummy allow_d_miss   
  allow_cont_miss print del;            

%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %if %eval(&&&i_var in n y) = 0 %then %do;
    %put ERROR: "&i_var" does not have a valid value!;
    %goto end_of_macro;
  %end;
%end;


/*******************************************************************************
LOAD AND RESTRICT INPUT DATA
*******************************************************************************/
%local strata_nmiss weight_nmiss weight_min;

/* To avoid problem with proc sql when strata = case, we rename the strata
variable here, and restore the name in the end. See issue #40.*/
data __ds_data1(rename = (&strata = __strata_tmp));
  set &in_ds;
  where &where;
run;
%local strata_ori;
%let strata_ori = &strata;
%let strata = __strata_tmp;

%if &syserr ne 0 %then %do;
  %put ERROR- The specified "where" condition:;
  %put ERROR- "where = &where";
  %put ERROR- produced a warning or an error. Macro terminated!;
  %goto end_of_macro; 
%end;

/* Check that the specified "strata" and "weight" variable does not contain 
missing values / empty strings, and that "weight" does not contain negative 
number . */
%if %sysevalf(%lowcase(&strata) ne null or %lowcase(&weight) ne null) %then %do;
  proc sql noprint;
    select  %if %lowcase(&strata) ne null %then %do; nmiss(&strata) %end;
            %if %lowcase(&weight) ne null %then %do;
            %if %lowcase(&weight) ne null and %lowcase(&strata) ne null %then %do; , %end;
            nmiss(&weight), 
            min(&weight)
            %end;
      into  %if %lowcase(&strata) ne null %then %do; :strata_nmiss %end;
            %if %lowcase(&weight) ne null %then %do;
            %if %lowcase(&weight) ne null and %lowcase(&strata) ne null %then %do; , %end;
            :weight_nmiss, 
            :weight_min
            %end;
      from __ds_data1(keep = 
        %if %lowcase(&strata) ne null %then %do; &strata %end;
        %if %lowcase(&weight) ne null %then %do; &weight %end;
        );
  quit;

  %if  &strata_nmiss > 0 %then %do;
    %put ERROR: The specified "strata" variable "&strata" contains missing values / empty strings!;
    %goto end_of_macro;
  %end;
  %if %lowcase(&weight) ne null %then %do;
    %if  &weight_nmiss > 0 %then %do;
      %put ERROR: The specified "weight" variable "&weight" contains missing values!;
      %goto end_of_macro;
    %end;
    %if %sysevalf(&weight_min < 0) %then %do;
      %put ERROR: The specified "weight" variable "&weight" contains one or more negative weights!;
      %goto end_of_macro;      
    %end;
  %end;
%end;

/*******************************************************************************
RENAME VARIABLES
*******************************************************************************/
%local i var_list_input by_input i_var;

/* To ensure that long variable names can be handled, we rename all variables
specified in the macro parameters. If no strata and/or by variables are given, 
we created dummy variables to facilitate the analyses. The original variable
names are substituted back into the output table later on. */

/* Save the input values of macro parameters. */
%let var_list_input = &var_list;
%let by_input = &by;

/* Replace with the new variables that are going to be created. */
%let var_list = ;
%do i = 1 %to %sysfunc(countw(&var_list_input, %str( )));
  %let var_list = &var_list __var_&i;
%end;

%let by = ;
%do i = 1 %to %sysfunc(countw(&by_input, %str( )));
  %let by = &by __by_&i;
%end;

data __ds_data2(keep = __:);
set  __ds_data1;
  /* Rename "var_list" variables. */
  %do i = 1 %to %sysfunc(countw(&var_list_input, %str( )));
    %let i_var = %scan(&var_list_input, &i, %str( ));
    rename &i_var = __var_&i;
  %end;
  /* Create/rename new "strata" variable. */
  %if %lowcase(&strata) ne null %then %do;
    rename &strata = __strata;
  %end;
  %else %do;
    __strata = "null";
  %end;
  /* Create/rename "weight" variable */
  %if %lowcase(&weight) ne null %then %do;
    rename &weight = __w;
  %end;
  %else %do;
    __w = 1;
  %end;
  /* Add __n variable to data */
  __n = 1;
  /* Rename/create "by" variables */
  %if %lowcase(&by_input) ne null %then %do;
    %do i = 1 %to %sysfunc(countw(&by_input, %str( )));
      %let i_var = %scan(&by_input, &i, %str( ));
      __by_&i = &i_var;
    %end;
  %end;
  %else %do;
    __by_1 = "null";
  %end;
run;

%if &print = y %then %do;
  %put WARNING- "var_list" input:;
  %put var_list_input: &var_list_input;
  %put WARNING- "var_list" after renaming variables:;
  %put var_list: &var_list;
  %put WARNING- "by" input:;
  %put by_input: &by_input;
  %put WARNING- "by" after renaming variables:;
  %put by: &by;
%end;


/******************************************************************************
FIND VARIABLE INFO
******************************************************************************/
%local i i_var i_type i_stat;

/*** Find information on the variables specified in "var_list". ***/
proc sql;
  create table __ds_info1 as
    select
      %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
        %let i_var = %scan(&var_list, &i, %str( ));
        count(distinct(&i_var)) as &i_var._nvalues,
        nmiss(&i_var) as &i_var._nmiss,
        min(&i_var) as &i_var._min,
        max(&i_var) as &i_var._max,
      %end;
      1 as __merge
      from __ds_data2;
quit;

data __ds_info2;
set __ds_data2(obs = 1);
  %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
    %let i_var = %scan(&var_list, &i, %str( ));
    &i_var._vt = vtype(&i_var);
    keep &i_var._vt;
  %end;
  __merge = 1;
  keep __merge;
run;

data __ds_info3; 
  merge __ds_info1 __ds_info2;
  by __merge;
run;

/*** Determine variable types ***/
data __ds_info4; 
  set __ds_info3;
  %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
    %let i_var = %scan(&var_list, &i, %str( ));
    format &i_var._type $4.;
    /*** Automatic ***/
    %if &var_types = auto %then %do;
      /* If the variable is character, we will assume it is a categorical
      variable. */
      if &i_var._vt = "C" then &i_var._type = "cat";
      /* Else, if the variable takes numeric values: */
      else do;
        /* If the variable only takes the values zero and/or one (besides 
        missing values) then we will assume it's dichotomous. */
        if 1 <= &i_var._nvalues <= 2 and cats(&i_var._min) in ("0" "1") 
          and cats(&i_var._max) in ("0" "1") then &i_var._type = "d";  
        /* Else, if the number of distinct values of the variable is less than 
        or equal to what is specified in &cat_groups_max, then we will assume 
        that the variable is categorical. */
        else if &i_var._nvalues <= &cat_groups_max
          then &i_var._type = "cat"; 
        /* Else we assume the variable is continuous. */
        else &i_var._type = "cont";
      end;
    %end;
    /*** Manual ***/
    %else %do;
      %let i_type = %scan(&var_types, &i, %str( ));
      &i_var._type = "&i_type";
    %end;

    /* Correction of nvalues if there are categorical variables
    with empty string values. */
    if &i_var._type = "cat" and &i_var._nmiss > 0 
        then &i_var._nvalues = &i_var._nvalues + 1; 
  %end;
run;

%if &print = y %then %do;
  %put WARNING- "var_types" before auto determine:;
  %put var_types: &var_types;
%end;

/* If "var_types = auto" we update the macro variable to include
the automatically determined variable types. */
%if &var_types = auto %then %do;
  %let var_types = ;
  %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
    %let i_var = %scan(&var_list, &i, %str( ));
    proc sql noprint;
      select &i_var._type into :i_type
        from __ds_info4;
    quit;
    %let var_types = &var_types &i_type;
  %end;
%end;

%if &print = y %then %do;
  %put WARNING- "var_types" after auto determine:;
  %put var_types: &var_types;
%end;

/*** Determine variable statistics ***/
data __ds_info5; 
  set __ds_info4;
  %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
    %let i_var = %scan(&var_list, &i, %str( ));
    format &i_var._stat $20.;
    /*** Automatic ***/
    %if &var_stats = auto %then %do;
      if &i_var._type = "cont" then &i_var._stat = "&stats_cont";
      else if &i_var._type in ("d" "cat") 
        then &i_var._stat = "&stats_d";
    %end;
    /*** Manual ***/
    %else %do;
      %let i_stat = %scan(&var_stats, &i, %str( ));
      &i_var._stat = "&i_stat";
    %end; 
  %end;
run;

%if &print = y %then %do;
  %put WARNING- "var_stats" before auto determine:;
  %put var_stats: &var_stats;
%end;

/* If "var_stats = auto" we update the macro variable to include
the automatically determined variable statistics. */
%if &var_stats = auto %then %do;
  %let var_stats = ;
  %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
    %let i_var = %scan(&var_list, &i, %str( ));
    proc sql noprint;
      select &i_var._stat into :i_stat
        from __ds_info5;
    quit;
    %let var_stats = &var_stats &i_stat;
  %end;
%end;


%if &print = y %then %do;
  %put WARNING- "var_stats" after auto determine:;
  %put var_stats: &var_stats;
%end;


/******************************************************************************
FURTHER CHECKS 
******************************************************************************/
%local i i_var i_var_input i_type i_vt i_nvalues i_min i_max i_var_nmiss i_stat;

/* Check that the variable types are compatible with the variable data */
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var = %scan(&var_list, &i, %str( ));
  %let i_var_input = %scan(&var_list_input, &i, %str( ));
  %let i_type = %scan(&var_types, &i, %str( ));
  proc sql noprint;
    select  &i_var._vt, 
            &i_var._nvalues,
            &i_var._min, 
            &i_var._max 
    into    :i_vt,
            :i_nvalues,
            :i_min,
            :i_max
    from __ds_info5;
  quit;

  /* Dichotomous: variable needs to be numeric and only take
  zero and/or one values */
  %if &i_type = d %then %do;
    %if %eval(
        &i_vt ne N or
        %sysfunc(prxmatch("^1$|^2$", &i_nvalues)) = 0 or
        %sysfunc(prxmatch("^0$|^1$", &i_min)) = 0 or
        %sysfunc(prxmatch("^0$|^1$", &i_max)) = 0
      ) %then %do;
      %put ERROR: The "var_list" variable "&i_var_input" is specified to be a;
      %put ERROR: dichotomous variable but does not fullfill the requirements;
      %put ERROR: of being a numeric variable with zero and/or one values.;
      %goto end_of_macro;    
    %end;
  %end;
  /* Categorical: No checks needed. */
  /* Continuous: variable must be numeric. */
  %if &i_type = cont %then %do;
    %if &i_vt ne N %then %do;
      %put ERROR: The "var_list" variable "&i_var_input" is specified to be a;
      %put ERROR: continuous variable but does not fullfill the requirements;
      %put ERROR: of being a numerical variable.;
      %goto end_of_macro;        
    %end;
  %end;
%end;

/* Depending on the values of "allow_d_miss" and "allow_cont_miss", 
terminate the macro with an error if any of the dichotomous and/or 
continuous variables have missing values. */
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var = %scan(&var_list, &i, %str( ));
  %let i_var_input = %scan(&var_list_input, &i, %str( ));
  %let i_type = %scan(&var_types, &i, %str( ));
  data _null_;
    set __ds_info4;
    call symput("i_var_nmiss", put(&i_var._nmiss, 20.));
  run;

  %if %sysevalf(&allow_d_miss = n and &i_type = d and &i_var_nmiss > 0) %then %do;
    %put ERROR: Dichotomous variable "&i_var_input" in;
    %put ERROR: "var_list = &var_list_input";
    %put ERROR: contains one or more missing values!;
    %goto end_of_macro;    
  %end;
  %if %sysevalf(&allow_cont_miss = n and &i_type = cont and &i_var_nmiss > 0) %then %do;
    %put ERROR: Continuous variable "&i_var_input" in;
    %put ERROR: "var_list = &var_list_input";
    %put ERROR: contains one or more missing values!;
    %goto end_of_macro;    
  %end;
%end; /* End of i-loop */

/* Check that the variable statistics are compatible with the variable
types */
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var = %scan(&var_list, &i, %str( ));
  %let i_var_input = %scan(&var_list_input, &i, %str( ));
  %let i_type = %scan(&var_types, &i, %str( ));
  %let i_stat = %scan(&var_stats, &i, %str( ));
  proc sql noprint;
    select  &i_var._type, 
            &i_var._stat
    into    :i_type,
            :i_stat
    from __ds_info5;
  quit;

  %if %sysevalf(
    (
      (&i_type = d or &i_type = cat) and ^(&i_stat = n_pct  or &i_stat = pct_n))
      or
      (&i_type = cont and ^(&i_stat = median_q1q3 or &i_stat = mean_stderr))
    ) %then %do;
    %put ERROR: The "var_list" variable "&i_var_input" has;
    %put ERROR: type "%sysfunc(compress(&i_type))" and stat "%sysfunc(compress(&i_stat))", which is not compatible!;
    %goto end_of_macro;    
  %end;
%end; /* End of i-loop */


/******************************************************************************
MAKE NUMERIC VERSIONS OF CATEGORICAL VARIABLES
******************************************************************************/
%local i var_list_temp i i_type i_temp i_var_input;

/* To facilitate the handling of categorical variables, we will make new
versions with numerical values. */
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var_input = %scan(&var_list_input, &i, %str( ));
  %let i_type = %scan(&var_types, &i, %str( ));
  %if &i_type = cat %then %do;

    proc sort data = __ds_data2(keep = __var_&i) 
        out = __ds_labels_cat_var_&i nodupkeys;
      by __var_&i;
    run;

    /* Find unique values and make corresponding numeric values */
    data __ds_labels_cat_var_&i;
      set __ds_labels_cat_var_&i;
      if _n_ = 1 then __cat_var_&i = 0;
      __cat_var_&i + 1;
    run;

    /* Make new numeric version */
    proc sort data = __ds_data2;
      by __var_&i;
    run;

    data __ds_data2;
      merge __ds_data2 __ds_labels_cat_var_&i;
      by __var_&i;
      drop __var_&i;
    run;

    /* Add title line and labels for the categorical values to be 
    include with labels for the other variables later. */
    data __ds_labels_cat_var_&i;
      set __ds_labels_cat_var_&i;
      format __var __label __var_input $500.;
       if _n_ = 1 then do;
        __var = "__cat_var_&i._title";
        __label = "&i_var_input: title";
        __var_input = "&i_var_input";
        output;
      end;
      __var = "__cat_var_&i" || "_" || cats(__cat_var_&i);
      __label = "&i_var_input: " || cats(__var_&i);
      __var_input = "&i_var_input";
      output;
      keep __var __label __var_input;
    run;
  %end;
%end;

/* Update "var_list" macro variable */
%if &print = y %then %do;
  %put WARNING- "var_list" before new categorial variable names:;
  %put var_list: &var_list;
%end;

%let var_list_temp = &var_list;
%let var_list = ;
%do i = 1 %to %sysfunc(countw(&var_types, %str( )));
  %let i_type = %scan(&var_types, &i, %str( ));
  %let i_temp = %scan(&var_list_temp, &i, %str( ));
  %let i_var_input = %scan(&var_list_input, &i, %str( ));
  %if &i_type = cat %then %do; 
    %let var_list = &var_list __cat_var_&i;
  %end;
  %else %do;
    %let var_list = &var_list &i_temp;
  %end;
%end;

%if &print = y %then %do;
  %put WARNING- "var_list" after new categorial variable names:;
  %put var_list: &var_list;
%end;


/******************************************************************************
MAKE LABELS FOR OUTPUT TABLE
******************************************************************************/
%local i i_type i_var_input;

/* Create an empty dataset so that the set-statement below also works
when there are no categorical variables and associated labels. */
data __ds_dummy;
  format __var __label __var_input $500.;
  call missing(__var, __label, __var_input);
run;

/* Combine labels for categorical variables and add labels for the 
remaining variables. */
data __ds_labels1(where = (__var ne ""));
  set __ds_dummy
  %do i = 1 %to %sysfunc(countw(&var_types, %str( )));
    %let i_type = %scan(&var_types, &i, %str( ));
    %if &i_type = cat %then %do; 
      __ds_labels_cat_var_&i
    %end;
  %end;
  ;
  output;
  if _n_ = 1 then do;
    __var = "__n";
    __label = "__n";
    __var_input = "__n";
    output;
    %do i = 1 %to %sysfunc(countw(&var_types, %str( )));
      %let i_type = %scan(&var_types, &i, %str( ));
      %let i_var_input = %scan(&var_list_input, &i, %str( ));
      %if &i_type ne cat %then %do; 
        __var = "__var_&i";
        __label = "&i_var_input";
        __var_input = "&i_var_input";
        output;
      %end;
    %end;
  end;
run;


/******************************************************************************
MAKE INDICATOR VARIABLES FOR CATEGORICAL VARIABLES
******************************************************************************/
%local n_values i i_var i_type i_n_values j
       var_list_temp var_types_temp var_stats_temp
       i_var_list_temp i_var_types_temp i_var_stats_temp;

/* If "var_list" contains categorical variables we replace each of them with a
set of dichotomous indicator variables to facilite the analyses. */

/* Make macro variable with the number of distinct values for 
each categorical variable, inserting dummy values for other variables. */
%let n_values = ;
%do i = 1 %to %sysfunc(countw(&var_types, %str( )));
  %let i_type = %scan(&var_types, &i, %str( ));
  %if &i_type = cat %then %do;
    proc sql noprint;
      select __var_&i._nvalues into :i_n_values
        from __ds_info5;
    quit;
  %end;
  %else %do;
    %let i_n_values = dummy;
  %end;
  %let n_values = &n_values &i_n_values;
%end; /* End of i-loop */

%if &print = y %then %do;
  %put WARNING- Number of distinct values for each (categorical) variable;
  %put n_values: &n_values;
%end;

/* Replace each categorical variable with a set of dichotomous variables,
including a dummy variable for the title */
data __ds_data3;
  set __ds_data2;
  %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
    %let i_var = %scan(&var_list, &i, %str( ));
    %let i_type = %scan(&var_types, &i, %str( ));
    %let i_n_values = %scan(&n_values, &i, %str( ));
    %if &i_type = cat %then %do;
      __cat_var_&i._title = 1;
      %do j = 1 %to &i_n_values;
        __cat_var_&i._&j = (__cat_var_&i. = &j.);
      %end;
      drop &i_var;
    %end;
  %end; /* End of i-loop */
run;

/* Update macro parameters. */ 
%if &print = y %then %do;
  %put WARNING- Macro variables before categorical variables replaced:;
  %put var_list: &var_list;
  %put var_types: &var_types;
  %put var_stats: &var_stats;
%end;

%let var_list_temp  = &var_list;
%let var_types_temp = &var_types;
%let var_stats_temp = &var_stats;
%let var_list = ;
%let var_types = ;
%let var_stats = ;

%do i = 1 %to %sysfunc(countw(&var_list_temp, %str( )));
  %let i_var_list_temp = %scan(&var_list_temp, &i, %str( ));
  %let i_var_types_temp = %scan(&var_types_temp ,&i, %str( ));
  %let i_var_stats_temp = %scan(&var_stats_temp ,&i, %str( ));
  %let i_n_values = %scan(&n_values, &i, %str( ));

  %if &i_var_types_temp = cat %then %do;
    %let var_list = &var_list &i_var_list_temp._title;
    %let var_types = &var_types title;
    %let var_stats = &var_stats title;
    %do j = 1 %to &i_n_values;
      %let var_list = &var_list __cat_var_&i._&j;
      %let var_types = &var_types d;
      %let var_stats = &var_stats &i_var_stats_temp;
    %end;
  %end;
  %else %do;
    %let var_list = &var_list &i_var_list_temp;
    %let var_types = &var_types  &i_var_types_temp;
    %let var_stats = &var_stats  &i_var_stats_temp;
  %end;
%end; /* End of i-loop */

%if &print = y %then %do;
  %put WARNING- Macro variables after categorical variables replaced:;
  %put var_list: &var_list;
  %put var_types: &var_types;
  %put var_stats: &var_stats;
%end;


/******************************************************************************
SUMMARIZE DATA
******************************************************************************/
%local i i_var i_stat;
proc sort data = __ds_data3;
  by __by:;
run;

/* At this point we can add the created __n variable to the relavant macro 
paramters, using the value of "stats_d" in "var_stats". */

%if &print = y %then %do;
  %put WARNING- Macro parameters before adding __n variable;
  %put var_list: &var_list;
  %put var_types: &var_types;
  %put var_stats: &var_stats;
%end;

%let var_list = __n &var_list;
%let var_types = d &var_types;
%let var_stats = &stats_d &var_stats;

%if &print = y %then %do;
  %put WARNING- Macro parameters after adding __n variable;
  %put var_list: &var_list;
  %put var_types: &var_types;
  %put var_stats: &var_stats;
%end;

/* Summarize data. */
proc means data = __ds_data3 noprint vardef = df;
  by __by:;
  class __strata;
  var &var_list;
  weight __w;
  output out = __ds_data4(drop = _type_ _freq_)
    %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
      %let i_var = %scan(&var_list, &i, %str( ));
      %let i_stat = %scan(&var_stats, &i, %str( ));
      %if &i_stat in n_pct pct_n %then %do;
        sum(&i_var) = &i_var._sum
        mean(&i_var) = &i_var._mean
      %end;
      %else %if &i_stat = median_q1q3 %then %do;
        p25(&i_var) = &i_var._p25
        median(&i_var) = &i_var._median
        p75(&i_var) = &i_var._p75
      %end;
      %else %if &i_stat = mean_stderr %then %do;
        mean(&i_var) = &i_var._mean
        stddev(&i_var) = &i_var._stddev
      %end;
    %end;
    / noinherit;
  types () __strata;
run;

/* Retain __n_sum value for total number of observations in each strata of 
by-variables,  so that __n percentage stats can be calculated. */
data __ds_data5;
  set __ds_data4;
  by __by: __strata;
  retain __n_total;
  if first.%scan(&by, -1, %str( )) then do;
    __n_total = __n_sum;
  end;
run;

data __ds_data6;
  set __ds_data5;
  format __var __stat_char __percent_stat $500. 
         __stat_num1 __stat_num2 __stat_num3 best32.;
  %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
    %let i_var = %scan(&var_list, &i, %str( ));
    %let i_stat = %scan(&var_stats, &i, %str( ));
    __var = "&i_var";
    %if &i_var = __n %then %do;
    __n_var = __n_total;
    %end;
    %else %do;
      __n_var = __n_sum;
    %end;

    /* n_pct */
    %if &i_stat= n_pct %then %do;
      __stat_num1 = &i_var._sum;
      __stat_num2 = &i_var._sum / __n_var * 100;
      __stat_num3 = .;
      %if &add_pct_symbol = y %then %do;
        __percent_stat = compress(put(__stat_num2, 32.&decimals_pct)) || "%";
      %end;
      %else %do;
        __percent_stat = compress(put(__stat_num2, 32.&decimals_pct));
      %end;
      if __stat_num1 ne . and __stat_num2 ne . then 
        __stat_char = 
          compress(put(__stat_num1, comma32.&decimals_d)) || 
          " (" || 
          compress(__percent_stat) || 
          ")";
        else __stat_char = "n/a";
    %end;
    /* pct_n */
    %else %if &i_stat = pct_n %then %do;
      __stat_num1 = &i_var._sum / __n_var * 100;
      __stat_num2 = &i_var._sum;
      __stat_num3 = .;
      %if &add_pct_symbol = y %then %do;
        __percent_stat = compress(put(__stat_num1, 32.&decimals_pct)) || "%";
      %end;
      %else %do;
        __percent_stat = compress(put(__stat_num1, 32.&decimals_pct));
      %end;
      if __stat_num1 ne . and __stat_num2 ne . then
        __stat_char = 
          compress(__percent_stat) || 
          " (" || 
          compress(put(__stat_num2, comma32.&decimals_d)) || 
          ")";
        else __stat_char = "n/a";
    %end;
    /* median_q1q3 */
    %else %if &i_stat = median_q1q3 %then %do;
      __stat_num1 = &i_var._median;
      __stat_num2 = &i_var._p25;
      __stat_num3 = &i_var._p75;
      if __stat_num1 ne . and __stat_num2 ne . and __stat_num3 ne . then
        __stat_char = 
          compress(put(__stat_num1, comma32.&decimals_cont)) ||
          " (" || 
          compress(put(__stat_num2, comma32.&decimals_cont)) ||
          ";" || 
          compress(put(__stat_num3, comma32.&decimals_cont)) ||
          ")";
        else __stat_char = "n/a";
    %end;
    /* mean_stderr*/
    %else %if &i_stat = mean_stderr %then %do;
      __stat_num1 = &i_var._mean;
      __stat_num2 = &i_var._stddev;
      __stat_num3 = .;
      if __stat_num1 ne . and __stat_num2 ne . then 
        __stat_char = 
          compress(put(__stat_num1, comma32.&decimals_cont)) ||
          " (" ||
          compress(put(__stat_num2, comma32.&decimals_cont)) ||
          ")";
        else __stat_char = "n/a";
    %end;
    /* Titles */
    %else %if &i_stat = title %then %do;
      __stat_num1 = .;
      __stat_num2 = .;
      __stat_num3 = .;
      __stat_char = "";
    %end;
    output;
  %end; /* End of i-loop */
  keep __by: __strata __var __stat:;
run;


/******************************************************************************
SORT OVERALL STRATAS
******************************************************************************/

/* Sort data so that the overall stratas are either first or last in
each by-variable strata. */
data __ds_data7;
  set __ds_data6;
  by __by: __strata;
  retain __sort_strata __sort_var;
  if _n_ = 1 then __sort_strata = 0;
  if first.__strata then do;
    __sort_strata = __sort_strata + 1;
    __sort_var = 0;
  end;
  __sort_var + 1;
run;

data __ds_data8;
  set __ds_data7;
  %if &overall_pos = last %then %do;
    if missing(__strata) then __sort_strata = 10**6;
  %end;
run;

proc sort data = __ds_data8 out = __ds_data9(drop = __sort:);
  by  __by: __sort_strata __sort_var;
run;


/******************************************************************************
TRANSFORM DECIMAL / DIGIT GROUP SYMBOLS 
******************************************************************************/

data __ds_data10;
  set __ds_data9;
  __stat_char = tranwrd(__stat_char, ".", "#");
  __stat_char = tranwrd(__stat_char, ",", "@");

  %if &decimal_mark = point %then %do;
    __stat_char = tranwrd(__stat_char, "#", ".");
  %end;
  %else %if &decimal_mark = comma %then %do;
    __stat_char = tranwrd(__stat_char, "#", ",");
  %end;
  %else %if &decimal_mark = space %then %do;
    __stat_char = tranwrd(__stat_char, "#", " ");
  %end;
  %else %if &decimal_mark = remove %then %do;
    __stat_char = compress(__stat_char, "#", "");
  %end;

  %if &big_mark = point %then %do;
    __stat_char = tranwrd(__stat_char, "@", ".");
  %end;
  %else %if &big_mark = comma %then %do;
    __stat_char = tranwrd(__stat_char, "@", ",");
  %end;
  %else %if &big_mark = space %then %do;
    __stat_char = tranwrd(__stat_char, "@", " ");
  %end;
  %else %if &big_mark = remove %then %do;
    __stat_char = compress(__stat_char, "@", "");
  %end;

  /* We add a sorting variable so we can recreate the 
  current ordering of datalines after categorical variable
  labels have been merged to the data. */
  __sort_var = _n_;
run;


/******************************************************************************
FINALIZE OUTPUT
******************************************************************************/
%local i i_by label_max_length var_input_max_length stat_max_length;

/* Merge labels to the data */
proc sql;
  create table __ds_data11(drop = __var) as
    select a.*, b.__label, b.__var_input
      from __ds_data10 as a
      left join 
      __ds_labels1 as b
      on a.__var = b.__var
      order by a.__sort_var;
quit;

/* Determine the maximum length of created variables, so that these variables 
can be redefined with the appropriate length etc. */
proc sql noprint;
  select  max(length(__label)), 
          max(length(__var_input)), 
          max(length(__stat_char)) 
    into :label_max_length, :var_input_max_length, :stat_max_length
    from __ds_data11;
quit;

data &out_ds(rename = (__strata_tmp = &strata_ori));;
  /* Reorder columns so that "by" and "strata" variables are the left-most 
  columns. */
  retain
  %do i = 1 %to %sysfunc(countw(&by_input, %str( )));
    %let i_by = %scan(&by_input, &i, %str( ));
      __by_&i
  %end;
  __strata;
  length __var $&var_input_max_length
         __label $&label_max_length 
         __stat_char $&stat_max_length;
  set __ds_data11(rename = (
      __label = __temp_label
      __stat_char = __temp_stat_char
    ));

  __var = __var_input;
  __label = __temp_label;
  __stat_char = __temp_stat_char;

  /* If no "strata" variable was specified we remove the automatically 
  created overall strata datalines and the dummy strata variable. */
  %if %lowcase(&strata) = null %then %do;
    if missing(__strata) then delete;
    drop __strata;
  %end;
  %else %do;
    rename __strata = &strata;
  %end;
  /* If no "by" variables were given we delete the dummy by variable. */
  %if %lowcase(&by_input) = null %then %do;
    drop __by_1;
  %end;
  %else %do;
    %do i = 1 %to %sysfunc(countw(&by_input, %str( )));
      %let i_by = %scan(&by_input, &i, %str( ));
      rename __by_&i = &i_by;
    %end;
  %end;
  /* Drop numerical statistic variables if specified. */
  %if &add_num_comp = n %then %do;
    drop __stat_num:;
  %end;
  /* Add dummy variable if specified. */
  %if &report_dummy = y %then %do;
    __report_dummy = 1;
  %end;
  drop __temp_: __var_input __sort_var;
run;


%end_of_macro:

/* Delete temporary datasets created by the macro, also when 
"del" has not be specified as either y or n. */
%if &del ne n  %then %do;
  proc datasets nodetails nolist;
    delete __ds_:;
  run;
  quit;
%end; 

%mend descriptive_summary;

