#.........................................................
#...Various utilities for doing diffs on files        ...
#.........................................................
package cts_diff_util;

use     POSIX qw( strtod );
use     diagnostics;
use     warnings;
use     Carp;
use     vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION );
use     Exporter;
use     my_utils qw (
                     print_error
                     print_perl_obj
                     ppo
                     run_command
                     status_bar
                     which_exec
                     my_smooth
                    );

use ctf_process qw (
                    ctf_read
                   );

$VERSION   = 1.00;

@ISA       = qw(
                Exporter
               );

@EXPORT    = qw(
               );

@EXPORT_OK = qw(
                &check_format_ds_data
                &check_format_data
                &create_diff
                &create_stats
                &cts_diff_unique_filenames
                &cts_get_val
                &get_file_type
                &get_tols
                &get_val_regexp
                &interpolate
                &merge_stats
                &parse_args
                &print_abs_rel_stats
                &print_gnuplot_data
                &run_gnuplot
                &read_file
                &which_exec
                $CTS_DIFF_FILE_CMD
                $CTS_DIFF_FILE_PDF
                $CTS_DIFF_FILE_PLOT_OUT
                $CTS_DIFF_FILE_PRESULT
                $CTS_DIFF_FILE_PS
                $GDATA
                $GDATASET_NAMES
                $GDS_FAILED
                $GDS_NOFAILED
                $GNAME
                $GORG
                $GCOORDX
                $GCOORDY
                $GDIFF
                $GMAX
                $GMEAN
                $GMIN
                $GRMS
                $GMAXABS
                $GSKIP
                $GSUMSQ
                $GTOL_A
                $GTOL_DS
                $GTOL_OR
                $GTOL_R
                $GTOL_VAL
                $GREL
                $GABS
                $GDEFAULT
                $GNUMNTRUE
                $GNUMNFALSE
                $GNUMNUMS
                $GNUMSTRUE
                $GNUMSFALSE
                $GNUMSTRS
                $GNUMTRUE
                $GNUMFALSE
                $GNUMALL
                $GNUMBER_REGEXP
                $GNUMSTRUE
                $GFTCTS
                $GFTKEYWORD
                $GFTOXY
                $GFTPOP
                $GFTCTF
                $GFTARES
                $GFTDUMMY
                $GFTTABLE
                $GFTTABLE_X
                $GFTTECPLOT
                $GFTTOKEN
                $GFTTRACER
                $GFTLINK
                $GFTXY
                $GFTXY_BLOCK
                $GCOPY_FORMAT
                $GCOPY_REGEXP
               );
sub BEGIN
  {
  }
sub END
  {
  }
#...................
#...global values...
#...................

# files
# can be modified by cts_diff_unique_filenames
$CTS_DIFF_FILE_CMD      = "cts_diff.cmd";
$CTS_DIFF_FILE_DATA     = "cts_diff.data";
$CTS_DIFF_FILE_PDF      = "cts_diff.pdf";
$CTS_DIFF_FILE_PLOT_OUT = "cts_diff.plot_out";
$CTS_DIFF_FILE_PRESULT  = "cts_diff.presult";
$CTS_DIFF_FILE_PS       = "cts_diff.ps";

#...data ref labels...
$GDATASET_NAMES = "Dataset_Names";
$GDATA = "Data";
$GNAME = "Name";
$GCOORDX = "X";
$GCOORDY = "Y";
$GORG  = "Orig";
$GDIFF = "Diff";
#...stat of counts...
$GNUMNTRUE  = "NumNTrue";
$GNUMNFALSE = "NumNFalse";
$GNUMNUMS   = "NumNums";
$GNUMSTRUE  = "NumSTrue";
$GNUMSFALSE = "NumSFalse";
$GNUMSTRS   = "NumStrings";
$GNUMTRUE   = "NumTrue";
$GNUMFALSE  = "NumFalse";
$GNUMALL    = "NumAll";
#...stat of other vals...
$GMAX    = "Max";
$GMEAN   = "Mean";
$GMIN    = "Min";
$GRMS    = "RMS";
$GRMSE   = "RMSE";
$GMAXABS = "MaxABS";
$GSUMSQ  = "SumSq";
#...names...
$GTOL_A    = "a";
$GTOL_OR   = "or";
$GTOL_R    = "r";
$GTOL_DS   = "ds";
$GTOL_VAL  = "val";
$GREL      = "Rel Diff";
$GABS      = "Abs Diff";
$GDS       = "ds";
$GDS_SKIP     = "ds_skip";
$GDS_NOSKIP   = "ds_noskip";
$GDS_FAILED   = "ds_failed";
$GDS_NOFAILED = "ds_nofailed";
$GDS_SMOOTH   = "ds_smooth";
$GDS_NOSMOOTH = "ds_nosmooth";
$GDS_SKIP_UNDEF   = "ds_skip_undef";
$GDS_NOSKIP_UNDEF = "ds_noskip_undef";
$GDS_SKIP_ALL_0   = "ds_skip_all_0";
$GDS_NOSKIP_ALL_0 = "ds_noskip_all_0";
$GDEFAULT  = "default";
#...file types...
$GFT        = "ft";
$GFTCTS     = "cts";
$GFTKEYWORD = "keyword";
$GFTOXY     = "oxy";
$GFTPLOT_OUTPUT = "plot_output";
$GFTPOP     = "pop";
$GFTCTF     = "ctf";
$GFTARES    = "ares";
$GFTDUMMY   = "dummy";
$GFTGMV     = "gmv";
$GFTTABLE   = "table";
$GFTTABLE_X = "table_x";
$GFTTECPLOT = "tecplot";
$GFTTOKEN   = "token";
$GFTTRACER  = "tracer";
$GFTLINK    = "link";
$GFTXY      = "xy";
$GFTXY_BLOCK = "xy_block";
#...multiple copy strings...
$GCOPY_FORMAT = '... copy %3d';
$GCOPY_REGEXP = ' \.\.\.\ copy\s*[0-9]+';
#...values larger than this are treated as strings...
$GSKIP = 8e99;
#...regexp to match number - simple for speed
$GNUMBER_REGEXP = '[+-]?\.?[0-9]+\.?[0-9]*([eE][+-]?\d+)?';
#...oxy strings...
$GOXY_TAG_START = "Final state ASCII diagnostic dump start";
# number of points to do with linespoints
$GLINESPOINTS_MAX = 30;

# val type options
$GVAL_SKIP = "val_skip";

############################################################################
# cts_diff_unique_filenames
#   generate unique filenames that will not overwrite ones in dir
#   resets CTS_DIFF_FILE_* names
sub cts_diff_unique_filenames{
    my(
        $cmd_ref,
        ) = @_;
    my(
        $dh_DIR,
        $file,
        $file_notdir,
        @files,
        $num_max,
        @nums,
        @nums_sort,
        $suffix,
        $file_name_root,
        );

    # put names of files in suffix
    $suffix = "";
    # 1 or 2 files (most common) - use filenames
    if( $#{$$cmd_ref{files}} <= 1 ){
        foreach $file ( @{$$cmd_ref{files}} ){
            ( $file_notdir = $file ) =~ s&^.*/&&;
            $suffix .= ".$file_notdir";
        }
    }
    # more than 2 files - use first file and tack on a ".multi"
    else{
        ( $file_notdir = $$cmd_ref{files}[0] ) =~ s&^.*/&&;
        $suffix = ".$file_notdir.multi";
    }

    # remove directory portion
    $CTS_DIFF_FILE_CMD      =~ s&^.*\/+&&;
    $CTS_DIFF_FILE_DATA     =~ s&^.*\/+&&;
    $CTS_DIFF_FILE_PDF      =~ s&^.*\/+&&;
    $CTS_DIFF_FILE_PLOT_OUT =~ s&^.*\/+&&;
    $CTS_DIFF_FILE_PRESULT  =~ s&^.*\/+&&;
    $CTS_DIFF_FILE_PS       =~ s&^.*\/+&&;

    # tack on suffix
    $CTS_DIFF_FILE_CMD      =~ s/(\.[^\.]+)$/$suffix$1/;
    $CTS_DIFF_FILE_DATA     =~ s/(\.[^\.]+)$/$suffix$1/;
    $CTS_DIFF_FILE_PDF      =~ s/(\.[^\.]+)$/$suffix$1/;
    $CTS_DIFF_FILE_PLOT_OUT =~ s/(\.[^\.]+)$/$suffix$1/;
    $CTS_DIFF_FILE_PRESULT  =~ s/(\.[^\.]+)$/$suffix$1/;
    $CTS_DIFF_FILE_PS       =~ s/(\.[^\.]+)$/$suffix$1/;

    # root name without filetype suffix
    ( $file_name_root = ${CTS_DIFF_FILE_DATA} ) =~ s/\.[^\.]+$//;
    
    # look for cts_diff.data
    if( opendir( $dh_DIR, $$cmd_ref{outdir} ) ){

        @files = readdir( $dh_DIR );
        closedir( $dh_DIR );

        # get the notdir
        grep( s&^.*/+&&, @files );

        @files = grep( /^${file_name_root}(\.\d+)?(\.[^\.]+)$/, @files );
        foreach $file ( @files ){
            if( $file =~ /\.(\d+)/ ){
                push( @nums, $1 );
            }
            else{
                push( @nums, 0 );
            }
        }
        if( @nums ){
            @nums_sort = sort numerically( @nums );
            $num_max = $nums_sort[-1] + 1;
            $CTS_DIFF_FILE_CMD      =~ s/(\.[^\.]+)$/.${num_max}$1/;
            $CTS_DIFF_FILE_DATA     =~ s/(\.[^\.]+)$/.${num_max}$1/;
            $CTS_DIFF_FILE_PDF      =~ s/(\.[^\.]+)$/.${num_max}$1/;
            $CTS_DIFF_FILE_PLOT_OUT =~ s/(\.[^\.]+)$/.${num_max}$1/;
            $CTS_DIFF_FILE_PRESULT  =~ s/(\.[^\.]+)$/.${num_max}$1/;
            $CTS_DIFF_FILE_PS       =~ s/(\.[^\.]+)$/.${num_max}$1/;
        }
    }

    # prepend output dir portion
    $CTS_DIFF_FILE_CMD      =~ s&^&$$cmd_ref{outdir}/&;
    $CTS_DIFF_FILE_DATA     =~ s&^&$$cmd_ref{outdir}/&;
    $CTS_DIFF_FILE_PDF      =~ s&^&$$cmd_ref{outdir}/&;
    $CTS_DIFF_FILE_PLOT_OUT =~ s&^&$$cmd_ref{outdir}/&;
    $CTS_DIFF_FILE_PRESULT  =~ s&^&$$cmd_ref{outdir}/&;
    $CTS_DIFF_FILE_PS       =~ s&^&$$cmd_ref{outdir}/&;
    
}

sub numerically { $a <=> $b; }

#............................................................................
#...Name
#...====
#... check_format_ds_data
#...
#...Purpose
#...=======
#... checks the format for hash to be sent to print_gnuplot_data
#...
#...Arguments
#...=========
#... $ds_data_ref    Intent: out
#...                 Perl type: reference to hash
#...                 Obtained after read_file.
#...
#... $ierr           Intent: out
#...                 Perl type: reference to hash
#...                 Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) check format for ds_data
#............................................................................
sub check_format_ds_data
  {
    my(
       $ds_data_ref,
       $variable,
       $source,
       $gnuplot_info_ref
      ) = @_;
    my(
       @format, # correct format for data
       $ierr, # error ret value
       $key_org, # key under org
       $dtype, # diff type
       $coord, # coordinate
      );
    $ierr = 0;
    $gnuplot_info_ref = $gnuplot_info_ref; # get rid of warnings
    $source = $source; # get rid of warnings
    $variable = $variable;
    @format =
      (
       'Format (when given ds_data_ref = data{ds_name}): ',
       ' If X data exists (eg for xy file types):',
       '   $ds_data_ref{$GCOORDX}{$GNAME}           = X name',
       '   $ds_data_ref{$GCOORDX}{$GORG}[]          = X data',
       '   $ds_data_ref{$GCOORDX}{$DIFF}{<dtype>}[] = X diff data',
       ' Y data (always):',
       '   $ds_data_ref{$GCOORDY}{$GNAME}           = Y name',
       '   $ds_data_ref{$GCOORDY}{$GORG}[]          = Y data',
       '   $ds_data_ref{$GCOORDY}{$DIFF}{<dtype>}[] = Y diff data',
       '   $ds_data_ref{$GCOORDY}{stats}            = perhaps y stats',
      );
    if( ref( $ds_data_ref ) ne "HASH" )
      {
        $ierr = 0;
        &print_error( "Internal Error in check_format_ds_data",
                      "ref(ds_data) ne 'HASH' of coord",
                      @format,
                      $ierr );
        $ierr = 1;
        return( $ierr );
      }
    if( ! defined( $$ds_data_ref{$GCOORDY} ) )
      {
        $ierr = 0;
        &print_error( "Internal Error in check_format_ds_data",
                      "ds_data{$GCOORDY} must be defined",
                      @format,
                      $ierr );
        $ierr = 1;
        return( $ierr );
      }
    foreach $coord ( sort keys %$ds_data_ref )
      {
        if( $coord ne $GCOORDX && $coord ne $GCOORDY )
          {
            $ierr = 0;
            &print_error( "Internal Error in check_format_ds_data",
                          "ds_data{$coord != $GCOORDX or $GCOORDY}",
                          @format,
                          $ierr );
            $ierr = 1;
            return( $ierr );
          }
        if( ref( $$ds_data_ref{$coord} ) ne "HASH" )
          {
            $ierr = 0;
            &print_error( "Internal Error in check_format_ds_data",
                          "ref(ds_data{$coord}) ne 'HASH' of $GORG",
                          @format,
                          $ierr );
            $ierr = 1;
            return( $ierr );
          }
        if( ! defined($$ds_data_ref{$coord}{$GNAME}) ||
            ref( $$ds_data_ref{$coord}{$GNAME} ) )
          {
            $ierr = 0;
            &print_error( "Internal Error in check_format_ds_data",
                          "ds_data{$coord}{$GNAME} must be name",
                          @format,
                          $ierr );
            $ierr = 1;
            return( $ierr );
          }
        if( ! defined($$ds_data_ref{$coord}{$GORG}) ||
            ref( $$ds_data_ref{$coord}{$GORG} ) ne "ARRAY" )
          {
            $ierr = 0;
            &print_error( "Internal Error in check_format_ds_data",
                          "ds_data{$coord}{$GORG} ne 'ARRAY' of values",
                          @format,
                          $ierr );
            $ierr = 1;
            return( $ierr );
          }

        foreach $key_org ( keys %{$$ds_data_ref{$coord}} )
          {
            if( $key_org !~ /^(${GORG}|${GNAME}|${GDIFF}|stats)$/ )
              {
                $ierr = 0;
                &print_error( "Internal Error in check_format_ds_data",
                              "ds_data{$coord}{$key_org != $GORG or $GNAME or $GDIFF or stats}",
                              @format,
                              $ierr );
                $ierr = 1;
                return( $ierr );
              }
            if( $key_org eq "$GDIFF" )
              {
                if( ref( $$ds_data_ref{$coord}{$key_org} ) ne "HASH" )
                  {
                    $ierr = 0;
                    &print_error( "Internal Error in check_format_ds_data",
                                  "ref(ds_data{$coord}{$key_org} ne 'HASH' of diff type",
                                  @format,
                                  $ierr );
                    $ierr = 1;
                    return( $ierr );
                  }
                foreach $dtype ( keys %{$$ds_data_ref{$coord}{$key_org}} )
                  {
                    if( ref( $$ds_data_ref{$coord}{$key_org}{$dtype} ) ne
                        "ARRAY" )
                      {
                        $ierr = 0;
                        &print_error( "Internal Error in check_format_ds_data",
                                      "ref(ds_data{$coord}{$key_org}{$dtype} ne 'ARRAY' of values",
                                      @format,
                                      $ierr );
                        $ierr = 1;
                        return( $ierr );
                      }
                  }
              }
          }
      }
  }

#............................................................................
#...Name
#...====
#... check_format_data
#...
#...Purpose
#...=======
#... checks the format for hash returned by read_file
#...
#...Arguments
#...=========
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              Obtained after read_file.
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) check format for data
#............................................................................
sub check_format_data
  {
    my(
       $data_ref,
      ) = @_;
    my(
       $ds_name, # dataset name
       @ds_names, # listing of ds_name s
       @format, # correct format for data
       $ierr, # error return value
       $string_1, # a string for matching
       $string_2, # a string for matching
      );
    @format =
      (
       'Format: ',
       ' $$data_ref{$GDATA}{<dataset name>} = Data for dataset',
      );
    $ierr = 0;
    if( defined( $$data_ref{$GDATA} ) && ref( $$data_ref{$GDATA} ) ne "HASH" )
      {
        $ierr = 0;
        &print_error( "Internal Error in check_format_data",
                      'ref($$data_ref{$GDATA}) ne "HASH" of ds_name',
                      @format,
                      $ierr );
        $ierr = 1;
        return( $ierr );
      }
    if( defined( $$data_ref{$GDATA} ) &&
        ref( $$data_ref{$GDATASET_NAMES} ) ne "ARRAY" )
      {
        $ierr = 0;
        &print_error( "Internal Error in check_format_data",
                      'ref($$data_ref{$GDATASET_NAMES}) ne "ARRAY" of ds_name s',
                      @format,
                      $ierr );
        $ierr = 1;
        return( $ierr );
      }
    if( defined( $$data_ref{$GDATA} ) )
      {
        @ds_names = sort keys %{$$data_ref{$GDATA}};
        $string_1 = join( '|', @ds_names );
        $string_2 = join( '|', sort @{$$data_ref{$GDATASET_NAMES}} );
        if( $string_1 ne $string_2 )
          {
            $ierr = 0;
            &print_error( "Internal Error in check_format_data",
                          '$$data_ref{$GDATASET_NAMES}[] should be an ordered listing of the keys of $$data_ref{$GDATA}{}',
                          "DATASET_NAMES = [$string_1]",
                          "DATA          = [$string_2]",
                          $ierr );
            $ierr = 1;
            return( $ierr );
          }
      }
    foreach $ds_name ( sort keys %{$$data_ref{$GDATA}} )
      {
        $ierr = &check_format_ds_data( $$data_ref{$GDATA}{$ds_name} );
        if( $ierr )
          {
            $ierr = 0;
            &print_error( "Internal Error in check_format_data",
                          "Error from check_format_ds_data (data_ref{$GDATA}{$ds_name})",
                          $ierr );
            $ierr = 1;
            return( $ierr );
          }
      }
  }

#............................................................................
#...Name
#...====
#... create_diff
#...
#...Purpose
#...=======
#... Create a diff hash from 2 arrays and command line arguments
#...    Rel Diff - relative difference
#...    Abs Diff - absolute difference
#... If either value is not a number, a string comparison is made
#... and a non-empty string is placed in Rel/Abs position if
#..  a difference is detected (and $diff_result is incremented)
#...
#...Arguments
#...=========
#... $array_base_ref   Intent: in
#...                   Perl type: reference to array
#...                   base array
#...
#... $array_new_ref    Intent: in
#...                   Perl type: reference to array
#...                   new array array
#...
#... $cmd_ref          Intent: in
#...                   Perl type: reference to hash
#...                   Gotten from parse_args()
#...
#... $var_name         Intent: in
#...                   Perl type: scalar
#...                   For getting variable specific tolerance from cmd_ref.
#...
#... $print            Intent: in
#...                   Perl type: scalar
#...                   If differences should be printed as they are found.
#...                   Non-"0" will print.
#...
#... $array_x_ref      Intent: in
#...                   Perl type: scalar
#...                   If you want to print out the X value that is the
#...                   coordinate to the corresponding Y values being diffed
#...                   You might want to do this if, for instance,
#...                   interpolation was done.
#...
#... $diff_ref         Intent: out
#...                   Perl type: reference to stat hash
#...                   given tolerences, assigns
#...                     Rel Diff: Relative    Difference
#...                     Abs Diff: Subtraction Difference
#...                   Can be used with other routines (eg print_gnuplot_data).
#...
#... $diff_result_ref  Intent: out
#...                   Perl type: reference to scalar
#...                   Number of differences (0 if no difference)
#...                   This values is also the return value.
#...
#...Program Flow
#...============
#... 1) Compute differences
#............................................................................
sub create_diff
  {
    my(
       $array_base_ref,
       $array_new_ref,
       $cmd_ref,
       $var_name,
       $verbosity,
       $array_x_ref,
       $diff_ref,
       $diff_result_ref,
       $print_str_header_ref,
       $print_str_diff_ref,
      ) = @_;
    my(
       %array_stats, # mean, ...
       $cmp,
       $compared, # if defined, a comparison was done
       $diff_flag,
       @diff_index, # which index has diff ("A", "B", "M", "R", ...)
       $i, # loop var
       $is_diff, # is a difference
       $is_diff_a, # is an absolute difference
       $is_diff_r, # is a  relative difference
       $match,
       $maxabs,
       $nomatch,
       $num_vals, # number of values to diff
       $pstring, # print string
       %tols, # the tolerance to use (hash)
       $tol_abs, # abs tol
       $tol_abs_d, # if defined
       $tol_rel, # rel tol
       $tol_rel_d, # if defined
       $tol_or_d, # if or defined
       $use_scaled_r, # if using scaled relative tolerances
       $skip_undef,
       $val1, # a value
       $val2, # a value
       $val_abs, # absolute difference
       $val_rel, # relative difference
       $val_aval_mean, # mean of abs of values
       $res,
       $rms, # rms of base array
       $val,
      );
    #..........
    #...init...
    #..........
    delete( $$diff_ref{$GABS} );
    delete( $$diff_ref{$GREL} );
    $$diff_result_ref = 0;
    $num_vals = $#{$array_base_ref} > $#{$array_new_ref} ?
      $#{$array_base_ref} : $#{$array_new_ref};
    #.....................................
    #...special quick diff if same data...
    #.....................................
    if( $array_new_ref == $array_base_ref )
      {
        for( $i = 0; $i <= $num_vals; $i++ )
          {
            push( @{$$diff_ref{$GABS}}, 0 );
            push( @{$$diff_ref{$GREL}}, 0 );
          }
        $compared = "";
        return( $$diff_result_ref );
      }

    #....................
    #...get tolerances...
    #....................
    &get_tols( $cmd_ref, $var_name, \%tols );
    $tol_abs = $tols{$GTOL_A};
    $tol_rel = $tols{$GTOL_R};
    if( defined( $tol_abs ) )
      {
        $tol_abs_d = 1;
      }
    else
      {
        $tol_abs_d = 0;
        $tol_abs   = 0;
      }

    # command line
    undef( $use_scaled_r );
    if( defined($$cmd_ref{scaled_r}) ){
        $use_scaled_r = "";
    }
    # override if given with -r
    if( defined( $tol_rel ) && $tol_rel =~ /^(ns|s):(.*)$/ ){
        $tol_rel = $2;
        $val1 = $1;
        if( $val1 eq "s" ){
            $use_scaled_r = "";
        }
        else{
            undef( $use_scaled_r );
        }
    }
    if( defined( $tol_rel ) ){
        $tol_rel_d = 1;
    }
    else
      {
        $tol_rel_d = 0;
        $tol_rel   = 0;
      }
    if( ( defined($$cmd_ref{$GTOL_OR}) ) ||
        (   $tol_abs_d && ! $tol_rel_d ) ||
        ( ! $tol_abs_d &&   $tol_rel_d ) )
      {
        $tol_or_d = 1;
      }
    else
      {
        $tol_or_d = 0;
      }
    # compute rms for computing relative tolerances
    $rms = 0;
    $maxabs = 0;
    &create_stats( $array_base_ref, \%array_stats );
    if( defined($array_stats{RMS}) ){
        $rms = $array_stats{RMS};
        $maxabs = $array_stats{MaxABS};
    }
    &create_stats( $array_new_ref, \%array_stats );
    if( defined($array_stats{RMS}) ){
        $rms += $array_stats{RMS};
        $maxabs += $array_stats{MaxABS};
    }
    # get mean of the current sum
    $maxabs = $maxabs / 2.0;
    $rms = $rms / 2.0;

    # use the rms supplied if given
    if( defined($$cmd_ref{scaled_r_ds_val}) ){
        $rms = $$cmd_ref{scaled_r_ds_val};
    }

    # how to deal with undefined values...
    # By default, base undefined for a defined new, will report a diff
    # unless ds_skip_undef.
    # undefined new is skipped always (might want to add a flag to
    # not skip?).
    # Look for GDS_SKIP_UNDEF,GDS_NOSKIP_UNDEF
    undef( $skip_undef );
    if( defined($$cmd_ref{$GDS_SKIP_UNDEF}) ){
        $match = $$cmd_ref{$GDS_SKIP_UNDEF};
        if( defined( $$cmd_ref{$GDS_NOSKIP_UNDEF} ) ){
            $nomatch = $$cmd_ref{$GDS_NOSKIP_UNDEF};
        }
        else{
            $nomatch = "";
        }
        if( $var_name =~ /^($match)$/ && $var_name !~ /^($nomatch)$/ ){
            $skip_undef = "";
        }
    }

    #.......................................
    #...compute diffs for each data point...
    #.......................................
    undef( @diff_index );
    for( $i = 0; $i <= $num_vals; $i++ ) {
        $val1   = $$array_base_ref[$i];
        $val2   = $$array_new_ref[$i];
        $is_diff = '-';

        # if both not defined, treat as same
        if( ! defined($$array_x_ref[$i]) ||
            ( ! defined( $val1 ) && ! defined( $val2 ) ) ){
            $is_diff = "-";
            $val_abs = "-";
            $val_rel = "-";
        }

        #.........................................
        #...if both are numbers, use tolerances...
        #.........................................
        elsif( defined( $val1 ) && $val1 =~ /^$GNUMBER_REGEXP$/ &&
               abs( $val1 ) < $GSKIP &&
               defined( $val2 ) && $val2 =~ /^$GNUMBER_REGEXP$/ &&
               abs( $val2 ) < $GSKIP ) {
            $val_abs = $val2 - $val1;
            $val_aval_mean = (abs($val1) + abs($val2))/2.0;
            $val_rel = 0;
            if( $val_aval_mean > 0 ){
                # if using a scaled relative difference
                if( defined($use_scaled_r) ){
                    # found that when using maxabs, a few large points obscured
                    #   diffs
                    #   $val_rel = $val_abs/((3*$val_aval_mean+$rms+$maxabs)/5.0);
                    # So, use a scaling of the average magnitude of the 2 points
                    #   and the rms of all points.
                    #   Also, if the points area already greater than the rms,
                    #   weigh closer to the points (so as not to skew to a
                    #   larger rel diff).
                    if( $val_aval_mean >= $rms ){
                        $val_rel = $val_abs/((3*$val_aval_mean+1*$rms)/4.0);
                    }
                    else{
                        $val_rel = $val_abs/((3*$val_aval_mean+2*$rms)/5.0);
                    }
                }
                else{
                    $val_rel = $val_abs/$val_aval_mean;
                }
            }
            else{
                $val_rel = 0;
            }

            #....................
            #...is_diff_<type>...
            #....................
            if( abs( $val_abs ) > $tol_abs )
              {
                $is_diff_a = 1;
              }
            else
              {
                $is_diff_a = 0;
              }
            if( abs( $val_rel ) > $tol_rel )
              {
                $is_diff_r = 1;
              }
            else
              {
                $is_diff_r = 0;
              }

            #............................................
            #...see if difference depending upon flags...
            #............................................
            #................
            #...or defined...
            #................
            if( $tol_or_d ) {
                if( $is_diff_r && $is_diff_a ) {
                    $is_diff = "B";
                }
            }
            #.................
            #...default and...
            #.................
            else {
                if( $is_diff_a && $is_diff_r ){
                    $is_diff = "B";
                }
                elsif( $is_diff_r ){
                    $is_diff = "R";
                }
                elsif( $is_diff_a ){
                    $is_diff = "A";
                }
            }

            # override is_diff if ds_cmp
            if( defined($tols{ds_cmp} ) ){
                ( $cmp = $tols{ds_cmp} ) =~ s/v/$val2/g;
                $res = eval $cmp;
                if( $res ){
                    $is_diff = "-";
                }
                else{
                    $is_diff = "B";
                }
            }

            #...................................
            #...if different, record values  ...
            #...................................
            $compared = "";
            if( $is_diff ne "-" ) {
                $$diff_result_ref += 1;
            }
        }
        #...............................................
        #...DONE: if both are numbers, use tolerances...
        #...............................................

        # If val2 is not defined, skip by default unless doing superset_x.
        # superset_x implies that you want to see any missing values.
        # in either base/new.
        # Do not mark as compared.
        elsif( ! defined( $val2 ) && ! defined($$cmd_ref{superset_x}) ){
            $is_diff = "-";
            $val_abs = "-";
            $val_rel = "-";
        }

        # if one is not defined and set to skip undefined, treat as same
        # but do not mark as compared (so diff if no vals compared)
        elsif( defined($skip_undef) &&
               ( ! defined( $val1 ) || ! defined( $val2 ) ) ){
            $is_diff = "-";
            $val_abs = "-";
            $val_rel = "-";
        }

        #.....................................
        #...if not numbers, compare strings...
        #.....................................
        else {
            if( !defined( $val1 ) || !defined( $val2 ) || $val1 ne $val2 ) {
                $is_diff = "S";
                $$diff_result_ref += 1;
                $val_abs = "StringDiff";
                $val_rel = "StringDiff";
            }
            else {
                $val_abs = "-";
                $val_rel = "-";
            }
            $compared = "";

        }
        push( @{$$diff_ref{$GABS}},  $val_abs );
        push( @{$$diff_ref{$GREL}},  $val_rel );
        push( @{$$diff_ref{type}},   $is_diff );
        push( @diff_index, $is_diff );
    }

    # if no values actually compared, consider that a diff
    if( ! defined( $compared ) ){
        $is_diff = "M";
        $$diff_result_ref += 1;
        push( @{$$diff_ref{$GABS}}, "NO_VALUES" );
        push( @{$$diff_ref{$GREL}}, "NO_VALUES" );
        push( @{$$diff_ref{type}},  $is_diff );
        push( @diff_index, $is_diff );
    }

    #.............................................
    #...DONE: compute diffs for each data point...
    #.............................................

    #.......................
    #...fill print values...
    #.......................
    # header and vals for normal
    if( $verbosity ne "last" ){

        # Just a summary printed
        if( $$cmd_ref{v} <= 3 ){
            $$print_str_header_ref .=
                sprintf( "%1s %11s %11s %15s %s\n",
                         "T", $GABS, $GREL,
                         "NumDiff/Total", "<File1> vs <File2> {<NameType>}<NameValue>" );
            $$print_str_header_ref .= 
                sprintf( "%1s %11s %11s %15s %s\n",
                         "-", "--------", "--------",
                         "-------------", "------------------------------------------" );
        }

        # Actual values printed as well
        else{
            $$print_str_header_ref .=
                sprintf( "%1s %11s %11s %15s %15s %15s %7s\n",
                         "T", $GABS, $GREL,
                         "X (#Diff/Tot)", "Base", "New", "Index" );
            $$print_str_header_ref .= 
                sprintf( "%1s %11s %11s %15s %15s %15s %7s\n",
                         "-", "--------", "--------",
                         "-------------", "----", "---", "-----" );
        }
        
        if( ( $verbosity == 4 && $$diff_result_ref > 0 ) ||
            $verbosity == 5 ) {
            $num_vals = $#{$$diff_ref{$GABS}};
            for( $i = 0; $i <= $num_vals; $i++ )
            {
                if( $diff_index[$i] ne "-" || $verbosity == 5 )
                {
                    $diff_flag = $diff_index[$i];
                    $$print_str_diff_ref .= "$diff_flag ";
                    $val = $$diff_ref{$GABS}[$i];
                    ($pstring, $val) = print_val( $val, 11, 4 );
                    $$print_str_diff_ref .= sprintf( "$pstring", $val );
                    $val = $$diff_ref{$GREL}[$i];
                    ($pstring, $val) = print_val( $val, 11, 4 );
                    $$print_str_diff_ref .= sprintf( " $pstring", $val );
                    $val = $$array_x_ref[$i];
                    ($pstring, $val) = print_val( $val, 15, 8 );
                    $$print_str_diff_ref .= sprintf( " $pstring", $val );
                    $val = $$array_base_ref[$i];
                    ($pstring, $val) = print_val( $val, 15, 8 );
                    $$print_str_diff_ref .= sprintf( " $pstring", $val );
                    $val = $$array_new_ref[$i];
                    ($pstring, $val) = print_val( $val, 15, 8 );
                    $$print_str_diff_ref .= sprintf( " $pstring", $val );
                    $$print_str_diff_ref .= sprintf( " %7s", $i+1 );
                    $$print_str_diff_ref .= sprintf( "\n" );
                }
            }
        }
    }

    # header and vals for last
    else{
        $$print_str_header_ref .= 
            sprintf( "%1s %11s %11s %15s %15s %15s %s\n",
                     "T", $GABS, $GREL, "X", "Base", "New", "Y" );
        $$print_str_header_ref .= 
            sprintf( "%1s %11s %11s %15s %15s %15s %s\n",
                     "-", "--------", "--------", "-", "----", "---", "-" );
        $num_vals = $#{$$diff_ref{$GABS}};
        for( $i = 0; $i <= $num_vals; $i++ ){
            $diff_flag = $diff_index[$i];
            $$print_str_diff_ref .= "$diff_flag ";
            $val = $$diff_ref{$GABS}[$i];
            ($pstring, $val) = print_val( $val, 11, 4 );
            $$print_str_diff_ref .= sprintf( "$pstring", $val );
            $val = $$diff_ref{$GREL}[$i];
            ($pstring, $val) = print_val( $val, 11, 4 );
            $$print_str_diff_ref .= sprintf( " $pstring", $val );
            $val = $$array_x_ref[$i];
            ($pstring, $val) = print_val( $val, 15, 8 );
            $$print_str_diff_ref .= sprintf( " $pstring", $val );
            $val = $$array_base_ref[$i];
            ($pstring, $val) = print_val( $val, 15, 8 );
            $$print_str_diff_ref .= sprintf( " $pstring", $val );
            $val = $$array_new_ref[$i];
            ($pstring, $val) = print_val( $val, 15, 8 );
            $$print_str_diff_ref .= sprintf( " $pstring", $val );
            $$print_str_diff_ref .= " $var_name";
            $$print_str_diff_ref .= sprintf( "\n" );
        }
    }
    #..............................
    #...DONE: print if requested...
    #..............................
    $$diff_result_ref;
  }

