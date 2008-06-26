#!/bin/bash

#!# WARNING! ACHTUNG! NOTICE!
#!# This script has control characters embedded in it!
#!# If you try to use anyth 'intelligent' editor on it, you have a good chance
#!# of mangling them! This will show as errors in parsing .httpfuncs.sh ...
#!# I use vi...

#!# If we run into bash 2.x, we get /weird/. I'm not sure I care...
#!# though I did some trickery with here documents to make bash 2.x not
#!# parse 3+ regexp operators.
#!# Using this for bash 1.x is likely a /bad/ idea.

#!# This whole shuffling about with 'read' is an attempt to not fork
#!# unnecessary processes. fork under cygwin is sloooow. so use builtins
#!# where you can, even if it makes it less clear.

# prescribe pills to offset the shakes to offset the pills you know you should take it a day at a time
#             panic! at the disco - "nails for breakfast, tacks for snacks"

# this is the first line! we want to know where this script /is/!
# appears to not work under 2.x. ah well.
RCPATH=${BASH_ARGV}
if [ ${RCPATH} ]; then
	RCDIR=`dirname $RCPATH`

	if [ ${RCDIR} == "." ]; then
		RCPATH=${PWD}/${RCPATH}
	fi
fi

# is this a link? where is the real file?
# oh, and THANKS SO MUCH SOLARIS for not having readlink!
if [[ ${RCPATH} && -h "${RCPATH}" ]]; then
	RCPATH=`ls -l ${RCPATH}|awk -F' -> ' '{print $2}'`
fi

# version information
JBVER="4.5.8"
JBVERSTRING='jBashRc v'${JBVER}'(u)'
JBSVNID='$Id: .bashrc 23 2008-06-26 07:09:34Z rj $'

## DEBUG SWITCH - UNCOMMENT TO TURN ON DEBUGGING
#BASHRC_DEBUG="yes"

