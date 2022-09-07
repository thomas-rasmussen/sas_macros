/*******************************************************************************
SIMULATE DATA
*******************************************************************************/

/* Simulate source population with the following variables:
pop:          Sub-population the person belongs to
id:           Person ID
index_date:   Index date. The day the person becomes a case, and we want to 
              find a set of matched controls.
fu_start:     Start of follow-up. Maximum of start of study, birth, immigration 
              etc.
fu_end:       End of follow-up. Minimum of end of study, death, censoring event, 
              emigration etc.
birth_year:   Birth year
male:         Male (1 = yes)
disease_date: Date of diagnosis of a certain disease/outcome
cat_var:      Categorical auxiliary variable
*/

data sourcepop;
  call streaminit(1);
  format pop $1. id $8. index_date fu_start fu_stop date9.
         birth_year $4. male 1. disease_date date9. cat_var 1.;
  do i = 1 to 10 ** 4;
    pop = put(round(rand("uniform") * 3), 1.);
    id = compress(put(i, z8.)); 
    index_date = mdy(1, 1, 2000) + round(rand("uniform")* 5000);
    fu_start = index_date - round(rand("uniform")* 1000);
    fu_stop = index_date + round(rand("uniform")* 1000);
    birth_year = put(1915 + round(rand("uniform") * 100), 4.);
    male = rand("bernoulli", 0.5);
    disease_date = min(index_date + round(rand("uniform") * 500), fu_stop);
    if rand("uniform") < 0.5 then disease_date = .;
    if rand("uniform") < 0.9 then index_date = .;
    cat_var = rand("binomial", 0.5 , 2);
    output;
  end;
  drop i;
run;
    
 
/*******************************************************************************
SIMPLE EXAMPLE
*******************************************************************************/

/* The macro only requires specification of 1) an input source population,
2) a prefix for the output datasets that are generated, and 3) a numerical 
variable giving the time, if any, at which the person is matched to a set of 
controls from the source population. This simplest form of matching is unlikely 
to be useful in practice, but is just to illustrate the minimum of input the 
macro needs. */
%hash_match(
  in_ds = sourcepop,
  out_pf = simple,
  match_date = index_date,
  seed = 1
);

/* Note that the output datasets does not include unused variables from the
input dataset by default (see keep_add_vars parameter), so the amount of 
variables in the matched dataset is sparse in this simple example. */


/*******************************************************************************
STANDARD USE
*******************************************************************************/

/* Usually, exact matching is desired on one or more variables, eg. gender. 
Furthermore, different inexact matching criterias are also common eg: 
- A case can't be its own control.
- Controls most be under follow-up at the time of matching.
- A case can be a control until he/she becomes a case, but can not
  be a control after becoming a case.
- Controls must be "disease/outcome-free" at the time of matching.
Finally it is considered good practice to set a seed for the random number 
generator so that the matched population is reproducible.

Such standard matching conditions can be specified using the match_exact and 
match_inexact parameters. Variables on which exact matching is done is
given as a space-separated list. Inexact matching conditions are 
given as a masked character string. The matching is done with a hash-table merge,
where the cases are in a dataset, and the potential controls are stored in a
hash-table, where all variables are given a "_ctrl_" prefix (Think of it as a
normal merge of two datasets in a data-step). Comparison of case and control 
values can now be done as shown in the macro call below: */
%hash_match(
  in_ds = sourcepop,
  out_pf = standard,
  match_date = index_date,
  match_exact = male,
  match_inexact = %str(
      id ne _ctrl_id
      and _ctrl_fu_start <= index_date <= _ctrl_fu_stop
      and (_ctrl_index_date > index_date or _ctrl_index_date = .)
      and (_ctrl_disease_date > index_date or _ctrl_disease_date = .)
    ),
  seed = 1
);

/* Note that all the variables we are using are included in output dataset
with the matched population. */

