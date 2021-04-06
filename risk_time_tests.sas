/*******************************************************************************
BASIC TESTS
*******************************************************************************/

data dat1;
  call streaminit(1);
  format id 8. male 1. birth_date fu_start fu_end date9.;
  do id = 1 to 100;
    birth_date = "01JAN1960"d + floor(10**3 * rand("uniform", -1, 1));
    fu_start = birth_date + 2 * floor(10**3 * rand("uniform"));
    fu_end = fu_start + 2 * floor(10**3 * rand("uniform"));
    male = rand("bernoulli", 0.7);
    birth_date_char = put(birth_date, date9.);
    fu_start_char = put(fu_start, date9.);
    fu_end_char = put(fu_end, date9.);
    by_num = rand("bernoulli", 0.5);
    by_char = put(rand("bernoulli", 0.5), 1.);
    output;
  end;
run;

/* Check that the macro gives an error if any of the macro parameters 
(except <where>) are missing. */
%risk_time;
%risk_time(in_ds = dat1);
%risk_time(out_ds = test1);

%macro test1;
%local opt_vars i i_var;
%let opt_vars = birth_date fu_start fu_end risk_time_unit stratify_year  
                stratify_age stratify_by max_ite print_notes    
                verbose del;          

%do i = 1 %to %sysfunc(countw(&opt_vars, %str( )));
  %let i_var = %scan(&opt_vars, &i, %str( ));
  %risk_time(
    in_ds   = dat1, 
    out_ds  = test1,
    &i_var  = 
  );
%end;
%mend test1;
%test1;

/*** <in_ds> ***/

/* Check error if dataset does not exist */
%risk_time(in_ds = abc, out_ds = test2);

/* Check empty dataset not accepted */
data dat1_empty;
  set dat1(obs = 0);
run;
%risk_time(in_ds = dat1_empty, out_ds = test2);


/*** <birth_date> tests ***/

/* Invalid variable name triggers errror */
%risk_time(in_ds = dat1, out_ds = test2, birth_date = 1nvalid);

/* Variable does not exist in dataset triggers error */
%risk_time(in_ds = dat1, out_ds = test2, birth_date = invalid);

/* Multiple variables specified triggers errror */
%risk_time(in_ds = dat1, out_ds = test2, birth_date = birth_date fu_start);

/* Character variable triggers error */
%risk_time(in_ds = dat1, out_ds = test2, birth_date = birth_date_char);


/*** <fu_start> tests ***/

/* Invalid variable name triggers errror */
%risk_time(in_ds = dat1, out_ds = test3, fu_start = 1nvalid);

/* Variable does not exist in dataset triggers error */
%risk_time(in_ds = dat1, out_ds = test3, fu_start = invalid);

/* Multiple variables specified triggers errror */
%risk_time(in_ds = dat1, out_ds = test3, fu_start = birth_date fu_start);

/* Character variable triggers error */
%risk_time(in_ds = dat1, out_ds = test3, fu_start = fu_start_char);


/*** <fu_end> tests ***/

/* Invalid variable name triggers errror */
%risk_time(in_ds = dat1, out_ds = test4, fu_end = 1nvalid);

/* Variable does not exist in dataset triggers error */
%risk_time(in_ds = dat1, out_ds = test4, fu_end = invalid);

/* Multiple variables specified triggers errror */
%risk_time(in_ds = dat1, out_ds = test4, fu_end = birth_date fu_start);

/* Character variable triggers error */
%risk_time(in_ds = dat1, out_ds = test4, fu_end = fu_end_char);


/*** <risk_time_unit> tests ***/

/* Invalid value triggers error */
%risk_time(in_ds = dat1, out_ds = test5, risk_time_unit = invalid);

/* Check valid values work */
%risk_time(in_ds = dat1, out_ds = test5, risk_time_unit = years);
%risk_time(in_ds = dat1, out_ds = test5, risk_time_unit = days);


/*** <stratify_year> tests ***/

/* Invalid value triggers error*/
%risk_time(in_ds = dat1, out_ds = test6, stratify_year = invalid);

/* Check valid values work */
%risk_time(in_ds = dat1, out_ds = test6, stratify_year = n);
%risk_time(in_ds = dat1, out_ds = test6, stratify_year = y);


/*** <stratify_age> tests ***/

/* Invalid value triggers error*/
%risk_time(in_ds = dat1, out_ds = test7, stratify_age = invalid);

/* Check valid values work */
%risk_time(in_ds = dat1, out_ds = test7, stratify_age = n);
%risk_time(in_ds = dat1, out_ds = test7, stratify_age = y);


/*** <stratify_by> tests ***/

/* Check variables not in data triggers error */
%risk_time(in_ds = dat1, out_ds = test8, stratify_by = invalid);

/* Check duplicate variables triggers error */
%risk_time(in_ds = dat1, out_ds = test8, stratify_by = by_num by_num);