sub print_val
  {
    my(
       $val, # value to print
       $len, # length to take up
       $dec  # digits after decimal (negative to print integer)
      ) = @_;
    my(
       $pstring, # print string
      );
    if( defined( $val ) && $val =~ /^$GNUMBER_REGEXP$/ &&
        abs( $val ) < $GSKIP )
      {
        if( $dec >= 0 )
          {
            $pstring = sprintf( "%%%d.%de", $len, $dec );
          }
        else
          {
            $pstring = sprintf( "%%%dd", $len, $dec );
          }
      }
    elsif( defined( $val ) )
      {
        $pstring = sprintf( "%%%ds", $len );
      }
    else
      {
        $val = "-";
        $pstring = sprintf( "%%%ds", $len );
      }
    return( $pstring, $val );
  }

#............................................................................
#...Name
#...====
#... create_stats
#...
#...Purpose
#...=======
#... Create stats hash from an array
#... Unless otherwise specified, non-number values will be skipped.
#...    Max       - max value
#...    MaxABS    - max absolute value
#...    Mean      - mean value
#...    Min       - min value
#...    RMS       - root mean square
#...    RMSE      - root mean square error
#...    SumSq     - Sum of the squares of the numbers
#...    NumNTrue  - Number of non-0 numbers
#...    NumNFalse - Number of 0 numbers
#...    NumNums   - Number of Numbers
#...    NumSTrue  - Number of non-empty strings
#...    NumSFalse - Number of empty strings
#...    NumStrs   - Number of strings
#...    NumTrue   - Number of true numbers and strings
#...    NumFalse  - Number of false numbers and strings
#...    NumAll    - Total count
#...
#...Arguments
#...=========
#... $array_ref   Intent: in
#...              Perl type: reference to array
#...
#... $stat_ref    Intent: out
#...              Perl type: reference to stat hash
#...
#... $mask_ref    Intent: in
#...              Per type: reference to array
#...              if defined and mask[i] eq "" or "-", $array[i] = 0;
#...
#...Program Flow
#...============
#... 1) Compute stats
#............................................................................
sub create_stats
  {
    my(
       $array_in_ref,
       $stat_ref,
       $mask_ref
      ) = @_;
    my(
       $i, # loop variable
       @array, # new array to calculate on if given mask
       $array_ref, # pointer
       $num_elements, # number of elements in array
       $val, # value of an array elem
       $val1, # value
       $val2, # value
       );
    #..........
    #...init...
    #..........
    undef( %{$stat_ref} );

    # deal with mask if given
    if( defined($mask_ref) ){
        for( $i = 0; $i <= $#{$array_in_ref}; $i++ ){
            if( $$mask_ref[$i] ne "-" && $$mask_ref[$i] ne "" ){
                $val = $$array_in_ref[$i];
            }
            else{
                $val = 0;
            }
            push( @array, $val );
        }
        $array_ref = \@array;
    }
    else{
        $array_ref = $array_in_ref;
    }

    $num_elements = $#{$array_ref};
    #...............
    #...init vals...
    #...............
    for( $i = 0; $i <= $num_elements; $i++ )
      {
        $val = $$array_ref[$i];
        if( defined( $val ) &&
            $val =~ /^$GNUMBER_REGEXP$/ &&
            abs( $val ) < $GSKIP )
          {
            $$stat_ref{$GMAX}  = $val;
            $$stat_ref{$GMIN}  = $val;
            last;
          }
      }
    $$stat_ref{$GNUMALL}    = $num_elements + 1;
    $$stat_ref{$GNUMNTRUE}  = 0;
    $$stat_ref{$GNUMNFALSE} = 0;
    $$stat_ref{$GNUMNUMS}   = 0;
    $$stat_ref{$GNUMSTRUE}  = 0;
    $$stat_ref{$GNUMSFALSE} = 0;
    $$stat_ref{$GNUMSTRS}   = 0;
    $$stat_ref{$GNUMTRUE}   = 0;
    $$stat_ref{$GNUMFALSE}  = 0;
    $$stat_ref{$GMEAN} = 0;
    $$stat_ref{$GSUMSQ} = 0;
    #................................
    #...loop setting various stats...
    #................................
    for( $i = 0; $i <= $num_elements; $i++ ) {
        $val = $$array_ref[$i];
        if( defined( $val ) &&
            $val =~ /^$GNUMBER_REGEXP$/ &&
            abs( $val ) < $GSKIP )
          {
            $$stat_ref{$GMAX}    = $$stat_ref{$GMAX} > $val ? $$stat_ref{$GMAX} : $val;
            $$stat_ref{$GMIN}    = $$stat_ref{$GMIN} < $val ? $$stat_ref{$GMIN} : $val;
            $$stat_ref{$GMEAN}  += $val;
            $$stat_ref{$GSUMSQ} += $val**2;
            $$stat_ref{$GNUMNUMS}++;
            if( $val != 0 ) {
                $$stat_ref{$GNUMNTRUE}++;
            }
          }
        else
          {
            $$stat_ref{$GNUMSTRS}++;
            if( defined( $val ) && length( $val ) > 0 ) {
                $$stat_ref{$GNUMSTRUE}++;
            }
          }
    }
    $$stat_ref{$GNUMNFALSE} = $$stat_ref{$GNUMNUMS}  - $$stat_ref{$GNUMNTRUE};
    $$stat_ref{$GNUMSFALSE} = $$stat_ref{$GNUMSTRS}  - $$stat_ref{$GNUMSTRUE};
    $$stat_ref{$GNUMTRUE}   = $$stat_ref{$GNUMNTRUE} + $$stat_ref{$GNUMSTRUE};
    $$stat_ref{$GNUMFALSE}  = $$stat_ref{$GNUMALL}   - $$stat_ref{$GNUMTRUE};
    #.......................
    #...delete if not set...
    #.......................
    if( $$stat_ref{$GNUMNUMS} == 0 )
      {
        delete( $$stat_ref{$GMEAN} );
        delete( $$stat_ref{$GSUMSQ} );
      }
    #...........................
    #...finish off some stats...
    #...........................
    if( $$stat_ref{$GNUMNUMS} > 0 )
      {
        $$stat_ref{$GMEAN} = ($$stat_ref{$GMEAN})/$$stat_ref{$GNUMNUMS};
        $val1 = abs( $$stat_ref{$GMIN} );
        $val2 = abs( $$stat_ref{$GMAX} );
        $$stat_ref{$GMAXABS} = $val1 > $val2 ? $val1 : $val2;
        if( $$stat_ref{$GNUMNUMS} > 0 ){
            $$stat_ref{$GRMS} = ($$stat_ref{$GSUMSQ}/$$stat_ref{$GNUMNUMS}) ** .5
        }
        else{
            $$stat_ref{$GRMS} = -1;
        }
        # todo: recalc this since not quite right (maybe if no nums)???
        if( $$stat_ref{$GNUMNUMS} > 1 )
          {
            $$stat_ref{$GRMSE} = 
              ( ( $$stat_ref{$GSUMSQ} -
                  $$stat_ref{$GNUMNUMS} * $$stat_ref{$GMEAN}**2 ) ** .5 ) /
                    ( $$stat_ref{$GNUMNUMS} - 1 );
          }
        else
          {
            $$stat_ref{$GRMSE} = -1;
          }
      }
    #.......................................................................
    #...rms - not used since slow - although less loss or arith precision...
    #.......................................................................
    #if( $$stat_ref{$GNUMNUMS} > 0 )
    #  {
    #    $$stat_ref{$GRMS}  = 0;
    #    for( $i = 0; $i <= $num_elements; $i++ )
    #      {
    #        $val = $$array_ref[$i];
    #        if( $val =~ /^$GNUMBER_REGEXP$/ && abs( $val ) < $GSKIP )
    #          {
    #            $$stat_ref{$GRMS} += ($val - $$stat_ref{$GMEAN})**2;
    #          }
    #      }
    #    if( $$stat_ref{$GNUMNUMS} > 1 )
    #      {
    #        $$stat_ref{$GRMS} =
    #          ((($$stat_ref{$GRMS})**.5)/($$stat_ref{$GNUMNUMS}-1));
    #      }
    #    else
    #      {
    #        $$stat_ref{$GRMS} = -1;
    #      }
    #  }
 }

