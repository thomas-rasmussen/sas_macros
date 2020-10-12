/******************************************************************************
Basic tests
******************************************************************************/

data dat;
  call streaminit(1);
  do i  = 1 to 10**3;
    id = i;
    by_char = "val_" || put(rand("bernoulli", 0.5), 1.);
    by_num = rand("bernoulli", 0.5);
    ps = rand("uniform");
    group = rand("bernoulli", 0.2);
    group3 = rand("binomial", 0.5, 2);
    maximum_length_variable_name1234 = rand("bernoulli", 0.5);
    output;
  end;
  drop i;
run;

/* Check that he macro gives an error if any of the macro
parameters (except <where>) are missing. */
%ps_match();
%ps_match(in_ds = );
%ps_match(in_ds = dat, out_pf = );
%ps_match(in_ds = dat, group_var = );
%ps_match(in_ds = dat, ps_var =);
%ps_match(in_ds = dat, match_on = );
%ps_match(in_ds = dat, caliper = );
%ps_match(in_ds = dat, replace = );
%ps_match(in_ds = dat, match_order = );
%ps_match(in_ds = dat, by = );
%ps_match(in_ds = dat, match_id_name = );
%ps_match(in_ds = dat, print_notes = );
%ps_match(in_ds = dat, verbose = );
%ps_match(in_ds = dat, seed = );
%ps_match(in_ds = dat, del = );

/* Check that variables with maximum variable name length work. */
%ps_match(in_ds = dat, group_var = maximum_length_variable_name1234);


/*** in_ds tests ***/

/* Check error if input dataset does not exist */
%ps_match(in_ds = abc);

/* Check error if input dataset is empty */
data dat_empty;
  set dat(obs = 0);
run;
%ps_match(in_ds = dat_empty);


/*** out_pf tests ***/

/* Check error if out_pf length exceeds what is allowed. */
%ps_match(in_ds = dat, out_pf = ds_that_has_length_22_);

/* Check max out_pf length works as intended */
%ps_match(in_ds = dat, out_pf = ds_that_has_length_21);


/*** group_var tests ***/

/* Check multiply variables triggers error. */
%ps_match(in_ds = dat, group_var = group group);

/* Check non-existent variable triggers error. */
%ps_match(in_ds = dat, group_var = abc);

/* Check invalid SAS name triggers error. */
%ps_match(in_ds = dat, group_var = 123);

/* Check more than two values triggers error. */
%ps_match(in_ds = dat, group_var = group3);

/* Check character variable triggers error. */
%ps_match(in_ds = dat, group_var = by_char);

/* Check non 0/1 values triggers error. */
%ps_match(in_ds = dat, group_var = ps);


/*** ps_var tests ***/

/* Check multiply variables triggers error. */
%ps_match(in_ds = dat, ps_var = ps ps);

/* Check non-existent variable triggers error. */
%ps_match(in_ds = dat, ps_var = abc);

/* Check invalid SAS name triggers error. */
%ps_match(in_ds = dat, ps_var = 123);

/* Check character variable triggers error. */
%ps_match(in_ds = dat, ps_var = by_char);

/* Check variables with values outside the interval (0;1) triggers error */
%ps_match(in_ds = dat, ps_var = group);


/*** match_on tests ***/

/* Check invalid value triggers error. */
%ps_match(in_ds = dat, match_on = invalid);

/* Check valid values work. */
%ps_match(in_ds = dat, match_on = ps);
%ps_match(in_ds = dat, match_on = logit_ps);


/*** caliper test ***/

/* Check invalid value triggers error. */
%ps_match(in_ds = dat, caliper = abc);

/* Check negative value triggers error. */
%ps_match(in_ds = dat, caliper = -1.0
);

/* Check zero not allowed. */
%ps_match(in_ds = dat, caliper = 0);
%ps_match(in_ds = dat, caliper = 0.0);

/* Check manual specified caliper work  */
%ps_match(in_ds = dat, caliper = 0.1, verbose = y);


/*** replace tests ***/

