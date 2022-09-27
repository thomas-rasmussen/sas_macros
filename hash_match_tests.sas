/*******************************************************************************
BASIC TESTS
*******************************************************************************/

data data;
  input id id_char$ index index_char$ var var_char$;
  datalines;
  1 1 1 1 1 1
  ;
run;


/*** <data> tests ***/

/* Check empty parameter value triggers error. */
%hash_match(data = , out = out, match_date = index);

/* Check empty dataset triggers error. */
data tmp;
  set data(obs = 0);
run;
%hash_match(data = tmp, out = out, match_date = index);

/* Check invalid (libname.)member-name triggers error.
NOTE: curently triggers a "does not exist" error, which is technically
true, but ideally it should trigger a more informative "not a valid name"
error. */
%hash_match(data = 1abc, out = out, match_date = index);
%hash_match(data = _work.data, out = out, match_date = index);

/* Check valid (libname.)member-name does not trigger error. */
%hash_match(data = data, out = out, match_date = index);
%hash_match(data = work.data, out = out, match_date = index);


/*** <out> tests ***/

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = , match_date = index);

/* Check invalid (libname).member-name triggers error. */
%hash_match(data = data, out = 1abc, match_date = index);
%hash_match(data = data, out = _work.data, match_date = index);

/* Check valid (libname.)member-name does not trigger error. */
%hash_match(data = data, out = out, match_date = index);
%hash_match(data = data, out = work.out, match_date = index);


/*** <match_date> tests ***/

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = out, match_date = );

/* Check invalid variable name triggers error. */
%hash_match(data = data, out = out, match_date = 1abc);

/* Check valid variable name does not trigger error. */
%hash_match(data = data, out = out, match_date = index);

/* Check non-existing variable triggers error. */
%hash_match(data = data, out = out, match_date = not_a_variable);

/* Check multiple variables triggers erorr. */
%hash_match(data = data, out = out, match_date = index index);

/* Check character variable triggers error. */
%hash_match(data = data, out = out, match_date = index_char);

/* Check case-insensitive. */
%hash_match(data = data, out = out, match_date = INDEX);


/*** <out_incomplete> tests ***/

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = out, match_date = index, out_incomplete = );

/* Check invalid (libname).member-name triggers error. */
%hash_match(data = data, out = out, match_date = index, out_incomplete = 1abc);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  out_incomplete = _work.incomplete
);

/* Check valid (libname.)member-name does not trigger error. */
%hash_match(
  data = data,
  out = out,
  match_date = index,
  out_incomplete = incomplete
);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  out_incomplete = work.incomplete
);


/*** <out_info> tests ***

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = out, match_date = index, out_info = );

/* Check invalid (libname).member-name triggers error. */
%hash_match(data = data, out = out, match_date = index, out_info = 1abc);
%hash_match(data = data, out = out, match_date = index, out_info = _work.info);

/* Check valid (libname.)member-name does not trigger error. */
%hash_match(data = data, out = out, match_date = index, out_info = info);
%hash_match(data = data, out = out, match_date = index, out_info = work.info);


/*** <match_exact> tests ***/

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = out, match_date = index, match_exact = );

/* Check invalid variable name triggers error. */
%hash_match(data = data, out = out, match_date = index, match_exact = 1abc);
%hash_match(data = data, out = out, match_date = index, match_exact = var 1abc);

/* Check valid variable name does not trigger error. */
%hash_match(data = data, out = out, match_date = index, match_exact = var);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_exact = var var_char
);

/* Check non-existing variable triggers error. */
%hash_match(data = data, out = out, match_date = index, match_exact = abc);
%hash_match(data = data, out = out, match_date = index, match_exact = var abc);

/* Check both numeric and character variables does not triggers errors. */
%hash_match(data = data, out = out, match_date = index, match_exact = var);
%hash_match(data = data, out = out, match_date = index, match_exact = var_char);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_exact = var var_char
);

/* Check duplicate variable names result in error. */ 
%hash_match(data = data, out = out, match_date = index, match_exact = var var);

/* Check variable names case-insensitive */
%hash_match(data = data, out = out, match_date = index, match_exact = VAR);


/*** <inexact_vars> test ***/

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = out, match_date = index, inexact_vars = );

/* Check that including variables in <inexact_vars> without using them in
<match_inexact> results in the variables being included in <out>. */
%hash_match(data = data, out = out, match_date = index, inexact_vars  = var);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  inexact_vars  = var var_char
);

/* Check that specifying an invalid variable name triggers an error. */
%hash_match(data = data, out = out, match_date = index, inexact_vars = 1abc);
%hash_match(data = data, out = out, match_date = index, inexact_vars = var 1abc);

