/******************************************************************************
Basic tests
******************************************************************************/

data dat;
  call streaminit(1);
  do i  = 1 to 1000;
    group = rand("bernoulli", 0.5);
    group_char = "val_" || put(group, 1.);
    group_1val = "A";
    group_3val = rand("binomial", 0.5, 2);
    weight = 0.5;
    bin_var = rand("bernoulli", 0.5);
    cont_var = rand("normal", 0, 1);
    cat_var_num = rand("binomial", 0.5, 2);
    cat_var_char = "val_" || put(rand("binomial", 0.5, 2), 1.);
    __test_var = rand("bernoulli", 0.5);
    maximum_length_variable_name1234 = rand("bernoulli", 0.5);
    output;
  end;
  drop i;
run;

/* Check that the macro gives an error if any of the macro 
parameters (except "where") are missing. */
%calculate_sd;
%calculate_sd(in_ds = dat);
%calculate_sd(in_ds = dat, out_ds = out);
%calculate_sd(in_ds = dat, out_ds = out, group_var = group);
%calculate_sd(in_ds = dat, out_ds = out, group_var = group, var = bin_var, weight = );
%calculate_sd(in_ds = dat, out_ds = out, group_var = group, var = bin_var, by = );
%calculate_sd(in_ds = dat, out_ds = out, group_var = group, var = bin_var, print_notes = );
%calculate_sd(in_ds = dat, out_ds = out, group_var = group, var = bin_var, verbose = );
%calculate_sd(in_ds = dat, out_ds = out, group_var = group, var = bin_var, del = );

/* Test that variables with a "__" prefix triggers an error */
%calculate_sd(in_ds = dat, out_ds = out, group_var = __test_var, var = bin_var);

/* Check that variables with maximum variable name length work */
%calculate_sd(in_ds = dat, out_ds = out, group_var = group, var = maximum_length_variable_name1234);


/*** in_ds tests ***/

/* Check error if input dataset does not exist */
%calculate_sd(in_ds = dat1, out_ds = out, group_var = group, var = bin_var);

/* Check error if input dataset is empty */
data dat_empty;
  set dat(obs = 0);
run;
%calculate_sd(in_ds = dat_empty, out_ds = out, group_var = group, var = bin_var);


/*** group_var tests ***/

/* Check that both numeric and character variables with two values work
as intended. */
%calculate_sd(in_ds = dat, out_ds = out, group_var = group, var = bin_var);
%calculate_sd(in_ds = dat, out_ds = out, group_var = group_char, var = bin_var);

/* Check that only one variable is allowed */
%calculate_sd(in_ds = dat, out_ds = out, group_var = group group_char, var = bin_var);

/* Check that if group_var only takes one value then macro behaves in a 
reasonably way, ie all SD's are missing. */
%calculate_sd(
  in_ds     = dat, 
  out_ds    = out,
  group_var = group_1val, 
  var       = bin_var cont_var cat_var_num
);

/* Check that if the group variables has more than 2 values it triggers
an error. */
%calculate_sd(
  in_ds     = dat, 
  out_ds    = out, 
  group_var = group_3val, 
  var       = bin_var
);

/*** var tests ***/

/* Check duplicates triggers error. */
%calculate_sd(
  in_ds     = dat, 
  out_ds    = out, 
  group_var = group, 
  var       = cont_var cont_var
);

/*** weight tests ***/

/* Check that specifying a weight variable works. */
%calculate_sd(
  in_ds     = dat, 
  out_ds    = out, 
  group_var = group, 
  var       = bin_var,
  weight    = weight
);

/* Check that specifying multiple variables triggers error. */
%calculate_sd(
  in_ds     = dat, 
  out_ds    = out, 
  group_var = group, 
  var       = bin_var,
  weight    = weight weight
); 

/* Check that zero-weights works */
%calculate_sd(
  in_ds     = dat, 
  out_ds    = out, 
  group_var = group, 
  var       = bin_var,
  weight    = cat_var_num
);