/* Check invalid value triggers error. */
%ps_match(in_ds = dat, replace = abc);

/* Check valid values work. */
%ps_match(in_ds = dat, replace = n);
%ps_match(in_ds = dat, replace = y);


/*** match_order ***/

/* Check invalid value triggers error. */
%ps_match(in_ds = dat, match_order = abc);

/* Check valid values work. */
%ps_match(in_ds = dat, match_order = rand);
%ps_match(in_ds = dat, match_order = asis);


/*** where tests ***/

/* Check that where conditions work as intended */
%ps_match(in_ds = dat, where = %str(by_num = 0));

/* Check that where conditions resulting in errors or warnings, 
triggers more informatie error message. */
%ps_match(in_ds = dat, where = %str(invalid = nonsense));


/*** by checks ***/

/* Check non-existent variable triggers error. */
%ps_match(in_ds = dat, by = abc);

/* Check invalid SAS name triggers error. */
%ps_match(in_ds = dat, by = 123);

/* Check duplicate variables triggers error. */
%ps_match(in_ds = dat, by = by_num by_num);

/* Check both numeric and character variables work. */
%ps_match(in_ds = dat, by = by_num by_char);


/*** match_id_name tests ***/

/* Check renaming works. */
%ps_match(in_ds = dat, match_id_name = match);

/* Check error if input variable name clash. */
%ps_match(in_ds = dat, match_id_name = id);

/* Check error if invalid SAS variable name. */
%ps_match(in_ds = dat, match_id_name = $jhw);


/*** print_notes tests ***/

/* Check invalid value triggers error. */
%ps_match(in_ds = dat, print_notes = abc);

/* Check valid values works as intended when notes are on
before running macro. */
option notes;
%ps_match(in_ds = dat, print_notes = y);

option notes;
%ps_match(in_ds = dat, print_notes = n);

/* Check valid values works as intended when notes are off
before running macro. */
option nonotes;
%ps_match(in_ds = dat, print_notes = y);

option nonotes;
%ps_match(in_ds = dat, print_notes = n);

option notes;


/*** verbose tests ***/

/* Check invalid value triggers error. */
%ps_match(in_ds = dat, verbose = abc);

/* Check valid values work. */
%ps_match(in_ds = dat, verbose = y);
%ps_match(in_ds = dat, verbose = n);


/*** seed tests ***/

/* Check invalid values triggers error. */
%ps_match(in_ds = dat, seed = -1.3);

/* Check valid values work as intended. */
%ps_match(in_ds = dat, seed = -1);
%ps_match(in_ds = dat, seed = 10332);


/*** del tests ***/

/* Check invalid value triggers error. */
%ps_match(in_ds = dat, del = abc);

/* Check valid values work. */
%ps_match(in_ds = dat, del = n);
%ps_match(in_ds = dat, del = y);


/******************************************************************************
Specific tests
******************************************************************************/

/*** Check that random matches are made in cases where multiple ps's are equally
close. ***/
data dat;
  do i = 1 to 1000;
    id = 1; group = 1; ps = 0.5; output;
    id = 2; group = 0; ps = 0.5; output;
    id = 3; group = 0; ps = 0.5; output;
  end;
  do i = 1 to 1000;
    id = 4; group = 1; ps = 0.4; output;
    id = 5; group = 0; ps = 0.31; output;
    id = 6; group = 0; ps = 0.49; output;
  end;
  drop i;
run;

%ps_match(in_ds = dat, match_on = ps, caliper = 0.1, seed = 1);

proc means data = _ps_match_matches nway noprint;
  class id;
  output out = equal_ps_test n(id) = test;
run;


/*** Check that macro makes an empty output dataset when there is no cases
or no controls. ***/
data dat;
  id = 1; group = 0; ps = 0.5; output;
  id = 2; group = 0; ps = 0.5; output;
run;
%ps_match(in_ds = dat);

data dat;
  id = 1; group = 1; ps = 0.5; output;
  id = 2; group = 1; ps = 0.5; output;
run;
%ps_match(in_ds = dat);


