########################################################################
# Type=table_csv
#   file fed into ctf_process.pm
#
# NOTE:
#   See cts_process.pm: "Internal Interface"
#
# File Format:
# ------------
#   table_csv
#     <general descrpiption line>
#     cycle, time(<units>), <var1>, <var2>, ...
#     <val>, <val>,         <val>,  <val>,  ...
#
########################################################################

# 2020.09.12: uses newer functionality.  Due to PATH that might include
#   this module but older ctf_process_util.pm, just use whole module
#   and assume that never process this filetype.
use ctf_process_util();

########################################################################
# Required routine: ctf_read_table_csv
sub ctf_read_table_csv{
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
        $cycle_first,
        $done,
        $extras_called,
        $fh_FILE,
        $field,
        @fields,
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
        $num_files_try_max,
        $start_file_done,
        %state,
        $units,
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

        # -table_csv file starts like this
        if( $file_top =~ /^\s*
                          \S.*\n\s*               # header line and next line and whitespace
                          cycle\s*,\s*            # cycle
                          time\s*\(\S+\)\s*,\s* # time (<units>)
                          (\S+\s*,\s*)*           # intermediate fields
                          (\S+)\s*\n              # last field
                         /x ){
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
        print "$args{VERBOSE}ctf_process_type_table_csv\n";
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

            # new header
            if( $line =~ /^\s*
                          cycle\s*,\s*            # cycle
                          time\s*\((\S+)\)\s*,\s*   # time (<units>)
                          (\S+\s*,\s*)*           # intermediate fields
                          (\S+)\s*\n              # last field
                         /x ){

                # units
                $units = $1;
                $line =~ s/\(.*?\)//g;
                # pre/post whitespace
                $line =~ s/^\s*//;
                $line =~ s/\s*$//;
                # separator
                $line =~ s/\s*,\s*/ /g;

                # cycle and time already correctly named fields
                @fields = split(/\s+/, $line);
            }

            # values (first is cycle, )
            elsif( $line =~ /^\s*\d+\s*,/ ){
                # pre/post whitespace
                $line =~ s/^\s*//;
                $line =~ s/\s*$//;
                # separator
                $line =~ s/\s*,\s*/ /g;
                @vals_a = split(/\s+/, $line);
                $i = 0;
                foreach $field ( @fields ){
                    if( $field =~ /^(cycle|time)$/ ){
                        $name = $field;
                    }
                    else{
                        $name = "$label:$field";
                    }
                    push( @{$vals{$name}}, $vals_a[$i] );
                    $i++;
                }
            }

            # top level label
            elsif( $line =~ /^\s*\S/ ){
                if( %vals ){
                    &ctf_process_util::ctf_vals_add_block( VALS=>$vals_ref, VALS_BLOCK=>\%vals );
                    undef( %vals );
                }

                $label = $line;
                # pre/post whitespace
                $label =~ s/^\s*//;
                $label =~ s/\s*$//;
                # underscore between
                $label =~ s/\s+/_/g;
            }


        } # process each line

        # add values from previous set if any
        if( %vals ){
            &ctf_process_util::ctf_vals_add_block( VALS=>$vals_ref, VALS_BLOCK=>\%vals, SKIP_UNION=>"yes" );
            undef( %vals );
        }

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

    # get consistent set of VALS{cycle,time}
    &ctf_process_util::ctf_vals_union_cycle_time( VALS=>$vals_ref );

    # do a check now
    &ctf_process_util::ctf_vals_check( VALS=>$vals_ref );

    # ctf_fill_time to get times on each field
    &ctf_process_util::ctf_fill_time( VALS=>$vals_ref );

    # return
    return( $ierr );
    
}

########################################################################
# Required routine: ctf_plot_table_csv
sub ctf_plot_table_csv{
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

    # single plots
    undef( %fields );
    foreach $field ( @fields_all ){
        if( $field !~ /^(cycle)$/ ){
            next;
        }
        $field_group = $field;
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

    # field_group from <blah>:<field_group>
    undef( %fields );
    foreach $field ( @fields_all ){
        if( $field =~ /:([^:]+)$/ ){
            $field_group = $1;
            push( @{$fields{$field_group}}, $field );
        }
    }

    # each field_group, plot left/right if 2
    foreach $field_group ( sort keys %fields ){
        # if 2, do left/right
        if( $#{$fields{$field_group}} == 1 ){
            $plot_i++;
            $$plot_info_ref[$plot_i]{title}  = "$field_group";
            $$plot_info_ref[$plot_i]{xlabel} = "time";
            $$plot_info_ref[$plot_i]{ylabel} = "$fields{$field_group}[0]";
            push( @{$$plot_info_ref[$plot_i]{y_fields}}, $fields{$field_group}[0] );
            $$plot_info_ref[$plot_i]{y2label} = "$fields{$field_group}[1]";
            push( @{$$plot_info_ref[$plot_i]{y2_fields}}, $fields{$field_group}[1] );
        }
        
        # if not 2, just plot separately
        else{
            foreach $field ( @{$fields{$field_group}} ){
                $plot_i++;
                $$plot_info_ref[$plot_i]{title}  = "$field";
                $$plot_info_ref[$plot_i]{xlabel} = "time";
                $$plot_info_ref[$plot_i]{ylabel} = "$field";
                push( @{$$plot_info_ref[$plot_i]{y_fields}}, $field );
            }
        }

    } # each field_group, plot left/right if 2
    
} # ctf_plot_table_csv

# final require return
1;
