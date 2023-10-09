package ctf_process_util;

########################################################################
# ctf_process_util.pm: (call these to process your files)
# -------------------
#   o ctf_vals_add( VALS=>\%vals, VALS_CYCLE=>\%vals_cycle )
#     Add a hash %vals_cycle to %vals.
#     %vals_cycle:
#       $vals_cycle{cycle}   = cycle number
#       $vals_cycle{<field>} = <value at that cycle>
#     If cycle >  previous cycle, add to array
#     If cycle == previous cycle, store longer one
#                 since longer => more precision.
#
#   o ctf_vals_add_segment( VALS=>\%vals, VALS_SEGMENT=>\%vals_segment )
#     Add a set of value arrays to vals (have data for vars for a segment
#       of cycles).
#     NOTE: cannot have cycle field
#     $vals_segment{time}[]      = time array
#     $vals_segment{<field 1>}[] = value array
#     $vals_segment{<field 2>}[] = value array
#     ...
#
#   o ctf_vals_add_segment_ctf
#     Add a set of cycle/time/field-value (like they would be
#     blocked together in a ctf_dump.txt file.
#
#   o ctf_vals_add_block
#     Use if you have a table of cycle/time/field-1/field-2/...
#       $vals_block{time}[]      = time array
#       $vals_block{cycle}[]     = cycle array
#       $vals_block{<field 1>}[] = value array
#       $vals_block{<field 2>}[] = value array
#       ...
#     Useful if you have multiple of these tables.  The cycle/time
#     values can be different, but must be consistent (cannot have
#     different times for the same cycle - or out of order times
#     when cycle/time fully assembled.
#
#   o ctf_vals_splice( VALS=>\%vals, CYCLE=>$cycle )
#     Truncate each field in vals to start at $cycle. Call this at each
#     restart point (since a restart might recalculate some cycles
#     again).
#
#   o ctf_vals_union_cycle_time ( VALS=>\%vals )
#     unions vals{cycle_time} + vals{field}{cycle_time} => updated vals{cycle_time}
#     Allows for pulling in various field{cycle,time} info then forming
#     consistent vals{cycle_time} info.
#     NOTE: this does NOT go back through field data and adjust time values.
#
#   o ctf_vals_check( VALS=>\%vals, CYCLE=>$cycle )
#     Sanity check on %vals.
#     Call after you process the files.
#
#   o ctf_fill_time( VALS=>\%vals )
#     Call after you process the files and call ctf_vals.
#     Each field will now have a "{time}[] = <time value>" array.
#
# my_utils.pm access:
# -------------------
#   o print_error()
#     Error printing
#   o ppo()
#     Perl object printing
#   ...
#
########################################################################

use POSIX qw( strtod );
use diagnostics;
use warnings;
use Carp;
use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION );
use Exporter;
use Scalar::Util qw(looks_like_number);

use my_utils qw (
    ppo
    print_error
);


# Update this version number whenever add routines that are used in ctf_process_<type>.pm.
# That way, the ctf_read_<type> can test on this version to make sure routines
# are available.
$VERSION   = 1.00;

@ISA       = qw(
                Exporter
               );

@EXPORT    = qw(
               );

@EXPORT_OK = qw(
                ctf_fill_time
                ctf_vals_add
                ctf_vals_add_block
                ctf_vals_add_overwrite
                ctf_vals_add_segment
                ctf_vals_add_segment_ctf
                ctf_vals_check
                ctf_vals_splice
                ctf_vals_union_cycle_time
               );
sub BEGIN{
}
sub END{
}

# local vars
# used various places but declared here
my(
    %CYCLE_HASH,
    );

########################################################################
########################################################################
###                    Internal Interface
########################################################################
########################################################################

# numerically sort
sub numerically { $a <=> $b; }

