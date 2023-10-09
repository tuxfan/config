########################################################################
# Type=ctf_dump
#   file fed into ctf_process.pm
#
# NOTE:
#   See cts_process.pm: "Internal Interface"
#
# File Format:
# ------------
#   ctf_dump.txt (file should likely be renamed)
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
# Required routine: ctf_read_ctf_dump
sub ctf_read_ctf_dump{
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
        $cycle,
        $data_found,
        $done,
        $extras_called,
        $field,
        $file,
        $file_num,
        $file_num_max,
        $file_top,
        $files_ref,
        $force,
        $ierr,
        $line,
        $lines_not_processed,
        $lines_ref,
        $lines_total,
        $ln,
        $start_file_done,
        %state,
        $time,
        $val,
        %vals,
        $vals_ref,
        );

    # Error return value
    # If cannot read this type of file, $ierr = undef
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
    $files_ref = $args{FILES};
    $lines_ref = $args{LINES};
    $force     = $args{FORCE};

    # output
    $vals_ref  = $args{VALS};

    # see if this is a ctf_dump.txt file (ideally named differently)
    undef( $ierr );

    # first line is:
    undef( $file_top );
    if( defined( $files_ref ) ){
        $file_top = `head -1 $$files_ref[0] 2>&1`;
    }
    else{
        $file_top = $$lines_ref[0];
    }
    if( $file_top =~ /^#\s*ctf_process\s*$/ ){
        $ierr = 0;
    }

    if( defined($force) ){
        $done = "";
        $ierr = 0;
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
        print "$args{VERBOSE}ctf_process_type_ctf_dump\n";
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
    $lines_total         = 0;

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
        undef( %state );
        undef( $start_file_done );
        undef( %vals );
        $ln = 0;

        undef($done);
        # reset that data was found
        undef( $data_found );
        undef( $field );
        while( ! defined($done) ){

            # read line
            if( ref($lines_ref) eq "ARRAY" ){
                $line = $$lines_ref[$ln]; $ln++;
            }
            else{
                $line = <$lines_ref>;
            }
            # done
            if( ! defined($line) ){
                last;
            }

            $lines_total++;

            # current block line
            #print "block: $ln $line";

            # blank
            if( $line !~ /\S/ ){
                next;
            }

            # new variable
            if( $line =~ /^#\s+(cycle)\s+(time)\s+(.*?)\s*$/ ){
                $field = $3;
                undef( %vals );
                $vals{field_name} = $field;
            }

            # data
            elsif( $line =~ /^\s*(\d+)\s+(\S+)\s+(\S+)\s*$/ ){

                while( $line =~ /^\s*(\d+)\s+(\S+)\s+(\S+)\s*$/ ){
                    $cycle = $1;
                    $time  = $2;
                    $val   = $3;
                    push( @{$vals{cycle}}, $cycle );
                    push( @{$vals{time}},  $time );
                    push( @{$vals{val}},   $val );
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>;
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    $lines_total++;
                }

                &ctf_vals_add_segment_ctf( VALS=>$vals_ref, VALS_SEGMENT=>\%vals );

            } # data

        } # process each line

        # close if opened
        if( ref($lines_ref) ne "ARRAY" ){
            close( $lines_ref );
        }
        
    } # process each file

    # print some more info
    if( defined($args{VERBOSE}) ){
        print "$args{VERBOSE}  lines_total         = $lines_total\n";
        print "$args{VERBOSE}  lines_not_processed = $lines_not_processed\n";
        print "$args{VERBOSE}  extras_called       = $extras_called\n";
    }
    
    ####################################################################
    # all files read - now finish up
    ####################################################################

    if( defined($args{VERBOSE}) ){
        print "$args{VERBOSE}  final processing for additional fields...\n";
    }

    # do a check now
    &ctf_vals_check( VALS=>$vals_ref );

    # ctf_fill_time to get times on each field
    &ctf_fill_time( VALS=>$vals_ref );

    # return
    return( $ierr );
    
}

########################################################################
# Required routine: ctf_plot_ctf_dump
sub ctf_plot_ctf_dump{
    my(
        $ierr,
        );

    # Error return value
    $ierr = 0;

    # Currently will not plot anything.
    # could put some logic that stores the origin of the data in ctf_dump.txt
    # files and then calls the origin plotting routine.
    return( $ierr );
}

# final require return
1;