# what version of bash are we dealing with? (please be 3.x, please be 3.x ...)
BASH_MAJOR=${BASH_VERSION/.*/}
BASH_MINOR=${BASH_VERSION#${BASH_MAJOR}.}
BASH_MINOR=${BASH_MINOR%%.*}

# are we a login shell?
INVNAME=(`ps -p $$ -o comm= 2>/dev/null`) # works on Linux and FreeBSD...
					  # solaris might, depends on which ps
# This works around openbsd's aggravating ps, possibly others
ILAST=${#INVNAME[*]}
((ILAST--))
INVNAME=${INVNAME[$ILAST]}

# possible locations for aux files, first one listed wins
# FIXME: set script up to use *all* of them
if [ -d ${HOME}/.bash.d ]; then
	BASHFILES="${HOME}/.bash.d"
elif [ -d /etc/bash.d ]; then
	BASHFILES="/usr/local/etc/bash.d"
elif [ -d /usr/local/etc/bash.d ]; then
	BASHFILES="/etc/bash.d"
fi

# qnd debug function
function print_debug {
	if [ ${BASHRC_DEBUG} ]; then
		echo -e ${@} >&2
	fi
}

## path(-like) functions
#?# TEST: do these work for directories with spaces?

# genstrip - remove element from path-type variable
# you need to specify the variable and the element!
function genstrip {
	# NOTE: debugging is commented out because quoting is parsed every
	#       time this function runs... whether debugging is enabled or not.
	#print_debug "Stripping ${2} from ${1}"
	#print_debug "${1} is\t\t${!1}"
	eval $1=${!1//':'${2}':'/':'}
	eval $1=${!1%:${2}}
	eval $1=${!1#${2}:}
	#print_debug "${1} is now\t${!1}"
}

#!# ALL FUNCTIONS USE STRIPPATH TO REMOVE DUPLICATES
#!# ALL FUNCTIONS CHECK EXISTENCE OF DIRECTORY BEFORE ADDING!
# genappend - add directory element to path-like element
# you need variable, then element
function genappend {
	genstrip ${1} ${2}
	if [ -d ${2} ]; then
		eval $1=${!1}':'${2}
	fi
}

# we keep pathappend, even though not used, for interactive purposes :)
function pathappend {
	genappend PATH ${1}
}

# genprepend - add directory element to FRONT of path-like list
function genprepend {
	genstrip ${1} ${2}
	if [ -d ${2} ]; then
		eval $1=${2}':'${!1}
	fi
}

# we keep pathprepend, even though not used, for interactive purposes :)
function pathprepend {
	genprepend PATH ${1}
}

# pathsetup - set system path to work around cases of extreme weirdness (yes I have seen them!)
function pathsetup {
	genprepend PATH /etc
	genprepend PATH /usr/etc
	genprepend PATH /usr/sysadm/privbin
	genprepend PATH /usr/games
	genprepend PATH /sbin
	genprepend PATH /usr/sysadm/bin
	genprepend PATH /usr/sbin
	genprepend PATH /usr/local/sbin
	genprepend PATH /usr/dt/bin
	genprepend PATH /usr/openwin/bin
	genprepend PATH /usr/bin/X11
	genprepend PATH /usr/X11R6/bin
	genprepend PATH /bin
	genprepend PATH /usr/bin
	genprepend PATH /usr/xpg4/bin
	genprepend PATH /usr/bsd
	genprepend PATH /usr/ucb
	genprepend PATH /usr/kerberos/bin # iunno, it's like redhat now...
	genprepend PATH /usr/nekoware/bin
	genprepend PATH /opt/local/bin
	genprepend PATH /usr/local/bin
	if [ ${OPSYS} == "cygwin" ]; then
		SystemDrive=`cygpath ${SYSTEMDRIVE}`
		ProgramFiles=`cygpath ${PROGRAMFILES}`
		SystemRoot=`cygpath ${SYSTEMROOT}`
		genappend PATH ${SystemDrive}/bin
	fi
}

function set_manpath {
	for dir in /usr/X11R6/man /usr/openwin/man /usr/dt/man /usr/share/man /usr/man /usr/local/share/man /usr/local/man; do
		genprepend MANPATH ${dir}
	done
	if [ -d /opt ]; then
		for dir in `ls /opt`; do
			genappend MANPATH /opt/${dir}/man
		done
	fi
	if [ ${OPSYS} == "cygwin" ]; then
		genappend MANPATH ${SystemRoot}/man
	fi
	export MANPATH
}

## internal functions
#-# HELPER FUNCTIONS
#--# Text processing
# matchstart - match word at beginning of a line (anywhere in a file) [used by getterminfo]
#?# TEST: spaces?
function matchstart {
	grep -q ^${1} ${2}
}

# sourcex - source file if found executable
function sourcex {
	if [ -x $1 ]; then source $1; fi
}

# chkcmd - check if specific command is present, wrapper around which being evil on some platforms
function chkcmd {
	case ${WSTR} in
		"0 1"|"1 1")
			${REAL_WHICH} ${1} &> /dev/null
			;;
		*)
			${REAL_WHICH} ${1} 2>&1 | grep -q ^no
			if [ ${?} == "1" ]; then
				true
			else
				false
			fi
			;; 
	esac
}

# v_alias - overloads command with specified function if command exists
function v_alias {
	chkcmd ${2}
	if [ ${?} == 0 ]; then
		alias ${1}=${2}
	fi
}

#-# SETUP FUNCTIONS
# colordefs - defines for XTerm/Console colors
function colordefs {
	RS='\[\e[0m\]' # I think this is xterm specific?
	# BC - bold colorset
	BC_LT_GRA='\[\e[0;37m\]'
	BC_BO_LT_GRA='\[\e[1;37m\]'
	#BC_DM_GRA='\[\e[2;37m\]' # 2-series not supported by xterm?
	BC_CY='\[\e[0;36m\]'
	BC_GRN='\[\e[0;32m\]'
	BC_BL='\[\e[0;34m\]'
	BC_PR='\[\e[0;35m\]'
	BC_BR='\[\e[0;33m\]'
	BC_RED='\[\e[0;31m\]'
}

# getterminfo - initialize term variables for function use
# we set color caps EVERY time in case of environment being handed to us via ssh/screen/?
function getterminfo {
	case ${TERM} in
		# bright (vs. bold), titleable terms
		cygwin*)
			TERM_CAN_TITLE=1
			TERM_COLORSET="bright"
			TERM_CAN_SETCOLOR=0
			;;
		# bold, titleable terms (with background colorset cmds!)
		xterm*|rxvt*)
			TERM_CAN_TITLE=1
			TERM_COLORSET="bold"
			TERM_CAN_SETCOLOR=1
			;;
		# bold, titlable terms (w/o background color caps)
		# putty - not available in everyone's termcaps... we work around that.
		putty*)
			TERM_CAN_TITLE=1
			TERM_COLORSET="bold"
			TERM_CAN_SETCOLOR=0
			if [[ ! ( `matchstart ${TERM} /etc/termcap` = 0 ) ]]; then
				export TERM=xterm
			fi
			;;
		# bright, not titleable
		linux*|ansi*)
			TERM_CAN_TITLE=0
			TERM_COLORSET="bright"
			TERM_CAN_SETCOLOR=0 # okay, a lie for linux, but it sets codes very differently than Xterm.
			;;
		# bold, not titleable (have not seen...)
		# ah yes, screen... just assume we're running it as an xterm
		# it drops color codes the incoming terminal doesn't understand :)
		# also, work around missing termcap entry. or the 'screen.linux' shit
		screen*)
			TERM_CAN_TITLE=1
			TERM_COLORSET="bold"
			TERM_CAN_SETCOLOR=1
			if [[ ! ( `matchstart ${TERM} /etc/termcap` = 0 ) ]]; then
				if [[ ! ( `matchstart screen /etc/termcap` = 0 ) ]]; then
					# be an xterm!
					export TERM=xterm
				else
					export TERM=screen
				fi
			fi
			;;
		# failsafe for when we have no idea
		*)
			TERM_CAN_TITLE=0
			TERM_COLORSET="none"
			TERM_CAN_SETCOLOR=0
			;;
		esac
}

