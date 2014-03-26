#!/usr/bin/tclsh
# -*- coding: utf-8 -*-

package require snit

namespace eval genconf {
    ::variable scriptName [info script]
}

snit::macro usage {usage kind name args} {
    uplevel 1 [list set [set kind]_usage($name) $usage]
    $kind $name {*}$args
}

snit::type genconf {
    usage {Rule definition file} \
	option -file rules.tcl
    usage {output directory} \
	option -outdir _gen
    usage {generate to stdout instead of outdir}\
	option -stdout no
    usage {avoid use of [interp -safe]} \
	option -unsafe no
    option -help no
    option -env ""
    option -quiet no
    option -dry-run no

    option -generator "nginx-genconf"

    typevariable optUsage -array [array get option_usage]

    component myRunner

    variable myTargetList ""
    variable myTargetDict -array {}

    constructor args {

	set safe [expr {![from args -unsafe no]}]
	$self _build runner $safe

	$self configurelist $args
    }

    method help {} {
	set name [file tail $genconf::scriptName]
	puts "Usage: $name \[-n\] \[-f rules.tcl\] \[-o destdir\]"
	puts ""
	puts "In general:"
	puts "       $name \[--opt=value\].. TARGET.. \[ENV=VAL\].."
	puts "  or   $name \[--opt=value\].. :METHOD ARGS..."
	puts ""
	puts "Methods: "
	puts "  :generate TARGET...  generates TARGET"
	puts "  :target   list       list targets (defined in rules.tcl)"
	puts ""
	puts "Options: "
	foreach o [lsort [$self info options]] {
	    puts [format "  -%-15s           %s" \
		      $o [default optUsage($o) {}]]
	}
    }

    method generate {{params ""} {target ""} args} {
	$self load-with $params

	if {$target eq ""} {
	    set targlist [$self target list]
	} else {
	    set targlist [linsert $args 0 $target]
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
	if {!$options(-stdout) && ![file exists $options(-outdir)]} {
	    $self _run file mkdir $options(-outdir)
	}
	set fname [file join $options(-outdir) $name]
	if {$options(-stdout)} {
	    puts "## writing $fname as:\n$data"
	} else {
	    if {$options(-dry-run)} {
		$self _msg will write $fname
		return
	    } else {
		$self _msg writing $fname
	    }
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
		lassign [dict get $shortcut $opt] nArgs name
		if {$nArgs == 0} {
		    set value [expr {1}]
		} elseif {$nArgs == 1} {
		    set args [lassign $args value]
		} else {
		    error "Unsupported nArgs($nArgs) for $name"
		}
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
    proc parse-params {arglist {dict ""}} {
	set params {}
	set others {}
	while {[llength $arglist]} {
	    set arglist [lassign $arglist any]
	    if {[regexp = $any]} {
		if {[regexp {^(\w[\w\-]*)=(.*)$} $any \
			 -> name value]} {
		    error "Can't parse option! $opt"
		}
		lappend params $name $value
	    } else {
		lappend others $any
	    }
	}
	list [dict merge $dict $params] {*}$others
    }
}

namespace eval genconf {
    namespace import ::util::*
}

if {![info level] && [info script] eq $::argv0} {
    set opts [util::posix-getopt ::argv {} \
		  [dict create \
		       -h {0 -help} \
		       -v {0 -verbose} \
		       -n {0 -dry-run} \
		       -q {0 -quiet} \
		       -o {1 -outdir} \
		       -f {1 -file} \
		      ]]

    genconf gen {*}$opts

    if {[gen cget -help]} {
	gen help
	exit
    }

    set ::argv [lassign [util::parse-params $::argv {}] params]

    if {![regsub ^: [lindex $::argv 0] {} meth]} {
	gen generate $params {*}$::argv
    } else {
	set rest [lrange $::argv 1 end]
	if {$meth eq "generate"} {
	    gen generate $params {*}$rest
	} else {
	    gen load-with $params
	    puts [gen $meth {*}$rest]
	}
    }
}
