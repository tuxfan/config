########################################################################
# Type=table_block_ct
#   file fed into ctf_process.pm
#
# NOTE:
#   See cts_process.pm: "Internal Interface"
#
# File Format:
# ------------
#   table_block_ct
#     Blocks of data for particular cycle+time
#     Type:
#       <column names> t=<time> cycle=<cycle>
#       <var name 1>  <val col 1> <val col 2> <...>
#       <var name 2>  <val col 1> <val col 2> <...>
#
#       <column names> t=<time> cycle=<cycle>
#       <var name 1>  <val col 1> <val col 2> <...>
#       <var name 2>  <val col 1> <val col 2> <...>
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
# Required routine: ctf_read_table_block_ct
sub ctf_read_table_block_ct{
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
        $cycle_clear,
        $cycle_first,
        $done,
        $extras_called,
        $fh_FILE,
        @fields,
        $fields_line,
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
        @lines,
        $lines_not_processed,
        $lines_ref,
        $lines_total,
        $ln,
        $ln_max,
        $name,
        $num,
        $num_files_try_max,
        $start_file_done,
        %state,
        $time,
        $type,
        %vals,
        @vals_a,
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

        # -table_block_ct file starts like this
        # Currently particular format...but can expand to others
        #   ERRORS IN ADVECTION (<types of error>) at t=<time> cycle=<cycle>
        if( $file_top =~ /^\s+ERRORS IN ADVECTION/m ||
            ( defined($file) &&
              $file =~ /\-advect_test$/ ) ){
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
        print "$args{VERBOSE}ctf_process_type_table_block_ct\n";
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
        undef( $cycle_first );
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

            # separator
            if( $line =~ /^\s*\-+\s*$/ ){
                next;
            }

            # new header: ERRORS IN ADVECTION
            if( $line =~ /^\s*
                           (ERRORS\s+IN\s+ADVECTION)\s+ # 1: type of table_block_ct
                           \(([^\)]+)\)\s+              # 2: (comma separated types of errors)
                           at\s+
                           t\s*=\s*(\S+)\s+             # 3: time
                           cycle\s*=\s*(\S+)\s+         # 4: cycle
                           /x ){

                # values
                $type        = $1;
                $fields_line = $2;
                $time        = $3;
                $cycle       = $4;

                # will splice and read in a new block of lines
                $cycle_first = $1;
                undef( %vals );

                $fields_line =~ s/\s+//g;
                @fields = split(/,/, $fields_line);
                next;
            }

            # data: ERRORS IN ADVECTION
            if( defined($cycle_first) && $cycle_first =~ /ERRORS\s+IN\s+ADVECTION/ &&
                $line =~ /\S/ ){

                $vals{time}  = $time;
                $vals{cycle} = $cycle;

                # read in block
                while( ! defined($done) ){
                    $line =~ s/^\s*//;
                    $line =~ s/\s*$//;
                    @vals_a = split( /\s+/, $line);
                    $label = shift( @vals_a );
                    $num = $#vals_a;
                    for( $i = 0; $i <= $num; $i++ ){
                        $name = "${label}_$fields[$i]";
                        $vals{$name} = $vals_a[$i];
                    }

                    # next line
                    $line = $$lines_ref[$ln]; $ln++;

                    # done with this block
                    if( ! defined( $line ) ||
                        $line !~ /\S/ ||
                        $line =~ /^\s*-+\s*$/ ){
                        last;
                    }

                }

                # As is, always splice since do not know what is the real "start"
                # of a file or catted together...Might rethink this if too slow.
                if( defined($cycle_first) ){
                    undef( $cycle_first );
                    $cycle_clear = $vals{cycle};
                    &ctf_vals_splice( VALS=>$vals_ref, CYCLE=>$cycle_clear );
                }

                # add values
                &ctf_vals_add( VALS=>$vals_ref, VALS_CYCLE=>\%vals );

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
# Required routine: ctf_plot_table_block_ct
sub ctf_plot_table_block_ct{
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
        @fields,
        @fields_all,
        $file_info_ref,
        $ierr,
        $plot_i,
        $plot_info_ref,
        $type,
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

    # default type
    $type = "";

    # block fields into groups
    #   ERRORS IN ADVECTION: different error types per var
    foreach $field ( @fields_all ){

        # skip time (time vs. time not too interesting)
        if( $field eq "time" ){
            next;
        }

        # could skip cycle...but kinda useful to see dt

        # define field_group = grouping name

        # <-LIKE name>_(<error type>)
        if( $field =~ /^(\S+-LIKE_\S+)_([^_]+)/ ){
            $field_group = $1;
            $type = "ERRORS IN ADVECTION";
        }

        # otherwise, it its own group
        else{
            $field_group = $field;
        }

        # fill have each field be on its own page (could change)
        push( @{$fields{$field_group}}, $field );

    }

    # plot
    foreach $field_group ( sort keys %fields ){
        $plot_i++;
        $$plot_info_ref[$plot_i]{title}  = "$field_group";
        $$plot_info_ref[$plot_i]{xlabel} = "time";
        $$plot_info_ref[$plot_i]{ylabel} = "$field_group";
        # set logscale to make sure visible (could be orders of magnitude differences)
        # If all values 0, will skip
        if( $type =~ /ERRORS IN ADVECTION/ ){
            $$plot_info_ref[$plot_i]{yscale} = "logscale";
        }
        push( @{$$plot_info_ref[$plot_i]{y_fields}}, @{$fields{$field_group}} );
    }
}

# final require return
1;
