/*******************************************************************************
BASIC TESTS
*******************************************************************************/

/* Simulate count data on variables, aggregate, and restructure */
data basic1;
  call streaminit(1);
  do i = 1 to 100;
    bin_var = rand("bernoulli", 0.05);
    cat_var = rand("binomial", 0.1, 2);
    output;
  end;
run;

data basic2;
  set basic1;
  cat_var_0 = (cat_var = 0);
  cat_var_1 = (cat_var = 1);
  cat_var_2 = (cat_var = 2);
  drop i cat_var;
run;

%macro test1;
%let vars = bin_var cat_var_0 cat_var_1 cat_var_2;

proc means data = basic2 noprint missing;
  var &vars;
  output out = basic3(drop = _type_ _freq_) 
    n(bin_var) = __n
    sum(&vars) = &vars
    / noinherit;
run;

%let vars = __n &vars;
data basic4;
  format __var __label $50.;
  set basic3;
  %do i = 1 %to %sysfunc(countw(&vars, %str( )));
    %let i_var = %scan(&vars, &i, %str( ));
    __var = "&i_var";
    __label = __var;
    __stat_num1 = &i_var;
    cnt_char = put(__stat_num1, 10.);
    if substr(__label, 1, 3) = "cat" then __var = "cat_var";
    output;
  %end;
  

  drop bin_var cat_var_:;
run;
%mend test1;
%test1;

/* Add dummy numeric versions of variables */
data basic5;
  set basic4;
  __var_num = _n_;
  __label_num = _n_;
run;

/* Check that the macro gives an error if any of the macro parameters 
(except "where") are missing. */
%mask_table;
%mask_table(in_ds = basic5);
%mask_table(out_ds = out1);

%let vars = 
  class_vars cnt_var id_var value_var n_value cont_vars   
  by mask_min mask_max mask_avg ite_max weighted del;      

%macro test1;
%do i = 1 %to %sysfunc(countw(&vars, %str( )));
  %let i_var = %scan(&vars, &i, %str( ));
  %put var: &i_var;
  %mask_table(in_ds = basic5, out_ds = out1, &i_var = );
%end;
%mend test1;
%test1;

/*** cnt_var tests ***/

/* Test that specifying a character variable results in an error. */
%mask_table(in_ds = basic5, out_ds = out1, cnt_var = cnt_char);


/*** id_var tests ***/

/* Test that specifying a numeric variable results in an error. */
%mask_table(in_ds = basic5, out_ds = out1, id_var = __var_num);

/*** value_var tests ***/

/* Test that specifying a numeric variable results in an error. */
%mask_table(in_ds = basic5, out_ds = out1, value_var = __label_num);


/*** n_value tests ***/

/* Check that quotes are needed or the macro will result in an error. */
%mask_table(in_ds = basic5, out_ds = out1, n_value = __n);


/*** mask_min tests ***/

/* Check that only positive integers are allowed. */
%mask_table(in_ds = basic5, out_ds = out1, mask_min = 0);


/*** mask_max tests ***/

/* Check that only non-integers are allowed. */
%mask_table(in_ds = basic5, out_ds = out1, mask_max = -2);

/* Check that mask_max needs to be greater than or equal to
mask_min. */
%mask_table(in_ds = basic5, out_ds = out1, mask_min = 3, mask_max = 2);


/*** mask_avg ***/

/* Test that non-real number input is not allowed */
%mask_table(in_ds = basic5, out_ds = out1, mask_avg = one);


/*** weighted, and del tests ***/

/* Check y/n macro parameter inputs */
%mask_table(in_ds = basic5, out_ds = out1, weighted = yes);
%mask_table(in_ds = basic5, out_ds = out1, del = yes);

/* Test ite_max input parameter */
%mask_table(in_ds = basic5, out_ds = out1, ite_max = 0);


/*******************************************************************************
USING CONTINUOUS VARIABLES
*******************************************************************************/
/* Add continuous variable to data. */
data cont1;
  set basic5 end = eof;
  if eof then do;
    __var = "cont_var";
    __label = "cont_var";
    __stat_num1 = 1.5;
    cnt_char = put(__stat_num1, best12.);
  end;
run;

/*** cont_var tests ***/

/* Check that duplicate values are not allowed */
%mask_table(in_ds = cont1, out_ds = out1, cont_vars = "cont_var" "cont_var");


