die() {
    echo 1>&2 ERROR: "$*"
    exit 1
}

dieIfEntryIsMissing() {
    eval "VALUE=\$$1"
    [ -n "$VALUE" ] || die "no $1 entry found in config"
}

_umount() {
    grep -q "$1" /proc/self/mounts && (umount -f "$1" || die "Could not umount $1")
}


_which() {
    command -v $1 || die "Unknown command $1"
}


export LANG="C" LANGUAGE="C" LC_ALL="C.UTF-8"

[ "$#" -ge 1 ] && CONFIGFILE=$1
[ -n "$CONFIGFILE" ] || die "configfile not set"
[ -r "$CONFIGFILE" ] || die "configfile not readable"

. "$CONFIGFILE"
dieIfEntryIsMissing BASEDIR