########################################################################
# add vals_cycle (set of values for this cycle) to vals
# will only overwrite existing value if longer.
# assumes that longer == more precision.
sub ctf_vals_add(){
    my %args = (
        VALS       => undef, # ref to hash result (will init)
        VALS_CYCLE => undef, # the values for the cycle
        @_,
        );
    my( $args_valid ) = "VALS|VALS_CYCLE";
    my(
        $arg,
        $cycle_old,
        $ierr,
        $field,
        $len1,
        $len2,
        $len3,
        $len4,
        $val1,
        $val2,
        $val3,
        $val4,
        $val_new,
        $val_new_test_1,
        $val_new_test_2,
        $val_old,
        $val_old_test_1,
        $val_old_test_2,
        $val_use,
        $vals_ref,
        $vals_cycle_ref,
        );

    # valid args
    foreach $arg (keys %args){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "FAILED", "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    $vals_ref       = $args{VALS};
    $vals_cycle_ref = $args{VALS_CYCLE};

    # check args
    if( ! defined($vals_ref)               ||
        ! defined($vals_cycle_ref)         ||
        ref($vals_ref)       ne "HASH"     ||
        ref($vals_cycle_ref) ne "HASH"     ||
        ! defined($$vals_cycle_ref{cycle}) ||
        $$vals_cycle_ref{cycle} < 0 ){
        $ierr = 1;
        &print_error( "FAILED", "Must define VALS{} and VALS_CYCLE{cycle}/{<other>}",
                      "  cycle = [$$vals_cycle_ref{cycle}]",
                      $ierr );
        exit( $ierr );
    }

    # for each field in vals_cycle_ref
    foreach $field ( keys %$vals_cycle_ref ){
      
        # cycle_old (-1 if first one)
        if( defined($$vals_ref{$field}{cycle}) ){
            $cycle_old = $$vals_ref{$field}{cycle}[-1];
        }
        else{
            $cycle_old = -1;
        }
  
        # new cycle
        if( $cycle_old != $$vals_cycle_ref{cycle} ){
            push( @{$$vals_ref{$field}{val}},   $$vals_cycle_ref{$field} );
            push( @{$$vals_ref{$field}{cycle}}, $$vals_cycle_ref{cycle} );
        }
        
        # overwrite val for that cycle
        else{

            # get old/new values
            $val_old = $$vals_ref{$field}{val}[-1];
            $val_new = $$vals_cycle_ref{$field};

            # if lengths are the same or val_old is nothing,
            # pick newer one.
            # Will assume that printed in same format.
            # Likely this is correct.
            #   1.123 vs 1.234 --> 1.234
            #   ""    vs 1.234 --> 1.234
            #
            # possible to have:
            #   1.23e+001 vs. 1.234e+01 
            # in which case, want more precision one.
            # Might want to skip this and always go to "check" case.
            # But want to do fastest first.
            $len1 = length($val_old);
            $len2 = length($val_new);
            if( $len1 == $len2 ||
                $val_old !~ /\S/ ){
                $$vals_ref{$field}{val}[-1] = $val_new;
            }

            # If either is not a number, pick newer one.
            #   foo vs. bar
            #   foo vs. 8
            elsif( ! looks_like_number($val_old) ||
                   ! looks_like_number($val_new) ){
                $$vals_ref{$field}{val}[-1] = $val_new;
            }

            # both are numbers
            #   1.1234 vs. 1.12345 -> longer 1.12345
            #   2.9999 vs. 3       -> longer and close 2.9999
            #   2.9999 vs. 5       -> longer but far   5 (second one)
            else{

                # Find the smallest number of digits of precision
                # If both numbers are the same with same precision,
                # use the longer one.
                # strip exponential notation part
                ($val1 = $val_old) =~ s/[ed].*//i;
                $val1 =~ s/[^\d]//g;
                ($val2 = $val_new) =~ s/[ed].*//i;
                $val2 =~ s/[^\d]//g;

                # get minimum precision
                $len1 = length($val1);
                $len2 = length($val2);
                $len3 = $len1 < $len2 ? $len1 : $len2;
                $len4 = $len3;
                $len3--;

                # Rounding where last digit is .5...tricky.
                # Need to round in correct direction
                # nudge a little if ends in 5 for rounding
                $val_old_test_1 = $val_old;
                $val_old_test_2 = $val_old;
                $val_new_test_1 = $val_new;
                $val_new_test_2 = $val_new;
                # will compare nudge-up and nudge-down values
                if( $val1 =~ /^.{$len4}5/ ){
                    $val_old_test_1 *=  .9999999999999;
                    $val_old_test_2 *= 1.0000000000001;
                }
                if( $val2 =~ /^.{$len4}5/ ){
                    $val_new_test_1 *=  .9999999999999;
                    $val_new_test_2 *= 1.0000000000001;
                }

                # print to new values with min precision
                $val1 = sprintf( "%.${len3}e", $val_old_test_1 );
                $val2 = sprintf( "%.${len3}e", $val_old_test_2 );
                $val3 = sprintf( "%.${len3}e", $val_new_test_1 );
                $val4 = sprintf( "%.${len3}e", $val_new_test_2 );
                # with smaller precision, same number --> use more precise
                if( $val1 == $val3 || $val1 == $val4 ||
                    $val2 == $val3 || $val2 == $val4 ){
                    $val_use = $len1 > $len2 ? $val_old : $val_new;
                }

                # different numbers --> use latest one
                else{
                    # This is the case where there is not just a rounding
                    # difference.
                    # In this case, pick the newer one (assuming last wins).
                    # These are the cases where there might be some sort
                    # of bug (in above logic....or in calling routine
                    # parser).
                    # Print out values here to check them if in doubt.
                    $val_use = $val_new;
                }

                # now set value
                $$vals_ref{$field}{val}[-1] = $val_use;
                
            } # both are numbers
        } # overwrite val for that cycle
    } # for each field in vals_cycle_ref

    # special init for time field if not defined
    # there might be some cases where you had a cycle but no
    # time data
    if( $#{$$vals_ref{time}{val}} < $#{$$vals_ref{cycle}{val}} ){
        push( @{$$vals_ref{time}{val}},   "" );
        push( @{$$vals_ref{time}{cycle}}, $$vals_cycle_ref{cycle} );
    }

    # clear $vals_cycle_ref
    undef( %$vals_cycle_ref );

}

########################################################################
# add vals_cycle (set of values for this cycle) to vals
# but will overwrite existing value (instead of if longer)
sub ctf_vals_add_overwrite(){
    my %args = (
        VALS       => undef, # ref to hash result (will init)
        VALS_CYCLE => undef, # the values for the cycle
        @_,
        );
    my( $args_valid ) = "VALS|VALS_CYCLE";
    my(
        $arg,
        $cycle_old,
        $ierr,
        $field,
        $vals_ref,
        $vals_cycle_ref,
        );

    # valid args
    foreach $arg (keys %args){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "FAILED", "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    $vals_ref       = $args{VALS};
    $vals_cycle_ref = $args{VALS_CYCLE};

    # check args
    if( ! defined($vals_ref)               ||
        ! defined($vals_cycle_ref)         ||
        ref($vals_ref)       ne "HASH"     ||
        ref($vals_cycle_ref) ne "HASH"     ||
        ! defined($$vals_cycle_ref{cycle}) ||
        $$vals_cycle_ref{cycle} < 0 ){
        $ierr = 1;
        &print_error( "FAILED", "Must define VALS{} and VALS_CYCLE{cycle}/{<other>}",
                      "  cycle = [$$vals_cycle_ref{cycle}]",
                      $ierr );
        exit( $ierr );
    }

    # for each field in vals_cycle_ref
    foreach $field ( keys %$vals_cycle_ref ){
      
        # cycle_old (-1 if first one)
        if( defined($$vals_ref{$field}{cycle}) ){
            $cycle_old = $$vals_ref{$field}{cycle}[-1];
        }
        else{
            $cycle_old = -1;
        }
  
        # new cycle
        if( $cycle_old != $$vals_cycle_ref{cycle} ){
            push( @{$$vals_ref{$field}{val}},   $$vals_cycle_ref{$field} );
            push( @{$$vals_ref{$field}{cycle}}, $$vals_cycle_ref{cycle} );
        }
        
        # overwrite val for that cycle
        else{
            $$vals_ref{$field}{val}[-1] = $$vals_cycle_ref{$field};
        }
    } # for each field in vals_cycle_ref

    # special init for time field if not defined
    # there might be some cases where you had a cycle but no
    # time data
    if( $#{$$vals_ref{time}{val}} < $#{$$vals_ref{cycle}{val}} ){
        push( @{$$vals_ref{time}{val}},   "" );
        push( @{$$vals_ref{time}{cycle}}, $$vals_cycle_ref{cycle} );
    }

    # clear $vals_cycle_ref
    undef( %$vals_cycle_ref );

}

########################################################################
# add vals_segment (set of values for a segment of cycles (times) ) to vals
# NOTE: currently no check for overlapping times - assume new block if
#       time > time previous
sub ctf_vals_add_segment(){
    my %args = (
        VALS       => undef, # ref to hash result (will init)
        VALS_SEGMENT => undef, # the values for the cycle
        @_,
        );
    my( $args_valid ) = "VALS|VALS_SEGMENT";
    my(
        $arg,
        @cycles,
        $i,
        $i_start,
        $i_stop,
        $ierr,
        $field,
        $last_cycle,
        $num_cycles,
        $num_cycles_total,
        $time_first,
        $time_last,
        $time_segment_first,
        $time_segment_last,
        $vals_ref,
        $vals_segment_ref,
        );

    # valid args
    foreach $arg (keys %args){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "FAILED", "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    $vals_ref         = $args{VALS};
    $vals_segment_ref = $args{VALS_SEGMENT};

    # check args
    if( ! defined($vals_ref)                      ||
        ! defined($vals_segment_ref)              ||
        ref($vals_ref)                ne "HASH"   ||
        ref($vals_segment_ref)        ne "HASH"   ||
        ! defined($$vals_segment_ref{time})       ||
        ref($$vals_segment_ref{time}) ne "ARRAY"
        ){
        $ierr = 1;
        &print_error( "FAILED", "Must define VALS{} and VALS_SEGMENT{time}[]/{<other>}",
                      $ierr );
        exit( $ierr );
    }
    # cannot define cycle (will be setting this)
    if( defined($$vals_segment_ref{cycle}) ){
        $ierr = 1;
        &print_error( "FAILED", "Cannot define 'cycle' field since assuming no cycle information",
                      $ierr );
        exit( $ierr );
    }

    # number of cycles in this segment
    $num_cycles = $#{$$vals_segment_ref{time}} + 1;

    # @cycles = array of cycles this segment pertains to
    undef( @cycles );
    
    # init if not there
    if( ! defined($$vals_ref{cycle}) ){
        @{$$vals_ref{cycle}{cycle}} = ();
        @{$$vals_ref{cycle}{val}} = ();
    }

    # get time and see if it is new
    $time_segment_first = $$vals_segment_ref{time}[0];
    $time_segment_last  = $$vals_segment_ref{time}[-1];
    $time_first = $$vals_ref{time}{val}[0];
    $time_last  = $$vals_ref{time}{val}[-1];

    # error if out of order
    if( defined($time_first) && $time_first > $time_segment_first ){
        $ierr = 1;
        &print_error( "FAILED", "Times are out of order:",
                      "  time_first=$time_first > time_segment_first=$time_segment_first",
                      "Make sure your files listed in increasing time order.",
                      $ierr );
        exit( $ierr );
    }

    # new time - push to time and cycle (and will set @cycles
    if( ! defined($time_last) || $time_last < $time_segment_first ){
        # time{val}
        push( @{$$vals_ref{time}{val}}, @{$$vals_segment_ref{time}} );
        # time{cycle}
        $last_cycle = $#{$$vals_ref{cycle}{val}} + 1;
        undef( @cycles );
        for( $i = 0; $i < $num_cycles; $i++ ){
            $cycles[$i] = $last_cycle + $i;
        }
        push( @{$$vals_ref{time}{cycle}},  @cycles );
        # cycle{cycle}, cycle{val}
        push( @{$$vals_ref{cycle}{cycle}}, @cycles );
        push( @{$$vals_ref{cycle}{val}},   @cycles );
    }

    # if not set, grab cycles
    if( ! @cycles ){
        $num_cycles_total = $#{$$vals_ref{time}{cycle}} + 1;
        $i_start = $num_cycles_total - $num_cycles;
        $i_stop  = $num_cycles_total-1;
        @cycles = @{$$vals_ref{time}{cycle}}[$i_start..$i_stop];
    }

    # for each field in vals_segment_ref
    foreach $field ( keys %$vals_segment_ref ){

        # skip time - already done
        if( $field eq "time" ){
            next;
        }

        # push cycle and val
        push( @{$$vals_ref{$field}{val}},   @{$$vals_segment_ref{$field}} );
        push( @{$$vals_ref{$field}{cycle}}, @cycles );
      
    } # for each field in vals_cycle_ref

    # clear $vals_cycle_ref
    undef( %$vals_segment_ref );

}

########################################################################
# add vals_segment (set of values for a segment of cycles (times) ) to vals
# NOTE: currently no check for overlapping times - assume new block if
#       time > time previous
sub ctf_vals_add_segment_ctf(){
    my %args = (
        VALS         => undef, # ref to hash result (will init)
        VALS_SEGMENT => undef, # the values for the cycle
        @_,
        );
    my( $args_valid ) = "VALS|VALS_SEGMENT";
    my(
        $arg,
        $cycle_exists,
        $cycle_new,
        $cycle_segment,
        @cycles_new,
        $done,
        $field,
        $ierr,
        $index_exists,
        $index_exists_max,
        $index_new,
        $index_segment,
        $index_segment_max,
        $time_new,
        @times_new,
        $vals_ref,
        $vals_segment_ref,
        );

    # valid args
    foreach $arg (keys %args){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "FAILED", "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    $vals_ref         = $args{VALS};
    $vals_segment_ref = $args{VALS_SEGMENT};

    # check args
    if( ! defined($vals_ref)                      ||
        ! defined($vals_segment_ref)              ||
        ref($vals_ref)                 ne "HASH"  ||
        ref($vals_segment_ref)         ne "HASH"  ||
        ! defined($$vals_segment_ref{field_name}) ||
        ! defined($$vals_segment_ref{time})       ||
        ref($$vals_segment_ref{time})  ne "ARRAY" ||
        ! defined($$vals_segment_ref{cycle})      ||
        ref($$vals_segment_ref{cycle}) ne "ARRAY" ||
        ! defined($$vals_segment_ref{val})        ||
        ref($$vals_segment_ref{val}) ne "ARRAY"   ||
        $#{$$vals_segment_ref{cycle}} != $#{$$vals_segment_ref{time}}
        ){
        $ierr = 1;
        &print_error( "FAILED", "Must define VALS{} and VALS_SEGMENT{cycle|time}[]/{<other>}",
                      $ierr );
        exit( $ierr );
    }

    # stuff field arrays
    $field = $$vals_segment_ref{field_name};
    @{$$vals_ref{$field}{val}}   = @{$$vals_segment_ref{val}};
    @{$$vals_ref{$field}{cycle}} = @{$$vals_segment_ref{cycle}};

    # if does not exist yet, short cut into time/cycle arrays and return
    if( ! defined($$vals_ref{time}) ){
        @{$$vals_ref{time}{val}}    = @{$$vals_segment_ref{time}};
        @{$$vals_ref{time}{cycle}}  = @{$$vals_segment_ref{cycle}};
        @{$$vals_ref{cycle}{val}}   = @{$$vals_segment_ref{cycle}};
        @{$$vals_ref{cycle}{cycle}} = @{$$vals_segment_ref{cycle}};
        # and done
        return( $ierr );
    }

    # quick check to see if already added in
    # not guaranteed...but hopefully will work
    # at least as many elements
    # could create hashes and see if several defined
    #   %hash_tmp = map{ $_ => "" } @{$$vals_segment_ref{cycle}};
    if( $#{$$vals_ref{cycle}{cycle}} >= $#{$$vals_segment_ref{cycle}} ){
        # first and last exists bound segment
        if( $$vals_ref{cycle}{cycle}[0]  <= $$vals_segment_ref{cycle}[0] &&
            $$vals_ref{cycle}{cycle}[-1] >= $$vals_segment_ref{cycle}[-1] ){
            return( $ierr );
        }
    }
    
    # splice into time/cycle arrays
    @times_new         = ();
    @cycles_new        = ();
    $index_new         = -1;
    $index_exists      = 0;
    $index_exists_max  = $#{$$vals_ref{cycle}{val}};
    $index_segment     = 0;
    $index_segment_max = $#{$$vals_segment_ref{cycle}};
    undef( $done );
    while( ! defined($done) ){

        # get current cycles
        if( $index_exists <= $index_exists_max ){
            $cycle_exists  = $$vals_ref{cycle}{val}[$index_exists];
        }
        else{
            undef( $cycle_exists );
        }
        if( $index_segment <= $index_segment_max ){
            $cycle_segment  = $$vals_segment_ref{cycle}[$index_segment];
        }
        else{
            undef( $cycle_segment );
        }

        # if done
        if( ! defined($cycle_exists) && ! defined($cycle_segment) ){
            last;
        }

        # at least one exists
        undef( $time_new );
        undef( $cycle_new );

        # only exists has values
        if( ! defined($cycle_segment) ){
            $time_new  = $$vals_ref{time}{val}[$index_exists];
            $cycle_new = $cycle_exists;
            $index_exists++;
        }

        # only segment has values
        elsif( ! defined($cycle_exists) ){
            $time_new  = $$vals_segment_ref{time}[$index_segment];
            $cycle_new = $cycle_segment;
            $index_segment++;
        }

        # both have values
        else{

            # both have same value - increase both
            if( $cycle_exists == $cycle_segment ){
                $time_new  = $$vals_segment_ref{time}[$index_segment];
                $cycle_new = $cycle_segment;
                $index_segment++;
                $index_exists++;
            }
            # exists < segment
            elsif( $cycle_exists < $cycle_segment ){
                $time_new  = $$vals_ref{time}{val}[$index_exists];
                $cycle_new = $cycle_exists;
                $index_exists++;
            }
            # segment < exists
            elsif( $cycle_segment < $cycle_exists ){
                $time_new  = $$vals_segment_ref{time}[$index_segment];
                $cycle_new = $cycle_segment;
                $index_segment++;
            }
            
        }

        # and push onto new arrays
        push( @cycles_new, $cycle_new );
        push( @times_new,  $time_new );

    }

    # and assign
    @{$$vals_ref{time}{val}}    = @times_new;
    @{$$vals_ref{time}{cycle}}  = @cycles_new;
    @{$$vals_ref{cycle}{val}}   = @cycles_new;
    @{$$vals_ref{cycle}{cycle}} = @cycles_new;

    # clear $vals_cycle_ref
    undef( %$vals_segment_ref );

}

########################################################################
# unions vals{cycle_time} + vals{field}{cycle_time} => updated vals{cycle_time}
# Allows for pulling in various field{cycle,time} info then forming
# consistent vals{cycle_time} info.
# NOTE: this does NOT go back through field data and adjust time values.
########################################################################
# add vals_block (set of cycle/time/<fields> arrays to vals
sub ctf_vals_union_cycle_time(){
    my %args = (
        VALS       => undef, # ref to hash result (will init)
        @_,
        );
    my( $args_valid ) = "VALS";
    my(
        $arg,
        $cycle,
        %cycle_time,
        @cycles,
        $cycles_ref,
        $field,
        $i,
        $ierr,
        $vals_ref,
        $time,
        %time_cycle,
        $time_old,
        @times,
        $times_ref,
        );

    # valid args
    foreach $arg (keys %args){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "FAILED", "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    $vals_ref       = $args{VALS};

    # check args
    if( ! defined($vals_ref)                    ||
        ref($vals_ref)               ne "HASH"
        ){
        $ierr = 1;
        &print_error( "FAILED", "Must define VALS{}",
                      $ierr );
        exit( $ierr );
    }


    # create cross-refererenced hashes from vals_ref (different parts)
    #   cycle_time{cycle} = time from vals_ref
    #   cycle_time{time}  = cycle
    # foreach field

    undef( %cycle_time );        
    foreach $field ( keys %{$vals_ref} ){

        # cycle needs to be there
        if( ! defined($$vals_ref{$field}{cycle}) ){
            $ierr = 1;
            &print_error( "FAILED", "Must define VALS{<field=$field>}{cycle}",
                          $ierr );
            exit( $ierr );
        }
        $cycles_ref = \@{$$vals_ref{$field}{cycle}};

        # time might not be known yet
        if( $field eq "time" ){
            $times_ref = \@{$$vals_ref{$field}{val}};
        }
        elsif( defined($$vals_ref{$field}{time}) ){
            $times_ref  = \@{$$vals_ref{$field}{time}};
        }
        else{
            undef( $times_ref );
        }
        # if times_ref, lengths must match
        if( defined( $times_ref ) ){
            if( $#$cycles_ref != $#$times_ref ){
                $ierr = 1;
                &print_error( "FAILED", "num mismatch VALS{<field=$field>}{cycle,time} = $#$cycles_ref,$#$times_ref",
                              $ierr );
                exit( $ierr );
                
            }
        }
        $i = 0;
        for( $i = 0; $i <= $#$cycles_ref; $i++ ){
            $cycle = $$cycles_ref[$i];
            if( defined($times_ref) ){
                $time = $$times_ref[$i];
            }
            else{
                # set unknown time to "" for now...will error later if never known
                $time = "";
            }

            # cycle_time : longest wins (assuming more precision)
            if( defined( $cycle_time{$cycle} ) ){
                $time_old = $cycle_time{$cycle};
                if( length($time_old) > length($time) ){
                    $time = $time_old;
                }
            }

            # stuff into hash
            $cycle_time{$cycle} = $time;
            $time_cycle{$time}  = $cycle;

        } # foreach field{cycle}[]

    } # foreach field
   
    # now have
    #  $cycle_time{ all $cycle values } = longest time value
    #  $time_cycle{ all $time values ... but also "1.2" and "1.9999"=longer }

    # create @cycles, @times
    undef( @cycles );
    undef( @times );
    foreach $cycle ( sort numerically keys %cycle_time ){
        push( @cycles, $cycle );
        $time = $cycle_time{$cycle};
        # at this point, must know time for the cycle
        if( ! defined($time_cycle{"$time"}) ||
            length( $time_cycle{"$time"} ) <= 0 ){
            $ierr = 1;
            &print_error( "FAILED", "could not find time value for cycle=$cycle",
                          $ierr );
            exit( $ierr );
        }
        push( @times, $time );
    }

    # ensure monatomically increasing time
    for( $i = 1; $i <= $#times; $i++ ){
        if( $times[$i-1] > $times[$i]){
            $ierr = 1;
            &print_error( "FAILED: time decreases:",
                          "  cycle=$cycles[$i-1] time=$times[$i-1]",
                          "  cycle=$cycles[$i] time=$times[$i]",
                          $ierr );
            exit( $ierr );
        }
    }

    # place into VALS
    @{$$vals_ref{time}{val}}    = @times;
    @{$$vals_ref{time}{cycle}}  = @cycles;
    @{$$vals_ref{cycle}{val}}   = @cycles;
    @{$$vals_ref{cycle}{cycle}} = @cycles;

}

########################################################################
# add vals_block (set of cycle/time/<fields> arrays to vals
sub ctf_vals_add_block(){
    my %args = (
        VALS       => undef, # ref to hash result (will init)
        VALS_BLOCK => undef, # time[], cycle[], <fields>[]
        SKIP_UNION => undef, # if skip the ctf_vals_union_cycle_time step (done manually)
        @_,
        );
    my( $args_valid ) = "SKIP_UNION|VALS|VALS_BLOCK";
    my(
        $arg,
        $cycle,
        @fields,
        $field,
        $ierr,
        $vals_block_ref,
        $vals_ref,
        );

    # valid args
    foreach $arg (keys %args){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "FAILED", "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    $vals_ref       = $args{VALS};
    $vals_block_ref = $args{VALS_BLOCK};

    # check args
    if( ! defined($vals_ref)                    ||
        ! defined($vals_block_ref)              ||
        ref($vals_ref)               ne "HASH"  ||
        ref($vals_block_ref)         ne "HASH"  ||
        ! defined($$vals_block_ref{time})       ||
        ref($$vals_block_ref{time})  ne "ARRAY" ||
        ! defined($$vals_block_ref{cycle})      ||
        ref($$vals_block_ref{cycle}) ne "ARRAY" ||
        $#{$$vals_block_ref{cycle}} != $#{$$vals_block_ref{time}}
        ){
        $ierr = 1;
        &print_error( "FAILED", "Must define VALS{} and VALS_BLOCK{cycle,time,fields}[]",
                      $ierr );
        exit( $ierr );
    }

    # delete previous values to account for restarts
    # only splice out fields defined to allow for processing different types
    # of csv files across restarts.
    undef( @fields );
    foreach $field ( keys( %{$vals_block_ref} ) ){
        if( $field =~ /cycle|time/ ){
            next;
        }
        push( @fields, $field );
    }
    $cycle = $$vals_block_ref{cycle}[0];
    &ctf_vals_splice( VALS=>$vals_ref, CYCLE=>$cycle, FIELDS=>\@fields );

    # go through each field and push current values
    foreach $field ( keys( %{$vals_block_ref} ) ){
        if( $field =~ /cycle|time/ ){
            next;
        }
        push( @{$$vals_ref{$field}{cycle}}, @{$$vals_block_ref{cycle}} );
        push( @{$$vals_ref{$field}{time}},  @{$$vals_block_ref{time}} );
        push( @{$$vals_ref{$field}{val}},   @{$$vals_block_ref{$field}} );
    }

    # get consistent set of VALS{cycle,time}
    # might only want to only do this at end of all files processed
    if( ! defined( $args{SKIP_UNION} ) ){
        &ctf_vals_union_cycle_time( VALS=>$vals_ref );
    }

}

########################################################################
# splice data to get rid of redone cycles
sub ctf_vals_splice{
    my %args = (
        VALS       => undef, # ref to hash result (will init)
        CYCLE      => undef, # this cycle read and up are deleted
        FIELDS     => undef, # if defined, use this set of fields to truncate
        @_,
        );
    my( $args_valid ) = "CYCLE|FIELDS|VALS";
    my(
        $arg,
        $cycle,
        $cycle_field,
        $cycle_first,
        $cycle_last,
        $cycle_next,
        $cycle_prev,
        $field,
        @fields,
        $i,
        $ierr,
        $index,
        $index_last,
        $vals_ref,
        );

    # valid args
    foreach $arg (keys %args){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "FAILED", "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    $vals_ref = $args{VALS};
    $cycle    = $args{CYCLE};

    # check args
    if( ! defined($vals_ref) ||
        ref($vals_ref) ne "HASH" ){
        $ierr = 1;
        &print_error( "FAILED", "Must define VALS", $ierr );
        exit( $ierr );
    }

    if( defined( $args{FIELDS} ) ){
        @fields = @{$args{FIELDS}};
    }
    else{
        @fields = keys %$vals_ref;
    }

    # foreach field in vals_ref
    foreach $field ( @fields ){

        # quick check if new field
        if( ! defined($$vals_ref{$field}) ){
            next;
        }

        # first and last cycles of the field
        $cycle_first = $$vals_ref{$field}{cycle}[0];
        $cycle_last  = $$vals_ref{$field}{cycle}[-1];
        $index_last  = $#{$$vals_ref{$field}{cycle}};

        # quick check that cycle_last < $cycle (a normal run)
        if( $cycle_last < $cycle ){
            next;
        }

        # quick check if cycle_first <= $cycle (remove $field)
        if( $cycle_first >= $cycle ){
            delete( $$vals_ref{$field} );
            next;
        }

        # start from end and go backwards until you hit the first
        # cycle_field < $cycle (guarantee exists)
        undef( $index );
        for( $i = $index_last; $i >= 0; $i-- ){
            $cycle_field = $$vals_ref{$field}{cycle}[$i];
            if( $cycle_field < $cycle ){
                # this is the last index to keep (size of arrays)
                $index = $i;
                last;
            }
        }

        # sanity (should never happen)
        if( ! defined($index) ){
            $ierr = 1;
            &print_error( "FAILED", "field = $field",
                          "Could not find index bounding cycle $cycle",
                          $ierr );
            exit( $ierr );
        }

        # sanity - should be the case
        $cycle_prev = $$vals_ref{$field}{cycle}[$index];
        $cycle_next = $$vals_ref{$field}{cycle}[$index+1];
        if( $cycle_prev < $cycle && $cycle <= $cycle_next ){
            # set size
            $#{$$vals_ref{$field}{cycle}} = $index;
            $#{$$vals_ref{$field}{val}}   = $index;
            # if set, truncate time also
            if( defined($$vals_ref{$field}{time}) ){
                $#{$$vals_ref{$field}{time}} = $index;
            }
        }
        else{
            $ierr = 1;
            &print_error( "FAILED", "field = $field",
                          "Expected $cycle_prev < $cycle <= $cycle_next",
                          $ierr );
            exit( $ierr );
        }        
    }

}

########################################################################
# sanity check of vals
#   call after reading files and before doing ctf_fill_time
sub ctf_vals_check{

    my %args = (
        VALS       => undef, # ref to hash result (will init)
        @_,
        );
    my( $args_valid ) = "VALS";
    my(
        $arg,
        $field,
        $i,
        $ierr,
        $num_cycle,
        $num_cycles,
        $num_times,
        $num_val,
        $val,
        $val_prev,
        $vals_ref,
        );

    # valid args
    foreach $arg (keys %args){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "FAILED", "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # clear %CYCLE_HASH
    undef( %CYCLE_HASH );

    # vals_ref
    $vals_ref = $args{VALS};
    if( ! defined($vals_ref) ){
            $ierr = 1;
            &print_error( "FAILED", "Missing VALS argument",
                          $ierr );
            exit( $ierr );
    }

    # if nothing there, that is ok
    if( ! keys %$vals_ref ){
        return( $ierr );
    }

    # num_cycles
    if( defined($$vals_ref{cycle}) ){
        $num_cycles = $#{$$vals_ref{cycle}{val}} + 1;
    }
    else{
        $num_cycles = 0;
    }

    # num_times
    if( defined($$vals_ref{time}) ){
        $num_times = $#{$$vals_ref{time}{val}} + 1;
    }
    else{
        $num_times = 0;
    }
    
    # num_cycles == num_times
    if( $num_times != $num_cycles ){
        $ierr = 1;
        &print_error( "FAILED", "num_times [$num_times] != num_cycles [$num_cycles]",
                      $ierr );
        exit( $ierr );
    }

    # check each field that the number of vals > 0 and
    # size val matches size cycle
    # If defined here, then must be non-0 size
    foreach $field ( keys %$vals_ref ){
        $num_val   = $#{$$vals_ref{$field}{val}} + 1;
        $num_cycle = $#{$$vals_ref{$field}{cycle}} + 1;
        if( $num_val == 0 || $num_val != $num_cycle ){
            $ierr = 1;
            &print_error( "FAILED", "field: $field",
                          "num_val [$num_val] num_cycle [$num_cycle]",
                          "Both must be same size and non-0",
                          $ierr);
            exit( $ierr );
        }
    }

    # cycle must be strictly increasing
    foreach $field ("cycle"){
        undef( $val_prev );
        $i = 0;
        foreach $val ( @{$$vals_ref{$field}{val}} ){
            if( defined( $val_prev ) &&
                $val_prev >= $val ){
                $ierr = 1;
                &print_error( "FAILED", "$field must be strictly increasing",
                              "val_prev [$val_prev] >= val [$val]",
                              "cycle = [$$vals_ref{cycle}{val}[$i]]",
                              "time  = [$$vals_ref{time}{val}[$i]]",
                              $ierr );
                exit( $ierr );
            }
            $val_prev = $val;
            $i++;
        }
    }

    # fix bad exponents (fortran when only allow 2 digits in 3 digit exponent)
    #    456.789+123 -> 456.789E+123
    # not sure if (because this can be expensive):
    #   this should be in routine by itself???
    #   some flag should be set in vals_ref to indicate needs fixing???
    # A 3 digit exponent when we do not expect one is often an error (super
    # small timestep, super large physical value).  So, might be best to just
    # keep it as "456.789+123" so that it will turn up as a string diff when
    # using cts_diff.pl.
    # So, add block - but keep commented...
    #foreach $field ( keys %$vals_ref ){
    #    foreach $val ( @{$$vals_ref{$field}{val}} ){
    #        $val =~ s/(\d)((\+|\-)(\d{3}))$/${1}E${2}/;
    #    }
    #}

    # time must be increasing
    # due to rounding issues and digits of precision, ignore this
    # for now and see if can fix it.
    #foreach $field ("time"){
    #    undef( $val_prev );
    #    $i = 0;
    #    foreach $val ( @{$$vals_ref{$field}{val}} ){
    #        if( defined( $val_prev ) &&
    #            $val_prev > $val ){
    #            $ierr = 1;
    #            &print_error( "$field must be increasing",
    #                          "val_prev [$val_prev] >= val [$val]",
    #                          "cycle = [$$vals_ref{cycle}{val}[$i]]",
    #                          "time  = [$$vals_ref{time}{val}[$i]]",
    #                          $ierr );
    #            exit( $ierr );
    #        }
    #        $val_prev = $val;
    #        $i++;
    #    }
    #}
}

########################################################################
# fill in the "time" data from the cycle data
# IT IS ASSUMED THAT YOU HAVE DONE A ctf_vals_check( VALS=>\%vals )
# Once called, each field is flagged as having already been time filled.
sub ctf_fill_time{
    my %args = (
        VALS => undef, # ref to hash result (will init)
        TIME => undef, # full or <undef>
        @_,
        );
    my( $args_valid ) = "TIME|VALS";
    my(
        $arg,
        $cycle,
        $cycle_ref,
        $cycle_val,
        $cycle_val_ref,
        $i,
        $i_val,
        $ierr,
        $field,
        @new_vals,
        $time,
        $time_ref,
        $time_type,
        $time_val_ref,
        $val,
        $val_ref,
        $vals_ref,
        );

    $ierr = 0;

    # valid args
    foreach $arg (keys %args){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "FAILED", "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # VALS and TIME
    $vals_ref = $args{VALS};
    if( defined($args{TIME}) ){
        $time_type = $args{TIME};
    }

    # check args
    if( ! defined($vals_ref) ||
        ref($vals_ref) ne "HASH" ){
        $ierr = 1;
        &print_error( "FAILED", "Must define VALS", $ierr );
        exit( $ierr );
    }

    # return if no time or cycle (no data)
    if( ! defined( $$vals_ref{cycle} ) && ! defined($$vals_ref{time}) ){
        return($ierr);
    }

    $cycle_ref = \@{$$vals_ref{cycle}{val}};
    $time_ref  = \@{$$vals_ref{time}{val}};

    # go through time and replace undef/empty with "-"
    foreach $time ( @{$$vals_ref{time}{val}} ){
        if( ! defined($time) || $time !~ /\S/ ){
            $time = "-";
        }
    }

    # cycle/time must be same size
    if( $#$cycle_ref != $#$time_ref ){
        $ierr = 1;
        &print_error( "FAILED", "max cycle index [$#$cycle_ref] != max time index [$#$time_ref]",
                      $ierr );
        exit( $ierr )
    }

    # fill cycle_hash if not done
    if( ! %CYCLE_HASH ){
        $i = 0;
        foreach $cycle ( @$cycle_ref ) {
            $CYCLE_HASH{$cycle} = $$time_ref[$i];
            $i++;
        }
    }

    # go through each field
    foreach $field ( keys %{$vals_ref} ) {

        # if already set, then must have been called, so next
        if( defined( $$vals_ref{$field}{time} ) ){
            next;
        }

        # sanity check that num cycles and vals match
        if( $#{$$vals_ref{$field}{cycle}} !=
            $#{$$vals_ref{$field}{val}} ){
            $ierr = 1;
            &print_error( "FAILED", "field: $field",
                          "\$#cycle [$#{$$vals_ref{$field}{cycle}}] != ".
                          "\$#val [$#{$$vals_ref{$field}{val}}]",
                          $ierr );
            exit( $ierr );
        }

        # quick cycle/time
        if( $field =~ /^(cycle|time)$/ ){
            # time_type==<undef> (default) (copy time)
            if( ! defined($time_type) ){
                @{$$vals_ref{$field}{time}} = @{$$vals_ref{time}{val}};
            }
            # time_type==full -> do not need cycle or time
            else{
                delete( $$vals_ref{$field}{cycle} );
                delete( $$vals_ref{$field}{time} );
            }
            next;
        }

        # init for this field
        $i_val = 0;
        $i     = 0;
        $cycle_val_ref = \@{$$vals_ref{$field}{cycle}};
        $val_ref       = \@{$$vals_ref{$field}{val}};
        delete(             $$vals_ref{$field}{time} );
        $time_val_ref  = \@{$$vals_ref{$field}{time}};

        # if time_type==<undef>, then will be searching for time
        if( ! defined($time_type) ){

            # go through cycle_val 
            foreach $cycle_val ( @{$cycle_val_ref} ){
                
                $time = $CYCLE_HASH{$cycle_val};
                
                # if time not found, just set to "-"
                if( ! defined($time) ){
                    $time = "-";
                    # had returned an error, but overload "cycle" with negative
                    # value for some fields...and want to allow that.
                    #$ierr = 1;
                    #&print_error( "field = [$field]",
                    #              "Could not find matching cycle [$cycle_val]",
                    #              $ierr );
                    #exit( $ierr );
                }

                # push time
                push( @{$time_val_ref}, $time );

            } # go through cycles

        } # time_type==<undef>

        # if time_type==full
        else{

            # quick check if same size
            if( $#{$cycle_ref} == $#{$cycle_val_ref} ){
                
                # full -> do not need cycle
                delete( $$vals_ref{$field}{cycle} );
                delete( $$vals_ref{$field}{time} );

                # copy
                # go to next field
                next;
            }

            undef( @new_vals );

            # go through cycle
            foreach $cycle ( @{$cycle_ref} ){
                
                # cycle match
                if( defined($$cycle_val_ref[$i_val]) &&
                    $cycle == $$cycle_val_ref[$i_val]){
                    $val = $$val_ref[$i_val];
                    # go to next i_val
                    $i_val++;
                }
                else{
                    undef( $val );
                }
                push( @new_vals, $val );
            }

            # store data
            @{$val_ref} = @new_vals;
            # full -> do not need cycle, time
            delete( $$vals_ref{$field}{cycle} );
            delete( $$vals_ref{$field}{time} );
            
        } # time_type==full


    } # go through each field

}

########################################################################
########################################################################
###                          Private
########################################################################
########################################################################


# final package return
1;