/*** Manual check that matching with and without replacement works as
intended. ***/

data dat;
  call streaminit(123);
  do i = 1 to 1000;
    id = i;
    group = rand("bernoulli", 0.5);
    ps = rand("uniform");
    output;
  end;
  drop i;
run;

%ps_match(in_ds = dat, replace = n, seed = 1);

proc sql;
  create table no_replace as
    select distinct id, group, count(*) as n
    from _ps_match_matches
    group id, group
    order by n descending;
quit;

%ps_match(in_ds = dat, replace = y, seed = 1);

proc sql;
  create table replace as
    select distinct id, group, count(*) as n
    from _ps_match_matches
    group id, group
    order by n descending;
quit;


/*** Missing data tests  ***/
data dat;
  format by_char_miss $10.;
  call streaminit(1);
  do i  = 1 to 10**3;
    id = i;
    by_char = "val_" || put(rand("bernoulli", 0.5), 1.);
    by_num = rand("bernoulli", 0.5);
    if rand("uniform") < 0.5 then by_char_miss = "";
    else by_char_miss = by_char;
    if rand("uniform") < 0.5 then by_num_miss = .;
    else by_num_miss = by_num;
    ps = rand("uniform");
    if rand("uniform") < 0.5 then ps_miss = .;
    else ps_miss = ps;
    group = rand("bernoulli", 0.2);
    if rand("uniform") < 0.5 then group_miss = .;
    else group_miss = group;
    output;
  end;
  drop i;
run;

/* Check missing values in group_var triggers error. */
%ps_match(in_ds = dat, group_var = group_miss);

/* Check missing values in ps_var triggers error. */
%ps_match(in_ds = dat, ps_var = ps_miss);

/* Check that missing/empty values in by variables works as intended. */
%ps_match(in_ds = dat, by = by_num_miss by_char_miss);


/*** Additional caliper tests ***/

data dat;
  call streaminit(1);
  do i  = 1 to 10**3;
    id = i;
    group = rand("bernoulli", 0.5);
    by = rand("binomial", 0.3, 4);
    ps = rand("uniform") / (1 + by);
    output;
  end;
  drop i;
run;

/* Check caliper changes in each strata when it is automatically calculated. */
%ps_match(in_ds = dat, by = by, verbose = y);

/* Check caliper is the same in each strata if manually specified. */
%ps_match(in_ds = dat, by = by, caliper = 0.1, verbose = y);

/* Check that no matches are made if caliper cannot be calculated. */
data dat;
  id = 1; group = 1; ps = 0.5; output;
  id = 2; group = 0; ps = 0.5; output;
run;
%ps_match(in_ds = dat, verbose = y);


/******************************************************************************
Protected variable name tests
******************************************************************************/

/* Check that the input data is not allowed to contain any variables with a
"__" prefix. */
data dat;
  call streaminit(1);
  do i = 1 to 1000;
    group = rand("bernoulli", 0.2);
    ps = rand("uniform");
    __test = 1;
    output;
  end;
run;

%ps_match(in_ds = dat);


/******************************************************************************
Non-matched output dataset
******************************************************************************/
data dat;
  call streaminit(1);
  id = 1; group = 1; ps = 0.5; output;
  id = 2; group = 0; ps = 0.5; output;
  id = 3; group = 1; ps = 0.8; output;
run;

/* Manual check to see if output looks correct. */
%ps_match(in_ds = dat, match_on = ps, caliper = 0.1, verbose = y);


/******************************************************************************
Performance
******************************************************************************/

data dat;
  call streaminit(1);
  do i  = 1 to 10**5;
    id = i;
    group = rand("bernoulli", 0.5);
    ps = rand("uniform");
    output;
  end;
  drop i;
run;

%ps_match(in_ds = dat);

/* Approximately 4min (on a relatively powerful server) for a relatively large 
population with 100,000 observation, where approximately 50,000 matches has to 
be tested for each treated patient. Not bad, but doesn't feel great either. On
the other hand, limited testing suggests that using eg a Cartesian join approach 
is way less effective.  */
