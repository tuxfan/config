eval 'exec perl -w -S $0 ${1+"$@"}'
if 0;

# search path for perl modules
use FindBin qw($RealBin);
use lib( grep( -x, "$RealBin", split(":", $ENV{PATH}), "$RealBin/lib", "$RealBin/../lib", @INC, "$RealBin/stub" ) );

use my_utils qw (
                 my_stat_guess
                 print_error
                 ppo
                 );

use ctf_process qw (
                    ctf_read
                    ctf_dump
                    ctf_plot
                    ctf_types
                    ctf_extras
);

use POSIX;

my(
    $ierr,
    $verbose,
    );

$ierr = 0;
$|    = 1;
$DUMP_DEFAULT     = "ctf_dump.txt";
$FILE_SPLIT       = "ctf_dump_split_";
# 10 char max
$DUMP_POP_DEFAULT = "ctfpop.txt";

&parse_args( \@ARGV, \%cmd );

# help
if ( defined( $cmd{h} ) ){
    %requiredh = &ctf_types();
    if( %requiredh ){
        @required = sort values %requiredh;
        $help_required .= "#...\n";
        $help_required .= "#...Required Types Found\n";
        $help_required .= "#...====================\n";
        $help_required .= "#...  ";
        $help_required .= join("\n#...  ", @required );
        $help_required .= "\n";
    }
    %requiredh = &ctf_extras();
    if( %requiredh ){
        @required = sort values %requiredh;
        $help_required .= "#...\n";
        $help_required .= "#...Required Extras Found\n";
        $help_required .= "#...=====================\n";
        $help_required .= "#...  ";
        $help_required .= join("\n#...  ", @required );
        $help_required .= "\n";
    }
    print <<"EOF";
#............................................................................
#...Synopsis
#...========
#...  Process a set of ctf (cycle/time/field) files and plot them.
#...
#...  The files are processed in the order given...so specify the
#...    files in the correct order.  If data is redefined for an earlier
#...    time/cycle, the data listed first is discarded (eg, when you do
#...    a restart and recalculate data, the data printed last wins).
$help_required#...
#...Usage
#...=====
#... ctf_process.pl <options>
#...    [list of files]
#...      List of ctf files.  The files are processed in the order given.
#...    [-h[elp]]
#...      Help info.
#...    [--dir <output directory>]
#...      default = $cmd{dir}
#...      Output directory where various files will be written.
#...    [-(no)d]
#...      Write a text "dump" file.
#...       <field 1>
#...         <cycle>    <time>    <value>
#...       <field 2>
#...         <cycle>    <time>    <value>
#...    [-(no)p]
#...      Default: on
#...      Plot the data.
#...      Implies "-d".
#...    [--split <comma separated list of field regular expressions>]
#...      Take a ctf_dump.txt file and split it into N files:
#...         ctf_dump_split_0.txt:      does not contain those fields
#...         ctf_dump_split_[1..N].txt: one per set of fields
#...      All files will have cycle and time fields.
#...      Useful for when ctf_dump.txt is huge and you want to do
#...      cts_diff.pl diffs on the pieces.
#...      NOTES:
#...        o The max_index and num_fields are no longer correct.
#...          These value are not known until after file header printed.
#...        o The history of how the files are obtained are in the multiple
#...          file_in and split key/value pairs in the file.
#...    [--split_only]
#...      Used with "--split" to signify that the split out files
#...      do not have the separate "cycle" or "time" fields.
#...      As such, they are no longer ctf_dump.txt files and cannot be
#...      further split or processed by ctf_process.pl again.
#...    [--time_range [start time]::[stop time]]
#...      Will restrict to the above time ranges.
#...      "start time" = f:<field>
#...        The start time will be the first time that field has a non-0 value.
#...      time_range done before time_shift
#...    [--time_shift <time>]
#...      Will shift times (positive or negative)
#...      "time" = f:<field>
#...        Will shift time so that the first max found in <field> is time=0
#...      time_range done before time_shift
#...    [--type <type>]
#...      Force file to be processed as a particular type
#...    [--to_pop]
#...      Takes the existing ctf_dump.txt file and generates a
#...      pop-friendlyish file.  Odds are, you will need to copy out
#...      chunks of the file and generate your own pop infile.
#...    [-(no)v]
#...      Default: on
#...      Verbose output
#...    [--(no)view]
#...      Default: on
#...      Bring up a viewer (gv, xpdf, ...) to look at plots.
#...
#... Internal opts: (DO NOT USE)
#...    [--time <time type>]
#...      How to fill the time.
#...      <default>: do not fill time
#...      <full>   : each <field> will have "-" for cycles if not defined.
#...
#...Notes
#...=====
#... o The "types" are searched for in your path.  Add a "reader".
#...
#... o Environment Variable: CTF_VAL_NODES_MAX
#...   When processing rj_batch_out and eap_output files, it will scale
#...   resources used by the amount of nodes on a machine.
#...   This is automatically gotten when processing rj_batch_out or rj_cmd_out
#...   files.  You only need to set this when processing eap -output files.
#...   For example, looking at rj_batch_out files:
#...     days_mach_per_day = machine days gotten per day
#...   Trinity: setenv CTF_VAL_NODES_MAX 9357
#...
#...Examples
#...========
#... o ctf_process.pl rj_adir/rj_cmd_out.*
#...   Parse and plot.
#... o ctf_process.pl outputs/*-output --nop
#...   Parse and just create the "dump".
#... o ctf_process.pl outputs/*-output --nop
#...   ctf_process.pl ctf_dump.txt --split matinfo.+,what_.+
#...   Create ctf_dump.txt and then split it into:
#...      <NOT>     : ctf_dump_split_0.txt
#...      "matinfo" : ctf_dump_split_1.txt
#...      "what_"   : ctf_dump_split_2.txt
#... o ctf_process.pl foo1-tracer  --time_range f:p_1_ne::f:p_10_ne
#...   Look at the foo1-tracer file:
#...     start when particle  1 ne value starts changing
#...     stop  when particle 10 ne value stops  changing
#... o ctf_process.pl foo1-tracer --time_shift f:p_1_ne
#...   Set time=0 when particle 1 reaches its first max.
#... o ctf_process.pl rj_adir/rj_batch_out*
#...   See how you are using machine resources for your trinity haswell job.
#...
#............................................................................
EOF
  exit;
}