/* Check that specifying a variable not in <data> triggers an error. */
%hash_match(data = data, out = out, match_date = index, inexact_vars = abc);
%hash_match(data = data, out = out, match_date = index, inexact_vars = var abc);

/* Check that variable specification is case-insensitive. */
%hash_match(data = data, out = out, match_date = index, inexact_vars = VAR);


/*** <n_controls> tests ***/

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = out, match_date = index, n_controls = );

/* Check non-positive integer triggers error. */
%hash_match(data = data, out = out, match_date = index, n_controls = one);
%hash_match(data = data, out = out, match_date = index, n_controls = -1);
%hash_match(data = data, out = out, match_date = index, n_controls = 0);
%hash_match(data = data, out = out, match_date = index, n_controls = 1.2);
%hash_match(data = data, out = out, match_date = index, n_controls = 1.0);

/* Check positive integer does not trigger error, and that the correct amount
of controls are found. */
%hash_match(data = data, out = out, match_date = index, n_controls = 1);
%hash_match(data = data, out = out, match_date = index, n_controls = 2);
%hash_match(data = data, out = out, match_date = index, n_controls = 5);


/*** <replace> tests ***/

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = out, match_date = index, replace = );

/* Check invaild values triggers an error. */
%hash_match(data = data, out = out, match_date = index, replace = abc);
%hash_match(data = data, out = out, match_date = index, replace = 1);
%hash_match(data = data, out = out, match_date = index, replace = yes);
%hash_match(data = data, out = out, match_date = index, replace = N);

/* Check that valid values does not trigger error. */
%hash_match(data = data, out = out, match_date = index, replace = n);
%hash_match(data = data, out = out, match_date = index, replace = y);
%hash_match(data = data, out = out, match_date = index, replace = m);


/*** <keep_add_vars> tests ***/

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = out, match_date = index, replace = );

/* Check specifying an invalid variable name triggers an error. */
%hash_match(data = data, out = out, match_date = index, keep_add_vars = 1abc);
%hash_match(data = data, out = out, match_date = index, keep_add_vars = var 1abc);

/* Check specifying a variable not in <data> triggers an error. */
%hash_match(data = data, out = out, match_date = index, keep_add_vars = abc);
%hash_match(data = data, out = out, match_date = index, keep_add_vars = var abc);

/* Check specified variables are included in <out>. */
%hash_match(data = data, out = out, match_date = index, keep_add_vars = var);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  keep_add_vars = var var_char
);

/* Check that adding superfluous variables are handled correctly. */
%hash_match(
  data = data,
  out = out,
  match_date = index,
  keep_add_vars = var var_char index id
);

/* Check that keep_add_vars = _all_ works as intended. */
%hash_match(data = data, out = out, match_date = index, keep_add_vars = _all_);


/* Check that _all_ and _null_ can't be included in a list of variables. */
%hash_match(
  data = data,
  out = out,
  match_date = index,
  keep_add_vars = var _null_
);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  keep_add_vars = var _all_
);

/* Check specifying duplicate variable names triggers an error. */
%hash_match(data = data, out = out, match_date = index, keep_add_vars = var var);


/*** <max_tries> tests ***/

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = out, match_date = index, max_tries = );

/* Check invalid value triggers an error. */
%hash_match(data = data, out = out, match_date = index, max_tries = y);
%hash_match(data = data, out = out, match_date = index, max_tries = -1);
%hash_match(data = data, out = out, match_date = index, max_tries = -);
%hash_match(data = data, out = out, match_date = index, max_tries = 0);
%hash_match(data = data, out = out, match_date = index, max_tries = 01);
%hash_match(data = data, out = out, match_date = index, max_tries = 1.2);

/* Check valid values does not trigger error. */
%hash_match(data = data, out = out, match_date = index, max_tries = 1);
%hash_match(data = data, out = out, match_date = index, max_tries = 10);
%hash_match(data = data, out = out, match_date = index, max_tries = _auto_);


/*** <seed> tests ***/

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = out, match_date = index, seed = );

/* Check invalid value triggers an error. */
%hash_match(data = data, out = out, match_date = index, seed = y);
%hash_match(data = data, out = out, match_date = index, seed = -);
%hash_match(data = data, out = out, match_date = index, seed = -1.2);
%hash_match(data = data, out = out, match_date = index, seed = 5.0);

/* Check valid value does not trigger error. */
%hash_match(data = data, out = out, match_date = index, seed = -1);
%hash_match(data = data, out = out, match_date = index, seed = 0);
%hash_match(data = data, out = out, match_date = index, seed = 01);
%hash_match(data = data, out = out, match_date = index, seed = 50);


