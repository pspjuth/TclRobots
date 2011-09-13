#****F* tclrobots/file_header
#
# NAME
#
#   tclrobots.tcl
#
# DESCRIPTION
#
#   This is the main file of TclRobots. It sources gui.tcl if GUI is
#   requested, but can be used stand-alone.
#
#   The authors are Jonas Ferry, Peter Spjuth and Martin Lindskog, based
#   on TclRobots 2.0 by Tom Poindexter.
#
#   See http://tclrobots.org for more information.
#
# COPYRIGHT
#
#   Jonas Ferry (jonas.ferry@tclrobots.org), 2010. Licensed under the
#   Simplified BSD License. See LICENSE file for details.
#
#******

#******
# CODING STANDARD
#
# In no particular order:
#
#  * Minimize the number of global variables. The default global
#    variables are argv, data, game and parms.
#
#  * The global keyword is preferred over the :: notation. List global
#    variables in alphabetical order. See proc main for an example.
#
#
#******

#****P* tclrobots/main
#
# NAME
#
#   main
#
# DESCRIPTION
#
#   The main proc is run at program startup.
#
# SOURCE
#
proc main {} {
    global allRobots argv data game gui nomsg os tcl_platform \
	thisDir thisScript version

    # Provide package name for starpack build, see Makefile
    package provide app-tclrobots 1.0

    namespace import ::tcl::mathop::*
    namespace import ::tcl::mathfunc::*

    set thisScript [file join [pwd] [info script]]
    set thisDir [file dirname $thisScript]

    # Check current operating system
    if {$tcl_platform(platform) eq "windows"} {
	set os "windows"
	create_display
    } elseif {$tcl_platform(os) eq "Darwin"} {
	set os "mac"
    } else {
	set os "linux"
    }
    set version          "3.0-alpha (2011-09-12)"
    set gui              0
    set nomsg            0
    set game(debug)      0
    set game(max_ticks)  6000
    set game(robotfiles) {}
    set game(tourn_type) 0
    set game(outfile)    ""
    set game(loglevel)   1
    set game(simulator)  0
    set game(state)      ""
    set game(numbattle)  1
    set game(winner)     {}

    set len [llength $argv]
    for {set i 0} {$i < $len} {incr i} {
        set arg [lindex $argv $i]

        switch -regexp -- $arg  {
            --debug   {set game(debug) 1}
            --gui     {set gui 1}
	    --help    {show_usage; return}
            --nomsg   {set nomsg 1}
            --n       {incr i; set game(numbattle) [lindex $argv $i]}
            --o       {incr i; set game(outfile) $arg}
            --seed    {incr i; set game(seed_arg) [lindex $argv $i]}
            --t.*     {set game(tourn_type) 1}
            --version {display "TclRobots $version"; return}
            default {
                if {[file isfile [pwd]/$arg]} {
                    lappend game(robotfiles) [pwd]/$arg
                } else {
                    display "'$arg' not found, skipping"
                }
            }
        }
    }
    if {[llength $game(robotfiles)] >= 2 && !$gui} {
        if {$game(tourn_type) == 0} {
            # Run single battle in terminal
	    if {$game(numbattle) == 1} {
		display "\nSingle battle started\n"
	    } else {
		display "\nSingle battles started\n"
	    }
            set running_time [/ [lindex [time {
		while {$game(numbattle) > 0} {
		    init_game
		    init_match 
		    run_game
		    set game(state) ""
		    incr game(numbattle) -1
		}
	    }] 0] 1000000.0]
            display "seed: $game(seed)"
            display "time: $running_time seconds"
	    if {$game(numbattle) == 1} {
		display "\nSingle battle finished\n"
	    } else {
		display "\nSingle battles finished\n"
		foreach robot $allRobots {
		    set count 0
		    foreach winner $game(winner) {
			if {$data($robot,name) eq $winner} {
			    incr count
			}
		    }
		    lappend winnerList "$count $data($robot,name)"
		}
		foreach item [lsort -index 0 -decreasing $winnerList] {
		    display $item
		}
		# Newline for pretty output
		display ""
	    }
        } else {
            # Run tournament in terminal
            display "\nTournament started\n"
            source $thisDir/tournament.tcl
            set running_time [/ [lindex [time {init_tourn;run_tourn}] 0] \
                                  1000000.0]
            display "seed: $game(seed)"
            display "time: $running_time seconds\n"
            display "Tournament finished\n"
        }
    } else {
        # Run GUI
        set gui 1
        source $thisDir/gui.tcl
        init_gui
    }
}
#******

#****P* main/create_display
#
# NAME
#
#   create_display
#
# DESCRIPTION
#
#   Windows has no standard output, so a special text box is created
#   to display game text messages.
#
# SOURCE
#
proc create_display {} {
    global display_t

    package require Tk

    grid columnconfigure . 0 -weight 1 
    grid rowconfigure    . 0 -weight 1

    # Create display text area
    set display_t [tk::text .t -width 80 -height 30 -wrap word \
		       -yscrollcommand ".s set"]

    # Create scrollbar for display window
    set display_s [ttk::scrollbar .s -command ".t yview" \
		       -orient vertical]
    # Grid the text box and scrollbar
    grid $display_t -column 0 -row 1 -sticky nsew
    grid $display_s -column 1 -row 1 -sticky ns
}
#******

