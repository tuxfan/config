########################################################################
# Type=sap_output
#   file fed into ctf_process.pm
#
# NOTE:
#   See cts_process.pm: "Internal Interface"
#
# File Format:
# ------------
#   sap
#
########################################################################

use ctf_process_util qw(
                        ctf_vals_add
                        ctf_vals_add_segment
                        ctf_vals_add_segment_ctf
                        ctf_vals_splice
                        ctf_vals_check
                        ctf_fill_time
                       );

########################################################################
# Required routine: ctf_read_sap_output
sub ctf_read_sap_output{
    # Argument checking has already been done
    # FILES : each exists and is readable
    # VALS  : is reference to empty hash
    my %args = (
        FILES      => undef, # ref to array of files
        LINES      => undef, # if given the lines array already
        VALS       => undef, # ref to hash result (will init)
        VERBOSE    => undef, # if verbose
        CHECK_ONLY => undef, # if only want to check filetype
        FORCE      => undef, # if should force the read
        @_,
        );
    my( $args_valid ) = "CHECK_ONLY|FILES|FORCE|LINES|VALS|VERBOSE";
    my(
        $arg,
        %ctf_extras_required,
        $cycle,
        $data_found,
        $done,
        $dt,
        $empty,
        $empty_len,
        $eval_error,
        $extra_routine,
        $extra,
        $extras_called,
        $field,
        $field1,
        $field2,
        @fields,
        @fields_metrics,
        $file,
        $file_num,
        $file_num_max,
        $file_top,
        $files_ref,
        $force,
        $i,
        $ierr,
        $label,
        $line,
        $lines_not_processed,
        $lines_ref,
        $ln,
        $ln_max,
        $ln_file_top,
        $matname,
        %matnames,
        $matnum,
        $num_files_try_max,
        $rest,
        $spaces,
        %state,
        $time,
        $time_short,
        $type,
        $val,
        $val1,
        $val2,
        %vals,
        @vals_a,
        $vals_ref,
        $verbose,
        );

    # Error return value
    # If cannot read this type of file, $ierr = undef
    $ierr = 0;

    %ctf_extras_required =  &ctf_extras();

    # SKIP THIS CHECK UNLESS THIS FILE ACTIVELY MAINTAINED WITH:
    #   ctf_process.pm/ctf_process.pl
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

    # either of these specify where data is
    $files_ref = $args{FILES};
    $lines_ref = $args{LINES};
    $force     = $args{FORCE};
    $verbose   = $args{VERBOSE};

    # output
    $vals_ref  = $args{VALS};

    # look through files
    # only look through this number of files
    $num_files_try_max = 2;
    if( defined($files_ref) ){
        $num_files_try_max = $#{$files_ref};
        if( $#{$files_ref} < $num_files_try_max ){
            $num_files_try_max = $#{$files_ref};
        }
    }
    $file_num = 0;
    $ln_max = 100;
    $ln = 0;
    undef( $done );
    # use ierr as check - so undefine it
    undef( $ierr );
    undef( $done );
    if( defined($force) ){
        $done = "";
        $ierr = 0;
    }
    while( ! defined($done) ){
        undef( $file );

        # $lines_ref = file handle or reference to array
        if( defined($files_ref) ){
            $file = $$files_ref[$file_num];
            if( ! open( $lines_ref, "$file" ) ){
                $ierr = 1;
                &print_error( "Cannot open $file" );
                exit( $ierr );
            }
        }
        else{
            # lines_ref already set
            $num_files_try_max = 0;
        }
        $file_num++;

        # read in $file_top ($ln_max lines of file)
        $file_top = "";
        $ln_file_top = 0;
        while(1==1){
            if( ref($lines_ref) eq "ARRAY" ){
                $line = $$lines_ref[$ln]; $ln++;
            }
            else{
                $line = <$lines_ref>;
                if( ! defined($line) ){
                    last;
                }
                $ln = length($line);
            }
            # done
            if( ! defined($line) ){
                last;
            }
            if( $line !~ /\S/ ){
                next;
            }
            # skip
            if( $line =~ /^\s*RJ_OUTPUT:/ ){
                next;
            }
            # skip
            if( $line =~ /^\s*run_job\.pl/ ){
                next;
            }
            # skip
            if( $line =~ /rj_cmd/ ){
                next;
            }
            # skip
            if( $line =~ /^\s*App launch reported/ ){
                next;
            }
            # skip
            if( $line =~ /\s*bound to socket/ ){
                next;
            }
            $file_top .= $line;
            $ln_file_top++;
            if( $ln_file_top > $ln_max ){
                last;
            }
            
        }
        # close if opened
        if( ref($lines_ref) ne "ARRAY" ){
            close( $lines_ref );
        }

        # if still looking, search for this
        # looks to be some sort of header line
        if( $file_top =~ /
            ^\s*
            METRICS\s+
            Date\s+
            TotPEs\s+
            Step\s+
            Time\s+
            /mx ){
            $ierr = 0;
            last;
        }

        # other matches
        if( $file_top =~ /SAP_MSG/ ||
            $file_top =~ /Silverton code project/ ){
            $ierr = 0;
            last;
        }

        # no more files
        if( $file_num > $num_files_try_max ){
            last;
        }

    }

    # now know if correct filetype
    if( ! defined($ierr) || defined($args{CHECK_ONLY}) ){
        return( $ierr );
    }

    # will read file if got to here

    # now set ierr
    $ierr = 0;

    # init for file processing
    $file_num     = 0;
    # files
    if( defined( $files_ref ) ){
        $file_num_max = $#$files_ref + 1;
    }
    # lines
    else{
        $file_num_max = 1;
    }
    if( defined($args{VERBOSE}) ){
        print "$args{VERBOSE}ctf_process_type_sap_output\n";
        print "$args{VERBOSE}  file_num_max        = $file_num_max\n";
        # will only print status_bar for files
        if( $file_num_max > 1 ){
            print "$args{VERBOSE}  ";
        }
    }

    # for keeping track of extra overhead (each lines_not_processed is a
    # wasted EXPENSIVE call to extras...
    $lines_not_processed = 0;
    $extras_called       = 0;

    # process each file
    undef( $done );
    while( ! defined($done) ){

        $file_num++;

        # if last file
        if( $file_num > $file_num_max ){
            last;
        }

        # file_num_max>1 : status per file
        if( defined($args{VERBOSE}) ){
            if( $file_num_max > 1 ){
                &status_bar( $file_num, $file_num_max );
            }
        }

        # init new stuff from file
        # keep state around
        #undef( %state );

        # $lines_ref = file handle or reference to array
        if( defined($files_ref) ){
            $file = $$files_ref[$file_num-1];
            if( ! open( $lines_ref, "$file" ) ){
                $ierr = 1;
                &print_error( "Cannot open $file" );
                exit( $ierr );
            }
        }
        else{
            # lines_ref already set
        }

        # process each line
        undef( %vals );
        $ln = 0;

        undef($done);
        # reset that data was found
        undef( $data_found );
        while( ! defined($done) ){

            &read_next_line( $lines_ref, \$line, \$ln );
            if( ! defined( $line ) ){
                last;
            }

            # debugging print to detect if cycle stored but no time
            #($line_new = $line) =~ s/\s*$//;
            #print "block $ln c=$#{$$vals_ref{cycle}{val}} t=$#{$$vals_ref{time}{val}} $line_new\n";
            
            # current block line
            #print "block: $ln $line";

            # blank
            if( $line !~ /\S/ ){
                next;
            }

            # step block (cycle)
            if( $line =~ /^\s*
                          Step\s+(\d+)\s+
                          t\s+=\s+(\S+)\s+
                          dt\s+=\s+(\S+)
                         /x ){
                $data_found = "";
                $cycle = $1;
                $time  = $2;
                $dt    = $3;
                $vals{time}  = $time;
                $vals{cycle} = $cycle;
                $vals{dt}    = $dt;

                # dt info
                undef( $done );
                while( ! defined( $done ) ){

                    &read_next_line( $lines_ref, \$line, \$ln );
                    if( ! defined( $line ) ){
                        last;
                    }

                    if( $line !~ /\S/ ){
                        last;
                    }

                    # not a "dt{blah} = " line
                    if( $line !~ /(dt(\S+))\s*=/ ){

                        # back up one line
                        if( ref($lines_ref) eq "ARRAY" ){
                            $ln--;
                        }
                        else{
                            seek($lines_ref, -$ln, 1);
                        }
                        last;
                    }

                    while( $line =~ /(dt(\S+))\s*=\s*(\S+)(.*)/ ){
                        $line = $4;
                        $field = "dt:$1";
                        $val = $3;
                        $vals{$field} = $val;
                    }

                }

            }

            # METRICS block: header
            elsif( $line =~ /^METRICS\s+.*Date/ ){
                @fields_metrics = split(/\s+/, $line );
                next;
            }
            # METRICS block: vals
            elsif( $line =~ /^METRICS\s+.*_at_/ ){
                # 2023.02.21
                #   mismatch of values printed.
                #   Step == to match time, should be Step++
                #   Time(Step+1) == short edit time value
                #   dt(step) == previous time step value
                #   setting cycle number to next and storing time.
                $data_found = "";
                @vals_a = split( /\s+/, $line );
                $i = -1;
                foreach $val ( @vals_a ){
                    $i++;
                    $field = $fields_metrics[$i];
                    if( $field eq "METRICS" ){
                        next;
                    }
                    if( $field eq "Step" ){
                        # in general, looks like this is actually next cycle
                        $val++;
                        $field = "cycle";
                    }
                    elsif( $field eq "Time" ){
                        # skip until above mismatch resolved
                        $field = "time";
                    }
                    elsif( $field eq "dt" ){
                        # this is dt of the previous cycle
                        # skip until above mismatch resolved
                        next;
                    }
                    else{
                        # prepend with METRICS:
                        $field = "METRICS:$field";
                    }
                    $vals{$field} = $val;
                }
            }

            # Short Edit
            elsif( $line =~ /^t\s*=\s*(\S+)\s+Short\s+Edit$/ ){
                # keep track of time the short edit has
                $time_short = $1;
                # has time, but do not know cycle...so just skip
                next;
            }

            # table: Matname Volume Mass Energy IE KE Source
            elsif( $line =~ /Matname\s+Volume\s+Mass/ ){
                @fields = split( /\s+/, $line );

                &read_next_line( $lines_ref, \$line, \$ln );
                if( ! defined( $line ) ){
                    last;
                }

                # read block
                while( ! defined( $done ) ){

                    &read_next_line( $lines_ref, \$line, \$ln );
                    if( ! defined( $line ) ){
                        last;
                    }

                    # first blank line
                    if( $line !~ /\S/ ){
                        next;
                    }

                    # strip beginning/ending whitespace
                    $line =~ s/^\s+//;
                    $line =~ s/\s+$//;

                    # split and put into vals
                    @vals_a = split( /\s+/, $line );
                    # first is number
                    if( $line !~ /^Totals\s+/ ){
                        $matnum = shift( @vals_a );
                    }

                    &matname_with_spaces( FIELDS=>\@fields, VALS=>\@vals_a );

                    $i = -1;
                    foreach $val ( @vals_a ){
                        $i++;
                        $field = $fields[$i];
                        if( $field eq "Matname" ){
                            $matname = $val;
                            $matnames{$matnum} = $matname;
                            next;
                        }
                        $field = "MAT:${matname}:${fields[$i]}";
                        $vals{$field} = $val;
                    }

                    # done if hit Totals
                    if( $line =~ /Totals\s+/ ){
                        last;
                    }

                } # read block
                
                # do not know cycle
                next;

            } # table: Matname Volume Mass Energy IE KE Source

            # table: Matname Plastic Elastic
            elsif( $line =~ /Matname\s+Plastic\s+Elastic/ ){
                @fields = split( /\s+/, $line );

                # Work Distortion
                &read_next_line( $lines_ref, \$line, \$ln );
                if( ! defined( $line ) ){
                    last;
                }

                # Plastic -> Plastic_Distortion
                grep( s/Plastic/Plastic_Distortion/, @fields );

                # blank
                &read_next_line( $lines_ref, \$line, \$ln );
                if( ! defined( $line ) ){
                    last;
                }

                # read block
                while( ! defined( $done ) ){

                    &read_next_line( $lines_ref, \$line, \$ln );
                    if( ! defined( $line ) ){
                        last;
                    }

                    # first blank line
                    if( $line !~ /\S/ ){
                        next;
                    }

                    # strip beginning/ending whitespace
                    $line =~ s/^\s+//;
                    $line =~ s/\s+$//;

                    # split and put into vals
                    @vals_a = split( /\s+/, $line );
                    # first is number
                    if( $line !~ /^Totals\s+/ ){
                        $matnum = shift( @vals_a );
                    }
                    &matname_with_spaces( FIELDS=>\@fields, VALS=>\@vals_a );
                    $i = -1;
                    foreach $val ( @vals_a ){
                        $i++;
                        $field = $fields[$i];
                        if( $field eq "Matname" ){
                            $matname = $val;
                            $matnames{$matnum} = $matname;
                            next;
                        }
                        $field = "MAT:${matname}:${fields[$i]}";
                        $vals{$field} = $val;
                    }

                    # done if hit Totals
                    if( $line =~ /Totals\s+/ ){
                        last;
                    }

                } # read block

                # do not know cycle
                next;
                
            } # table: Matname Plastic Elastic

            # table: Matname Mass Melted
            elsif( $line =~ /Matname\s+Mass\s+Melted/ ){
                @fields = ( "Matname", "Mass_Melted" );

                # blank
                &read_next_line( $lines_ref, \$line, \$ln );
                if( ! defined( $line ) ){
                    last;
                }

                # read block
                while( ! defined( $done ) ){

                    &read_next_line( $lines_ref, \$line, \$ln );
                    if( ! defined( $line ) ){
                        last;
                    }

                    # done if hit blank (no totals?)
                    if( $line !~ /\S/ ){
                        last;
                    }

                    # split and put into vals
                    @vals_a = split( /\s+/, $line );
                    # first is number
                    if( $line !~ /^Totals\s+/ ){
                        $matnum = shift( @vals_a );
                    }
                    &matname_with_spaces( FIELDS=>\@fields, VALS=>\@vals_a );
                    $i = -1;
                    foreach $val ( @vals_a ){
                        $i++;
                        $field = $fields[$i];
                        if( $field eq "Matname" ){
                            $matname = $val;
                            $matnames{$matnum} = $matname;
                            next;
                        }
                        $field = "MAT:${matname}:${field}";
                        $vals{$field} = $val;
                    }

                    # done if hit blank (no totals?)
                    if( $line !~ /\S/ ){
                        last;
                    }

                    # done if hit Totals
                    if( $line =~ /Totals\s+/ ){
                        last;
                    }

                } # read block

                # do not know cycle
                next;
                
            } # table: Matname Mass Melted

            # table: Matname Mass Burned
            elsif( $line =~ /Matname\s+Mass\s+Burned/ ){
                @fields = ( "Matname", "Mass_Burned" );

                # blank
                &read_next_line( $lines_ref, \$line, \$ln );
                if( ! defined( $line ) ){
                    last;
                }

                # read block
                while( ! defined( $done ) ){

                    &read_next_line( $lines_ref, \$line, \$ln );
                    if( ! defined( $line ) ){
                        last;
                    }

                    # skip blank lines
                    if( $line !~ /\S/ ){
                        next;
                    }

                    # split and put into vals
                    @vals_a = split( /\s+/, $line );
                    # first is number
                    if( $line !~ /^Totals\s+/ ){
                        $matnum = shift( @vals_a );
                    }
                    $i = -1;
                    &matname_with_spaces( FIELDS=>\@fields, VALS=>\@vals_a );
                    foreach $val ( @vals_a ){
                        $i++;
                        $field = $fields[$i];
                        if( $field eq "Matname" ){
                            $matnames{$matnum} = $matname;
                            $matname = $val;
                            next;
                        }
                        $field = "MAT:${matname}:${field}";
                        $vals{$field} = $val;
                    }

                    # done if hit Totals
                    if( $line =~ /Totals\s+/ ){
                        last;
                    }

                } # read block

                # do not know cycle
                next;
                
            } # table: Matname Mass Burned

            # Total (mass lost, energy...lost, kinetic energy dissipated, ...)
            elsif( $line =~ /^(Total\s+(.*?))\s+=\s+(\S+)/ ){

                $field = $1;
                $val   = $3;

                # make $field more search friendlyu
                # spaces
                $field =~ s/\s+/_/g;
                # just remove parens
                $field =~ s/[()]//g;
                # + -> plus
                $field =~ s/\+/_plus_/g;

                # and put into vals
                $vals{$field} = $val;

                # do not know cycle
                next;

            }

            # Generic fields: Min/Max Array Values & Locations
            elsif( $line =~ /Matname\s+/ ){
                @fields = split(/\s+/, $line);
                # do not know cycle
                next;
            }

            # values: Min/Max Array Values & Locations
            elsif( $line =~ /^\d+\s+.*\s+((min|max) (mixed|pure)) (.*)$/ ){
                $rest = $4;
                if( $rest !~ /^
                               (\s*
                                (
                                 \S+\s+      # value
                                 \([^\)]+\)   # ( coords )
                                )
                               )+
                              \s*$/x ){
                    # does not match, so go to next line
                    next;
                }

                # hack for empty columns
                # if you see enough whitespace, stick in dummy fields
                $empty_len = 38;
                $empty = " - (-)";
                $spaces = " "x(($empty_len - length($empty))/2);
                $line =~ s/ {$empty_len}/${spaces}${empty}${spaces}/g;

                # strip out coords
                $line =~ s/\([^\)]+\)//g;
                # strip out first digits
                $line =~ s/^(\d+)\s+//;
                if( defined($1) ){
                    $matnum = $1;
                }

                &matname_with_spaces( LINE=>\$line );

                # underscore (eg, min mixed -> min_mixed)
                $line =~ s/(min|max)\s+(mixed|pure)/${1}_${2}/;

                @vals_a = split( /\s+/, $line );
                $i = -1;
                foreach $val ( @vals_a ){
                    $i++;
                    # matname
                    if( $i == 0 ){
                        $matname = $val;
                        $matnames{$matnum} = $matname;
                        next;
                    }
                    # min_mixed, max_mixed, ... 
                    if( $i == 1 ){
                        $type = $val;
                        next;
                    }
                    $label = $fields[$i-1];
                    $field = "Min_Max:${matname}:${type}:${label}";
                    $vals{$field} = $val;
                }

                # do not know cycle
                next;
                
            } # values: Min/Max Array Values & Locations

            # Mixed-Cell Data: Npure, Nmixd, skip "Total 
            elsif( $line =~ /^(Npure|Nmixd)\s+=\s+(\S+)\s+
                              ((Max|Avg)\s+components\S+)\s+=\s+(\S+)$/x ){
                $field1 = $1;
                $val1   = $2;
                $field2 = $3;
                $val2   = $5;
                # whitespace
                $field2 =~ s/\s+/_/g;
                # vals have "," in them
                $val1 =~ s/,//g;
                $val2 =~ s/,//g;
                
                # stuff into vals
                $vals{"Mixed-Cell_Data:$field1"} = $val1;
                $vals{"Mixed-Cell_Data:$field2"} = $val2;

                # do not know cycle
                next;

            } # Mixed-Cell Data: Npure, Nmixd, skip "Total 
            
            # table: Mixed-Cell Data: mat Pure Mixed, mat Volume-Fraction
            elsif( $line =~ /^mat\s+Pure\s+Mixed$/ ||
                   $line =~ /^mat\s+Volume-Fraction$/ ){
                @fields = split( /\s+/, $line );

                # blank
                &read_next_line( $lines_ref, \$line, \$ln );
                if( ! defined( $line ) ){
                    last;
                }

                # read block
                while( ! defined( $done ) ){

                    &read_next_line( $lines_ref, \$line, \$ln );
                    if( ! defined( $line ) ){
                        last;
                    }

                    # done next blank line
                    if( $line !~ /\S/ ){
                        last;
                    }

                    # split and put into vals
                    @vals_a = split( /\s+/, $line );
                    $i = -1;
                    foreach $val ( @vals_a ){
                        $val =~ s/,//g;
                        $i++;
                        $field = $fields[$i];
                        if( $field eq "mat" ){
                            # replace matnum -> matname
                            $matname = $matnames{$val} || $val;
                            next;
                        }
                        $field = "Mixed-Cell_Data:${matname}:${field}";
                        $vals{$field} = $val;
                    }

                } # read block

                # do not know cycle
                next;
                
            } # table: Mixed-Cell Data: mat Pure Mixed, mat Volume-Fraction

            # Graphics Output
            elsif( $line =~
                   /^
                     Graphics\s+Output\s+finished \s+at:.*
                     using\s+a\s+total\s+of\s+(\S+)
                   /x ){
                $vals{"IO:Graphics:Time"} = $1;
                # do not know cycle
                next;
            }

            # Dump Output
            elsif( $line =~
                   /^
                     Restart\s+dump\s+written\s+at\s+(\S+)\s+(\S+)\/sec\s+
                     \(
                       \s*(\S+)\s+\S+;\s+
                       (\S+)\s+seconds\s*
                     \)
                   /x ){
                $vals{"IO:Dump:Write:Rate"} = $1;
                $vals{"IO:Dump:Write:Size"} = $3;
                $vals{"IO:Dump:Write:Time"} = $4;
                $vals{"IO:Dump:Write:Size"} =~ s/,//g;
                # do not know cycle
                next;
            }

            # ToDo: Memory Usage Statistics: other stuff
            # ToDo: Summary of EXCLUSIVE Timing Calipers
            # ToDo: Summary of INCLUSIVE Timing Calipers
            elsif( $line =~ /Summary of (EXCLUSIVE|INCLUSIVE) Timing Calipers/ ||
                   $line =~ /^\s*Memory Usage Statistics\s*$/ ){
                undef( $done );
                # read block
                while( ! defined( $done ) ){

                    &read_next_line( $lines_ref, \$line, \$ln );
                    if( ! defined( $line ) ){
                        last;
                    }
                    if( $line !~ /\S/ ){
                        last;
                    }
                }
            }


            # call extra routines
            else{
                delete( $state{processed} );
                delete( $state{data_found} );
                $state{ln}             = $ln;
                $state{line}           = $line;
                foreach $extra ( sort keys %ctf_extras_required ){
                    if( $extra =~ /(sap_output_.*)/ ){
                        $extras_called++;
                        $extra_routine = "ctf_read_${1}";
                        $eval_error = eval "\$ierr = &$extra_routine( LINES=>\$lines_ref, VALS=>\$vals_ref, VALS_THIS=>\\\%vals, STATE=>\\\%state, VERBOSE=>\$verbose )";
                        # error stored into $@
                        if( $@ || $ierr != 0 ){
                            $ierr = 1;
                            &print_error( "Error from $extra_routine :",
                                          $@, $ierr );
                            exit( $ierr );
                        }
                        # this mimics a "elsif" - if processed, then do not do other extra
                        if( defined($state{processed}) ){
                            # copy back state
                            $ln         = $state{ln};

                            # back up one line
                            if( ref($lines_ref) eq "ARRAY" ){
                                $ln--;
                            }
                            else{
                                seek($lines_ref, -$ln, 1);
                            }

                            # read line
                            if( ref($lines_ref) eq "ARRAY" ){
                                $line = $$lines_ref[$ln]; $ln++;
                            }
                            else{
                                $line = <$lines_ref>; $ln = length($line);
                            }

                            $data_found = $state{data_found};
                            last;
                        }
                    }
                }

                # if still not processed, record it
                if( ! defined( $state{processed}) ){
                    $lines_not_processed++;
                    # uncomment below to actually see the lines
                    #$line =~ s/\s*$//;
                    #printf( "lnp: %6d %s\n", $ln, $line );
                }

            } # call extra routines

            # ============
            # process vals
            # ============

            # add values if new data_found and and cycle defined
            if( defined($vals{cycle}) && defined($data_found) ){
                undef( $data_found );
                &ctf_vals_add( VALS=>$vals_ref, VALS_CYCLE=>\%vals );
            }

        } # process each line

        # close if opened
        if( ref($lines_ref) ne "ARRAY" ){
            close( $lines_ref );
        }

    } # process each file

    # print some more info
    if( defined($args{VERBOSE}) ){
        print "$args{VERBOSE}  lines_not_processed = $lines_not_processed\n";
        print "$args{VERBOSE}  extras_called       = $extras_called\n";
    }

    ####################################################################
    # all files read - now finish up
    ####################################################################

    # do a check now
    &ctf_vals_check( VALS=>$vals_ref );

    # ctf_fill_time to get times on each field
    &ctf_fill_time( VALS=>$vals_ref );

    # return
    return( $ierr );
    
}