#............................................................................
#...Name
#...====
#... get_file_type
#...
#...Purpose
#...=======
#... Get the filt type (xy, table, token, ... )
#... A file type match is done on the file name.
#... If not found, try to get file type by sampling a block of lines
#... and seeing what they look like.  If enough lines match the
#... threshhold, the file type is assigned.
#... If still no match, set file type to token.
#...
#...Arguments
#...=========
#... $file_name     Intent: in
#...                Perl type: scalar
#...                File name to read in
#...
#... $file_type_ref Intent: out
#...                Perl type: reference to scalar
#...                string of file type.
#...
#... $ierr          Intent: out
#...                Perl type: scalar
#...                Error return value (non-0 for error)
#...
#...Program Flow
#...============
#... 1) detect file type by name
#... 2) detect file type by contents
#............................................................................
sub get_file_type {
    my(
        $file_name,
        $file_type_ref,
        ) = @_;
    my(
        $count,  # count matches
        $count1, # count matches
        $done,
        $num_ds, # number of datasets
        $num_fields, # number of fields
        @fields,
        @files,
        $found, # if found something
        $i, # loop var
        $ierr, # error ret val
        $ierr_sys, # error ret val from system call
        $line, # line of file
        $lines_read, # number of lines to read in file (neg for whole file)
        @lines, # lines of file without blank lines
        $lines_all,
        @lines_orig, # lines of file untouched
        $start_line, # starting line number
        $threshhold, # threshhold ratio for match
        $threshhold_actual, # actual data gotten for threshhold
        %tmp,
        @tokens, # tokens on a line
        @tokens_numbers,
        );

    #..........
    #...init...
    #..........
    $ierr = 0;
    $threshhold = .7;
    $threshhold_actual = 1;
    $lines_read = 10;
    undef( $$file_type_ref );

    # if given a dummy file - do not (file not there)
    if( $file_name eq "dummy" ){
        $$file_type_ref = $GFTDUMMY;
        return( $ierr );
    }

    #................................
    #...open FILE, read some lines...
    #................................
    if( ! defined( $file_name ) ) {
        $ierr = 0;
        &cts_diff_util::print_error( "Filename not defined.",
                                     $ierr );
        return( 1 );
    }
    if( ! open( FILE, $file_name ) ) {
        $ierr = 0;
        &cts_diff_util::print_error( "Cannot open file [$file_name]",
                                     $ierr );
        return( 1 );
    }
    while( ( $lines_read < 0 || $#lines + 1 < $lines_read ) &&
           ( $line = <FILE> ) ) {
        push( @lines_orig, $line );
        if( $line =~ /\S/ ) {
            push( @lines, $line );
        }
    }
    close( FILE );

    $lines_all = join('',@lines);

    # gmv: can only handle "nodes -1 (nodes)" types of files
    # treat others as token
    if( ! defined($$file_type_ref) && $lines_all =~ /^\s*gmvinput/m ){
        if( $lines_all =~ /^\s*nodes\s+-1/m ){
            $$file_type_ref = $GFTGMV;
        }
        else{
            $$file_type_ref = $GFTTOKEN;
        }
    }

    #............................
    #...file line: plot_output...
    #............................
    #...first line looks like a data block
    if( ! defined( $$file_type_ref ) && $#lines > 0 )
      {
        if( $lines[0] =~ /^#\s*\[\d+\]\s*\S+/ )
          {
            $$file_type_ref = $GFTPLOT_OUTPUT;
          }
      }

    # tecplot
    if( ! defined( $$file_type_ref ) && $#lines > 0 ){
        if( $lines[0] =~ /^\s*title\b/ &&
            $lines[1] =~ /^\s*variables/ ){
            $$file_type_ref = $GFTTECPLOT;
        }
        if( $lines[0] =~ /^\s*VARIABLES=/ &&
            $lines[1] =~ /^\s*zone/ ){
            $$file_type_ref = $GFTTECPLOT;
        }
    }

    #...................
    #...file name: xy...
    #...................
    if( ! defined( $$file_type_ref ) && $file_name =~ /\.xy(\.std)?$/ )
      {
        $$file_type_ref = $GFTXY;
      }

    #...................
    #...file line: xy...
    #...................
    #... # <possible multi word ds name>
    #... <val1>  <val2>   (most of the lines fit this)
    if( ! defined( $$file_type_ref ) && $#lines > 0 ) {
        #.........................
        #...matches # <ds name>...
        #.........................
        if( $lines[0] =~ /^\s*\#\s*(\S+.*)/ ) {

            $count = 0;
            $count1 = 0;
            for( $i = 0; $i <= $#lines; $i++ ) {

                $line = $lines[$i];
                $line =~ s/^\s+//;
                $line =~ s/\s+$//;

                # possible header line - last "#" wins
                if( $line =~ /^\s*\#\s*(\S+.*?)\s*$/ ){
                    $line = $1;
                    # last possible fields for header
                    @fields = split( /\s+/, $line);
                }
                
                # data line (not a "#" line)
                elsif( $line =~ /^(\S.*?)\s*$/ ){
                    $line = $1;
                    @tokens = split( /\s+/, $line);
                    $count1++;
                    # header is not 2 values and
                    # data line 2 values both numbers
                    if( $#fields != 1 &&
                        $#tokens == 1 &&
                        $tokens[0] =~ /^$GNUMBER_REGEXP$/ &&
                        abs( $tokens[0] ) < $GSKIP &&
                        $tokens[1] =~ /^$GNUMBER_REGEXP$/ &&
                        abs( $tokens[1] ) < $GSKIP ) {
                        $count++;
                    }

                } # data line

            } # foreach line

            if( $count1 > 0 ){
                $threshhold_actual = $count/$count1;
            }
            else{
                $threshhold_actual = 0;
            }
            if( $threshhold_actual >= $threshhold ) {
                $$file_type_ref = $GFTXY;
            }

        } # matches # <ds name>

    } # file line: xy

    # xy_block
    if( ! defined( $$file_type_ref ) && $#lines > 0 ) {
        if( $lines[0] =~ /^\s*\$(\S+)\s+(\S+)\s*=\s*'\s*(\S+)\s*'\s*,?\s*\n$/ &&
            $lines[1] =~ /\s*(\S+)\s*\(\s*1\s*[, ]\s*(\d+)\s*\)\s*=\s*/ ){
            $$file_type_ref = $GFTXY_BLOCK;
        }
    }

    #....................
    #...file line: pop...
    #....................
    #...First line says something like "now in PoP"...
    if( ! defined( $$file_type_ref ) && $#lines > 0 ) {
        #.........................
        #...matches # <ds name>...
        #.........................
        if( $lines[0] =~ /\s+now in PoP\s+/ ) {
            $$file_type_ref = $GFTPOP;
        }
    }

    #....................
    #...file line: cts...
    #....................
    if( ! defined( $$file_type_ref ) && $#lines >= 0 ) {
        #...................
        #...matches # cts...
        #...................
        if( $lines[0] =~ /^\# cts\n$/ ) {
            $$file_type_ref = $GFTCTS;
        }
    }

    # ---
    # ctf
    # ---
    if( ! defined( $$file_type_ref ) ){
        @files = ($file_name);
        $ierr = &ctf_read( FILES=>\@files, CHECK_ONLY=>"", VALS=>\%tmp );
        # not defined, means not a ctf file
        if( ! defined($ierr) ){
            $ierr = 0;
        }
        # defined and no error, ctf file
        elsif( $ierr == 0 ){
            $$file_type_ref = $GFTCTF;
        }
        # defined and error means got an error (ignore it???)
        else{
            $ierr = 0;
        }
    }

    #.....................
    #...file line: ares...
    #.....................
    #...within a few lines, says key phrase...
    if( ! defined( $$file_type_ref ) && $#lines >= 0 ) {
        #............................................
        #...first non-blank line must match format...
        #............................................
        if( $lines[0] =~
            /
            ^\s*                    # start with possible whitespace
            (\S+)\s+                # test
            (DIFF|FAILED|PASSED)\s+ # test results
            (P-[0-9]+),\s+          # P field,
            (D-[0-9]+),\s+          # D field,
            (F-[0-9]+)\s+           # F field
            $/x ) {
            $$file_type_ref = $GFTARES;
        }
    }

    #.......................
    #...file name: tracer...
    #.......................
    if( ! defined( $$file_type_ref ) && $file_name =~ /\-tracer$/i ) {
        $$file_type_ref = $GFTTRACER;
    }

    #.......................
    #...file line: tracer...
    #.......................
    #... ds_name_1, ds_name_2, ... , ds_name_n
    #...   somewhere in there is "particle" and "time" fields
    #... val_1,     val_2, ... ,     val_n
    #... # <ds name>
    #... <val1>  <val2>   (most of the lines fit this)
    if( ! defined( $$file_type_ref ) && $#lines > 0 ) {
        $count  = 0;
        $num_ds = 0;
        $found = "false";
        #...check lines
        for( $i = 0; $i <= $#lines; $i++ ) {
            #...stop if hit enough matches
            if( $count > 10 ) {
                last;
            }
            #...remove leading/trailing whitespace and comment lines
            $line = $lines[$i];
            $line =~ s/^\s*(.*\S)\s*$/$1/;
            $line =~ s/\s*\#.*//;
            if( $line =~ /\S/ ) {
                @tokens = split( /\s*,\s*/, $line );
                $num_fields = $#tokens + 1;
                if( $found eq "false" ) {
                    $found = "true";
                    $count1 = 0;
                    $num_ds = $num_fields;
                    #...must have certain fields
                    if( grep( /^particle$/, @tokens ) ) {
                        $count1++;
                    }
                    if( grep( /^time$/, @tokens ) ) {
                        $count1++;
                    }
                    if( $count1 != 2 ) {
                        last;
                    }
                    next;
                }
                # if you hit a line that does not match num_ds,
                # this is not tracer
                if( $num_ds != $num_fields ) {
                    $count = 0;
                    last;
                }
                else {
                    $count++;
                }
            }
        }
        if( $count >= 1 ) {
            $$file_type_ref = $GFTTRACER;
        }
    }
    
    #....................
    #...file grep: oxy...
    #....................
    #>>>HAVE THIS LAST SINCE GREPPING THE WHOLE FILE<<<
    #>>>DO THIS SEARCH IF GOT A FUZZY MATCH ABOVE<<<
    if( ! ( defined( $$file_type_ref ) && $threshhold_actual eq "1" ) &&
        $#lines >= 0 ) {
        $ierr_sys = system( "grep", "-q", $GOXY_TAG_START, $file_name );
        if( ! $ierr_sys ) {
            $$file_type_ref = $GFTOXY;
        }
    }

    # special tables
    if( ! defined( $$file_type_ref ) && $lines_all =~ /Search on the following keywords/ ){
        $$file_type_ref = $GFTTABLE_X;
    }

    # special tables
    if( ! defined( $$file_type_ref ) && $lines_all =~ /^\s*#\s*eap_lineout/ ){
        $$file_type_ref = $GFTTABLE_X;
    }

    # above gmv already processed...rest is token
    # not a table
    if( ! defined( $$file_type_ref ) &&
        $lines_all =~ /^\s*gmvinput ascii/ ){
        $$file_type_ref = $GFTTOKEN;
    }

    # not a table
    if( ! defined( $$file_type_ref ) &&
        $lines_all =~ /^\s*-+\s*\n            # --------------------------
                        \s*Testing\s+:\s+.*\n # Testing : 
                        \s*(-\s){10,}-\s*\n   # - - - - - - - - - -...-
                      /xi ){
        $$file_type_ref = $GFTTOKEN;
    }

    #...............................
    #...file line: table, table_x...
    #...............................
    #...# <comments>
    #...#? <ds1 name>  <ds2 name>  <ds3 name>
    #... <val ds1>   <val ds2>   <val ds3>  (most of the lines fit this)
    #...
    #...NOTE: this will also treat a matrix (table w/out headers) as
    #...      a table.  this is fine (since the headers are not gotten here).
    if( ! defined( $$file_type_ref ) && $#lines > 0 ) {
        # get to first data line
        $start_line = -1;
        undef( $done );
        while( ! defined( $done ) ){
            undef( @tokens );
            undef( @tokens_numbers );
            $start_line++;

            # end of file
            if( $start_line > $#lines ){
                $done = "";
                next;
            }

            $line = $lines[$start_line];

            # comment line
            $line =~ s/^\s*#.*//;
            if( $line !~ /\S/ ){
                next;
            }

            $line =~ s/^\s*//;

            # not a data line (can have "-" as values)
            @tokens = split(/\s+/, $line);
            @tokens_numbers = grep( /^(($GNUMBER_REGEXP)|-)$/, @tokens);
            if( $#tokens != $#tokens_numbers ){
                next;
            }

            # if here, then have a data line
            $done = "";
        }

        # if got more than 1 column of numbers, say it is a table
        if( $#tokens_numbers > 0 ){
            $$file_type_ref = $GFTTABLE;
        }
    }

    #...............
    #...otherwise...
    #...............
    if( ! defined( $$file_type_ref ) ) {
        $$file_type_ref = $GFTTOKEN;
    }

    #...........................
    #...close file and return...
    #...........................
    close( FILE );
    return( $ierr );
}

#............................................................................
#...Name
#...====
#... get_tols
#...
#...Purpose
#...=======
#... Get the values for the tolerances given the inputs
#...
#...Arguments
#...=========
#... $cmd_ref          Intent: in
#...                   Perl type: reference to hash
#...                   Gotten from parse_args()
#...
#... $ds_name          Intent: in
#...                   Perl type: scalar
#...                   Name of the dataset
#...
#... $tols_ref         Intent: out
#...                   Perl type: reference to hash
#...                   $tols{$GABS, $GREL, ... }
#...                   Tolerances hash.
#...
#...Program Flow
#...============
#... 1) Compute differences
#............................................................................
sub get_tols {
    my(
        $cmd_ref,
        $ds_name,
        $tols_ref,
        ) = @_;
    my(
        $ds_regexp,
        $i,
        $tol_name,
        $val,
        );
    undef(%{$tols_ref});
    # last match wins
    foreach $tol_name ( $GTOL_A, $GTOL_R, $GVAL_SKIP, "ds_cmp" ){
        $$tols_ref{$tol_name} = undef;
        $i = 0;
        if( ! defined( $$cmd_ref{$tol_name} ) ){
            next;
        }
        foreach $ds_regexp ( @{$$cmd_ref{$tol_name}{$GTOL_DS}} ){
            $val = $$cmd_ref{$tol_name}{$GTOL_VAL}[$i];
            if( $ds_name =~ /^($ds_regexp)$/ ){
                $$tols_ref{$tol_name} = $val;
            }
            $i++;
        }
    }
}

########################################################################
# returns the value given the ds_name and type
sub get_val_regexp{
    my(
        $cmd_ref,
        $ds_name,
        $type,
        ) = @_;
    my(
        $ds_regexp,
        $i,
        $val,
        $val_try,
        );

    # last match wins
    undef( $val );
    $i = 0;
    if( defined($$cmd_ref{$type}) ){
        if( defined($$cmd_ref{$type}{$GTOL_DS}) ){
            foreach $ds_regexp ( @{$$cmd_ref{$type}{$GTOL_DS}} ){
                $val_try = $$cmd_ref{$type}{$GTOL_VAL}[$i];
                if( $ds_name =~ /^($ds_regexp)$/ ){
                    $val = $val_try;
                }
                $i++;
            }
        }
    }
    return( $val );
}

#............................................................................
#...Name
#...====
#... interpolate
#...
#...Purpose
#...=======
#... This converts 1 set of data points to another using the a set of X
#... values.
#...     (base_x, base_y) -> (intp_x, intp_y)
#...    in:
#...     base_x, base_y, intp_x
#...    out:
#...     inpt_y
#... Currently linear interpolation is done.
#...
#...Arguments
#...=========
#... $base_x_ref       Intent: in
#...                   Perl type: reference to array
#...                   The base X values.
#...                   These values must be monotonically increasing
#...
#... $base_y_ref       Intent: in
#...                   Perl type: reference to array
#...                   The base Y values.
#...
#... $intp_x_ref       Intent: in
#...                   Perl type: reference to array
#...                   The values to interpolate to.
#...                   These values must be monotonically increasing
#...
#... $intp_y_ref       Intent: out
#...                   Perl type: reference to array
#...                   The base Y values.
#...
#...Program Flow
#...============
#... 1) Foreach value in intp_x_ref
#... 1.1) Find 2 points in the base set
#... 1.2) compute slope m
#... 1.3) intp_y = m*(intp_x - base_x) + base_y
#............................................................................
sub interpolate
  {
    my(
       $base_x_ref,
       $base_y_ref,
       $intp_x_ref,
       $intp_y_ref
      ) = @_;
    my(
       $done, # if done in a loop
       $equal, # quick exit if same x vals
       $final_pair, # if no more pairs of points will be found - no search
       $i, # loop var
       $idx_a, # index of first point
       $idx_a_prev, # previous value for it
       $idx_b, # index of next point
       $idx_b_prev, # previous value for it
       $ierr,
       $intp_x, # a value of ref
       $intp_y, # a value of ref
       $m, # slope
       @prune_x,
       @prune_y,
       $tmp_a, # tmp value for printing
       $tmp_b, # tmp value for printing
       $val1,
       $val2,
       $val_prev, # previous value for testing monatomically increasing
       $val_curr, # current value for testing monatomically increasing
      );
    $ierr = 0;
    #.....................................................
    #...test for monatomically increasing base_x values...
    #.....................................................
    undef( $val_prev );
    for( $i = 0; $i <= $#$base_x_ref; $i++ )
      {
        $val_curr = $$base_x_ref[$i];
        if( ! defined( $val_curr ) || val_curr !~ /^$GNUMBER_REGEXP$/ || abs($val_curr) >= $GSKIP )
          {
            next;
          }
        if( defined( $val_prev ) && $val_prev > $val_curr )
          {
            $ierr = 1;
            $tmp_b = $i + 1;
            &print_error( "Base X-values must not be decreasing to interpolate",
                          "Prev: [$tmp_a:$val_prev] > Current [$tmp_b:$val_curr]",
                          $ierr );
            return( $ierr );
          }
        $tmp_a = $i+1;
        $val_prev = $val_curr;
      }

    # test that length of base_x >= base_y arrays
    if( $#$base_x_ref < $#$base_y_ref )
      {
        $ierr = 1;
        &print_error( "Length of Base X array [$#$base_x_ref] less than ".
                      "Base Y array [$#$base_y_ref]",
                      $ierr );
        return( $ierr );
      }

    # quick exit if the x vals are the same
    if( $#$base_x_ref == $#$intp_x_ref ){
        $equal = "true";
        for( $i = 0; $i <= $#$base_x_ref; $i++ ){

            # skip if both not defined
            if( ! defined($$base_x_ref[$i]) && ! defined($$intp_x_ref[$i]) ){
                next;
            }
            # if only one is not defined, not equal
            if( (! defined($$base_x_ref[$i]) || ! defined($$intp_x_ref[$i]) ) ){
                $equal = "false";
                last;
            }

            # if strings do not match, convert to same exponential notation.
            if( $$base_x_ref[$i] ne $$intp_x_ref[$i] ){
                # account for different exponents
                ($val1 = $$base_x_ref[$i]) =~ s/e(\+|-)0+/e$1/i;
                ($val2 = $$intp_x_ref[$i]) =~ s/e(\+|-)0+/e$1/i;
                if( $val1 ne $val2 ){
                    $equal = "false";
                    last;
                }
            }

            # if both x match, but base y value is undefined, interpolate
            if( $$base_x_ref[$i] == $$intp_x_ref[$i] &&
                ! defined($$base_y_ref[$i]) ){
                $equal = "false";
                last;
            }
            
        }
        if( $equal eq "true" ){
            @$intp_y_ref = @$base_y_ref;
            return( $ierr );
        }
    }
    #.....................................................
    #...test for monatomically increasing intp_x values...
    #.....................................................
    undef( $val_prev );
    foreach $val_curr ( @$intp_x_ref )
      {
        if( ! defined($val_curr) || $val_curr !~ /^$GNUMBER_REGEXP$/ || abs($val_curr) >= $GSKIP )
          {
            next;
          }
        #.......................................
        #...test for monatomically increasing...
        #.......................................
        if( defined( $val_prev ) && $val_prev >= $val_curr )
          {
            $ierr = 1;
            &print_error( "Intp X-values must be increasing to interpolate",
                          "Prev: [$val_prev] >= Current [$val_curr]",
                          $ierr );
            return( $ierr );
          }
        $val_prev = $val_curr;
      }

    # prune out undefs in base
    # this allows correct interpolation over undefs
    @prune_x = ();
    @prune_y = ();
    for( $i = 0; $i <= $#$base_x_ref; $i++ ){
        if( defined( $$base_y_ref[$i] ) ){
            push( @prune_x, $$base_x_ref[$i] );
            push( @prune_y, $$base_y_ref[$i] );
        }
    }
    $base_x_ref = \@prune_x;
    $base_y_ref = \@prune_y;
    
    #................................................................
    #...get to the first pair of points where $$base_x_ref differs...
    #................................................................
    $idx_a = 0;
    while( $idx_a <= $#$base_x_ref )
      {
        if( defined($$base_x_ref[$idx_a]) &&
            $$base_x_ref[$idx_a] =~ /^$GNUMBER_REGEXP$/ &&
            abs($$base_x_ref[$idx_a]) < $GSKIP )
          {
            last;
          }
        $idx_a++;
      }
    $idx_b = $idx_a + 1;
    while( $idx_b <= $#$base_x_ref )
      {
        if( defined( $$base_x_ref[$idx_b] ) &&
            $$base_x_ref[$idx_b] =~ /^$GNUMBER_REGEXP$/ &&
            abs($$base_x_ref[$idx_b]) < $GSKIP )
          {
            if( $$base_x_ref[$idx_a] != $$base_x_ref[$idx_b] )
              {
                last;
              }
            else
              {
                $idx_a = $idx_b;
              }
          }
        $idx_b++;
      }
    if( $idx_b > $#$base_x_ref )
      {
        $idx_b = $idx_a;
      }
    $idx_a_prev = $idx_a;
    $idx_b_prev = $idx_b;
    $final_pair = 0;
    #................................................
    #...compute intp_y foreach value in intp_x_ref...
    #................................................
    foreach $intp_x ( @$intp_x_ref )
      {
        #................................................
        #...if intp_x not valid, set intp_y to invalid...
        #................................................
        if( ! defined($intp_x) || $intp_x !~ /^$GNUMBER_REGEXP$/ || abs($intp_x) >= $GSKIP ||
            $idx_a > $#$base_x_ref )
          {
            $intp_y = "undef";
          }
        #........................................
        #...linear interpolation to get intp_y...
        #........................................
        else
          {
            $done = 0;
            #.........................................................
            #...Find 2 points in the base set to be used for interp...
            #.........................................................
            while( $done == 0 && $final_pair == 0 )
              {
                #.........................................................
                #...if bounded by idx_b, done since any subsequent pair...
                #...of points will be further away than this pair      ...
                #.........................................................
                if( $intp_x <= $$base_x_ref[$idx_b] )
                  {
                    $done = 1;
                  }
                #......................
                #...get to next pair...
                #......................
                else
                  {
                    #.................................................
                    #...reset previous values - increment a if != b...
                    #.................................................
                    $idx_b_prev = $idx_b;
                    if( $$base_x_ref[$idx_a] != $$base_x_ref[$idx_b] )
                      {
                        $idx_a_prev = $idx_a;
                      }
                    #................................................
                    #...point a to b and b starting guess at a + 1...
                    #................................................
                    $idx_a = $idx_b;
                    $idx_b = $idx_a + 1;
                    while( $idx_b <= $#$base_x_ref )
                      {
                        if( defined($$base_x_ref[$idx_b]) &&
                            $$base_x_ref[$idx_b] =~ /^$GNUMBER_REGEXP$/ &&
                            abs($$base_x_ref[$idx_b]) < $GSKIP )
                          {
                            last;
                          }
                        $idx_b++;
                      }
                    #.....................................................
                    #...if no next pair, then                          ...
                    #...  done, reset to previous point, and final_pair...
                    #.....................................................
                    if( $idx_b > $#$base_x_ref )
                      {
                        $final_pair = 1;
                        $done = 1;
                        $idx_b = $idx_b_prev;
                        $idx_a = $idx_a_prev;
                      }
                  }
                #............................
                #...DONE: get to next pair...
                #............................
              }
            #...............................................................
            #...DONE: Find 2 points in the base set to be used for interp...
            #...............................................................
            #...................................................
            #...if found at least 1 valid number intp on that...
            #...................................................
            if( $idx_a <= $#$base_x_ref )
              {
                #...............................................
                #...if base_y are numbers, interpolate       ...
                #...base_x already must be numbers from above...
                #...............................................
                if( defined($$base_y_ref[$idx_a]) &&
                    defined($$base_y_ref[$idx_b]) &&
                    $$base_y_ref[$idx_a] =~ /^$GNUMBER_REGEXP$/ &&
                    abs( $$base_y_ref[$idx_a] ) < $GSKIP &&
                    $$base_y_ref[$idx_b] =~ /^$GNUMBER_REGEXP$/ &&
                    abs( $$base_y_ref[$idx_b] ) < $GSKIP )
                  {
                    #.....................
                    #...compute slope m...
                    #.....................
                    if( $idx_a != $idx_b )
                      {
                        $m =
                          ($$base_y_ref[$idx_b] - $$base_y_ref[$idx_a])/
                            ($$base_x_ref[$idx_b] - $$base_x_ref[$idx_a]);
                      }
                    else
                      {
                        $m = 0;
                      }
                    #...........................................
                    #...intp_y = m*(intp_x - base_x) + base_y...
                    #...........................................
                    $intp_y = $m*($intp_x - $$base_x_ref[$idx_a]) +
                      $$base_y_ref[$idx_a];
                  }

                # if non-number, set to val if x index matches up
                # or set to "-".
                else {
                    if( $intp_x == $$base_x_ref[$idx_a] ){
                        $intp_y = $$base_y_ref[$idx_a];
                    }
                    elsif( $intp_x == $$base_x_ref[$idx_b] ){
                        $intp_y = $$base_y_ref[$idx_b];
                    }
                    else{
                        $intp_y = "undef";
                    }
                     
                    # had logic to set to closest x value...but
                    # that leads to odd results when comparing:
                    #    hello there
                    #    hello there and bye
                    #if( abs( $intp_x - $$base_x_ref[$idx_a] ) <
                    #    abs( $intp_x - $$base_x_ref[$idx_b] ) ) {
                    #    $intp_y = $$base_y_ref[$idx_a];
                    #}
                    #else {
                    #    $intp_y = $$base_y_ref[$idx_b];
                    #}
                }
              }

            #.........................................................
            #...DONE: if found at least 1 valid number intp on that...
            #.........................................................
            else
              {
                $intp_y = "undef";
              }
          }
        #..............................................
        #...DONE: linear interpolation to get intp_y...
        #..............................................

        # if the new_y value is also undefined, undef it
        if( defined( $intp_y ) && $intp_y eq "undef" ){
            undef( $intp_y );
        }
        push( @$intp_y_ref, $intp_y );
      }
    #......................................................
    #...DONE: compute intp_y foreach value in intp_x_ref...
    #......................................................
    return( $ierr );
  }

#............................................................................
#...Name
#...====
#... merge_stats
#...
#...Purpose
#...=======
#... merge first stat hash into second one (eg Max is max of first and
#... second one).
#... If the second stat is not defined, this is effectively a copy op.
#...
#...Arguments
#...=========
#... $stat_ref_a  Intent: in
#...              Perl type: reference to hash
#...              Created from create_stats
#...
#... $stat_ref_b  Intent: inout
#...              Perl type: reference to hash
#...              Created from create_stats
#...              Contains merging of stat_ref_a and stat_ref_b
#...
#...Notes
#...=====
#... Some values cannot be merged:
#...   - RMS -> take max RMS value
#...
#...Program Flow
#...============
#... 1) merge
#............................................................................
sub merge_stats
  {
    my(
       $stat_ref_a,
       $stat_ref_b
      ) = @_;
    my(
       $key, # key for hash
       %orig_b, # original stat_ref_b
       $val_a, # a value
       $val_b, # a value
     );
    foreach $key ( keys %{$stat_ref_b} )
      {
        $orig_b{$key} = $$stat_ref_b{$key};
      }
    foreach $key ( $GNUMNTRUE,
                   $GNUMNFALSE,
                   $GNUMNUMS,
                   $GNUMSTRUE,
                   $GNUMSFALSE,
                   $GNUMSTRS,
                   $GNUMTRUE,
                   $GNUMFALSE,
                   $GNUMALL,
                   $GSUMSQ )
      {
        $val_a = $$stat_ref_a{$key};
        $val_b = $orig_b{$key};
        if( defined( $val_a ) && defined( $val_b ) )
          {
            $$stat_ref_b{$key} = $val_a + $val_b;
          }
        elsif( defined( $val_a ) )
          {
            $$stat_ref_b{$key} = $val_a;
          }
        else
          {
            $$stat_ref_b{$key} = $val_b;
          }
      }
    foreach $key ( $GMAX, $GMAXABS )
      {
        $val_a = $$stat_ref_a{$key};
        $val_b = $orig_b{$key};
        if( defined( $val_a ) && defined( $val_b ) )
          {
            $$stat_ref_b{$key} = $val_a > $val_b ? $val_a : $val_b;
          }
        elsif( defined( $val_a ) )
          {
            $$stat_ref_b{$key} = $val_a;
          }
        else
          {
            $$stat_ref_b{$key} = $val_b;
          }
      }
    foreach $key ( $GMIN )
      {
        $val_a = $$stat_ref_a{$key};
        $val_b = $orig_b{$key};
        if( defined( $val_a ) && defined( $val_b ) )
          {
            $$stat_ref_b{$key} = $val_a < $val_b ? $val_a : $val_b;
          }
        elsif( defined( $val_a ) )
          {
            $$stat_ref_b{$key} = $val_a;
          }
        else
          {
            $$stat_ref_b{$key} = $val_b;
          }
      }
    #...mean (uses new numnums)...
    $val_a = $$stat_ref_a{$GMEAN};
    $val_b = $orig_b{$GMEAN};
    if( defined( $val_a ) && defined( $val_b ) )
      {
        $$stat_ref_b{$GMEAN} =
          ($val_a*$$stat_ref_a{$GNUMNUMS} + $val_b*$orig_b{$GNUMNUMS})/
            ($$stat_ref_b{$GNUMNUMS});
      }
    elsif( defined( $val_a ) )
      {
        $$stat_ref_b{$GMEAN} = $val_a;
      }
    else
      {
        $$stat_ref_b{$GMEAN} = $val_b;
      }
    #...rms (do with new numnums, and mean)...
    $val_a = $$stat_ref_a{$GRMS};
    $val_b = $orig_b{$GRMS};
    if( defined( $val_a ) && defined( $val_b ) )
      {
        $$stat_ref_b{$GRMS} =
          ((($$stat_ref_b{$GSUMSQ}-
             $$stat_ref_b{$GNUMNUMS}*
             ($$stat_ref_b{$GMEAN}**2)))**.5)/
              ($$stat_ref_b{$GNUMNUMS}-1);
      }
    elsif( defined( $val_a ) )
      {
        $$stat_ref_b{$GRMS} = $val_a;
      }
    else
      {
        $$stat_ref_b{$GRMS} = $val_b;
      }
  }

# return ret = a value of a flag given a name
# undef if not found or (no:-)
# sets $$found_ref if found at all
sub cts_get_val{
    my(
        $name,
        $dss_flag_val_ref, # hash of the @val, @dss, @flag
        $found_ref,
        ) = @_;
    my(
        $dss,
        $i,
        $flag,
        $regexp,
        $ret,
        );

    undef( $$found_ref );
    $i = 0;
    # skip special dataset names (these are created to explicitly be done)
    if( $name =~ /:ctslast$/ ){
    }
    else{
        foreach $dss ( @{$$dss_flag_val_ref{dss}} ){
            ($regexp = $dss) =~ s/\s*,\s*/|/g;
            if( $name =~ /^($regexp)$/ ){
                if( defined($found_ref) ){
                    $$found_ref = "";
                }
                $flag = $$dss_flag_val_ref{flag}[$i];
                if( $flag eq "+" ){
                    $ret = $$dss_flag_val_ref{val}[$i];
                }
                else{
                    $ret = undef;
                }
            }
            $i++;
        }
    }
    return( $ret );
}

#............................................................................
#...Name
#...====
#... parse_args
#...
#...Purpose
#...=======
#... Create cmd hash from command line
#...
#...Arguments
#...=========
#... $argv_ref    Intent: out
#...              Perl type: reference to array
#...              \@ARGV usually
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line
#...              $cmd{$option} = value
#...              $cmd{files}[] = array of file names
#...
#...Program Flow
#...============
#... 1) go through command line and assign to cmd hash
#............................................................................
sub parse_args {
    my(
        $argv_ref,
        $cmd_ref
        ) = @_;
    my(
        $arg_file, # name for argument file
        @arg_files, # all files read
        @args, # arguments
        $dss,
        $flag,
        $fh_FILE,
        $ierr, # error ret val
        @lines,
        $no_set,
        $num_args, # number of arguments
        $opt, # current option
        $opt_full,
        @opts, # array of options
        $regexp,
        $special,
        @vals, # array of values
        $val, # value for current option
        $val1, # another value
        $val2,
        $val_try,
        );
    $ierr = 0;
    @args = @{$argv_ref};

    # default
    $$cmd_ref{unique_filenames} = "";

    # putting in better mechanism in run_job.pl to enforce "#RJ TIME='
    # knl take really long to plot, default noplots
    #if( defined( $ENV{RJ_L_OS} ) ){
    #    if( $ENV{RJ_L_OS} eq "TR_KNL" ){
    #        unshift( @args, "--noplots" );
    #    }
    #}

    #...........................
    #...read in argument file...
    #...........................
    $arg_file = "./cts_diff.arg";
    if( -T $arg_file ) {
        # do not add since processing it
        # push( @{$$cmd_ref{command_line}}, "-arg $arg_file" );
        $ierr = &read_arg_file( $arg_file, \@args, \@arg_files );
        # silent
        if( $ierr ){
            $ierr = 0;
            #&print_error( "Failure reading argument file [$arg_file].",
            #              $ierr );
        }
    }

    #....................
    #...parse the args...
    #....................
    $num_args = $#args;
    while( @args ) {
        $opt = shift( @args );

        # -(a|r) <val>[<comma separated var regexp list>]
        if( $opt =~ /^-+(a|ds_base|ds_cmp|r|$GVAL_SKIP)$/ ) {
            $opt = $1;
            if( ! @args ) {
                $ierr = 1;
                &print_error( "Value needed for option [-$opt].",
                              $ierr );
                return( $ierr );
            }
            $val = shift( @args );
            push( @{$$cmd_ref{command_line}}, "-$opt '$val'" );
            @vals = split( /\s*,\s*/, $val );
            $val = shift( @vals );
            $val_try = $val;
            $special = "";
            if( $opt eq "r" && 
                $val =~ /^((ns|s):)(.*)$/ ){
                $special = $1;
                $val_try = $3;
            }
            if( $opt =~ /^(ds_base)$/ ){
                if( $val_try !~ /^$GNUMBER_REGEXP$/ ){
                    $ierr = 1;
                    &print_error( "Value for option [-$opt $val -> $val_try] must be a number",
                                  $ierr );
                    return( $ierr );
                }
            }
            elsif( $opt =~ /^(ds_cmp)$/ ){
                if( $val_try !~ /(>|>=|<|<=)\s*($GNUMBER_REGEXP)/ ){
                    $ierr = 1;
                    &print_error( "Value for option [-$opt $val -> $val_try] must be  {cmp}{val}:",
                                  "  >0",
                                  " <=-8.2e4",
                                  $ierr );
                    return( $ierr );
                }
            }
            elsif( $val_try !~ /^$GNUMBER_REGEXP$/ ||
                ( abs( $val_try ) >= $GSKIP || $val_try < 0 )){
                $ierr = 1;
                &print_error( "Value for option [-$opt $val -> $val_try] must be in the range [0,$GSKIP]",
                              $ierr );
                return( $ierr );
            }
            $val = "$special$val_try";
            if( $#vals < 0 ){
                $regexp = ".+";
            }
            else{
                $regexp = join( '|', @vals );
            }
            # stick onto ordered list
            push( @{$$cmd_ref{$opt}{$GTOL_DS}},  $regexp );
            push( @{$$cmd_ref{$opt}{$GTOL_VAL}}, $val );
        }

        # scaled_r_ds
        elsif( $opt =~ /^--((no)?(scaled_r_ds))$/ ){
            $opt_full = $1;
            $flag     = $2;
            $opt      = $3;
            if( ! @args ){
                $ierr = 1;
                &print_error( "Value needed for option [-$opt].",
                              $ierr );
                return( $ierr );
            }
            $val = shift( @args );
            push( @{$$cmd_ref{command_line}}, "-$opt_full '$val'" );

            # no/<normal>
            if( defined($flag) ){
                $flag = "-";
                $dss  = $val;
                $val  = undef;
            }
            else{
                if( $val =~ /^([^,]+),(.*)$/ ){
                    $dss = $2;
                    $val = $1;
                }
                else{
                    $dss = ".+";
                }
                $flag = "+";
            }
            
            # push onto list to be evaluated by cts_get_val
            push(@{$$cmd_ref{$opt}{val}},  $val);
            push(@{$$cmd_ref{$opt}{dss}},  $dss);
            push(@{$$cmd_ref{$opt}{flag}}, $flag);
        }

        #...................
        #...-ft file_type...
        #...................
        elsif( $opt =~ /^-+(ft)$/ ) {
            $opt = $1;
            if( ! @args ) {
                $ierr = 1;
                &print_error( "Value needed for option [-$opt].",
                              $ierr );
                return( $ierr );
            }
            $val = shift( @args );
            push( @{$$cmd_ref{command_line}}, "-$opt '$val'" );
            if( $val !~ /$GFTKEYWORD|$GFTCTF(:\S+)?|$GFTCTS|$GFTGMV|$GFTOXY|$GFTPLOT_OUTPUT|$GFTPOP|$GFTTABLE|$GFTTABLE_X|$GFTTECPLOT|$GFTTOKEN|$GFTTRACER|$GFTLINK|$GFTXY|$GFTXY_BLOCK/ ) {
                $ierr = 1;
                &print_error( "Invalid file_type [-$opt $val]",
                              $ierr );
                return( $ierr );
            }
            $$cmd_ref{$opt} = $val;
        }

        # help
        elsif( $opt =~ /^-+(help|h)$/ ) {
            $opt = "h";
            push( @{$$cmd_ref{command_line}}, "-$opt" );
            $$cmd_ref{$opt} = "true";
        }

        # (no)? flavors
        elsif( $opt =~ /^(-+)(no)?(inc|intp|or|pargs|pft|plot_orig|plotrun|plots|presult|scaled_r|status|superset_x|t0)$/ ){
            push( @{$$cmd_ref{command_line}}, "$opt" );
            $no_set = $2;
            $opt = $3;
            if( defined($no_set) ){
                $$cmd_ref{"no$opt"} = "true";
                undef($$cmd_ref{$opt});
            }
            else{
                $$cmd_ref{$opt} = "true";
                undef($$cmd_ref{"no$opt"});
            }
        }

        #....................
        #...-ds <datasets>...
        #....................
        elsif( $opt =~ /^-+($GDS|$GDS_SKIP|$GDS_SMOOTH|$GDS_NOSMOOTH|$GDS_SKIP_ALL_0|$GDS_NOSKIP_ALL_0|$GDS_SKIP_UNDEF|$GDS_NOSKIP_UNDEF|$GDS_FAILED|$GDS_NOFAILED|$GDS_NOSKIP)$/ ) {
            $opt = $1;
            if( ! @args ) {
                $ierr = 1;
                &print_error( "Value needed for option [-$opt].",
                              $ierr );
                return( $ierr );
            }
            $val = shift( @args );
            push( @{$$cmd_ref{command_line}}, "-$opt '$val'" );
            $val =~ s/^\s*//;
            $val =~ s/\s*$//;
            #...stuff into regexp (ds1|ds2|...|dsn)...
            @vals = split( /\s*,\s*/, $val );
            push( @{$$cmd_ref{"${opt}_orig"}}, @vals );
            # regexp allowed
            # grep( s/(\||\[|\]|\{|\}|\(|\)|\$|\@|\%|\*|\.)/\\$1/g, @vals );
            if( $#vals >= 0 ){
                $regexp = join( '|', @vals );
            }
            else{
                $regexp = ".+";
            }
            $$cmd_ref{$opt} .= "|$regexp";
        }

        # -ds_file
        elsif( $opt =~ /^-+(ds_file)$/ ){
            $opt = $1;
            if( ! @args ) {
                $ierr = 1;
                &print_error( "Value needed for option [-$opt].",
                              $ierr );
                return( $ierr );
            }
            $val = shift( @args );
            if( ! open( $fh_FILE, "$val" ) ){
                $ierr = 1;
                &print_error( "Cannot open file for option [$opt]:",
                              "  $val",
                              $ierr );
                return( $ierr );
            }

            # read in ds_file
            @lines = <$fh_FILE>;
            close( $fh_FILE );

            # remove leading/trailing whitespace
            grep( s/^\s+//, @lines );
            grep( s/\s+$//, @lines );

            # join lines with ',' and remove leading/trailing
            $val = join( ',', @lines );
            $val =~ s/\s*,\s*/,/g;
            $val =~ s/^,+//;
            $val =~ s/,+$//;

            # push back onto stack
            unshift( @args, $val );
            unshift( @args, "-ds" );

        } # -ds_file

        # flags for datasets with "no" option
        elsif( $opt =~ /^-+((no)?(last|last_only))$/ ){
            $opt_full = $1;
            $flag = $2;
            $opt = $3;
            if( ! @args ){
                $ierr = 1;
                &print_error( "Value needed for option [-$opt].",
                              $ierr );
                return( $ierr );
            }
            $val = shift( @args );
            push( @{$$cmd_ref{command_line}}, "-$opt_full '$val'" );
            # no values given for these
            if( $opt =~ /^(last|last_only)$/ ){
                $dss = $val;
                $val = "default";
            }
            else{
                if( $val =~ /^([^,]+),(.*)$/ ){
                    $dss = $2;
                    $val = $1;
                }
                else{
                    $dss = ".+";
                }
            }
            if( defined($flag) ){
                $flag = "-";
            }
            else{
                $flag = "+";
            }
            push(@{$$cmd_ref{$opt}{val}},  $val);
            push(@{$$cmd_ref{$opt}{dss}},  $dss);
            push(@{$$cmd_ref{$opt}{flag}}, $flag);
        }

        # --(no)?<opt>
        elsif( $opt =~ /^-+(no)?(unique_filenames)$/ ){
            $flag = $1;
            $opt = $2;
            if( defined($flag) ){
                undef( $$cmd_ref{$opt} );
            }
            else{
                $$cmd_ref{$opt} = "";
            }
        }

        #....................
        #...-v|fsets <num>...
        #....................
        elsif( $opt =~ /^-+(v|fsets)$/ ) {
            $opt = $1;
            if( ! @args ) {
                $ierr = 1;
                &print_error( "Value needed for option [-$opt].",
                              $ierr );
                return( $ierr );
            }
            $val = shift( @args );
            push( @{$$cmd_ref{command_line}}, "-$opt '$val'" );
            if( $val !~ /^[0-9]+$/ ) {
                $ierr = 1;
                &print_error( "Must give non-negative integer value for option [-$opt $val]",
                              $ierr );
                return( $ierr );
              }
            $$cmd_ref{$opt} = $val;
        }

        #.......................................
        #...-o_<file_type> <output data file>...
        #.......................................
        elsif( $opt =~ /^-+(o_(\S+))$/ ) {
            $opt = $1;
            if( ! @args ) {
                $ierr = 1;
                &print_error( "Value needed for option [-$opt].",
                              $ierr );
                return( $ierr );
            }
            $val = shift( @args );
            push( @{$$cmd_ref{command_line}}, "-$opt '$val'" );
            $$cmd_ref{$opt} = $val;
        }

        #.....................
        #...-arg <filename>...
        #.....................
        elsif( $opt =~ /^-+(arg)$/ ) {
            $opt = $1;
            if( ! @args ) {
                $ierr = 1;
                &print_error( "Value needed for option [-$opt].",
                              $ierr );
                return( $ierr );
            }
            $val = shift( @args );
            $ierr = &read_arg_file( $val, \@args, \@arg_files );
            if( $ierr ) {
                # silent
                $ierr = 0;
                #&print_error( "Failure reading argument file [-$opt $val].",
                #              $ierr );
            }
        }

        # --opt val
        elsif( $opt =~ /^-+(outdir|time_range|time_shift)$/ ){
            $opt = $1;
            if( ! @args ) {
                $ierr = 1;
                &print_error( "Value needed for option [-$opt].",
                              $ierr );
                return( $ierr );
            }
            $val = shift( @args );
            $$cmd_ref{$opt} = $val;
        }

        # unrecognized
        elsif( $opt =~ /^-/ ){
            $ierr = 1;
            &print_error( "Unrecognize option [$opt]", $ierr );
            return( $ierr );
        }

        #..............
        #...filename...
        #..............
        else {
            push( @{$$cmd_ref{command_line}}, "$opt" );
            push( @{$$cmd_ref{files}}, $opt );
        }
    }
    #..........................
    #...DONE: parse the args...
    #..........................

    #....................
    #...exclusive opts...
    #....................
    @opts = grep( /^($GFTKEYWORD|$GFTCTS|$GFTOXY|$GFTPOP|$GFTCTF|$GFTARES|$GFTGMV|$GFTTABLE|$GFTTABLE_X|$GFTTOKEN|$GFTTRACER|$GFTLINK|$GFTXY|$GFTXY_BLOCK)$/,
                  sort keys %{$cmd_ref} );
    if( $#opts >= 1 ) {
        $ierr = 1;
        &print_error( "The following options are exclusive:",
                      "[".join(" ", @opts)."]",
                      $ierr );
        return( $ierr );
    }

    # outdir
    if( ! defined($$cmd_ref{outdir}) ){
        $$cmd_ref{outdir} = ".";
    }
    # prepend output dir portion
    $CTS_DIFF_FILE_CMD      =~ s&^&$$cmd_ref{outdir}/&;
    $CTS_DIFF_FILE_DATA     =~ s&^&$$cmd_ref{outdir}/&;
    $CTS_DIFF_FILE_PDF      =~ s&^&$$cmd_ref{outdir}/&;
    $CTS_DIFF_FILE_PLOT_OUT =~ s&^&$$cmd_ref{outdir}/&;
    $CTS_DIFF_FILE_PRESULT  =~ s&^&$$cmd_ref{outdir}/&;
    $CTS_DIFF_FILE_PS       =~ s&^&$$cmd_ref{outdir}/&;

    # no files is help
    if( ! defined( $$cmd_ref{files} ) ){
        $$cmd_ref{h} = "";
    }

    #.................
    #...check fsets...
    #.................
    if( defined($$cmd_ref{files}) ) {
        $val1 = $#{$$cmd_ref{files}} + 1;
    }
    else {
        $val1 = 0;
    }
    $val2 = $$cmd_ref{fsets};
    if( defined( $val2 ) && $val2 > 0 && int( $val1/$val2 ) != $val1/$val2 ) {
        $ierr = 1;
        &print_error( "The number of files [$val1] must be",
                      "divisible by the file set size [-fsets $val2]",
                      $ierr );
        return( $ierr );
    }

    # clean up GDS GDS_SKIP
    foreach $opt ( $GDS, $GDS_FAILED, $GDS_NOFAILED, $GDS_SKIP, $GDS_NOSKIP, $GDS_SMOOTH, $GDS_NOSMOOTH, $GDS_SKIP_ALL_0, $GDS_NOSKIP_ALL_0, $GDS_SKIP_UNDEF, $GDS_NOSKIP_UNDEF ){
        if( defined( $$cmd_ref{$opt} ) ){
            $$cmd_ref{$opt} =~ s/^\|+//;
        }
    }

    # ds_failed --> presult
    if( defined( $$cmd_ref{ds_failed} ) ){
        $$cmd_ref{presult} = "";
    }

    # cannot set superset_x and either (no)intp
    # just check if used nointp
    if( defined($$cmd_ref{superset_x}) &&
        ! defined($$cmd_ref{intp}) ){
        $ierr = 1;
        &print_error( "Following args are mutually exclusive:",
                      "  superset_x",
                      "  (no)intp",
                      $ierr );
        return( $ierr );
    }

    # quiet if -v 0
    if( $$cmd_ref{v} == 0 ){
        undef( $$cmd_ref{presult} );
        undef( $$cmd_ref{pft} );
    }

    @{$$cmd_ref{arg_files}} = @arg_files;

    return( $ierr );
  }

#............................................
#...read_arg_file                         ...
#...  Little routine to read argument file...
#............................................
sub read_arg_file
  {
    my(
       $arg_file,
       $args_ref,
       $arg_files_ref,
      ) = @_;
    my(
       $dir, # directory to search
       $dir_check,
       $file, # actual file read in
       $ierr, # error ret val
       $line, # line of file
       @tokens, # tokens in file
      );
    $ierr = 0;

    # get $file
    $file = "";
    # pointing to one or contains a path
    if( $file !~ /\S/ ){
        if( $arg_file =~ m&/& || -f $arg_file ){
            $file = $arg_file;
        }
    }
    # from previous locations of arg files
    if( $file !~ /\S/ ){
        foreach $dir ( @CTS_ARG_FILE_DIRS ){
            if( -f "$dir/$arg_file" ){
                $file = "$dir/$arg_file";
                last;
            }
        }
    }
    # from relative location of checkout
    if( $file !~ /\S/ ){
        foreach $dir ( @CTS_ARG_FILE_DIRS ){
            $dir_check = "$dir/../../Test/Compare"; 
            if( -f "$dir_check/$arg_file" ){
                $file = "$dir_check/$arg_file";
                last;
            }
        }
    }
    # from path
    if( $file !~ /\S/ ){
        foreach $dir ( @INC ){
            if( -f "$dir/$arg_file" ){
                $file = "$dir/$arg_file";
                last;
            }
        }
    }
    # use arg_file
    if( $file !~ /\S/ ){
        $file = $arg_file;
    }

    # silent return since doing print below for arg file
    if( ! open( FILE, $file ) ){
        $ierr = 0;
        return( 1 );
    }
    push( @{$arg_files_ref}, $file );

    # add to list of dirs to search
    if( $file =~ m&/& ){
        ($dir = $file) =~ s&/[^/]+$&&;
        push( @CTS_ARG_FILE_DIRS, $dir );
    }

    undef( @tokens );
    while( $line=<FILE> )
      {
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        if( $line =~ /^\s*$/ ||
            $line =~ /^\s*\#/ )
          {
            next;
          }
        push( @tokens, split( /\s+/, $line ) );
        # print summary instead after
        # print "  $line\n";
      }
    if( @tokens )
      {
        unshift( @{$args_ref}, @tokens );
        # print summary instead after
        # print "\n";
      }
    close( FILE );
    return( $ierr );
  }

#............................................................................
#...Name
#...====
#... print_abs_rel_stats
#...
#...Purpose
#...=======
#... Print a few of the stats gotten from create_stats
#... Spacing tied to create_diff printing
#...
#...Arguments
#...=========
#... $title        Intent: in
#...               Perl type: scalar
#...               title of the stat line
#...
#... $print_header Intent: in
#...               Perl type: scalar
#...               0: no header
#...               1: header
#...
#... $stat_abs_ref Intent: out
#...               Perl type: reference to hash
#...               gotten from create_stats on absolute difference array
#...
#... $stat_rel_ref Intent: out
#...               Perl type: reference to hash
#...               gotten from create_stats on relative difference array
#...
#... $headers_printed_ref Intent: in
#...                      Perl type: reference to scalar
#...                      adds 1 to value if header printed.
#...
#...Program Flow
#...============
#... 1) print a few stats
#............................................................................
sub print_abs_rel_stats{
    my(
       $title,
       $stat_abs_ref,
       $stat_rel_ref
      ) = @_;
    my(
       $diff_flag,
       $num, # num diffs when printed
      );

    # diff_flag
    if( $$stat_rel_ref{$GNUMSTRUE} > 0 ){
        $diff_flag = "S";
    }
    elsif( $$stat_rel_ref{$GNUMTRUE} > 0 &&
           $$stat_abs_ref{$GNUMTRUE} > 0 ){
        $diff_flag = "B";
    }
    elsif( $$stat_abs_ref{$GNUMTRUE} > 0 ){
        $diff_flag = "A";
    }
    elsif( $$stat_rel_ref{$GNUMTRUE} > 0 ){
        $diff_flag = "R";
    }
    else{
        $diff_flag = "-";
    }

    $num = sprintf("%.2g/%.2g", $$stat_abs_ref{$GNUMTRUE}, $$stat_abs_ref{$GNUMALL} );
    if( $$stat_abs_ref{$GNUMNUMS} > 0 ){
        printf( "%1s %11.4e %11.4e %15s %s\n",
                $diff_flag,
                $$stat_abs_ref{$GMAXABS},
                $$stat_rel_ref{$GMAXABS},
                $num,
                $title,
            );
    }
    else{
        printf( "%1s %11s %11s %15s %s\n",
                $diff_flag,
                "-",
                "-",
                $num,
                $title,
            );
    }
}

#............................................................................
#...Name
#...====
#... print_gnuplot_data
#...
#...Purpose
#...=======
#... print a set of data obtained from read_file and possibly create_diff.
#... Updates gnuplot_info hash to be used in print_gnuplot_plots.
#...
#... Currently, the data is displayed as 1 variable per page with
#... 1 plot per diff type (diff types from ds_data).
#...   Title:   From title argument
#...   X-Label: From ds_data
#...   Y-Label: From ds_data
#...   Key:     From source argument
#...
#... A check is done to see if the $variable and $source have already been
#... processed with the %gnuplot_info.  If so, the routine returns.
#... So, change the $variable and $source name to print data.
#...
#...Arguments
#...=========
#... $ds_data_ref      Intent: in
#...                   Perl type: reference to array
#...                   Dataset data obtained from read_file with possible
#...                   calling of create_diff as well:
#...                     read_file -> %data
#...                     foreach $ds_name of %data
#...                       foreach $coord of $data{$ds_name}
#...                         create_diff $data{$ds_name}{$coord}{$GORG}[] ->
#...                                     $data{$ds_name}{$coord}{$GDIFF}{}[]
#...                         print_gnuplot_data with \%{$data{$ds_name}}
#...
#... $variable         Intent: in
#...                   Perl type: scalar
#...                   The same variable by different sources will be plotted
#...                   on the same plot.
#...                   The order of the variables is preserved.
#...
#... $source           Intent: in
#...                   Perl type: scalar
#...                   The same variable by different sources will be plotted
#...                   on the same plot.
#...                   The order of the sources is sorted.
#...                   This value will be used in the key.
#...
#... $title            Intent: in
#...                   Perl type: scalar
#...                   The title of the plot.  The title of the first source
#...                   will be used.
#...
#... $gnuplot_info_ref Intent: inout
#...                   Perl type: reference to hash
#...                   Contains info gnuplot will use to plot in run_gnuplot
#...                   routine.
#...
#...Program Flow
#...============
#... 1) print values
#... 2) store index and using info for gnuplot
#............................................................................
sub print_gnuplot_data
  {
    my(
       $ds_data_ref,
       $variable,
       $source,
       $title,
       $gnuplot_info_ref
      ) = @_;
    my(
       $column, # column
       $compare_group,
       $every,
       $file_base,
       $file_num,
       $ierr,
       $i, # loop var
       $label_x,
       $label_y,
       %labeld,
       $line, # line to print out
       $dtype, # diff type
       $num_vals, # number of values
       $len, # length of something
       $lena, # lengths in printing
       $lenb,
       $lenc,
       %points, # hash of y values of number of legal points
       $printed_block, # if printed the block at all
       $points_printed, # if legal points have been printed
       $title_short,
       $update_index, # if data has been printed - index needs updating
       $val, # a value
       $valid_x, # if the x coordinate is valid
       $xy, # if doing xy plot (otherwise just y values)
      );
    #..........
    #...init...
    #..........
    if( ! defined $$gnuplot_info_ref{data_file} )
      {
        $$gnuplot_info_ref{data_file} = $CTS_DIFF_FILE_DATA;
      }
    if( ! defined $$gnuplot_info_ref{num_sets} )
      {
        unlink( $$gnuplot_info_ref{data_file} );
        $$gnuplot_info_ref{num_sets} = 0;
      }
    undef( %points );

    #.................................
    #...return if already processed...
    #.................................
    if( defined( $$gnuplot_info_ref{processed}{$variable}{$source} ) )
      {
        return;
      }
    else
      {
        $$gnuplot_info_ref{processed}{$variable}{$source} = "";
      }
    #...................................
    #...check for correct ds_data_ref...
    #...................................
    $ierr = &check_format_ds_data( $ds_data_ref );
    if( $ierr )
      {
        $ierr = 0;
        &print_error( "Format error for ds_data", $ierr );
        $ierr = 1;
        return( $ierr );
      }
    #...............
    #...open file...
    #...............
    if( ! open( FILE, ">>$$gnuplot_info_ref{data_file}" ) )
      {
        $ierr = 1;
        &print_error( "Cannot open gnuplot data file [$$gnuplot_info_ref{data_file}]",
                      $ierr );
        exit( $ierr );
      }
    #......................
    #...get type of plot...
    #......................
    if( defined( $$ds_data_ref{$GCOORDX}{$GORG} ) )
      {
        $xy = 1;
      }
    else
      {
        $xy = 0;
      }
    #..........................
    #...get number of values...
    #..........................
    $num_vals = 0;
    if( defined( $$ds_data_ref{$GCOORDX}{$GORG} ) )
      {
        $len = $#{$$ds_data_ref{$GCOORDX}{$GORG}}+1;
        if( $len > $num_vals )
          {
            $num_vals = $len;
          }
      }
    if( defined( $$ds_data_ref{$GCOORDY}{$GORG} ) )
      {
        $len = $#{$$ds_data_ref{$GCOORDY}{$GORG}}+1;
        if( $len > $num_vals )
          {
            $num_vals = $len;
          }
      }
    foreach $dtype ( sort keys %{$$ds_data_ref{$GCOORDY}{$GDIFF}} )
      {
        $len = $#{$$ds_data_ref{$GCOORDY}{$GDIFF}{$dtype}} + 1;
        if( $len > $num_vals )
          {
            $num_vals = $len;
          }
      }
    if( $num_vals == 0 )
      {
        return;
      }
    #..................
    #...print header...
    #..................
    $lena = 15;
    $lenb = $lena + 7;
    $lenc = $lena + 4;

    if( $xy ){
        ( $label_x = $$ds_data_ref{$GCOORDX}{$GNAME} ) =~ s/\s+/_/g;
    }
    else{
        $label_x = " ";
    }
    ( $label_y = $$ds_data_ref{$GCOORDY}{$GNAME} ) =~ s/\s+/_/g;
    undef( %labeld );
    foreach $dtype ( sort keys %{$$ds_data_ref{$GCOORDY}{$GDIFF}} ){
        ( $labeld{$dtype} = $dtype ) =~ s/ +/_/g;
    }
    if( $source =~ /^cmp=\s*(\d+):\s*(\d+):(\S+)$/ ){
        $compare_group = $1;
        $file_num      = $2;
        $file_base     = $3;
    }
    else{
        # should never hit this...but just in case
        $file_base = $source;
    }

    $line = "";
    $line .= "# cts_diff.data\n";
    $line .= sprintf( "#   %-12s = %s\n", "index",     $$gnuplot_info_ref{num_sets} );
    $line .= sprintf( "#   %-12s = %s\n", "file_base", $file_base );
    $line .= sprintf( "#   %-12s = %s\n", "y",         $label_y );
    $line .= sprintf( "#   %-12s = %s\n", "x",         $label_x );
    $line .= sprintf( "#   %-12s = %s\n", "title",     $title );
    $line .= sprintf( "#   %-12s = %s\n", "num_vals",  $num_vals );
    $line .= sprintf( "#   %-12s = %s\n", "variable",  $variable );
    $line .= sprintf( "#   %-12s = %s\n", "source",    $source );
    $i = 0;
    foreach $dtype ( sort keys %{$$ds_data_ref{$GCOORDY}{$GDIFF}} ){
        $i++;
        $line .= sprintf( "#   %-12s = %s\n", "col:$i", $labeld{$dtype} );
    }

    $line .= "# data:\n";
    ($title_short = $title) =~ s/^.*{ds}//;
    $title_short =~ s/_/\\_/g;
    $line .= "# ";
    if( $xy ){
        $line .= sprintf( "%${lenc}s($GCOORDX)", $label_x );
    }
    else{
        $line .= sprintf( "%${lenb}s", $label_x );
    }
    $line .= sprintf( " %${lenc}s($GCOORDY)", $label_y );
    foreach $dtype ( sort keys %{$$ds_data_ref{$GCOORDY}{$GDIFF}} ){
        $line .= sprintf( " %${lenc}s($GCOORDY)", $labeld{$dtype} );
    }
    $line .= "\n";
    print FILE $line;
    #................
    #...print data...
    #................
    $update_index = 0;
    $points{$GORG} = 0;
    foreach $dtype ( sort keys %{$$ds_data_ref{$GCOORDY}{$GDIFF}} )
      {
        $points{$GDIFF}{$dtype} = 0;
      }
    for( $i = 0; $i < $num_vals; $i++ )
      {
        $line = "  ";
        #.......
        #...x...
        #.......
        $valid_x = 1;
        if( $xy )
          {
            $val = $$ds_data_ref{$GCOORDX}{$GORG}[$i];
            if( defined( $val ) && $val =~ /^$GNUMBER_REGEXP$/ &&
                abs( $val ) < $GSKIP )
              {
                $line .= sprintf( "%${lenb}.${lena}e", $val );
              }
            else
              {
                $valid_x = 0;
                $val = "-";
                $line .= sprintf( "%${lenb}s", $val );
              }
          }
        else
          {
            $line .= sprintf( "%${lenb}s", " " );
          }
        #.......
        #...y...
        #......
        $val = $$ds_data_ref{$GCOORDY}{$GORG}[$i];
        if( defined( $val ) && $val =~ /^$GNUMBER_REGEXP$/ &&
            abs( $val ) < $GSKIP )
          {
            if( $valid_x )
              {
                $points{$GORG} += 1;
              }
            $line .= sprintf( " %${lenb}.${lena}e", $val );
          }
        else
          {
            $val = "-";
            $line .= sprintf( " %${lenb}s", $val );
          }
        #............
        #...y diff...
        #............
        foreach $dtype ( sort keys %{$$ds_data_ref{$GCOORDY}{$GDIFF}} ) {
            $val = $$ds_data_ref{$GCOORDY}{$GDIFF}{$dtype}[$i];
            if( defined( $val ) && $val =~ /^$GNUMBER_REGEXP$/ &&
                abs( $val ) < $GSKIP ) {
                $line .= sprintf( " %${lenb}.${lena}e", $val );
                if( $valid_x ) {
                    $points{$GDIFF}{$dtype} += 1;
                }
            }
            else {
                if( $dtype eq "type" ){
                    # print the type as is
                }
                else{
                    $val = "-";
                }
                $line .= sprintf( " %${lenb}s", $val );
            }
        }
        $line .= "\n";
        $printed_block = "";
        print FILE $line;
      }
    $points_printed = $points{$GORG};
    foreach $dtype ( sort keys %{$$ds_data_ref{$GCOORDY}{$GDIFF}} )
      {
        $points_printed += $points{$GDIFF}{$dtype};
      }
    #................
    #...close file...
    #................
    print FILE "\n\n";
    close( FILE );
    #...........................
    #...store additional data...
    #...........................

    #...............................................
    #...save order of source, variable, and dtype...
    #...............................................
    if( ! defined $$gnuplot_info_ref{sources_def}{$source} )
      {
        push( @{$$gnuplot_info_ref{sources}}, $source );
        $$gnuplot_info_ref{sources_def}{$source} = "";
      }
    if( ! defined $$gnuplot_info_ref{variables_def}{$variable} )
      {
        push( @{$$gnuplot_info_ref{variables}}, $variable );
        $$gnuplot_info_ref{variables_def}{$variable} = "";
      }
    foreach $dtype ( sort keys %{$$ds_data_ref{$GCOORDY}{$GDIFF}} )
      {
        if( ! defined $$gnuplot_info_ref{dtypes_def}{$dtype} )
          {
            push( @{$$gnuplot_info_ref{dtypes}}, $dtype );
            $$gnuplot_info_ref{dtypes_def}{$dtype} = "";
          }
      }

    #................................................
    #...line type - unique and the same per source...
    #................................................
    if( ! defined( $$gnuplot_info_ref{lt}{count}) ) {
        $$gnuplot_info_ref{lt}{count} = 0;
    }
    if( ! defined($$gnuplot_info_ref{lt}{source}{$source}) ) {
        $$gnuplot_info_ref{lt}{source}{$source} =
            $$gnuplot_info_ref{lt}{count} % 64 + 1;
        $$gnuplot_info_ref{lt}{count}++;
    }

    #.......................................................
    #...gnuplot variables - only if actual points printed...
    #.......................................................
    if( defined( $printed_block ) )
      {
        #..........
        #...init...
        #..........
        $$gnuplot_info_ref{index}{$variable}{$source} =
          $$gnuplot_info_ref{num_sets};
        $column = 0;
        $$gnuplot_info_ref{title}{$variable}{$source} = $title;
        #.......
        #...x...
        #.......
        if( $xy )
          {
            $column++;
            $$gnuplot_info_ref{using}{$variable}{$source}{$GCOORDX}{$GORG} =
              "$column";
            $$gnuplot_info_ref{label}{$variable}{$source}{$GCOORDX}{$GORG} =
              $$ds_data_ref{$GCOORDX}{$GNAME};
          }
        #.......
        #...y...
        #.......
        $column++;
        $$gnuplot_info_ref{numvalid}{$variable}{$source}{$GCOORDY}{$GORG} =
            $points{$GORG};
        $$gnuplot_info_ref{using}{$variable}{$source}{$GCOORDY}{$GORG} =
            "$column";
        $$gnuplot_info_ref{label}{$variable}{$source}{$GCOORDY}{$GORG} =
            $$ds_data_ref{$GCOORDY}{$GNAME};
        $every = POSIX::ceil($points{$GORG}/$GLINESPOINTS_MAX);
        if( $every == 0 ){
            $every = 1;
        }
        $$gnuplot_info_ref{every}{$variable}{$source}{$GCOORDY}{$GORG} =
            $every;
        #............
        #...y diff...
        #............
        foreach $dtype ( sort keys %{$$ds_data_ref{$GCOORDY}{$GDIFF}} ) {
            $$gnuplot_info_ref{numvalid}{$variable}{$source}{$GCOORDY}{$GDIFF}{$dtype} =
                $points{$GDIFF}{$dtype};
            $column++;
            $$gnuplot_info_ref{using}{$variable}{$source}{$GCOORDY}{$GDIFF}{$dtype} =
                "$column";
            $$gnuplot_info_ref{label}{$variable}{$source}{$GCOORDY}{$GDIFF}{$dtype} =
                "$$ds_data_ref{$GCOORDY}{$GNAME} [$dtype]";
            $every = POSIX::ceil($points{$GDIFF}{$dtype}/$GLINESPOINTS_MAX);
            if( $every == 0 ){
                $every = 1;
            }
            $$gnuplot_info_ref{every}{$variable}{$source}{$GCOORDY}{$GDIFF}{$dtype} =
                $every;
        }
      }
    $$gnuplot_info_ref{num_sets}++;
  }

#............................................................................
#...Name
#...====
#... read_file
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: in
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              List of datasets in order of appearance:
#...                $$data_ref{$GDATASETNAMES}[] = array of dataset names
#...              If X data exists (eg for xy file types):
#...                $$data_ref{<dataset name>}{$GCOORDX}{$GNAME}  = X name
#...                $$data_ref{<dataset name>}{$GCOORDX}{$GORG}[] = X data
#...              Y data (always):
#...                $$data_ref{<dataset name>}{$GCOORDY}{$GNAME}  = Y name
#...                $$data_ref{<dataset name>}{$GCOORDY}{$GORG}[] = Y data
#...              Corresponding <dataset name> arrays eventually will be
#...              diffed using the specific tolerances given for the $GNAME
#...              value.
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) determine file type and pass to correct reading routine
#............................................................................
sub read_file
  {
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
      ) = @_;
    my(
       $chop,
       $do_last,
       $do_last_only,
       $ds_name_last,
       $ds_noskip,
       $ds_nosmooth,
       $ds_regexp,
       $field,
       @fields_new, # array of dataset field names
       $file_type, # type of file
       $i,
       $ierr, # error return value
       $j,
       $non_0,
       %non_empty,
       $num,
       $num_smooths,
       $num_smooths_max,
       $tmin,
       $tmp_index,
       $tmp_val_x,
       $tmp_val_x_old,
       @tmp_x,
       @tmp_y,
       $tol,
       %tols,
       $tthis,
       $val,
       @x_keep,
       $y_ref,
      );
    #..........
    #...init...
    #..........
    $ierr = 0;
    #...................
    #...get file type...
    #...................
    $file_type = $$cmd_ref{ft};
    if( ! defined( $file_type ) || $file_name eq "dummy" ) {
        $ierr = cts_diff_util::get_file_type( $file_name, \$file_type );
        if( $ierr != 0 ) {
            $ierr = 1;
            &print_error( "Error getting type of file",
                          $ierr );
            return( $ierr );
        }
    }
    if( defined($$cmd_ref{pft}) ){
        printf( "File Type: $file_type [$file_name]\n" );
    }

    #..................................
    #...read file based on file type...
    #..................................
    if( $file_type eq "$GFTXY" ) {
        $ierr = &read_file_xy( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type eq "$GFTXY_BLOCK" ) {
        $ierr = &read_file_xy_block( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type eq "$GFTTECPLOT" ) {
        $ierr = &read_file_tecplot( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type eq "$GFTCTS" ) {
        $ierr = &read_file_cts( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type eq "$GFTGMV" ) {
        $ierr = &read_file_gmv( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type eq "$GFTDUMMY" ) {
        $ierr = &read_file_dummy( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type eq "$GFTTABLE" || $file_type eq "$GFTTABLE_X" ) {
        $ierr = &read_file_table_x( $file_name, $cmd_ref, $data_ref, $file_type );
    }
    elsif( $file_type eq "$GFTKEYWORD" ) {
        $ierr = &read_file_keyword( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type eq "$GFTOXY" ) {
        $ierr = &read_file_oxy( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type eq "$GFTPLOT_OUTPUT" ) {
        $ierr = &read_file_plot_output( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type eq "$GFTPOP" ) {
        $ierr = &read_file_pop( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type =~ /$GFTCTF(:\S+)?/ ) {
        $ierr = &read_file_ctf( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type eq "$GFTARES" ) {
        $ierr = &read_file_ares( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type eq "$GFTTRACER" ) {
        $ierr = &read_file_tracer( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type eq "$GFTLINK" ) {
        $ierr = &read_file_link( $file_name, $cmd_ref, $data_ref );
    }
    elsif( $file_type eq "$GFTTOKEN" ) {
        $ierr = &read_file_token( $file_name, $cmd_ref, $data_ref );
    }
    else{
        $ierr = 1;
        &print_error( "Invalid file type [$file_type]",
                      $ierr );
        return( $ierr );
    }
    if( $ierr ) {
        &print_error( "Error in read_file_<type> = $file_type",
                      $ierr );
        return( $ierr );
    }

    # pre-return if no data found (before pruning)
    # do now so do not have to worry about checking that $data_ref{$GDATA} exists
    if( ! defined( $$data_ref{$GDATA} ) &&
        ! defined( $$cmd_ref{ds_base} ) &&
        ! defined( $$cmd_ref{ds_cmp} ) ){
        print "  WARNING: FAILED: NO DATA FROM FILE: $file_name\n";
        return( $ierr );
    }

    # generic skip of datasets
    # would be faster to do before reading, but easier here
    if( defined($$cmd_ref{$GDS_SKIP}) ){
        if( defined( $$cmd_ref{$GDS_NOSKIP} ) ){
            $ds_noskip = $$cmd_ref{$GDS_NOSKIP};
        }
        else{
            $ds_noskip = ""
        }
        undef( @fields_new );
        foreach $field (@{$$data_ref{$GDATASET_NAMES}}) {
            if( $field =~ /^($$cmd_ref{$GDS_SKIP})$/ &&
                $field !~ /^($ds_noskip)$/){
                delete($$data_ref{$GDATA}{$field});
            }
            else{
                push( @fields_new, $field );
            }
        }
        @{$$data_ref{$GDATASET_NAMES}} = @fields_new;
    }

    # ds_skip_all_0
    if( defined($$cmd_ref{$GDS_SKIP_ALL_0}) ){
        if( defined( $$cmd_ref{$GDS_NOSKIP_ALL_0} ) ){
            $ds_noskip = $$cmd_ref{$GDS_NOSKIP_ALL_0};
        }
        else{
            $ds_noskip = ""
        }
        @fields_new = keys %{$$data_ref{$GDATA}};
        foreach $field ( @fields_new ) {
            if( $field =~ /^($$cmd_ref{$GDS_SKIP_ALL_0})$/ &&
                $field !~ /^($ds_noskip)$/){
                # check if all the value are 0
                undef( $non_0 );
                $y_ref = \@{$$data_ref{$GDATA}{$field}{Y}{Orig}};
                $num = $#{$y_ref};
                for( $i = 0; $i <= $num; $i++ ){
                    if( defined( $$y_ref[$i] ) && $$y_ref[$i] =~ /${GNUMBER_REGEXP}/ ){
                        if( $$y_ref[$i] != 0 ){
                            $non_0 = "";
                            last;
                        }
                    }
                }
                if( ! defined( $non_0 ) ){
                    delete($$data_ref{$GDATA}{$field});
                }
            }
        }
        @{$$data_ref{$GDATASET_NAMES}} = sort keys %{$$data_ref{$GDATA}};
    }

    # generic include of datasets
    if( defined($$cmd_ref{$GDS}) ){
        $ds_noskip = $$cmd_ref{$GDS};
        undef( @fields_new );
        foreach $field (@{$$data_ref{$GDATASET_NAMES}}) {
            if( $field !~ /^($ds_noskip)$/ ){
                delete($$data_ref{$GDATA}{$field});
            }
            else{
                push( @fields_new, $field );
            }
        }
        @{$$data_ref{$GDATASET_NAMES}} = @fields_new;
    }

    # prune cycle if given eap_lineout
    #   cycle and eap_lineout_cycle are dummy vars not used
    if( defined($$data_ref{$GDATASET_NAMES}) &&
        defined($$data_ref{$GDATA}{eap_lineout_dummy}) ){
        undef( @fields_new );
        foreach $field (@{$$data_ref{$GDATASET_NAMES}}) {
            if( $field =~ /^(cycle|eap_lineout_dummy)$/ ){
                delete($$data_ref{$GDATA}{$field});
            }
            else{
                push( @fields_new, $field );
            }
        }
        @{$$data_ref{$GDATASET_NAMES}} = @fields_new;
    }

    # another warning if no data
    if( $#{$$data_ref{$GDATASET_NAMES}} < 0 ){
        print "  WARNING: NO DATA FROM FILE: $file_name\n";
        return( $ierr );
    }

    # val_skip : replace values with undef
    if( defined($$cmd_ref{$GVAL_SKIP}) ){
        foreach $field (@{$$data_ref{$GDATASET_NAMES}}) {
            $j = 0;
            foreach $ds_regexp ( @{$$cmd_ref{$GVAL_SKIP}{$GTOL_DS}} ){
                if( $field =~ /^($ds_regexp)$/ ){
                    undef( %tols );
                    &get_tols( $cmd_ref, $field, \%tols );
                    $tol = $tols{$GVAL_SKIP};
                    $y_ref = \@{$$data_ref{$GDATA}{$field}{Y}{Orig}};
                    $num = $#{$y_ref};
                    for( $i = 0; $i <= $num; $i++ ){
                        if( defined( $$y_ref[$i] ) && $$y_ref[$i] =~ /${GNUMBER_REGEXP}/ ){
                            if( abs($$y_ref[$i]) >= $tol ){
                                undef( $$y_ref[$i] );
                            }
                        }
                    }
                }
                $j++;
            }
        }
    }

    # prune out any dataset that does not have values
    undef( %non_empty );
    foreach $field (@{$$data_ref{$GDATASET_NAMES}}) {
        $y_ref = \@{$$data_ref{$GDATA}{$field}{Y}{Orig}};
        foreach $val ( @{$y_ref} ){
            if( defined( $val ) &&
                $val ne "-" ){
                $non_empty{$field} = "";
                last;
            }
        }
    }
    if( %non_empty ){
        foreach $field (@{$$data_ref{$GDATASET_NAMES}}) {
            if( ! defined( $non_empty{$field} ) ){
                delete $$data_ref{$GDATA}{$field};
            }
        }
        @{$$data_ref{$GDATASET_NAMES}} =
            sort keys %{$$data_ref{$GDATA}};
    }
    
    # force first time to be 0 if requested
    if( defined( $$cmd_ref{t0} ) ){

        # get tmin
        $tmin = 1e99;
        foreach $field ( keys %{$$data_ref{$GDATA}} ){
            $tthis = $$data_ref{$GDATA}{$field}{X}{Orig}[0];
            if( $tmin > $tthis ){
                $tmin = $tthis;
            }
        }

        # subtract out tmin
        foreach $field ( keys %{$$data_ref{$GDATA}} ){
            $num = $#{$$data_ref{$GDATA}{$field}{X}{Orig}};
            for( $i = 0; $i <= $num; $i++ ){
                $$data_ref{$GDATA}{$field}{X}{Orig}[$i] -= $tmin;
            }
        }

    }

    # force increasing X if requested
    if( defined($$cmd_ref{inc}) ){
        foreach $field ( keys %{$$data_ref{$GDATA}} ){
            $num = $#{$$data_ref{$GDATA}{$field}{X}{Orig}};
            undef( @tmp_x );
            undef( @tmp_y );
            $tmp_val_x_old = $$data_ref{$GDATA}{$field}{X}{Orig}[0];
            $tmp_x[0] = $tmp_val_x_old;
            $tmp_y[0] = $$data_ref{$GDATA}{$field}{Y}{Orig}[0];
            $tmp_index = 0;
            for( $i = 1; $i <= $num; $i++ ){
                $tmp_val_x = $$data_ref{$GDATA}{$field}{X}{Orig}[$i];
                if( $tmp_val_x >= $tmp_val_x_old ){
                    if( $tmp_val_x > $tmp_val_x_old ){
                        $tmp_index++;
                    }
                    $tmp_val_x_old = $tmp_val_x;
                }
                else{
                    for( $j = $tmp_index; $j >= 0; $j-- ){
                        if( $tmp_x[$j] < $tmp_val_x ){
                            $j++;
                            last;
                        }
                    }
                    $tmp_index = $j;
                }
                $tmp_x[$tmp_index] = $tmp_val_x;
                $tmp_y[$tmp_index] = $$data_ref{$GDATA}{$field}{Y}{Orig}[$i];
            }
            @{$$data_ref{$GDATA}{$field}{X}{Orig}} = @tmp_x;
            @{$$data_ref{$GDATA}{$field}{Y}{Orig}} = @tmp_y;
        }
    }

    # if doing last/last_only, create those now (just last point with name+:ctslast)
    # do before smoothing and after skipping
    foreach $field ( keys %{$$data_ref{$GDATA}} ){
        $do_last = &cts_get_val( $field, \%{$$cmd_ref{"last"}} );
        $do_last_only = &cts_get_val( $field, \%{$$cmd_ref{"last_only"}} );
        if( defined($do_last) || defined($do_last_only)){
            # names
            $ds_name_last = "${field}:ctslast";
            $$data_ref{$GDATA}{$ds_name_last}{$GCOORDX}{Name} =
                $$data_ref{$GDATA}{$field}{$GCOORDX}{Name};
            $$data_ref{$GDATA}{$ds_name_last}{$GCOORDY}{Name} =
                $$data_ref{$GDATA}{$field}{$GCOORDY}{Name};
            # data (just last point)
            $$data_ref{$GDATA}{$ds_name_last}{$GCOORDX}{Orig}[0] =
                $$data_ref{$GDATA}{$field}{$GCOORDX}{Orig}[-1];
            $$data_ref{$GDATA}{$ds_name_last}{$GCOORDY}{Orig}[0] =
                $$data_ref{$GDATA}{$field}{$GCOORDY}{Orig}[-1];
            # add to list of datasets
            push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name_last );
        }
    }

    # generic smoothing of datasets
    # currently smooths once with no special points.
    # could run smooth twice to preserve min/maxs...but do not now
    if( defined($$cmd_ref{$GDS_SMOOTH}) ){
        if( defined( $$cmd_ref{$GDS_NOSMOOTH} ) ){
            $ds_nosmooth = $$cmd_ref{$GDS_NOSMOOTH};
        }
        else{
            $ds_nosmooth = ""
        }
        $num_smooths_max = 0;
        foreach $field (@{$$data_ref{$GDATASET_NAMES}}) {
            if( $field =~ /^($$cmd_ref{$GDS_SMOOTH})$/ &&
                $field !~ /^($ds_nosmooth)$/){
                $num_smooths_max++;
            }
        }
        if( $num_smooths_max > 0 ){
            print "  Smoothing:\n    ";
        }
        $num_smooths = 0;
        foreach $field (@{$$data_ref{$GDATASET_NAMES}}) {
            if( $field =~ /^($$cmd_ref{$GDS_SMOOTH})$/ &&
                $field !~ /^($ds_nosmooth)$/){
                $num_smooths++;
                &status_bar( $num_smooths, $num_smooths_max );
                @x_keep = (-1); # do not keep any points - just get general shape
                # if you are smoothing data, only doing approximate diffs
                # so bump up NUM_SMOOTHS and/or NOISE
                &my_smooth(X=>$$data_ref{$GDATA}{$field}{X}{Orig},
                           Y=>$$data_ref{$GDATA}{$field}{Y}{Orig},
                           X_KEEP=>\@x_keep,
                           VERBOSE=>undef,
                           SPACING=>"  ",
                           NOISE=>.05);
                # After smoothing, remove head/tail points (since those have
                # kept their original values) and adjacent points (since they
                # have been smoothed based on head/tail) and diffs might be large.
                # If at least some number of points total, chop 2.
                if( $#{$$data_ref{$GDATA}{$field}{X}{Orig}} > 15 ){
                    $chop = 2;
                }
                # if not some min points, then at least chop 1
                else{
                    $chop = 1;
                }
                # X
                for( $i = 1; $i < $chop; $i++ ){
                    pop(   @{$$data_ref{$GDATA}{$field}{X}{Orig}} );
                    shift( @{$$data_ref{$GDATA}{$field}{X}{Orig}} );
                }
                # Y
                for( $i = 1; $i < $chop; $i++ ){
                    pop(   @{$$data_ref{$GDATA}{$field}{Y}{Orig}} );
                    shift( @{$$data_ref{$GDATA}{$field}{Y}{Orig}} );
                }
            }
        }
    }

    #...........................
    #...check for consistency...
    #...........................
    $ierr = &check_format_data( $data_ref );
    return( $ierr );
  }

########################################################################
# use ctf_read to parse file (cycle/time/field)
sub read_file_ctf {
    my(
        $file_name,
        $cmd_ref,
        $data_ref,
        ) = @_;
    my(
        $field,
        @files,
        $ft,
        $i,
        $ierr,
        $time,
        $val,
        %vals,
        $verbose,
        );
    $ierr = 0;
    
    @files = ($file_name);
    
    if( $$cmd_ref{v} > 0 ){
        $verbose = "  ";
    }
    
    if( defined( $$cmd_ref{ft} ) &&
        $$cmd_ref{ft} =~ /$GFTCTF:(\S+)/  ){
        $ft = $1;
    }
    &ctf_read( FILES=>\@files, VALS=>\%vals, VERBOSE=>$verbose, TYPE=>\$ft,
               CMD=>$cmd_ref );
    # copy into data_ref
    foreach $field ( keys %vals ){
        # only pull in fields with numbers in them for now, might
        # want to expand that later.
        # If it starts with a "-", that might be a tracer field with
        # valid values later...
        $val = $vals{$field}{val}[0];
        if( ! defined( $val ) ){
            $val = "-";
        }
        if( $val =~ /^$GNUMBER_REGEXP$/ || $val eq "-" ){
            push( @{$$data_ref{$GDATASET_NAMES}}, $field );
            $$data_ref{$GDATA}{$field}{$GCOORDX}{$GNAME}   = "time";
            $$data_ref{$GDATA}{$field}{$GCOORDY}{$GNAME}   = $field;
            $i = 0;
            foreach $time ( @{$vals{$field}{time}} ) {
                # some data might not have a time field
                # might want to put in some logic to do this
                # as cycle data...dunno...
                $val = $vals{$field}{val}[$i];
                if( defined($time) && $time ne "-" ){
                    push( @{$$data_ref{$GDATA}{$field}{$GCOORDX}{$GORG}},
                          $time );
                    push( @{$$data_ref{$GDATA}{$field}{$GCOORDY}{$GORG}},
                          $val );
                }
                $i++;
            }
        }
    }
    return( $ierr );
}

#............................................................................
#...Name
#...====
#... read_file_ares
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) stuff the specific lines into %data
#............................................................................
sub read_file_ares
  {
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
      ) = @_;
    my(
       $ds_name_full, # corresponding arrays with this name are diffed
       $ds_name_tol,  # dataset name used for diff tolerances
       $ierr,         # error return value
       $line,         # line of file
       $title,
       @tokens,       # split on whitespace of $line
       $type,         # used in skipping and naming dataset
      );
    $ierr = 0;
    $title = sprintf( "cycle %5d", 0 );
    #...............
    #...open file...
    #...............
    if( ! open( FILE, "$file_name" ) )
      {
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
      }
    #........................
    #...look at every line...
    #........................
    while( $line=<FILE> )
      {
        #..................
        #... result line...
        #..................
        if( $line =~
            /
            ^\s*                    # start with possible whitespace
            (\S+)\s+                # test
            (DIFF|FAILED|PASSED)\s+ # test results
            (P-[0-9]+),\s+          # P field,
            (D-[0-9]+),\s+          # D field,
            (F-[0-9]+)\s+           # F field
            $/x )
          {
            $type = $1;
            @tokens = ($2, $3, $4, $5);
            #............................................
            #...skip if not interested in this dataset...
            #............................................
            if( defined( $$cmd_ref{$GDS} ) &&
                $type !~ /^($$cmd_ref{$GDS})$/ )
              {
                next;
              }
            $ds_name_tol  = "$type";
            $ds_name_full = "$ds_name_tol";
            if( ! defined( $$data_ref{$GDATA}{$ds_name_full}) )
              {
                push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name_full );
                $$data_ref{$GDATA}{$ds_name_full}{$GCOORDY}{$GNAME} =
                  $ds_name_tol;
              }
            push( @{$$data_ref{$GDATA}{$ds_name_full}{$GCOORDY}{$GORG}},
                  @tokens );
          }
      }
    #........................
    #...look at every line...
    #........................
    close( FILE );
    return( $ierr );
  }

#............................................................................
#...Name
#...====
#... read_file_cts
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) get to start of data
#... 2) repeat:
#... 2.1) get dataset name
#... 2.2) get coordinate name(s)
#... 2.3) stuff values into dataset
#............................................................................
sub read_file_cts
  {
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
      ) = @_;
    my(
       $coord,        # general  name of a coordinate
       $coord_name,   # specific name of a coordinate
       @coords,       # the general names
       $copy,         # copy number for unique ds_name
       $ds_name,      # dataset name
       $ds_name_orig, # original dataset name (if needed to create new one)
       $i,            # loop variable
       $ierr,         # error return value
       $line,         # line of file
       $line_num,     # line of file
       @tokens,       # split on whitespace of $line
      );
    $ierr = 0;
    #...............
    #...open file...
    #...............
    if( ! open( FILE, "$file_name" ) )
      {
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
      }
    #...............................
    #...get passed first cts line...
    #...............................
    $line=<FILE>;
    #......................
    #...read in datasets...
    #......................
    $ds_name = "";
    $line_num = 1;
    while( $line=<FILE> )
      {
        $line_num++;
        #................
        #...blank line...
        #................
        if( $line !~ /\S/ )
          {
            next;
          }
        #.................
        #...new dataset...
        #.................
        if( $line =~
            /
            ^\#\s*Dataset\s*Name:\s* # "Dataset Name:"
            (\S.*?)                  # dataset name
            \s+$                     # at least return whitespace
            /x )
          {
            $ds_name = $1;
            undef( @coords );
            #............................................
            #...skip if not interested in this dataset...
            #............................................
            if( defined( $$cmd_ref{$GDS} ) &&
                $ds_name !~ /^($$cmd_ref{$GDS})$/ )
              {
                $ds_name = "";
                next;
              }
            #.....................
            #...initialize data...
            #.....................
            if( $ds_name =~ /\S/ )
              {
                #..........................................
                #...create unique dataset name if needed...
                #..........................................
                if( defined( $$data_ref{$GDATA}{$ds_name} ) )
                  {
                    $copy = 1;
                    $ds_name_orig = $ds_name;
                    while( 1 == 1 )
                      {
                        $ds_name = sprintf( "%s $GCOPY_FORMAT",
                                            $ds_name_orig, $copy );
                        if( !defined( $$data_ref{$GDATA}{$ds_name} ) )
                          {
                            last;
                          }
                        $copy++;
                      }
                  }
                push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
              }
          }
        #.....................
        #...coordinate name...
        #.....................
        elsif( $ds_name =~ /\S/ &&
               $line =~
               /
               ^\#\s*Coord\s*Name\s* # "Coord Name:"
               (\S+):\               # coord name general:
               (\S.*?)               # coord name specific
               \s+$                  # at least return whitespace
               /x )
          {
            $coord      = $1;
            $coord_name = $2;
            push( @coords, $coord );
            $$data_ref{$GDATA}{$ds_name}{$coord}{$GNAME} = $coord_name;
          }
        #..........................................
        #...skip other lines starting with pound...
        #..........................................
        elsif( $line =~ /^\#/ )
          {
          }
        #...............
        #...data line...
        #...............
        elsif( $ds_name =~ /\S/ )
          {
            $line =~ s/^\s*(\S.*?)\s*$/$1/;
            @tokens = split( /\s+/, $line );
            if( $#tokens != $#coords )
              {
                $ierr = 1;
                &print_error( "Mismatch in number of values/coordinates",
                              "Coords: ".join(', ', @coords),
                              "Values: ".join(', ', @tokens),
                              "File: [$file_name:$line_num]",
                              $ierr );
                return( $ierr );
              }
            for( $i = 0; $i <= $#tokens; $i++ )
              {
                push( @{$$data_ref{$GDATA}{$ds_name}{$coords[$i]}{$GORG}},
                      $tokens[$i] );
              }
          }
        #.....................
        #...DONE: data line...
        #.....................
      }
    #............................
    #...DONE: read in datasets...
    #............................
    close( FILE );
    return( $ierr );
  }

########################################################################
# no file there
sub read_file_dummy {
    my(
        $file_name,
        $cmd_ref,
        $data_ref,
        ) = @_;
    my(
        $ierr,
        );

    # get rid of perl_standardize.pl warnings
    $file_name = $file_name;
    $cmd_ref   = $cmd_ref;
    $data_ref  = $data_ref;

    $ierr = 0;
    return( $ierr );
}

#............................................................................
#...Name
#...====
#... read_file_keyword
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) find a keyword line and stuff it into data.
#............................................................................
sub read_file_keyword
  {
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
      ) = @_;
    my(
       $ds_name,  # dataset name
       $ierr,     # error return value
       $index,    # index of keyword value
       $line,     # line of file
       $val,      # value
      );
    $ierr = 0;
    #...............
    #...open file...
    #...............
    if( ! open( FILE, "$file_name" ) )
      {
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
      }
    #........................
    #...look at every line...
    #........................
    while( $line=<FILE> )
      {
        if( $line =~
            /
            ^\s*(\S+)    # dataset name
            \s*=\s*      # =
            (\S+)\s*$    # value
            /x )
          {
            $ds_name = $1;
            ($val = $2) =~ s/(\d)([+-]\d)/$1e$2/;
            #............................................
            #...skip if not interested in this dataset...
            #............................................
            if( defined( $$cmd_ref{$GDS} ) &&
                $ds_name !~ /^($$cmd_ref{$GDS})$/ )
              {
                next;
              }
            #...........................................
            #...init data if this is first occurrance...
            #...........................................
            if( ! defined($$data_ref{$GDATA}{$ds_name}) )
              {
                push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
                $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = "index";
                $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = $ds_name;
              }
            push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                  $val );
            $index = $#{@{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}}} + 1;
            push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}},
                  $index );
          }
      }
    #.................................
    #...DONE: push values onto data...
    #.................................
    close( FILE );
    return( $ierr );
  }

#............................................................................
#...Name
#...====
#... read_file_oxy
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) get to start of data (2 line matches)
#... 2) get dataset name
#... 3) stuff values into dataset
#............................................................................
sub read_file_oxy
  {
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
      ) = @_;
    my(
       $ds_name,      # dataset name
       $ds_name_orig, # original dataset name (if needed to create new one)
       $copy,         # copy number for unique ds_name
       $ierr,         # error return value
       $line,         # line of file
       $line_num,
       $skip_ds,      # if skipping this dataset
       @tokens,       # split on whitespace of $line

       @lines,        # lines of the file after being read by translator
      );
    &read_file_oxy_orig_translator( $file_name, \@lines );
    $ierr = 0;
    #.......................
    #...process each line...
    #.......................
    $ds_name = "unknown";
    $ds_name_orig = "unknown";
    $line_num = 0;
    $skip_ds = 0;
    foreach $line ( @lines )
      {
        $line =~ s/^\s*(.*?)\s*$/$1/;
        #..............................
        #...data line (or something)...
        #..............................
        if( $line =~ /^[^\#]/ )
          {
            #........................................
            #...skip line if skipping this dataset...
            #........................................
            if( $skip_ds )
              {
                next;
              }
            @tokens = split( /\s+/, $line );
            grep( s/(\d)([+-]\d)/$1e$2/, @tokens );
            #......................
            #...simple data line...
            #......................
            if( $#tokens == 1 )
              {
                push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}},
                      $tokens[0] );
                push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                      $tokens[1] );
              }
            #.......................................................
            #...character data line - just put all data on 1 line...
            #.......................................................
            else
              {
                push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}},
                      "" );
                push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                      $line );
              }
            if( ! defined($$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME}) )
              {
                push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
                $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = "unknown";
                $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = "unknown";
              }
          }
        #..............................
        #...data line (or something)...
        #..............................
        #..................
        #...new data set...
        #..................
        elsif( $line =~
               /
               ^\#\s*    # pound + whitespace
               (\S.*)    # data set name
               $/x )
          {
            $ds_name      = $1;
            $ds_name_orig = $ds_name;
            #................................
            #...see if should skip this ds...
            #................................
            if( defined( $$cmd_ref{$GDS} ) &&
                $ds_name_orig !~ /^($$cmd_ref{$GDS})$/ )
              {
                $skip_ds = 1;
                next;
              }
            else
              {
                $skip_ds = 0;
              }
            #..........................................
            #...create unique dataset name if needed...
            #..........................................
            if( defined( $$data_ref{$GDATA}{$ds_name} ) )
              {
                $copy = 1;
                while( 1 == 1 )
                  {
                    $ds_name = sprintf( "%s $GCOPY_FORMAT",
                                        $ds_name_orig, $copy );
                    if( !defined( $$data_ref{$GDATA}{$ds_name} ) )
                      {
                        last;
                      }
                    $copy++;
                  }
              }
            push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
            $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = $GCOORDX;
            $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = $ds_name_orig;
          }
      }
    #.............................
    #...DONE: process each line...
    #.............................
    undef( @lines );
    return( $ierr );
  }

#............................................................................
#...Name
#...====
#... read_file_plot_output
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) first line has dataset names
#... 2) stuff lines into data
#............................................................................
sub read_file_plot_output
  {
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
      ) = @_;
    my(
       @col_names,
       @ds_names, # dataset names
       $ds_start,
       $i,        # loop variable
       $ierr,     # error return value
       $line,     # line of file
       $time_old,
       @vals,
      );
    $ierr = 0;
    #...............
    #...open file...
    #...............
    if( ! open( FILE, "$file_name" ) )
      {
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
      }
    # get to block
    while( $line=<FILE> ){
        if( $line =~ /#\s*\[\d+\]\s*(\S+.*?)\s*$/ ){
            $ds_start = $1;
            $ds_start =~ s/\s+/_/g;
            $line = <FILE>;
            if( ! defined( $line ) || $line !~ /\S/ ){
                next;
            }
            if( defined( $$cmd_ref{$GDS} ) &&
                $$cmd_ref{$GDS} eq "track" ){
                if( $ds_start =~
                    /Resources:memory|
                     cc\/s\/p|
                     dmp_write_time|
                     lost_cycles|
                     procmon_|
                     secs|
                     sumRSS_GB|
                     sumcpu|
                     sumwallhr
                     /x ){
                    next;
                }
            }
            elsif( defined( $$cmd_ref{$GDS} ) &&
                $ds_start !~ /^($$cmd_ref{$GDS})/ ) {
                next;
            }
            print "Datasets: [$file_name:$ds_start]\n";
            $line =~ s/^\s+//;
            @col_names = split( /\s+/, $line );
            # prepend ${ds_start}:: to column headers to for ds_names
            @ds_names = @col_names;
            grep( s/^/${ds_start}::/, @ds_names );
            # for now, only do cycle|time|var1|var2|... blocks
            if( $#col_names >= 2 && $col_names[0] eq "cycle" && $col_names[1] eq "time" ){
                # register names
                for( $i = 2; $i <= $#col_names; $i++ ){
                    push( @{$$data_ref{$GDATASET_NAMES}}, $ds_names[$i] );
                    $$data_ref{$GDATA}{$ds_names[$i]}{$GCOORDX}{$GNAME} = $col_names[1];
                    $$data_ref{$GDATA}{$ds_names[$i]}{$GCOORDY}{$GNAME} = $col_names[$i];
                }
                # stuff in this block
                $time_old = -1e99;
                while( $line=<FILE> ){
                    if( $line !~ /\S/ ){
                        last;
                    }
                    $line =~ s/^\s+//;
                    @vals = split( /\s+/, $line );
                    # only add to array if time is increasing
                    if( $vals[1] > $time_old ){
                        $time_old = $vals[1];
                        for( $i = 2; $i <= $#col_names; $i++ ){
                            push( @{$$data_ref{$GDATA}{$ds_names[$i]}{$GCOORDX}{$GORG}}, $vals[1] );
                            push( @{$$data_ref{$GDATA}{$ds_names[$i]}{$GCOORDY}{$GORG}}, $vals[$i] );
                        }
                    }
                }
            }
        }
    }
    close( FILE );
    return( $ierr );
  }

#.........................................................................
#...this is taken from the original translator (see file in obsolete)  ...
#...It had some statements                                             ...
#...that were confusing (the set of 11 perl regexp modifiers) and some ...
#...bugs (at least I think they are bugs).  It basically takes input in...
#...a poorly spec'd form and produces output in a poorly spec'd form.  ...
#...My comments will have a "cts" in the comment line                  ...
#...This routine fills an array of the lines of the routine and        ...
#...returns is - might have to be changed if that takes too much mem   ...
#...Changes:                                                           ...
#...  - Added indentation to translator to turn into subroutine        ...
#...  - Added "my" variables to insulate (and changed local to my)     ...
#...  - Added $Count as argument to FixCounts to avoid global variable ...
#...  - Added $zero arg to FixCounts - effectively a global var        ...
#...  - Initialize $zero to 0
#...  - Changed print to push onto array                               ...
#.........................................................................
sub read_file_oxy_orig_translator
  {
    my(
       $file_name,
       $lines_ref,
      ) = @_;
    my(
       $StartString1,
       $StartString2,
       $EndString,
       $Count,
       $zero,
       $InFile,
       $Matches,
       $Line,
      );
    #  This script formats the output from a run of one of the TestSuite input
    #  decks into the standard format for comparision with a standard.
    
    $StartString1 = "Final state ASCII diagnostic dump start";
    $StartString2 = "Scalar stop";
    $EndString = "print. Final";
    $Count = 0;
    #...cts...
    $zero = 0;
    
    #main( Infile, Outfile )
    # cts comment out usage, rename $InFile, and comment out outfile
    # cts if( $#ARGV < 1 ) {
    # cts     print "Usage: $0 <InputFile> <OutputFile>\n";
    # cts     exit(-1);
    # cts }
    # cts $InFile = shift(@ARGV);
    $InFile = $file_name;
    open( IN, $InFile ) || die "Unable to open input file: $InFile\n";
    # cts $OutFile = shift(@ARGV);
    # cts open( OUT, ">".$OutFile ) || die "Unable to open output file: $OutFile\n";
    
    $Matches = 0;
    while( $Matches < 3 && ($Line = <IN>) ) {
    #      $Line = <IN>;
        chop( $Line );
        if( $Matches < 1 ) {
    	if( $Line =~ /$StartString1/ ) {
                $Matches++;
    	}
    	next; # Don't print this line
        }
        elsif( $Matches < 2 ) {
    	if( $Line =~ /$StartString2/ ) {
                $Matches++;
    	}
    	next; # Don't print this line
        }
        if( $Line =~ /$EndString/ ) {
    	$Matches++;
    	last; # Done
        }
        if( $Line eq "" ) {
    	next; # Don't print this line
        }
        $Line =~ s/mype=    0 //;
        $Line =~ s/[0-9]{1,} {0,}([a-z]{1,}) {1,}nul=.{0,}/ $1/;
        $Line =~ s/^[ \t]*[0-9]*:[ \t]*//;
        $Line =~ s/^[0-9]{2,}//;
        $Line =~ s/[ ]{1,}/\n/g;
        $Line =~ s/([a-z]{1,})/#  $1/;
        $Line =~ s/([+-][0-9][0-9])([+-])/$1\n$2/g;
        $Line =~ s/\n(\.0{1,})/\n0$1/g;
        $Line =~ s/^(\.0{1,})/0$1/g;
        $Line =~ s/\n{2,}/\n/g;
        $Line =~ s/^\n//g;
        
        # cts replace print with push
        # cts print OUT &FixCounts( $Line );
        push( @$lines_ref, split( /\n/, &FixCounts( $Line, \$Count, \$zero ) ) );
    }
  }

################################################################################
sub FixCounts {
   #local( $In ) = @_;
   #local( $i, @lines, $line );
   #...cts...
   my(
      $In,
      $Count_ref,
      $zero_ref,
      ) = @_;
   my(
      $item,
      @lines,
      $line,
     );

   # cts
   $line = "";
   @lines = split(/\n/,$In);
   foreach $item (@lines) {
      if( $item =~ /#  [a-z]{1,}/ ) {
         $$Count_ref = 0;
      }
      else {
         ${$Count_ref}++;
         if( ($item =~ /7\.777777000E\+83/i) || 
             ($item =~ /1\.000000000E-99/i) ) {
            $item = "";  # Invalid, skip
         }
         else {
            if( $item =~ /0\.000000000E\+00/i ) {  # should match 0 instead
               if( $$zero_ref == 0 ) {  # First 0
                  $item =~ s/^/ $$Count_ref    /; # Add line count
                  $$zero_ref = 1;
               }
               else {  # Repeat 0, skip
                  $item = "";
               }
            }
            else { # Valid number of interest
               $item =~ s/^/ $$Count_ref    /; # Add line count
               $$zero_ref = 0; # non-zero
            }
         }
      }
      if( $item ne "" ) {
         $line .= "$item\n"; # Reaccumulate
      }
   }

   $line;  # Return value
} # end FixCounts

#............................................................................
#...Name
#...====
#... read_file_oxy_cts
#...
#...Purpose
#...=======
#... NOTE: This was an attempt to write my own parser.
#...       For now, read_file_oxy directly incorporates logic from their
#...       old translator.
#...
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) get to start of data (2 line matches)
#... 2) get dataset name
#... 3) stuff values into dataset
#............................................................................
sub read_file_oxy_cts
  {
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
      ) = @_;
    my(
       $copy,         # copy number for unique ds_name
       $ds_name,      # dataset name
       $ds_name_orig, # original dataset name (if needed to create new one)
       $form,         # different forms of new data line
       $found,        # if a tag was found
       $ierr,         # error return value
       $index,        # index for value
       $line,         # line of file
       $pushed_token, # if a token was pushed onto the data
       $skip_zero,    # if skipping the following 0 values
       $skip_val,     # if skipping the printing of the value
       $tag_start,    # starting tag
       $tag_stop,     # stopping tag
       $tag_ds_start, # starting place where ds data is
       @tokens,       # split on whitespace of $line
       $token,        # single token
       $token_last,   # the last token
       %skip_vals,   # special values to be skipped
       $val_type,     # for replacing values of %skip_vals
      );
    $ierr = 0;
    $tag_start = $GOXY_TAG_START;
    $tag_stop = "Final state ASCII diagnostic dump stop";
    $tag_ds_start = "Scalar stop";
    $skip_vals{skip1} = "7.777777000E+83";
    $skip_vals{skip2} = "1.000000000E-99";
    $index     = 0;
    $skip_val  = 0;
    $skip_zero = 0;
    #...............
    #...open file...
    #...............
    if( ! open( FILE, "$file_name" ) )
      {
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
      }
    #...............................
    #...get to lines of interest....
    #...............................
    $found = 0;
    while( $line=<FILE> )
      {
        if( $line =~ /$tag_start/ )
          {
            while( $line=<FILE> )
              {
                if( $line =~ /$tag_ds_start/ )
                  {
                    $found = 1;
                    last;
                  }
              }
            last;
          }
      }
    if( ! $found )
      {
        $ierr = 1;
        &print_error( "Incorrect format - cannot keyword lines",
                      "The following lines are needed:",
                      "  [$tag_start]",
                      "  [$tag_ds_start]",
                      $ierr );
        return( $ierr );
      }
    #......................
    #...read in datasets...
    #......................
    $ds_name = "";
    $pushed_token = 0;
    $found = 0;
    while( $line=<FILE> )
      {
        #.....................
        #...end of all data...
        #.....................
        if( $line =~ /$tag_stop/ )
          {
            $found = 1;
            #................................
            #...finish last 0 if necessary...
            #................................
            if( $skip_zero != 0 && $pushed_token == 0 )
              {
                push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}},
                      $index );
                push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                      $token_last );
              }
            last;
          }
        #.................
        #...new dataset...
        #.................
        if( $line =~
            /
            ^\s*[0-9]+\s+      # whitespace and some digits
            ([a-z]+)\s+        # dataset name
            (\S+)=\s+(\S+)\s+  # nul value
            (\S+)=\s+(\S+)     # out_of_range value
            /x ||
            $line =~
            /
            ^mype=\s*[0-9]+\s+[0-9]+\s* # mype= <num> <num>
            ([a-z]+)                    # <name>
            (.*)$                       # vals
            /x)
          {
            #................................
            #...finish last 0 if necessary...
            #................................
            if( $skip_zero != 0 && $pushed_token == 0 )
              {
                push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}},
                      $index );
                push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                      $token_last );
              }
            $ds_name = $1;
            if( defined( $3 ) )
              {
                $form = 1;
                #...no more data on line...
                $line = "";
              }
            else
              {
                $form = 2;
                #...data on line...
                $line = $2;
              }
            $index = 0;
            $skip_zero = 0;
            $pushed_token = 0;
            #............................................
            #...skip if not interested in this dataset...
            #............................................
            if( defined( $$cmd_ref{$GDS} ) &&
                $ds_name !~ /^($$cmd_ref{$GDS})$/ )
              {
                $ds_name = "";
                next;
              }
            #.....................
            #...initialize data...
            #.....................
            if( $ds_name =~ /\S/ )
              {
                #..........................................
                #...create unique dataset name if needed...
                #..........................................
                if( defined( $$data_ref{$GDATA}{$ds_name} ) )
                  {
                    $copy = 1;
                    $ds_name_orig = $ds_name;
                    while( 1 == 1 )
                      {
                        $ds_name = sprintf( "%s $GCOPY_FORMAT",
                                            $ds_name_orig, $copy );
                        if( !defined( $$data_ref{$GDATA}{$ds_name} ) )
                          {
                            last;
                          }
                        $copy++;
                      }
                  }
                push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
                $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = $GCOORDX;
                $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = $ds_name;
              }
          }
        #...............
        #...data line...
        #...............
        if( $ds_name =~ /\S/ && $line =~ /\S/ )
          {
            $line =~ s/^\s*(\S.*?)\s*$/$1/;
            #...remove index if there is one...
            $line =~ s/\s*[0-9]+:\s*//;
            @tokens = split( /\s+/, $line );
            grep( s/(\d)([+-]\d)/$1e$2/, @tokens );
            #........................................
            #...replace values with special values...
            #........................................
            foreach $token ( @tokens )
              {
                $skip_val = 0;
                #...only use first of consecutive 0s...
                if( $token == 0 )
                  {
                    #...use first 0...
                    if( $skip_zero == 0 )
                      {
                        $skip_zero = 1;
                      }
                    #...skip other 0s...
                    else
                      {
                        $skip_val = 1;
                      }
                  }
                #...skip special values...
                else
                  {
                    #................................
                    #...finish last 0 if necessary...
                    #................................
                    if( $skip_zero != 0 && $pushed_token == 0 )
                      {
                        push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}},
                              $index );
                        push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                              $token_last );
                      }
                    $skip_zero = 0;
                    foreach $val_type ( keys %skip_vals )
                      {
                        if( $token eq "$skip_vals{$val_type}" )
                          {
                            $skip_val = 1;
                            last;
                          }
                      }
                  }
                $index++;
                #...push if not skipping...
                if( ! $skip_val )
                  {
                    $pushed_token = 1;
                    push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}},
                          $index );
                    push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                          $token );
                  }
                else
                  {
                    $pushed_token = 0;
                  }
                $token_last = $token;
              }
            #..............................................
            #...DONE: replace values with special values...
            #..............................................
          }
        #.....................
        #...DONE: data line...
        #.....................
      }
    #............................
    #...DONE: read in datasets...
    #............................
    if( ! $found )
      {
        $ierr = 1;
        &print_error( "Incorrect format - cannot find stop tag",
                      "[$tag_stop]",
                      $ierr );
        return( $ierr );
      }
    close( FILE );
    return( $ierr );
  }

