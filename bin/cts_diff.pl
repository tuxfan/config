eval 'exec perl -w -S $0 ${1+"$@"}'
  if 0;

# search path for perl modules
use FindBin qw($RealBin);
use File::Find;
use lib( grep( -x, "$RealBin", split(":", $ENV{PATH}), "$RealBin/lib", "$RealBin/../lib", @INC, "$RealBin/stub" ) );

#.................
#...use modules...
#.................
use my_utils qw (
 print_perl_obj
 ppo
 sort_numerically_unique
 which_exec
);

use cts_diff_util qw (
 create_stats
 cts_diff_unique_filenames
 cts_get_val
 get_val_regexp
 get_tols
 parse_args
 $GDATASET_NAMES
 $GDS_FAILED
 $GDS_NOFAILED
 $GNUMTRUE
 $GNUMBER_REGEXP
 $CTS_DIFF_FILE_CMD
 $CTS_DIFF_FILE_PLOT_OUT
 $CTS_DIFF_FILE_PDF
 $CTS_DIFF_FILE_PRESULT
 $CTS_DIFF_FILE_PS
 );

#..................
#...my variables...
#..................
my(
   %cmd, # command line values: a, r, or, quiet, l, files[]
   $compare_group, # what compare group you are on
   %data, # data from reading
   %data_base, # data from first file
   %ds_diffs, # which datasets have diffs per file compare
   $ds_name, # dataset name
   %ds_names, # hash of dataset names
   $ds_names_ref, # ref to hash of ds names
   $headers_printed, # a header has been printed for a level
   $i, # loop var
   $ierr, # error return
   $is_diff, # if different
   $is_diff_local, # if this particular dataset is different
   @files, # list of files in compare group
   $file_name, # file name
   $file_new, # new file
   $num_compare_groups, # number of compare groups
   $num_diffs, # number of diffs
   $coord_name, # coordinate name
   $print_source, # source name label to print
   $print_var, # variable name label to print
   $print_header, # print a header
   $print_title, # source name label to print
   %result_diff, # for -presult, stores additional data for printing later.
   %stat_file, # stat results for file
   %stat_cmp_grp, # stat results for everything
   %stat_total, # total stat results
   %time, # time to do various ops
   %gnuplot_info, # info used for plotting
  );

#.................
#...global vars...
#.................
my(
   $GDATA,   # global name for data type
   $GORG,    # global name for data type
   $GREL,    # global name for data type
   $GABS,    # global name for data type
   $GDIFF,   # global name for diff of dataset
   $GCOORDY, # global name for coordinate
   $GCOORDX, # global name for coordinate
   $GNAME,   # global name for name hash
   );
$GORG    = $cts_diff_util::GORG;
$GREL    = $cts_diff_util::GREL;
$GABS    = $cts_diff_util::GABS;
$GDATA   = $cts_diff_util::GDATA;
$GDIFF   = $cts_diff_util::GDIFF;
$GNAME   = $cts_diff_util::GNAME;
$GCOORDX = $cts_diff_util::GCOORDX;
$GCOORDY = $cts_diff_util::GCOORDY;

# print as gotten
$|=1;

$time{a_all}{start} = time();

#........................
#...parse command line...
#........................
# default args
$cmd{intp} = "";
$cmd{inc} = "";
$cmd{plots} = "";
$cmd{plotrun} = "";
$cmd{v} = 3;
$cmd{pft} = "";
$cmd{status} = "";
$ierr = cts_diff_util::parse_args( \@ARGV, \%cmd );
if( $ierr != 0 )
  {
    cts_diff_util::print_error( "FAILED: Invalid Command Line",
                                "Run [$0] without args for help.",
                                $ierr );
    exit( $ierr );
  }

