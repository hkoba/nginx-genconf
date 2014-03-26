# -*- coding: utf-8 -*-

#========================================
#
# [target NAME COMMAND] declares target file NAME and its generator COMMAND.
#
# [define NAME VALUE] defines Tcl proc "NAME" and also variable $::NAME.
#
# [cmdsubst STR] applies [subst] on STR with [command] substitution only.
#  You can use $ and \ without escaping.
#
# [mapsubst VARNAME LIST STR] loops on LIST
#
# [comment STR] is for embedded comment.
#
# [varsubst STR] applies [subst] on STR with $variable substitution only.
#  You can use [] and \ without escaping.
#
# [default VAR VALUE] tries to fetch VAR. If it is empty, returns VALUE
#
# [cget -NAME] returns config param of nginx-genconf itself.
#
# [include FILE] does [source FILE]
#
#========================================

# include [file join [file dirname [info script]] other.tcl]

define ROOT [default ::env(APPS_ROOT) /var/www/webapps]

# Pure name of this app
define MYAPP myapp

# location without last '/'
define LOC  /[MYAPP]

# Absolute path of this application
define ABS  $ROOT[LOC]

# Root of publically visible (mapped) subtree.
define HTML [ABS]/html

target [MYAPP].conf {
    cmdsubst {
	location [LOC]/ {
	    fastcgi_split_path_info ^([LOC])(.*);
	    include fastcgi_params;
	    fastcgi_pass unix:[ABS]/var/tmp/fcgi.sock;
	}
    }
}
