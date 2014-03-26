nginx-genconf
=============

nginx-genconf is a small tool to generate (multiple) nginx conf
files from single rule file written in [Tcl].  Tcl has simple,
flexible syntax. It's curly block can fit almost every C-like block
structured text. Also, Tcl has many builtins for templating such as
[subst], [string map] and others. That's why I wrote this tool.

(Actually, this tool is not restricted to nginx.)

SYNOPSIS
--------------------

First create rules.tcl, like following:

```tcl
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
```

Then run nginx-genconf.tcl


```
% nginx-genconf.tcl -h
Usage: nginx-genconf.tcl [-n] [-f rules.tcl] [-o destdir]

In general:
       nginx-genconf.tcl [--opt=value].. TARGET.. [ENV=VAL]..
  or   nginx-genconf.tcl [--opt=value].. :METHOD ARGS... [ENV=VAL]..

Methods:
  :generate TARGET...  generates TARGET
  :target list         list targets (defined in rules.tcl)
  :target eval TARGET  generate TARGET to stdout

Options:
  --debug
  --dry-run         Just report what this will generate, like make -n
  --file            Rule definition file(default: rules.tcl)
  --generator       Name of generator. Can be embedded via [cget -generator].
  --help
  --outdir          output directory(shortly: -o, default: _gen)
  --quiet
  --stdout          generate to stdout instead of outdir
  --unsafe          avoid use of tcl sandbox ([interp -safe])
%
% nginx-genconf.tcl :target list
myapp.conf

% nginx-genconf.tcl :target eval myapp.conf

location /myapp/ {
    fastcgi_split_path_info ^(/myapp)(.*);
    include fastcgi_params;
    fastcgi_pass unix:/var/www/webapps/myapp/var/tmp/fcgi.sock;
}

% nginx-genconf.tcl  :target eval myapp.conf APPS_ROOT=/opt/webapps
location /myapp/ {
    fastcgi_split_path_info ^(/myapp)(.*);
    include fastcgi_params;
    fastcgi_pass unix:/opt/webapps/myapp/var/tmp/fcgi.sock;
}
 
% nginx-genconf.tcl -n
# will write _gen/myapp.conf

% ./nginx-genconf.tcl
# writing _gen/myapp.conf
%
```

Rule commands
--------------------

`rules.tcl` is basically normal Tcl script 
so you can use all commands in Tcl (but [IO is restricted][safe], by default).
It must contain at least one `target` declaration.

There are some predefined helper commands, listed below.

### target NAME COMMAND

Declares target file `NAME` and its generator `COMMAND`.

### define NAME VALUE

Defines Tcl proc `NAME` and also variable `$::NAME`.

### cmdsubst STR

Substitute all `[tcl command]` in `STR`.
You can use `$` and `\` as ordinally text.

### mapsubst VARNAME LIST STR

Loops command-only subst for each `VARNAME` in `LIST`.

### varsubst STR

Substitute all `$tcl_variables` in STR.
You can use `[]` and `\` without escaping.

### cc CHARS

returns `[CHARS]`. Useful to construct character class for regexp.

### ID

Shorthand of `cc ^./`, which means regexp `[^./]`.

### comment STR

To embed comment as `[comment My comment!]`

### default VAR VALUE

tries to fetch VAR. If it is empty, returns VALUE

### cget -NAME

returns config param of nginx-genconf itself.

### include FILE

does `[source FILE]`


Internals.
--------------------

nginx-genconf evals script under Tcl's sandbox mechanism.
Before loading rules.tcl, it installs all public commands defined in `::util::*`
to the sandbox. So, you may want to add procs there.

Also, nginx-genconf is written as reusable snit::type. 
So, you can safely `source` this tcl script and instantiate via
`genconf NAME opts...`.


[Tcl]:http://www.tcl.tk/
[subst]:http://www.tcl.tk/man/tcl/TclCmd/subst.htm
[string map]:http://www.tcl.tk/man/tcl/TclCmd/string.htm#M33
[safe]:http://www.tcl.tk/man/tcl/TclCmd/interp.htm#M44
