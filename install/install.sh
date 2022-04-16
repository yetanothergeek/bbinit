#!/lib/bb/sh
# -*- mode: sh; -*-

BB=/bin/busybox

EtcBbD='/etc/bb.d'
UsrShareBbInit='/usr/share/bbinit'
CheckSumFile="$EtcBbD/conf/checksums"

Die () { echo "${0##*/}: ERROR: $@" 1>&2 ; exit 1 ; }

Exe=$(readlink -f $0)
[ -e "$Exe" ] || Exe=$0
cd $(dirname "$Exe")/..

. ./install/help.sh # Check command line args, etc.

# Try to find a unique suffix for *.new and *.old files.
# If none can be found in 000 thru 999, overwrite the oldest backup
UniqueName () {
  [ ! -e "$1" ] && echo "$1" && return
  local N=0
  local Ext=''
  while : ; do 
    Ext=$(printf "%03d" "$N")
    if [ -e "$1.$Ext" ] ; then
      N=$((N+1))
      if [ $N -gt 999 ] ; then # Already 999 backups??? Start over!
       # Overwrite oldest file that matches wildcard
       stat -c "%Y %n" $1* | sort -n | sed -ne 's/^.* //' -e '1p'
       return
      fi
    else
      echo "$1.$Ext" && return
    fi
  done
}

# Check for a usable /bin/busybox. If not, complain loudly and quit.
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


ToBeKept=$(     mktemp -t bbi-install-keep.XXXXXX )
ToBeReplaced=$( mktemp -t bbi-install-repl.XXXXXX )
ToBeRenamed=$(  mktemp -t bbi-install-back.XXXXXX )


if [ -e "$RootDir$EtcBbD" ] ; then # Assume we are updating existing installation
  IsNew=0
  if [ -f "$RootDir$CheckSumFile" ] ; then
    while read Sum File ; do
      [ -e "$RootDir$File" ] || continue
      if echo "$Sum  $RootDir$File" | md5sum -c - &> /dev/null ; then
        # If file hasn't been modified since installed, mark it for deletion
        echo "$RootDir$File" >> "$ToBeReplaced"
      else
        # Modified files /etc/bb.d/rc.local and /etc/bb.d/conf/* are retained,
        # any other modified files will be renamed to *.old
        case "$RootDir$File" in
          $RootDir$EtcBbD/conf/*) echo "$RootDir$File" >> "$ToBeKept" ;;
          $RootDir$EtcBbD/rc.local) echo "$RootDir$File" >> "$ToBeKept" ;;
          *) echo "$RootDir$File" >>  "$ToBeRenamed" ;;
        esac
      fi
    done < "$RootDir$CheckSumFile"
  else
    # If we don't have a checksum file, mark all files for deletion, except
    # for /etc/bb.d/rc.local and /etc/bb.d/conf/*
    for File in $(find usr/ etc/ -type f | sort) ; do
      File="$RootDir/$File"
      case "$File" in
        $RootDir$EtcBbD/conf/*) echo "$File" >> "$ToBeKept" ;;
        $RootDir$EtcBbD/rc.local) echo "$File" >> "$ToBeKept" ;;
        *) [ -e "$File" ] && echo "$File" >> "$ToBeReplaced" ;;
      esac
    done
  fi
else # Assume this is a first-time installation
  IsNew=1
fi


# Create any target directories that don't already exist.
for Dir in $(find usr/ etc/ -type d | sort) ; do
  $OP mkdir -p $RootDir/$Dir
done

# Create a file containing the checksums of the new "pristine" files.
# We can use it on the next update to see if the user has modified anything.
[ $1 = '-n' ] || \
md5sum $(find etc/ usr/ -type f | sort) | \
  sed 's#  #  /#' > "$RootDir/$CheckSumFile"

Rename () {
  $OP mv $Ask "$1" "$2"
}

Install () {
  $OP cp $Ask "$1" "$2"
}


for SrcFile in $(find usr/ etc/ -type f | sort) ; do
  TrgFile="$RootDir/$SrcFile"
  Handled=0
  while read OldFile ; do
    if [ "$TrgFile" = "$OldFile" ] ; then
      TrgFile=$(UniqueName $TrgFile.new)
      Handled=1
      break;
    fi
  done < "$ToBeKept"
  if [ $Handled -eq 0 ] ; then
    while read OldFile ; do
      if [ "$TrgFile" = "$OldFile" ] ; then
        Rename "$TrgFile" $(UniqueName $TrgFile.old)
        Handled=1
        break
      fi
    done < "$ToBeRenamed"
    if [ $Handled -eq 0 ] ; then
      while read OldFile ; do
        :
      done < "$ToBeReplaced"
    fi
  fi
  # Only install distro-specific files if their target directory already exists.
  case "$SrcFile" in 
    *usr/share/libalpm/*|*etc/kernel.d/*) 
      TrgDir=$(dirname "$SrcFile")
      [ -d  "$RootDir/$TrgDir" ] || continue
    ;;
    
  esac
  Install "$SrcFile" "$TrgFile"
done

rm -f "$ToBeKept" "$ToBeRenamed" "$ToBeReplaced"

if [ "$1" = '-n' ] || [ $(id -u) = 0 ] ; then
  $OP chown -R 0:0 $RootDir$EtcBbD $RootDir$UsrShareBbInit
fi


# The "inittab" and "mdev.conf" files can be real files 
# (possibly even from another init system) or they can 
# be symlinks to our own version.
# But either way, they MUST exist in /etc !
for File in inittab mdev.conf ; do
  [ -e $RootDir/etc/$File ] || ln -s bb.d/conf/$File $RootDir/etc/$File
done

Identical () {
  diff -q "$1" "$2" > /dev/null
}

for Dir in $RootDir/$EtcBbD $RootDir/$UsrShareBbInit ; do
  [ -d $Dir ] || continue
  for File in $(find $Dir -type f) ; do
    if [ -e "$File.old" ] && Identical "$File.old" "$File" ; then
      mv "$File.old" "$File"
    fi
    if [ -e "$File.new" ] && Identical "$File" "$File.new" ; then
      rm "$File.new"
    fi
  done
done


. ./install/chk-fstab.sh

[ "$Ask" = '-i' ] && echo "Press return to continue..." && read

if [ $IsNew = 1 ] ; then # Final actions and messages for new installation:
  . ./install/finish.sh
else # Final actions and messages for updated installation:
  [ "$1" = '-n' ] || cat ./install/updated.msg
fi

