/*******************************************************************************
BASIC TESTS
*******************************************************************************/
data __data1;
  call streaminit(1);
  format id_num 12. id_char $12. by_num 1. by_char $1.;
  do i = 1 to 10 ** 3;
    id_num = i;
    id_char = compress(put(id_num, z12.)); 
    by_num = rand("bernoulli", 0.5);
    by_char = compress(put(by_num, 1.));
    fu_start = round(rand("uniform", 0, 100));
    fu_end = fu_start + round(rand("uniform", 0, 100));
    index_var = fu_start + (fu_end - fu_start) / 2;
    if rand("uniform") < 0.90 then do;
      index_var = .;
    end;
    index_var_char = compress(put(index_var, best12.));
    if index_var_char = "." then index_var_char = "";
    match_num = rand("bernoulli", 0.5);
    match_char = compress(put(match_num, 1.));
    output;
  end;
  drop i;
run;

/* Check that the macro gives an error if any of the macro parameters 
(except "where") are missing. */
%hash_match;
%hash_match(in_ds = __data1);
%hash_match(in_ds = __data1, out_pf = __out1);
%hash_match(in_ds = __data1, out_pf = __out1, id_var = id_num);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_num, 
  index_var = index_var
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_num, 
  index_var = index_var,
  fu_start = fu_start
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_num, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end
);

%macro test1;
%let opt_vars = match_vars n_controls replace by max_tries 
                ctrl_until_case seed del;              

%do i = 1 %to %sysfunc(countw(&opt_vars, %str( )));
  %let i_var = %scan(&opt_vars, &i, %str( ));
  %put ERROR: "&i_var = ";
  option nonotes;
  %hash_match(
    in_ds = __data1, 
    out_pf = __out1, 
    id_var = id_num, 
    index_var = index_var,
    fu_start = fu_start,
    fu_end = fu_end,
    &i_var = 
  );
  option notes;
%end;
%mend test1;
%test1;


/*** id_var tests ***/

/*invalid variable name*/
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = 1invalid, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end
);
/*variable does not exist in dataset */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = invalid, 
  index_var = index_var_date,
  fu_start = fu_start,
  fu_end = fu_end
);
/* Multiple id_vars */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_num id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end
);
/* Test that both numeric and character variables works */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_num, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char,
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end
);


/*** index_var, fu_start, and fu_end tests ***/

/*invalid variable name*/
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = 1invalid,
  fu_start = fu_start,
  fu_end = fu_end
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = 1invalid,
  fu_end = fu_end
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = 1invalid
);
/*variable does not exist in dataset */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = invalid,
  fu_start = fu_start,
  fu_end = fu_end
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = invalid,
  fu_end = fu_end
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = invalid
);
/* Multiple vars specified */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var index_var,
  fu_start = fu_start,
  fu_end = fu_end
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start index_var,
  fu_end = fu_end
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end index_var
);
/* Is numeric */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var_char,
  fu_start = fu_start,
  fu_end = fu_end
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = index_var_char,
  fu_end = fu_end
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = index_var_char
);


/*** match_vars tests ***/

/*invalid variable name*/
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  match_vars = 1invalid
);
/*variable does not exist in dataset */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  match_vars = invalid
);
/* Test both numeric and character variables works */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  match_vars = match_num
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  match_vars = match_char
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  match_vars = match_num match_char
);


/*** where tests ***/
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  match_vars = match_num,
  where = %str(match_num = 1)
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  match_vars = match_num,
  where = %str(match_char = "0")
);
%let macro_var = match_char;
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  match_vars = match_num,
  where = %str(&macro_var = "0")
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  match_vars = match_num,
  where = nonsense
);


/*** by tests ***/

/*invalid variable name*/
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  by = 1invalid
);
/*variable does not exist in dataset */
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = invalid,
  fu_start = fu_start,
  fu_end = fu_end
);

/*** n_control and max_tries tests ***/
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  n_controls = 0
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  max_tries = 0
);


/*** seed tests ***/

%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  seed = -1
);

%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  seed = 3.4
);


/*** "ctrl_until_case", "replace", and "del" checks ***/

%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  ctrl_until_case = invalid
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  replace = invalid
);
%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id_char, 
  index_var = index_var,
  fu_start = fu_start,
  fu_end = fu_end,
  del = invalid
);


/*******************************************************************************
CHECK THAT MACRO FIND VALID MATCHES AS INTENDED
*******************************************************************************/
data __data1;
  id = 1; start = 0; end = 20; index = 5; output;
  id = 2; start = 0; end = 20; index = .; output;
  id = 3; start = 0; end = 20; index = .; output;
  id = 4; start = 10; end = 30; index = .; output;
  id = 5; start = 0; end = 40; index = 11; output;
  id = 6; start = 60; end = 60; index = 60; output;
run;

%hash_match(
  in_ds = __data1, 
  out_pf = __out1, 
  id_var = id, 
  index_var = index,
  fu_start = start,
  fu_end = end,
  n_controls = 20,
  seed = 1
);

/*******************************************************************************
PROBLEM WITH INPUT DATA
*******************************************************************************/

/* Test that the macro correctly terminates with an error if "id_var",
"fu_start", or "fu_end" has missing values or if fu_end < fu_start for one
or more observations. */
data __data2;
  test = 1; id_num = .; start = 1; end = 2; index =.; output;
  test = 2; id_num = 1; start = .; end = 2; index =.; output;
  test = 3; id_num = 1; start = 1; end = .; index =.; output;
  test = 4; id_num = 1; start = 2; end = 1; index =.; output;
