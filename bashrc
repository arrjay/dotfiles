# prescribe pills to offset the shakes to offset the pills you know you should take it a day at a time
#             panic! at the disco - "nails for breakfast, tacks for snacks"
# path functions
# pathappend - add function to back of path...
# pathprepend - add function to front of path, clearing other entries if needed
# v_pathappend - this moves components... if it exists, shift to back
# v_pathprepend - this one too.
# strippath - remove path component
# internal functions
# writetitle - update xterm titlebar
# kickenv - run all variable initialization, set PATH
# gethostinfo - initialize host variables for function use, call early
# getuserinfo - initialize user variables for function use, call early
# whichery - does our version of which actually work?
# hostsetup - call host/os-specific subscripts
# chkcmd - check if specific command is present
# v_alias - overloads command with specified function
# display functions
# pscount - return count of processes on this system
# overloaded commands
# (m)which - which with function expansion (when possible)
# (m)su - su with term color change for extra attention
# cd - cd with titlebar updates (when possible)
# pushd - like cd
# popd - like cd

## environment manipulation
# dealias - undefine alias if it exists
function dealias {
	if alias|grep $1 > /dev/null
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
	if export|grep 'declare -x'|grep $1 > /dev/null
		then unset $1
	fi
}

# new functions
# push2host # copy environment files over using scp, link in to .bashrc and friends (only available in personal copies)
# httpsnarf # quick and dirty http(s) fetch [https requires openssl]