# gethostinfo - initialize host variables for function use
function gethostinfo {
	#?# TEST: are all unames created equal?
	#!# all trs are *not* created equal
	print_debug trtest
	if [ -x /usr/bin/tr ]; then alias tr=/usr/bin/tr; fi
	FQDN=`uname -n|tr [:upper:] [:lower:]`
	HOST=${FQDN%%\.*} # in case uname returns FQDN
	DOMAIN=${FQDN##${HOST}.}
	OPSYS=`uname -s|tr [:upper:] [:lower:]`
	CPU=`uname -m|tr [:upper:] [:lower:]`
	MVER=`uname -r|awk -F. '{ print $1 }'` # x
	LVER=`uname -r|sed 's/-.*$//'|awk -F. '{ print $1$2 }'` # x.x
	CURTTY=`tty`
	CURTTY=${CURTTY:5}
	print_debug case_opsys
	case $OPSYS in
		# hack around cygwin including the Windows ver
		cygwin*)
			OPSYS=cygwin
			;;
		# the first of MANY hacks around solaris
		sunos)
			CPU=`uname -p|tr [:upper:] [:lower:]`
			if [ $MVER == 5 ]; then
				OPSYS="solaris"
			fi
			# we *have* to use SysV ps
			INVNAME=`/usr/bin/ps -p $$ -o comm= 2>/dev/null`
			;;
		# OS X is actually similar here
		darwin)
			CPU=`uname -p|tr [:upper:] [:lower:]`
			;;
	esac

	print_debug x86_check
	if [ ${CPU:2} == 86 ] && [ ${CPU:0:1} == "i" ]; then
		CPU="x86"
	fi

	# while we're here, find 'which' and see if it works
	print_debug which_hacking
	dealias which
	REAL_WHICH=`which which`||REAL_WHICH="/usr/bin/which" # Pray!
	# following functions require bash 3.x
	# this works around the case of cygwin/win32 having gnuwin32's which...
	if [ ${BASH_MAJOR} -gt "2" ]; then
	if [ ${RCPATH} -nt ${HOME}/.whichery.sh ]; then
	(
	cat <<\WHICHERY
if [[ "${REAL_WHICH}" =~ ":" ]]; then
	# paths do not contain colons, wtf?
	REAL_WHICH=/usr/bin/which
fi
WHICHERY
) > ${HOME}/.whichery.sh
	fi
	. ${HOME}/.whichery.sh
	fi

	WSTR=`${REAL_WHICH} --help 2>&1 | grep -q ^no ; echo ${PIPESTATUS[@]}`
	# 1 0 - which returned an error, grep did not - bad which
	# 1 1 - which returned an error, grep did too - bad which (?)
	# 0 1 - which success, grep returned an error - good which
	# 0 0 - which success, grep success           - EVIL WHICH!
	print_debug su_hacking
	# su too
	print_debug ${REAL_WHICH}
	REAL_SU=`${REAL_WHICH} su`
	print_debug sed_hacking
	# sed three
	SED=`${REAL_WHICH} sed 2> /dev/null`||SED="/bin/sed"
	# are we a 'login' shell?
	if [ ${INVNAME} ] && [ ${INVNAME:0:1} == '-' ]; then
		LSHELL="yes"
	fi
	# if we are in the domain 'saic.com', force HTTP/1.1 (websense!)
	case ${DOMAIN} in
	*saic.com)
		USE_HTTP_1DOT1="yes"
		;;
	esac
}