#****P* main/show_usage
#
# NAME
#
#   show_usage
#
# DESCRIPTION
#
#   Shows command-line arguments.
#
# SOURCE
#
proc show_usage {} {
    global version

    display "
TclRobots $version

Command-line arguments (in any order):

--debug     : Enable debug messages and lowered health for quicker battles.
--gui       : Use GUI; useful in combination with robot files.
--help      : Show this help.
--msg       : Disable robot messages.
--n <N>     : Run N number of battles.
--o <FILE>  : Set results output file.
--seed <S>  : Start with random seed S to replay a specific battle.
--t*        : Run tournament in batch mode.
--version   : Show version and exit.
<robot.tr> : Add one ore more robot files.
"
}
#******

#****P* main/init_game
#
# NAME
#
#   init_game
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc init_game {} {
    global finish robmsg_out tick

    set finish ""
    set robmsg_out ""
    set tick 0
	
    init_parms
    init_trig_tables
    init_rand
    init_files
}
#******

#****P* main/init_match
#
# NAME
#
#   init_match
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc init_match {} {
    init_robots
    init_interps
}
#******

#****P* init/init_parms
#
# NAME
#
#   init_parms
#

# DESCRIPTION
#
#   Set general TclRobots environment parameters.
#
# SOURCE
#
proc init_parms {} {
    global game gui parms

    # milliseconds per tick
    if {$gui} {
        set parms(tick) 100
    } else {
        set parms(tick) 0
    }
    # meters of possible error on scan resolution
    set parms(errdist) 10
    # distance traveled at 100% per tick
    set parms(sp) 10
    # accel/deaccel speed per tick as % speed
    set parms(accel) 10
    # maximum range for a missile
    set parms(mismax) 700
    # distance missiles travel per tick
    set parms(msp) 100
    # missile reload time in ticks
    set parms(mreload) [round [+ [/ $parms(mismax) $parms(msp)] 0.5]]
    # missile long reload time after clip
    set parms(lreload) [* $parms(mreload) 3]
    # number of missiles per clip
    set parms(clip)	4
    # max turn speed < 25 deg. delta
    set parms(turn,0) 100
    #  "   "     "   " 50  "     "
    set parms(turn,1) 50
    #  "   "     "   " 75  "     "
    set parms(turn,2) 30
    #  "   "     "   > 75  "     "
    set parms(turn,3) 20
    # max rate of turn per tick at speed < 25
    set parms(rate,0) 90
    #  "   "   "   "    "   "   "    "   " 50
    set parms(rate,1) 60
    #  "   "   "   "    "   "   "    "   " 75
    set parms(rate,2) 40
    #  "   "   "   "    "   "   "    "   > 75
    set parms(rate,3) 30
    #  "   "   "   "    "   "   "    "   > 75
    set parms(rate,4) 20
    # robot start health
    if {$game(debug)} {
        # Debug health for quick matches
        set parms(health) 1
    } else {
        # Normal health
        set parms(health) 100
    }
    # diameter of direct missile damage
    set parms(dia0) 6
    #     "    "  maximum   "      "
    set parms(dia1) 10
    #     "    "  medium    "      "
    set parms(dia2) 20
    #     "    "  minimum   "      "
    set parms(dia3) 40
    # damage within range 0
    set parms(hit0) -25
    #    "       "     "   1
    set parms(hit1) -12
    #    "       "     "   2
    set parms(hit2) -7
    #    "       "     "   3
    set parms(hit3) -3
    #    "    from collision into wall
    set parms(coll) -5
    # speed when heat builds
    set parms(heatsp) 35
    # max heat index, sets speed to heatsp
    set parms(heatmax) 200
    # inverse heating rate (greater hrate=slower)
    set parms(hrate) 10
    # cooling rate per tick, after overheat
    set parms(cooling) -25
    # cannon heating rate per shell
    set parms(canheat) 20
    # cannon cooling rate per tick
    set parms(cancool) -1
    # cannon heat index where scanner is inop
    set parms(scanbad) 35
    # quadrants, can be used to spread out robots at start
    set parms(quads) {{100 100} {600 100} {100 600} {600 600}}
}
#******

#****P* init/init_trig_tables
#
# NAME
#
#   init_trig_tables
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc init_trig_tables {} {
    global c_tab s_tab
    # init sin & cos tables
    set pi  [* 4 [atan 1]]
    set d2r [/ 180 $pi]

    for {set i 0} {$i<360} {incr i} {
        set s_tab($i) [sin [/ $i $d2r]]
        set c_tab($i) [cos [/ $i $d2r]]
    }
}
#******

#****P* init/init_rand
#
# NAME
#
#   init_rand
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc init_rand {} {
    global game

    # Set random seed.
    if {![info exists game(seed_arg)]} {
	set game(seed) [int [* [rand] [clock clicks]]]
    } else {
        set game(seed) $game(seed_arg)
    }
    srand $game(seed)
}
#******

#****P* init/init_files
#
# NAME
#
#   init_files
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc init_files {} {
    global activeRobots allRobots data game 

    set allRobots {}
    array unset data

    # Pick a random element from a list; use this for reading code!
    # lpick list {lindex $list [expr {int(rand()*[llength $list])}]}

    for {set i 0} {$i < [llength $game(robotfiles)]} {incr i} {
        # Give the robots names like r0, r1, etc.
        set robot r$i
        # Update list of robots
        lappend allRobots $robot

        # Read code
        set f [open [lindex $game(robotfiles) $i]]
        set data($robot,code) [read $f]
        close $f

    }
    set allSigs {}
    set file_index 0

    foreach robot $allRobots {
        set name [file tail [lindex $game(robotfiles) $file_index]]

        # Search for duplicate robot names
        foreach used_name [array names data *,name] {
            if {$name eq $data($used_name)} {
		set name "$data($used_name)([+ $file_index 1])"
            }
        }
        incr file_index

        # generate a new unique signature
        set newsig [mrand 65535]
        while {$newsig in $allSigs} {
            set newsig [mrand 65535]
        }
        lappend allSigs $newsig

        # window name = source.file_randnumber
        set data($robot,name) ${name}
        # the rand number as digital signature
        set data($robot,num) $newsig
    }
    # At the start of the game all robots are active
    set activeRobots $allRobots
}
#******

