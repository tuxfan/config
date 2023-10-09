# extras for processing cassio data

########################################################################
# Called from ctf_read_*
# Usage: Call when you see following line:
#   ^\s*RJ_OUTPUT:
#   Will then process next lines if match.
#   Will do backup_line when done
#   (assumes calling routine reads next line).
#
#   Will also read the corresponding rj_batch_out file when it sees:
#   /ENV (RJ_TAG)\s*=\s*(\d\S+)/
#   It will see this once per "rj_cmd_out" run.
#
#   Cycle specific data will be stored into:
#     state_ref{rj_*}
#   Calling routine can clear these values out after you have stored them.
#   Other data in the hash is stored and expected to be saved for all
#   of the file processing so that the final ctf_readfinish_rj_cmd_out
#   can be used.
#
# NOTE: final ctf values produced
#   All values will be of the form:
#     rj_<name>
#   As with other ctf values, splicing is done to only have the
#   "productive" values saved.
#   So, only data for the first "productive" cycle is saved.
#   This will correspond to a single rj_cmd_out<rj_RJ_TAG> processed.
#     rj_RJ_TAG      = full tag = <TAG_BASE>.<try number>
#   The data will be for that batch session (TAG_BASE)
#     restarts:     It will not correspond
#
#   Inclusive (incl) vs. Exclusive (excl)
#     excl: includes only values resulting in productive work
#     incl: includes productive and non-productive (recalculing cycles)
#
#   Definition of fields produced:
#   ------------------------------
#     rj_ACCT
#       Batch account used ("unknown" for interactive sessions).
#     rj_PID
#       Process id.
#     rj_RJ_TAG
#       Full tag (used in various filenames).
#       <TAG_BASE>.<TRY>
#     rj_SUBMIT_TIME_ABS
#       Batch submit time (child jobs launched when parent starts run).
#     rj_SUBMIT_TIME_orig
#       Batch submit time (original string).
#     rj_date_start_base
#       Start date of the TAG_BASE (batch session).
#     rj_date_stop_base
#       Stop date of the TAG_BASE (batch session).
#     rj_mean_secs_used_incl_sum
#     rj_mean_secs_wait_incl_sum
#       Average number of seconds used/waited per batch session so far.
#       rj_secs_used_incl_sum / rj_num_batch_incl_sum
#       rj_secs_wait_incl_sum / rj_num_batch_wait_sum
#     rj_num_batch_excl
#       Number of batch jobs contributed to productive work.
#       0 = already accounted for previously in this list
#           a retry in same TAG_BASE already seen (not counted again)
#       1 = first TAG_BASE (batch session)
#     rj_num_batch_excl_sum
#       Running sum of number of productive batch jobs.
#       Running sum of rj_num_batch_excl.
#     rj_num_batch_incl
#       Number of batch sessions (productive and not productive) since
#       last productive work.
#       0 = already accounted for previously in this list
#     rj_num_batch_incl_sum
#       Running sum of number of productive and non-productive batch jobs.
#       Running sum of rj_num_batch_incl.
#     rj_secs_used_excl
#       Batch session time used in this batch session.
#       0 = already accounted for previously in this list
#     rj_secs_used_excl_base
#       Same as rj_secs_used_excl, but has all values filled in for the base.
#     rj_secs_used_excl_sum
#       Running sum batch session time where some productive work done.
#     rj_secs_used_incl
#       All batch session time used since last productive work done.
#       0 = already accounted for previously in this list
#     rj_secs_used_incl_sum
#       Running sum batch session time including non-productive time.
#       Running sum of rj_secs_used_incl.
#     rj_secs_wait_excl
#       Time spent since last batch finished.
#       0 = already accounted for previously in this list
#     rj_secs_wait_excl_base
#       Same as rj_secs_wait_excl, but has all values filled in for the base.
#     rj_secs_wait_excl_sum
#       Running sum of time spent waiting with productive results.
#     rj_secs_wait_incl
#       Time spent waiting since last productive work done.
#       0 = already accounted for previously in this list
#     rj_secs_wait_incl_sum
#       Running sum batch session wait including non-productive time.
#
#   Fields of Interest
#   ------------------
#     rj_mean_secs_used_incl_sum
#       Average used time per all batch sessions so far.
#     rj_mean_secs_wait_incl_sum
#       Average wait time per all batch sessions so far.
#     rj_date_stop_base[last index]
#     (time_wait_latest_secs)
#       When last batch session finished (or last date of running job)
#       If job in queue and eligible:
#         secs_wait = current time - rj_date_stop_base[last index]
#     rj_secs_used_excl_base[last index]
#     (time_used_latest_secs)
#       Time this current batch session has used.
#     rj_secs_wait_excl_base[last index]
#     (time_wait_previous_secs)
#       Time this current batch session has spent waiting.
# 
#
########################################################################