#............................................................................
#...Name
#...====
#... read_file_pop
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) find a pop line and stuff it into data.
#............................................................................
sub read_file_pop
  {
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
      ) = @_;
    my(
       $ds_name,      # dataset name
       $ds_name_base,
       $ierr,         # error return value
       %keywords,    # %keywords, %var, %regexps
       %regexps,     # a regexp
       $line,         # line of file
       @tokens,       # split on whitespace of $line
       %vars          # current variable name hash
      );
    $ierr         = 0;
    $keywords{ds}   = 'card';
    $keywords{time} = 'time';
    $keywords{x}    = 'x var:';
    $keywords{y}    = 'y var:';
    $regexps{ds}   = 'card';
    $regexps{time} = 'time';
    $regexps{x}    = 'x\ var:';
    $regexps{y}    = 'y\ var:';
    #....................
    #...default values...
    #....................
    $ds_name_base = "unknown";
    $vars{ds}     = 0;
    $vars{time}   = 0;
    $vars{x}      = $GCOORDX;
    $vars{y}      = $GCOORDY;
    #...............
    #...open file...
    #...............
    if( ! open( FILE, "$file_name" ) )
      {
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
      }
    #........................
    #...look at every line...
    #........................
    while( $line=<FILE> )
      {
        #.......................................
        #...data - have before other id match...
        #.......................................
        if( $line =~
            /
            ^\ $regexps{ds}\s*[0-9]+\.\s* # new id
            write\s*$ # ends in write
            /x )
          {
            $ds_name = $ds_name_base;
            #............................................
            #...skip if not interested in this dataset...
            #............................................
            if( defined( $$cmd_ref{$GDS} ) &&
                $ds_name !~ /^($$cmd_ref{$GDS})$/ )
              {
                next;
              }
            $ds_name = "$keywords{ds}=$vars{ds},$ds_name,time=$vars{time}";
            #...............................
            #...slurp this dataset values...
            #...............................
            while( $line=<FILE> )
              {
                $line =~ s/^\s*//;
                $line =~ s/\s*$//;
                if( $line !~ /\S/ )
                  {
                    next;
                  }
                if( $line =~ /^curve\s+/ )
                  {
                    last;
                  }
                @tokens = split( /\s+/, $line );
                grep( s/(\d)([+-]\d)/$1e$2/, @tokens );
                #......................
                #...simple data line...
                #......................
                if( $#tokens == 1 )
                  {
                    push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}},
                          $tokens[0] );
                    push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                          $tokens[1] );
                  }
                #.......................................................
                #...character data line - just put all data on 1 line...
                #.......................................................
                else
                  {
                    push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}},
                          "" );
                    push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                          $line );
                  }
                if( ! defined($$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME}) )
                  {
                    push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
                    $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = $vars{x};
                    $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = $vars{y};
                  }
              }
            #.....................................
            #...DONE: slurp this dataset values...
            #.....................................
            next;
          }
        #.........................
        #...new ID - reset vals...
        #.........................
        if( $line =~
            /
            ^\ $regexps{ds}\s+ # starts with this keyword
            ([0-9]+)            # dataset ID
            \.\s*               # dot and spaces
            (\S+.*?)            # dataset name base
            \s*$                # any whitespace and end
            /x )
          {
            $vars{ds}      = sprintf( "%4d", $1 );
            $ds_name_base  = $2;
            $vars{time}    = 0;
            $vars{x}       = $GCOORDX;
            $vars{y}       = $GCOORDY;
            next;
          }
        #..........................
        #...* <variable> <value>...
        #..........................
        if( $line =~
            /
            ^\s+\*\s+ # start with star
            $regexps{time} # variable
            \s*       # whitespace
            (\S.*?)   # value
            \s+$      # whitespace and end
            /x )
          {
            $vars{time} = $1;
            next;
          }
        if( $line =~
            /
            ^\s+\*\s+ # start with star
            $regexps{x} # variable
            \s*       # whitespace
            (\S.*?)   # value
            \s+$      # whitespace and end
            /x )
          {
            $vars{x} = $1;
            next;
          }
        if( $line =~
            /
            ^\s+\*\s+ # start with star
            $regexps{y} # variable
            \s*       # whitespace
            (\S.*?)   # value
            \s+$      # whitespace and end
            /x )
          {
            $vars{y} = $1;
            next;
          }
      }
    #.................................
    #...DONE: push values onto data...
    #.................................
    close( FILE );
    return( $ierr );
  }