#****P* init/init_robots
#
# NAME
#
#   init_robots
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc init_robots {} {
    global allRobots data parms 

    foreach robot $allRobots {
        set x [mrand 1000]
        set y [mrand 1000]

        #########
        # set robot parms
        #########
        # robot status: 0=not used or dead, 1=running
        set data($robot,status)	1
        # robot current x
        set data($robot,x) $x
        # robot current y
        set data($robot,y) $y
        # robot origin  x since last heading
        set data($robot,orgx) $x
        # robot origin  y   "    "     "
        set data($robot,orgy) $y
        # robot current range on this heading
        set data($robot,range) 0
        # robot current health
        set data($robot,health) $parms(health)
        # robot inflicted damage
        set data($robot,inflicted) 0
        # robot current speed
        set data($robot,speed) 0
        # robot desired   "
        set data($robot,dspeed)	0
        # robot current heading
        set data($robot,hdg) [mrand 360]
        # robot desired   "
        set data($robot,dhdg) $data($robot,hdg)
        # robot direction of turn (+/-)
        set data($robot,dir) +
        # robot last scan dsp signature
        set data($robot,sig) "0 0"
        # missile state: 0=avail, 1=flying
        set data($robot,mstate) 0
        # missile reload time: 0=ok, >0 = reloading
        set data($robot,reload) 0
        # number of missiles used per clip
        set data($robot,mused) 0
        # missile current x
        set data($robot,mx) 0
        # missile current y
        set data($robot,my) 0
        # missile origin  x
        set data($robot,morgx) 0
        # missile origin  y
        set data($robot,morgy) 0
        # missile heading
        set data($robot,mhdg) 0
        # missile current range
        set data($robot,mrange)	0
        # missile target distance
        set data($robot,mdist) 0
        # motor heat index
        set data($robot,heat) 0
        # overheated flag
        set data($robot,hflag) 0
        # alert procedure to call when scanned
        set data($robot,alert) {}
        # signature of last robot to scan us
        set data($robot,ping) {}
        # list of requested timed callbacks
        set data($robot,callbacks) {}
        # declared team
        set data($robot,team) ""
        # last team message sent
        set data($robot,data) ""
        # barrel temp, affected by cannon fire
        set data($robot,btemp) 0
        # request from robot slave interp to master
        # tick -1 is set to {} to handle scanner charging in tick 0
        set data($robot,syscall,-1) {}
        # return value from master to slave interp
        set data($robot,sysreturn,0) {}
    }
}
#******