/* We should always check that the matching criterias are acutally
fulfilled in the matched population. */
data standard_check1;
  set standard_matches;
  by __match_id;
  retain
    case_male case_id case_index_date case_fu_start case_fu_stop 
    case_disease_date
    fail_male fail_id fail_fu fail_not_case fail_not_diseased;
  if first.__match_id then do;
    /* Retain case variable values */
    case_male = male;
    case_id = id;
    case_index_date = index_date;
    case_fu_start = fu_start;
    case_fu_stop = fu_stop;
    case_disease_date = disease_date;
    /* Reset number of failed conditions */
    fail_male = 0;
    fail_id = 0;
    fail_fu = 0;
    fail_not_case = 0;
    fail_not_diseased = 0;
  end;
  else do;
    if case_male ne male then fail_male = 1;
    if case_id = id then fail_id = 1;
    if (fu_start <= case_index_date <= fu_stop) = 0 then fail_fu = 1;
    if (index_date > case_index_date or index_date = .) = 0
      then fail_not_case = 1;
    if (disease_date > case_index_date or disease_date = .) = 0
      then fail_not_diseased = 1;
  end;
  if last.__match_id;
  keep fail_:;
run;

proc means data = standard_check1 sum;
  var fail_:;
run;

/*
        The MEANS Procedure

 Variable                      Sum

 fail_male                       0
 fail_id                         0
 fail_fu                         0
 fail_not_case                   0
 fail_not_diseased               0
 

*/


/*******************************************************************************
ADVANCED USE
*******************************************************************************/

/* We will build on the previous example by modifying some additional 
parameters in the macro: 
- Select 5 instead of 10 control using the n_control parameter
- Do matching without replacement by setting replace = n
- Keep the unused auxiliary variable cat_var from the input dataset that is
  not used in the matching using the keep_add_vars parameter.
- Do matching in subpopulations defined by the pop variable, using the by 
  parameter. */
%hash_match(
  in_ds = sourcepop,
  out_pf = advanced,
  match_date = index_date,
  match_exact = male,
  match_inexact = %str(
      id ne _ctrl_id
      and _ctrl_fu_start <= index_date <= _ctrl_fu_stop
      and (_ctrl_index_date > index_date or _ctrl_index_date = .)
      and (_ctrl_disease_date > index_date or _ctrl_disease_date = .)
    ),
  n_controls = 5,
  replace = n,
  keep_add_vars = cat_var,
  by = pop,
  seed = 1
);


/*******************************************************************************
MATCHING ON CHARLSON COMORBIDITY INDEX (CCI)
*******************************************************************************/

/* Matching on disease scores like the CCI is commonly done in an attempt to
match patients with the same level of comorbidity. The CCI summarizes
comorbidities of a patient into a single score, typically categorized as
0/1-2/+3. The CCI is not time-invariant like birth year or sex, but changes over
time as the patient's comorbidities changes. This makes the CCI more complicated
to match on, since it has to be recalculated every time a control is evaluated
as a match, since the matching/index date is different for each case. Furthermore,
the CCI is sometimes defined using a moving time window, eg a fixed lookback
period of 10 years, making the matching even more complicated. For more
information on the implementation of the CCI, see the calculate_cci macro.

Here we will show how extensive use of inexact matching conditions, can be
used to match on the CCI in the special case where we use all comorbidity
data on patients, not only data in a fixed period before the index date. In this
scenario the situation is a little more simple as we only need to know the first
date (if any) of any relevant dianoses used in the CCI definition, to be able to
define the CCI on any given date.

Extensive use of inexact matching conditions is likely to make the macro
perform poorly, ie it will take many attempts to find valid matches among
potential controls. Although, small amounts of anecdotal evidence indicates that
alternative approaches where all potential controls are first identified for each
case, and then the CCI is calculated for each potential control before the final
controls are picked, are still way less efficient.

Matching is done by calculating the CCI on the index date for cases, and 
by building a complex inexact matching condition that calculates the CCI for
potential controls on the fly, at the time of evaluating the matching criterias
for a specific case with a specific index date. */


/* CCI definition used in data steps based on dichotomized diagnosis
dates (does the patient have the disease yes/no) to simplify the
expression. The dichotomomized variables are defined in the data step
beforehand. */
%let cci_def = %str(
  1*(cci_01_1 + cci_01_2 + cci_01_3 + cci_01_4 + cci_01_5 + cci_01_6 +
     cci_01_7 + cci_01_8 +
     (1 - cci_01_17)*cci_01_9 +
     (1 - cci_01_13)*cci_01_10
    ) +
  2*(cci_01_11 + cci_01_12 + cci_01_13 +
     (1 - cci_01_18)*cci_01_14 +
     cci_01_15 + cci_01_16
    ) +
  3*(cci_01_17) +
  6*(cci_01_18 + cci_01_19)
);
%put &cci_def;