#............................................................................
#...Name
#...====
#... read_file_table_x
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) first line has dataset names
#... 2) stuff lines into data
#............................................................................
sub read_file_table_x{
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
       $file_type_in
      ) = @_;
    my(
       $done,     # if done
       @ds_names, # dataset names
       @ds_names_numbers, # grep for numbers (no header)
       $ds_name,  # dataset name
       $ds_name_tag,
       $ds_name_use, # has table_name in it
       @ds_names_match,
       $fh_FILE,  # file handle
       @fields,
       @fields_num,
       $file_type, # file type (table, table_x)
       $header_line, # the line of the header (will process into fields)
       $i,        # loop variable
       $ierr,     # error return value
       $is_data,
       $index,    # index number
       $j,
       @lines,    # lines of the file
       $line,     # line of file
       $line_tmp, # modified copy of line
       $headerdone, # if header has been processed
       $start_line, # starting line of data
       $table_name, # grouped table name (if any)
       $table_type,
       @tokens,   # split on whitespace of $line
       @tokens_numbers,
       $x_index,  # index of the x column (-1 for none)
       $x_name,   # name used for x axis
       $x_val,    # x value to use
       $val,      # value
      );
    $ierr = 0;
    #...............
    #...open file...
    #...............
    if( ! open( $fh_FILE, "$file_name" ) ) {
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
    }
    @lines = <$fh_FILE>;
    close( $fh_FILE );

    #...........................
    #...push values onto data...
    #...........................
    $done = "false";
    $index = 0;
    $i = -1;
    while( $done eq "false" ) {
        $i++;

        # end of file
        if( $i > $#lines ){
            $done = "true";
            next;
        }

        # skip blanks
        # 2 blanks means new header info
        if( $lines[$i] !~ /\S/ ) {
            if( $i < $#lines && $lines[$i+1] !~ /\S/ && defined($headerdone) ){
                undef( $headerdone );
                undef( @ds_names );
                undef( $table_name );
                $index++;
            }
            next;
        }

        $line = $lines[$i];
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;

        # data line if:
        #   ds_names and line does not start with "#" and one of following:
        #    number first
        #    number of cols matches number of ds_names
        undef( $is_data );

        if( ! defined($is_data) ){
            if( @ds_names && $line !~ /^\s*\#/ ){
                if( $line =~ /^${GNUMBER_REGEXP}/){
                    $is_data = "";
                }
            }
        }
        if( ! defined($is_data) ){
            if( @ds_names && $line !~ /^\s*\#/ ){
                @fields = split(/\s+/, $line);
                @fields_num = grep( /^(${GNUMBER_REGEXP})$/, @fields );
                if( @ds_names && $#fields - $#fields_num <= 1 ){
                    $is_data = "";
                }
            }
        }

        if( defined($is_data) ){

            # process new header
            if( ! defined($headerdone) ){

                # special table type
                $table_type = "";

                # starting line for this dataset
                $start_line = $i;

                # see if there is a field for the "X" value
                if( defined($$cmd_ref{ft}) ){
                    $file_type = $$cmd_ref{ft};
                }
                elsif( defined($file_type_in) && $file_type_in eq "$GFTTABLE_X" ){
                    $file_type = $GFTTABLE_X;
                }
                else{
                    # if first field matches or any field is "time"
                    if( $ds_names[0] =~ /^(i|index|time)$/i ||
                        grep( /^time\b/i, @ds_names ) ){
                        $file_type = $GFTTABLE_X;
                    }
                    else{
                        $file_type = $GFTTABLE;
                    }
                }

                # settings for file_type
                if( $file_type eq $GFTTABLE_X ){
                    # choose the time field if you find it
                    undef( $x_index );
                    for( $j = 0; $j <= $#ds_names; $j++ ){
                        # look for any field that has time in it
                        if( $ds_names[$j] =~ /^time\b/i ){
                            $x_index = $j;
                            last
                        }
                    }
                    # if not found, use first index
                    if( ! defined($x_index) ){
                        $x_index = 0;
                    }
                    $x_name = $ds_names[$x_index];
                }
                else{
                    $x_index = -1;
                    $x_name = "index";
                }
                
                # if forming a ds_name using values of other fields
                @ds_names_match = grep( /^(mat|md01|cycle|time)$/, @ds_names );
                if( $#ds_names_match == 3 ){
                    $table_type = "matedit";
                }

                # do not process header again
                $headerdone = "";
            }

            # now go through data line
            @tokens = split( /\s+/, $line );
            grep( s/(\d)([+-]\d)/$1e$2/, @tokens );
            $ds_name_tag = "";
            for( $j = 0; $j <= $#ds_names; $j++ ) {
                if( $j == $x_index ){
                    next;
                }
                $ds_name = $ds_names[$j];
                if( defined( $$cmd_ref{$GDS} ) &&
                    $ds_name !~ /^($$cmd_ref{$GDS})$/ ) {
                    next;
                }

                # init ds_name_use to ds_name
                $ds_name_use = $ds_name;

                # matedit
                if( $table_type eq "matedit" ){
                    if( $ds_name eq "mat" ){
                        $ds_name_tag = sprintf( "matedit_mat_%03d", $tokens[$j] );
                        next;
                    }
                    # Turns out the value under this column can change
                    # So, skip adding it in...just use mat num above.
                    #if( $ds_name eq "md01" ){
                    #    $ds_name_tag .= sprintf( "_md01_%d", $tokens[$j] );
                    #    next;
                    #}
                }

                if( $ds_name_tag =~ /\S/ && $ds_name_use ne "cycle" ){
                    $ds_name_use = "${ds_name_tag}_$ds_name_use";
                }

                # include table_name if set
                if( defined( $table_name ) ){
                    $ds_name_use .= "_$table_name";
                }

                # init ds vals if not already done
                # might have been seen in previous table (and skip index)
                if( ! defined($$data_ref{$GDATA}{$ds_name_use}) ){
                    push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name_use );
                    $$data_ref{$GDATA}{$ds_name_use}{$GCOORDX}{$GNAME} = $x_name;
                    $$data_ref{$GDATA}{$ds_name_use}{$GCOORDY}{$GNAME} = $ds_name_use;
                }
                
                # get val (or undefine it if not there)
                if( $j <= $#tokens ){
                  $val = $tokens[$j];
                }
                else{
                  $val = "-";
                }
                if( $val eq "-" ){
                    undef( $val );
                }
                if( $file_type eq $GFTTABLE_X ){
                    $x_val = $tokens[$x_index];
                }
                else{
                    $x_val = $i - $start_line + 1;
                }
                push( @{$$data_ref{$GDATA}{$ds_name_use}{$GCOORDX}{$GORG}},
                      $x_val );
                push( @{$$data_ref{$GDATA}{$ds_name_use}{$GCOORDY}{$GORG}},
                      $val );
            }
        }

        # header line
        else{

            # special cases for table_name
            if( $line =~ /^\s*#\s*channel\s+(\S+)/i ){
                $table_name = $1;
            }

            # get guess of header_line (might not be...[comments, or something else]
            $line_tmp = $line;
            if( $line_tmp !~ /^\#\S/ ){
                $line_tmp =~ s/^\s*\#\s*//;
            }
            $header_line = $line_tmp;
            @ds_names = split(/\s+/, $line_tmp);

            # if line did not start with comment and
            # if all ds_names are numbers, then this is a table without
            # a header.  Just label the headers by column number
            if( $line !~ /^\s*\#/ && $#ds_names >= 0 ){
                @ds_names_numbers = grep( /^($GNUMBER_REGEXP)$/, @ds_names);
                if( $#ds_names_numbers == $#ds_names ){
                    # go back one line and set appropriate header_line
                    $i--;
                    $header_line = "";
                    for( $j = 0; $j <= $#ds_names; $j++ ){
                        $header_line .= sprintf( "ind_%03d_col_%03d ", $index, $j );
                    }
                    $header_line =~ s/\s+$//;
                }
            }

            @ds_names = split(/\s+/, $header_line);

            # take a look at next non-blank and non-delimiter line
            while( $i+1 <= $#lines &&
                   ( $lines[$i+1] !~ /\S/ ||
                     $lines[$i+1] =~ /^(\s*\#\s*)?(-|\s)*$/ ) ){
                $i++;
            }
            if( $i+1 <= $#lines ){
                $line = $lines[$i+1];
            }
            else{
                $line = "";
            }
            $line =~ s/^\s*//;
            $line =~ s/\s*$//;
            @tokens = split(/\s+/, $line);
            @tokens_numbers = grep( /^(($GNUMBER_REGEXP)|-)$/, @tokens);
            # if next line is all numbers - that is data line
            if( $#tokens_numbers == $#tokens ){
                # correct for mismatch of ds_names and tokens

                # maybe space and then units ("velocity (m/s)")
                if( $#ds_names != $#tokens ){
                    $header_line =~ s/\s+(\(|\[)/$1/g;
                    @ds_names = split(/\s+/, $header_line);
                }

                # maybe number-space-Rate
                if( $#ds_names != $#tokens ){
                    $header_line =~ s/(\d)\s+(Rate)/$1-$2/g;
                    @ds_names = split(/\s+/, $header_line);
                }

                # if still not match, just label via columns
                if( $#ds_names != $#tokens ){
                    $header_line = "";
                    for( $j = 0; $j <= $#tokens; $j++ ){
                        $header_line .= sprintf( "ind_%03d_col_%03d ", $index, $j );
                    }
                    $header_line =~ s/\s+$//;
                    @ds_names = split(/\s+/, $header_line);
                }
            }
        }
    }

    #.................................
    #...DONE: push values onto data...
    #.................................
    return( $ierr );
}

#............................................................................
#...Name
#...====
#... read_file_gmv
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) first line has dataset names
#... 2) stuff lines into data
#............................................................................
sub read_file_gmv {
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
      ) = @_;
    my(
        @centers,
        $dims,
        $ds_name,  # dataset name
        $ds_name_x, # x name
        @edges_x,
        @edges_y,
        @edges_z,
        $i, # loop
        $ierr,     # error return value
        @indices,
        $invars,
        $line,     # line of file
        $num_x,
        $num_y,
        $num_z,
        $nummat,
        @vals,      # value(s)
        $vals_needed,
        $vals_found,
        $x_ref,
        $y_ref,
      );

    $ierr = 0;
    $cmd_ref = $cmd_ref; # get rid of warning

    # open file
    if( ! open( FILE, "$file_name" ) ){
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
    }

    # parse lines
    while( $line=<FILE> ){

        if( $line !~ /\S/ ){
            next;
        }

        # grid info
        if( $line =~ /^\s*nodes\s+(-1)\s+(\d+)\s+(\d+)\s+(\d+)/ ){

            # number of edges (number of cells + 1)
            $num_x = $2;
            $num_y = $3;
            $num_z = $4;
            $dims = 1;

            $vals_needed = $num_x-1;
            if( $num_y > 1 ){
                $vals_needed *= $num_y - 1;
                $dims++;
            }
            if( $num_z > 1 ){
                $vals_needed *= $num_z - 1;
                $dims++;
            }

            # edge values
            while( $line=<FILE> ){
                # next line starts with a character - done with edge info
                if( $line =~ /^\s*[a-zA-Z]/ ){
                    last;
                }

                # otherwise, edge value (they are listed in order
                $line =~ s/^\s+//;
                $line =~ s/\s+$//;
                @vals = split( /\s+/, $line );
                if( $#edges_x + 1 < $num_x ){
                    push( @edges_x, @vals );
                }
                elsif($#edges_y + 1 < $num_y){
                    push( @edges_y, @vals );
                }
                else{
                    push( @edges_z, @vals );
                }
            }

            # store these node for diffing
            $ds_name_x = "indices";

            $ds_name = "nodes_x";
            push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
            @indices = (1..$num_x);
            $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = $ds_name_x;
            $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = $ds_name;
            @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}} = @indices;
            @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}} = @edges_x;

            $ds_name = "nodes_y";
            push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
            @indices = (1..$num_y);
            $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = $ds_name_x;
            $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = $ds_name;
            @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}} = @indices;
            @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}} = @edges_y;

            $ds_name = "nodes_z";
            push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
            @indices = (1..$num_z);
            $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = $ds_name_x;
            $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = $ds_name;
            @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}} = @indices;
            @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}} = @edges_z;

            # for 1d, ref_x is the average X value
            if( $dims == 1 ){
                for( $i = 0; $i < $num_x-1; $i++ ){
                    push( @centers, ($edges_x[$i] + $edges_x[$i+1])/2 );
                }
            }
            # otherwise, just use an index value
            else{
                @centers = (0..$vals_needed-1);
            }
        }

        # material block
        if( $line =~ /^\s*material\s+(\d+)\s+/ ){
            $nummat = $1;
            # skip past material name lines
            for( $i = 0; $i < $nummat; $i++ ){
                $line = <FILE>;
            }
            # dominant mat
            $ds_name = "dominant";
            # add to name list
            push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
            # set names for x/y
            if( $dims == 1 ){
                $ds_name_x = "x";
            }
            else{
                $ds_name_x = "index";
            }
            $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = $ds_name_x;
            $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = $ds_name;
            # set x to the centers (which is indices if 2d/3d)
            $x_ref = \@{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}};
            @{$x_ref} = @centers;
            # point to y_ref
            $y_ref = \@{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}};

            # push values onto y_ref
            $vals_found = 0;
            while( $line = <FILE> ){
                $line =~ s/^\s+//;
                $line =~ s/\s+$//;
                @vals = split( /\s+/, $line );
                push( @{$y_ref}, @vals );
                $vals_found += $#{vals} + 1;
                if( $vals_found >= $vals_needed ){
                    last;
                }
            }
        }

        # in/out variable section
        if( $line =~ /^\s*variable\s*$/ ){
            $invars = "";
            next;
        }
        if( $line =~ /^\s*endvars\s*$/ ){
            undef( $invars );
            next;
        }

        # found a variable
        # looks like something that starts with a letter or '%' can be a variable
        if( defined($invars) && $line =~ /^\s*([a-zA-Z%]\S*)\s+0\s*$/ ){
            $ds_name = "var_${1}";
            # add to name list
            push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
            # set names for x/y
            if( $dims == 1 ){
                $ds_name_x = "x";
            }
            else{
                $ds_name_x = "index";
            }
            $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = $ds_name_x;
            $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = $ds_name;
            # set x to the centers (which is indices if 2d/3d)
            $x_ref = \@{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}};
            @{$x_ref} = @centers;
            # point to y_ref
            $y_ref = \@{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}};

            # push values onto y_ref
            $vals_found = 0;
            while( $line = <FILE> ){
                $line =~ s/^\s+//;
                $line =~ s/\s+$//;
                @vals = split( /\s+/, $line );
                push( @{$y_ref}, @vals );
                $vals_found += $#{vals} + 1;
                if( $vals_found >= $vals_needed ){
                    last;
                }
            }
        }
    }
    close( FILE );
    return( $ierr );
}