/*** <print_notes> tests ***/

option notes;

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = out, match_date = index, print_notes = );

/* Check invalid values trigger an error. */
%hash_match(data = data, out = out, match_date = index, print_notes = abc);
%hash_match(data = data, out = out, match_date = index, print_notes = yes);
%hash_match(data = data, out = out, match_date = index, print_notes = N);

/* Check valid values does not trigger an error. */
%hash_match(data = data, out = out, match_date = index, print_notes = n);
%hash_match(data = data, out = out, match_date = index, print_notes = y);

/* Check notes are written to the SAS log if specified, regardless
of the value of the NOTES system option */
option notes;
%hash_match(data = data, out = out, match_date = index, print_notes = y);
option nonotes;
%hash_match(data = data, out = out, match_date = index, print_notes = y);

/* Check notes are not written to the SAS log if specified, regardless
of the value of the NOTES system option */
option notes;
%hash_match(data = data, out = out, match_date = index, print_notes = n);
option nonotes;
%hash_match(data = data, out = out, match_date = index, print_notes = n);

option notes;


/*** <verbose> tests ***/

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = out, match_date = index, verbose = );

/* Check invalid value triggers an error. */
%hash_match(data = data, out = out, match_date = index, verbose = 1);
%hash_match(data = data, out = out, match_date = index, verbose = a);
%hash_match(data = data, out = out, match_date = index, verbose = yes);
%hash_match(data = data, out = out, match_date = index, verbose = N);

/* Check valid values does not trigger error. */
%hash_match(data = data, out = out, match_date = index, verbose = n);
%hash_match(data = data, out = out, match_date = index, verbose = y);


/*** <del> checks ***/

/* Check empty parameter value triggers error. */
%hash_match(data = data, out = out, match_date = index, del = );

/* Check invalid value triggers an error. */
%hash_match(data = data, out = out, match_date = index, del = 1);
%hash_match(data = data, out = out, match_date = index, del = a);
%hash_match(data = data, out = out, match_date = index, del = yes);
%hash_match(data = data, out = out, match_date = index, del = N);


/* Check valid values does not trigger error. */
%hash_match(data = data, out = out, match_date = index, del = n);
%hash_match(data = data, out = out, match_date = index, del = y);


/*******************************************************************************
VARIABLE NAME LENGTH CHECKS
*******************************************************************************/

data data;
  input index variable_name_with_length_of_31 variable_name_with_length_of__32;
  datalines;
  1 1 1
  ;
run;

/* Check variable of length 31 does not trigger error. */
%hash_match(data = data, out = out, match_date = variable_name_with_length_of_31);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_exact = variable_name_with_length_of_31
);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str(variable_name_with_length_of_31 = 1)
);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  inexact_vars = variable_name_with_length_of_31
);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  keep_add_vars = variable_name_with_length_of_31
);

/* Check variable of length 32 trigger error. */
%hash_match(data = data, out = out, match_date = variable_name_with_length_of__32);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_exact = variable_name_with_length_of__32
);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str(variable_name_with_length_of__32 = 1)
);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  inexact_vars = variable_name_with_length_of__32
);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  keep_add_vars = variable_name_with_length_of__32
);


/*******************************************************************************
VARIABLE NAME UNDERSCORE PREFIX
*******************************************************************************/

data data;
  input index _var __var;
  datalines;
  1 1 1
  ;
run;

/* Check that specified variables names are not allowed to have a double
underscore prefix */
%hash_match(data = data, out = out, match_date = __var);
%hash_match(data = data, out = out, match_date = index, match_exact = __var);
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str(__var = 1)
);
%hash_match(data = data, out = out, match_date = index, inexact_vars = __var);
%hash_match(data = data, out = out, match_date = index, keep_add_vars = __var);

/* Check that variable names in <data> are allowed to have a double underscore
prefix if they are not used by the macro. */
%hash_match(data = data, out = out, match_date = index);

/* Check <match_inexact> / <inexact_vars> variable names are not allowed to have a
single underscore prefix. */
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str(_var = 1)
);
%hash_match(data = data, out = out, match_date = index, inexact_vars = _var);

/* Check that <match_date> / <match_exact> / <keep_add_vars> variable names
are allowed to have a single underscore prefix.*/
%hash_match(data = data, out = out, match_date = _var);
%hash_match(data = data, out = out, match_date = index, match_exact = _var);
%hash_match(data = data, out = out, match_date = index, keep_add_vars = _var);


