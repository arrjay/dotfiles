#!/usr/bin/env bash

# prefer `g` prefix variants of likely GNU commands
____coreutil_setup () {
  local gnuutils prog
  gnuutils=(install yes whoami wc vdir unlink uniq unexpand uname tty tsort
            truncate true tr touch test tee tail tac sync sum stat split sort
            sleep shuf shred sha512sum sha384sum sha256sum sha224sum sha1sum
            seq runcon rmdir rm realpath readlink pwd ptx printf printenv pr
            pathchk paste od numfmt nohup nproc nl mv mktemp mknod mkfifo mkdir
            md5sum ls logname ln link kill join id head groups fold fmt false
            factor expr expand env echo du dirname dircolors dir dd date cut
            csplit cp comm cksum chown chmod chgrp chcon cat basename base32
            base64 b2sum df '[' stty uptime pinky users who nice timeout hostid
            chroot find xargs)
  for prog in "${gnuutils[@]}" ; do
    # shellcheck disable=SC2006
    case "`type -t "${prog}"`" in builtin|function) continue ;; esac
    chkcmd "g${prog}" && eval "${prog} () { command g${prog} \$\"{@}\" ; }"
  done
}
____coreutil_setup
unset -f ____coreutil_setup
