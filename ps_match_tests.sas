/*******************************************************************************
*	AUTHOR:       Thomas Bøjer Rasmussen (TBR)
* VERSION:      1.0
* DATE:         2019-03-07
********************************************************************************
*	DESCRIPTION:
* Tests of the ps_match macro. 
*******************************************************************************/

/*******************************************************************************
 BASIC TESTS OF MACRO PARAMETER SPECIFICATIONS 
*******************************************************************************/
/* Test that macro correctly handles input dataset variables and saves them in
the output dataset*/
data pop;
  pnr = "pt1"; exposure = 1; prop_score = 0.5; cov="1"; output;
  pnr = "pt2"; exposure = 0; prop_score = 0.5; cov="2"; output;
run; 

%ps_match(
  in_ds = pop 
  ,out_ds = pop_matched
	,id = pnr
	,E = exposure
	,ps = prop_score
  ,caliper = 0.1
  ,save_info = Y
  ,del = N
);

/* Test input parameter checks are working as intended */
data pop;
  ID = 1; T = 1; PS = 0.5; output;
run; 

%ps_match(
  in_ds = pop_123
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
);

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = pnr
	,E = T
	,ps = PS
);

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = E
	,ps = PS
);

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = Prop_score
);

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
  ,replace = yes
);

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
  ,order = yes
);

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
  ,caliper = 0..32
);

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
  ,caliper = default
);

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
  ,caliper =
);

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
  ,save_info = fds
);

data pop;
  ID = 1; T = "1"; PS = 0.5; output;
run; 

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
);

data pop;
  ID = 1; T = 1; PS = "0.1"; output;
run; 

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
);

data pop;
  ID = 1; T = 2; PS = 0.1; output;
run; 

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
);


data pop;
  ID = 1; T = 1; PS = 0; output;
run; 

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
);

data pop;
  ID = 1; T = 1; PS = .; output;
run; 

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
);

data pop;
  ID = 1; T = 1; PS = 0.5; output;
  ID = 1; T = 1; PS = 0.5; output;
run; 

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
);


data pop;
  ID = 1; by=1; T = 1; PS = 0.5; output;
  ID = 1; by=2; T = 1; PS = 0.5; output;
  ID = 1; by=2; T = 1; PS = 0.5; output;
run; 

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
  ,by = by
	,id = ID
	,E = T
	,ps = PS
);


/*******************************************************************************
MORE TESTS
*******************************************************************************/

/* Empty input dataset */
data pop;
  ID = 1; T = 1; PS = 0.5; output;
run;

data pop;
  set pop(obs=0);
run; 

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = T
	,ps = PS
);
/* Gives the somewhat cryptic error message that the E variable is not numeric.
This happens since the macro variable E_type will not be defined when the input 
dataset is empty, which in turn make E fail the numeric value test. This should at 
the very least promt the user to check the input dataset and realize it's empty, 
so we will not try to handle this specific scenario in a better way. */


/* Check the order macro parameter actually matches the exposed patients in
the order they are appear in the data when order = ASIS */
data pop;
  by=1; ID = 1; T = 1; PS = 0.5; output;
  by=1; ID = 2; T = 1; PS = 0.5; output;
  by=1; ID = 3; T = 1; PS = 0.5; output;
  by=1; ID = 4; T = 1; PS = 0.5; output;
  by=1; ID = 5; T = 0; PS = 0.5; output;
  by=2; ID = 1; T = 0; PS = 0.4; output;
  by=2; ID = 2; T = 0; PS = 0.3; output;
  by=2; ID = 3; T = 1; PS = 0.5; output;
  by=2; ID = 4; T = 1; PS = 0.5; output;
  by=2; ID = 5; T = 1; PS = 0.5; output;
  by=2; ID = 6; T = 1; PS = 0.5; output;
run;

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
  ,by = by
	,id = ID
	,E = T
	,ps = PS
  ,order= ASIS
  ,caliper = 1
  ,del = N
  ,save_info = Y
  ,seed = 123
);


/* Check the order macro parameter actually matches the exposed patients in
the order they are appear in the data when order = ASIS but the input data
is not not sorting according to the by variables */
data pop;
  by=2; ID = 5; T = 1; PS = 0.5; output;
  by=2; ID = 6; T = 1; PS = 0.5; output;
  by=1; ID = 1; T = 1; PS = 0.5; output;
  by=1; ID = 2; T = 1; PS = 0.5; output;
  by=1; ID = 3; T = 1; PS = 0.5; output;
  by=1; ID = 4; T = 1; PS = 0.5; output;
  by=1; ID = 5; T = 0; PS = 0.5; output;
  by=2; ID = 1; T = 0; PS = 0.4; output;
  by=2; ID = 2; T = 0; PS = 0.3; output;
  by=2; ID = 3; T = 1; PS = 0.5; output;
  by=2; ID = 4; T = 1; PS = 0.5; output;

run;

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
  ,by = by
	,id = ID
	,E = T
	,ps = PS
  ,order= ASIS
  ,caliper = 1
  ,del = N
  ,save_info = Y
  ,seed = 123
);

/* Check the progress output in the log and the output info dataset
when using by-variables, and that the macro works appropriately when the 
caliper is automatically calculated, but the input dataset has no exposed 
or unexposed patients in one/more/all by-variable stratas */
data pop;
  call streaminit(123);
  do i = 1 to 10;
    do j = 1 to 100;
      by = i;
      ID = j; 
      E = rand("bernoulli", 0.5**i); 
      ps = rand("uniform");
      output;
    end;
  end;
  drop i j;
run;

options nonotes;
%ps_match(
  in_ds = pop
	,out_ds = pop_matched
  ,by = by
	,id = ID
	,E = E
	,ps = ps
  ,save_info = Y
);
option notes;

/* Check that if there are only a few discrete ps-values and we do matching
with replacemetn, that a random of the closest unexposed is used and not the same 
for each exposed patient */
data pop;
  call streaminit(123);
  do i = 1 to 10000;
    ID = i;
    E = rand("bernoulli", 0.2); 
    ps = 1 / ( 1.1 + rand("binomial", 0.5, 3));
    output;
  end;
  drop i ;
run;

options nonotes;
%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = E
	,ps = ps
  ,replace = Y
  ,save_info = Y
);
option notes;

proc sort data = pop_matched out = dup_match nodupkeys;
  by ID;
run;

/* 333 duplicates removed. Seems reasonable considering there were 7992
unexposed patients with only 4 different ps values. */

  
/* Check that the macro correctly handles multiple by-variables */
data pop;
  call streaminit(123);
  do i = 1 to 10;
    do j = 1 to 10;
      do k = 1 to 100;
        by1 = i;
        by2 = j;
        ID = k; 
        E = rand("bernoulli", 0.5); 
        ps = rand("uniform");
        output;
      end;
    end;
  end;
  drop i j k;
run;


options nonotes;
%ps_match(
  in_ds = pop
	,out_ds = pop_matched
  ,by = by1 by2
	,id = ID
	,E = E
	,ps = ps
  ,save_info = Y
  ,del = n
);
option notes;


/* Check that if an empty input dataset if given, that a warning is issued
and an empty output dataset with the added _match variable is correctly created. */
data pop(where=(ID NE .));
  format ID E ps best12.;
run;

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = ID
	,E = E
	,ps = ps
);
