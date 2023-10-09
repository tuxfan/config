package ctf_process;

########################################################################
# ==================
# External Interface
# ==================
#
# Synopsis
# --------
#   ctf == cycle time field
#   The purpose of this routine is to act as a general interface
#   to reading a set of text files for time vs. <var> values.
#   Often you produce a set of files that have information per cycle.
#   You want to see how a variable varies vs. time.
#   Also, these files might represent several restarts where cycles
#   can be repeated.  So, you want to remove the repeated cycles and
#   only include the latest cycles.
#
# Subroutines
# -----------
#   o ctf_read( <see subroutine for args> )
#     read a set of files
#     In:  a file list in the order you want them processed
#          For time-stamped files, the ordering is done just by sorting the
#          filename.  So, this can just be something like:
#            glob( 'rj_cmd_out.*' )
#          Can also input pre-defined @lines array.
#     Out:
#          vals{<field>}{val}[]   = array of values
#          vals{<field>}{cycle}[] = (time_type==<undef>) array of cycles
#          vals{<field>}{time}[]  = (time_type==<undef>) array of times
#          For completeness, you will have "time" and "cycle" in the
#          <field> list as well.
#   
#   o ctf_dump( <see subroutine for args> )
#     Prints the %vals to a file (in a gnuplot friendly way)
#
#   o ctf_plot( <see subroutine for args> )
#     Calls ctf_dump if needed, creates a plot file, and runs guplot
#     on it.
#
#   o ctf_types, ctf_extras
#     Returns an array of types/extras found.
#
########################################################################

########################################################################
# ==================
# Internal Interface
# ==================
#
# Synopsis
# --------
#   When making an interface for a new filetype to be read, here are
#   the specifications.
#   See ctf_process_type_default.pm (type=default) for an example.
#
# Module name
# -----------
#   ctf_process_type_<type name>.pm
#
#   Example type=foo:
#     ctf_process_type_foo.pm
#
#   Location: Will include all files searched for in your PATH
#     of the above form.
#
# Required subroutines:
# ---------------------
#   o ctf_read_<type>( FILES=>\@filelist (LINES=>\@lines), VALS=>\%vals )
#     Process each file in filelist (or each line in @lines):
#       call ctf_vals_splice() if doing a restart and might start
#         at a previous cycle.
#       call ctf_vals_add each cycle (possibly multiple times each
#         cycle)
#     return:  0    ->     correct file type and successfully read
#             !0    ->     correct file type but failed    to read
#             undef -> not correct file type
#
#   o ctf_plot_<type>( FILE_INFO=>\%file_info, PLOT_INFO=>\%plot_info )
#     Given %file_info, fills out plot_info specifying how the plots
#     should look.
#
########################################################################

use POSIX qw( strtod );
use diagnostics;
use warnings;
use Carp;
use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION );
use Exporter;
use Cwd;
use Time::Local;
use Tie::File;
use Fcntl 'O_RDONLY';
use FindBin qw($RealBin);

use my_utils qw (
                 conv_time
                 date_ymdhms_sep
                 extrema
                 my_copy_obj
                 my_dir
                 my_get_locs
                 my_derivative
                 my_smooth
                 my_stat
                 print_error
                 ppo
                 run_command
                 status_bar
                 which_exec
                );

$VERSION   = 1.00;

@ISA       = qw(
                Exporter
               );

@EXPORT    = qw(
               );

@EXPORT_OK = qw(
                ctf_dump
                ctf_extras
                ctf_read
                ctf_plot
                ctf_types
               );
sub BEGIN {
}
sub END{
}

my(
    $dir,
    @dirs,
    $inc_dir,
    $loc,
    %locs,
    $require_file,
    @require_files,
    %TYPES_PROCESSED,
    @TYPES_PROCESSED_ARRAY,
    %EXTRAS_PROCESSED,
    @EXTRAS_PROCESSED_ARRAY,
    $require_name,
  );

$CTF_TYPE          = "";
$FILE_CTF_DUMP     = "ctf_dump.txt";
$FILE_CTF_PLOT_CMD = "ctf_plot.cmd";
$FILE_CTF_PLOT_PS  = "ctf_plot.ps";
$FILE_CTF_PLOT_PDF = "ctf_plot.pdf";
@CTF_TYPES = ();

#...regexp to match number - simple for speed
$CTF_NUMBER_REGEXP = '[+-]?\.?[0-9]+\.?[0-9]*([eE][+-]?\d+)?';

# separator for multi valued values
# gnuplot does not handle "whitespace and/or ," type separators well.
# Anything but " " here  will result in an gnuplot error...sigh.
$CTF_VAL_SEPARATOR = " ";

# dirs to search for things
# where exec is first
@dirs = ( $RealBin );
# if exec is in clone, loc of LOC_TOOLS_ALL_FULL/general
# since you likely want the things in clone
&my_get_locs( LOCS => \%locs );
if( defined( $locs{LOC_TOOLS_ALL_FULL} ) ){
    foreach $dir ( split( /\s+/, $locs{LOC_TOOLS_ALL_FULL} ) ){
        $loc = "$dir/General";
        push( @dirs, $loc );
    }
}
# then rest of things in INC (like PATH)
push( @dirs, @INC );

# require - type interface
# Pick the first one found of a type.
# If you want to use another one first, put earlier in PATH (INC)
undef( @TYPES_PROCESSED_ARRAY );
foreach $inc_dir ( @dirs ){
    @require_files = glob( "$inc_dir/ctf_process_type_*.pm" );
    foreach $require_file( @require_files ){
        if( -r $require_file &&
            $require_file =~ m&.*/ctf_process_type_(\S+).pm$& ){
            $require_name = $1;
            if( ! defined $TYPES_PROCESSED{$require_name} ){
                $TYPES_PROCESSED{$require_name} = $require_file;
                push( @TYPES_PROCESSED_ARRAY, $require_file );
            }
        }
    }
}