# verbose
if( defined($cmd{v}) ){
    $verbose = "  ";
}

# header
if( defined($cmd{v}) ){
    print "\n";
    print "ctf_process.pl\n";
}

# to_pop
#   Blocks of:
#     $ <comment>
#     exp<num>/<field>
#     <time> / <value>
if( defined( $cmd{to_pop} ) ){
    $ctf_dump_file     = "$cmd{dir}/$DUMP_DEFAULT";
    $ctf_dump_pop_file = "$cmd{dir}/$DUMP_POP_DEFAULT";
    $number_regexp = '[+-]?\.?[0-9]+\.?[0-9]*([eE][+-]?\d+)?';
    if( -e $ctf_dump_pop_file ){
        $ierr = 1;
        &print_error( "to_pop: ctf_dump_pop_file exists - remove first:",
                      "  $ctf_dump_pop_file",
                      $ierr );
        exit( $ierr );
    }

    if( ! open($fh_FILE, "$ctf_dump_file" ) ){
        $ierr = 1;
        &print_error( "to_pop: Cannot read ctf_dump_file:",
                      "  $ctf_dump_file",
                      $ierr );
        exit( $ierr );
    }

    if( ! open($fh_FILE_POP, ">$ctf_dump_pop_file" ) ){
        $ierr = 1;
        &print_error( "to_pop: Cannot write to ctf_dump_pop_file:",
                      "  $ctf_dump_pop_file",
                      $ierr );
        exit( $ierr );
    }

    $field = "";
    $exp = 1;
    undef( $header_done );
    undef( $footer_done );
    undef( $in_field );
    while( $line = <$fh_FILE> ){
        $line_new = "";

        # field
        if( $line =~ /^#\s+field\s+=\s+(\S+.*?)\s*$/ ){
            $in_field = "";
            undef( $header_done );
            undef( $footer_done );
            $field = $1;
        }

        # comment
        if( $line =~ /^#/ ){
            $line_new = '$'.$line;
        }
        # blank
        elsif( $line !~ /\S/ ){
            # finish off exp
            if( defined($in_field) && ! defined( $footer_done ) ){
                undef( $in_field );
                $footer_done = "";
                $line_new = "end";
            }
            $line_new .= "\n";
        }
        # data
        elsif( $line =~ /\s*(\S+)\s+(\S+)\s+(\S+)/ ){
            # print header if set
            if( ! defined( $header_done ) ){
                # cannot handle field names > 10 chars
                if( length($field) <= 10 ){
                    $field_use = $field;
                }
                else{
                    $field_use = "exp$exp";
                }
                # cannot handle internal "/"
                $field_use =~ s&/&_&g;
                $header_done = "";
                print $fh_FILE_POP "exp$exp/$field_use\n";
                # point to next exp
                $exp++;
            }
            $time = $2;
            $val  = $3;
            $line_new = "";
            if( $val =~ /^${number_regexp}$/ ){
                $line_new .= "$time / $val\n";
            }
        }
       
        print $fh_FILE_POP $line_new;
        
    }

    close( $fh_FILE_POP );
    close( $fh_FILE );

}

