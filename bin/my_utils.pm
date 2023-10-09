package my_utils;

use     POSIX qw( strtod tcgetpgrp getpgrp );
use     diagnostics;
use     warnings;
use     Carp;
use     vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION );
use     Exporter;
use     Cwd;
use     Digest::MD5 qw(md5 md5_hex);
use     IO::Select;
use     IO::Handle;
use     Fcntl qw(:DEFAULT :flock);
use     File::Copy;
use     Scalar::Util qw(openhandle);
use     Math::Trig qw(pi);
# for converting hex to 64 bit int...not sure if this is using a
# sledgehammer on a tack and something less intrusive is better
use     Math::BigInt;
use     Time::Local;
# not needed right now...but could add in
#use     File::Spec;

use     Time::HiRes qw(time);


$VERSION   = 1.00;

@ISA       = qw(
                Exporter
               );

@EXPORT    = qw(
               );

@EXPORT_OK = qw(
                &array_to_range
                &conv_time
                &datafile_files
                &datafile_parse
                &datafile_getval
                &datafile_getblock
                &datafile_setcond
                &datafile_debug
                &date_ymdhms
                &date_ymdhms_sep
                &date_ymdhms_sep_hr
                &expand_string
                &extrema
                &my_fix_perms
                &get_id_num
                &get_pname
                &get_rj_id_next
                &get_sysinfo
                &get_jobinfo
                &my_array_stats
                &my_checksum_string
                &my_checksum_string_hex
                &my_chdir
                &my_cleanpath
                &my_compare_version
                &my_copy
                &my_copyf
                &my_copy_hpss
                &my_copy_obj
                &my_cull
                &my_derivative
                &my_dir
                &my_file_flush
                &my_fit
                &my_get_area
                &my_get_area_shift
                &my_get_area_segment
                &my_get_batch_id
                &my_get_locs
                &my_getval
                &my_interpolate
                &my_ldd_info
                &my_lockfile
                &my_log
                &my_logderiv
                &my_convolve
                &my_max
                &my_mkdir
                &my_mkdirf
                &my_mkdir_hpss
                &my_mode
                &my_mount_info
                &my_munge
                &my_nudge
                &my_notdir
                &my_packit
                &my_readkey
                &my_sleep
                &my_smooth
                &my_stat
                &my_stat_guess
                &my_stat_fullpath
                &my_timer
                &my_xml_read
                &my_xml_read_simple
                &parse_key_val
                &path_add_default
                &print_perl_obj
                &ppo
                &print_error
                &run_command
                &sort_unique
                &sort_numerically_unique
                &status_bar
                &which_exec
                &latexify
               );
sub BEGIN{
}
sub END{
}
#......................
#...global variables...
#......................
my(
   %CONV_TIME_HASH,
   %G_RUN_COMMAND_SEEN,
   $MY_READKEY_S,
   $MY_COUNTER_ID, # for tagging messages with an ID
   %MY_TIMER_TIMES,
   %GET_SYSINFO, # global saves for get_sysinfo
  );


########################################################################
# Fix permissions of a path recursively downward and optionally for
# parent dirs.
sub my_fix_perms{
    my %args = (
        ALLOW_CHGRP_PARENT => undef, # if chgrp of parent allowed
        DEBUG => undef, # debug
        FIXED => undef, # ref to hash of parent dirs already processed
        FILES => undef, # ref to array of paths
        FORK_PID => undef, # ref to pid if forking
        GROUP => undef, # change to this group (if this is path, use that group)
        GROUPS => undef, # {<group1>}=<group2>,{<group3>}=<group4>,...
        GROUP_PARENT => undef, # regexp for parent groups (or owner)
        NO_FIND => undef, # only do objects explicitly listed
        UMASK => undef, # effective umask
        UP => undef, # same perms for parent dirs
        V => undef, # verbose
        STATUS => undef, # status
        @_,
        );
    my $args_valid = "ALLOW_CHGRP_PARENT|DEBUG|FILES|FIXED|FORK_PID|GROUP|GROUPS|GROUP_PARENT|NO_FIND|UMASK|UP|V|STATUS";
    my(
        %all_files,
        @all_files_array,
        $arg,
        $arg_name,
        %args_checked,
        $com,
        $do_chgrp,
        $file,
        $file_arg,
        @files_arg,
        $files_arg_ref,
        @files,
        @files_arr,
        %fixed,
        $fixed_ref,
        $fork_pid_ref,
        $fr,
        $group,
        $group_found,
        $group_orig,
        $group_try,
        %group_parent_dirs,
        %groups_arg,
        $groups_arg_ref,
        $groups_in,
        @groups_try,
        $i,
        $ierr,
        $is_exec,
        $mode,
        $mode_changed,
        $mode_new_o,
        $mode_orig_o,
        $num_files,
        $num_tmp,
        $out,
        $path,
        $path_top,
        $realpath,
        $ref_type,
        $ref_type_need,
        %seen,
        %stat,
        $this,
        $to,
        $val,
        @vals,
        );
    
    # init
    $ierr = 0;
    $MY_COUNTER_ID++;

    if( defined($args{V}) || defined($args{STATUS}) ){
        print "my_fix_perms: date start: pid=$$ ID=$MY_COUNTER_ID ",&date_ymdhms_sep(),"\n";
    }
    
    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # needed
    if( ! defined( $args{FILES}) ){
        $ierr = 1;
        &print_error( "Missing arg [FILES]",
                      $ierr );
        exit( $ierr );
    }

    # conflicting
    if( defined($args{GROUP_PARENT}) && defined($args{UP}) ){
        $ierr = 1;
        &print_error( "Cannot define both GROUP_PARENT and UP.",
                      $ierr );
        exit( $ierr );
    }

    # check types
    $ref_type_need = "HASH";
    foreach $arg_name ( "FIXED" ){
        $args_checked{$arg_name} = "";
        if( defined($args{$arg_name}) ){
            $ref_type = ref($args{$arg_name});
            if( $ref_type ne $ref_type_need ){
                $ierr = 1;
                &print_error( "ref($arg_name) [$ref_type] != '$ref_type_need'",
                              $ierr );
                exit( $ierr );
            }
        }
    }

    # check types
    $ref_type_need = "SCALAR";
    foreach $arg_name ( "FORK_PID" ){
        $args_checked{$arg_name} = "";
        if( defined($args{$arg_name}) ){
            $ref_type = ref($args{$arg_name});
            if( $ref_type ne $ref_type_need ){
                $ierr = 1;
                &print_error( "ref($arg_name) [$ref_type] != '$ref_type_need'",
                              $ierr );
                exit( $ierr );
            }
        }
    }

    # GROUPS to hash if needed
    $arg_name = "GROUPS";
    if( defined($args{$arg_name}) ){
        $ref_type = ref($args{$arg_name});
        $args_checked{$arg_name} = "";
        if( $ref_type eq "" ){
            $val  = $args{$arg_name};
            @vals = split( /\s*,\s*/, $val );
            foreach $val ( @vals ){
                if( $val =~ /(\S+)=(\S+)/ ){
                    $fr = $1;
                    $to = $2;
                    $groups_arg{$fr} = $to;
                }
                else{
                    $ierr = 1;
                    &print_error( "$arg_name: expected <group1>=<group2> [$val]",
                                  $ierr );
                    exit( $ierr );
                }
            }
            $groups_arg_ref = \%groups_arg;
        }
        elsif( $ref_type eq "HASH" ){
            $groups_arg_ref = $args{$arg_name};
        }
        else{
            $ierr = 1;
            &print_error( "ref($arg_name) [$ref_type] != '' or 'ARRAY'",
                          $ierr );
            exit( $ierr );
        }
    }

    # FILES to array if needed
    $arg_name = "FILES";
    $ref_type = ref($args{$arg_name});
    $args_checked{$arg_name} = "";
    if( $ref_type eq "" ){
        @files_arg = ($args{$arg_name});
        $files_arg_ref = \@files_arg;
    }
    elsif( $ref_type eq "ARRAY" ){
        $files_arg_ref = $args{$arg_name};
    }
    else{
        $ierr = 1;
        &print_error( "ref($arg_name) [$ref_type] != '' or 'ARRAY'",
                      $ierr );
        exit( $ierr );
    }
    
    $ref_type_need = "";
    foreach $arg_name ( split(/|/, $args_valid) ){
        if( defined( $args_checked{$arg_name} ) ){
            next;
        }
        if( defined($args{$arg_name}) ){
            $ref_type = ref($args{$arg_name});
            if( $ref_type ne $ref_type_need ){
                $ierr = 1;
                &print_error( "ref($arg_name) [$ref_type] != '$ref_type_need'",
                              $ierr );
                exit( $ierr );
            }
        }
    }

    # implies
    if( defined($args{DEBUG}) ){
        $args{V} = "";
    }

    # group from path (do before group_parent)
    if( defined( $args{GROUP} ) &&
        $args{GROUP} =~ /^(\.|.*\/.*)$/ ){
        &my_stat( $args{GROUP}, \%stat );
        if( %stat ){
            $args{GROUP} = $stat{group};
        }
        else{
            $ierr = 1;
            &print_error( "Cannot find info about GROUP=<PATH> [$args{GROUP}]",
                          $ierr );
            exit( $ierr );
        }
    }

    # umask
    if( defined( $args{UMASK} ) ){
        if( $args{UMASK} !~ /^[0-7]+$/ ){
            $ierr = 1;
            &print_error( "Expected format for UMASK [$args{UMASK}] = [0-7]+",
                          $ierr);
            exit( $ierr );
        }
        # strip off leading 0's
        $args{UMASK} =~ s/^0+//;
    }

    # group_parent processing
    if( defined( $args{GROUP_PARENT} ) ){
        # , -> |
        # might want to do whitespace?  nah...
        if( $args{GROUP_PARENT}=~ /,/ ){
            $args{GROUP_PARENT} =~ s/,\s*,/,/g;
            $args{GROUP_PARENT} =~ s/^\s*,//g;
            $args{GROUP_PARENT} =~ s/,\s*$//g;
            @vals = split(/\s*,\s*/, $args{GROUP_PARENT});
            $args{GROUP_PARENT} = join("|", @vals);
        }
        # and tack on GROUP
        # this MUST be last so that GROUP_PARENT takes precidence
        # for chgrp of parent dir(s).
        if( defined( $args{GROUP} ) ){
            $args{GROUP_PARENT} .= "|$args{GROUP}";
        }
        # strip leading/trailing |
        $args{GROUP_PARENT} =~ s/^\|+/\|/;
        $args{GROUP_PARENT} =~ s/^\|+//;
        $args{GROUP_PARENT} =~ s/\|+$//;
    }

    # fork here after checking but before doing stuff
    # parent returns
    if( defined( $args{FORK_PID} ) ){
        $fork_pid_ref = $args{FORK_PID};
        if( $$fork_pid_ref=fork ){
            return( $ierr );
        }
    }
    
    if( defined($args{V}) || defined($args{STATUS}) ){
        print "\n";
    }
    
    # print if debug
    if( defined($args{DEBUG}) ){
        print "$0 : debug\n";
    }
    
    # starting
    if( defined($args{V}) || defined($args{STATUS}) ){
        print "$0 : getting filelist\n";
    }

    # do not process parents if already fixed
    undef( %fixed );
    if( defined($args{FIXED}) ){
        $fixed_ref = $args{FIXED};
    }
    else{
        $fixed_ref = \%fixed;
    }

    # remove duplicate files (since find can be expensive)
    undef( %seen );
    foreach $file_arg ( @{$files_arg_ref} ) {
        $seen{$file_arg} = "";
    }
    @files_arr = sort keys %seen;

    # create list of files to process
    undef( %all_files );
    foreach $file_arg ( @files_arr ) {
        &my_stat( $file_arg, \%stat );
        if( defined( $args{NO_FIND} ) ){
            $all_files{$stat{fullpath}} = "";
        }
        else{
            @files = split( /\n/, `find '$file_arg' -print 2> /dev/null` );
            if( defined( $args{V} ) || defined( $args{STATUS} ) ){
                $num_tmp = $#files + 1;
                print "$0 : $file_arg\n";
                print "$0 : num_files=$num_tmp\n";
                print "\n";
            }
            $i = 0;
            if( $#files < 0 ){
                # silently skip
                #$ierr = 0;
                #&print_error( "Nothing under:",
                #              $file_arg,
                #              "skipping...",
                #              $ierr );
                next;
            }
            foreach $file ( @files ){
                if( defined( $args{STATUS} ) ){
                    $i++;
                    &status_bar( $i, $num_tmp );
                }
                #old&my_stat( $file, \%stat );
                #old$realpath = $stat{fullpath} || undef;
                $realpath = Cwd::realpath($file);
                if( defined( $realpath ) ){
                    $all_files{$realpath} = "";
                }
                else{
                    $ierr = 0;
                    &print_error( "Could not stat:",
                                  $file,
                                  "skipping...",
                                  $ierr );
                }
            }
        }
        
        # parent directories
        # up           -> all_files         all have same perms
        # group_parent -> group_parent_dirs parents just have x access
        if( defined($args{UP}) || defined($args{GROUP_PARENT}) ){
            $this = $file_arg;
            while( 1 == 1 ){
                
                &my_stat( $this, \%stat );
                if( ! %stat ){
                    last;
                }

                # one you hit a dir you do not own, exit
                # might want to keep checking up???
                if( $stat{uid} != $< ){
                    last;
                }
                
                if( defined( $$fixed_ref{$stat{fullpath}} ) ){
                    last;
                }
                $$fixed_ref{$stat{fullpath}} = "";
                if( $this =~ /\S/ ){
                    if( defined($args{UP}) ){
                        $all_files{$stat{fullpath}} = "";
                    }
                    else{
                        # only add in if actually dir
                        if( defined($stat{is_dir}) ){
                            $group_parent_dirs{$stat{fullpath}} = "";
                        }
                    }
                }
                
                # go up a dir
                $this = $stat{dir};

            }
        }
    }

    # get all files to be processed
    @all_files_array = sort keys %all_files;
    if( defined( $args{V} ) || defined( $args{STATUS} ) ){
        $num_files = $#all_files_array + 1 + keys(%group_parent_dirs);
        print "$0 : fixing files\n";
        print "$0 : num_files=$num_files\n";
        print "\n";
    }

    # group_parent -> group_parent_dirs
    if( %group_parent_dirs ){
        foreach $path ( reverse sort keys %group_parent_dirs ){
            
            &my_stat($path, \%stat);
            # should not happen...but could...
            if( ! %stat ){
                $ierr = 0;
                &print_error( "Oddity...trying to fix dir that does not exist: $path", $ierr );
                last;
            }
            
            # one you hit a dir you do not own, exit
            if( $stat{uid} != $< ){
                last;
            }
            
            # if this is a top level path
            #   scratch{digits}/{maybe .something}/LOGNAME
            #     /net/scratch4/.mdt3/lmdm
            #     /net/scratch4/yellow/lmdm
            if( defined($ENV{LOGNAME}) &&
                $path =~ m&scratch\d*/([^/]+)?/$ENV{LOGNAME}$& ){
                $path_top = "";
            }
            else{
                undef( $path_top );
            }
            
            # if path_top, fix perms now
            # Policy is to remove other access
            if( defined( $path_top ) ){

                # original mode
                $mode_orig_o = $stat{mode};
                
                # init mode_new_o
                $mode_new_o  = $mode_orig_o;
                
                # had removed "other" access but keep since want to
                # allow "cd through" to directory they can see.
                #$mode_new_o = $mode_orig_o & ~07;
                
                # remove group write as this was likely added due to
                # umask being 2...
                $mode_new_o = $mode_new_o & ~020;
                
                if( $mode_orig_o != $mode_new_o && ! -e "$path/WORLD_ACCESS" ){
                    printf( "*** Removing group write to top level scratch directory. (touch $path/WORLD_ACCESS to allow) ***\n" );
                    if( ! defined($args{DEBUG}) ){
                        chmod( $mode_new_o, $path );
                    }
                    $mode_changed = sprintf( "*** mode = %06o ->  %06o %32s %s\n",
                                             $mode_orig_o, $mode_new_o, "", $path );
                    # remove leading "04" from dirs
                    $mode_changed =~ s/ 04/  /g;
                    print $mode_changed;
                    # and get new stat
                    &my_stat($path, \%stat);
                }
            }

            # groups and modes
            $group_orig  = $stat{group};
            $mode_orig_o = $stat{mode};
            
            # GROUP_PARENT = list of valid group_parent + group requested
            #   group requested can be:
            #     owner: asking to lock it down
            #     other group: will want this group to be able to cd through

            # if owner is in list of GROUP_PARENT, only need owner +x
            if( $stat{user} =~ /^$args{GROUP_PARENT}$/ ){
                $mode_new_o = $mode_orig_o | 0100;
            }
            # otherwise, if current group is in the group set need group +x
            elsif( $group_orig =~ /^$args{GROUP_PARENT}$/ ){
                $mode_new_o = $mode_orig_o | 010;
            }
            # in different group, need other +x ... which is not allowed
            # at the top level.  I think the following is fine (no read
            # access and can cd through it):
            #   drwx--S--x
            # So, instead will change to first group in GROUP_PARENT
            # and make mode 2710
            else{

                # top level dir and group settings is special
                # might want to make this any parent dir???
                # this would make parent dirs dacodes and mode 2710
                # which is probably what you want
                if( defined( $path_top ) ){

                    # find group you would like to change it to
                    # pick first one in GROUP_PARENT
                    @groups_try = split( /\|/, $args{GROUP_PARENT} );
                    # regexp of groups you are in
                    $groups_in = `groups 2>&1`;
                    $groups_in =~ s/\s+/|/g;
                    undef( $group_found );
                    foreach $group_try ( @groups_try ){
                        # first one that is not the user-group
                        if( $group_try =~ /\S+/ &&
                            $group_try ne $group_orig &&
                            $group_try =~ /^($groups_in)$/ ){
                            $group_found = $group_try;
                            last;
                        }
                    }

                    # default will chgrp
                    $do_chgrp = "";

                    # did not find group to chgrp
                    if( ! defined( $group_found ) ){
                        undef( $do_chgrp );
                    }

                    # currently turned off
                    if( ! defined($args{ALLOW_CHGRP_PARENT}) ){
                        undef( $do_chgrp );
                    }

                    # can chgrp
                    if( defined( $do_chgrp ) ){
                        
                        # change the group
                        $com = "chgrp '$group_found' '$path'";
                        $out = &run_command( COMMAND=>$com,
                                             DEBUG=>$args{DEBUG},
                                             VERBOSE_ECHO=>$args{V},
                                             ERROR_REGEXP=>'/\S/' );
                        print "*** WARNING: Changed permissions of PARENT $path\n";
                        printf( "*** group = %-47s %s\n",
                                "$group_orig -> $group_found", $path );
                        &my_stat($path, \%stat);
                        $mode_orig_o = $stat{mode};
                        $group_orig  = $stat{group};
                        # new mode: g+sx (group can cd through and sticky)
                        # remove all group and other access, then add g+sx
                        $mode_new_o = ($mode_orig_o & ~077) | 02010;
                        if( $mode_new_o == $mode_orig_o ){
                            $mode_changed = sprintf( "    mode  = %06o ->  %6s %30s %s\n",
                                                     $mode_orig_o, "<same>", "", $path );
                            # remove leading "04" from dirs
                            $mode_changed =~ s/ 04/  /g;
                            print $mode_changed;
                        }
                        
                    } # can chgrp

                    # print message about not allowing o+x mod
                    else{
                        print "\n";
                        print "*** WARNING: $path\n";
                        print "*** WARNING: This is a top level scratch directory.\n";
                        print "*** WARNING: Allowing group access requires o+x .\n";
                        print "*** WARNING: This violates policy.\n";
                        if( defined( $group_found ) ){
                            print "*** WARNING: Run again with the additional arg to:\n";
                            print "*** WARNING    allow group to cd through directory,\n";
                            print "*** WARNING    but not allow read access.\n";
                            print "*** WARNING:   --allow_chgrp_parent\n";
                            print "*** WARNING: Or run the following command manually to do the same thing:\n";
                            print "*** WARNING:   chgrp $group_found $path\n";
                            print "*** WARNING    chmod 2710 $path\n";
                        }
                        else{
                            print "*** WARNING: no valid groups found.\n";
                        }
                        print "\n";
                    }

                } # top level dir

                # not a top level dir, can add o+x
                else{
                    $mode_new_o = $mode_orig_o | 01;
                }
            }
            
            # if mode_orig_o not sufficient
            if( $mode_orig_o != $mode_new_o ){
                if( ! defined($args{DEBUG}) ){
                    chmod( $mode_new_o, $path );
                }
                $mode_changed = sprintf( "*** mode = %06o ->  %06o %32s %s\n",
                                         $mode_orig_o, $mode_new_o, "", $path );
                # remove leading "04" from dirs
                $mode_changed =~ s/ 04/  /g;
                print "*** WARNING: Changed permissions of PARENT $path\n";
                print $mode_changed;
            }
            
        }
        
    }

    # process each file
    $i = 0;
    foreach $file ( @all_files_array ){
        if( defined( $args{STATUS} ) ){
          $i++;
          &status_bar( $i, $num_files );
        }

        &my_stat( $file, \%stat );
        if( ! %stat ){
            next;
        }
        
        # skip if not owner (since cannot change perms anyways)
        if( $stat{uid} != $< ){
            next;
        }
        
        # change group
        $group = "";
        # preference is groups
        if( defined($groups_arg_ref) ){
            if( defined($$groups_arg_ref{$stat{group}}) ){
                $group = $$groups_arg_ref{$stat{group}};
            }
        }
        
        # if not set, use group
        if( $group !~ /\S/ ){
            if( defined($args{GROUP}) ){
                $group = $args{GROUP};
            }
        }
    
        # change group if needed
        if( ( ! defined($stat{group}) ) ||
            ( $group =~ /\S/ && $group ne $stat{group} ) ){
            
            $com = "chgrp $group '$file'";
            # since already know you own file, should be able to change perms.
            # on slow filesystesm, got a timeout and this failed....which
            # meant you had to rerun from start.
            # So, just print any output and continue
            #   ERROR_REGEXP=>'/\S/'
            # Should add a "retry" mechanism.
            $out = &run_command( COMMAND=>$com, DEBUG=>$args{DEBUG},
                                 VERBOSE_ECHO=>$args{V}, STDOUT=>'' );
            if( $out =~ /\S/ ){
            }
            # need to reset stat since perms change if group changes if dir
            if( defined( $stat{is_dir} ) ){
                &my_stat( $file, \%stat );
            }
        }
        
        # permissions
        $mode = "";
        if( defined($stat{is_dir}) ){
            if( defined( $args{UMASK} ) ){
                $mode = &my_mode( DEC=>"", DIR=>"", UMASK=>$args{UMASK} );
            }
            else{
                # see if group sticky bit already set
                if( $stat{mode_dp} !~ /^2\d{3}$/ ){
                    $mode = "g+s";
                }
            }
        }
        else{
            if( defined( $args{UMASK} ) ){
                $is_exec = $stat{is_exec};
                $mode = &my_mode( DEC=>"", EXEC=>$is_exec, UMASK=>$args{UMASK} );
            }            
        }
        
        # do not change it if already correct
        if( $stat{mode_dp} =~ /^0*${mode}$/ ){
            $mode = "";
        }
        if( $mode =~ /\S/ ){
            $com = "chmod $mode '$file'";
            $out = &run_command( COMMAND=>$com, DEBUG=>$args{DEBUG},
                                 VERBOSE_ECHO=>$args{V}, ERROR_REGEXP=>'/\S/' );
        }
    }

    if( defined($args{V}) || defined($args{STATUS}) ){
        if( defined( $args{STATUS} ) ){
            print "\n";
        }
        print "my_fix_perms: date stop:  pid=$$ ID=$MY_COUNTER_ID ",&date_ymdhms_sep(),"\n";
    }

    # if fork, this is child and exit
    if( defined( $args{FORK_PID} ) ){
        exit;
    }
    
}

################################################################################
# return hash of location of checkout dirs
#   LOC_<SOURCE|TEST|TOOLS>_<N>_FULL = full path to various dirs
#
# NOTE: currently assumes the my_utils.pm file is located in the checkout
# NOTE: Looks for LOC_<TYPE>_<N> files
sub my_get_locs{
    # use FindBin qw($RealBin);
    # use __FILE__ as location to start with

    my %args = (
        LOCS     => undef, # output locations
        DIR      => undef, # &my_dir(__FILE__) is default
        @_,
        );
    my $args_valid = "DIR|LOCS";
    my(
        $arg,
        $dir,
        $file,
        @files,
        $ierr,
        $key,
        @keys,
        $locs_ref,
        $match,
        $name,
        %stat,
        $type,
        @types,
        $types_regexp,
        );

    # init
    $ierr = 0;

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    @types = ( "READMES", "SOURCE", "TEST", "TOOLS" );
    $types_regexp = join( "|", @types );

    $locs_ref = $args{LOCS};
    if( ! defined($locs_ref) ){
        $ierr = 1;
        &print_error( "locs not defined",
                      $ierr );
        exit( $ierr );
    }

    if( defined($args{DIR}) ){
        $dir = $args{DIR};
    }
    else{
        $dir = &my_dir( __FILE__ );
    }

    undef( %{$locs_ref} );

    # search up for file named LOC_<SOURCE|TEST|TOOLS>_<N>
    while( $dir =~ m&/\S& ){
        @files = glob( "$dir/LOC_*_[0-9]" );
        foreach $file ( @files ){
            if( $file =~ m&/(LOC_(${types_regexp})_\d)$& ){
                $match = $1;
                &my_stat( $file, \%stat );
                $$locs_ref{"${match}_FULL"} = $stat{dir};
                last;
            }
        }
        if( %{$locs_ref} ){
            last;        
        }
        $dir = &my_dir( $dir );
    }

    # exit now if did not find it
    if( ! %{$locs_ref} ){
        return;
    }

    # other LOC files will be at the same level as this file
    # new: ../../eap.*/*/LOC_*_[0-9]
    # old: ../*/LOC_*_[0-9]
    @files = glob( "$dir/../../eap.*/*/LOC_*_[0-9] $dir/../*/LOC_*_[0-9]" );
    foreach $file ( @files ){
        if( $file =~ m&/(LOC_(${types_regexp})_\d)$& ){
            $match = $1;
            &my_stat( $file, \%stat );
            # should not happen since glob above worked.
            # but did on trinity...ugh...
            if( ! %stat ){
                &print_error( "Oddity: cannot stat $file", 0 );
                $stat{dir} = "/unknown/loc/$file";
            }
            $$locs_ref{"${match}_FULL"} = $stat{dir};
        }
    }
    
    # LOC_<TYPE>_ALL_FULL = whitespace separated list of all directories
    foreach $type ( @types ){
        $name = "LOC_${type}_ALL_FULL";
        @keys = grep( /^LOC_${type}_\d+_FULL$/, sort keys %$locs_ref );
        if( @keys ){
            foreach $key ( @keys ){
                $$locs_ref{$name} .= "$$locs_ref{$key} ";
            }
        }
    }

    # LOC_ALL_<N>_FULL
    foreach $type ( @types ){
        @keys = grep( /^LOC_${type}_\d+_FULL$/, sort keys %$locs_ref );
        if( @keys ){
            foreach $key ( @keys ){
                if( $key =~ /^LOC_${type}_(\d+)_FULL$/ ){
                    $name = "LOC_ALL_${1}_FULL";
                    $$locs_ref{$name} .= "$$locs_ref{$key} ";
                }
            }
        }
    }

    # prune off trailing whitespace
    foreach $name ( keys %{$locs_ref} ){
        $$locs_ref{$name} =~ s/\s+$//;
    }

}


################################################################################
# print progress bar given current count (start at 1) and total count
#  $imax = $#array+1;
#  $i = 1;
#  foreach $val ( @array ){
#     &status_bar($i, $imax);
#     $i++;
#  }
sub status_bar{
    if( $_[0] == 1 ){
        my $spaces = $_[2]||"";
        print "${spaces}Status 1..9: ";
    }
    print substr( "123456789\n", int(($_[0]-1)/($_[1]/10.)),(int($_[0]/($_[1]/10.)) - int(($_[0]-1)/($_[1]/10.))) );
}

################################################################################
# my_sleep: partial second sleep (.3, 1.5, ... )
sub my_sleep{
    my(
        $time, # secs to sleep
        ) = @_;
    select( undef, undef, undef, $time );
}

################################################################################
#............................................................................
#...Name
#...====
#... my_array_stats
#...
#...Purpose
#...=======
#... Create stats hash from an array
#... Unless otherwise specified, non-number values will be skipped.
#...    max       - max value
#...    maxabs    - max absolute value
#...    mean      - mean value
#...    min       - min value
#...    range     - max - min
#...    nrmse     - rmse/(max - min)
#...    rms       - root mean square
#...    rmse      - root mean square error
#...    rmse_max  - sqrt(maximum distance from mean)
#...    sum       - sum of nums
#...    sumsq     - Sum of the squares of the numbers
#...    numntrue  - Number of non-0 numbers
#...    numnfalse - Number of 0 numbers
#...    numnums   - Number of Numbers
#...    numstrue  - Number of non-empty strings
#...    numsfalse - Number of empty strings
#...    numstrs   - Number of strings
#...    numtrue   - Number of true numbers and strings
#...    numfalse  - Number of false numbers and strings
#...    numall    - Total count
#...
#...Arguments
#...=========
#... $array_ref   Intent: in
#...              Perl type: reference to array
#...
#... $stat_ref    Intent: out
#...              Perl type: reference to stat hash
#...
#... $mask_ref    Intent: in
#...              Per type: reference to array
#...              if defined and mask[i] eq "" or "-", $array[i] = 0;
#...
#...Program Flow
#...============
#... 1) Compute stats
#............................................................................
sub my_array_stats{
    my(
        $array_in_ref,
        $stat_ref,
        $mask_ref
        ) = @_;
    my(
        $i, # loop variable
        @array, # new array to calculate on if given mask
        $array_ref, # pointer
        $num_elements, # number of elements in array
        $number_regexp,
        $number_skip,
        $val, # value of an array elem
        $val1, # value
        $val2, # value
        $val3,
        );

    $number_regexp = '[+-]?\.?[0-9]+\.?[0-9]*([eE][+-]?\d+)?';
    $number_skip = 8e99;

    #..........
    #...init...
    #..........
    undef( %{$stat_ref} );
    
    # deal with mask if given
    if( defined($mask_ref) ){
        for( $i = 0; $i <= $#{$array_in_ref}; $i++ ){
            if( $$mask_ref[$i] ne "-" && $$mask_ref[$i] ne "" ){
                $val = $$array_in_ref[$i];
            }
            else{
                $val = 0;
            }
            push( @array, $val );
        }
        $array_ref = \@array;
    }
    else{
        $array_ref = $array_in_ref;
    }

    $num_elements = $#{$array_ref};

    #...............
    #...init vals...
    #...............
    for( $i = 0; $i <= $num_elements; $i++ ){
        $val = $$array_ref[$i];
        if( defined( $val ) &&
            $val =~ /^$number_regexp$/ &&
            abs( $val ) < $number_skip ) {
            $$stat_ref{max}  = $val;
            $$stat_ref{min}  = $val;
            last;
        }
    }
    $$stat_ref{numall}    = $num_elements + 1;
    $$stat_ref{numntrue}  = 0;
    $$stat_ref{numnfalse} = 0;
    $$stat_ref{numnums}   = 0;
    $$stat_ref{numstrue}  = 0;
    $$stat_ref{numsfalse} = 0;
    $$stat_ref{numstrs}   = 0;
    $$stat_ref{numtrue}   = 0;
    $$stat_ref{numfalse}  = 0;
    $$stat_ref{mean}      = 0;
    $$stat_ref{sum}       = 0;
    $$stat_ref{sumsq}     = 0;

    #................................
    #...loop setting various stats...
    #................................
    for( $i = 0; $i <= $num_elements; $i++ ) {
        $val = $$array_ref[$i];
        if( defined( $val ) &&
            $val =~ /^$number_regexp$/ &&
            abs( $val ) < $number_skip ) {
            $$stat_ref{max}    = $$stat_ref{max} > $val ? $$stat_ref{max} : $val;
            $$stat_ref{min}    = $$stat_ref{min} < $val ? $$stat_ref{min} : $val;
            $$stat_ref{sum}   += $val;
            $$stat_ref{sumsq} += $val**2;
            $$stat_ref{numnums}++;
            if( $val != 0 ) {
                $$stat_ref{numntrue}++;
            }
        }
        else {
            $$stat_ref{numstrs}++;
            if( defined( $val ) && length( $val ) > 0 ) {
                $$stat_ref{numstrue}++;
            }
        }
    }
    $$stat_ref{numnfalse} = $$stat_ref{numnums}  - $$stat_ref{numntrue};
    $$stat_ref{numsfalse} = $$stat_ref{numstrs}  - $$stat_ref{numstrue};
    $$stat_ref{numtrue}   = $$stat_ref{numntrue} + $$stat_ref{numstrue};
    $$stat_ref{numfalse}  = $$stat_ref{numall}   - $$stat_ref{numtrue};

    #.......................
    #...delete if not set...
    #.......................
    if( $$stat_ref{numnums} == 0 ) {
        delete( $$stat_ref{mean} );
        delete( $$stat_ref{sum} );
        delete( $$stat_ref{sumsq} );
    }

    #...........................
    #...finish off some stats...
    #...........................
    if( $$stat_ref{numnums} > 0 ) {
        $$stat_ref{mean} = ($$stat_ref{sum})/$$stat_ref{numnums};
        $$stat_ref{range} = $$stat_ref{max} - $$stat_ref{min};
        $val1 = abs( $$stat_ref{min} );
        $val2 = abs( $$stat_ref{max} );
        $$stat_ref{maxabs} = $val1 > $val2 ? $val1 : $val2;
        if( $$stat_ref{numnums} > 0 ){
            $$stat_ref{rms} = ($$stat_ref{sumsq}/$$stat_ref{numnums}) ** .5
        }
        else{
            $$stat_ref{rms} = -1;
        }
        # todo: recalc this since not quite right (maybe if no nums)???
        if( $$stat_ref{numnums} > 1 ) {
            $$stat_ref{rmse} = 
                ( ( $$stat_ref{sumsq} -
                    $$stat_ref{numnums} * $$stat_ref{mean}**2 ) / $$stat_ref{numnums} ) ** .5;
            $$stat_ref{nrmse} = $$stat_ref{rmse};
            if( ($$stat_ref{max} - $$stat_ref{min}) != 0 ){
                $$stat_ref{nrmse} = $$stat_ref{nrmse} / ($$stat_ref{max} - $$stat_ref{min});
            }
        }
        else {
            $$stat_ref{rmse} = -1;
        }
        $val1 = abs( $$stat_ref{max} - $$stat_ref{mean} );
        $val2 = abs( $$stat_ref{min} - $$stat_ref{mean} );
        if( $val1 > $val2 ){
            $val3 = $val1;
        }
        else{
            $val3 = $val2;
        }
        $val3 = sqrt($val3);
        $$stat_ref{rmse_max} = $val3;
    }
    
    #.......................................................................
    #...rms - not used since slow - although less loss or arith precision...
    #.......................................................................
    #if( $$stat_ref{numnums} > 0 )
    #  {
    #    $$stat_ref{rms}  = 0;
    #    for( $i = 0; $i <= $num_elements; $i++ )
    #      {
    #        $val = $$array_ref[$i];
    #        if( $val =~ /^$number_regexp$/ && abs( $val ) < $number_skip )
    #          {
    #            $$stat_ref{rms} += ($val - $$stat_ref{mean})**2;
    #          }
    #      }
    #    if( $$stat_ref{$GNUMNUMS} > 1 )
    #      {
    #        $$stat_ref{$GRMS} =
    #          ((($$stat_ref{rms})**.5)/($$stat_ref{numnums}-1));
    #      }
    #    else
    #      {
    #        $$stat_ref{rms} = -1;
    #      }
    #  }
}

################################################################################

# compute an unsigned long checksum from a string
sub my_checksum_string{
    my(
        $string,  # string to create checksum for
        $digits,  # max number of digits
        ) = @_;
    my(
        $ret
        );
    # this is not a secure checksum - and I was hoping 
    $ret = substr( md5_hex($string), 0, 16 );
    $ret = Math::BigInt->new( "0x$ret" );
    if( defined( $digits ) ){
        $ret = substr( $ret, 0, $digits );
    }
    return( $ret );
}

# hex flavor (0x<return value>)
sub my_checksum_string_hex{
    my(
        $string,  # string to create checksum for
        $digits,  # max number of digits
        ) = @_;
    my(
        $ret
        );
    $ret = &my_checksum_string($string, 16);
    $ret = sprintf("%0${digits}x",$ret%(16**$digits));
}

########################################################################
# compare 2 version numbers:
#   op  == 1 -> returns ($ver_a > $ver_b)
# cat get ( "=" ) by ( not ">" and not "<" )
#
# Just split on non-digits (12.4.7 > 12 3 sub release 854 > 6.54 > .99999 )
# Currently, cannot handle 12a vs 12b
sub my_compare_version{
    my( $ver_a, $op, $ver_b ) = @_;
    my(
        @fields_a,
        @fields_b,
        $i,
        $num,
        $num_a,
        $num_b,
        $ret,
        );

    if( ! defined($ver_a) || $ver_a !~ /\S/ ){
        $ver_a = "0";
    }
    if( ! defined($ver_b) || $ver_b !~ /\S/ ){
        $ver_b = "0";
    }

    # This is used with raw module names to try to get the version.
    # Try to pull out things that might be in string but are not real
    # version numbers.
    #
    # Could fix at source in run_job.pl::find_modules() but easier to fix
    # in one place here...might need to adjust later...
    #
    # Need tight pattern-match so that real version numbers are not modded.
    # darwin p9 (power9):
    #    /smpi/p9/ -> /smpi/pNINE
    # There is a mixture of smpi and compiler version in the full name...
    # leave this in since do not know what part is actually used.
    #   ibm/smpi/p9/10.3.0.1-xlc-16.1.1.7-xlf-16.1.1.7-cuda-11.0
    $ver_a =~ s&/smpi/p9/&/smpi/pNINE/&;
    $ver_b =~ s&/smpi/p9/&/smpi/pNINE/&;

    # intel(stuff)/2022(stuff) -> intel(stuff)/(2 digits)(stuff)
    $ver_a =~ s&(intel.*/)20(\d\d)&$1$2&;
    $ver_b =~ s&(intel.*/)20(\d\d)&$1$2&;

    # now create version numbering array
    $ver_a =~ s/^\s+//;
    $ver_a =~ s/\s+$//;
    $ver_a =~ s/^\D+//;
    $ver_b =~ s/^\s+//;
    $ver_b =~ s/\s+$//;
    $ver_b =~ s/^\D+//;
    @fields_a = split( /\D+/, $ver_a );
    @fields_b = split( /\D+/, $ver_b );
    $num = $#fields_a;
    if( $num < $#fields_b ){
        $num = $#fields_b;
    }
    $ret = eval( "1 $op 1" );
    for( $i = 0; $i <= $num; $i++ ){
        # num_a,num_b
        # remove leading 0's (or would convert to octal)
        $num_a = $fields_a[$i];
        if( defined($num_a) ){
            $num_a =~ s/^0+//;
        }
        $num_b = $fields_b[$i];
        if( defined($num_b) ){
            $num_b =~ s/^0+//;
        }
        if( ! defined( $num_a ) || $num_a eq "" ){
            $num_a = 0;
        }
        if( ! defined( $num_b ) || $num_b eq "" ){
            $num_b = 0;
        }

        # and eval if not equal
        if( $num_a != $num_b ){
            return( eval( "$num_a $op $num_b" ) );
        }
    }
    $ret;
}

########################################################################
# NOT EXPORTED: need to have this in local scope to work - so just
#   copy/paste it into your code
# sort( my_compare_version_sort <array of values> )
sub my_compare_version_sort{
    &my_compare_version( $a, "<=>", $b );
}

################################################################################
# my_get_area
#   get the area of an entire 1d array
sub my_get_area{
    my(
       $x_ref, # X values
       $y_ref, # Y values
       $dx,    # if no X values, the dx to use for area of a point
       ) = @_;
    my(
       $area,
       $i,
       $max_i,
       );
    # compute area - just use trapezoidal rule
    $max_i = $#{$x_ref};
    if( $max_i == 0 ){
        if( ! defined($dx) ){
            $dx = 1;
        }
        $area = $$y_ref[0]*$dx;
    }
    else{
        for( $i = 0; $i < $max_i; $i++ ){
            $area += (($$y_ref[$i] + $$y_ref[$i+1])/2)*
                ( $$x_ref[$i+1] - $$x_ref[$i] );
        }
    }
    return( $area );
}

################################################################################
# my_get_area
#   get the area of an entire 1d array but shift the y axis so that
#   the minimum y values is 0
sub my_get_area_shift{
    my(
        $x_ref, # X values
        $y_ref, # Y values
        $dx,    # if no X values, the dx to use for area of a point
        ) = @_;
    my(
        $area,
        $i,
        $max_i,
        $y_min,
        );
    
    $max_i = $#{$x_ref};

    # find the minimum y value
    $y_min = $$y_ref[0];
    for( $i = 1; $i <= $max_i; $i++ ){
        if( $$y_ref[$i] < $y_min ){
            $y_min = $$y_ref[$i]
        }
    }

    # compute area - just use trapezoidal rule
    # if 1 point, area is just y*dx
    if( $max_i == 0 ){
        if( ! defined($dx) ){
            $dx = 1;
        }
        $area = $$y_ref[0]*$dx;
    }
    else{
        for( $i = 0; $i < $max_i; $i++ ){
            $area += ((($$y_ref[$i]-$y_min) + ($$y_ref[$i+1]-$y_min))/2)*
                ( $$x_ref[$i+1] - $$x_ref[$i] );
        }
    }
    return( $area );
}

###############################################################################
# my_get_area_segment
#   get the area of a segment of an array
#   Segment parts defined outside the area are assumed to be 0
sub my_get_area_segment{
    my(
       $x_ref,        # X values
       $y_ref,        # Y values
       $x_start,      # Starting X value
       $x_stop,       # Stopping X value
       $index_lo_ref, # index to start looking (to save time - will be set)
       ) = @_;
    my(
       $area,
       $dx_block,
       $dx_cur,
       $dy_block,
       $i,
       $index_hi,
       $x_cur_1,
       $x_cur_2,
       $x_cur_start,
       $x_cur_stop,
       $y_cur_1,
       $y_cur_2,
       $y_cur_start,
       $y_cur_stop,
       );

    # init 
    if( ! defined($$index_lo_ref) ){
        $$index_lo_ref = 0;
    }

    # find lo
    while( $$index_lo_ref <= $#{$x_ref} && $$x_ref[$$index_lo_ref] <= $x_start ){
        $$index_lo_ref++;
    }
    $$index_lo_ref--;

    # find hi
    $index_hi = $$index_lo_ref;
    while( $index_hi < $#{$x_ref} && $$x_ref[$index_hi] < $x_stop ){
        $index_hi++;
    }
    $index_hi--;

    # compute area
    $area = 0;
    for( $i = $$index_lo_ref; $i <= $index_hi; $i++ ){
        # starting point
        # below
        if( $$x_ref[$i] < $x_start  ){
            $x_cur_start = $$x_ref[$i];
            $x_cur_stop  = $$x_ref[$i+1];
            $y_cur_start = $$y_ref[$i];
            $y_cur_stop  = $$y_ref[$i+1];
            $dx_block = $x_cur_stop - $x_cur_start;
            $dy_block = $y_cur_stop - $y_cur_start;
            $dx_cur = $x_start - $x_cur_start;
            $x_cur_1 = $x_start;
            $y_cur_1 = $y_cur_start + $dy_block * ( $dx_cur / $dx_block );
        }
        # use whole block
        else{
            $x_cur_1 = $$x_ref[$i];
            $y_cur_1 = $$y_ref[$i];
        }

        # stopping point
        # between (could be at an end point due to rounding)
        if( $$x_ref[$i+1] > $x_stop  ){
            $x_cur_start = $$x_ref[$i];
            $x_cur_stop  = $$x_ref[$i+1];
            $y_cur_start = $$y_ref[$i];
            $y_cur_stop  = $$y_ref[$i+1];
            $dx_block = $x_cur_stop - $x_cur_start;
            $dy_block = $y_cur_stop - $y_cur_start;
            $dx_cur = $x_stop - $x_cur_start;
            $x_cur_2 = $x_stop;
            $y_cur_2 = $y_cur_start + $dy_block * ( $dx_cur / $dx_block );
        }
        # end (use whole block)
        else{
            $x_cur_2 = $$x_ref[$i+1];
            $y_cur_2 = $$y_ref[$i+1];
        }

        # increment area
        $area += ($x_cur_2-$x_cur_1)*(($y_cur_2+$y_cur_1)/2);
    }
    return( $area );
}

###################################################################################

# If this is a "batch" job, return its id.
# If not, return "".
# try various environment variables...assuming that if they are set, then
# the id is the job id number
# Finally, just return pid
# Sometimes, PBS_JOBID is not set for cielo, needed to add BATCH_JOBID
# For our machines, we want something that is moab friendly.
# On all other machines, you can get the MOAB id by taking the numbers
# of the environment variable.  On trinitite, they have MOAB_JOBID.
# But, on trinity they do not:
#     PBS_JOB = <pbs number>.<some stuff like "tr-drm1"
#     MOAB id = <some other number>
sub my_get_batch_id{
    my(
        $exe,
        $id,
        $out,
        );

    # snow/fire/ice:
    #   For BATCH jobs, SLURM_JOBID and MOAB_JOBID match...BUT for interactive jobs,
    #     SLURM_JOBID and MOAB_JOBID do not match!!! WOW!!!
    #   If we pick SLURM_JOBID first, that seems to work.
    #   Used for:
    #       mdiag jobid has SLURM_JOBID (run_status.pl -j $SLURM_JOBID)
    #       msub launching dependent jobs uses SLURM_JOBID
    $id =  $ENV{SLURM_JOBID} || $ENV{MOAB_JOBID} ||$ENV{PBS_JOBID} || $ENV{SLURM_JOB_ID} || $ENV{BATCH_JOBID} || $ENV{LSB_BATCH_JID} || $ENV{PALS_APID} ;

    # special hack for trinity until they make it easier
    # this will go away once they set MOAB_JOBID in the environment
    if( defined($id) && $id =~ /^[\d]+\.t[tr]\-/ ){
        # uses run_status.pl - so do not call from within run_status.pl
        if( $0 !~ /run_status\.pl/ ){
            $exe = &which_exec( "run_status.pl", QUIET=>"" );
            if( $exe =~ /\S/ ){
                $out = `$exe -j $id -k`;
                if( $out =~ /^\s*JOBID\s*=\s*(\d+)/i ){
                    $id = $1;
                }
            }
        }
    }

    # for cielito, PBS_JOBID was set to something that would cause moab "depend" to puke
    # remove junk around id
    if( defined($id) && $id =~ /^[\d]+\.c/ ){
        $id = &get_id_num($id);
    }

    # if in a container (charliecloud, docker), the batch id might have been
    # inherited from the parent process but is not really active.
    # charliecloud has this file (other ways to detect?)
    # At the time this is called, L_EAP_CONTAINER is not set...might need to
    # adjust that (run_status.pl).
    if( defined($id) ){
        if( -e "/WEIRD_AL_YANKOVIC" ){
          undef( $id );
	}
    }

    # if not set, return ""
    if( ! defined( $id ) ){
        $id = "";
    }
    return( $id );
}

########################################################################

sub date_ymdhms{
    my( $epoch_secs ) = @_;
    my( $date );
    if( defined( $epoch_secs ) ){
        $date = `date -d \@$epoch_secs +%Y%m%d%H%M%S`;
    }
    else{
        $date = `date +%Y%m%d%H%M%S`;
    }
    chomp( $date );
    return( $date );
}
sub date_ymdhms_sep{
    my( $epoch_secs ) = @_;
    my( $date );
    if( defined( $epoch_secs ) ){
        $date = `date -d \@$epoch_secs +%Y.%m.%d.%H.%M.%S`;
    }
    else{
        $date = `date +%Y.%m.%d.%H.%M.%S`;
    }
    chomp( $date );
    return( $date );
}

# tack on partial secs
sub date_ymdhms_sep_hr{
    my( $epoch_secs ) = @_;
    my( 
        $date,
        );
    if( defined( $epoch_secs ) ){
        $date = `date -d \@$epoch_secs +%Y.%m.%d.%H.%M.%S.%3N`;
    }
    else{
        $date = `date +%Y.%m.%d.%H.%M.%S.%3N`;
    }
    chomp( $date );
    return( $date );
}

# returns best guess at the numeric portion of a string id
# strips out non-digit stuff (useful for moab jobids)
# try to get the number portion of the jobid
sub get_id_num{
    my($id) = @_;
    my(
        $id_cur,
        $id_num_try,
        $id_num,
        );
    $id =~ s/\s+//g;
    $id_num = "";
    # if starts with digits, once you hit non-digits, drop rest
    if( $id =~ /^([0-9]+)/ ){
        $id_num = $1;
    }
    # otherwise, grab the largest contiguous block of digits
    else{
        $id_cur = $id;
        while( $id_cur =~ /(\d+)/ ){
            $id_num_try = $1;
            $id_cur =~ s/\d+//;
            if( length($id_num_try) > length($id_num) ){
                $id_num = $id_num_try;
            }
        }
    }
    # if nothing, just set to 0
    if( $id_num !~ /\S/ ){
        $id_num = 0;
    }
    return( $id_num );
}

########################################################################
# Get the id from a file (usually $RJ_FILE_ID_NEXT)
# Expanded to also get BATCHID from $RJ_FILE_ID file
sub get_rj_id_next{
    my(
        $filename,
        ) = @_;
    my(
        $done,
        $id_full,
        $try,
        );

    # will try a few times to get file
    $id_full = "";
    $try = 0;
    undef($done);
    while( ! defined($done) ){
        $try++;

        # get from file and remove trailing whitespace
        $id_full = `cat '$filename' 2> /dev/null`;
        # if not found, just set to blank (easier logic below)
        if( ! defined($id_full) ){
            $id_full = "";
        }
        $id_full =~ s/\s*$//;

        # RJ_FILE_ID_NEXT:
        # Know have full file if you see RJ_DONE at end of line.
        if( $id_full =~ /(\s+RJ_DONE)\s*$/ ){
            $id_full =~ s/(\s+RJ_DONE)\s*$//;
            last;
        }

        # RJ_FILE_ID
        # Guaranteed to have PID and LAST
        if( $id_full =~ /^\s*PID\s*=\s*/m &&
            $id_full =~ /^\s*LAST\s*=\s*1\s*$/m ){
            # might not have a batchid...exit this while regardless
            if( $id_full =~ /^\s*BATCHID\s*=\s*(\S+)/m ){
                $id_full = $1;
            }
            else{
                $id_full = "";
            }
            last;
        }

        # possible that rj_id file is incomplete so will have a bunch
        # of lines in it...
        # Could prune it...but leave it whole for now.  Will have
        # "Waiting:done" message long...

        # Existing jobs from old run_job.pl will not have line ender.
        # Just had user with old run with many jobs hang from this...
        # So do not try too many times and sleep for little.
        #
        # Since now look at rj_id file, need to try a few times.
        # With just rj_id_next, could get away with 1 time (1 echo).
        # Now try some with bit of throttle.
        # Waiting will also be done in run_job.pl::my_wait() so only
        # try again once.
        #   (was 10 tries at .5 seconds)
        if( $try >= 2 ){
            last;
        }

        # throttle
        &my_sleep(.2);
        # try to flush
        &my_file_flush( $filename );
    }

    # Could be problem if file created but invalid data
    #   filesystem full (so 0 sized file)
    #   job killed just at the moment file created
    # Set id_full to something so at least no hang.
    # This does happen.
    if( $id_full !~ /\S/ ){
        $id_full = "empty:$filename";
    }

    return( $id_full );

}

################################################################################
# my_interpolate: interpolate onto a regular DX
sub my_interpolate{
    my %args = (
                DX       => undef, # scalar dx to interpolate onto (DX or X_NEW)
                RESPONSE => undef, # if this is a response function (will make (0,0) point)
                VERBOSE  => undef, # if print messages
                SPACING  => "",    # spacing for VERBOSE
                X        => undef, # reference to x array
                X_NEW    => undef, # x array to interpolate onto (DX or X_NEW)
                Y        => undef, # reference to y array
                @_,
               );
    my(
       $area,
       $area_old,
       $delta_x,
       $i,
       $ierr,
       $dx,
       $index_hi,
       $index_lo,
       $key,
       $slope,
       $x_new,
       $x_new_ref,
       $x_now,
       $x_ref, # reset using $dx when done
       $x_start,
       $x_stop,
       $y_ref,
       @y_new, # interpolated array coppied into y_ref when done
       @x_new, # the new x array (if given dx)
       @x_tmp,
       @y_tmp,
       );

    #...invalid args
    foreach $key ( keys %args ){
        if( $key !~ /^(DX|RESPONSE|SPACING|VERBOSE|X|X_NEW|Y)$/){
            $ierr = 1;
            &print_error( "Invalid argument to my_interpolate [$key]",
                          $ierr );
            exit( $ierr );
        }
    }

    # readability
    $dx        = $args{DX};
    $x_ref     = $args{X};
    $x_new_ref = $args{X_NEW};
    $y_ref     = $args{Y};

    if( defined( $x_new_ref ) && defined( $dx) ||
        ( !defined( $x_new_ref ) && !defined( $dx)) ){
        $ierr = 1;
        &print_error( "Must define exactly 1 of DX or X_NEW",
                      $ierr );
        exit( $ierr );
    }
    if( !defined( $x_ref ) && !defined( $y_ref) ){
        $ierr = 1;
        &print_error( "Must define X and Y",
                      $ierr );
        exit( $ierr );
    }

    # dx > 0
    if( defined( $dx ) && $dx <= 0 ){
        $ierr = 1;
        &print_error( "DX [$dx] muxt be > 0",
                      $ierr );
        exit( $ierr );
    }

    # if response, put in (0,0) value if no value for x=0
    if( defined($args{RESPONSE}) && $$x_ref[0] != 0 ){
        unshift( @{$x_ref}, 0 );
        unshift( @{$y_ref}, 0 );
    }

    # area_old
    if( defined($args{VERBOSE}) ){
        $area_old = &my_get_area_shift( $x_ref, $y_ref, $dx );
    }

    # create x_new if given dx and point x_new_ref to it
    if( defined( $dx ) ){
        $x_start = $$x_ref[0];
        $x_now   = $x_start;
        $x_stop  = $$x_ref[-1];
        $i = 0;
        $x_new[$i] = $x_now;
        while( $x_now < $x_stop ){
            $i++;
            $x_now = $x_start + $dx * $i;
            $x_new[$i] = $x_now;
        }
        $x_new_ref = \@x_new;
    }

    if( defined($args{VERBOSE}) ){
        printf( "$args{SPACING}Interpolate: num_points_old=%d num_points_new=%d",
                $#{$x_ref}+1, $#{$x_new_ref}+1 );
        if( defined( $dx ) ){
            printf( "  dx=%.15e", $dx );
        }
        print "\n";
    }

    # create dummy flat array if only given 1 x_ref point
    if( $#{$x_ref} == 0 ){
        # will be constant y - so set x onto x_new
        $x_tmp[0] = $$x_new_ref[0];
        # pick next x to be the next x_new
        if( $#x_new_ref >= 1 ){
            $x_tmp[1] = $$x_new_ref[1];
        }
        # if only 1 x_new, set it so when subtract to get delta_x, get non-0 value
        # (x + 1 == x for x >> 0 [roundoff-error])
        # so that slope=dy/dx where dx!=0 (dy will be 0)
        else{
            $x_tmp[1] = 2*$x_tmp[0] + 1;
        }
        $y_tmp[0] = $$y_ref[0];
        $y_tmp[1] = $$y_ref[0];
        $x_ref = \@x_tmp;
        $y_ref = \@y_tmp;
    }

    # interpolate
    $index_lo = 0;
    for( $i = 0; $i <= $#$x_new_ref; $i++ ){

        # find index_lo/index_hi
        # index_lo: stop at 1 less than max index so that index_hi can be max index
        while( ($index_lo < $#$x_ref) &&
               $$x_ref[$index_lo] <= $$x_new_ref[$i] ){
            $index_lo++;
        }
        $index_lo--;
        if( $index_lo < 0 ){
            $index_lo = 0;
        }
        # index_hi is next point
        $index_hi = $index_lo + 1;

        # get y from line
        $slope = ($$y_ref[$index_hi] - $$y_ref[$index_lo])/
            ($$x_ref[$index_hi] - $$x_ref[$index_lo]);
        $delta_x = $$x_new_ref[$i] - $$x_ref[$index_lo];
        $y_new[$i] = $slope*$delta_x + $$y_ref[$index_lo];
    }

    # overwrite with new
    @{$y_ref} = @y_new;
    @{$x_ref} = @{$x_new_ref};

    # get new area
    if( defined($args{VERBOSE}) ){
        $area = &my_get_area_shift( $x_ref, $y_ref, $dx );
        printf( "$args{SPACING}  rel_area_error=%.2e\n",
                ($area_old - $area)/$area );
    }
    
}

################################################################################

sub get_jobinfo{
    my(
       $jobid,
       $jobinfo_ref,
       ) = @_;
    my(
       $cmd,
       $hosts,
       $output,
       );
    $cmd = "run_status.pl -j $jobid -k";
    $output = &run_command( COMMAND=>$cmd );
    $hosts = '';
    if( $output =~ /^\s*NODELIST\s*=\s*(\S+)/m ){
        $hosts = $1;
    }
    $$jobinfo_ref{hosts_string} = $hosts;
}

# Add some default dirs to the PATH.
#   Will prepend the path to the script being run.
#   This allows folks to run:
#     /path/to/run_job.pl
#   And use the other scripts that might be associated with that path:
#     /path/to/run_job_cleanup.pl
#     /path/to/run_status.pl
#     /path/to/ctf_process.pl
sub path_add_default{
    my(
        $debug,
        ) = @_;
    my(
        $dir,
        $path,
        $root1,
        $root2,
        $root3,
        );

    # dirs of this file and parents
    $root1 = &my_dir( __FILE__ );
    $root2 = &my_dir( $root1 );
    $root3 = &my_dir( $root2 );

    # init to loc of exec
    $dir = &my_dir( $0 );
    $path = "$dir";

    # loc of this file
    if( $root1 ne $dir ){
        $path .= ":$root1";
    }

    # loc <parent>/Environment
    if( -d "$root2/Environment" ){
        $path .= ":$root2/Environment";
    }

    # "." is not by default added
    # $path = ".:$path";

    # do not actually do anything if debug
    if( ! defined($debug) ){
        &my_munge( STRING_REF=>\$ENV{PATH}, PRE=>$path );
    }

    return( $path );

}

########################################################################
# get ldd info from an exec
# For the SO_ vars, can pass in undef or "" to have not defined.
sub my_ldd_info{
    my %args = (
        EXEC         => undef, # exec
        LDD_INFO     => undef, # ref to hash
        SO_KEEP      => undef, # so's to keep
        SO_KEEP_SKIP => undef, # so's to skip in keep list
        SO_SKIP      => undef, # so's to skip
        SO_SKIP_KEEP => undef, # so's to keep in skip list
        @_,
        );
    my $args_valid = "EXEC|LDD_INFO|SO_KEEP|SO_KEEP_SKIP|SO_SKIP|SO_SKIP_KEEP";
    my(
        $absolute,
        $arg,
        $dir,
        $file_from,
        $file,
        @files,
        $ierr,
        $ldd_info_ref,
        $line,
        @lines,
        $out,
        %processed,
        $so_keep,
        $so_keep_skip,
        $so_skip,
        $so_skip_keep,
       );

    # init
    $ierr = 0;

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # undef same as ""
    if( defined( $args{SO_KEEP} ) && 
        $args{SO_KEEP} =~ /\S/ ){
        $so_keep = $args{SO_KEEP};
    }
    if( defined( $args{SO_KEEP_SKIP} ) && 
        $args{SO_KEEP_SKIP} =~ /\S/ ){
        $so_keep_skip = $args{SO_KEEP_SKIP};
    }
    if( defined( $args{SO_SKIP} ) && 
        $args{SO_SKIP} =~ /\S/ ){
        $so_skip = $args{SO_SKIP};
    }
    if( defined( $args{SO_SKIP_KEEP} ) && 
        $args{SO_SKIP_KEEP} =~ /\S/ ){
        $so_skip_keep = $args{SO_SKIP_KEEP};
    }

    $ldd_info_ref = $args{LDD_INFO};
    if( ! defined($args{EXEC}) || ! defined($ldd_info_ref) ){
        $ierr = 1;
        &print_error( "my_ldd_info(EXEC=>, LDD_INFO=>)", $ierr );
        exit( $ierr );
    }

    $out = `ldd '$args{EXEC}' 2>&1`;
    @lines = split( /\n/, $out );
    foreach $line ( @lines ){

        # lines without "=>" in them have hardwired paths and seem
        # to never use LD_LIBRARY_PATH (and maybe internal rpath) even if
        # the lib is missing.
        # Do not skip them, but note that these are absolute-pathed
        undef( $absolute );
        if( $line !~ /\s+=>\s+/ ){
            $absolute = "";
        }

        if( $line =~ /([\/a-z]\S+)\s+\(0x/ ){
            $file_from = $1;
            # Do we want actual file?
            # If symlink, this will get actual final file...but for speed
            # do not do that.  Let calling prog call it if needed.
            #&my_stat( $file_from, \%stat );
            #$file_from = $stat{fullpath};
            if( defined($so_skip) &&
                $file_from =~ /$so_skip/ ){
                if( ! defined($so_skip_keep) ||
                    $file_from !~ /$so_skip_keep/ ){
                    next;
                }
            }
            if( defined($so_keep) &&
                $file_from !~ /$so_keep/ ){
                if( ! defined($so_keep_skip) ||
                    $file_from !~ /$so_keep_skip/ ){
                    next;
                }
            }

            if( defined($file_from) ){
                
                # mkl hack
                # If your $file_from is a mkl lib, add all mkl libs found in dir.
                # mkl apparently does some dynamic loading of other mkl libs during
                # the run (perhaps doing file ops) that is not shown in the ldd of
                # the of the lib/exec.
                # So, just add all mkl libs found in the dir.
                if( $file_from =~ m&/libmkl_[^/]*\.so[^/]*$& ){
                    $dir = &my_dir( $file_from );
                    if( ! defined( $processed{$dir} ) ){
                        $processed{$dir} = "";
                        @files = glob( "$dir/libmkl_*.so*" );
                        foreach $file ( @files ){
                            push( @lines, "mkl_hack => $file (0x)" );
                        }
                    }
                }

                $$ldd_info_ref{libs}{$file_from} = $args{EXEC};
                if( defined($absolute) ){
                    $$ldd_info_ref{absolute}{$file_from} = $args{EXEC};
                }
            }
        }
    }
}

########################################################################
# get a lockfile
#   Create a lockfile with some info that serves as a lockfile for other
#   calls to my_lockfile.
#
# See "help" below.
#
sub my_lockfile{
    my %args = (
                FH       => undef,    # If given a filehandle, just do flock (no writing).
                                      # The file will be created if it does not exist.
                                      # Passing filehandles through %args is strange...
                                      # Looks like flock() works and close() frees the
                                      # flock, but cannot write or read with it.
                                      # Can open a new filehandle on that file and write/read
                                      # with it then close it...then close the original one.
                                      # If you attempt the following, you get weird free error:
                                      #    $ierr = &my_lockfile(%args);
                                      #    $fh_FILE = $args{FH}
                                      #    print $fh_FILE "to file\n";  # error
                                      #    close( $fh_FILE ); # does free lock
                LOCKFILE => "./lockfile", # age of lockfile
                LOGNAME  => undef,    # if logname matches, override lockfile
                NOWAIT   => undef,    # if lockfile exists, do not wait, just return non-0
                QUIET    => undef,    # ""->nothing, "success"->only once successful
                REASON   => undef,    # additional string to put in lockfile
                TIME     => undef,    # time in seconds of maximum age of lockfile before forcing
                TYPE     => 2,        # 1 lockfile, 2 flock(), 3 homegrown (obsolete)
                RECURSE  => undef,    # if called from within my_lockfile
                WARNING  => undef,    # If error, just warn, not abort
                FORCE    => undef,    # will get the lockfile regardless
                HELP     => undef,    # reference to scalar if you want help message
                @_,
                );
    my $args_valid = "HELP|FH|FORCE|LOGNAME|LOCKFILE|NOWAIT|QUIET|REASON|RECURSE|TIME|TYPE|WARNING";
    my(
       $arg,
       $blow_away_string,
       $dir,
       $done,
       $exists,
       $flock_ret,
       $flock_errno,
       $fh_FILE,
       $getinfo_try,
       $grid,
       $group,
       $groups_regexp,
       $help_ref,
       $id_read,
       $ierr,
       $lockfile,
       %lockfile_info,
       %lockfile_info_new,
       $lockfile_dir,
       $lockfile_notdir,
       $lockfile_perm,
       $lockfile_tmp,
       $output,
       $sleep_min,
       %stat,
       $time,
       $time_honor,
       $time_s_written,
       $time_since_flock,
       $time_start,
       $uname,
       );

    # init
    $ierr = 0;
    $time_start = time();

    # sleep time to allow os to catch up and throttle
    # sleep time will be
    #   sleep_min + rand($sleep_min)
    # to have a value between sleep_min and 2xsleep_min
    $sleep_min = .02;

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # help
    if( defined($args{HELP}) ){
        $help_ref = $args{HELP};
        $$help_ref = <<'EOF';
#
# NOTE: lockfile contention on HPFS
#   If many processes are competing at the same time for a lockfile,
#   this might not work well.  Various 
#   flock/file-flushing/write-read-check/sleep calls are done to try and
#   minimize this...but filesystem buffering might cause multiple
#   processes to incorrectly obtain a lock at the same time.
#
#   In a test of N=20 simulaneous jobs competing for the same lock and
#   removing the lock N times:
#     local (/tmp):        seems to not fail
#     nfs   (~):           fairly reliable
#     HPFS  with  flock(): fairly reliable
#     HPFS  w/out flock(): (our lustre) can fail since flock()
#                           effectively not used.
#
#   However, our new lustre systems do not have file locking turned on.
#   So, the flock() call sets $! to "Function not implemented".  I check
#   for this string and just assume the lock was gotten.
#
#   You might want to place your lockfile on a non-HPFS filesystem.
#   You can also create multiple lockfile layers (lock your lockfile).
# 
EOF
    return($ierr);
    }

    $lockfile = $args{LOCKFILE};
    $time = $args{TIME};
    if( defined($time) && $time !~ /^\d+$/ ){
        $ierr = 1;
        &print_error( "TIME must be an integer number of seconds [$time]",
                      $ierr );
        exit( $ierr );
    }
    $uname = `uname`;
    $uname =~ s/\s+//g;

    $blow_away_string = "BLOW_AWAY: $$ $uname";

    # message
    if( ! defined( $args{QUIET} ) || $args{QUIET} !~ /^(|success)$/ ){
        print "my_lockfile $$ start ".&date_ymdhms_sep()." [$lockfile]\n";
    }

    # if given a FH, will just be trying to flock the file
    # file contents will not be modified
    # If a new file was created (forcing a lock, new file), a new filehandle
    # will be returned.
    if( defined $args{FH} ){
        &my_stat( $lockfile, \%stat );
        # if given an invalid FH, open a new one
        if( tell($args{FH}) == -1 ){
            if( %stat ){
                open( $args{FH}, "+< $args{LOCKFILE}" );
            }
            else{
                open( $args{FH}, "+> $args{LOCKFILE}" );
            }
            # if given an invalid FH, open a new one
            if( tell($args{FH}) == -1 ){
                $ierr = 1;
                &print_error( "Given FH but FH not open [$lockfile]",
                              $ierr );
                exit( $ierr );
            }
        }

        $time_honor = $time;
        if( ! defined($time_honor) ){
            $time_honor =  99999999; # default forever
        }

        # start the clock (used for forcing)
        $time_start = time();

        # while still trying to get lock
        undef( $done );
        while( ! defined($done) ){
            $flock_ret   = 0;
            undef($!);
            $flock_ret   = flock( $args{FH}, LOCK_EX|LOCK_NB );
            $flock_errno = $!;
            # on some machines, will always return "false" - just turn it to ok and pray
            # could instead try a couple of times then give up and just take the lock
            # anyways.
            # Filesystem oddness on trinitite....also ignore if get "unknown error 524"
            # if you got the lock
            if( $flock_ret == 1 || $uname eq "Darwin" ||
                (defined( $flock_errno ) && (
                     $flock_errno =~ /not implemented/i ||
                     $flock_errno =~ /unknown error 524/i ) ) ){
                if( ! defined( $args{QUIET} ) || $args{QUIET} =~ /^(success)$/ ){
                    print "my_lockfile $$ obtained ".&date_ymdhms_sep()." [$lockfile]\n";
                }
                $flock_ret = 1;
                $done = "true";
                next;
            }

            # just return if NOWAIT
            elsif( defined($args{NOWAIT}) ){
                $ierr = 1;
                return( $ierr );
            }

            # force the lock if enough time has passed
            if( time() - $time_start > $time_honor || defined( $args{FORCE} ) ){

                # put a lock around this - might not work...but try
                $lockfile_tmp = "$args{LOCKFILE}.tmp.lock";
                &my_lockfile( LOCKFILE=>$lockfile_tmp, QUIET=>"",
                              TIME=>120,
                              REASON=>"Forcing FH lockfile" );
                close( $args{FH} );
                if( ! defined( $args{QUIET} ) || $args{QUIET} !~ /^(|success)$/ ){
                    print "my_lockfile $$ forcing ".&date_ymdhms_sep()." [$lockfile]\n";
                }
                # get new stats - might have changed
                $ierr = &my_stat( $lockfile, \%stat );

                # if no size, just delete and open new one
                if( ! defined($stat{size}) || $stat{size} == 0 ){
                    if( ! defined( $args{QUIET} ) || $args{QUIET} !~ /^(|success)$/ ){
                        print "my_lockfile $$ new ".&date_ymdhms_sep()." [$lockfile]\n";
                    }
                    unlink($args{LOCKFILE});
                    open( $args{FH}, "+> $args{LOCKFILE}" );
                }

                # if has size, then copy, move, reset meta, and open new one
                else{
                    if( ! defined( $args{QUIET} ) || $args{QUIET} !~ /^(|success)$/ ){
                        print "my_lockfile $$ copying ".&date_ymdhms_sep()." [$lockfile]\n";
                    }
                    
                    copy( $args{LOCKFILE}, "$args{LOCKFILE}.$$") ||
                        die "my_lockfile: copy failed\n";
                    move( "$args{LOCKFILE}.$$", $args{LOCKFILE} ) ||
                        die "my_lockfile: move failed\n";
                    # if these fail, just continue
                    `chgrp $stat{group} '$args{LOCKFILE}'`;
                    chmod( $stat{mode}, $args{LOCKFILE} );
                    open( $args{FH}, "+< $args{LOCKFILE}" );
                }

                # remove the tmp lockfile
                unlink($lockfile_tmp);

                # reset clock to try again
                $time_start = time();
            }
        }

        return( $ierr );
    }

    # get some info about the lockfile and notdor
    $lockfile_notdir = &my_notdir( $lockfile );

    # get group name of parent directory
    $lockfile_dir = &my_dir( $lockfile );
    if( $lockfile_dir !~ /\S/ ){
        $lockfile_dir = "/";
    }
    $ierr = &my_stat( $lockfile_dir, \%stat );
    if( $ierr != 0 ){
        &print_error( "Cannot get info about: ",
                      "  parent directory [$lockfile_dir]",
                      "  of the lockfile  [$lockfile]",
                      "Lockfile not created", $ierr );
        exit( $ierr );
    }
    # Some parent directories might have a gid without a name
    # in this case, $group will be undefined (and no chgrp done)
    $group = $stat{group};

    # see if can set to this groups
    $groups_regexp = `groups 2>&1`;
    $groups_regexp =~ s/\s+/\|/g;
    if( defined( $group ) && $group !~ /^($groups_regexp)$/ ){
        undef( $group );
    }

    # set permissions for lockfile
    # if can set the group, then group write.
    # if not, then other write (so others can remove lockfile if needed)
    if( defined( $group ) ){
        $lockfile_perm = 0660;
    }
    else{
        $lockfile_perm = 0666;
    }

    # process lockfile
    $getinfo_try = 0;
    $time_since_flock = time();
    undef( $done );
    while( ! defined( $done ) ){

        # get $fh_FILE and note if it already existed or not
        undef( $exists );
        # file already exists - open it
        if( open( $fh_FILE, "+< $lockfile" ) ){
            $exists = "";
        }
        # file does not exist, create it and immediately put blow_away_string
        # later locks might not work - so want to have this in it for other
        # procs.
        elsif( open( $fh_FILE, "+> $lockfile" ) ){
            print $fh_FILE "$blow_away_string initial\n";
            $fh_FILE->flush();
            seek($fh_FILE, 0, 0);
        }
        # open failed for some reason (no write permission?)
        else{
            # ok...here is the strange thing.  When they brough trinitite back
            # under slurm, the filesytem was very odd.  It was sluggish and the
            # following would fail:
            #   rm file
            #   launch job
            #   launched job would access file
            # The rm would be slow in propagating to the compute node.  Odd things
            # would then happen to the permissions of the file - it would get created
            # with no permissions.  If the file was already there and just modified,
            # things seemed to work.  It was just the "rm <file>" + "create <file>".
            # This has been reported to the consultants.
            # Since lockfiles are used in this way (rm, create, rm, create, ... ),
            # If you detect that you should be able to write the lockfile, print this
            # warning and try to just chmod it.
            $dir = &my_dir( $lockfile );
            if( -w $dir ){
                $ierr = 0;
                &print_error( "Lockfile could not be opened for writing [$lockfile]...oddity...trying again",
                              "chmod $lockfile_perm $lockfile",
                              $ierr );
                chmod( $lockfile_perm, $lockfile );
                next;
            }
            else{
                $ierr = 1;
                &print_error( "Lockfile could not be opened for writing [$lockfile]",
                              $ierr );
                exit( $ierr );
            }
        }

        # at this point, have a valid $fh_FILE
        
        # non-blocking so that other procs go back to pool after this proc
        $flock_ret   = 0;
        undef($!);
        $flock_ret   = flock( $fh_FILE, LOCK_EX|LOCK_NB );
        $flock_errno = $!;

        # on some machines, will always return "false" - just turn it to ok and pray
        # could instead try a couple of times then give up and just take the lock
        # anyways.
        # Filesystem oddness on trinitite....also ignore if get "unknown error 524"
        # if you got the lock
        if( $flock_ret == 1 || $uname eq "Darwin" ||
            (defined( $flock_errno ) && (
                 $flock_errno =~ /not implemented/i ||
                 $flock_errno =~ /unknown error 524/i ) ) ){
            
            # file could have at that moment been created by other process
            # and it is still writing its BLOW_AWAY message
            if( $exists ){
                $fh_FILE->flush();
                &my_sleep( $sleep_min );
                $fh_FILE->flush();
            }

            # reset time_since_flock
            $time_since_flock = time();
                
            # get info about the lockfile
            $ierr = &my_lockfile_getinfo( $lockfile, \%lockfile_info, $time, $fh_FILE );
            $getinfo_try++;

            # lockfile_info will not be defined if size of lockfile > 0
            # but did not see valid strings in the lockfile.
            # This could mean the lockfile is actively being written and
            # will eventually finish (should not take long) or that the lockfile
            # is some file not recognized and should not be overwritten.
            # close to try again or error if too much time passed.
            if( $ierr != 0 && $getinfo_try > 100 ){
                &print_error( "lockfile [$lockfile] not recognized and will not overwrite it.",
                              "Valid files:",
                              "  size(lockfile)==0",
                              "  or expected format found:",
                              "     <keyword>: <value>",
                              "     ...(lines of this form)...",
                              "     <reason text>",
                              "Not overwriting lockfile and aborting.",
                              $ierr );
                exit( $ierr );
            }
            
            # no lockfile_info -> stat failed, just close and try again
            elsif( ! %lockfile_info ){
                close( $fh_FILE );
                &my_sleep( $sleep_min + rand($sleep_min) );
                next;
            }

            # successfully got it
            $getinfo_try = 0;

            # if exists and not BLOW_AWAY, check lockfile contents
            # BLOW_AWAY means that the lockfile was meant to be blown away
            # but there was some contention detected and "try again"
            if( ! defined($lockfile_info{BLOW_AWAY}) && defined( $exists ) ){

                # if first or new lockfile, remember it and print info about it
                if( ! %lockfile_info_new ||
                    $lockfile_info{lines_all} ne $lockfile_info_new{lines_all} ){

                    # remember it
                    %lockfile_info_new = %lockfile_info;

                    # if not quiet, print info about it
                    if( ! defined( $args{QUIET} ) || $args{QUIET} !~ /^(|success)$/ ){
                        %lockfile_info_new = %lockfile_info;
                        print "my_lockfile $$ lockfile_age [$lockfile_info{age} secs] lockfile_time_honor [$lockfile_info{time_honor} secs]\n";
                        $output = $lockfile_info{lines_all};
                        $output =~ s/\s*$//;
                        print "my_lockfile $$ \n";
                        print "my_lockfile $$ lockfile contents:\n";
                        print "my_lockfile $$ ------------------\n";
                        print "$output\n\n";
                    }
                }

                # past time_honor, will exit this if and overwrite file
                if( $lockfile_info{age} > $lockfile_info{time_honor} ||
                    defined( $args{FORCE} ) ){
                    if( ! defined( $args{QUIET} ) || $args{QUIET} !~ /^(|success)$/ ){
                        print "my_lockfile $$ FORCING age ($lockfile_info{age}) > time_honor ($lockfile_info{time_honor})\n";
                    }
                }

                # if matching logname
                elsif( defined( $args{LOGNAME} ) &&
                    $lockfile_info{LOGNAME} eq $ENV{LOGNAME} ){
                    print "my_lockfile $$ FORCING LOGNAME ($lockfile_info{LOGNAME})\n";
                }

                # not taking lock
                else{

                    # just return at this point if NOWAIT
                    if( defined($args{NOWAIT}) ){
                        close( $fh_FILE );
                        $ierr = 1;
                        return( $ierr );
                    }

                    # close to try again in case file got newly created/removed
                    close( $fh_FILE );
                    &my_sleep( $sleep_min + rand($sleep_min) );
                    next;
                }

            }

            # now at this point, this process should overwrite and create its
            # own lockfile (created one -or- past time_honor)
            
            # write/read pid as double check
            # Mark the lockfile as BLOW_AWAY so that even if fails read/write
            #   check, the lockfile is marked as getting blown away.
            seek($fh_FILE, 0, 0);
            truncate($fh_FILE, 0);
            print $fh_FILE "$blow_away_string\n";
            $fh_FILE->flush();
            seek($fh_FILE, 0, 0);
            $fh_FILE->flush();
            # perftry
            #&my_sleep( $sleep_min + rand($sleep_min) );
            #$fh_FILE->flush();
            $id_read = <$fh_FILE>;
            #todo: could also do a read from the system cat command to see if that
            #      matches if need be.
            if( defined($id_read) && $id_read eq "$blow_away_string\n" ){
                # this was the only process that wrote to the file
                $done = "true";
                next;
            }
            # try again later
            # sleep for a bit longer because if this happens, definitely
            # something strange happened
            close( $fh_FILE );
            &my_sleep( $sleep_min + rand($sleep_min) );
        }

        # did not get the lock, try again later
        else{

            # close to try again in case file got newly created/removed
            close( $fh_FILE );

            # broken flock - only if given a time
            # a "broken flock" is one where the time since the last
            # flock is more than the time given to wait
            if( defined( $time) && time() - $time_since_flock > $time ){
                if( ! defined( $args{QUIET} ) || $args{QUIET} !~ /^(|success)$/ ){
                    print "my_lockfile $$ Dead flock - unable to get flock in time=$time secs\n";
                    print "my_lockfile $$ Dead flock - deleting $lockfile\n";
                }
                unlink( $lockfile );
            }

            &my_sleep( $sleep_min + rand($sleep_min) );
            next;
        }
    }

    # now empty file
    seek($fh_FILE, 0, 0);
    truncate($fh_FILE, 0);
    chmod( $lockfile_perm, $lockfile );
    if( defined($group) ){
        # `chgrp $group $lockfile 2>&1`;
        $grid = getgrnam($group);
        chown( -1, $grid, $lockfile );
    }

    # put message into lockfile
    # if you modify this, modify valid_keywords in my_lockfile_getinfo
    $time_s_written = time();
    print $fh_FILE "LOGNAME: $ENV{LOGNAME}\n";
    print $fh_FILE "EXEC:    $0\n";
    print $fh_FILE "TYPE:    $args{TYPE}\n";
    print $fh_FILE "DATE:    ",&date_ymdhms_sep(),"\n";
    print $fh_FILE "TIME_S:  ",$time_s_written,"\n";
    if( defined($time) ){
        print $fh_FILE "TIME:    $time\n";
    }
    print $fh_FILE "PID:     ",$$,"\n";
    print $fh_FILE "PGID:    ",getpgrp(),"\n";
    print $fh_FILE "UNAME:   ",`uname -n`,"\n";
    if( defined( $args{REASON} ) ){
        print $fh_FILE $args{REASON},"\n";
    }
    $fh_FILE->flush();
    # perftry
    #&my_file_flush( $lockfile );

    close( $fh_FILE );
    # perftry
    #&my_file_flush( $lockfile );

    # got it - message
    if( ! defined( $args{QUIET} ) || $args{QUIET} =~ /^(success)$/ ){
        print "my_lockfile $$ obtained  ".&date_ymdhms_sep()." [$lockfile]\n";
        print "\n";
    }

    return( $ierr );

}

########################################################################
# my_lockfile_getinf
# info about the lockfile
# key => scalar value (needs to be scalar due to coppies done elseqhere)
sub my_lockfile_getinfo{
    my(
        $lockfile,
        $info_ref,
        $time_in,
        $fh_FILE,
        ) = @_;
    my(
        $valid_keywords,
        $ierr,
        $line,
        @lines,
        %stat,
        );

    $ierr = 0;

    # reset
    undef( %{$info_ref} );

    $fh_FILE->flush();
    
    # stat the lockfile
    &my_stat( $lockfile, \%stat );

    # should not happen since fh_FILE should be a valid locked filehandle
    # will return an undefined info_ref which my_lockfile will try again.
    if( ! %stat ){
        return( $ierr );
    }

    # process the lines
    $valid_keywords = "DATE|EXEC|LOGNAME|PID|TIME|TIME_S|TYPE|UNAME";
    @lines = <$fh_FILE>;
    foreach $line ( @lines ){
        if( $line =~ /^TIME_S:\s+(\d+)\n$/m ){
            $$info_ref{TIME_S} = $1;
            $$info_ref{age} = time() - $$info_ref{TIME_S};
        }
        elsif( $line =~ /^(BLOW_AWAY):\s+(.*?)\n$/m ){
            $$info_ref{$1} = $2;
        }
        elsif( $line =~ /^(${valid_keywords}):\s+(\S+)\n*$/m ){
            $$info_ref{$1} = $2;
        }
        else{
            # can skip rest of parsing since not key=value (just lock reason)
            last;
        }
    }

    # if the lockfile has size but does not have any key/value pairs
    # something went wrong and should stop (lockfile given might not be
    # a simple lockfile and do NOT want to clobber it).
    # So, return a silent error and let my_lockfile() deal with it.
    if( $stat{size} > 0 && ! %{$info_ref} ){
        $ierr = 1;
        return( $ierr );
    }

    # finish age
    # mtime_since should exist since &my_stat succeeded
    if( ! defined( $$info_ref{age} ) ){
        $$info_ref{age} = $stat{mtime_since};
    }

    if( ! defined( $$info_ref{PID} ) ){
        $$info_ref{PID} = "";
    }
        
    # default time_honor
    # if given time arg, default to that
    if( defined( $time_in ) ){
        $$info_ref{time_honor} = $time_in;
    }
    # otherwise, default to forever
    else{
        $$info_ref{time_honor} = 99999999;
    }
    # if found a TIME in the file, use that
    if( defined( $$info_ref{TIME} ) ){
        $$info_ref{time_honor} = $$info_ref{TIME};
    }

    # store all the lines into info_ref for printing later
    $$info_ref{lines_all} = join("", @lines );
    if( ! defined($$info_ref{lines_all}) ){
        $$info_ref{lines_all} = "";
    }

}

########################################################################
# my_log
#   Do the following special cases:
#     log(small)  = next valid value
#     log(-y)     = -log(y)
sub my_log{

    my %args = (
        Y => undef,
        @_,
        );
    my $args_valid = "Y";
    my(
        $arg,
        $i,
        $ierr,
        $res,
        $sign,
        $skipped,
        $val,
        $y_ref,
        $y_valid,
        );

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    $y_ref = $args{Y};

    # go through first pass (skip small for now)
    for( $i = 0; $i <= $#$y_ref; $i++ ){
        $val = $$y_ref[$i];
        $sign = 1;
        $res = "";
        # skip - will fill later
        if( $val == 0 || abs($val) < 1e-15 ){
            $skipped = "";
        }
        else{
            if( $val < 0 ){
                $sign = -1;
                $val  = -$val;
            }
            if( $val > 0 ){
                $res = $sign * log($val);
            }
            # keep track of first valid value
            if( ! defined($y_valid) ){
                $y_valid = $res;
            }
        }
        $$y_ref[$i] = $res;
    }

    # now fill skipped
    if( defined($skipped) ){
        # if no valid values, will be 0 everywhere
        if(! defined($y_valid) ){
            $y_valid = 0;
        }
        # go through first pass (skip small for now)
        for( $i = 0; $i <= $#$y_ref; $i++ ){
            if( $$y_ref[$i] eq "" ){
                $$y_ref[$i] = $y_valid;
            }
            else{
                $y_valid = $$y_ref[$i];
            }
        }
    }

}

########################################################################
# create tar file of scripts/files needed to run this and friends
sub my_packit{
    my %args = (
                DIR          => undef,
                NAME         => undef,
                PACKIT_FILES => undef,
                PACKIT_GROUP => undef,
                CP           => undef, # do cp instead of create tar file
                DEBUG        => undef, # just say what will do
                @_,
               );
    my( $valid_args ) = "CP|DEBUG|DIR|NAME|PACKIT_FILES|PACKIT_GROUP";

    my(
        $dir,
        $com,
        @dirs_search,
        $file,
        $filename,
        $filename_use,
        $packit_group,
        $dir_use,
        @files,
        %files_hash,
        $ierr,
        $key,
        $out,
        $packit_dir,
        $packit_name,
        $packit_files_ref,
        $root,
        %stat,
        $tarfile,
        );

    #...invalid args
    foreach $key ( keys %args ) {
        if( $key !~ /^($valid_args)$/) {
            $ierr = 1;
            &print_error( "Invalid arg [$key]",
                          "Valid args: $valid_args",
                          $ierr );
            exit( $ierr );
        }
    }

    $packit_dir       = $args{DIR};
    $packit_name      = $args{NAME};
    $packit_files_ref = $args{PACKIT_FILES};
    $packit_group     = $args{PACKIT_GROUP};

    if( ! defined($packit_dir) ||
        ! defined($packit_name) ||
        ! defined($packit_files_ref) ){
            $ierr = 1;
            &print_error( "Missing args ($valid_args)",
                          "Valid args: $valid_args",
                          $ierr );
            exit( $ierr );        
    }

    # first: current directory
    ($dir = $0) =~ s&/+[^/]*$&&;
    &my_stat( $dir, \%stat );
    $dir = $stat{fullpath};
    push( @dirs_search, $dir );

    # add in @INC (assume this has been pushed onto list)
    push( @dirs_search, @INC );

    # if this directory is from a checkout, add the other dirs
    # of the checkout
    if( $dir =~ m&Tools.*/General& ){
        ($root = $dir) =~ s&/Tools.*/General&&;
        push( @dirs_search, glob("$root/Tools*/General") );
        push( @dirs_search, glob("$root/Tools*/Environment") );
    }

    # now go through packit_files_ref and push into files_hash
    foreach $filename ( keys %{$packit_files_ref} ) {
        foreach $dir ( @dirs_search ){
            @files = glob("$dir/$filename");
            foreach $file ( @files ){
                if( $file !~ /\*/ &&
                    $file !~ /\~$/ &&
                    $file !~ /.orig$/ ){
                    # use "-r"/readable to skip over protected files
                    if( -r $file ){
                        $filename_use = &my_notdir( $file );
                        $dir_use      = &my_dir(    $file );
                        # first one wins
                        if( ! defined($files_hash{$filename_use}) ){
                            $files_hash{$filename_use} = $dir_use;
                        }
                    }
                }
            }
        }
    }

    # create tar file
    $tarfile = "$packit_dir/$packit_name.tar";
    &my_stat_guess( $tarfile, \%stat );
    $tarfile = $stat{fullpath};
    print "packit:\n";
    if( defined($args{DEBUG}) ){
        print "  DEBUG\n";
    }
    if( %files_hash ){
        if( defined( $args{CP} ) ){
            print "  Installing: $packit_dir\n";
        }
        else{
            print "  Creating: $tarfile\n";
        }
        print "  Processing:\n";
        unlink( $tarfile );
        foreach $filename ( sort keys %files_hash ){
            $dir = $files_hash{$filename};
            # check group if given
            if( defined($packit_group) ){
                &my_stat( "$dir/$filename", \%stat );
                if( $packit_group !~ /,$stat{group},/){
                    next;
                }
            }
            print "    $filename from\n      $dir\n";
            if( ! defined( $args{DEBUG} ) ){
                if( defined( $args{CP} ) ){
                    $com = "cp -p $dir/$filename $packit_dir";
                }
                else{
                    $com = "tar -C '$dir' -rhpf '$tarfile' '$filename'";
                }
                $out = `$com 2>&1`;
                if( $out =~ /\S/ ){
                    print "output: $out\n";
                }
            }
        }
    }
    else{
        print "  No files found...probably an error\n";
    }
    print "\n";

}

########################################################################
# my_convolve
#   convolve 2 arrays together
#   assumed 2 equally spaced arrays
#   in the future, will add Y and Y_RESPONSE 
sub my_convolve{
    my %args = (
                DX => undef,
                Y => undef,
                IN_TYPE => "array",
                RESPONSE => undef,
                RESPONSE_TYPE => "array",
                PAD => "",
                @_,
        );
    my $args_valid = "DX|IN_TYPE|PAD|RESPONSE|RESPONSE_TYPE|Y";
    my(
        $arg,
        $dx,
        $i,
        $i_in,
        $ierr,
        $j,
        $max_index,
        @out,
        $response_ref,
        @segment,
        $valid_types,
        $y_ref,
        @y_tmp,
       );

    # init
    $ierr = 0;

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # checks
    $valid_types = "array|response";
    if( $args{IN_TYPE} !~ /^($valid_types)$/ ){
        $ierr = 1;
        &print_error( "Invalid type [$args{IN_TYPE}] !~ /($valid_types)/",
                      $ierr );
        exit( $ierr );
    }
    if( $args{RESPONSE_TYPE} !~ /^($valid_types)$/ ){
        $ierr = 1;
        &print_error( "Invalid type [$args{RESPONSE_TYPE}] !~ /($valid_types)/",
                      $ierr );
        exit( $ierr );
    }

    if( ! defined($args{DX}) ){
        $ierr = 1;
        &print_error( "Must define DX",
                      $ierr );
        exit( $ierr );
    }

    $dx = $args{DX};
    $y_ref = $args{Y};
    $response_ref = $args{RESPONSE};

    # pad with 0 by default for single data points
    if( $args{PAD} eq "" ){
        if( $#$y_ref == 0 ){
            $args{PAD} = "zero";
        }
    }

    # pad if needed
    if( $args{PAD} ne "" ){
        @y_tmp = @{$y_ref};
        if( $args{PAD} eq "zero" ){
            @segment = (0) x $#$response_ref;
        }
        elsif( $args{PAD} eq "same" ){
            @segment = ($$y_ref[-1]) x $#$response_ref;
        }
        else{
            $ierr = 1;
            &print_error( "Invalid pad [$args{PAD}] !~ /(zero|same)/", $ierr );
            exit( $ierr );
        }
        push( @y_tmp, @segment );
        $y_ref = \@y_tmp;
    }

    # convolve for this response function
    # chop off at original time
    # still signal out there to drain from out, but no valid to set
    # "false" in signal to 0
    #$max_index = $#$y_ref + $#$response_ref;
    $max_index = $#$y_ref;
    # still signal out there to drain into out
    $#out = $max_index;
    for( $i = 0; $i <= $max_index; $i++ ){
        for( $j = 0; $j <= $#$response_ref; $j++ ){
            $i_in = $i - $j;
            if( $i_in >= 0 && $i_in <= $#$y_ref ){
                $out[$i] += $$y_ref[$i_in]*$$response_ref[$j]*$dx;
            }
        }
    }
    @{$args{Y}} = @out;
}

#............................................................................
#...Name
#...====
#... my_mode
#...
#...Purpose
#...=======
#... Various mode <-> umask settings depending on in Returns a string of the correct mode given a umask setting
#...   if UMASK => return mode
#...   if MODE  => umask
#...
#............................................................................
sub my_mode{
    my %args = (
        DEC    => undef,  # return decimal flavor (otherwise octal flavor)
        DIR    => undef,  # print mode of dir given the umask (or input mode is dir)
        EXEC   => undef,  # if exec permission also           (or input mode file has exec)
        UMASK  => undef,  # umask setting (will default to current) - must be decimal "%lo"
        MODE   => undef,  # input dec mode of a directory/file (DIR/EXEC above), output umask
        @_,
        );
    my $args_valid = "DEC|DIR|MODE|EXEC|UMASK";
    my(
        $arg,
        $i,
        $ierr,
        $mode,
        $mode_dp,
        $ret,
        $val,
        );
    
    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # default umask
    if( ! defined($args{UMASK}) ){
        $args{UMASK} = sprintf( "%lo", umask());
    }

    # MODE - return umask
    if( defined($args{MODE}) ){
        # given dir
        if( defined($args{DIR}) ){
            # just the last 4 digits
            $mode_dp = substr($args{MODE}, -4, 4);

            $ret = oct("2777") - oct($mode_dp);
        }
        # given file
        else{
            # if an executable
            if( oct("111") & oct($args{MODE}) ){
                $ret = oct("777") - oct($args{MODE});
            }
            # not an exec - treat as if exec and subtract from 777
            #   640 -> 750
            else{
                $mode = $args{MODE};
                for( $i = 0; $i < length($mode); $i++ ){
                    $val = substr($mode,$i,1);
                    if( $val ne "0" ){
                        substr($mode,$i,1) = $val + 1;
                    }
                }
                $ret = (oct("777") - oct($mode));
            }
        }
    }

    # return mode
    else{

        # mode of dir
        if( defined($args{DIR} ) ){
            $ret = oct("2777") - oct($args{UMASK});
        }
        
        # mode of file
        else{
            # mode of file with exec permissions
            $ret = oct("777") - oct($args{UMASK});
            # if not an exec
            if( ! defined($args{EXEC}) ){
                $ret &= oct("666");
            }
        }
    }
    
    # decimal flavor
    if( defined($args{DEC}) ){
        $ret = sprintf( "%lo", $ret );
    }
    
    # return
    return( $ret );
}

#............................................................................
#...Name
#...====
#... my_munge
#...
#...Purpose
#...=======
#... Takes a : delimited string, perpends or postpends args, and removes any duplicates
#...
#............................................................................
sub my_munge{
    my %args = (
                STRING_REF  => undef, # inout ref to string
                PRE         => undef, # pre
                PST         => undef, # pst
                DELETE      => undef, # if deleting
                EXIST       => undef, # check existance of all paths
                @_,
                );
    my(
       $ierr,
       $arg,
       );
    my $args_valid = "DELETE|EXIST|PST|PRE|STRING_REF";
    my(
       %del,
       $pre,
       $pst,
       %seen,
       $string_ref,
       $val,
       @vals,
       @vals_res,
       );
    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    $string_ref = $args{STRING_REF};
    $pre = $args{PRE};
    $pst = $args{PST};

    # if deleting
    if( defined( $args{DELETE} ) ){
        # pre = delete
        undef( @vals );
        if( defined($pre) ){
            push( @vals, split( /\s*:\s*/, $pre ) );
        }
        
        # stuff into hash and reset pre to empty
        foreach $val ( @vals ){
            $del{$val} = "";
        }
        $pre = "";
    }
    
    # create full @vals
    undef( @vals );
    # pre
    if( defined($pre) ){
        push( @vals, split( /\s*:\s*/, $pre ) );
    }
    # string
    push( @vals, split( /\s*:\s*/, $$string_ref ) );
    # post
    if( defined($pst) ){
        push( @vals, split( /\s*:\s*/, $pst ) );
    }
    
    foreach $val ( @vals ){
        # skip if already seen
        if( defined( $seen{$val} ) ){
            next;
        }
        $seen{$val} = "";

        # skip nulls
        if( $val !~ /\S/ ){
            next;
        }

        # skip if del
        if( defined( $del{$val} ) ){
            next;
        }

        # skip if not exist
        if( defined($args{EXIST}) ){
            if( ! -e $val ){
                next;
            }
        }

        # add
        push( @vals_res, $val );
    }
    $$string_ref = join( ":", @vals_res );
}

#............................................................................
#...Name
#...====
#... get_pname
#...
#...Purpose
#...=======
#... Try to determine the problem name given the files in the directory.
#... Returns the problem name (or '')
#...
#...Arguments
#...=========
#... $dir      Intent: in
#...           Perl type: scalar
#...           directoryt path to look
#...
#............................................................................
sub get_pname{
  my(
     $dir,
     ) = shift(@_);
  my %args = (
              INFILE  => undef,
              @_,
              );
  my $args_valid = "INFILE";
  my(
     $arg,
     $age, # age in seconds
     $file,
     @files_all,
     @files_all_sort,
     $ierr,
     $line,
     @lines,
     $line_new,
     @lines_new,,
     $max,
     $output,
     $pname,
     $pname_guess,
     $pname_run_job,
     $pname_rj_cmd_out,
     $pname_rj_cmd_out_env,
     $run_job_file,
     @run_job_files,
     %seen,
     %seen_type,
     %stat,
     $type,
    );
  # args
  foreach $arg ( keys %args ){
      if( $arg !~ /^$args_valid$/ ){
          $ierr = 1;
          &print_error( "Invalid argument [$arg]",
                        "Valid args [$args_valid]",
                        $ierr );
          exit( $ierr );
      }
  }

  # init to none
  $pname = "";

  # no dir, just return
  if( ! defined($dir) ) {
      return( $pname );
  }

  # get pname_run_job from run_job.<shell> file
  # find run_job_file name
  $pname_run_job = "";
  $run_job_file = "";
  @run_job_files = glob( "$dir/run_job.*");
  foreach $file ( @run_job_files ){
      if( $file =~ /\.(bash|csh|sh|tcsh)$/ ){
          $run_job_file = $file;
          last;
      }
  }

  # look through run_job_file for input file then get pname from that
  if( -e "$run_job_file" ){
      $output = `egrep -a 'RJ_CMD_PRUN.*\.in*' '$run_job_file' 2> /dev/null`;
      # put last first to find the last occurrence
      @lines = reverse split( /\n/, $output );
      foreach $line ( @lines ){
          
          # skip commented out lines
          if( $line =~ /^\s*\#/ ){
              next;
          }
          
          # get RJ_CMD_PRUN line, grab input file, look for pname setting
          if( $line =~ /RJ_CMD_PRUN.*\s(\S+\.in\S*)/ ){
              $file = $1;
              $file =~ s/[\'\"]//g;
              if( $file !~ /^\// ){
                  $file = "$dir/$file";
              }
              if( -e "$file" ){
                  $output = `egrep -a '^[ \t]*pname[ \t]*=' '$file'`;
                  @lines_new = reverse split( /\n/, $output );
                  foreach $line_new ( @lines_new ){
                      if( $line_new =~ /^\s*pname\s*=\s*['"](\S+?)["']/ ){
                          $pname_run_job = $1;
                          # skip any variable setting
                          if( $pname_run_job =~ /\$/ ){
                              $pname_run_job = "";
                          }
                          else{
                              last;
                          }
                      }
                  }
                  # found from previous foreach - exit loop
                  if( $pname_run_job =~ /\S/ ){
                      if( defined($args{INFILE}) ){
                          (${$args{INFILE}} = $file) =~ s/\.\///g;
                      }
                      last;
                  }
              }
          }
      }
  }

  # get pname_rj_cmd_out, pname_rj_cmd_out_env
  $pname_rj_cmd_out = "";
  $pname_rj_cmd_out_env = "";
  if( -e "$dir/rj_cmd_out" ){
      # Look for things that define pname.

      # The first "Open output file:" can be for generating
      # the teos.out file (or merge or something).
      # Look at the first set of lines only (or else large files
      # take forever to process).  Hit a case where "grep -m 2" was
      # still looking at the whole output file since only 1 line there.
      $output = `head -n 10000 '$dir/rj_cmd_out' 2> /dev/null | egrep -a "Open output file:|ENV RJ_VAR_PNAME ="`;
      if( defined($output) ){
          # put last first to find the last occurrence
          $output = join ( "\n", reverse split( /\n/, $output ) );
          if( $output =~ /Open output file:\s*(\S+)-output\b/ ){
              $pname_rj_cmd_out = $1;
          }

          # and look for command/run_job.csh line setting
          if( $output =~ /ENV RJ_VAR_PNAME =\s*(\S+.*)/ ){
              $pname_rj_cmd_out_env = $1;
              $pname_rj_cmd_out_env =~ s/\s+$//;
          }

      }

  }

  # rj_cmd_out is new and it has pname in it, use that.
  # Users might modify input file while job is running.
  # In that case, the cleanup should use the one from the running
  # job.
  if( $pname !~ /\S/ ){
      if( -e "$dir/rj_cmd_out" ){
          $age = -M "$dir/rj_cmd_out";
          $age *= 24 * 3600;
      }
      else{
          $age = 1e10; # roundoff sometimes gives negative age - so make large
      }
      if( $age <= 5 && $pname_rj_cmd_out =~ /\S/ ){
          $pname = $pname_rj_cmd_out;
      }
  }

  # get pname from run_job.<shell> -> input file
  if( $pname !~ /\S/ && $pname_run_job =~ /\S/ ){
      $pname = $pname_run_job;
  }

  # get from names of files
  if( $pname !~ /\S/ ) {
      # skip silently if cannot get into directory
      if( ! opendir(DIR, $dir) ) {
          $ierr = 0;
          # just name it the directory name
          $pname = &my_notdir( $dir );
          return( $pname );
      }
      @files_all = grep ! /^\.\.?$/, readdir( DIR );
      closedir( DIR );
      # full path name for sorting
      # if cannot get time, set time to large number so it will be last (soft link pointing to nowhere)
      # do not try if too many files in this directory
      if( $#files_all < 2000 ){
          @files_all_sort = sort { (-M "$dir/$a"||9999) <=> (-M "$dir/$b"||9999) } @files_all;
      }
      undef( %seen );
      undef( %seen_type );
      foreach $file ( @files_all_sort ) {
          # these files will have -output in the name but should be skipped
          if( $file =~ /^gold_/ ||
              $file =~ /^cts_diff\./ ){
              next;
          }
          # if file is of a certain type (pname)-(type)
          if( $file =~ /^(\S+)\-(build|dmp|editmix|history|lastcycle|lastdump|output|problemsize|status|DO_NOT_RUN)/ ){
              $pname_guess = $1;
              $type = $2;
              # only get last created file of a certain type
              if( defined( $seen_type{$type} ) ){
                  next;
              }
              $seen_type{$type} = '';
              # add it to the count seen for that pname
              if( ! defined($seen{$pname_guess}) ) {
                  $seen{$pname_guess} = 0;
              }
              $seen{$pname_guess}++;
          }
      }
      # pick one with the highest number of files
      $max = 0;
      foreach $pname_guess ( keys %seen ) {
          if ( $seen{$pname_guess} > $max ) {
              $pname = $pname_guess;
              $max = $seen{$pname_guess};
          }
      }
  }

  # get from $pname_rj_cmd_out_env
  if( $pname !~ /\S/ && $pname_rj_cmd_out_env =~ /\S/ ){
      $pname = $pname_rj_cmd_out_env;
  }
  
  # get from env var
  if( $pname !~ /\S/ ){
      if( defined($ENV{RJ_VAR_PNAME}) ){
          $pname = $ENV{RJ_VAR_PNAME};
      }
  }

  # get from last directory name
  if( $pname !~ /\S/ ){
      &my_stat( $dir, \%stat );
      if( defined($stat{notdir}) ){
          $pname = $stat{notdir};
      }
  }
  return( $pname );
}

###########################################################################
 
# array_to_range
# takes an array of strings and compresses it using perl range operators
#   "a09","ml10","ml2","ml1","ml2","ml3","ml005","a10" -> "a[09-10];ml[001-003,005,010]"
sub array_to_range{
    my(
        $array_ref,
        ) = @_;
    my(
        $len_cur,
        $len_max,
        $len_maxs,
        $num,
        $num_consecutive,
        $num_previous,
        $num_range,
        $num_start,
        $prefix,
        %prefix_nums,
        %prefix_nums_new,
        $range,
        $ret,
        $val,
        );

    $ret = "";

    # for now, assume <prefix><num>, but could make more sophisticated
    foreach $val ( @{$array_ref} ){
        if( $val =~ /^(.*?)(\d+)$/ ){
            $prefix = $1;
            $num = $2;
            if( ! defined( $prefix ) ){
                $prefix = "";
            }
            $prefix_nums{$prefix}{$num} = "";;
        }
    }

    # find maximum digit length foreach prefix (for leading 0s)
    foreach $prefix ( keys %prefix_nums ){
        $len_max = 0;
        foreach $num ( keys %{$prefix_nums{$prefix}} ){
            $len_cur = length( $num );
            if( $len_cur > $len_max ){
                $len_max = $len_cur;
            }
        }
        $len_maxs{$prefix} = $len_max;
    }

    # now only have non-0-leading nums stored
    foreach $prefix ( keys %prefix_nums ){
        foreach $num ( keys %{$prefix_nums{$prefix}} ){
            $num = $num*1;
            
            $prefix_nums_new{$prefix}{$num} = "";
        }
    }
    %prefix_nums = %prefix_nums_new;

    foreach $prefix ( sort keys %prefix_nums ){
        $num_previous = "";
        $num_range = "no";
        $range = "";
        $len_max = $len_maxs{$prefix};

        # end with $num="" to finish off sequence
        foreach $num ( sort( my_numerically keys %{$prefix_nums{$prefix}} ), "" ){
            if( $num_previous =~ /^\d+$/ ){
                $num_consecutive = $num_previous + 1;
            }
            else{
                $num_consecutive = "none";
            }
            # if consecutive
            if( $num eq $num_consecutive ){
                # if first one
                if( $num_range eq "no" ){
                    $num_range = "yes";
                    $num_start = $num_previous;
                }
            }
            # no longer consecutive
            else{
                if( $num_range eq "yes" ){
                    $range .= sprintf( "%0${len_max}d-%0${len_max}d,", $num_start,$num_previous );
                }
                elsif( $num_previous ne "" ){
                    $range .= sprintf( "%0${len_max}d,", $num_previous );
                }
                $num_range = "no";
            }
            $num_previous = $num;
        }
        $range =~ s/,$//;
        $ret .= $prefix;
        if( $range =~ /[^\d]/ ){
            $ret .= "[$range]";
        }
        else{
            $ret .= "$range";
        }
        $ret .= ",";
    }

    $ret =~ s/,$//;
    
    return( $ret );
}

###########################################################################

#............................................................................
#...Name
#...====
#... expand_string
#...
#...Purpose
#...=======
#... Takes a string with a regexp pattern and returns an array of values.
#...    foo[1-3],bar[2-4,7]a => foo1,foo2,foo3,bar2a,bar3a,bar4a,bar7a
#...
#...Arguments
#...=========
#... $string      Intent: in
#...              Perl type: scalar
#...              regexp'd string
#...
#... $array_string_ref    Intent: inout
#...                      Perl type: reference to array
#...
#............................................................................
sub expand_string{
    my(
       $string,
       $array_string_ref,
       ) = @_;
    my(
       $a,
       $b,
       $mid,
       $pre,
       $pst,
       $val,
       $string_result,
       @vals,
       @words,
       );

    # remove ppn constructs
    $string =~ s/:\d+//g;
    $string =~ s/\*\d+//g;
    # if string is from checkjob, put it in ljobs type form
    # [hosta:ppn][hostb:ppn][hostc:ppn] => hosta,hostb,hostc
    if( $string =~ /^(\[[^\[\]]+\])+$/ ){
        $string_result = "";
        while( $string =~ /^(\[[^\[\]]+\])(.*)$/ ){
            $string_result .= ",$1";
            $string = $2;
        }
        $string = $string_result;
        $string =~ s/^,//;
    }
    # ljobs form: "," separated and expand stuff inside "[]"
    $a = $string;
    $a =~ s/^\s*//;
    $a =~ s/\s*$//;
    $b = "";
    while( $a ne $b )
    {
        $b = $a;
        #...replace , with ; inside [] so can split on ,
        if( $a =~ /^(.*)(\[[^\[\]]*,[^\[\]]*\])(.*)$/ )
        {
            $pre = $1;
            $mid = $2;
            $pst = $3;
            $mid =~ s/,/;/g;
            $a = "$pre$mid$pst";
        }
        #...replace - with .. inside [] (perl range operator)
        if( $a =~ /^(.*)(\[[^\[\]]*\-[^\[\]]*\])(.*)$/ )
        {
            $pre = $1;
            $mid = $2;
            $pst = $3;
            $mid =~ s/\-/\.\./g;
            $a = "$pre$mid$pst";
        }
    }
    @vals = split(/\s*,\s*/, $a );
    foreach $val( @vals )
    {
        #...put , back
        $val =~ s/;/,/g;
        #...replace [] with a range into an array
        if( $val =~ /^(.*)\[(.*)\](.*)$/ )
        {
            $pre = $1;
            $mid = $2;
            $pst = $3;
            $mid =~ s/(\w+)/'$1'/g;
            @words = eval($mid);
            grep( s/^/${pre}/, @words );
            grep( s/$/${pst}/, @words );
        }
        #...or just stick value onto words
        else
        {
            @words = ($val);
        }
        push( @{$array_string_ref}, @words );
    }
}

sub my_chdir
  {
    my(
       $dir
      ) = @_;
    my(
       $ierr,
      );
    if( ! chdir( $dir ) )
      {
        $ierr = 1;
        &print_error( "Cannot chdir to [$dir]",
                      $ierr );
        exit( $ierr );
      }
    return( &cwd() );
  }

########################################################################
# NOT EXPORTED: need to have this in local scope to work - so just
#   copy/paste it into your code
# numerically: for sorting...
# @foo = ( "1\n","5\n","12\n" );
# print "numerically\n", sort my_numerically @foo;
# print "default\n", sort @foo;
#
# numerically
# 1
# 5
# 12
# default
# 1
# 12
# 5
sub my_numerically { $a <=> $b; }

#............................................................................
#...Name
#...====
#... datafile_parse
#...
#...Purpose
#...=======
#... Parse data file(s) and stuff into $data_file_ref
#... Data File Format:
#...   # comment
#...   a = b \ # variable with line continuation
#...       c
#...   block: code # start the "code" block
#...   code source pack prefix group # header for this block
#...   a    b      c    d      e     # values for a line
#...   f    g      h    i      j     # values for another line
#...   block: # end of the block.
#...   block.: code{TU} # add to code block if "TU"
#...   code source pack prefix group # header for this block
#...   k    l      m    n      o     # values for a line
#...   block: # end of the block.
#...   
#...
#...Arguments
#...=========
#... $cmd_ref     Intent: in
#...              Perl type: reference to hash
#...              command line
#...              $cmd{$option} = value
#...              $cmd{files}[] = array of file names
#...
#... $data_file_ref    Intent: inout
#...                   Perl type: reference to has
#...                   Necessary Fields:
#...                     {blocks_valid}{<block namd>} =
#...                        "<field>|<field>|<field>..."
#...                     {files} =
#...                         ("<datafile1>", "<datafile2>", "<datafile2>", ... )
#...                   Output Fields:
#...                     {blocks}{block}[<line num>]{<key>} = <value>
#...                     {key_val}{<key>}{vals}{<condition>} = <value>
#...                     {key_val}{<key>}{order}[] = <condition>
#...
#...Program Flow
#...============
#... 1) go through command line and assign to cmd hash
#............................................................................
sub datafile_parse
  {
    my(
       $data_file_ref
      ) = @_;
    my(
       $active,
       $block,
       $block_line,
       $blocks_valid,
       %blocks,
       $cond,
       $cond_set,
       $done,
       $done_block,
       $field,
       @fields,
       $file,
       $i,
       $ierr,
       $j,
       $key,
       %key_val,
       $line_num,
       $line,
       $line_new,
       @lines_file,
       $op,
       $val,
       @vals,
      );
    # default COND
    if( ! defined( $COND ) ){
        &datafile_setcond( "" );
    }
    $DEFAULT_DATA_FILE_REF = $data_file_ref;
    $blocks_valid = join("|",sort keys %{$$data_file_ref{blocks_valid}});
    # open and process each file
    foreach $file ( @{$$data_file_ref{files}} )
      {
        print "Datafile: [$file]";
        if( ! open( FILE, $file ) )
          {
            print " skipping\n";
            next;
          }
        print "\n";
        @lines_file = <FILE>;
        close( FILE );
        $i = 0;
        $done = "false";
        # process file
        while( $done eq "false" )
          {
            #...if done with file
            if( $i > $#lines_file )
              {
                $done = "true";
                next;
              }
            &_datafile_get_next_line( \$i, \@lines_file, \$line );
            # block
            if( $line =~ /^\s*block\s*(\.?:)\s*(.*)/ )
              {
                $op = $1;
                $block = $2;
                if( $block =~ /^(\S+)\s*\{\s*(.*?)\s*\}\s*$/ ) {
                    $block = $1;
                    $cond = $2;
                }
                else {
                    $cond = "";
                }
                if( $block !~ /^($blocks_valid)$/ )
                  {
                    $ierr = 1;
                    $line_num = $i;
                    &print_error( "Invalid block [$block]",
                                  "Valid blocks: [$blocks_valid]",
                                  "File: [$file:$line_num]",
                                  "line: [$line]",
                                  $ierr );
                    exit( $ierr );
                  }
                # see if this block is active
                my( $cond_eval ) = $cond;
                # go through each condition set and replace that string with true (1)
                # if that condition is set, or false (0) if not.
                # First will use ";" for "true", then replace all other strings with
                # false (0), then replace ";" with true (1)
                # replace pure numbers with true (right now, ";")
                $cond_eval =~ s/\b[1-9]\d*/\;/g;
                # replace each condition set with true (;)
                foreach my $cond_set ( split( /\s*,\s*/, $COND ) ){
                    $cond_eval =~ s/\b$cond_set\b/\;/g;
                }
                # replace all other words with false (0)
                $cond_eval =~ s/\b\w+\b/0/g;
                # set ";" back to true (1)
                $cond_eval =~ s/\;/1/g;
                # if non-null, then eval it
                if( $cond_eval =~ /\S/ ){
                    eval( "\$cond_eval = $cond_eval" );
                }
                # default is null being true
                else{
                    $cond_eval = 1;
                }
                if( $cond_eval ){
                    $active = "true";
                }
                else{
                    $active = "false";
                }
                #...init this block (will add to it if ".:")
                if( $op eq ":" && $active eq "true" ) {
                    @{$blocks{$block}} = ();
                }
                &_datafile_get_next_line( \$i, \@lines_file, \$line );
                if( $line !~ /\S/ ) {
                    $ierr = 1;
                    $line_num = $i;
                    &print_error( "Missing column header for block [$block]",
                                  "File: [$file:$line_num]",
                                  "line: [$line]",
                                  $ierr );
                    exit( $ierr );
                }
                @fields = split( /\s+/, $line );
                # check valid fields
                foreach $field ( @fields ) {
                    if( $field !~ /^($$data_file_ref{blocks_valid}{$block})$/ ) {
                        $ierr = 1;
                        $line_num = $i;
                        &print_error( "Missmatch of fields for block [$block]",
                                      "field:        [$field]",
                                      "fields valid: [".
                                      $$data_file_ref{blocks_valid}{$block}."]",
                                      "File: [$file:$line_num]",
                                      "line: [$line]",
                                      $ierr );
                        exit( $ierr );
                    }
                }
                $done_block = "false";
                $block_line = 0;
                # block_line
                while( $done_block eq "false" ) {
                    &_datafile_get_next_line( \$i, \@lines_file, \$line );
                    if( $line !~ /\S/ ) {
                        $ierr = 1;
                        $line_num = $i;
                        &print_error( "Missing data for block [$block]",
                                      "File: [$file:$line_num]",
                                      "End of File",
                                      $ierr );
                        exit( $ierr );
                    }
                    if( $line eq "block:" ) {
                        $done_block = "true";
                        next;
                    }
                    $line_new = $line;
                    @vals = ();
                    while( $line_new =~ /\S/ ){
                        if( $line_new =~ /^\s*\"([^\"]*?)\"(.*)/ ){
                            $val = $1;
                            $line_new = $2;
                            push( @vals, $val );
                        }
                        elsif( $line_new =~ /^\s*(\S+)(.*)/ ){
                            $val = $1;
                            $line_new = $2;
                            push( @vals, $val );
                        }
                    }
                    if( $#fields !~ $#vals ) {
                        $ierr = 1;
                        $line_num = $i;
                        &print_error( "Missmatch of fields and values for block [$block]",
                                      "fields: ".join(', ', @fields),
                                      "vals:   ".join(', ', @vals),
                                      "File: [$file:$line_num]",
                                      "line: [$line]",
                                      $ierr );
                        exit( $ierr );
                    }
                    if( $active eq "true" ){
                        $block_line = $#{$blocks{$block}} + 1;
                        $j = 0;
                        foreach $field ( @fields ) {
                            # if the block is active, save it
                            $blocks{$block}[$block_line]{$field} = &datafile_replace_var( $vals[$j] );
                            $j++;
                        }
                    }
                } # done: block_line
            } # done: block
            # key = val
            elsif( $line =~ /^(.*?)\s*(\.?=)\s*(.*?)$/ )
              {
                $key = $1;
                $op  = $2;
                $val = $3;
                if( $key =~ /^(\S+)\s*\{\s*(.*?)\s*\}\s*$/ )
                  {
                    $key  = $1;
                    $cond = $2;
                  }
                else
                  {
                    $cond = "";
                  }
                if( ! defined( $key_val{$key}{vals}{$cond} ) )
                  {
                    push( @{$key_val{$key}{order}}, $cond );
                  }
                if( $op eq ".=" )
                  {
                    if( defined( $key_val{$key}{vals}{$cond} ) )
                      {
                        $val = "$key_val{$key}{vals}{$cond} $val";
                      }
                  }
                $key_val{$key}{vals}{$cond} = $val;
              } # done: key = val
            # unparsed line
            elsif( $line =~ /\S/ )
              {
                $ierr = 1;
                $line_num = $i;
                &print_error( "Unparsed line",
                              "File: [$file:$line_num]",
                              "line: [$line]",
                              $ierr );
                exit( $ierr );
              }
          } # done: file
      } # open and process each file
    %{$$data_file_ref{blocks}} = %blocks;
    %{$$data_file_ref{key_val}} = %key_val;
  }
#...prune comments, join continuations, skip blank lines
sub _datafile_get_next_line
  {
    my(
       $i_ref,
       $lines_ref,
       $line_ref,
      ) = @_;
    my(
       $done,
       $line_new,
      );
    #...init
    $done = "false";
    while( $done eq "false" )
      {
        $$line_ref = "";
        #...end of file
        if( $$i_ref > $#{$lines_ref} )
          {
            $done = "true";
            next;
          }
        $$line_ref = $$lines_ref[$$i_ref];
        # leading/trailing whitespace
        $$line_ref =~ s/^\s*(.*?)\s*$/$1/;
        $$i_ref++;
        # comment line
        $$line_ref =~ s/\s*#.*//;
        # continuation line
        while( $$line_ref =~ /^(.*?)\s*\\\s*$/ )
          {
            $$line_ref = $1;
            $$line_ref =~ s/\s*$//;
            if( $$i_ref <= $#{$lines_ref} )
              {
                $line_new = $$lines_ref[$$i_ref];
                # comment
                $line_new =~ s/\s*#.*//;
                # leading trailing whitespace
                $line_new =~ s/^\s*(.*?)\s*$/$1/;
                $$line_ref .= " $line_new";
                #...leading/trailing whitespace
                $$line_ref =~ s/^\s*(.*?)\s*$/$1/;
              }
            $$i_ref++;
          }
        # skip blank
        if( $$line_ref =~ /\S/ )
          {
            $done = "true";
          }
      }
  }

#............................................................................
#...Name
#...====
#... datafile_files
#...
#...Purpose
#...=======
#... The list of files to be parsed in datafile_parse
#...
#...Arguments
#...=========
#... $data_file_ref    Intent: inout
#...                   Perl type: reference to hash
#...                   Will be used in datafile_parse
#...
#...Program Flow
#...============
#... 1) stuff array into data_file_ref
#............................................................................
sub datafile_files{
    my(
       $data_file_ref,
       @files
       );
    $data_file_ref = shift(@_);
    @files = @_;
    push( @{$$data_file_ref{files}}, @files );
}
#...return string containing datafile info
sub datafile_debug{
  my(
     $data_file_ref
    ) = @_;
  my(
     $block,
     @block_vals,
     $file,
     $i,
     $key,
     @keys,
     $val,
     %width,
     $output,
    );
  $output  = "\n";
  $output .= "==============\n";
  $output .= "Datafile Begin\n";
  $output .= "==============\n\n";
  $output .= "Files:\n";
  $output .= "------\n";
  foreach $file ( @{$$data_file_ref{files}} ){
    $output .= " $file\n";
  }
  $output .= "\n";
  $output .= "Condition: $COND\n";
  $output .= "\n";
  $output .= "Vars:\n";
  $output .= "-----\n";
  foreach $key ( sort keys %{$$data_file_ref{key_val}}) {
    $val = &datafile_getval($key);
    if( !defined($val) ){
      $val = "<UNDEF>";
    }
    $output .= sprintf( "%20s = %s\n", $key, $val );
  }
  $output .= "\n";
  $output .= "Blocks:\n";
  $output .= "-------\n";
  foreach $block (sort keys %{$$data_file_ref{blocks}} ) {
    $output .= " [$block]\n";
    @block_vals = &datafile_getblock($block);
    if( $#block_vals >= 0 ){
      @keys = sort( keys %{$block_vals[0]} );
      # get max width
      foreach $key ( @keys ) {
        $width{$key} = length($key);
      }
      for ( $i = 0; $i <= $#block_vals; $i++ ) {
        foreach $key ( @keys ) {
          $val = $block_vals[$i]{$key};
          if( $val !~ /\S/ ){
              $val = '""';
          }
          elsif( $val =~ /\s/ ){
              $val = '"'.$val.'"';
          }
          if( length($val) > $width{$key} ){
            $width{$key} = length($val);
          }
        }
      }
      foreach $key ( @keys ) {
        $output .= sprintf( "%$width{$key}s ", $key );
      }
      $output .= "\n";
      for ( $i = 0; $i <= $#block_vals; $i++ ) {
        foreach $key ( @keys ) {
            $val = $block_vals[$i]{$key};
            if( $val !~ /\S/ ){
                $val = '""';
            }
            elsif( $val =~ /\s/ ){
                $val = '"'.$val.'"';
            }
          $output .= sprintf( "%$width{$key}s ", $val );
        }
        $output .= "\n";
      }
      $output .= "\n";
    }
  }
  $output .= "============\n";
  $output .= "Datafile End\n";
  $output .= "============\n";

  return( $output );
}

#............................................................................
#...Name
#...====
#... datafile_getblock
#...
#...Purpose
#...=======
#... Returns block info for a particular block
#...
#...Arguments
#...=========
#... $block       Intent: in
#...              Perl type: scalar
#...              the block you want
#...
#...Program Flow
#...============
#... 1) return value (default of cond="" is returned if no condition set
#............................................................................
sub datafile_getblock
  {
    my(
       $block
      ) = @_;
    my(
       @nothing
      );
    if( defined($$DEFAULT_DATA_FILE_REF{blocks}{$block}) ){
        return( @{$$DEFAULT_DATA_FILE_REF{blocks}{$block}} );
    }
    else{
        return( @nothing );
    }
  }

#............................................................................
#...Name
#...====
#... datafile_getval
#...
#...Purpose
#...=======
#... Returns the value of an item in the datafile with the conditions
#... set in datafile_setcond
#...
#...Arguments
#...=========
#... $key         Intent: in
#...              Perl type: scalar
#...              the key to the value you want
#...
#...Program Flow
#...============
#... 1) return value
#............................................................................
sub datafile_getval
  {
    my(
       $key,
       $error,
      ) = @_;
    my(
       $cond,
       $cond_set,
       $ierr,
       $var,
      );
    if( defined($error) && ! defined($$DEFAULT_DATA_FILE_REF{key_val}{"$key"}))
      {
        $ierr = 1;
        &print_error( "Datafile variable not defined [$key]",
                      "Available variables:",
                      sort( keys( %{$$DEFAULT_DATA_FILE_REF{key_val}}) ),
                      $ierr );
        exit( $ierr );
      }
    # if the variable is defined at all
    if( defined($$DEFAULT_DATA_FILE_REF{key_val}{"$key"}) ){
        # go through each condition of the variable in order
        foreach $cond ( @{$$DEFAULT_DATA_FILE_REF{key_val}{$key}{order}} ){
            my( $cond_eval ) = $cond;
            # go through each condition set and replace that string with true (1)
            # if that condition is set, or false (0) if not.
            # First will use ";" for "true", then replace all other strings with
            # false (0), then replace ";" with true (1)
            # replace pure numbers with true (right now, ";")
            $cond_eval =~ s/\b[1-9]\d*/\;/g;
            # replace each condition set with true (;)
            foreach my $cond_set ( split( /\s*,\s*/, $COND ) ){
                $cond_eval =~ s/\b$cond_set\b/\;/g;
            }
            # replace all other words with false (0)
            $cond_eval =~ s/\b\w+\b/0/g;
            # set ";" back to true (1)
            $cond_eval =~ s/\;/1/g;
            # if non-null, then eval it
            if( $cond_eval =~ /\S/ ){
                eval( "\$cond_eval = $cond_eval" );
            }
            # default is null being true
            else{
                $cond_eval = 1;
            }
            if( $cond_eval ){
                $var = $$DEFAULT_DATA_FILE_REF{key_val}{$key}{vals}{$cond};
            }
        }
    }
    # replace any "${<var>}" with values
    if( defined( $var ) ){
        $var = &datafile_replace_var($var);
    }
    return( $var );
  }
# replace a${c}b with correct (using $ENV{c} if needed)
sub datafile_replace_var{
    my( $var ) = @_;
    my( 
        $ierr,
        $mid,
        $mid_orig,
        $pre,
        $pst,
        $var_new,
        );
    $var_new = $var;
    while ( $var_new =~ /^(.*)\$\{(\w+)\}(.*)$/ ){
        $pre = $1;
        $mid_orig = $2;
        $pst = $3;
        $mid = &datafile_getval("$mid_orig");
        if( ! defined($mid) ){
            if( defined($ENV{$mid_orig}) ){
                $mid = $ENV{$mid_orig};
            }
            else{
                $ierr = 1;
                &print_error( "Cannot find value for datafile variable [\$$mid_orig] from [$var]",
                              $ierr );
                exit( $ierr );
            }
        }
        $var_new = "${pre}${mid}${pst}";
    }
    return( $var_new );
}

#............................................................................
#...Name
#...====
#... extrema
#...
#...Purpose
#...=======
#... Given a set of x values, finds the extrema (mins and maxs)
#... If smoothing, will smooth first.
#...
#...Program Flow
#...============
#... 1) set condition
#............................................................................
sub extrema{
    my %args = (
        BY        => undef, # if finding extrema based on some other method (log)
        X         => undef, # X values, equal spacing if not defined
        Y         => undef, # Y values
        INFO      => undef, # hash of info where <array>[<number>] = X/Y index
                            #   {maxs|mins}[]
                            #     maxs and mins
                            #   {max_rise_<%>|max_fall_<%>|min_rise_<%>|min_fall_<%>}[]
                            #     index of % rise and fall
                            #     Current %: 95, 90, 30
                            #   {quick}  (and {quick_<type>} will be types of quick)
                            #     Start index quickly varying values ($i = same, $i+1 = change)
                            #     Used by my_smooth, my_deriv.
                            #     Currently, looks for "enough" changes from 0.
                            #   {special...}[number of max/min vals]
                            #     In order listing of max/min info.
                            #     Done for convenient use in other routines.
                            #   {special_t}
                            #     "max", "min", "max", "min, ... (might start with "min" first)
                            #   {special_i}
                            #     Which max/min index it is: 0, 0, 1, 1, 2, 2, ...
                            #   {special_xi}
                            #     The index of the max or min
                            #   {array_stats}
                            #     from my_array_stats()
        NOISE     => undef, # fraction of $y_range for extrema
        VERBOSE   => undef, # spit results to screen
        SPACING   => undef, # spacing for verbose prints
        @_,
        );
    my $args_valid = "BY|INFO|NOISE|X|Y|SPACING|VERBOSE";
    my(
        $x_ref,
        $y_ref,
        );
    my(
        $arg,
        @array,
        %array_stat,
        $box_window_ratio,
        $delta_cur,
        $delta_max,
        $done,
        $found_block,
        $i,
        $ierr,
        $j,
        $max_i,
        %max_mins,
        $noise,
        $noise_factor,
        $pct,
        @pcts,
        %quick_hash,
        $sign,
        $spacing,
        %special_i,
        $special_ndx,
        %special_t,
        $special_xi,
        $special_xi_next,
        $special_xi_orig,
        $special_xi_prev,
        @special_xis,
        $start,
        %stat,
        $stop,
        $type,
        $unchanged_ratio,
        $unchanged_num,
        @x,
        $x_range,
        $x_window_width,
        $y_range,
        $y_mean,
        );

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    if( defined($args{SPACING}) ){
        $spacing = $args{SPACING};
    }
    else{
        $spacing = "";
    }

    if( defined($args{NOISE}) ){
        $noise = $args{NOISE};
    }
    else{
        $noise = .01;
    }

    if( ! defined $args{Y} || ref($args{Y}) ne "ARRAY" ){
        $ierr = 1;
        &print_error( "Must supply Y array",
                      $ierr );
        exit( $ierr );
    }
    $y_ref = $args{Y};
    if( $#{$y_ref} < 0 ){
        $ierr = 1;
        &print_error( "Number of points is 0",
                      $ierr );
        exit( $ierr );
    }

    # must supply INFO
    if( ! defined($args{INFO}) || ref($args{INFO}) ne "HASH" ){
        $ierr = 1;
        &print_error( "Must supply INFO hash",
                      $ierr );
        exit( $ierr );
    }
    # init it
    undef( %{$args{INFO}} );

    # X (0..num-1 if not supplied)
    if( defined($args{X}) ){
        $x_ref = $args{X};
    }
    else{
        @x = (0..$#{$y_ref});
        $x_ref = \@x;
    }

    # sanity check lengths
    if( $#$x_ref != $#$y_ref ){
        $ierr = 1;
        &print_error( "Length of X and Y arrays must match X[$#$x_ref] != Y[$#$y_ref]", $ierr );
        exit( $ierr );
    }

    # largest index
    $max_i           = $#$y_ref;

    # parameters for {INFO}{unchanged_starts}...
    $unchanged_ratio = .05;
    $unchanged_num   = 100;

    # x_range
    # used in {INFO}{unchanged_starts}...
    # Will be using as a divisor so if 0, then the local x_range_this will
    # also be 0 so set this to 1.
    $x_range = $$x_ref[-1] - $$x_ref[0];
    if( $x_range == 0 ){
        $x_range = 1;
    }

    # x_window_width: size of box window to use
    # used in {INFO}{quick}/{quick_biggish}
    # size of each window will be x_window_width/$box_window_ratio
    if( $noise > 0 ){
        $box_window_ratio = int(1/$noise) / 4;
    }
    else{
        $box_window_ratio = 1e10;
    }
    if( $box_window_ratio < 1 ){
        $box_window_ratio = 1;
    }
    $x_window_width = ($$x_ref[-1] - $$x_ref[0]) / (2 * $box_window_ratio);

    # ===================
    # {INFO}{array_stats} 
    # ===================
    # get stats of whole array and stuff into {INFO}
    &my_array_stats($y_ref, \%array_stat );
    %{$args{INFO}{array_stats}} = %array_stat;
    
    # y_range, y_mean
    # also used in verbose header
    $y_range = $array_stat{max} - $array_stat{min};
    $y_mean  = $array_stat{mean};

    # verbose header
    if( defined($args{VERBOSE}) ){
        printf( "%s %s=%d %s=%22.15e %s=%9.2e\n",
                "${spacing}extrema()", "max_i", $max_i, "y_range", $y_range, "noise", $noise );
        printf( "%s %s: %22.15e - %22.15e %s: %22.15e - %22.15e\n",
                "${spacing}         ", "x", $$x_ref[0], $$x_ref[-1],
                "y", $array_stat{min}, $array_stat{max} );
    }

    # get max_mins{max|min}[$i] = index of original data
    &extrema_get_max_mins( MAX_MINS=>\%max_mins, Y_ARRAY_STATS=>\%array_stat,
                           Y_REF=>$y_ref, NOISE=>$noise, BY=>$args{BY} );

    # max_mins{max|min}[$i] = index of the max/min ->
    #   special_t{index} = max/min
    #   special_i{index} = index in max_mins
    # find special indices
    foreach $type ( "max", "min" ){
        if( defined($max_mins{$type}) ){
            @{$args{INFO}{$type}} = @{$max_mins{$type}};
            for( $i = 0; $i <= $#{$max_mins{$type}}; $i++ ){
                $j = $max_mins{$type}[$i];
                $special_t{$j} = $type;
                $special_i{$j} = $i;
            }
        }
    }

    @special_xis = sort my_numerically keys %special_t;

    # go through and look for rise or fall
    # will always be:
    #    rise -> max/min -> fall
    # do in order from lowest to highest
    @pcts = (30, 60, 90, 100);
    $special_ndx = 0;
    foreach $special_xi_orig ( @special_xis ){

        # type: max/min
        # sign: 
        $type = $special_t{$special_xi_orig};
        if( $type eq "max" ){
            $sign = 1;
        }
        else{
            $sign = -1;
        }

        # rise
        # special_xi_prev
        if( $special_ndx > 0 ){
            $special_xi_prev = $special_xis[$special_ndx-1];
        }
        else{
            # just use first datapoint
            #$special_xi_prev = $special_xis[0];
            $special_xi_prev = 0;
        }
        $delta_max = $sign * ($$y_ref[$special_xi_orig] - $$y_ref[$special_xi_prev]);
        $special_xi = $special_xi_orig;
        # go through @pcts
        foreach $pct ( @pcts ){
            for( $i = $special_xi; $i >= $special_xi_prev ; $i-- ){
                $delta_cur = $sign * ($$y_ref[$special_xi_orig] - $$y_ref[$i]);
                if( $delta_cur >= $delta_max * ($pct/100.0) ){
                    push( @{$args{INFO}{"${type}_rise_${pct}"}}, $i );
                    # start from just before new location
                    if($i < $special_xi_orig ){
                        $special_xi = $i + 1;
                    }
                    last;
                }
            }
        }

        # special_xi_next
        if( $special_ndx < $#special_xis ){
            $special_xi_next = $special_xis[$special_ndx+1];
        }
        else{
            # just use last datapoint
            #$special_xi_next = $special_xis[-1];
            $special_xi_next = $#{$y_ref};
        }
        $delta_max = $sign * ($$y_ref[$special_xi_orig] - $$y_ref[$special_xi_next]);
        $special_xi = $special_xi_orig;
        # go through @pcts
        foreach $pct ( @pcts ){
            # fall
            for( $i = $special_xi; $i <= $special_xi_next; $i++ ){
                $delta_cur = $sign * ($$y_ref[$special_xi_orig] - $$y_ref[$i]);
                if( $delta_cur >= $delta_max * ($pct/100.0) ){
                    push( @{$args{INFO}{"${type}_fall_${pct}"}}, $i );
                    # start from just before new location
                    if($i > $special_xi_orig ){
                        $special_xi = $i - 1;
                    }
                    last;
                }
            }
        }
        $special_ndx++;
    }

    @special_xis = sort my_numerically keys %special_t;
    foreach $special_xi ( @special_xis ){
        push( @{$args{INFO}{special_t}},  $special_t{$special_xi} );
        push( @{$args{INFO}{special_i}},  $special_i{$special_xi} );
        push( @{$args{INFO}{special_xi}}, $special_xi );
    }

    # =============
    # {INFO}{quick}
    # {INFO}{quick_big}
    # {INFO}{qick_biggish}
    # {INFO}{quick_non0}
    # =============
    #   $i   = value that has been about the same for a while
    #   $i+1 = value has changed a lot
    #   store $i
    undef( $done );
    $start = 0;
    $stop  = 0;
    $i = 0;
    # do not do if basically a flat line or large noise
    if( $y_range <= 1e-8 * abs($y_mean) ||
        $noise >= 1 ){
        $done = "";
    }
    while( ! defined($done) ){

        $i++;

        # finished when $i is >= end (since looking at $i+1)
        if( $i >= $max_i ){
            $done = "";
            last;
        }

        # for inequalities, use ">" so that values that are all 0 ($y_range==0)
        # will get filtered out
        
        # big change
        # multiple of noise or some factor of y_range
        $noise_factor = 10;
        if( (abs($$y_ref[$i] - $$y_ref[$i+1]) > $y_range * ($noise*$noise_factor)) ||
            ($noise < 1/$noise_factor && abs($$y_ref[$i] - $$y_ref[$i+1]) > $y_range * .25 ) ){
            push(@{$args{INFO}{quick}}, $i);
            push(@{$args{INFO}{quick_big}}, $i);
            next;
        }

        # move from 0
        # past couple 0 and change (have it be pretty small)
        if( $$y_ref[$i-1] == 0 && $$y_ref[$i] == 0 &&
            abs($$y_ref[$i] - $$y_ref[$i+1]) > $y_range * ($noise/5) ){
            push( @{$args{INFO}{quick}}, $i );
            push( @{$args{INFO}{quick_non0}}, $i );
            next;
        }

        # biggish change
        # do last since might be expensive and, if already triggered in above
        # quick, will not need to be done
        $noise_factor = 5;
        if( (abs($$y_ref[$i] - $$y_ref[$i+1]) > $y_range * ($noise * $noise_factor)) ||
            ($noise < 1/$noise_factor && abs($$y_ref[$i] - $$y_ref[$i+1]) > $y_range * .05 ) ){
            # get indices around this point with no quick
            undef( %quick_hash );
            &my_get_start_stop_width($x_ref, $i, $x_window_width, \%quick_hash,
                                     \$start, \$stop );
            @array = @{$y_ref}[$start..$i];
            &my_array_stats(\@array, \%stat );
            # previous values not changing much
            if( abs( $stat{max} - $stat{min} ) < $y_range * ($noise/2.0) ){
                push( @{$args{INFO}{quick}}, $i );
                push( @{$args{INFO}{quick_biggish}}, $i );
            }
        }

    }

    # ========================
    # {INFO}{unchanged_starts}
    # {INFO}{unchanged_stops}
    # ========================
    #   regions where the y values have not changed
    undef( $done );
    undef( $found_block );
    $start = 0;
    undef( $stop );
    $i = 0;
    while( ! defined($done) ){
        $i++;

        # finished when $i is > end (since looking at $i+1)
        if( $i > $max_i ){
            $done = "";
            last;
        }

        # current different than previous
        if( $$y_ref[$i] != $$y_ref[$i - 1] ){
            $stop = $i - 1;
            $found_block = "";
        }
        # if at end
        elsif( $i >= $max_i ){
            $stop = $i;
            $found_block = "";
        }

        # if found a block of unchanging
        if( defined( $found_block ) ){
            
            # if enough width
            #   at least 1 point between start/stop and
            #     width more than some cutoff point
            #     at least some number of points
            # mark it
            if( $stop > $start+1 &&
                ( $$x_ref[$stop] - $$x_ref[$start] > $x_range * $unchanged_ratio ||
                  $stop - $start > $unchanged_num ) ){
                push( @{$args{INFO}{unchanged_starts}}, $start );
                push( @{$args{INFO}{unchanged_stops}},  $stop );
            }

            # reset region
            undef( $found_block );
            $start = $i;
            undef( $stop );
        }

    }
}

###################################################################################
# extrema_get_max_mins
#   fill max_mins{max|min}[$i] = index of max or min
sub extrema_get_max_mins{

    my %args = (
        MAX_MINS      => undef, # \%max_mins
        Y_ARRAY_STATS => undef, # \%array_stats of my_array_stats($y)
        Y_REF         => undef, # y array ref
        NOISE         => undef, # noise
        BY            => undef, # what to do by
        @_,
        );
    my $args_valid = "BY|MAX_MINS|NOISE|Y_ARRAY_STATS|Y_REF";

    my(
        $arg,
        %array_stats_new,
        $array_stats_ref,
        $by,
        $changed,
        $done,
        $extrema_last_index,
        $extrema_last_type,
        $extrema_last_val,
        %extrema_type_o,
        $i,
        $ierr,
        %last_index,
        %last_val,
        $max_i,
        $max_mins_ref,
        $noise,
        $val,
        $y_mean,
        $y_range,
        $y_ref,
        @y_new,
        );

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # array_stats
    $array_stats_ref = $args{Y_ARRAY_STATS};

    # y_ref
    $y_ref = $args{Y_REF};

    # noise
    $noise = $args{NOISE};

    # max_mins_ref
    $max_mins_ref = $args{MAX_MINS};

    # by
    # if set, need to reset:
    #   $y_ref
    #   $array_stats_ref
    $by = $args{BY};
    if( ! defined($by) ){
        $by = "";
    }
    # by=log
    if( $by eq "log" ){

        # get new "log" of data (special cases for y and negative data)
        @y_new = @$y_ref;
        $y_ref = \@y_new;
        &my_log( Y=>$y_ref );

        # array_stats_ref from new y_ref
        $array_stats_ref = \%array_stats_new;
        &my_array_stats( $y_ref, $array_stats_ref );
        
    }

    # get y_range, y_mean
    $y_range = $$array_stats_ref{range};
    $y_mean  = $$array_stats_ref{mean};

    # largest index
    $max_i           = $#$y_ref;

    # parameters that affect finding extrema
    $extrema_type_o{max} = "min";
    $extrema_type_o{min} = "max";

    # init point
    $val = $$y_ref[0];
    $i = 0;
    $last_val{max}   = $val;
    $last_index{max} = $i;
    $last_val{min}   = $val;
    $last_index{min} = $i;

    # go through array
    undef( $done );
    # short circuit if flat line
    if( $y_range <= abs($y_mean) * 1e-8 ){
        $done = "";
    }
    while( ! defined( $done ) ){

        # next point
        $i++;

        # value (even if $i > $#$xref, this is ok and will not increase
        # the size of y_ref - $val will just be undefined
        $val = $$y_ref[$i];
        undef( $changed );

        # if no more points, fill in last one if large enough difference
        if( $i > $max_i ){
            $done = "";
            $changed = "";

            # if never found any extrema (1 point, flat line)
            if( ! defined( $extrema_last_type ) ){
                $extrema_last_type = "max";
                $extrema_last_val  = $last_index{$extrema_last_type};
            }

            # set last values to be previous extrema and either max/min
            # so that goes through extrema logic below
            # need to kludge last/type to trigger storing latest max/min
            # if diffs large enough
            if( $extrema_last_type eq "min" ){
                $last_val{min}     = $extrema_last_val; # value of last extrema
                $last_index{min}   = $last_index{max} + 1; # to ensure correct type detection
            }
            if( $extrema_last_type eq "max" ){
                $last_val{max}     = $extrema_last_val; # value of last extrema
                $last_index{max}   = $last_index{min} + 1; # to ensure correct type detection
            }
        }

        # still have not found starting point
        elsif( ! defined( $extrema_last_type ) ){
            # keep track of latest max and min
            if( $val > $last_val{max} ){
                $last_val{max}   = $val;
                $last_index{max} = $i;
                $changed = "";
            }
            if( $val < $last_val{min} ){
                $last_val{min}   = $val;
                $last_index{min} = $i;
                $changed = "";
            }
        }

        # extrema_last_type == min
        elsif( $extrema_last_type eq "min" ){
            # reset last if found new max
            if( $val > $last_val{max} ){
                $last_val{max}   = $val;
                $last_index{max} = $i;
                $last_val{min}   = $val;
                $last_index{min} = $i;
            }
            # reset min if found a new one
            elsif( $val < $last_val{min} ){
                $last_val{min}   = $val;
                $last_index{min} = $i;
                $changed = "";
            }
        }

        # extrema_last_type == max
        elsif( $extrema_last_type eq "max" ){
            # reset last if found new min
            if( $val < $last_val{min} ){
                $last_val{max}   = $val;
                $last_index{max} = $i;
                $last_val{min}   = $val;
                $last_index{min} = $i;
            }
            # reset max if found a new one
            elsif( $val > $last_val{max} ){
                $last_val{max}   = $val;
                $last_index{max} = $i;
                $changed = "";
            }
        }
        
        # if turnaround point changed enough
        #   changed
        #   max-min range more than machine noise
        #   max-min range more than user    noise
        if( defined( $changed ) &&
            ($y_range > (abs($last_val{max} + $last_val{min})) * 1e-8 ) &&
            $last_val{max} - $last_val{min} > $y_range*$noise ){
            
            # min came first
            if( $last_index{min} < $last_index{max} ){
                $extrema_last_type = "min";
            }
            # max came first
            else{
                $extrema_last_type = "max";
            }

            # stuff index into max_mins{$extrema_last_type}
            # is the first one or
            # enough variation between last extrema and this candidate
            if( ! defined( $extrema_last_index ) || # this is first one
                abs($extrema_last_val - $last_val{$extrema_last_type}) >
                $y_range*$noise ){

                # stuff index into max_mins{$extrema_last_type}
                $extrema_last_index = $last_index{$extrema_last_type};
                $extrema_last_val   = $last_val{$extrema_last_type};
                push( @{$$max_mins_ref{$extrema_last_type}}, $extrema_last_index );
                # reset last_val to this extrema to start looking from there
                $i   = $last_index{$extrema_type_o{$extrema_last_type}};
                $val = $last_val{$extrema_type_o{$extrema_last_type}};
                $last_val{max}   = $val;
                $last_index{max} = $i;
                $last_val{min}   = $val;
                $last_index{min} = $i;
            }
        }
    }
}

###################################################################################
# my_cull
#   Culls an array to an approzimate size
sub my_cull{
    my %args = (
        CULL      => undef, # Input: reference to array of size 1 whose value
                            #        is the approximate number of elements to cull
                            #        down to.
                            #        or
                            #        array whose values are the indices you want to keep
                            # Output: array of indices kept of the original array.
                            # Use: cull to about 1k points, then use that set
                            #      as points to keep for other arrays.
        BY           => undef, # by (log)
        X            => undef, # X values, equal spacing if not defined
        Y            => undef, # Y values
        VERBOSE      => undef, # if verbose
        SPACING      => undef, # number of spaces to indent
        NOISE        => undef, # noise factor
        @_,
        );
    my $args_valid = "BY|CULL|NOISE|SPACING|VERBOSE|X|Y";
    my(
        $arg,
        $cull_given,
        %cull_hash,
        $cull_num,
        $cull_point,
        @cull_points,
        $cull_ref,
        $cull_sampling,
        @cull_starts,
        @cull_stops,
        @cull_types,
        @cull_unique_starts,
        @cull_unique_stops,
        $cull_value,
        $cull_x_ratio,
        $cull_y_ratio,
        $den,
        $done,
        $done1,
        $i,
        $ierr,
        $i_other,
        $i_regions,
        $i_unchanged,
        $index,
        $index_out,
        %info_new,
        $j,
        $key,
        $max_i,
        $num,
        $num_cull_points,
        $range_spike,
        $range_this,
        %ranges_this,
        $rate_other,
        $rate_regions,
        $rate_use,
        $region_splice,
        $skip_string,
        $spacing,
        $start,
        $stop,
        $this_starts,
        $this_stops,
        @tmp,
        %tmp_info,
        $type,
        $type_full,
        $type_min_max,
        @unchanged_starts,
        @unchanged_stops,
        $width_other,
        $width_regions,
        $width_spike,
        $width_unchanged,
        @x_default,
        @x_new,
        $x_range,
        $x_ref,
        @y_1st,
        @y_2nd,
        @y_new,
        $y_range,
        $y_ref,
        );
    
    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }
    
    if( defined($args{SPACING}) ){
        $spacing = $args{SPACING};
    }
    else{
        $spacing = "";
    }

    if( ! defined $args{Y} || ref($args{Y}) ne "ARRAY" ){
        $ierr = 1;
        &print_error( "Must supply Y array",
                      $ierr );
        exit( $ierr );
    }
    $y_ref = $args{Y};
    $max_i = $#{$y_ref};
    if( $max_i < 0 ){
        $ierr = 1;
        &print_error( "Number of points is 0",
                      $ierr );
        exit( $ierr );
    }

    # check CULL
    $cull_ref = $args{CULL};
    if( ref($cull_ref) ne "ARRAY" ||
        ( $#{$cull_ref} != 0 && $#{$cull_ref} > $#{$y_ref} ) ||
        ! defined($$cull_ref[0]) ){
        $ierr = 1;
        &print_error( "CULL input: reference to array of size 1 where cull[0]=<num cull points>",
                      "              or ",
                      "            array whose values are the indices you want to keep");
        exit( $ierr );
    }

    if( defined($args{CULL_X_RATIO}) ){
        $cull_x_ratio = $args{CULL_X_RATIO};
    }
    else{
        $cull_x_ratio = .01; # max x width for rise/fall
    }

    if( defined($args{CULL_Y_RATIO}) ){
        $cull_y_ratio = $args{CULL_Y_RATIO};
    }
    else{
        $cull_y_ratio = 1e-5; # (rise or fall) to max/min rel to total range (scaled by x_ratio)
    }

    # sampling rate change for interesting regions
    # will be multiplied by the width ratio (smaller the interesting region -> more points)
    if( defined($args{CULL_SAMPLING}) ){
        $cull_sampling = $args{CULL_SAMPLING};
    }
    else{
        $cull_sampling = 10;
    }

    # desired number of point to end with
    # special case if only given 1 point - just assume want the point back
    undef( $cull_given );
    if( $#$y_ref == 0){
        $cull_num = 1;
    }
    elsif( $#$cull_ref == 0 ){
        $cull_num = $$cull_ref[0]
    }
    else{
        $cull_given = "";
        $cull_num = $#$cull_ref + 1;
    }

    if( defined $args{X} && ref($args{X}) ne "ARRAY" ){
        $ierr = 1;
        &print_error( "If given x, must be array",
                      $ierr );
        exit( $ierr );
    }

    # header
    if( defined($args{VERBOSE}) ){
        if( defined( $cull_given ) ){
            print "${spacing}Culling given the index array to $cull_num points\n";
        }
        else{
            print "${spacing}Culling to about $cull_num points (maxs/mins/rises/falls + other_areas)\n";
            printf( "%s%s=%10.2e %s=%10.2e\n",
                    "$spacing  ", "cull_x_ratio", $cull_x_ratio, "cull_sampling", $cull_sampling );
        }
    }

    # create X if needed
    if( defined($args{X}) ){
        $x_ref = $args{X};
    }

    # cull_given - do and return
    if( defined($cull_given) ){
        
        # always have y
        undef( @y_new );
        $index_out = 0;
        foreach $i (@{$cull_ref}){
            if( $i >= 0 && $i <= $max_i ){
                $y_new[$index_out] = $$y_ref[$i];
                $index_out++;
            }
        }
        @$y_ref = @y_new;

        # might not have x
        if( defined( $x_ref ) ){
            undef( @x_new );
            $index_out = 0;
            foreach $i (@{$cull_ref}){
                if( $i >= 0 && $i <= $max_i ){
                    $x_new[$index_out] = $$x_ref[$i];
                    $index_out++;
                }
            }
            @$x_ref = @x_new;
        }
        if( defined( $args{VERBOSE}) ){
            print "${spacing}  Culled to ",$index_out+1," points\n";
        }
        return;
    }

    # now create x if needed
    if( ! defined($x_ref) ){
        @x_default = (0..$max_i);
        $x_ref = \@x_default;
    }

    # now x/y sizes must be equal
    if( $#{$y_ref} != $#{$x_ref} ){
        $ierr = 1;
        &print_error( "Size of X/Y must be equal",
                      $ierr );
        exit( $ierr );
    }
        
    # x_range
    $x_range = $$x_ref[-1] - $$x_ref[0];
    if( $x_range == 0 ){
        $x_range = 1;
    }

    # culling points of interest are:
    #   maxs/mins
    #   maxs/mins of derivative
    #   area around max/mins of second derivative
    
    # first and last point
    undef( @cull_points );
    if( $max_i >= 0 ){
        push( @cull_points, 0 );
    }
    if( $max_i > 0 ){
        push( @cull_points, $max_i );
    }
    
    undef( @cull_starts );
    undef( @cull_stops );
    undef( @cull_types );
    
    # ------------------------
    # extrema of original data
    # ------------------------
    if( defined($args{VERBOSE}) ){
        print "$spacing  Culling: original data info: other_areas = around maxs/mins\n";
    }
    undef( %info_new );
    @y_new = @$y_ref;
    &extrema( X=>$x_ref, Y=>\@y_new, INFO=>\%info_new, BY=>$args{BY},
              NOISE=>$args{NOISE}, VERBOSE=>$args{VERBOSE}, SPACING=>"    $spacing" );
    $y_range = $info_new{array_stats}{range};
    # remember unchanged at this point
    if( defined($info_new{unchanged_starts}) ){
        @unchanged_starts = @{$info_new{unchanged_starts}};
        @unchanged_stops  = @{$info_new{unchanged_stops}};
    }
    $num_cull_points = 0;
    foreach $key ( keys %info_new ){
        if( $key =~ /special|array_stats/ ){
            next;
        }
        $num_cull_points += $#{$info_new{$key}} + 1;
        push( @cull_points, @{$info_new{$key}} );
    }
    if( defined($args{VERBOSE}) ){
        print "$spacing    num_cull_points=$num_cull_points\n";
    }
    # cull_starts/cull_stops: areas around maxs/mins (rise/fall)
    $type = "orig";
    $range_this = $info_new{array_stats}{range};
    $ranges_this{$type} = $range_this;
    foreach $key ( sort keys %info_new ) {
        if( $key =~ /((max|min)_(rise|fall)_(\d+))/ ){
            $type_full    = $1;
            $type_min_max = $2;
            $num = $#{$info_new{$type_min_max}} + 1;
            for( $i = 0; $i < $num; $i++ ){
                # rise to max/min
                if( $type_full =~ /rise/ ){
                    push( @cull_starts, $info_new{$type_full}[$i] );
                    push( @cull_stops,  $info_new{$type_min_max}[$i] );
                }
                else{
                    push( @cull_starts, $info_new{$type_min_max}[$i] );
                    push( @cull_stops,  $info_new{$type_full}[$i] );
                }
                push( @cull_types, "$type_full" );
            }
        }
    }
    
    # -------------------------
    # extrema of 1st derivative
    # -------------------------
    if( defined($args{VERBOSE}) ){
        print "$spacing  Culling: 1st-deriv info: other_areas = around maxs/mins\n";
    }
    undef( %info_new );
    &my_derivative( DERIV=>\@y_1st, X=>$x_ref, Y=>\@y_new,
                    NOISE=>$args{NOISE}, SPACING=>"    $spacing" );
    &extrema( X=>$x_ref, Y=>\@y_1st, INFO=>\%info_new,
              NOISE=>$args{NOISE}, VERBOSE=>$args{VERBOSE}, SPACING=>"    $spacing" );
    $num_cull_points = 0;
    foreach $key ( keys %info_new ){
        if( $key =~ /special|array_stats/ ){
            next;
        }
        $num_cull_points += $#{$info_new{$key}} + 1;
        push( @cull_points, @{$info_new{$key}} );
    }
    if( defined($args{VERBOSE}) ){
        print "$spacing    num_cull_points=$num_cull_points\n";
    }
    # cull_starts/cull_stops: areas around maxs/mins (rise/fall)
    $type = "1st-deriv";
    $range_this = $info_new{array_stats}{range};
    $ranges_this{$type} = $range_this;
    foreach $key ( sort keys %info_new ) {
        if( $key =~ /((max|min)_(rise|fall)_(\d+))/ ){
            $type_full    = $1;
            $type_min_max = $2;
            $num = $#{$info_new{$type_min_max}} + 1;
            for( $i = 0; $i < $num; $i++ ){
                # rise to max/min
                if( $type_full =~ /rise/ ){
                    push( @cull_starts, $info_new{$type_full}[$i] );
                    push( @cull_stops,  $info_new{$type_min_max}[$i] );
                }
                else{
                    push( @cull_starts, $info_new{$type_min_max}[$i] );
                    push( @cull_stops,  $info_new{$type_full}[$i] );
                }
                push( @cull_types, "$type_full" );
            }
        }
    }
    
    # -------------------------
    # extrema of 2nd derivative
    # -------------------------
    if( defined($args{VERBOSE}) ){
        print "$spacing  Culling: 2nd-deriv info\n";
    }
    undef( %info_new );
    &my_derivative( DERIV=>\@y_2nd, X=>$x_ref, Y=>\@y_1st,
                    NOISE=>$args{NOISE}, SPACING=>"    $spacing" );
    &extrema( X=>$x_ref, Y=>\@y_2nd, INFO=>\%info_new,
              NOISE=>$args{NOISE}, VERBOSE=>$args{VERBOSE}, SPACING=>"    $spacing" );
    $num_cull_points = 0;
    foreach $key ( keys %info_new ){
        if( $key =~ /special|array_stats/ ){
            next;
        }
        $num_cull_points += $#{$info_new{$key}} + 1;
        push( @cull_points, @{$info_new{$key}} );
    }
    if( defined($args{VERBOSE}) ){
        print "$spacing    num_cull_points=$num_cull_points\n";
    }
    # cull_starts/cull_stops: areas around maxs/mins (rise/fall)
    $type = "2nd-deriv";
    $range_this = $info_new{array_stats}{range};
    $ranges_this{$type} = $range_this;
    foreach $key ( sort keys %info_new ) {
        if( $key =~ /((max|min)_(rise|fall)_(\d+))/ ){
            $type_full    = $1;
            $type_min_max = $2;
            $num = $#{$info_new{$type_min_max}} + 1;
            for( $i = 0; $i < $num; $i++ ){
                # rise to max/min
                if( $type_full =~ /rise/ ){
                    push( @cull_starts, $info_new{$type_full}[$i] );
                    push( @cull_stops,  $info_new{$type_min_max}[$i] );
                }
                else{
                    push( @cull_starts, $info_new{$type_min_max}[$i] );
                    push( @cull_stops,  $info_new{$type_full}[$i] );
                }
                push( @cull_types, "$type_full" );
            }
        }
    }
    
    # strip out the regions that are not wide (wrt x and y)
    # do before splicing since do not want to wash out any
    # sharp regions with flat ones.
    if( defined($args{VERBOSE}) ){
        printf( "%s%22s - %22s %9s %9s %4s %s\n",
                "$spacing      ", "x-start", "x-stop", "x_ratio", "y_ratio", "keep", "type" );
    }
    for( $i = 0; $i <= $#cull_starts; $i++ ){
        @tmp = @{$y_ref}[$cull_starts[$i]..$cull_stops[$i]];
        &my_array_stats(\@tmp, \%tmp_info);
        $this_starts = $$x_ref[$cull_starts[$i]];
        $this_stops = $$x_ref[$cull_stops[$i]];
        $width_spike = ($this_stops - $this_starts)/$x_range;
        $range_spike = $tmp_info{range};
        if( $y_range > 0 ){
            $range_spike = ($range_spike/$y_range);
            # and scale to the $range_spike (if x range small, y range can be small)
            if( $width_spike > 0 ){
                $range_spike = $range_spike / $width_spike;
            }
        }
        if( $width_spike >= $cull_x_ratio ||
            $range_spike <= $cull_y_ratio ){
            $skip_string = "SKIP";
            $cull_starts[$i] = -10;
            $cull_stops[$i]  = -10;
        }
        else{
            $skip_string = " yes";
        }
        if( defined($args{VERBOSE}) ){
            # do not print the SKIPs
            if( 1 == 1 || $skip_string !~ /SKIP/ ){
                printf( "%s%22.15e - %22.15e %9.2e %9.2e",
                        "$spacing      ",
                        $this_starts, $this_stops,
                        $width_spike, $range_spike );
                print " $skip_string $cull_types[$i]\n";
            }
        }
    }
    
    # splice any overlapping regions
    $i = 0;
    undef( $done );
    
    while( ! defined($done) ){
        if( $#cull_starts < 0 ){
            $done = "";
            last;
        }
        
        # get a region
        $start = shift(@cull_starts);
        $stop  = shift(@cull_stops);
        # this one tagged as a skip
        if( $start < 0 ){
            next;
        }
        
        # see if this is in another region
        undef( $done1 );
        while( ! defined($done1) ){
            undef( $region_splice );
            for( $i = 0; $i <= $#cull_starts; $i++ ){
                # if this start or stop is within or
                # only 1 point separates
                # the region tag it for splicing and exit loop
                if( ( $start >= $cull_starts[$i] - 2 &&
                      $start <= $cull_stops[$i]  + 2 ) ||
                    ( $stop  >= $cull_starts[$i] - 2 &&
                      $stop  <= $cull_stops[$i]  + 2 ) ){
                    $region_splice = $i;
                    last;
                }
                # if another region is within this region, remove it
                if( $cull_starts[$i] >= $start &&
                    $cull_stops[$i]  <= $stop ){
                    $cull_starts[$i] = -10;
                    $cull_stops[$i]  = -10;
                }
            }
            if( ! defined($region_splice) ){
                $done1 = "";
                last;
            }
            
            # splice region
            if( $start > $cull_starts[$region_splice] ){
                $start = $cull_starts[$region_splice];
            }
            if( $stop  < $cull_stops[$region_splice] ){
                $stop  = $cull_stops[$region_splice];
            }
            
            # tag this region as spliced
            $cull_starts[$region_splice] = -10;
            $cull_stops[$region_splice]  = -10;
            
        }
        
        # now start/stop are a non-overlapping region
        push( @cull_unique_starts, $start );
        push( @cull_unique_stops, $stop );
    }
    
    # now order them
    @cull_starts = sort my_numerically @cull_unique_starts;
    @cull_stops  = sort my_numerically @cull_unique_stops;
    
    # regions with no sampling (unchanged_starts/unchanged_stops)
    for( $i = 0; $i <= $#cull_starts; $i++ ){
        for( $j = 0; $j <= $#unchanged_starts; $j++ ){
            # cull region inside unchanged region
            if( $cull_starts[$i] >= $unchanged_starts[$j] &&
                $cull_starts[$i] <= $unchanged_stops[$j]  &&
                $cull_stops[$i]  >= $unchanged_starts[$j] &&
                $cull_stops[$i]  <= $unchanged_stops[$j]
                ){
                # tag cull region as empty
                $cull_starts[$i] = -10;
                $cull_stops[$i]  = -10;
            }
            # cull_start inside unchanged
            elsif( $cull_starts[$i] >= $unchanged_starts[$j] &&
                   $cull_starts[$i] <= $unchanged_stops[$j] ){
                $cull_starts[$i] = $unchanged_stops[$j];
            }
            # cull_stop inside unchanged
            elsif( $cull_stops[$i]  >= $unchanged_starts[$j] &&
                   $cull_stops[$i]  <= $unchanged_stops[$j] ){
                $cull_stops[$i] = $unchanged_starts[$j];
            }
        }            
    }
    
    # sort unique
    %cull_hash = map{$_=>1} @cull_points;
    @cull_points = sort my_numerically keys %cull_hash;
    
    # determine the spacing when you are in a start/stop
    # region and when not in one
    $width_regions = 0;
    $i_regions = 0;
    for( $i = 0; $i <= $#cull_starts; $i++ ){
        if( $cull_starts[$i] < 0 ){
            next;
        }
        $width_regions += $$x_ref[$cull_stops[$i]] - $$x_ref[$cull_starts[$i]];
        $i_regions     +=         $cull_stops[$i]  -         $cull_starts[$i] + 1;
    }
    
    $width_unchanged = 0;
    $i_unchanged = 0;
    for( $i = 0; $i <= $#unchanged_starts; $i++ ){
        if( $unchanged_starts[$i] < 0 ){
            next;
        }
        $width_unchanged += $$x_ref[$unchanged_stops[$i]] - $$x_ref[$unchanged_starts[$i]];
        $i_unchanged     +=         $unchanged_stops[$i]  -         $unchanged_starts[$i] + 1;
    }
    $width_other = $x_range - $width_regions - $width_unchanged;
    $i_other     = $max_i   - $i_regions     - $i_unchanged;
    if($width_other < 0 ){
        $width_other = 0;
    }
    if($i_other < 0 ){
        $i_other     = 0;
    }
    
    # subtract out a portion of the hardwired cull_points
    $cull_num = $cull_num - (($#cull_points + 1)/2);
    
    # I base the culling rate on the number of points instead of
    # the distance.  I am assuming that if the spacing is very
    # small, there is a reason for it.
    # So, in "interesting" regions, pick every Nth point and
    #     in "default"     regions, pick every Mth point
    #     where Mth and Nth rates are some factor of eachother
    #     and the relative number of points in the dataset.
    #
    # rate_<part> = number / width
    # rate_regions * i_regions + rate_other * i_other = cull_num
    # rate_regions = cull_sampling * rate_other
    # cull_sampling * rate_other * i_regions + rate_other * i_other = cull_num
    # rate_other * (cull_sampling * i_regions + i_other) = cull_num
    # rate_other = cull_num / (cull_sampling * i_regions + i_other)
    #
    # scale cull_sampling to the width of the interesting region
    if( $i_regions != 0 ){
        $cull_sampling = $cull_sampling / sqrt($i_regions/($max_i+1));
    }
    $rate_other = 0;
    $rate_regions = 0;
    
    if( $cull_num > 0 ){
        $den = $cull_sampling * $i_regions + $i_other;
        if( $den == 0 ){
            $den = 1;
        }
        $rate_other   = $cull_num / $den;
        $rate_regions = $cull_sampling * $rate_other;
        # if more than every 1, adjust so picks every one
        if( $rate_regions > 1 - 1e-8 ){
            # whatever the rate would be from the remaining points to fill out the
            # rest of cull_num
            if( $i_other > 0 ){
                $rate_other   = ($cull_num - $i_regions) / $i_other;
            }
        }
        if( $rate_other > 1 - 1e-8 ){
            # whatever the rate would be from the remaining points to fill out the
            # rest of cull_num
            if( $i_regions > 0 ){
                $rate_regions = ($cull_num - $i_other)   / $i_regions;
            }
        }
        if( $rate_regions > 1 - 1e-8 ){
            $rate_regions = 1;
        }
        if( $rate_other > 1 - 1e-8 ){
            $rate_other = 1;
        }
    }
    
    if( defined($args{VERBOSE}) ){
        printf(     "${spacing}  Default                 sampling rate= %22.15e\n",
                    $rate_other );
        if( $#cull_starts >= 0 ){
            printf( "${spacing}  Interesting ranges with sampling rate= %22.15e width_ratio=%9.2e i_ratio=%9.2e\n",
                    $rate_regions, $width_regions/$x_range, $i_regions/($max_i+1));
            printf( "%s%22s - %22s\n",
                    "$spacing    ",
                    "x-start", "x-stop");
            for( $i = 0; $i <= $#cull_starts; $i++ ){
                if( $cull_starts[$i] < 0 ){
                    next;
                }
                printf( "%s%22.15e - %22.15e (indices %d - %d)\n",
                        "$spacing    ",
                        $$x_ref[$cull_starts[$i]], $$x_ref[$cull_stops[$i]],
                        $cull_starts[$i], $cull_stops[$i]);
            }
        }
        if( $#unchanged_starts >= 0 ){
            printf( "${spacing}  Unchanging  ranges with sampling rate= %22.15e width_ratio=%9.2e i_ratio=%9.2e\n",
                    0, $width_unchanged/$x_range, $i_unchanged/($max_i+1));
            printf( "%s%22s - %22s\n",
                    "$spacing    ",
                    "x-start", "x-stop");
            for( $i = 0; $i <= $#unchanged_starts; $i++ ){
                printf( "%s%22.15e - %22.15e (indices %d - %d)\n",
                        "$spacing    ",
                        $$x_ref[$unchanged_starts[$i]], $$x_ref[$unchanged_stops[$i]],
                        $unchanged_starts[$i], $unchanged_stops[$i]);
            }
        }
    }
    
    # go through and add points
    @{$cull_ref} = ();
    undef( @x_new );
    undef( @y_new );
    $index = 0;
    $cull_value = 0;
    for( $i = 0; $i <= $max_i; $i++ ){
        
        # default rate_use
        $rate_use = $rate_other;
        
        # rate_use: unchanged_starts/unchanged_stops
        if( $#unchanged_starts >= 0 ){
            # be sure to include boundaries
            if( $i >= $unchanged_starts[0] && $i <= $unchanged_stops[0] ){
                $rate_use = 0;
            }
            # shift off
            if( $i == $unchanged_stops[0] || $unchanged_starts[0] < 0 ){
                shift(@unchanged_starts);
                shift(@unchanged_stops);
            }
        }
        
        # rate_use: rate_regions
        if( $#cull_starts >= 0 ){
            # be sure to include boundaries
            if( $i+1 >= $cull_starts[0] && $i-1 <= $cull_stops[0] ){
                $rate_use = $rate_regions;
            }
            # shift off cull_starts/cull_stops
            if( $i == $cull_stops[0] || $cull_starts[0] < 0 ){
                shift(@cull_starts);
                shift(@cull_stops);
            }
        }
        
        # add to cull_value
        $cull_value = $cull_value + $rate_use;
        
        # see if a cull point
        undef( $cull_point );
        
        # on list of cull_points
        if( $#cull_points >= 0 && $i == $cull_points[0] ){
            $cull_point = "";
            # shift off cull_points
            shift( @cull_points );
        }
        
        # see if enough distance for next point
        elsif( $i == $max_i || $cull_value >= 1 - 1e-8 ){
            $cull_point = "";
        }
        
        # if cull_point, then add to arrays
        if( defined($cull_point) ){
            $cull_value = $cull_value - 1;
            if( $cull_value < 0 ){
                $cull_value = 0;
            }
            $index = $i;
            push( @x_new, $$x_ref[$i]);
            push( @y_new, $$y_ref[$i]);
            push( @{$cull_ref}, $i );
        }
        
    }
    
    # reset input arrays
    @{$x_ref} = @x_new;
    @{$y_ref} = @y_new;
    $max_i = $#{$x_ref};
    undef( @x_new );
    undef( @y_new );
    
    if( defined($args{VERBOSE}) ){
        printf( "${spacing}  Culled size = %d\n", $max_i + 1 );
    }                  
}

###################################################################################
# my_derivative
#   finds derivative of an array
#   Notes:
#     --test6 --deriv
#       If used lsp, got a spike at the start/stop of the
#       non-flat areas.  So, perhaps in general it is best to
#       always use the slope from the least-squares-linear fit.
#   
#   If given maxs/mins, will set those values to 0 and adjust the least squares
#     window accordingly.
sub my_derivative{
    my %args = (
        BY           => undef, # by (log) for extrema
        DERIV        => undef, # the derivative at each value
        EXTREMA_INFO => undef, # info from extrema (if not supplied, will get)
        SPACING      => undef, # spacing for verbose prints
        X            => undef, # X values, equal spacing if not defined
        Y            => undef, # Y values
        VERBOSE      => undef, # if verbose
        QUICK        => undef, # deriv is quickly changing at these indices
        RECUR        => undef, # if called recursively (to not repeat call)
        NOISE        => undef, # noise factor (used for box_window_width)
        @_,
        );
    my $args_valid = "BY|DERIV|EXTREMA_INFO|NOISE|RECUR|SPACING|X|Y|VERBOSE|QUICK";
    my(
        $arg,
        $box_window_ratio,
        @deriv,
        $deriv_ref,
        %extrema_info,
        $extrema_info_ref,
        %fit_info,
        $i,
        $ierr,
        $m_aft,
        $m_bef,
        $m_max,
        $max_i,
        $noise,
        @quick,
        $spacing,
        $start,
        $stop,
        @x,
        $x_distance_total,
        $x_ref,
        $x_window_width,
        $y_ref,
        $quick_ref,
        %quick_hash,
        );

    $ierr = 0;
    
    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # check args

    if( defined($args{SPACING}) ){
        $spacing = $args{SPACING};
    }
    else{
        $spacing = "";
    }

    $extrema_info_ref = $args{EXTREMA_INFO};

    # X
    if( defined $args{X} && ref($args{X}) ne "ARRAY" ){
        $ierr = 1;
        &print_error( "Must supply X array",
                      $ierr );
        exit( $ierr );
    }
    # if given X
    if( defined( $args{X}) ){
        $x_ref = $args{X};
    }
    # if not given X, use equal spacing
    else{
        @x = (0..$#{$y_ref});
        $x_ref = \@x;
    }

    # Y
    if( ! defined $args{Y} || ref($args{Y}) ne "ARRAY" ){
        $ierr = 1;
        &print_error( "Must supply Y array",
                      $ierr );
        exit( $ierr );
    }
    $y_ref = $args{Y};

    # noise
    if( defined($args{NOISE}) ){
        $noise = $args{NOISE};
    }
    else{
        $noise = .01;
    }

    # DERIV
    # Y
    if( ! defined $args{DERIV} || ref($args{DERIV}) ne "ARRAY" ){
        $ierr = 1;
        &print_error( "Must supply Y array",
                      $ierr );
        exit( $ierr );
    }
    $deriv_ref = $args{DERIV};

    # number of points
    $max_i = $#{$x_ref};

    if( defined($args{VERBOSE}) ){
        print "${spacing}my_derivative() max_i=$max_i noise=$noise\n";
    }
    
    # QUICK
    $quick_ref = $args{QUICK};
    if( ! defined($quick_ref) ){

        undef( @quick );
        if( ! defined($extrema_info_ref) ){
            if( defined($args{VERBOSE}) ){
                print "${spacing}  Finding extrema for keep info\n";
            }
            &extrema( X=>$x_ref, Y=>$y_ref, NOISE=>$noise,
                      INFO=>\%extrema_info, SPACING=>"$spacing    ",
                      BY=>$args{BY}, VERBOSE=>$args{VERBOSE} );
            $extrema_info_ref = \%extrema_info;
        }

        # also keep the quick values (before and after)
        if( defined($$extrema_info_ref{quick}) ){
            push( @quick, @{$$extrema_info_ref{quick}} );
            if( defined($args{VERBOSE}) ){
                print "${spacing}    indices kept: ", $#quick + 1, "\n";
            }
        }
        $quick_ref = \@quick;
    }
    %quick_hash = map{$_=>1} @{$quick_ref};

    # x_window_width: size of box window to use
    # size of each window will be x_window_width/$box_window_ratio
    if( $noise > 0 ){
        $box_window_ratio = int(1/$noise) / 2;
    }
    else{
        $box_window_ratio = 1e10;
    }
    if( $box_window_ratio < 1 ){
        $box_window_ratio = 1;
    }
    $x_distance_total= $$x_ref[-1] - $$x_ref[0];
    $x_window_width = $x_distance_total / (2 * $box_window_ratio);

    # my_fit in box_window for each point
    $i = 0;
    while( $i <= $max_i ){

        # sanity check
        if( $i < $max_i && $$x_ref[$i+1] <= $$x_ref[$i] ){
            $ierr = 1;
            &print_error( "x values must be increasing (index=$i)", $ierr );
            exit( $ierr );
        }

        # get start/stop indices given
        # array of x vals, center index, width desired, and values to keep
        &my_get_start_stop_width($x_ref, $i, $x_window_width, \%quick_hash,
                                 \$start, \$stop );

        # look at values before and after this point to see if it should
        # restrict this range further
        # special case if $start==$stop : pick side with greatest slope
        if( $stop == $start ){

            # m_bef and m_aft
            undef( $m_bef );
            undef( $m_aft );
            undef( %fit_info );
            $fit_info{find_m} = "";
            $fit_info{index}  = $i;
            $fit_info{method} = "lsl";
            if( $i > 0 ){
                &my_fit($x_ref, $y_ref, $i - 1, $i, \%fit_info );
                $m_bef = $fit_info{m};
            }
            if( $i < $max_i ){
                &my_fit($x_ref, $y_ref, $i, $i+1, \%fit_info );
                $m_aft = $fit_info{m}
            }

            # only 1 point
            if( ! defined($m_bef) && ! defined($m_aft) ){
                $m_max = 0;
            }
            # at start
            elsif( ! defined($m_bef) ){
                $m_max = $m_aft;
            }
            # at end
            elsif( ! defined($m_aft) ){
                $m_max = $m_bef;
            }
            # bef larger
            elsif( abs($m_bef) > abs($m_aft) ){
                $m_max = $m_bef;
            }
            # aft larger
            else{
                $m_max = $m_aft;
            }
                        
            $deriv[$i] = $m_max;
            $i++;
            next;
        }

        # if the start/stop is a quick, need to decide how to deal
        # with that
        elsif( defined($quick_hash{$start}) ||
               defined($quick_hash{$stop}) ){

            # stop
            if( defined($quick_hash{$stop}) ){
                # skip: points before $i are the same and stop is not
                if( $$y_ref[$i] == $$y_ref[$i-1] &&
                    $$y_ref[$i] != $$y_ref[$stop] ){
                    $stop--;
                }
                else{
                }
            }

            # start
            if( defined($quick_hash{$start}) ){
                # skip: points after $i are the same and start is not
                if( $$y_ref[$i] == $$y_ref[$i+1] &&
                    $$y_ref[$i] != $$y_ref[$start] ){
                    $start++;
                }
                else{
                }
            }
        }

        # find fit (returns slope)
        undef( %fit_info );
        $fit_info{find_m} = "";
        $fit_info{index}  = $i;
        $fit_info{method} = "lsl";
        &my_fit( $x_ref, $y_ref, $start, $stop, \%fit_info );
        $deriv[$i] = $fit_info{m};
        $i++;
        next;
    }

    @{$deriv_ref} = @deriv;

    grep( $_ = sprintf( "%.15e", $_), @${deriv_ref} );
    
}

###################################################################################
# my_fit
#   On a segment [$start..$stop], do a fit
#
# args
# ====
#   x_ref, y_ref, start, stop: ref to array x/y vals and the start/stop indices
#   info: inout hash
#     index:
#       inout
#       The index you are interested in getting a value/slope for
#     method, method_use
#       in, out
#       If not defined, will pick the "best" one.
#       Whitespace separated list of methods.
#         !<method> --> not that <method>
#       On out, will be set to the method used.
#     m, find_m:
#       out, in
#       If find_m set to "", means "calculate slope at that point".
#       This can force both "lsp" and "box" to be calculated...so will
#       be more expensive.
#     y:
#       out
#       The fitted y value.
#     x_orig, y_orig
#       out
#       original x/y values
#     <methods>
#     none: Was determined that no smoothing needed
#        y: fitted y value
#     lsl: least squares linear: y = mx + b
#        y:    fitted y value
#        m, b: equation values
#     lsp: least squares parabolic: y = a + bx + cx^2
#       y:       fitted value
#       a, b, c: equation values
#       m:       slope
#     box: box window smoothing
#       y: fitted value
#       distance_factor, distance_factor_use: in,out weighting width (1-4)
#       m: slope (just from lsp)
#
# notes
# =====
#   o It is assumed that start/stop are already set to resonable values
#     (called from extrema() where various sharp points are already found)
#
sub my_fit{
    my(
        $x_ref,
        $y_ref,
        $start,
        $stop,
        $info_ref,
        ) = @_;
    my(
        @answer,
        $c,
        %calc,
        $col,
        @col_non_zero,
        $denom,
        $dir,
        $dist,
        $distance_factor,
        $distance_factor_default,
        $done,
        $factor,
        $g_sd,
        $i,
        $index,
        $index_this,
        $index_shifted,
        $ierr,
        $lsp_c_b_rel,
        @matrix,
        $max,
        $method,
        @methods,
        $mult,
        $N,
        $numer,
        $r,
        $rel_diff,
        @result,
        $row,
        $shift_x,
        $shift_y,
        $size,
        $smooth_it,
        $sum_x_2,
        $sum_x_2_y,
        $sum_x_3,
        $sum_x_4,
        $sum_x,
        $sum_xy,
        $sum_y,
        $val,
        $weight,
        $weight_after,
        $weight_before,
        $weight_total,
        $x_new,
        @xs,
        $y_after,
        $y_before,
        @ys,
        );

    # number of points
    $N      = $stop - $start + 1;

    # cuttoff point for trying box method also (do not do if practically line)
    $lsp_c_b_rel = 1e-3;

    $index = $$info_ref{index};
    if( ! defined($index) ){
        $index = $start;
        $$info_ref{index} = $index;
    }

    $$info_ref{x_orig} = $$x_ref[$index];
    $$info_ref{y_orig} = $$y_ref[$index];

    # minimize rounding errors of large numbers, operate on
    # shifted data (x[index] -> 0, y[index] -> 0).
    $shift_x = $$x_ref[$index];
    $shift_y = $$y_ref[$index];
    @xs = @{$x_ref}[$start..$stop];
    grep( $_ -= $shift_x, @xs );
    @ys = @{$y_ref}[$start..$stop];
    grep( $_ -= $shift_y, @ys );
    
    # All methods available
    @methods = ("none", "lsl", "lsp", "box");

    # If given $$info_ref{method}, limit based on that
    if( defined($$info_ref{method}) && $$info_ref{method} =~ /\S/ ){
        # if not given a "!" (not), just use those
        if( $$info_ref{method} !~ /\s+\!/ ){
            foreach $method ( split(/\s+/, $$info_ref{method}) ){
                $calc{$method} = "";
            }
        }
        # if given nots, add all then remove
        else{
            foreach $method ( @methods ){
                $calc{$method} = "";
            }
            foreach $method ( split(/\s+/, $$info_ref{method}) ){
                if( $method =~ /\!(\S+)/ ){
                    delete($calc{$1});
                }
            }
        }
    }

    else{
        # by default, use these.
        # Currently, will only use lsp if a straight line.
        # box smoothing at edges of a sloped line does not do
        # well (tends to curl edges) (--test7 --deriv:1)
        $calc{box} = "";
        $calc{lsp} = "";
    }

    # Check 'none' first
    # if all data increasing or decreasing, then choose 'none'
    # currently turned off
    if( defined($calc{none}) ){
        # find first different value
        undef( $dir );
        for( $i = 1; $i < $N; $i++ ){
            if( $$y_ref[$i] > $$y_ref[0] ){
                $dir = ">";
                last;
            }
            elsif( $$y_ref[$i] < $$y_ref[0] ){
                $dir = "<";
                last;
            }
        }
        # start checking after next index for opposite dir
        $index_this = $i;
        undef( $smooth_it );
        if( defined($dir) ){
            if( $dir eq ">" ){
                for( $i = $index_this; $i < $N; $i++ ){
                    if( $$y_ref[$i] > $$y_ref[$i+1] ){
                        $smooth_it = "";
                        last;
                    }
                }
            }
            else{
                for( $i = $index_this; $i < $N; $i++ ){
                    if( $$y_ref[$i] < $$y_ref[$i+1] ){
                        $smooth_it = "";
                        last;
                    }
                }
            }
        }

        # if never switches, no smoothing and do not bother checking others
        if( ! defined($smooth_it) ){
            $$info_ref{none}{y} = $$y_ref[$index];
            undef( %calc );
            $calc{none} = "";
        }

    }
    
    # box uses lsp for m
    if( defined($calc{box}) && defined($$info_ref{find_m}) ){
        $calc{lsp} = "";
    }
       
    # lsl/lsp
    if( defined($calc{lsl}) || defined($calc{lsp})  ){
        $sum_x     = 0;
        $sum_x_2   = 0;
        $sum_xy    = 0;
        $sum_y     = 0;

        for( $i = 0; $i < $N; $i++ ){
            $sum_x     += $xs[$i];
            $sum_x_2   += $xs[$i]**2;
            $sum_xy    += $xs[$i]*$ys[$i];
            $sum_y     += $ys[$i];
        }
    }

    # lsp
    if( defined($calc{lsp}) ){
        $sum_x_3   = 0;
        $sum_x_4   = 0;
        $sum_x_2_y = 0;
        for( $i = 0; $i < $N; $i++ ){
            $sum_x_3   += $xs[$i]**3;
            $sum_x_4   += $xs[$i]**4;
            $sum_x_2_y += ($xs[$i]**2) * $ys[$i];
        }
    }
        
    # -------------------------
    # lsl: least squares linear
    # -------------------------
    # y = mx + b;
    if( defined($calc{lsl}) ){
        $numer = $N*$sum_xy  - $sum_x*$sum_y;
        $denom = $N*$sum_x_2 - $sum_x**2;
        if( $denom != 0 ){
            $$info_ref{lsl}{m} = $numer/$denom;
        }
        # better have 0/0
        else{
            if( $numer == 0 ){
                $$info_ref{lsl}{m} = 0;
            }
            else{
                $ierr = 1;
                &print_error( "got $numer/$denom - expected $numer==0", $ierr );
                exit( $ierr );
            }
        }

        # have a floor for slope with respect to y value to reduce roundoff noise
        if( $$y_ref[$index] != 0 &&
            abs($$info_ref{lsl}{m}/$$y_ref[$index]) < 1e-9 ){
            $$info_ref{lsl}{m} = 0;
        }
        
        # b (remember to add back in the subtracted start vals)
        $$info_ref{lsl}{b} = ($sum_y/$N + $shift_y) - $$info_ref{lsl}{m}*($sum_x/$N + $shift_x);
        $$info_ref{lsl}{y} = $$info_ref{lsl}{m} * $$x_ref[$index] + $$info_ref{lsl}{b};
    }
    
    # ----------------------------
    # lsp: least squares parabolic
    # ----------------------------
    # y = a + bx + cx**2
    #
    # sum(y)     = a N        + b sum(x)   + c sum(x^2)
    # sum(xy)    = a sum(x)   + b sum(x^2) + c sum(x^3)
    # sum(x^2 y) = a sum(x^2) + b sum(x^3) + c sum(x^4)
    if( defined($calc{lsp}) ){
        @result = (
            $sum_y,
            $sum_xy,
            $sum_x_2_y,
            );
        @matrix = (
            [ $N,         $sum_x,   $sum_x_2 ], 
            [ $sum_x,     $sum_x_2, $sum_x_3 ],
            [ $sum_x_2,   $sum_x_3, $sum_x_4 ],
            );
        
        $size = $#matrix + 1;
        undef( @col_non_zero );
        for( $col = 0; $col < $size; $col++ ){
            # find largest magnitude row
            $max = -1;
            for( $r = 0; $r < $size; $r++ ){
                if( abs($matrix[$r][$col]) > $max ){
                    # previous cols must be 0
                    undef( $done );
                    for( $c = 0; $c < $col; $c++ ){
                        if( $matrix[$r][$c] != 0 ){
                            $done = "";
                            last;
                        }
                    }
                    if( ! defined( $done ) ){
                        $max = abs($matrix[$r][$col]);
                        $row = $r;
                    }
                }
            }
            # non-determined matrix = will choose 0 for that value
            # by not setting col_non_zero
            # this means only 2 points
            if( $max == 0 ){
                next;
            }
            $col_non_zero[$row] = $col;
            $factor = $matrix[$row][$col];
            
            # foreach row, subtract 
            for( $r = 0; $r < $size; $r++ ){
                if( $r == $row ){
                    next;
                }
                $mult = $matrix[$r][$col] / $factor;
                for( $c = 0; $c < $size; $c++ ){
                    $matrix[$r][$c] -= $mult * $matrix[$row][$c];
                }
                $result[$r]     -= $mult * $result[$row];
                # for roundoff, just set other vals on that col to 0
                $matrix[$r][$col] = 0;
            }
        }
        
        # answer
        #  y = a + bx + cx^2
        # init a/b/c to 0 (for 1-point and 2-point only datasets)
        for( $c = 0; $c < $size; $c++ ){
            $answer[$c] = 0;
        }
        for( $r = 0; $r < $size; $r++ ){
            if( defined( $col_non_zero[$r]) ){
                $answer[$col_non_zero[$r]] = $result[$r] / $matrix[$r][$col_non_zero[$r]];
            }
        }
        $$info_ref{lsp}{a} = $answer[0];
        $$info_ref{lsp}{b} = $answer[1];
        $$info_ref{lsp}{c} = $answer[2];
        
        # shift back
        $$info_ref{lsp}{a} =
            $$info_ref{lsp}{a} +
            $shift_y -
            $$info_ref{lsp}{b} * $shift_x +
            $$info_ref{lsp}{c} * ($shift_x**2);
        $$info_ref{lsp}{b} =
            $$info_ref{lsp}{b} -
            2 * $$info_ref{lsp}{c} * $shift_x;
        
        $$info_ref{lsp}{y} =
            $$info_ref{lsp}{a} +
            $$info_ref{lsp}{b} * $$info_ref{x_orig} +
            $$info_ref{lsp}{c} * ($$info_ref{x_orig} ** 2);
        # relative slope contribution due to b and c (not relative yet)
        $$info_ref{lsp}{m_b} = $$info_ref{lsp}{b};
        $$info_ref{lsp}{m_c} = $$info_ref{lsp}{c} * $$info_ref{x_orig};
        $$info_ref{lsp}{m} = $$info_ref{lsp}{m_b} + $$info_ref{lsp}{m_c};
        # now relative
        $$info_ref{lsp}{m_b_rel} = abs($$info_ref{lsp}{m_b});
        $$info_ref{lsp}{m_c_rel} = abs($$info_ref{lsp}{m_c});
        $denom = ($$info_ref{lsp}{m_b_rel} + $$info_ref{lsp}{m_c_rel})/2;
        if( $denom != 0 ){
            $$info_ref{lsp}{m_b_rel} /= $denom;
            $$info_ref{lsp}{m_c_rel} /= $denom
        }
    }

    # --------------------
    # box window smoothing
    # --------------------
    if( defined($calc{box}) ){
        # g_sd: just use following for standard deviation
        # todo: find the real sd and see if really mean variance or not
        $g_sd = abs(($xs[0]-$xs[-1]/2));
        # for computing weights - really want to have the near values
        # contribute more.  1 was too little and the max detected
        # in --test1 was wrong for second spike.
        # could set this differently depending on whether or not
        # x_keep specified...
        # larger the number, faster the dropoff for distant points.
        $distance_factor_default = 4;
        if( defined($$info_ref{box}{distance_factor}) ){
            $distance_factor = $$info_ref{box}{distance_factor};
        }
        else{
            $distance_factor = $distance_factor_default;
            if( $stop - $start <= 3 ){
                $distance_factor = $distance_factor/4;
            }
        }
        $index_shifted = $index - $start;
        $$info_ref{box}{distance_factor_use} = $distance_factor;
        $x_new = $xs[$index_shifted];
        $$info_ref{box}{y} = 0;
        $weight_total  = 0;
        $weight_before = 0;
        $weight_after  = 0;
        $y_before      = 0;
        $y_after       = 0;
        if( $#xs > 0 ){
            $val = 0;
            for( $i = 0; $i <= $#xs; $i++ ){
                # distance from X - closer vals weight more
                $dist = $distance_factor*abs($xs[$i] - $x_new);
                $weight = exp( -0.5 * ( ($dist)/$g_sd )**2 )/sqrt(2*(Math::Trig::pi)*$g_sd**2);
                $val += $ys[$i] * $weight;
                if( $i < $index_shifted ){
                    $y_before += $ys[$i] * $weight;
                    $weight_before += $weight;
                }
                elsif( $i > $index_shifted){
                    $y_after += $ys[$i] * $weight;
                    $weight_after += $weight;
                }
                $weight_total += $weight;
            }
            $$info_ref{box}{y} = $val;
        }
        else{
            $$info_ref{box}{y} = $ys[$i];
            $weight_total = 1;
        }
        $$info_ref{box}{y} /= $weight_total;
        $$info_ref{box}{y} += $shift_y;
        $denom = ($weight_before + $weight_after)/2;
        if( $denom == 0 ){
            $denom = 1;
        }
        $rel_diff = abs($weight_before - $weight_after)/$denom;
        $$info_ref{box}{weight_rel_diff} = $rel_diff;
        if( $weight_before != 0 ){
            $y_before /= $weight_before;
        }
        if( $weight_after != 0 ){
            $y_after  /= $weight_after;
        }
        $y_before += $shift_y;
        $y_after  += $shift_y;
        $denom = $$info_ref{box}{y};
        if( $denom == 0 ){
            $denom = 1;
        }
        $rel_diff = abs($y_before - $y_after)/$denom;
        $$info_ref{box}{y_rel_diff} = $rel_diff;

        # For the derivative, just use the one already calculated from lsl.
        # Probably not the best way to do this.
        #   --test6 --deriv
        #     If used lsp, got a spike at the start/stop of the
        #     non-flat areas.
        $$info_ref{box}{m} = $$info_ref{lsl}{m};
    }

    # ===========
    # pick method
    # ===========

    undef( $method );

    # if just one method, set to use that
    @methods = keys %calc;
    if( $#methods == 0 ){
        $method = $methods[0];
    }

    # lsp: a + bx + cx^2
    if( ! defined($method) && defined($calc{lsp}) ){
        # If c is basically 0, then straight line so use lsp
        # Box smoothing of sloped straight line tends to curl edges (--test7 --deriv:1)
        #print "debug $$info_ref{lsp}{a} $$info_ref{lsp}{b} $$info_ref{lsp}{c}\n";
        if( abs($$info_ref{lsp}{c}) <= 1e-12 ){
            $method = "lsp";
        }
    }

    # if method still is not set, use
    if( ! defined($method) ){
        if( defined($calc{box}) ){
            # --test7 --deriv shows what happens if you just use box smoothing
            #   everywhere.  Box seems to work best when the following are true:
            #     weight before and after point close
            #     not basically straight line
            #       slope due to c is small relative to slope due to b or
            #       flat line

            # some other possible metrics:
            #   calculated y before and after point close
            #     $$info_ref{box}{y_rel_diff} <= .001 &&
            #     still want to smooth out corners of stairstep (--test3:0 --smooth --noise1)

            # maybe do not pick box if weight before/after differ by a lot?
            # weight_rel_diff
            $method = "box";

            #if( $$info_ref{x_orig} > 20 && $$info_ref{x_orig} < 30 ){
            #    print "$$info_ref{index} x= $$x_ref[$start] - $$info_ref{x_orig} $$x_ref[$stop] N=$N w=$$info_ref{box}{weight_rel_diff} c=$$info_ref{lsp}{m_c_rel} >= $lsp_c_b_rel mb=$$info_ref{lsp}{m_b} mc=$$info_ref{lsp}{m_c}";
            #    if( defined( $method ) ){
            #        print " m=$method";
            #    }
            #    print "\n";
            #}
        }
    }

    # use lsp (must be a straight line)
    if( ! defined($method) && defined($calc{lsp}) ){
        $method = "lsp";
    }
    
    # still not defined , lsp : at least 2 points
    if( ! defined($method) ){
        if( $N > 1 && defined($calc{lsp})){
            $method = "lsp";
        }
    }

    $$info_ref{method_use} = $method;
    $$info_ref{y}          = $$info_ref{$method}{y};
    $$info_ref{m}          = $$info_ref{$method}{m};
}

###################################################################################
# my_get_start_stop_width
#   get start/stop indices given
#     array of x vals, center index, width desired, and values to keep
#   Does include keep value edges but not beyond.
#   If the value given is a keep, the return will only be that keep value.
#   To effectively not include any keep values, modify keep_ref
#   to include the point before and after the keep.
#   It is assumed that the previous start/stop values are from
#   the previous $i (which speeds up the search)
sub my_get_start_stop_width{
    my(
        $x_ref,
        $i,
        $x_window_width,
        $keep_ref,
        $start_ref, # in -> previous value, out -> new value
        $stop_ref,  # ^^
        ) = @_;
    my(
        $at_edge,
        $dir,
        $done,
        $edge_point,
        $i_try,
        $max_i,
        $max_index_diff,
        $start_min,
        $this_ref,
        $type,
        $window_diff_new,
        $window_diff_off,
        $x_window_width_new,
        $x_val,
        );
    
    # start/stop will be the set of points:
    #  Does not go beyond any "keep" points (but does include them)
    #  Max width is 1/2 width of box on each side
    #  Same width on each side
    $x_val = $$x_ref[$i];
    $max_i = $#$x_ref;
    # --test6 --smooth
    #   was 50 - but had a problem smoothing because large slope
    #   and lots of points below did not balance points above.
    #   Try 20.
    #   Also, 10 on each side will be faster...
    $max_index_diff = 20;

    # =============================================
    # start_min = can never start before this point
    # =============================================
    # do this check with previous $$start_ref/$$stop_ref
    $start_min = -1;

    # make sure start_min >= previous start
    if( defined($$start_ref) ){
        if( $start_min < $$start_ref ){
            $start_min = $$start_ref;
        }
    }

    # if going past a new keep, then start_min == $$stop_ref
    if( defined($$stop_ref) && $i > $$stop_ref ){
        $start_min = $$stop_ref;
    }
    
    # ==================
    # now know start_min
    # ==================

    # init start/stop
    if( !defined($$start_ref) ){
        $$start_ref = $i;
    }
    if( !defined($$stop_ref) ){
        $$stop_ref  = $i;
    }
    if( $$start_ref > $i ){
        $$start_ref = $i;
    }
    # stop is less than current $i
    # cannot have start go before this stop
    if( $$stop_ref < $i ){
        $$stop_ref = $i;
    }
    # quick check to see if this new $i is at a keep
    if( defined($$keep_ref{$i}) ){
        $$start_ref = $i;
        $$stop_ref  = $i;
        return;
    }

    # quick check to see if the previous stop was at
    # a limiter (a keep or at end of array)
    # If so, set x_window_width_new to that value.
    # Otherwise, start will fan out, then fan back at end.
    $x_window_width_new = $x_window_width/2;
    if( $i <= $$stop_ref && defined($$keep_ref{$$stop_ref}) ){
        $x_window_width_new = $$x_ref[$$stop_ref] - $x_val;
    }
    if( $$x_ref[-1] - $x_val < $x_window_width_new ){
        $x_window_width_new = $$x_ref[-1] - $x_val;
    }

    #$debugloops = 0;

    # find start (get new window), stop (with that new window), start again
    # need to do start again since stop could have hit a keep
    # foreach start, stop, start
    foreach $type ( "start", "stop", "start" ){
        if( $type eq "start" ){
            $this_ref   = $start_ref;
            $dir        = 1;
            $edge_point = 0;
        }
        else{
            $this_ref   = $stop_ref;
            $dir        = -1;
            $edge_point = $max_i;
        }

        # might already be at a keep
        if( defined($$keep_ref{$$this_ref}) ){
            # if this is outside window move so not at keep
            if( abs($x_val - $$x_ref[$$this_ref]) > $x_window_width_new ){
                $$this_ref = $$this_ref + $dir;
            }
        }

        undef( $done );
        while( ! defined($done) ){

            # keep
            if( defined($$keep_ref{$$this_ref}) ){
                last;
            }

            # past or at width
            if( abs($x_val - $$x_ref[$$this_ref]) >= $x_window_width_new ){
                # at the point
                if( $$this_ref == $i ){
                    $done = "";
                    last;
                }
                # previous point less than window
                elsif( abs($x_val - $$x_ref[$$this_ref+$dir]) < $x_window_width_new ){
                    $done = "";
                    last;
                }
                # previous point still >= window
                else{
                    $$this_ref = $$this_ref + $dir;
                    next;
                }
            }

            # not at width yet
            else{
                # edge done
                if( $$this_ref == $edge_point ){
                    last;
                }
                # if start and already at start_min, then done
                elsif( $type eq "start" && $$this_ref eq $start_min ){
                    last;                    
                }
                # back up
                else{
                    $$this_ref = $$this_ref - $dir;
                    if( abs($i - $$this_ref) >= $max_index_diff ){
                        $done = "";
                    }
                    next;
                }
            }
        }

        # if at the edge
        undef( $at_edge );
        if( $$this_ref == $edge_point ){
            $at_edge = "";
        }

        # obey max_index_diff
        # keep this check/set here because might have left before check above
        if( abs($i - $$this_ref) > $max_index_diff ){
            $$this_ref = $i - $max_index_diff*$dir;
        }
        # due to rounding errors, pick closest match window
        # wider point (not already at keep or at edge)
        if( ! defined($$keep_ref{$$this_ref}) && ! defined( $at_edge ) ){
            $i_try = $$this_ref - $dir;
            $window_diff_new = abs($x_window_width_new -
                                   abs(($$x_ref[$i]-$$x_ref[$$this_ref])));
            $window_diff_off = abs($x_window_width_new -
                                   abs(($$x_ref[$i]-$$x_ref[$i_try])));
            if( $window_diff_off < $window_diff_new ){
                $$this_ref = $i_try;
            }
        }

        # narrower point (not already at i)
        if( $$this_ref != $i ){
            $i_try = $$this_ref + $dir;
            $window_diff_new = abs($x_window_width_new -
                                   abs(($$x_ref[$i]-$$x_ref[$$this_ref])));
            $window_diff_off = abs($x_window_width_new -
                                   abs(($$x_ref[$i]-$$x_ref[$i_try])));
            if( $window_diff_off < $window_diff_new ){
                $$this_ref = $i_try;
            }
        }

        # obey start_min
        if( $type eq "start" ){
            if( $$this_ref < $start_min ){
                $$this_ref = $start_min;
            }
        }

        # reset width
        $x_window_width_new = abs(($$x_ref[$i]-$$x_ref[$$this_ref]));

    } # foreach start, stop, start

}

###################################################################################
# my_nudge
#   Takes an array of monotonic values and nudges them so that the values are unique.
#   1, 2, 2, 2, 2, 3 --> 1, 1.4, 1.8, 2.2, 2.6, 3 (or something smarter)
sub my_nudge{
    my %args = (
        VALS         => undef, # reference to values
        @_,
        );
    my $args_valid = "VALS";
    my(
        $arg,
        $delta,
        $found,
        $i,
        $ierr,
        $index,
        $index_last,
        $index_same_start,
        $index_same_stop,
        $val_same,
        $val_start,
        $val_stop,
        $vals_ref,
        );

    $ierr = 0;

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # check args
    if( ! defined $args{VALS} || ref($args{VALS}) ne "ARRAY" ){
        $ierr = 1;
        &print_error( "Must supply VALS array",
                      $ierr );
        exit( $ierr );
    }
    $vals_ref = $args{VALS};

    # quick check if already in order
    $index_last = $#{$vals_ref};
    for( $i = 0; $i < $index_last; $i++ ){
        if( $$vals_ref[$i] >= $$vals_ref[$i+1] ){
            $found = "";
            last;
        }
    }
    if( ! defined($found) ){
        return( $ierr );
    }

    $index_same_start = 0;
    $index_same_stop  = 0;
    $index = 0;
    while( $index < $index_last ){
        $index_same_start = $index;
        $index_same_stop  = $index;
        $val_same = $$vals_ref[$index_same_start];
        while( $index_same_stop < $index_last ){
            $index_same_stop++;
            if( $$vals_ref[$index_same_stop] != $val_same ){
                $index_same_stop--;
                last;
            }
        }

        # if found some of the same
        if( $index_same_start < $index_same_stop ){

            # get val_start, val_stop
            if( $index_same_start > 0 ){
                $val_start = $$vals_ref[$index_same_start - 1];
            }
            else{
                $val_start = $$vals_ref[$index_same_start];
                $index_same_start++;
            }
            if( $index_same_stop < $index_last ){
                $val_stop = $$vals_ref[$index_same_stop + 1];
            }
            else{
                $val_stop = $$vals_ref[$index_same_stop];
                $index_same_stop--;
            }

            # space / number of units we need
            $delta = ($val_stop - $val_start) / ( $index_same_stop - $index_same_start + 2 );

            # reset numbers
            for( $i = $index_same_start; $i <= $index_same_stop; $i++ ){
                $$vals_ref[$i] = $val_start + ($i - $index_same_start + 1) * $delta;
            }
        }

        $index = $index_same_stop + 1;

    }

}

###################################################################################
# my_smooth
#   Smooth a curve
sub my_smooth{
    my %args = (
        AREAS        => undef, # old area, new area, error (1=100%)
        BY           => undef, # smoothing by (log)
        X            => undef, # X values, equal spacing if not defined
        X_KEEP       => undef, # x indices that must maintain their Y value.
                               #   The points around the keep are saved as well.
                               #   If not given, will call extrema and x_keep =
                               #     quick
                               #     sharp rise/fall of max and min
        EXTREMA_INFO => undef, # info from extrema (if not supplied, will get)
        Y            => undef, # Y values
        VERBOSE      => undef, # if verbose
        SPACING      => undef, # number of spaces to indent
        NUM_SMOOTHS  => undef, # override the number of smoothing passes
        NOISE        => undef, # given a noise factor for smoothing (if not given X_KEEP)
        @_,
        );
    my $args_valid = "AREAS|BY|EXTREMA_INFO|NOISE|NUM_SMOOTHS|SPACING|VERBOSE|X|X_KEEP|Y";
    my(
        @areas,
        $areas_ref,
        $arg,
        $box_window_ratio,
        $dist_fall,
        $dist_max,
        $dist_rise,
        %extrema_info,
        $extrema_info_ref,
        %fit_info,
        %fit_types,
        $i,
        $ierr,
        $index,
        $index_extrema,
        $index_point,
        $j,
        $keep_it,
        $max_i,
        $name,
        $noise,
        $num,
        $num_points,
        $num_smooths,
        $num_smooths_default,
        $pct,
        $range_fall,
        $range_rise,
        $range_y,
        $spacing,
        $start,
        $stop,
        $total,
        $type,
        @x_keep,
        $x_keep_ref,
        %x_keep_hash,
        $x_distance_total,
        $x_ref,
        $x_window_width,
        $y_ref,
        $val,
        @y_new,
        );

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # check args
    if( ! defined $args{X} || ref($args{X}) ne "ARRAY" ){
        $ierr = 1;
        &print_error( "Must supply X array",
                      $ierr );
        exit( $ierr );
    }
    $x_ref = $args{X};
    if( defined $args{X_KEEP} && ref($args{X_KEEP}) ne "ARRAY" ){
        $ierr = 1;
        &print_error( "X_KEEP must be array reference",
                      $ierr );
        exit( $ierr );
    }
    $x_keep_ref = $args{X_KEEP};
    if( ! defined $args{Y} || ref($args{Y}) ne "ARRAY" ){
        $ierr = 1;
        &print_error( "Must supply Y array",
                      $ierr );
        exit( $ierr );
    }
    $y_ref = $args{Y};

    if( defined($args{SPACING}) ){
        $spacing = $args{SPACING};
    }
    else{
        $spacing = "";
    }

    # AREAS before VERBOSE so areas_ref set correctly
    if( defined $args{AREAS} ){
        if( ref($args{AREAS}) ne "ARRAY" ){
            $ierr = 1;
            &print_error( "AREAS not an array",
                          $ierr );
            exit( $ierr );
        }
        $areas_ref = $args{AREAS};
    }

    # noise
    if( defined($args{NOISE}) ){
        $noise = $args{NOISE};
    }
    else{
        $noise = .01;
    }

    # AREAS before VERBOSE so areas_ref set correctly
    if( defined( $args{VERBOSE} ) ){
        if( ! defined( $areas_ref ) ){
            $areas_ref = \@areas;
        }
    }

    $extrema_info_ref = $args{EXTREMA_INFO};

    # number of smoothing passes - not sure if >1 is better
    $num_smooths_default = 2;
    if( defined($args{NUM_SMOOTHS}) ){
        $num_smooths = $args{NUM_SMOOTHS};
    }
    else{
        $num_smooths = $num_smooths_default;
    }

    $max_i = $#{$x_ref};

    if( defined($args{VERBOSE}) ){
        print "${spacing}my_smooth() max_i=$max_i noise=$noise num_smooths=$num_smooths\n";
    }

    # init X if needed
    if( $#{$x_ref} != $#{$y_ref} ){
        $#{$x_ref} = $#{$y_ref};
        for( $i = 0; $i <= $max_i; $i++ ){
            $$x_ref[$i] = $i;
        }
    }

    # area_old
    if( defined( $areas_ref ) ){
        $$areas_ref[0] = &my_get_area_shift($x_ref, $y_ref);
    }

    # create x_keep if needed
    if( ! defined( $x_keep_ref ) ){
        # find extrema if not supplied
        if( ! defined($extrema_info_ref) ){
            if( defined($args{VERBOSE}) ){
                print "${spacing}  Finding extrema for keep info\n";
            }
            # do not pass verbose here since summarized below
            &extrema( X=>$x_ref, Y=>$y_ref, NOISE=>$noise, BY=>$args{BY},
                      INFO=>\%extrema_info );
            $extrema_info_ref = \%extrema_info;
        }
        # max/min if pct% width of spike (pct rise/fall)
        $range_y = $$extrema_info_ref{array_stats}{range};
        # divide noise by more if need to be sharper (--test1 --smooth)
        $pct = $noise/2 * 100;
        if( defined($args{VERBOSE}) ){
            print "${spacing}  Boundaries kept:\n";
        }
        $dist_max = $$x_ref[-1] - $$x_ref[0];
        # loop through max/mins
        $index_extrema = 0;
        foreach $type ( @{$$extrema_info_ref{special_t}} ){
            $index = $$extrema_info_ref{special_i}[$index_extrema];
            $index_point = $$extrema_info_ref{$type}[$index];
            # % width that comes from extrema
            $name = "60";
            $i = $$extrema_info_ref{"${type}_rise_${name}"}[$index];
            $j = $$extrema_info_ref{"${type}_fall_${name}"}[$index];
            # distance between spike rise/fall
            $dist_rise  = abs($$x_ref[$i] - $$x_ref[$index_point]);
            $dist_fall  = abs($$x_ref[$j] - $$x_ref[$index_point]);
            $range_rise = abs($$y_ref[$i] - $$y_ref[$index_point] );
            $range_fall = abs($$y_ref[$j] - $$y_ref[$index_point] );
            # if below threshhold, it is a spike and keep it
            # no distance between rise/fall
            # distance between rise/fall is less than $pct of entire x axis
            # number of points between rise/fall is small
            $keep_it = "";
            if( $dist_max == 0 ){
                $keep_it .= ",1-point";
            }
            # rise (do not use this if the first max/min since might be edge)
            if( $index_extrema > 0 &&
                ( $range_rise > $range_y * ($pct/100) ) &&
                ( $dist_max > 0 && ($dist_rise/$dist_max)*100.0 < $pct) ){
                $keep_it .= ",rise";
            }
            # fall (do not use this if the last max/min since might be edge)
            if( $index_extrema < $#{$$extrema_info_ref{special_t}} &&
                ( $range_fall > $range_y * ($pct/100) ) &&
                ( $dist_max > 0 && ($dist_fall/$dist_max)*100.0 < $pct) ){
                $keep_it .= ",fall";
            }
            if( $keep_it =~ /\S/ ){
                $keep_it =~ s/^,//;
                push( @x_keep, $index_point );
                if( defined($args{VERBOSE}) ){
                    printf( "${spacing}    x=%22.15e y=%22.15e (i=%7d) ${type} ${name} rise/fall [$keep_it]\n",
                            $$x_ref[$index_point], $$y_ref[$index_point], $index_point);
                }
            }
            # next one
            $index_extrema++;
        }

        # also keep the quick values
        if( defined($$extrema_info_ref{quick}) ){
            foreach $val ( @{$$extrema_info_ref{quick}} ){
                if( defined($args{VERBOSE}) ){
                    printf( "${spacing}    x=%22.15e y=%22.15e (i=%7d) quick\n",
                            $$x_ref[$val], $$y_ref[$val], $val);
                }
                push( @x_keep, $val );
            }
        }

        if( defined($args{VERBOSE}) ){
            if( ! @x_keep ){
                print "${spacing}    <none>\n";
            }
        }

        # now point to it
        $x_keep_ref = \@x_keep;
    }
    
    # now stuff before/keep/after points into x_keep_hash
    # This will make it so the keeps are not used in the smoothing.
    foreach $val ( @$x_keep_ref ){
        $x_keep_hash{$val-1} = "";
        $x_keep_hash{$val}   = "";
        $x_keep_hash{$val+1} = "";
    }

    # x_window_width: size of box window to use
    # size of each window will be x_window_width/$box_window_ratio
    if( $noise > 0 ){
        $box_window_ratio = int(1/$noise) / 4;
    }
    else{
        $box_window_ratio = 1e10;
    }
    if( $box_window_ratio < 1 ){
        $box_window_ratio = 1;
    }
    $x_distance_total= $$x_ref[-1] - $$x_ref[0];
    $x_window_width = $x_distance_total / (2 * $box_window_ratio);

    for( $num = 0; $num < $num_smooths; $num++ ){

        if( defined($args{VERBOSE}) ){
            print "${spacing}  Smoothing pass ", $num+1, "/$num_smooths\n";
        }

        # smooth in box_window
        undef( $start );
        undef( $stop );
        undef( %fit_types );
        undef( @y_new );
        for( $i = 0; $i <= $max_i; $i++ ){

            # get start/stop indices given
            # array of x vals, center index, width desired, and values to keep
            &my_get_start_stop_width($x_ref, $i, $x_window_width, \%x_keep_hash,
                                     \$start, \$stop );

            # will be 0 for start==stop
            $num_points = $stop - $start + 1;
            if( $num_points > 1 ){
                undef( %fit_info );
                $fit_info{index} = $i;
                &my_fit( $x_ref, $y_ref, $start, $stop, \%fit_info );
                $fit_types{$fit_info{method_use}}++;
                $y_new[$i] = $fit_info{y};
            }
            else{
                $y_new[$i] = $$y_ref[$i];
            }
        }
        ### keeping max/min rise/fall?  check test5 and see squirly

        @{$y_ref} = @y_new;

        if( defined($args{VERBOSE}) ){
            $total = 0;
            foreach $type ( sort keys %fit_types ){
                $total += $fit_types{$type};
            }
            foreach $type ( sort keys %fit_types ){
                printf( "${spacing}  %5s rel=%6.2e (%d)\n",
                        $type, $fit_types{$type}/$total, $fit_types{$type} );
            }
        }
        
    }

    # roundoff since smoothing
    grep( $_ = sprintf( "%.13g", $_), @${y_ref} );

    if( defined( $areas_ref ) ){
        $$areas_ref[1] = &my_get_area_shift($x_ref, $y_ref);
        if( $$areas_ref[0] > 0 ){
            $$areas_ref[2] = ($$areas_ref[0]-$$areas_ref[1])/($$areas_ref[0]);
        }
        else{
            $$areas_ref[2] = $$areas_ref[1];
        }
        if( defined( $args{VERBOSE} ) ){
            printf("${spacing}  Original data -> Smoothed data: rel_area_error=%.2e\n", $$areas_ref[2] );
        }
    }
}

###################################################################################

#............................................................................
#...Name
#...====
#... datafile_setcond
#...
#...Purpose
#...=======
#... sets the condition used for getting values
#...
#...Arguments
#...=========
#... $cond     Intent: in
#...           Perl type: scalar
#...           the condition
#...
#...Program Flow
#...============
#... 1) set condition
#............................................................................
sub datafile_setcond
  {
      my( $cond ) = @_;
      $COND = $cond;
  }

#............................................................................
#...Name
#...====
#... get_sysinfo( \%sysinfo, <opts hash> )
#...
#...Purpose
#...=======
#... Populates a hash with system info.
#... Can overwrite old settings in \%sysinfo
#... Currently is sysinfo{<scalar>}.  If changed, might have to fix
#... various places.
#... 
#... See options below.
#............................................................................
sub get_sysinfo{
    my(
        $sysinfo_ref, # ref to %sysinfo
        ) = shift( @_ );
    my $args_valid = "PARTITION|PARTITION_QUICK|QUICK|SETIT|TMPENV_SET|TMPENV_UNSET";
    my %args = (
        SETIT => undef, # if also push onto %ENV (export to environment)
        PARTITION => undef, # If given, will set L_EAP_PPN based on this.
        PARTITION_QUICK => undef, # Assumes %sysinfo is valid data and sets:
                                  # L_EAP_PPN, L_EAP_NUMAPN
                                  # Does NOT reset L_OS - maybe should
        QUICK => undef, # sets some things for Makefile_vars.mk quck
        TMPENV_SET   => undef, # sysinfo -> ENV{rj_tmpenv_info_{var}}
        TMPENV_UNSET => undef, # clear out  ENV{rj_tmpenv_info_{var}}
        @_,
        );
    my(
        $arg,
        $batch_type,
        $com,
        $do_makefile_vars,
        $ex,
        $file,
        $file_find,
        $found_quick,
        $ierr,
        $key,
        $key_new,
        $line,
        @lines,
        $name,
        $numapn,
        $numapn_plus,
        $out,
        $partition,
        $partition_use,
        $partition_guess,
        $partition_quick,
        $pct,
        $ppn,
        $ppn_new,
        $ppn_plus,
        $ppn_reduction,
        $ppn_adjusted,
        $rest,
        %set,
        $status,
        $sysinfo_done,
        $val,
        $var,
        @vals,
        );

    $ierr = 0;

    # hack to get around perl_standardize.pl check
    $pct = '%';

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # TMPENV_SET
    if( defined( $args{TMPENV_SET} ) ){
        $ENV{"rj_tmp_info"} = "yes";
        foreach $name ( keys %{$sysinfo_ref} ){
            $ENV{"rj_tmp_info_${name}"} = $$sysinfo_ref{$name};
        }
        return( $ierr );
    }

    # TMPENV_UNSET
    if( defined( $args{TMPENV_UNSET} ) ){

        foreach $name ( keys %ENV ){
            if( $name =~ /^rj_tmp_info/ ){
                delete( $ENV{$name} );
            }
        }
        return( $ierr );
    }

    # rj_tmp_info shortcut
    # If set in ENV, use that instead of re-doing the discovery.
    if( defined( $ENV{rj_tmp_info} ) ){
        foreach $var ( keys %ENV ){
            if( $var =~ /rj_tmp_info_(\S+)/ ){
                $$sysinfo_ref{$1} = "$ENV{$var}";
            }
        }
        $sysinfo_done = "";
    }

    # PARTITION_QUICK
    if( defined( $args{PARTITION_QUICK} ) ){
        $partition_quick = $args{PARTITION_QUICK};
        # and use this for the partition if set to non-blank
        if( $partition_quick =~ /\S/ ){
            $partition = $partition_quick;
        }
    }

    # PARTITION
    if( ! defined($partition) ){
        if( defined( $args{PARTITION} ) ){
            $partition = $args{PARTITION};
        }
    }

    # partition - default is "" (not undefined)
    if( ! defined($partition) ){
        $partition = "";
    }

    # do Makefile_vars.mk
    $do_makefile_vars = "";

    if( defined($partition_quick) ){
        undef( $do_makefile_vars );
    }

    if( defined($sysinfo_done) ){
        undef( $do_makefile_vars );
    }

    # ----------------
    # Makefile_vars.mk
    # ----------------
    # Makefile that gives system info
    if( defined($do_makefile_vars ) ){

        # There is an environment variable L_EAP_MACH_OPT which is used
        # to set the environment up in the path:
        #   L_EAP_MACH_OPT = KNL
        #   source .cshrc (or .bashrc)
        #     calls Makefile_vars.mk
        #     sets L_EAP_OS to TR_KNL
        #   load environment variables
        # So, it is really only done once to load the modules then done.
        # We unset it in the .cshrc when done, and also unset it in
        # my_utils.pm::get_sysinfo() (since it is really only used once).
        delete( $ENV{L_EAP_MACH_OPT} );

        $file_find = "Makefile_vars.mk";
        $file = &which_exec( "$file_find", QUIET=>"", NOEXEC=>"" );
        if( $file !~ /\S/ ){
            $ierr = 1;
            &print_error( "Cannot find sysinfo file [$file_find]",
                          $ierr );
            exit( $ierr );
        }
        $ex = &which_exec( "gmake" );
        if( $ex !~ /\S/ ){
            $ex = &which_exec( "make" );
        }
        if( $ex !~ /\S/ ){
            $ierr = 1;
            &print_error( "Cannot find make command [tried gmake, make]",
                          $ierr );
            exit( $ierr );
        }
        $com = "$ex -f $file print_makefile_vars";
        # if quick specified, short-circuit these
        if( defined($args{QUICK}) ){
            $com .= " MAKEFILE_VARS_QUICK=yes";
        }
        $out = `$com 2>&1`;
        if( $out =~ /permission denied/i ||
            $out =~ /no rule to make target/i ){
            $ierr = 1;
            &print_error( "Odd error when running [$com]",
                          "\n$out",
                          $ierr );
            exit( $ierr );
        }
        foreach $line ( split( /\n/, $out ) ){
            $line =~ s/\s*$//;
            # <var until FIRST equals>=<value with possible multiple words>
            # NOTE: value could be empty...must make sure this is checked for
            #       There are places where it is assumed this is at least set.
            #       Do not change this to "not define if empty" unless you fix
            #       those other places.
            if( $line =~ /(\S+?)=(.*)$/ ){
                $key = $1;
                $val = $2;
                if( ! defined($val) ){
                    $val = "";
                }
                $$sysinfo_ref{$key} = $val;
                $set{$key}          = $val;
            }
        }

        # also put this in do_makefile_vars for now - might want to change
        # conceivable this might be expensive to do at some point.
        $$sysinfo_ref{batchid} = &my_get_batch_id();

    } # do_makefile_vars

    # ----------------------
    # DONE: Makefile_vars.mk
    # ----------------------

    # SETIT: push back onto environment if not already set
    # only if do_makefile_vars for now...might want to change
    if( defined( $args{SETIT} ) ){
        foreach $key ( keys %{$sysinfo_ref} ){
            # only do the L_ vars since sysinfo might already
            # have other things in it (eg, rj_tmp_info).
            if( $key !~ /^L_/ ){
                next;
            }
            # need to translate L_<VAR> to L_EAP_<var>
            $key_new = $key;
            if( $key_new !~ /^L_EAP_/ ){
                $key_new =~ s/^L_/L_EAP_/;
            }
            # Had this to not override previous values.
            # However, I think I had this for trinity and nids resetting...and now
            # I think I detect this correctly...so always reset this.
            #if( ! defined($ENV{$key_new}) ){
            $ENV{$key_new} = $$sysinfo_ref{$key};
        }
    }

    # --------------------------------
    # if sysinfo_done, can return now.
    # --------------------------------
    if( defined($sysinfo_done) ){
        return( $ierr );
    }

    # ---------
    # L_EAP_PPN
    # L_EAP_NUMAPN
    # ---------
    # o L_EAP_PPN = system processes per node
    #
    #   This is used for:
    #     The default number of mpi ranks per node.
    #     Figuring out the number of nodes needed when getting resources.
    #     Figuring out how full a node is
    #  
    #   This is often the number of cores on a node....with mods...
    #     - Leave some room for the os (eg, TR_KNL has 68 cores, use 64).
    #     - Different batch partitions will have different values.
    #       The node you are on might not match where you will be running.
    #  
    #   NOTES:
    #     - L_EAP_PPN_THIS
    #       This is used in various places in build, so still determined
    #       in Makefile_vars.mk.
    #
    # o L_EAP_NUMAPN
    #   non-uniform memory access per node (perhaps incorrect term)
    #   This is now basically the number of sockets per node.
    #   Used to tell mpi to get at least 1 rank per socket.
    #
    # o method:
    #   - Query batch system if you can.  slurm seems to have right
    #     info (might need to specify parition).
    #   - If that does not work, query the node you are on.
    # 

    # what batch system you are using
    $batch_type = $$sysinfo_ref{L_EAP_BATCH_TYPE} || "";

    # ------------------
    # Default partitions
    # ------------------
    # If you are not giving a partition, you likely need a default one.
    # This is because otherwise, the guess will be to find the
    # PPN/NUMAPN on the login node which might not match what is on the
    # compute node.
    # You might be able to find out the default partition by:
    #   slurm:
    #     sacctmgr -p show assoc user=$LOGNAME
    # However, we want to set the partition on trinity based on what
    # modules you have loaded...so tricky.
    if( $partition eq "" ){

        # TRINITY
        if( $$sysinfo_ref{L_CLASS} eq "TRINITY" ){
            # TR
            if( $$sysinfo_ref{L_OS} eq "TR" ){
                $partition = "standard";
            }
            # TR_KNL
            else{
                $partition = "knl";
            }
        }

        # DARWIN_DGPU
        # If you do not specify one, you apparently get this
        if( $$sysinfo_ref{L_CLASS} eq "DARWIN_GPU" ){
            if( $$sysinfo_ref{L_OS} eq "DGPU" ){
                $partition = "general";
            }
            if( $$sysinfo_ref{L_OS} eq "DPOWER9" ){
                $partition = "power9-rhel7";
            }
        }

        # RO (tycho has `fe` partition listed first which messes up
        #   when run_suite.pl is getting info about the node from
        #   the back end).
        if( $$sysinfo_ref{L_OS} eq "RO" ){
            $partition = "standard";
        }
        
    }

    # ------------------------
    # DONE: Default partitions
    # ------------------------

    # label used for setting sysinfo key for ppn+
    $partition_guess = $partition;
    if( $partition_guess eq "" ){
        $partition_guess = "GUESSDEFAULT";
    }

    # L_EAP_PPN_OVERRIDE
    if( defined( $ENV{L_EAP_PPN_OVERRIDE} ) ){
        $found_quick = "";
        $ppn = $ENV{L_EAP_PPN_OVERRIDE};
        # might need to be smarter about this
        $numapn = 1;
    }

    # L_EAP_NUMAPN_OVERRIDE
    if( defined( $ENV{L_EAP_NUMAPN_OVERRIDE} ) ){
        $numapn = $ENV{L_EAP_NUMAPN_OVERRIDE};
    }
    
    # L_EAP_PPN_OVERRIDE
    if( ! defined( $ppn ) &&
        defined( $ENV{L_EAP_PPN_OVERRIDE} ) ){
        $found_quick = "";
        $ppn = $ENV{L_EAP_PPN_OVERRIDE};
        # might need to be smarter about this (override for this???)
        $numapn = 1;
    }
    
    # see if this is already determined for your partition
    if( ! defined( $ppn ) &&
        defined( $$sysinfo_ref{"ppn_p_${partition_guess}"} ) ){
        $found_quick = "";
        $ppn    = $$sysinfo_ref{"ppn_p_${partition_guess}"};
        $numapn = $$sysinfo_ref{"numapn_p_${partition_guess}"};
        $ppn_plus    = $$sysinfo_ref{"ppn_plus_p_${partition_guess}"};
        $numapn_plus = $$sysinfo_ref{"numapn_plus_p_${partition_guess}"};
    }

    # -------------
    # ppn_reduction = reduce the number for ppn from max
    # -------------

    # default
    $ppn_reduction = 0;

    # KNL : 68 -> 64 ... got better performance saving 4
    if( $partition =~ /^knl/ || $partition_guess =~ /^knl/ ){
        $ppn_reduction = 4;
    }
    # DPOWER9 get slower when run multiple mpi jobs at the same time
    # got decent performance if reduced 40 -> 10 ... but that does not leave much.
    # Tried to reduce it 40->30 and was still bad.
    # So keep at max and set to run 1 test at a time in run_suilte.pl
    if( $$sysinfo_ref{L_CLASS} eq "DARWIN_GPU" ){
        if( $partition =~ /^power9/ || $$sysinfo_ref{L_OS} =~ /^(DPOWER9)$/ ){
            $ppn_reduction = 0;
        }
    }

    # sierra/rzansel
    # looks like they set max to be 4 less than this (maybe hardwired to 40???)
    if( $$sysinfo_ref{L_OS} =~ /^(SR)$/ ){
      $ppn_reduction = 4;
    }

    # -------------------
    # DONE: ppn_reduction
    # -------------------

    # ------------------------
    # get info by batch system
    # ------------------------

    # slurm
    if( ! defined( $ppn ) &&
        $batch_type eq "slurm" ){

        # This can be called many times to get info about each partition.
        # Go ahead and save the data from one call and then fetch that
        # info as needed.
        if( ! defined($GET_SYSINFO{partition}) ){
            $com = 'sinfo -a -o "'.${pct}.'c %X %Y %Z %R" ';
            # for whatever reason, this can hang or take a long time.
            $out = &run_command( COMMAND=>$com, TIMEOUT=>"3s",
                                 STATUS=>\$status );
            # command worked and you see a line with the CPUS field in it
            if( $status == 0 && $out =~ /\bCPUS\b.*\n((.|\n)*)$/ ){
                # strip out all before and the column header
                $rest = $1 || "";
                @lines = split( /\n/, $rest );
                foreach $line ( @lines ){
                    # last column is partition
                    # might have to mod if start to have spaces in fields
                    if( $line =~ /^(.*)\s+(\S+)$/ ){
                        $partition_use = $2;
                        $val = $1;
                        $GET_SYSINFO{partition}{$partition_use} = $val;
                        # first one is <empty> partition
                        $partition_use = "<empty>";
                        if( ! defined($GET_SYSINFO{partition}{$partition_use}) ){
                            $GET_SYSINFO{partition}{$partition_use} = $val;
                        }
                    }
                }
            }
        }

        # rest = line of info for that partition
        # (or first line) if no partitions
        $line = "";
        if( defined( $GET_SYSINFO{partition} ) ){
            if( $partition eq "" ){
                $partition_use = "<empty>";
            }
            else{
                $partition_use = $partition;
            }
            $line = $GET_SYSINFO{partition}{$partition_use} || "";
        }
      
        # if sinfo worked and found info about the partition
        if( $line =~ /\S/ ){

            # get line, split it into vals
            $line =~ s/^\s*//;
            $line =~ s/\s*$//;
            @vals = split( /\s+/, $line );
            
            # sequoia:
            #   CPUS SOCKETS CORES THREADS
            #   8K   512     16    4
            # This is a mixture of node and plane values
            # $ppn = CORES
            if( $$sysinfo_ref{L_CLASS} eq "SEQUOIA" ){
                $ppn    = $vals[2];
                $numapn = 1; # dunno about this
            }
            
            # Other systems
            else{
                # Some systems have partitions with different hardware
                # This will give results like:
                #   vals[0] vals[1] vals[2] vals[3]
                #   CPUS    SOCKETS CORES   THREADS
                #   8+      2+      16+     4
                # "+" means any node in that partition will have at least:
                #   8 cpus, 2 sockets, 16 cores
                # but every partition has 4 threads.
                # So, just use that minimum.  If you are on the node itself,
                # it will correctly determine PPN/NUMAPN (Makefile_vars.mk
                # for PPN and below /proc/cpuinfo for NUMAPN ).
                if( $vals[1] =~ /^(\d+)/ ){
                    $numapn = $1;
                    if( $vals[2] =~ /^(\d+)/ ){
                        $ppn = $numapn * $1;
                        
                        # set that this was a "minimum" so that if on
                        # back end, will use current node values.
                        if( $vals[1] =~ /\+/ ){
                            $numapn_plus = "${numapn}+";
                        }
                        if( $vals[1] =~ /\+$/ || $vals[2] =~ /\+$/ ){
                            $ppn_plus = "${ppn}+";
                        }

                        # if cpus and threads are constant,
                        # use that to define ppn and unset ppn_plus
                        #
                        # NOTE: to get more info about each node:
                        #   scontrol -o show partition
                        #   <get nodes for knl>
                        #   scontrol -o show node "nid00[192-291]"
                        #   look at CoresPerSocket, Sockets, ...
                        if( defined( $ppn_plus ) ){
                            if( defined($vals[0]) && $vals[0] =~ /^(\d+)$/ &&
                                defined($vals[0]) && $vals[3] =~ /^(\d+)$/ ){
                                $ppn_new = $vals[0] / $vals[3];
                                if( $ppn_new =~ /^(\d+)$/ ){
                                    undef( $ppn_plus );
                                    $ppn = $ppn_new;
                                }
                            }
                        } # ppn_plus use CPUS/THREADS
                    } # found CORES
                } # found SOCKETS
            } # Other systems (non-sequoia)
        } # sinfo worked
    } # slurm

    # moab
    # no longer have access to moab system...used to work...
    if( ! defined( $ppn ) &&
        $batch_type eq "moab" ){
        
        # CPUS SOCKETS CORES THREADS
        $com = 'lcstat';
        # for whatever reason, this can hang or take a long time.
        $out = &run_command( COMMAND=>$com, TIMEOUT=>"3s",
                             STATUS=>\$status );
        if( $out =~ /\d+:(\d+)/){
            $ppn    = $1;
            $numapn = 1; # just guessing
        }
        
    } # moab

    # lsf
    if( ! defined( $ppn ) &&
        $batch_type eq "lsf" ){
        
        # CPUS SOCKETS CORES THREADS
        $com = 'lshosts';
        # for whatever reason, this can hang or take a long time.
        $out = &run_command( COMMAND=>$com, TIMEOUT=>"3s",
                             STATUS=>\$status );
        # 5th col is ncpus.  pick highest one (might not be best choice...)
        @lines = split( /\n/, $out );
        $ppn = -1;
        $numapn = 1; # no idea
        foreach $line ( @lines ){

            # get line, split it into vals
            $line =~ s/^\s*//;
            $line =~ s/\s*$//;
            @vals = split( /\s+/, $line );
            
            if( defined($vals[4]) && $vals[4] =~ /^\d+$/ && $vals[4] > $ppn ){
                $ppn = $vals[4];
            }
        }
        if( $ppn <= 0 ){
            undef( $ppn );
            undef( $numapn );
        }

        # looks like they set max to be 4 less than this (maybe hardwired to 40???)
        if( defined($ppn) ){
          $ppn_adjusted = "yes";
          $ppn -= $ppn_reduction;
        }
        
    } # lsf

    # punt to L_EAP_PPN_THIS (current node) if still not found
    if( ! defined($ppn) ||
        ( defined($ppn_plus) && $$sysinfo_ref{L_END} eq "BACK" ) ){
        $ppn    = $$sysinfo_ref{L_EAP_PPN_THIS};

        # try from /proc/sysinfo
        $com = "cat /proc/cpuinfo | grep 'physical id' | sort -u | wc -l";
        $out = `$com 2>&1`;
        if( $out =~ /^\s*(\d+)\s*$/ ){
            $numapn = $1;
            if( $numapn == 0 ){
              undef( $numapn );
            }
        }

        # try from lscpu
        # this is used in args for sockets...so I did not name the var
        # correctly...at some point, should rename...
        if( ! defined( $numapn ) ){
          $com = "lscpu";
          $out = `$com 2>&1`;
          # $out =~ /^\s*NUMA\s+node\(s\):\s*(\d+)/m
          if( $out =~ /^\s*Socket\(s\):\s*(\d+)/m ){
            $numapn = $1;
          }
        }

        # punt to this
        if( ! defined( $numapn ) ){
            # again, punt.
            # if you are root, you have access to other options
            # dmidecode -t4 | egrep 'Designation|Status'
            $numapn = 1;
        }

        # DPOWER9
        if( $$sysinfo_ref{L_OS} eq "DPOWER9" ){
            $ppn_adjusted = "yes";
            $ppn -= $ppn_reduction;
        }

        # adjust again for back end knls since reset to L_EAP_PPN_THIS
        # might want to adjust value from Makefile_vars.mk instead?
        if( $partition_guess =~ /^knl/ ){
            $ppn_adjusted = "yes";
            $ppn -= $ppn_reduction;
        }

        # SR adjust
        if( $$sysinfo_ref{L_OS} eq "DPOWER9" ){
            $ppn_adjusted = "yes";
            $ppn -= $ppn_reduction;
        }

    }

    # ------------------------
    # DONE: get info by batch system
    # ------------------------

    # adjustments of L_EAP_PPN
    # do not adjust again if using previously determined values or
    # already adjusted in this call.
    if( defined( $ppn ) && ! defined($found_quick) ){
        # knl: leave 4 for os
        # seen knl partition names knl, knl_qc, knl_any, knl_allmodes
        if( $partition =~ /^knl/ && ! defined($ppn_adjusted) ){
            if( $ppn > $ppn_reduction ){
                $ppn_adjusted = "yes";
                $ppn -= $ppn_reduction;
            }
        }

        # DPOWER9
        if( $$sysinfo_ref{L_OS} eq "DPOWER9" && ! defined($ppn_adjusted) ){
            if( $ppn > $ppn_reduction ){
                $ppn_adjusted = "yes";
                $ppn -= $ppn_reduction;
            }
        }

        # SR
        if( $$sysinfo_ref{L_OS} eq "SR" && ! defined($ppn_adjusted) ){
            if( $ppn > $ppn_reduction ){
                $ppn_adjusted = "yes";
                $ppn -= $ppn_reduction;
            }
        }

    }

    # if somethind odd (probably a mac...heh...), punt to some default
    if( ! defined($ppn) || $ppn <= 0 ){
        $ppn    = 16;
        $numapn = 1;
    }

    # Save these so future calls can use it without batch query
    $$sysinfo_ref{"ppn_p_${partition_guess}"} = $ppn;
    $$sysinfo_ref{"numapn_p_${partition_guess}"} = $numapn;

    if( defined($ppn_plus) ){
        $$sysinfo_ref{"ppn_plus_p_${partition_guess}"} = $ppn_plus;
    }
    if( defined($numapn_plus) ){
        $$sysinfo_ref{"numapn_plus_p_${partition_guess}"} = $numapn_plus;
    }

    # these are the current values based on current partition.
    $$sysinfo_ref{L_EAP_PPN} = $ppn;
    $$sysinfo_ref{L_EAP_NUMAPN} = $numapn;
    delete($$sysinfo_ref{L_EAP_PPN_PLUS});
    if( defined($ppn_plus) ){
        $$sysinfo_ref{L_EAP_PPN_PLUS} = $ppn_plus;
    }
    delete($$sysinfo_ref{L_EAP_NUMAPN_PLUS});
    if( defined($numapn_plus) ){
        $$sysinfo_ref{L_EAP_NUMAPN_PLUS} = $numapn_plus;
    }

    # ---------------
    # DONE: L_EAP_PPN, L_EAP_NUMAPN
    # ---------------

    # ---------
    # gpu stuff
    # ---------
    # gpu_gpn = gpus per node
    # gpu_mb  = memory in MB per gpu
    #           if you use more mem than this, 10x slower or crash.
    if( ! defined($$sysinfo_ref{gpu_gpn}) ){

        # default to 0
        $$sysinfo_ref{gpu_gpn} = 0;
        $$sysinfo_ref{gpu_mb}  = 0;
        
        # This works just for DPOWER9 and SR...can adjust to others later.
        # Might need to put some sort of timeout wrapper if this hangs.
        # another option is "lshw -C display" but that takes longer and
        # spits out other garbage in output.
        # For each gpu, will have line like:
        #   0004:04:00.0 3D controller: NVIDIA Corporation GV100GL [Tesla V100 SXM2 16GB] (rev a1)
        $out = `/usr/sbin/lspci 2> /dev/null`;
        if( defined( $out ) ){
            $out =~ s/\s+$//;
            @lines = grep( /nvidia/i, split( /\n/, $out ) );
            if( $#lines >= 0 ){
                $$sysinfo_ref{gpu_gpn} = $#lines + 1;
                if( $lines[0] =~ /\s+(\d+)GB\s+/ ){
                    $$sysinfo_ref{gpu_mb} = $1 * 1024;
                }
                # default to 16GB
                else{
                    $$sysinfo_ref{gpu_mb} = 16 * 1024;
                } # see \d+GB
            } # found nvidia
        } # found lspci
        
    } # if gpu_gpn not already found
    
} # get_sysinfo

########################################################################
# Gets mount info for the various visible filesystems.
# Optionally sleeps for the required time for the filesystem to flush
# things (given DIR and SLEEP args).
#
# On dvs (trinity), they set attrcache_timeout to some >0 value which
# is essentially the time needed to sleep between doing some(?) filesystem
# ops that change metadata and actually seeing it change:
#   set _sleep = 0
#   
#   rm -f a b sf
#   sleep 5
#   echo a > a
#   echo b > b
#   ln -sf a sf
#   ls -la sf
#   cat sf
#   rm -f sf
#   ln -sf b sf
#   sleep $_sleep
#   ls -la sf
#   cat sf
#
#   [sleep for "long enough"]
#   ls -la sf
#   cat sf
#   [will be correct]
#
# Crazy...but unfortunately true...
# So, need to account for this in various places (specifically "ln -s" commands)
sub my_mount_info{
    my %args = (
        INFO    => undef, # ref to info (keep around so that you do not have to redo)
        DIR     => undef, # dir in question
        SLEEP   => undef, # if given a dir, sleep for the "lag" time for the dir
        VERBOSE => undef, # print stuff
        @_,
        );
    my $args_valid = "DIR|INFO|SLEEP|VERBOSE";
    my(
        $arg,
        $as,
        $attrs,
        $dir,
        $dir_use,
        $from,
        $ierr,
        $info_ref,
        $lag,
        $line,
        @lines,
        $out,
        $sleep,
        $sleep_time,
        $type,
        );

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # info
    $info_ref = $args{INFO};
    if( ! defined($info_ref) ){
        $ierr = 1;
        &print_error("Missing INFO", $ierr );
        exit( $ierr );
    }

    # dir
    $dir = $args{DIR};
    
    # sleep
    $sleep = $args{SLEEP};

    # fill /proc/mounts info if not defined
    if( ! defined( $$info_ref{ass} ) ){
        $out = `cat /proc/mounts 2>&1`;
        @lines = split( /\n/, $out );
        foreach $line ( @lines ){
            if( $line =~ /^\s*
                          (\S+)\s+  #  1: from
                          (\S+)\s+  #  2: as
                          (\S+)\s+  #  3: type
                          (\S+)     #  4: attrs
                         /x ){
                $from  = $1;
                $as    = $2;
                $type  = $3;
                $attrs = $4;
                $$info_ref{ass}{$as}{from}  = $from;
                $$info_ref{ass}{$as}{type}  = $type;
                $$info_ref{ass}{$as}{attrs} = $attrs;
                
                # put in some specifics (eg lag)
                # currently, only if see this do you need a lag
                if( $attrs =~ /attrcache_timeout=([^,]+)/ ){
                    $lag = $1;
                }
                else{
                    $lag = 0;
                }
                # add in 10%?
                # Might be able to get away with no change...or maybe need some min added.
                $lag = $lag * 1.1;
                $$info_ref{ass}{$as}{lag} = $lag;
            }
        }
    }

    # reset as
    undef( $as );

    # if given a DIR, stuff into dirs_as for future reference
    if( defined($dir) ){

        # already found in dirs_as
        if( ! defined($as) ){
            $as = $$info_ref{dirs_as}{$dir};
        }

        # already top level
        if( ! defined($as) ){
            if( defined($$info_ref{ass}{$dir}) ){
                $as = $dir;
            }
        }

        # use df - might need to keep moving up in dirs until
        # you find it
        if( ! defined($as) ){
            $dir_use = $dir;
            while( 1 == 1 ){
                # first field seems to be the filesystem
                # following is not standard: --output=source 
                $out = `df '$dir_use' 2>&1`;
                if( $out =~ /^\s*Filesystem\s+.*\n(\S+)/ ){
                    $as = $1;
                    last;
                }
                if( $dir_use eq "/" ){
                    last;
                }
                $dir_use = &my_dir($dir_use);
            }
        }

        # stuff into dirs_as so known next time
        $$info_ref{dirs_as}{$dir} = $as;

    }

    # if given a DIR and SLEEP, sleep for requested time
    if( defined($dir) && defined($sleep) ){
        if( ! defined($as) ){
            $ierr = 1;
            &print_error( "sanity check: 'as' should be defined",
                          "dir = [$dir]",
                          $ierr );
            exit( $ierr );
        }
        $sleep_time = $$info_ref{ass}{$as}{lag};
        if( defined($sleep_time) &&
            $sleep_time > 0 ){
            if( defined($args{VERBOSE}) ){
                print "my_mount_info: sleep $sleep_time\n";
            }
            &my_sleep( $sleep_time );
        }
    }

}

########################################################################
# my_copy: does a copy
# NOTE: moving to my_copyf - use that instead!!!!
sub my_copy
  {
    my(
       $path_from,
       $path_to,
       $group_to
      ) = @_;
    my(
       $command,
       $cwd,
       $executable,
       $final_path_to,
       $group,
       $ierr,
       $notdir_from,
       $parent_to,
       $type_from,
       $type_to,
      );
    $cwd = &cwd();
    if( ! -e $path_from )
      {
        $ierr = 1;
        &print_error( "my_copy: path_from [$path_from] does not exist",
                      "cwd = $cwd",
                      $ierr );
        exit( $ierr );
      }
    if( -d $path_from  )
      {
        $type_from = "directory";
      }
    else
      {
        $type_from = "file";
      }
    if( -x $path_from )
      {
        $executable = "true";
      }
    else
      {
        $executable = "false";
      }
    if( -d $path_to )
      {
        $type_to = "directory";
      }
    elsif( -e $path_to )
      {
        $type_to = "file";
      }
    else
      {
        $type_to = "";
      }
    #...get notdir
    ($notdir_from = $path_from) =~ s&/*$&&;
    if( $notdir_from =~ m&([^/]+)$& )
      {
        $notdir_from = $1;
      }
    else
      {
        $ierr = 1;
        &print_error( "my_copy: could not parse path_from [$path_from]",
                      $ierr );
        exit $ierr;
      }
    #...group
    if( ! defined($group_to) ){
      if ( $type_to eq "directory" ) {
        $group = (stat $path_to)[5];
        $group = (getgrgid($group))[0];
      } elsif ( $type_to eq "file" || $type_to eq "" ) {
        ($parent_to = $path_to) =~ s&[^/]*$&&;
        if ( $parent_to !~ /\S/ ) {
          $parent_to = ".";
        }
        $group = (stat $parent_to)[5];
        $group = (getgrgid($group))[0];
      }
    }
    else{
      $group = $group_to;
    }
    #...final_path_to
    #...file to
    if( $type_from eq "file" )
      {
        #...file to directory
        if( $type_to eq "directory" )
          {
            $final_path_to = "$path_to/$notdir_from";
          }
        #...file to file
        else
          {
            $final_path_to = "$path_to";
          }
      }
    #...directory to
    else
      {
        #...directory to existing directory
        if( $type_to eq "directory" )
          {
            $final_path_to = "$path_to/$notdir_from";
          }
        #...directory to existing non-directory
        elsif( $type_to eq "" )
          {
            $final_path_to = "$path_to";
          }
        #...directory to file
        else
          {
            $ierr = 1;
            &print_error( "my_copy: trying to copy directory to file",
                          "[$path_from] -> [$path_to]",
                          $ierr );
            exit( $ierr );
          }
      }
    #...copy
    $command = "\\cp -f -L -R $path_from $path_to";
    &run_command( COMMAND=>$command, ERROR_REGEXP=>'/\S/' );
    #...chgrp
    $command = "chgrp -R $group $final_path_to";
    &run_command( COMMAND=>$command );
    #...set permissions
    $command = "chmod -R g+rw $final_path_to";
    &run_command( COMMAND=>$command );
    #...add group execute if owner has execute
    if( -x $final_path_to ){
        $command = "chmod -R g+x $final_path_to";
        &run_command( COMMAND=>$command );
    }
    $command = "find $final_path_to -type d -exec chmod 02770  {} \\;";
    &run_command( COMMAND=>$command );
  }

########################################################################
# my_copyf
#   does cp -R from to and fixes mode/group
sub my_copyf {
    my %args = (
        PATH_FROM => undef, # scalar or reference to array of files
        PATH_TO   => undef, # scalar to
        GROUP     => undef, # group name (preserve if not given)
        MODE      => undef, # decimal mode (preserve if not given)
        SAFE      => undef, # "safe" mode (rsync creates "tmp" first)
                            # rsync takes 20x longer - so only use if need to
        SKIP_MISSING => undef, # Skip any missing files
        UMASK     => undef, # decimal umask to convert permissions to
        VERBOSE   => undef, # if verbose
        @_,
        );
    my $args_valid = "PATH_FROM|PATH_TO|GROUP|MODE|SAFE|SKIP_MISSING|UMASK|VERBOSE";
    my(
        $arg,
        $arg_dir,
        $arg_exec,
        $com,
        $dir_create,
        $dir_parent,
        $file_from,
        $file_from_full,
        $file_to,
        @files_from,
        @files_from_full,
        $files_from_string,
        %files_to_from,
        $group,
        $ierr,
        $mode,
        $mode_dir,
        $mode_dir_oct,
        $mode_exec,
        $mode_file,
        $mode_use,
        $out,
        $path_to,
        $rename,
        $replace_from,
        $replace_to,
        $umask_use,
        );

    $ierr = 0;

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # @files_from = list of files from
    if( ref($args{PATH_FROM}) eq "ARRAY" ){
        @files_from = @{$args{PATH_FROM}};
    }
    else{
        @files_from = ($args{PATH_FROM});
    }

    $path_to = $args{PATH_TO};
    if( ! defined($path_to) || ! @files_from ){
        $ierr = 1;
        &print_error( "Must define PATH_FROM and PATH_TO", $ierr );
        exit( $ierr );
    }

    # group
    $group = $args{GROUP};

    # find various resulting modes for files
    # start with umask
    if( defined($args{MODE}) || defined($args{UMASK}) ){
        if( defined($args{UMASK}) ){
            $umask_use = $args{UMASK};
        }
        else{
            if( -d $files_from[0] ){
                $arg_dir = "";
            }
            elsif( -x $files_from[0] ){
                $arg_exec = "";
            }
            $umask_use = &my_mode(DEC=>"", DIR=>$arg_dir, EXEC=>$arg_exec, MODE=>$mode);
        }
        $mode = "";
        $mode_dir  = &my_mode(DEC=>"", DIR=>"",  UMASK=>$umask_use);
        $mode_exec = &my_mode(DEC=>"", EXEC=>"", UMASK=>$umask_use);
        $mode_file = &my_mode(DEC=>"", UMASK=>$umask_use);
        $mode_dir_oct = oct($mode_dir);
    }

    # dir_create: if need to create the directory
    # rename: also set rename if will be renaming
    if( ! -d $path_to ){
        # if more than one PATH_FROM, last must be a directory
        if( $#files_from > 0 ){
            $dir_create = $path_to;
        }
        # single files_from - since path_to not a dir, will rename
        else{
            $rename = "";
            # also need to create the parent dir if files_from is a dir
            $dir_parent = &my_dir($path_to);
            if( -d $dir_parent ){
                $dir_create = $dir_parent;
            }
        }
    }
    if( defined($dir_create) ){
        &my_mkdirf( DIR=>$dir_create, GROUP=>$group, MODE=>$mode_dir_oct,
                    ERROR=>"", VERBOSE=>$args{VERBOSE} );
    }

    # string surrounded by '' in case spaces
    $files_from_string = "";
    foreach $file_from ( @files_from ){
        $files_from_string .= " '$file_from'";
    }

    # copy
    # will get warnings about '-p' if you do not own file...that is fine
    # could parse those out and look for real errors to return an error
    # Use "rsync --checksum" instead of cp.  We've had issues with the
    # destination dir becoming full and cp leaving empty files.
    # At least with rsync, we will only get screwed by this when the files
    # are actually different.so we can only copy on diff.
    # cp:
    #   -f force, -L follow symlinks, -R recursive, -p preserve
    # rsync:
    #   --checksum copy only if different using checksum
    #     do not use since takes %10 longer and date/size probably enough
    #   -a -L preserve everything but -L follow symlinks
    if( defined($args{SAFE}) ){
        $com = "rsync -a -L $files_from_string $path_to";
    }
    else{
        $com = "\\cp -f -L -R -p $files_from_string $path_to";
    }
    $out = &run_command( COMMAND=>$com, VERBOSE=>$args{VERBOSE} );
    if( $out =~ /(no such file or directory)/i ){
        if( defined($args{SKIP_MISSING}) ){
            $ierr = 0;
        }
        else{
            $ierr = 1;
        }
        if( ! defined($args{SKIP_MISSING}) ||
            $args{SKIP_MISSING} ne "quiet" ){
            &print_error( "Error during copy",
                          "\n$out",
                          $ierr );
        }
        if( ! defined($args{SKIP_MISSING}) ){
            exit( $ierr );
        }
    }

    # if mode or group is specified, then need to get a list of
    # files that were actually coppied and fix the perms
    if( defined($group) || defined($mode) ){
        foreach $file_from ( @files_from ){
            # list of files from this $file_from
            $out = `find '$file_from' -print 2> /dev/null`;
            $out =~ s/\s+$//;
            @files_from_full = split(/\s*\n\s*/, $out);
            foreach $file_from_full ( @files_from_full ){
                # replace_from, replace_to
                $replace_to   = $path_to;
                if( defined($rename) ){
                    $replace_from = $file_from;
                }
                else{
                    $replace_from = &my_dir($file_from);
                    if( $replace_from eq "." ){
                        $replace_from = "";
                    }
                }
                ($file_to = $file_from_full) =~ s&^${replace_from}&${replace_to}/&;
                $file_to =~ s&/$&&;
                $file_to =~ s&//&/&g;
                $files_to_from{$file_to} = $file_from_full;
            }
        }
    }

    # fix groups first (since group changes will change mode on dirs)
    # if lots of files, would be better to do system commands in blocks
    if( defined($group) ){
        foreach $file_to ( keys %files_to_from ){
            $com = "chgrp $group $file_to";
            if( defined($args{VERBOSE}) ){
                print "$args{VERBOSE}$com\n";
            }
            $out = &run_command( COMMAND=>$com );
            # add back in g+s to dirs
            if( -d $file_to ){
                $com = "chmod g+s '$file_to'";
                $out = `$com 2>&1`;
            }
        }
    }

    # fix mode
    # if lots of files, would be better to do system commands in blocks
    if( defined($mode) ){
        foreach $file_to ( keys %files_to_from ){
            if( -d $file_to ){
                $mode_use = $mode_dir;
            }
            elsif( -x $file_to ){
                $mode_use = $mode_exec;
            }
            else{
                $mode_use = $mode_file;
            }
            $com = "chmod $mode_use $file_to";
            if( defined($args{VERBOSE}) ){
                print "$args{VERBOSE}$com\n";
            }
            $out = &run_command( COMMAND=>$com );
        }
    }
}

#............................................................................
#...Name
#...====
#... my_copy_obj
#...
#...Purpose
#...=======
#... coppies a confusing hash - mainly for debugging - not sure if needed
#...   a = b
#...
#............................................................................
sub my_copy_obj{
    my(
        $obj_a_ref,
        $obj_b_ref,
        ) = @_;
    if( ref( $obj_b_ref ) eq "HASH" ){
        &my_copy_hash( \%{$obj_a_ref}, \%{$obj_b_ref} );
    }
    elsif( ref( $obj_b_ref ) eq "ARRAY" ){
        &my_copy_array( \@{$obj_a_ref}, \@{$obj_b_ref} );
    }
    else{
        $$obj_a_ref = $$obj_b_ref;
    }
}

sub my_copy_hash{
    my(
        $hash_a_ref,
        $hash_b_ref,
        ) = @_;
    my(
        $key,
        );
    undef( %{$hash_a_ref} );
    foreach $key ( keys %{$hash_b_ref} ){
        if( ref( $$hash_b_ref{$key} ) eq "HASH" ){
            &my_copy_hash( \%{$$hash_a_ref{$key}}, \%{$$hash_b_ref{$key}} );
        }
        elsif( ref( $$hash_b_ref{$key} ) eq "ARRAY" ){
            &my_copy_array( \@{$$hash_a_ref{$key}}, \@{$$hash_b_ref{$key}} );
        }
        else{
            $$hash_a_ref{$key} = $$hash_b_ref{$key};
        }
    }
}

sub my_copy_array{
    my(
        $array_a_ref,
        $array_b_ref,
        ) = @_;
    my(
        $i,
        );
    undef(@{$array_a_ref});
    for( $i = 0; $i <= $#{$array_b_ref}; $i++ ){
        if( ref( $$array_b_ref[$i] ) eq "HASH" ){
            &my_copy_hash( \%{$$array_a_ref[$i]}, \%{$$array_b_ref[$i]} );
        }
        elsif( ref( $$array_b_ref[$i] ) eq "ARRAY" ){
            &my_copy_array( \@{$$array_a_ref[$i]}, \@{$$array_b_ref[$i]} );
        }
        else{
            $$array_a_ref[$i] = $$array_b_ref[$i];
        }
    }
}

#............................................................................
#...Name
#...====
#...  my_copy_hpss
#...
#...Purpose
#...=======
#...  Copies dirs or files to hpss.  This simulates what the unix "cp -R" does.
#...  Why didn't psi/hsi do this themselves???
#...  Also, can do a PRESERVE option to preserve the original permissions of the
#...  files.  With the way I have to kludge it, this might take a VERY long time
#...  (seconds per file) so it is not on my defualt.
#...
#...  Dir example:
#...    PATH_FROM = a/b/c
#...                a/b/c/d/file.txt  (local file)
#...                a/b/c/c.txt       (local file)
#...                Command to simulate
#...                  rm -rf a b c d e f
#...                  mkdir -p a/b/c/d ; touch a/b/c/d/file.txt ; touch a/b/c/c.txt ; mkdir -p e/f ; cp -R a/b/c e/f
#...                  mkdir -p a/b/c/d ; touch a/b/c/d/file.txt ; touch a/b/c/c.txt ; mkdir -p e   ; cp -R a/b/c e/f
#...    PATH_TO   = e/f
#...                will create this tree if e/f already exists (keeps c)
#...                  e/f/c/c.txt      
#...                  e/f/c/d/file.txt
#...                will create this tree if e/f does not exist (c -> f)
#...                  e/f/c.txt        
#...                  e/f/d/file.txt
#...
#...  File example:
#...    PATH_FROM = a/b/file.txt      (local file)
#...                Command to simulate
#...                  rm -rf a b c d e f
#...                  mkdir -p a/b ; touch a/b/file.txt ; mkdir -p c/d ; cp -R a/b/file.txt c/d
#...                  mkdir -p a/b ; touch a/b/file.txt ; mkdir -p c   ; cp -R a/b/file.txt c/d
#...    PATH_TO   = c/d
#...                c/d/file.txt (will create this tree if d exists and is a dir)
#...                c/d          (will create this tree if d is not a directory d==file.txt)
#...
#...  Multiple files (or dirs) example (PATH_TO must be a directory)
#...    PATH_FROM = a/b d/e/f.txt
#...                local files: 
#...                  a/b/c.txt
#...                  a/b/c/c1.txt
#...                  d/e/f.txt
#...                Command to simulate:
#...                  rm -rf a b c d e f
#...                  mkdir -p a/b/c d/e ; touch a/b/c.txt a/b/c/c1.txt d/e/f.txt ; mkdir f ; cp -R a/b d/e/f.txt f
#...    PATH_TO   = f
#...                will create:
#...                  f/b/c.txt
#...                  f/b/c/c1.txt
#...                  f/f.txt
#............................................................................
sub my_copy_hpss{
    my %args = (
        PATH_FROM  => undef, # from file or files (scalar or reference to an array)
        PATH_TO    => undef, # where to put them (scalar)
        GROUP      => undef, # will set to from group if not set
        RM         => undef, # remove after store
        ERROR_FILE => undef,
        MODE       => undef, # default mode (uses umask)
        PRESERVE   => undef, # preserve permissions
        ERROR_SUB  => undef, # subroutine ref to call before exit
        SKIP_MKDIR => undef, # assume initial directory already made (saves time)
                             # This implies no renames also
        FOLLOW_SYMLINKS => undef, # if following symlinks (default keep as symlink)
        VERBOSE    => undef,
        @_,
        );
    my $args_valid = "ERROR_FILE|ERROR_SUB|FOLLOW_SYMLINKS|MODE|PATH_FROM|PATH_TO|GROUP|PRESERVE|RM|SKIP_MKDIR|VERBOSE";
    my(
        $arg,
        $com,
        $com_hpss_pre,
        $com_local,
        $dir,
        %dir_files,
        $dir_from,
        $dir_to,
        $file,
        $file_from,
        $file_from_list,
        $file_from_r,
        $file_to,
        $file_to_r,
        $filelist,
        @files,
        @files_from,
        %files_to,
        $group,
        $hpss_ex,
        $ierr,
        $mode,
        $mode_dir,
        %new_group,
        %new_mode,
        $out,
        $output,
        $path_to_not_dir,
        $rename_file,
        $res,
        %stat,
        %stat_from_first,
        $umask,
        $umask_use,
        );

    # check args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            if( defined( $args{ERROR_SUB} ) ){
                &{$args{ERROR_SUB}}($ierr);
            }
            exit( $ierr );
        }
    }

    # umask - current umask
    $umask = sprintf("%lo", umask());

    # hpss_exec
    $hpss_ex = "";
    # try hsi first (faster and psi going away)
    if( $hpss_ex eq "" ){
        $hpss_ex = &which_exec( "hsi", QUIET=>"" );
    }
    # try psi
    if( $hpss_ex eq "" ){
        $hpss_ex = &which_exec( "psi", QUIET=>"" );
    }
    if( $hpss_ex eq "" ){
        $ierr = 1;
        &print_error( "Cannot find an hpss exec (hsi, psi)", $ierr );
        if( defined( $args{ERROR_SUB} ) ){
            &{$args{ERROR_SUB}}($ierr);
        }
        exit( $ierr );
    }

    # @files_from = list of files from
    if( ref($args{PATH_FROM}) eq "ARRAY" ){
        @files_from = @{$args{PATH_FROM}};
    }
    else{
        @files_from = ($args{PATH_FROM});
    }

    # directory where to store files (default to this, redefine if needed)
    $dir_to = $args{PATH_TO};

    if( defined($args{VERBOSE}) ){
        $file_from = $files_from[0];
        if( $#files_from > 0 ){
            $file_from .= "[...]";
        }
        print "$args{VERBOSE}my_copy_hpss : file_from=$file_from dir_to=$dir_to\n";
    }

    # if only one @files_from, then need to see if storing into
    # directory (no name change) or non-directory (change name)
    #   rename_file = what the new file will be named (if defined)
    #   dir_to      = directory to create (where files will be stored)
    # if SKIP_MKDIR, will assume it is a directory if needed.
    if( $#files_from == 0 ){

        $com = "$hpss_ex 'cd $dir_to'";
        $out = &run_command( COMMAND=>$com, STATUS=>\$res );
        # psi: returns error if fails
        # hsi: returns error if does not exist,
        #      returns 0 but error message if text file
        if( $out =~ /not a directory/i || $res != 0 ){
            $path_to_not_dir = "";
        }

        # if path_to_not_dir, then renaming
        if( defined( $path_to_not_dir ) ){

            # if from is a directory
            if( -d $files_from[0] ){
                
                # hsi: I can't get the ":" to work with directories to
                # rename in place.  So, treat this as a multi store into
                # a new directory.
                if( $hpss_ex =~ /hsi$/ ){
                    # if from is a directory, then will rename that dir
                    $out = `find '$files_from[0]' -maxdepth 1`;
                    $out =~ s/\s+$//;
                    @files_from = split(/\s+/, $out );
                    # first one is the directory itself - so shift it
                    shift( @files_from );
                    # and no longer need to rename
                    undef( $rename_file );
                }
                
                # psi: you can simply use the <old>:<new> construct to rename
                #   the directory
                else{
                    $rename_file = &my_notdir($dir_to);
                    $dir_to      = &my_dir($dir_to);
                }
                
            }
            
            # from is a file
            # hsi works correctly (like psi)
            else{
                $rename_file = &my_notdir($dir_to);
                $dir_to      = &my_dir($dir_to);
            }
        }
    }
    
    # $dir_files{$dir} = list of files from that directory
    foreach $file ( @files_from ){
        $dir = &my_dir( $file );
        push( @{$dir_files{$dir}}, $file );
    }

    # stat_from_first = stat of the first file_from
    # group/mode info used to create destination directory
    &my_stat( $files_from[0], \%stat_from_first );

    if( ! %stat_from_first ){
        $ierr = 1;
        &print_error( "FROM [$files_from[0]] does not exist", $ierr );
        if( defined( $args{ERROR_SUB} ) ){
            &{$args{ERROR_SUB}}($ierr);
        }
        exit( $ierr );
    }

    # umask_use - one to use when doing ops
    if( defined( $args{MODE} ) ){
        if( -d $files_from[0] ){
            $umask_use = &my_mode( DIR=>"", MODE=>$args{MODE}, DEC=>"" );
        }
        else{
            $umask_use = &my_mode(          MODE=>$args{MODE}, DEC=>"" );
        }
    }
    else{
        $umask_use = $umask;
    }
    # mode of directory to create
    $mode_dir = &my_mode( DIR=>"", UMASK=>$umask_use, DEC=>"" );

    # if set use that - otherwise, group of $files_from_first
    $group = $args{GROUP};
    if( ! defined($group) ){
        $group = $stat_from_first{group};
    }

    # create dir_to
    if( ! defined($args{SKIP_MKDIR}) ){
        &my_mkdir_hpss( DIR=>$dir_to, GROUP=>$group, MODE=>$mode_dir, ERROR_SUB=>$args{ERROR_SUB},
                        VERBOSE=>$args{VERBOSE}, FIX=>"" );
    }

    # $com_hpss_pre = command that will always be run
    $com_hpss_pre = "";
    # set the umask
    $com_hpss_pre .= " umask $umask_use;";
    # cd into the store directory
    if( $dir_to ne "." ){
        $com_hpss_pre .= " cd $dir_to;";
    }
    
    # store command
    # hsi
    if( $hpss_ex =~ /hsi$/ ){
        # use recursive cput
        #   (cput is conditional and follow symlinks default)
        $com_hpss_pre .= " cput -R";
        # keep symlinks as symlinks (matches hsi and psi)
        if( ! defined($args{FOLLOW_SYMLINKS}) ){
            $com_hpss_pre .= " -h";
        }
        # preserve timestamp (does not seem to be anything to preserve perms)
        $com_hpss_pre .= " -p";
        # if removing
        if( defined($args{RM}) ){
            $com_hpss_pre .= " -d";
        }
    }
    # psi
    else{
        # use recursive store
        # follow symlinks would be: -h
        $com_hpss_pre .= " store --cond -R";
        #   follow symlinks (commented out - matches hsi and psi)
        if( defined($args{FOLLOW_SYMLINKS}) ){
            $com_hpss_pre .= " -h";
        }
        # psi does not seem to have the ability to preserve the timestamp/perms
        #$com_hpss_pre .= " -p";
        # if removing
        if( defined($args{RM}) ){
            $com_hpss_pre .= " --rm";
        }
    }

    # now store files in groups of dir_from
    foreach $dir_from ( keys %dir_files ){

        # com_local = any non-hpss commands (like cd)
        $com_local = "";
        # locally need to go to directory
        if( $dir_from ne "." ){
            $com_local .= " cd $dir_from &&";
        }
        
        # file_from_list
        $file_from_list = "";
        foreach $file_from ( @{$dir_files{$dir_from}} ){
            $file_from_list .= " ".&my_notdir($file_from);
        }

        # com = whole command
        $com = "$com_local $hpss_ex '$com_hpss_pre $file_from_list";
        
        # rename if set (will just be 1 file)
        if( defined( $rename_file ) ){
            # hsi
            if( $hpss_ex =~ /hsi$/ ){
                $com .= " : $rename_file";
            }
            # psi
            else{
                $com .= ":$rename_file";
            }            
        }
        
        # finish off quote
        $com .= "'";
        
        # and run it
        # hsi has a problem copying symlink again, so cannot exit on ERROR_STATUS=>"".
        # instead captture $ierr and error if $ierr and not symlink error
        $out = &run_command( COMMAND=>$com, STATUS=>\$ierr, ERROR_FILE=>$args{ERROR_FILE},
                             VERBOSE=>$args{VERBOSE}, ERROR_SUB=>$args{ERROR_SUB} );
        if( $ierr ne "0" ){
            if( $out !~ /hpss_Symlink/ ){
                &print_error( "Command failed", $ierr );
                $ierr = 1;
                if( defined($args{ERROR_SUB}) ){
                    &{$args{ERROR_SUB}}($ierr);
                }
                exit( $ierr );
            }
            else{
                $ierr = 0;
                &print_error( "HSI cannot handle copying over symlinks - ignoring error.",
                              "The other files SHOULD have been coppied.",
                              $ierr );
            }
        }
    }

    # since forcing a FIX in my_mkdir_hpss, should be no durn acls
    # on any of the files stored

    # PRESERVE: keep same group and permissions
    # WOW!!! no flag to say "keep mode and group" for store...so needed to add this
    # do not check for error - just try and do it
    # This could take a LONG time if lots of files (each command takes several seconds)
    if( defined($args{PRESERVE}) || defined($args{MODE}) || defined($args{GROUP}) ){
        
        if( defined( $args{VERBOSE} ) ){
            print "$args{VERBOSE}my_copy_hpss: PRESERVE/MODE/GROUP\n";
        }

        # $files_to{to file} = from file
        foreach $dir_from( keys %dir_files ){
            foreach $file_from ( @{$dir_files{$dir_from}} ){
                if( defined($rename_file) ){
                    $file_to = "$dir_to/$rename_file";
                }
                else{
                    $file_to = "$dir_to/".&my_notdir($file_from);
                }
                $files_to{$file_to} = $file_from;
                # if a recursive copy, get files coppied
                if( -d $file_from ){
                    $output = `cd '$file_from' && find . -print`;
                    $output =~ s/\s*$//;
                    @files = split(/\n/, $output);
                    # skip top one
                    shift( @files );
                    foreach $file ( @files ){
                        $file =~ s&^\./&&;
                        $file_from_r = "$file_from/$file";
                        $file_to_r   = "$file_to/$file";
                        $files_to{$file_to_r} = $file_from_r;
                    }
                }
            }
        }

        # go through files_to and organize based on group and mode
        foreach $file_to ( keys %files_to ){
            $file_from = $files_to{$file_to};
            &my_stat($file_from, \%stat );
            if( defined($args{GROUP}) ){
                $group = $args{GROUP};
            }
            else{
                $group = $stat{group};
            }
            if( defined($args{MODE}) ){
                $mode = $args{MODE};
            }
            else{
                $mode  = $stat{mode_dp};
            }
            push( @{$new_group{$group}}, $file_to );
            push( @{$new_mode{$mode}},   $file_to );
        }

        # remove acls - don't think needed
        #$com .= "chacl -c $filelist; ";
        ## hsi and directory - clear "CO"
        #if( $hpss_ex =~ /hsi$/ && -d "$dir/$file_local" ){
        #    $com .= "chacl -c -ic $args{PATH_TO} ; chacl -c -io $args{PATH_TO} ; ";
        #}

        # could combine this all into one giant command...but
        # will likely have issues with size if too many files...
        
        # loop through groups
        foreach $group ( keys %new_group ){
            $filelist = join( " ", @{$new_group{$group}} );
            $com = "";
            $com .= "chgrp $group $filelist; ";
            $com =~ s/\s*;\s*$//;
            $com = "$hpss_ex '$com'";
            &run_command( COMMAND=>$com, ERROR_FILE=>$args{ERROR_FILE},
                          VERBOSE=>$args{VERBOSE} );
        }

        # loop through modes
        foreach $mode ( keys %new_mode ){
            $filelist = join( " ", @{$new_mode{$mode}} );
            $com = "";
            $com .= "chmod $mode  $filelist; ";
            $com =~ s/\s*;\s*$//;
            $com = "$hpss_ex '$com'";
            &run_command( COMMAND=>$com, ERROR_FILE=>$args{ERROR_FILE},
                          VERBOSE=>$args{VERBOSE} );
        }
    }
}

##########################################################################

sub my_max{
    my(
        $a,
        $b,
        ) = @_;
    if( $a >= $b ){
        return( $a );
    }
    else{
        return( $b );
    }
}

##########################################################################

#............................................................................
#...Name
#...====
#... my_mkdir
#...
#...Purpose
#...=======
#... creates a directory (with parents) of the group and mode
#...
#...Arguments
#...=========
#... $dir_in   Intent: in
#...           Perl type: scalar
#...           the directory
#...
#... $group_in Intent: in
#...           Perl type: scalar
#...           the group (default is group of last parent that already exists
#...
#...Program Flow
#...============
#... 1) Get info about last dir that exists in path
#... 2) make_path with that mode/group or the ones given
#............................................................................
sub my_mkdir {
    my(
       $dir_in,
       $group_in,
       $mode_in,  # octal flavor
      ) = @_;

    my( $ierr );

    $ierr = &my_mkdirf( DIR=>$dir_in, GROUP=>$group_in, MODE=>$mode_in );

    return( $ierr );

}

#............................................................................
#...Name
#...====
#... my_mkdirf
#...
#...Purpose
#...=======
#... creates a directory (with parents) of the group and mode
#...
#...Arguments
#...=========
#... $dir_in   Intent: in
#...           Perl type: scalar
#...           the directory
#...
#... $group_in Intent: in
#...           Perl type: scalar
#...           the group (default is group of last parent that already exists
#...
#...Program Flow
#...============
#... 1) Get info about last dir that exists in path
#... 2) make_path with that mode/group or the ones given
#............................................................................
sub my_mkdirf {

    my %args = (
                DIR      => undef, # directory to create
                GROUP    => undef, # group name
                MODE     => undef, # octal mode (02700)
                ERROR    => undef, # exit if error occurs (0 success, non-0 otherwise)
                VERBOSE  => undef,
                @_,
               );
    my $args_valid = "DIR|ERROR|GROUP|MODE|VERBOSE";

    my(
       $arg,
       $dir,
       $dir_cur,
       $dir_this,
       @dirs,
       @fields,
       $group,
       $group_cur,
       $group_in,
       $ierr,
       $mkdir_done,
       $mode,
       $mode_dec,
       $mode_in,
       $mode_s,
       $perms_fixed,
       %stat,
       $umask_old,
      );

    $ierr = 0;

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }
    
    if( ! defined($args{DIR}) ){
        $ierr = 1;
        &print_error( "Must give DIR", $ierr );
        exit( $ierr );
    }
    $dir = $args{DIR};

    $group_in = $args{GROUP};
    $mode_in  = $args{MODE};

    #...if directory doesn't already exist
    if( ! -d $dir ){
        
        &my_stat_guess( $dir, \%stat );

        #...set mode
        if( defined($mode_in) && $mode_in =~ /\S/ ) {
            if( $mode_in eq "-1" ){
                $mode = $stat{mode};
            }
            else{
                $mode = $mode_in;
            }
        }
        else{
            $mode = 02770;
        }
        # always add group sticky
        $mode   = $mode | 02000;
        $mode_s = sprintf( "%o", $mode );

        #...set group
        if( defined( $group_in ) && $group_in =~ /\S/ ) {
            $group = $group_in;
        }
        else {
            $group = $stat{group};
        }

        # set umask to 0 for now
        $umask_old = umask(0);
        $dir_cur = $stat{info_on};
        @dirs = split(m&/&, $stat{info_rest});
        undef( $mkdir_done );
        undef( $perms_fixed );
        foreach $dir_this ( @dirs ){
            $dir_cur .= "/$dir_this";
            if( ! -d $dir_cur ){
                $mkdir_done = "";
                if( defined($args{VERBOSE}) ){
                    $mode_dec = sprintf("%lo",$mode);
                    print "$args{VERBOSE}mkdir $dir_cur mode=[$mode_dec] group=[$group]\n";
                }

                if( ! mkdir( $dir_cur, $mode ) ){
                    # there seems to be a race condition for multiple processes
                    # making this call at the same time.  In between the check and the
                    # mkdir, the other process does a mkdir as well and this process
                    # fails.  So, only an error if the directory is still not there.
                    if( ! -d $dir_cur ){
                        $ierr = 1;
                        &print_error( "Cannot create directory [$dir_cur]", $ierr );
                        if( defined( $args{ERROR} ) ){
                            exit( $ierr );
                        }
                        else{
                            return( $ierr );
                        }
                    }
                }
            }

            # after first $mkdir_done and modes set, no longer need to
            # fix group+mode again.
            if( defined( $mkdir_done ) && ! defined( $perms_fixed ) ){
                $perms_fixed = "";
                @fields = stat $dir_cur;
                $group_cur = getgrgid($fields[5]);
                if( "$group" ne "$group_cur" ){
                    `chgrp $group '$dir_cur' 2>&1`;
                    # some systems reset group sticky after chgrp
                    chmod( $mode, $dir_cur );
                }
            }
        }

        # reset umask
        umask($umask_old);

    } #...done: if directory doesn't exist already

    return( $ierr );

}

###################################################################################
# my_logderiv
#...      Computes the logarithmic derivative of a strictly positive
#...      Y quantity.
#...        logderiv(Y) = (dY/dt)/Y
#...                    = (log(Y2) - log(Y1))/(X2-X1) 
#...                    = log(Y2/Y1) / (X2-X1)
#...      The logderiv will be "fixed" to account for noise or initial 0 values:
#...      R = Y2/Y1
#...        = 1 when Y2 and Y1 are close/equal to 0 (uses --noise and the
#...          total magnitude of Y)
sub my_logderiv{
    my %args = (
        BY           => undef, # by (log) for extrema
        DERIV        => undef, # the derivative at each value
        SPACING      => undef, # spacing for verbose prints
        X            => undef, # X values, equal spacing if not defined
        Y            => undef, # Y values
        VERBOSE      => undef, # if verbose
        NOISE        => undef, # noise factor (used for box_window_width)
        @_,
        );
    my $args_valid = "BY|DERIV|NOISE|SPACING|X|Y|VERBOSE";
    my(
        $arg,
        %array_stats,
        $i,
        $ierr,
        $last,
        $max_i,
        $noise,
        $noise_value,
        $out_noise,
        $ratio,
        $spacing,
        @x,
        $x_diff,
        $x_diff_rel,
        $x_range,
        $x_ref,
        $y_diff,
        $y_range,
        @y_new,
        $y_ref,
        );

    $ierr = 0;
    
    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    # check args

    if( defined($args{SPACING}) ){
        $spacing = $args{SPACING};
    }
    else{
        $spacing = "";
    }

    # X
    if( defined $args{X} && ref($args{X}) ne "ARRAY" ){
        $ierr = 1;
        &print_error( "Must supply X array",
                      $ierr );
        exit( $ierr );
    }
    # if given X
    if( defined( $args{X}) ){
        $x_ref = $args{X};
    }
    # if not given X, use equal spacing
    else{
        @x = (0..$#{$y_ref});
        $x_ref = \@x;
    }

    # Y
    if( ! defined $args{Y} || ref($args{Y}) ne "ARRAY" ){
        $ierr = 1;
        &print_error( "Must supply Y array",
                      $ierr );
        exit( $ierr );
    }
    $y_ref = $args{Y};

    # noise
    if( defined($args{NOISE}) ){
        $noise = $args{NOISE};
    }
    else{
        $noise = .01;
    }

    # number of points
    $max_i = $#{$x_ref};

    if( defined($args{VERBOSE}) ){
        print "${spacing}my_logderiv() max_i=$max_i noise=$noise\n";
    }
    # get info about the input values to use for noise
    &my_array_stats( $y_ref, \%array_stats );
    $y_range = $array_stats{range};
    &my_array_stats( $x_ref, \%array_stats );
    $x_range = $array_stats{range};

    # noise_value scaled to what the y_range is multiplied by supplied noise
    $noise_value = 1e-10 * $y_range * $noise;

    undef( @y_new );
    $last = 0;
    # once you have hit real values, out_noise will be set so do not
    #   use initial noise again.
    #   extrema test6 shows hump if do not do this.
    #   Might want to interp if between 2 "good" values instead of keeping
    #   last value.
    undef( $out_noise );
    for( $i = 1; $i <= $#$x_ref; $i++ ){
        $Y1 = $$y_ref[$i-1];
        $Y2 = $$y_ref[$i];
        $X1 = $$x_ref[$i-1];
        $X2 = $$x_ref[$i];
        $y_diff = abs($Y2 - $Y1);
        $x_diff = $X2 - $X1;
        $x_diff_rel = $x_diff/$x_range;
        # if suspicious or possibly noisy value, set to
        # last good value.
        if( $Y2 <= 0 || $Y1 <= 0 ){
            $y_new[$i] = $last;
        }
        # values are close to the same (which handles the
        # case when Y2 and Y1 are close to 0 but the ratio
        # could vary a lot).
        # might need to do something more sophisticated here if BY is set.
        elsif( $y_diff == 0 ||               # no difference
               $x_diff == 0 ||               # time step too small to diff???
               ( abs($Y1) <= 1e-15 &&
                 abs($Y2) <= 1e-15 ) ||      # both small in abs precision
               ( ! defined($out_noise) &&
                 abs($Y1) <= $noise_value &&
                 abs($Y2) <= $noise_value )  # both small wrt noise_value
            ){
            $y_new[$i] = $last;
        }
        # acceptable value - reset $last
        else{
            # consider outside the initial noise range
            $out_noise = "";
            $ratio = $Y2/$Y1;
            $y_new[$i] = log($ratio)/$x_diff;
            $last = $y_new[$i];
        }
    }
    if( $#x_ref > 0 ){
        $y_new[0] = $y_new[1];
    }
    else{
        $y_new[0] = 0;
    }
    @$y_ref = @y_new;
}

#............................................................................
#...Name
#...====
#... my_mkdir_hpss
#...
#...Purpose
#...=======
#... creates a directory (with parents) of the group and mode.
#... If dir already exists and you can cd into it, just returns 0.
#...
#...Arguments
#...=========
#... $dir_in   Intent: in
#...           Perl type: scalar
#...           the directory
#...
#... $group_in Intent: in
#...           Perl type: scalar
#...           the group (default is group of last parent that already exists
#...
#... $mode_in  Intent: in
#...           Perl type: scalar
#...           umask is always ignored
#...           the mode (default is 2770)
#...
#...Program Flow
#...============
#... 1) find last parent that exists (and get info about that parent)
#... 2) create child dirs
#............................................................................
sub my_mkdir_hpss {
    my %args = (
        DIR        => undef, # directory to make
        ERROR_SUB  => undef, # subroutine ref to call before exit
        GROUP      => undef, # group to make
        GROUP_REF  => undef, # reference to group actually used (will be set)
        MODE       => undef, # decimal mode
        FIX        => undef, # if set, fix things like acls and perms regardless if dir was made
        VERBOSE    => undef,
        @_,
        );

    my $args_valid = "DIR|ERROR_SUB|FIX|GROUP|GROUP_REF|MODE|VERBOSE";

    my(
        $arg,
        %args_new,
        $com,
        $created_dir,
        $dir,
        $dir_info,
        $dir_parent,
        @fields,
        $group,
        $group_found,
        $group_used,
        $hpss_ex,
        $ierr,
        $mode,
        $out,
        $out_new,
        $perms,
        $status,
        );

    $ierr = 0;

    # check args
    foreach $arg ( keys %args ){
        if( $arg !~ /^($args_valid)$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            if( defined( $args{ERROR_SUB} ) ){
                &{$args{ERROR_SUB}}($ierr);
            }
            exit( $ierr );
        }
    }

    $dir   = $args{DIR};
    $group = $args{GROUP};

    # just do this mode by default
    $mode = $args{MODE};
    if( ! defined($mode) ){
        $mode = "2770";
    }
    # always add in group sticky bit - I think always good to have
    $mode = sprintf( "%lo", oct($mode)|02000);

    # hpss_exec
    $hpss_ex = "";
    # try hsi first (faster and psi going away)
    if( $hpss_ex eq "" ){
        $hpss_ex = &which_exec( "hsi", QUIET=>"" );
    }
    # try psi
    if( $hpss_ex eq "" ){
        $hpss_ex = &which_exec( "psi", QUIET=>"" );
    }
    if( $hpss_ex eq "" ){
        $ierr = 1;
        &print_error( "Cannot find an hpss exec (hsi, psi)", $ierr );
        if( defined( $args{ERROR_SUB} ) ){
            &{$args{ERROR_SUB}}($ierr);
        }
        exit( $ierr );
    }


    if( defined($args{VERBOSE}) ){
        print "$args{VERBOSE}my_mkdir_hpss : mode=$mode group=";
        if( defined($group) ){
            print "$group";
        }
        else{
            print "<parent>";
        }
        print " dir=$dir\n";
    }

    # error
    if( ! defined($dir) || $dir !~ /\S/ ){
        $ierr = 1;
        &print_error( "Missing dir", $ierr );
        if( defined( $args{ERROR_SUB} ) ){
            &{$args{ERROR_SUB}}($ierr);
        }
        exit( $ierr );
    }

    # hsi
    if( $hpss_ex =~ /hsi$/ ){

        # do a listing of the directory

        # get info about dir
        $dir_info = $dir;
        $com = "$hpss_ex ls -lad $dir_info";
        $status = 0;
        $out = &run_command( COMMAND=>$com, STATUS=>\$status );

        # authentication error - will never work
        if( $out =~ /unable to setup communication to HPSS/i ){
            $ierr = 1;
            &print_error( "Authentication error [$dir_info]", "\n$out", $ierr );
            if( defined( $args{ERROR_SUB} ) ){
                &{$args{ERROR_SUB}}($ierr);
            }
            exit( $ierr );
        }

        # parse output
        $perms       = "";
        $group_found = "";
        if( $status == 0 ){
            ($out_new = $out) =~ s/\s*$//;
            # get last line
            if( $out_new =~ /([^\n]+)$/ ){
                $out_new = $1;
                $out_new =~ s/^\s+//;
                @fields = split(/\s+/, $out_new);
                $perms       = $fields[0];
                $group_found = $fields[3];
                if( ! defined( $group ) ){
                    $group = $group_found;
                    if( defined($args{GROUP_REF}) ){
                        ${$args{GROUP_REF}} = $group;
                    }
                }
            }
        }
        
        # if already a directory
        if( $perms =~ /^d/ ){
            $status = 0;
        }

        # not a directory (file or something)
        elsif( $perms =~ /\S/ && $perms !~ /^d/ ){
            $ierr = 1;
            &print_error( "File exists, but is not a directory [$dir]", "\n$out", $ierr );
            if( defined( $args{ERROR_SUB} ) ){
                &{$args{ERROR_SUB}}($ierr);
            }
            exit( $ierr );
        }

        # does not exist - but no error (will try to create)
        else{
            $status = 1;
        }

        # try to create
        if( $status != 0 ){

            # if not given a group, use group of parent (if exists)
            if( ! defined($group) ){
                # get info about dir
                $dir_info = &my_dir($dir);
                $com = "$hpss_ex ls -lad $dir_info";
                $status = 0;
                $out = &run_command( COMMAND=>$com, STATUS=>\$status );
                
                # authentication error - will never work
                if( $out =~ /unable to setup communication to HPSS/i ){
                    $ierr = 1;
                    &print_error( "Authentication error [$dir_info]", $out, $ierr );
                    if( defined( $args{ERROR_SUB} ) ){
                        &{$args{ERROR_SUB}}($ierr);
                    }
                    exit( $ierr );
                }
                
                # parse output
                $perms       = "";
                $group_found = "";
                if( $status == 0 ){
                    $out =~ s/\s*$//;
                    # get last line
                    if( $out =~ /([^\n]+)$/ ){
                        $out = $1;
                        $out =~ s/^\s+//;
                        @fields = split(/\s+/, $out);
                        $perms       = $fields[0];
                        $group_found = $fields[3];
                    }
                }
                if( $group_found =~ /\S/ ){
                    $group = $group_found;
                    if( defined($args{GROUP_REF}) ){
                        ${$args{GROUP_REF}} = $group;
                    }
                }
            }

            # try to create the file
            $com = "$hpss_ex mkdir -m $mode ${dir}";
            $out = &run_command( COMMAND=>$com, STATUS=>\$status, ERROR_SUB=>$args{ERROR_SUB} );

            # authentication error - will never work
            if( $out =~ /unable to setup communication to HPSS/i ){
                $ierr = 1;
                &print_error( "Authentication error [$dir_info]", "\n$out", $ierr );
                if( defined( $args{ERROR_SUB} ) ){
                    &{$args{ERROR_SUB}}($ierr);
                }
                exit( $ierr );
            }
            # if trying to create directory where you cannot, error here
            elsif( $out =~ /access denied/i ){
                $ierr = 1;
                &print_error( "Access denied [$dir]", "\n$out", $ierr );
                if( defined( $args{ERROR_SUB} ) ){
                    &{$args{ERROR_SUB}}($ierr);
                }
                exit( $ierr );
            }

            # if created at this point
            if( $status == 0 ){
                $created_dir = "";
            }

            # WOW!! mkdir silently fails if the file already exists (even if text file)
            #       But if this is the case, the the above "cd" check would have failed
            #       So, can correctly use the $status failure as indicator that file
            #       does not exist or incorrect permissions.

            # if there was an error, try to run one directory up (to make parents)
            # do this way instead of using "-p" because I want all the parent dirs
            # to have the correct settings
            if( $status != 0 ){
                $dir_parent = &my_dir( $dir );
                # if has a parent
                if( $dir_parent ne $dir && $dir_parent ne "" ){
                    %args_new      = %args;
                    $args_new{DIR} = $dir_parent;
                    if( defined( $args{VERBOSE} ) ){
                        $args_new{VERBOSE} = "$args{VERBOSE}  ";
                    }
                    $ierr = &my_mkdir_hpss( %args_new, GROUP_REF=>\$group_used );
                    if( ! defined($group) ){
                        $group = $group_used;
                        if( defined($args{GROUP_REF}) ){
                            ${$args{GROUP_REF}} = $group;
                        }
                    }
                    # if still error, then abort
                    if( $ierr != 0 ){
                        &print_error( "Could not create parent directory [$dir_parent] of dir [$dir]", $ierr );
                        if( defined( $args{ERROR_SUB} ) ){
                            &{$args{ERROR_SUB}}($ierr);
                        }
                        exit( $ierr );
                    }
                    # run again on full dir
                    $com = "$hpss_ex mkdir -m $mode ${dir}";
                    &run_command( COMMAND=>$com, STATUS=>\$status, ERROR_SUB=>$args{ERROR_SUB} );
                    # now if error, abort
                    if( $status != 0 ){
                        $ierr = 1;
                        &print_error( "Could not create directory [$dir] after creating parent [$dir_parent]", $ierr );
                        if( defined( $args{ERROR_SUB} ) ){
                            &{$args{ERROR_SUB}}($ierr);
                        }
                        exit( $ierr );
                    }
                    $created_dir = "";
                }
                else{
                    $ierr = 1;
                    &print_error( "Could not create directory [$dir]", $ierr );
                    if( defined( $args{ERROR_SUB} ) ){
                        &{$args{ERROR_SUB}}($ierr);
                    }
                    exit( $ierr );
                }
            }
        }

        # if created_dir
        if( defined( $created_dir ) ){
            if( defined( $args{VERBOSE} ) ){
                print "$args{VERBOSE}my_mkdir_hpss : mode=$mode group=$group dir=$dir created\n";
            }
        }

        # fix if created_dir or FIX
        if( defined( $created_dir ) || defined($args{FIX}) ){

            # hsi is pretty damn slow...so string as many of these commands together as you can
            $com = "";
            
            # remove all acl and inheritance
            # can string commands together with ";" but not "&&"
            # consult said to order "-ic" -> "-io" ... dunno why...
            $com .= "chacl -c ${dir} ; chacl -c -ic ${dir} ; chacl -c -io ${dir} ; ";
            
            # chgrp and chmod
            $com .= "chgrp ${group} ${dir} ; chmod $mode ${dir} ; ";
            
            # remove extra
            $com =~ s/\s*;\s*$//;
            
            $com = "$hpss_ex '$com'";
            # do not error - might not own dir?
            &run_command( COMMAND=>$com );
        }

    }

    # psi
    # NOTE: this is not as fancy as the above that creates the directory chain
    #       correctly.   But, psi going away, so not worth the effort to fix.
    elsif( $hpss_ex =~ /psi$/ ){

        # create dir
        $com = "$hpss_ex mkdir -p --cond ${dir}";
        &run_command( COMMAND=>$com, ERROR_REGEXP=>'/Error E/', ERROR_SUB=>$args{ERROR_SUB} );

        $com = "";
        $com .= "chacl -c ${dir}; ";
        if( defined($group) ){
            $com .= "chgrp ${group} ${dir}; ";
        }
        $com .= "chmod $mode ${dir}; ";

        # remove extra
        $com =~ s/\s*;\s*$//;

        $com = "$hpss_ex '$com'";
        &run_command( COMMAND=>$com, ERROR_SUB=>$args{ERROR_SUB} );

        # not really correct if dir already exists...but put here
        # and psi going away anyways
        if( defined( $args{VERBOSE} ) ){
            print "$args{VERBOSE}my_mkdir_hpss: created [$dir]\n";
        }
    }
    
    # sanity check
    else{
        $ierr = 1;
        &print_error( "Cannot find an hpss exec (hsi, psi)", $ierr );
        if( defined( $args{ERROR_SUB} ) ){
            &{$args{ERROR_SUB}}($ierr);
        }
        exit( $ierr );
    }

    return( $ierr );

}

##################################################################################
# stuff <key> = <val> into hash
sub parse_key_val{
    my( $out,
        $key_val_ref,
        ) = @_;
    my(
        $line,
        @lines,
        );
    @lines = split( "\n", $out );
    foreach $line ( @lines ){
        if( $line =~ /^\s*(\S+)\s*=\s*(\S.*)$/ ){
            $$key_val_ref{$1} = $2;
        }
    }
}

#............................................................................
#...Name
#...====
#... print_error
#...
#...Purpose
#...=======
#... Print a standard error message.
#...
#...Arguments
#...=========
#... error_lines  Intent: in
#...              Perl type: array
#...              0: cause of error (file_name:line_number)
#...              1: explanation/fix (if there is one)
#...              2: error value
#...
#...Program Flow
#...============
#... 1) see if warning or error (last argument is 0 or not)
#... 2) Line up error lines by column
#... 3) find out who was calling this routine and the line number
#... 4) print out info
#............................................................................
sub print_error
  {
    my( 
       @error_lines # what emitted the error
      ) = @_;
    my(
       @c_filename,    # caller val
       @c_line,        # caller val
       @c_package,     # caller val
       @c_subname,     # caller val
       $error_level,   # what is printed (eg WARNING or ERROR)
       $error_line,    # each line of input argument
       $error_message, # the message to print
       $i,             # loop var
       @routine_info,  # var from caller
       $spaces         # spaces for lining up columns
      );
    #......................................................
    #...assign WARNING or ERROR depending on error value...
    #......................................................
    if ( "$error_lines[$#error_lines]" eq "0" )
      {
        $error_level = "**WARNING**";
        $spaces      = "           ";
      }
    else
      {
        $error_level = "**ERROR**";
        $spaces      = "         ";
      }
    #............................................................
    #...DONE: assign WARNING or ERROR depending on error value...
    #............................................................
    #.......................................
    #...init error and add argument lines...
    #.......................................
    $error_message = "\n$error_level Message:\n";
    foreach $error_line ( @error_lines )
      {
        $error_message .= "$spaces  $error_line\n";
      }
    # date
    $error_message .= $spaces." Date: ".&date_ymdhms_sep()."\n";
    #...........
    #...stack...
    #...........
    $error_message .= $spaces." Stack:\n";
    $i = 0;
    @routine_info = caller($i);
    while( $#routine_info >= 3 )
      {
        $i++;
        push( @c_package,  $routine_info[0] );
        push( @c_filename, $routine_info[1] );
        push( @c_line,     $routine_info[2] );
        push( @c_subname,  $routine_info[3] );
        @routine_info = caller($i);
      }
    shift( @c_subname );
    push( @c_subname, "main" );
    for( $i = $#c_package; $i >= 0; $i-- )
      {
        $error_message .= sprintf( "%s  %04d %s%s:%s %s\n",
                                   $spaces, $#c_package - $i,
                                   " "x($#c_package - $i),
                                   $c_filename[$i], $c_line[$i],
                                   $c_subname[$i]);
      }
    #..........................................
    #...print error and return error message...
    #..........................................
    print STDERR $error_message;
    $error_message;
  }

#............................................................................
#...Name
#...====
#... print_perl_obj
#...
#...Purpose
#...=======
#... Print the structure of a perl object...for easier debugging.
#... Mixtures of arrays, hashes, and scalars can be printed.
#...
#... Up to a certain number of hash/array values are printed.
#... Beyond this, values are skipped (unless they are a reference
#... themselves) until the last value of the array/hash.
#...
#...Arguments
#...=========
#... $obj_ref          Intent: in
#...                   Perl type: reference to array
#...                   Reference to object to print (\%, \@, \$)
#...
#... $in_pref          Intent: in
#...                   Perl type: scalar
#...                   The preface string to name this object.
#...                   If passing \%foo, a good pref might be "foo".
#...                   if not defined, a default will be used.
#...
#... $in_max_items     Intent: in
#...                   Perl type: scalar
#...                   Maximum number of items in array/hash to print.
#...                   If negative, print all items.
#...                   If not defined, all items will be printed.
#...
#... $in_file          Intent: in
#...                   Perl type: scalar
#...                   Output file (usually just STDOUT).
#...                   on the same plot.
#...                   If not defined, STDOUT will be used.
#...
#...Program Flow
#...============
#... 1) If hash or array, recursively call this routine.
#... 2) If scalar, print the value.
#............................................................................
sub ppo{&print_perl_obj(@_)} # quick name for print_perl_obj
sub print_perl_obj
{
  my(
     $obj_ref,
     $in_pref,
     $in_max_items,
     $in_file
    ) = @_;
  my(
     $file, # file to use
     $i, # loop var
     @indices, # indices of object
     $max_items, # max items to use
     $new_pref, # new preface
     $pref, # preface to use
     $skip, # if skipping
     $skip_count, # how many skipped
     $val, # scalar value
    );
  #..........................
  #...fix non-defined vals...
  #..........................
  if( ! defined( $in_pref ) )
    {
      $pref = "var";
    }
  else
    {
      $pref = $in_pref;
    }
  if( ! defined( $in_max_items ) )
    {
      $max_items = -1;
    }
  else
    {
      $max_items = $in_max_items;
    }
  if( ! defined( $in_file ) )
    {
      $file = STDOUT;
    }
  else
    {
      $file = $in_file;
    }
  #...............................
  #...print depending upon type...
  #...............................
  if( ref( $obj_ref ) eq "ARRAY" )
  {
    if( $#{$obj_ref} < 0 )
      {
        print {$file} "$pref\[\] undefined\n";
      }
    else
      {
        $skip = 0;
        $skip_count = 0;
        for( $i = 0; $i <= $#{$obj_ref}; $i++ )
          {
            #...determine if should skip printing this one...
            if( $i > $max_items-1 && $max_items >= 0 )
              {
                $skip = 1;
              }
            $new_pref = sprintf( "%s[%s]", $pref, $i );
            $val = $$obj_ref[$i];
            if( ref( $val ) )
              {
                # recursively only do if non-skip
                if( $skip == 0 || $i == $#{$obj_ref} ) {
                    if( $skip_count > 0 ){
                        print {$file} "$pref\[...$skip_count\]\n";
                    }
                    &print_perl_obj( $val, $new_pref, $max_items, $file )
                }
                else{
                    $skip_count++;
                }
              }
            else
              {
                #...print last one no matter what...
                if( $skip && $i < $#{$obj_ref} )
                  {
                    $skip_count++;
                    next;
                  }
                if( $skip_count > 0 )
                  {
                    print {$file} "$pref\[...$skip_count\]\n";
                    $skip_count = 0;
                  }
                &print_perl_obj( \$val, $new_pref, $max_items, $file )
              }
          }
      }
  }
  elsif( ref( $obj_ref ) eq "HASH" )
  {
    @indices = sort keys %{$obj_ref};
    if( $#indices < 0 )
      {
        print {$file} "$pref\{\} undefined\n";
      }
    else
      {
        for( $i = 0; $i <= $#indices; $i++ )
          {
            $new_pref = sprintf( "%s{%s}", $pref, $indices[$i] );
            $val = $$obj_ref{$indices[$i]};
            if( ref( $val ) )
              {
                &print_perl_obj( $val, $new_pref, $max_items, $file )
              }
            else
              {
                &print_perl_obj( \$val, $new_pref, $max_items, $file )
              }
          }
      }
  }
  else
  {
     if( defined( $$obj_ref ) )
     {
       print {$file} "$pref = [$$obj_ref]\n";
     }
     else
     {
       print {$file} "$pref undefined\n";
     }
  }
}

#............................................................................
#...Name
#...====
#... run_command
#...
#...Purpose
#...=======
#... Runs a command and does varios things depending on args.
#... Returns the output.
#...
#...Arguments
#...=========
#... APPEND       Intent: in
#...              Perl type: scalar
#...              Default: overwrite
#...              If output is appended to ouput file
#...
#... COMMAND      Intent: in
#...              Perl type: scalar
#...              command to run
#...
#... OUT_FILE     Intent: in
#...              Perl type: scalar
#...              Default: no output file
#...              output file name
#...              If specified:
#...                 <OUT_FILE> = output file of command as it is running
#...                 <OUT_FILE>_post = output plus some additional info
#...
#... ERROR_REGEXP Intent: in
#...              Perl type: scalar
#...              Default: no error checking
#...              Regular expression to check on for error condition.
#...              Must be put in single ticks:
#...                  ERROR_REGEXP => '/^error(s)?$/i'
#...
#...Usage
#...=====
#...  use my_utils qw ( run_command );
#...  &run_command( COMMAND => "ls", OUT_FILE => './ls_out.txt' )
#...
#...NOTES
#...=====
#...  o For "TIMEOUT", only the first command is done under timeout.
#...    COMMAND=>"df -h /foo ; df -h /bar" TIMEOUT=>"4s"   ====>
#...    timout -s 9 4s df -h /foo ; df -h /bar
#...
#...Program Flow
#...============
#... 1) go through command line and assign to cmd hash
#............................................................................
sub run_command
  {
    my %args = (
                APPEND       => undef,
                COMMAND      => undef,
                DEBUG        => undef,
                ERROR_FILE   => undef,
                ERROR_REGEXP => undef,
                ERROR_SUB    => undef, # subroutine ref to call before exit
                ERROR_STATUS => undef, # exit if status != 0
                FORK         => undef, # fork the command - returns pid
                FORK_EXEC    => undef, # does fork/exec
                GROUP        => undef,
                OUT_FILE     => undef,
                STATUS       => undef, # ref to status return
                STDOUT       => undef, # no output - send to screen
                TIMING       => undef, # if printing timing output
                VERBOSE      => undef,
                VERBOSE_ECHO => undef, # just echo the command itself
                TIMEOUT      => undef, # seconds to timeout
                @_,
               );
    my(
       $clear_out_file,
       $cwd,
       $command_exec,
       $date,
       $debug_on,
       $fh_FILE,
       $ierr,
       $key,
       $out_file_post,
       $output,
       $pid_child,
       $print_error_msg,
       $status,
       $time_a,
       $time_b,
       $timeout,
       $tee,
      );
    $status = 0;
    if( defined($args{TIMING}) ){
      $time_a = time();
      print      "Running:          $args{COMMAND}\n";
    }
    #...invalid args
    foreach $key ( keys %args )
      {
        if( $key !~ /^(APPEND|COMMAND|DEBUG|ERROR_FILE|ERROR_REGEXP|ERROR_STATUS|ERROR_SUB|FORK|FORK_EXEC|GROUP|OUT_FILE|STATUS|STDOUT|TIMEOUT|TIMING|VERBOSE|VERBOSE_ECHO)$/)
          {
            $ierr = 1;
            &print_error( "Invalid argument to run_command [$key]",
                          $ierr );
            exit( $ierr );
          }
      }
    if( ! defined( $args{COMMAND} ) || $args{COMMAND} !~ /\S/ )
      {
        $ierr = 1;
        &print_error( "COMMAND not defined or empty",
                      $ierr );
        exit( $ierr );
      }
    if( defined( $args{OUT_FILE} ) && $args{OUT_FILE} !~ /\S/ )
      {
        $ierr = 1;
        &print_error( "OUT_FILE set but empty",
                      $ierr );
        exit( $ierr );
      }
    if( defined( $args{APPEND} ) && ! defined ($args{OUT_FILE} ) )
      {
        $ierr = 1;
        &print_error( "APPEND set but OUT_FILE not",
                      $ierr );
        exit( $ierr );
      }
    $timeout = "";
    if( defined($args{TIMEOUT}) ){
        $timeout = &which_exec("timeout", QUIET=>"");
        if( $timeout ne "" ){
            $timeout = "$timeout -s 9 $args{TIMEOUT}";
        }
    }
    $cwd = &cwd();
    #...if set to debug, just echo
    if( defined( $args{DEBUG} ) )
      {
        $debug_on = "true";
        $command_exec = "echo '$args{COMMAND}'";
      }
    else
      {
        $debug_on = "false";
        $command_exec = "$args{COMMAND}";
      }
    #...clear output files and tee
    if( defined( $args{OUT_FILE} ) )
      {
        $tee = "| tee -a $args{OUT_FILE}";
        $out_file_post = "$args{OUT_FILE}_post";
        if( defined( $args{APPEND} ) )
          {
            #...clear it first time in run regardless
            if( ! defined( $G_RUN_COMMAND_SEEN{"$args{OUT_FILE}"} ) )
              {
                $clear_out_file = "true";
              }
            else
              {
                $clear_out_file = "false";
              }
          }
        else
          {
            $clear_out_file = "true";
          }
        $G_RUN_COMMAND_SEEN{"$args{OUT_FILE}"} = "";
        #...clear files if set
        if( $clear_out_file eq "true" )
          {
            if( ! open( $fh_FILE, ">$args{OUT_FILE}" ) )
              {
                $ierr = 1;
                &print_error( "Cannot open command output file [$args{OUT_FILE}]",
                              "Command: $args{COMMAND}",
                              $ierr );
                exit( $ierr );
              }
            close( $fh_FILE );
            # only use _post file if doing verbose also
            if( defined($args{VERBOSE}) ){
                if( ! open( $fh_FILE, ">$out_file_post" ) )
                {
                    $ierr = 1;
                    &print_error( "Cannot open command output file [$out_file_post]",
                                  "Command: $args{COMMAND}",
                                  $ierr );
                    exit( $ierr );
                }
                close( $fh_FILE );
                if( defined($args{GROUP}) ){
                    `chgrp $args{GROUP} '$args{OUT_FILE}' '$out_file_post'`;
                }
            }
          }
        if( defined($args{VERBOSE}) ){
            if( ! open( $fh_FILE, ">>$out_file_post" ) )
            {
                $ierr = 1;
                &print_error( "Cannot open command output file [$out_file_post]",
                              "Command: $args{COMMAND}",
                              $ierr );
                exit( $ierr );
            }
        }
      } # clear output files and tee
    else
      {
        $tee = "";
      }

    # VERBOSE_ECHO the command
    # if (debug and stdout) already echo so do not do again
    if( defined($args{VERBOSE_ECHO}) &&
        (
         ! ( $debug_on eq "true" && defined($args{STDOUT} ) )
        ) ){
        print "$args{COMMAND}\n";
    }

    #...print header, run comand, print footer
    if( defined($args{OUT_FILE}) && defined($args{VERBOSE}) )
      {
        ($date = `date 2>&1`) =~ s/\s*$//;
        print $fh_FILE "========\n";
        print          "========\n";
        print $fh_FILE "Date:             $date\n";
        print          "Date:             $date\n";
        print $fh_FILE "CWD:              $cwd\n";
        print          "CWD:              $cwd\n";
        print $fh_FILE "Command:          $args{COMMAND}\n";
        print          "Command:          $args{COMMAND}\n";
        print $fh_FILE "Debug:            $debug_on\n";
        print          "Debug:            $debug_on\n";
        print $fh_FILE "out_file:         $args{OUT_FILE}\n";
        print          "out_file:         $args{OUT_FILE}\n";
        print $fh_FILE "out_file_post:    $args{OUT_FILE}_post\n";
        print          "out_file_post:    $args{OUT_FILE}_post\n";
      }
    if( defined($args{VERBOSE}) )
      {
        print "CWD     : $cwd\n";
        print "Command : $args{COMMAND}\n";
      }

    # use timeout if set and available
    if( $timeout ne "" ){
        $command_exec = "$timeout $command_exec";
    }
    $command_exec = "($command_exec) 2>&1 $tee";
    if( defined( $args{FORK} ) ||
        defined( $args{FORK_EXEC} ) ){
        # parent block successful fork
        if( $pid_child=fork ) {
            $output = "";
            $status = 0;
            if( defined($args{FORK}) ){
                ${$args{FORK}} = $pid_child;
            }
            else{
                ${$args{FORK_EXEC}} = $pid_child;
            }
        }
        else{
            # if you do not close this, if parent uses STDIN, then
            # odd things happen (like my_readkey sometimes requiring
            # additional inputs for one <STDIN>)
            close( STDIN );
            open( STDIN, "</dev/null" );
            if( defined( $args{FORK_EXEC} ) ){
                exec( $command_exec );
                exit 0;
            }
            else{
                $output = `$command_exec`;
                $status = $?;
                wait;
            }
            exit 0;
        }
    }
    else{
        if( defined($args{STDOUT}) ) {
            $status = system( $command_exec );
            $output = "";
        }
        else {
            $output = `$command_exec`;
            $status = $?;
        }
    }

    # set status if defined
    if( defined($args{STATUS}) ){
        ${$args{STATUS}} = $status;
    }

    # if VERBOSE
    if( defined($args{VERBOSE}) )
      {
        print "Output  :\n$output\n";
      }

    # if error
    if( ! defined($args{DEBUG}) &&
        ( ( defined( $args{ERROR_REGEXP} ) && eval "\$output =~ $args{ERROR_REGEXP}" ) ||
          ( defined( $args{ERROR_STATUS} ) && $status != 0 ) ) )
      {
        $ierr = 1;
        $print_error_msg =
          &print_error( "Error running command [$args{COMMAND}]",
                        "cwd [$cwd]",
                        "Output from command:",
                        $output,
                        $ierr );
        if( defined($args{ERROR_FILE}) ){
          open( MY_RUN_COMMAND_FILE, ">$args{ERROR_FILE}" );
          print MY_RUN_COMMAND_FILE $print_error_msg;
          close( MY_RUN_COMMAND_FILE );
        }
        if( defined( $args{ERROR_SUB} ) ){
            &{$args{ERROR_SUB}}($ierr);
        }
        exit( $ierr );
      }
    if( defined($args{OUT_FILE}) && defined($args{VERBOSE}) )
      {
        ($date = `date 2>&1`) =~ s/\s*$//;
        print $fh_FILE "-------\n";
        print          "-------\n";
        print $fh_FILE "$output\n";
        print          " [see $args{OUT_FILE}]\n";
        print $fh_FILE "-------\n";
        print          "-------\n";
        print $fh_FILE "Date:             $date\n";
        print          "Date:             $date\n";
        print $fh_FILE "========\n";
        print          "========\n";
        close( $fh_FILE );
      }
    if( defined($args{TIMING}) ){
      $time_b = time();
      printf( "TIME:    %.2f mins\n", ($time_b - $time_a)/60.0 );
    }
    return( $output );
  }

#...case insensitive sort
sub sort_case_insensitive
  {
    my( $a, $b );
    lc($a) cmp lc($b);
  }
sub sort_unique{
    my( $array_ref ) = @_;
    my( @array, %seen );
    @array = sort grep{ ! $seen{$_}++ } @{$array_ref};
}
sub sort_numerically_unique{
    my( $array_ref ) = @_;
    my( @array, %seen );
    @array = sort my_numerically grep{ ! $seen{$_}++ } @{$array_ref};
}

#............................................................................
#...Name
#...====
#... my_getval
#...
#...Purpose
#...=======
#...  Gets a value from stdin
#...  If VAR already set, then just return - no checking done.
#...
#...Arguments
#...=========
#... PROMPT       Intent: in
#...              Perl type: scalar
#...              Default: "Value?"
#...              The question to ask for the value.
#...
#... DEFAULT      Intent: in
#...              Perl type: scalar
#...              Default: none
#...              default value.
#...
#... TYPE         Intent: in
#...              Perl type: scalar
#...              Default: STRING
#...              Type of value read in.
#...
#... REGEXP       Intent: in
#...              Perl type: scalar
#...              Default: none
#...              Value must also match the regexp
#...
#... DIR          Intent: in
#...              Perl type: scalar
#...              Default: none
#...              When finding files, use this as path
#...
#... VAR          Intent: inout
#...              Perl type: scalar
#...              Default: none
#...              variable to assign value to.
#...
#............................................................................
sub my_getval{
    my %args = (
        PROMPT      => undef,
        SET_IT      => undef, # ask first if you even want to set it
        DEFAULT     => undef,
        TYPE        => undef,
        REGEXP      => undef,
        DIR         => undef,
        BLANK       => undef,
        VAR         => undef,
        NOTE        => undef,
        USE_DEFAULT => undef, # if should use the default w/out asking
        @_,
        );

    my $args_valid = "BLANK|DEFAULT|DIR|NOTE|PROMPT|REGEXP|SET_IT|TYPE||USE_DEFAULT|VAR";
    
    my(
        $done,
        $ierr,
        $key,
        $set_it,
        %time,
        $val,
        $val_dir,
        $var_ref,
    );
    
    $ierr = 0;
    
    #...invalid args
    foreach $key ( keys %args ) {
        if( $key !~ /^(${args_valid})$/) {
            $ierr = 1;
            &print_error( "Invalid argument [$key]",
                          $ierr );
            exit( $ierr );
        }
    }
    
    # must have space for var
    if( ! defined($args{VAR}) ){
        $ierr = 1;
        &print_error( "Must define VAR",
                      $ierr );
        exit( $ierr );
    }
    $var_ref = $args{VAR};

    # if already defined, return
    if( defined( $$var_ref ) ){
        return( $ierr );
    }

    # init PROMPT
    if( ! defined($args{PROMPT}) ){
        $args{PROMPT} = "Value?";
    }
    
    # check SET_IT (will exit if no)
    if( defined($args{SET_IT}) ){
        &my_getval( PROMPT=>"Set $args{PROMPT}", DEFAULT=>$args{SET_IT},
                    TYPE=>"yes/no", VAR=>\$set_it, USE_DEFAULT=>$args{USE_DEFAULT} );
        if( $set_it ne "yes" ){
            return( $ierr );
        }
    }
    
    # if USE_DEFAULT, set to default and return if set
    # Need to be done after check for SET_IT
    if( defined($args{USE_DEFAULT}) ){
        $$var_ref = $args{DEFAULT};
    }
    # now check again if already defined, return
    if( defined( $$var_ref ) ){
        return( $ierr );
    }
    
    # other defaults
    if( ! defined($args{TYPE}) ){
        $args{TYPE} = "string";
    }
    
    # get value
    $done = "false";
    while( $done eq "false" ){
        $done = "true";
        # NOTE
        if( defined($args{NOTE}) && $args{NOTE} =~ /\S/ ){
            print "$args{NOTE}\n";
        }
        # read in val
        print "$args{PROMPT} ";
        if( defined($args{REGEXP}) ){
            print "(regexp [$args{REGEXP}]) ";
        }
        if( defined($args{TYPE}) ){
            print "(type [$args{TYPE}]) ";
        }
        if( defined($args{DEFAULT}) ){
            print "(default [$args{DEFAULT}]) ";
        }
        if( defined($args{BLANK}) ){
            print "(<space> for no value) ";
        }
        $val = <STDIN>;
        chomp( $val );
        if( $val =~ /^\s+$/ && defined($args{BLANK}) ){
            $$var_ref = "";
            return( $ierr );
        }
        $val =~ s/^\s*//;
        $val =~ s/\s*$//;
        if( $val eq "" && defined($args{DEFAULT}) ){
            $val = $args{DEFAULT};
        }
        if( defined($args{DIR}) ){
            if( $val =~ m&^/& ){
                $val_dir = $val;
            }
            else{
                $val_dir = "$args{DIR}/$val";
            }
        }
        else{
            $val_dir = $val;
        }
        # make sure matches REGEXP if any
        if( defined($args{REGEXP}) && eval "\$val !~ $args{REGEXP}" ){
            print "ERROR: [$val] does not match [$args{REGEXP}]\n";
            $done = "false";
            next;
        }
        # check TYPE
        if( $args{TYPE} eq "string" ){
        }
        elsif( $args{DEFAULT} eq "" && $val eq "" ){
        }
        elsif( $args{TYPE} eq "exec" ){
            if( ! -x $val_dir || -d $val_dir ){
                print "ERROR: [$val_dir] not executable\n";
                $done = "false";
            }
        }
        elsif( $args{TYPE} eq "yes/no" ){
            if( $val ne "yes" && $val ne "no" ){
                print "ERROR: [$val] must be either 'yes' or 'no'\n";
                $done = "false";
            }
        }
        elsif( $args{TYPE} =~ /\|/ ){
            if( $val !~ /^$args{TYPE}$/ ){
                print "ERROR: [$val] must be [$args{TYPE}]\n";
                $done = "false";
            }
        }
        elsif( $args{TYPE} eq "file" ){
            if( ! -e $val_dir || -d $val_dir ){
                print "ERROR: [$val_dir] not file\n";
                $done = "false";
            }
        }
        elsif( $args{TYPE} eq "dir" ){
            if( ! -d $val_dir ){
                print "ERROR: [$val_dir] not directory\n";
                $done = "false";
            }
        }
        elsif( $args{TYPE} eq "int" ){
            if( $val !~ /^\d+$/ ) {
                print "ERROR: [$val] must be an int\n";
                $done = "false";
            }
        }
        elsif( $args{TYPE} eq "int_frac" ){
            if( $val !~ /^\d+$/ &&
                $val !~ /^\d+\/\d+$/ ) {
                print "ERROR: [$val] must be an int or a fraction\n";
                $done = "false";
            }
        }
        elsif( $args{TYPE} eq "time" ){
            %time = &conv_time( STRING=>$val );
            $val = $time{hms};
        }
        else{
            $ierr = 1;
            &print_error( "Invalid type [$args{TYPE}]",
                          $ierr );
            exit( $ierr );
        }
    }
    $$var_ref = $val;
    return( $ierr );
  }

#............................................................................
#...Name
#...====
#... which_exec
#...
#...Purpose
#...=======
#... Returns value for full path to executable ("" if not found).
#...
#...Arguments
#...=========
#... exec Intent: in
#...      Perl type: string scalar
#...      executable in question
#... QUIET Intent: in
#...       Perl type: hash scalar
#...       be quiet
#... ERROR Intent: in
#...       Perl type: hash scalar
#...       error if not found
#... NOEXEC Intent: in
#...        Perl type: hash scalar
#...        execute permission not needed for file
#...
#...Program Flow
#...============
#... 1) go through path to find exec
#............................................................................
sub which_exec {
    my(
       $exec,
       ) = shift(@_);
    my %args = (
                QUIET         => undef,
                ERROR         => undef,  # error if not found
                NOEXEC        => undef,  # if ok if not executable
                XPATH         => undef,  # additionap path search
                USE           => undef,  # will set to $exec if not found
                ERROR_SUB     => undef,  # call this if exit forced
                SCRIPT_STRING => undef, # if the exec is a script and matches this, no exec
                @_,
                );
    my( $args_valid ) = "QUIET|ERROR|ERROR_SUB|NOEXEC|SCRIPT_STRING|USE|XPATH";
    my(
       $cwd, # current working dir
       $ierr, # error return value
       $exec_try, # see if exec is here
       $found, # if found
       $key,
       $out,
       $path, # current dir in search for execs
       @paths, # list of search paths for execs
       $this_dir, # current directory
       );

    #...invalid args
    foreach $key ( keys %args ) {
        if( $key !~ /^($args_valid)$/) {
            $ierr = 1;
            &print_error( "Invalid argument to which_exec [$key]",
                          $ierr );
            exit( $ierr );
        }
    }

    #...build paths from PATH and others...
    $cwd = getcwd();
    $path = $ENV{PATH};
    @paths = split( /:/, $ENV{PATH} );
    # prepend path to exec to path
    ($this_dir = $0) =~ s/\/[^\/]+$//;
    unshift( @paths, $this_dir );
    # if set to look in additional places, do so
    if( defined( $args{XPATH}) ){
        unshift( @paths, split(':', &path_add_default("") ) );
        # do not prepend "." by default
        # unshift( @paths, "." );
    }

    #.....................................
    #...loop through paths to find exec...
    #.....................................
    $found = "false";
    foreach $path (@paths) {
        if( $path eq "." ){
            $path = $cwd;
        }
        $exec_try = "$path/$exec";
        if( -f "$exec_try" ){
            # NOEXEC or it must also be executable
            if( defined($args{NOEXEC}) || -x "$exec_try" ){
                # check against SCRIPT_STRING
                # we have commands (msub) that have been depricated and have been
                # replaced with a script that point elsewhere (sbatch).
                if( defined($args{SCRIPT_STRING}) ){
                    $out = `file -L '$exec_try' 2>&1`;
                    if( $out =~ /script/ ){
                        $out = `head $exec_try 2>&1`;
                        if( $out =~ /$args{SCRIPT_STRING}/ ){
                            next;
                        }
                    }
                }
                $found = "true";
                last;
            }
        }
    }

    #........................................
    #...error if still could not find exec...
    #........................................
    if( $found eq "false" ) {
        $ierr = 0;
        if( ! defined($args{QUIET}) || defined($args{ERROR}) ) {
            if( defined($args{ERROR}) ){
                $ierr = 1;
            }
            &print_error(
                         "Executable [$exec] not found in PATH",
                         $ierr
                         );
            if( defined($args{ERROR}) ){
                if( defined( $args{ERROR_SUB} ) ){
                    &{$args{ERROR_SUB}}($ierr);
                }
                exit( $ierr );
            }
        }
        if( defined($args{USE}) ){
            $exec_try = $exec;
        }
        else{
            $exec_try = "";
        }
    }
    return( $exec_try );
}

########################################################################

sub my_cleanpath{
    my(
        $path_in,
        ) = @_;
    # trim // and /./
    while( $path_in =~ m&//& || $path_in =~ m&/\./& ){
        $path_in =~ s&/\./&/&g;
        $path_in =~ s&\/+&/&g;
    }
    # trim trailing /.?
    $path_in =~ s&\/\.?$&&;
    return( $path_in );
}
sub my_notdir
  {
    my(
       $dir,
      ) = @_;
    my(
       $notdir,
      );
    $dir = &my_cleanpath($dir);
    ($notdir = $dir) =~ s&/*$&&;
    if( $notdir =~ m&([^/]+)$& )
      {
        $notdir = $1;
      }
    return( $notdir );
  }
sub my_dir
  {
    my(
       $file,
      ) = @_;
    my(
       $dir,
       $file_new,
       $file_old,
      );
    if( ! defined($file) ){
        $file = "";
    }
    if( $file !~ /\// ){
        $file = "./$file";
    }
    $file = &my_cleanpath($file);
    $file_new = $file;
    $file_old = "";
    while( $file_new ne $file_old ){
        $file_old = $file_new;
        $file_new =~ s&/[^/]+/\.\./&/&;
    }
    ($dir = $file_new) =~ s&^(.*)/.*?$&$1&;
    if( $dir eq "./." ){
        $dir = ".";
    }
    return( $dir );
  }

#############################################################################

# try to flush a file
sub my_file_flush{
    my( $file ) = @_;
    my( $i, $fh_FILE, @lines, %stat );
    # repeat
    for( $i = 0; $i < 2; $i++ ){
        `ls -la '$file' > /dev/null 2>&1 ; cat '$file' > /dev/null 2>&1`;
        if( open( $fh_FILE, "$file" ) ){
            @lines = <$fh_FILE>;
            close( $fh_FILE );
        }
        &my_stat( $file, \%stat );
        # hangs on some machines...sigh...
        # `sync`;
    }
}

##################################################################################

# non-blocking terminal input
# method 1:
#   use Term::ReadKey;
#   while( defined( ReadKey(-1) ) ){ $key = "" } ;
# will spend $time_in seconds checking for input
sub my_readkey{
    my(
        $time_in,
        ) = @_;
    my(
        $ret,
        $time,
        $try,
        $TTY_fh,
        );

    # do not "try" if not attached to terminal or in background
    $try = "true";
    # if STDIN not terminal
    if( $try eq "true" ){
        if( ! -e STDIN ){
            $try = "false";
        }
    }
    # detecting if background process
    if( $try eq "true" ){
        if (!open($TTY_fh, "/dev/tty")) {
            $try = "false";
        }
        else {
            my $tpgrp = &tcgetpgrp(fileno($TTY_fh));
            my $pgrp = &getpgrp();
            if ($tpgrp != $pgrp) {
                $try = "false";
            }
            close( $TTY_fh );
        }
    }

    # only get if getting STDIN from terminal not process
    if( $try eq "true" ){
        if( ! defined($MY_READKEY_S) ){
            $MY_READKEY_S = IO::Select->new();
            $MY_READKEY_S->add(\*STDIN);
        }
        if( ! defined( $time_in ) ){
            $time = 1;
        }
        else{
            $time = $time_in;
        }
        if ($MY_READKEY_S->can_read($time)) {
            $ret = <STDIN>;
            if( defined($ret) ){
                $ret =~ s/\s+$//;
            }
        }
        # do not think need this
        # $MY_READKEY_S->remove( \*STDIN );
    }
    return( $ret );
}

##################################################################################

# just quick fullpath
sub my_stat_fullpath{
    my(
        $file,
        $stat_ref,
        ) = @_;
    my(
        $ierr,
        );
    $ierr = 0;
    if( -e $file ){
        $$stat_ref{fullpath} = Cwd::realpath($file);
    }
    else{
        $ierr = 1;
    }
    return( $ierr );
}

# get stats on file
# return = 1 -> file does not exist
# return = 2 -> timeout hit
# the eval+`command` is expensive.  Consider if you have to do this for lots of files.
sub my_stat
  {
    my(
       $file,
       $stat_ref,
      ) = @_;
    my(
       $cwd,
       $timeout_hit, # for trying to stat files on dead filesystems
       $timeout_time, # time to spend looking for file
       # $timeout_sig_prev, # previous signale handler - not needed due to local
       @fields,
       $ierr,
       $time,
       @tmp,
      );
    $ierr = 0;
    undef( %{$stat_ref} );
    $time = time;

    # do a timeout to check for dead filesystem
    # must do command in "``" so that the alarm
    # can kill it.
    # On trinity back ends, 1 second was not enough...bump to 3
    $timeout_time = 3;
    $timeout_hit = "true";
    # do not need to remember/restore previous alarm since local below
    # $timeout_sig_prev = $SIG{ALRM};
    eval {
        local $SIG{ALRM} = sub { die "my_stat:alarm:timeout\n" };
        alarm($timeout_time);
        # just do something quick that will access the file.  Faster than stat or cd.
        # just `` itself takes a long time, unfortunately
        `readlink "$file" 2>&1`;
        $timeout_hit = "false";
        alarm(0);
    };
    # restore $SIG{ALRM} (above "local" seems to make it so not needed)
    # if( defined( $timeout_sig_prev ) ){
    #     $SIG{ALRM} = $timeout_sig_prev;
    # }

    # only do stat if not timeout_hit (filesystem hosed and stat will hang)
    if( $timeout_hit eq "false" ){
        @fields = stat $file;
    }

    if( $timeout_hit eq "false" && $#fields >= 0 ){
        $$stat_ref{exists} = "";
        $$stat_ref{dev}     = $fields[0];
        $$stat_ref{ino}     = $fields[1];
        $$stat_ref{mode}    = $fields[2];
        $$stat_ref{nlink}   = $fields[3];
        $$stat_ref{uid}     = $fields[4];
        $$stat_ref{gid}     = $fields[5];
        $$stat_ref{rdev}    = $fields[6];
        $$stat_ref{size}    = $fields[7];
        $$stat_ref{atime}   = $fields[8];
        $$stat_ref{mtime}   = $fields[9];
        $$stat_ref{ctime}   = $fields[10];
        $$stat_ref{blksize} = $fields[11];
        $$stat_ref{blocks}  = $fields[12];
        # additional info
        $$stat_ref{atime_since} = $time - $$stat_ref{atime};
        $$stat_ref{mtime_since} = $time - $$stat_ref{mtime};
        $$stat_ref{ctime_since} = $time - $$stat_ref{ctime};
        $$stat_ref{mtime_localtime} = scalar localtime($$stat_ref{mtime});
        $$stat_ref{group} = getgrgid($$stat_ref{gid});
        @tmp = getpwuid($$stat_ref{uid});
        $$stat_ref{user} = $tmp[0];
        # link stuff
        if( -l $file ){
            $$stat_ref{slink} = readlink($file);
        }
        # directory stuff
        $$stat_ref{fullpath} = Cwd::realpath($file);
        # should get realpath, but does on cielito for some dirs...cielito is broken
        if( ! defined($$stat_ref{fullpath}) || $$stat_ref{fullpath} !~ /\S/ ){
            $$stat_ref{fullpath} = $file;
            if( $$stat_ref{fullpath} !~ m&^/& ){
                $cwd = Cwd::getcwd();
                # if it cannot get cwd...all sorts of things are going to get hosed
                if( ! defined($cwd) ){
                    $cwd = "";
                }
                $$stat_ref{fullpath} = "$cwd/$$stat_ref{fullpath}";
            }
        }

        # if directory (pointing to a directory if slink)
        # This is expensive if doing a ton of files and not always needed.
        if( -d $$stat_ref{fullpath} ){
            $$stat_ref{is_dir}  = 1; # defined and 1 vs. not defined
        }
        elsif( -x $$stat_ref{fullpath} ){
            $$stat_ref{is_exec} = 1; # defined and 1 vs. not defined
        }

        $$stat_ref{dir}       = my_dir( $$stat_ref{fullpath} );
        $$stat_ref{notdir}    = my_notdir($$stat_ref{fullpath});
        $$stat_ref{mode_d}    = sprintf( "%o", $$stat_ref{mode} );
        # just last 4 digits for permission mode
        $$stat_ref{mode_dp}   = substr($$stat_ref{mode_d}, -4, 4);
        # what file this info is about (see my_stat_guess belos)
        $$stat_ref{info_on}   = $$stat_ref{fullpath};
        $$stat_ref{info_rest} = "";
    }
    else{
        if( $timeout_hit eq "false" ){
            $ierr = 1;
        }
        else{
            $ierr = 2;
        }
    }
    return( $ierr );
}

# does a my_stat for files that might not exist
# tries to fill in things like full paths and stuff
# if {exists} not defined, had to go up the directory
# tree.
sub my_stat_guess{
    my(
       $file,
       $stat_ref,
      ) = @_;
    my(
        $file_current,
        $file_chop,
        $file_new,
        $file_old,
        $offset,
        %stat
        );

    undef( %{$stat_ref} );

    $file_current = $file;

    # always fully qualify file_current
    if( $file_current !~ /^\// ){
        $file_current = &cwd()."/$file_current";
    }

    # <path>/<path1>/.. -> <path>
    $file_new = $file_current;
    $file_old = "";
    # for ease, tack on "/" at end
    if( $file_new !~ /\/$/ ){
        $file_new = "$file_new/";
    }
    while( $file_new ne $file_old ){
        $file_old = $file_new;
        $file_new =~ s&/[^/]+/\.\./&/&;
    }
    $file_new =~ s&/+$&&;

    # slrum on capulin seems to set workdir incorrectly (or at least
    # does not match what is on the front end.
    # sync code in run_status.pl and my_utils.pm
    # /yellow/projects -> /usr/projects
    if( $file_new =~ m&^(/(yellow/projects))(/.*)& ){
        if( ! -d "$1" ){
            $file_new = "/usr/projects/$3";
        }
    }
    # /yellow/foo -> /foo
    if( $file_new =~ m&^(/(yellow))(/.*)& ){
        if( ! -d "$1" ){
            $file_new = $3;
        }
    }
    # /pfs/foo/yellow -> /lustre/foo/
    if( $file_new =~ m&^(/(pfs)/)(.*)/yellow/(.*)& ){
        if( ! -d "$1" ){
            $file_new = "/lustre/$3/$4";
        }
    }

    # keep going up chain until found valid dir
    $file_current = $file_new;
    $file_chop = "";
    while( ! %stat ){
        &my_stat( $file_current, \%stat );
        if( ! %stat ){
            # try to clean up file
            $file_current =~ s&/+&/&;
            $file_current =~ s&/$&&;
            $file_current =~ s&/([^/]+)$&&;
            $file_chop = "${1}/${file_chop}";
            if( $file_current eq "" ){
                $file_current = "/";
            }
        }
    }

    %{$stat_ref} = %stat;

    # fill in things if needed to go up dirs to find valid dir
    # is_dir and is_exec will be undefined since do not know what will be
    if( $file_chop ne "" ){
        undef( $$stat_ref{exists} );
        $$stat_ref{fullpath} .= "/$file_chop";
        $$stat_ref{fullpath} =~ s&/+$&&;
        $$stat_ref{fullpath} =~ s&^/+&/&;
        $$stat_ref{dir} = my_dir( $$stat_ref{fullpath} );
        $$stat_ref{notdir} = my_notdir($$stat_ref{fullpath});
        $$stat_ref{info_rest} = $$stat_ref{fullpath};
        # if nothing in path, just remove slash
        if( $$stat_ref{info_on} eq "/" ){
            $offset = 0;
        }
        # otherwise remove through "/"
        else{
            $offset = 1;
        }
        substr( $$stat_ref{info_rest}, 0, length($$stat_ref{info_on})+$offset ) = "";
    }
}

########################################################################
# my_timer
# basic timer
sub my_timer{
    my %args = (
        NAME  => undef,
        OP    => undef,
        TAG   => undef,
        @_,
        );

    my $args_valid = "NAME|OP|TAG";

    my(
        $delta,
        $ierr,
        $key,
        $name,
        $op,
        $tag,
        );
    
    # invalid args
    foreach $key ( keys %args ) {
        if( $key !~ /^($args_valid)$/) {
            $ierr = 1;
            &print_error( "Invalid argument to which_exec [$key]",
                          $ierr );
            exit( $ierr );
        }
    }
    
    $name = $args{NAME} || "";
    $op   = $args{OP}   || "";
    $tag  = $args{TAG}  || "";

    # my_timernoop
    $op = "";
    
    # noop - just return time
    if( $op eq "" ){
        return( time() );
    }

    # start
    elsif( $op eq "start" ){
        $MY_TIMER_TIMES{$name} = time();
    }
    
    # stop
    elsif( $op eq "stop" ){
        $MY_TIMER_TIMES{$name} = time() - $MY_TIMER_TIMES{$name};
        printf( "my_timer: %-15s: %.6e %s\n", $name, $MY_TIMER_TIMES{$name}, $tag );
    }
    
    # delta
    elsif( $op eq "delta" ){
        if( ! defined( $MY_TIMER_TIMES{$name} ) ){
            $MY_TIMER_TIMES{$name} = time();
        }
        $delta = time() - $MY_TIMER_TIMES{$name};
        $MY_TIMER_TIMES{$name} = time();
        printf( "my_timer: %-15s: %.6e %s\n", $name, $delta, $tag );
    }
    
} # my_timer

#............................................................................
#...Name
#...====
#... my_xml_read
#...
#...Purpose
#...=======
#... Reads a text xml file with restrictions on the format.
#... Stuffs it into a hash.
#...
#...hash format
#...===========
#...  At each level:
#...    tag            = hash to next tag level (containing same keys)
#...    tag_name       = name of the tag
#...    tag_start_line = line string of start tag
#...    tag_start_ln   = line number in file of start tag
#...    tag_stop_line  = line string of stop  tag
#...    tag_stop_ln    = line number in file of stop  tag
#...    val            = value of this tag (either val or tag)
#... Example:
#... $hash{filename}{tag}
#... $hash{filename}{tag_start_line = ""
#...
#...Arguments
#...=========
#... HASHREF Intent: inout
#...      Perl type: reference to hash
#...
#... LABEL Intent: in
#...      Perl type: string
#...      xml start/stop tags of the form <LABEL<string>> and </LABEL<string>>
#...
#... FILENAME Intent: inout
#...      Perl type: string
#...      Filename to read
#...
#...Program Flow
#...============
#... 1) 
#............................................................................
sub my_xml_read{
    my %args = (
                FILE=>"",
                HASHREF=>undef,
                LABEL=>"",
                KEY=>undef,
                @_,
                );
    my(
       $file,
       $hashref,
       $label,
       );
    my(
       $done,
       $ierr,
       $key,
       $key_string,
       @keys,
       $line,
       $line_orig,
       $ln,
       $loc_ref,
       $pre,
       $rest,
       $stop,
       $str,
       $tag,
       $tag_last,
       $tag_str,
       $tag_str_short,
       @tags,
       $val,
       );
    #...invalid args
    foreach $key ( keys %args ) {
        if( $key !~ /^(FILE|HASHREF|KEY|LABEL)$/) {
            $ierr = 1;
            &print_error( "Invalid argument [$key]",
                          $ierr );
            exit( $ierr );
        }
    }
    $file = $args{FILE};
    $hashref = $args{HASHREF};
    $label = $args{LABEL};
    $key = $args{KEY};
    if( ! defined( $key ) ){
        $key = $file;
    }
    if( !defined($hashref) || ref($hashref) ne "HASH" ){
        $ierr = 1;
        &print_error( "HASHREF must be a reference to a hash",
                      $ierr );
        exit( $ierr );
    }
    if( ! open( FILE, "$file" ) ){
        $ierr = 1;
        &print_error( "File does not exist [$file]",
                      $ierr );
        exit( $ierr );
    }
    $ln = 0;
    $val = "";
    @tags = ("{\"$key\"}");
    $$hashref{"$key"}{tag_name}       = $key;
    $$hashref{"$key"}{tag_start_line} = "";
    $$hashref{"$key"}{tag_start_ln}   = 0;
    $$hashref{"$key"}{tag_stop_line}  = "";
    $$hashref{"$key"}{tag_stop_ln}    = 0;
    while( $line_orig=<FILE> ){
        $ln++;
        $line_orig =~ s/\n$//;
        $line = $line_orig;
        # consume line
        $done = "false";
        while( $done eq "false" ){
            # line contains start or stop
            if( $line =~ /(^.*?)<(\/)?$label([^>]*?)>(.*)$/ ){
                $pre = $1;
                $stop = $2;
                $tag = $3;
                $rest = $4;
                $val = $val.$pre;
                $tag_str = join( "{\"tag\"}", @tags );
                $tag_str_short = join( "", @tags );
                $str = "\\\%{\$\$hashref${tag_str}}";
                eval "\$loc_ref = $str";
                # ending tag - add to value and stop
                if( defined( $stop ) ){
                    $$loc_ref{"tag_stop_ln"} = $ln;
                    $$loc_ref{"tag_stop_line"} = $line_orig;
                    $tag_last = pop( @tags );
                    $tag_last =~ s/^{\"(.*)\"}/$1/;
                    if( "$tag_last" ne "$tag" ){
                        $ierr = 1;
                        &print_error( "Trying to end tag [$tag] of tag chain=[$tag_str_short]",
                                      "Start: $file:$$loc_ref{tag_start_ln}",
                                      "  $$loc_ref{tag_start_line}",
                                      "Stop:  $file:$ln",
                                      "  $line_orig",
                                      $ierr );
                        exit( $ierr );
                    }
                    $val =~ s/^\s+//;
                    $val =~ s/\s+$//;
                    # store val if non-blank
                    if( $val =~ /\S/ ){
                        # cannot have embedded values and tags
                        if( defined( $$loc_ref{"tag"} ) ){
                            @keys = sort keys(%{$$loc_ref{"tag"}} );
                            $key_string = join( ",", @keys );
                            $ierr = 1;
                            &print_error( "Cannot have both value and sub tags for tag=[$tag_str_short]",
                                          "Sub tags: $key_string",
                                          "Start: $file:$$loc_ref{tag_start_ln}",
                                          "  $$loc_ref{tag_start_line}",
                                          "Stop:  $file:$ln",
                                          "  $line_orig",
"[$val]\n",
                                          $ierr );
                            exit( $ierr );
                        }
                        $$loc_ref{"val"} = $val;
                        $$loc_ref{"val_line"} = $ln;
                        $val = "";
                    }
                }
                # starting tag
                else{
                    # if already defined, delete old one
                    delete($$loc_ref{tag}{$tag});
                    $$loc_ref{tag}{$tag}{"tag_start_ln"} = $ln;
                    $$loc_ref{tag}{$tag}{"tag_start_line"} = $line_orig;
                    $$loc_ref{tag}{$tag}{"tag_name"} = $tag;
                    # cannot have embedded values and tags
                    if( $val =~ /\S/ ){
                        @keys = sort keys(%{$$loc_ref{"tag"}} );
                        $key_string = join( ",", @keys );
                        $ierr = 1;
                        &print_error( "Cannot have both value and sub tags for tag=[$tag_str_short]",
                                      "Sub tags: $key_string",
                                      "Start: $file:$$loc_ref{tag_start_ln}",
                                      "  $$loc_ref{tag_start_line}",
                                      "Next start:  $file:$ln",
                                      "  $line_orig",
                                      $ierr );
                        exit( $ierr );
                    }
                    push( @tags, "{\"$tag\"}" );
                }
                $line = $rest;
            }
            # push onto current val
            else{
                $val = $val.$line."\n";
                $line = "";
            }
            # no more line, done
            if( $line eq "" ){
                $done = "true";
            }
        }
    }
    close( FILE );
    return( $ierr );
}

###########################################################################
# my_xml_read_simple
#   does a simple parse of text xml output (specifically for the
#   output from mdiag).
#   Too many systems do not have any perl xml reader module...so
#   writing my own....sigh...
#   XML_STRING will be consumed to the point where the to level
#   field is done.
#
# NOTE: will get confused by embedded "<", ">"
# NOTE: will get confused by embedded fields with the same name
#
sub my_xml_read_simple{
    my %args = (
        XML_HASH=>undef,   # reference to xml hash
        LABEL=>undef,      # use this attr as key into xml hash
        XML_STRING=>undef, # input reference to xml string
        @_,
        );
    my $args_valid = "LABEL|XML_HASH|XML_STRING";
    my(
        $arg,
        $attr,
        $attr_name,
        %attr_hash,
        $broken,
        $done,
        $done1,
        $field,
        $field_name,
        $field_name_use,
        @field_names,
        $ierr,
        $key,
        @keys,
        $label,
        $num,
        $quote,
        $val,
        $xml_hash_ref,
        $xml_new_ref,
        $xml_string_ref,
        );

    # args
    foreach $arg ( keys %args ){
        if( $arg !~ /^(${args_valid})$/ ){
            $ierr = 1;
            &print_error( "Invalid argument [$arg]",
                          "Valid args [$args_valid]",
                          $ierr );
            exit( $ierr );
        }
    }

    $xml_hash_ref   = $args{XML_HASH};
    $xml_string_ref = $args{XML_STRING};
    $label          = $args{LABEL};

    undef( $done );
    # while stuff in string
    while( ! defined($done) ){

        # no more output
        if( $$xml_string_ref !~ /\S/ ){
            $done = "";
            last;
        }

        # if ending this level
        if( $$xml_string_ref =~ /^\s*<\// ){
            $done = "";
            last;
        }

        # new field at this level
        if( $$xml_string_ref =~ /^\s*<([^\s>]+)/ ){
            # field_name
            $field_name = $1;
            # pull out all of field
            # NOTE: this breaks if you have a sub field with the same name as the parent
            # NOTE: or confusing things inside a quote
            $$xml_string_ref =~ s/^(\s*<${field_name}\s*((.|\s)*?)\s*<\/${field_name}>)//;
            # strip off field start/stop
            $field = $2;
            # broken: if there is not end field string, just have the rest of it be the field
            # This can happen if the xml string is broken and only have the first part
            # of it.
            if( ! defined($field) ){
                $broken = "";
                ($field = $$xml_string_ref) =~ s/^(\s*<${field_name})//;
                $$xml_string_ref = "";
            }

            # init to in attr
            # set to being in attr until definitely not in it
            $attr = "";
            undef( %attr_hash );

            # while still stuff in field
            undef( $done1 );
            while( ! defined($done1) ){

                # if still in attr
                if( defined($attr) ){

                    # attr=val
                    if( $field =~ /^\s*([^=>]+?)\s*=\s*((.|\s)*)/ ){
                        $attr_name = $1;
                        # consume attr name from field
                        $field = $2;
                        # see if surrounded in quotes
                        undef( $quote );
                        if( $field =~ /^("|')/ ){
                            $quote = $1;
                        }
                        # consume attr value from field
                        if( defined($quote) ){
                            $field =~ s/^\s*${quote}//;
                            if( $field =~ /^(.*?)${quote}/ ){
                                $val   = $1;
                                $field =~ s/^.*?${quote}//;
                            }
                            # broken: no end quote
                            else{
                                $broken = "";
                                $val    = $field;
                                $field  = "";
                            }
                        }
                        else{
                            $field =~ s/^\s*([^\s>]+)\s*//;
                            $val = $1;
                        }
                        $attr_hash{$attr_name} = $val;
                    }

                    # end of attr

                    # normal: field might start with > so end of attrs
                    if( $field =~ /^\s*>/ ){
                        undef( $attr );
                        $field =~ s/^\s*>//;
                    }

                    # broken: strange attribute (no equal sign) ... ignore
                    elsif( $field =~ /^([^=>]*)\s*>/ ){
                        $broken = "";
                        $field  =~ s/^([^=>]*)\s*>//;
                        undef( $attr );
                    }

                    # broken: no equal sign or end >
                    elsif( $field =~ /^[^=>]*$/ ){
                        $broken = "";
                        $field  = "";
                        undef( $attr );
                    }

                    # regardless, start field processing again to consume more attrs if any
                    next;
                }

                # get field_name = name of entry point into xml hash
                # use label if set
                undef( $field_name_use );
                if( ! defined($field_name_use) ){
                    if( defined( $label ) ){
                        if( defined($attr_hash{$label}) ){
                            $field_name_use = $attr_hash{$label};
                        }
                    }
                }

                # if still not set, just use count of other labels
                if( ! defined($field_name_use) ){
                    @keys = keys %{$xml_hash_ref};
                    @field_names = grep( /^${field_name}/, @keys );
                    $num = $#field_names + 1;
                    $field_name_use = "${field_name}___$num";
                }

                # register this field (in case no attrs or sub fields)
                undef( $$xml_hash_ref{$field_name_use} );

                # have attributes now - stuff into xml hash
                foreach $key ( keys %attr_hash ){
                    $$xml_hash_ref{$field_name_use}{attrs}{$key} = $attr_hash{$key};
                }

                # end marker
                # recursive call using xml{$field_name}{fields}
                if( $field =~ /^\s*</ ){
                    # sub-field: recursive call
                    if( $field =~ /^\s*<[^\/]/ ){
                        $xml_new_ref = \%{$$xml_hash_ref{$field_name_use}{fields}};
                        # no LABEL
                        &my_xml_read_simple(XML_HASH=>$xml_new_ref, XML_STRING=>\$field );
                    }
                    else{
                        $broken = "";
                        $field  = "";
                    }
                }

                # value of this field
                if( $field =~ /^\s*([^<])/ ){
                    $quote = $1;
                    if( $quote =~ /['"]/ ){
                        $field =~ s/^\s*${quote}([^${quote}]*?)${quote}\s*//;
                        $val = $1;
                        # broken: no end quote
                        if( ! defined( $val ) ){
                            $broken = "";
                            $field  =~ s/^\s*${quote}//;
                            $val = $field;
                            $field = "";
                        }
                    }
                    else{
                        $field =~ s/^\s*([^<>]*)\s*//;
                        $val = $1;
                    }
                    $$xml_hash_ref{$field_name_use}{val} = $val;
                }

                # no more left in field
                if( $field !~ /\S/ ){
                    $done1 = "";
                }

                # mark if broken
                if( defined( $broken ) ){
                    $$xml_hash_ref{$field_name_use}{broken} = "";
                    undef( $broken );
                }

            } # done1: while still stuff in field
        } # new field at this level

        # broken: stuff there but not a field
        else{
            $$xml_hash_ref{broken} = "";
            $$xml_string_ref = "";            
        }

    } # done: while stuff in string

}

#............................................................................
#...Name
#...====
#... conv_time
#...
#...Purpose
#...=======
#... Converts different time formats into consistent fields:
#...   dates:      eg: some date string
#...   time units: eg: some number of hours, min, secs
#...
#...hash format
#...===========
#...  Input (may be blank):
#...    SECS, MINS, HOURS, DAYS, YEARS
#...    STRING: colon separated list of values (might start with an A)
#...      Special strings:
#...        YMDHMS <recognized date string>
#...           Can have "." between fields...so do not need all digits.
#...           Can have <yyyy> be "Y" and will try to determine "Y".
#...           The seconds field is supposed to be [0-60).  If given 60
#...           (due to rounding or something), it will set it to 0 and
#...           bump up minutes (and bump up hours if needed...and so on).
#...        A<time unit spec>
#...      If not "YMDHMS...", will determine from format if date or not.
#...    RESET reset the previous data for trying to determine correct year.
#...
#...  If given a YMDHMS string, SECS_TOTAL will be epoch seconds.
#...
#...  Output:
#...    Above Input filled out (except for STRING)
#...    SECS_TOTAL, 
#...    string
#...    string_b
#...    hms
#...
#............................................................................
sub conv_time {
  my %args = (
              SECS=>   0,
              MINS=>   0,
              HOURS=>  0,
              DAYS=>   0,
              YEARS=>  0,
              STRING=> "",
              RESET=>undef,
              @_,
             );
  my(
      $date_given,
      @dates,
      $day,
      $day_try,
      $done,
      $extra,
      $factor,
      $hours,
      $ierr,
      $inc,
      %num_secs,
      $out,
      $rest,
      $secs_decimal,
      $secs_now,
      $secs_try,
      %size,
      $time,
      @time_fields,
      $type,
      %types,
      $unit,
      %unit_next,
      $val_new,
      $val,
      @vals,
      $when,
      $year,
      $year_now,
      $year_try,
      );
  # some constants
  $size{SECS}  = 60;
  $size{MINS}  = 60;
  $size{HOURS} = 24;
  $size{DAYS}  = 365;
  $unit_next{SECS}  = "MINS";
  $unit_next{MINS}  = "HOURS";
  $unit_next{HOURS} = "DAYS";
  $unit_next{DAYS}  = "YEARS";
  $unit_next{YEARS} = "UNKNOWN";
  $num_secs{SECS}  = 1;
  $num_secs{MINS}  = 60;
  $num_secs{HOURS} = 60*$num_secs{MINS};
  $num_secs{DAYS}  = 24*$num_secs{HOURS};
  $num_secs{YEARS} = 365*$num_secs{DAYS};

  # if dealing with secs_decimal
  $secs_decimal = 0;

  # do not use the previously found data to find year
  if( defined( $args{RESET} )){
    undef( %CONV_TIME_HASH );
  }

  # parse a STRING time
  if( defined($args{STRING}) && $args{STRING} =~ /\S/ ){

      # will be modifying this as needed for future pasring
      $val_new = $args{STRING};
      $val_new =~ s/^\s+//;
      $val_new =~ s/\s+$//;
      $args{STRING} = $val_new;

      # init these to 0
      # For a "date" type field, SECS will be set to epoch_secs
      # and then set in SECS_TOTAL.
      $args{YEARS} = 0;
      $args{DAYS}  = 0;
      $args{HOURS} = 0;
      $args{MINS}  = 0;
      $args{SECS}  = 0;
      $types{y} = "YEARS";
      $types{d} = "DAYS";
      $types{h} = "HOURS";
      $types{m} = "MINS";
      $types{s} = "SECS";

      # -----------------------
      # PREPROCESS YMDHMS field
      # -----------------------

      # PREPROCESS to YMDHMS field
      # <day of week> <rest of date string> <possible year>
      #   Wed Sep 29 11:56:31 (possible year)
      # This is for llnl lsf where their dates for submission/run time
      # does not have the year in it (for whatever annoying reason).
      # So, have to guess the year.
      # Odds are that the:
      #   DayName Month DayOfMonth
      # will return the correct year since the day will match current
      # year or next year.
      # Issue is if it does not match.  If so, just assume it is
      # multi-years in the past (since likely will not be returning
      # some "launch date" that is a couple of years in the future).
      #   PAST -   if mismatch current year, search in PAST (default)
      #   FUTURE - if mismatch current year, search in FUTURE
      #
      # After finding year, will set to YYYY.MM.DD...and continue parsing.
      if( $val_new =~ /^((PAST|FUTURE)\s+)?(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s+(.*?)\s*$/ ){
          $when = $2 || "PAST";
          $day  = $3;
          $rest = $4;
          # has year - use that year regardless
          if( $rest =~ /\s\d{4}/ ){
              $val_new = `date -d "$day $rest" +%Y.%m.%d.%H.%M.%S`;
          }
          
          # does not have year...look for matching day
          else{
              
              $out = `date -d "$rest" +%Y.%a 2> /dev/null`;
              chomp( $out );
              if( $out !~ /^\d{4}\.(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$/ ){
                  $ierr = 1;
                  &print_error( "Could not parse date: [$val_new]",
                                $ierr );
                  exit( $ierr );
              }
              ( $year_now, $day_try ) = split( /\./, $out );
              
              # Likely this is a match - use it regardless.
              # This will catch anything of this year and a date
              # that was looking for next year.
              # This will catch 
              if( "$day" eq "$day_try" ){
                  $val_new = `date -d "$day $rest" +%Y.%m.%d.%H.%M.%S`;
              }
              # current year did not match
              else{
                  # due to leap-day, just go until hit day
                  undef( $done );
                  $year_try = $year_now;
                  if( $when eq "PAST" ){
                      $inc = -1;
                  }
                  else{
                      $inc = 1;
                  }
                  while( ! defined( $done ) ){
                      $year_try = $year_try + $inc;
                      $out = `date -d "$rest $year_try" +%a 2> /dev/null`;
                      chomp( $out );
                      if( $out eq $day ){
                          last;
                      }
                      # might have been given DST MDT PDT ... and it will
                      # never hit correct year.
                      if( abs($year_now - $year_try) > 20 ){
                          $year_try = $year_now;
                          $rest =~ s/[a-zA-Z]+\s*$//;
                      }
                  }
                  $val_new = `date -d "$day $rest $year_try" +%Y.%m.%d.%H.%M.%S`; 
              } # current year did not match
          } # does not have year...look for matching day

          # now in correct form, prepend with YMDHMS, and continue
          $val_new = "YMDHMS $val_new";

      } # <day of week> <rest of date string>

      # HH:MM:SS-M{1,2}/D{1-2}
      # prepend with YMDHMS and continue to next preprocess
      if( $val_new =~ /^(\d+):(\d+):(\d+)-(\d+)\/(\d+)$/ ){
          $val_new = "YMDHMS $val_new";
      }

      # YYYY.DD.MM.HH.MM.SS(.frac_secs_optional)
      # correct form, but missing YMDHMS - prepend it
      if( $val_new =~ /^(\d{4})\.(\d{2})\.(\d{2})\.(\d{2})\.(\d{2})\.(\d{2})(.\s+)?$/ ){
          $val_new = "YMDHMS $val_new";
      }

      # PREPROCESS to YMDHMS field
      # pull out fractional seconds and store it
      # YYYYMMDD:HHMMSS(optional fractional second)
      if( $val_new =~ /^\s*YMDHMS (\S+)/ ){
          $val_new = $1;

          # HH:MM:SS-M{1,2}/D{1-2}
          if( $val_new =~ /^(\d+):(\d+):(\d+)-(\d+)\/(\d+)$/ ){
            $val_new = sprintf("Y.%02d.%02d.%02d.%02d.%02d", $4, $5, $1, $2, $3);
          }

          # MMDD:HHMMSS
          if( $val_new =~ /^(\S{2})(\S{2}):(\S{2})(\S{2})(\S{2})(\.\S+)?$/ ){
              $val_new = "Y.$1.$2.$3.$4.$5";
              if( defined( $6 ) ){
                  $val_new .= "$6";
              }
          }

          # YYYYMMDD:HHMMSS(.<fractional>)
          if( $val_new =~ /^(\d{4}\d{2}\d{2}):(\d{2}\d{2}\d{2})(\.\d+)?/ ){
              $val_new = "$1$2";
              if( defined($3) ){
                  $secs_decimal = $3;
              }
          }

          # replace 1 digit with 0 padded 2 digits
          if( $val_new =~ /\./ ){
              @time_fields = split( /\./, $val_new);
              # if given decimal, pull it out
              if( $#time_fields == 6 ){
                  $secs_decimal = ".".pop( @time_fields );
              }
              if( $time_fields[0] eq "Y" ){
                  $year = shift( @time_fields );
              }
              else{
                  $year = "";
              }
              @time_fields = grep( $_ = sprintf("%02d", $_), @time_fields );
              $val_new = join(".", @time_fields);
              if( $year eq "Y" ){
                  $val_new = "$year.$val_new";
              }
          }

          # prepend with YMDHMS since in correct form and continue parsing
          $val_new = "YMDHMS $val_new";

      }
      # --------------------------------
      # DONE: PREPROCESS to YMDHMS field
      # --------------------------------

      # Now that $val_new is of correct YMDHMS format (if needed),
      # process string.

      # if given a date, assume given the epoch seconds
      #   YYYYMMDDHHMMSS
      if( $val_new =~ /^YMDHMS (\d{4})\.?(\d{2})\.?(\d{2})\.?(\d{2})\.?(\d{2})\.?(\d{2})$/ ){
          $date_given = "";
          # 0 based: month...which is not what date returns - so convert
          @time_fields = ($1,$2-1,$3,$4,$5,$6);
          &time_fields_nudge( \@time_fields );
          $args{SECS}  = timelocal( reverse @time_fields );
          if( $args{SECS} !~ /^\d+$/ ){
              $args{SECS}  = 0;
          }
          # tack on secs_decimal
          $args{SECS} += $secs_decimal;
      }

      # Date with missing year.
      # Will use CONV_TIME_HASH
      #   "Y"MMDDHHMMSS
      elsif( $val_new =~ /^YMDHMS (Y)\.?(\d{2})\.?(\d{2})\.?(\d{2})\.?(\d{2})\.?(\d{2})$/ ){
          $date_given = "";
          $args{date_dot}  = "$1.$2.$3.$4.$5.$6";
          # 0 based: month...which is not what date returns - so convert
          @time_fields = ($1,$2-1,$3,$4,$5,$6);

          # use any previous year given
          if( defined($CONV_TIME_HASH{date_year}) ){
              $time_fields[0] = $CONV_TIME_HASH{date_year};
              &time_fields_nudge( \@time_fields );

              # When given 2 digit year, use any previously found year as guess.
              # If this results in a previous time, then this is likely
              # crossing a new year and adjust year up.
              # (assuming that times are likely given in increasing order)
              $secs_now = $CONV_TIME_HASH{SECS_TOTAL};
              $secs_try = timelocal( reverse @time_fields );
              # add a day since @time_fields does not have timezone info so <1 day off
              if( $secs_try + 24*3600 < $secs_now ){
                  $time_fields[0]++;
              }
          }

          # otherwise, use current year
          else{

              $year = (localtime)[5];
              # some give 3 digits
              if( length($year) <= 3 ){
                  $year += 1900;
              }
              
              # first try this year, and subtract one if this would be in the future
              $time_fields[0] = $year;
              &time_fields_nudge( \@time_fields );
              $secs_try = timelocal( reverse @time_fields );
              $secs_now = time();
              # add a day since @time_fields does not have timezone info so <1 day off
              if( $secs_now + 24*3600 < $secs_try ){
                  $time_fields[0]--;
              }
          }

          # now we know date_year
          $args{SECS}      = timelocal( reverse @time_fields );
          if( $args{SECS} !~ /^\d+$/ ){
              $args{SECS}  = 0;
          }
          # tack on secs_decimal
          $args{SECS} += $secs_decimal;

      }

      # S, M:S, H:M:S, D:H:M:S, Y:D:H:M:S
      elsif( $val_new =~ /^A(.*)$/ ){
          $val_new = $1;
          $val_new =~ s/-/:/;
          @vals = split(":",$val_new);
          $unit = "SECS";
          foreach $val ( reverse @vals ){
              $args{$unit} = $val;
              $unit = $unit_next{$unit};
          }
      }

      # if just given one digit, it is in minutes
      elsif( $val_new =~ /^\s*(\d+)\s*$/ ){
          $args{MINS} = $1;
      }

      # H:, H:M, H:M:S, D:H:M:S, Y:D:H:M:S
      elsif( $val_new =~ /^\s*\d+\s*:/ ){
          $val_new =~ s/\s+//g;
          @vals = split(":",$val_new);
          if( $#vals <= 2 ){
              unshift( @vals,0,0);
          }
          elsif( $#vals == 3 ){
              unshift( @vals, 0 );
          }
          ($args{YEARS},$args{DAYS},$args{HOURS},$args{MINS},$args{SECS}) = @vals;
      }

      # D-H(:M(:S))
      elsif( $val_new =~ /\s*(\d+)-(\d+(:\d+)*)\s*$/ ){
          $args{DAYS} = $1;
          $val = $2;
          @vals = split(":", $val );
          ($args{HOURS},$args{MINS},$args{SECS}) = @vals;
      }

      # YYYY-MM-DDTHH:MM:SS
      # does not pin string to beginning of line so matches if or not
      # YMDHMS
      elsif( $val_new =~ /((\d{4})\-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2}))/ ){
          $val = $1;
          @time_fields = split( /[^\d]+/, $val );
          $time_fields[1]--;
          @dates = reverse @time_fields;
          $args{SECS} = timelocal(@dates);
      }

      # ydhms (with weeks and months)
      #   4y 3m 1.2Day8s
      # This is NOT a date.
      else{
          while( $val_new =~ /\S/ ){
              if( $val_new =~ /^\s*(\d+(\.\d+)?)\s*(y|w|d|h|m|s)([a-z]*)\s*:?\s*(.*?)$/i ){
                  $val_new = $5;
                  $time = $1;
                  $type = $3;
                  $extra = $4;
                  if( ! defined($extra) ){
                      $extra = "";
                  }
                  $type =~ tr/A-Z/a-z/;
                  $extra =~ tr/A-Z/a-z/;
                  $extra = "${type}${extra}";
                  if( $extra =~ /^week/ ){
                      $type = "d";
                      $time *= 7;
                  }
                  if( $extra =~ /^month/ ){
                      $type = "d";
                      $time *= 31;
                  }
                  
                  $args{$types{$type}} = $time;
              }
              else{
                  $ierr = 1;
                  &print_error( "Unrecognized time format [$args{STRING}]",
                                $ierr );
                  exit( $ierr );
              }
          }
      }
  }

  # convert to total number of seconds
  $args{SECS_TOTAL} = 0;
  foreach $unit ( "SECS", "MINS", "HOURS", "DAYS", "YEARS" ) {
      if( ! defined($args{$unit}) || $args{$unit} !~ /\d/ ){
          $args{$unit} = 0;
      }
  }
  foreach $unit ( "SECS", "MINS", "HOURS", "DAYS", "YEARS" ) {
    $args{SECS_TOTAL} += $num_secs{$unit} * $args{$unit};
  }
  # put into units
  foreach $unit ( "SECS", "MINS", "HOURS", "DAYS", "YEARS" ) {
      $args{$unit} = 0;
  }
  $args{SECS} = abs($args{SECS_TOTAL});
  foreach $unit ( "SECS", "MINS", "HOURS", "DAYS" ) {
      if( $args{$unit} >= $size{$unit} ){
          $factor = int($args{$unit} / $size{$unit});
          $args{$unit_next{$unit}} += $factor;
          $args{$unit} -= $factor * $size{$unit};
      }
  }

  # string
  $args{string} = "";
  foreach $unit ( "YEARS", "DAYS", "HOURS", "MINS" ) {
    if( $args{$unit} > 0 ) {
      $args{string} .= " $args{$unit} $unit";
    }
  }
  if( $args{SECS} > 0 )
    {
      $args{string} .= sprintf( " %.2f", $args{SECS})." SECS";
    }
  if( $args{string} eq "" )
    {
      $args{string} = " 0 SECS";
    }
  $args{string} =~ s/^\s+//;

  # condensed string
  $args{string_b} = "0_SECS";
  foreach $unit ( "YEARS", "DAYS", "HOURS", "MINS", "SECS" ) {
      if( $args{$unit} > 0 ){
          $args{string_b} = "$args{$unit}_$unit";
          last;
      }
  }
  
  # h:m:s
  $hours = $args{YEARS}*$size{DAYS}*$size{HOURS} + $args{DAYS}*$size{HOURS} + $args{HOURS};
  $args{hms} = sprintf( "%d:%02d:%02d", $hours, $args{MINS}, $args{SECS} );

  # fill some things if time_fields is defined
  if( @time_fields ){
      # make month 1 based again
      $time_fields[1]++;
      # 0-pad fields
      @time_fields = grep( $_ = sprintf("%02d", $_), @time_fields );
      $args{date_year}   = $time_fields[0];
      $args{date_dot}    = join(".", @time_fields );
      $args{date_single} = join("",  @time_fields );
      if( $secs_decimal ne "0" ){
          $args{date_dot}    .= $secs_decimal;
          $args{date_single} .= $secs_decimal;
      }
  }
  
  # store in global var if given a date
  # This is used for determining year if diven date w/out (full) year.
  if( defined( $date_given ) ){
      %CONV_TIME_HASH = %args;
  }

  return( %args );
}

# deal with time_fields being 60 (increment previous vals --> 0..59)
sub time_fields_nudge{
    my(
        $time_fields,
        ) = @_;
    my(
        $secs,
        );
    
    if( $$time_fields[5] == 60 ){
        $$time_fields[5] = 59;
        $secs = timelocal( reverse @$time_fields );
        @$time_fields = reverse( (localtime($secs+1))[0..5] );
        if( length($$time_fields[0]) <= 3 ){
            $$time_fields[0] += 1900;
        }
    }
}


####################################################################3

sub latexify{
    my( $string_in ) = @_;
    my( $string );
    $string = $string_in;
    # was needed to get underscores to be underscores...but not needed with the packages:
    # \usepackage{textcomp}
    # \usepackage[T1]{fontenc}
    # does not work since used in args for other commands $string =~ s/_/\\verb1_1/g;
    # $string =~ s/_/\\url{_}/g;
    $string =~ s/_/\\_/g;
    $string =~ s/&/\\&/g;
    $string =~ s/^(\s*<br>\s*)+//mgi;
    $string =~ s/<br>/\\newline /gi;
    $string =~ s/<\/?cfoutput>//gi;
    $string =~ s/</\$<\$/g;
    $string =~ s/>/\$>\$/g;
    $string =~ s/\^/\*\*/g;
    $string =~ s/\#/number/g;
    $string =~ s/\036/-/g;
    $string =~ s/\010/ /g;
    # specific hacks
    $string =~ s/\}( typical energy)/$1/;
    $string =~ s/(matdef)\{/$1/;
    $string =~ s/(thres)\}/$1/;
    return( $string );
}
#...return true
1;