# getuserinfo - initialize user variables for function use (mostly determine if we are a superuser)
function getuserinfo {
	case ${OPSYS} in
		cygwin*)
			#?# hardcoded RID here...
			id -G | grep -q 544
			if [ $? == 0 ]; then
				HD='#'
			else
				HD='$'
			fi
			;;
		solaris)
			if [ `/usr/xpg4/bin/id -u` == "0" ]; then
				HD='#'
			else
				HD='$'
			fi
			;;
		*)
			if [ `id -u` == "0" ]; then
				HD='#'
			else
				HD='$'
			fi
			;;
	esac
}

# hostsetup - call host/os-specific subscripts
# call after gethostinfo, BEFORE getuserinfo!
function hostsetup {
	sourcex ${BASHFILES}/opsys/${OPSYS}.sh
	sourcex ${BASHFILES}/opsys/${OPSYS}-${CPU}.sh
	sourcex ${BASHFILES}/opsys/${OPSYS}${MVER}.sh
	sourcex ${BASHFILES}/opsys/${OPSYS}${MVER}-${CPU}.sh
	sourcex ${BASHFILES}/opsys/${OPSYS}${LVER}.sh
	sourcex ${BASHFILES}/opsys/${OPSYS}${LVER}-${CPU}.sh
	sourcex ${BASHFILES}/host/${HOST}.sh
}

# pbinsetup - load personal bin directory for host
function pbinsetup {
	genappend PATH ${HOME}/bin/noarch
	genappend PATH ${HOME}/bin/${OPSYS}-${CPU}
	genappend PATH ${HOME}/bin/${OPSYS}${MVER}-${CPU}
	genappend PATH ${HOME}/bin/${OPSYS}${LVER}-${CPU}
	genappend PATH ${HOME}/hbin/${HOST}
	# set PERL5LIB here
	if [ -d ${HOME}/Library/perl5 ]; then
		export PERL5LIB=${HOME}/Library/perl5
	fi
	# add our personal ~/Applications subdirectories
	for dir in `ls -d ${HOME}/Applications/*/bin 2> /dev/null`; do
		genappend PATH $dir
	done
	# add out personal ~/Library subdirectories
	for dir in `ls -d ${HOME}/Library/*/lib 2> /dev/null`; do
		genappend LD_LIBRARY_PATH $dir
	done
	export LD_LIBRARY_PATH
}

# zapenv - kill all environment setup routines, including itself(!)
function zapenv {
	unset -f pathsetup
	unset -f getterminfo
	unset -f gethostinfo
	unset -f getuserinfo
	unset -f hostsetup
	unset -f pbinsetup
	unset -f kickenv
	unset -f colordef
	unset -f matchstart
	unset -f set_manpath
	unset -f zapenv
}

