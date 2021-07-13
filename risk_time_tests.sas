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
%let opt_vars = birth_date fu_start fu_end risk_time_unit stratify_by 
                max_ite print_notes verbose del;          

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

/*** <stratify_by> tests ***/

/* Check variables not in data triggers error */
%risk_time(in_ds = dat1, out_ds = test8, stratify_by = invalid);

/* Check duplicate variables triggers error */
%risk_time(in_ds = dat1, out_ds = test8, stratify_by = by_num by_num);

/* Check use of stratify_by = _null_ */
%risk_time(in_ds = dat1, out_ds = test8, stratify_by = _null_);

/* Check use of _age_ or _year_ */
%risk_time(in_ds = dat1, out_ds = test8, stratify_by = _age_);
%risk_time(in_ds = dat1, out_ds = test8, stratify_by = _year_);

/* Check both numeric and/or character variables work */
%risk_time(in_ds = dat1, out_ds = test8, stratify_by = by_num);
%risk_time(in_ds = dat1, out_ds = test8, stratify_by = by_char);
%risk_time(in_ds = dat1, out_ds = test8, stratify_by = by_num by_char);


/*** <max_ite> tests ***/

/* Check invalid values triggers errror */
%risk_time(in_ds = dat1, out_ds = test9, max_ite = invalid);
%risk_time(in_ds = dat1, out_ds = test9, max_ite = -1);
%risk_time(in_ds = dat1, out_ds = test9, max_ite = 0);
%risk_time(in_ds = dat1, out_ds = test9, max_ite = 01);

/* Check that low value triggers error because max iteration is reached */
%risk_time(in_ds = dat1, out_ds = test9, max_ite = 1);

/* Check max_ite = _auto_ correctly sets a value accoridng to what is included
in stratify_by */
%risk_time(in_ds = dat1, out_ds = test9, stratify_by = _null_, verbose = y);
%risk_time(in_ds = dat1, out_ds = test9, stratify_by = _age_, verbose = y);
%risk_time(in_ds = dat1, out_ds = test9, stratify_by = _year_, verbose = y);
%risk_time(in_ds = dat1, out_ds = test9, verbose = y);

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
  id = 1; birth_date = "01JAN2001"d; fu_start = "01JAN2001"d; fu_end = "01JAN2001"d; output;
  id = 2; birth_date = "01JAN2001"d; fu_start = "01JAN2001"d; fu_end = "01JAN2002"d; output;
  id = 3; birth_date = "01JAN2001"d; fu_start = "01JAN2001"d; fu_end = "02JAN2001"d; output;
  id = 4; birth_date = "01JAN2001"d; fu_start = "01JAN2001"d; fu_end = "02JAN2002"d; output;
  id = 5; birth_date = "01JAN2001"d; fu_start = "01JAN2001"d; fu_end = "31DEC2001"d; output;
  id = 6; birth_date = "01JAN2001"d; fu_start = "01JAN2001"d; fu_end = "31DEC2002"d; output;
  id = 7; birth_date = "01JAN2001"d; fu_start = "01JAN2001"d; fu_end = "01JAN2003"d; output;
  id = 8; birth_date = "01JAN2001"d; fu_start = "01AUG2001"d; fu_end = "01JAN2002"d; output;
  id = 9; birth_date = "01AUG2000"d; fu_start = "01JAN2001"d; fu_end = "01JAN2002"d; output;
run;

%risk_time(
  in_ds = dat2, 
  out_ds = test_strat1_days,
  stratify_by = id _year_ _age_,
  risk_time_unit = days
);

%risk_time(
  in_ds = dat2, 
  out_ds = test_strat1_years,
  stratify_by = id _year_ _age_,
  risk_time_unit = years
);



/*******************************************************************************
TEST DATE FORMATS
*******************************************************************************/

data dat5;
  format fu_start date9. fu_end yymmdd10. fu_end_dt datetime20.;
  id = 1;
  birth_date = 1;
  fu_start = 2;
  fu_end = 3;
  fu_end_dt = fu_end;
run;

/* Test that the date variables accepts different formats from the list of
recognized date formats. */
%risk_time(in_ds = dat5, out_ds = test_fmt1);

/* Test that unrecognized/invalid formats trigger an error. */
%risk_time(fu_end = fu_end_dt, in_ds = dat5, out_ds = test_fmt2);


/*******************************************************************************
STRESS TESTS
*******************************************************************************/


/* 10 million persons, with long follow-up. */
data dat6;
  call streaminit(1);
  format id 8. birth_date fu_start fu_end date9.;
  do id = 1 to 10**7;
    birth_date = "01JAN1960"d + floor(10**3 * rand("uniform", -1, 1));
    fu_start = birth_date + 2 * floor(10**3 * rand("uniform"));
    fu_end = fu_start + 2 * floor(10**4 * rand("uniform"));
    male = rand("bernoulli", 0.5);
    output;
  end;
run;

/* No stratification of person-time */
%risk_time(in_ds = dat6, out_ds = test_stress1, stratify_by = _null_);
/* run-time: 10s */

/* Stratification wrt. _age_ */
%risk_time(in_ds = dat6, out_ds = test_stress2, stratify_by = _age_);
/* run-time: 4m40s */

/* Stratification wrt. _year_ */
%risk_time(in_ds = dat6, out_ds = test_stress3, stratify_by = _year_);
/* run-time: 1m30s */

/* Stratification wrt. _year_ and _age_ */
%risk_time(in_ds = dat6, out_ds = test_stress4);
/* run-time: 10m */



