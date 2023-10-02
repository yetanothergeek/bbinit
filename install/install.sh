#!/lib/bb/sh
# -*- mode: sh; -*-

DEBUG () { printf '%s\n' "$@" 1>&2 ; }

EtcBbD='/etc/bb.d'
UsrShareBbInit='/usr/share/bbinit'
CheckSumFile="$EtcBbD/conf/checksums"

Die () { echo "${0##*/}: ERROR: $@" 1>&2 ; exit 1 ; }

Exe=$(readlink -f $0)
[ -e "$Exe" ] || Exe=$0
cd $(dirname "$Exe")/..

. ./install/help.sh # Check command line args, etc.


# Check for a usable /lib/bb/busybox. If not, complain loudly and quit.
. ./install/chk-busybox.sh

[ "$1" = '-n' ] && sleep 2
[ "$Ask" = '-i' ] && echo "Press return to continue..." && read


# If a file or directory already exists, that's okay.
# If it doesn't exist, that's fine too.
# But if a file exists where we need a directory,
# or a directory exists where we need a file,
# that's badness, bail out now.
for Type in d f ; do
  for Obj in $(find etc/ usr/ -type $Type) ; do
  [ -e "$RootDir/$Obj" ] || continue
  [ -$Type "$RootDir/$Obj" ] || Die "Incompatible existing object: $RootDir/$Obj"
  done
done


Identical () { diff -q "$1" "$2" > /dev/null ; }


# Preserve existing file, install new version to CONFLICTS directory.
KeepFile () {
  Identical "./$1" "$RootDir/$1" && return 
  local TrgDir=$ConflictsDir/$(dirname "$1")
  $OP mkdir -p "$TrgDir"
  $OP cp -a $Ask "./$1" "$ConflictsDir/$1.new"
}


MoveToConflicts () {
  local TrgDir=$ConflictsDir/$(dirname "$1")
  $OP mkdir -p "$TrgDir"
  $OP mv $Ask "$RootDir/$1" "$ConflictsDir/$1.$2"
}


# Replace existing file, move old version to CONFLICTS directory.
ReplaceFile () {
  [ -f "./$1" ] || return
  Identical "./$1" "$RootDir/$1" && return
  [ "$2" = 'overwrite' ] || MoveToConflicts "$1" 'old'
  local TrgDir=$(dirname "$1")
  $OP mkdir -p "$RootDir/$TrgDir"
  $OP cp -a $Ask "./$1" "$RootDir/$1"
}


# File no longer exists in update, move old file to CONFLICTS directory.
DisableFile () {
  MoveToConflicts "$1" 'relic'
}

if [ -e "$RootDir$EtcBbD" ] ; then # Assume we are updating existing installation
  IsNew=0
  if [ -f "$RootDir$CheckSumFile" ] ; then
    while read Sum File ; do
      [ -e "$RootDir$File" ] || continue
      if echo "$Sum  $RootDir$File" | md5sum -c - &> /dev/null ; then
        # If file hasn't been modified since installed, mark it for deletion
        if [ -e "./$File" ] ; then
          ReplaceFile "$File" 'overwrite'
        else
          DisableFile "$File"
        fi
      else
        # Modified files /etc/bb.d/rc.local and /etc/bb.d/conf/* are retained,
        # any other modified files will be renamed to *.old
        if  [ -e "./$File" ] ; then
          case "$RootDir$File" in
            $RootDir$EtcBbD/conf/*) KeepFile "$File" ;;
            $RootDir$EtcBbD/rc.local) KeepFile "$File" ;;
            *) ReplaceFile "$File" ;;
          esac
        else
          # Modified files from the previous version that no longer exist
          # in the new version will be moved to the "CONFLICTS" directory.
          DisableFile "$File"
        fi
      fi
    done < "$RootDir$CheckSumFile"
  else
    # If we don't have a checksum file, update all files, except
    # for /etc/bb.d/rc.local and /etc/bb.d/conf/*
    for File in $(find usr/ etc/ -type f | sort) ; do
      case "$File" in
        $EtcBbD/conf/*)   KeepFile "$File" ;;
        $EtcBbD/rc.local) KeepFile "$File" ;;
        *) [ -e "$File" ] && ReplaceFile "$File" ;;
      esac
    done
  fi
else # Assume this is a first-time installation
  IsNew=1
fi

# Create a file containing the checksums of the new "pristine" files.
# We can use it on the next update to see if the user has modified anything.
if [ $1 != '-n' ] ; then
  mkdir -p $(dirname "$RootDir/$CheckSumFile")
  md5sum $(find etc/ usr/ -type f | sort) | \
    sed 's#  #  /#' > "$RootDir/$CheckSumFile"
fi

for SrcFile in $(find usr/ etc/ -type f | sort) ; do
  TrgFile="$RootDir/$SrcFile"
  TrgDir=$(dirname "$TrgFile")
  # Only install distro-specific files if their target directory already exists.
  case "$SrcFile" in 
    *usr/share/libalpm/*|*etc/kernel.d/*) [ -d  "$TrgDir" ] || continue ;;
#    *) continue;
  esac
  [ -e "$TrgFile" ] && continue
  $OP mkdir -p "$TrgDir" 
  $OP cp -a $Ask "$SrcFile" "$TrgFile"
done

if [ "$1" = '-n' ] || [ $(id -u) = 0 ] ; then
  $OP chown -R 0:0 $RootDir$EtcBbD $RootDir$UsrShareBbInit
fi


# The "inittab" and "mdev.conf" files can be regular files 
# (possibly even from another init system) or they can 
# be symlinks to our own version.
# But either way, they MUST exist in /etc !
for File in inittab mdev.conf ; do
  [ -e $RootDir/etc/$File ] || ln -s bb.d/conf/$File $RootDir/etc/$File
done

. ./install/chk-fstab.sh

[ "$Ask" = '-i' ] && echo "Press return to continue..." && read

if [ $IsNew = 1 ] ; then # Final actions and messages for new installation:
  . ./install/finish.sh
  exit 0
fi

# Final message for simulated update:
if [ "$1" = '-n' ] ; then
  echo 'Update simulation completed.'
  exit 0
fi

# Final message for updated installation:
if [ -e "$ConflictsDir" ] ; then
cat << EOF

Update is complete. Please check the contents of:
$ConflictsDir
for any changes which might break your system!
EOF
else
cat << EOF

Update is complete.
All changes were merged successfully.
EOF
fi