#............................................................................
#...Name
#...====
#... read_file_tecplot
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) first line has dataset names
#... 2) stuff lines into data
#............................................................................
sub read_file_tecplot{

    my(
        $file_name,
        $cmd_ref,
        $data_ref,
        ) = @_;
    my(
        $block_num,
        $cycle,
        $done,
        $ds_name,
        $ds_name_all,
        $ds_name_block,
        @ds_names,
        %ds_names_defined,
        $ierr,
        $line,
        $num_blocks,
        $num_digits,
        $quote,
        $time,
        $time_index,
        $time_last,
        $time_ref,
        $token,
        @tokens,
        $val_index,
        $val_last,
        $val_ref,
        %vals,
        $var,
        $var_index,
        $var_index_last,
        $var_name,
        @var_names,
        $var_new,
        @vars,
        $vars_line,
        $vars_line_new,
        );
    
    $ierr = 0;
    $cmd_ref = $cmd_ref; # get rid of warning
    
    #...............
    #...open file...
    #...............
    if( ! open( FILE, "$file_name" ) ){
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
    }

    # tecplot file w/out title - so init it
    $ds_name = "untitled";
    
    #..............................
    #...get to/parse header line...
    #..............................
    undef( $done );
    undef( $line );
    while( ! defined($done) ){

        # skip: blank line (and initial read)...
        if( ! defined($line) || $line !~ /\S/ ){
            $line = <FILE> || last;
            next;
        }

        # title with possible time/cycle -> ds_name, time/cycle
        if( $line =~ /^\s*title\s*(\S.*)$/ ){
            $ds_name = $1;

            if( $ds_name =~
                /^(.*)\s*             # ds_name
                 ,\s*t\s*=\s*(\S+)\s* # time
                 ,\s*n\s*=\s*(\S+)\s* # cycle                 
                 /x ){
                $ds_name = $1;
                $time    = $2;
                $cycle   = $3;

                # clean up cycle
                $cycle =~ s/["']//g;

            }

            # clean up ds_name
            $ds_name =~ s/["']//g;
            $ds_name =~ s/^\s*//;
            $ds_name =~ s/\s*$//;
            $ds_name =~ s/\s+/_/g;

            # add to ds_names if not already there
            if( ! defined( $ds_names_defined{$ds_name} ) ){
                $ds_names_defined{$ds_name} = "";
                push( @ds_names, $ds_name );
            }

            if( defined( $time ) ){
                push( @{$vals{$ds_name}{time}}, $time );
            }
            if( defined( $cycle ) ){
                push( @{$vals{$ds_name}{cycle}}, $cycle );
            }

            # go to next line
            $line = <FILE>;

        }

        # variable names
        elsif( $line =~ /^\s*variables(\s*=\s*)?\s+(\S.*)/i ){

            # get total vars_line (will create vars later)
            $vars_line = $2;
            while( $line = <FILE> ){

                # done when hit zone
                if( $line =~ /^\s*zone\s+/ ){
                    last;
                }
                $vars_line .= " $line";
            }

            $vars_line =~ s/^\s*//;
            $vars_line =~ s/\s*$//;

            # one style seems to have quotes and comma separated...so yank these out
            if( $vars_line =~ /^("|')/ ){
                $quote = $1;
                $vars_line_new = "";
                while( $vars_line =~ /${quote}([^${quote}]+)${quote}(.*)/ ){
                    # start between quote
                    $var_new = $1;

                    # remove beginning var
                    if( defined( $2 ) ){
                        $vars_line = $2;
                    }
                    else{
                        $vars_line = "";
                    }

                    # strip off quotes, whitespace, and comma
                    $var_new =~ s/^\s*//;
                    $var_new =~ s/\s*$//;
                    $var_new =~ s/\s+/_/g;
                    $vars_line_new .= " $var_new";
                }
                
                
                $vars_line_new =~ s/^\s*//;
                $vars_line_new =~ s/\s*$//;
                $vars_line = $vars_line_new;
            }

            # now split on whitespace
            @vars = split(/\s+/, $vars_line);

            # might need to get consistent name of time (and maybe cycle)

            # reset what variable you are on
            $var_index = 0;
            $var_index_last = $#vars;

            # already on zone, so no need to go to next line

        }

        # zone (skip)
        elsif( $line =~ /^\s*zone\s+/ ){
            # go to next line
            $line = <FILE>;
        }

        # datapacking (skip)
        elsif( $line =~ /^\s*datapacking\s+/ ){
            # go to next line
            $line = <FILE>;
        }

        # variable values
        else{
            
            # split line into token
            $line =~ s/^\s*//;
            $line =~ s/\s*$//;
            @tokens = split( /\s+/, $line );
            
            # stuff tokens onto variables
            foreach $token ( @tokens ){

                # 1-123 -> 1e-123
                $token =~ s/(\d+)([\-\+])(\d+)/${1}E$2$3/;

                # variable name
                $var_name = $vars[$var_index];

                # push onto vals list
                push( @{$vals{$ds_name}{$var_name}}, $token );

                # next var_name
                $var_index++;
                if( $var_index > $var_index_last ){
                    $var_index = 0;
                }

            }

            # go to next line
            $line = <FILE>;

        }
    }

    # done with FILE
    close( FILE );

    # fill in time field if not defined
    if( ! defined($vals{$ds_name}{time}) ){
        push( @{$vals{$ds_name}{time}}, 0 );
    }

    # now have:
    #   $vals{<ds_name>}{time}[]
    #   $vals{<ds_name>}{cycle}[]
    #   $vals{<ds_name>}{<var>}[] : this might need to be split into blocks
    # split <var> -> <var><block>
    foreach $ds_name ( sort keys %vals ){
        
        $time_ref = \@{$vals{$ds_name}{time}};
        $time_last = $#{$time_ref};

        @var_names = sort keys %{$vals{$ds_name}};

        # foreach var stuff in
        foreach $var ( @var_names ) {

            # skip time
            if( $var eq "time" ){
                next;
            }

            $val_ref  = \@{$vals{$ds_name}{$var}};
            $val_last = $#{$val_ref};

            # will have block values for this var
            $num_blocks = ($val_last + 1) / ($time_last + 1);
            $num_digits = length($num_blocks);

            # register ds_name_all
            for( $block_num = 1; $block_num <= $num_blocks; $block_num++ ){
                if( $num_blocks > 1 ){
                    $ds_name_block = sprintf( ":b_%0${num_digits}d", $block_num );
                }
                else{
                    $ds_name_block = "";
                }
                $ds_name_all = "$ds_name:$var$ds_name_block";
                push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name_all );
                $$data_ref{$GDATA}{$ds_name_all}{$GCOORDX}{$GNAME} = "time";
                $$data_ref{$GDATA}{$ds_name_all}{$GCOORDY}{$GNAME} = $var; 
                
            }
            
            # loop through values
            $val_index = 0;
            # foreach time
            for( $time_index = 0; $time_index <= $time_last; $time_index++ ){

                # foreach block
                for( $block_num = 1; $block_num <= $num_blocks; $block_num++ ){

                    if( $num_blocks > 1 ){
                        $ds_name_block = sprintf( ":b_%0${num_digits}d", $block_num );
                    }
                    else{
                        $ds_name_block = "";
                    }
                    $ds_name_all = "$ds_name:$var$ds_name_block";

                    push( @{$$data_ref{$GDATA}{$ds_name_all}{$GCOORDX}{$GORG}},
                          $$time_ref[$time_index] );
                    push( @{$$data_ref{$GDATA}{$ds_name_all}{$GCOORDY}{$GORG}},
                          $$val_ref[$val_index] );

                    # next value
                    $val_index++;
                    
                }

            }

        }

    }
    
    return( $ierr );

} # read_file_tecplot

#............................................................................
#...Name
#...====
#... read_file_token
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) find a keyword line and stuff it into data.
#............................................................................
sub read_file_token
  {
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
      ) = @_;
    my(
       $ds_name,  # dataset name
       $i,        # loop var
       $ierr,     # error return value
       $line,     # line of file
       $num,      # number of items (or index)
       @tokens,   # split on whitespace of $line
      );
    $ierr = 0;
    $cmd_ref = $cmd_ref; # get rid of warning
    #...............
    #...open file...
    #...............
    if( ! open( FILE, "$file_name" ) )
      {
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
      }
    #........................
    #...look at every line...
    #........................
    $ds_name = "token";
    push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
    $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = "token";
    $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = $ds_name;
    while( $line=<FILE> )
      {
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        @tokens = split( /\s+/, $line );
        grep( s/(\d)([+-]\d)/$1e$2/, @tokens );
        push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}}, @tokens );
      }
    # fill in index
    $num = $#{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}};
    for( $i = 0; $i <= $num; $i++ ){
        $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}[$i] = $i+1;
    }
    # if files exist but are badly hosed (or empty), then
    # token is choosen.  If no data, remove
    if( $num < 0 ){
        delete($$data_ref{$GDATA}{$ds_name});
        shift(@{$$data_ref{$GDATASET_NAMES}});
    }
    #.................................
    #...DONE: push values onto data...
    #.................................
    close( FILE );
    return( $ierr );
  }

