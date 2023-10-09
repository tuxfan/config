########################################################################
# Type=rj_batch_out
#   file fed into ctf_process.pm
#
# NOTE:
#   See cts_process.pm: "Internal Interface"
#
# File Format (add more types as needed):
# ------------
#  rj_batch_out file
#
########################################################################

use ctf_process_util qw(
                        ctf_vals_add
                        ctf_vals_add_block
                        ctf_vals_splice
                        ctf_vals_check
                        ctf_vals_union_cycle_time
                        ctf_fill_time
                       );

########################################################################
# Required routine: ctf_read_rj_batch_out
sub ctf_read_rj_batch_out{
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
        $data_found,
        $days_mach_per_day,
        $days_mach_tot,
        $days_per_day,
        $days_tot,
        $deriv,
        $done,
        $extras_called,
        $fh_FILE,
        $field_1,
        $file,
        $file_a,
        $file_b,
        $file_prev,
        $file_num,
        $file_num_max,
        $file_real,
        @files,
        $files_ref,
        $force,
        $ierr,
        $line,
        @lines,
        $lines_not_processed,
        $lines_ref,
        $lines_total,
        $ln,
        $ln_max,
        $machine,
        $nodes,
        $nodes_max,
        $num_files_try_max,
        $path_real,
        $rj_cmd_out,
        $start,
        $start_prev,
        $stop,
        $stop_prev,
        %time,
        $time_begin,
        %vals,
        %vals_tmp,
        $vals_ref,
        $wallclock_days,
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
    $file_num = 0;
    undef( $done );
    undef( $ierr );
    if( defined($force) ){
        $done = "";
        $ierr = 0;
    }

    # just go by name of the file
    if( ! defined( $done) && 
        $$files_ref[$file_num] =~ /rj_batch_out/ ){
        $ierr = 0;
        $done = "";
    }

    # now know if correct filetype
    if( ! defined($ierr) || defined($args{CHECK_ONLY}) ){
        return( $ierr );
    }

    # will read file if got to here

    # now set ierr
    $ierr = 0;

    # correct file type - process them
    undef( $fh_FILE );

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
        print "$args{VERBOSE}ctf_process_type_rj_batch_out\n";
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

    # init for all files
    undef( $time_begin );
    undef( $file );
    undef( $file_real );
    $days_tot      = 0;
    $days_mach_tot = 0;
    
    # set nodes_max (default 1)
    if( defined($ENV{CTF_VAL_NODES_MAX}) ){
        $nodes_max = $ENV{CTF_VAL_NODES_MAX};
    }
    else{
        $nodes_max = 1;
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

        # close previous one if any
        if( defined( $fh_FILE ) ){
            close( $fh_FILE );
            undef( $fh_FILE );
        }
        
        # get $lines_ref (can no longer use lines_ref as a arg check)
        # files_ref
        if( defined($files_ref) ){
            # read in whole file since have to back up sometimes
            $file = $$files_ref[$file_num-1];
            if( ! open( $fh_FILE, $file ) ){
                $ierr = 1;
                &print_error( "Cannot open $file" );
                exit( $ierr );
            }
            @lines = <$fh_FILE>;
            close( $fh_FILE );
            $lines_ref = \@lines;
        }
        else{
            # lines_ref already set
        }

        # process each line
        $ln          = 0;
        $ln_max      = $#$lines_ref;
        $lines_total += $ln_max + 1;

        if( defined($args{VERBOSE}) ){
            if( $file_num_max == 1 ){
                print "$args{VERBOSE}  lines_total         = $lines_total (processing can take a while)\n";
            }
        }
        
        undef($done);
        # reset that data was found
        undef( $data_found );

        # get the real file name
        if( defined( $file ) ){
            if( -l $file ){
                $file_real = readlink( $file );
            }
            else{
                $file_real = $file;
            }
            ( $path_real = $file_real ) =~ s&rj_batch_out\.\d+&&;
            if( $path_real eq "" ){
                $path_real = ".";
            }
        }

        # time_begin from filename if possible (this is the submit time)
        if( defined( $file_real ) && ! defined( $time_begin ) ){
            if( $file_real =~ /rj_batch_out\.(\d+)/ ){
                %time = &conv_time( STRING=>"YMDHMS $1" );
                $time_begin = $time{SECS_TOTAL};
            }
        }

        # init for this file
        $start   = 0;
        $nodes   = 0;
        $stop    = 0;
        $machine = "unknown";
        undef( $rj_cmd_out );
        
        # read this files info
        while( ! defined($done) ){

            # done
            if( $ln > $ln_max ){
                last;
            }

            # read line
            $line = $$lines_ref[$ln]; $ln++;
            $line =~ s/^\s*//;
            $line =~ s/\s*$//;

            # current block line
            #print "block: $ln $line";

            # blank
            if( $line !~ /\S/ ){
                next;
            }

            # start
            if( $start == 0 && $line =~ /^\s*TIME_S:(\d+)/ ){
                $start = $1;
                # time_begin if not gotten from filename (this is when started running)
                if( ! defined( $time_begin ) ){
                    $time_begin = $start;
                }
            }

            # latest rj_cmd_out
            elsif( $line =~ m&^\s*Command :.* >> rj_adir/(rj_cmd_out\S+)& ){
                $rj_cmd_out = $1;
                # assume in the same dir as this rj_batch_out file
                if( defined($path_real) ){
                    $rj_cmd_out = "$path_real/$rj_cmd_out";
                }
            }

            # nodes: if run a normal job, will have this
            elsif( $nodes == 0 && $line =~ /^\s*NODES\s+=\s+(\d+)/ ){
                $nodes = $1;
            }

            # from printenv at beginning - add others in if cannot find it
            elsif( $nodes == 0 && $line =~ /NUM_NODES=(\d+)/ ){
                $nodes = $1;
            }

            # machine -> nodes_max
            # if found anywhere, that is likely the one to use.
            elsif( $line =~ /^\s*L_EAP_MACHINE\s*=\s*(\S+)/ ){
                $machine = $1;
                $nodes_max = &ctf_nodes_max( $machine );
            }

            # stop
            elsif( $line =~ /^\s*TIME_S:(\d+)/ ){
                $stop = $1;
            }

            # stop
            elsif( $line =~ /CANCELLED AT (\S+)/ ){
                %time = &conv_time( STRING=>"YMDHMS $1" );
                $stop = $time{SECS_TOTAL};
            }
            
        } # read this files info

        # if did not find start, punt and go to next one
        if( $start == 0 ){
            next;
        }

        # nodes_max -> field_1 name
        if( $nodes_max == 1 ){
            # do not have nodes_max info -> secs_tot_nodes
            $field_1   = "days_nodes";
        }
        else{
            # have nodes_max info -> secs_tot_machine
            $field_1   = "days_mach";
        }

        # if nodes not found, just set to 1
        if( $nodes == 0 ){
            $nodes = 1;
        }

        # if never found stop, get from rj_cmd_out
        if( $stop == 0 ){
            if( defined( $rj_cmd_out ) && -e $rj_cmd_out ){

                # cannot rely on time stamp of this file...so try to get date from file
                #&my_stat( $rj_cmd_out, \%stat );
                #$stop = $stat{mtime};

                @files = ( glob( "${rj_cmd_out}*" ) );
                undef( %vals_tmp );
                &ctf_read_eap_output( FILES=>\@files, VALS=>\%vals_tmp );
                if( defined( $vals_tmp{date} ) ){
                    $stop = $vals_tmp{date}{val}[-1];
                    %time = &conv_time( STRING=>"YMDHMS $stop" );
                    $stop = $time{SECS_TOTAL};
                }
            }

            # punt if not found
            if( $stop == 0 ){
                $stop = $start;
            }

        }

        # if overlap start/stop, skip second one
        # happens if user is running job in same dir but on >1 machine.
        if( ! defined( $start_prev ) ){
            $start_prev = $start;
        }
        if( ! defined( $stop_prev ) ){
            $stop_prev = $start;
        }
        if( $start < $stop_prev ){
            $file_a = $file_prev || "undefined";
            $file_b = $file_real || "undefined";
            $ierr = 0;
            print "\n";
            &print_error( "Detected overlapping start/stop times.",
                          "Likely due to submitting jobs on different machines in same directory.",
                          "Keep previous file:",
                          "  $file_a",
                          "Skip next     file:",
                          "  $file_b",
                          $ierr );
            next;
        }
        
        $wallclock_days = ($stop  - $time_begin)                  / (3600*24);
        $days_tot      += ($stop  - $start)                       / (3600*24);
        $days_mach_tot += ($stop  - $start) * ($nodes/$nodes_max) / (3600*24);
        if( $wallclock_days > 0 ){
            $days_per_day      = $days_tot      / $wallclock_days;
            $days_mach_per_day = $days_mach_tot / $wallclock_days;
        }
        else{
            $days_per_day      = 0;
            $days_mach_per_day = 0;
        }
        
        # push onto vals
        push( @{$vals{time}},                 $wallclock_days );
        push( @{$vals{days}},                 $days_tot );
        push( @{$vals{nodes}},                $nodes );
        push( @{$vals{nodes_max}},            $nodes_max );
        push( @{$vals{machine}},              $machine );
        push( @{$vals{"days_per_day"}},       $days_per_day );
        push( @{$vals{$field_1}},             $days_mach_tot );
        push( @{$vals{"${field_1}_per_day"}}, $days_mach_per_day );

        # remember prev
        $start_prev = $start;
        $stop_prev  = $stop;
        $file_prev  = $file_real || "undefined";

    } # process each file


    if( %vals ){

        # Re: NOISE
        # got some large jumps in deriv if did not give large NOISE

        # deriv - day
        &my_derivative( X=>$vals{time}, Y=>$vals{days},     DERIV=>\@deriv, NOISE=>2 );
        push( @{$vals{"days_deriv"}}, @deriv );

        # deriv field_1
        &my_derivative( X=>$vals{time}, Y=>$vals{$field_1}, DERIV=>\@deriv, NOISE=>2 );
        push( @{$vals{"${field_1}_deriv"}}, @deriv );

        # and add vals
        &ctf_vals_add_segment( VALS=>$vals_ref, VALS_SEGMENT=>\%vals );
        undef( %vals );
    }

    # print some more info
    if( defined($args{VERBOSE}) ){
        if( $file_num_max > 1 ){
            print "$args{VERBOSE}  lines_total         = $lines_total\n";
        }
        print "$args{VERBOSE}  lines_not_processed = $lines_not_processed\n";
        print "$args{VERBOSE}  extras_called       = $extras_called\n";
    }
    
    # close previous $fh_FILE if any
    if( defined( $fh_FILE ) ){
        close( $fh_FILE );
        undef( $fh_FILE );
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
# Required routine: ctf_plot_rj_batch_out
sub ctf_plot_rj_batch_out{
    my %args = (
        FILE_INFO  => undef, # \%file_info
        PLOT_INFO  => undef, # \@plot_info
        VERBOSE    => undef, # if verbose
        @_,
        );
    my( $args_valid ) = "FILE_INFO|PLOT_INFO|VERBOSE";
    my(
        $arg,
        @fields_all,
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

    # plot
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "wallclock days vs. days (run days) and days_mach (days scaled by available nodes)";
    $$plot_info_ref[$plot_i]{xlabel} = "time";
    $$plot_info_ref[$plot_i]{ylabel} = "days (run days) days_mach (days scaled by available nodes)";
    $$plot_info_ref[$plot_i]{grid}   = "";
    push( @{$$plot_info_ref[$plot_i]{y_fields}}, "days" );
    push( @{$$plot_info_ref[$plot_i]{y_fields}}, "days_mach" );

    # plot
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "days (run days) per wallclock day";
    $$plot_info_ref[$plot_i]{xlabel} = "time";
    $$plot_info_ref[$plot_i]{ylabel} = "days (run days) per wallclock day";
    $$plot_info_ref[$plot_i]{grid}   = "";
    push( @{$$plot_info_ref[$plot_i]{y_fields}}, "days_per_day" );
    push( @{$$plot_info_ref[$plot_i]{y_fields}}, "days_deriv" );

    # plot
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "days_mach (days scaled by available nodes) per wallclock day";
    $$plot_info_ref[$plot_i]{xlabel} = "time";
    $$plot_info_ref[$plot_i]{ylabel} = "days_mach (days scaled by available nodes) per wallclock day";
    $$plot_info_ref[$plot_i]{grid}   = "";
    push( @{$$plot_info_ref[$plot_i]{y_fields}}, "days_mach_deriv" );
    push( @{$$plot_info_ref[$plot_i]{y_fields}}, "days_mach_per_day" );

}

# final require return
1;