/*******************************************************************************
USING BY VARIABLES
*******************************************************************************/
data by1;
  set basic5(in=q1) basic5;
  if q1 then by_var_num = 1;
  else by_var_num = 2;
  by_var_char = put(by_var_num, 1.);
run;

/* Check that both numeric and character by-variables works */
%mask_table(in_ds = by1, out_ds = out1, by = by_var_num);
%mask_table(in_ds = by1, out_ds = out1, by = by_var_char);

/* Check that duplicate variables are not allowed */
%mask_table(in_ds = by1, out_ds = out1, by = by_var_num by_var_num);


/*******************************************************************************
CLASS VARIABLE
*******************************************************************************/

/* Simulate count data on variables, aggregate, and restructure */
data class1;
  call streaminit(1);
  do i = 1 to 100;
    class_num = rand("bernoulli", 0.5);
    bin_var = rand("bernoulli", 0.05);
    output;
  end;
  drop i;
run;

%macro test1;

proc means data = class1 noprint missing;
  class class_num;
  var bin_var;
  output out = class2(drop = _type_ _freq_) 
    n(bin_var) = __n
    sum(bin_var) = bin_var
    / noinherit;
run;

%let vars = __n bin_var;
data class3;
  format __var __label $50.;
  set class2;
  %do i = 1 %to %sysfunc(countw(&vars, %str( )));
    %let i_var = %scan(&vars, &i, %str( ));
    __var = "&i_var";
    __label = __var;
    __stat_num1 = &i_var;
    output;
  %end;
  

  drop bin_var;
run;
%mend test1;
%test1;

data class4;
  set class3;
  class_char = compress(put(class_num, 1.));
  if class_char = "." then class_char = "";
run;

/* Test that both numeric and character class variables work */
%mask_table(in_ds = class4, out_ds = out1, class_vars = class_num);
%mask_table(in_ds = class4, out_ds = out1, class_vars = class_char);


/* Test that if two classification variables have the exact same
stratas that the macro behaves in a desirable manner. */
%mask_table(in_ds = class4, out_ds = out1, class_vars = class_char class_num);
/* Works as inteded, one classification is effectively ignored. */

/* Test that dublicates are not allowed*/
%mask_table(in_ds = class4, out_ds = out1, class_vars = class_num class_num);


/*******************************************************************************
MULTIPLE CLASS VARIABLES
*******************************************************************************/

/* Test the use of multiple classification variables */
data mult1;
  call streaminit(1);
  do i = 1 to 100;
    class1 = rand("bernoulli", 0.3);
    class2 = rand("bernoulli", 0.3);
    bin1 = rand("bernoulli", 0.2);
    output;
  end;
run;

proc means data = mult1 noprint missing;
  class class1 class2;
  var bin1;
  output out = mult2(drop = _type_ _freq_) 
    n(bin1) = __n
    sum(bin1) = bin1
    / noinherit;
run;

%macro test1;
%let vars = __n bin1;
data mult3;
  format __var __label $50.;
  set mult2;
  %do i = 1 %to %sysfunc(countw(&vars, %str( )));
    %let i_var = %scan(&vars, &i, %str( ));
    __var = "&i_var";
    __label = __var;
    __stat_num1 = &i_var;
    output;
  %end;
  keep __var __label class1 class2 __stat_num1;
run;
%mend test1;
%test1;

%mask_table(in_ds = mult3, out_ds = out1, class_vars = class1 class2);

/* Before masking */
proc report data = mult3(where = (__label = "bin1")) missing;
  columns class1 class2, __stat_num1;
    define class1 / group;
    define class2 / across;
    define __stat_num1 / sum;
run;

/*
                    class2
                .          0          1
        __stat_nu  __stat_nu  __stat_nu
class1         m1         m1         m1
     .         14         10          4
     0         10          8          2
     1          4          2          2
*/


/* After masking */
proc report data = out1(where = (__label = "bin1")) missing;
  columns class1 class2, __stat_num1;
    define class1 / group;
    define class2 / across;
    define __stat_num1 / sum;
run;

/*
class2
                 .          0          1
         __stat_nu  __stat_nu  __stat_nu
 class1         m1         m1         m1
      .         14          .          .
      0          .          8          .
      1          .          .          .

*/

/* Seems to be working correctly. */ 