#............................................................................
#...Name
#...====
#... read_file_tracer
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) foreach line
#... 1.1) new dataset line - reset stuff
#... 1.2) data line of dataset - stuff value into data
#............................................................................
sub read_file_tracer
  {
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
      ) = @_;
    my(
       $ds_name,        # dataset name
       @fields,         # fields (columns)
       $ds_name_root,   # root ds name
       $i,              # loop variable
       $ierr,           # error return value
       $line,           # line of file
       $line_num,       # line number in file
       $particle,       # particle number
       $particle_field, # the field number
       @seen,           # if seen this particle
       %seen_field,     # if this field has already been seen in the line
       $time,           # the time value
       $time_field,     # the field number
       @tokens,         # items to push into onto data arrays
      );
    $ierr = 0;
    #...............
    #...open file...
    #...............
    if( ! open( FILE, "$file_name" ) )
      {
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
      }
    #.......................
    #...process each line...
    #.......................
    $ds_name = "unknown";
    $line_num = 0;
    $particle_field = -1;
    $time_field = -1;
    while( defined( $line=<FILE> ) )
      {
        $line_num++;
        #...remove leading/trailing whitespace and comment lines
        $line =~ s/^\s*(.*?)\s*$/$1/;
        $line =~ s/\s*#.*//;
        #..............................
        #...data line (or something)...
        #..............................
        if( $line =~ /\S/ )
          {
            @tokens = split( /\s*,\s*/, $line );
            #...field names
            if( $#fields < 0 )
              {
                @fields = @tokens;
                for( $i = 0; $i <= $#fields; $i++ )
                  {
                    if( $fields[$i] eq "particle" )
                      {
                        $particle_field = $i;
                      }
                    if( $fields[$i] eq "time" )
                      {
                        $time_field = $i;
                      }
                  }
                if( $particle_field == -1 || $time_field == -1 )
                  {
                    $ierr = 1;
                    &print_error( "Cannot find particle and/or time fields from header: $file_name:$line_num",
                                  "[$line]",
                                  $ierr );
                    return( $ierr );
                  }
                next;
              }
            #...data
            $time = $tokens[$time_field];
            $particle = $tokens[$particle_field];
            $ds_name_root = "p_${particle}_";
            #...stuff onto name array
            if( ! defined($seen[$particle]) )
              {
                $seen[$particle] = 1;
                undef( %seen_field );
                for( $i = 0; $i <= $#tokens; $i++ )
                  {
                    #...skip fields
                    if( $i == $time_field ||
                        $i == $particle_field ||
                        ( defined( $$cmd_ref{$GDS} ) &&
                          $fields[$i] !~ /^($$cmd_ref{$GDS})$/ ))
                      {
                        next;
                      }
                    $ds_name = "${ds_name_root}$fields[$i]";
                    if( ! defined( $seen_field{$ds_name} ) ){
                        $seen_field{$ds_name} = "";
                        push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
                        $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = "time";
                        $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = "$ds_name";
                    }
                  }
              }
            #...stuff values
            undef( %seen_field );
            for( $i = 0; $i <= $#tokens; $i++ ) {
                #...skip fields
                if( $i == $time_field ||
                    $i == $particle_field ||
                    ( defined( $$cmd_ref{$GDS} ) &&
                      $fields[$i] !~ /^($$cmd_ref{$GDS})$/ )) {
                    next;
                }
                $ds_name = "${ds_name_root}$fields[$i]";
                if( ! defined( $seen_field{$ds_name} ) ){
                    $seen_field{$ds_name} = "";
                    push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}},
                          $tokens[$time_field] );
                    push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                          $tokens[$i] );
                }
            }
          } # if data line
      } # each line
    #.............................
    #...DONE: process each line...
    #.............................
    close( FILE );
    return( $ierr );
  }

#............................................................................
#...Name
#...====
#... read_file_link
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#... Almost identical to read_file_token, except with an extra fix
#... to handle formatted numbers that run into each other, e.g.:
#...      0.0000000E+00-1.7347235E-18
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) find a keyword line and stuff it into data.
#............................................................................
sub read_file_link
  {
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
      ) = @_;
    my(
       $ds_name,  # dataset name
       $i,
       $ierr,     # error return value
       $line,     # line of file
       $num,
       @tokens,   # split on whitespace of $line
      );
    $ierr = 0;
    $cmd_ref = $cmd_ref; # get rid of warning
    #...............
    #...open file...
    #...............
    if( ! open( FILE, "$file_name" ) )
      {
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
      }
    #........................
    #...look at every line...
    #........................
    $ds_name = "token";
    push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
    $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = "token";
    $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = $ds_name;
    while( $line=<FILE> )
      {
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        # add an extra space to separate any pair of Enn.n numbers
        # that have run together
        $line =~ s/(?<=\d)(-\d\.\d+E[+-]\d\d)/ $1/g;
        @tokens = split( /\s+/, $line );
        push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}}, @tokens );
      }
    # fill in index
    $num = $#{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}};
    for( $i = 0; $i <= $num; $i++ ){
        $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}[$i] = $i+1;
    }
    #.................................
    #...DONE: push values onto data...
    #.................................
    close( FILE );
    return( $ierr );
  }

