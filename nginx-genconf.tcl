#!/usr/bin/tclsh
# -*- coding: utf-8 -*-

package require snit

namespace eval genconf {
    ::variable scriptName [info script]
}

snit::type genconf {
    option -file rules.tcl
    option -destdir .
    option -stdout no
    option -safe yes
    option -env ""
    option -quiet no
    option -dry-run no

    option -generator "nginx-genconf"

    component myRunner

    variable myTargetList ""
    variable myTargetDict -array {}

    constructor args {

	set safe [from args -safe yes]
	$self _build runner $safe

	$self configurelist $args
    }

    method help {} {
	set name [file tail $genconf::scriptName]
	puts "Usage: $name \[opts\].. TARGET  \[K=V\].."
	puts "  or   $name \[opts\].. :METHOD ARGS"
	puts "Methods: "
	puts "  gen TARGET       generates TARGET"
	puts "  target list      list targets (defined in rules.tcl)"
	puts "Options: "
	foreach o [lsort [$self info options]] {
	    puts "  $o"
	}
    }

    method gen {{params ""} {target ""} args} {
	$self load-with $params

	if {$target eq ""} {
	    set targlist [$self target list]
	} else {
	    set targlist [list $target]
	}

	set result {}
	foreach target $targlist {
	    lappend result $target [$self target eval $target]
	}
	foreach {target data} $result {
	    $self target write $target $data
	}
    }

    method {_build runner} {is_safe} {
	set opts {}
	if {$is_safe} {
	    lappend opts -safe
	}
	install myRunner using interp create {*}$opts $self.runner

	$myRunner eval [list array set env $options(-env)]

	foreach cmd [info commands ::util::*] {
	    $myRunner eval [::util::definition-of-proc $cmd yes]
	}
	foreach cmd {pwd file} {
	    $myRunner expose $cmd
	}

	$myRunner alias target $self target add
	$myRunner alias cget   $self cget
    }

    method load-with {params} {
	$myRunner eval [list array unset env]
	$myRunner eval [list array set env [dict merge $options(-env) $params]]

	$myRunner invokehidden source $options(-file)
    }

    method {target list} {} {
	set myTargetList
    }

    method {target add} {name command {opts ""}} {
	set vn myTargetDict($name)
	if {[info exists $vn]} {
	    error "Target $name already exists! [dict get [set $vn] debug]"
	}
	set $vn [list id [llength $myTargetList] debug [info frame -1]\
		     opts $opts command $command]
	lappend myTargetList $name
    }

    method {target eval} name {
	$myRunner eval [$self target command $name]
    }

    method {target info} name {
	set myTargetDict($name)
    }

    method {target command} name {
	set info [$self target info $name]
	dict get $info command
    }

    method {target body} name {
	set cmd [$self target command $name]
	$myRunner eval info body [lindex $cmd 0]
    }

    method {target write} {name data} {
	set info [$self target info $name]
	if {!$options(-stdout) && ![file exists $options(-destdir)]} {
	    $self _run file mkdir $options(-destdir)
	}
	set fname [file join $options(-destdir) $name]
	if {$options(-stdout)} {
	    puts "## writing $fname as:\n$data"
	} else {
	    $self _msg writing $fname
	    if {$options(-dry-run)} return
	    set fh [open $fname w]
	    if {[dict get $info opts] ne ""} {
		fconfigure $fh {*}[dict get $info opts]
	    }
	    puts -nonewline $fh $data
	    close $fh
	}
    }

    method _run args {
	$self _msg {*}$args
	if {$options(-dry-run)} return
	{*}$args
    }
    
    method _msg args {
	if {$options(-quiet)} return
	puts "# [join $args]"
    }
}

namespace eval ::util {

    # To define constant (in rules.tcl)

    proc define {name value} {
	set ::$name $value
	proc $name {} [list return $value]
    }

