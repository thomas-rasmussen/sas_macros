/* Source population with the following variables:
id - person id.
birth_year - matching variable
male - matching variable
fu_start - start of follow-up. Maximum of start of study, birth/immigration etc.
fu_end - End of follow-up. Minimum of end of study, death, censoring event, emigration etc.
diag_date - date of diagnosis. Person becomes cases at diagnosis date.
*/
data sourcepop;
  call streaminit(1);
  format id $12. diag_date fu_start fu_end date9.;
  do i = 1 to 10 ** 6;
    id = compress(put(i, z12.)); 
    birth_year = put(1900 + round(rand("uniform") * 100), 4.);
    male = rand("bernoulli", 0.5);
    fu_start = mdy(1, 1, 1990) + round(rand("normal", 0, 1000));
    fu_end = fu_start + round(rand("uniform") * 10000);
    if rand("uniform") < 0.10 then do;
      diag_date = fu_start + (fu_end - fu_start) / 2;
    end;
    else do;
      diag_date = .;
    end;
    output;
  end;
  drop i;
run;

/* Matching on birth-year and sex. Cases an be used as controls for other cases, 
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
