########################################################################
# Type=eap_output
#   file fed into ctf_process.pm
#
# NOTE:
#   See cts_process.pm: "Internal Interface"
#
# File Format:
# ------------
#   eap -output, -status, screen ouput
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
# Required routine: ctf_read_eap_output
sub ctf_read_eap_output{
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
        %count,
        %ctf_extras_required,
        $cycle,
        $cycle_delta,
        $cycle_field,
        $cycle_f,
        $cycle_f_sub,
        $cycle_date_prev,
        $cycle_date_prev_redo,
        $cycle_first,
        $cycle_prev,
        $cycle_clear,
        $cycle_numnodes,
        $cycle_ref,
        $cycle_restart_block,
        $cycle_restart_block_next,
        $cycle_sumwallhr,
        %cycles,
        %cycles_max,
        $days_secs_tot,
        $days_secs_tot_mach,
        $days_sumwallhr,
        $date,
        $date_prev_redo,
        $date_start,
        $date_start_this,
        $date_this,
        $datestamp,
        $datestamp_filename,
        $datestamp_filename_old,
        $datestamp_line,
        $datestamp_line_old,
        $datestamp_ln,
        $datestamp_ln_old,
        $datestamp_old,
        $data_found,
        $date_orig,
        $date_prev,
        $dim,
        $dim_name,
        $dist,
        $done,
        $done_1,
        $done_2,
        $dt,
        $dump_file,
        $duplicate_detected,
        $eng_in,
        $eng_out,
        $eval_error,
        $extra,
        $extra_routine,
        $extras_called,
        $fh_FILE,
        @files,
        $files_search_ref,
        $field,
        $field_1,
        $field_new,
        $field_sub,
        $field_use,
        @fields,
        @fields_all,
        @fields_new,
        @fields_post,
        %fieldsh,
        %fieldsh_orig,
        $file,
        $file_num,
        $file_num_max,
        $file_top,
        $filename,
        $filename_old,
        $files_ref,
        $flag,
        $force,
        $found,
        $i,
        $i_parse,
        $ierr,
        $in_run_job_cleanup,
        $index,
        $index_max,
        %indices,
        $j,
        $j_next,
        $j_start,
        $k,
        $k_start,
        $key,
        $key_val,
        %keys_vals,
        $label_1,
        $label_2,
        $label_3,
        $label,
        $line,
        $line_tmp,
        @lines_error,
        $lines_not_processed,
        $lines_ref,
        $ln,
        $ln_max,
        $mat,
        $max_restart_blocks,
        $nall_num,
        $name,
        $ncell_all,
        $ncell_all_mixed,
        $ncell_all_mixed_mats,
        $ncell_top,
        $ncell_top_mixed,
        $ncell_top_mixed_mats,
        $nodes_max,
        $ntop_num,
        $num,
        $num_c,
        $num_files_try_max,
        $num_mats,
        $num_numnodes,
        $num_secs_cycle,
        $num_secs_tot,
        $num_sumwallhr,
        $numnodes,
        $ppp_header,
        $probe,
        $rate,
        $restart_block,
        $restart_block_num,
        $restart_block_num_print,
        $rs_block,
        $same_file,
        $secs,
        $secs_post,
        $secs_start,
        $size,
        $speed,
        $start_file_done,
        $state_ref,
        %state,
        %state_file,
        $subroutine,
        $t0,
        $time,
        %time_h,
        $time_trig,
        $tot,
        $tot_seg,
        $tot_sum,
        $type,
        $val,
        $val_1,
        $val_2,
        $val_prev,
        $val_tot,
        $val_seg,
        %vals,
        @vals_arr,
        @vals_line,
        @vals_sorted,
        $vals_ref,
        $version,
        $verbose,
        $wall_days,
        $which,
        $x,
        $y,
        $z,
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

    # output
    $vals_ref  = $args{VALS};

    # init version
    $version = "";

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
    # get a reasonable list of files
    $files_search_ref = $files_ref;
    if( ! defined($done) ){
        if( defined($files_ref) ){
            # try pruning out the files that are "tries"
            @files = grep( ! /\.\d{3}$/, @{$files_ref});
            # if have enough files without retries, use those
            if( $#files + 1 >= $num_files_try_max ){
                $files_search_ref = \@files;
            }
            # might want to take a mix of tries and firsts...
        }
    }
    while( ! defined($done) ){
        undef( $file );
        # fill file_top
        if( defined($files_search_ref) ){
            if( $file_num > $#$files_search_ref ){
                last;
            }
            if( $file_num >= $num_files_try_max ){
                last;
            }
            $file = $$files_search_ref[$file_num];
            $file_top = `head -10 $file 2>&1`;
            $file_num++;
        }
        else{
            $ln_max = 10;
            if( $ln_max > $#$lines_ref ){
                $ln_max = $#$lines_ref;
            }
            $file_top = join("\n", @{$lines_ref}[0..$ln_max]);
            # will be done after this regardless
            $done = "";
        }

        # if screen output, will be a bit lower
        if( $file_top =~ /^\s*RJ_OUTPUT: / ){

            undef( $in_run_job_cleanup );

            # open file if given
            undef( $fh_FILE );
            if( defined( $file ) ){
                if( ! open( $fh_FILE, $file ) ){
                    last;
                }
            }

            # go through lines
            $i       = 0;
            $i_parse = 0;
            undef( $done_1 );
            while( ! defined($done_1) ){

                # get line from file
                if( defined($file) ){
                    $line=<$fh_FILE>;
                    if( ! defined($line) ){
                        last;
                    }
                }
                # get line from lines
                else{
                    if( $i > $#$lines_ref ){
                        last;
                    }
                    $line = $$lines_ref[$i];
                }
                $i++;
                
                # ignore RJ_OUTPUT lines (do not count towards $i max
                if( $line =~ /^\s*RJ_OUTPUT: / ){
                    next;
                }

                # skip these lines - happens with .so's not having explicit version
                # info and get printed for each mpi rank on startup.
                if( $line =~ /no version information available/ ){
                    next;
                }

                # we have some debugging lines (srun -l cat /proc/meminfo)
                if( $line =~ /^\s*\d+: / ){
                    next;
                }

                # get past run_job_cleanup lines
                # determine if in run_job_cleanup and skip
                # start
                if( $line =~ /^\s*Started:.*run_job_cleanup.pl/ ){
                    $in_run_job_cleanup = "";
                }
                # stop
                if( $line =~ /^\s*Finished:.*run_job_cleanup.pl/ ){
                    undef( $in_run_job_cleanup );
                }
                # skip if in
                if( defined($in_run_job_cleanup) ){
                    next;
                }

                $i_parse++;

                # only read up to a point
                if( $i_parse > 100 ){
                    last;
                }

                # matches
                if( $line =~ /^\s*Special Version ID:/ ){
                    $ierr = 0;
                    last;
                }
                if( defined($ierr) ){
                    last;
                }

            } # go through lines

            # close file if opened
            if( defined($fh_FILE) ){
                close( $fh_FILE );
            }

            # exit main loop if found
            if( defined($ierr) ){
                last;
            }

            # go to next file
            next;

        } # if screen output, will be a bit lower

        # if still looking, search for this
        # -status files do not have splash block
        if( $file_top =~ /^\s*Special Version ID\:/m ||
            $file_top =~ /^\s*cycle\s*=\s*(\d+)\s*,\s*
                              time\s*=\s*(\S+)\s*,\s*
                              dtnext\s*=\s*(\S+)\s*$/mx ){
            $ierr = 0;
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
        print "$args{VERBOSE}ctf_process_type_eap_output\n";
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

    # init to before time
    $datestamp_filename_old = "";
    $datestamp_line_old     = "";
    $datestamp_ln_old       = -1;
    $datestamp_old          = -1;

    $filename_old = "";
    $nodes_max = 1;

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
        undef( %state );
        undef( $start_file_done );
        undef( %vals );

        # $lines_ref = file handle or reference to array
        if( defined($files_ref) ){
            $file = $$files_ref[$file_num-1];
            $filename = $file;
            # store this since used to find rj_batch_out
            $state_file{filename} = $filename;
            if( ! open( $lines_ref, "$file" ) ){
                $ierr = 1;
                &print_error( "Cannot open $file" );
                exit( $ierr );
            }
        }
        else{
            undef( $file );
            # lines_ref already set
        }

        # process each line
        $ln = 0;

        undef($done);

        # data_found
        #   This is used to say:
        #     call ctf_vals_add()
        #   Used when got data, but that data might not have any cycle
        #   info in the lines processed (and especially if that data might
        #   printed before any the next cycle info is printed).
        #   This happens for ensight_write_time (seen at cycle-0 graphics
        #   dumps).

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

            # crash...leave this file because likely many other lines that
            # are not worth processing (hang messages, core dump messages, ...
            if( $line =~ /\*\*FATAL_ERROR\*\*/ ||
                $line =~ /^\s*Loguru caught a signal: / ||
                $line =~ /double free or corruption.*: 0x/ ||
                $line =~ /corrupted size vs. prev_size.*: 0x/ ||
                $line =~ /^\s*\d+:.*\[heap\]\s*$/
                ){
                last;
            }

            # blank
            if( $line !~ /\S/ ){
                next;
            }

            # filler lines
            if( $line =~ /^\s*(=|-|\*)+\s*$/ ){
                next;
            }


            # old versions have this issue with libraries on startup
            if( $line =~ /no version information available/ ){
                next;
            }

            # skip srun errors (every process prints these)
            # NOTE: MPICH2 error and problem continued
            if(
                $line =~ /^\s*srun: error: / ||
                $line =~ /^\s*srun: Terminating job step/ ||
                $line =~ /^\s*srun: forcing job termination/ ||
                $line =~ /^\s*MPICH2 ERROR \[Rank /
                ){
                next;
            }
            
            # no-op first check
            if( $line =~ /^empty beginning if block/ ){
            }

            # RJ_OUTPUT: process to get some data
            elsif( $line =~ /^\s*RJ_OUTPUT: / ){
                if( $ctf_extras_required{rj_cmd_out} ){
                    # state gets deleted when it sees start of new run.
                    # store the rj_cmd_out data found into state_file
                    $state_ref = \%state_file;

                    # both $ln and $line are used
                    $$state_ref{ln}       = $ln;
                    $$state_ref{line}     = $line;
                    $$state_ref{filename} = $filename;
                    $extras_called++;
                    $extra_routine = "ctf_read_rj_cmd_out";
                    $eval_error = eval "\$ierr = &$extra_routine( LINES=>\$lines_ref, VALS=>\$vals_ref, VALS_THIS=>\\\%vals, STATE=>\$state_ref, VERBOSE=>\$verbose )";
                    # error stored into $@
                    if( $@ || $ierr != 0 ){
                        $ierr = 1;
                        &print_error( "Error from $extra_routine :",
                                      $@, $ierr );
                        exit( $ierr );
                    }
                    if( ! defined($ENV{CTF_VAL_NODES_MAX}) &&
                        defined( $$state_ref{rj_nodes_max} ) ){
                        $nodes_max = $$state_ref{rj_nodes_max};
                    }

                    # Could put in something to detect this is a new
                    # file (if folks cat multiple files together).

                    # copy back state (since backup line done)
                    #   $ln:   valid and used
                    #   $line: will be reset since "next" assumed
                    $ln          = $$state_ref{ln};
                    # undef not really needed...but hopefully catch bugs
                    undef($line);
                    
                }

                # assumed that next is a new read of line
                next;
                
            }

            # run_job_cleanup.pl
            elsif( $line =~ /^\s*Started:.*run_job_cleanup.pl/ ){
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    # stop
                    if( $line =~ /^\s*Finished:.*run_job_cleanup.pl/ ){
                        last;
                    }
                }
                next;
            }

            # -------------------------------
            # if you see this again, treat as new file for
            # ctf_vals_splice
            # (user might have cat'd output files together)
            # -------------------------------
            elsif( $line =~ /^\s*Version:/ ){
                undef( $start_file_done );
                undef( %state );
                undef( %vals );
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                    # secs_lost[cycle of restart dump]    = this date
                    # will later set this to be the time spent between runs (sitting
                    # in batch or just not starting up again)
                    if( $line =~ /Date:time\s+=\s+(\S+)/ ){
                        $date_this = $1;
                        # old format will not have extended date here so need
                        # to ignore it in general.
                        if( $date_this !~ /\.\d+$/ ){
                            $version = "old";
                        }
                        %time_h = &conv_time( STRING=>"YMDHMS $date_this" );
                        $vals{date}     = $time_h{date_dot};
                        ($datestamp_line = $line) =~ s/\s*$//;
                        $datestamp_ln   = $ln;

                        $secs             = $time_h{SECS_TOTAL};
                        $vals{secs_lost}  = $secs;
                        $vals{date_start} = $vals{date};
                        
                        $data_found = "";

                    }

                    # machine type
                    # thought to get machine run on...but can run TR on TR_KNL...
                    # so best to use rj_cmd_out file
                    #elsif( $line =~ /V_TF_PREBUILT_NAME: (\S+)/ ){
                    #    $vals{V_TF_PREBUILT_NAME} = $1;
                    #}

                    elsif( $line =~ /Number of processors/ ){
                        last;
                    }
                } # while reading version info
            } # Version:

            # -------------------------------
            # Input File
            # -------------------------------
            elsif( $line =~ /\*\*\* Input File\s*$/ ){
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                    if( $line =~ /\*\*\* End Input File\s*$/ ){
                        last;
                    }

                    # old code ran out of buffer space and you never hit "end"
                    if( $line =~ /Resources: start/ ||
                        $line =~ /Closed Parallel IO file/ ){
                        # back up one line
                        if( ref($lines_ref) eq "ARRAY" ){
                            $ln--;
                        }
                        else{
                            seek($lines_ref, -$ln, 1);
                        }
                    }

                }
            }

            # -------------------------------
            # List of pre-defined
            # -------------------------------
            elsif( $line =~ /\*\*\* List of pre-defined parser variables\s*$/ ){
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line =~ /\*\*\* End list of pre-defined parser variables\s*$/ ){
                        last;
                    }
                }
            }

            # -------------------------------
            # Current parser functions
            # -------------------------------
            elsif( $line =~ /\*\*\* Current parser functions\s*$/ ){
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line =~ /\*\*\* End Current parser functions\s*$/ ){
                        last;
                    }
                }
            }

            # -------------------------------
            # Current parser buffer commands
            # -------------------------------
            elsif( $line =~ /\*\*\* Current parser buffer commands\s*$/ ){
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line =~ /\*\*\* End Current parser buffer commands\s*$/ ){
                        last;
                    }
                }
            }

            # -------------------------------
            # Current parser buffer when/then
            # -------------------------------
            elsif( $line =~ /\*\*\* Current parser buffer when/ ){
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line =~ /\*\*\* End Current parser buffer when/ ){
                        last;
                    }
                }
            }

            # -------------------------------
            # initial gravity
            # -------------------------------
            elsif( $line =~ /^\s*Initial Gravity Solver settings/ ){
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line =~ /^\s*End Gravity Solver internals/ ){
                        last;
                    }
                }
            }

            # -------------------------------
            # restart_block: -output file
            # -------------------------------
            elsif( $line =~ /Current parser buffer restart blocks/ ){
                undef( $done );
                # while in restart block
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                    # restart block and active flag
                    if( $line =~ /Echo restart block info, restart block name = (\S+.*?)\s*$/ ){
                        $rs_block = $1;
                        $rs_block =~ s/\s+/_/g;
                        $field = "restart_block:$rs_block";
                        # next line is status
                        # read line
                        if( ref($lines_ref) eq "ARRAY" ){
                            $line = $$lines_ref[$ln]; $ln++;
                        }
                        else{
                            $line = <$lines_ref>; $ln = length($line);
                        }
                        # done
                        if( ! defined($line) ){
                            last;
                        }
                        if( $line =~ /Active flag = (\S+)/ ) {
                            $flag = $1;
                            # just mark when it turns on
                            if( $flag eq "true" && ! defined($$vals_ref{$field}) ){
                                # will replace with <num>:<rs block> later
                                $vals{$field} = $rs_block;
                            }
                        }
                    }
                    elsif( $line =~ /End Current parser restart blocks/ ){
                        last;
                    }
                } # while in restart block
            }

            # restart_block: screen output (rj_cmd_out)
            elsif( $line =~ /^\s*\*\* Echo restart block info, restart block name = (\S+.*?)\s*$/ ){
                $rs_block = $1;
                $rs_block =~ s/\s+/_/g;
                $field = "restart_block:$rs_block";
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }

                # next line should be this
                if( defined($line) && $line =~ /Active flag = (\S+)/ ){
                    $flag = $1;
                    # In the screen output case, only will have lines
                    # for the restart block(s) that got triggered...
                    # not all the restart blocks that are active.
                    # So, just register first time active.
                    # If multiple restart blocks trigger at same time,
                    # the name of the dump file is the first restart block name.
                    if( $flag eq "true" && ! defined($$vals_ref{$field}) ){
                        # will replace with <num>:<rs block> later
                        $vals{$field} = $rs_block;
                    }
                    
                }
               
                # something odd (since should match)....back up a line
                else{
                    # back up one line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $ln--;
                    }
                    else{
                        seek($lines_ref, -$ln, 1);
                    }
                }
                
            }

            # -------------------------------
            # reading dump file
            # -------------------------------
            elsif( $line =~ /^\s*Opened existing PIO file:\s*(\S+dmp\S+)\s+for read access./ ) {
                $dump_file = $1;
                $state{restart} = $dump_file;

                # restart block info from screen output file
                # Detect from name of dump file being read in.
                # Not very robust because users could name dump file
                # differently.
                # Could 
                if( $dump_file =~ /-dmp(\d+)_rb_(\S+)/ ){
                    $state{restart_block} = $1;
                }
                else{
                    delete($state{restart_block});
                }
            }

            elsif( $line =~ /^\s*Closed (Parallel IO|PIO) file: (\S+) dandt = (\S+) .*\s+sec\s+=\s+(\S+)\s+(\S+\/sec\s+=\s+(\S+))?/ &&
                defined( $state{restart} ) ){
                delete( $state{restart} );
                $file = $2;
                $date = $3;
                $secs = $4;
                $rate = $6;
                if( ! defined( $rate ) ){
                    $rate = "-";
                    $size = "-";
                }
                else{
                    $size = $rate * $secs;
                }
                # this has date when it was created - might want to use this
                # as guess to secs_lost???
                # remove fractional second
                $vals{dmp_read_time} = $secs;
                $vals{dmp_read_rate} = $rate;
                $vals{dmp_read_size} = $size;
                $data_found = "";
            }

            # -------------------------------------
            # reading other file (CHECK DUMP FIRST)
            # -------------------------------------
            elsif( $line =~ /^\s*Opened existing PIO file: (\S+) for read access./ ) {
                $state{pio_read_other} = "";
            }
            elsif( $line =~ /^\s*Closed (Parallel IO|PIO) file:.*\s+sec\s+=\s+(\S+)\s+(\S+\/sec\s+=\s+(\S+))?/ &&
                   defined( $state{pio_read_other} ) ) {
                $data_found = "";
                $field = "pio_read_other";
                delete( $state{$field} );
                $vals{"$field:time"} += $2;
                $rate = $4;
                if( ! defined($rate) ){
                    $rate = "-";
                }
                $vals{"$field:rate"}  = $rate;
            }

            # pio_barrier_throttle - parsed multiple places
            elsif( $line =~ /^\s*(pio_barrier_throttle)\s+ # 1 tag
                                 (\S+)\s+ # 2 name
                                 (\S+)\s+ # 3 pio routine
                                 (\S+)\s+ # 4 dowho
                                 (\S+)\s+ # 5 dowhat
                                 (\S+)\s+ # 6 count
                                 (\S+)\s+ # 7 time op
                                 (\S+)\s+ # 8 time between ops
                                 /x ){
                $field = "${1}:${2}:${3}:${4}:${5}:op";
                $val = $7;
                $vals{$field} = $val;
                $field = "${1}:${2}:${3}:${4}:${5}:between_op";
                $val = $8;
                $vals{$field} = $val;
            }

            # -------------------------------
            # ISO: User Isotope Input
            # -------------------------------
            elsif( $line =~ /\*\*\* ISO: User Isotope Input/ ){
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line =~ /\*\*\* End ISO: User Isotope Input/ ){
                        last;
                    }
                }
            }

            # -------------------------------
            # ISO: Iso Vars Generation
            # -------------------------------
            elsif( $line =~ /\*\*\* ISO: Iso Vars Generation/ ){
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line =~ /\*\*\* End ISO: Iso Vars Generation/ ){
                        last;
                    }
                }
            }

            # --------------------
            # some ipcress parsing
            # --------------------
            # do NOT skip ALL ipcress since has some file IO in int
            elsif( $line =~ /^\s*Ipcress opacity group boundaries for all materials/ ){
                undef( $done_1);
                # still in resource block
                while( ! defined($done_1)  ) {
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    
                    if( $line =~ /^\s*hnu-lo/ ){
                    }
                    elsif( $line =~ /^\s*for group/ ){
                    }
                    elsif( $line =~ /^\s*(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*$/ ){
                    }
                    # line wrap...ugh
                    elsif( $line =~ /^\s*\d+\s+\d+\s*$/ ){
                    }
                    elsif( $line =~ /^\s*table limits for ipcress/ ){
                    }
                    elsif( $line =~ /^\s*ipcress table base:/ ){
                    }
                    elsif( $line =~ /^\s*\(Ipcress frequency/ ){
                    }
                    elsif( $line =~ /^\s*<Z_nuc/ ){
                    }
                    elsif( $line =~ /^\s*rho-lo, hi=/ ){
                    }
                    elsif( $line =~ /^\s*tev-lo, hi=/ ){
                    }
                    else{
                        # back up one line
                        if( ref($lines_ref) eq "ARRAY" ){
                            $ln--;
                        }
                        else{
                            seek($lines_ref, -$ln, 1);
                        }
                        last;
                    }
                }
            }

            # --------------
            # HEBURN_INITIAL
            # --------------
            elsif( $line =~ /^\s*HEBURN_INITIAL:/ ){
                undef( $done_1);
                while( ! defined($done_1)  ) {
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    
                    if( $line =~ /^\s*he\s*\d+/ ){
                    }
                    elsif( $line =~ /^\s*reactants, mat/ ){
                    }
                    elsif( $line =~ /^\s*products, mat/ ){
                    }
                    elsif( $line =~ /^\s*state \d+:\s*$/ ){
                    }
                    elsif( $line =~ /^\s*CJ state:\s*$/ ){
                    }
                    elsif( $line =~ /^\s*VN state:\s*$/ ){
                    }
                    elsif( $line =~ /^\s*HE specific energy/ ){
                    }
                    elsif( $line =~ /^\s*V = / ){
                    }
                    elsif( $line =~ /^\s*e = / ){
                    }
                    elsif( $line =~ /^\s*P = / ){
                    }
                    elsif( $line =~ /^\s*T = / ){
                    }
                    elsif( $line =~ /^\s*D = / ){
                    }
                    elsif( $line =~ /^\s*u = / ){
                    }
                    else{
                        # back up one line
                        if( ref($lines_ref) eq "ARRAY" ){
                            $ln--;
                        }
                        else{
                            seek($lines_ref, -$ln, 1);
                        }
                        last;
                    }
                }
            }

            # -------------------------------
            # Resource %
            # -------------------------------
            elsif( $line =~ /Resources: start/ ) {
                undef( $done_1);
                # still in resource block

                # NOTE: skipping the first pass through 
                while( ! defined($done_1)  ) {
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                    # numpe, numnodes, ppn
                    # Could get this in other places, but will always have this
                    # in -output and rj_cmd_out and will be correct for spliced
                    # runs.
                    if( $line =~ /numpe\s*=\s*(\d+)/ ){
                        $field = "Resources:NUMPE";
                        $vals{$field} = $1;
                        next;
                    }
                    if( $line =~ /number of nodes\s*=\s*(\d+)/ ){
                        $field = "Resources:NUMNODES";
                        $vals{$field} = $1;
                        next;
                    }
                    if( $line =~ /processes per node.*=\s*(\d+)/ ){
                        $field = "Resources:PPN";
                        $vals{$field} = $1;
                        next;
                    }

                    # available mem per node
                    if( $line =~ /available mem per node.*\s+(\S+)\s+(\S+)\s*$/ ){
                        $field = "Resources:memory:avail_node";
                        $vals{"$field:Min"} = $1;
                        $vals{"$field:Max"} = $2;
                    }
                    # percent stuff
                    if( $line =~ /^\s*Type\s+Min\%\s+Mean\%\s+Max\%\s*$/ ) {
                        undef( $done_2 );
                        # while in percent stuff
                        while( ! defined($done_2) ) {
                            # read line
                            if( ref($lines_ref) eq "ARRAY" ){
                                $line = $$lines_ref[$ln]; $ln++;
                            }
                            else{
                                $line = <$lines_ref>; $ln = length($line);
                            }
                            # done
                            if( ! defined($line) ){
                                last;
                            }

                            # NOTE: had put in a var="-" of the first resource
                            #   info gotten in a file since that block is
                            #   printed before anything allocated (so values
                            #   are not very worthwhile).
                            #   But having arrays with embedded "-" confused
                            #   another post processing script.
                            #   So, do not do this for now.
                            #   Also, there were issues when I wanted to
                            #   smooth this array and warning messages about
                            #   "-" not being numeric.
                            #   So, would need to resolve that as well.
                            if( $line =~ /(Estimate|RSS|Virt|RSS_MAX)\s+
                                  (\S+)\s+(\S+)\s+(\S+)/x ) {
                                $field = "Resources:memory:$1:";
                                $vals{"${field}Min%"}  = $2;
                                $vals{"${field}Mean%"} = $3;
                                $vals{"${field}Max%"}  = $4;
                            }
                            # next block after this
                            elsif( $line !~ /\S/ ){
                                $done_1 = "";
                                last;
                            }
                        } # while in percent stuff
                    }
                } # still in resource block

            }

            # -------------------------------
            # Resource vals
            # -------------------------------
            elsif( $line =~ m&Estimated/Actual Resources for iope& ) {

                # separator, header,  separator
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }

                undef( $done_1);
                # still in resource block
                while( ! defined($done_1)  ) {
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                    # value stuff
                    if( $line =~ /^\s*(\S+).*=\s*(\S+)$/ ) {
                        $val = $2;
                        $vals{"Resources:memory:$1"} = $val;
                    }
                    # blank line separator
                    elsif( $line !~ /\S/ ){
                        next;
                    }
                    # cannot remember if this is always printed
                    elsif( $line =~ /last package calling resource_set/ ){
                        last;
                    }
                    # exit if not match (hopefully above good enough)
                    else{
                        last;
                    }
                } # still in resource block
              
            } # resources vals

            # -------------------------------
            # creating dump file
            # -------------------------------
            elsif( $line =~ /^\s*(Create|Creating) PIO file:.*-dmp.*\s+cycle\s*=\s*(\d+)\s*$/ ) {
                # turns out that creating dump files might not coincide with
                # any time data.  Will stick in an undef value.
                $data_found = "";
                $vals{cycle} = $2;
                # use the date here because this might be the only date value we have.
                # This date is close enough (might be same or off by a second) to
                # any of the following dates for a cycle (###, long)
                # get to dump time spent line
                undef($done_1);
                while( ! defined($done_1) ) {
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                    # closed
                    if( $line =~ /^\s*Closed (Parallel IO|PIO) file: (\S+) dandt = (\S+) .*\s+sec\s+=\s+(\S+)\s+(\S+\/sec\s+=\s+(\S+))?/ ){
                        $file = $2;
                        $date = $3;
                        $secs = $4;
                        $rate = $6;
                        if( ! defined($rate) ){
                            $rate = "-";
                            $size = "-";
                        }
                        else{
                            $size = $secs * $rate;
                        }

                        # put into same format for other date's
                        # need to ignore fractional seconds if old version
                        if( $version eq "old" ){
                            $date =~ s/\.\d+$//;
                        }
                        if( $date =~ /(\d{4})(\d{2})(\d{2}):(\d{2})(\d{2})(\d{2})/ ){
                            %time_h = &conv_time( STRING=>"YMDHMS $date" );
                            $vals{date}     = $time_h{date_dot};
                            ($datestamp_line = $line) =~ s/\s*$//;
                            $datestamp_ln   = $ln;
                        }
                        $vals{dmp_write_time} = $secs;
                        $vals{dmp_write_rate} = $rate;
                        $vals{dmp_write_size} = $size;
                        last;
                    }

                    # pio_barrier_throttle - parsed multiple places
                    elsif( $line =~ /^\s*(pio_barrier_throttle)\s+ # 1 tag
                                 (\S+)\s+ # 2 name
                                 (\S+)\s+ # 3 pio routine
                                 (\S+)\s+ # 4 dowho
                                 (\S+)\s+ # 5 dowhat
                                 (\S+)\s+ # 6 count
                                 (\S+)\s+ # 7 time op
                                 (\S+)\s+ # 8 time between ops
                                 /x ){
                        $field = "${1}:${2}:${3}:${4}:${5}:op";
                        $val = $7;
                        $vals{$field} = $val;
                        $field = "${1}:${2}:${3}:${4}:${5}:between_op";
                        $val = $8;
                        $vals{$field} = $val;
                    }
                }
            }

            # -------------------------------
            # ### line
            # ### <column headers> :: <date> <tstep>
            # -------------------------------
            elsif( $line =~ /^\s*\#\#\#\s*cyc\s+time\s+dt/ ){
                # remember this line for splitting of fields
                ($ppp_header = $line) =~ s/^\s+//;
                $ppp_header =~ s/\s+$//;
            }
            elsif( $line =~ /^\s*\#\#\#\s+
                        (\S+)\s+    # 1
                        (\S+)\s+    # 2
                        (\S+)\s+    # 3
                        (\S+)\s+    # 4
                        (\S+)\s+    # 5
                        (\S+)\s+    # 6
                        (\S+)\s+    # 7
                        (\S+)\s+    # 8
                        (\S+)\s+    # 9
                        (\S+)\s+    # 10
                        ((\S+)\s+)? # 11
                        (\S+)\s+    # 13
                        (::)\s+     # 14
                        (\S+)\s+    # 15
                        (\S+.*?)    # 16
                        \s*$/x ) {
                $data_found = "";
                # get fields
                $line =~ s/^\s+//;
                $line =~ s/\s+$//;
                # after this, could reset ppp_header, but keep it
                # just in case there are spliced file fragments from
                # multiple runs and one of them has correct values.
                @fields   = split( /\s+/, $ppp_header );
                @vals_arr = split( /\s+/, $line );
                undef( $time );
                undef( $dt );
                while( @vals_arr ){
                    $val   = shift( @vals_arr );
                    if( @fields ){
                        $field = shift( @fields );
                    }
                    else{
                        # field after last field is "date";
                        $field = "date";
                    }

                    # convert name if needed
                    if( $field eq "cyc" ){
                        $field = "cycle";
                    }
                    elsif( $field eq "#cell" ){
                        $field = "ncell";
                    }
                    elsif( $field eq "cc/s/pe" ){
                        $field = "cc/s/p";
                    }


                    # skip ###
                    if( $field eq "###" ){
                        # skip
                    }
                    # special - done below
                    elsif( $field eq "time" ){
                        $time = $val;
                    }
                    # special - done below
                    elsif( $field eq "dt" ){
                        $dt = $val;
                    }
                    # special for fields after "::"
                    # :: <date> <rest is time step and can have spaces>
                    elsif( $val eq "::" ){
                        # date
                        $field = "date";
                        $val   = shift( @vals_arr );
                        $vals{$field} = $val;
                        # tstep is reast of line
                        $field = "tstep";
                        $val   = join("_", @vals_arr );
                        $val   =~ s/_+$//;
                        $vals{$field} = $val;
                        @vals_arr = ();
                    }
                    else{
                        $vals{$field} = $val;
                    }

                }

                # mod some
                if( ! defined( $vals{time} ) ||
                    length($time) >= length($vals{time}) ){
                    $vals{time} = $time;
                }
                if( ! defined( $vals{dt} ) ||
                    length($dt) >= length($vals{dt}) ){
                    $vals{dt} = $dt;
                }

                # MMDD:HHMMSS (no year)
                # Make year "Y" so that this is shorter than other date strings
                # that actually have the year
                %time_h = &conv_time( STRING=>"YMDHMS $vals{date}" );
                $vals{date} = $time_h{date_dot};
                ($datestamp_line = $line) =~ s/\s*$//;
                $datestamp_ln   = $ln;

            }

            # -------------------------------
            # Begin LONG Editcycle (first part)
            # -------------------------------
            elsif( $line =~ /\*\*\* Begin LONG Editcycle/ ){

                # blank
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }

                # cycle/time/dtnext
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }
                if( $line =~ /^\s*
                              cycle\s*=\s*(\d+)\s*,\s*
                              time\s*=\s*(\S+)\s*,\s*
                              dtnext\s*=\s*(\S+)
                             \s*/x ){
                    $vals{cycle}  = $1;
                    $time         = $2;
                    $vals{dtnext} = $3;
                    if( ! defined( $vals{time} ) ||
                        length($time) >= length($vals{time}) ){
                        $vals{time} = $time;
                    }
                }

                # first block of performance
                undef( $found );
                while( 1 == 1 ){

                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( defined( $found ) && $line !~ /\S/ ){
                        last;
                    }

                    # this line has changed a bit...so make it general
                    #   pct    ->  run-pct,    sum-pct    (both there, just renamed)
                    #   calls  ->  run-calls,  sum-calls  (sum new)
                    #   s/call ->  run-s/call, sum-s/call (sum new)
                    if( $line =~ m&^\s*n\s+
                                    run\-cpusec\s+
                                    (run-)?pct(,)?\s+
                                    sum-cpusec\s+
                                    (sum-)?pct(,)?\s+
                                  &x ){
                        $line =~ s/^\s*(.*?)\s*$/$1/;
                        @fields = split(/\s+/, $line);

                        # get common names for fields
                        undef( %count );
                        foreach $field ( @fields ){
                            $field =~ s/,$//;
                            $count{$field}++;
                            if( $field =~ /^(pct|calls|s\/call)$/ ){
                                if( $count{$field} == 1 ){
                                    $field = "run-$field";
                                }
                                else{
                                    $field = "sum-$field";
                                }
                            }
                        }

                        $found = "";
                        while( 1 == 1 ){
                            # read line
                            if( ref($lines_ref) eq "ARRAY" ){
                                $line = $$lines_ref[$ln]; $ln++;
                            }
                            else{
                                $line = <$lines_ref>; $ln = length($line);
                            }
                            # done
                            if( ! defined($line) ){
                                last;
                            }
                            # done
                            if( $line !~ /\S/ ){
                                last;
                            }
                            
                            $line =~ s/^\s*(.*?)\s*$/$1/;
                            # a "," in some vals...but not all???  wow...
                            $line =~ s/\s*,\s*/ /g;
                            @vals_line = split( /\s+/, $line );
                            # line with ??? has first 2 fields skipped
                            if( $vals_line[-1] eq "???" ){
                                # put in dummy ranking (found out later, and "F")
                                unshift( @vals_line, -1, "F" );
                            }
                            # last lines have fewer fields
                            if( $#vals_line < $#fields ){
                                last;
                            }
                            $subroutine = $vals_line[-1];
                            $which = "";
                            for( $i = 0; $i <= $#fields; $i++ ){
                                $field_use = $fields[$i];
                                # skip these
                                if( $field_use =~ /^(n|subroutine)$/ ){
                                    next;
                                }
                                # adds in "T/F" in unlabeled column after n
                                $index = $i + 1;
                                # calls -> seg_calls (do running sum, more useful)
                                $field_use = "timing_${field_use}_sub_${subroutine}";
                                if( $field_use =~  /^timing_(sum|run)-calls_sub_/ ){
                                    $field_use =~ s/^timing_(sum|run)-calls_sub_/timing_seg_${1}-calls_sub_/;
                                    # if this is the first one in the file, add previous val
                                    if( ! defined($state{$field_use}) ){
                                        if( defined($$vals_ref{$field_use}) ){
                                            $state{$field_use} = $$vals_ref{$field_use}{val}[-1];
                                        }
                                        else{
                                            $state{$field_use} = 0;
                                        }
                                    }
                                    $vals_line[$index] += $state{$field_use};
                                }
                                $vals{$field_use} = $vals_line[$index];
                            }
                        }
                        # if done
                        if( defined( $found ) && $line !~ /\S/ ){
                            last;
                        }
                    }
                }

                # skip past performance stuff ("=====" of Resources)
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line =~ /================/ ){
                        last;
                    }
                }
            }

            # -------------------------------
            # long cycle info
            # -------------------------------
            elsif( $line =~ /^\s*
                        cycle\s+          #  1
                        t\s+              #  2
                        dtnext\s+         #  3
                        timestep\s+       #  4 (can be 2 words?!?)
                        cstb\s+           #  5
                        tpct\s+           #  6
                        epct\s+           #  7
                        ritr\s+           #  8
                        hitr\s+           #  9
                        sumritr\s+        # 10
                        wallhr\s+         # 11
                        sumwallhr\s+      # 12
                        sumcpuhr\s+       # 13
                        date:time\s*      # 14
                        /x ) {
                
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }
                $line =~ s/^\s*//;
                $line =~ s/\s*$//;
                
                #...replace spaces in timestep with underscores
                @fields = split(/\s+/, $line );
                while ( $#fields > 13 ) {
                    $fields[3] = "$fields[3]_$fields[4]";
                    $fields[4] = "";
                    $line = join( " ", @fields );
                    @fields = split( /\s+/, $line );
                }
                if ( $line =~ /^
                       (\S+)\s+ # 1
                       (\S+)\s+ # 2
                       (\S+)\s+ # 3
                       (\S+)\s+ # 4
                       (\S+)\s+ # 5
                       (\S+)\s+ # 6
                       (\S+)\s+ # 7
                       (\S+)\s+ # 8
                       (\S+)\s+ # 9
                       (\S+)\s+ # 10
                       (\S+)\s+ # 11
                       (\S+)\s+ # 12
                       (\S+)\s+ # 13
                       (\S+)    # 14
                       $/x ) {
                    $data_found = "";
                    $vals{"cycle"}     = $1;
                    $time              = $2;
                    $dt                = $3;
                    $vals{"tstep"}     = $4;
                    $vals{date}        = $14;
                    $vals{"#ritr"}     = $8;
                    $vals{"sumwallhr"} = $12;
                    $vals{"sumcpu"}    = $13;
                    $vals{"tstep"}     =~ s/\s+/_/g;
                    # mod some
                    if( ! defined( $vals{dt} ) ||
                        length($dt) >= length($vals{dt}) ){
                        $vals{dt} = $dt;
                    }
                    if( ! defined( $vals{time} ) ||
                        length($time) >= length($vals{time}) ){
                        $vals{time} = $time;
                    }
                    # YYYYMMDD:HHMMSS
                    $vals{date} =~ s/(\S{4})(\S{2})(\S{2}):(\S{2})(\S{2})(\S{2})/$1.$2.$3.$4.$5.$6/;
                    %time_h = &conv_time( STRING=>"YMDHMS $vals{date}" );
                    $vals{date}     = $time_h{date_dot};
                    ($datestamp_line = $line) =~ s/\s*$//;
                    $datestamp_ln   = $ln;
                }
            }

            # -------------------------------
            # ISO: Isotope Summary
            # -------------------------------
            elsif( $line =~ /\*\*\* ISO: Isotope Summary \*\*\*/ ){
                $data_found = "";
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                    if( $line =~ /Time:\s*(\S+)\s*Cycle:\s*(\d+)/ ){
                        $time        = $1;
                        $vals{cycle} = $2;
                        if( ! defined( $vals{time} ) ||
                            length($time) >= length($vals{time}) ){
                            $vals{time} = $time;
                        }
                    }

                    # Could read in column headers but just assume will not change.
                    # If it does, simply add in reader and parse fields
                    elsif( $line =~ /^\s*
                                    (isosum)_(\S+)\s+  # 1: TAG
                                    (\S+)\s+           # 3: TIME (already have)
                                    (\S+)\s+           # 4: CYCLE (already have)
                                    (\S+)\s+           # 5: ISOTOPE
                                    (\S+)\s+           # 6: NUMBER
                                    (\S+)\s+           # 7: MOLES
                                    (\S+)\s*           # 8: MASS
                                   /x ){
                        $val   = $6;
                        $val_1 = $7;
                        $val_2 = $8;
                        # always print these since want to know when an
                        # iso goes to 0 (HE)
                        if( 1 == 1 || $val > 0 ){
                            $field_1 = sprintf( "%s_%03d_%s", ${1}, ${2}, ${5} );
                            $vals{"${field_1}_NUMBER"} = $val;
                            $vals{"${field_1}_MOLES"}  = $val_1;
                            $vals{"${field_1}_MASS"}   = $val_2;
                        }
                    }

                    # done
                    elsif( $line =~ /\*\*\* End ISO: Isotope Summary \*\*\*/ ){
                        last;
                    }
                }
            }

            # -------------------------------
            # cell info
            # -------------------------------
            elsif( $line =~ /^\s*.*\ssum_cell\s.*\savg_cell\s.*\savg_top\s/ ){
                $line =~ s/^\s*//;
                $line =~ s/\s*$//;
                @fields = split( /\s+/, $line );

                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }
                $line =~ s/^\s*//;
                $line =~ s/\s*$//;

                $data_found = "";

                @vals_line = split( /\s+/, $line );
                for( $i = 0; $i <= $#fields; $i++ ){
                    # nummat to state
                    if( $fields[$i] eq "nummat" ){
                        $state{nummat} = $vals_line[$i];
                    }
                    if( $fields[$i] eq "sum_cell"){
                        $vals{ncell} = $vals_line[$i];
                    }
                    elsif( $fields[$i] eq "sum_top"){
                        $vals{pct_top} = 100.0*$vals_line[$i]/$vals{ncell};
                    }
                    elsif( $fields[$i] =~ /^(max_cell|avg_cell|min_cell)$/ ){
                        $vals{$1} = $vals_line[$i];
                    }
                    elsif( $fields[$i] eq "free_mem"){
                        $vals{procmon_machine_free_min} = $vals_line[$i];
                    }
                    elsif( $fields[$i] eq "pct"){
                        $vals{procmon_free_mem_pct_min} = $vals_line[$i];
                    }
                }
            }

            # -------------------------------
            # what info (Extrema)
            # -------------------------------
            elsif( $line =~ /^\s*
                             Extrema\s+   # start
                             for\s+cycle\s+number:\s*(\d+)\s+
                             at\s+time\s+(\S+)/x ){
                $vals{cycle} = $1;
                $time = $2;
                if( ! defined( $vals{time} ) ||
                    length($time) >= length($vals{time}) ){
                    $vals{time} = $time;
                }
            }
            elsif( $line =~ /^\s*
                       what\s+    #  1
                       max\s+     #  2
                       cell\s+    #  3
                       (xc)\s*    #  4
                       (yc)?\s*   #  5
                       (zc)?\s*   #  6
                       min\s+     #  7
                       cell\s+    #  8
                       xc\s*      #  9
                       (yc)?\s*   # 10
                       (zc)?\s*   # 11
                       /x ){

                $data_found = "";

                $dim = 1;
                $dim_name[1] = "1_$1";
                if( defined($2) ){
                    $dim = 2;
                    $dim_name[2] = "2_$2";
                }
                if( defined($3) ){
                    $dim = 3;
                    $dim_name[3] = "3_$3";
                }
                $state{dim} = $dim;
                undef( $done_1 );
                while( ! defined($done_1) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    $line =~ s/^\s*//;
                    $line =~ s/\s*$//;
                    if( $line !~ /^[A-Z]/ ||
                        $line =~ /^FYI, / ) {
                        last;
                    }
                    #...boo! var name might have space in it
                    $line =~ s/([A-Z])\s+([A-Z])/${1}_${2}/g;
                    @fields = split( /\s+/, $line );
                    # replace 1-145 -> 1E-145
                    grep( s/(\d)-(\d)/${1}E-$2/, @fields );
                    $index = 0;
                    $field = "what_$fields[$index]";
                    $index++;
                    $vals{"${field}_max"} = $fields[$index];
                    $index += 2;
                    $dist = 0;
                    for( $i = 1; $i <= $dim; $i++ ) {
                        $dist += $fields[$index]**2;
                        $vals{"${field}_max_$dim_name[$i]"} = $fields[$index];
                        $index++;
                    }
                    $dist = $dist**.5;
                    $vals{"${field}_max_dist"} = $dist;
                    $vals{"${field}_min"}      = $fields[$index];
                    $index += 2;
                    $dist = 0;
                    for( $i = 1; $i <= $dim; $i++ ) {
                        $dist += $fields[$index]**2;
                        $vals{"${field}_min_$dim_name[$i]"} = $fields[$index];
                        $index++;
                    }
                    $dist = $dist**.5;
                    $vals{"${field}_min_dist"} = $dist;
                }
            }

            # -------------------------------
            # integrated_state_data
            # -------------------------------
            elsif( $line =~ /^\s*
                             Integrated\s+state\s+data\s+   # start
                             for\s+cycle\s+number:\s*(\d+)\s+
                             at\s+time\s+(\S+)/x ){
                $vals{cycle} = $1;
                $time = $2;
                if( ! defined( $vals{time} ) ||
                    length($time) >= length($vals{time}) ){
                    $vals{time} = $time;
                }
            }
            elsif( $line =~ /tmxd\s+=.*\s+tmass\s+=/ ){
                $data_found = "";
                $name = "Integrated_state_data";
                # already at data so back up
                # back up one line
                if( ref($lines_ref) eq "ARRAY" ){
                    $ln--;
                }
                else{
                    seek($lines_ref, -$ln, 1);
                }
                undef( $done_1 );
                while( ! defined($done_1) ){
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    # if line has any <foo> = <bar> not done, otherwise done
                    $done_1 = "true";
                    while( $line =~ /^\s*(\S+)\s*=\s*(\S+)\s*(.*?)\s*$/ ){
                        $field = $1;
                        $val   = $2;
                        $line  = $3;
                        # skip some fields
                        #   ver_r, ver_s: version
                        if( $field =~ /^(ver_r|ver_s)$/ ){
                            next;
                        }
                        # error/err also stored here
                        if( $field eq "error" ){
                            $field = "err";
                        }
                        # eot (energy out) should be 0 or negative
                        # Plot this on log scale, so save neg_eot
                        if( $field eq "eot" ){
                            $field = "-eot";
                            # mult by -1 converts to int
                            # -$val prepends a "+"
                            # fix one or other
                            $val = -$val;
                            $val =~ s/^\+//;
                        }
                        # error stored elsewhere
                        if( $field eq "err" ){
                            $field_use = "err";
                        }
                        else{
                            $field_use = "$name:$field";
                        }
                        
                        $vals{$field_use} = $val;
                        undef( $done_1 );
                    }
                }
                # back up one line
                if( ref($lines_ref) eq "ARRAY" ){
                    $ln--;
                }
                else{
                    seek($lines_ref, -$ln, 1);
                }
            }

            # time step report
            elsif( $line =~ /^\s*Time step report: State data for the cell/ ){
                undef( $done_1);
                while( ! defined($done_1)  ) {
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    
                    if( 
                        $line =~ /^\s*-------------------/ ||
                        $line =~ /^\s*tstepnum =/ ||
                        $line =~ /^\s*ldt = / ||
                        $line =~ /^\s*level = / ||
                        $line =~ /^\s*mat = / ||
                        $line =~ /^\s*md01 = / ||
                        $line =~ /^\s*pmx = / ||
                        $line =~ /^\s*sxx = / ||
                        $line =~ /^\s*nm = /
                        ){
                        next;
                    }

                    last;
                }

                # back up one line
                if( ref($lines_ref) eq "ARRAY" ){
                    $ln--;
                }
                else{
                    seek($lines_ref, -$ln, 1);
                }
            }

            # -------------------------------
            # matinfo (State data by material)
            # -------------------------------
            elsif( $line =~ /^\s*
                             State\s+data\s+by\s+material\s+   # start
                             for\s+cycle\s+number:\s*(\d+)\s+
                             at\s+time\s+(\S+)/x ){
                $vals{cycle} = $1;
                $time = $2;
                if( ! defined( $vals{time} ) ||
                    length($time) >= length($vals{time}) ){
                    $vals{time} = $time;
                }
            }
            # matinfo header line
            # assume will always start consistent set of fields and end in matident
            #zzz
            elsif( $line =~ /^\s*
                        (mat)\s+    #  1
                        (md01)\s+   #  2
                        (md61)\s+   #  3
                        (mass)\s+   #  4
                        .*          # other fields
                        (matident)  # end with matident
                   /x ){
                $line =~ s/^\s+//;
                $line =~ s/\s+$//;
                @fields = split( /\s+/, $line );
                undef( $done_1 );
                while( ! defined($done_1) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                    # fix broken exponent 1-123 -> 1E-123
                    $line =~ s/(\d)(-\d\d\d)/$1E$2/g;

                    # stuff into hash fieldsh_orig
                    $line =~ s/^\s+//;
                    $line =~ s/\s+$//;
                    @vals_arr = split( /\s+/, $line );

                    # done
                    if( $line !~ /^\s*\d/ || $#vals_arr < $#fields ){
                        last;
                    }
                    
                    undef( %fieldsh_orig );
                    foreach $field ( @fields ){
                        # rest of line is matident (can have spaces...yuck)
                        if( $field eq "matident" ){
                            $fieldsh_orig{$field} = join( " ", @vals_arr );
                            last;
                        }
                        $fieldsh_orig{$field} = shift( @vals_arr );
                    }
                    if( ! defined( $fieldsh_orig{matident} ) ){
                        last;
                    }

                    # fieldsh_orig -> fieldsh
                    undef( %fieldsh );
                    # set mass now
                    $fieldsh{mass} = $fieldsh_orig{mass};
                    # set vol  now
                    if( $fieldsh_orig{rho} != 0 ) {
                        $fieldsh{vol} = $fieldsh{mass}/$fieldsh_orig{rho};
                    }
                    else{
                        $fieldsh{vol} = 0;
                    }
                    foreach $field ( keys %fieldsh_orig ){
                        if( $field eq "mat" ){
                            $fieldsh{matnum} = $fieldsh_orig{$field};
                        }
                        elsif( $field eq "matident" ){
                            ($fieldsh{mat} = $fieldsh_orig{$field}) =~ s/\s+/_/g;
                        }
                        # specific by mass
                        elsif( $field =~ /^(eng|sie|ske|spe|sxe)$/ ){
                            # remove beginning s=specific
                            ($field_use = $field) =~ s/^s//;
                            if( $field_use =~ /^(eng|ie)$/ ){
                                $fieldsh{$field_use} = 
                                    sprintf( "%.14e", $fieldsh_orig{$field} * $fieldsh{mass} );
                            }
                            else{
                                $fieldsh{$field_use} =
                                                      $fieldsh_orig{$field} * $fieldsh{mass};
                            }
                        }
                        # specific by volume
                        elsif( $field =~ /^(re|beng)$/ ){
                            $fieldsh{$field} = $fieldsh_orig{$field} * $fieldsh{vol};
                        }
                        # default set to same
                        else{
                            $fieldsh{$field} = $fieldsh_orig{$field};
                        }
                    }
                    
                    # mat name needs to include matnum so that sorting prints in order
                    $mat = sprintf( "%03d.%s",
                                    $fieldsh{matnum}, $fieldsh{mat} );
                    foreach $field ( keys %fieldsh ){
                        # not shoved into vals
                        if( $field =~ /^(mat|matnum|md.*)$/ ){
                            next;
                        }
                        $vals{"matinfo_${mat}_$field"} = $fieldsh{$field};
                    }
                }
            }

            # -------------------------------
            # mixed material cells
            # material distribution for cycle number...
            # -------------------------------
            elsif( $line =~ /^\s*
                             Material\s+distribution\s+   # start
                             for\s+cycle\s+number:\s*(\d+)\s+
                             at\s+time\s+(\S+)/x ){
                $vals{cycle} = $1;
                $time = $2;
                if( ! defined( $vals{time} ) ||
                    length($time) >= length($vals{time}) ){
                    $vals{time} = $time;
                }
            }

            elsif( $line =~ /----- cells containing material ----/ ) {
            
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }
                undef($done_1);
                while( ! defined($done_1) ) {
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line !~ /\S/ ) {
                        last;
                    }
                    if ( $line =~ /^\s*
                         (\d+)\s*:\s* # 1: material number
                         /x ) {
                        $state{nummat} = $1;
                    }
                }
            }

            # -------------------------------
            # mixed material cells
            # (material distribution)
            #
            # Goal: variables showing:
            #   o number of cells that have > 1 material in them (mixed)
            #   o average number of materials per cell
            #
            # Processes following block as example at a particular cycle:
            #   >
            #   >       ---------- cells with num materials ----------
            #   > num   -------- total -------  ------- active -------
            #   >   1:           131 ( 80.9% )           115 ( 87.8% )
            #   >   2:            31 ( 19.1% )            16 ( 12.2% )
            #   >
            #   >                  total  active
            #   > materials/cell    1.19    1.12
            #
            # The labeling of the "material distribution" fields has
            # changed over time.
            # Used to be "all" instead of "total"
            # Used to be "top" instead of "active".
            # I kept the variable names the same just in case some
            # folks were parsing these values.  But now, the single
            # letter "A" and "T" in the var names is just confusing.
            # If a single letter:
            #   A = All cells = total
            #   T = Top (Top =~ Active...approximately - can have inactive top)
            #
            # Vars:
            #
            # NcellAMix    - all : percentage of cells that are mixed
            # NcellTMix    - top : percentage of cells that are mixed 
            # NcellAMixAvg - all : average number of mats per cell
            # NcellTMixAvg - top : average number of mats per cell
            # MatPctTot    - all : :<pct cells N mats>:<pct cells N+1 mats>:
            # MatPctTop    - top : :<pct cells N mats>:<pct cells N+1 mats>:
            #
            # Following are from the "materials/cell" line...but have
            # fewer digits of precision.
            # MatDistMatPerCellTotal  - all : NcellAMixAvg
            # MatDistMatPerCellActive - top : NcellTMixAvg
            # -------------------------------
            elsif( $line =~ /----- cells with num materials -----/ ) {
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }
                $ncell_all            = 0;
                $ncell_top            = 0;
                $ncell_all_mixed      = 0;
                $ncell_top_mixed      = 0;
                $ncell_all_mixed_mats = 0;
                $ncell_top_mixed_mats = 0;
                undef( %fieldsh );
                undef( $done_1 );
                while( ! defined($done_1) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line !~ /\S/ ){
                        last;
                    }
                    if( $line =~ /^\s*
                         (\d+)\s*:\s* # 1: number of materials
                         (\d+)\s*     # 2: number of cells total
                         \(\s*        # (
                         (\S+)        # 3: percent of tot
                         \s*[,%]\s*\)\s* # ,)
                         (\d+)\s*     # 4 : number of cells active
                         \(\s*        # (
                         (\S+)        # 5: percent of tot
                         \s*[,%]\s*\)\s* # ,)
                         /x ) {
                        $num_mats = $1;
                        $nall_num = $2;
                        $ntop_num = $4;
                        $fieldsh{tot}{$1} = $3;
                        $fieldsh{top}{$1} = $5;
                        $ncell_all += $nall_num;
                        $ncell_top += $ntop_num;
                        if( $num_mats > 1 ){
                            $ncell_all_mixed += $nall_num;
                            $ncell_top_mixed += $ntop_num;
                        }
                        $ncell_top_mixed_mats += $ntop_num*$num_mats;
                        $ncell_all_mixed_mats += $nall_num*$num_mats;
                    }
                }

                # NcellAMix    - all : percentage of cells that are mixed
                # NcellTMix    - top : percentage of cells that are mixed 
                # NcellAMixAvg - all : average number of mats per cell
                # NcellTMixAvg - top : average number of mats per cell
                # MatPctTot    - all : :<pct cells N mats>:<pct cells N+1 mats>:
                # MatPctTop    - top : :<pct cells N mats>:<pct cells N+1 mats>:
                if( $ncell_all > 0 ){
                    $vals{NcellAMix}    = ($ncell_all_mixed/$ncell_all)*100.0;
                    $vals{NcellTMix}    = ($ncell_top_mixed/$ncell_top)*100.0;
                    $vals{NcellTMixAvg} = $ncell_top_mixed_mats/$ncell_top;
                    $vals{NcellAMixAvg} = $ncell_all_mixed_mats/$ncell_all;
                    $vals{MatPctTot}    = "";
                    $vals{MatPctTop}    = "";
                    for( $i = 1; $i <= $state{nummat}; $i++ ){
                        if( defined( $fieldsh{tot}{$i} ) ){
                            $vals{MatPctTot} .= "$fieldsh{tot}{$i}:";
                            $vals{MatPctTop} .= "$fieldsh{top}{$i}:";
                        }
                        else{
                            $vals{MatPctTot} .= "-:";
                            $vals{MatPctTop} .= "-:";
                        }
                    }
                    $vals{MatPctTot} =~ s/:$//;
                    $vals{MatPctTop} =~ s/:$//;
                }

                # blank line
                if( $line !~ /\S/ ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                }
                # total/active
                if( $line =~ /^\s*total\s+active\s*$/ ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                }
                # total/active
                #   MatDistMatPerCellTotal  - total  : NcellAMixAvg
                #   MatDistMatPerCellActive - active : NcellTMixAvg
                if( $line =~ /^\s*materials\/cell\s*(\S+)\s+(\S+)\s*$/ ){
                    $vals{MatDistMatPerCellTotal}  = $1;
                    $vals{MatDistMatPerCellActive} = $2;
                }

            }

            # -------------------------------
            # AMR Information
            # -------------------------------
            elsif( $line =~ /^\s*
                             AMR\s+Information\s+   # start
                             for\s+cycle\s+number:\s*(\d+)\s+
                             at\s+time\s+(\S+)/x ){
                $vals{cycle} = $1;
                $time = $2;
                if( ! defined( $vals{time} ) ||
                    length($time) >= length($vals{time}) ){
                    $vals{time} = $time;
                }
                
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }

                # level info and total (until blank line)
                undef( $done );
                undef( @fields );
                $field_use = "l";
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    
                    # done if blank
                    if( $line !~ /\S/ ){
                        last;
                    }

                    # trim, split
                    $line =~ s/^\s+//;
                    $line =~ s/\s+$//;
                    @vals_line = split(/\s+/, $line);
                    
                    # header
                    if( $line =~ /^\s*level\s+/ ){
                        @fields = @vals_line;
                    }

                    # data
                    elsif( $line =~ /^\d+/ ){
                        if( $field_use eq "l" ){
                            for( $j = 0; $j <= $#vals_line; $j++ ){
                                if( $fields[$j] eq "level" ){
                                    $field_new = "l_$vals_line[$j]";
                                    next;
                                }
                                # just do numall/numact
                                if( $fields[$j] !~ /^(numall|numact)$/ ){
                                    next;
                                }
                                $vals{"$fields[$j]_${field_new}"} = $vals_line[$j];
                            }
                        }
                        # totals
                        elsif( $field_use eq "t" ){
                            for( $j = 0; $j <= $#vals_line; $j++ ){
                                $field_1 = $fields[$j+1];
                                $vals{"$field_1"} = $vals_line[$j];
                                if( $j > 0 ){
                                    last;
                                }
                            }                            
                        }
                    }

                    # separator to totals
                    elsif( $line =~ /^-{2,}\s+-{2}/){
                        $field_use = "t";
                    }

                } # level and total info

                # done
                if( ! defined($line) ){
                    last;
                }

                # read next if blank
                if( $line !~ /\S/ ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                }
                
                # (3-d numall, numact)
                # This is NOT numall/numact ... I have no idea what this is.
                # It might be "if this problem were 3d at min resolution,
                # this is the number of cells"...but I do not know.
                if( $line =~ /(numall|numact)/ ){
                    undef( $done );
                    while( ! defined($done) ){

                        # numall/numact
                        if( $line =~ /^\s*.*(numall|numact)\s*=\s*(\d+)/ ){
                            $vals{"${1}_3d"} = $2;
                        }
                        # read line
                        if( ref($lines_ref) eq "ARRAY" ){
                            $line = $$lines_ref[$ln]; $ln++;
                        }
                        else{
                            $line = <$lines_ref>; $ln = length($line);
                        }
                        # done
                        if( ! defined($line) ){
                            last;
                        }
                        # stop if blank
                        if( $line !~ /\S/ ){
                            last;
                        }
                    }
                }
                
                # blank line
                if( $line !~ /\S/ ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                }
                # metric: contiguity
                if ( $line =~ /^\s*
                      metric:\s+
                        (contiguity)\s+(\S+)\s+(\S+) # contiguity
                        /x ) {
                    $fields[1] = $1;
                    $fields[2] = $2;
                    $fields[3] = $3;
                    $field = "metric:$fields[1]";
                    if ( $fields[1] eq "contiguity" ) {
                        $vals{"$field"} = $3;
                    }
                }
            }

            # -------------------------------
            # Mass and energy sources and sinks
            # -------------------------------
            elsif( $line =~ /^\s*
                             Mass\s+and\s+energy\s+sources\s+and\s+sinks\s+   # start
                             for\s+cycle\s+number:\s*(\d+)\s+
                             at\s+time\s+(\S+)/x ){
                $vals{cycle} = $1;
                $time = $2;
                if( ! defined( $vals{time} ) ||
                    length($time) >= length($vals{time}) ){
                    $vals{time} = $time;
                }
                # separator and header
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }
                
                # vals
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    $field = "energy_source_sink:";
                    if( $line =~ /^\s*
                                 (\d+)\s+            # 1: n
                                 (\S+(\s-\s\S+)?)\s+   # 2,3: energy source
                                 (\S+)\s+            # 4: eng-in
                                 (\S+)\s*            # 5: eng-out
                                 \s*$/x ){
                        $field_1   = $2;
                        $eng_in  = $4;
                        $eng_out = $5;
                        # fix poorly formatted 3 digit exponents
                        $eng_in  =~ s/(\d)-(\d)/${1}E-${2}/;
                        $eng_out =~ s/(\d)-(\d)/${1}E-${2}/;
                        $field_1 =~ s/\s/_/g;
                        # not sure if you want to skip the 0s...
                        if( $eng_in != 0 ){
                            $vals{"${field}:${field_1}:eng-in"}  = $eng_in;
                        }
                        if( $eng_out != 0 ){
                            $vals{"${field}:${field_1}:eng-out"} = $eng_out;
                        }
                    }
                    else{
                        last;
                    }
                }
            }

            # more energy source sink lines
            elsif( $line =~ /^\s*
                             dir\s+
                             eng-in-lo\s+
                             eng-out-lo\s+
                             eng-in-hi\s+
                             eng-out-hi\s+
                             $/x ){

                undef($done_1);
                while( ! defined($done_1) ) {
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line !~ /^\s*\d+\s+/ ) {
                        last;
                    }
                }
                
                # back up one line (since read to following line)
                if( ref($lines_ref) eq "ARRAY" ){
                    $ln--;
                }
                else{
                    seek($lines_ref, -$ln, 1);
                }
            }

            # -------------------------------
            # Cell distribution
            # -------------------------------
            elsif( $line =~ /^\s*
                             Cell\s+distribution\s+   # start
                             for\s+cycle\s+number:\s*(\d+)\s+
                             at\s+time\s+(\S+)/x ){
                $vals{cycle} = $1;
                $time = $2;
                if( ! defined( $vals{time} ) ||
                    length($time) >= length($vals{time}) ){
                    $vals{time} = $time;
                }

                # get past separator
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }
                
                # skip to blank line or separator
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line !~ /\S/ || 
                        $line =~ /^\s*\-{5}/ ){
                        last;
                    }
                }
            }

            # -------------------------------
            # Time Step Restrictions
            # -------------------------------
            elsif( $line =~ /^\s*
                             Time\s+Step\s+Restrictions\s+   # start
                             for\s+cycle\s+number:\s*(\d+)\s+
                             at\s+time\s+(\S+)/x ){
                $vals{cycle} = $1;
                $time = $2;
                if( ! defined( $vals{time} ) ||
                    length($time) >= length($vals{time}) ){
                    $vals{time} = $time;
                }
                # skip to blank line
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line !~ /\S/ ){
                        last;
                    }
                }
            }

            # -------------------------------
            # process info
            # -------------------------------
            elsif( $line =~ /^\s*
                      procmon:
                        \s+(\S+)    # 1: field name
                        \s+(\S+)    # 2: min
                        \s+(\S+)    # 3: max
                        \s+(\S+)    # 4: avg
                        (\s+(\S+))? # 5: sum
                        /x ) {
                $data_found = "";
                $vals{"procmon_${1}_min"} = $2;
                $vals{"procmon_${1}_max"} = $3;
                $vals{"procmon_${1}_avg"} = $4;
                if ( defined($5) ) {
                    $vals{"procmon_${1}_sum"}[$cycle] = $5;
                }
            }

            # -------------------------------
            # cyc_ info
            # -------------------------------
            elsif ( $line =~ /^\s*
                        (cyc_cc\/s)\s+     #  1
                        (cyc_sec)\s+       #  2
                        (cyc_cc\/s\/pe)\s+ #  3
                        /x ) {
                $fields[1] = $1;
                $fields[2] = $2;
                $fields[3] = "cc/s/p";
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }
                $data_found = "";
                if ( $line =~ /^\s*
                       (\S+)\s+
                       (\S+)\s+
                       (\S+)\s+
                       /x ) {
                    $vals{$fields[3]} = $3;
                }
            }

            # -----------------------
            # laser
            # -----------------------
            elsif( $line =~ /^\s*
                          (nvert_inner)\s*(\d+)\s*
                          (nvert_crit)\s*(\d+)\s*
                          (nvert_fine)\s*(\d+)\s*
                          (nvert_outer)\s*(\d+)\s*
                            /x ){
                $vals{"LLE_RT_$1"} = $2;
                $vals{"LLE_RT_$3"} = $4;
                $vals{"LLE_RT_$5"} = $6;
                $vals{"LLE_RT_$7"} = $8;
            }
            elsif( $line =~ /^\s*Plotting ray trajectories/ ||
                   $line =~ /^\s*plot_lle_mesh: / ||
                   $line =~ /^\s*MESSAGE\{dlib/ ||
                   $line =~ /^\s*INFORMATION\{dlib/ ||
                   $line =~ /^\s*DIAGNOSTIC\{dlib/ ||
                   $line =~ /^\s*WARNING\{dlib/
                ){
            }

            # -------------------------------
            # probe data
            # only the first time the probe is triggered is recorded
            # -------------------------------
            elsif( $line =~ /^\s*Probe\s+data/i ){
                $data_found = "";

                # go past header
                # read line
                if( ref($lines_ref) eq "ARRAY" ){
                    $line = $$lines_ref[$ln]; $ln++;
                }
                else{
                    $line = <$lines_ref>; $ln = length($line);
                }
                # done
                if( ! defined($line) ){
                    last;
                }

                undef( $done_1 );
                while( ! defined($done) ){

                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                    # data
                    # probe line
                    if( $line =~ /^\s*
                            (\S+)\s+ # 1 n
                            (\S+)\s+ # 2 x
                            (\S+)\s+ # 3 y
                            (\S+)\s+ # 4 z
                            (\S+)\s+ # 5 time
                            (\S+)\s+ # 6 type
                            (\S+)\s* # 7 value
                            (\S+)?   # 8 speed (if moving)
                            /x ){
                        $probe      = $1;
                        $x          = $2;
                        $y          = $3;
                        $z          = $4;
                        $time_trig  = $5;
                        $type       = $6;
                        $val        = $7;
                        $speed      = $8;

                        # mod some
                        $dist       = ($x**2 + $y**2 + $z**2)**.5;
                        if( ! defined($speed) ){
                            $speed = 0;
                        }

                        # probes that have not triggered yet have huge time
                        if( $time_trig < 1e50 ){
                            $field = "probe_${probe}_dist";
                            # if probe not set already
                            if( ! defined($$vals_ref{$field}) ){
                                $field = "probe_${probe}_x";
                                $vals{$field} = $x;
                                $field = "probe_${probe}_y";
                                $vals{$field} = $y;
                                $field = "probe_${probe}_z";
                                $vals{$field} = $z;
                                $field = "probe_${probe}_time_trig";
                                $vals{$field} = $time_trig;
                                $field = "probe_${probe}_type";
                                $vals{$field} = $type;
                                $field = "probe_${probe}_value";
                                $vals{$field} = $val;
                                $field = "probe_${probe}_dist";
                                $vals{$field} = $dist;
                                $field = "probe_${probe}_speed";
                                $vals{$field} = $speed;
                            } # if probe not set already
                        } # probes that have not triggered yet
                    } # probe line

                    # done with probe
                    else{
                        last;
                    }
              
                }
            }

            # -------------------------------
            # creating hdf files
            # -------------------------------
            elsif( $line =~ /^\s*HDF\d*PLT called.*\s+(\S+)\s+(\S+)\s+(\S+)\s*$/ ) {
                $data_found = "";
                $vals{cycle} = $1;
                # get to dump time spent line
                undef($done_1);
                $field = "hdf_write_time";
                while( ! defined($done_1) ) {
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if( $line =~ /^\s*HDF\d*PLT finished.\s*cpu\s*=\s*(\S+)/ ) {
                        $vals{$field} = $1;
                        last;
                    }
                }
            }

            # -------------------------------
            # creating ensight files
            # -------------------------------
            elsif( $line =~ /^\s*
                   ENSIGHT:\s*Wrote\s*
                   (\S+)\s+Mbytes\s+in\s*
                   (\S+)\s+elapsed
                   \s*/x ) {


                # while reading ensight write lines, sum up secs
                undef( $done );
                $secs = 0;
                while( ! defined($done) ){
                    if( $line =~ /^\s*
                        ENSIGHT:\s*Wrote\s*
                        (\S+)\s+Mbytes\s+in\s*
                        (\S+)\s+elapsed
                        \s*/x ) {
                        $secs += $1;
                    }
                    else{
                        last;
                    }

                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                } # while reading ensight write lines

                # set ensight_write_time
                $vals{ensight_write_time} = $secs;
                $data_found = "";

                # back up one line (since read to following line)
                if( ref($lines_ref) eq "ARRAY" ){
                    $ln--;
                }
                else{
                    seek($lines_ref, -$ln, 1);
                }

            }

            # -------------------------------
            # creating ensight files
            # Closed Parallel IO file: EnSight6.geo000001 dandt = 20180129:091638.059 Mbytes =   1.59E+01 sec =   1.46E-01 Mbytes/sec =   1.09E+02
            # -------------------------------
            elsif( $line =~ /^\s*
                   Closed\sParallel\sIO\sfile:\sEnSight
                   .*
                   \ssec\s=\s+(\S+)
                   /x ) {

                # while reading ensight write lines, sum up secs
                undef( $done );
                $secs = 0;
                while( ! defined($done) ){
                    if( $line =~ /^\s*
                        Closed\sParallel\sIO\sfile:\sEnSight
                        .*
                        \ssec\s=\s+(\S+)
                        /x ) {
                        $secs += $1;
                    }
                    else{
                        last;
                    }

                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                } # while reading ensight write lines

                # set ensight_write_time
                $vals{ensight_write_time} = $secs;
                $data_found = "";

                # back up one line (since read to following line)
                if( ref($lines_ref) eq "ARRAY" ){
                    $ln--;
                }
                else{
                    seek($lines_ref, -$ln, 1);
                }

            }

            # ---------------------------------------
            # RESIZE has cycle number in it (no time)
            # This will be the cycle on the dump
            # ---------------------------------------
            elsif( $line =~ /^\s*RESIZE: cycle, oldsize,.*=\s*(\d+)/ ){
                $state{cycle} = $1;
                # only store it if existing $$vals_ref
                # Otherwise, if dump from restart only, this will trigger
                # data (io time/rates) to be stored to cycle that has no
                # time field.
                if( defined($$vals_ref{cycle}) ){
                    $vals{cycle} = $1;
                }
            }


            # BHR3
            elsif( $line =~ /^\s*\#\#\#(BHR3)/ ){
                $field_new = $1;
                $line_tmp = $line;
                while( $line_tmp =~ /^(.*)(\s(\S+)\s*=\s*(\S+)\s)(.*)$/ ){
                    $field = $3;
                    $val   = $4;
                    $field_1 = "${field_new}_$field";
                    if( $field eq "t" ){
                        $field_1 = "time";
                        # only add if more precision
                        if( defined( $vals{$field_1} ) &&
                            length($val) <= length($vals{$field_1}) ){
                            undef( $val );
                        }
                    }
                    elsif( $field eq "cyc" ){
                        $field_1 = "cycle";
                    }
                    elsif( $field eq "dt" ){
                        $field_1 = "dt";
                        # only add if more precision (and always)
                        # Restart issue.
                        # This is not printed every cycle.
                        # Have test that restarts from another dump where
                        # previous cycle had print (and got precise dt).
                        # Restart sets low precision dt...and diffs.
                        # Wish to keep tight tols on that test...so just
                        # skip this for now.
                        if( 1 == 1 ||
                            ( defined( $vals{$field_1} ) &&
                              length($val) <= length($vals{$field_1}) ) ){
                            undef( $val );
                        }
                    }
                    if( defined( $val ) ){
                        $vals{"$field_1"} = $val;
                    }
                    # and shrink line
                    $line_tmp = "$1 $5";
                }
            }

            # -----------------
            # dump/ncycle block
            # This will be the cycle on the dump just read
            # -----------------
            elsif( $line =~ /^\s*dump\s*=\s*(T|F)/ ){

                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                    # cycle
                    if( $line =~ /^\s*ncycle\s*=\s*(\d+)/ ){
                        $state{cycle} = $1;
                        # only store it if existing $$vals_ref
                        # Otherwise, if dump from restart only, this will trigger
                        # data (io time/rates) to be stored to cycle that has no
                        # time field.
                        if( defined($$vals_ref{cycle}) ){
                            $vals{cycle} = $state{cycle};
                        }
                    }
                    elsif( $line !~ /\S/ ){
                        last;
                    }
                }
            }

            # -----------------
            # cstab, alarm_flag block
            # skip these blocks
            # -----------------
            elsif( $line =~ /^\s*(cstab|alarm_flag)\s*=\s*(\S+)\s*$/ ){

                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                    # done if blank line or does not match
                    if( $line !~ /^\s*(\S+)\s*=\s*(\S+)\s*$/ ){
                        # back up if not a blank line
                        if( $line =~ /\S/ ){
                            # back up one line
                            if( ref($lines_ref) eq "ARRAY" ){
                                $ln--;
                            }
                            else{
                                seek($lines_ref, -$ln, 1);
                            }
                        }
                        last;
                    }
                }
            }

            # ------------------------
            # secs_run = (time program ran)
            # ------------------------
            elsif( $line =~ /^\s*sec\s*=\s*(\S+)\s*$/ ){
                $data_found = "";
                $vals{secs_run} = $1;
            }

            # ----------
            # spica crap
            # ----------
            elsif( $line =~ /Warning, SC_makeTabular/ ){

                while( defined($line) && 
                       $line =~ /(Warning, SC_makeTabular|Removed)/ ){
                    
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    
                }

                # back up one line
                if( ref($lines_ref) eq "ARRAY" ){
                    $ln--;
                }
                else{
                    seek($lines_ref, -$ln, 1);
                }

            }

            # ----------
            # INITIAL
            # ----------
            elsif( $line =~ /^\s*INITIAL: time to fill/ ){

                undef($done_1);
                while( ! defined($done_1) ) {
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if(
                        $line =~ /^\s*numpe\s+=\s+\S+\s*$/ ||
                        $line =~ /^\s*numdim\s+=\s+\S+\s*$/ ||
                        $line =~ /^\s*numvel\s+=\s+\S+\s*$/ ||
                        $line =~ /^\s*numfine\s+=\s+\S+\s*$/ ||
                        $line =~ /^\s*maxlevel\s+=\s+\S+\s*$/ ||
                        $line =~ /^\s*numcells\s+=\s+\S+\s*$/
                        ) {
                        next;
                    }

                    last;
                }
                
                # back up one line (since read to following line)
                if( ref($lines_ref) eq "ARRAY" ){
                    $ln--;
                }
                else{
                    seek($lines_ref, -$ln, 1);
                }
            }


            # ----------
            # DEBUG_ECHO: meminfo
            # ----------
            elsif( $line =~ /^\s*DEBUG_ECHO: meminfo/ ){

                undef($done_1);
                while( ! defined($done_1) ) {
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if(
                        $line =~ /^\s*DEBUG_ECHO: DONE: meminfo/
                        ) {
                        last;
                    }

                }
                
            }

            # ----------
            # WARNING: Duplicate
            # ----------
            elsif( $line =~ /^\s*\*+ WARNING: Duplicate Scalar Commands/ ){

                undef($done_1);
                while( ! defined($done_1) ) {
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }
                    if(
                        $line =~ /^\s*The following commands/ ||
                        $line =~ /^\s*The last instance of/ ||
                        $line =~ /^\s*Is this what/ ||
                        $line =~ /^\s*Line\s*$/ ||
                        $line =~ /^\s*Filename\s+Number\s+Command/ ||
                        $line =~ /^\s*-+\s+-+\s+-+\s*$/ ||
                        $line =~ /^\s*\S+\s+\d+\s+\S/ ||
                        $line =~ /^\s*$/
                        ) {
                        next;
                    }

                    last;
                }
                
                # back up one line (since read to following line)
                if( ref($lines_ref) eq "ARRAY" ){
                    $ln--;
                }
                else{
                    seek($lines_ref, -$ln, 1);
                }
            }

            # ------
            # tracer
            # ------
            elsif( $line =~ /^\s*\$\$\$ TRACER_GET_DATA: cycle, record, time, count\/max\s*=\s*(\d+)\s*(\d+)\s*(\S+)\s*(\S+)\s*$/ ){
                $vals{cycle} = $1;
                $vals{time}  = $3;
            }

            # other tracer
            elsif( $line =~ /^\s*\$\$\$ TRACER_GET_DATA/ ){
                # skip
            }

            # editmix
            elsif( $line =~ /^\s*Create editmix file: \S+-editmix\s*time=\s*(\S+)\s*\[s\]\s*cycle=\s*(\d+)/ ){
                $vals{time}  = $1;
                $vals{cycle} = $2;
            }

            # strength stuff
            elsif(
                $line =~ /^\s*\$\$\$ ms, nm, mat/ ||
                $line =~ /^\s*\$\$\$ mat =.*strength/ ||
                $line =~ /\s+, strength_rho_fail\(*/
                ){
            }

            # paraview
            elsif(
                $line =~ /^\s*COPROCESS / ||
                $line =~ /^\s*Total time for auto gate/ ||
                $line =~ /^\s*Total time for create in situ/ ||
                $line =~ /^\s*Total time for load data into insitu/ ||
                $line =~ /^\s*Total time for coprocessing/ ||
                $line =~ /^\s*pv_insitu /
                ){
            }

            # TN Reactions
            elsif( $line =~ /^\s*=+ TN Reactions =+\s*$/  ){
                $data_found = "";
                # process until you hit End TN Reactions
                undef( $done );
                @fields = ();
                $label_1 = "undef_parser_error";
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                    # done
                    if( $line =~ /^\s*=+ End TN Reactions =+\s*$/  ){
                        last;
                    }

                    # time cycle
                    elsif( $line =~ /Time:\s*(\S+)\s+Cycle:\s*(\d+)/ ){
                        $time        = $1;
                        $vals{cycle} = $2;
                        if( ! defined( $vals{time} ) ||
                            length($time) >= length($vals{time}) ){
                            $vals{time} = $time;
                        }
                    }

                    # new table
                    elsif( $line =~ /^\s*(table)\s*=\s*(\S+)\s*$/ ){
                        $label_1 = "$1=$2:";
                    }

                    # table header
                    # This seems to be next line after "table" so could parse that way
                    elsif( $line =~ /^\s*reaction_zaid/ ){
                        # strip start/stop whitespace and split on whitespace
                        $line =~ s/^\s*//;
                        $line =~ s/^\s*//;
                        @fields = split( /\s+/, $line );
                    }

                    # table line
                    # look for (\S+)=>(\S+)
                    # These come in a block after the table header and separator so
                    # could parse that way
                    elsif( $line =~ /^\s*(\S+)->(\S+)\s+/ ){
                        # strip start/stop whitespace and split on whitespace
                        $line =~ s/^\s*//;
                        $line =~ s/^\s*//;
                        @vals_line = split( /\s+/, $line );
                        # process data line into vals
                        if( $#vals_line == $#fields ){
                            undef( %keys_vals );
                            $label_2 = "";
                            $label_3 = "";
                            $i = 0;
                            foreach $val ( @vals_line ){
                                # part of variable name
                                if( $fields[$i] =~ /^reaction_zaid$/ ){
                                    $label_2 = "rz=$val:";
                                }
                                elsif( $fields[$i] =~ /^(mat)$/ ){
                                    # 0-pad material so sorts well
                                    $val_1   = sprintf( "%03d", $val );
                                    $label_3 = "$1=$val_1:";
                                }
                                else{
                                    $keys_vals{$fields[$i]} = $val;
                                }
                                $i++;
                            }

                            # stuff into %vals
                            foreach $key ( keys %keys_vals ){
                                $label = "TNR:${label_1}${label_2}${label_3}$key";
                                $vals{$label} = $keys_vals{$key};
                            }

                        } # process data line into vals

                    } # table_line
                    
                } # process until you hit End TN Reactions
                
            } # TN Reactions

            # EOS stuff
            elsif(
                $line =~ /^\s*npmin_t\(/ ||
                $line =~ /^\s*teos_table_check: Checking/ ||
                $line =~ /^\s*\! Checked: matid/ ||
                $line =~ /^\s*Crossed Isotherms: nm = / ||
                $line =~ /^\s*Open eos file: / ||
                $line =~ /^\s*Data read from file: / ||
                $line =~ /^\s*numm\s+=\s+\S+\s*$/ ||
                $line =~ /^\s*numt\s+=\s+\S+\s*$/ ||
                $line =~ /^\s*nump\s+=\s+\S+\s*$/ ||
                $line =~ /^\s*numtp\s+=\s+\S+\s*$/ ||
                $line =~ /^\s*p_floor\s+=\s+\S+\s*$/ ||
                $line =~ /^\s*, nplo\s+=\s+/ ||
                $line =~ /^\s*Checking: finished/ ||
                $line =~ /^\s*p_ceiling\s+=\s+\S+\s*$/ ||
                $line =~ /^\s*Thermodynamic range limits/ ||
                $line =~ /^\s*pmin_mat\(*/ ||
                $line =~ /^\s*sie_min_mat\(*/ ||
                $line =~ /^\s*rho_min_mat\(*/ ||
                $line =~ /^\s*Equation of State Parameters Used for material/ ||
                $line =~ /^\s*Eos Model = \S+\s*$/ ||
                $line =~ /^\s*Gamma =\s+\S+\s*$/ ||
                $line =~ /^\s*CV =\s+\S+\s*$/
                ){
            }

            # -------------------------------
            # misc skip lines (to reduce extra subroutine calls)
            # -------------------------------
            elsif(
                $line =~ /\*\*\* End LONG Editcycle \*\*\*/ ||
                $line =~ /^\s*\#+:\s*DEBUG\s+STEP/ ||
                $line =~ /^\s*Resources: end\s*$/ ||
                $line =~ /^\s*Stop condition:/ ||
                $line =~ /^\s*little endian\s*$/ ||
                $line =~ /WARNING: These region values are only rough estimates/ ||
                $line =~ /^\s*Reference Thermodynamics based on average value over all cells\s*$/ ||
                $line =~ /^\s*EOS SR scalings - matdef/ ||
                $line =~ /^\s*Component Masses and Densities\s*$/ ||
                $line =~ /^\s*FYI, the time to do a global_reduce/ ||
                $line =~ /vtkCPAdaptorApi.cxx/ ||
                $line =~ /\[pvbatch\.\d+/ ||
                $line =~ /^\s*requested                                     computed\s*$/ ||
                $line =~ /^\s*INITAX: sum_numold, sum_numcell/ ||
                $line =~ /^\s*RAMP:/ ||
                $line =~ /^\s*RAMP \(by material\):/ ||
                $line =~ /^\s*initialize region / ||
                $line =~ /^\s*______Using RMA ATOA/ ||
                $line =~ /^\s*______RMA ATOA setup complete/ ||
                $line =~ /^\s*______RMA setup complete/ ||
                $line =~ /^\s*______Using s2s for kidmom/ ||
                $line =~ /^\s*______Using anonymous advection/ ||
                $line =~ /^\s*______Using s2s for node/ ||
                $line =~ /^\s*BLD_RHO_0.0.*: pres, tev/ ||
                $line =~ /^\s*Setting the GEM default mapper/ ||
                $line =~ /^\s*REGION_INITIAL0: numfine, fill_depth/ ||
                $line =~ /^\s*Name of input deck file/ ||
                $line =~ /^\s*\#\#\#\# \[EAP MESH REWRITE\]/ ||
                $line =~ /^\s*duplicate_array_values = / ||
                $line =~ /^\s*Open output file: / ||
                $line =~ /^\s*\*\*\*\* WARNING/ ||
                $line =~ /^\s*\*\s+Running in 2T mode/ ||
                $line =~ /^\s*BLOCKS_INITIALIZE/ ||
                $line =~ /^\s*BUILD_GRID: time/ ||
                $line =~ /^\s*Pore crush ramp P-alpha parameters/ ||
                $line =~ /^\s*he_model\(\s*\d+\s*\)/ ||
                $line =~ /^\s*NDI WARNING, warning code/ ||
                $line =~ /^\s*.*NDI error.*opening gendir/ ||
                $line =~ /^\s*ipcress_file_read:/ ||
                $line =~ /^\s*ipcress_table bcast:/ ||
                $line =~ /^\s*ALIVE_TIMER_TEST: / ||
                $line =~ /^\s*INITIAL: time to finish/ ||
                $line =~ /^\s*Iso:\s+iso_data_dir=/ ||
                $line =~ /^\s*Iso:\s+iso_gendir_root=/ ||
                $line =~ /^\s*Iso:\s+ndi_gendir_path=/ ||
                $line =~ /^\s*ISO_GEN_ATWGT/ ||
                $line =~ /^\s*iso_gen_atwgt: enter/ ||
                $line =~ /^\s*iso_gen_atwgt: exit/ ||
                $line =~ /^\s*WARNING: DEPRECATED : / ||
                $line =~ /^\s*Using bulkio with \d+ IO pes/ ||
                $line =~ /^\s*advecting strength BY \S+\s*$/ ||
                $line =~ /^\s*l_eap_version_dump = / ||
                $line =~ /^\s*eap_cuda_test/ ||
                $line =~ /^\s*reading chunk mixed cell values\s*$/ ||
                $line =~ /^\s*DEBUG -- :\s*$/ ||
                $line =~ /^\s*\$\$\$ Unable to find file \S+-lastcycle\s*$/ ||
                $line =~ /^\s*Prevent restarts by writing file \S+-DO_NOT_RUN\s*$/ ||
                $line =~ /^\s*CPT: warning/ ||
                $line =~ /^\s*\*\*\* NOTICE: These material values/
                ){
            }

            # ---------------------------------------
            # not sure what these block are - so skip
            # do at end so others have chance to catch
            # ---------------------------------------
            elsif(
                $line =~ /^\s*n  run   cycle    time        dt            wallhr   sumwallhr    sumcpuhr  Cum_max_gb  version.ext  numpe            numcell      date:time    prbnm\s*$/ ||
                $line =~ /^\s*n  run   cycle    time        dt            wallhr   sumwallhr    sumcpuhr  Cum_max_gb  numpe            numcell      date:time    prbnm\s*$/ ||
                $line =~ /^\s*    n  run  cycle    time        dt          tmass       tpe         tke         tie         tre         txe         ein         eot         te          error       tmxd        tmyd\s*$/ ||
                $line =~ /^\s*n  run   cycle    time        dt         job-id  numpe      ritr    cc\/s\/pe     rhomax      prsmax      tevmax      revmax\s*$/ ||
                $line =~ /^\s*n  run  cycle    time        dt          tmass       tpe         tke         tie         tre         txe         ein         eot         te          error       tmxd\s*$/ ||
                $line =~ /^\s*material            mass (grams)      density \(grams\/cc\)            mass \(grams\)      density \(grams\/cc\)\s*$/ ||
                $line =~ /^\s*loop nreg  mat matdef    regm          regte         regie         regke         regre\s*$/ ||
                $line =~ /^\s*loop nreg  mat matdef    pres          pmax          tev           rho           se            sie           re            snd           dpde\/r        cv\s*$/ ||
                $line =~ /^\s*material                   input                    used\s*$/ ||
                $line =~ /^\s*material            mass \(grams\)      density \(grams\/cc\)            mass \(grams\)      density \(grams\/cc\)\s*$/ ||
                $line =~ /^\s*material      Density \(grams\/cc\)    Pressure \(microbars\)        Temperature \(eV\)\s*$/ ||
                $line =~ /^\s*nt         l  lev    (x|y|z)           xdot        ydot        rho         tev         p           pmx\s*$/ ||
                $line =~ /^\s*n   sumcpusec     count   avgcpusec  mincpusec   maxcpusec    subroutine\s*$/ ||
                $line =~ /^\s*material                   alpha                      Pe                      Pc    reversable/ ||
                $line =~ /^\s*n  run   cycle    time        dt            wallhr   sumwallhr    sumcpuhr  Cum_max_gb  numpe/ ||
                $line =~ /^\s*n  run  cycle    time        dt          tmass       tpe         tke         tie         tre         txe         ein         eot         te          error       tmxd        tmyd        tmzd/ ||
                $line =~ /^\s*raw   ident    type            abar            zbar/ ||
                $line =~ /^\s*n   ident    type            abar            zbar\s*$/ ||
                $line =~ /^\s*m   mat                      rho                      sie                     bmod                    bmodT                     dpde                      Gam                       cv                       cp                    betaV/ ||
                $line =~ /^\s*nm\s+vof_nmats\(nm\)/
                ){
                undef( $done );
                while( ! defined($done) ){
                    # read line
                    if( ref($lines_ref) eq "ARRAY" ){
                        $line = $$lines_ref[$ln]; $ln++;
                    }
                    else{
                        $line = <$lines_ref>; $ln = length($line);
                    }
                    # done
                    if( ! defined($line) ){
                        last;
                    }

                    # done
                    if( $line !~ /\S/ ){
                        last;
                    }

                    # if does not match an int as first field, back up and done
                    if( $line !~ /^\s*\d/ ){
                        # back up one line
                        if( ref($lines_ref) eq "ARRAY" ){
                            $ln--;
                        }
                        else{
                            seek($lines_ref, -$ln, 1);
                        }
                        last;
                    }

                }
            }

            # Stop processing if you see this.
            # For large problems, might have a zillion stack trace lines...
            # So, punt.
            elsif( $line =~ /application called MPI_Abort/ ){
                last;
            }

            # -------------------------------
            # ELSE call extra in this else so that call not made every line
            # -------------------------------
            else{
                delete( $state{processed} );
                delete( $state{data_found} );
                $state{ln}             = $ln;
                $state{line}           = $line;
                foreach $extra ( sort keys %ctf_extras_required ){
                    if( $extra =~ /(eap_output_.*)/ ){
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

            } # processed line (or line set)

            # ============
            # process vals
            # ============

            # ctf_vals_splice/ctf_vals_add are expensive
            # only call if you have data to put in
            if( defined($vals{cycle}) && defined($data_found) ){

                undef($data_found);

                # keep previous cycle around since not all data knows cycle
                $state{cycle} = $vals{cycle};

                # get cycle_prev (default to this cycle if no previous)
                if( defined($$vals_ref{cycle}) ){
                    $cycle_prev = $$vals_ref{cycle}{val}[-1];
                }
                else{
                    $cycle_prev = $vals{cycle};
                }
                $vals{cycle_prev} = $cycle_prev;

                # If the start is done, check that the cycles are increasing.
                # If not, then within a run, the cycles are jumping around.
                # This is indicative of multiple jobs running at the same time
                # and corrupting the file.  This happens occasionally because
                # we have different machines that access the same scratch
                # space and use the same execs...so it is easy to accidentally
                # be on different machines and launch the "same" job.
                # Have this be an error and have users move the file out of the way.
                if( defined($start_file_done) ){

                    # if cycles out of order, say so
                    # We sometimes send in same cycle...so look for ">"
                    if( $cycle_prev > $vals{cycle} ){
                        $ierr = 1;
                        @lines_error = ();
                        push( @lines_error,
                              "Found out-of-order cycles within the SAME RUN!!!",
                            );
                        if( defined($filename) ){
                            push( @lines_error,
                                  "File:",
                                  "  $filename",
                                );
                        }
                        else{
                            push( @lines_error,
                                  "No filename available - internal read",
                                );
                            
                        }
                        push( @lines_error,
                              "Cycle old: $cycle_prev",
                              "Cycle new: $vals{cycle}",
                            );
                        push( @lines_error,
                              "",
                              "This is likely due to multiple jobs running at the same time",
                              "in the same directory (maybe submitted from different machines).",
                              "",
                              "Move this file out of the way and re-run your command.",
                              "",
                            );
                        &print_error( @lines_error,
                                      $ierr );
                        exit( $ierr );
                        last;
                    }
                }

                # if this is the start of the file, deal with restart splicing
                else{

                    $start_file_done = "";

                    # stuff in some values if they exist and clear them out

                    # this is done at the "start" of a file where info stored.
                    # clear out state_file - need to pass through cycle
                    # if you processed RJ_OUTPUT data, call with "clear"
                    if( defined( $state_file{processed} ) ){
                        $state_ref = \%state_file;
                        $state_file{cycle} = $state{cycle};
                        $state_file{clear} = "";
                        $extra_routine = "ctf_read_rj_cmd_out";
                        $eval_error = eval "\$ierr = &$extra_routine( LINES=>\$lines_ref, VALS=>\$vals_ref, VALS_THIS=>\\\%vals, STATE=>\$state_ref, VERBOSE=>\$verbose )";
                        # error stored into $@
                        if( $@ || $ierr != 0 ){
                            $ierr = 1;
                            &print_error( "Error from $extra_routine :",
                                          $@, $ierr );
                            exit( $ierr );
                        }
                    }

                    # clear out from next cycle on
                    $cycle_clear = $state{cycle} + 1;
                    &ctf_vals_splice( VALS=>$vals_ref, CYCLE=>$cycle_clear );

                    # try to detect if this file is a duplicate of previous file
                    # If so, reset one cycle further and reset some things from
                    # previous run.
                    if( defined($vals{date_start}) ){
                        %time_h = &conv_time( STRING=>"YMDHMS $vals{date_start}");
                        $date_start_this = $time_h{date_dot};
                    }
                    else{
                        # set to something that is not default value of $date_start
                        $date_start_this = -2;
                    }
                    if( defined($filename) ){
                        $datestamp_filename = $filename;
                    }
                    else{
                        $datestamp_filename = "";
                    }
                    $date_start = -1;
                    if( defined($$vals_ref{date_start}) ){
                        $date_start = $$vals_ref{date_start}{val}[-1];
                    }
                    # just print warning of possible duplicate file
                    undef( $date_prev_redo );
                    undef( $cycle_date_prev_redo );
                    if( $date_start_this eq $date_start ){

                        if( ! defined( $duplicate_detected) ){
                            $duplicate_detected = "";
                            print "\n**WARNING** Detected duplicate files [skip warning for others] $datestamp_filename_old $datestamp_filename\n";
                        }

                        # restore to previous values (all must be there since duplicate file
                        $state{cycle}           = $$vals_ref{cycle}{val}[-1];
                        $vals{cycle}            = $$vals_ref{cycle}{val}[-1];
                        $cycle_prev             = $$vals_ref{cycle_prev}{val}[-1];
                        $vals{cycle_prev}       = $cycle_prev;
                        $vals{lost_cycles}      = $$vals_ref{lost_cycles}{val}[-1];
                        $date_prev_redo         = $$vals_ref{date_prev}{val}[-1];
                        $cycle_date_prev_redo   = $$vals_ref{date_prev}{cycle}[-1];
                        $datestamp_old          = $$vals_ref{datestamp_old}{val}[-1];
                        $datestamp_filename_old = $$vals_ref{datestamp_filename_old}{val}[-1];
                        $datestamp_ln_old       = $$vals_ref{datestamp_ln_old}{val}[-1];
                        $datestamp_line_old     = $$vals_ref{datestamp_line_old}{val}[-1];

                        # now clear out this cycle's data
                        $cycle_clear = $state{cycle};
                        &ctf_vals_splice( VALS=>$vals_ref, CYCLE=>$cycle_clear );

                    }

                    # various starting file things
                    $vals{filename}               = $filename;
                    $vals{datestamp_filename_old} = $datestamp_filename_old;
                    $vals{datestamp_line_old}     = $datestamp_line_old;
                    $vals{datestamp_ln_old}       = $datestamp_ln_old;
                    $vals{datestamp_old}          = $datestamp_old;

                    # also store any lost_cycles
                    # upon restart, the first cycle seen is actually
                    # the one from the restart dump.  Some data will be
                    # reprinted, but not all.  So only clear after that
                    # cycle.
                    $vals{lost_cycles}  = $cycle_prev - $vals{cycle};
                    $state{cycle_start} = $state{cycle};

                    # get/save previous date
                    # upon restarts, the date will get redefined to be
                    # whatever the last date read is.  So, this will
                    # be whatever the previous date was.
                    undef( $date_prev );
                    # from duplicate file
                    if( defined( $date_prev_redo ) ){
                        $date_prev = $date_prev_redo;
                    }
                    # previous date was found, this is (likely?) restart so
                    elsif( defined($$vals_ref{date}) ){
                        $date_prev = $$vals_ref{date}{val}[-1];
                    }

                    # no previous date, so use current date found (if found)
                    elsif( defined($vals{date}) ){
                        $date_prev = $vals{date};
                    }

                    # if not defined, this is a -status file
                    #   (or other fragment w/out date)
                    # might want to use date of file if found?
                    # for now, do not set
                    else{
                    }
                    
                    if( defined( $date_prev ) ){

                        # do not overwrite date_prev if already have a date_prev
                        # for that cycle.  Want to keep the first date_prev found.
                        # run 1: cycles 10-20 : 
                        # run 2: cycles 15-30 : want date_prev[cycle-15] = date[20]
                        # run 3: cycles 15-40 : want to keep date_prev[cycle-15]
                        $cycle_date_prev = -1;
                        if( defined( $cycle_date_prev_redo ) ){
                            $cycle_date_prev = $cycle_date_prev_redo;
                        }
                        elsif( defined($$vals_ref{date_prev}) ){
                            $cycle_date_prev = $$vals_ref{date_prev}{cycle}[-1];
                        }
                        if( $state{cycle} != $cycle_date_prev || defined($cycle_date_prev_redo) ){
                            %time_h = &conv_time( STRING=>"YMDHMS $date_prev" );
                            $vals{date_prev}       = $date_prev;
                            $vals{secs_prev_epoch} = $time_h{SECS_TOTAL};
                        }
                    }

                }
                
                # cycle==cycle_start
                # if the cycle is the same as the cycle read from the dump
                if( $vals{cycle} == $state{cycle_start} &&
                    defined($$vals_ref{date}) ){
                    # do not overwrite date of this first cycle - keep the date
                    # previously found - will use this to convert the date that is
                    # in secs_lost right now into secs_lost seconds (the time between
                    # runs).
                    # But, store the last date found for this cycle.  If you have
                    # a long/short edit at this cycle, this will be the date when the
                    # restart has finished.  Otherwise, it will just be when the
                    # restart dump has been read in (and not include any time for
                    # things like building mesh or other package restart).  But,
                    # will take what we can get.
                    # The date field is already in yyyy.mm.dd.hh.mm.ss (could test
                    # on this...).
                    if( defined($vals{date}) ){

                        %time_h = &conv_time( STRING=>"YMDHMS $vals{date}" );
                        $vals{date}         = $time_h{date_dot};
                        $vals{secs_restart} = $time_h{SECS_TOTAL};

                        # The first cycle seen (cycle_start) should either be a fresh
                        # run or a continuation from a previous restart dump.
                        # Hit case where user picked up from a restart dump that started
                        # at a future cycle.  Need to keep the date seen in this
                        # case since previous date not seen.  Print a warning this this
                        # is seen.
                        if( $vals{cycle} <= $cycle_prev ){
                            # never delete it...this will always be the last date seen.
                            # upon restart, this will be when everything has been read in
                            # and the first cycle is ready to go.
                            #delete( $vals{date} );
                        }
                        else{
                            print "\n**WARNING** Detected jump in cycles ($cycle_prev - $vals{cycle})...missing files?  File:";
                            if( defined( $filename ) ){
                                print " $filename";
                            }
                            print "\n";
                        }

                    }

                    # secs_lost, secs_restart are "stored" at the cycle of
                    # the dump but are computed new when processing file
                    # reading restart dump.
                    # So, DO overwrite them (commented out)
                    #delete( $vals{secs_lost} );
                    #delete( $vals{secs_restart} );
                } # cycle == cycle_start

                # sanity check on date
                if( defined($vals{date}) ){

                    # get datestamp and name of file
                    %time_h = &conv_time( STRING=>"YMDHMS $vals{date}");
                    $datestamp = $time_h{SECS_TOTAL};
                    if( defined($filename) ){
                        $datestamp_filename = $filename;
                    }
                    else{
                        $datestamp_filename = "";
                    }

                    $same_file = "";
                    if( $datestamp_filename =~ /\S/ &&
                        $datestamp_filename eq $datestamp_filename_old ){
                        $same_file = " within the SAME RUN!!!";
                    }

                    if( $datestamp < $datestamp_old ){

                        # warning since ok for daylightsavings moving hour back
                        $ierr = 0;
                        
                        @lines_error = (
                            "Datestamp out of order$same_file.",
                            "",
                            "datestamp_filename:",
                            "  $datestamp_filename",
                            "line/column $datestamp_ln: ",
                            "  $datestamp_line",
                            "  $datestamp",
                            "datestamp_filename_old:",
                            "  $datestamp_filename_old",
                            "line/column $datestamp_ln_old: ",
                            "  $datestamp_line_old",
                            "  $datestamp_old",
                            );
                        if( $same_file =~ /\S/ ){
                            push( @lines_error,
                                  "",
                                  "This is ok if this happens when we move an hour back for daylightsavings.",
                                  "In this case, wallclock values like secs/cycle will be nonsensical.",
                                  "This could instead be due to multiple jobs running at the same time",
                                  "in the same directory (maybe submitted from different machines).",
                                  "",
                                  "If this is the case, move this file out of the way and re-run your command.",
                                  "",
                                );
                        }
                        else{
                            push( @lines_error,
                                  "Files are processed in the order specifiec on the command line.",
                                  "It is possible that the date tags of the files are out of order.",
                                  "To send the files in modification time order: ",
                                  '  ctf_process.pl `\\ls -1rt <files>`',
                                  "If needed, you can use the following to update modification times:",
                                  "  cd <run dir> ; run_job.pl --touch_arg <file list>",
                                  "",
                                );
                        }
                        &print_error( @lines_error,
                                      $ierr );
                        #exit( $ierr );

                    }
                    $datestamp_filename_old       = $datestamp_filename;
                    $datestamp_line_old           = $datestamp_line;
                    $datestamp_ln_old             = $datestamp_ln;
                    $datestamp_old                = $datestamp;
                }
                
                # add values
                &ctf_vals_add( VALS=>$vals_ref, VALS_CYCLE=>\%vals );

                # keep previous cycle around since not all data knows cycle
                $vals{cycle} = $state{cycle};
            }

        } # process each line

        # close if opened
        if( ref($lines_ref) ne "ARRAY" ){
            close( $lines_ref );
        }
        
        # 
        # save old things
        $filename_old = $filename;

    } # process each file

    # print some more info
    if( defined($args{VERBOSE}) ){
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

    # Final rj_cmd_out pass with an up-2-date versions of things.
    # Should be ok with everything spliced together correctly since
    # only getting last dates on the very last state_file.
    # Cannot use the "finish" since that only called with vals
    # clear out state_file - need to pass through cycle
    if( defined( $state_file{processed} ) ){
        $state_ref = \%state_file;
        $state_file{cycle} = $state{cycle};
        # call with "final"
        $state_file{final} = "";
        $extra_routine = "ctf_read_rj_cmd_out";
        $eval_error = eval "\$ierr = &$extra_routine( LINES=>\$lines_ref, VALS=>\$vals_ref, VALS_THIS=>\\\%vals, STATE=>\$state_ref, VERBOSE=>\$verbose )";
        # error stored into $@
        if( $@ || $ierr != 0 ){
            $ierr = 1;
            &print_error( "Error from $extra_routine :",
                          $@, $ierr );
            exit( $ierr );
        }
    }

    # DONE Final rj_cmd_out pass

    # get list of keys
    @fields_all = keys( %$vals_ref );

    # ---------------------
    # finish timing_ blocks
    # ---------------------

    # timing_seg_sum-cpusec_sub_${subroutine}
    # normalize the sums to the first run-cpusec value
    # The result sum-cpusec will be the time spent in this set of file(s)
    @fields = grep(/^timing_sum-cpusec_sub_(\S+)/, @fields_all);
    @fields_new = ();
    $tot = 0;
    foreach $field ( @fields ){
        ($subroutine = $field) =~ s/^timing_sum-cpusec_sub_//;
        $t0 = $$vals_ref{$field}{val}[0] -
            $$vals_ref{"timing_run-cpusec_sub_${subroutine}"}{val}[0];
        $i = 0;
        $field_new = "timing_seg_sum-cpusec_sub_${subroutine}";
        push( @fields_new, $field_new );
        foreach $val ( @{$$vals_ref{$field}{val}} ){
            $val_seg = sprintf( "%.8e", $val - $t0);
            $cycle = $$vals_ref{$field}{cycle}[$i];
            push(@{$$vals_ref{$field_new}{val}},   $val_seg );
            push(@{$$vals_ref{$field_new}{cycle}}, $cycle );
            $i++;
        }
    }

    # update fields_all since used below
    @fields_all = keys( %$vals_ref );

    # compute rankings based on (seg_)?sum-cpusec

    # rankings: sum-cpusec
    @vals_arr = ();
    foreach $field ( @fields ){
        push( @vals_arr, "$$vals_ref{$field}{val}[-1] $field" );
    }
    @vals_sorted = reverse sort this_numerically_val @vals_arr;

    $i = 0;
    foreach $key_val ( @vals_sorted ){
        $i++;
        ($subroutine = $key_val) =~ s/^.*_sub_//;
        $cycle = $i;
        $$vals_ref{"timing_rank_sum-cpusec"}{val}[$i-1]   = "$subroutine";
        $$vals_ref{"timing_rank_sum-cpusec"}{cycle}[$i-1] = -$cycle;
        $val = $$vals_ref{"timing_sum-cpusec_sub_${subroutine}"}{val}[-1];
        $$vals_ref{"timing_rank_sum-cpusec"}{time}[$i-1]  = $val;;
    }

    # rankings: seg_sum-cpusec
    @vals_arr = ();
    foreach $field ( @fields_new ){
        push( @vals_arr, "$$vals_ref{$field}{val}[-1] $field" );
    }
    @vals_sorted = reverse sort this_numerically_val @vals_arr;

    $i = 0;
    foreach $key_val ( @vals_sorted ){
        $i++;
        ($subroutine = $key_val) =~ s/^.*_sub_//;
        $cycle = $i;
        $$vals_ref{"timing_seg_rank_sum-cpusec"}{val}[$i-1]   = "$subroutine";
        $$vals_ref{"timing_seg_rank_sum-cpusec"}{cycle}[$i-1] = -$cycle;
        $val = $$vals_ref{"timing_seg_sum-cpusec_sub_${subroutine}"}{val}[-1];
        $$vals_ref{"timing_seg_rank_sum-cpusec"}{time}[$i-1]  = $val;;
    }

    # get tot_seg, tot_sum
    # no need to update fields_all since that was only "rank" added
    @fields = grep(/^timing_(seg_)?sum-cpusec_sub_(\S+)/, @fields_all);
    $tot_sum = 0;
    $tot_seg = 0;
    $cycle = 0;
    foreach $field ( @fields ){
        # will use this last cycle as the data point for totals
        $cycle = $$vals_ref{$field}{cycle}[-1];
        if( $field =~ /^timing_seg_/ ){
            $tot_seg += $$vals_ref{$field}{val}[-1];
        }
        else{
            $tot_sum += $$vals_ref{$field}{val}[-1];
        }
    }
    if( @fields ){
        $$vals_ref{"timing_seg_sum-cpusec_total"}{val}[0]   = $tot_seg;
        $$vals_ref{"timing_seg_sum-cpusec_total"}{cycle}[0] = $cycle;
        $$vals_ref{"timing_sum-cpusec_total"}{val}[0]       = $tot_sum;
        $$vals_ref{"timing_sum-cpusec_total"}{cycle}[0]     = $cycle;
    }

    # get new list of fields
    @fields_all = keys( %$vals_ref );

    # take derivs 
    @fields = grep( /^timing_sum-cpusec_sub_/, @fields_all );
    foreach $field ( @fields ){
        if( $field =~ /timing_(sum-cpusec)_sub_(\S+)/ ){
            $field_new = "timing_deriv_${1}_sub_${2}";
        }
        @{$$vals_ref{$field_new}{val}}   = ();
        @{$$vals_ref{$field_new}{cycle}} = @{$$vals_ref{$field}{cycle}};
        &my_derivative( DERIV=>$$vals_ref{$field_new}{val},
                        X=>$$vals_ref{$field}{cycle},
                        Y=>$$vals_ref{$field}{val},
                        NOISE=>.3 );
    }
    
    # --------------
    # secs from date
    # --------------
    if( defined( $$vals_ref{date}) ){
        # copy over cycle
        @{$$vals_ref{secs}{"cycle"}} = @{$$vals_ref{date}{"cycle"}};
        
        $index_max = $#{$$vals_ref{date}{val}};
        for( $i = 0; $i <= $index_max; $i++ ){
            $date_orig   = $$vals_ref{date}{val}[$i];
            %time_h = &conv_time( STRING=>"YMDHMS $date_orig" );
            $$vals_ref{secs}{val}[$i] = $time_h{SECS_TOTAL};
        }
            
    }

    # ---------
    # secs_restart: secs epoch -> secs it took to restart
    # do while secs_lost is still an epoch seconds value
    # This is so the correct value is subtracted to normalize secs_restart.
    # Will normalize secs_lost next.
    #----------
    # secs_restart - subtract out secs_lost
    $field     = "secs_restart";
    $field_sub = "secs_lost";
    if( defined($$vals_ref{$field}) ){
        $index_max = $#{$$vals_ref{$field_sub}{cycle}};
        $index     = 0;
        for( $i = 0; $i <= $index_max; $i++ ){
            if( $$vals_ref{$field_sub}{cycle}[$i] <
                $$vals_ref{$field}{cycle}[$index] ){
                next;
            }
            $$vals_ref{$field}{val}[$index] -= $$vals_ref{$field_sub}{val}[$i];
            $index++;
            # if done
            if( $index > $#{$$vals_ref{$field}{cycle}} ){
                last;
            }
        }
    }

    # ---------
    # secs_lost: secs epoch -> secs between last stop and starting
    # do while secs is still an epoch seconds value
    # Do this after normalizing secs_restart (use full value of secs_lost)
    #----------
    # secs_lost - subtract out secs
    $field     = "secs_lost";
    $field_sub = "secs_prev_epoch";
    if( defined($$vals_ref{$field}) ){
        $index_max = $#{$$vals_ref{$field_sub}{cycle}};
        $index     = 0;
        for( $i = 0; $i <= $index_max; $i++ ){

            $cycle_f     = $$vals_ref{$field}{cycle}[$index];
            $cycle_f_sub = $$vals_ref{$field_sub}{cycle}[$i];

            if( $cycle_f_sub < $cycle_f ){
                next;
            }

            $$vals_ref{$field}{val}[$index] -= $$vals_ref{$field_sub}{val}[$i];
            $index++;
            # if done
            if( $index > $#{$$vals_ref{$field}{cycle}} ){
                last;
            }
        }

        # on problems run from scratch (no restart dump), the first secs field
        # is actually going to be the actual time to set up the problem...so
        # this value will be negative.  So, min that value.
        if( $$vals_ref{$field}{val}[0] < 0 ){
            $$vals_ref{$field}{val}[0] = 0;
        }

    }

    # ----------
    # NOW normalize secs: epoch -> start at 0
    # ----------
    if( defined( $$vals_ref{secs}) ){
        # now normalize time
        $secs_start = $$vals_ref{secs}{val}[0];
        $index_max = $#{$$vals_ref{secs}{val}};
        for( $i = 0; $i <= $index_max; $i++ ){
            $$vals_ref{secs}{val}[$i] -= $secs_start;
        }
    }

    # ----------
    # secs_cycle - instantaneous value at that cycle block
    # ----------
    if( defined($$vals_ref{secs}) ){
        $index_max  = $#{$$vals_ref{secs}{val}};
    }
    else{
        $index_max = -1;
    }
    # foreach index
    for( $i = 0; $i <= $index_max; $i++ ){
        
        # current cycle - next if still looking
        $cycle = $$vals_ref{secs}{cycle}[$i];
        
        if( $i == 0 ){
            push( @{$$vals_ref{secs_cycle}{val}}, 0 );
        }
        else{
            push( @{$$vals_ref{secs_cycle}{val}},
                  $$vals_ref{secs}{val}[$i] -
                  $$vals_ref{secs}{val}[$i-1] );
        }
        push( @{$$vals_ref{secs_cycle}{cycle}}, $cycle );
    }
    
    # now subtract out stuff
    # will be subtracting out these
    # fields - subtract from current cycle
    # dmp_read_time is included in secs_restart
    @fields = (
        "dmp_write_time",
        "ensight_write_time",
        "hdf_write_time",
        "secs_restart",
        "secs_lost",
        );
    # fields_post - subtract from cycle after
    # pio_read_other:time this is eos files read upon restart
    @fields_post = (
        "pio_read_other:time",
        );
    # first cycle where these are defined
    foreach $field ( @fields, @fields_post ){
        if( defined($$vals_ref{$field}) ){
            $indices{$field}    = 0;
            $cycles{$field}     = $$vals_ref{$field}{cycle}[0];
            $cycles_max{$field} = $$vals_ref{$field}{cycle}[-1];
            $vals{$field}       = $$vals_ref{$field}{val}[0];
        }
    }

    # foreach index
    if( defined($$vals_ref{secs_cycle}) ){
        $index_max = $#{$$vals_ref{secs_cycle}{val}};
    }
    else{
        $index_max = -1;
    }
    $secs_post = 0;
    for( $i = 0; $i <= $index_max; $i++ ){
        
        # current cycles secs_cycle info
        $cycle = $$vals_ref{secs_cycle}{cycle}[$i];
        $secs  = $$vals_ref{secs_cycle}{val}[$i];

        # keep diagnostic prints around since get this wrong lots
        #printf( "secs c=%5d s=%9.2e i=%7d\n", $cycle, $secs, $i );

        # subtract out $secs_post
        # which gets set for the next cycle
        $secs -= $secs_post;
        
        # subtract out field time
        foreach $field ( @fields ){
            # if field is defined at that cycle, subtract it
            if( defined( $cycles{$field} ) && $cycle >= $cycles{$field} ){
                # go up to next cycle
                delete( $cycles{$field} );
                for( $j = $indices{$field};
                     $j <= $#{$$vals_ref{$field}{val}}; $j++ ){
                    $cycle_field = $$vals_ref{$field}{cycle}[$j];
                    # done if the cycle_field past cycle
                    if( $cycle_field > $cycle ){
                        $indices{$field} = $j;
                        # next cycle for this field
                        if( $j <= $#{$$vals_ref{$field}{val}} ){
                            $cycles{$field} = $$vals_ref{$field}{cycle}[$j];
                        }
                        last;
                    }
                    # subtract out
                    #printf( "  s: c=%5d s=%9.2e f=%20s cf=%5d v=%.2g\n",
                    #        $cycle, $secs, $field, $cycle_field, $$vals_ref{$field}{val}[$j] );
                    $secs -= $$vals_ref{$field}{val}[$j];
                }
            }
        }
        
        # find secs_post
        $secs_post = 0;
        foreach $field ( @fields_post ){
            # if field is defined at that cycle, subtract it
            if( defined( $cycles{$field} ) && $cycle == $cycles{$field} ){
                #printf( " sp: c=%5d s=%9.2e f=%20s cf=%5d v=%.2g\n",
                #        $cycle, $secs, $field, $cycles{field}, $vals{$field} );
                $secs_post += $vals{$field};
                # point to next one
                if( $cycle < $cycles_max{$field} ){
                    $indices{$field}++;
                    $cycles{$field} = $$vals_ref{$field}{cycle}[$indices{$field}];
                    $vals{$field}   = $$vals_ref{$field}{val}[$indices{$field}];
                }
            }
        }

        # granularity of secs is 1 second...so could be rounding
        # error.  -secs = 0
        if( $secs < 0 ){
            $secs = 0;
        }
        
        $$vals_ref{secs_cycle}{val}[$i] = $secs;
    }
    
    # now sum up secs_cycle to get secs_tot
    # foreach index
    if( defined($$vals_ref{secs_cycle}) ){
        $index_max = $#{$$vals_ref{secs_cycle}{val}};
    }
    else{
        $index_max = -1;
    }
    for( $i = 0; $i <= $index_max; $i++ ){
        $secs  = $$vals_ref{secs_cycle}{val}[$i];
        $cycle = $$vals_ref{secs_cycle}{cycle}[$i];
        if( $i > 0 ){
            $secs += $$vals_ref{secs_tot}{val}[$i-1];
        }
        $$vals_ref{secs_tot}{val}[$i]   = $secs;
        $$vals_ref{secs_tot}{cycle}[$i] = $cycle;
    }
    
    # now divide secs_cycle/delta(cycles) to finish secs_cycle
    if( defined($$vals_ref{secs_cycle}) ){
        $index_max = $#{$$vals_ref{secs_cycle}{val}};
    }
    else{
        $index_max = -1;
    }
    for( $i = 0; $i <= $index_max; $i++ ){
        $secs  = $$vals_ref{secs_cycle}{val}[$i];
        $cycle = $$vals_ref{secs_cycle}{cycle}[$i];
        if( $i > 0 ){
            $cycle -= $$vals_ref{secs_cycle}{cycle}[$i-1];
        }
        else{
            $cycle = 1;
        }
        $$vals_ref{secs_cycle}{val}[$i] /= $cycle;
    }

    # -----------------------------
    # secs_io_write = dmp_write_time + hdf_write_time + ensight_write_time
    # -----------------------------
    $field_use = "secs_io_write";
    # fields - add to current cycle
    @fields = (
        "dmp_write_time",
        "ensight_write_time",
        "hdf_write_time",
        );
    foreach $field ( @fields ){
        if( defined($$vals_ref{$field}) ){
            $indices{$field}    = 0;
            $cycles{$field}     = $$vals_ref{$field}{cycle}[0];
            $cycles_max{$field} = $$vals_ref{$field}{cycle}[-1];
            $vals{$field}       = $$vals_ref{$field}{val}[0];
        }
    }
    
    # foreach index
    if( defined($$vals_ref{cycle}) ){
        $index_max = $#{$$vals_ref{cycle}{val}};
    }
    else{
        $index_max = -1;
    }
    for( $i = 0; $i <= $index_max; $i++ ){
        
        # current cycle info
        $cycle = $$vals_ref{cycle}{cycle}[$i];
        
        # subtract out field time
        undef( $found );
        $secs = 0;
        foreach $field ( @fields ){
            # if field is defined at that cycle, subtract it
            if( defined( $cycles{$field} ) && $cycle == $cycles{$field} ){
                $found = "";
                $secs += $vals{$field};
                # point to next one
                if( $cycle < $cycles_max{$field} ){
                    $indices{$field}++;
                    $cycles{$field} = $$vals_ref{$field}{cycle}[$indices{$field}];
                    $vals{$field}   = $$vals_ref{$field}{val}[$indices{$field}];
                }
            }
        }
        
        # only add if defined
        if( defined($found) ){
            push( @{$$vals_ref{$field_use}{val}},   $secs );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
        }
    }
    
    # -----------------------------
    # secs_io_read = dmp_read_time + pio_read_other:time
    # -----------------------------
    $field_use = "secs_io_read";
    # fields - add to current cycle
    @fields = (
        "dmp_read_time",
        "pio_read_other:time",
        );
    foreach $field ( @fields ){
        if( defined($$vals_ref{$field}) ){
            $indices{$field}    = 0;
            $cycles{$field}     = $$vals_ref{$field}{cycle}[0];
            $cycles_max{$field} = $$vals_ref{$field}{cycle}[-1];
            $vals{$field}       = $$vals_ref{$field}{val}[0];
        }
    }
    
    # foreach index
    if( defined($$vals_ref{cycle}) ){
        $index_max = $#{$$vals_ref{cycle}{val}};
    }
    else{
        $index_max = -1;
    }
    for( $i = 0; $i <= $index_max; $i++ ){
        
        # current cycle info
        $cycle = $$vals_ref{cycle}{cycle}[$i];
        
        # subtract out field time
        undef( $found );
        $secs = 0;
        foreach $field ( @fields ){
            # if field is defined at that cycle, subtract it
            if( defined( $cycles{$field} ) && $cycle == $cycles{$field} ){
                $found = "";
                $secs += $vals{$field};
                # point to next one
                if( $cycle < $cycles_max{$field} ){
                    $indices{$field}++;
                    $cycles{$field} = $$vals_ref{$field}{cycle}[$indices{$field}];
                    $vals{$field}   = $$vals_ref{$field}{val}[$indices{$field}];
                }
            }
        }
        
        # only add if defined
        if( defined($found) ){
            push( @{$$vals_ref{$field_use}{val}},   $secs );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
        }
    }
    

    # -----------------------------
    # secs_io = secs_io_read + secs_io_write
    # -----------------------------
    $field_use = "secs_io";
    # fields - add to current cycle
    @fields = (
        "secs_io_read",
        "secs_io_write",
        );
    foreach $field ( @fields ){
        if( defined($$vals_ref{$field}) ){
            $indices{$field}    = 0;
            $cycles{$field}     = $$vals_ref{$field}{cycle}[0];
            $cycles_max{$field} = $$vals_ref{$field}{cycle}[-1];
            $vals{$field}       = $$vals_ref{$field}{val}[0];
        }
    }
    
    # foreach index
    if( defined($$vals_ref{cycle}) ){
        $index_max = $#{$$vals_ref{cycle}{val}};
    }
    else{
        $index_max = -1;
    }
    for( $i = 0; $i <= $index_max; $i++ ){
        
        # current cycle info
        $cycle = $$vals_ref{cycle}{cycle}[$i];
        
        # subtract out field time
        undef( $found );
        $secs = 0;
        foreach $field ( @fields ){
            # if field is defined at that cycle, subtract it
            if( defined( $cycles{$field} ) && $cycle == $cycles{$field} ){
                $found = "";
                $secs += $vals{$field};
                # point to next one
                if( $cycle < $cycles_max{$field} ){
                    $indices{$field}++;
                    $cycles{$field} = $$vals_ref{$field}{cycle}[$indices{$field}];
                    $vals{$field}   = $$vals_ref{$field}{val}[$indices{$field}];
                }
            }
        }
        
        # only add if defined
        if( defined($found) ){
            push( @{$$vals_ref{$field_use}{val}},   $secs );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
        }
    }

    # -------------------------------------------------
    # secs_tot_dmp_write   = cumulative(dmp_write_time)
    # -------------------------------------------------
    $field     = "dmp_write_time";
    $field_use = "secs_tot_dmp_write";
    if( defined($$vals_ref{$field}) ){
        $secs = 0;
        # foreach index
        $index_max = $#{$$vals_ref{$field}{val}};
        for( $i = 0; $i <= $index_max; $i++ ){
            
            # current cycle info
            $cycle = $$vals_ref{$field}{cycle}[$i];
            $val   = $$vals_ref{$field}{val}[$i];
            $secs += $val;
            push( @{$$vals_ref{$field_use}{val}},   $secs );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
        }
    }

    # -------------------------------------------------
    # secs_tot_dmp_read    = cumulative(dmp_read_time)
    # -------------------------------------------------
    $field     = "dmp_read_time";
    $field_use = "secs_tot_dmp_read";
    if( defined($$vals_ref{$field}) ){
        $secs = 0;
        # foreach index
        $index_max = $#{$$vals_ref{$field}{val}};
        for( $i = 0; $i <= $index_max; $i++ ){
            
            # current cycle info
            $cycle = $$vals_ref{$field}{cycle}[$i];
            $val   = $$vals_ref{$field}{val}[$i];
            $secs += $val;
            push( @{$$vals_ref{$field_use}{val}},   $secs );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
        }
    }

    # -------------------------------------------------
    # secs_tot_hdf         = cumulative(hdf_write_time)
    # -------------------------------------------------
    $field     = "hdf_write_time";
    $field_use = "secs_tot_hdf";
    if( defined($$vals_ref{$field}) ){
        $secs = 0;
        # foreach index
        $index_max = $#{$$vals_ref{$field}{val}};
        for( $i = 0; $i <= $index_max; $i++ ){
            
            # current cycle info
            $cycle = $$vals_ref{$field}{cycle}[$i];
            $val   = $$vals_ref{$field}{val}[$i];
            $secs += $val;
            push( @{$$vals_ref{$field_use}{val}},   $secs );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
        }
    }

    # -------------------------------------------------
    # secs_tot_ensight     = cumulative(ensight_write_time)
    # -------------------------------------------------
    $field     = "ensight_write_time";
    $field_use = "secs_tot_ensight";
    if( defined($$vals_ref{$field}) ){
        $secs = 0;
        # foreach index
        $index_max = $#{$$vals_ref{$field}{val}};
        for( $i = 0; $i <= $index_max; $i++ ){
            
            # current cycle info
            $cycle = $$vals_ref{$field}{cycle}[$i];
            $val   = $$vals_ref{$field}{val}[$i];
            $secs += $val;
            push( @{$$vals_ref{$field_use}{val}},   $secs );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
        }
    }

    # -------------------------------------------------
    # secs_tot_io_write    = cumulative(secs_io_write)
    # -------------------------------------------------
    $field     = "secs_io_write";
    $field_use = "secs_tot_io_write";
    if( defined($$vals_ref{$field}) ){
        $secs = 0;
        # foreach index
        $index_max = $#{$$vals_ref{$field}{val}};
        for( $i = 0; $i <= $index_max; $i++ ){
            
            # current cycle info
            $cycle = $$vals_ref{$field}{cycle}[$i];
            $val   = $$vals_ref{$field}{val}[$i];
            $secs += $val;
            push( @{$$vals_ref{$field_use}{val}},   $secs );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
        }
    }

    # -------------------------------------------------
    # secs_tot_io_read     = cumulative(secs_io_read)
    # -------------------------------------------------
    $field     = "secs_io_read";
    $field_use = "secs_tot_io_read";
    if( defined($$vals_ref{$field}) ){
        $secs = 0;
        # foreach index
        $index_max = $#{$$vals_ref{$field}{val}};
        for( $i = 0; $i <= $index_max; $i++ ){
            
            # current cycle info
            $cycle = $$vals_ref{$field}{cycle}[$i];
            $val   = $$vals_ref{$field}{val}[$i];
            $secs += $val;
            push( @{$$vals_ref{$field_use}{val}},   $secs );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
        }
    }

    # -------------------------------------------------
    # secs_tot_io         = cumulative(secs_io_read)
    # -------------------------------------------------
    $field     = "secs_io";
    $field_use = "secs_tot_io";
    if( defined($$vals_ref{$field}) ){
        $secs = 0;
        # foreach index
        $index_max = $#{$$vals_ref{$field}{val}};
        for( $i = 0; $i <= $index_max; $i++ ){
            
            # current cycle info
            $cycle = $$vals_ref{$field}{cycle}[$i];
            $val   = $$vals_ref{$field}{val}[$i];
            $secs += $val;
            push( @{$$vals_ref{$field_use}{val}},   $secs );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
        }
    }

    # ----------------
    # secs_tot_restart
    # ----------------
    $field     = "secs_restart";
    $field_use = "secs_tot_restart";
    if( defined( $$vals_ref{"$field"} ) ){
        $val = 0;
        $index_max = $#{$$vals_ref{$field}{val}};
        for( $i = 0; $i <= $index_max; $i++ ){
            $cycle  = $$vals_ref{$field}{cycle}[$i];
            $val   += $$vals_ref{$field}{val}[$i];
            push( @{$$vals_ref{$field_use}{val}},   $val );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
        }
    }

    # -------------------------------------------------
    # secs/cycle[last]  = the average secsonds/cycle for whole run
    # -------------------------------------------------
    $field     = "secs_tot";
    $field_use = "secs/cycle";
    if( defined($$vals_ref{$field}) ){
        $num   = $$vals_ref{$field}{val}[-1];
        $cycle = $$vals_ref{$field}{cycle}[-1];
        # the first cycle starts at value 0 - so do not include it
        # (so, do not add 1 to num_c)
        $num_c = $cycle - $$vals_ref{$field}{cycle}[0];
        # if no cycles run (-status file), do not record this
        if( $num_c >= 1 ){
            $val   = $num/$num_c;
            push( @{$$vals_ref{$field_use}{val}},   $val );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
        }
    }

    # -------------------------------------------------
    # secs/dmp_read[last]  = secs_tot_dmp_read[last cycle]  / number non-0
    # -------------------------------------------------
    $field     = "secs_tot_dmp_read";
    $field_use = "secs/dmp_read";
    if( defined($$vals_ref{$field}) ){
        $num   = $#{$$vals_ref{$field}{val}} + 1;
        $val   = $$vals_ref{$field}{val}[-1]/$num;
        $cycle = $$vals_ref{$field}{cycle}[-1];
        push( @{$$vals_ref{$field_use}{val}},   $val );
        push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
    }

    # -------------------------------------------------
    # secs/dmp_write[last]  = secs_tot_dmp_write[last cycle]  / number non-0
    # -------------------------------------------------
    $field     = "secs_tot_dmp_write";
    $field_use = "secs/dmp_write";
    if( defined($$vals_ref{$field}) ){
        $num   = $#{$$vals_ref{$field}{val}} + 1;
        $val   = $$vals_ref{$field}{val}[-1]/$num;
        $cycle = $$vals_ref{$field}{cycle}[-1];
        push( @{$$vals_ref{$field_use}{val}},   $val );
        push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
    }

    # --------------------
    # Resources:walldays:sumwallhr,secs_tot,secs_tot_mach
    # Resources:walldays:sumwallhr,secs_tot,secs_tot_nodes
    #   wallclock days vs: days of sumwallhr, secs_tot, scaled machine secs_tot
    # --------------------
    if( defined( $$vals_ref{"secs_tot"} ) &&
        defined( $$vals_ref{"Resources:NUMNODES"} ) ){
        $num_secs_tot   = $#{$$vals_ref{"secs_tot"}{cycle}} + 1;
        $num_numnodes   = $#{$$vals_ref{"Resources:NUMNODES"}{cycle}} + 1;
        if( defined($$vals_ref{"sumwallhr"}) ){
            $num_sumwallhr  = $#{$$vals_ref{"sumwallhr"}{cycle}} + 1;
        }
        else{
            $num_sumwallhr = 0;
        }
        
        # set nodes_max (default 1)
        if( defined($ENV{CTF_VAL_NODES_MAX}) ){
            # have nodes_max info -> secs_tot_mach
            $nodes_max = $ENV{CTF_VAL_NODES_MAX};
        }

        if( $nodes_max == 1 ){
            $field_1 = "Resources:walldays:sumwallhr,secs_tot,secs_tot_nodes";
        }
        else{
            $field_1 = "Resources:walldays:sumwallhr,secs_tot,secs_tot_mach";
        }

        $j_start = 0;
        $k_start = 0;
        $val_prev = 0;
        for( $i = 0; $i < $num_secs_tot; $i++ ){
            $cycle = $$vals_ref{"secs_tot"}{cycle}[$i];
            $val   = $$vals_ref{"secs_tot"}{val}[$i];

            # get numnodes for this cycle
            for( $j = $j_start; $j < $num_numnodes; $j++ ){
                $cycle_numnodes = $$vals_ref{"Resources:NUMNODES"}{cycle}[$j];
                if( $cycle_numnodes >= $cycle ){
                    $numnodes = $$vals_ref{"Resources:NUMNODES"}{val}[$j];
                    $j_start = $j;
                    last;
                }
            }

            # get sumwallhr for this cycle (default val is unset)
            $days_sumwallhr = sprintf( "%12s", "-" );
            for( $k = $k_start; $k < $num_sumwallhr; $k++ ){
                $cycle_sumwallhr = $$vals_ref{"sumwallhr"}{cycle}[$k];
                # less than
                if( $cycle_sumwallhr < $cycle ){
                    # go to next one now
                }
                # matches
                elsif( $cycle_sumwallhr == $cycle ){
                    # found it - update for start of next search
                    $days_sumwallhr = sprintf( "%12.6e", $$vals_ref{"sumwallhr"}{val}[$k]/(24) );
                    $k_start = $k + 1;
                    last;
                }
                # greater than
                else{
                    # already past it - let the cycle catch up
                    last;
                }
            }
            
            # wall_days, days_wall_tot, days_mach_tot
            # separate by ${CTF_VAL_SEPARATOR} for gnuplot plotting
            $days_secs_tot = $val / ( 3600 * 24 );
            $days_secs_tot_mach += ($val - $val_prev) * ( $numnodes / $nodes_max ) / (3600 * 24);
            $wall_days = $$vals_ref{"secs"}{val}[$i]/(3600 * 24);
            $val_1 = sprintf( "%12.6e${CTF_VAL_SEPARATOR}%s${CTF_VAL_SEPARATOR}%12.6e${CTF_VAL_SEPARATOR}%12.6e",
                              $wall_days,
                              $days_sumwallhr,
                              $days_secs_tot,
                              $days_secs_tot_mach
                );
            push( @{$$vals_ref{$field_1}{val}},   $val_1 );

            $val_prev = $val;

        }

        # now shove in cycle
        @{$$vals_ref{$field_1}{cycle}}   = @{$$vals_ref{"secs_cycle"}{cycle}};

    }

    # --------------
    # restart_blocks : the end of the cycle where restart_block triggered
    #                  next cycle is the first real cycle
    # restart_block:<restart_block> with restart block num
    # --------------
    @fields = grep( /^restart_block:/, keys %{$vals_ref} );
    if( @fields ){
        undef( %key_val );
        # start with restart_block:NONE
        $cycle = $$vals_ref{cycle}{cycle}[0];
        $val   = "NONE";
        push( @{$keys_vals{$cycle}}, $val );
        # fill in order of restart block
        foreach $field ( sort @fields ){
            ( $field_new = $field ) =~ s/^restart_block://;
            $cycle = $$vals_ref{$field}{cycle}[0];
            $val = $field_new;
            # can have multiple restart blocks trigger at same time
            push( @{$keys_vals{$cycle}}, $val );
        }
        @cycles = sort my_numerically keys %keys_vals;
        $restart_block_num = 0;
        foreach $cycle ( @cycles ){
            foreach $val ( @{$keys_vals{$cycle}} ){
                $restart_block_num_print = sprintf( "%03d", $restart_block_num );
                $field_use = "$restart_block_num_print:$val";
                $restart_block_num++;
                push( @{$$vals_ref{"restart_blocks"}{val}},   $field_use );
                push( @{$$vals_ref{"restart_blocks"}{cycle}}, $cycle );
                push( @{$$vals_ref{"restart_block:$field_use"}{val}},   $field_use );
                push( @{$$vals_ref{"restart_block:$field_use"}{cycle}}, $cycle );
                # delete ctf of restart_block: w/out restart block number
                delete( $$vals_ref{"restart_block:$val"} );
            }
        }
    } # restart_blocks, restart_block:<restart_block> with restart block num

    # ------------------------
    # restart_block_secs_cycle:$restart_block
    # restart_block_secs_cycle_sum
    # ------------------------
    if( defined( $$vals_ref{"secs_cycle"} ) &&
        defined( $$vals_ref{"restart_blocks"} ) ){

        $num_secs_cycle     = $#{$$vals_ref{"secs_cycle"}{cycle}} + 1;
        $max_restart_blocks = $#{$$vals_ref{"restart_blocks"}{cycle}};
        $j_start  = 0;
        $val_tot  = 0;
        $val_prev = 0;

        # restart_block_secs_cycle
        $cycle_restart_block = $$vals_ref{"restart_blocks"}{cycle}[$j_start];
        $cycle_restart_block_next = -1;
        $j_next = 0;
        $restart_block = $$vals_ref{"restart_blocks"}{val}[$j_start];
        $field_use = "restart_block_secs_cycle:$restart_block";
        for( $i = 0; $i < $num_secs_cycle; $i++ ){

            # current cycle and value info
            $cycle = $$vals_ref{"secs_cycle"}{cycle}[$i];
            $val   = $$vals_ref{"secs_cycle"}{val}[$i];

            # if $cycle past the next restart block and there is another rb
            if( $cycle > $cycle_restart_block_next && $j_next >= 0 ){
                # will start searching at next one
                $j_start = $j_next;
                # update the start cycle for this restart block
                $cycle_restart_block =
                    $$vals_ref{"restart_blocks"}{cycle}[$j_start];
                # rename field_use
                $restart_block = $$vals_ref{"restart_blocks"}{val}[$j_start];
                $field_use = "restart_block_secs_cycle:$restart_block";

                # find next one
                # init j_next = -1 == "there is no next one"
                $j_next = -1;
                for( $j = $j_start+1; $j <= $max_restart_blocks; $j++ ){
                    $cycle_restart_block_next =
                        $$vals_ref{"restart_blocks"}{cycle}[$j];
                    if( $cycle_restart_block_next > $cycle_restart_block ){
                        $j_next = $j;
                        last;
                    }
                }

            }

            # add values
            push( @{$$vals_ref{$field_use}{val}},   $val );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle );

        } # restart_block_secs_cycle

        # now have:
        # restart_block_secs_cycle:{num}:{restart_block}
        #   This is the secs_cycle of the first cycle run in the new restart block.
        #   Which is 1 more than the cycle number of:
        #      restart_block:{num}:{restart_block}

        # restart_block_secs_cycle_tot
        @fields = sort grep( /^restart_block_secs_cycle:/, keys %{$vals_ref} );
        undef( $cycle_prev );
        foreach $field ( @fields ){
            ( $restart_block = $field ) =~
                s/^(restart_block_secs_cycle)://;
            # starting value and cycle
            $val         = 0;
            $cycle_first = $$vals_ref{$field}{cycle}[0];
            # only need to set this the first time (cycle_prev will be found later)
            if( ! defined( $cycle_prev ) ){
                $cycle_prev = $cycle - 1;
            }
            $num_secs_cycle = $#{$$vals_ref{$field}{cycle}} + 1;
            # sum up values for this restart block.
            # restart_block_secs_cycle is the val for just that cycle
            # so need to multiply by the number of cycles to get real
            # wallclock secs (modcyc > 1)
            for( $i = 0; $i < $num_secs_cycle; $i++ ){
                $cycle        = $$vals_ref{$field}{cycle}[$i];
                $cycle_delta  = $cycle - $cycle_prev;
                $val         += $cycle_delta * $$vals_ref{$field}{val}[$i];
                $cycle_prev   = $cycle;
            }
            $field_use = "restart_block_secs_cycle_tot:$restart_block";
            push( @{$$vals_ref{$field_use}{val}},   $val );
            push( @{$$vals_ref{$field_use}{cycle}}, $cycle_first );            
        }

    } # restart_block_secs_cycle, restart_block_secs_cycle_sum

    # ---------------------
    # smooth various things
    # makes for better visual plots of restart block stuff
    # ---------------------
    $field_use = "dt";
    if( defined( $$vals_ref{$field_use} ) ){
        @vals_arr = @{$$vals_ref{$field_use}{val}};
        $cycle_ref = \@{$$vals_ref{$field_use}{cycle}};
        # can be pretty noisy...smooth most
        &my_smooth( X=>$cycle_ref, Y=>\@vals_arr, NUM_SMOOTHS=>1, NOISE=>1 );
        push( @{$$vals_ref{"${field_use}_smooth"}{val}},   @vals_arr );
        push( @{$$vals_ref{"${field_use}_smooth"}{cycle}}, @{$cycle_ref} );
    }
    $field_use = "ncell";
    if( defined( $$vals_ref{$field_use} ) ){
        @vals_arr = @{$$vals_ref{$field_use}{val}};
        $cycle_ref = \@{$$vals_ref{$field_use}{cycle}};
        # can be pretty noisy...smooth most
        &my_smooth( X=>$cycle_ref, Y=>\@vals_arr, NOISE=>1 );
        push( @{$$vals_ref{"${field_use}_smooth"}{val}},   @vals_arr );
        push( @{$$vals_ref{"${field_use}_smooth"}{cycle}}, @{$cycle_ref} );
    }
    $field_use = "Resources:memory:RSS:Max%";
    if( defined( $$vals_ref{$field_use} ) ){
        @vals_arr = @{$$vals_ref{$field_use}{val}};
        $cycle_ref = \@{$$vals_ref{$field_use}{cycle}};
        # can be pretty noisy...smooth most
        &my_smooth( X=>$cycle_ref, Y=>\@vals_arr, NOISE=>1 );
        push( @{$$vals_ref{"${field_use}_smooth"}{val}},   @vals_arr );
        push( @{$$vals_ref{"${field_use}_smooth"}{cycle}}, @{$cycle_ref} );
    }
    $field_use = "secs_cycle";
    if( defined( $$vals_ref{$field_use} ) ){
        @vals_arr = @{$$vals_ref{$field_use}{val}};
        $cycle_ref = \@{$$vals_ref{$field_use}{cycle}};
        # can be pretty noisy...smooth most
        &my_smooth( X=>$cycle_ref, Y=>\@vals_arr, NOISE=>1 );
        push( @{$$vals_ref{"${field_use}_smooth"}{val}},   @vals_arr );
        push( @{$$vals_ref{"${field_use}_smooth"}{cycle}}, @{$cycle_ref} );
    }

    # -------------------
    # Any extra finishing
    # -------------------
    foreach $extra ( sort keys %ctf_extras_required ){
        if( $extra =~ /(eap_output_.*)/ ){
            $extra_routine = "ctf_readfinish_${1}";
            $eval_error = eval "\$ierr = &$extra_routine( VALS=>\$vals_ref, VERBOSE=>\$verbose )";
            # error stored into $@
            if( $@ || $ierr != 0 ){
                $ierr = 1;
                &print_error( "Error from $extra_routine :",
                              $@, $ierr );
                exit( $ierr );
            }
        }
    }

    # finish of things that are done after the other extras
    foreach $extra ( sort keys %ctf_extras_required ){
        if( $extra =~ /(rj_cmd_out)/ ){
            $extra_routine = "ctf_readfinish_$1";
            $eval_error = eval "\$ierr = &$extra_routine( VALS=>\$vals_ref, VERBOSE=>\$verbose )";
            # error stored into $@
            if( $@ || $ierr != 0 ){
                $ierr = 1;
                &print_error( "Error from $extra_routine :",
                              $@, $ierr );
                exit( $ierr );
            }
        }
    }

    # do a check now
    &ctf_vals_check( VALS=>$vals_ref );

    # ctf_fill_time to get times on each NEW field
    &ctf_fill_time( VALS=>$vals_ref );
    
    # return
    return( $ierr );
    
}

sub my_numerically { $a <=> $b; }

########################################################################
# sort "<number><whitespace><string>" based numerically on number
sub this_numerically_val{
    my(
        $a_val,
        $b_val,
        $ret,
        );
    ($a_val = $a) =~ s/\s+.*//;
    ($b_val = $b) =~ s/\s+.*//;
    $ret = $a_val <=> $b_val;
    # if tied, just cmp rest of string
    if( $ret == 0 ){
        ($a_val = $a) =~ s/^\S+\s+//g;
        ($b_val = $b) =~ s/^\S+\s+//g;
        $ret = $a_val cmp $b_val;
    }
    return( $ret );
}

########################################################################
# Required routine: ctf_plot_eap_output
sub ctf_plot_eap_output{
    my %args = (
        FILE_INFO  => undef, # \%file_info
        PLOT_INFO  => undef, # \@plot_info
        VERBOSE    => undef, # if verbose
        @_,
        );
    my( $args_valid ) = "FILE_INFO|PLOT_INFO|VERBOSE";
    my(
        $arg,
        %ctf_extras_required,
        $eval_error,
        $extra,
        $extra_routine,
        $field,
        $field_1,
        $field_2,
        $field_title,
        $field_use,
        @fields,
        @fields_1,
        @fields_all,
        @fields_found,
        %fieldsh,
        $file_info_ref,
        $ierr,
        $max,
        $mat,
        $match,
        $num,
        $num_max,
        $plot_i,
        $plot_info_ref,
        $seg,
        %state,
        $subroutine,
        %subroutines,
        $title,
        $val,
        $var,
        $verbose,
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

    # for extra plotting routines
    %ctf_extras_required =  &ctf_extras();

    # either of these specify where data is
    $file_info_ref = $args{FILE_INFO};
    $plot_info_ref = $args{PLOT_INFO};

    @fields_all = sort keys %{$$file_info_ref{field}};
    $plot_i = -1;

    # secs
    if( defined($$file_info_ref{field}{"secs"}) ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "secs_tot (seconds total) and secs (secs per op)";
        $$plot_info_ref[$plot_i]{xlabel} = "cycle";
        $$plot_info_ref[$plot_i]{ylabel} = "seconds total (secs, secs_tot, secs_tot_io";
        $$plot_info_ref[$plot_i]{yscale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y_fields}},
              "secs",
              "secs_tot",
              "secs_tot_io",
            );
        $$plot_info_ref[$plot_i]{y2label} = "secs per op";
        $$plot_info_ref[$plot_i]{y2scale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y2_fields}},
              "secs_cycle",
              "secs/cycle",
              "secs_lost",
              "secs_restart",
              "secs_io",
            );
    }

    # secs_io
    if( defined($$file_info_ref{field}{"secs"}) ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "IO secs_tot (seconds total) and secs (secs per op)";
        $$plot_info_ref[$plot_i]{xlabel} = "cycle";
        $$plot_info_ref[$plot_i]{ylabel} = "seconds total";
        $$plot_info_ref[$plot_i]{yscale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y_fields}},
              "secs_tot",
              "secs_tot_io",
              "secs_tot_io_read",
              "secs_tot_io_write",
              "secs_tot_dmp_read",
              "secs_tot_dmp_write",
            );
        $$plot_info_ref[$plot_i]{y2label} = "secs per op";
        $$plot_info_ref[$plot_i]{y2scale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y2_fields}},
              "secs_cycle",
              "secs/cycle",
              "secs_io",
              "secs_io_read",
              "secs_io_write",
              "dmp_read_time",
              "dmp_write_time",
              "pio_read_other:time",
              "ensight_write_time",
              "hdf_write_time",
            );
    }

    # rate_io
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "IO Rate";
    $$plot_info_ref[$plot_i]{xlabel} = "cycle";
    $$plot_info_ref[$plot_i]{ylabel} = "Rate (probably MB/S)";
    #$$plot_info_ref[$plot_i]{yscale} = "logscale";
    push( @{$$plot_info_ref[$plot_i]{y_fields}},
          "dmp_read_rate",
          "dmp_write_rate",
          "pio_read_other:rate",
        );
    $$plot_info_ref[$plot_i]{y2label} = "size (probably MB)";
    $$plot_info_ref[$plot_i]{y2scale} = "logscale";
    push( @{$$plot_info_ref[$plot_i]{y2_fields}},
          "dmp_read_size",
          "dmp_write_size",
        );

    # resources
    if( defined($$file_info_ref{field}{"Resources:memory:RSS_MAX:Max%"}) ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "Resources: percent and total";
        $$plot_info_ref[$plot_i]{xlabel} = "cycle";
        $$plot_info_ref[$plot_i]{ylabel} = "percent";
        # we have machines that allow 4000% virtual memory...so need logscale
        $$plot_info_ref[$plot_i]{yscale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y_fields}},
              "Resources:memory:RSS_MAX:Max%",
              "Resources:memory:RSS_MAX:Min%",
              "Resources:memory:RSS:Max%",
              "Resources:memory:RSS:Min%",
              "Resources:memory:Virt:Max%",
              "procmon_free_mem_pct_min"
            );
        $$plot_info_ref[$plot_i]{y2label} = "total";
        $$plot_info_ref[$plot_i]{y2scale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y2_fields}},
              "Resources:memory:avail_node:Min",
              "Resources:memory:avail_node:Max",
              "ncell",
              "sumRSS_GB",
            );
    }

    # relationship of secs_cycle and memory use
    if( defined($$file_info_ref{field}{"Resources:memory:RSS_MAX:Max%"}) &&
        defined($$file_info_ref{field}{"secs_cycle"}) ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "Memory and secs_cycle";
        $$plot_info_ref[$plot_i]{xlabel} = "cycle";
        $$plot_info_ref[$plot_i]{ylabel} = "percent";
        # too hard to see the type of growth (linear, non-linear)
        # with log scale...so take this out.  Still on previous plot.
        #$$plot_info_ref[$plot_i]{yscale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y_fields}},
              #"Resources:memory:Virt:Max%",
              "Resources:memory:RSS_MAX:Max%",
              "Resources:memory:RSS:Max%",
            );
        $$plot_info_ref[$plot_i]{y2label} = "total";
        #$$plot_info_ref[$plot_i]{y2scale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y2_fields}},
              "secs_cycle",
              "secs/cycle",
            );
    }

    # relationship of secs_cycle and ncell
    if( defined($$file_info_ref{field}{"Resources:memory:RSS_MAX:Max%"}) &&
        defined($$file_info_ref{field}{"secs_cycle"}) ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "ncell and secs_cycle";
        $$plot_info_ref[$plot_i]{xlabel} = "cycle";
        $$plot_info_ref[$plot_i]{ylabel} = "ncell";
        # too hard to see the type of growth (linear, non-linear)
        # with log scale...so take this out.  Still on previous plot.
        #$$plot_info_ref[$plot_i]{yscale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y_fields}},
              "ncell",
            );
        $$plot_info_ref[$plot_i]{y2label} = "secs_cycle";
        #$$plot_info_ref[$plot_i]{y2scale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y2_fields}},
              "secs_cycle",
            );
    }

    # Resources:walldays:{stuff}
    @fields_found = grep( /^Resources:walldays/, @fields_all );
    if( @fields_found ){
        $field = $fields_found[0];
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "$field : (mach -> scaled by available nodes)";
        $$plot_info_ref[$plot_i]{xlabel} = "wallclock days";
        $$plot_info_ref[$plot_i]{ylabel} = "days values (mach -> scled by available nodes)";
        $$plot_info_ref[$plot_i]{grid}   = "";
        # days:sumwallhr
        push( @{$$plot_info_ref[$plot_i]{y_fields}}, "$field" );
        push( @{$$plot_info_ref[$plot_i]{usings}},   "using 3:4" );
        push( @{$$plot_info_ref[$plot_i]{titles}},   "days:sumwallhr" );
        # days:secs_tot
        push( @{$$plot_info_ref[$plot_i]{y_fields}}, "$field" );
        push( @{$$plot_info_ref[$plot_i]{usings}},   "using 3:5" );
        push( @{$$plot_info_ref[$plot_i]{titles}},   "days:secs_tot" );
        # days:secs_tot_mach (if there)
        # only useful when have the value scaled to machine days (nodes_total)
        if( $field =~ /secs_tot_mach/ ){
            push( @{$$plot_info_ref[$plot_i]{y_fields}}, "$field" );
            push( @{$$plot_info_ref[$plot_i]{usings}},   "using 3:6" );
            push( @{$$plot_info_ref[$plot_i]{titles}},   "days:secs_tot_mach" );
        }
    }

    # restart blocks and secs things
    if( defined( $$file_info_ref{field}{secs} ) ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "Wallclock Days per [Restart Block] and [Secs Things]";
        $$plot_info_ref[$plot_i]{xlabel} = "cycle";
        $$plot_info_ref[$plot_i]{grid}   = "";

        $$plot_info_ref[$plot_i]{ylabel} = "Wallclock Days Restart Blocks";
        @fields = grep(/^restart_block_secs_cycle_tot/, @fields_all);
        push( @{$$plot_info_ref[$plot_i]{y_fields}}, @fields );
        foreach $field ( @fields ){
            $$plot_info_ref[$plot_i]{with}{$field}        = "with impulses";
            $$plot_info_ref[$plot_i]{lw}{$field}          = "lw 3";
            ( $title = $field ) =~ s/restart_block_secs_cycle_tot://;
            $$plot_info_ref[$plot_i]{title_field}{$field} = $title;
            # convert into days
            $$plot_info_ref[$plot_i]{using_math}{$field}  = "(y/3600/24)";
        }

        # overall times for things
        # will sort this on last value
        $$plot_info_ref[$plot_i]{y2label} = "Wallclock Days Secs Things";
        @fields = (
            "secs",
            "secs_tot",
            "rj_secs_wait_excl_sum",
            "secs_tot_restart",
            "secs_tot_io",
            "secs_tot_io_write",
            "secs_tot_io_read"
            );
        $$plot_info_ref[$plot_i]{y2_sort} = "last_val";
        push( @{$$plot_info_ref[$plot_i]{y2_fields}}, @fields );
        foreach $field ( @fields ){
            # convert into days
            $$plot_info_ref[$plot_i]{using_math}{$field}  = "(y/3600/24)";
        }

    }

    # restart blocks vs. sim time
    if( defined( $$file_info_ref{field}{secs} ) ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "Wallclock Days per [Restart Block] -Versus- Simulation Time";
        $$plot_info_ref[$plot_i]{xlabel} = "time";
        $$plot_info_ref[$plot_i]{grid}   = "";

        $$plot_info_ref[$plot_i]{ylabel} = "Wallclock Days Restart Blocks";
        @fields = grep(/^restart_block_secs_cycle_tot/, @fields_all);
        push( @{$$plot_info_ref[$plot_i]{y_fields}}, @fields );
        foreach $field ( @fields ){
            $$plot_info_ref[$plot_i]{with}{$field}        = "with impulses";
            $$plot_info_ref[$plot_i]{lw}{$field}          = "lw 3";
            ( $title = $field ) =~ s/restart_block_secs_cycle_tot://;
            $$plot_info_ref[$plot_i]{title_field}{$field} = $title;
            # convert into days
            $$plot_info_ref[$plot_i]{using_math}{$field}  = "(y/3600/24)";
        }

    }

    # restart blocks and various fields
    # smoothing looks better for these
    #   "Resources:memory:RSS:Max%",
    #   "dt",
    #   "ncell",
    #   "secs_cycle",
    # order to show ncell growth and effect on memory afterwards
    foreach $field_use (
        "ncell_smooth",
        "Resources:memory:RSS:Max%_smooth",
        "secs_cycle_smooth",
        "dt_smooth",
        "#pe",
        "Resources:PPN",
        "Resources:NUMNODES"
        ){
        
        # strip out for more concise title
        ( $field_title = $field_use ) =~ s/^Resources://;

        if( defined( $$file_info_ref{field}{secs} ) ){
            $plot_i++;
            $$plot_info_ref[$plot_i]{title}  = "Wallclock Days per [Restart Block] and [$field_title]";
            $$plot_info_ref[$plot_i]{xlabel} = "cycle";
            $$plot_info_ref[$plot_i]{grid}   = "";
            
            $$plot_info_ref[$plot_i]{ylabel} = "Wallclock Days Restart Blocks";
            @fields = grep(/^restart_block_secs_cycle_tot/, @fields_all);
            push( @{$$plot_info_ref[$plot_i]{y_fields}}, @fields );
            foreach $field ( @fields ){
                $$plot_info_ref[$plot_i]{with}{$field}        = "with impulses";
                $$plot_info_ref[$plot_i]{lw}{$field}          = "lw 3";
                ( $title = $field ) =~ s/restart_block_secs_cycle_tot://;
                $$plot_info_ref[$plot_i]{title_field}{$field} = $title;
                # convert into days
                $$plot_info_ref[$plot_i]{using_math}{$field}  = "(y/3600/24)";
            }
            
            # overall times for things
            # will sort this on last value
            $$plot_info_ref[$plot_i]{y2label} = "$field_title";
            if( $field_use =~ /^dt/ ){
                $$plot_info_ref[$plot_i]{y2scale} = "logscale";
            }
            @fields = (
                $field_use,
                );
            $$plot_info_ref[$plot_i]{y2_sort} = "last_val";
            push( @{$$plot_info_ref[$plot_i]{y2_fields}}, @fields );
            foreach $field ( @fields ){
                ( $title = $field ) =~ s/^Resources://;
                $$plot_info_ref[$plot_i]{title_field}{$field}  = $field_title;
            }
            
        }

    } # various other Resources:

    # avg_cell
    if( defined($$file_info_ref{field}{"avg_cell"}) ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "avg_cell and ncell";
        $$plot_info_ref[$plot_i]{xlabel} = "cycle";
        $$plot_info_ref[$plot_i]{ylabel} = "min/avg/max_cell";
        #$$plot_info_ref[$plot_i]{yscale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y_fields}},
              "min_cell",
              "avg_cell",
              "max_cell",
            );
        $$plot_info_ref[$plot_i]{y2label} = "ncell,numact,numall";
        #$$plot_info_ref[$plot_i]{y2scale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y2_fields}},
              "ncell",
              # plots get too busy if you include these
              #"numact",
              #"numall",
            );
    }

    # solver iterations
    if( defined( $$file_info_ref{field}{"#ritr"}) ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "Solver Iterations";
        $$plot_info_ref[$plot_i]{xlabel} = "cycle";
        $$plot_info_ref[$plot_i]{ylabel} = "total";
        #$$plot_info_ref[$plot_i]{yscale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y_fields}},
              "#ritr",
              "#citr",
            );
    }

    # cc/s/p
    if( defined($$file_info_ref{field}{"cc/s/p"}) ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "cc/s/p and lost cycles";
        $$plot_info_ref[$plot_i]{xlabel} = "cycle";
        $$plot_info_ref[$plot_i]{ylabel} = "cc/s/p";
        #$$plot_info_ref[$plot_i]{yscale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y_fields}},
              "cc/s/p" );
        $$plot_info_ref[$plot_i]{y2label} = "lost_cycles";
        #$$plot_info_ref[$plot_i]{y2scale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y2_fields}},
              "lost_cycles" );
    }

    # time vs. cycle
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "(time) and (cycle)";
    $$plot_info_ref[$plot_i]{xlabel} = "cycle";
    $$plot_info_ref[$plot_i]{ylabel} = "time";
    push( @{$$plot_info_ref[$plot_i]{y_fields}},
          "time",
        );
    $$plot_info_ref[$plot_i]{y2label} = "ncell, secs_cycle";
    $$plot_info_ref[$plot_i]{y2scale} = "logscale";
    push( @{$$plot_info_ref[$plot_i]{y2_fields}},
          "ncell",
          "secs_cycle",
        );

    # cycle vs. time
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "(cycle) and (time)";
    $$plot_info_ref[$plot_i]{xlabel} = "time";
    $$plot_info_ref[$plot_i]{ylabel} = "cycle";
    push( @{$$plot_info_ref[$plot_i]{y_fields}},
          "cycle",
        );
    $$plot_info_ref[$plot_i]{y2label} = "ncell, secs_cycle";
    $$plot_info_ref[$plot_i]{y2scale} = "logscale";
    push( @{$$plot_info_ref[$plot_i]{y2_fields}},
          "ncell",
          "secs_cycle",
        );

    # dt
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "dt";
    $$plot_info_ref[$plot_i]{xlabel} = "time";
    $$plot_info_ref[$plot_i]{ylabel} = "dt";
    #$$plot_info_ref[$plot_i]{yscale} = "logscale";
    push( @{$$plot_info_ref[$plot_i]{y_fields}},
          "dt",
        );
    $$plot_info_ref[$plot_i]{y2label} = "cycle";
    #$$plot_info_ref[$plot_i]{y2scale} = "logscale";
    push( @{$$plot_info_ref[$plot_i]{y2_fields}},
          "cycle" );

    # timing_
    @fields = grep(/^timing_/, @fields_all);
    if( @fields ){

        $max{seg_} = $$file_info_ref{field}{"timing_seg_sum-cpusec_total"}{max};
        $max{sum}  = $$file_info_ref{field}{"timing_sum-cpusec_total"}{max};
        $val = .01;

        # see which subroutines we are interested in
        
        undef( %subroutines );
        foreach $field ( @fields ){
            if( $field =~ /timing_(seg_)?sum-cpusec_sub_(\S+)/ ){
                $seg = $1;
                $subroutine = $2;
                if( ! defined($seg) ){
                    $seg = "sum";
                }
                if( $$file_info_ref{field}{$field}{max} >= $max{$seg} * $val ){
                    $subroutines{$subroutine} = "";
                }
            }
        }

        # if any matches
        if( %subroutines ){

            foreach $match( 
                "timing_seg_sum-cpusec_sub_",
                "timing_seg_run-calls_sub_",
                "timing_sum-cpusec_sub_",
                "timing_deriv_sum-cpusec_sub_",
                "timing_sum-pct_sub_",
                "timing_run-s/call_sub_",
                ){
                $plot_i++;
                $title = $match;
                if( $match =~ /timing_seg/ ){
                    $title .= " (_seg_ = normalized to 0)";
                }
                $$plot_info_ref[$plot_i]{title}  = $title;
                $$plot_info_ref[$plot_i]{xlabel} = "cycle";
                
                # for sum-cpusec, do total on right axis
                if( $match =~ /timing_(seg_)?sum-cpusec_sub_/ ){
                    $seg = $1;
                    if( ! defined($seg) ){
                        $seg = "";
                    }
                    $field = "timing_${seg}sum-cpusec_total";
                    $val = sprintf( " %.3e", $$file_info_ref{field}{$field}{max} );
                }
                else{
                    $val = "";
                }
                $$plot_info_ref[$plot_i]{ylabel} = "$match$val";
                
                $$plot_info_ref[$plot_i]{y_sort} = "last_val";
                if( $match =~ m&(s/call_sub_|calls_sub_)& ){
                    $$plot_info_ref[$plot_i]{yscale} = "logscale";
                }
                foreach $field ( @fields ){
                    if( $field =~ /^${match}/ ){
                        if( $field =~ /_sub_(\S+)/ ){
                            $subroutine = $1;
                            if( defined($subroutines{$subroutine}) ){
                                push( @{$$plot_info_ref[$plot_i]{y_fields}},
                                      $field,
                                    );
                            }
                        }
                    }
                }
            }
        }
    } # timing

    # mixed material cells (material distribution)
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "mixed material cells (material distribution)";
    $$plot_info_ref[$plot_i]{xlabel} = "time";
    $$plot_info_ref[$plot_i]{ylabel} = "NCellTMix = percentage of top cells that are mixed";
    #$$plot_info_ref[$plot_i]{yscale} = "logscale";
    push( @{$$plot_info_ref[$plot_i]{y_fields}},
          "NcellTMix",
        );
    $$plot_info_ref[$plot_i]{y2label} = "NCellTMixAvg = average number of mats per cell";
    #$$plot_info_ref[$plot_i]{y2scale} = "logscale";
    push( @{$$plot_info_ref[$plot_i]{y2_fields}},
          "NcellTMixAvg",
        );

    # integrated_state_data
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "integrated_state_data";
    $$plot_info_ref[$plot_i]{xlabel} = "time";
    $$plot_info_ref[$plot_i]{ylabel} = "Energy";
    $$plot_info_ref[$plot_i]{yscale} = "logscale";
    @fields_1 = grep(/^Integrated_state_data:\-?(e.*|.*e)$/, @fields_all);
    @fields   = grep( ! /(err)/, @fields_1 );
    push( @{$$plot_info_ref[$plot_i]{y_fields}},
          @fields,
        );
    $$plot_info_ref[$plot_i]{y2label} = "err";
    push( @{$$plot_info_ref[$plot_i]{y2_fields}},
          "err",
        );

    # energy_source_sink
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "energy_source_sink";
    $$plot_info_ref[$plot_i]{xlabel} = "time";
    $$plot_info_ref[$plot_i]{ylabel} = "Energy -in";
    #$$plot_info_ref[$plot_i]{yscale} = "logscale";
    @fields = grep(/^energy_source_sink::.*-in$/, @fields_all);
    push( @{$$plot_info_ref[$plot_i]{y_fields}},
          @fields,
        );
    $$plot_info_ref[$plot_i]{ylabel} = "Energy -out";
    @fields = grep(/^energy_source_sink::.*-out$/, @fields_all);
    push( @{$$plot_info_ref[$plot_i]{y2_fields}},
          @fields,
        );

    # what_<VAR>
    @fields = grep( /^what_([A-Z])/, @fields_all );
    undef( %fieldsh );
    foreach $field( @fields ){
        if( $field =~ /^what_([A-Z_]+)/ ){
            ($var = $1) =~ s/_$//;
            if( $field =~ /(max|min)$/ ){
                push( @{$fieldsh{$var}{y}}, $field );
            }
            elsif( $field =~ /dist$/ ){
                push( @{$fieldsh{$var}{y2}}, $field );
            }
        }
    }
    foreach $var ( sort keys %fieldsh ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "what_$var";
        $$plot_info_ref[$plot_i]{xlabel} = "time";
        $$plot_info_ref[$plot_i]{ylabel} = "max/min";
        #$$plot_info_ref[$plot_i]{yscale} = "logscale";
        if( defined($fieldsh{$var}{y}) ){
            push( @{$$plot_info_ref[$plot_i]{y_fields}},
                  @{$fieldsh{$var}{y}},
                );
        }
        if( defined($fieldsh{$var}{y2}) ){
            $$plot_info_ref[$plot_i]{y2label} = "dist";
            push( @{$$plot_info_ref[$plot_i]{y2_fields}},
                  @{$fieldsh{$var}{y2}},
                );
        }
    }

    # matinfo
    @fields = grep( /^matinfo_(\d+)/, @fields_all );
    undef( %fieldsh );
    foreach $field( @fields ){
        if( $field =~ /^matinfo_(\d+)/ ){
            $mat = $1;
            if( $field =~ /(mass|rho|vol)/ ){
                push( @{$fieldsh{$mat}{y2}}, $field );
            }
            else{
                push( @{$fieldsh{$mat}{y}}, $field );
            }
        }
    }
    foreach $mat ( sort keys %fieldsh ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "matinfo_$mat";
        $$plot_info_ref[$plot_i]{xlabel} = "time";
        $$plot_info_ref[$plot_i]{ylabel} = "Energy";
        $$plot_info_ref[$plot_i]{yscale} = "logscale";
        if( defined($fieldsh{$mat}{y}) ){
            push( @{$$plot_info_ref[$plot_i]{y_fields}},
                  @{$fieldsh{$mat}{y}},
                );
        }
        $$plot_info_ref[$plot_i]{y2label} = "mass,vol,rho";
        if( defined($fieldsh{$mat}{y2}) ){
            push( @{$$plot_info_ref[$plot_i]{y2_fields}},
                  @{$fieldsh{$mat}{y2}},
                );
        }
    }
    
    # isosum
    @fields = grep( /^isosum_(\d+)/, @fields_all );
    undef( %fieldsh );
    foreach $field( @fields ){
        if( $field =~ /^isosum_(\d+)/ ){
            $mat = $1;
            if( $field =~ /(_MASS)/ ){
                push( @{$fieldsh{$mat}{y2}}, $field );
            }
            else{
                push( @{$fieldsh{$mat}{y}}, $field );
            }
        }
    }
    foreach $mat ( sort keys %fieldsh ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "isosum_$mat";
        $$plot_info_ref[$plot_i]{xlabel} = "time";
        $$plot_info_ref[$plot_i]{ylabel} = "moles, number";
        $num_max = 10;
        $num = 0;
        if( defined($fieldsh{$mat}{y}) ){
            $num = $#{$fieldsh{$mat}{y}};
        }
        if( $num <= $num_max ){
            if( defined($fieldsh{$mat}{y}) ){
                push( @{$$plot_info_ref[$plot_i]{y_fields}},
                      @{$fieldsh{$mat}{y}},
                    );
            }
        }
        $$plot_info_ref[$plot_i]{y2label} = "mass";
        $$plot_info_ref[$plot_i]{y2scale} = "logscale";
        if( $num <= $num_max ){
            if( defined($fieldsh{$mat}{y2}) ){
                push( @{$$plot_info_ref[$plot_i]{y2_fields}},
                      @{$fieldsh{$mat}{y2}},
                    );
            }
        }
    }

    # TN Reactions
    # Might be too many to plot (many zaids or mats)  or make sense of plots.
    @fields = sort grep( /^TNR:table=/, @fields_all );
    undef( %fieldsh );
    # 1 plot per zaid:type (combine per_mat and total)
    foreach $field( @fields ){

        # skip the "mol" ones (have the "#" ones)
        if( $field =~ /mol/ ){
            next;
        }

        # skip the ones that stay 0
        if( $$file_info_ref{field}{$field}{num_vals_nums} ==
            $$file_info_ref{field}{$field}{num_vals_0} ){
            next;
        }

        # plot based on reaction_zaid
        if( $field =~ /:rz=([^:]+)/ ){
            $field_1 = $1;
        }
        else{
            $field_1 = "parser_error_tn_reactions_zaid";
        }

        # and var type
        if( $field =~ /:([^:]+)$/ ){
            $field_2 = $1;
        }
        else{
            $field_2 = "parser_error_tn_reactions_var_type";
        }

        push( @{$fieldsh{"$field_1:$field_2"}}, $field );
        
    }

    # defined TN Reactions plots
    foreach $field ( sort keys %fieldsh ){
        
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "TNR:$field";
        $$plot_info_ref[$plot_i]{xlabel} = "time";
        $$plot_info_ref[$plot_i]{ylabel} = "$field";
        $$plot_info_ref[$plot_i]{y_sort} = "last_val";
        
        push( @{$$plot_info_ref[$plot_i]{y_fields}},
              @{$fieldsh{$field}},
            );
    }

    # ------------------
    # Any extra plotting
    # ------------------
    undef( %state );
    $state{plot_i}         = $plot_i;
    $state{fields_all_ref} = \@fields_all;
    foreach $extra ( sort keys %ctf_extras_required ){
        if( $extra =~ /(eap_output_.*)/ ){
            $extra_routine = "ctf_plot_${1}";
            $eval_error = eval "\$ierr = &$extra_routine( PLOT_INFO=>\$plot_info_ref, FILE_INFO=>\$file_info_ref, STATE=>\\\%state, VERBOSE=>\$verbose )";
            # error stored into $@
            if( $@ || $ierr != 0 ){
                $ierr = 1;
                &print_error( "Error from $extra_routine :",
                              $@, $ierr );
                exit( $ierr );
            }
            $plot_i = $state{plot_i};
        }
    }
    


}
# final require return
1;