sub ctf_read_rj_cmd_out{
    my %args = (
        LINES      => undef,
        VALS       => undef,
        VALS_THIS  => undef,
        STATE      => undef,
        VERBOSE    => undef,
        @_,
        );
    my( $args_valid ) = "LINES|VALS|VALS_THIS|STATE|VERBOSE";
    my(
        $arg,
        $backup_line,
        $cycle_stop,
        @cycles,
        $date,
        $date_stop,
        $done,
        $field,
        $field_use,
        $final_tag,
        %final_tag_fields,
        $key,
        @keys,
        $ierr,
        $line, 
        $lines_ref,
        $ln, 
        $machine,
        $nodes_max,
        $num_batch_excl,
        $num_batch_excl_sum,
        $num_batch_incl,
        $num_batch_incl_sum,
        $secs,
        $secs_start_previous,
        $secs_stop_previous,
        $secs_used_excl,
        $secs_used_excl_sum,
        $secs_used_incl,
        $secs_used_incl_sum,
        $secs_wait_excl,
        $secs_wait_excl_sum,
        $secs_wait_incl,
        $secs_wait_incl_sum,
        $state_ref,
        $tag,
        $tag_base,
        $tag_base_latest,
        $tag_base_previous,
        $tag_base_ref,
        %tag_base_seen,
        $tag_full,
        @tag_tries,
        $tag_try,
        $tag_try_latest,
        $tag_try_previous,
        $tag_try_ref,
        @tags,
        %time_h,
        @times,
        $try,
        $val,
        $val_stop,
        @vals,
        $vals_ref, 
        $vals_this_ref, 
        $verbose, 
        );

    $ierr = 0;

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

    $lines_ref     = $args{LINES};
    $vals_ref      = $args{VALS};
    $vals_this_ref = $args{VALS_THIS};
    $state_ref     = $args{STATE};
    $verbose       = $args{VERBOSE};

    $ln     = $$state_ref{ln};
    $line   = $$state_ref{line};

    undef( $backup_line );

    # final: fill in things given that last value of vals
    #   has correct stuff for this file
    if( defined( $$state_ref{final} ) ){
        delete($$state_ref{final});

        # by this point, have various tag things set - save stuff
        $tag_base_latest   = $$state_ref{tag_base_latest};
        $tag_base_previous = $$state_ref{tag_base_previous};
        $tag_try_latest    = $$state_ref{tag_try_latest};
        $tag_try_previous  = $$state_ref{tag_try_previous};
        
        # if you have a different state_ref{TIME_YMDHMS}, save to
        #   $tag_try_latest{TIME_YMDHMS_stop}
        # Do NOT put in TIME_YMDHMS_stop if did not find one - future check
        $date = $$state_ref{tag_base}{$tag_base_latest}{try}{$tag_try_latest}{TIME_YMDHMS_start};
        if( $$state_ref{TIME_YMDHMS} ne $date ){
            $$state_ref{tag_base}{$tag_base_latest}{try}{$tag_try_latest}{TIME_YMDHMS_stop} = $$state_ref{TIME_YMDHMS};
        }
        
        $field = "cycle";
        if( defined( $$vals_ref{$field}) ){
            $val_stop = $$vals_ref{$field}{val}[-1];
            $$state_ref{tag_base}{$tag_base_latest}{try}{$tag_try_latest}{"${field}_stop"} = 
                $val_stop;
            $$state_ref{tag_base}{$tag_base_latest}{"${field}_stop"} =
                $val_stop;
        }

        $field = "date";
        if( defined( $$vals_ref{$field}) ){
            $val_stop = $$vals_ref{$field}{val}[-1];
            $$state_ref{tag_base}{$tag_base_latest}{try}{$tag_try_latest}{"${field}_stop"} = 
                $val_stop;
            $$state_ref{tag_base}{$tag_base_latest}{"${field}_stop"} =
                $val_stop;
        }

        # fill in {tag_base}{rj_date_stop_base} as best as can
        # want this filled in since will use it to calculate various wait times
        foreach $tag_base ( sort keys %{$$state_ref{tag_base}} ){
            $tag_base_ref = $$state_ref{tag_base}{$tag_base};
            if( ! defined( $$tag_base_ref{rj_date_stop_base} ) ){
                
                # tag_tries = reverse sort tries (look at last first)
                @tag_tries = reverse sort keys %{$$tag_base_ref{try}};
                
                foreach $tag_try ( @tag_tries ) {

                    # try {$tag_try}TIME_YMDHMS_stop
                    if( defined($$tag_base_ref{try}{$tag_try}{TIME_YMDHMS_stop}) ){
                        $$tag_base_ref{rj_date_stop_base} =
                            $$tag_base_ref{try}{$tag_try}{TIME_YMDHMS_stop};
                    }

                    # try {$tag_try}date_stop = last date seen in run
                    elsif( defined($$tag_base_ref{try}{$tag_try}{date_stop}) ){
                        $$tag_base_ref{rj_date_stop_base} =
                            $$tag_base_ref{try}{$tag_try}{date_stop};
                    }

                    # punt to {$tag_try}TIME_YMDHMS_start
                    elsif( defined($$tag_base_ref{try}{$tag_try}{TIME_YMDHMS_start}) ){
                        $$tag_base_ref{rj_date_stop_base} = 
                            $$tag_base_ref{try}{$tag_try}{TIME_YMDHMS_start};
                    }

                    # exit if found
                    if( defined($$tag_base_ref{rj_date_stop_base}) ){
                        last;
                    }

                }

                # still not found, set to rj_date_start_base
                if( ! defined($$tag_base_ref{rj_date_stop_base}) ){
                    $$tag_base_ref{rj_date_stop_base} = 
                        $$tag_base_ref{rj_date_start_base};
                }

            } # if no {tag_base}{rj_date_stop_base}

        } # foreach tag_base, fill in {tag_base}{rj_date_stop_base} as best as can

        # go through all the tags stored and accumulate values into tags
        foreach $tag_base ( sort keys %{$$state_ref{tag_base}} ){

            $tag_base_ref = \%{$$state_ref{tag_base}{$tag_base}};

            foreach $tag_try ( sort keys %{$$tag_base_ref{try}} ){

                $tag_try_ref = \%{$$tag_base_ref{try}{$tag_try}};

                # try secs_start
                undef( $date );
                # try{TIME_YMDHMS_start}
                if( defined( $$tag_try_ref{TIME_YMDHMS_start} ) ){
                    $date = $$tag_try_ref{TIME_YMDHMS_start};
                }
                # punt
                else{
                    # this should never happen since should always get
                    # the "RJ_OUTPUT: TIME_YMDHMS:" line is near the top.
                    $ierr = 0;
                    &print_error( "Odd error - missing start time from",
                                  "  tag_base=$tag_base",
                                  "  tag_try=$tag_try",
                                  $ierr );
                    # set date to somethihng else?  dunno...
                }
                if( defined($date) ){
                    %time_h = &conv_time( STRING=>"YMDHMS $date" );
                    $$tag_try_ref{secs_start} = $time_h{SECS_TOTAL};
                }

                # try secs_stop
                undef( $date );
                # try{TIME_YMDHMS_stop}
                if( defined( $$tag_try_ref{TIME_YMDHMS_stop} ) ){
                    $date = $$tag_try_ref{TIME_YMDHMS_stop};
                }
                # base{TIME_YMDHMS_stop}
                elsif( defined( $$tag_try_ref{date_stop} ) ){
                    $date = $$tag_try_ref{date_stop};
                }
                # punt - no dates found...set to start
                else{
                    $date = $$tag_try_ref{TIME_YMDHMS_start};
                }
                if( defined($date) ){
                    %time_h = &conv_time( STRING=>"YMDHMS $date" );
                    $$tag_try_ref{secs_stop} = $time_h{SECS_TOTAL};
                }

            }
        }

        # now go through and fill in tag_base{ secs_start, secs_stop }

        # go through all the tags stored and accumulate values into tags
        undef( $secs_start_previous );
        undef( $secs_stop_previous );
        foreach $tag_base ( sort keys %{$$state_ref{tag_base}} ){

            $tag_base_ref = \%{$$state_ref{tag_base}{$tag_base}};

            # base secs_start
            undef( $date );
            # rj_date_start_base/rj_state_stop should be filled in
            if( defined($$tag_base_ref{rj_date_start_base}) ){
                $date = $$tag_base_ref{rj_date_start_base};
            }
            
            # if not found, then probably was from `run_job.pl -i` and
            # no rj_batch_out.
            # try to find from first try data
            if( ! defined( $date ) && defined($$tag_base_ref{try}) ){
                foreach $try ( sort keys %{$$tag_base_ref{try}} ){
                    if( defined( $$tag_base_ref{try}{$try}{TIME_YMDHMS_start} ) ){
                        $$tag_base_ref{rj_date_start_base} =
                            $$tag_base_ref{try}{$try}{TIME_YMDHMS_start};
                        $date = $$tag_base_ref{rj_date_start_base};
                        last;
                    }
                }
            }

            # if still not found, uncovered case and print warning
            # set to current date
            if( ! defined( $date ) ){
                $date = &date_ymdhms_sep();
                $ierr = 0;
                &print_error( "Odd error - missing rj_date_start_base",
                              "  tag_base=$tag_base",
                              "Contact runtools\@lanl.gov",
                              $ierr );
            }

            if( defined($date) ){
                %time_h = &conv_time( STRING=>"YMDHMS $date" );
                $$tag_base_ref{secs_start} = $time_h{SECS_TOTAL};
            }

            # base secs_stop
            undef( $date );
            # rj_date_start_base/rj_state_stop should be filled in
            if( defined($$tag_base_ref{rj_date_stop_base}) ){
                $date = $$tag_base_ref{rj_date_stop_base};
            }
            # punt
            else{
                $ierr = 0;
                &print_error( "Odd error - missing rj_date_stop_base",
                              "  tag_base=$tag_base",
                              $ierr );
            }
            if( defined($date) ){
                %time_h = &conv_time( STRING=>"YMDHMS $date" );
                $$tag_base_ref{secs_stop} = $time_h{SECS_TOTAL};
            }

            # secs_wait_excl = from previous stop
            if( defined( $secs_stop_previous ) ){
                $secs = $$tag_base_ref{secs_start} - $secs_stop_previous;
            }
            else{
                $secs = 0;
            }
            $$tag_base_ref{secs_wait_excl} = $secs;

            # store previous values
            $secs_start_previous = $$tag_base_ref{secs_start};
            $secs_stop_previous  = $$tag_base_ref{secs_stop};

            # secs_used_excl = just this run
            $secs = $$tag_base_ref{secs_stop} - $$tag_base_ref{secs_start};
            $$tag_base_ref{secs_used_excl} = $secs;

            # maybe stuff other things back into tag_try?  dunno.
            #foreach $tag_try ( sort keys %{$$tag_base_ref{try}} ){
            #    $tag_try_ref = \%{$$tag_base_ref{try}{$tag_try}};
            #}

        }
        
        # tags that we end up with in the pruned vals
        undef( @tags );
        $field = "rj_RJ_TAG";
        if( defined( $$vals_ref{$field}) ){
            @tags = @{$$vals_ref{$field}{val}};
            @cycles = @{$$vals_ref{$field}{cycle}};
            @times = @{$$vals_ref{$field}{time}};
        }
        foreach $tag ( @tags ){
            $final_tag{$tag}{processed} = "";
        }

        # loop through stat_ref tags and create final_tag data
        undef( %final_tag_fields );
        undef( %tag_base_seen );

        # init various secs vars
        $secs_used_excl_sum = 0;
        $secs_wait_excl_sum = 0;
        $secs_used_incl_sum = 0;
        $secs_wait_incl_sum = 0;
        $secs_used_incl = 0;
        $secs_wait_incl = 0;

        # init number of batch jobs
        $num_batch_excl_sum = 0;
        $num_batch_incl_sum = 0;
        $num_batch_excl = 0;
        $num_batch_incl = 0;
        
        # loop through tag_base
        foreach $tag_base ( sort keys %{$$state_ref{tag_base}} ){

            $tag_base_ref = \%{$$state_ref{tag_base}{$tag_base}};

            # vals for this tag_base
            $secs_used_excl = $$tag_base_ref{secs_used_excl};
            $secs_wait_excl = $$tag_base_ref{secs_wait_excl};

            # incl = times since last (crashes, restarts)

            # incl sum = complete sum
            $secs_used_incl_sum += $secs_used_excl;
            $secs_wait_incl_sum += $secs_wait_excl;
            $num_batch_incl_sum++;

            # incl this will be zeroed when added in
            $secs_used_incl += $secs_used_excl;
            $secs_wait_incl += $secs_wait_excl;
            $num_batch_incl++;

            # loop through found trys
            foreach $tag_try ( sort keys %{$$tag_base_ref{try}} ){

                $tag_try_ref = \%{$$tag_base_ref{try}{$tag_try}};

                if( $tag_try eq "000" ){
                    $tag_full = $tag_base;
                }
                else{
                    $tag_full = $tag_base.".".$tag_try;
                }

                # this is a final tag
                if( defined( $final_tag{$tag_full} ) ){

                    # do not double-count if this tag_base already seen
                    if( ! defined( $tag_base_seen{$tag_base} ) ){

                        $tag_base_seen{$tag_base} = "";

                        # excl - just time for this run
                        $final_tag{$tag_full}{secs_used_excl} = $secs_used_excl;
                        $final_tag{$tag_full}{secs_wait_excl} = $secs_wait_excl;
                        $final_tag{$tag_full}{num_batch_excl} = 1;
                        # excl sum - increment
                        $secs_used_excl_sum += $secs_used_excl;
                        $secs_wait_excl_sum += $secs_wait_excl;
                        $num_batch_excl_sum++;

                        # incl - inclusive since last final tag
                        $final_tag{$tag_full}{secs_used_incl} = $secs_used_incl;
                        $final_tag{$tag_full}{secs_wait_incl} = $secs_wait_incl;
                        $final_tag{$tag_full}{num_batch_incl} = $num_batch_incl;
                        # and reset incl since accounted for
                        $secs_used_incl = 0;
                        $secs_wait_incl = 0;
                        $num_batch_incl = 0;

                    }

                    # save these things
                    $final_tag{$tag_full}{date_stop_base} = $$tag_base_ref{rj_date_stop_base};
                    # useful to have the seconds used/waited for last base
                    $final_tag{$tag_full}{secs_used_excl_base} = $secs_used_excl;
                    $final_tag{$tag_full}{secs_wait_excl_base} = $secs_wait_excl;

                    # record sums for all final tags
                    $final_tag{$tag_full}{secs_used_excl_sum} = $secs_used_excl_sum;
                    $final_tag{$tag_full}{secs_used_incl_sum} = $secs_used_incl_sum;
                    $final_tag{$tag_full}{secs_wait_excl_sum} = $secs_wait_excl_sum;
                    $final_tag{$tag_full}{secs_wait_incl_sum} = $secs_wait_incl_sum;
                    $final_tag{$tag_full}{num_batch_excl_sum} = $num_batch_excl_sum;
                    $final_tag{$tag_full}{num_batch_incl_sum} = $num_batch_incl_sum;

                } # this is a final tag

            } # loop through trys

        } # loop through tag base

        # Create average wait and average used
        # I think just doing incl_sum is the only one really useful.
        # mean_secs_used_incl_sum = average seconds used per batch
        # mean_secs_wait_incl_sum = average seconds wait per batch
        foreach $tag ( keys %final_tag ){

            $final_tag{$tag}{mean_secs_used_incl_sum} =
                $final_tag{$tag}{secs_used_incl_sum} /
                $final_tag{$tag}{num_batch_incl_sum};
            $final_tag{$tag}{mean_secs_wait_incl_sum} =
                $final_tag{$tag}{secs_wait_incl_sum} /
                $final_tag{$tag}{num_batch_incl_sum};

        }

        # create list of fields
        foreach $tag ( keys %final_tag ){
            foreach $field ( keys %{$final_tag{$tag}} ){
                if( $field =~ /^(processed)$/ ){
                    next;
                }
                $final_tag_fields{$field} = "";
            }
        }

        # store final_tag data back into vals_ref
        foreach $field ( keys %final_tag_fields ){
            @vals = ();
            foreach $tag ( @tags ){
                $val = $final_tag{$tag}{$field} || 0;
                push( @vals, $val );
            }

            $field_use = "rj_$field";
            @{$$vals_ref{$field_use}{val}}   = @vals;
            @{$$vals_ref{$field_use}{cycle}} = @cycles;
            @{$$vals_ref{$field_use}{time}}  = @times;


        }

        return( $ierr );

    } # final - all data done
    
    # if just clearing data from previous cycle
    # called when have new data but:
    #   - not stored yet into vals_ref
    #   - vals_ref had not cleared out redone cycles yet
    if( defined( $$state_ref{clear} ) ){
        delete($$state_ref{clear});
        
        # get the previous tags
        $tag_base_previous = $$state_ref{tag_base_previous} || "";
        $tag_try_previous  = $$state_ref{tag_try_previous}  || "000";

        # get various things based on values from vals_ref
        if( defined( $$vals_ref{date} ) ){
            $date_stop  = $$vals_ref{date}{val}[-1];
            $cycle_stop = $$vals_ref{cycle}{val}[-1];
        }
        else{
            $date_stop  = "";
            $cycle_stop = ""
        }

        # previous, set cycle_stop and date_stop based on vals_ref
        if( $date_stop =~ /\S/ && $tag_base_previous =~ /\S/ ){

            $$state_ref{tag_base}{$tag_base_previous}{cycle_stop} = $cycle_stop;
            $$state_ref{tag_base}{$tag_base_previous}{try}{$tag_try_previous}{cycle_stop} = $cycle_stop;
            $$state_ref{tag_base}{$tag_base_previous}{date_stop} = $date_stop;
            $$state_ref{tag_base}{$tag_base_previous}{try}{$tag_try_previous}{date_stop} = $date_stop;

        } # previous
        
        # latest: various things
        if( defined( $$state_ref{tag_base_latest} ) ){
            $tag_base = $$state_ref{tag_base_latest};
            $tag_try = $$state_ref{tag_try_latest};

            # cycle_start - set for only first cycle done or if earlier cycle
            if( ! defined($$state_ref{tag_base}{$tag_base}{cycle_start}) ){
                $$state_ref{tag_base}{$tag_base}{cycle_start} =
                    $$state_ref{cycle};
            }
            elsif( $$state_ref{tag_base}{$tag_base}{cycle_start} > $$state_ref{cycle}){
                $$state_ref{tag_base}{$tag_base}{cycle_start} =
                    $$state_ref{cycle};
            }
            $$state_ref{tag_base}{$tag_base}{try}{$tag_try}{cycle_start} =
                $$state_ref{cycle};

        } # latest


        # do last: unset rj_ vars for calling routine
        @keys = keys %$state_ref;
        foreach $key ( @keys ){
            if( $key =~ /^rj_/ ){
                $$vals_this_ref{$key} = $$state_ref{$key};
                delete( $$state_ref{$key} );
            }
        }

        return( $ierr );

    } # clear - hit new block of data (probably file)

    # RJ_OUTPUT: line
    if( $line =~ /^\s*RJ_OUTPUT:/ ){

        $$state_ref{processed}  = "";
        $$state_ref{data_found} = "";

        undef( $done );
        # while:
        #   process RJ_OUTPUT lines
        #   read next line
        # backup line if needed
        while( ! defined($done) ){

            # -----------------------
            # process RJ_OUTPUT lines
            # -----------------------

            # no-op first check
            if( $line =~ /^empty beginning if block/ ){
            }

            # TIME_YMDHMS:
            # 2021.04.22: had typo in run_job.pl that had TIME_YmdHMS
            # need case insensitive
            elsif( $line =~ /TIME_YMDHMS:(\S+)/i ){
                # save the previous one
                #   - ran errorless: will be the _last of previous
                $$state_ref{TIME_YMDHMS_previous} = $$state_ref{TIME_YMDHMS};
                $$state_ref{TIME_YMDHMS}          = $1;
            }

            # PID
            elsif( $line =~ /PID: (\d+)/ ){
                $$state_ref{rj_PID} = $1;
            }

            # machine
            elsif( $line =~ /ENV (RJ_L_MACHINE) = (\S+)/ ){
                $machine = $2;
                $$state_ref{"rj_$1"} = $machine;
                $nodes_max = &ctf_nodes_max( $machine );
                $$state_ref{rj_nodes_max} = $nodes_max;
            }

            # TAG (and will use to look at rj_batch_out)
            # Seen once per "rj_cmd_out" run...so do other processing here.
            elsif( $line =~ /ENV (RJ_TAG)\s*=\s*(\d\S+)/ ){
                $field = "rj_$1";
                $$state_ref{$field} = $2;

                # store the file into list
                push( @{$$state_ref{filenames}}, $$state_ref{filename} );

                # and now process the rj_batch_file associated with this
                # rj_cmd_out file
                &ctf_process_extras_rj_batch_out( STATE=>$state_ref );

                # by this point, have various tag things set - save stuff
                $tag_base_latest   = $$state_ref{tag_base_latest};
                $tag_base_previous = $$state_ref{tag_base_previous};
                $tag_try_latest    = $$state_ref{tag_try_latest};
                $tag_try_previous  = $$state_ref{tag_try_previous};

                # store some things into tag_base.tag_try
                if( defined( $$state_ref{rj_PID} ) ){
                    $$state_ref{tag_base}{$tag_base_latest}{try}{$tag_try_latest}{rj_PID} = 
                        $$state_ref{rj_PID};
                }                

                # latest: will always be correct
                $$state_ref{tag_base}{$tag_base_latest}{try}{$tag_try_latest}{TIME_YMDHMS_start} = 
                    $$state_ref{TIME_YMDHMS};
                
                # previous: fill in tag_try_previous{TIME_YMDHMS_stop} with
                # the previously seen TIME_YMDHMS_stop if it is different.
                if( $tag_base_previous =~ /\S/ ){
                    $date = $$state_ref{tag_base}{$tag_base_previous}{try}{$tag_try_previous}{TIME_YMDHMS_start};
                    # Do NOT put in TIME_YMDHMS_stop if did not find one - future check
                    if( $date ne $$state_ref{TIME_YMDHMS_previous} ){
                        $$state_ref{tag_base}{$tag_base_previous}{try}{$tag_try_previous}{TIME_YMDHMS_stop} = 
                            $$state_ref{TIME_YMDHMS_previous};
                    }
                }

            }
            
            # TAG (and will use to look at rj_batch_out)
            elsif( $line =~ /ENV (RJ_batchid)\s*=\s*(\d\S+)/ ){
                $$state_ref{$1} = $2;
            }

            # --------------
            # read next line
            # --------------
            if( ref($lines_ref) eq "ARRAY" ){
                $line = $$lines_ref[$ln]; $ln++;
            }
            else{
                $line = <$lines_ref>; $ln = length($line);
            }

            # done no line read
            if( ! defined($line) ){
                # nothing to read...do not backup line
                last;
            }

            # done: if not RJ_OUTPUT
            if( $line !~ /^\s*RJ_OUTPUT:/ ){
                # will need to re-read this line, so backup.
                $backup_line = "";
                last;
            }

        } # while not done

        # backup line if needed - assume that will read next line
        # (so that then next "read" will process this line)
        if( defined( $backup_line ) ){
            # back up one line
            if( ref($lines_ref) eq "ARRAY" ){
                $ln--;
            }
            else{
                seek($lines_ref, -$ln, 1);
            }
        }
        
    } # RJ_OUTPUT: line

    # stuff state if processed
    if( defined($$state_ref{processed}) ){
        # since already backing up line:
        #   $ln   is valid and will be used
        #   $line is not valid - but will be reset by caller
        $$state_ref{ln}   = $ln;
        $$state_ref{line} = $line;
    }

    return( $ierr );
}

