
BBCK_SCRIPTS_ROOT='.' ./$UsrShareBbInit/utils/bbck
if [ $? -ne 0 ]  ; then
  echo
  echo "Compatibility test for busybox failed."
  M="You could try replacing it with this one:"
  case $(uname -m) in
    x86_64|x86-64) F='busybox-x86_64';;
    i?86) F='busybox-i686';;
    *)
      F=
      M="See if you can find a replacement here:"
    ;;
  esac
  U="https://busybox.net/downloads/binaries/1.26.2-defconfig-multiarch/$F"
  echo "$M"
  echo "  $U"
  exit 1
fi