# kickenv - run all variable initialization, set PATH.
function kickenv {
	print_debug gethostinfo
	gethostinfo # set REAL_WHICH!!
	print_debug pathsetup
	pathsetup
	print_debug hostsetup
	hostsetup # to extend path, at least for solaris
	print_debug getuserinfo
	getuserinfo
	print_debug getterminfo
	getterminfo
	print_debug colordefs
	colordefs
	print_debug set_manpath
	set_manpath
	print_debug pbinsetup
	pbinsetup
	print_debug zapenv
	zapenv
}

#-# TERMINAL FUNCTIONS
# writetitle - update xterm titlebar
function writetitle {
	if [ ${TERM_CAN_TITLE} == 1 ]; then
		echo -ne "\e]0;${@}\a"
	fi
}

# setcolors - set xterm/rxvt background/foreground/highlight colors
# arguments (fgcolor bgcolor) <- arguments as colorstrings (termspecific)
function setcolors {
	if [ ${TERM_CAN_SETCOLOR} == 1 ]; then
		echo -ne "\e]10;${1}\a" # foreground
		echo -ne "\e]17;${1}\a" # highlight
		echo -ne "\e]11;${2}\a" # background
	fi
}


# display functions
# pscount - return count of processes on this system (stub, returns -1. should be replaced by opsys-specific call.)
function pscount {
	echo -n "-255"
}

function .properties {
	echo -n ${JBVERSTRING}
	if [ ${RCPATH} ]; then
		if `test ${RCPATH} = ${HOME}/.bashrc`; then
			echo ' Personal Edition'
		else
			echo ' System Edition'
		fi
	else
		echo ''
	fi
	echo 'from SVN: '${JBSVNID}
	echo 'SysID: '${HOST}' '${OPSYS}${LVER}' '${CPU}' ('${TERM}')'
	if [ ${RCPATH} ]; then
		echo 'RCFile: '${RCPATH}
	fi
	echo 'using bash '${BASH_VERSION}
}

# overloaded commands
# (m)which - which with function expansion (when possible)
function mwhich {
	if [[ ${WSTR} == "0 1" ]]; then
		(alias; declare -f) | ${REAL_WHICH} --tty-only --read-alias --read-functions --show-tilde --show-dot $@
	else
		if [ ${BASH_MAJOR} -gt "2" ]; then
			declare -f|grep -q ^${1}
			if [ ${?} == "0" ]; then
				declare -f ${1}
			fi
		else
			FUNCTION=`declare -f|grep "^declare"|grep ' '${1}' '`
			if [ ${?} == "0" ]; then
				declare -f `echo ${FUNCTION}|awk '{ print $3 }'`
			fi
		fi
		alias|grep "alias ${1}="
		${REAL_WHICH} ${1}
	fi
}

# (m)su - su with term color change for extra attention
function msu {
	setcscheme ${CSCHEME_SU}
	${REAL_SU} $@
	echo ' '
	setcscheme ${CSCHEME_DEFAULT}
}

## environment manipulation
# dealias - undefine alias if it exists
function dealias {
	if alias|grep -q $1
		then unalias $1
	fi
}

# setenv - sets an *exported* environment variable
function setenv {
	oifs=$IFS
	IFS=' '
	name=$1
	shift
	export $name="$*"
	IFS=$oifs
	unset oifs
}

# unsetenv - unsets exported environment variables
function unsetenv {
	if export|grep 'declare -x'|grep -q $1
		then unset $1
	fi
}

