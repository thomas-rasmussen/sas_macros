/*******************************************************************************
AUTHOR:     Thomas Bøjer Rasmussen
VERSION:    1.0.0
DATE:       2019-08-18
LICENCE:    Creative Commons CC0 1.0 Universal  
            (https://www.tldrlegal.com/l/cc0-1.0)
********************************************************************************
DESCRIPTION:
Produces a so-called "table 1" with summarized patient characteristics based 
on an input dataset with patient level obervations and a set of 
variables/patient characteristics. See the accompanying examples
for how the output dataset is intended to be used with proc report. 

Developed using SAS 9.4.

Find the newest version of the macro and accompanying examples at:
https://github.com/thomas-rasmussen/sas_macros

PARAMETERS:	
*** REQUIRED ***
in_ds:		          (libname.)member-name of input dataset with the population 
                    of interest. A filepath enclosed in quotes can also be used.
out_ds:		          (libname.)member-name of output dataset.
                    A filepath enclosed in quotes can also be used.
var_list:           List of patients characteristic variables. Variable
                    names needs to be separated by spaces " ". Variables with 
                    a double-underscore "__" prefix and variables named "n"
                    are not allowed.    
 
*** OPTIONAL ***
var_types:          List of variable types (dichotomous (d) / categorical (cat)
                    / continuous (cont)) corresponding to the variables
                    given in var_list. The types are automatically guessed
                    from the input data if the default value var_types = auto
                    is given. To manually overwrite this, use d/cat/cont to 
                    specify the types (in the same 
                    order as the variables are listed in var_list) and use 
                    spaces " " as the delimiter. The algorithm guessing
                    the types works as follows:
                    1) If character variable: categorical
                    2) Else, if numeric and one or two distinct values that
                       are zero and/or one: dichotomous
                    3) Else, if numeric and fewer than &cont_cutoff (see below)
                       distinct values: categorical.
                    4) Else: continuous.
group_var:          A grouping variable can be specified, so that the output
                    will contain summarized patients characteristics in stratas
                    of the values of group_var. Furthermore, a
                    total category is created that will have a missing value
                    "." for a numeric group_var og a empty value "" for a 
                    character group_var. As a consequence a grouping variable
                    is not allowed to take missing / empty values. The default
                    is group_var = null, ie no grouping variable is 
                    provided. As a consequence, a variable named null can
                    not be used as a grouping variable.
by_vars:            Specify by-variables. If more than one by-variable is
                    specified, use spaces " " as delimiters. The default is
                    by_vars = null, ie no by_vars. As a consequence variables
                    named "null" are not allowed if multiple variables are
                    specified, and as with group_var, a variable named "null"
                    can not be used as a single by-var.
weight:             Assign a weight to each oberservation, either by giving a
                    numeric value that is used as a weight for all observations,
                    or by speficying a variable that holds the weight for each
                    observation. Default value is weight = 1, ei. no weights.
cont_cutoff:        If var_types = auto then cont_cutoff is used to decide
                    whether or not a numerical variable is a categorical or
                    continuous. See var_types documentation. Default value
                    is cont_cutoff = 20. 
median_mean:        Specify if median (Q1-Q3) (median_mean = median) or 
                    mean (stderr) (median_mean = mean) statistics are calculated
                    for continuous variales. Default is median_mean = median.
npct_pctn:          Specify if n (%)  (npct_pctn = npct) or 
                    % (n) (npct_pctn) statistics are calculated for 
                    for dichotomous and categorical variales. 
                    Default is npct_pctn = npct.
dec_n:              Control the number of decimals to show in the statistics
                    showing the total number of patients in the population
                    (or in each strata defined by group_var).
                    Default is dec_n = 0.
dec_d_cat:          Control the number of decimals to show for the "n" 
                    part of the n (%) / (%) n part of statistics 
                    for dichotomous and categorical variables. 
                    Default is dec_d_cat = 0.
dec_cont:           Control the number of decimals to show for the 
                    median/mean/stedrr/Q1/Q3 statistics of continuous
                    variables. Default is dec_cont = 2.
dec_pct:            Control the number of decimals to show for percentage
                    statistics. Default is dec_pct = 2.
sep_dec:            Specify the decimal separator symbol to use. Enclose in 
                    double-quotes. Defualt is sep_dec = ".". Use 
                    sep_dec = remove to remove the decimal separator altogether. 
                    The "¤" and "@" symbols are not allowed as delimiters.
sep_digit:          Specify the digit group separator symbol to use. Enclose 
                    in double-quotes. Default is sep_digit = ".". Use 
                    sep_digit = remove to remove the digit group separator
                    altogether. The "¤" and "@" symbols are not allowed.
allow_d_miss:       Specify if dichotomous variables are allowed to have 
                    missing values. 
                    Yes (allow_d_miss = y) / No (allow_d_miss = n). 
                    Default is allow_d_miss = n. Note that if missing values
                    are allowed, that these observations are still included in
                    the denominator when calculating percentages!
allow_cont_miss:    Specify if continuous variables are allowed to have 
                    missing values.
                    Yes (allow_d_miss = y) / No (allow_d_miss = n). 
                    Default is allow_cont_miss = n.
total_group_last:   If a grouping variable is specified in group_var,
                    specify if the total group should be first
                    (total_group_last = n) or last (total_group_last = y) in
                    the output to help facilitate whether the total group
                    should be placed to the left (first) or right (last) in
                    the table. Default is total_group_last = y.   
inc_num_stat_vars:  Toggle whether or not additional numeric variables
                    with each component of the statistics are included in
                    the output. Yes (inc_num_stat_vars = y) or 
                    no (nc_num_stat_vars = n). Default is inc_num_stat_vars = n.
inc_report_dummy:   Toggle whether or not to include a dummy variable in
                    the output to help facility making the final tables
                    in proc report. Yes (inc_report_dummy = y) or
                    no (inc_report_dummy = n). Default is inc_report_dummy = y.
del:                Specify if temporay datasets created by the macro are 
                    deleted. Yes (del = y) or No (del = n). Default is 
                    del = y.
******************************************************************************/

