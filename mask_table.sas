/*******************************************************************************
AUTHOR:     Thomas Boejer Rasmussen
VERSION:    0.1.1
DATE:       2020-04-15
LICENCE:    Creative Commons CC0 1.0 Universal  
            (https://www.tldrlegal.com/l/cc0-1.0)
********************************************************************************
DESCRIPTION:
Masks/suppresses/censors a table of aggregated counts, if the table contains
counts that are deemed person-sensitive. Based on the approach described in:

Paper SAS2022-2018
"Implementing Privacy Protection-Compliant SAS Aggregate Reports"
by Leonid Batkhan
link: https://support.sas.com/content/dam/SAS/support/en/
sas-global-forum-proceedings/2018/2022-2018.pdf

In short, masking person-sensitive count data that is classified according to 
classification variables with total categories can be achieved by working with 
the data in "long format", and then applying the following algorithm iteratively
across the classification variables and considering each variable of counts:
1. Take the average of masked counts (so far), if it is lower than a threshold, 
   mask the lowest non-masked count.
2. If the lowest count non-masked count is considered to be person-sensitive, 
   mask it.
3. If exactly one count has been masked so far, mask the second lowest count.

When the algorithm no longer masks additional counts, it is stopped. Finally,
since very large counts are often considered just as person-sensitive as low 
counts (since we know the total), we mask any count that is deemed to close to 
the total count. If this is not behavior is unwanted, this can be disabled.

The macro is intended to be used in connection with the pt_char 
macro. Therefore, the input table needs to follow the same structure as the
output from the pt_char macro. That is, the input table must be in "long format"
with respect to the classification variables to which masking is done. The table
can include counts of numerous variables, identified using a 
"variable id"-variable and a "variable value"-variable (to be able to identify
each value of any categorical variables). See mask_table_examples file for 
examples of the exact structure the input data must have.

Accompanying examples and tests, version notes etc. can be found at:
https://github.com/thomas-rasmussen/sas_macros
********************************************************************************
PARAMETERS:
*** REQUIRED ***
in_ds:      (libname.)member-name of input dataset with table data.     
out_ds:     (libname.)member-name of output dataset with masked table data.

*** OPTIONAL ***
class_vars: Space-separated list of class-variables. Each class variable must
            have a total/overall category identified with a missing/empty value.   
            Default is class_vars = null, ie no class variables. 
cnt_var:    Variable with counts to be masked.       
id_var:     Character variable with id-values identifying what
            variable/characteristic the count data corresponds to. 
            Default is id_var = __var.
value_var:  Character variable with variable value information 
            corresponding to the variable id's given in "id_var". For binary
            and continuous variable/characteristics, and the variable holding
            the "n" statistic information, value_var needs to take the same
            value as id_var. Categorical variables have multiple lines in the
            input dataset, and value_var needs to specify the category of the
            categorical variable.
            Default is value_var = __label.
n_value:    Quoted "id_var" value corresponding to the variable with
            the number of patients in the strata (defined by by- and 
            class-variables).
            Default is n_value = "__n".
cont_vars:  Space-separated list of quoted "id_var" values that corresponds
            to continuous variables that are not to be masked.
            Default is cont_vars = null, ie no variables.
where:      Condition used to to restrict the input dataset in a where-
            statement, eg where = %str(var = "value").  
by:         Space-separated list of by-variables. Default is by = null,
            ie no by variables. 
mask_min:   Minimum count value to mask. Must be a positve integer.
            Default is mask_min = 1. 
mask_max:   Maximum count value to mask. Must be a non-negative integer,
            with mask_min <= mask_max. Default is mask_max = 4. 
mask_avg:   Average to use in algorithm. Default is mask_avg = 1, ie if the
            mean value of the masked counts is less than or equal to 1, then
            an additional count is masked until the mean is larger than one.
mask_big:   Should large counts close to n_value also be considered person-
            sensitive, ie if count <= n_value - mask_max < count?
            - No: mask_big = n
            - Yes: mark_large = y (default)
ite_max:    Maximum number of masking algorithm iterations across the 
            classification variables before automatic termination )to avoid 
            infinite loop). Must be a positive integer.
            Default is ite_max = 20.
weighted:   Is the count data from a weighted population, ie should 
            non-integer counts be expected and allowed?
            - No: weighted = n (default)
            - Yes: weighted = y 
del:        Delete intermediate datasets created by the macro:
            - Yes: del = y (default)
            - no:  del = n              
******************************************************************************/
%macro mask_table(
  in_ds         = ,
  out_ds        = ,
  class_vars    = null,
  cnt_var       = __stat_num1,
  id_var        = __var,
  value_var     = __label,
  n_value       = "__n",
  cont_vars     = null,
  where         = %str(),
  by            = null, 
  mask_min      = 1,
  mask_max      = 4,
  mask_avg      = 1,
  mask_big      = y,
  ite_max       = 20,
  weighted      = n,
  del           = y
 ) / minoperator mindelimiter = ' ';