/* Check that zero-weights works */
%calculate_sd(
  in_ds     = dat, 
  out_ds    = out, 
  group_var = group, 
  var       = cat_var_num,
  weight    = bin_var
);

/* Check character variable triggers error */
%calculate_sd(
  in_ds     = dat, 
  out_ds    = out, 
  group_var = group, 
  var       = bin_var,
  weight    = cat_var_char
);

/* Check that negative weights triggers error */
%calculate_sd(
  in_ds     = dat, 
  out_ds    = out, 
  group_var = group, 
  var       = bin_var,
  weight    = cont_var
);


/*** where tests ***/

/* Check that where conditions work as intended */
%calculate_sd(
  in_ds     = dat, 
  out_ds    = out, 
  group_var = group, 
  var       = bin_var,
  where     = %str(bin_var = 0)
);

/* Check that misspecified where conditions triggers error */
%calculate_sd(
  in_ds     = dat, 
  out_ds    = out, 
  group_var = group, 
  var       = cont_var,
  where     = %str(invalid = nonsense)
);


/*** by tests ***/

/* Check that duplicates results in an error. */
%calculate_sd(
  in_ds     = dat, 
  out_ds    = out, 
  group_var = group, 
  var       = cont_var,
  by        = bin_var bin_var
);

/* Check that both numeric and character by variables are correctly
handled */
%calculate_sd(
  in_ds     = dat, 
  out_ds    = out, 
  group_var = group, 
  var       = cont_var,
  by        = bin_var cat_var_char
);


/*** print_notes tests ***/

/* Check invalid value triggers an error. */
option notes;
%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = cont_var,
  print_notes = invalid
);

/* Check valid values works as intended when notes are on
before running macro. */
option notes;
%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = cont_var,
  print_notes = y
);

option notes;
%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = cont_var,
  print_notes = n
);

/* Check valid values works as intended when notes are off
before running macro. */
option nonotes;
%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = cont_var,
  print_notes = y
);

option nonotes;
%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = cont_var,
  print_notes = n
);

option notes;


/*** verbose tests ***/

/* Check invalid value triggers an error. */
%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = cont_var,
  verbose     = invalid
);

/* Check valid values behaves as intended. */
%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = cont_var,
  verbose     = n
);

%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = cont_var,
  verbose     = y
);


/*** del checks ***/

/* Check invalid value triggers an error. */
%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = cont_var,
  del         = invalid
);

/* Check valid values behaves as intended. */
%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = cont_var,
  del         = n
);

%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = cont_var,
  del         = y
);


/******************************************************************************
Manual specification of variable types 
******************************************************************************/

data dat;
  call streaminit(1);
  do i  = 1 to 100;
    group = rand("bernoulli", 0.5);
    bin_var = rand("bernoulli", 0.5);
    cont_var = rand("normal", 0, 1);
    cat_var = rand("binomial", 0.5, 2);
    cat_var_char = "val_" || put(cat_var, 1.);
    output;
  end;
  drop i;
run;

/* Check that that algorithm (generally) correctly guesses variable types when 
not manually specified. */
%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = bin_var cont_var cat_var cat_var_char,
  verbose     = y
);

/* Check that the same results are obtained if the variable types are
manually specified. */
%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = bin_var/d cont_var/cont cat_var/cat cat_var_char/cat
);

/* Check that invalid variable types triggers errors. */
%calculate_sd(in_ds = dat, out_ds = out, group_var = group, var = bin_var/invalid);

/* Check that trying to specify variable types not compatible with the 
data triggers errors. */
%calculate_sd(in_ds = dat, out_ds = out, group_var = group, var = cat_var_char/d);
%calculate_sd(in_ds = dat, out_ds = out, group_var = group, var = cat_var_char/cont);
%calculate_sd(in_ds = dat, out_ds = out, group_var = group, var = cont_var/d);


/******************************************************************************
Variables with missing values
******************************************************************************/

