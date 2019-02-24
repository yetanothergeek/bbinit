  [ "$1" = '-n' ] || printf "\n\n%s\n\n" 'bbinit successfully installed!'
  
  Ramfs="$RootDir/boot/test.bbi"
  
  if [ "$Ask" = '-i' ] ; then
    printf "Shall I create an initramfs ($Ramfs) now? [Y/N]: "
    while read YN ; do
      case "$YN" in
        Y|y) YN='Y' ; break ;;
        N|n) YN='N' ; break ;;
        *) 
          printf 'Please press "Y" for "yes" or "N" for "no"\n'
          printf "Shall I create an initramfs ($Ramfs) now? [Y/N]: "          
        ;;
      esac
    done
  else
    YN='Y'
  fi
  
  if [ "$YN" = 'N' ] ; then
    echo 'Skipped creation of initramfs'
    echo 'You can create one later by running:'
    echo $UsrShareBbInit/mkramfs
    exit
  fi
  
  if [ "$1" = '-n' ] ; then
    echo
    Ramfs=$($BB mktemp -t "__DryRun__ramfs.XXXXXX" )
    echo ./$UsrShareBbInit/mkramfs $(uname -r) "$Ramfs"
    ./$UsrShareBbInit/mkramfs $(uname -r) "$Ramfs" || exit 1
    $BB rm -f "$Ramfs"
    echo
#    exit
  else
    mkdir -p $(dirname "$Ramfs")
    ./$UsrShareBbInit/mkramfs $(uname -r) "$Ramfs" || exit 1
  fi
  
  printf "\n%s %s\n\n%s\n%s\n%s\n\n" \
  'I have created an initramfs image named' \
  "$Ramfs" \
  'To boot the currently running system with bbinit,' \
  'ensure that you have a bootloader entry matching' \
  'these parameters:'
  
  for Arg in $($BB cat /proc/cmdline); do
    case "$Arg" in
      rw) printf '  %s\n' ' ro' ;;
      initrd=*)
        eval "$Arg"
        printf '  initrd=%s/%s\n' "${initrd%/*}" "${Ramfs##*/}"
      ;;
      init=*) ;;
      *) printf '  %s\n' "$Arg"
    esac
  done
  echo '  init=/etc/bb.d/init'
  echo
  echo '(At least that is my best guess.)'
  echo 'Please use your own good judgement!'
  echo

