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
  match_date = index_date
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
where the cases are in a dataset, and the potential controls are stored in the
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

/* Looking at the output we can see that the fu_start <= index_date condition
does not hold as intended, and no warning or error was produced by the macro
informing us that we have specified a variable that does not exist in the data.
What has happend is that a _ctrl_fu_starts variable has been created in the 
hash-table that always has a missing value, making the 
_ctrl_fu_starts <= index_date condition always true. 

Always check that the matching was done as intended. */


/* Alternatively a misspelling can result in a condition that is always false.
This will most likely result in the macro taking a very long time to execute
since we are using the maximum amount of tries to find controls for each case
bofore giving up. For example imagine that we accidentally wrote _ctrl_fu_end 
instead of _ctrl_fu_stop (actually happened while making these examples....). 
The index_date <= _ctrl_fu_end condition would always be false, since index_date 
is never missing for cases and _ctrl_fu_end is always missing (since the 
variable is not in the data and is created by the hash-table and set to missing
as before). We use the limit_tries parameter here to limit the amount of tries 
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
  limit_tries = 1000,
  seed = 1
);

/* We can see that the matched dataset is empty, that all the cases are
instead included in the dataset with cases with incomplete controls,
and in the dataset with matching info we can see that zero controls
was found for all cases. 

If the log does not show any or only very slow progress of the matching,
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