data dat;
  call streaminit(1);
  do i  = 1 to 1000;
    group = rand("bernoulli", 0.5);
    bin_var = rand("bernoulli", 0.5);
    if rand("uniform") < 0.5 then bin_var_miss = .;
    else bin_var_miss = bin_var;
    cont_var = rand("normal", 0, 1);
    if rand("uniform") < 0.5 then cont_var_miss = .;
    else cont_var_miss = cont_var;
    cat_var = rand("binomial", 0.5, 2);
    if rand("uniform") < 0.5 then cat_var_miss = .;
    else cat_var_miss = cat_var;
    cat_var_char = put(cat_var, 1.);
    if rand("uniform") < 0.5 then cat_var_char_miss = "";
    else cat_var_char_miss = cat_var_char;
    output;
  end;
  drop i;
run;

/* Check that missing values are treated as a separate category
for categorical variables. */
%calculate_sd(
  in_ds       = dat, 
  out_ds      = out, 
  group_var   = group, 
  var         = bin_var_miss cont_var_miss cat_var_miss cat_var_char_miss
);


/******************************************************************************
Compare formulas
******************************************************************************/

data dat;
  length var $50.;
  call streaminit(1);
  do j = 10**2, 10**3, 10**4, 10**5;
  do i  = 1 to j;
    pop = j;
    group = rand("bernoulli", 0.5);
    var = "bin_var";
    if rand("uniform") < 0.5 then value = rand("bernoulli", 0.5);
    else value = rand("bernoulli", 0.5);
    output;
    var = "bin_var_0";
    value = (value = 0);
    output;
    var = "bin_var_1";
    value = (value = 0);
    output;
  end;
  end;
  drop i j;
run;

/* Manual calculation of SD for a dichotomous variable and a categorical
version version of the variable */
proc means data = dat noprint nway vardef = df;
  class pop var group;
  output out = bin_man1
    mean(value) = value_mean
    var(value) = value_var
    / noinherit;
run;

data bin_man2;
  set bin_man1;
  by pop var group;
  retain value_mean_0 value_mean_1 value_var_0 value_var_1;
  if first.var then do;
    value_mean_0 = value_mean;
    value_var_0 = value_var;
  end;
  else do;
    value_mean_1 = value_mean;
    value_var_1 = value_var;
  end;
  if last.var;

  sd_cont = 
    abs(value_mean_0 - value_mean_1) 
    / sqrt((value_var_0 + value_var_1) / 2);
  sd_bin = 
    abs(value_mean_0 - value_mean_1) 
    / sqrt((value_mean_0*(1- value_mean_0) + value_mean_1*(1 - value_mean_1))/2);
  keep pop var sd_:;
run;

/* We see that treating a dichotomous variable as a categorical variable
gives identical SD's. Furthermore, we see that using the continous formula
for binomial variables gives almost identical results. */

/* Check that the macro implementation of the SD formula gives the
same results. */
%calculate_sd(
  in_ds = dat, 
  out_ds = bin_macro, 
  group_var = group, 
  var = value, 
  by = pop var
);


/******************************************************************************
Performance
******************************************************************************/

data dat;
  do i  = 1 to 10**6;
    group = rand("bernoulli", 0.5);
    bin_var = rand("bernoulli", 0.5);
    cont_var = rand("normal", 0, 1);
    cat_var_num = rand("binomial", 0.5, 2);
    cat_var_char = "val_" || put(rand("binomial", 0.5, 2), 1.);
    output;
  end;
  drop i;
run;

%calculate_sd(
  in_ds = dat, 
  out_ds = out, 
  group_var = group, 
  var = bin_var cont_var cat_var_num cat_var_char,
  del = n
);

/* Even for a dataset with 1 million rows, the macro only runs for a couple of 
seconds on a semi-powerful server. Input dataset is approx 40MB,
and the intermediate restructured data created by the macro to facilitate 
the SD calculations is approx 700MB. Not a disk-space "efficient" solution
but not a problem either. */
