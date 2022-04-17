[ $# -eq 1 ] || [ $# -eq 2 ] || Die "Try '${0#*/} -h'"

OP=
Ask=

help () {
cat << EOF

Usage: ${0#*/} <option> [root-dir]
Option should be one of:
  -i   Interactive (Ask before overwriting files, etc.)
  -y   Assume "yes" to most questions.
  -n   Dry run: Show commands, but make no changes.
  -h   This help message.

root-dir is the root directory for installation.
( Defaults to / if not specified. )

EOF
exit
}

case "$1" in
  -i) Ask='-i' ;;
  -y) ;;
  -n) OP=echo ;;
  -h) help ;;
  *) Die "Try '${0#*/} -h'" ;;
esac

if [ "x$2" = 'x' ] ; then
  RootDir=
else
  case "$2" in 
    /*) ;;
    *) Die "Root path must be absolute." ;;
  esac
  RootDir=$(echo "$2" | sed -e 's#/\+#/#g' -e 's#/$##') # No // or final /
fi


[ -d $RootDir ] || Die "Invalid target directory: $RootDir"

[ "$1" = '-n' ] || \
  [ -w "$RootDir" ] || \
    [ $(id -u) = 0 ] || \
      Die "You must be root to install or update bbinit"