# Fix vals: deal with spaces in matname
#    Matname                             Volume        Mass
#     mat1                                1.0           3.0
#     Cu rod                              2.0           4.0
sub matname_with_spaces{
    my %args = (
        FIELDS => undef,
        LINE   => undef, 
        VALS   => undef,
        @_,
        );
    my( $args_valid ) = "FIELDS|LINE|VALS";
    my( 
        $arg,
        $i,
        $ierr,
        $field,
        $fields_ref,
        $line_ref,
        $matname,
        $vals_ref,
        @vals_new,
        @vals_old,
        );

    $ierr = 0;
    foreach $arg (keys %args){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # either of these specify where data is
    $fields_ref = $args{FIELDS};
    $vals_ref   = $args{VALS};
    $line_ref   = $args{LINE};


    # Given line
    if( defined( $line_ref ) ){
        if( $$line_ref =~ /^\s*([\S\s]+)\s+((min|max)\s+(mixed|pure).*)/ ){
            $matname   = $1;
            $$line_ref = $2;
            $matname =~ s/^\s+//;
            $matname =~ s/\s+$//;
            $matname =~ s/\s+/_/g;
            $$line_ref = "$matname $$line_ref";
            return( $ierr );
        }
    }

    # given fields, vals
    $i = 0;
    @vals_old = @$vals_ref;
    # go from last elem to first and put into vals_new
    # once you hit field "Matname", all rest are the name
    # and replace whitespace with "_"
    foreach $field ( reverse @$fields_ref ){
        if( $field eq "Matname" ){
            unshift( @vals_new, join( "_", @vals_old ) );
            last;
        }
        unshift( @vals_new, pop(@vals_old) );
    }
    @$vals_ref = @vals_new;

}

# bump line and prune
sub read_next_line{
    my( $lines_ref,
        $line_ref,
        $ln_ref ) = @_;

    # read line
    if( ref($lines_ref) eq "ARRAY" ){
        $$line_ref = $$lines_ref[$$ln_ref]; $$ln_ref++;
    }
    else{
        $$line_ref = <$lines_ref>;
        if( defined($$line_ref) ){
            $$ln_ref = length($$line_ref);
        }
    }
    # strip beginning/ending whitespace
    if( defined( $$line_ref ) ){
        $$line_ref =~ s/^\s+//;
        $$line_ref =~ s/\s+$//;
    }

}


########################################################################
# Required routine: ctf_plot_sap_output
sub ctf_plot_sap_output{
    my %args = (
        FILE_INFO  => undef, # \%file_info
        PLOT_INFO  => undef, # \@plot_info
        VERBOSE    => undef, # if verbose
        @_,
        );
    my( $args_valid ) = "FILE_INFO|PLOT_INFO|VERBOSE";
    my(
        $arg,
        $field,
        @fields_all,
        @fields_found,
        $file_info_ref,
        $ierr,
        $plot_i,
        $plot_info_ref,
        );

    # Error return value
    $ierr = 0;

    # SKIP THIS CHECK UNLESS THIS FILE ACTIVELY MAINTAINED WITH:
    #   ctf_process.pm/ctf_process.pl
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

    # either of these specify where data is
    $file_info_ref = $args{FILE_INFO};
    $plot_info_ref = $args{PLOT_INFO};

    @fields_all = sort keys %{$$file_info_ref{field}};
    $plot_i = -1;

    # time vs. cycle
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "(time) and (cycle)";
    $$plot_info_ref[$plot_i]{xlabel} = "cycle";
    $$plot_info_ref[$plot_i]{ylabel} = "time";
    push( @{$$plot_info_ref[$plot_i]{y_fields}},
          "time",
        );

    # cycle vs. time
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "(cycle) and (time)";
    $$plot_info_ref[$plot_i]{xlabel} = "time";
    $$plot_info_ref[$plot_i]{ylabel} = "cycle";
    push( @{$$plot_info_ref[$plot_i]{y_fields}},
          "cycle",
        );

    # dt
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "dt";
    $$plot_info_ref[$plot_i]{xlabel} = "time";
    $$plot_info_ref[$plot_i]{ylabel} = "dt";
    $$plot_info_ref[$plot_i]{yscale} = "logscale";
    push( @{$$plot_info_ref[$plot_i]{y_fields}},
          "dt",
        );
    $$plot_info_ref[$plot_i]{y2label} = "cycle";
    #$$plot_info_ref[$plot_i]{y2scale} = "logscale";
    push( @{$$plot_info_ref[$plot_i]{y2_fields}},
          "cycle" );

    # METRICS:
    @fields_found = grep( /^METRICS:/, @fields_all );
    foreach $field ( @fields_found ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "$field";
        $$plot_info_ref[$plot_i]{xlabel} = "time";
        $$plot_info_ref[$plot_i]{ylabel} = "$field";
        push( @{$$plot_info_ref[$plot_i]{y_fields}},
              "$field",
            );
    }

    # dt:
    @fields_found = grep( /^dt:/, @fields_all );
    if( @fields_found ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "dt:{limiter}";
        $$plot_info_ref[$plot_i]{xlabel} = "time";
        $$plot_info_ref[$plot_i]{ylabel} = "dt:{limiter}";
        $$plot_info_ref[$plot_i]{yscale} = "logscale";
        # dt
        push( @{$$plot_info_ref[$plot_i]{y_fields}},
              "dt",
            );
        # rest
        push( @{$$plot_info_ref[$plot_i]{y_fields}}, @fields_found );
    }

}

# final require return
1;