/*******************************************************************************
INPUT PARAMETER CHECKS 
*******************************************************************************/

%local  vars i i_var j j_var type ds_id rc cnt;

%let vars = 
  in_ds out_ds class_vars cnt_var id_var value_var n_value cont_vars where      
  by mask_min mask_max mask_avg mask_big ite_max weighted del;    

/* Check that none of the macro parameters are empty except possibly 
the "where" macro parameter. */
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %if (&i_var in where) = 0 and %sysevalf(&&&i_var = ) %then %do;
  %put ERROR: Macro parameter "&i_var" not specified!;
  %goto end_of_macro;    
  %end;
%end;

/* Remove single and double quotes from macro parameters where they are not 
supposed to be used, but might have been used anyway´. */
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %if (&i_var in where n_value cont_vars) = 0 %then %do;
    %let &i_var = %sysfunc(tranwrd(&&&i_var, %nrstr(%"), %str( )));
    %let &i_var = %sysfunc(tranwrd(&&&i_var, %nrstr(%'), %str( )));
  %end;
%end;

/* Make sure all relevant macro parameter values are in lowercase. */
%let vars = mask_big weighted del;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %let &i_var = %lowcase(&&&i_var);
%end;


/*** in_ds checks ***/

/* Check input dataset exists. */
%if %sysfunc(exist(&in_ds)) = 0 %then %do;
  %put ERROR: Specified input dataset "in_ds = &in_ds" does not exist!;
  %goto end_of_macro;
%end;

/* Check input dataset is not empty. */
%let ds_id = %sysfunc(open(&in_ds));
%if  %sysfunc(attrn(&ds_id, nobs)) = 0 %then %do;
  %let rc = %sysfunc(close(&ds_id));
  %put ERROR: Input dataset "in_ds = &in_ds" is empty!;
  %goto end_of_macro;
%end;
%let rc = %sysfunc(close(&ds_id));

/* Check that all specified variable names are valid, exists in the input
dataset, and that none of the specified variables have a "__mt_" prefix, a
prefix that is used throughout the macro for intermediate variables. */
%let vars = class_vars cnt_var id_var value_var by;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %do j = 1 %to %sysfunc(countw(&&&i_var, %str( )));
    %let j_var = %scan(&&&i_var, &j, %str( ));
    %if %sysfunc(nvalid(&j_var)) = 0 %then %do;
      %put ERROR: Variable "&j_var" specified in "&i_var = &&&i_var";
      %put ERROR: is not a valid SAS variable name!;
      %goto end_of_macro;
    %end;
    %if %lowcase(&j_var) ne null %then %do;
      %let ds_id = %sysfunc(open(&in_ds));
      %if %sysfunc(varnum(&ds_id, &j_var)) = 0 %then %do;
        %let rc = %sysfunc(close(&ds_id));
        %put ERROR: Variable "&j_var" specified in "&i_var = &&&i_var" does;
        %put ERROR: not exist in the input dataset "in_ds = &in_ds"!;
        %goto end_of_macro; 
      %end;
      %let rc = %sysfunc(close(&ds_id));
    %end;
    %if %eval(%qsubstr(&j_var dummy, 1, 2) = __mt_) %then %do;
      %put ERROR: Variable "&j_var" specified in "&i_var = &&&i_var" has a "__mt_" prefix;
      %put ERROR: This is not allowed to make sure that input variables are not;
      %put ERROR: overwritten by temporary variables created by the macro!;
      %goto end_of_macro; 
    %end;
  %end; /* End of j-loop */
%end; /*End of i-loop */



/*** class_vars checks ***/

/* Check that there are no duplicates in class_vars. */
%do i = 1 %to %sysfunc(countw(&class_vars, %str( )));
  %let i_var = %scan(&class_vars, &i, %str( ));
  %let cnt = 0;
  %do j = 1 %to %sysfunc(countw(&class_vars, %str( )));
    %if &i_var = %scan(&class_vars, &j, %str( )) 
      %then %let cnt = %eval(&cnt + 1);
  %end;
  %if %sysevalf(&cnt > 1) %then %do;
    %put ERROR: Variable "&i_var" is specified multiple times in "class_vars"!;
    %goto end_of_macro;
  %end;
%end;

/*** cnt_var checks ***/

/* Check that the specified variable is numeric. */
proc sql noprint;
  select type into :type
  from sashelp.vcolumn 
  where libname = "WORK" and memname = "%upcase(&in_ds)" and
    name = "&cnt_var";
quit;

%if &type = char %then %do;
  %put ERROR: Specified variable "cnt_var = &cnt_var" with counts;
  %put ERROR: needs to be a numeric variable!;
  %goto end_of_macro;
%end;

/*** id_var checks ***/

/* Check that the specified variable is character */
proc sql noprint;
  select type into :type
  from sashelp.vcolumn 
  where libname = "WORK" and memname = "%upcase(&in_ds)" and
    name = "&id_var";
quit;

%if %sysevalf(&type ne char) %then %do;
  %put ERROR: Specified variable "id_var = &id_var";
  %put ERROR: needs to be a character variable!;
  %goto end_of_macro;
%end;


/*** value_var checks ***/

/* Check that the specified variable is character */
proc sql noprint;
  select type into :type
  from sashelp.vcolumn 
  where libname = "WORK" and memname = "%upcase(&in_ds)" and
    name = "&value_var";
quit;

%if %sysevalf(&type ne char) %then %do;
  %put ERROR: Specified variable "value_var = &value_var";
  %put ERROR: needs to be a character variable!;
  %goto end_of_macro;
%end;


/*** n_value checks ***/

/* Check that a quoted string has been specified. */
%if %sysfunc(prxmatch('^".*"$', &n_value)) = 0 and
    %sysfunc(prxmatch("^'.*'$", &n_value)) = 0 %then %do;
  %put ERROR: "n_value" must be a quoted string!;
  %goto end_of_macro; 
%end;


/*** cont_vars checks ***/

/* Check that there are no duplicates in cont_vars. */
%do i = 1 %to %sysfunc(countw(&cont_vars, %str( )));
  %let i_var = %scan(&cont_vars, &i, %str( ));
  %let cnt = 0;
  %do j = 1 %to %sysfunc(countw(&cont_vars, %str( )));
    %if &i_var = %scan(&cont_vars, &j, %str( )) 
      %then %let cnt = %eval(&cnt + 1);
  %end;
  %if %sysevalf(&cnt > 1) %then %do;
    %put ERROR: Variable &i_var is specified multiple times in "cont_vars"!;
    %goto end_of_macro;
  %end;
%end;



/*** by checks ***/

/* Check that there are no duplicates in cont_vars. */
%do i = 1 %to %sysfunc(countw(&by, %str( )));
  %let i_var = %scan(&by, &i, %str( ));
  %let cnt = 0;
  %do j = 1 %to %sysfunc(countw(&by, %str( )));
    %if &i_var = %scan(&by, &j, %str( )) 
      %then %let cnt = %eval(&cnt + 1);
  %end;
  %if %sysevalf(&cnt > 1) %then %do;
    %put ERROR: Variable &i_var is specified multiple times in "by"!;
    %goto end_of_macro;
  %end;
%end;


/*** mask_min ***/

/* Check that "max_min" is specified as a positive integer.
Regular expression: Starts with a number 1-9, followed by, and ends with,
one or more digits (so that eg. 0 is not allowed, but 10 is)*/
%if %sysfunc(prxmatch('^[1-9]\d*$', &mask_min)) = 0 %then %do;
  %put ERROR: "max_min" must be a positive integer!;
  %goto end_of_macro; 
%end;



/*** mask_max ***/

/* Check that mask_max is corrrectly given as a non-negative integer. */
%if %sysfunc(prxmatch('^\d+$', &mask_max)) = 0 %then %do;
  %put ERROR: "mask_max" must be a non-negative integer!;
  %goto end_of_macro; 
%end;

/* Check that mask_min <= mask_max */
%if %sysevalf(&mask_min > &mask_max) %then %do;
  %put ERROR: mask_max < mask_min!;
  %goto end_of_macro; 
%end;


/*** mask_avg ***/

/* Check that mask_max is corrrectly given as a real number */
%if %sysfunc(prxmatch('^(-)*(0.)*\d+$', &mask_avg)) = 0 %then %do;
  %put ERROR: "mask_avg" must be a a real number!;
  %goto end_of_macro; 
%end;


/*** ite_max ***/

/* Check that "ite_max" is specified as a positive integer.
Regular expression: Starts with a number 1-9, followed by, and ends with,
one or more digits (so that eg. 0 is not allowed, but 10 is)*/
%if %sysfunc(prxmatch('^[1-9]\d*$', &ite_max)) = 0 %then %do;
  %put ERROR: "ite_max" must be a positive integer!;
  %goto end_of_macro; 
%end;


/*** Check that y/n macro parameters are specified correctly */
%let vars = mask_big weighted del;            
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %if %eval(&&&i_var in n y) = 0 %then %do;
    %put ERROR: "&i_var" does not have a valid value!;
    %goto end_of_macro;
  %end;
%end;


/*******************************************************************************
LOAD INPUT DATA
*******************************************************************************/

%local i i_var;

data __mt_data1;
  set &in_ds;
  where &where;
run;

/* If the specified where-condition results in any warnings or errors,
the macro is terminated. */
%if &syserr ne 0 %then %do;
  %put ERROR- The specified "where" condition:;
  %put ERROR- "where = &where";
  %put ERROR- produced a warning or an error. Macro terminated!;
  %goto end_of_macro; 
%end;

/* Rename by-variables to facilitate macro. */
data __mt_data2;
  set __mt_data1;
  %if %lowcase(&by) = null %then %do;
    __mt_by_1 = "null";
  %end;
  %else %do;
    rename 
    %do i = 1 %to %sysfunc(countw(&by, %str( )));
      %let i_var = %scan(&by, &i, %str( ));
      &i_var = __mt_by_&i
    %end;
    ;
  %end;
  %if %lowcase(&class_vars) = null %then %do;
    null = .;
  %end;
  rename 
    &cnt_var = __mt_cnt_var
    &id_var = __mt_var_id
    &value_var = __mt_var_value
  ;
  __mt_order = _n_; 
  __mt_cnt_masked = &cnt_var;
run;


/*******************************************************************************
MAKE NEW CLASSIFICATION VARIABLES
*******************************************************************************/

%local i i_var;
/* To facilitate the analysis we make a new set of classification variables */
%do i = 1 %to %sysfunc(countw(&class_vars, %str( )));
  %let i_var = %scan(&class_vars, &i, %str( ));
  proc sort data = __mt_data2(keep = &i_var) out = __mt_class_val1
      nodupkeys;
    by &i_var;
  run;

  data __mt_class_val2;
    set __mt_class_val1;
    if _n_ = 1 then __mt_class_&i = 0;
    __mt_class_&i + 1;
  run;

  proc sort data = __mt_data2;
    by &i_var;
  run;

  data __mt_data2;
    merge __mt_data2 __mt_class_val2;
    by &i_var;
    if missing(&i_var) then __mt_class_&i = .;
  run;
%end;



/* Restrict to the specified variable values */
data __mt_data3;
  set __mt_data2;
  %if %lowcase(&cont_vars) ne null %then %do;
    where __mt_var_id not in (&cont_vars);
  %end;
run;


/* Merge number of patients in each strata to data */
proc sort data = __mt_data3(where = (__mt_var_id = &n_value)) 
    out = __mt_n_values nodupkeys;
  by __mt_by_: __mt_class_:;
run;

proc sql;
  create table __mt_data4 as
    select a.*, b.__mt_cnt_var as __mt_n
      from __mt_data3 as a
      left join 
      __mt_n_values as b
      on 
      %do i = 1 %to %sysfunc(countw(&by, %str( )));
        a.__mt_by_&i = b.__mt_by_&i and
      %end; 
      %do i = 1 %to %sysfunc(countw(&class_vars, %str( )));
        a.__mt_class_&i = b.__mt_class_&i 
        %if &i ne %sysfunc(countw(&class_vars, %str( ))) %then %do; and %end;
      %end; 
      order by a.__mt_order;
quit;



/*******************************************************************************
CHECK DATA
*******************************************************************************/
%local check_cnt check_int check_miss_cat check_sum i i_var var_type;

/* Check if counts are integers. */
data __mt_check_int1;
  set __mt_data4;
  if __mt_cnt_var ne . then do;
    if int(__mt_cnt_var) ne __mt_cnt_var then output;
  end;
run;

proc sql noprint;
  select count(*)
    into :check_int
    from __mt_check_int1;
quit;

%if &check_int > 0 and &weighted = n %then %do;
  %put ERROR: One or more count value is not an integer!;
  %put ERROR: If the table includes continuous variables use "cont_vars" to;
  %put ERROR: specify them. If the aggregated counts are from a weighted;
  %put ERROR: population, specify using "weighted = y";
  %goto end_of_macro;
%end;


/* Check that counts are valid, ie should be between 0 and n in each strata,
or be missing, eg a title line from the pt_char output. */
data __mt_check_cnt1;
  set __mt_data4;
  where ^(0 <= __mt_cnt_var <= __mt_n or __mt_cnt_var = .);
run;

proc sql noprint;
  select count(*)
    into :check_cnt
    from __mt_check_cnt1;
quit;

%if &check_cnt > 0 %then %do;
  %put ERROR: One or more "&cnt_var" values are negative or larger than the;
  %put ERROR: total number of patients in that strata!;
  %goto end_of_macro;
%end;

/*** Classification variables are supposed to have missing values
with total counts. Check that the variables do indeed have missing
values. ***/
%if %lowcase(&class_vars) ne null %then %do;
  %do i = 1 %to %sysfunc(countw(&class_vars, %str( )));
    %let check_miss_cat = ;
    %let i_var = %scan(&class_vars, &i, %str( ));
    proc sql noprint;
      select count(*) into :check_miss_cat
      from __mt_data4(where = (__mt_class_&i = .));
    quit;
    %if &check_miss_cat = 0 %then %do;
      %put ERROR: Specified classification variable "&i_var" does not have;
      %put ERROR: an empty/missing value, supposed to indicate total/overall ocounts!;
      %goto end_of_macro;
    %end;
  %end; /* End of i-loop */
%end; 


/* To make a crude assessment of whether or not the total counts are actually
that or something else entirely, we check that the total counts corresponds to 
the sum of the strata counts for each classification variable. */
%if %lowcase(&class_vars) ne null %then %do;
  proc means data = __mt_data4(where = (
      %do i = 1 %to %sysfunc(countw(&class_vars, %str( )));
        %if &i ne 1 %then %do; and %end;
        __mt_class_&i = .
      %end;
      )) 
      nway missing noprint;
    class __mt_by_: __mt_var_id;
    output out = __mt_sum_total(drop = _type_ _freq_)
      sum(__mt_cnt_var) = __mt_sum_total
      / noinherit;
  run;

  proc means data = __mt_data4(where = (
      %do i = 1 %to %sysfunc(countw(&class_vars, %str( )));
        %if &i ne 1 %then %do; and %end;
        __mt_class_&i ne .
      %end;
      )) 
      nway missing noprint;
    class __mt_by_: __mt_var_id;
    output out = __mt_sum_strata(drop = _type_ _freq_) 
      sum(__mt_cnt_var) = __mt_sum_strata
      / noinherit;
  run;

  data __mt_check_sums1;
    merge __mt_sum_total __mt_sum_strata;
    by __mt_by_: __mt_var_id;
    if __mt_sum_total ne __mt_sum_strata;
  run;

  proc sql noprint;
    select count(*) 
    into :check_sum
    from __mt_check_sums1;
  quit;

  %if %sysevalf(&check_sum > 0) %then %do;
    %put ERROR: The sum of some strata counts does not add up to the;
    %put ERROR: specified total counts!;
    %goto end_of_macro;
  %end;
%end; 

/*******************************************************************************
RESTRUCTURE DATA
*******************************************************************************/

/* Determine how many data lines each variable id has in each
by and class strata, to identify binary variables and categorical variables
with only one value, for which we will create a complementary category that
will help facilitate the analysis. */

/* Exclude missing count from eg title lines for categorical variables. */
proc sort data = __mt_data4(where = (__mt_cnt_var ne .)) out = __mt_lines1;
  by __mt_by_: __mt_class_: __mt_var_id;
run;

data __mt_lines2;
  set __mt_lines1;
  by __mt_by_: __mt_class_: __mt_var_id;
  retain __mt_cnt_lines;
  if first.__mt_var_id then do;
    __mt_cnt_lines = 0;
  end;
  __mt_cnt_lines = __mt_cnt_lines + 1;
run;

proc sort data = __mt_lines2 out = __mt_lines3;
  by __mt_by_: __mt_class_: __mt_var_id descending __mt_cnt_lines;
run;

data __mt_lines4;
  set __mt_lines3;
  by __mt_by_: __mt_class_: __mt_var_id;
  if first.__mt_var_id;
  keep __mt_by_: __mt_class_: __mt_var_id __mt_cnt_lines;
run;

proc means data = __mt_lines4 missing nway noprint;
  class __mt_var_id;
  output out = __mt_lines5
    min(__mt_cnt_lines) = __mt_min max(__mt_cnt_lines) = __mt_max
    / noinherit;
run;


/*
If the number is not the same in all by and class stratas, throw an error
since this irregular behavior makes things problematic? Implement later, but
use data step approach to solve this that can easily be modified later. */

proc sql noprint;
  select count(*)
    into :check_lines
    from __mt_lines5(where =(__mt_min ne __mt_max));
quit;

%if &check_cnt > 0 %then %do;
  %put ERROR: One or more variables in "&id_var" has an irregular number of values;
  %put ERROR: in stratas defined by by- and class-variables!;
  %goto end_of_macro;
%end;


/* Merge line info to data */
proc sql;
  create table __mt_data5 as
    select a.*, b.__mt_min as __mt_cnt_lines
    from __mt_data4 as a
    left join
    __mt_lines5 as b
    on a.__mt_var_id = b.__mt_var_id
    order by __mt_order;
quit;


/* 
Include data-lines for the complement of binary variables using the &n_label variable.
(We need the &n_label var so that we can also censor numbers that are too close to
n ). We can keep the empty title lines for the cat variable, they wont affect the
algorithm */

data __mt_data6;
  set __mt_data5;
  if __mt_cnt_lines = 1 and __mt_var_id ne &n_value then do;
    __mt_var_value = compress(__mt_var_id) ||": 1"; 
    __mt_cnt_masked = __mt_cnt_var; 
    __mt_dummy = 0;
    output;
    __mt_var_value = compress(__mt_var_id) ||": 0";  
    __mt_cnt_var = __mt_n - __mt_cnt_var; 
    __mt_cnt_masked = __mt_cnt_var; 
    __mt_dummy = 1;
    output;
  end;
  else do; 
    __mt_cnt_masked = __mt_cnt_var; 
    output; 
  end;
  drop __mt_cnt_lines;
run;


/*******************************************************************************
MASK
*******************************************************************************/

%local i ite_class_vars masked_class masked_any ite_cnt ite_class;

/* Make macro variables with class variables and also include __mt_var_value */
%let ite_class_vars = __mt_var_value;
%do i = 1 %to %sysfunc(countw(&class_vars, %str( )));
  %let ite_class_vars = &ite_class_vars __mt_class_&i;
%end;

%let masked_class = 0;
%let masked_any = 0;
%let ite_cnt = 0;

%let ite_class =  %scan(&ite_class_vars, 1, %str( ));

%do %until (
  &masked_any = 0 and 
  &ite_cnt > %sysfunc(countw(&ite_class_vars, %str( ))) and
  &ite_class = %scan(&ite_class_vars, 1, %str( ))
  );
  %let ite_cnt = %eval(&ite_cnt + 1);

  %if &ite_class = %scan(&ite_class_vars, 1, %str( ))
    %then %let masked_any = 0;
  %let masked_class = 0;

/*  %put ite_class: &ite_class;*/
/*  %put ite_cnt: &ite_cnt;*/
/*  %put masked_any: &masked_any;*/
/*  %put masked_class: &masked_class;*/

  proc sort data = __mt_data6;
   by __mt_by_: __mt_var_id &ite_class __mt_cnt_masked; 
  run;
   
  data __mt_data6(drop = __mt_sup_n __mt_sup_sum __mt_avg_flg); 
    set __mt_data6; 
    by __mt_by_: __mt_var_id &ite_class __mt_cnt_masked; 

    /* initialize number and sum of masked cells */ 
    retain __mt_sup_n __mt_sup_sum;
    if first.&ite_class then do; 
      __mt_sup_n = 0; 
      __mt_sup_sum = 0; 
    end; 

    /* enhanced suppression flag */ 
    if __mt_sup_n ne 0 then __mt_avg_flg = (__mt_sup_sum /__mt_sup_n <= &mask_avg); 

    /* apply suppression criteria */       
    if &mask_min <= __mt_cnt_masked and 
      (__mt_cnt_masked <= &mask_max or __mt_sup_n = 1 or __mt_avg_flg) then do; 
      __mt_cnt_masked = .m;
      call symputx('masked_class', 1); 
    end; 
    if __mt_cnt_masked = .m then do; 
      /* increment number and sum of masked cells */ 
      __mt_sup_n = __mt_sup_n + 1; 
      __mt_sup_sum = __mt_sup_sum + __mt_cnt_var; 
    end; 
  run; 

  %if &masked_class = 1 %then %let masked_any = 1;

  /* Choose next classification variable */
  %let current_class = &ite_class;
  %do i = 1 %to %sysfunc(countw(&ite_class_vars, %str( )));
    %let i_var = %scan(&ite_class_vars, &i, %str( ));
    %if &i_var = &current_class %then %do;
      %if %sysevalf(&i ne %sysfunc(countw(&ite_class_vars, %str( )))) %then %do;
        %let ite_class = %scan(&ite_class_vars, %eval(&i +1), %str( ));
      %end;
      %else %do;
        %let ite_class = %scan(&ite_class_vars, 1, %str( ));
      %end;
    %end;
  %end;

  %if %sysevalf(&ite_cnt >= &ite_max) %then %do;
    %let masked_any = 0;
    %put ERROR: Algorithm stopped after &ite_max iterations to avoid infinite loop.;
    %put ERROR: Change "ite_max" if necesary;
  %end;
%end; /* end of while-loop */


data __mt_data7;
  set __mt_data6;
  /* Remove dummy datalines for binary variables and revert the changes
  made to __mt_var_value. */
  if __mt_dummy = 1 then delete;
  if __mt_dummy = 0 then __mt_var_value = __mt_var_id;
  drop __mt_dummy;
run;


/*******************************************************************************
PRIMARY SUPPRESSING LARGE NUMBERS
*******************************************************************************/

/* Primary suppression of cells with counts larger than or equal to n - &mask_max. 
We only need primary suppressing for this since it is done last. Because of
the inclusion of "dummy" categories for binary variables, we have already done
this for binary variables. 

The &n_label variable is a special case where suppressing is not applied. Is there
a more natural way to do this ?*/

%if &mask_big = y %then %do;
  data __mt_data7;
    set __mt_data7;
    if __mt_var_id ne &n_value and __mt_n - &mask_max <= __mt_cnt_masked < __mt_n 
      then __mt_cnt_masked = .m;
  run;
%end;

/*******************************************************************************
RESTRUCTURE
*******************************************************************************/


/* Merge to input data */
proc sql;
  create table __mt_data8 as
    select a.*, b.__mt_cnt_masked
    from __mt_data2(drop = __mt_cnt_masked) as a
    left join 
    __mt_data7 as b
    on 
    %do i = 1 %to %sysfunc(countw(&by, %str( )));
      a.__mt_by_&i = b.__mt_by_&i and
    %end; 
    %do i = 1 %to %sysfunc(countw(&class_vars, %str( )));
      a.__mt_class_&i = b.__mt_class_&i and
    %end; 
      a.__mt_var_value = b.__mt_var_value
    order by __mt_order;
quit;

data __mt_data9;
  set __mt_data8;
  if __mt_cnt_var ne . and __mt_cnt_masked = . then __mt_cnt_masked = __mt_cnt_var;
  drop __mt_order;
  %if %lowcase(&by) = null %then %do;
    drop __mt_by_1;
  %end;
run;

data &out_ds;
  set __mt_data9(drop = __mt_cnt_var);
  %if %lowcase(&by) ne null %then %do;
    rename 
      %do i = 1 %to %sysfunc(countw(&by, %str( )));
        %let i_var = %scan(&by, &i, %str( ));
        __mt_by_&i = &i_var
      %end;
      ;
  %end;
  rename
    __mt_cnt_masked = &cnt_var 
    __mt_var_id = &id_var
    __mt_var_value = &value_var
  ;
  %if %lowcase(&class_vars) = null %then %do;
    drop null;
  %end;
  drop __mt_class_:;
run;


%end_of_macro:

/* Delete temporary datasets created by the macro, also when 
"del" has not be specified as either y or n. */
%if &del ne n  %then %do;
  proc datasets nodetails nolist;
    delete __mt_:;
  run;
  quit;
%end;
 
%mend mask_table;




