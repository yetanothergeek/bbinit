#!/lib/bb/sh
# Check to see if /tmp /run and /dev/shm are mentioned in /etc/fstab.
# If not, explain to the user that they probably should be.

TmpMnts=''

HaveTmpInFsTab=0
HaveRunInFsTab=0
HaveShmInFsTab=0

if [ -f $RootDir/etc/fstab ] ; then
FsTab=$RootDir/etc/fstab
else
  echo "*** Warning: $RootDir/etc/fstab file not found."
  FsTab='/dev/null'
fi

while read Dev MtPt Typ Opts Dump Pass ; do
  case "$Dev" in
   \#*) continue
  esac
  MtPt=$(echo "$MtPt" | $BB sed -e 's#/\+#/#g' -e 's#/$##') # No // or final /
  case "$MtPt" in
    /tmp)      HaveTmpInFsTab=1 ;;
    /run)      HaveRunInFsTab=1 ;;
    /dev/shm)  HaveShmInFsTab=1 ;;
  esac
done < "$FsTab"

if [ $HaveTmpInFsTab -eq 0 ] || \
   [ $HaveRunInFsTab -eq 0 ] || \
   [ $HaveShmInFsTab -eq 0 ] ; then
cat << EOF
*** Important! ***
bbinit does not automatically mount /tmp or /run or /dev/shm
unless they are specified in $RootDir/etc/fstab.

If you need these directories to be mounted (Probably you do)
You should add entries similar to these in your /etc/fstab:

  tmp  /tmp      tmpfs  nosuid,nodev  0 0
  shm  /dev/shm  tmpfs  nosuid,nodev  0 0
  run  /run      tmpfs  nosuid,nodev,mode=0755  0 0

EOF
fi
