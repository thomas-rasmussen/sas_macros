/*******************************************************************************
TESTS
*******************************************************************************/
data __data1;
  call streaminit(1);
  do i = 1 to 10 ** 4;
    id_num = i;
    id_char = compress(put(id_num, z5.)); 
    index_num = round(1000 * rand("uniform"));
    index_char = compress(put(index_num, best12.));
    if rand("uniform") < 0.9 then do;
      index_num = .;
      index_char = "";
    end;
    var_num1 = rand("bernoulli", 0.5);
    var_num2 = rand("bernoulli", 0.5);
    var_char1 = put(var_num1, 1.);
    var_char2 = put(var_num2, 1.);
    variable_name_length_25__ = .;
    variable_name_length_26___ = .;
    output;
  end;
  drop i;
run;


/* Check that the macro gives an error if any of the macro parameters 
(except "where" and "match_inexact") are missing. */
%hash_match;
%hash_match(in_ds = __data1);
%hash_match(in_ds = __data1, out_pf = __out1);
%hash_match(in_ds = __data1, out_pf = __out1, match_date = index_num);

%macro test1;
%local opt_vars i i_var;
%let opt_vars = 
  match_exact n_controls replace keep_add_vars by            
  limit_tries seed print_notes verbose del;          

%do i = 1 %to %sysfunc(countw(&opt_vars, %str( )));
  %let i_var = %scan(&opt_vars, &i, %str( ));
  option nonotes;
  %hash_match(
    in_ds       = __data1, 
    out_pf      = __out1, 
    match_date  = index_num,
    &i_var      = 
  );
  option notes;
%end;
%mend test1;
%test1;

/*** out_pf test ***/

/* Check prefix of length 20 works. */
%hash_match(
  in_ds = __data1, 
  out_pf = out_pf_that_20_chars, 
  match_date = index_num
);

/* Check prefix of length 21 gives error. */
%hash_match(
  in_ds = __data1, 
  out_pf = out_pf_that_21_chars_, 
  match_date = index_num
);


/*** match_date tests ***/

/* Invalid variable name */
%hash_match(in_ds = __data1, out_pf = __out1, match_date = 1invalid);

/* Variable does not exist in dataset */
%hash_match(in_ds = __data1, out_pf = __out1, match_date = invalid);


/* Multiple variables specified */
%hash_match(in_ds = __data1, out_pf = __out1, match_date = index_num index_char);

/* Is numeric */
%hash_match(in_ds = __data1, out_pf = __out1, match_date = index_char);


/*** match_exact tests ***/

/* Invalid variable name */
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  match_exact = 1nvalid
);

/* Variable does not exist in dataset */
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  match_exact = invalid
);

/* Test both numeric and character variables work */
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  match_exact = var_num1
);

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  match_exact = var_char1
);

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  match_exact = var_num1 var_char2
);

/* Check duplicates result in error. */ 
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  match_exact = var_num1 var_num1
);

/*** match_inexact tests ***/

/* Check correct use works */
%hash_match(
  in_ds         = __data1, 
  out_pf        = __out1, 
  match_date    = index_num,
  match_inexact = %str(var_num1 ne _ctrl_var_num1)
);

/* Check no warning/error even though variable misspelled */
%hash_match(
  in_ds         = __data1, 
  out_pf        = __out1, 
  match_date    = index_num,
  match_inexact = %str(var_num1 ne invalid)
);

/* Check warning/error if logical operator misspelled */
%hash_match(
  in_ds         = __data1, 
  out_pf        = __out1, 
  match_date    = index_num,
  match_inexact = %str(var_num1 net invalid)
);


/*** n_control tests ***/

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  n_controls  = 0
);

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  n_controls  = -1
);

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  n_controls  = 2.5
);


/*** replace checks ***/

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  replace     = invalid
);

/*** keep_add_vars tests ***/

/* Test additional variable is added to output datasets. */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  match_date = index_num,
  keep_add_vars = var_char1
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  match_date = index_num,
  keep_add_vars = index_num
);

/* Test that adding superfluous variables are handled 
correctly. */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  match_date = index_num,
  match_exact = var_char1,
  keep_add_vars = index_num var_char1
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  match_date = index_num,
  match_exact = var_char1,
  match_inexact = %str(var_num2 ne _ctrl_var_num2),
  keep_add_vars = index_num var_char1 var_num1
);

/* Check that keep_add_vars = _all_ works as intended. */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  match_date = index_num,
  keep_add_vars = _all_
);

/* Check that _all_ and _null_ can't be included in a list of variables. */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  match_date = index_num,
  keep_add_vars = _all_ var_char1
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  match_date = index_num,
  keep_add_vars = _null_ var_char1
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  match_date = index_num,
  keep_add_vars = _null_ _all_
);

/* Check duplicates gives error. */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  match_date = index_num,
  keep_add_vars = var_num1 var_num1
);


/*** where tests ***/

%hash_match(
  in_ds         = __data1, 
  out_pf        = __out1, 
  match_date    = index_num,
  where         = %str(var_num1 = 1),
  keep_add_vars = var_num1
);

%let where_cond = %str(var_num1 = 1 and var_char2 = "1");
%hash_match(
  in_ds         = __data1, 
  out_pf        = __out1, 
  match_date    = index_num,
  where         = &where_cond,
  keep_add_vars = var_num1 var_char2
);

/* Check that the macro terminates if the where condition
produces an error. */
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  where       = nonsense
);


/*** by tests ***/

/* Invalid variable name. */
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  by          = 1nvalid
);

/* Variable does not exist in dataset. */
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  by          = invalid
);

/* Check works when correctly specified.  */
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  by          = var_num1
);
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  by          = var_num1 var_char2
);

/* Check duplicates results in an error. */
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  by          = var_num1 var_num1
);

/*** limit_tries tests ***/

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  limit_tries = 0
);

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  limit_tries = -1
);

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  limit_tries = 2.5
);

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  limit_tries = 1000
);

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  limit_tries = 5
);


/*** seed tests ***/

%hash_match(in_ds = __data1, out_pf = __out1, match_date = index_num, seed = -1);
%hash_match(in_ds = __data1, out_pf = __out1, match_date = index_num, seed = 3.4);


/*** print_notes tests ***/

option notes;
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  print_notes = invalid
);

option notes;
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  print_notes = y
);

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  print_notes = n
);

option nonotes;
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  print_notes = y
);

option notes;


/*** verbose tests ***/

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  verbose     = invalid
);

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  verbose     = y
);


/*** del checks ***/

%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  del         = invalid
);


/*** Check variable name lengths ***/

/* match_date */
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = variable_name_length_25__
);
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = variable_name_length_26___
);

/* match_exact */
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  match_exact = variable_name_length_25__
);
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  match_exact = variable_name_length_26___
);

/* match_inexact */
%hash_match(
  in_ds         = __data1, 
  out_pf        = __out1, 
  match_date    = index_num,
  match_inexact = %str(variable_name_length_25__ = .)
);
%hash_match(
  in_ds         = __data1, 
  out_pf        = __out1, 
  match_date    = index_num,
  match_inexact = %str(variable_name_length_26___ = .)
);
/* Macro does not give the planned error message, but
the error it does give is just as informative. Macro
terminates without cleaning up and resetting the notes
option though which is not ideal. For now we will not
fix this, since the same error problem would still
occur if a non-existing variable is specified that is
also length 33 or more. */

/* by */
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  by          = variable_name_length_25__ 
);
%hash_match(
  in_ds       = __data1, 
  out_pf      = __out1, 
  match_date  = index_num,
  by          = variable_name_length_26___ 
);
