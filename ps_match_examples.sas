/* Specifying a 0.1 caliper on when matching on the ps which is a common choice. 
Since matching is done on logit(ps), this corresponds to specifying a caliper of 
expit(0.1) = 1 / (1 + exp(-0.1)) = 0.525 */
data pop;
  call streaminit(123);
  do i = 1 to 1000;
    id = i;
    E = rand("bernoulli", 0.2);
    ps = E*rand("beta", 2, 3) + (1-E) * rand("beta", 2, 6);
    output;
  end;
  drop i;
run;

%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,id = id
	,E = E
	,ps = ps
  ,caliper = 0.525
  ,seed = 123
  );


/* Using a by-variable to do ps-matching on multiple populations stored
in the same dataset in a long format. We also use the save_info macro parameter to
save information from the macro on what calipers was chosen and how many patients
were matched ect. Note that the nonotes option is used so that the progress
of the macro can be easily seen in the log, and that the output dataset contains
all the variables in the input dataset. Even though the last population if very
larg, the matching should not take more than a couple of minutes on a normal 
computer. */
data pop;
  call streaminit(123);
  format pop $10. id $10.;
   pop = "pop1";
   do i = 1 to 1000;
     id = "ID"||compress(put(i, 20.));
     E = rand("bernoulli", 0.2);
     ps = rand("Uniform");
     age = rand("Normal", 50, 10);
     male = rand("Bernoulli", 0.5); 
     output;
   end; 
   pop = "pop2";
   do i = 1 to 10000;
     id = "ID"||compress(put(i, 20.));
     E = rand("bernoulli", 0.2);
     ps = E*rand("Beta", 2, 3) + (1 - E) * rand("Beta", 2, 6);
     age = rand("Normal", 50, 10);
     male = rand("Bernoulli", 0.5); 
     output;
   end;  
   pop = "pop3"; 
   do i = 1 to 50000;
     id = "ID"||compress(put(i, 20.));
     E = rand("bernoulli",0.2);
     ps = max(min(round(rand("Uniform"), 0.1), 0.9), 0.1);
     age = rand("Normal", 50, 10);
     male = rand("Bernoulli", 0.5); 
     output;
   end; 
  drop i;
run;

option nonotes;
%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,by = pop
	,id = id
	,E = E
	,ps = ps
	,save_info = Y
  ,seed = 123
  );
option notes;


/* Use of the macro in a simulation study, matching with replacement */
data pop;
  call streaminit(123);
  format pop1 pop2 10. ID 10.;
  sims=100;
  obs=1000;
  do i=1 to sims;
    do j=1 to obs;
    Pop1=i;
    Pop2=rand("Bernoulli",0.5);
    ID=j;
    E=rand("bernoulli",0.2);
    ps=rand("uniform");
    output;
    end;
  end;
  drop sims obs i j;
run;

option nonotes;
%ps_match(
  in_ds = pop
	,out_ds = pop_matched
	,by = pop1 pop2
	,id = ID
	,E = E
	,ps = ps
  ,replace = Y
	,save_info = Y
  ,seed = 123
  );
option notes;