%macro pt_char(
  in_ds             = ,
  out_ds            = ,
  var_list          = ,
  var_types         = auto,
  group_var         = null,
  by_vars           = null,
  weight            = 1,
  cont_cutoff       = 20,
  median_mean       = median,
  npct_pctn         = npct,
  dec_n             = 0,
  dec_d_cat         = 0,
  dec_cont          = 2,
  dec_pct           = 2,
  sep_dec           = ".",
  sep_digit         = ",",
  allow_d_miss      = n,
  allow_cont_miss   = n,
  total_group_last  = y,
  inc_num_stat_vars = n,
  inc_report_dummy  = y,
  del               = y
) / minoperator mindelimiter = ' ';

%local  i i_by_vars i_by_vars_ori i_min i_max i_nvalues 
        i_var_list i_var_list_ori i_var_list_temp i_var_nmiss 
        i_var_nvalues i_var_types i_vars i_vt
        j j_var
        by_vars_ori cat_label_datasets cat_vars cat_vars_ori ds_id 
        group_var_ori group_var_nmiss nvalues rc stat_max_length
        var_list_ori var_list_temp var_max_length vars w_min
        ;   


/*******************************************************************************	
INPUT PARAMETER CHECKS 
*******************************************************************************/

/* Check that none of the macro paramters are empty. */
%let vars = in_ds out_ds var_list var_types group_var by_vars weight 
            cont_cutoff median_mean npct_pctn dec_n dec_d_cat dec_cont dec_pct 
            sep_dec sep_digit allow_d_miss allow_cont_miss total_group_last 
            inc_num_stat_vars inc_report_dummy del;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_vars = %scan(&vars, &i, %str( ));
  %if %sysevalf(&&&i_vars = ) %then %do;
  %put ERROR: Macro parameter &i_vars not specified!;
  %goto end_of_macro;    
  %end;
%end;
 
