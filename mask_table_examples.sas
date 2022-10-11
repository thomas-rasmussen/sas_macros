/*** Example using output from descriptive_summary macro ***/

/* Simulate data */
data dat1;
  call streaminit(1);
  do i = 1 to 100;
    E = rand("bernoulli", 0.2);
    bin_var = rand("bernoulli", 0.1);
    cont_var = rand("normal", 0, 1);
    cat_var = rand("binomial", 0.5, 3);
    output;
  end;
run;

/* Aggregate data into descriptive table*/
%descriptive_summary(
	in_ds    = dat1,
  out_ds   = dat2,
	var_list = bin_var cat_var cont_var,
  strata   = E
);

/* Mask person-sensitive counts in the table. */
%mask_table(
  in_ds       = dat2,
  out_ds      = dat3,
  class_vars  = E,
  cont_vars   = "cont_var"
 );

/* Mask character variable to be used in the output table,
if the count was masked. */
data dat4;
  set dat3;
  if __stat_num1 = .m then __stat_char = "*";
  drop __stat_num:;
run;