# split
if( defined($cmd{split}) ){
    # file_in needs to be in current directory and named ctf_dump.txt
    $file_in      = $cmd{f}[0];

    # file_in: open
    if( ! open($fh_FILE_IN, $file_in) ){
        $ierr = 1;
        &print_error( "Cannot open input split file_in=$file_in",
                      $ierr );
        exit( $ierr );
    }
    # file_in: check first line
    $out = `head -1 $file_in 2>&1`;
    if( $out !~ /^# ctf_process\s*$/ ){
        $ierr = 1;
        &print_error( "Input split file_in=$file_in must be a ctf_dump.txt file.",
                      "Run 'ctf_process.pl <file list>' to first generate a ctf_dump.txt",
                      "file then run 'split' on that file.",
                      $ierr );
        exit( $ierr );
    }

    # files_split[] = names of files
    $i = 0;
    foreach ( @{$cmd{split}} ) {
        $files_split[$i] = "$cmd{dir}/${FILE_SPLIT}$i.txt";
        $i++;
    }

    # check for files_split
    $i = 0;
    foreach $file_split ( @files_split ) {
        if( -e $file_split ){
            $ierr = 1;
            &print_error( "Output split file [$file_split] already exists",
                          $ierr );
            exit( $ierr );
        }
    }

    # open files_split
    $i = 0;
    foreach $file_split ( @files_split ) {
        if( ! open($fh_FILES_SPLIT[$i], ">$files_split[$i]") ){
            $ierr = 1;
            &print_error( "Cannot open output split file_split [$file_split]",
                          $ierr );
            exit( $ierr );
        }
        $i++;
    }

    # init index
    $i = 0;
    foreach $file_split ( @files_split ) {
        $index[$i] = -1;
        $i++;
    }

    # read/print file header
    undef( $done );
    $out = "";
    while( ! defined($done) ){
        $line = <$fh_FILE_IN>;
        $out .= $line;
        if( $line !~ /\S/ ){
            last;
        }
    }

    # make max_index and num_fields negative since cannot put in real number
    # without rewriting whole file again (and file could be HUGE)
    $out =~ s/(max_index.*=\s+)\-?(\d+)/${1}-${2}/;
    $out =~ s/(num_fields.*=\s+)\-?(\d+)/${1}-${2}/;
    
    # remove starting stuff and file_name, ending separator
    $out =~ s/^# ctf_process.*\s*#+\s*#(\s+)(file_name\s+)=\s+.*\s*//;
    $spaces_start = $1;
    $len_field = length($2);
    $out =~ s/#+\s*$//;

    # top
    $out_1 = "# ctf_process\n###################################\n";

    # file_name
    $field = "file_name";
    $spaces = " " x ($len_field - length($field));
    $i = 0;
    foreach $file_split ( @files_split ){ 
        $out_2[$i] = "#${spaces_start}${field}${spaces}= $file_split\n";
        $i++;
    }

    # file_in
    $field = "file_in";
    $spaces = " " x ($len_field - length($field));
    $out_3 = "#${spaces_start}${field}${spaces}= $file_in\n";

    # split
    $field  = "split";
    $spaces = " " x ($len_field - length($field));
    $i = 0;
    foreach $file_split ( @files_split ){
        $split = $cmd{split}[$i];
        if( $split eq "<NOT>" ){
            $split = join(",",@{$cmd{split}});
            $split =~ s/,/ /;
        }
        $out_4[$i] = "#${spaces_start}${field}${spaces}= $split\n";
        $i++;
    }

    # end
    $out_5 = "###################################\n";

    # and print
    $i = 0;
    foreach $file_handle ( @fh_FILES_SPLIT ){
        # if split_only, then the non <NOT> files do not have cycle/time
        # fields and are to ctf_process files.
        $out_1 = "# ctf_process\n###################################\n";
        if( defined( $cmd{split_only} ) && $i > 0 ){
            $out_1 = "# split_only ctf_process\n###################################\n";
        }
        print $file_handle $out_1, $out_2[$i], $out, $out_3, $out_4[$i], $out_5;
        $i++;
    }

    undef( $done );
    while( 1==1 ){

        # ------------
        # field header
        # ------------
        $out = "";
        while( 1==1 ){
            $line = <$fh_FILE_IN>;
            if( ! defined($line) ){
                last;
            }
            $out .= $line;
            if( $line !~ /\S/ ){
                last;
            }
        }

        # get field
        if( $out =~ /^# field\s+=\s+(\S.*?)\s*$/m ){
            $field = $1;
        }

        # $printit{split file num} = <defined> == yes
        undef( %printit );
        # both get cycle/time fields
        if( $field eq "cycle" || $field eq "time" ){
            $i = 0;
            foreach $file_split ( @files_split ){
                # <NOT> has these
                if( $i == 0 ){
                    $printit{$i} = "";
                }
                else{
                    # do not include cycle/time for split_only
                    if( ! defined( $cmd{split_only} ) ){
                        $printit{$i} = "";
                    }
                    else{
                        # if cycle/time matches the split, still print
                        if( $field =~ /^($cmd{split}[$i])$/ ){
                            $printit{$i} = "";
                        }
                    }
                }
                $i++;
            }
        }
        else{
            $i = 0;
            undef( $found );
            foreach $file_split ( @files_split ){
                if( $field =~ /^($cmd{split}[$i])$/ ){
                    $found = "";
                    $printit{$i} = "";
                }
                $i++;
            }
            # if not found, then "<NOT>"
            if( ! defined($found) ){
                $printit{0} = "";
            }
        }
        
        # if writing to that split file,
        #   index[split file num]++ (index number of that field to write)
        foreach $split_file_num ( keys %printit ){
            $index[$split_file_num]++;
        }

        # print field header
        foreach $split_file_num ( keys %printit ){
            $out =~ s/^(# index\s+=\s+)(\S+)\s*$/$1$index[$split_file_num]/m;
            $file_handle = $fh_FILES_SPLIT[$split_file_num];
            print $file_handle "\n", $out;
        }

        # should just be blank line...but just in case old files
        # have data here, do the subst and print again (no extra
        # \n this time.
        $out = "";
        while( 1==1 ){
            $line = <$fh_FILE_IN>;
            if( ! defined($line) ){
                last;
            }
            if( $line !~ /\S/ ){
                last;
            }
            $out .= $line;
        }

        foreach $split_file_num ( keys %printit ){
            $out =~ s/^(# index\s+=\s+)(\S+)\s*$/$1$index[$split_file_num]/m;
            $file_handle = $fh_FILES_SPLIT[$split_file_num];
            print $file_handle $out;
        }

        # no more lines
        if( ! defined($line) ){
            last;
        }

    }

    # close
    close( $fh_FILE_IN );
    $i = 0;
    foreach $file_handle ( @fh_FILES_SPLIT ){
        close( $file_handle );
        $i++;
    }

    $i = 0;
    foreach $file_split ( @files_split ){
        print "  $files_split[$i]\n";
        print "    split      = $cmd{split}[$i]\n";
        print "    num_fields = ",$index[$i] + 1,"\n";
        $i++;
    }

}

# process files
if( $#{$cmd{f}} >= 0 && ! defined($cmd{split})){
    $type = $cmd{type};
    if( defined($cmd{lines}) ){
        $files_all = join(" ", @{$cmd{f}});
        $cat_all = `cat $files_all`;
        @lines = split( /\n/, $cat_all );
        $ierr = &ctf_read( LINES=>\@lines, VALS=>\%vals, TIME=>$cmd{time},
                           TYPE=>\$type, VERBOSE=>$verbose, CMD=>\%cmd );
    }
    else{
        $ierr = &ctf_read( FILES=>\@{$cmd{f}}, VALS=>\%vals, TIME=>$cmd{time},
                           TYPE=>\$type, VERBOSE=>$verbose, CMD=>\%cmd );
    }
    
    if( ! defined($ierr) ){
        $ierr = 1;
        &print_error( "Could not find a reader for your files.",
                      $ierr );
        exit( $ierr );
    }
    
    # send to file
    if( defined($cmd{d}) ){
        &ctf_dump( DIR=>$cmd{dir}, VALS=>\%vals, FILE_INFO=>\%file_info,
                   VERBOSE=>$verbose );
        if( defined($cmd{v}) && $file_info{num_fields} == 0 ){
            $ierr = 0;
            &print_error( "Did not print any data to file.",
                          $ierr );
        }
    }
    
    # and plot it
    if( defined($cmd{p}) && $file_info{num_fields} > 0 ){
        &ctf_plot( DIR=>$cmd{dir}, FILE_INFO=>\%file_info, VIEW=>$cmd{view},
                   VERBOSE=>$verbose );
    }
}
    
if( defined($cmd{v}) ){
    print "\n";
}

exit( $ierr );

########################################################################
# parse ARGV into cmd_ref
sub parse_args {
    my(
        $argv_ref,
        $cmd_ref
        ) = @_;
    my(
        @args, # arguments
        $ierr, # error ret val
        $num_args, # number of arguments
        $opt, # current option
        %types_processed,
        @types_processed_array,
        $unset,
        $val, # value for current option
        @vals,
        );
    $ierr = 0;
    @args = @{$argv_ref};

    # default
    $$cmd_ref{d}    = "";
    $$cmd_ref{p}    = "";
    $$cmd_ref{v}    = "";
    $$cmd_ref{view} = "";

    # parse each arg
    $num_args = $#args + 1;
    while( @args ) {

        $opt = shift( @args );

        # help
        if( $opt =~ /^-+(h(elp)?)$/i ) {
            $opt = "h";
            $$cmd_ref{$opt} = "true";
        }

        # -(no)<opt>
        elsif( $opt =~ /^-+(no)?(d|p|v|view)$/ ){
            $unset  = $1;
            $opt    = $2;
            if( defined($unset) ){
                delete( $$cmd_ref{$opt} );
            }
            else{
                $$cmd_ref{$opt} = "";
            }
        }
        
        # --opt
        elsif( $opt =~ /^--(lines|to_pop|split_only)$/ ){
            $opt = $1;
            $$cmd_ref{$opt} = "";
        }

        # -opt <val>
        elsif( $opt =~ /^-(skip for now)$/ ){
            $opt = $1;
            if( ! @args ) {
                $ierr = 1;
                &print_error( "Value needed for option [--$opt].",
                              $ierr );
                exit( $ierr );
            }
            $val = shift( @args );
            $$cmd_ref{$opt} = $val;
        }

        # --opt <val>
        elsif( $opt =~ /^--(dir|time|time_range|time_shift)$/ ){
            $opt = $1;
            if( ! @args ) {
                $ierr = 1;
                &print_error( "Value needed for option [--$opt].",
                              $ierr );
                exit( $ierr );
            }
            $val = shift( @args );
            $$cmd_ref{$opt} = $val;
        }

        # --type <type>
        elsif( $opt =~ /^--(type)$/ ){
            $opt = $1;
            if( ! @args ) {
                $ierr = 1;
                &print_error( "Value needed for option [--$opt].",
                              $ierr );
                exit( $ierr );
            }
            $val = shift( @args );
            %types_processed = &ctf_types();
            @types_processed_array = sort keys %types_processed;
            grep( s/^/  /, @types_processed_array );
            if( ! defined($types_processed{$val}) ){
                $ierr = 1;
                &print_error("Could not find type [$val]",
                             "Valid types:",
                             @types_processed_array,
                             $ierr );
                exit( $ierr );
            }
            $$cmd_ref{$opt} = $val;
        }

        # --split <vals>
        elsif( $opt =~ /^--(split)$/ ){
            $opt = $1;
            if( ! @args ) {
                $ierr = 1;
                &print_error( "Value needed for option [--$opt].",
                              $ierr );
                exit( $ierr );
            }
            $val = shift( @args );
            @vals = split(/\s*,\s*/, $val);
            push( @{$$cmd_ref{$opt}}, @vals );
        }

        # other args
        else{

            # if --, all rest are other args
            if( $opt eq "--" ){
                if( ! @args ) {
                    $ierr = 1;
                    &print_error( "Arguments expected after [$opt].",
                                  $ierr );
                    exit( $ierr );
                }
                push( @{$$cmd_ref{f}}, @args );
                next;
            }

            # no previously parsed "-" arg
            elsif( $opt =~ /^-/ ){
                $ierr = 1;
                &print_error( "Unrecognized argument that starts with '-' [$opt]",
                              "If your filename starts with '-', shame on you and use:",
                              "  '--' <remaining args are the file list>",
                              $ierr );
                exit( $ierr );
            }

            # push onto file list
            push( @{$$cmd_ref{f}}, $opt );
        }
    }

    # if no args or no files
    if( $num_args == 0 ||
        ( $#{$$cmd_ref{f}} < 0 &&
          ! defined($$cmd_ref{to_pop}) ) ){
        $$cmd_ref{h} = "true";
    }

    # split
    if( defined($$cmd_ref{split}) ){
        # split requires exactly 1 file
        if( $#{$$cmd_ref{f}} != 0 ){
            $ierr = 1;
            &print_error( "The 'split' arg requires specifying exactly 1 ctf_dump.txt file.",
                          $ierr );
            exit( $ierr );
        }
        # first split is actually <NOT>
        unshift( @{$$cmd_ref{split}}, "<NOT>" );
    }

    # split_only requires split
    if( defined($$cmd_ref{split_only}) &&
        ! defined($$cmd_ref{split}) ){
        $ierr = 1;
        &print_error( "The 'split_only' arg requires specifying 'split' arg as well.",
                      $ierr );
        exit( $ierr );
    }

    # dir
    if( ! defined($$cmd_ref{dir}) ){
        $$cmd_ref{dir} = ".";
    }
    if( ! defined($$cmd_ref{h}) && ! -w $$cmd_ref{dir} ){
        $ierr = 1;
        &print_error( "Cannot write to output directory [$$cmd_ref{dir}]",
                      "Use '--dir <directory>' to change output dir",
                      $ierr );
        exit( $ierr );
    }

    # if doing to_pop, cannot have any files given (post-processing only)
    if( ! defined($$cmd_ref{h} ) ){
        if( defined($$cmd_ref{to_pop}) && $#{$$cmd_ref{f}} >= 0 ){
            $ierr = 1;
            &print_error( "Arg 'to_pop' can only be used to post-process the dump.",
                          "Run without the 'to_pop' arg first",
                          $ierr );
            exit( $ierr );
        }
    }

    return( $ierr );
}