/* CCI matching expression used in hash_match macro call. Notice that 
we are comparing diagnosis dates on the controls (variables have a
_ctrl_ prefix) with the index date of the case. */
%let cci_exp = %str(
  1*(
      (. < _ctrl_cci_1 < index_date) + (. < _ctrl_cci_2 < index_date) +
      (. < _ctrl_cci_3 < index_date) + (. < _ctrl_cci_4 < index_date) +
      (. < _ctrl_cci_5 < index_date) + (. < _ctrl_cci_6 < index_date) +
      (. < _ctrl_cci_7 < index_date) + (. < _ctrl_cci_8 < index_date) +
      (1 - (. < _ctrl_cci_17 < index_date))*(. < _ctrl_cci_9 < index_date) +
      (1 - (. < _ctrl_cci_13 < index_date))*(. < _ctrl_cci_10 < index_date)
     ) +
  2*(
      (. < _ctrl_cci_11 < index_date) + (. < _ctrl_cci_12 < index_date) +
      (. < _ctrl_cci_13 < index_date) +
      (1 - (. < _ctrl_cci_18 < index_date))*(. < _ctrl_cci_14 < index_date) +
      (. < _ctrl_cci_15 < index_date) + (. < _ctrl_cci_16 < index_date)
    ) +
  3*((. < _ctrl_cci_17 < index_date)) +
  6*((. < _ctrl_cci_18 < index_date) + (. < _ctrl_cci_19 < index_date))
);
%let cci_exp = %str(0*(&cci_exp = 0) + 1*(1 <= &cci_exp <= 2) + 2*(&cci_exp >= 3));
%put &cci_exp;

/* Add first-ever diagnoses of each of the 19 disease groups included in
the CCI to the data for each id. Based on this we calculate the CCI on the
index date for cases. */
%macro _sim_data;
data dat_cci;
  /* reorder columns */
  retain id index_date cci cci_g;
  set sourcepop;
  call streaminit(123);

  cci = .;
  cci_g = .;
  %do i = 1 %to 19;
    format cci_&i yymmdd10.;
    cci_&i = fu_start + round(rand("uniform") * 1000);
    cci_01_&i = (. < cci_&i < index_date);
    if rand("uniform") > 0.1 then do;
      cci_&i = .;
      cci_01_&i = 0;
    end;
  %end;
  if index_date ne . then do;
    cci = &cci_def;
    if cci = 0 then cci_g = 0;
    else if 1 <= cci <= 2 then cci_g = 1;
    else if cci >= 3 then cci_g = 2;
  end;
  drop cci_01:;
  keep id index_date cci:;
run;
%mend _sim_data;
%_sim_data;

/* Match on CCI */
%hash_match(
  in_ds = dat_cci,
  out_pf = cci,
  match_date = index_date,
  match_inexact = %str(id ne _ctrl_id and &cci_exp = cci_g),
  n_controls = 10,
  seed = 1
);

/* (Re)calculate/update cci and cci_g to the matching date, and check that we
have indeed succesfully matched on grouped cci. */
%macro _assess_match;
data cci_check1;
  retain __match_id id __case cci cci_g case_cci_g;
  set cci_matches;
  by __match_id;
  if first.__match_id then do;
    case_cci_g = cci_g;
  end;
  %do i = 1 %to 19;
    cci_01_&i = (. < cci_&i < __match_date);
  %end;
  cci = &cci_def;
  if cci = 0 then cci_g = 0;
  else if 1 <= cci <= 2 then cci_g = 1;
  else if cci >= 3 then cci_g = 2;
  fail_cci = (case_cci_g ne cci_g);
  drop cci_01: case_cci_g;
run;
%mend _assess_match;
%_assess_match;

proc means data = cci_check1 sum;
  var fail_cci;
run;

/*
The MEANS Procedure

Analysis Variable : fail_cci

                 Sum
                   0

*/


/*******************************************************************************
TALES OF CAUTION
*******************************************************************************/

