########################################################################
# Type=eap_tally
#   file fed into ctf_process.pm
#
# NOTE:
#   See cts_process.pm: "Internal Interface"
#
# File Format:
# ------------
#   eap -tally
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
# Required routine: ctf_read_eap_tally
sub ctf_read_eap_tally{
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
        $fh_FILE,
        $field,
        $field_name,
        @fields,
        $file,
        $filename,
        $file_num,
        $file_num_max,
        $file_top,
        $files_ref,
        $force,
        $group,
        $i,
        $ierr,
        $line,
        $line_new,
        $lines_not_processed,
        $lines_ref,
        $lines_total,
        $ln,
        $ln_max,
        $new_run,
        $num_files_try_max,
        $time,
        %vals,
        @vals_arr,
        %vals_hash,
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

        # one type
        #   Version 1
        #   time/cycle/...
        if( $file_top =~ /^Version\s*\d+\n/ &&
            $file_top =~ /^Time,.*Cycle,.*/m ){
            $ierr = 0;
            last;
        }

        # another type
        #   blank
        #   time/cycle/...
        if( $file_top =~ /^\s*\n/ &&
            $file_top =~ /^\s*Time\s*,.*Cycle\s*,.*/m ){
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
        print "$args{VERBOSE}ctf_process_type_eap_tally\n";
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
            $filename = $file;
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
        undef( %vals );
        $ln = 0;

        undef($done);
        # reset that data was found
        undef( $data_found );
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

            # blank
            if( $line !~ /\S/ ){
                next;
            }

            # new run
            if( $line =~ /^\s*Version\s+\d+\s*$/ ){
                $new_run = "";
            }

            # time/cycle
            elsif( $line =~ /^\s*Time,\s*([^,]+)\s*,.*Cycle,\s*([^,]+)/ ){

                $time  = $1;
                $cycle = $2;

                # if a new run, sploice out the old values
                if( defined( $new_run ) ){
                    &ctf_vals_splice( VALS=>$vals_ref, CYCLE=>$cycle );
                    undef( $new_run );
                }

                # store previous values if any
                if( %vals ){
                    &ctf_vals_add( VALS=>$vals_ref, VALS_CYCLE=>\%vals );
                }
                undef( %vals );

                # prep for new vals
                $vals{time}  = $time;
                $vals{cycle} = $cycle;
                
            } # time/cycle

            # field names
            elsif( $line =~ /^\s*(Groups|Total|Energy_grp|Summary)\s*,/ ){
                ( $line_new = $line ) =~ s/^\s+//;
                $line_new =~ s/\s+$//;
                @fields = split( /\s*,\s*/, $line_new );
                # remove units
                grep( s/\(.*\)//, @fields );
                # whitespace
                grep( s/\s+/_/g, @fields );
                # consistent group name
                grep( s/^group#$/#/gi, @fields );
            }

            # data
            elsif( $line =~ /^(Group|Sum|Group\s*\d+)\s*,/ ){
                ( $line_new = $line ) =~ s/^\s+//;
                $line_new =~ s/\s+$//;
                @vals_arr = split( /\s*,\s*/, $line_new );
                undef( %vals_hash );
                # have some files with more vals than fields?!?
                for( $i = 0; $i <= $#fields; $i++ ){
                    $vals_hash{$fields[$i]} = $vals_arr[$i];
                }
                
                # Groups
                if( $fields[0] =~ /^(Groups)$/ ){
                    $group = sprintf( "g_%03d", $vals_hash{"#"} );
                    foreach $field ( @fields ){
                        if( $field =~ /^(Groups|#|)$/ ){
                            next;
                        }
                        $field_name = "${group}_${field}";
                        $vals{$field_name} = $vals_hash{$field};
                    }
                }

                # Energy_grp
                if( $fields[0] =~ /^(Energy_grp)$/ ){
                    $group = $vals_hash{$fields[0]};
                    $group =~ s/^Group\s*//;
                    $group = sprintf( "g_%03d", $group );
                    foreach $field ( @fields ){
                        if( $field =~ /^(Energy_grp|)$/ ){
                            next;
                        }
                        $field_name = "${group}_${field}";
                        $vals{$field_name} = $vals_hash{$field};
                    }
                }

                # Total/Summary
                elsif( $fields[0] =~ /^(Total|Summary)$/ ){
                    $field = $fields[0];
                    $group = "$vals_hash{$field}";
                    foreach $field ( @fields ){
                        if( $field =~ /^(Total|Summary|)$/ ){
                            next;
                        }
                        $field_name = "${group}_${field}";
                        $vals{$field_name} = $vals_hash{$field};
                    }                    
                }
            }

        } # process each line

        # close if opened
        if( ref($lines_ref) ne "ARRAY" ){
            close( $lines_ref );
        }

        # store previous values if any
        if( %vals ){
            &ctf_vals_add( VALS=>$vals_ref, VALS_CYCLE=>\%vals );
        }
        undef( %vals );
        
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

    # return
    return( $ierr );
    
}

########################################################################
# Required routine: ctf_plot_eap_tally
sub ctf_plot_eap_tally{
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
        $field_group,
        %fields,
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

    # block fields into groups
    # currently blocked by tally type
    # will only try to plot if something like 10 or fewer particles
    foreach $field ( @fields_all ){

        # field_group
        $field_group = "";

        # skip time
        if( $field eq "time" ){
            next;
        }

        # Totals in plots by themselves
        elsif( $field =~ /^Sum_/ ){
            $field_group = $field;
        }

        # groups by column
        elsif( $field =~ /^g_\d+_(\S+)$/ ){
            $field_group = $1;
        }

        # cycle/time
        elsif( $field =~ /^(cycle)$/ ){
            $field_group = $field;
        }

        push( @{$fields{$field_group}}, $field );

    }

    # plot
    foreach $field_group ( sort keys %fields ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "$field_group";
        $$plot_info_ref[$plot_i]{xlabel} = "time";
        $$plot_info_ref[$plot_i]{ylabel} = "$field_group";
        $$plot_info_ref[$plot_i]{yscale} = "logscale";
        push( @{$$plot_info_ref[$plot_i]{y_fields}}, @{$fields{$field_group}} );
    }
}

# final require return
1;