# new functions
# push2host # copy environment files over using scp, link in to .bashrc and friends (only available in personal copies)
function push2host {
	RCDIR=`dirname ${RCPATH}`
	if [[ ( `expr match ${RCPATH} ${HOME}` = ${#HOME} ) ]]; then
		if [[ ( `expr match ${BASHFILES} ${HOME}` = ${#HOME} ) ]]; then
			scp -r ${BASHFILES} ${1}:~
			scp ${RCPATH} ${1}:~/.bash.d/rc
			ssh ln -sf ~/.bash.d/rc ~/.bashrc
			ssh ln -sf ~/.bash.d/rc ~/.bash_profile
		else
			scp ${RCPATH} ${1}:~/.bashrc
			ssh ln -sf ~/.bashrc ~/.bash_profile
		fi
	fi

}

# httpsnarf # quick and dirty http(s) fetch [https requires openssl]
function httpsnarf {
	HTTP_PURI=`echo ${1}|sed s@https://@@`
	HTTP_HOST=`echo ${HTTP_PURI}|awk -F/ '{ print $1 }'`
	HTTP_PATH=`echo ${HTTP_PURI}|sed s@${HTTP_HOST}@@`
	if [ "x${HTTP_PATH}" = "x" ]; then
		HTTP_PATH="/"
	fi
	case ${USE_HTTP_1DOT1} in
		yes)
			HTTP_REQ="GET ${HTTP_PATH} HTTP/1.1\r\nHost: ${HTTP_HOST}\r\nUser-Agent: JBashRc (${JBVER}; ${OPSYS}${LVER} ${CPU}; ${COLUMNS}x${LINES})\r\nAccept-Encoding: *;q=0\r\nConnection: close\r\n\n"
			;;
		*)
			HTTP_REQ="GET ${HTTP_PATH}\r\n\n"
			;;
	esac

	if [[  ( `expr match ${1} https` = 5 ) ]]; then
		chkcmd openssl
		if [ ${?} == 0 ]; then
			echo -ne ${HTTP_REQ}|openssl s_client -connect ${HTTP_HOST}:443 -quiet 2> /dev/null
		else
			echo "I don't have openssl here, sorry."
		fi
	else
		exec 5<>/dev/tcp/${HTTP_HOST}/80
		echo -ne ${HTTP_REQ}>&5
		cat <&5
	fi
}

# following functions require bash 3.x
if [ ${BASH_MAJOR} -gt "2" ]; then
if [ ${RCPATH} -nt ${HOME}/.httpfuncs.sh ]; then
(
cat <<\HTTPFUNCS
# http_dechunk # pseudo-dechunker for http
function http_dechunk {
	setter=-u
	if shopt -q nocasematch; then
		setter=-s
	fi
	chunklen=0
	is_chunked=0
	hdr_line=0
	shopt -s nocasematch
	while read line; do
		#line=${line%}
		if [[ ${line} =~ '^transfer-encoding:.*chunked;?.*' ]]; then
			is_chunked=1
			line=`echo ${line}|sed 's/[Cc]hunked;*//'`
			if [[ ! ${line} =~ '^transfer-encoding: *$' ]]; then
				echo ${line}
			fi
		fi
		if [[ (${chunklen} == 0 && (${hdr_line} == 1 && ${line} != "0")) ]]; then
			chunklen=${line%}
		elif [[ ! ${line} == "0" ]]; then
			echo ${line}
		fi
		if [[ ${line} =~ '^$' ]]; then
			hdr_line=1
		fi
	done
	shopt $setter nocasematch
}

# http_striphdr # this is *supposed* to remove the http header bits, but I'm not guaranteeing it.
function http_striphdr {
	hdr_line=0
	while read line; do
		if [ ${hdr_line} == 1 ]; then
			echo ${line}
		fi
		if [[ ${line} =~ '^$' ]]; then
			hdr_line=1
		fi
	done
}

# http_stripcontent # only show http headers. maybe.
function http_stripcontent {
	hdr_line=0
	while read line; do
		if [[ ${line} =~ '^$' ]]; then
			hdr_line=1
		fi
		if [ ! ${hdr_line} == 1 ]; then
			echo ${line}
		fi
	done
}
HTTPFUNCS
) > ${HOME}/.httpfuncs.sh
fi
. ${HOME}/.httpfuncs.sh
fi

## Monolithic version - now we config some things!
function monolith_setfunc {
	case $OPSYS in
		linux)
			# redifine linux-specific functions
			function pscount {
				echo -n `expr \`ps ax|wc -l\` - 6`
			}
			;;
		cygwin)
			# create a .pscount.vbs script if needed
			if [ ! -f ${HOME}/.pscount.vbs ]; then
				echo -ne "c = 0\r\nset w = GetObject(\"winmgmts:{impersonationlevel=impersonate}!\\\\\\.\\\root\\\cimv2\")\r\nset l = w.ExecQuery (\"Select * from Win32_Process\")\r\nfor each objProcess in l\r\nc = c + 1\r\nnext\r\nc = c - 3\r\nwscript.stdout.write c\r\n" > ${HOME}/.pscount.vbs
			fi

			PSCVBS=`cygpath -da ${HOME}/.pscount.vbs`

			function pscount {
				cscript //nologo ${PSCVBS}
			}
			# fake getent - call mkpasswd/mkgroup as appropriate
			function getent {
				case ${1} in
					passwd)
						mkpasswd.exe -du ${2}
						;;
					group)
						mkgroup.exe -du ${2}
						;;
					*)
						echo 'Wha?'
						;;
				esac
			}
			;;
		solaris)
			function pscount {
				echo -n `expr \`ps ax|wc -l\` - 5`
			}
			;;
		freebsd)
			function pscount {
				# try to exclude kernel threads
				echo -n `expr \`ps ax|grep -v '[0-9] \['|wc -l\` - 7`
			}
			;;
		irix)
			function pscount {
				echo -n `expr \`ps -ef|wc -l\` - 6`
			}
			;;
		openbsd)
			function pscount {
				echo -n `expr \`ps ax|wc -l\` - 6`
			}
			;;
		darwin)
			function pscount {
				echo -n `expr \`ps ax|wc -l\` - 5`
			}
			;;
		*)
			# do nothing...
			;;
	esac
	unset -f monolith_setfunc
}

