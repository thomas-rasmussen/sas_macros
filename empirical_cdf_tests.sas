/******************************************************************************
Basic tests
******************************************************************************/
data dat;
  format strata_char_miss $10.;
  call streaminit(1);
  do i  = 1 to 10**4;
    strata_char = "val_" || put(rand("bernoulli", 0.5), 1.);
    strata_num = rand("bernoulli", 0.5);
    if rand("uniform") < 0.5 then strata_char_miss = "";
    else strata_char_miss = strata_char;
    if rand("uniform") < 0.5 then strata_num_miss = .;
    else strata_num_miss = strata_num;
    var1 = rand("normal", 0, 1);
    var2 = rand("weibull", 1, 1);
    if rand("uniform") < 0.5 then var_miss = .;
    else var_miss = var1;
    __var1 = var1;
    maximum_length_variable_name1234 = rand("bernoulli", 0.5);
    output;
  end;
  drop i;
run;

/* Check that he macro gives an error if any of the macro
parameters (except <where>) are missing. */
%empirical_cdf();
%empirical_cdf(in_ds = dat);
%empirical_cdf(in_ds = dat, out_ds = out);
%empirical_cdf(in_ds = dat, out_ds = out, var = );
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, strata = );
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, weight = );
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, n_xvalues = );
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, print_notes = );
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, verbose = );
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, del = );

/* Check that variables with a "__" prefix triggers an error. */
%empirical_cdf(in_ds = dat, out_ds = out, var = __var1);

/* Check that variables with maximum variable name length work. */
%empirical_cdf(in_ds = dat, out_ds = out, var = maximum_length_variable_name1234);


/*** in_ds tests ***/

/* Check error if input dataset does not exist */
%empirical_cdf(in_ds = dat1, out_ds = out, var = var1);

/* Check error if input dataset is empty */
data dat_empty;
  set dat(obs = 0);
run;
%empirical_cdf(in_ds = dat_empty, out_ds = out, var = var1);


/*** var tests ***/

/* Check non-existent variables triggers error. */
%empirical_cdf(in_ds = dat, out_ds = out, var = nonexist);

/* Check character variable triggers error. */
%empirical_cdf(in_ds = dat, out_ds = out, var = strata_char);

/* Check that missing values triggers error. */
%empirical_cdf(in_ds = dat, out_ds = out, var = var_miss);

/* Check duplicates triggers error. */
%empirical_cdf(in_ds = dat, out_ds = out, var = var1 var1);


/*** strata tests ***/

/* Check duplicates triggers error. */
%empirical_cdf(
  in_ds   = dat, 
  out_ds  = out, 
  var     = var1, 
  strata  = strata_num strata_num
);

/* Check both numerical and character strata variables work. */
%empirical_cdf(
  in_ds   = dat, 
  out_ds  = out, 
  var     = var1, 
  strata  = strata_num strata_char
);

/* Check strata variables with missing values work, */
%empirical_cdf(
  in_ds   = dat, 
  out_ds  = out, 
  var     = var1, 
  strata  = strata_num_miss strata_char_miss
);

/*** weight tests ***/

/* Check that specifying a weight variable works. */
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, weight = var2);

/* Check that specifying multiple variables triggers error. */
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, weight = var2 var2);

/* Check that zero-weights works */
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, weight = strata_num);

/* Check character variable triggers error */
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, weight = strata_char);

/* Check that negative weights triggers error */
%empirical_cdf(in_ds = dat, out_ds = out, var = var2, weight = var1);

/* Check that missing weights triggers error */
%empirical_cdf(in_ds = dat, out_ds = out, var = var2, weight = var_miss);


/*** where tests ***/

/* Check that where conditions work as intended */
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, where = %str(var1 > 0));

/* Check that misspecified where conditions triggers error *//* Check that where conditions work as intended */
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, where = %str(invalid = nonsense));


/*** print_notes tests ***/

/* Check invalid value triggers an error. */
option notes;
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, print_notes = invalid);

/* Check valid values works as intended when notes are on
before running macro. */
option notes;
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, print_notes = y);

option notes;
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, print_notes = n);


/* Check valid values works as intended when notes are off
before running macro. */
option nonotes;
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, print_notes = y);

option nonotes;
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, print_notes = n);

option notes;


/*** verbose tests ***/

/* Check invalid value triggers an error. */
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, verbose = invalid);


/* Check valid values behaves as intended. */
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, verbose = n);
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, verbose = y);


/*** verbose tests ***/

/* Check invalid value triggers an error. */
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, del = invalid);


/* Check valid values behaves as intended. */
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, del = n);
%empirical_cdf(in_ds = dat, out_ds = out, var = var1, del = y);


/******************************************************************************
Performance
******************************************************************************/

data dat;
  call streaminit(1);
  do i  = 1 to 10**6;
    strata = rand("binomial", 0.5, 2);
    var1 = rand("normal", 0, 1);
    var2 = rand("weibull", 1, 1);
    output;
  end;
  drop i;
run;

%empirical_cdf(in_ds = dat, out_ds = out, var = var1 var2, strata = strata);

/* Approximately 1,5 minute on a SAS server for a relatively large dataset with
1 million observations and two variables, using the default 100 x-values. 
Performance could probably be improved by using another approach, eg IML, but 
since IML is often not available this approach does not seem useful in practice.
An IML approach could also lead to memory issues for large datasets. Performance 
is probably good enough for most cases to not be a source of irritation for 
the user. */
