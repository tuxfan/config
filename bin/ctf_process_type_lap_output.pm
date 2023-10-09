########################################################################
# Type=lap_output
#   file fed into ctf_process.pm
#
# NOTE:
#   See cts_process.pm: "Internal Interface"
#
# File Format:
# ------------
#   lap screen output (so far...can add other types)
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
# Required routine: ctf_read_lap_output
sub ctf_read_lap_output{
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
        $cycle_field,
        $cycle_clear,
        $cycle_prev,
        $cycle_secs,
        $cycle_secs_tot,
        $data_found,
        $date,
        $done,
        $done_1,
        $extras_called,
        $field,
        $field_use,
        @fields_all,
        @fields_arr,
        $file,
        $file_num,
        $file_num_max,
        $file_top,
        $fh_FILE,
        $files_ref,
        $force,
        $i,
        $ierr,
        $index_field,
        $index_max,
        %indices,
        $line,
        @lines,
        $lines_not_processed,
        $lines_total,
        $lines_ref,
        $ln,
        $ln_max,
        $num,
        $num_c,
        $num_files_try_max,
        $secs,
        $secs_lost,
        $secs_run,
        $secs_start,
        $secs_tot,
        $start_file_done,
        %state,
        $time,
        $val,
        @vals,
        $vals_ref,
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
    while( ! defined($done) ){
        undef( $file );
        # fill file_top
        if( defined($files_ref) ){
            if( $file_num > $#$files_ref ){
                last;
            }
            if( $file_num >= $num_files_try_max ){
                last;
            }
            $file = $$files_ref[$file_num];
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
        if( $file_top =~ /RJ_OUTPUT: / ){

            # open file if given
            undef( $fh_FILE );
            if( defined( $file ) ){
                if( ! open( $fh_FILE, $file ) ){
                    last;
                }
            }

            # go through lines
            $i=0;
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

                # only read up to a point
                if( $i > 200 ){
                    last;
                }

                # matches exec
                if( $line =~ m&RJ_OUTPUT:.*RJ_L_PRUN_EXEC=.*(OPUS|SPUBLIC)& ){
                    $ierr = 0;
                    last;
                }

                # matches some output
                if( $line =~ /^\s*OPUS:/ ){
                    $ierr = 0;
                    last;
                }
                $i++;
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
        if( $file_top =~ /^\s*OPUS\:/m ){
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
        print "$args{VERBOSE}ctf_process_type_lap_output\n";
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
        undef( %state );
        undef( $start_file_done );
        undef( %vals );
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
        while( ! defined($done) ){

            # debugging print to detect if cycle stored but no time
            #($line_new = $line) =~ s/\s*$//;
            #print "block $ln c=$#{$$vals_ref{cycle}{val}} t=$#{$$vals_ref{time}{val}} $line_new\n";

            # done
            if( $ln > $ln_max ){
                last;
            }

            # most likely a block will not match this line...so skip
            # file_num_max==1 : status per line
            #if( defined($args{VERBOSE}) ){
            #    if( $file_num_max == 1 ){
            #        &status_bar( $ln, $ln_max );
            #    }
            #}

            # read line
            $line = $$lines_ref[$ln]; $ln++;

            # current block line
            #print "block: $ln $line";

            # blank
            if( $line !~ /\S/ ){
                next;
            }

            # filler lines
            if( $line =~ /^\s*(=|-|\*)+\s*$/ ){
                next;
            }

            # filler lines
            elsif( $line =~ /^\s*RJ_OUTPUT:/ ){
                next;
            }

            # -------------------------------
            # if you see this again, treat as new file for
            # ctf_vals_splice
            # (user might have cat'd output files together)
            # -------------------------------
            elsif( $line =~ /^\s*CREATED BY:/ ){

                undef( $start_file_done );
                undef( %state );
                undef( $done );
                while( ! defined($done) ){
                    if( $ln > $ln_max ){
                        last;
                    }
                    $line = $$lines_ref[$ln]; $ln++;

                    if( $line =~ /EXECUTION: (.*?)\s*$/ ){
                        $date = $1;
                        $vals{date} = $date;
                    }
                    elsif( $line =~ /^\s*\*\*\*\*\*\*/ ){
                        last;
                    }
                }
            }

            # ----------------
            # MESH INFORMATION
            # ----------------
            elsif( $line =~ /^\s*\-+\s*MESH\s+INFORMATION\s*\-+\s*$/ ){
                $data_found = "";
                undef( $done );
                while( ! defined($done) ){
                    if( $ln > $ln_max ){
                        last;
                    }
                    $line = $$lines_ref[$ln]; $ln++;

                    if( $line =~ /Zones\s*:\s*(\d+)$/ ){
                        $vals{ncell} = $1;
                    }
                    elsif( $line =~ /^\s*\-+\s*$/ ){
                        last;
                    }
                }
            }

            # ----------------
            # cycle,time,dt,et
            # NOTE: data from this cycle is printed after this cycle
            #       (might also be before...but definitely after also)
            # ----------------
            elsif( $line =~ /^\s*
                             Cycle:\s*(\d+)\s*  # cycle
                             Time:\s*(\S+)\s*   # time
                             dt:\s*(\S+)\s*     # dt
                             ET:\s*(\S+)\s*     # ET
                             \s*$/x ){
                $data_found = "";
                $vals{cycle} = $1;
                $time        = $2;
                $vals{dt}    = $3;
                $vals{ET}    = $4;
                if( ! defined( $vals{time} ) ||
                    length($time) >= length($vals{time}) ){
                    $vals{time} = $time;
                }
                # keep track of the first cycle here
                if( ! defined($state{cycle_first}) ){
                    $state{cycle_first} = $vals{cycle};
                }
            }

            # ----------------
            # DT Limiter
            # ----------------
            elsif( $line =~ /^\s*
                             DT\s+Limiter:\s+(.*?)  # DT Limiter
                             \s*$/x ){
                $data_found = "";
                $vals{tstep} = $1;
                $vals{tstep} =~ s/\s+/_/g;
            }

            # ----------------
            # ncycg
            # ----------------
            elsif( $line =~ /^\s*
                             ncycg=\s*(\d+)\s*  # cycle
                             /x ){
                $vals{cycle} = $1;
            }

            # ----------------
            # timeg
            # ----------------
            elsif( $line =~ /^\s*
                             timeg=\s*(\S+)\s*  # time
                             /x ){
                $data_found = "";
                $time = $1;
                if( ! defined( $vals{time} ) ||
                    length($time) >= length($vals{time}) ){
                    $vals{time} = $time;
                }
            }

            # ----------------
            # total problem run time
            # ----------------
            elsif( $line =~ /^\s*
                             total\sproblem\srun\stime=\s*(\S+)\s*  # time
                             \s*$/x ){
                $data_found = "";
                $vals{secs_run} = $1;
            }

            # ----------------
            # ELAPSED TIMES SORTED PER PACKAGE
            #  also tells you:
            #    cycle
            #    ncell
            # ----------------
            # NOTE: This is not resilient to changes in columns
            #       (more cols, name changes, ...)
            #       And assumes some line found to signify block end
            elsif( $line =~ /ELAPSED TIMES SORTED PER PACKAGE/ ){
                
                $data_found = "";
                undef( $done );
                while( ! defined($done) ){
                    if( $ln > $ln_max ){
                        last;
                    }
                    $line = $$lines_ref[$ln]; $ln++;

                    if( $line =~ /EXECUTION: (.*?)\s*$/ ){
                        $date = $1;
                        $vals{date} = $date;
                    }
                    elsif( $line =~ /^\s*Total\s+Time\s+\|\s+
                                     (\S+)\s+\|\s+ # Since Last Report
                                     (\S+)         # Since Problem Start
                                     /xi ){
                        # Naming: ELAPSED_TIMES_P0_SPS_Total_Time
                        #   ELAPSED_TIMES
                        #   P0  = process 0 (maybe later have PALL, PMAX, ...)
                        #   SPS = Since Problem Start (Since Last Report, Last Cycle, ...)
                        #   Total_Time = Total Time with whitespace->_
                        $vals{ELAPSED_TIMES_P0_SPS_Total_Time} = $2;
                    }
                    elsif( $line =~ /Total number of zones\s*:\s*(\S+)/ ){
                        $vals{ncell} = $1;
                    }
                    elsif( $line =~ /^\s*All\s+(\S+)\s+cycles\s*:\s*(\S+)/ ){
                        $vals{Grind_Times_SPS} = $2;
                        # assume that cycle gotten from above block
                        $val = $1;
                        if( $vals{cycle} ne $val ){
                            $ierr = 0;
                            &print_error( "Assumption that cycle number found before ELAPSED TIMES SORTED PER PACKAGE",
                                          $ierr );
                        }
                        last;
                    }
                }
                
            }

            # -------------------------------
            # ELSE call extra in this else so that call not made every line
            # -------------------------------
            else{
                $lines_not_processed++;
            }

            # ============
            # process vals
            # ============

            # ctf_vals_splice/ctf_vals_add are expensive
            # only call if you have data to put in
            if( defined($vals{cycle}) && defined($data_found) ){

                undef($data_found);

                # keep previous cycle around since not all data knows cycle
                $state{cycle} = $vals{cycle};

                # if this is the start of the file, deal with restart splicing
                if( ! defined( $start_file_done ) ){

                    $start_file_done = "";
                    # also store any lost_cycles
                    if( defined($$vals_ref{cycle}) ){
                        $cycle_prev = $$vals_ref{cycle}{val}[-1];
                    }
                    else{
                        $cycle_prev = $vals{cycle};
                    }
                    # upon restart, the first cycle seen is actually
                    # the one from the restart dump.  Some data will be
                    # reprinted, but not all.  So only clear after that
                    # cycle.
                    $cycle_clear = $state{cycle} + 1;
                    &ctf_vals_splice( VALS=>$vals_ref, CYCLE=>$cycle_clear );
                    $vals{lost_cycles} = $cycle_prev - $vals{cycle};
                }

                # add values
                &ctf_vals_add( VALS=>$vals_ref, VALS_CYCLE=>\%vals );

                # keep previous cycle around since not all data knows cycle
                $vals{cycle} = $state{cycle};
            }

        } # process each line

    } # process each file

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

    # get list of keys
    @fields_all = keys( %$vals_ref );

    # ---------------------------
    # secs from date, ET, secs_run, 
    # ---------------------------
    if( defined( $$vals_ref{date}) ){

        @fields_arr = ("date", "ET", "secs_run");

        foreach $field ( @fields_arr ) {
            if( defined($$vals_ref{$field}) ){
                $indices{$field} = 0;
            }
        }

        if( defined($$vals_ref{cycle}) ){
            $index_max = $#{$$vals_ref{cycle}{val}};
        }
        else{
            $index_max = -1;
        }

        # init some vals
        $secs_run       =  0;
        $secs_tot       =  0;
        $cycle_secs     = -1;
        $cycle_secs_tot = -1;

        # loop through cycle
        for( $i = 0; $i <= $index_max; $i++ ){
            $cycle = $$vals_ref{cycle}{val}[$i];

            foreach $field ( @fields_arr ){
                if( ! defined( $indices{$field}) ){
                    next;
                }

                # index/cycle of the field
                $index_field = $indices{$field};
                $cycle_field = $$vals_ref{$field}{cycle}[$index_field];

                # skip if cycle does not match
                if( $cycle_field != $cycle ){
                    next;
                }

                $val = $$vals_ref{$field}{val}[$index_field];
                if( $index_field < $#{$$vals_ref{$field}{cycle}} ){
                    $indices{$field}++;
                }
                else{
                    delete( $indices{$field} );
                }

                # date
                # get secs_run and secs_lost
                if( $field eq "date" ){
                    $secs = `date -d "$val" +%s`;
                    $secs =~ s/\s+//g;
                    # secs at the start of this run
                    $secs_run = 0;

                    # get previous secs for secs_lost
                    if( defined($$vals_ref{secs}) ){
                        $secs_lost = $secs_run - $$vals_ref{secs}{val}[-1];
                    }
                    else{
                        $secs_lost = 0;
                    }
                    push( @{$$vals_ref{secs_lost}{val}},   $secs_lost);
                    push( @{$$vals_ref{secs_lost}{cycle}}, $cycle);
                    
                }

                # ET
                elsif( $field eq "ET" ){
                    $secs_tot += $val;
                    $secs     += $val;
                    $secs_run += $val;
                    # overwrite or push value
                    if( $cycle_secs < $cycle ){
                        $cycle_secs = $cycle;
                        push( @{$$vals_ref{secs}{val}},       $secs);
                        push( @{$$vals_ref{secs}{cycle}},     $cycle);
                        push( @{$$vals_ref{secs_tot}{val}},   $secs_tot);
                        push( @{$$vals_ref{secs_tot}{cycle}}, $cycle);
                    }
                    else{
                        $$vals_ref{secs}{val}[-1]     = $secs;
                        $$vals_ref{secs_tot}{val}[-1] = $secs_tot;
                    }
                }

                # secs_run
                elsif( $field eq "secs_run" ){
                    # subtract out previous secs_run to get val
                    $val = $val - $secs_run;
                    $secs_tot += $val;
                    $secs     += $val;
                    $secs_run += $val;
                    # overwrite or push value
                    if( $cycle_secs < $cycle ){
                        $cycle_secs = $cycle;
                        push( @{$$vals_ref{secs}{val}},       $secs);
                        push( @{$$vals_ref{secs}{cycle}},     $cycle);
                        push( @{$$vals_ref{secs_tot}{val}},   $secs_tot);
                        push( @{$$vals_ref{secs_tot}{cycle}}, $cycle);
                    }
                    else{
                        $$vals_ref{secs}{val}[-1]     = $secs;
                        $$vals_ref{secs_tot}{val}[-1] = $secs_tot;
                    }
                }

            } # foreach field
            
        } # loop through cycle

        # now normalize time
        $secs_start = $$vals_ref{secs}{val}[0] - $$vals_ref{secs_tot}{val}[0];
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
    # sumwallhr
    # -------------------------------------------------
    $field_use = "sumwallhr";
    $field     = "secs_tot";
    if( defined($$vals_ref{$field}) ){
        $cycle = $$vals_ref{$field}{cycle}[-1];
        $val   = $$vals_ref{$field}{val}[-1] / 3600;
        push( @{$$vals_ref{$field_use}{val}},   $val );
        push( @{$$vals_ref{$field_use}{cycle}}, $cycle );
    }

    # do a check now
    &ctf_vals_check( VALS=>$vals_ref );

    # ctf_fill_time to get times on each NEW field
    &ctf_fill_time( VALS=>$vals_ref );
    
    # return
    return( $ierr );
    
}

########################################################################
# Required routine: ctf_plot_lap_output
sub ctf_plot_lap_output{
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

    # secs
    if( defined($$file_info_ref{field}{"secs"}) ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "secs_tot (seconds total) and secs (secs per op)";
        $$plot_info_ref[$plot_i]{xlabel} = "cycle";
        $$plot_info_ref[$plot_i]{ylabel} = "seconds total";
        $$plot_info_ref[$plot_i]{yscale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y_fields}},
              "secs",
              "secs_tot",
            );
        $$plot_info_ref[$plot_i]{y2label} = "secs per op";
        $$plot_info_ref[$plot_i]{y2scale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y2_fields}},
              "secs_cycle",
              "secs_lost",
            );
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

    # Grind_Times / ELAPSED_TIMES
    $plot_i++;
    $$plot_info_ref[$plot_i]{title}  = "Grind_Times";
    $$plot_info_ref[$plot_i]{xlabel} = "cycle";
    $$plot_info_ref[$plot_i]{ylabel} = "Grind Times (ms/zone/cycle)";
    #$$plot_info_ref[$plot_i]{yscale} = "logscale";
    push( @{$$plot_info_ref[$plot_i]{y_fields}},
          "Grind_Times_SPS",
        );
    $$plot_info_ref[$plot_i]{y2label} = "ELAPSED_TIMES_P0_SPS_Total_Time (seconds)";
    #$$plot_info_ref[$plot_i]{y2scale} = "logscale";
    push( @{$$plot_info_ref[$plot_i]{y2_fields}},
          "ELAPSED_TIMES_P0_SPS_Total_Time" );


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

}
# final require return
1;
