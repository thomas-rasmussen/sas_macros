
/*
TODO:
- make examples showing that "incidence" "prevalence" and "case control" matching
can be done with the macro. 
- Make example to show performance when there are not valid controls
  among the potential matches. Maybe under tests.
*/

/* source population with diagnosis date, if any, on all patients. 
fu_start and fu_end is the start and end date of follow-up for each 
person, eg fu_end should include end of study period and any diagnoses
that disqualifies the person as being a case/ control. */
data data1;
  call streaminit(1234);
  format pnr $12. diag_date fu_start fu_end date9.;
  do i = 1 to 10 ** 5;
    pnr = compress(put(i, z12.)); 
    birth_year = put(1900 + round(rand("uniform") * 10), 4.);
    male = rand("bernoulli", 0.5);
    if rand("uniform") < 0.01 then do;
      diag_date = mdy(1, 1, 2000) + round(rand("normal", 0, 1000));
    end;
    else do;
      diag_date = .;
    end;
    fu_start = mdy(1, 1, 1990) + round(rand("normal", 0, 1000));
    fu_end = mdy(1, 1, 2010) + round(rand("normal", 0, 1000));
    output;
  end;
  drop i;
run;

option notes; 

%hash_match(
  in_ds = data1,
  out_ds = data2,
  id_var = pnr,
  index_date = diag_date,
  fu_start = fu_start,
  fu_end = fu_end,
  match_vars = birth_year male,
  seed = 1234,
  del = y
);

/* with index: */
/* source pop of 10mil, 1% exposed, 10 controls, 202 strata:
    loop run-time: ca. 20 secs */
/* source pop of 10mil, 10% exposed, 10 controls, 202 strata:
    loop run-time: ca. 30 secs*/

/* without  index: */
/* source pop of 10mil, 1% exposed, 10 controls 202 strata 
loop run-time: ca. 4m20s */
/* source pop of 10mil, 10% exposed, 10 controls 202 strata 
loop run-time: ca. 4m20s */


/* Blazing fast. Index seems to do a big difference. */
