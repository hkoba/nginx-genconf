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
# [cget -name] returns config param of nginx-genconf itself.
#
#========================================


define ROOT [default ::env(DOCUMENT_ROOT) /var/www/webapps]

# location without last '/'
define LOC  /myapp

# Absolute path of this application
define APP  $ROOT[LOC]

# Root of publically visible (mapped) subtree.
define HTML [APP]/html

# Expected path of where configs are saved.
define ETC  [APP].etc


# nginx configs
target main.conf    {rule /}
target admin.conf   {rule /admin/}
target public.conf  public_conf
target intra.conf   intra_conf

# systemd config
target myapp.service systemd_service

# 存在しないファイルまで App Server に丸投げだと、DDoS の鴨なんじゃないか？ って訳で、
# ファイルの存在を確認できたもののみ投げるように限定する実験。

# error_page + return のコンビで named location へ redirect, だと、
# App Server が返した status code を使ってくれない、と判明したため。

# Note:
# location で定義した (?<capture>) 変数を使える場所は限られる。
# 特に、 rewrite のパターン側では一切使えないことに注意。

proc rule loc {
    cmdsubst {
	#
	# This file was automatically generated. Do not edit!
	# Generator: [cget -generator]
	#
	alias [HTML][set loc];

	location ~ ^(.*?/)$ {
	    rewrite ^(.*?)/$ $1/index.yatt last;
	}

	[comment 拡張子有りで、実際にあるファイルなら fastcgi_pass]
	location ~ ^([LOC])(?<yatt_uri>/.*?\.(?:ydo|yatt|ytmpl))(?<yatt_args>/.*)?$ {

	    fastcgi_split_path_info ^([LOC][set loc])(.*);
	    #
	    include fastcgi_params;
	    fastcgi_param PATH_TRANSLATED $yatt_root$yatt_uri$yatt_args;
	    fastcgi_param HTTPS           $HTTPS;

	    # Not directly used. Only for debugging aid.
	    fastcgi_param YATT_SCRIPT     $fastcgi_script_name;
	    fastcgi_param YATT_PI         $fastcgi_path_info;
	    fastcgi_param YATT_DIR        $yatt_root;
	    fastcgi_param YATT_URI        $yatt_uri;
	    fastcgi_param YATT_SUBPI      $yatt_args;

	[mapsubst vn {HTML} {
	    if (-f [$vn]$yatt_uri) {
		set $yatt_root [$vn];
		fastcgi_pass unix:[APP]/var/tmp/fcgi.sock;
		break;
	    }
	}]
	    return 404;
	}

	[comment 拡張子無しの時に、.yatt ファイルの有無を検査し、あれば .yatt 有りに飛ばす]
	[comment XXX: この正規表現では一段階のサブディレクトリまでしか対応していない]
	location ~ ^([LOC])(?<d1>/[ID]+)?(?<d2>/[ID]+)?((?:/[cc ^/]+)*)$ {
	[mapsubst vn {HTML} {
	    [comment サブディレクトリの場合を先に]
	    if (-f [$vn]$d1$d2.yatt) {
		set $yatt_root [$vn];
		rewrite ^([LOC])(/[ID]+/[ID]+)(.*)$  $1$2.yatt$3 last;
	    }
	    [comment ベースディレクトリの場合]
	    if (-f [$vn]$d1.yatt) {
		set $yatt_root [$vn];
		rewrite ^([LOC])(/[ID]+)(.*)$        $1$2.yatt$3 last;
	    }
	}]
	}
    }
}

proc public_conf {} {
    cmdsubst {
	# -*- mode: tcl -*-
	location [LOC]/ {
	    include [ETC]/main.conf;
	}

	location [LOC]/siteadmin/ {
	    deny all;
	    return 404;
	}

	location = [LOC] {
	    rewrite ^(.*)$  $1/ redirect;
	}
    }
}

proc intra_conf {} {
    cmdsubst {
	# -*- mode: tcl -*-
	location [LOC]/ {
	    include [ETC]/main.conf;
	}

	location [LOC]/siteadmin/ {
	    allow 127.0.0.1;
	    allow 192.168.0.0/16;
	    deny all;
	    # Password Protection!
	    auth_basic "[LOC] (unified) admin";
	    auth_basic_user_file [ETC]/htpasswd;
	    include [ETC]/admin.conf;
	}

	location = [LOC] {
	    rewrite ^(.*)$  $1/ redirect;
	}
    }
}

proc systemd_service {} {
    varsubst {
	[Unit]
	Description=$::LOC psgi app

	#Requires=http-daemon.service
	Requires=nginx.service
	Before=nginx.service

	[Service]
	Type=simple

	ExecStart=$::APP/runplack

	User=nginx
	Group=nginx

	Restart=always
	TimeoutSec=5

	[Install]
	WantedBy=multi-user.target
    }
}

