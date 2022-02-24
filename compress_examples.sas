/*******************************************************************************
EXAMPLES
*******************************************************************************/

/* For illustration we just simulate a single character variable with an
unnecesary large length. This is ofcourse silly, but real data is often saved
in not so optimized ways, including the use of very large lengths, where it is
not necessary. A significant reductions in size can sometimes be obtained by
compressing such datasets. */
data dat;
  length var $100;
  do i = 1 to 10000;
    var = compress(put(i, 10.));
    output;
  end;
  drop i;
run;

%compress(in_ds = dat, out_ds = dat_compress);