# require - additional files that the type's might want
undef( @EXTRAS_PROCESSED_ARRAY );
foreach $inc_dir ( @dirs ){
    @require_files = glob( "$inc_dir/ctf_process_extras_*.pm" );
    foreach $require_file( @require_files ){
        if( -r $require_file &&
            $require_file =~ m&.*/ctf_process_extras_(\S+).pm$& ){
            $require_name = $1;
            if( ! defined $EXTRAS_PROCESSED{$require_name} ){
                $EXTRAS_PROCESSED{$require_name} = $require_file;
                push( @EXTRAS_PROCESSED_ARRAY, $require_file );
            }
        }
    }
}

# now "require" them
foreach $require_file ( @TYPES_PROCESSED_ARRAY, @EXTRAS_PROCESSED_ARRAY ){
    require $require_file;
}

########################################################################
########################################################################
###                    External Interface
########################################################################
########################################################################

########################################################################
# returns hash of types found
sub ctf_types{ return %TYPES_PROCESSED; }


########################################################################
# returns hash of extras found
sub ctf_extras{ return %EXTRAS_PROCESSED; }

########################################################################
# read the files
sub ctf_read{
    my %args = (
        CHECK_ONLY => undef, # if only checking the filetype
        FILES      => undef, # array of files
        FILES_GLOB => undef, # glob string for files
        LINES      => undef, # @lines array (contents of files)
        VALS       => undef, # ref to hash result (will init)
        TIME       => undef, # full    -> "undef" for missing cycle data
                             #            no field copy of {time}
                             # <undef> -> copy of {time} for defined
        TYPE       => undef, # ref to type used to parse files
        VERBOSE    => undef, # verbose output
        CMD        => undef, # cmd (cmd{opt} = val)
        @_,
        );
    my( $args_valid ) = "CHECK_ONLY|CMD|FILES|FILES_GLOB|LINES|TIME|TYPE|VALS|VERBOSE";
    my(
        $arg,
        $check_only,
        $cmd_ref,
        %cmd_null,
        $cycle_ref,
        $eval_error,
        $field,
        $file,
        @files,
        @files_error,
        $force,
        $i,
        $i_max,
        $ierr,
        %info,
        $lines_ref,
        $max_i,
        $n_cycle,
        $n_time,
        $n_val,
        $num,
        $require_file,
        $ret,
        $time,
        $time_a,
        $time_b,
        $time_max,
        $time_min,
        $time_ref,
        $time_shift,
        $type,
        $type_force,
        $type_ref,
        $type_used,
        @types_processed_array,
        $val_ref,
        $verbose,
        $val_old,
        $vals_ref,
        );

    # valid args
    foreach $arg (keys %args){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # cmd_ref
    if( defined( $args{CMD} ) ){
        $cmd_ref = $args{CMD};
    }
    else{
        $cmd_ref = \%cmd_null;
    }

    # if give lines
    if( defined($args{LINES}) ){
        $lines_ref = $args{LINES};
    }

    else{
        # @files
        if( defined($args{FILES}) && ref($args{FILES}) eq "ARRAY" ){
            @files = @{$args{FILES}};
        }
        elsif( defined($args{FILES_GLOB}) ){
            @files = glob($args{FILES_GLOB});
        }
        
        if( ! @files || $#files < 0 ){
            $ierr = 1;
            &print_error( "Must give 'FILES' or 'FILES_GLOB' arg", $ierr );
            exit( $ierr );
        }

        # must be able to read all files
        foreach $file ( @files ){
            if( ! -r $file ){
                push( @files_error, "  $file" );
            }
        }
        if( @files_error ){
            $ierr = 1;
            &print_error( "The following file(s) cannot be read or do not exist:",
                          @files_error,
                          $ierr );
            exit( $ierr );
        }
    }

    # check_only
    if( defined($args{CHECK_ONLY}) ){
        $check_only = "";
    }
        
    # VALS
    $vals_ref = $args{VALS};
    if( ! defined($vals_ref) || ref($vals_ref) ne "HASH" ){
        $ierr = 1;
        &print_error( "Must give 'VALS' as ref tp hash arg", $ierr );
        exit( $ierr );
    }
    undef( %$vals_ref );

    # TYPE
    if( defined( $args{TYPE} ) ){
        $type_ref = $args{TYPE};
    }

    # time
    if( defined( $args{TIME} ) ){
        $time = $args{TIME};
    }

    # verbose
    if( defined( $args{VERBOSE} ) ){
        $verbose = "$args{VERBOSE}  ";
    }

    # process the files
    undef( %{$vals_ref} );

    if( defined($args{VERBOSE}) ){
        print "$args{VERBOSE}ctf_read\n";
    }

    # start time
    $time_a = time();

    # print require files
    if( defined($args{VERBOSE}) ){
        print "\n";
        print "$args{VERBOSE}  Require files:\n";
        foreach $require_file ( @TYPES_PROCESSED_ARRAY, @EXTRAS_PROCESSED_ARRAY ){
            print "$args{VERBOSE}    $require_file\n";
        }
        print "\n";
    }

    # which types to process
    @types_processed_array = sort keys %TYPES_PROCESSED;
    $type_force = "";
    if( defined($type_ref) ){
        if( defined($$type_ref) ){
            if( $$type_ref =~ /\S/ ){
                @types_processed_array = ($$type_ref);
                $type_force = $$type_ref;
            }
        }
    }

    foreach $type ( @types_processed_array ){
        # too verbose...when lots of types
        #if( defined($args{VERBOSE}) ){
        #    print "$args{VERBOSE}  trying type = $type\n";
        #}
        undef( $ret );
        undef( $type_used );
        undef( $force );
        if( $type eq $type_force ){
            $force = "";
        }
        if( defined($lines_ref) ){
            $eval_error = eval "\$ret = &ctf_read_$type( LINES=>\$lines_ref, VALS=>\$vals_ref, CHECK_ONLY=>\$check_only, VERBOSE=>\$verbose, FORCE=>\$force )";
        }
        else{
            $eval_error = eval "\$ret = &ctf_read_$type( FILES=>\\\@files,   VALS=>\$vals_ref, CHECK_ONLY=>\$check_only, VERBOSE=>\$verbose, FORCE=>\$force )";
        }
        # error stored into $@
        if( $@ ){
            $ierr = 1;
            &print_error( "FAILED", 
                          "Error from ctf_read_$type :",
                          $@, $ierr );
            exit( $ierr );
        }
        if( defined( $ret ) ){
            $type_used = $type;
            $CTF_TYPE = $type;
            last;
        }
    }

    # if did not find type (might process independently)
    if( ! defined( $ret ) ){
        return( $ret );
    }

    # assign type_ref
    if( defined( $type_ref ) ){
        $$type_ref = $type_used;
    }

    # if got error processing (but found correct type)
    if( $ret != 0 ){
        &print_error( "type: $TYPES_PROCESSED{$type_used}",
                      "Error returned",
                      $ret );
        $ierr = 1;
        exit( $ierr );
    }

    # fill out the time for each field if not already done
    &ctf_fill_time( VALS=>$vals_ref, TIME=>$time );

    # time_range (time_range then time_shift)
    if( defined( $$cmd_ref{time_range} ) ){
        ($time_min, $time_max) = split(/::/, $$cmd_ref{time_range});

        if( ! defined( $time_min ) || $time_min !~ /\S/ ){
            $time_min = -9e99;
        }
        if( ! defined( $time_max ) || $time_max !~ /\S/ ){
            $time_max = 9e99;
        }

        # time_min if given a field instead
        if( $time_min =~ /^f:(\S.*?)\s*$/ ){
            $field = $1;

            if( ! defined($$vals_ref{$field}) ){
                $ierr = 1;
                &print_error( "FAILED",
                              "Could not find field [$field] ",
                              $ierr );
                exit( $ierr );
            }

            $cycle_ref = $$vals_ref{$field}{cycle};
            $time_ref  = $$vals_ref{$field}{time};
            $val_ref   = $$vals_ref{$field}{val};
            $i_max     = $#$val_ref;
            $i = 0;
            $time_min  = $$time_ref[$i]; 
            $val_old = $$val_ref[$i] || 0;
            if( $val_old eq "-" ){
                $val_old = 0;
            }
            for( $i = 1; $i <= $i_max; $i++ ){
                if( $$val_ref[$i] ne "-" && $$val_ref[$i] != $val_old ){
                    $time_min = $$time_ref[$i-1];
                    last;
                }
            }
        }

        # time_max if given a field instead
        if( $time_max =~ /^f:(\S.*?)\s*$/ ){
            $field = $1;

            if( ! defined($$vals_ref{$field}) ){
                $ierr = 1;
                &print_error( "FAILED",
                              "Could not find field [$field] ",
                              $ierr );
                exit( $ierr );
            }

            $cycle_ref = $$vals_ref{$field}{cycle};
            $time_ref  = $$vals_ref{$field}{time};
            $val_ref   = $$vals_ref{$field}{val};
            $i_max     = $#$val_ref;
            $i = $i_max;
            $time_max  = $$time_ref[$i]; 
            $val_old = $$val_ref[$i_max] || 0;
            if( $val_old eq "-" ){
                $val_old = 0;
            }
            for( $i = $i_max-1; $i >= 0; $i-- ){
                if( $$val_ref[$i] ne "-" && $$val_ref[$i] != $val_old ){
                    $time_max = $$time_ref[$i+1];
                    last;
                }
            }
        }

        if( $time_min !~ /^($CTF_NUMBER_REGEXP)$/ ||
            $time_max !~ /^($CTF_NUMBER_REGEXP)$/ ){
            $ierr = 1;
            &print_error( "FAILED",
                          "Expected:",
                          "  --time_range <time>::<time> ",
                          "  --time_range f:<variable>::f:<variable> ",
                          "Got:",
                          "  --time_range ${time_min}::${time_max}",
                          $ierr );
            exit( $ierr );
        }

        foreach $field ( keys %{$vals_ref} ){
            $cycle_ref = $$vals_ref{$field}{cycle};
            $time_ref  = $$vals_ref{$field}{time};
            $val_ref   = $$vals_ref{$field}{val};
            undef( @n_cycle );
            undef( @n_time );
            undef( @n_val );
            $max_i = $#{$time_ref};
            for( $i = 0; $i <= $max_i; $i++ ){
                if( $$time_ref[$i] >= $time_min && $$time_ref[$i] <= $time_max ){
                    push( @n_cycle, $$cycle_ref[$i] );
                    push( @n_time,  $$time_ref[$i] );
                    push( @n_val,   $$val_ref[$i] );
                }
            }
            if( @n_time ){
                @{$cycle_ref} = @n_cycle;
                @{$time_ref}  = @n_time;
                @{$val_ref}   = @n_val;
            }
            else{
                delete( $$vals_ref{$field} );
            }
        }
    }

    # time_shift
    $time_shift = 0;
    if( defined($$cmd_ref{time_shift}) ){

        # based on first max of a field
        if( $$cmd_ref{time_shift} =~ /^f:(\S.*?)\s*$/ ){
            $field = $1;

            if( ! defined($$vals_ref{$field}) ){
                $ierr = 1;
                &print_error( "FAILED",
                              "Could not find field [$field] ",
                              $ierr );
                exit( $ierr );
            }

            &extrema( X=>$$vals_ref{$field}{time},
                      Y=>$$vals_ref{$field}{val},
                      NOISE=>.5, INFO=>\%info );
            if( defined( $info{max} ) ){
                $time_shift -= $$vals_ref{$field}{time}[$info{max}[0]];
            }
        }

        # given absolute value
        else{
            $time_shift = $$cmd_ref{time_shift};
            if( $time_shift !~ /^($CTF_NUMBER_REGEXP)$/ ){
                $ierr = 1;
                &print_error( "FAILED",
                              "Expected: ",
                              "  --time_shift [f:<variable>]",
                              "  --time_shift [<time>]",
                              "Got:",
                              "  --time_shift $time_shift",
                              $ierr );
                exit( $ierr );
            }
        }

        # time_shift (time_range then time_shift)
        if( $time_shift != 0 ){
            foreach $field ( keys %{$vals_ref} ){
                $time_ref  = $$vals_ref{$field}{time};
                $max_i = $#{$time_ref};
                for( $i = 0; $i <= $max_i; $i++ ){
                    $$time_ref[$i] += $time_shift;
                }
                if( $field eq "time" ){
                    @{$$vals_ref{$field}{val}} = @{$time_ref};
                }
            }
        }
    }

    # stop time
    if( defined($args{VERBOSE}) ){
        if( defined($$vals_ref{cycle}) ){
            $num = keys %{$vals_ref};
            printf( "$args{VERBOSE}  num_fields  = %s\n", $num );
            if( $#{$$vals_ref{cycle}{val}} >= 0 ){
                printf( "$args{VERBOSE}  cycle_range = %d - %d\n",
                        $$vals_ref{cycle}{val}[0], $$vals_ref{cycle}{val}[-1] );
                printf( "$args{VERBOSE}  time_range  = %s - %s\n",
                        $$vals_ref{time}{val}[0], $$vals_ref{time}{val}[-1] );
                if( $time_shift != 0 ){
                    printf( "$args{VERBOSE}  time_shift  = %s\n",
                            $time_shift );
                }
            }
        }
        $time_b = time();
        printf( "$args{VERBOSE}  Time: %.2f minutes\n",
                ($time_b - $time_a)/60.0 );
    }

    return( $ret );

}

########################################################################
# dump vals to a file
sub ctf_dump{
    my %args = (
        DIR        => undef, # directory to print to
        VALS       => undef, # ref to hash
        FILE_INFO  => undef, # ref to hash contains info about the file
        VERBOSE    => undef, # if verbose output
        @_,
        );
    my( $args_valid ) = "DIR|FILE_INFO|VALS|VERBOSE";
    my(
        $arg,
        %col_width,
        $cycle,
        $cycle_ref,
        $dir,
        $fh_FILE,
        $field,
        $field_tmp,
        $file,
        $file_info_ref,
        $file_name,
        $i,
        $ierr,
        $j,
        $last_val,
        $max,
        @max_a,
        $min,
        @min_a,
        $num_fields,
        $num_fields_max,
        $num_times,
        $num_sub,
        $num_vals,
        @num_vals_a,
        $num_vals_0,
        @num_vals_0_a,
        $num_vals_neg,
        @num_vals_neg_a,
        $num_vals_nums,
        @num_vals_nums_a,
        $num_vals_pos,
        @num_vals_pos_a,
        $time,
        $time_a,
        $time_b,
        $time_ref,
        $val,
        $val_use,
        $val_use_orig,
        @vals,
        $vals_ref,
        );

    # valid args
    foreach $arg (keys %args){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }
    
    # VALS
    $vals_ref = $args{VALS};
    if( ! defined($vals_ref) || ref($vals_ref) ne "HASH" ){
        $ierr = 1;
        &print_error( "Must give 'VALS' as ref tp hash arg", $ierr );
        exit( $ierr );
    }
    $vals_ref = $args{VALS};

    # file
    if( ! defined($args{DIR}) ){
        $dir = ".";
    }
    else{
        $dir = $args{DIR};
    }
    # FILE
    $file = "$dir/$FILE_CTF_DUMP";
    
    # FILE_INFO
    $file_info_ref = $args{FILE_INFO};
    
    if( defined($args{VERBOSE}) ){
        print "$args{VERBOSE}ctf_dump\n";
    }

    # start time
    $time_a = time();

    # open file
    if( defined($file) ){
        $file_name = $file;
        # too annoying to remove this by hand each time
        #if( -e $file ){
        #    $ierr = 1;
        #    &print_error( "Output file [$file] already exists - remove it",
        #                  $ierr );
        #    exit( $ierr );
        #}
        if( ! open( $fh_FILE, ">$file" ) ){
            $ierr = 1;
            &print_error( "Cannot create output file [$file]",
                          $ierr );
            exit( $ierr );
        }
    }
    else{
        $file_name = "STDOUT";
        $fh_FILE   =  STDOUT;
    }

    $num_fields_max = keys %$vals_ref;
    if( defined($args{VERBOSE}) ){
        print "$args{VERBOSE}  num_fields = $num_fields_max\n";
        print "$args{VERBOSE}  ";
    }

    # fill some info
    if( defined($file_info_ref) ){
        $$file_info_ref{file_name}  = $file_name;
        $$file_info_ref{index}      = "0-based";
        $$file_info_ref{max_index}  = $num_fields_max-1;
        $$file_info_ref{num_fields} = $num_fields_max;
    }

    # header
    printf( $fh_FILE "# ctf_process\n" );
    printf( $fh_FILE "###################################\n" );
    printf( $fh_FILE "#   file_name  = %s\n", $file_name );
    printf( $fh_FILE "#   index      = %s\n", "0-based" );
    printf( $fh_FILE "#   max_index  = %d\n", $num_fields_max-1 );
    printf( $fh_FILE "#   num_fields = %d\n", $num_fields_max );
    printf( $fh_FILE "###################################\n" );
    printf( $fh_FILE "\n" );
 
    # go through each field
    $num_fields     = 0;
    foreach $field ( sort keys %$vals_ref ){

        # increment num_fields
        $num_fields++;

        if( defined($args{VERBOSE}) ){
            &status_bar( $num_fields, $num_fields_max );
        }

        if( defined($$vals_ref{$field}{cycle}) ){
            $cycle_ref = \@{$$vals_ref{$field}{cycle}};
        }
        else{
            $cycle_ref = \@{$$vals_ref{cycle}{val}};
        }
        if( defined($$vals_ref{$field}{time}) ){
            $time_ref = \@{$$vals_ref{$field}{time}};
        }
        else{
            $time_ref = \@{$$vals_ref{time}{val}};
        }

        # find col widths
        $col_width{val}   = length($field);
        foreach $field_tmp ( "cycle", "time" ) {
            $col_width{$field_tmp} = length($field_tmp);
        }

        # for special separated values, see how many there are
        $num_sub = 1;
        foreach $val ( @{$$vals_ref{$field}{val}} ) {
            if( defined( $val ) &&
                $val ne "-" &&
                $val ne "" ){
                $num_sub = split( /\s*${CTF_VAL_SEPARATOR}\s*/, $val );
                last;
            }
        }

        $i = 0;

        # init stats
        $num_times = 0;
        undef( @num_vals_a );
        undef( @num_vals_nums_a );
        undef( @num_vals_0_a );
        undef( @num_vals_pos_a );
        undef( @num_vals_neg_a );
        undef( @max_a );
        undef( @min_a );
        for( $j = 0; $j < $num_sub; $j++ ){
            $num_vals_a[$j]       = 0;
            $num_vals_nums_a[$j]  = 0;
            $num_vals_0_a[$j]     = 0;
            $num_vals_pos_a[$j]   = 0;
            $num_vals_neg_a[$j]   = 0;
            $max_a[$j]            = "-";
            $min_a[$j]            = "-";
        }
        $last_val       = $$vals_ref{$field}{val}[-1];
        if( ! defined( $last_val ) ||
            $last_val !~ /\S/ ){
            $last_val = "-";
        }
        foreach $val ( @{$$vals_ref{$field}{val}} ) {

            if( defined($val) &&
                $val ne "" ){
                $val_use = $val;
            }
            else{
                $val_use = "-";
            }
            $val_use_orig = $val_use;

            @vals = split(/\s*${CTF_VAL_SEPARATOR}\s*/, $val_use_orig);
            $j = 0;
            foreach $val_use ( @vals ){

                $num_vals_a[$j]++;

                # num_vals_0, num_vals_pos, num_vals_neg
                if( $val_use eq "0" ){
                    $num_vals_0_a[$j]++;
                    if( $max_a[$j] eq "-" ){
                        $max_a[$j] = $val_use;
                    }
                    if( $min_a[$j] eq "-" ){
                        $min_a[$j] = $val_use;
                    }
                }
                elsif( $val_use =~ /^($CTF_NUMBER_REGEXP)$/ ){
                    if( $max_a[$j] eq "-" ){
                        $max_a[$j] = $val_use;
                    }
                    else{
                        if( $val_use > $max_a[$j] ){
                            $max_a[$j] = $val_use;
                        }
                    }
                    if( $min_a[$j] eq "-" ){
                        $min_a[$j] = $val_use;
                    }
                    else{
                        if( $val_use < $min_a[$j] ){
                            $min_a[$j] = $val_use;
                        }
                    }
                    if( $val_use > 0 ){
                        $num_vals_pos_a[$j]++;
                    }
                    elsif( $val_use == 0 ){
                        $num_vals_0_a[$j]++;
                    }
                    else{
                        $num_vals_neg_a[$j]++;
                    }
                }

                $j++;
            }

            $val_use = $val_use_orig;

            # keep track of times
            if( $$time_ref[$i] ne "-" ){
                $num_times++;
            }

            # widths
            if( length($val_use) > $col_width{val} ){
                $col_width{val} = length($val_use);
            }
            if( length($$cycle_ref[$i]) > $col_width{cycle} ){
                $col_width{cycle} = length($$cycle_ref[$i]);
            }
            if( length($$time_ref[$i]) > $col_width{time} ){
                $col_width{time} = length($$time_ref[$i]);
            }
            $i++;
        }

        for( $j = 0; $j < $num_sub; $j++ ){
            $num_vals_nums_a[$j] = $num_vals_pos_a[$j] + $num_vals_0_a[$j] + $num_vals_neg_a[$j];
        }

        # join to CTF_VAL_SEPARATOR separated values
        # if other parsers cannot handle this, combine somehow into 1 value
        $num_vals      = join( "${CTF_VAL_SEPARATOR}", @num_vals_a );
        $num_vals_nums = join( "${CTF_VAL_SEPARATOR}", @num_vals_nums_a );
        $num_vals_0    = join( "${CTF_VAL_SEPARATOR}", @num_vals_0_a );
        $num_vals_pos  = join( "${CTF_VAL_SEPARATOR}", @num_vals_pos_a );
        $num_vals_neg  = join( "${CTF_VAL_SEPARATOR}", @num_vals_neg_a );
        $max           = join( "${CTF_VAL_SEPARATOR}", @max_a );
        $min           = join( "${CTF_VAL_SEPARATOR}", @min_a );

        # if past the first one
        if( $num_fields > 1 ){
            printf( $fh_FILE "\n" );
        }

        # header (order: field, index, alphabetical)
        printf( $fh_FILE "###################################\n" );
        printf( $fh_FILE "# field          = %s\n", $field );
        printf( $fh_FILE "# index          = %d\n", $num_fields-1 );
        printf( $fh_FILE "# last_val       = $last_val\n" );
        printf( $fh_FILE "# max            = $max\n" );
        printf( $fh_FILE "# min            = $min\n" );
        printf( $fh_FILE "# num_times      = $num_times\n" );
        printf( $fh_FILE "# num_vals       = $num_vals\n" );
        printf( $fh_FILE "# num_vals_0     = $num_vals_0\n" );
        printf( $fh_FILE "# num_vals_neg   = $num_vals_neg\n" );
        printf( $fh_FILE "# num_vals_nums  = $num_vals_nums\n" );
        printf( $fh_FILE "# num_vals_pos   = $num_vals_pos\n" );
        if( defined($file_info_ref) ){
            $$file_info_ref{field}{$field}{index}          = $num_fields-1;
            $$file_info_ref{field}{$field}{last_val}       = $last_val;
            $$file_info_ref{field}{$field}{max}            = $max;
            $$file_info_ref{field}{$field}{min}            = $min;
            $$file_info_ref{field}{$field}{num_vals}       = $num_vals;
            $$file_info_ref{field}{$field}{num_vals_nums}  = $num_vals_nums;
            $$file_info_ref{field}{$field}{num_vals_pos}   = $num_vals_pos;
            $$file_info_ref{field}{$field}{num_vals_0}     = $num_vals_0;
            $$file_info_ref{field}{$field}{num_vals_neg}   = $num_vals_neg;
            $$file_info_ref{field}{$field}{num_times}      = $num_times;
        }
        printf( $fh_FILE "# %$col_width{cycle}s %$col_width{time}s %$col_width{val}s\n",
                "cycle", "time", $field );

        # and print cycle/time/val
        $i = 0;
        foreach $val ( @{$$vals_ref{$field}{val}} ) {
            if( defined($val) && $val =~ /\S/ ){
                $val_use = $val;
            }
            else{
                $val_use = "-";
            }
            printf( $fh_FILE "  %$col_width{cycle}s %$col_width{time}s %$col_width{val}s\n",
                    $$cycle_ref[$i], $$time_ref[$i], $val_use );
            $i++;
        }

        printf( $fh_FILE "\n" );

    }
    
    # close file
    if( defined( $file ) ){
        close( $fh_FILE );
    }

    if( defined($args{VERBOSE}) ){
        printf( "$args{VERBOSE}  Created: $file\n" );
    }

    # stop time
    $time_b = time();
    if( defined($args{VERBOSE}) ){
        printf( "$args{VERBOSE}  Time: %.2f minutes\n",
                ($time_b - $time_a)/60.0 );
    }

}

########################################################################
# plot it
sub ctf_plot{
    my %args = (
        FILE_INFO  => undef, # filled %file_info ref from ctf_dump
        DIR        => undef, # directory to use
        VERBOSE    => undef, # verbose output
        VIEW       => undef, # if actually view the resulting plots
        @_,
        );
    my( $args_valid ) = "DIR|FILE_INFO|VIEW|VERBOSE";
    my(
        $arg,
        $axes,
        $color,
        $color_arg,
        $com,
        $dir,
        $eval_error,
        $fh_FILE,
        $field,
        @fields,
        %fields_new,
        %fields_use,
        $file_cmd,
        $file_in,
        $file_info_ref,
        $file_pdf,
        $file_ps,
        $gnuplot_cmd,
        $ierr,
        $j,
        $index,
        $lw,
        $num,
        $num_vals_nums,
        $output,
        $plot_i,
        $plot_num,
        $plot_num_p,
        $plot_idx_max,
        @plot_info,
        $plot_info_ref,
        $side,
        $status,
        $title,
        $title_field,
        $using,
        $using_math,
        $val,
        @vals,
        @vals_sorted,
        $verbose,
        $with,
        );

    # valid args
    foreach $arg (keys %args){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    $GNUPLOT = &which_exec( "gnuplot" );
    $PS2PDF  = &which_exec( "ps2pdf" );
    $VIEWER = "";
    # prefer gv since can operate on ps file
    if( $VIEWER !~ /\S/ ) {
        $VIEWER = &which_exec( "gv",       QUIET=>'' );
    }
    if( $VIEWER !~ /\S/ ) {
        $VIEWER = &which_exec( "xpdf",     QUIET=>'' );
    }
    if( $VIEWER !~ /\S/ ) {
        $VIEWER = &which_exec( "evince",   QUIET=>'' );
    }
    if( $VIEWER !~ /\S/ ) {
        $VIEWER = &which_exec( "acroread", QUIET=>'' );
    }

    if( ! defined($args{FILE_INFO}) ){
        $ierr = 1;
        &print_error( "Missing VALS arg - call ctf_read() -> ctf_dump()",
                      $ierr );
        exit( $ierr );
    }

    if( defined($args{VERBOSE}) ){
        print "$args{VERBOSE}ctf_plot\n";
    }

    $file_info_ref = $args{FILE_INFO};
    $dir = $args{DIR};

    $file_in  = $$file_info_ref{file_name};
    $file_cmd = "$dir/$FILE_CTF_PLOT_CMD";
    $file_pdf = "$dir/$FILE_CTF_PLOT_PDF";
    $file_ps  = "$dir/$FILE_CTF_PLOT_PS";

    # define plot_info
    $eval_error = eval "\$ret = &ctf_plot_$CTF_TYPE( FILE_INFO=>\$file_info_ref, PLOT_INFO=>\\\@plot_info, VERBOSE=>\$verbose )";
    # error stored into $@
    if( $@ ){
        $ierr = 1;
        &print_error( "Error from ctf_plot_$CTF_TYPE :",
                      $@, $ierr );
        exit( $ierr );
    }

    # do nothing if no plots
    if( ! @plot_info ){
        if( defined($args{VERBOSE}) ){
            print "$args{VERBOSE}  No data found to plot.\n";
        }
        return( $ierr );
    }

    # ---------------
    # gnuplot command
    # ---------------

    $gnuplot_cmd = "";

    # ------
    # header
    # ------
    $gnuplot_cmd .= "#\n";
    $gnuplot_cmd .= "# gnuplot commands\n";
    $gnuplot_cmd .= "#   in:  $file_in\n";
    $gnuplot_cmd .= "#   out: $file_ps\n";
    $gnuplot_cmd .= "#\n";
    $gnuplot_cmd .= "# remove the next 2 lines if you want to run gnuplot interactively:\n";
    $gnuplot_cmd .= "set output '$file_ps'\n";
    $gnuplot_cmd .= "set terminal postscript noenhanced portrait color 'Times-Roman' 12\n";
    $gnuplot_cmd .= "# Some basic init lines applying to all plots:\n";
    $gnuplot_cmd .= "set datafile missing '-'\n";
    $gnuplot_cmd .= "set title   noenhanced\n";
    $gnuplot_cmd .= "set xlabel  noenhanced\n";
    $gnuplot_cmd .= "set x2label noenhanced\n";
    $gnuplot_cmd .= "set ylabel  noenhanced\n";
    $gnuplot_cmd .= "set y2label noenhanced\n";
    $gnuplot_cmd .= "set key     noenhanced\n";
    $gnuplot_cmd .= "set key     below box\n";
    $gnuplot_cmd .= "set xtics   rotate\n";
    $gnuplot_cmd .= "set ytics   mirror\n";
    $gnuplot_cmd .= "set format  x  '%g'\n";
    $gnuplot_cmd .= "set format  x2 '%g'\n";
    $gnuplot_cmd .= "set format  y  '%g'\n";
    $gnuplot_cmd .= "set format  y2 '%g'\n";
    $gnuplot_cmd .= "# Each plot (in blocks below):\n";
    $gnuplot_cmd .= "print '  Starting gnuplot'\n";

    # loop through pages
    $plot_idx_max = $#plot_info;

    $plot_num = 0;
    for( $plot_i = 0; $plot_i <= $plot_idx_max; $plot_i++ ){

        # copy fields for each side (will prune this)
        undef( %fields_use );
        foreach $side( "y", "y2" ){
            if( defined($plot_info[$plot_i]{"${side}_fields"}) ){
                @{$fields_use{"${side}_fields"}} =
                    @{$plot_info[$plot_i]{"${side}_fields"}};
            }
        }

        # sanity check - must define if usings or titles
        if(
            (
             defined($plot_info[$plot_i]{usings}) ||
             defined($plot_info[$plot_i]{titles})
            ) &&
            (
             ! defined($plot_info[$plot_i]{usings}) ||
             ! defined($plot_info[$plot_i]{titles})
            ) ){
            $ierr = 1;
            &print_error( "ctf_plot: field=$field",
                          "The following must _ALL_ be defined if _ANY_ are used:",
                          "  usings, titles",
                          $ierr );
            exit( $ierr );
        }

        # sanity check - usings and titles must be of same length
        if( defined($plot_info[$plot_i]{usings}) &&
            ( $#{$plot_info[$plot_i]{usings}} != $#{$plot_info[$plot_i]{titles}} ) ){
            $ierr = 1;
            &print_error( "ctf_plot: field=$field",
                          "The following must match in size:",
                          "  usings, titles",
                          $ierr );
            exit( $ierr );
        }

        # sanity check - cannot sort if usings
        if( defined($plot_info[$plot_i]{usings}) &&
            (
             defined($plot_info[$plot_i]{y_sort}) ||
             defined($plot_info[$plot_i]{y2_sort})
            ) ){
            $ierr = 1;
            &print_error( "ctf_plot: field=$field",
                          "Cannot use usings with sort",
                          $ierr );
            exit( $ierr );
        }

        # gnuplot fails to plot when using logscale and all values non-positive
        # num = number of plots done
        if( ! defined( $plot_info[$plot_i]{usings} ) ){
            undef( %fields_new );
            $num = 0;
            foreach $side( "y", "y2" ){
                
                # skip if nothing there
                if( ! defined($fields_use{"${side}_fields"}) ){
                    next;
                }
                
                # go through each field
                foreach $field ( @{$fields_use{"${side}_fields"}} ){
                    
                    # skip if not in file
                    if( ! defined($$file_info_ref{field}{$field}) ){
                        next;
                    }
                    
                    # skip of no numbers
                    if( $$file_info_ref{field}{$field}{num_vals_nums} == 0 ){
                        next;
                    }
                    
                    # skip if logscale and no positive valus
                    if( defined($plot_info[$plot_i]{"${side}scale"}) &&
                        $plot_info[$plot_i]{"${side}scale"} eq "logscale" &&
                        $$file_info_ref{field}{$field}{num_vals_pos} == 0 ){
                        next;
                    }
                    
                    # valid field - push
                    push( @{$fields_new{"${side}_fields"}}, $field );
                    $num++;
                    
                }
            }

            # if no plots done, next
            if( $num == 0 ){
                next;
            }
            
            # copy back
            &my_copy_obj( \%fields_use, \%fields_new );
            
        }

        $plot_num++;
        $plot_num_p = sprintf( "%04d", $plot_num );

        # settings
        $gnuplot_cmd .= "# title = $plot_info[$plot_i]{title}\n";
        $gnuplot_cmd .= "# plot  = $plot_num\n";
        $gnuplot_cmd .= "  print '    $plot_num_p : $plot_info[$plot_i]{title}'\n";
        $gnuplot_cmd .= "  set title   '$plot_info[$plot_i]{title}'\n";
        if( defined( $plot_info[$plot_i]{grid} ) ){
            $gnuplot_cmd .= "  set grid\n";
        }
        $gnuplot_cmd .= "  set xlabel  '$plot_info[$plot_i]{xlabel}'\n";
        $gnuplot_cmd .= "  set ylabel  '$plot_info[$plot_i]{ylabel}'\n";
        if( defined($plot_info[$plot_i]{yscale}) ){
            $gnuplot_cmd .= "  set $plot_info[$plot_i]{yscale} y\n";
        }
        if( defined($plot_info[$plot_i]{y2label}) ){
            $gnuplot_cmd .= "  set y2label '$plot_info[$plot_i]{y2label}'\n";
            $gnuplot_cmd .= "  set y2tics\n";
            $gnuplot_cmd .= "  set ytics   nomirror\n";
            if( defined($plot_info[$plot_i]{y2scale}) ){
                $gnuplot_cmd .= "  set $plot_info[$plot_i]{y2scale} y2\n";
            }
        }
        
        # plot

        $gnuplot_cmd .= "  plot \\\n";
        
        # start color == 0
        # but want each axis to start with same number...but offset
        # so as not to overlap.
        # This starts black.
        $color = 0;

        foreach $side( "y", "y2" ){

            # bump color on y2 to start at same color but offset from y
            if( $side eq "y2" ){
                # this started with dark blue
                $color = 30;
            }

            # get fields
            if( defined($fields_use{"${side}_fields"}) ){
                @fields = @{$fields_use{"${side}_fields"}};
            }
            else{
                @fields = ();
            }
            # sort based on max if requested
            if( defined($plot_info[$plot_i]{"${side}_sort"}) ){
                undef( @vals );
                if( $plot_info[$plot_i]{"${side}_sort"} eq "last_val" ){
                    foreach $field ( @fields ){
                        push( @vals, "$$file_info_ref{field}{$field}{last_val} $field" );
                    }
                }
                else{
                    foreach $field ( @fields ){
                        push( @vals, "$$file_info_ref{field}{$field}{max} $field" );
                    }
                }
                @vals_sorted = reverse sort numerically_val @vals;
                undef( @fields );
                foreach $val ( @vals_sorted ){
                    ($field = $val) =~ s/.*\s+//;
                    push( @fields, $field );
                }
            }

            $j = 0;
            foreach $field ( @fields ) {
                # title_field
                if( defined( $plot_info[$plot_i]{titles} ) ){
                    $title_field = $plot_info[$plot_i]{titles}[$j];
                }
                elsif( defined( $plot_info[$plot_i]{title_field} ) &&
                    defined( $plot_info[$plot_i]{title_field}{$field} ) ){
                    $title_field = $plot_info[$plot_i]{title_field}{$field};
                }
                else{
                    # default
                    ( $title_field = $field ) =~ s/_/\_/g;
                }

                # index
                $index = "index $$file_info_ref{field}{$field}{index}";

                # using_math
                if( defined( $plot_info[$plot_i]{using_math} ) &&
                    defined( $plot_info[$plot_i]{using_math}{$field} ) ){
                    $using_math = $plot_info[$plot_i]{using_math}{$field};
                    $using_math =~ s/y/\$3/;
                }
                else{
                    $$plot_info_ref[$plot_i]{mult}{$field} = $title;
                    $using_math = "3";
                }
                # using
                if( defined( $plot_info[$plot_i]{usings} ) ){
                    $using = $plot_info[$plot_i]{usings}[$j];
                }
                elsif( $plot_info[$plot_i]{xlabel} eq "time" ){
                    $using = "using 2:$using_math";
                }
                else{
                    $using = "using 1:$using_math";
                }

                $num_vals_nums = $$file_info_ref{field}{$field}{num_vals_nums};
                # take first value of multi-valued values
                $num_vals_nums =~ s/${CTF_VAL_SEPARATOR}.*//;
                if( defined( $plot_info[$plot_i]{with} ) &&
                    defined( $plot_info[$plot_i]{with}{$field} ) ){
                    $with = $plot_info[$plot_i]{with}{$field};
                }
                elsif( $num_vals_nums > 100 ){
                    $with = "with lines";
                }
                else{
                    $with = "with linespoints";
                }
                if( $side eq "y" ){
                    $axes = "axes x1y1";
                }
                else{
                    $axes = "axes x1y2";
                }
                if( defined( $plot_info[$plot_i]{lw} ) &&
                    defined( $plot_info[$plot_i]{lw}{$field} ) ){
                    $lw = $plot_info[$plot_i]{lw}{$field};
                }
                else{
                    # default
                    $lw = "lw 3";
                }
                $color_arg = "lc $color";

                # dot the top if impulses and use this as symbol
                if( $with =~ /impulses/ ){
                    $gnuplot_cmd .= "    '$file_in' $index $using with linespoints $axes $lw $color_arg title '$title_field' , \\\n";
                    $title_field = '';
                }
                
                # line
                $gnuplot_cmd .=     "    '$file_in' $index $using $with       $axes $lw $color_arg title '$title_field' , \\\n";
                $color++;

                $j++;
            }
        }

        $gnuplot_cmd =~ s/\s*,\s*\\\n$/\n/;

        # reset settings
        if( defined($plot_info[$plot_i]{grid}) ){
            $gnuplot_cmd .= "  unset grid\n";
        }
        if( defined($plot_info[$plot_i]{yscale}) ){
            $gnuplot_cmd .= "  unset $plot_info[$plot_i]{yscale} y\n";
        }
        if( defined($plot_info[$plot_i]{y2label}) ){
            $gnuplot_cmd .= "  set y2label\n";
            $gnuplot_cmd .= "  unset y2tics\n";
            $gnuplot_cmd .= "  set ytics   mirror\n";
            if( defined($plot_info[$plot_i]{y2scale}) ){
                $gnuplot_cmd .= "  unset $plot_info[$plot_i]{y2scale} y2\n";
            }
        }
    }

    # print $file_cmd
    if( ! open( $fh_FILE, ">$file_cmd") ){
        $ierr = 1;
        &print_error( "Cannot open ctf_plot cmd file [$file_cmd]",
                      $ierr );
        exit( $ierr );
    }
    print $fh_FILE $gnuplot_cmd;
    close( $fh_FILE );

    # gnuplot
    if( defined( $GNUPLOT ) ){
        $com = "$GNUPLOT < $file_cmd 2>&1 | grep -v 'Warning: empty'";
        $output = &run_command( COMMAND=>$com, STDOUT=>"", TIMING=>"" );
        $status = $?;
        if( $status != 0 ){
            $ierr = 1;
            &print_error( "Error from gnuplot", $ierr );
            exit( $ierr );
        }
        if( $PS2PDF ne "" && -T $file_ps ){
            $com = "$PS2PDF $file_ps $file_pdf";
            $output = &run_command( COMMAND=>$com, STDOUT=>"" );
            $status = $?;
            if( $status != 0 ){
                $ierr = 1;
                &print_error( "Error from ps2pdf", $ierr );
                exit( $ierr );
            }
            # use gv on ps file if available
            if( defined($args{VIEW}) ){
                if( $VIEWER =~ /gv$/ ){
                    $com = "$VIEWER $file_ps";
                }
                else{
                    $com = "$VIEWER $file_pdf &";
                }
                $output = &run_command( COMMAND=>$com, STDOUT=>"" );
            }
        }
    }

}

########################################################################
# sort "<number><whitespace><string>" based numerically on number
sub numerically_val{
    my(
        $a_val,
        $b_val,
        );
    ($a_val = $a) =~ s/\s+.*//;
    ($b_val = $b) =~ s/\s+.*//;
    $a_val <=> $b_val;
}

# return nodes_max given machine
# run_status.pl -v -> total - down
# data from 2022.11.15
sub ctf_nodes_max{
    my(
        $machine
        ) = @_;
    my(
        $nodes_max
        );
    $nodes_max = 1;
    if( $machine    =~ /SIERRA/ ){
        $nodes_max = 4291;
    }
    elsif( $machine =~ /SNOW/ ){
        $nodes_max = 366;
    }
    elsif( $machine =~ /CYCLONE/ ){
        $nodes_max = 1112;
    }
    elsif( $machine =~ /FIRE/ ){
        $nodes_max = 1095;
    }
    elsif( $machine =~ /ICE/ ){
        $nodes_max = 1097;
    }
    elsif( $machine =~ /RZANSEL/ ){
        $nodes_max = 54;
    }
    elsif( $machine =~ /TRINITITE/ ){
        $nodes_max = 100;
    }
    elsif( $machine =~ /TRINITITE_KNL/ ){
        $nodes_max = 100;
    }
    elsif( $machine =~ /TRINITY/ ){
        $nodes_max = 9357;
    }
    elsif( $machine =~ /TRINITY_KNL/ ){
        $nodes_max = 9976;
    }
    return( $nodes_max );
    
}

# final package return
1;