#..............................
#...must have at least 1 arg...
#..............................
if ( defined( $cmd{h} ) )
  {
    print <<"EOF";
#............................................................................
#...Name
#...====
#... cts_diff.pl
#...   Find differences between data files "base" and "new".
#...   Each file is split into a set of dataset arrays (see "-ft" option
#...   below for definitions of file types).  The respective arrays
#...   are diff'd.  These arrays are Y-coordinate arrays.
#...
#...   By default, missing values in a dataset in "new" are ignored.
#...   (see -nointp below).
#...
#...   A "FAILED" is returned if an entire dataset array exists in exactly
#...   one of "base" or "new".
#...   If all values of a dataset are missing in both "base" and "new"
#...   the dataset is ignored.
#...
#...   Interpolation: (-nointp)
#...   --------------
#...     If X-coordinate array(s) are given, interpolation is done in
#...     order to diff the values on the "new" X-coordinate
#...     Simple linear interpolation is done.
#...
#...     Data diffed:
#...       o The X coordinates of the new data (X_new) are used.
#...       o Only the corresponding Y values (Y_base<interpolated> and Y_new)
#...         of X_new are diffed.  If a file has only part of a run,
#...         list it second so only its values are diffed.
#...
#...     Requirements :
#...        o X_new must be increasing
#...
#...     Interpolation may be turned off with the "-nointp" flag (see below).
#...
#...  Smoothing: (-ds_(no)smooth)
#...  ----------
#...    You can smooth datasets before diffing.
#...    This allows for keeping tighter tolerances for noisy data.
#...    You can do something like only turn on smoothing when comparing gold files
#...    and runs done on different compilers/machines.
#...    Smoothing will try to detect actual features of the data and smooth elsewhere.
#...
#...  Files:
#...  ------
#...    cts_diff.{file base}-{file new}{.number}.cmd
#...       gnuplot commands
#...    cts_diff.{file base}-{file new}{.number}.data
#...       data produced
#...    cts_diff.{file base}-{file new}{.number}.pdf,ps
#...       plots
#...    cts_diff.{file base}-{file new}{.number}.plot_out
#...       output from gnuplot commands.
#...       Use this to find page numbers for the plots.
#...    cts_diff.{file base}-{file new}{.number}.presult
#...       If "-presult".
#...       List all vars and their results (DIFF, FAILED, PASSED)
#...
#...    {.number} = Increment this so you can run cts_diff.pl multiple times
#...      and not overwrite older files.
#...
#...Usage
#...=====
#... cts_diff.pl <files: base new1 new2 ...>
#...             [-a <absolute tolerance>[,<comma sep list of variables>]]
#...             [-arg <argument file>]
#...             [-ds <comma separated list of datasets to compare>]
#...             [-ds_failed <comma separated list of datasets to treat DIFF as FAILED>]
#...             [-ds_file <file with 1-per-line list of datasets to compare]
#...             [-ds_skip   <comma separated list of datasets to     skip>]
#...             [-ds_noskip <comma separated list of datasets to not skip>]
#...             [-fsets <n - number of file sets>]
#...             [-ft <ares|cts|gmv|keyword|oxy|plot_output|pop|table|table_x|tecplot|token|tracer|link|xy|xy_block>]
#...             [-(no)inc]
#...             [-(no)intp]
#...             [-(no)last <comma separated list of datasets>]
#...             [-(no)last_only <comma separated list of datasets>]
#...             [-(no)or]
#...             [-(no)pargs]
#...             [-(no)pft]
#...             [-(no)plot_orig]
#...             [-(no)plots]
#...             [-(no)presult]
#...             [-(no)plotrun]
#...             [-(no)scaled_r]
#...             [--scaled_r_ds <dataset>,<comma separated list of regexp datasets>
#...             [-(no)status]
#...             [-ds_(no)skip_all_0 <comma separated list of datasets to skip if ALL values 0>]
#...             [-ds_(no)skip_undef <comma separated list of datasets to (not)skip undefined values>]
#...             [-ds_(no)smooth <comma separated list of datasets to (not)smooth>]
#...             [-ds_(no)fail <comma separated list of datasets that report fail if diff>]
#...             [-ds_base <value>,<comma separated list of datasets to compare against this value>]
#...             [-ds_cmp <expr>,<comma separated list of datasets to compare against this value>]
#...             [--superset_x]
#...             [--time_range <time or f:<name>>::f:<name>]
#...               Start/Stop times.
#...               If given name, start/stop times based when that var name
#...               starts or stops changing.
#...               ONLY works on ctf type files.
#...             [--time_shift <time or f:<name> to shift on first max>]
#...               Shift starting time by <time>.
#...               If given field, shift based on first max of that field.
#...               ONLY works on ctf type files.
#...             [--outdir <output directory>]
#...             [-r <relative tolerance>[,<comma sep list of variables>]]
#...             [--(no)unique_filenames]
#...             [-v <number>]
#...             [--val_skip <abs value boundary to skip>[,<comma sep list of variables>]]
#...
#...   <files: base new1 new2 ...>
#...      When given more than 1 data files, the first data file will
#...      be used as the base values from which all differences are taken.
#...      This can be used to detect drift.  Differences between the two
#...      latest files might be within tolerances when differences between
#...      the first and the last file would show differences.
#...         a1 a2 a3 --> (a1 vs. a2 vs. a3)
#...      See -fsets which changes what files are compared.
#...      If given a filename of "dummy", no data will be read in.
#...      This is useful if assigning base values with -ds_base and
#...      do not have a base file to use.
#...
#...   -a        <abs tol>[,<variable list>]
#...   -r [ns,s:]<rel tol>[,<variable list>]
#...      (The default is no tolerance.)
#...      Values are said to be "the same" if the absolute & relative
#...      difference is less than or equal to the absolute & relative
#...      tolernace.  The "-or" flag changes that to "the same" if
#...      within either absolute or relative tolerances.
#...
#...        Absolute Difference{[0,)} = abs(value1-value2)
#...        Relative Difference{[0,)} =
#...             mean_values = ((abs(val1)+abs(val2))/2)
#...             RMS = root mean square of a dataset
#...             mean_RMS = the mean of the 2 datasets being diffed
#...           default relative difference: (--noscaled_r, -r ns:<value>)
#...             abs(value1-value2)/mean_values
#...           scaled  relative difference: (--scaled_r,   -r  s:<value>)
#...             abs(value1-value2)/((3*mean_values+mean_RMS)/4)
#...               This takes into account the average value of the
#...               the datasets when computing the relative difference
#...               Weighs mean_values more than the mean_RMS.
#...
#...      When specifying a tolerance for a specific dataset, that
#...      overrides any general setting.
#...      Example: Relative tol of .005 except for the "foo" dataset
#....              which will be .002 and use scaled relative values.
#...           -r s:.002,foo -r .005
#...
#...   -arg <argument file>
#...      (By default, only a file named "cts_diff.arg" is read).
#...      The arguments can also be read from a file.  Blank and comment
#...      lines (starting with "#") are ignored.  Otherwise, the contents
#...      would look as if they were typed on the command line at the
#...      position the "-arg <argument file>.
#...      This is useful if the arguments get long or are difficult to
#...      remember why they were chosen:
#...          | # default tolerances
#...          | -a .01 -r .05
#...          | # tolerances for specific datasets
#...          | -a .001,foo -r .0001,bar
#...
#...   -ds <comma separated list of datasets to compare>
#...      (By default, all datasets are compared).
#...      If specified, only datasets in the list will be compared.
#...      If datasets have whitespace, be sure to place the whole list
#...      in quotes.  Can be regular expressions.
#...          -ds 'foo,bar.*'
#...
#...   -ds_failed <comma separated list of datasets to treat DIFF as FAILED>
#...      You may wish to consider some DIFF conditions as FAILED states.
#...
#...   -ds_file <name of file to specify datasets>
#...    Will join each line of the file with a comma to do:
#...      -ds <join ',' the lines in <ds_file>>
#...
#...   -ds_base <value>,<comma separated list of datasets to compare against this value>
#...      Set the "base" value to the value specified instead of the one
#...      (if any) found in the datafile.  If you do not have a "base" file,
#...      you can specify the base filename as "dummy".
#...
#...   -ds_cmp <expr>,<comma separated list of datasets to compare against this value>]
#...      <expr> is some comparison.  Use 'v' to represent your variable.
#...         -ds_cmp '( v > 0 && v <= 1.7e3 ) || ( v < -123 )',var.+_foo
#...      (put in single quotes since there are likely many shell symbols.
#...
#...   -ds_(no)fail <comma separated list of datasets that report fail if diff>
#...      Implies -presult (look at the presult file to see pass/diff/fail.
#...
#...   -ds_(no)skip <comma separated list of datasets to skip>
#...      Similar to "-ds" but specify datasets to skip or not skip.
#...
#...   -ds_(no)skip_all_0 <comma separated list of datasets to skip if ALL values 0>
#...      Default: does not skip.
#...      If all values of a dataset are 0, skip it entirely.
#...      Useful when you change file formats and add variables, but most of the
#...      tests, those new variables are all 0.  If you do not skip then, you will
#...      get failures because the new variables exist in the new runs even though
#...      they have values that are all 0.
#...   -ds_(no)skip_undef <comma separated list of datasets to (not)skip undefined values>
#...      Default: ds_noskip_undef .+
#...               Skip undefined values on "new" datasets only.
#...        This allows diffing:
#...          cts_diff.pl base_full_data new_subset_data
#...        Where base_full_data has all the data and new_subset_data
#...        has a subset of the full data.
#...        If new_subset_data has data where base_full_data does not have data,
#...        you will get a diff.
#...        This is useful in telling you that the new data has values that the
#...        base data does not have.
#...      If you specify ds_skip_undef, you will now skip undefined values in
#...      base_full_data (as well as the undefined values in new_subset_data).
#...      NOTE: this will typically only come into play where there is
#...      -nointp (no interpolation) done and you explicitly have undefined
#...      values in the base data.
#...
#...   -ds_(no)smooth <comma separated list of datasets to (not)smooth>
#...
#...   -fsets <n - number of file sets>
#...      (The default is the number of files <num files>)
#...      Multiple file sets can be compared.  Each corresponding file in
#...      each file set is compared.  So, if you specify the following
#...      on the command line:
#...        -fsets 3 a1 b1 a2 b2 a3 b3
#...      The following sets of file will be compared:
#...        (a1 vs. a2 vs. a3) and (b1 vs. b2 vs. b3)
#...      With lots of files/data, it is probably best not to do any
#...      plotting (-noplots) since the data file for plotting will be
#...      very large.
#...
#...   -ft <ares|ctf|cts|keyword|oxy|pop|table|tecplot|token|tracer|link|xy|xy_block>
#...      (By default, the type is determined automatically (by file name
#...       or a sampling of the source lines...if possible).)
#...      This specifies the data format of the file(s).
#...      o ctf file (cycle/time/<field>)
#...        ctf_process.pm can read different types of project files.
#...        Internally, each field (variable) has cycle, time, and value
#...        information.
#...        Files that can be processed:
#...          eap -ouput, screen output, various other eap files
#...          ctf data (so it can read in its own ctf_dump.txt file).
#...        Although it should not be needed, you can pass the ctf file type to
#...        the ctf reader by adding to the arg:
#...          -ft ctf:eap_output
#...          -ft ctf:eap_tracer
#...      o ares: Reads in the results from a suite of tests from a particular
#...        code project:
#...        | <Test Name> <PASSED|DIFF|FAILED>  P-<#>, D-<#>, F-<#>
#...        Each test name is its own dataset with an array of values
#...        (PASSED|DIFF|FAILED, P-#, D-#, F-#).
#...      o cts: Can read a the file produced when using the "-o" option.
#...        | # cts
#...        | # Dataset Name: <dataset name>
#...        | # Coord Name <X if it exists>: <coordinate name>
#...        | # Coord Name <Y - must exist>: <coordinate name>
#...        | <value 1 for coord X if it exists> <value 1 for coord Y>
#...        | <value 2 for coord X if it exists> <value 2 for coord Y>
#...        | ...repeat starting from Dataset Name for other datasets...
#...      o gmv
#...        Basic gmv processing (and probably will only work for the
#...        one file I am looking at:
#...          gmvinput ascii
#...          nodes -1 <#x> <#y> <#z>
#...          <list edge values>
#...          variable
#...          <variable> 0
#...          <variable values>
#...          <another variable>
#...          endvars
#...      o keyword: (cannot be autodetected)
#...        | <keyword> = <value>  (whitespace ignored - all on 1 line)
#...        | (all other lines ignored)
#...        dataset    = keyword
#...        X variable = none
#...        Y variable = keyword
#...      o oxy: Reads in files from a particular code project
#...        Various variables are read in for that particular file type.
#...        Previously, a post processor was used on the data to generate
#...        file type "xy".  Now, the original output file is parsed.
#...      o plot_output: plot_output.data file created by plot_output.pl
#...        You can give special "-ds" flags:
#...        -ds track
#...            skip the fields that will not track from run to run
#...            (like performance numbers)
#...        # [<num>] <dataset name>
#...        cycle  time  <col 1> <col 2> ...and so on
#...      o pop: This is a crude interpreter of the output from running
#...        this graphics package.
#...        Various keywords are found/used to create the data.
#...        dataset    = combo of card title/number and time ("* time").
#...        X variable = Line in output file: "* x var:"
#...        Y variable = Line in output file: "* y var:"
#...      o table: (lines are in columns with first line is header and
#...                following lines has columns of numbers)
#...        | <dataset name 1>  <dataset name 2> ...
#...        | <val ds 1>        <val ds 2>       ...
#...        | <val ds 1>        <val ds 2>       ...
#...        | ...               ...              ...
#...        | <2 or more blank lines means there is a new table>
#...        dataset    = dataset name
#...        X variable = none
#...        Y variable = dataset name
#...
#...        Note: I try to parse column headers that have whitespace
#...          in them...but it is hard if there is whitespace and non-number
#...          values for data lines.  So, best to not have whitespace in
#...          your column headers (and certainly not for data).
#...          If you have to have whitespace in places and cannot write your
#...          own pre-processor, let me know.
#...      o table_x: Like "table" but will use a particular column as the
#...        X variable:
#...          - look for "time" in any field
#...          - use first column otherwise
#...        If the first column is labeled "(i|time)", then table_x is
#...        automatically used.
#...      o tecplot: just trying to parse these in a reasonable way
#...          Format 1:
#...            title "<name><possible t=time c=cycle fields"
#...            variables <variable list>
#...              <variable time and cycle defs could be here also>
#...            zone f=point i=<number>
#...            <line of vals for each variable>
#...            <might have another block that resets cycle/time>
#...            ...repeat blocks of title/variables/zone/var vals
#...      
#...            These are stuffed into arrays:
#...               time, cycle, var1, var2, var3, ...
#...            The size of var1, var2, var3 must be a multiple of time.
#...            These blocks will be numbered and the block number will be
#...            appended to the variable name.  This allows each block to be
#...            things like:
#...               cell number  (each block is the value for a cell)
#...               group number (energy spectra)
#...          Format 2:
#...            Similar to above, but:
#...            - no title
#...            - ignore datapacking
#...      o tracer: (-tracer file ending and CSV file with particle/time fields)
#...        |  particle,      time, <dataset name 1>  <dataset name 2> ...
#...        | <particle #>, <time>, <val ds 1>        <val ds 2>       ...
#...        | <particle #>, <time>, <val ds 1>        <val ds 2>       ...
#...        |     ...         ...      ...              ...
#...        dataset    = p_<particle number>_<dataset name n>
#...        X variable = time
#...        Y variable = dataset name
#...      o link: (.lnk, .lnk.NNNNN file ending)
#...        Each whitespace separated token or Enn.n format real number
#...        is compared with the corresponding token in another file.
#...        dataset    = dataset name
#...        X variable = none
#...        Y variable = "token"
#...      o xy: (.std, .xy file endings, first line starts with # followed
#...             by 2 columns of values)
#...        | # <dataset name>
#...        | <x val> <y val>
#...        | <x val> <y val>
#...        | ...
#...        | # <dataset name>
#...        | <x val> <y val>
#...        | <x val> <y val>
#...        | ...[repeat for other datasets]
#...        dataset    = dataset name
#...        X variable = "X"
#...        Y variable = dataset name
#...      o xy_block: xy data but in special format
#...        Can be "," delimited or "," replaced with " ".
#...        Whitespace around symbols (eg "=") ignored.
#...        y-name data is listed first, followed by x-name data.
#...        | \${ignored} {ignored}='{var_start} ',
#...        | {y-name}(1,{index}) = {vals}
#...        |   {more vals}
#...        | {x-name}(1,{index}) = {vals}
#...        |   {more vals}
#...        | ...[repeat for other datasets]
#...        | \$end {does not need \$end...but anything afterwards ignored}
#...        dataset    = {var_start}_{index}
#...        X variable = {x-name}
#...        Y variable = {y-name}
#...      o token: (any other type)
#...        Each whitespace separated token is compared with the
#...        corresponding token in another file.
#...        dataset    = dataset name
#...        X variable = none
#...        Y variable = "token"
#...
#...      Additional Format Notes:
#...      o Values > 8e99 (GSKIP) or strings are tested for string match.
#...        If they are different, a difference is reported (but not used
#...        in the numerical analysis like mean, min, max, ...).
#...      o Blank lines are ignored.
#...
#...   -(no)inc
#...      (By default, inc is done)
#...      Data is pruned to enforce increasing X values.
#...         X Y      X Y
#...         1 2      1 2
#...         3 4      <dropped since later "3" <= "3" found>
#...         3 5   -> 3 5
#...         7 8      <dropped since later "6" <= "7" found>
#...         6 7      6 7
#...   -(no)intp
#...      (By default, interpolation is done)
#...      Turn on/off interpolation.  Each dataset will be diff'd as-is
#...      by comparing y-values of common x-values.  x-values that are
#...      not the same will be skipped.
#...      Interpolation does take extra time - so if you know that the
#...      files will have identical X values, turning this off will
#...      increase performance.
#...      Related: (no)intp, superset_x - see Examples below.
#...
#...    -(no)last <comma separated list of datasets>
#...      Compare the last element in the datasets as well as the whole dataset
#...
#...    -(no)last_only <comma separated list of datasets>
#...      Only compare the last element in the datasets
#...
#...   -o_<file type> <output data file>
#...      Write the data of the last file in the list of files to the
#...      specified output data file.  If only 1 file is given, that
#...      file will be written.
#...      Currently, the following ar supported output types:
#..         -o_cts : cts format
#...        -o_xy  : xy format
#...
#...      This is useful if the original data file is large and you
#...      only want to store the data to be diffed.
#...      NOTE: Datesets that are skipped upon read will not be printed
#...            upon write.
#...
#...   -or
#...      (The default is "and").
#...      This flag changes the default behavior when given both absolute
#...      and relative tolerances. With this flag,
#...      a value is "the same" if it is within (less than or equal to)
#...      _either_ the absolute _or_ relative tolerances.
#...
#...   --outdir <output directory>
#...      Default: $cmd{outdir}
#...      Directory to place files.
#...
#...   -(no)pargs
#...      Print the command line arguments that are actually used.
#...
#...   -(no)pft
#...      Print the file type of each file after it is read.
#...      Used to verify if this script detects the correct type of file.
#...
#...   -(no)plot_orig
#...      Do not compute differences - just plot the original data.
#...
#...   -(no)plotrun
#...      (By default, plots are created via gnuplot.)
#...      norungnuplot will just turn off the actuall running
#...      of gnuplot.
#...
#...   -(no)plots
#...      (By default, plots are created via gnuplot.)
#...
#...   -(no)presult
#...      Print the result at the end of each diff.
#...      Used by a project for greping.
#...        PASSED: No diffs.
#...        DIFF:   Diffs.
#...        FAILED: Failure (eg missing file, --ds_failed <ds list>, )
#...
#...   -(no)status
#...      Return a 0 regardless of if diffs are found or not.
#...      Useful since CTS stops for non-0 return status in .test files
#...      (if you would like to continue doing diffs).
#...
#...   --(no)unique_filenames
#...      default = yes
#...      Files created will be uniquely named so multiple cts_diff.pl
#...      commands will not overwrite existing output files.
#...      form:
#...         cts_diff.<notdir names of files>.<number>.<data, ps, pdf, ...>
#...
#...   --(no)scaled_r
#...      Use scaled relative tolerances.
#...
#...   --scaled_r_ds <dataset to scale with>,<comma separated list of regexp datasets>
#...     (no)scaled_r_ds <comma separated list of datasets>
#...      When scaled_r is set, the datasets that you are diffing are used
#...      to scale the relative differences.  You can, instead, supply a
#...      different dataset as the scaling.
#...      Useful for when two datasets have large relative differences, but
#...      are still small with respect to another dataset.
#...
#...      If given the "no" prefix, remove the dataset from this scaled_r_ds
#...      list.
#...
#...   --superset_x
#...     The x-values are a superset of the x-values of the base
#...     and the new datasets.
#...     Then the new and old are diff'd.
#...     Any x value that is not in both datasets will result in a
#...     string diff.
#...     This is useful if you expect all of the x-values to be the
#...     same in both datasets and want to report a diff otherwise.
#...     If the x-values are allowed to be different, then it is
#...     better to use intp/nointp options to allow the second dataset
#...     to be a subset of the first dataset.
#...     Related: (no)intp, superset_x - see Examples below.
#...
#...   -(no)t0
#...      Shift the first time of each file to be 0.  Useful if the starting
#...      time of each file is different, but are effectively the same due
#...      to simulation time noise at the beginng.  So, this will still allow
#...      interpolation.
#...
#...   -v <number>
#...      Verbosity.  Larger number -> more info printed
#...        0: No info printed - just return status.
#...        1: Final results from diffs of all files.
#...        2: Results from each file.
#...        3: (default) Results from each dataset in each file.
#...        4: Every difference.
#...           At this verbosity, different Base and New values are printed
#...           along with the common X value interpolated to.
#...               (X, y_base) vs. (X, y_new)
#...        5: All values (diffs +  non-diffs)
#...      Diff Types (T):
#...        A: absolute diff
#...        B: both absolute and relative diff
#...        M: missing
#...        R: relative diff
#...        S: string diff
#...
#...   --val_skip <abs value boundary to skip>[,<comma sep list of variable regexps>]
#...      If abs(variable_value) >= this_value, then replace that value with the
#...      skip value "-".
#...      If no list of variables, do to all variables.
#...      If a variable matches multiple variable regexps, the last one matched wins.
#...
#...Return Value
#...============
#... If the -nostatus flag is not set:
#...   0: No differences found
#...   1: Otherwise
#...
#...Files
#...=====
#...  $CTS_DIFF_FILE_CMD : command file used to generate plots
#...  $CTS_DIFF_FILE_PLOT_OUT : output from plot command (index)
#...  $CTS_DIFF_FILE_PS, $CTS_DIFF_FILE_PDF : plots
#...
#...Examples
#...========
#... 1) cts_diff.pl file1 file2 file3 -v 2 -noplots -ds foo,bar
#...    Diff between 3 files.
#...    Diff summary from each file is printed.
#...    No plots are produced.
#...    Only the datasets foo and bar will be compared.
#...
#... 2) cts_diff.pl file1 file2 -a .4 -r .1 -a 10,xvel -or -o dat_file
#...    Diff two files.
#...    Data points are considered the "same" if
#...     absolute value of difference is <= .4 (-a .4) or (-or)
#...     the absolute value of the relative difference is <= .1 (-r .1).
#...     For the dataset "xvel", use the absolute tolerance of 10 instead
#...     of .4 .
#...    Plots will be produced.
#...    Create an output data file of the data in file2.
#...    Default verbosity (summary of diff).
#...
#... 3) cts_diff.pl gold_2002/* gold_2003/* gold_2004/* -fsets 3
#...    Diff three sets of gold standard files using gold_2002 as the base
#...    set.
#...
#... 4) cts_diff.pl foo1-tracer foo2-tracer \
#...                --time_range f:p_1_ne::f:p_10_ne \
#...                --time_shift f:p_1_ne
#...    Diff the 2 tracer files but
#...      start when particle 1  ne value starts changing
#...      stop  when particle 10 ne value stop   changing
#...      Set time=0 for each file when its particle 1 ne value has first max
#...    This is useful when you have lots of dead data at the start/stop of
#...    the run and normalize each run to have time=0 when they start.
#...
#... 5) intp .vs. nointp .vs. superset_x
#...    cts_diff.pl -v 5 --intp (-intp == default)
#...      Diff file_b y-values and interpolate file_a x-values as needed.
#...      intp:
#...         file_a                              file_b
#...        time val                            time val
#...          1  10   --> intp x,y to 1.1,11 --> 1.1  11 (pass numerical)
#...          2  20   --> intp x,y to 2,20   --> 2    21 (diff numerical)
#...          3  30   SKIP (outside range of file_b)
#...
#...    cts_diff.pl -v 5 --nointp
#...      Diff file_b y-values that have same x-value.
#...      nointp:
#...         file_a                              file_b
#...        time val                            time val
#...          1  10   SKIP (not in file_a)       1.1  11 (pass since SKIP)
#...          2  20   --> diff x same        --> 2    21 (diff)
#...          3  30   SKIP (not in file_b)
#...
#...    cts_diff.pl -v 5 --superset_x
#...      Create superset of file_a and file_b x-values and diff.
#...      nointp:
#...         file_a                              file_b
#...        time val                            time val
#...          1  10   --> diff since undef   --> (undef) (diff missing)
#...          (undef) --> diff since undef   --> 1.1  11 (diff missing)
#...          2  20   --> diff x same        --> 2    21 (diff numerical)
#...          3  30   --> diff since undef   --> (undef) (diff missing)
#...
#... 6) cts_diff.pl -ds_cmp 'v>0 && v<=1e2',var_. dummy my_table.txt
#...    Diff of the vars matching var_. in my_table.txt for being
#...    outside of the range specified.
#...    Use the dummy base file 'dummy' so that you do not need a file.
#...
#............................................................................
EOF
  exit;
  }