# processing a rj_batch_out file to get various bits
# currently expected to be called from within processing rj_cmd_out file.
sub ctf_process_extras_rj_batch_out{
    my %args = (
        STATE      => undef,
        @_,
        );
    my( $args_valid ) = "STATE";
    my(
        $arg,
        $date,
        $dir,
        $fh_FILE,
        $field,
        $filename_rj_batch_out,
        %first,
        $line,
        @lines,
        $ierr,
        $state_ref,
        $tag_base,
        $tag_try,
        %time_h,
        $val,
        );

    $ierr = 0;

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

    $ierr = 0;

    $state_ref     = $args{STATE};

    # get rid of "try" number
    if( $$state_ref{rj_RJ_TAG} =~ /^(\S+?)(\.(\S+))?$/ ){
        $tag_base = $1;
        $tag_try  = $3 || "000";
    }
    else{
        # something odd about name of tag...return with error
        return( $ierr );
    }
    # some things might have been cleared out by caller...reprocess file.

    $dir = &my_dir($$state_ref{filename});

    # set previous/current regardless
    # previous ones
    $$state_ref{tag_previous}      = $$state_ref{tag_latest}      || "";
    $$state_ref{tag_base_previous} = $$state_ref{tag_base_latest} || "";
    $$state_ref{tag_try_previous}  = $$state_ref{tag_try_latest}  || "000";
    
    # current one
    $$state_ref{tag_latest}      = $$state_ref{rj_RJ_TAG};
    $$state_ref{tag_base_latest} = $tag_base;
    $$state_ref{tag_try_latest}  = $tag_try;

    # get filename of rj_batch_out
    undef( $filename_rj_batch_out );

    # try current dir (if given rj_adir/rj_cmd_out...
    if( ! defined( $filename_rj_batch_out ) ){
        $filename_rj_batch_out = "$dir/rj_batch_out.$tag_base";
        if( ! -r $filename_rj_batch_out ){
            undef( $filename_rj_batch_out );
        }
    }

    # try rj_adir/<file> (if given rj_cmd_out only)
    if( ! defined( $filename_rj_batch_out ) ){
        $filename_rj_batch_out = "$dir/rj_adir/rj_batch_out.$tag_base";
        if( ! -r $filename_rj_batch_out ){
            undef( $filename_rj_batch_out );
        }
    }

    # return if not found
    # this can happen if `run_job.pl -i`
    if( ! defined( $filename_rj_batch_out) ){
        # no error, just not read
        return( $ierr );
    }

    # open file
    if( ! open( $fh_FILE, $filename_rj_batch_out ) ){
        # no error, just not read
        return( $ierr );
    }
    @lines = <$fh_FILE>;
    close( $fh_FILE );

    # go through lines in the rj_batch_out file
    undef( %first );
    foreach $line ( @lines ){

        # no-op first check
        if( $line =~ /^empty beginning if block/ ){
        }

        elsif( $line =~ /^\s*(JOBID)\s*=\s*(\S+)/ ){
            $field = "rj_$1";
            $$state_ref{$field} = $2;
        }

        elsif( $line =~ /^\s*(ACCT)\s*=\s*(\S+)/ ){
            $field = "rj_$1";
            $$state_ref{$field} = $2;
        }

        # TIME_YMDHMS: == date
        elsif( $line =~ /^\s*(TIME_YMDHMS):(\S+)/ ){
            # can be starting or stopping time
            $date = $2;
            if( ! defined($first{"date"}) ){
                $first{"date"} = "";
                $$state_ref{tag_base}{$tag_base}{TIME_YMDHMS_start} = $date;
                $field = "rj_date_start_base";
                $$state_ref{$field} = $date;
            }
            else{
                $$state_ref{tag_base}{$tag_base}{TIME_YMDHMS_stop} = $date;
                $field = "rj_date_stop_base";
                $$state_ref{$field} = $date;
            }
        }

        # slurm crash message
        elsif( $line =~ /slurmstepd:.*CANCELLED AT (\S+)/ ){
            $date = $1;
            %time_h = &conv_time( STRING=>$date );
            $date = $time_h{date_dot};
            $$state_ref{tag_base}{$tag_base}{TIME_YMDHMS_stop} = $date;
            $$state_ref{rj_date_stop_base} = $date;
        }

        # SUBMIT_TIME_ABS
        elsif( $line =~ /^\s*(SUBMIT_TIME_ABS)\s*=\s*(\S+)/ ){
            # if defined, this will be in a YMDHMS type field (w/out YMDHMS)
            $field = "rj_$1";
            $date = $2;
            $$state_ref{$field} = $date;
        }

        # SUBMIT_TIME_orig
        elsif( $line =~ /^\s*(SUBMIT_TIME_orig)\s*=\s*(\S+.*?)\s*$/ ){
            # this is the raw value returned by the batch system.
            $field = "rj_$1";
            $date = $2;
            $$state_ref{$field} = $date;
        }

    } # process each line in the rj_batch_out file

    # fill in some fields if not there

    $field = "rj_SUBMIT_TIME_orig";
    if( ! defined( $$state_ref{$field} ) ){
        # use "-" so know undefined (tested elsewhere)
        $$state_ref{$field} = "-";
    }

    # fill in some fields if not there
    # 2021.11.01 This field is now in rj_batch_out...
    #   but not in older ones.
    $field = "rj_SUBMIT_TIME_ABS";
    if( ! defined( $$state_ref{$field} ) ){
        # this is defined above
        if( $$state_ref{"rj_SUBMIT_TIME_orig"} ne "-" ){
            $val = $$state_ref{"rj_SUBMIT_TIME_orig"};
            # conv_time should be able to convert w/out changing val
            %time_h = &conv_time( STRING=>$val );
            $$state_ref{$field} = $time_h{date_dot};
        }
        else{
            # use "-" so know undefined (tested elsewhere)
            $$state_ref{$field} = "-";
        }
    }

    # fill in some fields if not there
    $field = "rj_ACCT";
    if( ! defined( $$state_ref{$field} ) ){
        # likely done in an interactive session
        $$state_ref{$field} = "unknown";
    }

    # save fields to permanent area
    $field = "rj_date_start_base";
    if( defined($$state_ref{$field}) ){
        $$state_ref{tag_base}{$tag_base}{$field} = $$state_ref{$field};
    }
    $field = "rj_date_stop_base";
    if( defined($$state_ref{$field}) ){
        $$state_ref{tag_base}{$tag_base}{$field} = $$state_ref{$field};
    }
    
    
}

