CWD="$(dirname "$0")"
. $CWD/rpi-funcs.sh

[ "$#" -ge 1 ] && CONFIGFILE=$1
[ -n "$CONFIGFILE" ] || die "configfile not set"
[ -r "$CONFIGFILE" ] || die "configfile not readable"

. "$CONFIGFILE"
dieIfEntryIsMissing BASEDIR