#............................................................................
#...Program Flow
#...============
#...1) parse command line
#...2) read in first file (base)
#...3) process each file
#...3.1) read file
#...3.2) for each dataset
#...3.2.1) diff/stat/print coordinates (X and Y data)
#...3.3) print file stats
#...4) print total stats
#...5) run gnuplot
#............................................................................

# create unique filenames
if( defined($cmd{unique_filenames}) ){
    &cts_diff_unique_filenames( \%cmd );
}

# print stuff if verbose:
if( $cmd{v} > 0 ){
    print "\n$0\n\n";

    # print any arg_file
    if( $cmd{v} > 0 ){
        foreach $arg_file ( @{$cmd{arg_files}} ){
            print "-arg $arg_file\n";
        }
        if( $#{$cmd{arg_files}} >= 0 ){
            print "\n";
        }
    }
    
    # print out all arguments
    if( defined( $cmd{pargs} ) ){
        $num_args = $#{$cmd{command_line}};
        if( $num_args >= 0 ){
            print "$0 \\\n";
            $i = 0;
            foreach $opt ( @{$cmd{command_line}} ){
                print "  $opt";
                if( $i < $num_args ){
                    print " \\";
                }
                print "\n";
                $i++;
            }
            print "\n";
        }
    }
}
#...........................
#...default file set size...
#...........................
if( !defined( $cmd{fsets} ) || $cmd{fsets} <= 0 )
  {
    $cmd{fsets} = $#{$cmd{files}}+1;
  }