########################################################################
# Called from ctf_readfinish_eap_output
# done after all other "finish" has been done.
sub ctf_readfinish_rj_cmd_out{

    my %args = (
        VALS       => undef,
        VERBOSE    => undef,
        @_,
        );
    my( $args_valid ) = "VALS|VERBOSE";
    my(
        $arg,
        $ierr,
        $vals_ref,
        );

    $ierr = 0;

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

    $vals_ref = $args{VALS};
    
    return( $ierr );

}

sub numerically { $a <=> $b; }

########################################################################
# Called from ctf_plot_*
sub ctf_plot_rj_cmd_out{
    my %args = (
        PLOT_INFO  => undef,
        FILE_INFO  => undef,
        STATE      => undef,
        VERBOSE    => undef,
        @_,
        );
    my( $args_valid ) = "PLOT_INFO|FILE_INFO||STATE|VERBOSE";
    my(
        $arg,
        $field, 
        @fields, 
        @fields_all, 
        @fields_count, 
        @fields_energy, 
        %fields_hash, 
        $file_info_ref, 
        $ierr, 
        $plot_i, 
        $plot_info_ref, 
        $state_ref,
        $title, 
       );

    $ierr = 0;

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

    $plot_info_ref = $args{PLOT_INFO};
    $file_info_ref = $args{FILE_INFO};
    $plot_i = $#{$plot_info_ref};

    @fields_all = sort keys %{$$file_info_ref{field}};

    # IMC_Diagnostics
    @fields = grep( /^IMC_Diagnostics:/, @fields_all );
    # process all fields
    if( @fields ){

        # fields_hash{<plot title>} = array of fields
        undef( %fields_hash );
        foreach $field ( @fields ){
            if( $field =~ /^((IMC_Diagnostics:Table):(\S+)):\S+$/ ){
                push( @{$fields_hash{$1}}, $field );
            }
            if( $field =~ /^(IMC_Diagnostics:Total):(\S+)$/ ){
                push( @{$fields_hash{$1}}, $field );
            }
            if( $field =~ /^(IMC_Diagnostics:(TotalCells|TotalMem)):(\S+)$/ ){
                push( @{$fields_hash{$1}}, $field );
            }
        }

        # foreach title
        foreach $title ( sort keys %fields_hash ){

            $plot_i++;

            @fields_count  = grep( ! /energy/i, @{$fields_hash{$title}} );
            @fields_energy = grep(   /energy/i, @{$fields_hash{$title}} );

            $$plot_info_ref[$plot_i]{title}   = "$title";
            $$plot_info_ref[$plot_i]{xlabel}  = "cycle";

            if( @fields_count ){
                $$plot_info_ref[$plot_i]{ylabel}  = "count";
                $$plot_info_ref[$plot_i]{yscale}  = "logscale";
                push( @{$$plot_info_ref[$plot_i]{y_fields}}, @fields_count );
            }

            if( @fields_energy ){
                $$plot_info_ref[$plot_i]{y2label} = "energy";
                $$plot_info_ref[$plot_i]{y2scale} = "logscale";
                push( @{$$plot_info_ref[$plot_i]{y2_fields}}, @fields_energy );
            }

        } # foreach title

    } # IMC Diagnostics

    # store back into state
    $$state_ref{plot_i} = $plot_i;

    return( $ierr );

}

# final require return
1;
