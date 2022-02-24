/*******************************************************************************
BASIC TESTS
*******************************************************************************/

data dat1;
  var = 1;
  output;
run;

/* Check macro throws error if any of the macro parameters are missing */
%compress();
%compress(in_ds = dat1);
%compress(in_ds = dat1, out_ds = out1, compress = );
%compress(in_ds = dat1, out_ds = out1, min_length = );
%compress(in_ds = dat1, out_ds = out1, always_compress = );
%compress(in_ds = dat1, out_ds = out1, print_notes = );
%compress(in_ds = dat1, out_ds = out1, verbose = );
%compress(in_ds = dat1, out_ds = out1, del = );

/*** <in_ds> ***/

/* Check error if dataset does not exist */
%compress(in_ds = abc, out_ds = out1);

/*** <compress> ***/

/* Invalid value triggers error*/
%compress(in_ds = dat1, out_ds = out1, compress = abc);

/* Check valid values work */
%compress(in_ds = dat1, out_ds = out1, compress = auto, verbose = y);
%compress(in_ds = dat1, out_ds = out1, compress = no, verbose = y);
%compress(in_ds = dat1, out_ds = out1, compress = char, verbose = y);
%compress(in_ds = dat1, out_ds = out1, compress = binary, verbose = y);


/*** <min_length> ***/

/* Invalid value triggers error*/
%compress(in_ds = dat1, out_ds = out1, min_length = abc);
%compress(in_ds = dat1, out_ds = out1, min_length = -1);

/* Check valid values work */
/* Should not compress */
%compress(in_ds = dat1, out_ds = out1, min_length = 10, verbose = y);
/* Should compress */
%compress(in_ds = dat1, out_ds = out1, min_length = 1, verbose = y);


/*** <always_compress> ***/

/* Check invalid value trigges error */
%compress(in_ds = dat1, out_ds = out1, always_compress = abc);

/* Check dataset not compressed if it does not result in smaller size */
data dat2;
  do i = 1 to 1000;
    var = "abcfds";
    output;
  end;
run;

%compress(in_ds = dat2, out_ds = out2, always_compress = n);

/* Check compresses if always_compress = y */
%compress(in_ds = dat2, out_ds = out2, always_compress = y);


/*** <print_notes> tests ***/

option notes;
%compress(in_ds = dat1, out_ds = out1, print_notes = abc);
%compress(in_ds = dat1, out_ds = out1, print_notes = y);
%compress(in_ds = dat1, out_ds = out1, print_notes = n);

option nonotes;
%compress(in_ds = dat1, out_ds = out1, print_notes = y);
%compress(in_ds = dat1, out_ds = out1, print_notes = n);

option notes;


/*** <verbose> tests ***/

/* Invalid value triggers error*/
%compress(in_ds = dat1, out_ds = out1, verbose = abc);

/* Check valid values work */
%compress(in_ds = dat1, out_ds = out1, verbose = n);
%compress(in_ds = dat1, out_ds = out1, verbose = y);


/*** <del> tests ***/

/* Invalid value triggers error */
%compress(in_ds = dat1, out_ds = out1, del = abc);

/* Check valid values work */
%compress(in_ds = dat1, out_ds = out1, del = n);
%compress(in_ds = dat1, out_ds = out1, del = y);