$headers_printed = 0;
$num_compare_groups = ($#{$cmd{files}} + 1) / $cmd{fsets};
$last = "";
#................................
#...process each compare group...
#................................
for( $compare_group = 1; $compare_group <= $num_compare_groups;
     $compare_group++ ) {
    undef( %stat_cmp_grp );
    undef( %result_diff );
    #......................
    #...create file list...
    #......................
    $index = $compare_group-1;
    undef( @files );
    for( $i = 0; $i < $cmd{fsets}; $i++ )
      {
        push( @files, $cmd{files}[$index] );
        $index = $index + $num_compare_groups;
      }

    # read in first file - this is the base
    undef( %data_base );
    #printf "debug %20s %s", "before read", `date "+\%S \%N"`;
    $time{b_read}{start} = time();
    $ierr = cts_diff_util::read_file( $files[0], \%cmd, \%data_base );
    $time{b_read}{sum} += time() - $time{b_read}{start};
    #printf "debug %20s %s", "after read", `date "+\%S \%N"`;
    if( $ierr != 0 )
      {
        cts_diff_util::print_error( "FAILED: Error in reading data file(s)",
                                    $ierr );
        exit( $ierr );
      }
    $is_diff = 0;
    undef( %ds_diffs );
    $file_base = $files[0];

    # process each file
    for( $i = 1; $i <= $#files; $i++ ) {
        $file_num = $i;
        #...............
        #...read file...
        #...............
        $file_name = $files[$i];
        $file_new = $files[$i];
        undef( %data );
        #printf "debug %20s %s", "before read", `date "+\%S \%N"`;
        $time{b_read}{start} = time();
        $ierr = cts_diff_util::read_file( $file_name, \%cmd, \%data );
        $time{b_read}{sum} += time() - $time{b_read}{start};
        #printf "debug %20s %s", "after read", `date "+\%S \%N"`;
        if( $ierr != 0 )
          {
            cts_diff_util::print_error( "FAILED: Error in reading data file(s)",
                                        $ierr );
            exit( $ierr );
          }

        #......................
        #...get all ds_names...
        #......................
        undef( %ds_names );
        foreach $ds_name ( keys %{$data_base{$GDATA}} )
          {
            $ds_names{$ds_name} = "";
          }
        foreach $ds_name ( keys %{$data{$GDATA}} )
          {
            $ds_names{$ds_name} = "";
          }
        undef( %stat_file );

        #..............................................
        #...diff each dataset with base file dataset...
        #..............................................
        foreach $ds_name ( sort keys %ds_names ) {

            # skip if given "dummy" file and ds not in
            #   ds_base
            #   ds_cmp
            if( $file_base eq "dummy" ){
                undef( $val );
                $val = &get_val_regexp( \%cmd, $ds_name, "ds_base" );
                if( ! defined( $val ) ){
                    $val = &get_val_regexp( \%cmd, $ds_name, "ds_cmp" );
                }
                if( ! defined( $val ) ){
                    next;
                }
            }

            $is_diff_local = 0;

            # do full dataset diff (if not a do_last_only dataset - those
            # will be done by themselves)
            $do_last_only = &cts_get_val( $ds_name, \%{$cmd{"last_only"}} );
            if( !defined( $cmd{plot_orig} ) && ! defined( $do_last_only )  ){
                $time{c_diff}{start} = time();
                &do_diff( \%cmd,
                          $file_base,
                          $file_new,
                          \%data,
                          \%data_base,
                          $ds_name,
                          \%stat_file,
                          \%ds_diffs,
                          \$headers_printed,
                          \$is_diff_local,
                          \$is_diff,
                          \%{$result_diff{$compare_group}{$file_num}},
                          \$last,
                    );
                $time{c_diff}{sum} += time() - $time{c_diff}{start};
            }

            # if diffs on last, still a diff
            if( $is_diff_local > 0 ){
                $is_diff = 1;
                $ds_diffs{$ds_name} = "";
            }

            # print_gnuplot_data if (diff of data or last) or plot_orig
            if( defined( $cmd{plots} ) &&
                ( $is_diff_local != 0 || defined( $cmd{plot_orig} ) ) ) {
                if( defined( $data{$GDATA}{$ds_name}{$GCOORDY} ) ) {
                    $print_var = "cmp=$compare_group:$ds_name";
                    $print_source = sprintf( "cmp=%3d:%3d:%s",
                                             $compare_group, $i, $file_new );
                    $print_title = sprintf( "%s vs. %s -> {ds}%s",
                                            $file_base, $file_new,
                                            $ds_name
                        );
                    #printf "debug %20s %s", "before print_gnuplot", `date "+\%S \%N"`;
                    $time{d_gnuplot_data}{start} = time();
                    cts_diff_util::print_gnuplot_data( \%{$data{$GDATA}{$ds_name}},
                                                       $print_var,
                                                       $print_source,
                                                       $print_title,
                                                       \%gnuplot_info );
                    $time{d_gnuplot_data}{sum} += time() - $time{d_gnuplot_data}{start};
                    #printf "debug %20s %s", "after print_gnuplot", `date "+\%S \%N"`;
                }
            }

            # no longer needed so free up memory
            delete( $data{$GDATA}{$ds_name} );

        }
        #....................................................
        #...DONE: diff each dataset with base file dataset...
        #....................................................

        #.....................................................
        #...merge file to cmp_group stats and print abs/rel...
        #.....................................................
        cts_diff_util::merge_stats( \%{$stat_file{$GABS}},
                                    \%{$stat_cmp_grp{$GABS}} );
        cts_diff_util::merge_stats( \%{$stat_file{$GREL}},
                                    \%{$stat_cmp_grp{$GREL}} );
        if( $cmd{v} >= 2 ){
            if( defined( $stat_file{$GABS}{$GNUMTRUE} ) && $stat_file{$GABS}{$GNUMTRUE} > 0 ) {
                $print_title = sprintf( "   %d:%d %s vs. %s",
                                        $compare_group, $file_num, $file_base, $file_new );
                cts_diff_util::print_abs_rel_stats( $print_title,
                                                    \%{$stat_file{$GABS}},
                                                    \%{$stat_file{$GREL}} );
            }
        }
        #...........................................................
        #...DONE: merge file to cmp_group stats and print abs/rel...
        #...........................................................

        # say what files were diffed for last
        if( $last ne "" ){
            $last .= "$file_base vs. $file_new\n";
        }
        
    } # foreach file
    undef( %data );
    #.............................
    #...DONE: process each file...
    #.............................

    #..............................
    #...plot data_base if needed...
    #..............................
    if( defined( $cmd{plots} ) ) {
        #...................................................................
        #...get list of datasets to plot - all if plot_orig or only diffs...
        #...................................................................
        if( defined( $cmd{plot_orig} ) )
          {
            $ds_names_ref = \%{$data_base{$GDATA}};
          }
        else
          {
            $ds_names_ref = \%ds_diffs;
          }

        foreach $ds_name ( sort keys %$ds_names_ref ) {
            if( defined( $data_base{$GDATA}{$ds_name}{$GCOORDY} ) ) {
                $print_var = "cmp=$compare_group:$ds_name";
                $print_source = sprintf( "cmp=%3d:%3d:%s",
                                       $compare_group, 0, $file_base );
                $print_title = sprintf( "base %s -> {ds}%s",
                                        $file_base, $ds_name
                                      );

                #.......................................................
                #...create 0 diff data: keeps key and draws diff axis...
                #.......................................................
                if( ! defined( $cmd{plot_orig} ) ) {
                    #printf "debug %20s %s", "before base diff", `date "+\%S \%N"`;
                    $print_header = "";
                    $print_diff = "";
                    cts_diff_util::create_diff( \@{$data_base{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                                                \@{$data_base{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                                                \%cmd,
                                                $data_base{$GDATA}{$ds_name}{$GCOORDY}{$GNAME},
                                                0, undef,
                                                \%{$data_base{$GDATA}{$ds_name}{$GCOORDY}{$GDIFF}},
                                                \$num_diffs,
                                                \$print_header,
                                                \$print_diff );
                    #printf "debug %20s %s", "after base diff", `date "+\%S \%N"`;
                }
                #.............................................................
                #...DONE: create 0 diff data: keeps key and draws diff axis...
                #.............................................................

                #printf "debug %20s %s", "before print_gnuplot", `date "+\%S \%N"`;
                $time{d_gnuplot_data}{start} = time();
                cts_diff_util::print_gnuplot_data( \%{$data_base{$GDATA}{$ds_name}},
                                                   $print_var, $print_source,
                                                   $print_title,
                                                   \%gnuplot_info );
                #printf "debug %20s %s", "after print_gnuplot", `date "+\%S \%N"`;
                $time{d_gnuplot_data}{sum} += time() - $time{d_gnuplot_data}{start};
            }
        }
    }
    undef( %data_base );
    #....................................
    #...DONE: plot data_base if needed...
    #....................................

    #..............................................
    #...merge cmp_group to total and print stats...
    #..............................................
    cts_diff_util::merge_stats( \%{$stat_cmp_grp{$GABS}},
                                \%{$stat_total{$GABS}} );
    cts_diff_util::merge_stats( \%{$stat_cmp_grp{$GREL}},
                                \%{$stat_total{$GREL}} );
    if( $cmd{v} == 1 ||
        $cmd{v} == 2 && $#files > 1 ||
        $cmd{v} >= 3 ){
        if( defined($stat_cmp_grp{$GABS}{$GNUMTRUE}) && $stat_cmp_grp{$GABS}{$GNUMTRUE} > 0 ) {
            $print_title = sprintf( "  %d:A base %s", $compare_group, $file_base );
            cts_diff_util::print_abs_rel_stats( $print_title,
                                                \%{$stat_cmp_grp{$GABS}},
                                                \%{$stat_cmp_grp{$GREL}} );
        }
    }
}
#......................................
#...DONE: process each compare group...
#......................................

#.....................................................
#...print total stats (unless only 1 compare group)...
#.....................................................
if( $cmd{v} > 0 && $num_compare_groups > 1 ){
    if( $stat_total{$GABS}{$GNUMTRUE} > 0 ) {
        $print_title = sprintf( "%s", "Total" );
        cts_diff_util::print_abs_rel_stats( $print_title,
                                            \%{$stat_total{$GABS}},
                                            \%{$stat_total{$GREL}} );
    }
}

# print "last"
if( $last ne "" ){
    print "\n";
    print $last;
}

#.............................
#...print out -presult info...
#.............................
if( defined( $cmd{presult} ) ) {
    $presult = "\n";
    $maxlen = 0;
    foreach $compare_group ( sort numerically keys %result_diff ){
        foreach $file_num ( sort numerically keys %{$result_diff{$compare_group}} ){
            foreach $coord_name ( sort keys %{$result_diff{$compare_group}{$file_num}{num}} ){
                $maxlen_try = length($result_diff{$compare_group}{$file_num}{num}{$coord_name});
                if( $maxlen_try > $maxlen ){
                    $maxlen = $maxlen_try;
                }
            }
        }
    }
    foreach $compare_group ( sort numerically keys %result_diff ){
        foreach $file_num ( sort numerically keys %{$result_diff{$compare_group}} ){
            foreach $coord_name ( sort keys %{$result_diff{$compare_group}{$file_num}{num}} ){
                $result = "$result_diff{$compare_group}{$file_num}{result}{$coord_name}";
                ($result_prune = $result) =~ s/\s+//;
                $result_type{$result_prune} = "";
                $presult .= sprintf( "%s cts_diff.pl %${maxlen}s [%s:%s:%s]\n",
                                    $result,
                                    $result_diff{$compare_group}{$file_num}{num}{$coord_name},
                                    $compare_group, $file_num, $coord_name );
            }
        }
    }

    # final result flag
    if( defined( $result_type{FAILED} ) ){
        $flag = "FAILED";
    }
    elsif( defined( $result_type{DIFF} ) || $is_diff != 0 ){
        $flag = "DIFF  ";
    }
    else{
        $flag = "PASSED";
    }

    $presult_f = sprintf( "\n%s cts_diff.pl: %s\n", $flag, join( " ", @{$cmd{files}} ) );
    $presult .= $presult_f;

    if( open( FILE, ">$CTS_DIFF_FILE_PRESULT") ){
        print FILE $presult;
        close( FILE );
        print $presult_f;
        print "See $CTS_DIFF_FILE_PRESULT\n";
        print "pwd: ".`pwd`;
    }
    else{
        print $presult;
    }
}

#.................
#...run gnuplot...
#.................
if( defined( $cmd{plots} ) && %gnuplot_info )
  {
    $time{e_gnuplot}{start} = time();
    if( $cmd{v} >= 1 )
      {
        print "\nCreating Gnuplot Plots\n";
      }
    #printf "debug %20s %s", "before run_gnuplot", `date "+\%S \%N"`;
    #$gnuplot_info{orientation} = "portrait";
    cts_diff_util::run_gnuplot( \%gnuplot_info, \%cmd );
    #printf "debug %20s %s", "after run_gnuplot", `date "+\%S \%N"`;
    $time{e_gnuplot}{sum} += time() - $time{e_gnuplot}{start};
  }

# timing results
$time{a_all}{sum} += time() - $time{a_all}{start};
if( $cmd{v} > 0 ){
    print "\nTiming:";
    foreach $time_field ( sort keys %time ){
        ($time_field_print = $time_field) =~ s/^._//;
        printf( " ${time_field_print}=%.2f", $time{$time_field}{sum}/60 );
    }
    print "\n";
}

if( $cmd{v} >= 1 ){
    print "\n";
}

if( !defined( $cmd{status} ) )
  {
    exit( 0 );
  }
else
  {
    exit( $is_diff );
  }

# sub numerically for sorting
sub numerically { $a <=> $b; }

#.............................................................................
#............................. Subroutines ...................................
#.............................................................................
sub do_diff
  {
    my(
       $cmd_ref,
       $file_base,
       $file_new,
       $data_ref,
       $data_base_ref,
       $ds_name,
       $stat_file_ref,
       $ds_diffs_ref,
       $headers_printed_ref,
       $is_diff_local_ref,   # does not reset - cumulative with last and full
       $is_diff_ref,
       $result_diff_ref,
       $last_ref,
      ) = @_;
    my(
       @array_common_x,
       $array_ref, # temp array reference
       $array_base_ref, # reference array (interpolated, raw, ... )
       $array_base_x_ref, # x array
       $array_diff_ref,
       @array_new_base_y,
       $array_new_ref, # new array (might be modified to skip non-common values)
       $array_new_x_ref, # x array
       @array_new_y,
       $array_x_ref, # reference to orig array
       $array_y_ref,
       $coord_name, # name of the coordinate
       $ds_failed,
       $ds_nofailed,
       $flag,
       $found, # if found a match
       %hash_base_x,
       %hash_new_x,
       $hash_ref,
       $i, # loop var
       $ierr, # error return value
       $index_base, # current index into base
       $index_last_base, # last index
       $index_last_new, # last index
       $j,
       @array_x, # x array if needed
       @array_base_intp, # interpolated array
       @array_common_base, # base array with common balues
       $match,
       $name_it,
       $num, # number
       $num_diffs, # the number of diffs after create_diff
       $num_parsed, # number of values actually looked at
       $print_title, # the title to use for printing
       $print_diffs, # if printing the individual diffs
       $print_str_diff,
       $print_str_diff_tmp,
       $print_str_header,
       $print_str_header_tmp,
       $result_print, # for printing ration of diffs or passed
       $skip_undef,
       %stat, # stats for the diff
       %tmp_array_diff,
       $val,
       $val_rms,
       $val_x_new, # value
       $val_x_base, # value
       $x,
      );

    # report failed or diff
    if( defined( $$cmd_ref{$GDS_FAILED} ) ){
        $ds_failed = $$cmd_ref{$GDS_FAILED};
        if( defined( $$cmd_ref{$GDS_NOFAILED} ) ){
            $ds_nofailed = $$cmd_ref{$GDS_NOFAILED};
        }
        else{
            $ds_nofailed = "";
        }
    }
    else{
        $ds_nofailed = "";
        $ds_failed = "";
    }

    # get rid of warning
    $headers_printed_ref = $headers_printed_ref;

    #..................................
    #...if printing every difference...
    #..................................
    $print_diffs = $$cmd_ref{v};

    # if ds_base/ds_cmp for this ds_name, insert/overwrite the base data
    # with the value
    # ds_base
    $val = &get_val_regexp( $cmd_ref, $ds_name, "ds_base" );
    # ds_cmp
    if( ! defined( $val ) ){
        $val = &get_val_regexp( $cmd_ref, $ds_name, "ds_cmp" );
        if( defined( $val ) &&
            $val =~ /($GNUMBER_REGEXP)/ ){
            $val = $1;
        }
    }
    if( defined($val) ){
        # ds does not exist - create it on base
        # it must have already existed on the new...so use those values
        # for names
        if( ! defined($$data_base_ref{$GDATA}{$ds_name}) ){
            push( @{$$data_base_ref{$GDATASET_NAMES}}, $ds_name );
        }
        # always overwrite names with ones seen in new
        $$data_base_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} =
            $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME};
        $$data_base_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} =
            $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME};
        # set x-values to match x ones in new
        # set y-values to match val
        delete( $$data_base_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG} );
        delete( $$data_base_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG} );
        @{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}} = 
            @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}};
        $num = $#{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}} + 1;
        @{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}} = (($val) x $num);
    }

    # add stat field if required (scaled_r_ds)
    # save it to scaled_r_ds_val if you are going to use it
    undef( $val_rms );
    if( defined( $$cmd_ref{scaled_r_ds} ) ){
        # if this ds specifies a ds from scaled_r_ds
        $val = &cts_get_val( $ds_name, \%{$$cmd_ref{scaled_r_ds}}, \$found );
        if( defined($val) ){
            # if the ds=$val exists in the base
            if( defined($$data_base_ref{$GDATA}{$val}) ){
                # if that dataset does not have stats done yet, do them
                if( ! defined($$data_base_ref{$GDATA}{$val}{$GCOORDY}{stats}) ){
                    &create_stats( \@{$$data_base_ref{$GDATA}{$val}{$GCOORDY}{$GORG}},
                                   \%{$$data_base_ref{$GDATA}{$val}{$GCOORDY}{stats}} );
                }
            }
            $val_rms = $$data_base_ref{$GDATA}{$val}{$GCOORDY}{stats}{RMS};
        }
    }
    $$cmd_ref{scaled_r_ds_val} = $val_rms;

    # if base and new exist
    #   both have to exist to do interpolation or matching values
    if( defined( $$data_base_ref{$GDATA}{$ds_name} ) &&
        defined( $$data_ref{$GDATA}{$ds_name} ) && 
        defined( $$data_base_ref{$GDATA}{$ds_name}{$GCOORDX} ) &&
        defined( $$data_ref{$GDATA}{$ds_name}{$GCOORDX} ) ){

        $array_diff_ref = \%{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GDIFF}};

        # superset_x
        # kinda a weird one given the design of cts_diff.pl
        if( defined( $$cmd_ref{superset_x} ) ){

            $array_base_x_ref = \@{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}};
            $array_base_ref   = \@{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}};
            $array_new_x_ref  = \@{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}};
            $array_new_ref    = \@{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}};

            undef( @array_common_x );
            undef( %hash_base_x );
            undef( %hash_new_x );

            # hash_base_x and push to @array_common_x
            $array_ref   = $array_base_x_ref;
            $array_y_ref = $array_base_ref;
            $hash_ref = \%hash_base_x;
            if( defined($array_ref) ){
                for( $i = 0; $i <= $#{$array_ref}; $i++ ){
                    $$hash_ref{$$array_ref[$i]} = $$array_y_ref[$i];
                }
                push( @array_common_x, keys %$hash_ref );
            }

            # hash_new_x  and push to @array_common_x
            $array_ref   = $array_new_x_ref;
            $array_y_ref = $array_new_ref;
            $hash_ref = \%hash_new_x;
            if( defined($array_ref) ){
                for( $i = 0; $i <= $#{$array_ref}; $i++ ){
                    $$hash_ref{$$array_ref[$i]} = $$array_y_ref[$i];
                }
                push( @array_common_x, keys %$hash_ref );
            }

            # sort_numerically_unique
            @array_common_x = &sort_numerically_unique( \@array_common_x );
            $array_x_ref = \@array_common_x;

            # $array_base_ref superset x
            @array_new_base_y = ();
            $array_ref = \@array_new_base_y;
            $hash_ref  = \%hash_base_x;
            foreach $x ( @$array_x_ref ){
                if( defined($$hash_ref{$x}) ){
                    push( @$array_ref, $$hash_ref{$x} );
                }
                else{
                    push( @$array_ref, undef );
                }
            }
            $array_base_ref = $array_ref;

            # $array_new_ref superset x
            @array_new_y = ();
            $array_ref = \@array_new_y;
            $hash_ref  = \%hash_new_x;
            foreach $x ( @$array_x_ref ){
                if( defined($$hash_ref{$x}) ){
                    push( @$array_ref, $$hash_ref{$x} );
                }
                else{
                    push( @$array_ref, undef );
                }
            }
            $array_new_ref = $array_ref;

            # overwrite with new values
            # NOTE: this gets a bit weird when you diff >2 datasets
            #   since new one adds to the list of new x-values.
            #   If it comes up, might need to create union of all
            #   at the beginning then do diffs (or something).
            @{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}} = @{$array_x_ref};
            @{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}} = @{$array_base_ref};
            @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}}      = @{$array_x_ref};
            @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}}      = @{$array_new_ref};


        } # superset_x

        # no interpolation
        # diff arrays based on common x-values
        elsif( ! defined($$cmd_ref{intp} ) ){
            $array_base_x_ref = \@{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}};
            $array_base_ref   = \@{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}};
            $array_new_x_ref  = \@{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}};
            $array_new_ref    = \@{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}};
            $index_base = 0;
            $index_last_base = $#{$array_base_ref};
            $index_last_new  = $#{$array_new_ref};

            # default skip if new not defined (unless noskip_undef)
            # Theory is that you want to be able to diff:
            #   diff base_all_data new_subset_data
            # and automatically skip over parts of "new" not defined that are in base.
            $skip_undef = "";
            if( defined($$cmd_ref{ds_noskip_undef}) ){
                $match = $$cmd_ref{ds_noskip_undef};
                if( $ds_name =~ /^($match)$/ ){
                    undef( $skip_undef );
                }
            }

            undef( @array_common_base );
            
            # go through values defined on the new array
            for( $i = 0; $i <= $index_last_new; $i++ ){

                # go through values on base array
                $val_x_new = $$array_new_x_ref[$i];
                undef( $found );
                for( $j = $index_base; $j <= $index_last_base; $j++ ){
                    $val_x_base = $$array_base_x_ref[$j];
                    
                    # if reached x value on base array
                    if( $val_x_base >= $val_x_new ){
                        # if x values match, have a match
                        if( $val_x_base == $val_x_new ){
                            $found = "";
                        }
                        # regardless, set new start search point
                        $index_base = $j;
                        last;
                    }
                }

                # if found match, the push onto arrays to diff
                if( defined( $found ) ){
                    push( @array_x, $val_x_new );
                    push( @array_common_base, $$array_base_ref[$index_base] );
                }
                else{
                    push( @array_common_base, undef );
                    push( @array_x, undef );
                }
            }
            
            # set references to diff
            $array_x_ref    = \@array_x;
            $array_base_ref = \@array_common_base;

        } # no interpolation

        #..............................................................
        #...if X coords exist for both current and base, interpolate...
        #...from (base.x, base.y) -> (new.x, base.y)                ...
        #..............................................................
        else{ 
            undef( @array_base_intp );
            $array_x_ref = \@{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}};
            $ierr = cts_diff_util::interpolate( \@{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}},
                                                \@{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                                                $array_x_ref,
                                                \@array_base_intp );
            if( $ierr != 0 ){
                cts_diff_util::print_error( "Interpolation failed for",
                                            "File: [$file_base]",
                                            "Dataset: [$ds_name]",
                                            "Using uninterpolated values",
                                            0 );
                $array_base_ref = \@{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}};
            }
            else{
                $array_base_ref = \@array_base_intp;
            }
            $array_new_ref = \@{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}};
        }
    } # if base and new exist
    
    # either is missing - will result in a diff unless skip_undef
    else{
        # have base
        if( defined( $$data_base_ref{$GDATA}{$ds_name} ) &&
            defined( $$data_base_ref{$GDATA}{$ds_name}{$GCOORDY} ) ){
            $array_base_ref = \@{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}};
            $array_new_ref  = undef;
            $array_x_ref    = \@{$$data_base_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}};
            $array_diff_ref = \%tmp_array_diff;
            # need to fill in missing data for reference
            $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = "-";            
            $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}[0] = undef;            
        }

        # have ref
        else{
            $array_base_ref = undef;
            $array_new_ref  = \@{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}};
            $array_x_ref    = undef;
            $array_diff_ref = \%{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GDIFF}};
        }
    }

    #..........................................................
    #...get coordinate name from data, data_base, or default...
    #..........................................................
    $coord_name = $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME};
    # if not there, pick name from data_base_ref
    if( ! defined( $coord_name ) ||
        $coord_name eq "-" )
      {
        $coord_name = $$data_base_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME};
      }
    # if still not there, just global GCOORDY
    if( ! defined( $coord_name ) ||
        $coord_name eq "-" )
      {
        $coord_name = $GCOORDY;
      }
    #.............................................
    #...reset coord name incase was not defined...
    #.............................................
    if( defined($$data_ref{$GDATA}{$ds_name}) ){
        $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME}      = $coord_name;
    }
    if( defined($$data_base_ref{$GDATA}{$ds_name}) ){
        $$data_base_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = $coord_name;
    }

    # name to use in printing
    if( $ds_name eq $coord_name ){
        $name_it = "{ds+$GCOORDY}$ds_name";
    }
    else{
        $name_it = "{ds}${ds_name}{$GCOORDY}$coord_name";
    }

    #..........
    #...diff...
    #..........
    $num_diffs = 0;
    #printf "debug %20s %s", "before diff", `date "+\%S \%N"`;
    $print_str_header = "";
    $print_str_diff = "";
    # :ctslast will be printed later - so skip here
    if( $ds_name =~ /:ctslast$/ ){
        $print_diffs = "last";
    }
    $print_str_header_tmp = "";
    $print_str_diff_tmp = "";
    cts_diff_util::create_diff( $array_base_ref,
                                $array_new_ref,
                                $cmd_ref,
                                $coord_name,
                                $print_diffs,
                                $array_x_ref,
                                $array_diff_ref,
                                \$num_diffs,
                                \$print_str_header_tmp,
                                \$print_str_diff_tmp );
    if( $print_diffs eq "last" ){
        if( $print_str_header_tmp =~ /\S/ && $$last_ref eq "" ){
            $$last_ref .= "Last Results:\n";
            $$last_ref .= "=============\n";
            $$last_ref .= $print_str_header_tmp;
        }
        $$last_ref .= $print_str_diff_tmp;
    }
    else{
        $print_str_header .= $print_str_header_tmp;
        $print_str_diff .= $print_str_diff_tmp;
    }
    $print_diffs = $$cmd_ref{v};
    
    # print header
    if( ! defined( $CTS_PRINTED_HEADER ) && $$cmd_ref{v} >= 1 ){
        print "\n";
        print "Results:\n";
        print "========\n";
        printf $print_str_header;
        $CTS_PRINTED_HEADER = "";
    }

    # fill into result_diff_ref
    $num_parsed = $#{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GDIFF}{$GREL}} + 1;
    if( $num_diffs > 0 ){
        if( $ds_name =~ /^(${ds_failed})(:ctslast)?$/ &&
            $ds_name !~ /^(${ds_nofailed})(:ctslast)?$/ ){
            $flag = " FAILED";
        }
        else{
            # if either missing, treat that as FAILED
            if( $$array_diff_ref{type}[-1] eq "M" ){
                $flag = " FAILED";
            }
            else{
                $flag = "DIFF   ";
            }
        }
        $$result_diff_ref{result}{"$name_it"} = $flag;
        $result_print = sprintf("%d/%d", $num_diffs, $num_parsed );
        $$result_diff_ref{num}{"$name_it"} = $result_print;
    }
    else{
        $$result_diff_ref{result}{"$name_it"} = "PASSED ";
        $result_print = sprintf("%d", $num_parsed );
        $$result_diff_ref{num}{"$name_it"} = $result_print;
    }

    #printf "debug %20s %s", "before stats", `date "+\%S \%N"`;
    cts_diff_util::create_stats( $$array_diff_ref{$GABS}, \%{$stat{$GABS}}, $$array_diff_ref{type} );
    cts_diff_util::create_stats( $$array_diff_ref{$GREL}, \%{$stat{$GREL}}, $$array_diff_ref{type} );
    cts_diff_util::merge_stats( \%{$stat{$GABS}}, \%{$$stat_file_ref{$GABS}} );
    cts_diff_util::merge_stats( \%{$stat{$GREL}}, \%{$$stat_file_ref{$GREL}} );
    
    # print vals if requested
    if( $print_str_diff ne "" ){
        if( $print_diffs >= 4 ){
            printf $print_str_diff;
        }
    }
    
    #printf "debug %20s %s", "after diff", `date "+\%S \%N"`;
    if( $num_diffs > 0 ) {
        $$ds_diffs_ref{$ds_name} = "";
        $$is_diff_local_ref = 1;
        $$is_diff_ref = 1;
    }
    
    if( $$is_diff_local_ref > 0 || $print_diffs >= 5 ){
        $print_title = sprintf( "%s vs. %s %s",
                                $file_base, $file_new, $name_it );
        cts_diff_util::print_abs_rel_stats( "    $print_title",
                                            \%{$stat{$GABS}},
                                            \%{$stat{$GREL}} );
    }
    
  }


=head1 COPYRIGHT AND LICENSE

 Copyright (2006). The Regents of the University of California. This material was
 produced under U.S. Government contract W-7405-ENG-36 for Los Alamos National
 Laboratory, which is operated by the University of California for the U.S. Department
 of Energy. The U.S. Government has rights to use, reproduce, and distribute this
 software.  NEITHER THE GOVERNMENT NOR THE UNIVERSITY MAKES ANY WARRANTY, EXPRESS OR
 IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE. If software is
 modified to produce derivative works, such modified software should be clearly marked,
 so as not to confuse it with the version available from LANL.

 Additionally, this program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by the Free Software
 Foundation; either version 2 of the License, or (at your option) any later version.
 Accordingly, this program is distributed in the hope that it will be useful, but WITHOUT
 ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
 PARTICULAR PURPOSE. See the GNU General Public License for more details.



=cut