#............................................................................
#...Name
#...====
#... read_file_xy
#...
#...Purpose
#...=======
#... Read a file and stuff it into $data_ref
#...
#...Arguments
#...=========
#... $file_name   Intent: in
#...              Perl type: scalar
#...              File name to read in
#...
#... $cmd_ref     Intent: out
#...              Perl type: reference to hash
#...              command line options
#...
#... $data_ref    Intent: out
#...              Perl type: reference to hash
#...              See read_file for format
#...
#... $ierr        Intent: out
#...              Perl type: reference to hash
#...              Return value (non-0 is error)
#...
#...Program Flow
#...============
#... 1) foreach line
#... 1.1) new dataset line - reset stuff
#... 1.2) data line of dataset - stuff value into data
#............................................................................
sub read_file_xy
  {
    my(
       $file_name,
       $cmd_ref,
       $data_ref,
      ) = @_;
    my(
       $ds_name,      # dataset name
       $ds_name_orig, # original dataset name (if needed to create new one)
       $copy,         # copy number for unique ds_name
       $ierr,         # error return value
       $line,         # line of file
       $line_num,
       $skip_ds,      # if skipping this dataset
       @tokens,       # items to push into onto data arrays
      );
    $ierr = 0;
    #...............
    #...open file...
    #...............
    if( ! open( FILE, "$file_name" ) )
      {
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
      }
    #.......................
    #...process each line...
    #.......................
    $ds_name = "unknown";
    $ds_name_orig = "unknown";
    $line_num = 0;
    $skip_ds = 0;
    while( defined( $line=<FILE> ) )
      {
        $line =~ s/^\s*(.*?)\s*$/$1/;
        #..............................
        #...data line (or something)...
        #..............................
        if( $line =~ /^[^\#]/ )
          {
            #........................................
            #...skip line if skipping this dataset...
            #........................................
            if( $skip_ds )
              {
                next;
              }
            #................................................................
            #...if line consists of at least 2 whitespace separated tokens...
            #................................................................
            if( $line =~ /^(\S+)\s+(\S.*)$/ )
              {
                @tokens = ($1, $2);
                #..........................................
                #...fix broken numbers (1+123 -> 1e+123)...
                #..........................................
                grep( s/(\d)([+-]\d)/$1e$2/, @tokens );
                push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}},
                      $tokens[0] );
                push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                      $tokens[1] );
              }
            #................................................
            #...otherwise, just push whole line to GCOORDY...
            #................................................
            else
              {
                push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GORG}},
                      "undef" );
                push( @{$$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GORG}},
                      $line );
              }
            #..................
            #...init dataset...
            #..................
            if( ! defined($$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME}) )
              {
                push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
                $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = "unknown";
                $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = "unknown";
              }
          }
        #....................................
        #...DONE: data line (or something)...
        #....................................
        #..................
        #...new data set...
        #..................
        elsif( $line =~
               /
               ^\#\s*    # pound + whitespace
               (\S.*)    # data set name
               $/x )
          {
            $ds_name      = $1;
            $ds_name_orig = $ds_name;
            #................................
            #...see if should skip this ds...
            #................................
            if( defined( $$cmd_ref{$GDS} ) &&
                $ds_name_orig !~ /^($$cmd_ref{$GDS})$/ )
              {
                $skip_ds = 1;
                next;
              }
            else
              {
                $skip_ds = 0;
              }
            #..........................................
            #...create unique dataset name if needed...
            #..........................................
            if( defined( $$data_ref{$GDATA}{$ds_name} ) )
              {
                $copy = 1;
                while( 1 == 1 )
                  {
                    $ds_name = sprintf( "%s $GCOPY_FORMAT",
                                        $ds_name_orig, $copy );
                    if( !defined( $$data_ref{$GDATA}{$ds_name} ) )
                      {
                        last;
                      }
                    $copy++;
                  }
              }
            push( @{$$data_ref{$GDATASET_NAMES}}, $ds_name );
            $$data_ref{$GDATA}{$ds_name}{$GCOORDX}{$GNAME} = $GCOORDX;
            $$data_ref{$GDATA}{$ds_name}{$GCOORDY}{$GNAME} = $ds_name_orig;
          }
      }
    #.............................
    #...DONE: process each line...
    #.............................
    close( FILE );
    return( $ierr );
  }

########################################################################
# read_file_xy_block
sub read_file_xy_block{
    my(
        $file_name,
        $cmd_ref,
        $data_ref,
        ) = @_;
    my(
        $ierr,         # error return value
        $index,
        $line,         # line of file
        $ord,
        @tokens,       # split on whitespace of $line
        $var,
        $var_start,
        $xy,
        );
    $ierr = 0;
    # get rid of perl_standardize warning
    $cmd_ref = $cmd_ref;

    if( ! open( FILE, "$file_name" ) ){
        $ierr = 1;
        &print_error( "Cannot open data file [$file_name].",
                      $ierr );
        return( $ierr );
    }

    # process each line
    while( $line=<FILE> ){
        
        # blank line
        if( $line !~ /\S/ ){
            next;
        }

        # end
        if( $line =~ /^\s*\$end\s*\n$/ ){
            last;
        }
        
        # new var - get var_new and go to next line
        if( $line =~ /^\s*\$(\S+)\s+(\S+)\s*=\s*'\s*(\S+)\s*'\s*,?\s*\n/ ){
            $var_start = $3;
            next;
        }

        # start of vals block
        if( $line =~ /\s*(\S+)\s*\(\s*1\s*[, ]\s*(\d+)\s*\)\s*=\s*(.*)$/ ){
            
            $ord   = $1; # x/y label
            $index = $2; # var_index
            $line  = $3; # rest of line for more processing
            
            # var name
            $var = "${var_start}_${index}";
            
            # first is "y"
            if( ! defined( $$data_ref{$GDATA}{$var} ) ){
                push( @{$$data_ref{$GDATASET_NAMES}}, $var );
                $xy = $GCOORDY;
            }
            else{
                $xy = $GCOORDX;
            }
            
            $$data_ref{$GDATA}{$var}{$xy}{$GNAME} = $ord;
            
            # not "next" so can process rest of line
            
        }
        
        # if nothing left of line, next
        if( $line !~ /\S/ ){
            next;
        }
        
        # comma separator -> blank
        # remove leading/trailing whitespace
        $line =~ s/,/ /g;
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;

        @tokens = split( /\s+/, $line );
        
        # store vals
        push( @{$$data_ref{$GDATA}{$var}{$xy}{$GORG}},
              @tokens );
              
    } # process each line

    close( FILE );
    return( $ierr );

} # read_file_xy_block

#............................................................................
#...Name
#...====
#... run_gnuplot
#...
#...Purpose
#...=======
#... Runs gnuplot given %gnuplot_info (creates plots)
#...
#...Arguments
#...=========
#... $gnuplot_info_ref Intent: inout
#...                   Perl type: reference to hash
#...                   Contains info gnuplot will use to plot.
#...                   Filled by print_gnuplot_data routine.
#...
#...Program Flow
#...============
#... 1) Compute differences
#............................................................................
sub run_gnuplot{
    my(
        $gnuplot_info_ref,
        $cmd_ref,
        ) = @_;
    my(
        $com,
        $compare_group,
        $dtype, # the data type in %gnuplot_info
        %dtypes, # the particular dtypes defined for a variable (plots/page)
        @dtypes_arr,
        $dtypeu,
        $ierr,
        $every,
        $file_base,
        $file_num,
        $fix_file, # fix for doing ps2pdf with landscape
        $gnuplot, # where gnuplot is
        $gnuplot_cmd, # gnuplot commands
        $gnuplot_cmd_plot,
        $index,
        $landscape, # filled with the landscape option
        $len_max,
        $len_this,
        $lt,
        $lt_max,
        %lts,
        $lw,
        $num_plots, # number of plots in a page
        $num_sources,
        $numvalid,
        $page, # current page number
        $plot_index, # total plot num
        $plot_num,
        $plotnum_tot,
        $printed,
        $origin, # gnuplot origin for plot
        $output, # output from shell command
        $ps2pdf, # where ps2pdf is
        $size, # gnuplot size for plot
        $source, # the source in %gnuplot_info
        $title_p,
        $variable, # the variable in %gnuplot_info
        $using_x, # x column
        $using_y, # y column
        $viewer, # prog to view plots (pdf)
        $viewer_ps, # prog to view plots (ps)
        $xlabel, # label for coord
        $ylabel, # label for coord
        $y2label,
        $ylabel_tmp,
        $title, # title of plot
        );

    # exit now if not defined
    if( ! %$gnuplot_info_ref ){
        return;
    }

    # init
    $gnuplot_cmd = "";
    $page = 0;
    if( ! defined $$gnuplot_info_ref{cmd_file} ){
        $$gnuplot_info_ref{cmd_file} = $CTS_DIFF_FILE_CMD;
    }
    if( ! defined $$gnuplot_info_ref{ps_file} ){
        $$gnuplot_info_ref{ps_file} = $CTS_DIFF_FILE_PS;
    }
    if( ! defined $$gnuplot_info_ref{pdf_file} ){
        $$gnuplot_info_ref{pdf_file} = $CTS_DIFF_FILE_PDF;
    }
    if( defined( $$gnuplot_info_ref{orientation} ) ){
        $landscape = $$gnuplot_info_ref{orientation};
    }
    else{
        $landscape = "";
    }

    # find needed execs (add some things to path)
    if( defined( $$cmd_ref{plotrun}) ){
	$gnuplot = which_exec( "gnuplot" );
	$ps2pdf  = which_exec( "ps2pdf" );
	$viewer = "";
	if( $viewer !~ /\S/ ){
	    $viewer = &which_exec( "xpdf",     QUIET=>'' );
	}
	if( $viewer !~ /\S/ ){
	    $viewer = &which_exec( "gv",       QUIET=>'' );
	}
	if( $viewer !~ /\S/ ){
	    $viewer = &which_exec( "evince",   QUIET=>'' );
	}
	if( $viewer !~ /\S/ ){
	    $viewer = &which_exec( "acroread", QUIET=>'' );
	}
	if( $viewer !~ /\S/ ){
	    $viewer = "unknow_pdf_viewer";
	}

        # also point to something that can process ps files.
        # pick evince over gv since above already picks gv for pdf files.
        # So, below print will at least have other option for ps/viewer_ps.
	$viewer_ps = "";
	if( $viewer_ps !~ /\S/ ){
	    $viewer_ps = &which_exec( "evince",   QUIET=>'' );
	}
	if( $viewer !~ /\S/ ){
	    $viewer_ps = &which_exec( "gv",       QUIET=>'' );
	}
	if( $viewer !~ /\S/ ){
	    $viewer_ps = "unknow_pdf_viewer";
	}
    }
    else{
	$gnuplot = "noplotrun";
	$ps2pdf  = "noplotrun";
	$viewer  = "noplotrun";
    }

    # finish off lt to get consistent line types
    $lt = 1;
    $num_sources = 0;
    foreach $source ( sort keys %{$$gnuplot_info_ref{lt}{source}} ){
        $num_sources++;
        if( $source =~ /^cmp=\s*(\d+):\s*(\d+):(\S+)$/ ){
            $compare_group = $1;
            $file_num      = $2;
            $file_base     = $3;
            if( $file_num == 0 ){
                $$gnuplot_info_ref{lt}{source}{$source} = 2;
            }
            else{
                if( ! defined($lts{$file_base}) ){
                    $lts{$file_base} = $lt;
                    $lt++;
                    if( $lt == 2 ){
                        $lt++;
                    }
                }
                $$gnuplot_info_ref{lt}{source}{$source} = $lts{$file_base};
            }
        }
    }

    # beginning gnuplot_cmd
    $plot_index = 1;
    $gnuplot_cmd .= "# cts_diff.cmd\n";
    $gnuplot_cmd .= "\n";
    $gnuplot_cmd .= "# module load gnuplot\n";
    $gnuplot_cmd .= "#\n";
    $gnuplot_cmd .= "# Interactive:\n";
    $gnuplot_cmd .= "#   gnuplot (run multiple windows if you want multiple plots)\n";
    $gnuplot_cmd .= "#   {copy/paste HEADER_BLOCK}\n";
    $gnuplot_cmd .= "#   {copy/paste title...plot block}\n";
    $gnuplot_cmd .= "#   {skip SKIP BLOCK IF INTERACTIVE}\n";
    $gnuplot_cmd .= "# \n";
    $gnuplot_cmd .= "# Default:\n";
    $gnuplot_cmd .= "#   gnuplot $$gnuplot_info_ref{cmd_file}\n";
    $gnuplot_cmd .= "#   Creates:\n";
    $gnuplot_cmd .= "#     $$gnuplot_info_ref{ps_file}\n";
    $gnuplot_cmd .= "#   from:\n";
    $gnuplot_cmd .= "#     $$gnuplot_info_ref{data_file} .\n";
    $gnuplot_cmd .= "\n";
    $gnuplot_cmd .= "# SKIP BLOCK IF INTERACTIVE\n";
    $gnuplot_cmd .= "set output '$$gnuplot_info_ref{ps_file}'\n";
    $gnuplot_cmd .= "set terminal postscript noenhanced $landscape color 'Times-Roman' 10\n";
    $gnuplot_cmd .= "\n";
    $gnuplot_cmd .= "# HEADER BLOCK\n";
    $gnuplot_cmd .= "set datafile  missing '-'\n";
    $gnuplot_cmd .= "set title     noenhanced\n";
    $gnuplot_cmd .= "set xlabel    noenhanced\n";
    $gnuplot_cmd .= "set x2label   noenhanced\n";
    $gnuplot_cmd .= "set ylabel    noenhanced\n";
    $gnuplot_cmd .= "set y2label   noenhanced\n";
    $gnuplot_cmd .= "set key       noenhanced\n";
    $gnuplot_cmd .= "set ytics     nomirror\n";
    $gnuplot_cmd .= "set y2tics\n";
    $gnuplot_cmd .= "set grid\n";
    # $gnuplot_cmd .= "set xtics rotate by -30\n";
    $gnuplot_cmd .= "set format x  '%g'\n";
    $gnuplot_cmd .= "set format x2 '%g'\n";
    # since plotting orig, y has same values so do not need
    #$gnuplot_cmd .= "set format y  '\%15.8e'\n";
    $gnuplot_cmd .= "set format y  '%g'\n";
    $gnuplot_cmd .= "set format y2 '%.3e'\n"; # abs,rel just a few digits
    $gnuplot_cmd .= "\n";
    
    # process each variable in own page
    # gi.variables[0] = cmp=1:dt
    #             [1] = cmp=1:err
    foreach $variable ( @{$$gnuplot_info_ref{variables}} ){

        #get number of dtype plots and which are used
        # gi.sources[0] = cmp=  1:  1:ipc_mgroup-output
        #           [1] = cmp=  1:  0:gold_ipc_mgroup-output
        $num_plots = 0;
        undef( %dtypes );
        undef( $printed );
        foreach $source ( sort @{$$gnuplot_info_ref{sources}} ) {
            @dtypes_arr = keys %{$$gnuplot_info_ref{using}{$variable}{$source}{$GCOORDY}{$GDIFF}};
            # plot_orig will plot orig also
            if( defined($$cmd_ref{plot_orig}) ){
                push( @dtypes_arr, $GORG );
            }
            foreach $dtype ( @dtypes_arr ) {
                # skip the "type" array since that is just the type of diff:
                #   "-", "B", "A", "R"
                if( $dtype eq "type" ){
                    next;
                }
                $dtypes{$dtype} = "";
            }
        }
        if( %dtypes ){
            $num_plots += keys( %dtypes );
        }

        # if no plots, go to next variable
        if( $num_plots == 0 ){
            next;
        }

        # gi.dtypes[0] = Abs Diff
        #          [1] = Rel Diff
        #          [2] = type

        # per page (variable) gnuplot_cmd
        $page++;
        $gnuplot_cmd .= "#\n";
        $gnuplot_cmd .= sprintf( "print '  Page %4d: %s'\n", $page, $variable );
        $gnuplot_cmd .= "#\n";
        $gnuplot_cmd .= "\n";
        if( $num_plots > 1 ){
            $gnuplot_cmd .= "# SKIP BLOCK IF INTERACTIVE\n";
            $gnuplot_cmd .= "set multiplot\n";
        }
        $plot_num = 0;
        $size   = sprintf( "%13.4e", 1/$num_plots );
        $origin = sprintf( "%13.4e", 1 - $size);

        # process original data then each dtype plot in correct order
        # $dtype -> Orig, Abs Diff, Rel Diff, (type not defined in dtypes so skipped)
        foreach $dtype ( sort keys %dtypes ){
            $plot_num++;

            # xlabel
            undef( $xlabel );
            foreach $source ( sort @{$$gnuplot_info_ref{sources}} ){
                $xlabel =
                    $$gnuplot_info_ref{label}{$variable}{$source}{$GCOORDX}{$GORG};
                if( defined( $xlabel ) ){
                    last;
                }
            }
            if( ! defined( $xlabel ) ){
                $xlabel = "$GCOORDX";
            }

            # ylabel, y2label
            undef( $ylabel );
            foreach $source ( sort @{$$gnuplot_info_ref{sources}} ){
                $ylabel =
                    $$gnuplot_info_ref{label}{$variable}{$source}{$GCOORDY}{$GORG};
                if( defined( $ylabel ) ){
                    last;
                }
            }
            if( ! defined( $ylabel ) ){
                $ylabel = "$GORG";
            }
            # if too long, truncate
            $len_max  = 15;
            $len_this = length($ylabel);
            # chop middle with "..." (len 3)
            if( $len_this > $len_max*2 + 3 ){
                $ylabel_tmp =
                    substr( $ylabel, 0, $len_max )."...".
                    substr( $ylabel, $len_this - $len_max, $len_max );
                $ylabel = $ylabel_tmp;
            }
            # could just set to $GORG
            #$ylabel  = $GORG;
            $y2label = $dtype;

            # title
            foreach $source ( sort @{$$gnuplot_info_ref{sources}} ){
                $title = $$gnuplot_info_ref{title}{$variable}{$source};
                if( defined( $title ) ){
                    last;
                }
            }
            if( ! defined( $title ) ){
                $title = "$variable";
            }
            $title = "$title [$dtype]";

            # gnuplot_cmd_plot = plot line1, line2, line3, ....
            # will prepend with header below for full 
            $gnuplot_cmd_plot = "";

            # Orig data - y1axis
            $dtypeu = $GORG;
            $lt_max = 0;
            foreach $source ( sort @{$$gnuplot_info_ref{sources}} ){
                $using_x = $$gnuplot_info_ref{using}{$variable}{$source}{$GCOORDX}{$GORG};
                $using_y =
                    $$gnuplot_info_ref{using}{$variable}{$source}{$GCOORDY}{$dtypeu};
                $every =
                    $$gnuplot_info_ref{every}{$variable}{$source}{$GCOORDY}{$dtypeu};
                $numvalid =
                    $$gnuplot_info_ref{numvalid}{$variable}{$source}{$GCOORDY}{$dtypeu};
                $index =
                    $$gnuplot_info_ref{index}{$variable}{$source};
                $lw = 1;
                $lt =
                    $$gnuplot_info_ref{lt}{source}{$source};
                $title_p = "$dtypeu: $source";

                # have points to plot
                if( defined( $using_y ) && $numvalid > 0 ){
                    # per source gnuplot_cmd
                    # lines
                    $gnuplot_cmd_plot .= "'$$gnuplot_info_ref{data_file}' ";
                    $gnuplot_cmd_plot .= "index $index ";
                    $gnuplot_cmd_plot .= "using ";
                    if( defined( $using_x ) ){
                        $gnuplot_cmd_plot .= "$using_x:";
                    }
                    $gnuplot_cmd_plot .= "$using_y ";
                    $gnuplot_cmd_plot .= "title \"$title_p\" ";
                    $gnuplot_cmd_plot .= "with lines ";
                    $gnuplot_cmd_plot .= "axis x1y1 ";
                    $gnuplot_cmd_plot .= "lw $lw ";
                    $gnuplot_cmd_plot .= "lt $lt ";
                    $gnuplot_cmd_plot .= ",\\\n       ";
                    # points
                    $gnuplot_cmd_plot .= "'$$gnuplot_info_ref{data_file}' ";
                    $gnuplot_cmd_plot .= "index $index ";
                    $gnuplot_cmd_plot .= "using ";
                    if( defined( $using_x ) ){
                        $gnuplot_cmd_plot .= "$using_x:";
                    }
                    $gnuplot_cmd_plot .= "$using_y ";
                    $gnuplot_cmd_plot .= "every $every ";
                    $gnuplot_cmd_plot .= "title \"\" ";
                    $gnuplot_cmd_plot .= "with points ";
                    $gnuplot_cmd_plot .= "axis x1y1 ";
                    $gnuplot_cmd_plot .= "lw $lw ";
                    $gnuplot_cmd_plot .= "lt $lt ";
                    $gnuplot_cmd_plot .= ",\\\n       ";
                } # have points to plot

            }

            # process each source part of dtype plot
            $dtypeu = $dtype;
            foreach $source ( sort @{$$gnuplot_info_ref{sources}} ){
                # plot_orig
                if( $dtypeu eq $GORG ){
                    next;
                }
                if( $source =~ /^cmp=\s*(\d+):\s*(\d+):(\S+)$/ ){
                    $compare_group = $1;
                    $file_num      = $2;
                    $file_base     = $3;
                }
                $using_x =
                    $$gnuplot_info_ref{using}{$variable}{$source}{$GCOORDX}{$GORG};
                $using_y =
                    $$gnuplot_info_ref{using}{$variable}{$source}{$GCOORDY}{$GDIFF}{$dtypeu};
                $every =
                    $$gnuplot_info_ref{every}{$variable}{$source}{$GCOORDY}{$GDIFF}{$dtypeu};
                $numvalid =
                    $$gnuplot_info_ref{numvalid}{$variable}{$source}{$GCOORDY}{$GDIFF}{$dtypeu};
                $index =
                    $$gnuplot_info_ref{index}{$variable}{$source};
                $lw = 1;
                $lt =
                    $$gnuplot_info_ref{lt}{source}{$source};
                # if only 2 sources (most of the time), then pick single good color.
                if( $num_sources <= 2 ){
                    $lt = 3;
                }
                $title_p = "$dtypeu: $source";
                if( $file_num == 0 ){
                    $lw = .5;
                    $lt = -1;
                    $title_p = "";
                }
                
                # have points to plot
                if( defined( $using_y ) && $numvalid > 0 ){
                    
                    # per source gnuplot_cmd
                    # lines
                    $gnuplot_cmd_plot .= "'$$gnuplot_info_ref{data_file}' ";
                    $gnuplot_cmd_plot .= "index $index ";
                    $gnuplot_cmd_plot .= "using ";
                    if( defined( $using_x ) ){
                        $gnuplot_cmd_plot .= "$using_x:";
                    }
                    $gnuplot_cmd_plot .= "$using_y ";
                    $gnuplot_cmd_plot .= "title \"$title_p\" ";
                    $gnuplot_cmd_plot .= "with lines ";
                    $gnuplot_cmd_plot .= "axis x1y2 ";
                    $gnuplot_cmd_plot .= "lw $lw ";
                    $gnuplot_cmd_plot .= "lt $lt ";
                    $gnuplot_cmd_plot .= ",\\\n       ";
                    # points
                    if( $file_num != 0 ){
                        $gnuplot_cmd_plot .= "'$$gnuplot_info_ref{data_file}' ";
                        $gnuplot_cmd_plot .= "index $index ";
                        $gnuplot_cmd_plot .= "using ";
                        if( defined( $using_x ) ){
                            $gnuplot_cmd_plot .= "$using_x:";
                        }
                        $gnuplot_cmd_plot .= "$using_y ";
                        $gnuplot_cmd_plot .= "every $every ";
                        $gnuplot_cmd_plot .= "title \"\" ";
                        $gnuplot_cmd_plot .= "with points ";
                        $gnuplot_cmd_plot .= "axis x1y2 ";
                        $gnuplot_cmd_plot .= "lw $lw ";
                        $gnuplot_cmd_plot .= "lt $lt ";
                        $gnuplot_cmd_plot .= ",\\\n       ";
                    }
                } # have points to plot
            } # process each source part of dtype plot

            # if made this plot
            if( $gnuplot_cmd_plot =~ /\S/ ){
                $gnuplot_cmd .= "\n";
                $gnuplot_cmd .= sprintf( "  # Title: [%s] Plot Num [%s/%s]\n",
                                         $title, $plot_num, $num_plots );
                $gnuplot_cmd .= "  # SKIP BLOCK IF INTERACTIVE\n";
                $gnuplot_cmd .= "  set size   1,$size\n";
                $gnuplot_cmd .= "  set origin 0,$origin\n";
                $gnuplot_cmd .= "\n";
                $plotnum_tot++;
                $gnuplot_cmd .= "  # INTERACTIVE: set term wxt $plotnum_tot\n";
                $gnuplot_cmd .= "  set title '$title'\n";
                $gnuplot_cmd .= "  set xlabel  '$xlabel'\n";
                $gnuplot_cmd .= "  set ylabel  '$ylabel'\n";
                $gnuplot_cmd .= "  set y2label '$y2label'\n";
                $gnuplot_cmd .= "  plot $gnuplot_cmd_plot";
                
            }# if made this plot

            # finish dtype gnuplot_cmd
            $gnuplot_cmd =~ s/,\\\s+$/\n/;
            $origin = sprintf( "%13.4e", $origin - $size );
            
          } # process each source part of dtype plot

        # finish per page (variable) gnuplot_cmd gnuplot_cmd
        if( $num_plots >= 1 ){
            $plot_index++;
            if( $num_plots > 1 ){
                $gnuplot_cmd .= "\n";
                $gnuplot_cmd .= "# SKIP BLOCK IF INTERACTIVE\n";
                $gnuplot_cmd .= "set nomultiplot\n";
                $gnuplot_cmd .= "\n";
            }
        } # process each dtype plot
    } # process each variable in own page

    # print gnuplot_cmd to file
    open ( FILE, ">$$gnuplot_info_ref{cmd_file}" );
    print FILE $gnuplot_cmd;
    close FILE;
    if( $$cmd_ref{v} >= 1 ){
        print "  Using     $CTS_DIFF_FILE_DATA\n";
        print "  Created   $CTS_DIFF_FILE_CMD\n";
        print "  Viewing:\n";
        print "    gnuplot:\n";
        print "      See top of .cmd file for instructions to view interactively in gnuplot\n";
        print "    python:\n";
        print "      pyplot_cts_diff.py -d $CTS_DIFF_FILE_DATA\n";
    }

    # run gnuplot, ps2pdf+fix
    if( defined( $$cmd_ref{plotrun} ) ){

        # run gnuplot
        $com = "$gnuplot $$gnuplot_info_ref{cmd_file} 2>&1 | grep -v Warning:";
        if( $$cmd_ref{v} >= 1 ){
            print "  Creating  $CTS_DIFF_FILE_PS\n";
            print "    tail -F $CTS_DIFF_FILE_PLOT_OUT\n";
        }
        system( "$com 2>&1 > $CTS_DIFF_FILE_PLOT_OUT" );

        # ps2pdf and fix ps rotate
        if( $ps2pdf ne "" && -T "$$gnuplot_info_ref{ps_file}" ){

            # fix for doing landscape correctly
            # Some pdf viewers (gv on trinity) chop off the plot unless
            # the rotation is hacked in the ps file.  Hopefully either the
            # ps or pdf will work for everyone.
            if( $$cmd_ref{v} >= 1 ){
                print "  Creating  $CTS_DIFF_FILE_PDF\n";
            }
            $fix_file = "$$gnuplot_info_ref{ps_file}.tmp.ps";
            $output = `head -1 $$gnuplot_info_ref{ps_file}`;
            if( ! open( FILE, ">$fix_file" ) ){
                $ierr = 1;
                &print_error( "Cannot write to temporary file [$fix_file]",
                              $ierr );
                exit( $ierr );
            }
            print FILE $output;
            print FILE "<</AutoRotatePages /None>>setdistillerparams\n";
            close FILE;
            $output = `cat $$gnuplot_info_ref{ps_file} >> $fix_file`;
            $output = `$ps2pdf $fix_file $$gnuplot_info_ref{pdf_file} 2>&1`;
            unlink( $fix_file );
        } # ps2pdf and fix ps rotate

        if( $$cmd_ref{v} >= 1 ){
            print "  Viewing:\n";
            print "    $viewer_ps $CTS_DIFF_FILE_PS\n";
            print "    $viewer     $CTS_DIFF_FILE_PS\n";
        }

    } # run gnuplot, ps2pdf+fix

} # run_gnuplot

1;

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