# set screen colors for bright or bold
function monolith_setcolors {
	case ${TERM_COLORSET} in
		bold)
			;;
		bright)
			;;
	esac
}

function monolith_aliases {
	# we actually set PAGER/EDITOR here as well
	chkcmd less
	if [ ${?} == 0 ]; then
		export PAGER=less
	fi
	chkcmd vim
	if [ ${?} == 0 ]; then
		export EDITOR=vim
	fi
	# try to call coreutils & friends
	v_alias ls gls
	v_alias cp gcp
	v_alias mv gmv
	v_alias rm grm
	v_alias df gdf
	v_alias du gdu
	v_alias id gid
	v_alias tail gtail
	v_alias md5sum gmd5sum
	v_alias vi vim
	v_alias expr gexpr
	v_alias chgrp gchgrp
	v_alias chown gchown
	v_alias chmod gchmod
	v_alias find gfind
	v_alias lynx links
	v_alias more less
	v_alias watch cmdwatch
	v_alias man pinfo
	v_alias mpg123 mpg321	# we prefer mpg321 if we have it...
	v_alias mpg321 mpg123	# else mpg123
	v_alias ftp ncftp
	
	# common custom aliases
	alias path='echo ${PATH}'
	alias scx='screen -x'
	alias l='ls'
	alias s='sync;sync;sync'

	# pretend to be DOS, sometimes
	alias cls='clear'
	alias md='mkdir'
	alias rd='rm -rf'
	alias copy='cp'
	alias move='mv'
	alias type='cat'
	alias tracert='traceroute'
	alias ipconfig='ifconfig'

	# override system which with our more flexible version...
	alias which='mwhich'

	case ${OPSYS} in
		cygwin*)
			alias ll='ls -FlAh --color=tty'
			alias ls='ls --color=tty -h'
			alias start='cygstart'
			alias du='du -h'
			alias df='df -h'
			alias cdw='cd "$USERPROFILE"'
			v_alias ping ${SystemRoot}/system32/ping.exe
			aspn_rpath=/proc/registry/HKEY_LOCAL_MACHINE/SOFTWARE/ActiveState/ActivePerl
			if [ -f ${aspn_rpath}/CurrentVersion ]; then
				read aspn_hive < ${aspn_rpath}/CurrentVersion
				read -r ASPN_PATH < ${aspn_rpath}/${aspn_hive}/\@
				ASPN_PATH=`cygpath ${ASPN_PATH}`bin
				v_alias perl ${ASPN_PATH}/perl.exe
			fi
			unalias ipconfig
			;;
		linux)
			alias ll='ls -FlAh --color=tty'
			alias ls='ls --color=tty -h'
			alias vi='vim'
			alias du='du -h'
			alias df='df -h'
			alias mem='free -m'
			;;
		openbsd)
			alias ll='ls -FlAh'
			alias du='du -h'
			alias df='df -h'
			alias free='vmstat'
			alias mem='vmstat'
			;;
		*)
			alias ll='ls -FlAh'
			;;
	esac
}

