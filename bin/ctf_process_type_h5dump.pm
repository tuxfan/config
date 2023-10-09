########################################################################
# Type=h5dump
#   file fed into ctf_process.pm
#
# NOTE:
#   See cts_process.pm: "Internal Interface"
#
# File Format:
# ------------
#  NOTE: I only do a crude parsing of this file.  Basically:
#  Look for: ds = variable name
#    DATASET "{ds}"
#  Look for: vals = values
#    DATA { ... vals ... }
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
# Required routine: ctf_read_h5dump
sub ctf_read_h5dump{
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
        $done,
        $extras_called,
        $fh_FILE,
        $file,
        $file_num,
        $file_num_max,
        $file_top,
        $files_ref,
        $force,
        @groups,
        @groups_spacing,
        $groups_string,
        $ierr,
        $line,
        @lines,
        $lines_not_processed,
        $lines_ref,
        $lines_total,
        $ln,
        $ln_max,
        $num_files_try_max,
        $spacing,
        %vals,
        $vals_ref,
        $var,
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

        # h5dump file starts like this
        if( $file_top =~ /^HDF5 ".*" \{/ ){
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
        print "$args{VERBOSE}ctf_process_type_h5dump\n";
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
        $var = "unset_var";
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

            # GROUP: start
            if( $line =~ /^(\s*)GROUP "(\S+)" \{/ ){
                $spacing = $1 || "";
                push( @groups_spacing, $spacing );
                push( @groups, $2 );
                next;
            }
            # GROUP: end
            if( $line =~ /^(\s*)\}/ ){
                $spacing = $1 || "";
                if( @groups ){
                    # will have same indentation as original group
                    if( $groups_spacing[-1] eq $spacing ){
                        pop( @groups );
                        pop( @groups_spacing );
                    }
                }
                next;
            }
            
            
            # new DATASET
            # assuming this is on a line by itself and no DATA after it
            if( $line =~ /^\s*DATASET "(.*)" \{/ ){
                $var = $1;
                $var =~ s/^\s+//;
                $var =~ s/\s+$//;
                $var =~ s/\s+/_/g;

                # replace special var if this exists in file
                if( $var =~ /^(cycle|time)$/ ){
                    $var = "${1}_file";
                }

                # prepend any groups to it
                $groups_string = join( "/", @groups );
                $var = $groups_string."/$var";
                $var =~ s&^/+&&;

                next;
            }

            # DATA
            # Just stuff in values until you see a }
            # This does not check for data having special tokens in it.
            if( $line =~ /^\s*DATA \{/ ){

                undef( %vals  );
                undef( $done );
                while( ! defined($done) ){

                    # if see }, then done
                    if( $line =~ /}/ ){
                        $line =~ s/\s*}\s*//;
                        $done = "";
                    }

                    # stip off stuff not used
                    $line =~ s/^\s*DATA \{//;
                    # starting with (i,j,k):
                    $line =~ s/^\s*\(.*\)://;
                    # replace commas with whitespace
                    $line =~ s/,/ /g;
                    # leading/trailing whitespace
                    $line =~ s/^\s+//;
                    $line =~ s/\s+$//;
                    
                    # now push the lines vals into vals
                    if( $line =~ /\S/ ){
                        push( @{$vals{val}}, split( /\s+/, $line) );
                    }

                    # add values if at end of DATA
                    if( defined( $done ) ){
                        # fill in a "time" field which is just the index
                        @{$vals{time}}  = (0..$#{$vals{val}});
                        @{$vals{cycle}} = (0..$#{$vals{val}});
                        $vals{field_name} = $var;
                        &ctf_vals_add_segment_ctf( VALS=>$vals_ref, VALS_SEGMENT=>\%vals );
                        # done with this DATA block - get to next one
                        undef( $done );
                        last;
                    }
                    
                    # done
                    if( $ln > $ln_max ){
                        last;
                    }
                    # next line
                    $line = $$lines_ref[$ln]; $ln++;

                } # while in this DATA

            } # hit DATA line

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
# Required routine: ctf_plot_h5dump
sub ctf_plot_h5dump{
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

        $field_group = $field;

        # fill have each field be on its own page (could change)
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
