#!/usr/bin/env bash

# prefer `g` prefix variants of likely coreutils commands
chkcmd gchmod     &&     chmod () { gchmod     "${@}" ; }
chkcmd gchown     &&     chown () { gchown     "${@}" ; }
chkcmd gchgrp     &&     chgrp () { gchgrp     "${@}" ; }
chkcmd gcp        &&        cp () { gcp        "${@}" ; }
chkcmd gdf        &&        df () { gdf        "${@}" ; }
chkcmd gdu        &&        du () { gdu        "${@}" ; }
chkcmd gexpr      &&      expr () { gexpr      "${@}" ; }
chkcmd gid        &&        id () { gid        "${@}" ; }
chkcmd gls        &&        ls () { gls        "${@}" ; }
chkcmd gmd5sum    &&    md5sum () { gmd5sum    "${@}" ; }
chkcmd gmv        &&        mv () { gmv        "${@}" ; }
chkcmd grm        &&        rm () { grm        "${@}" ; }
chkcmd gsha1sum   &&   sha1sum () { gsha1sum   "${@}" ; }
chkcmd gsha256sum && sha256sum () { gsha256sum "${@}" ; }
chkcmd gsha512sum && sha512sum () { gsha512sum "${@}" ; }
chkcmd gtail      &&      tail () { gtail      "${@}" ; }
chkcmd gwc        &&        wc () { gwc        "${@}" ; }

# find is findutils, but...similar.
chkcmd gfind  &&  find () { gfind  "${@}" ; }
chkcmd gxargs && xargs () { gxargs "${@}" ; }