run;
%macro test1;
%do i = 1 %to 4;
  %hash_match(
    in_ds = __data2, 
    out_pf = __out2, 
    id_var = id_num, 
    index_var = index,
    fu_start = start,
    fu_end = end,
    where = %str(test = &i)
  );
%end;
%mend test1;
%test1;

data __data2;
  by = 1; id_num = 1; start = 1; end = 2; index =.; output;
  by = 2; id_num = 1; start = 1; end = 2; index =.; output;
run;
/* Test that the macro gives and error if id values are not unique. */
%hash_match(
  in_ds = __data2, 
  out_pf = __out2, 
  id_var = id_num, 
  index_var = index,
  fu_start = start,
  fu_end = end
);
%hash_match(
  in_ds = __data2, 
  out_pf = __out2, 
  id_var = id_num, 
  index_var = index,
  fu_start = start,
  fu_end = end,
  by = by
);
data __data2;
  by = 1; id_num = 1; start = 1; end = 2; index =.; output;
  by = 2; id_num = 1; start = 1; end = 2; index =.; output;
  by = 1; id_num = 1; start = 1; end = 2; index =.; output;
  by = 2; id_num = 1; start = 1; end = 2; index =.; output;
run;
%hash_match(
  in_ds = __data2, 
  out_pf = __out2, 
  id_var = id_num, 
  index_var = index,
  fu_start = start,
  fu_end = end,
  by = by
);


/*******************************************************************************
BENCHMARK TESTS
*******************************************************************************/

data __data1;
  call streaminit(1);
  do i = 1 to 10 ** 7;
    id = i;
    match_var_10 = round(rand("uniform") * 10);
    match_var_100 = round(rand("uniform") * 100);
    short_start = round(rand("uniform") * 100);
    short_end = short_start + round(rand("uniform") * 10);
    short_index = short_start + floor((short_end - short_start) / 2); 
    long_start = round(rand("uniform") * 100);
    long_end = long_start + round(rand("uniform") * 100);
    long_index = long_start + floor((long_end - long_start) / 2); 
    if rand("uniform") < 0.01 then do;
      short_index_1 = short_index;
      long_index_1 = long_index;
    end;
    else do;
      short_index_1 = .;
      long_index_1 = .;
    end;
    if rand("uniform") < 0.1 then do;
      short_index_10 = short_index;
      long_index_10 = long_index;
    end;
    else do;
      short_index_10 = .;
      long_index_10 = .;
    end;
    output;
  end;
  drop i;
run;

%let n_obs = 10**4 10**7;
%let match_stratas = 10 100;
%let index_pct = 1 10;
%let fu_length = short long;

%macro test1;
proc datasets nolist nodetails;
  delete run_time run_times;
run;
quit;

%do i = 1 %to %sysfunc(countw(&n_obs, %str( )));
  %let i_n = %scan(&n_obs, &i, %str( ));
  data __subset; 
    set __data1; 
    where id <= &i_n; 
  run;
  %do j = 1 %to %sysfunc(countw(&match_stratas, %str( )));
    %let j_match_strata = %scan(&match_stratas, &j, %str( ));
    %do k = 1 %to %sysfunc(countw(&index_pct, %str( )));
      %let k_index_pct = %scan(&index_pct, &k, %str( ));
      %do l = 1 %to %sysfunc(countw(&fu_length, %str( )));
        %let l_length = %scan(&fu_length, &l, %str( ));

        option nonotes;
        %let start = %sysfunc(time());
        %hash_match(
          in_ds = __subset, 
          out_pf = __out1, 
          id_var = id, 
          index_var = &l_length._index_&k_index_pct,
          fu_start = &l_length._start,
          fu_end = &l_length._end,
          match_vars = match_var_&j_match_strata
        );
        option notes;
        %let end = %sysfunc(time());
        %let time = %sysevalf(&end-&start);

        data run_time;
          format n_obs match_stratas index_var_pct fu_length $10. time 10.;
          n_obs = "&i_n";
          match_stratas = "&j_match_strata";
          index_var_pct = "&k_index_pct";
          fu_length = "&l_length";
          time = &time;
          output;
        run;
        proc append base = run_times data = run_time; run;
      %end; /* End of l-loop */
    %end; /* End of k-loop */
  %end; /* End of j-loop */    
%end; /* End of i-loop */


proc print data = run_times noobs; run;
%mend test1;

option notes;

/*
Server:
 
Computer specifications:
OS:           Windows Server 2012 R2 Standard
System type:  x64-based
Processor:    Intel(R) Xeon(R) CPU E5-2543 v3 @ 3.40GHz 12 processors
RAM:          256 GB
*/
%test1;
proc print data = run_times noobs; run;

/*

               match_        index_var_
 n_obs         stratas          pct        fu_length           time

 10**4         10            1             short                  2
 10**4         10            1             long                   2
 10**4         10            10            short                  2
 10**4         10            10            long                   2
 10**4         100           1             short                 16
 10**4         100           1             long                  16
 10**4         100           10            short                 16
 10**4         100           10            long                  16
 10**7         10            1             short                 56
 10**7         10            1             long                  38
 10**7         10            10            short                311
 10**7         10            10            long                 141
 10**7         100           1             short                 56
 10**7         100           1             long                  57
 10**7         100           10            short                227
 10**7         100           10            long                 153

*/