/* Remove single and double quotes from macro parameters where they are not 
supposed to be used, but might have been used anyway. */
%let vars = var_list var_types group_var by_vars weight median_mean npct_pctn 
            allow_d_miss allow_cont_miss total_group_last inc_num_stat_vars 
            inc_report_dummy del;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_vars = %scan(&vars, &i, %str( ));
  %let &i_vars = %sysfunc(tranwrd(&&&i_vars, %nrstr(%"), %str( )));
  %let &i_vars = %sysfunc(tranwrd(&&&i_vars, %nrstr(%'), %str( )));
%end;

/* Make sure all relevant macro parameters are in lowercase. */
%let vars = var_list var_types group_var by_vars weight median_mean 
            npct_pctn allow_d_miss allow_cont_miss total_group_last 
            inc_num_stat_vars inc_report_dummy del;           
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_vars = %scan(&vars, &i, %str( ));
  %let &i_vars = %lowcase(&&&i_vars);
%end;

/* Try to laod the first observation of the input dataset and use this 
dataset for the following checks. This is done to avoid errors/warnings
when the input dataset is given as a filepath, while at the same time 
giving meaningful errors in the log, that results in the macro being 
terminated. */
data _pc_in_ds_tests;
  set &in_ds(obs = 1);
run;

/* Check that the specified input dataset exists and is not empty. */
%if %sysfunc(exist(_pc_in_ds_tests)) = 0 %then %do;
  %put ERROR: Input dataset: &in_ds does not exist!;
  %goto end_of_macro;
%end;

%let ds_id = %sysfunc(open(_pc_in_ds_tests));
%if  %sysfunc(attrn(&ds_id, nobs)) = 0 %then %do;
  %let rc = %sysfunc(close(&ds_id));
  %put ERROR: Input dataset: &in_ds does not exist or is empty!;
  %goto end_of_macro;
%end;
%let rc = %sysfunc(close(&ds_id));

/* Check that the variables specified in var_list exists in the 
input dataset, and that none of them is named "n". */
%let ds_id = %sysfunc(open(_pc_in_ds_tests));
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var_list = %scan(&var_list, &i, %str( ));
  %if %sysfunc(nvalid(&i_var_list)) = 0 %then %do;
    %let rc = %sysfunc(close(&ds_id));
    %put ERROR: Variable "&i_var_list" specified in var_list;
    %put ERROR: is not a valid SAS variable name!;
    %goto end_of_macro;
  %end;
  %if %sysfunc(varnum(&ds_id, &i_var_list)) = 0 or &i_var_list = n %then %do;
    %if &i_var_list = n %then %do;
      %let rc = %sysfunc(close(&ds_id));
      %put ERROR: Variables named "n" are not allowed in var_list!;
    %end;
    %else %if %sysfunc(varnum(&ds_id, &i_var_list)) = 0 %then %do;
      %let rc = %sysfunc(close(&ds_id));
      %put ERROR: Variable: &i_var_list specified in var_list;
      %put ERROR: does not exist in the input dataset!;
    %end;
    %goto end_of_macro; 
  %end;
%end;
%let rc = %sysfunc(close(&ds_id));

/* Check that manually specified variable types are valid */
%if &var_types ne auto %then %do;
  %do i = 1 %to %sysfunc(countw(&var_types, %str( )));
    %let i_var_types = %scan(&var_types, &i, %str( ));
    %if %eval(&i_var_types in d cat cont) = 0 %then %do;
      %put ERROR: Macro parameter var_types contains invalid value: &i_var_types;
      %put ERROR: Valid values:;
      %put ERROR: d (dichotomous);
      %put ERROR: cat (categorical);
      %put ERROR: cont (continuous);
      %goto end_of_macro; 
    %end;
  %end;
%end;

/* If variable types have been specified manually, check that the number of 
manually specified variable types, matches the number of variables in 
var_list */
%if &var_types ne auto %then %do;
  %let var_list_n = %sysfunc(countw(&var_list, %str( )));
  %let var_types_n = %sysfunc(countw(&var_types, %str( )));
  %if %eval(&var_list_n ne &var_types_n) %then %do;
    %put ERROR: Then number of specified variable types in var_types (&var_types_n);
    %put ERROR: does not match the number of variables in var_list (&var_list_n)!;
    %goto end_of_macro; 
  %end;
%end;

/* Check that only one grouping variable is specified */
%if %eval(%sysfunc(countw(&group_var, %str( ))) > 1) %then %do;
  %put ERROR: Only one grouping variable can be specified in group_var!;
  %goto end_of_macro; 
%end;

/* Check that the specified grouping variable exists in the input data */
%if &group_var ne null %then %do;
  %if %sysfunc(nvalid(&group_var)) = 0 %then %do;
    %put ERROR: Group variable: &group_var specified in group_var;
    %put ERROR: is not a valid SAS variable name!;
    %goto end_of_macro;
  %end;
  %let ds_id = %sysfunc(open(&in_ds));
  %if %sysfunc(varnum(&ds_id, &group_var)) = 0 %then %do;
    %let rc = %sysfunc(close(&ds_id));
    %put ERROR: The variable specified in group_var: &group_var does;
    %put ERROR: not exist in the input dataset!;
    %goto end_of_macro; 
  %end;
  %let rc = %sysfunc(close(&ds_id));
%end;

/* Check that the specified by-variables exists in the input dataset,
and if multiple variables are given, make sure none of them is named
"null". */
%if &by_vars ne null %then %do;
  %let ds_id = %sysfunc(open(&in_ds));
  %do i = 1 %to %sysfunc(countw(&by_vars, %str( )));
    %let i_by_vars = %scan(&by_vars, &i, %str( ));
    %if %sysfunc(nvalid(&i_by_vars)) = 0 %then %do;
      %let rc = %sysfunc(close(&ds_id));
      %put ERROR: Variable: &i_by_vars specified in by_vars;
      %put ERROR: is not a valid SAS variable name!;
      %goto end_of_macro;
    %end;
    %if %sysfunc(varnum(&ds_id, &i_by_vars)) = 0 or &i_by_vars = null %then %do;
      %if &i_by_vars = null %then %do;
        %put ERROR: By-variables named "null" are not allowed!;
      %end;      %else %if %sysfunc(varnum(&ds_id, &i_by_vars)) = 0 %then %do;
        %put ERROR: By-variable "&i_by_vars" specified in by_vars does not exist!;
      %end;
      %let rc = %sysfunc(close(&ds_id));
      %goto end_of_macro; 
    %end;
  %end;
  %let rc = %sysfunc(close(&ds_id));
%end;

/* Check that only one numeric/character value is specified in the
weight macro paramter */
%else %if %eval(%sysfunc(countw(&weight, %str( ))) > 1 ) %then %do;
  %put ERROR: Several numeric values/variables are specified in the;
  %put ERROR: weight macro parameter! Only one numeric value or one;
  %put ERROR: variable is allowed!;
  %goto end_of_macro; 
%end;

/* If weight is not specified as a numeric value but as a variable name,
check that the variable exists in the input dataset and that it is a
numeric variable. */
%if %datatyp(&weight) = CHAR %then %do;
  %if %sysfunc(nvalid(&weight)) = 0 %then %do;
    %put ERROR: Weight variable: &weight is not a valid SAS variable name!;
    %goto end_of_macro;
  %end;
  %let ds_id = %sysfunc(open(&in_ds));
  %if %sysfunc(varnum(&ds_id, &weight)) = 0 %then %do;
    %let rc = %sysfunc(close(&ds_id));
    %put ERROR: The specified weight variable (&weight);
    %put ERROR: does not exist in the input dataset!;
    %goto end_of_macro; 
  %end;
  %if %sysfunc(vartype(&ds_id, %sysfunc(varnum(&ds_id, &weight)))) = C %then %do;
    %let rc = %sysfunc(close(&ds_id));
    %put ERROR: The specified weight variable (&weight);
    %put ERROR: is not numeric!;
    %goto end_of_macro; 
  %end;
  %let rc = %sysfunc(close(&ds_id));
%end;

/* Check that none of the specified variables has a "__" prefix. Note
that "dummy_var" has been included in %qsubstr call so that
variables with a name of length one can be handled. */
%let vars = var_list group_var by_vars weight;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_vars = %scan(&vars, &i, %str( ));
  %do j = 1 %to %sysfunc(countw(&&&i_vars, %str( )));
    %let j_var = %scan(&&&i_vars, &j, %str( ));
    %if %eval(%qsubstr(&j_var dummy_var, 1, 2) = __) %then %do;
      %put ERROR: &i_vars contains a variable with a "__" prefix (&&&i_vars);
      %put ERROR: This is not allowed to make sure that input variables are not;
      %put ERROR: overwritten by temporary variables created by the macro!;
      %goto end_of_macro; 
    %end;
  %end;
%end; /* End of i-loop */

/* Check that cont_cutoff is specified as a positive integer.
Regular expression: Starts with a number 1-9, followed by, and ends with,
one or more digits (so that eg. 0 is not allowed, but 10 is)*/
%if %sysfunc(prxmatch('^[1-9]\d*$', &cont_cutoff)) = 0 %then %do;
  %put ERROR: cont_cutoff must be a positive integer!;
  %goto end_of_macro; 
%end;

/* Check that median_mean takes either the value "median" or the value "mean". */
%if %eval(&median_mean in median mean) = 0  %then %do;
  %put ERROR: The median_mean parameter must be speficied as either;
  %put ERROR: median_mean = median or median_mean = mean.;
  %goto end_of_macro; 
%end;

/* Check that npct_pctn takes either the value "npct" or the value "pctn". */
%if %eval(&npct_pctn in npct pctn) = 0 %then %do;
  %put ERROR: The npct_pctn parameter must be speficied as either;
  %put ERROR: "npct" or "pctn";
  %goto end_of_macro; 
%end;

/* Check that the parameters specifying how many decimals to display in the
output if corrrectly specified as a non-negative integer */
%if %sysfunc(prxmatch('^\d+$', &dec_n)) = 0 %then %do;
  %put ERROR: dec_n must be a non-negative integer!;
  %goto end_of_macro; 
%end;
%if %sysfunc(prxmatch('^\d+$', &dec_d_cat)) = 0 %then %do;
  %put ERROR: dec_d_cat must be a non-negative integer!;
  %goto end_of_macro; 
%end;
%if %sysfunc(prxmatch('^\d+$', &dec_cont)) = 0 %then %do;
  %put ERROR: dec_cont must be a non-negative integer!;
  %goto end_of_macro; 
%end;
%if %sysfunc(prxmatch('^\d+$', &dec_pct)) = 0 %then %do;
  %put ERROR: dec_pct must be a non-negative integer!;
  %goto end_of_macro; 
%end;

/* Check that sep_dec and sep_digit is specified correctly as "remove" or 
on the form: starts with a double-quote, followed by one or more 
symbols(none of which are the symbols "¤" or "@", and ends in double-quote. */
%if %eval(&sep_dec ne remove and %sysfunc(prxmatch('^["][^¤@]*["]$|^remove$', &sep_dec)) = 0) %then %do;
  %put ERROR: sep_dec does not have a valid value!;
  %goto end_of_macro;  
%end;

%if %sysfunc(prxmatch('^["][^¤@]*["]$|^remove$', &sep_digit)) = 0 %then %do;
  %put ERROR: sep_digit does not have a valid value!;
  %goto end_of_macro;  
%end;

/* Check that y/n macro parameters are specified correctly */
%let vars = allow_d_miss allow_cont_miss total_group_last
            inc_num_stat_vars inc_report_dummy del;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_vars = %scan(&vars, &i, %str( ));
  %if %eval(&&&i_vars in n y) = 0 %then %do;
    %put ERROR: &i_vars must be specified as  &i_vars = n (no) or &i_vars = y (yes)!;
    %goto end_of_macro;
  %end;
%end;


/*******************************************************************************	
RENAME VARIABLES
*******************************************************************************/
/* To ensure that long variable names can be handled, we rename all variables
specified in the var_list group_var and by_vars macro parameters. If no
group_var and/or by_vars are given, we created dummy variables to facilitate
the analyses. The original input is saved so that the variable names can be
supstituted back into the output table. */
%let var_list_ori = &var_list;
%let group_var_ori = &group_var;
%let by_vars_ori = &by_vars;

%let var_list = ;
%let group_var = __group_var;
%let by_vars = ;

%do i = 1 %to %sysfunc(countw(&var_list_ori, %str( )));
  %let var_list = &var_list __var_&i;
%end;
%do i = 1 %to %sysfunc(countw(&by_vars_ori, %str( )));
  %let by_vars = &by_vars __by_var_&i;
%end;

data _pc_data1(keep = __:);
	set &in_ds;
  /* Rename var_list variables. */
  %do i = 1 %to %sysfunc(countw(&var_list_ori, %str( )));
    %let i_var_list_ori = %scan(&var_list_ori, &i, %str( ));
    rename &i_var_list_ori = __var_&i;
  %end;
  /* Rename or create group variable. */
  %if &group_var_ori ne null %then %do;
    rename &group_var_ori = __group_var;
  %end;
  %else %do;
    __group_var = "dummy";
  %end;
  /* Create weight variable */
  	__w = &weight;
  /* dummy variable used when summarizing the data. */
  __dummy = 1;
  /* Rename or create by_vars */
  %if &by_vars_ori ne null %then %do;
    %do i = 1 %to %sysfunc(countw(&by_vars_ori, %str( )));
      %let i_by_vars_ori = %scan(&by_vars_ori, &i, %str( ));
      rename &i_by_vars_ori = __by_var_&i;
    %end;
  %end;
  %else %do;
    __by_var_1 = "dummy";
  %end;
run;
/*%put var_list_ori: &var_list_ori;*/
/*%put var_list: &var_list;*/
/*%put group_var_ori: &group_var_ori;*/
/*%put group_var: &group_var;*/
/*%put by_vars_ori: &by_vars_ori;*/
/*%put by_vars: &by_vars;*/


/*******************************************************************************	
INPUT DATA CHECKS
*******************************************************************************/

/* Check that the specified grouping variable does not contain 
missing values / empty strings */
proc sql noprint;
  select nmiss(__group_var) into: group_var_nmiss
    from _pc_data1(keep = __group_var);
quit;

%if  &group_var_nmiss > 0 %then %do;
  %put ERROR: The specified group_var variable contains missing;
  %put ERROR: values / empty strings!;
  %goto end_of_macro;
%end;


/******************************************************************************
FIND VARIABLE INFO
******************************************************************************/

proc sql;
  create table _pc_info1 as
    select
      %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
        %let i_var_list = %scan(&var_list, &i, %str( ));
        count(distinct(&i_var_list)) as &i_var_list._nvalues,
        nmiss(&i_var_list) as &i_var_list._nmiss,
        min(&i_var_list) as &i_var_list._min,
        max(&i_var_list) as &i_var_list._max,
      %end;
      min(__w) as __w_min,
      1 as __merge
      from _pc_data1;		
quit;

data _pc_info2;
set _pc_data1(obs = 1);
  %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
    %let i_var_list = %scan(&var_list, &i, %str( ));
    &i_var_list._vt = vtype(&i_var_list);
    keep &i_var_list._vt;
  %end;
  __merge = 1;
  keep __merge;
run;

data _pc_info3; 
  merge _pc_info1 _pc_info2;
  by __merge;
run;

/* If any observation has a negative weight, we terminate the macro
with an error. */
proc sql noprint;
  select __w_min into :w_min
    from _pc_info3;
quit;

%if %sysevalf(&w_min < 0) %then %do;
  %put ERROR: One or more observations have a negative weight!;
  %goto end_of_macro;      
%end;

/******************************************************************************
DETERMINE VARIABLE TYPES
******************************************************************************/

data _pc_info4; 
  set _pc_info3;
  %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
    %let i_var_list = %scan(&var_list, &i, %str( ));
    format &i_var_list._type $4.;
    /*** Automatic ***/
    %if &var_types = auto %then %do;
      /* If the variable is character, we will assume it is a categorical
      variable. */
      if &i_var_list._vt = "C" then &i_var_list._type = "cat";
      /* Else, if the variable takes numeric values: */
      else do;
        /* If the variable only takes the values zero and/or one (besides 
        missing values) then we will assume it's dichotomous. */
        if 1 <= &i_var_list._nvalues <= 2 and cats(&i_var_list._min) in ("0" "1") 
          and cats(&i_var_list._max) in ("0" "1") then &i_var_list._type = "d";  
        /* Else, if the variable takes fewer distinct values than
        specified in &cont_cufoff then we will assume that the variable
        is categorical. */
        else if &i_var_list._nvalues < &cont_cutoff 
          then &i_var_list._type = "cat"; 
        /* Else we assume the variable is continuous. */
        else &i_var_list._type = "cont";
      end;
    %end;
    /*** Manual ***/
    %else %do;
      %let i_var_types = %scan(&var_types, &i, %str( ));
      &i_var_list._type = "&i_var_types";
    %end;

    /* Correction of nvalues if there are categorical variables
    with missing values. */
    if &i_var_list._type = "cat" and &i_var_list._nmiss > 0 
        then &i_var_list._nvalues = &i_var_list._nvalues + 1; 
  %end;
run;

/*%put var_types before auto determine: &var_types;*/

/* If &var_types = auto we update the macro variable to include
the automatically determined variable types. */
%if &var_types = auto %then %do;
  %let var_types = ;
  %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
    %let i_var_list = %scan(&var_list, &i, %str( ));
    proc sql noprint;
      select &i_var_list._type into :i_var_types
        from _pc_info4;
    quit;
    %let var_types = &var_types &i_var_types;
  %end;
%end;

/*%put var_types after auto determine: &var_types;*/

/******************************************************************************
FURTHER CHECKS AFTER VARIABLE TYPES DETERMINED
******************************************************************************/

/* Depending on the values of &allow_d_miss and &allow_cont_miss, 
terminate the macro with an error if any of the dichotomous and/or 
continuous variables have missing values. */
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var_list = %scan(&var_list, &i, %str( ));
  %let i_var_list_ori = %scan(&var_list_ori, &i, %str( ));
  %let i_var_types = %scan(&var_types, &i, %str( ));
  data _null_;
    set _pc_info4;
    call symput("i_var_nmiss", put(&i_var_list._nmiss, 20.));
  run;

  %if &allow_d_miss = n and &i_var_types = d and %eval(&i_var_nmiss > 0) %then %do;
    %put ERROR: Dichotomous variable "&i_var_list_ori" contains one or more missing values!;
    %put ERROR: Use allow_d_miss = y if missing values in dichotomous variables are to be allowed.;
    %put ERROR: Note that if missing values are allowed, that the missing observations are still;
    %put ERROR: counted in the denominator when calculating percentages!;
    %goto end_of_macro;    
  %end;
  %if &allow_cont_miss = n and &i_var_types = cont and %eval(&i_var_nmiss > 0) %then %do;
    %put ERROR: Continuous variable "&i_var_list_ori" contains one or more missing values!;
    %put ERROR: Use allow_cont_miss = y if missing values in continuous variables are to be allowed.;
    %goto end_of_macro;    
  %end;
%end; /* End of i-loop */

/* Check that the variable types are compatible with the variables */
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var_list = %scan(&var_list, &i, %str( ));
  %let i_var_list_ori = %scan(&var_list_ori, &i, %str( ));
  %let i_var_types = %scan(&var_types, &i, %str( ));
  proc sql noprint;
    select  &i_var_list._vt, 
            &i_var_list._nvalues,
            &i_var_list._min, 
            &i_var_list._max 
    into    :i_vt,
            :i_nvalues,
            :i_min,
            :i_max
    from _pc_info4;
  quit;

  /* Dichotomous: variable needs to be numeric and only take
  zero and/or one values (besides missing values) */
  %if &i_var_types = d %then %do;
    %if %eval(&i_vt ne N or %sysfunc(prxmatch("^1$|^2$", &i_nvalues)) = 0
        or %sysfunc(prxmatch("^0$|^1$", &i_min)) = 0
        or %sysfunc(prxmatch("^0$|^1$", &i_max)) = 0) %then %do;
      %put ERROR: The var_list variable "&i_var_list_ori" is specified to be a;
      %put ERROR: dichotomous variable but does not fullfill the requirements;
      %put ERROR: of being a numeric variable with zero and/or one values.;
      %goto end_of_macro;    
    %end;
  %end;
  /* Categorical: variable must have fewer than &cont_cutoff 
  distinct values. */
  %if &i_var_types = cat %then %do;
    %if &i_nvalues ge &cont_cutoff %then %do;
      %put ERROR: The var_list variable "&i_var_list_ori" is specified to be a;
      %put ERROR: categorical variable but does not fullfill the requirements;
      %put ERROR: of having fewer than &cont_cutoff (cont_cutoff) distrinct values;
      %goto end_of_macro;        
    %end;
  %end;
  /* Continuous: variable must be numeric. */
  %if &i_var_types = cont %then %do;
    %if &i_vt ne N %then %do;
      %put ERROR: The var_list variable "&i_var_list_ori" is specified to be a;
      %put ERROR: continuous variable but does not fullfill the requirements;
      %put ERROR: of being a numerical variable.;
      %goto end_of_macro;        
    %end;
  %end;
%end;


/******************************************************************************
MAKE NUMERIC VERSIONS OF CATEGORICAL VARIABLES
******************************************************************************/

/* To facilitate the handling of categorical variables, we will make new
versions with numerical values. */

/* Update/make macro variables */
/*%put var_list before num cat vars: &var_list;*/
%let var_list_temp = &var_list;
%let var_list = ;
%do i = 1 %to %sysfunc(countw(&var_types, %str( )));
  %let i_var_types = %scan(&var_types, &i, %str( ));
  %let i_var_list_temp = %scan(&var_list_temp, &i, %str( ));
  %let i_var_list_ori = %scan(&var_list_ori, &i, %str( ));
  %if &i_var_types = cat %then %do; 
    %let var_list = &var_list __cat_var_&i;
  %end;
  %else %do;
    %let var_list = &var_list &i_var_list_temp;
  %end;
%end;
/*%put var_list after num cat vars: &var_list;*/


/* Make new version numeric version of categorical variables. */
%do i = 1 %to %sysfunc(countw(&var_list, %str( )));
  %let i_var_list_ori = %scan(&var_list_ori, &i, %str( ));
  %let i_var_types = %scan(&var_types, &i, %str( ));
  %if &i_var_types = cat %then %do;
    proc sort data = _pc_data1;
      by __var_&i;
    run;

    /* Replace the categorical variables with numeric versions
    and save the unique original and corresponding numeric values,
    separately. */
    data _pc_data1(drop = __var_&i) 
         _pc_unique_1_&i(keep = __var_&i __cat_var_&i);
      set _pc_data1;
      by __var_&i;
      retain __cat_var_&i;
      if _n_ = 1 then __cat_var_&i = 0;
      if first.__var_&i then do;
        __cat_var_&i = __cat_var_&i + 1;
        output;
      end;
      else output _pc_data1;
    run;

    data _pc_cat_num_vals_&i;
      set _pc_unique_1_&i;
      format __var_name __label $500. ;
      __var_name = "__cat_var_&i" || "_" || cats(__cat_var_&i);
      __label = "&i_var_list_ori: " || cats(__var_&i);
      output;
      /* Include title line */
      if _n_ = 1 then do;
        __var_name = "__cat_var_&i._title";
        __label = "&i_var_list_ori";
        output;
      end;
      keep __var_name __label;
    run;
  %end;
%end;


/******************************************************************************
MAKE LABELS FOR OUTPUT TABLE
******************************************************************************/

/* Create an empty dataset  so that the set-statement below also works
when there are no categorical variables in the data. */
data _pc_dummy;
  format __var_name __label $500.;
  call missing(__var_name, __label);
run;

/* Combine the the datasets with the original categorical variables/values
and the new correpondings values. Add the remaining variables, and make
output labels for all variables. */
data _pc_labels1;
  set _pc_dummy
  %do i = 1 %to %sysfunc(countw(&var_types, %str( )));
    %let i_var_types = %scan(&var_types, &i, %str( ));
    %if &i_var_types = cat %then %do; 
      _pc_cat_num_vals_&i
    %end;
  %end;
  ;
  output;
  if _n_ = 1 then do;
    __var_name = "n";
    __label = "n";
    output;
    %do i = 1 %to %sysfunc(countw(&var_types, %str( )));
      %let i_var_types = %scan(&var_types, &i, %str( ));
      %let i_var_list_ori = %scan(&var_list_ori, &i, %str( ));
      %if &i_var_types ne cat %then %do; 
        __var_name = "__var_&i";
        __label = "&i_var_list_ori";
        output;
      %end;
    %end;
  end;
  /* Remove the dummy dataline */
  if __var_name = "" then delete;
run;


/******************************************************************************
INDICATOR FUNCTIONS FOR CATEGORICAL VARIABLES
******************************************************************************/

/* If the data contains categorical variables we replace each of them with a
set of dichotomous indicator variables */

/* Make macro variable with the number of distinct values for 
each categorical variable. */
%let nvalues = ;
%do i = 1 %to %sysfunc(countw(&var_types, %str( )));
  %let i_var_types = %scan(&var_types, &i, %str( ));
  %if &i_var_types = cat %then %do;
    proc sql noprint;
      select __var_&i._nvalues into :i_var_nvalues
        from _pc_info4;
    quit;
  %end;
  %else %do;
    %let i_var_nvalues = dummy;
  %end;
  %let nvalues = &nvalues &i_var_nvalues;
%end; /* End of i-loop */
/*%put nvalues: &nvalues;*/

/* Create dichotomous indicator variables to replace each categorical variable,
including a dummy variable used as a title line in the final output. */
data _pc_data2;
  set _pc_data1;
  %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
    %let i_var_list = %scan(&var_list, &i, %str( ));
    %let i_var_types = %scan(&var_types, &i, %str( ));
    %let i_nvalues = %scan(&nvalues, &i, %str( ));
    %if &i_var_types = cat %then %do;
      __cat_var_&i._title = 1;
      %do j = 1 %to &i_nvalues;
        __cat_var_&i._&j = (__cat_var_&i. = &j.);
      %end;
      drop &i_var_list;
    %end;
  %end; /* End of i-loop */
run;

/* Replace the categorical variables with the sets of dichotomous variables
in the var_list and var_types macro variables. */ 
/*%put var_list before replace cat vars: &var_list;*/
/*%put var_types before replace cat vars: &var_types;*/
%let var_list_temp = &var_list;
%let var_types_temp = &var_types;
%let var_list = ;
%let var_types = ;

%do i = 1 %to %sysfunc(countw(&var_list_temp, %str( )));
  %let i_var_list_temp = %scan(&var_list_temp, &i, %str( ));
  %let i_var_types_temp = %scan(&var_types_temp ,&i, %str( ));
  %let i_nvalues = %scan(&nvalues, &i, %str( ));

  %if &i_var_types_temp = cat %then %do;
    %let var_list = &var_list &i_var_list_temp._title;
    %let var_types = &var_types title;
    %do j = 1 %to &i_nvalues;
      %let var_list = &var_list __cat_var_&i._&j;
      %let var_types = &var_types d;
    %end;
  %end;
  %else %do;
    %let var_list = &var_list &i_var_list_temp;
    %let var_types = &var_types  &i_var_types_temp;
  %end;
%end; /* End of i-loop */
/*%put var_list after replace cat vars: &var_list;*/
/*%put var_types after replace cat vars: &var_types;*/


/******************************************************************************
SUMMARIZE DATA
******************************************************************************/

proc sort data = _pc_data2;
  by __by:;
run;

proc means data = _pc_data2 noprint vardef = df;
  by __by:;
  class __group_var;
  var &var_list;
  weight __w;
  output out = _pc_data3(drop = _type_ _freq_)
    sum(__dummy) = n
    sum(&var_list) =
    p25(&var_list) =
    median(&var_list) =
    p75(&var_list) =
    mean(&var_list) =
    stddev(&var_list) =
    / autoname noinherit;
  types () __group_var;
run;

data _pc_data4;
  set _pc_data3;
  format __var_name __stat_char $500. 
         __stat_num1 __stat_num2 __stat_num3 best32.;
  /* Make "n" datalines and stat variables */
  __var_name = "n";
  __stat_num1 = n;
  __stat_char = compress(put(__stat_num1, comma32.&dec_n));
  output;
  %do i = 1 %to %sysfunc(countw(&var_list, %str( )));
    %let i_var_list = %scan(&var_list, &i, %str( ));
    %let i_var_types = %scan(&var_types, &i, %str( ));
    __var_name = "&i_var_list";
    /* Dichotomous (including recoded categorigal) variables */
    %if &i_var_types = d %then %do;
      /* n (%)*/
      %if &npct_pctn = npct %then %do;
        __stat_num1 = &i_var_list._sum;
        __stat_num2 = &i_var_list._sum / n * 100;
        __stat_num3 = .;
        if __stat_num1 ne . and __stat_num2 ne . then 
          __stat_char = compress(put(__stat_num1, comma32.&dec_d_cat)) || 
                       " (" || 
                       compress(put(__stat_num2, 32.&dec_pct)) || 
                       ")";
        else __stat_char = "n/a";
      %end;
      /* % (n) */
      %if &npct_pctn = pctn %then %do;
        __stat_num1 = &i_var_list._sum / n * 100;
        __stat_num2 = &i_var_list._sum;
        __stat_num3 = .;
        if __stat_num1 ne . and __stat_num2 ne . then
          __stat_char = compress(put(__stat_num1, 32.&dec_pct)) || 
                       " (" || 
                       compress(put(__stat_num2, comma32.&dec_d_cat)) || 
                       ")";
        else __stat_char = "n/a";
      %end;
    %end;
    /* Continous variables */
    %if &i_var_types = cont %then %do;
      /* Median (Q1-Q3) */
      %if &median_mean = median %then %do;
        __stat_num1 = &i_var_list._median;
        __stat_num2 = &i_var_list._p25;
        __stat_num3 = &i_var_list._p75;
        if __stat_num1 ne . and __stat_num2 ne . and __stat_num3 ne . then
          __stat_char = compress(put(__stat_num1, comma32.&dec_cont)) ||
                      " (" || compress(put(__stat_num2, comma32.&dec_cont)) ||
                      ";" || compress(put(__stat_num3, comma32.&dec_cont)) ||
                      ")";
        else __stat_char = "n/a";
      %end;
      /* Mean (stderr) */
      %if &median_mean = mean %then %do;
        __stat_num1 = &i_var_list._mean;
        __stat_num2 = &i_var_list._stddev;
        __stat_num3 = .;
        if __stat_num1 ne . and __stat_num2 ne . then 
          __stat_char = compress(put(__stat_num1, comma32.&dec_cont)) ||
                      " (" ||
                      compress(put(__stat_num2, comma32.&dec_cont)) ||
                      ")";
        else __stat_char = "n/a";
      %end;
    %end;
    /* Titles */
    %if &i_var_types = title %then %do;
      __stat_num1 = .;
      __stat_num2 = .;
      __stat_num3 = .;
      __stat_char = "";
    %end;
    output;
  %end;
  keep __by: __group_var __var_name __stat:;
run;


/******************************************************************************
SORT TOTAL GROUP
******************************************************************************/

/* Sort data so that the total group of the grouping values are either 
first or last in each strata of by-variables. */
data _pc_data5;
  set _pc_data4;
  by __by: __group_var;
  retain __sort_group_var __sort_var_name;
  if _n_ = 1 then __sort_group_var = 0;
  if first.__group_var then do;
    __sort_group_var = __sort_group_var + 1;
    __sort_var_name = 0;
  end;
  __sort_var_name = __sort_var_name + 1;
run;

data _pc_data6;
  set _pc_data5;
  %if &total_group_last = y %then %do;
    if missing(__group_var) then __sort_group_var = 10**6;
  %end;
run;

proc sort data = _pc_data6 out = _pc_data7(drop = __sort:);
  by  __by: __sort_group_var __sort_var_name;
run;


/******************************************************************************
TRANSFORM DECIMAL / DIGIT GROUP SYMBOLS 
******************************************************************************/

data _pc_data8;
  set _pc_data7;
  /* Transform separator symbols to unused symbols */
  __stat_char = tranwrd(__stat_char, ".", "¤");
  __stat_char = tranwrd(__stat_char, ",", "@");
  /* Transform decimal separator symbol */
  %if &sep_dec = remove %then %do;
    __stat_char = compress(__stat_char, "¤");
  %end;
  %else %do;
    __stat_char = tranwrd(__stat_char, "¤", &sep_dec);
  %end;
  /* Transform digit group separator. */
  %if &sep_digit = remove %then %do;
    __stat_char = compress(__stat_char, "@");
  %end;
  %else %do;
    __stat_char = tranwrd(__stat_char, "@", &sep_digit);
  %end;

  /* We create a sorting variable so we can recreate the 
  current ordering of datalines after categorical variable
  labels have been merged to the data. */
  __sort_var = _n_;
run;


/******************************************************************************
FINALIZE OUTPUT
******************************************************************************/

/* Merge labels to the data */
proc sql;
  create table _pc_data9(drop = __var_name) as
    select a.*, b.__label
      from _pc_data8 as a
      left join 
      _pc_labels1 as b
      on a.__var_name = b.__var_name
      order by a.__sort_var;
quit;

/* Determine the maximum length of the __label and __stat_char
so that these variables can be redefined with the appropriate length
etc. */
proc sql noprint;
  select max(length(__label)), max(length(__stat_char)) 
    into :var_max_length, :stat_max_length
    from _pc_data9;
quit;

data &out_ds;
  /* Reorder columns so that by- and group-variables are the left-most columns. */
  retain
  %do i = 1 %to %sysfunc(countw(&by_vars_ori, %str( )));
    %let i_by_vars_ori = %scan(&by_vars_ori, &i, %str( ));
      __by_var_&i
  %end;
  __group_var;
  length __var_name $&var_max_length __stat_char $&stat_max_length;
  set _pc_data9(rename = (__label = __temp_var_name 
                          __stat_char = __temp_stat));

  __var_name = __temp_var_name;
  __stat_char = __temp_stat;

  /* If no group variable was specified we remove the automatically 
  created total category datalines and the dummy group variable. */
  %if &group_var_ori = null %then %do;
    if missing(__group_var) then delete;
    drop __group_var;
  %end;
  %else %do;
    rename __group_var = &group_var_ori;
  %end;
  /* If no by_vars were given we delete the dummy by variable. */
  %if &by_vars_ori = null %then %do;
    drop __by_var_1;
  %end;
  %else %do;
    %do i = 1 %to %sysfunc(countw(&by_vars_ori, %str( )));
      %let i_by_vars_ori = %scan(&by_vars_ori, &i, %str( ));
      rename __by_var_&i = &i_by_vars_ori;
    %end;
  %end;
  %if &inc_num_stat_vars = n %then %do;
    drop __stat_num:;
  %end;
  %if &inc_report_dummy = y %then %do;
    __report_dummy = 1;
  %end;
  drop __temp: __sort_var;
run;


%end_of_macro:

/* Delete temporary datasets created by the macro */
%if &del = y %then %do;
  proc datasets nodetails nolist;
    delete _pc_:;
  run;
  quit;
%end; 

%mend pt_char;