/*******************************************************************************
MATCHING WITH(OUT) REPLACEMENT
*******************************************************************************/

/* Test that the different types of matching with / without replacement works
as intended. */

/*** Matching without replacement. ***/

data data;
  input id index;
  datalines;
  1 1
  2 .
  3 .
  ;
run;

%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str( id ne _id),
  replace = n
);
/* Case should have only 2 controls, id 2 and 3 once each. The remaining 8 controls
can't be found since the pool of potential controls has been depleted. */


/*** Match with replacement ***/

data data;
  input id index;
  datalines;
  1 1
  2 .
  3 .
  ;
run;

%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str( id ne _id),
  replace = y
);
/* Case should have all 10 controls: multiple copies of id 2 and 3. */

/*** Matching with "mixed" replacement ***/ 

data data;
  input id index;
  datalines;
  1 1
  2 1
  3 .
  4 .
  ;
run;

%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str( id ne _id and _index = .),
  replace = m
);
/* Both cases should have 2 controls, one copy of id 3 and 4. */


/*******************************************************************************
NO CASES IN STRATA
*******************************************************************************/

/* Test that the macro correctly handles matching in strata with no cases. */

/*** One strata, no cases ***/
data data;
  input id index;
  datalines;
  1 .
  ;
run;

%hash_match(data = data, out = out, match_date = index);


/*** Two strata, no cases in first strata ***/

data data;
  input id index strata;
  datalines;
  1 . 1
  2 1 2
  3 . 2
  ;
run;

%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_exact = strata,
  match_inexact = %str(id ne _id)
);


/*******************************************************************************
NO CONTROLS IN STRATA
*******************************************************************************/

/* Test that the macro correctly handles matching in strata with no controls. */

/*** One strata, no controls ***/

/* Only control is case itself, should just match to itself. */
data data;
  input id index;
  datalines;
  1 1
  ;
run;

%hash_match(
  data = data,
  out = out,
  match_date = index,
  keep_add_vars = id
);


/* No valid controls, should result in empty <out>*/
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str(id ne _id)
);


/*** Two strata, no controls in first strata ***/

data data;
  input id index strata;
  datalines;
  1 1 1
  2 1 2
  3 . 2
  ;
run;

/* Case in first strata should match to itself. */
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_exact = strata,
  keep_add_vars = id
);

/* Case in first strata has no valid matches, should not be included in <out>. */
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_exact = strata,
  match_inexact = %str(id ne _id)
);


/*******************************************************************************
MATCH_INEXACT CHECKS
*******************************************************************************/

data data;
  input id index var;
  datalines;
  1 1 1
  2 . 1
  3 . 2
  4 . 2
  ;
run;

/* Check that inexact matching works as intended. */
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str(id ne _id and var = _var)
);
/* id 2 should be only control that is matcehd */

/* Check macro throws error when variable name is misspelled */
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str(id ne _id and var1 = _var1)
);

/* Check macro throws error if logical operator is misspelled */
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str(id net _id)
);

/* Check variable names are case-insensitive */
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str(ID ne _id)
);


/*******************************************************************************
MATCH_INEXACT_VARS CHECKS
*******************************************************************************/

data data;
  input id index var;
  datalines;
  1 1 1
  2 . 1
  3 . 2
  4 . 2
  ;
run;

/* Check that specifying variable not in <data> triggers error */
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str(id ne _id),
  inexact_vars = id1
);

/* Check that if variable used in <match_inexact> is left out of
<inexact_vars> then an informative error is thrown. */
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_inexact = %str(id ne _id and var = _var),
  inexact_vars = id
);


/*******************************************************************************
MATCHING ORDER
*******************************************************************************/

/* Check that matching is done in the order cases appear in <data>, in strata
defined by variables in <match_exact>. This is still effectively the same as
matching in the order cases appear in <data>, since controls in one strata can
never be controls for a case in another strata. */

data data;
  input id index var;
  datalines;
   3 1 1
   2 1 1
   1 1 1
   4 1 2
   5 1 2
   6 1 2
  ;
run;

/* Check cases are matched in the order they appear in the data. */
%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_exact = var,
  n_controls = 1,
  keep_add_vars = id
);

/* Check that id 1 is matched to id 4, and id 8 to id 5 */
data data;
  input id index var;
  datalines;
   4 1 1
   3 1 1
   2 1 1
   1 . 1
   5 1 2
   6 1 2
   7 1 2
   8 . 2
  ;
run;

%hash_match(
  data = data,
  out = out,
  match_date = index,
  match_exact = var,
  match_inexact = %str(id ne _id and _index = .),
  replace = n
);