    #========================================
    # subst with loop
    #
    proc mapsubst {varName list subst} {
	upvar 1 $varName var
	set result ""
	foreach var $list {
	    append result [uplevel 1 [list subst -novariable -nobackslash\
					  $subst]]
	}
	set result
    }

    proc cmdsubst {subst} {
	set result [uplevel 1 [list subst -novariables -nobackslash $subst]]
	softab [unindent $result]
    }

    proc varsubst {subst} {
	set result [uplevel 1 [list subst -nocommands -nobackslash $subst]]
	softab [unindent $result]
    }

    #========================================

    proc cc chars { return \[$chars\] }

    # (Loose) identifier. [^./]
    proc ID {} { cc ^/\\. }

    proc comment args { return "" }

    proc quote str { set str }

    proc unindent string {
	# Replace each indented-newlines with simple newlines
	if {[regexp {^\n[\ \t]*} $string indent]} {
	    string map [list $indent "\n"] $string
	} else {
	    string map [list "\n    " "\n" "\n\t" "\n    "] $string
	}
    }

    proc indent {level string} {
	set softab "    "
	set indent [string repeat $softab $level]
	set result ""
	foreach line [split [softab $string] \n] {
	    append result $indent$line\n
	}
	set result
    }

    proc softab string {
	regsub -all \t $string "        "
    }

    #========================================
    # misc

    proc default {varName default} {
	upvar 1 $varName var
	if {[info exists var]} {
	    set var
	} else {
	    set default
	}
    }

    #========================================
    namespace export *

    #========================================
    # (used to pass defs to subinterp)
    proc definition-of-proc {proc {tail no}} {
	set args {}
	foreach var [info args $proc] {
	    if {[info default $proc $var default]} {
		lappend args [list $var $default]
	    } else {
		lappend args $var
	    }
	}
	if {$tail} {
	    set proc [namespace tail $proc]
	}
	list proc $proc $args [info body $proc]
    }

    #========================================
    # 制限付きの、 posix long option parser.
    proc posix-getopt {argVar {dict ""} {shortcut ""}} {
	upvar 1 $argVar args
	set result {}
	while {[llength $args]} {
	    if {![regexp ^- [lindex $args 0]]} break
	    set args [lassign $args opt]
	    if {$opt eq "--"} break
	    if {[regexp {^-(-no)?(-\w[\w\-]*)(=(.*))?} $opt \
		     -> no name eq value]} {
		if {$no ne ""} {
		    set value no
		} elseif {$eq eq ""} {
		    set value [expr {1}]
		}
	    } elseif {[dict exists $shortcut $opt]} {
		set name [dict get $shortcut $opt]
		set value [expr {1}]
	    } else {
		error "Can't parse option! $opt"
	    }
	    lappend result $name $value
	    if {[dict exists $dict $name]} {
		dict unset dict $name
	    }
	}

	list {*}$dict {*}$result
    }
    proc parse-params {argVar {dict ""}} {
	upvar 1 $argVar args
	set result {}
	while {[llength $args]} {
	    if {![regexp = [lindex $args 0]]} break
	    set args [lassign $args opt]
	    if {[regexp {^(\w[\w\-]*)=(.*)$} $opt \
		     -> name value]} {
		error "Can't parse option! $opt"
	    }
	    lappend result $name $value
	    if {[dict exists $dict $name]} {
		dict unset dict $name
	    }
	}

	dict merge $dict $result
    }
}

namespace eval genconf {
    namespace import ::util::*
}

if {![info level] && [info script] eq $::argv0} {
    set opts [util::posix-getopt ::argv {} \
		  [dict create -v -verbose -n -dry-run -q -quiet]]
    genconf gc {*}$opts

    set params [util::parse-params ::argv {}]

    if {![llength $::argv]} {
	gc help
	exit
    }

    if {[regsub ^: [lindex $::argv 0] {} meth]} {
	gc load-with $params
	puts [gc $meth {*}[lrange $::argv 1 end]]
    } else {
	gc gen $params {*}$::argv
    }
}