# export the prompt
function setprompt {
	print_debug checkps1
	if [[ -n $PS1 ]]; then
	print_debug setps1
	case "$1" in
	simple)
		PS1=${INVNAME}"-"${BASH_MAJOR}"."${BASH_MINOR}${HD}" "
		;;
	classic)
		PROMPT_COMMAND="writetitle ${USER}@${HOST}:\`pwd\`"
		setprompt simple
		;;
	old)
		PROMPT_COMMAND="writetitle ${USER}@${HOST}:\`pwd\`"
		PS1="${BC_LT_GRA}\t ${BC_PR}[\u@${HOST}] ${BC_BL}{${CURTTY}}\n${BC_RED}<"'`pscount`'"> ${BC_GRN}(\W) ${BC_BR}${HD}${RS} "
		;;
	timely)
		PROMPT_COMMAND="writetitle ${USER}@${HOST}:\`pwd\`"
		case ${TERM_COLORSET} in
			bold)
				PS1="${BC_BR}#${RS} ${BC_CY}(\t)${RS} ${BC_PR}?"'${?}'"${RS} ${BC_GRN}!\!${RS} ${BC_LT_GRA}\u${RS}${BC_GRN}@${RS}${BC_LT_GRA}${HOST}${RS} ${BC_GRN}"'`pscount`'" ${RS}${BC_PR}{\W}${RS} ${BC_BR}${HD}${RS}\n"
				;;
			*)
				PS1="# (\t) ?"'${?}'" !\! \u@${HOST} `pscount` {\W} ${HD}\n" # mono
				;;
		esac
		;;
	new|*)
		PROMPT_COMMAND="writetitle ${USER}@${HOST}:\`pwd\`"
		case ${TERM_COLORSET} in
			bold)
				PS1="${BC_BR}#${RS} ${BC_PR}?"'${?}'"${RS} ${BC_GRN}!\!${RS} ${BC_LT_GRA}\u${RS}${BC_CY}@${RS}${BC_LT_GRA}${HOST}${RS} ${BC_GRN}"'`pscount`'" ${RS}${BC_PR}{\W}${RS} ${BC_BR}${HD}${RS}\n"
				;;
			*)
				PS1="# ?"'${?}'" !\! \u@${HOST} `pscount` {\W} ${HD}\n" # mono
				;;
		esac
		;;
	esac
	fi
}

# cleanup
function monolith_cleanup {
	unset -f monolith_setfunc
	unset -f monolith_setcolors
	unset -f monolith_aliases
	unset -f monolith_cleanup
}

# Call setup routines
kickenv
monolith_setfunc
monolith_setcolors
monolith_aliases

print_debug fortune
if [[ -n ${PS1} ]]; then
	lyricsfile=${HOME}/.fortune/song-lyrics
	print_debug fortune_file
	if [ -f ${lyricsfile} ]; then
		chkcmd strfile
		if [ ${?} == "0" ]; then
			function lyric {
				print_debug cmp_fortune_mods
				if [ ${lyricsfile} -nt ${lyricsfile}.dat ]; then
					strfile ${lyricsfile} >& /dev/null
				fi
				fortune ${lyricsfile}
			}
		fi
		lyric
	fi
fi
setprompt

monolith_cleanup