/* Check both numeric and/or character variables work */
%risk_time(in_ds = dat1, out_ds = test8, stratify_by = by_num);
%risk_time(in_ds = dat1, out_ds = test8, stratify_by = by_char);
%risk_time(in_ds = dat1, out_ds = test8, stratify_by = by_num by_char);

/* Check parameter work in connection with the stratify_year and
stratify_age parameters */
%risk_time(
  in_ds = dat1, 
  out_ds = test8, 
  stratify_year = n,
  stratify_age = n,
  stratify_by = by_num by_char
);

/*** <max_ite> tests ***/

/* Check invalid values triggers errror */
%risk_time(in_ds = dat1, out_ds = test9, max_ite = invalid);
%risk_time(in_ds = dat1, out_ds = test9, max_ite = -1);
%risk_time(in_ds = dat1, out_ds = test9, max_ite = 0);
%risk_time(in_ds = dat1, out_ds = test9, max_ite = 01);

/* Check that low value triggers error because max iteration is reached */
%risk_time(in_ds = dat1, out_ds = test9, max_ite = 1);


/*** <print_notes> tests ***/

option notes;
%risk_time(in_ds = dat1, out_ds = test10, print_notes = invalid);
%risk_time(in_ds = dat1, out_ds = test10, print_notes = y);
%risk_time(in_ds = dat1, out_ds = test10, print_notes = n);


option nonotes;
%risk_time(in_ds = dat1, out_ds = test10, print_notes = y);
%risk_time(in_ds = dat1, out_ds = test10, print_notes = n);

option notes;


/*** <verbose> tests ***/

/* Invalid value triggers error*/
%risk_time(in_ds = dat1, out_ds = test11, verbose = invalid);

/* Check valid values work */
%risk_time(in_ds = dat1, out_ds = test11, verbose = n);
%risk_time(in_ds = dat1, out_ds = test11, verbose = y);

/*** <verbose> tests ***/

/* Invalid value triggers error*/
%risk_time(in_ds = dat1, out_ds = test12, del = invalid);

/* Check valid values work */
%risk_time(in_ds = dat1, out_ds = test12, del = n);
%risk_time(in_ds = dat1, out_ds = test12, del = y);


/*******************************************************************************
TEST STRATIFICATION
*******************************************************************************/

/* Test basic counting of follow-up time */
data dat2;
  format id 2. birth_date fu_start fu_end date9.;
  id = 1;
  birth_date  = "01JAN2001"d;
  fu_start    = "01JAN2001"d;
  fu_end      = "01JAN2001"d;
  output;
  id = 2;
  birth_date  = "01JAN2001"d;
  fu_start    = "01JAN2001"d;
  fu_end      = "02JAN2001"d;
  output;
  id = 3;
  birth_date  = "01JAN2001"d;
  fu_start    = "01JAN2001"d;
  fu_end      = "31DEC2001"d;
  output;
  id = 4;
  birth_date  = "01JAN2001"d;
  fu_start    = "01JAN2001"d;
  fu_end      = "01JAN2002"d;
  output;
run;

%risk_time(
  in_ds = dat2, 
  out_ds = test_strat1_days,
  stratify_by = id,
  risk_time_unit = days
);

%risk_time(
  in_ds = dat2, 
  out_ds = test_strat1_years,
  stratify_by = id,
  risk_time_unit = years
);

/* Tets age split */
data dat3;
  format id 2. birth_date fu_start fu_end date9.;
  id = 1;
  birth_date  = "01JAN2001"d;
  fu_start    = "01JAN2002"d;
  fu_end      = "01JAN2003"d;
  output;
  id = 2;
  birth_date  = "01JUL2001"d;
  fu_start    = "01JAN2002"d;
  fu_end      = "01JAN2003"d;
  output;
run;

%risk_time(
  in_ds = dat3, 
  out_ds = test_strat2_days,
  stratify_by = id,
  risk_time_unit = days
);

%risk_time(
  in_ds = dat3, 
  out_ds = test_strat2_years,
  stratify_by = id,
  risk_time_unit = years
);


/* Test basic counting of follow-up time in leap-year */
data dat4;
  format id 2. birth_date fu_start fu_end date9.;
  id = 1;
  birth_date  = "01JAN2000"d;
  fu_start    = "01JAN2000"d;
  fu_end      = "01JAN2000"d;
  output;
  id = 2;
  birth_date  = "01JAN2000"d;
  fu_start    = "01JAN2000"d;
  fu_end      = "02JAN2000"d;
  output;
  id = 3;
  birth_date  = "01JAN2000"d;
  fu_start    = "01JAN2000"d;
  fu_end      = "31DEC2000"d;
  output;
  id = 4;
  birth_date  = "01JAN2000"d;
  fu_start    = "01JAN2000"d;
  fu_end      = "01JAN2001"d;
  output;
run;

%risk_time(
  in_ds = dat4, 
  out_ds = test_strat3_days,
  stratify_by = id,
  risk_time_unit = days
);

%risk_time(
  in_ds = dat4, 
  out_ds = test_strat3_years,
  stratify_by = id,
  risk_time_unit = years
);