#****P* init/init_interps
#
# NAME
#
#   init_interps
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc init_interps {} {
    global allRobots data thisDir tick

    set tick 0
    foreach robot $allRobots {
        set data($robot,interp) [interp create -safe]

        # Stop robots from using another rand than the syscall
        $data($robot,interp) eval {rename tcl::mathfunc::rand {}}

        interp alias $data($robot,interp) syscall {} syscall $robot

        $data($robot,interp) invokehidden source $thisDir/syscalls.tcl

        $data($robot,interp) eval coroutine \
                ${robot}Run [list uplevel \#0 $data($robot,code)]

        interp alias {} ${robot}Run $data($robot,interp) ${robot}Run
    }
    act
    tick
}
#******

#****P* main/run_game
#
# NAME
#
#   run_game
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc run_game {} {
    global activeRobots game

    set game(state) "run"
    coroutine run_robotsCo run_robots
    while {$game(state) eq "run" ||
	   $game(state) eq "pause"} {
	vwait game(state)
    }
    if {$game(state) ne "halt"} {
	find_winner
    }
}
#******

#****P* run_game/run_robots
#
# NAME
#
#   run_robots
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc run_robots {} {
    global activeRobots data do_step game gui parms sim_syscall StatusBarMsg \
    step tick timeAt5

    while {$game(state) eq "run" || $game(state) eq "pause"} {
        if {$game(state) ne "pause"} {
            if {$game(simulator)} {
                # Reset health of target
                set data(target,health) [* $parms(health) 10]
            }
            foreach robot $activeRobots {
                if {($data($robot,alert) ne {}) && \
                        ($data($robot,ping) ne {})} {
                    # Prepend alert data to sysreturn no notify robot it's
                    # been scanned.
                    set data($robot,sysreturn,[- $tick 1]) \
                        "alert $data($robot,alert) $data($robot,ping) $data($robot,sysreturn,[- $tick 1])"

                    # Robot is notified; reset alert request
                    set data($robot,ping) {}
                }
                ${robot}Run $data($robot,sysreturn,[- $tick 1])
            }
            act

            # Print extra information in simulator GUI
            if {$game(simulator) &&
                [ne $data(r0,sysreturn,$tick) ""]} {
                set sim_syscall $data(r0,syscall,$tick)
                append sim_syscall " => " $data(r0,sysreturn,$tick)
            }
            update_robots

            if {$gui} {
                update_gui
            }
            tick

            # Check if single step is active in simulator mode
            if {$game(simulator) && $step} {
                vwait do_step
                set do_step 0
            }
            if {$parms(tick) < 5} {
                # Don't bother at high speed
                after $parms(tick) [info coroutine]
            } elseif {$tick <= 5} {
                # Let the first few ticks pass before measuring
                after $parms(tick) [info coroutine]
                set timeAt5 [clock milliseconds]
            } else {
                # Try to measure time, to adjust the tick delay for load
                set target [expr {$parms(tick) * ($tick - 4) + $timeAt5}]
                set delay [expr {$target - [clock milliseconds]}]
                # Sanity check value
                if {$delay > $parms(tick)} {
                    set delay $parms(tick)
                } elseif {$delay < 5} {
                    set delay 5
                }
                after $delay [info coroutine]
                # Keep the lag visible
                set StatusBarMsg "Running $delay"
            }
            yield
        } else {
            # Game is paused, but GUI needs to respond
            update
        }
    }
    rename [info coroutine] ""
    yield
}
#******

#****P* run_robots/act
#
# NAME
#
#   act
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc act {} {
    global activeRobots data tick

    foreach robot $activeRobots {
        if {$data($robot,status)} {
            set currentSyscall $data($robot,syscall,$tick)
            switch [lindex $currentSyscall 0] {
                scanner      {sysScanner     $robot}
                dsp          {sysDsp         $robot}
                alert        {sysAlert       $robot}
                cannon       {sysCannon      $robot}
                drive        {sysDrive       $robot}
                health       -
                speed        -
                heat         -
                loc_x        -
                loc_y        {sysData        $robot}
                tick         {sysTick        $robot}
                team_declare {sysTeamDeclare $robot}
            }
        }
    }
}
#******

#****P* run_robots/update_robots
#
# NAME
#
#   update_robots
#
# DESCRIPTION
#
#   update position of missiles and robots, assess damage
#
# SOURCE
#
proc update_robots {} {
    global allRobots data game

    foreach robot $allRobots {
        # check all flying missiles
        set num_miss [check_missiles $robot]

        # skip rest if robot dead
        if {!$data($robot,status)} {
            continue
        }
        # update missile reloader
        if {$data($robot,reload)} {
            incr data($robot,reload) -1
        }
        # check for barrel overheat, apply cooling
        check_barrel $robot

        # check for excessive speed, increment heat
        check_speed $robot

        # update robot speed, moderated by acceleration
        update_speed $robot

        # update robot heading, moderated by turn rates
        update_heading $robot

        # update distance traveled on this heading
        update_distance $robot

        # check for wall collision
        check_wall $robot
    }
    # check for robot health
    set health_status [check_health]

    set num_rob       [lindex $health_status 0]
    set diffteam      [lindex $health_status 1]
    set num_team      [lindex $health_status 2]

    if {($num_rob<=1 || $num_team==1) && $num_miss==0} {
        # Stop game
        set game(state) "end"
    }
}
#******

#****P* update_robots/check_missiles
#
# NAME
#
#   check_missiles
#
# DESCRIPTION
#
#   check all flying missiles
#
# SOURCE
#
proc check_missiles {robot} {
    global activeRobots data 
    set num_miss 0

    if {$data($robot,mstate)} {
        incr num_miss
        update_missile_location $robot
        # check if missile reached target
        if {$data($robot,mrange) > $data($robot,mdist)} {
            missile_reached_target $robot

            # assign damage to all within explosion ranges
            foreach target $activeRobots {
                if {!$data($target,status)} {
                    continue
                }
                assign_missile_damage $robot $target
            }
        }
    }
    return $num_miss
}
#******

#****P* update_robots/update_missile_location
#
# NAME
#
#   update_missile_location
#
# DESCRIPTION
#
#   update location of missile
#
# SOURCE
#
proc update_missile_location {robot} {
    global c_tab data parms s_tab

    set data($robot,mrange) \
        [+ $data($robot,mrange) $parms(msp)]
    set data($robot,mx) \
        [+ [* $c_tab($data($robot,mhdg)) $data($robot,mrange)] \
             $data($robot,morgx)]
    set data($robot,my) \
        [+ [* $s_tab($data($robot,mhdg)) $data($robot,mrange)] \
             $data($robot,morgy)]
}
#******

#****P* update_robots/missile_reached_target
#
# NAME
#
#   missile_reached_target
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc missile_reached_target {robot} {
    global c_tab data gui s_tab

    set data($robot,mstate) 0
    set data($robot,mx) \
        [+ [* $c_tab($data($robot,mhdg)) $data($robot,mdist)] \
             $data($robot,morgx)]
    set data($robot,my) \
        [+ [* $s_tab($data($robot,mhdg)) $data($robot,mdist)] \
             $data($robot,morgy)]
    if {$gui} {
        after 1 "show_explode $robot"
    }
}
#******

#****P* update_robots/assign_missile_damage
#
# NAME
#
#   assign_missile_damage
#
# DESCRIPTION
#
#   assign damage to all within explosion ranges
#
# SOURCE
#
proc assign_missile_damage {robot target} {
    global data parms

    set d [hypot [- $data($robot,mx) $data($target,x)] \
            [- $data($robot,my) $data($target,y)]]
    if {$d < $parms(dia3)} {
        if {$d < $parms(dia0)} {
            incr data($target,health) $parms(hit0)
            incr data($robot,inflicted) [- $parms(hit0)]
        } elseif {$d<$parms(dia1)} {
            incr data($target,health) $parms(hit1)
            incr data($robot,inflicted) [- $parms(hit1)]
        } elseif {$d<$parms(dia2)} {
            incr data($target,health) $parms(hit2)
            incr data($robot,inflicted) [- $parms(hit2)]
        } else {
            incr data($target,health) $parms(hit3)
            incr data($robot,inflicted) [- $parms(hit3)]
        }
    }
}
#******

#****P* update_robots/check_barrel
#
# NAME
#
#   check_barrel
#
# DESCRIPTION
#
#   check for barrel overheat, apply cooling
#
# SOURCE
#
proc check_barrel {robot} {
    global data parms

    if {$data($robot,btemp)} {
        incr data($robot,btemp) $parms(cancool)
        if {$data($robot,btemp) < 0} {
            set data($robot,btemp) 0
        }
    }
}
#******

#****P* update_robots/check_speed
#
# NAME
#
#   check_speed
#
# DESCRIPTION
#
#   check for excessive speed, increment heat
#
# SOURCE
#
proc check_speed {robot} {
    global data parms

    if {$data($robot,speed) > $parms(heatsp)} {
        incr data($robot,heat) \
            [+ [round [/ [- $data($robot,speed) $parms(heatsp)] \
                           $parms(hrate)]] 1]
        if {$data($robot,heat) >= $parms(heatmax)} {
            set data($robot,heat) $parms(heatmax)
            set data($robot,hflag) 1
            if {$data($robot,dspeed) > $parms(heatsp)} {
                set data($robot,dspeed) $parms(heatsp)
            }
        }
    } else {
        # if overheating, apply cooling rate
        if {$data($robot,hflag) || $data($robot,heat) > 0} {
            incr data($robot,heat) $parms(cooling)
            if {$data($robot,heat) <= 0} {
                set data($robot,hflag) 0
                set data($robot,heat) 0
            }
        }
    }
}
#******

#****P* update_robots/update_speed
#
# NAME
#
#   update_speed
#
# DESCRIPTION
#
#   update robot speed, moderated by acceleration
#
# SOURCE
#
proc update_speed {robot} {
    global data parms

    if {$data($robot,speed) != $data($robot,dspeed)} {
        if {$data($robot,speed) > $data($robot,dspeed)} {
            incr data($robot,speed) -$parms(accel)
            if {$data($robot,speed) < $data($robot,dspeed)} {
                set data($robot,speed) $data($robot,dspeed)
            }
        } else {
            incr data($robot,speed) $parms(accel)
            if {$data($robot,speed) > $data($robot,dspeed)} {
                set data($robot,speed) $data($robot,dspeed)
            }
        }
    }
}
#******

#****P* update_robots/update_heading
#
# NAME
#
#   update_heading
#
# DESCRIPTION
#
#   update robot heading, moderated by turn rates
#
# SOURCE
#
proc update_heading {robot} {
    global data parms

    if {$data($robot,hdg) != $data($robot,dhdg)} {
        set mrate $parms(rate,[int [/ $data($robot,speed) 25]])
        set d1 [% [+ [- $data($robot,dhdg) $data($robot,hdg)]  360] 360]
        set d2 [% [+ [- $data($robot,hdg)  $data($robot,dhdg)] 360] 360]

        if {$d1 < $d2} {
            set d $d1
        } else {
            set d $d2
        }
        if {$d <= $mrate} {
            set data($robot,hdg) $data($robot,dhdg)
        } else {
            set data($robot,hdg) \
                [% [+ [$data($robot,dir) $data($robot,hdg) $mrate] 360] 360]
        }
        set data($robot,orgx)  $data($robot,x)
        set data($robot,orgy)  $data($robot,y)
        set data($robot,range) 0
    }
}
#******

#****P* update_robots/update_distance
#
# NAME
#
#   update_distance
#
# DESCRIPTION
#
#   update distance traveled on this heading
#
# SOURCE
#
proc update_distance {robot} {
    global c_tab data parms s_tab

    if {$data($robot,speed) > 0} {
        set data($robot,range) \
            [+ $data($robot,range) \
                 [/ [* $data($robot,speed) $parms(sp)] 100]]

        # Modify range with random factor to avoid totally
        # deterministic movement. Range is currently +- 1%.
        # Playtesting will tell if this should be lower or higher.
        set randfactor [/ [+ [mrand 100] 1.0] 10000]
        if {[mrand 2] == 0} {
            set randfactor [- $randfactor]
        }
        set data($robot,range) [+ $data($robot,range) \
                                    [* $data($robot,range) \
                                         $randfactor]]

        set data($robot,x) \
            [round [+ [* $c_tab($data($robot,hdg)) $data($robot,range)] \
                         $data($robot,orgx)]]

        set data($robot,y) \
            [round [+ [* $s_tab($data($robot,hdg)) $data($robot,range)] \
                        $data($robot,orgy)]]
    }
}
#******

#****P* update_robots/check_wall
#
# NAME
#
#   check_wall
#
# DESCRIPTION
#
#   check for wall collision
#
# SOURCE
#
proc check_wall {robot} {
    global data parms

    if {$data($robot,speed) > 0} {
        if {($data($robot,x) < 0) || ($data($robot,x) > 999)} {
            if {$data($robot,x) < 0} {
                set data($robot,x) 0
            } else {
                set data($robot,x) 999
            }
            set data($robot,orgx)    $data($robot,x)
            set data($robot,orgy)    $data($robot,y)
            set data($robot,range)   0
            set data($robot,speed)   0
            set data($robot,dspeed)  0
            incr data($robot,health) $parms(coll)
        }
        if {($data($robot,y) < 0) || ($data($robot,y) > 999)} {
            if {$data($robot,y) < 0} {
                set data($robot,y) 0
            } else {
                set data($robot,y) 999
            }
            set data($robot,orgx)    $data($robot,x)
            set data($robot,orgy)    $data($robot,y)
            set data($robot,range)   0
            set data($robot,speed)   0
            set data($robot,dspeed)  0
            incr data($robot,health) $parms(coll)
        }
    }
}
#******

#****P* update_robots/check_health
#
# NAME
#
#   check_health
#
# DESCRIPTION
#
#   check for robot health
#
# SOURCE
#
proc check_health {} {
    global activeRobots data finish gui tick

    set num_rob  0
    set diffteam ""
    set num_team 0
    foreach robot $activeRobots {
        if {$data($robot,status)} {
            if {$data($robot,health) <= 0 } {
                set data($robot,status) 0
                set data($robot,health) 0
                disable_robot $robot
                append finish "$data($robot,name) team($data($robot,team)) dead at tick: $tick\n"
                if {$gui} {
                    after 1 "show_die $robot"
                }
            } else {
                incr num_rob
                if {$data($robot,team) != ""} {
                    if {[lsearch -exact $diffteam $data($robot,team)] == -1} {
                        lappend diffteam $data($robot,team)
                        incr num_team
                    }
                } else {
                    lappend diffteam $data($robot,name)
                    incr num_team
                }
            }
        }
    }
    return [list $num_rob $diffteam $num_team]
}
#******

#****P* check_health/disable_robot
#
# NAME
#
#   disable_robot
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc disable_robot {robot} {
    global activeRobots data tick

    if {[interp exists $data($robot,interp)]} {
        interp delete $data($robot,interp)
        set index [lsearch -exact $activeRobots $robot]
        set activeRobots [lreplace $activeRobots $index $index]
        array unset data $robot
    } else {
        display "disable robot $robot failed; interp does not exist"
    }
}
#******

#****P* run_robots/tick
#
# NAME
#
#   tick
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc tick {} {
    global game tick

    if {$tick < $game(max_ticks)} {
        incr tick
    } else {
        set game(state) "end"
    }
}
#******

#****P* run_game/find_winner
#
# NAME
#
#   find_winner
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc find_winner {} {
    global activeRobots allRobots data finish game robmsg_out win_msg winner 

    set winner ""
    set num_team 0
    set diffteam ""
    set win_color black
    foreach robot $activeRobots {
        lappend winner $data($robot,name)
	lappend game(winner) $data($robot,name)

        if {$data($robot,team) != ""} {
            if {[lsearch -exact $diffteam $data($robot,team)] == -1} {
                lappend diffteam $data($robot,team)
                incr num_team
            }
        } else {
            incr num_team
        }
    }
    # Set winner announcement
    switch [llength $activeRobots] {
        0 {
            set win_msg "No robots left alive"
        }
        1 {
            if {[string length $diffteam] > 0} {
                set diffteam "Team $diffteam"
                set win_msg "WINNER:\n$diffteam\n$winner\n"
            } else {
                set win_msg "WINNER:\n$winner"
            }
        }
        default {
            # check for teams
            if {$num_team == 1} {
                set win_msg "WINNER:\nTeam $diffteam\n$winner"
            } else {
                set win_msg "TIE:\n$winner"
            }
        }
    }
    display "$win_msg\n"
    foreach robot $activeRobots {
        disable_robot $robot
    }
    set score "score: "
    set points 1
    foreach l [split $finish \n] {
        set n [lindex $l 0]
        if {[string length $n] == 0} {continue}
        set l [string last _ $n]
        if {$l > 0} {incr l -1; set n [string range $n 0 $l]}
        append score "$n = $points  "
        incr points
    }
    foreach n $winner {
        set l [string last _ $n]
        if {$l > 0} {incr l -1; set n [string range $n 0 $l]}
        append score "$n = $points  "
    }
    set players "BATTLE:\n"
    foreach robot $allRobots {
        append players "$data($robot,name) "
    }
    # Set up report file message
    set outmsg ""
    append outmsg "$players\n\n"
    append outmsg "$win_msg\n\n"
    if {$finish ne ""} {
        append outmsg "DEFEATED:\n$finish\n"
    }
    append outmsg "SCORE:\n$score\n\n"
    append outmsg "MESSAGES:\n$robmsg_out"

    if {$game(outfile) ne ""} {
        catch {write_file $game(outfile) $outmsg}
    }
}
#******

#****P* tclrobots/write_file
#
# NAME
#
#   write_file
#
# DESCRIPTION
#
#   Writes a string to a file
#
# SOURCE
#
proc write_file {file str} {
    set fd [open $file w]
    display $fd $str
    close $fd
}
#******

#****P* tclrobots/syscall
#
# NAME
#
#   syscall
#
# DESCRIPTION
#
#   Handle syscalls from robots
#
# SOURCE
#
proc syscall {args} {
    global data tick

    set robot [lindex $args 0]
    set result 0

    set syscall [lrange $args 1 end]

    # Handle all immediate syscalls
    switch [lindex $syscall 0] {
        dputs {
            sysDputs $robot [lrange $args 2 end]
        }
        rand {
            set result [mrand [lindex $syscall 1]]
        }
        team_send {
            sysTeamSend $robot [lindex $syscall 1]
        }
        team_get {
            set result [sysTeamGet $robot]
        }
        callback {
            set ticks  [lindex $syscall 1]
            set script [lindex $syscall 2]
            set when [+ $tick $ticks]
            lappend data($robot,callbacks) [list $when $script]
            set data($robot,callbacks) \
                    [lsort -integer -index 0 $data($robot,callbacks)]
        }
        callbackcheck {
            set when [lindex $data($robot,callbacks) 0 0]
            if {$when ne "" && $when <= $tick} {
                set result [lindex $data($robot,callbacks) 0 1]
                set data($robot,callbacks) \
                        [lrange $data($robot,callbacks) 1 end]
            } else {
                set result ""
            }
        }
        default {
            # All postponed syscalls ends up here
            set data($robot,syscall,$tick) $syscall
        }
    }
    return $result
}
#******

#****P* syscall/sysScanner
#
# NAME
#
#   sysScanner
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc sysScanner {robot} {
    global activeRobots data parms tick 

    if {($data($robot,syscall,$tick) eq \
             $data($robot,syscall,[- $tick 1]))} {

        set deg [lindex $data($robot,syscall,$tick) 1]
        set res [lindex $data($robot,syscall,$tick) 2]

        set dsp    0
        set health 0
        set near   9999
        foreach target $activeRobots {
            if {"$target" == "$robot"} {
                continue
            }
            set x [- $data($target,x) $data($robot,x)]
            set y [- $data($target,y) $data($robot,y)]
            set d [round [* 57.2958 [atan2 $y $x]]]

            if {$d < 0} {
                incr d 360
            }
            set d1  [% [+ [- $d $deg] 360] 360]
            set d2  [% [+ [- $deg $d] 360] 360]

            if {$d1 < $d2} {
                set f $d1
            } else {
                set f $d2
            }
            if {$f<=$res} {
                set data($target,ping) $data($robot,num)
                set dist [round [hypot $x $y]]

                if {$dist<$near} {
                    set derr [* $parms(errdist) $res]

                    if {$res > 0} {
                        set terr [+ 5 [mrand $derr]]
                    } else {
                        set terr [+ 0 [mrand $derr]]
                    }
                    if {[mrand 2]} {
                        set fud1 -
                    } else {
                        set fud1 +
                    }
                    if {[mrand 2]} {
                        set fud2 -
                    } else {
                        set fud2 +
                    }
                    set near [$fud1 $dist [$fud2 $terr $data($robot,btemp)]]

                    if {$near < 1} {
                        set near 1
                    }
                    set dsp    $data($robot,num)
                    set health $data($robot,health)
                }
            }
        }
        # if cannon has overheated scanner, report 0
        if {$data($robot,btemp) >= $parms(scanbad)} {
            set data($robot,sig) "0 0"
            set val 0
        } else {
            set data($robot,sig) "$dsp $health"

            if {$near == 9999} {
                set val 0
            } else {
                set val $near
            }
        }
        set data($robot,sysreturn,$tick) $val

    } else {
        set data($robot,sysreturn,$tick) 0
    }
}
#******

#****P* syscall/sysDsp
#
# NAME
#
#   sysDsp
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc sysDsp {robot} {
    global data tick

    set data($robot,sysreturn,$tick) $data($robot,sig)
}
#******

#****P* syscall/sysAlert
#
# NAME
#
#   sysAlert
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc sysAlert {robot} {
    global data tick

    set data($robot,alert) [lindex $data($robot,syscall,$tick) 1]
    set data($robot,sysreturn,$tick) 1
}
#******

#****P* syscall/sysCannon
#
# NAME
#
#   sysCannon
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc sysCannon {robot} {
    global data parms tick

    set deg [lindex $data($robot,syscall,$tick) 1]
    set rng [lindex $data($robot,syscall,$tick) 2]

    set val 0

    if {$data($robot,mstate)} {
        set val 0
    } elseif {$data($robot,reload)} {
        set val 0
    } elseif {[catch {set deg [round $deg]}]} {
        set val -1
    } elseif {[catch {set rng [round $rng]}]} {
        set val -1
    } elseif {($deg < 0) || ($deg > 359)} {
        set val -1
    } elseif {($rng < 0) || ($rng > $parms(mismax))} {
        set val -1
    } else {
        set data($robot,mhdg)   $deg
        set data($robot,mdist)  $rng
        set data($robot,mrange) 0
        set data($robot,mstate) 1
        set data($robot,morgx)  $data($robot,x)
        set data($robot,morgy)  $data($robot,y)
        set data($robot,mx)     $data($robot,x)
        set data($robot,my)     $data($robot,y)
        incr data($robot,btemp) $parms(canheat)
        incr data($robot,mused)
        # set longer reload time if used all missiles in clip
        if {$data($robot,mused) == $parms(clip)} {
            set data($robot,reload) $parms(lreload)
            set data($robot,mused) 0
        } else {
            set data($robot,reload) $parms(mreload)
        }
        set val 1
    }
    set data($robot,sysreturn,$tick) $val
}
#******

#****P* syscall/sysDrive
#
# NAME
#
#   sysDrive
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc sysDrive {robot} {
    global data parms tick

    set deg [lindex $data($robot,syscall,$tick) 1]
    set spd [lindex $data($robot,syscall,$tick) 2]

    set d1  [% [+ [- $data($robot,hdg) $deg] 360] 360]
    set d2  [% [+ [- $deg $data($robot,hdg)] 360] 360]

    if {$d1 < $d2} {
        set d $d1
    } else {
        set d $d2
    }
    set data($robot,dhdg) $deg

    if {$data($robot,hflag) && ($spd > $parms(heatsp))} {
        set data($robot,dspeed) $parms(heatsp)
    } else {
        set data($robot,dspeed) $spd
    }
    # shutdown drive if turning too fast at current speed
    set index [int [/ $d 25]]
    if {$index > 3} {
        set index 3
    }
    if {$data($robot,speed) > $parms(turn,$index)} {
        set data($robot,dspeed) 0
        set data($robot,dhdg)   $data($robot,hdg)
    } else {
        set data($robot,orgx)  $data($robot,x)
        set data($robot,orgy)  $data($robot,y)
        set data($robot,range) 0
    }
    # find direction of turn
    if {($data($robot,hdg)+$d+360)%360==$deg} {
        set data($robot,dir) +
    } else {
        set data($robot,dir) -
    }
    set data($robot,sysreturn,$tick) $data($robot,dspeed)
}
#******

#****P* syscall/sysData
#
# NAME
#
#   sysData
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc sysData {robot} {
    global data tick

    set val 0

    switch $data($robot,syscall,$tick) {
        health {set val $data($robot,health)}
        speed  {set val $data($robot,speed)}
        heat   {set val $data($robot,heat)}
        loc_x  {set val $data($robot,x)}
        loc_y  {set val $data($robot,y)}
    }
    set data($robot,sysreturn,$tick) $val
}
#******

#****P* syscall/sysTick
#
# NAME
#
#   sysTick
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc sysTick {robot} {
    global data tick

    set data($robot,sysreturn,$tick) $tick
}
#******

#****P* syscall/sysTeamDeclare
#
# NAME
#
#   sysTeamDeclare
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc sysTeamDeclare {robot} {
    global data tick

    set team [lindex $data($robot,syscall,$tick) 1]
    set data($robot,team) $team
    set data($robot,sysreturn,$tick) $team
}
#******

#****P* syscall/sysTeamSend
#
# NAME
#
#   sysTeamSend
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc sysTeamSend {robot msg} {
    global data

    display "sysTeamSend $robot $msg"
    set data($robot,data) $msg
}
#******

#****P* syscall/sysTeamGet
#
# NAME
#
#   sysTeamGet
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc sysTeamGet {robot} {
    global data activeRobots tick

    set val ""

    if {$data($robot,team) ne {}} {
        foreach target $activeRobots {
            if {"$robot" eq "$target"} {continue}
            if {"$data($robot,team)" eq "$data($target,team)"} {
                lappend val [list $data($target,num) $data($target,data)]
            }
        }
    }
    if {$val ne {}} {
        display "sysTeamGet $robot $val"
    }
    return $val
}
#******

#****P* syscall/sysDputs
#
# NAME
#
#   sysDputs
#
# DESCRIPTION
#
#   
#
# SOURCE
#
proc sysDputs {robot msg} {
    global data game gui nomsg robmsg_out tick

    if {!$nomsg} {
	set msg [join $msg]

	if {$gui} {
	    # Output to robot message box
	    show_msg $robot $msg
	} else {
	    # Output to terminal
	    display "$data($robot,name): $msg"
	}
	if {$game(outfile) ne ""} {
	    append robmsg_out "$data($robot,name): $msg\n"
	}
    }
}
#******

#****P* tclrobots/mrand
#
# NAME
#
#   mrand
#
# DESCRIPTION
#
#   Return random integer 1-max
#
# SOURCE
#
proc mrand {max} {
    return [int [* [rand] $max]]
}
#******

#****P* tclrobots/display
#
# NAME
#
#   display
#
# DESCRIPTION
#
#   Displays text $msg.
#
# SOURCE
#
proc display {msg} {
    global display_t os

    if {$os eq "windows"} {
	$display_t insert end "$msg\n"
	$display_t see end
	update
    } else {
	puts $msg
    }
}
#******

#****P* tclrobots/debug
#
# NAME
#
#   debug
#
# DESCRIPTION
#
#   Prints debug message. The proc name makes it easy to search for.
#   Precede other debug changes with the word debug in a comment. Note
#   that TclRobots has to be called with the -debug flag for debug
#   messages to display.
#
#   If the first argument to debug is "breakpoint" execution will halt
#   until ::broken is set to 0 e.g. by Tkinspect.
#
#   If the first argument is "exit", debug will print the message and
#   exit TclRobots.
#
#   The name of the procedure that called debug is automatically
#   included in the debug message.
#
# SOURCE
#
proc debug {args} {
    global broken game
   
    if {$game(debug)} {
        # Display name of procedure that called debug
        set caller [lindex [info level [- [info level] 1]] 0]
        if {[lindex $args 0] eq "breakpoint"} {
            set broken 1
            display "Breakpoint reached (dbg: $caller)"
            vwait broken
        } elseif {[lindex $args 0] eq "exit"} {
            # Calling with 'debug exit "msg"' prints the message and then
            # exits. This is useful for "checkpoint" style debugging.
            display "- [join [lrange $args 1 end]] (dbg: $caller)\n"
            exit
        } else {
            display "- [join $args] (dbg: $caller)\n"
        }
    }
}
#******

# All procs are sourced; enter main proc; see top of file.
main