/* The match_inexact parameter is very flexible, but at the same time it is
unfortunately very easy to make mistakes that does not result in a warning or 
an error! Look a the standard example from above but with a slight misspelling
of _ctrl_fu_start as _ctrl_fu_starts. */
%hash_match(
  in_ds = sourcepop,
  out_pf = misspell,
  match_date = index_date,
  match_exact = male,
  match_inexact = %str(
      id ne _ctrl_id
      and _ctrl_fu_starts <= index_date <= _ctrl_fu_stop
      and (_ctrl_index_date > index_date or _ctrl_index_date = .)
      and (_ctrl_disease_date > index_date or _ctrl_disease_date = .)
    ),
  seed = 1
);

/* No warning or error was produced by the macro informing us that we have 
specified a variable that does not exist in the data. What has happend is that 
a _ctrl_fu_starts variable has been created in the hash-table that always has a 
missing value, making the _ctrl_fu_starts <= index_date condition always true. */

/* If we check whether or not the matching conditions are fullfilled in the
matched data, as we should, we can also easily see that the matching
criterias are not working as intended. */
data misspell_check1;
  set misspell_matches;
  by __match_id;
  retain
    case_male case_id case_index_date case_fu_start case_fu_stop 
    case_disease_date
    fail_male fail_id fail_fu fail_not_case fail_not_diseased;
  if first.__match_id then do;
    /* Retain case variable values */
    case_male = male;
    case_id = id;
    case_index_date = index_date;
    case_fu_start = fu_start;
    case_fu_stop = fu_stop;
    case_disease_date = disease_date;
    /* Reset number of failed conditions */
    fail_male = 0;
    fail_id = 0;
    fail_fu = 0;
    fail_not_case = 0;
    fail_not_diseased = 0;
  end;
  else do;
    if case_male ne male then fail_male = 1;
    if case_id = id then fail_id = 1;
    if (fu_start <= case_index_date <= fu_stop) = 0 then fail_fu = 1;
    if (index_date > case_index_date or index_date = .) = 0
      then fail_not_case = 1;
    if (disease_date > case_index_date or disease_date = .) = 0
      then fail_not_diseased = 1;
  end;
  if last.__match_id;
  keep fail_:;
run;

proc means data = misspell_check1 sum;
  var fail_:;
run;

/*
        The MEANS Procedure

 Variable                      Sum
 
 fail_male                       0
 fail_id                         0
 fail_fu               935.0000000
 fail_not_case                   0
 fail_not_diseased               0
 
*/


/* Alternatively a misspelling can result in a condition that is always false.
This will most likely result in the macro taking a very long time to execute
since we are using the maximum amount of tries to find controls for each case
bofore giving up. For example, imagine that we accidentally wrote _ctrl_fu_end 
instead of _ctrl_fu_stop (actually happened while making these examples....). 
The index_date <= _ctrl_fu_end condition would always be false, since index_date 
is never missing for cases and _ctrl_fu_end is always missing (since the 
variable is not in the data and is created by the hash-table and set to missing
as before). We use the max_tries parameter here to limit the amount of tries 
we make before giving up, so that the macro call does not take too long.
*/
%hash_match(
  in_ds = sourcepop,
  out_pf = always_false,
  match_date = index_date,
  match_exact = male,
  match_inexact = %str(
      id ne _ctrl_id
      and _ctrl_fu_start <= index_date <= _ctrl_fu_end
      and (_ctrl_index_date > index_date or _ctrl_index_date = .)
      and (_ctrl_disease_date > index_date or _ctrl_disease_date = .)
    ),
  max_tries = 1000,
  seed = 1
);

/* We can see that the matched dataset is empty, that all the cases are
instead included in the dataset with cases with incomplete controls,
and in the dataset with matching info we can see that zero controls
was found for all cases. 

If the log does not show any, or only very slow progress of the matching,
consider if something is wrong. */


/* If a logical operator is misspelled the macro should terminate with 
an error. */
%hash_match(
  in_ds = sourcepop,
  out_pf = error,
  match_date = index_date,
  match_exact = male,
  match_inexact = %str(
      id net _ctrl_id
      and _ctrl_fu_start <= index_date <= _ctrl_fu_stop
      and (_ctrl_index_date > index_date or _ctrl_index_date = .)
      and (_ctrl_disease_date > index_date or _ctrl_disease_date = .)
    ),
  seed = 1
);
