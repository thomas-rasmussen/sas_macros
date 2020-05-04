/* Source population with the following variables:
id - unique person id.
birth_year - matching variable
male - matching variable
fu_start - start of follow-up. Maximum of start of study, birth/immigration etc.
fu_end - End of follow-up. Minimum of end of study, death, censoring event, emigration etc.
diag_date - date of diagnosis. Person becomes cases at diagnosis date
add_var1 - Additional variable
pop_id - Variable indicating what sub-population the person belongs to. 
*/
data sourcepop;
  call streaminit(1);
  format id $12. diag_date fu_start fu_end date9.;
  do i = 1 to 10 ** 5;
    id = compress(put(i, z12.)); 
    birth_year = put(1980 + round(rand("uniform") * 10), 4.);
    male = rand("bernoulli", 0.5);
    fu_start = mdy(1, 1, 2000) + round(rand("normal", 0, 1000));
    fu_end = fu_start + round(rand("uniform") * 10000);
    if rand("uniform") < 0.01 then do;
      diag_date = fu_start + (fu_end - fu_start) / 2;
    end;
    else do;
      diag_date = .;
    end;
    add_var1 = rand("bernoulli", 0.5);
    pop_id = rand("bernoulli", 0.2);
    output;
  end;
  drop i;
run;

/* Finding matches for each case. The matching date is the day the case became a case.
Matching is done on birth-year and sex. Cases an be used as controls for other cases, 
if they are "diagnosis-free" at the time of matching. */
%hash_match(
  in_ds       = sourcepop,
  out_pf      = matched_pop,
  id_var      = id,
  index_var   = diag_date,
  fu_start    = fu_start,
  fu_end      = fu_end,
  match_vars  = birth_year male,
  seed        = 1234
);

/* Example using some additional optional macro parameters:
- Using keep_add_vars to keep the unused variable add_var1 in
  the output dataset.
- Use replace = n to match without replacement.
- Use n_controls = 5 to specify that we want to find 5 controls
  for each case instead of 10 (the default value). 
- Use by = pop_id to do the matching separately for each value
  of pop_id.
*/
%hash_match(
  in_ds         = sourcepop,
  out_pf        = matched_pop,
  id_var        = id,
  index_var     = diag_date,
  fu_start      = fu_start,
  fu_end        = fu_end,
  match_vars    = birth_year male,
  n_controls    = 5,
  replace       = n,
  by            = pop_id,
  keep_add_vars = add_var1,
  seed          = 1234
);

