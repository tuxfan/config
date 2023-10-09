########################################################################
# Type=silverton_output
#   file fed into ctf_process.pm
#
# NOTE:
#   See cts_process.pm: "Internal Interface"
#
# File Format:
# ------------
#   silverton
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
# Required routine: ctf_read_silverton_output
sub ctf_read_silverton_output{
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
        $dt,
        $file,
        $file_num,
        $file_num_max,
        $file_top,
        $files_ref,
        $force,
        $ierr,
        $line,
        $lines_ref,
        $ln,
        $ln_max,
        $ln_file_top,
        $num_files_try_max,
        $time,
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
    $ln_max = 10;
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
        # -status files do not have splash block
        if( $file_top =~ /
                          \s*(\S+)\s*\n            # code
                          \s*\(Version:\s.*\)\s*\n # vers, machine, date
                          \s*Date\sand\sTime:.*\sat\s.*Machine:\s # date,time,mach
                          /x ){
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
        print "$args{VERBOSE}ctf_process_type_silverton_output\n";
        print "$args{VERBOSE}  file_num_max        = $file_num_max\n";
        # will only print status_bar for files
        if( $file_num_max > 1 ){
            print "$args{VERBOSE}  ";
        }
    }

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
        undef( %vals );
        $ln = 0;

        undef($done);
        # reset that data was found
        undef( $data_found );
        while( ! defined($done) ){

            # debugging print to detect if cycle stored but no time
            #($line_new = $line) =~ s/\s*$//;
            #print "block $ln c=$#{$$vals_ref{cycle}{val}} t=$#{$$vals_ref{time}{val}} $line_new\n";

            # read line
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
            }

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

########################################################################
# Required routine: ctf_plot_silverton_output
sub ctf_plot_silverton_output{
    my %args = (
        FILE_INFO  => undef, # \%file_info
        PLOT_INFO  => undef, # \@plot_info
        VERBOSE    => undef, # if verbose
        @_,
        );
    my( $args_valid ) = "FILE_INFO|PLOT_INFO|VERBOSE";
    my(
        $arg,
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

}

# final require return
1;
