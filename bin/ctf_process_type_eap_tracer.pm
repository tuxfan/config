########################################################################
# Type=eap_tracer
#   file fed into ctf_process.pm
#
# NOTE:
#   See cts_process.pm: "Internal Interface"
#
# File Format:
# ------------
#   eap -tracer
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
# Required routine: ctf_read_eap_tracer
sub ctf_read_eap_tracer{
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
        $done,
        $extras_called,
        $fh_FILE,
        $field,
        @fields,
        $fields_max,
        $file,
        $file_num,
        $file_num_max,
        $file_top,
        $files_ref,
        $force,
        $ierr,
        $j,
        $line,
        @lines,
        $lines_not_processed,
        $lines_ref,
        $lines_total,
        $ln,
        $ln_max,
        $num_files_try_max,
        $particle,
        $particle_this,
        %seen,
        $start_file_done,
        %state,
        $time,
        $time_first,
        $time_last,
        $time_this,
        $val,
        %vals,
        @vals_array,
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

        # tracer file looks like:
        #   particle,time,<comma separated fields list>
        # If see this, then stop
        if( $file_top =~ /^particle,time,\S+/ ){
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
        print "$args{VERBOSE}ctf_process_type_eap_tracer\n";
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

            # done
            if( $ln > $ln_max ){
                last;
            }

            # read line
            $line = $$lines_ref[$ln]; $ln++;

            # current block line
            #print "block: $ln $line";

            # blank
            if( $line !~ /\S/ ){
                next;
            }

            # new particle,time
            if( $line =~ /^\s*particle\s*,\s*time\s*,\s*\S+/ ){
                $line =~ s/\s*$//;
                @fields = split(/\s*,\s*/, $line);
                $fields_max = $#fields;
                undef( $time_first );
                undef( $time_last );
            }

            # data
            elsif( $line =~ /^\s*(\d+)\s*,\s*([^,\s]+)/ ){

                # this particle (must be a new particle)
                $particle_this = $1;
                $time_this     = $2;
                # will use this as sanity check for other times
                if( ! defined($time_first) ){
                    $time_first = $time_this;
                }

                # reset vals
                undef( %vals );

                # will read all of this particle's data and process
                # it as a block
                undef( $done );
                while( ! defined($done) ){

                    # done if does not match data
                    if( $line =~ /^\s*(\d+)\s*,\s*([^,\s]+)/ ){
                        $particle = $1;
                        $time     = $2;
                    }
                    # non-data line
                    else{
                        # back up a line
                        $ln--;
                        last;
                    }

                    # next particle
                    if( $particle != $particle_this ){
                        # back up a line
                        $ln--;
                        last;
                    }

                    $line =~ s/\s*$//;
                    @vals_array = split(/\s*,\s*/, $line);

                    # push onto vals
                    push( @{$vals{time}}, $time );
                    # values might be listed multiple times in columns.
                    # Just pick the first one
                    undef( %seen );
                    for( $j = 2; $j <= $fields_max; $j++ ){
                        if( defined($seen{$fields[$j]}) ){
                            next;
                        }
                        $seen{$fields[$j]} = "";
                        $val = $vals_array[$j];
                        # special value that is actually a skip value
                        # need to stuff it in since doing ctf_vals_add_segment()
                        if( $val <= -1e98 ){
                            undef( $val );
                        }
                        $field = "p_${particle}_$fields[$j]";
                        push( @{$vals{$field}}, $val );
                    }

                    # done
                    if( $ln > $ln_max ){
                        last;
                    }
                    
                    # split values
                    $line = $$lines_ref[$ln]; $ln++;

                } # read in all of this particle's data and process
                
                &ctf_vals_add_segment( VALS=>$vals_ref, VALS_SEGMENT=>\%vals );

            } # data

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

    # return
    return( $ierr );
    
}

########################################################################
# Required routine: ctf_plot_eap_tracer
sub ctf_plot_eap_tracer{
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
    # currently blocked by tracer type
    # will only try to plot if something like 10 or fewer particles
    foreach $field ( @fields_all ){

        # skip time
        if( $field eq "time" ){
            next;
        }

        # field_group
        $field_group = "";

        # seems to have bogus data
        if( $field =~ /mut_mg$/ ){
            next;
        }
        # special group data
        elsif( $field =~ /(mut_mg)/ ){
            $field_group .= $1;
        }
        # particle data
        elsif( $field =~ /^(p_\d+)_(\S+)/ ){
            $field_group .= $2;
        }
        # cycle, time
        else{
            $field_group .= "$field";
        }

        push( @{$fields{$field_group}}, $field );

    }

    # plot
    foreach $field_group ( sort keys %fields ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "$field_group";
        $$plot_info_ref[$plot_i]{xlabel} = "time";
        $$plot_info_ref[$plot_i]{ylabel} = "$field_group";
        push( @{$$plot_info_ref[$plot_i]{y_fields}}, @{$fields{$field_group}} );
    }
}

# final require return
1;
