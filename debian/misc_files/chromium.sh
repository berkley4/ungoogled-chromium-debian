#!/bin/sh -e

# Chromium launcher

# Authors:
#  Fabien Tassin <fta@sofaraway.org>
# License: GPLv2 or later

. /etc/chromium/launcher.vars

want_debug=0
want_temp=0

APP_NAME=chromium
BIN_NAME=chrome

LIBDIR=/usr/lib/$APP_NAME
CHROMIUM=$LIBDIR/$BIN_NAME

GDB=/usr/bin/gdb

nosse3="\
The hardware on this system lacks support for the sse3 instruction set.
The upstream chromium project no longer supports this configuration.
For more information, please go to https://crbug.com/1123353."

output_error() {
  case "$DISPLAY" in
    "")
      echo "$@" 1>&2 ;;

    *)
      # Prefer gxmessage over xmessage. Fallback to echo.
      XMESSAGE=echo
      if [ -x /usr/bin/gxmessage ]; then
        XMESSAGE=gxmessage
      elif [ -x /usr/bin/xmessage ]; then
        XMESSAGE=xmessage
      fi

      $XMESSAGE "$@" ;;
  esac

  exit 1
}

aggregate_features() {
  sed -z -e 's@\n@@g' -e 's@--[de][in]s*able-features=@,@g' -e 's@^,@@'
}

strip_features() {
  sed -e 's@--enable-features=[^ ]*@@g' -e 's@--disable-features=[^ ]*@@g'
}

strip_flags() {
  sed -e 's@--$flag@@' -e 's@--$flag=[^ ]*\$@@' \
      -e "s@--$flag @@g" -e "s@--$flag=[^ ]* @@g" \
      -e "s@ --$flag\$@@g" -e "s@ --$flag=[^ ]*\$@@g"
}

usage() {
  echo "$APP_NAME [-h|--help] [-g|--debug] [--temp-profile] [options] [URL]"
  echo
  echo "        -g or --debug              Start within $GDB"
  echo "        -h or --help               This help screen"
  echo "        --temp-profile             Start with a new and temporary profile"
  echo
  echo " Other supported options are:"
  MANWIDTH=80 man chromium | sed -e '1,/OPTIONS/d; /ENVIRONMENT/,$d'
  echo " See 'man chromium' for more details"
}

@PRINT_DIST@


# Do not allow root users to run this script
case $USER in
  root)
    output_error "Run this script as an unprivileged user" ;;
esac

# Only proceed if the system has an SSE3 (or PNI) capable cpu
case $(uname -m) in
  i386|i586|i686|x86_64)
    grep -q 'sse3\|pni' /proc/cpuinfo || output_error "$nosse3" ;;
esac


# Inform the chrome binary that it has been run via a wrapper script
export CHROME_WRAPPER=$0

# Set the correct file name for the desktop file
export CHROME_DESKTOP="chromium.desktop"

# Stop gnome bug-buddy intercepting crashes (see http://crbug.com/24120)
export GNOME_DISABLE_CRASH_DIALOG=SET_BY_GOOGLE_CHROME


# Set CHROME_VERSION_EXTRA text, which is displayed in the About dialog
DIST=$(print_dist)
BUILD_DIST="@BUILD_DIST@"
export CHROME_VERSION_EXTRA="built on $BUILD_DIST, running on $DIST"


read BLOCKED_FILES < /etc/chromium.d/blocked-files

# Source CHROMIUM_FLAGS from flag files
eval "
for file in /etc/chromium.d/*; do
  case \${file##*/} in
    $BLOCKED_FILES|*.dpkg-*)
      continue ;;

    blocked-flags)
      [ \$SWITCH_BLOCKING -eq 0 ] || read BLOCKED_FLAGS < \$file ;;

    *)
      . \$file ;;
  esac
done
"

# Positional parameter processing (including runtime flags)
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help | -help )
      usage
      exit 0 ;;
    -g | --debug )
      want_debug=1
      shift ;;
    --temp-profile )
      want_temp=1
      shift ;;
    --[a-z]* )
      new_flag=${1#--}
      if [ $SWITCH_BLOCKING -eq 2 ]; then
        case $BLOCKED_FLAGS in
          $new_flag|$new_flag\ *|*\ $new_flag|\ $new_flag\ *)
            new_flag= ;;
        esac
      elif [ $SWITCH_BLOCKING -eq 3 ]; then
        new_flag=
      fi
      [ -z "$new_flag" ] || CHROMIUM_FLAGS="$CHROMIUM_FLAGS $new_flag"
      shift ;;
    -- ) # Stop option prcessing
      shift
      break ;;
    * )
      break ;;
  esac
done

# Remove blocked flags if any exist within CHROMIUM_FLAGS
if [ -n "$BLOCKED_FLAGS" ]; then
  for flag in $BLOCKED_FLAGS; do
    case $CHROMIUM_FLAGS in
      --$flag|--$flag=*|*\ --$flag\ *|*\ --$flag=*|*\ --$flag)
        CHROMIUM_FLAGS="$(echo $CHROMIUM_FLAGS | strip_flags)" ;;
    esac
  done
fi


# Use a temporary profile for --disable-web-security if one isn't already specified
case $CHROMIUM_FLAGS in
  *--disable-web-security*)
    case $CHROMIUM_FLAGS in
      *--user-data-dir=*)
        : ;;

      *)
        want_temp=1 ;;
    esac ;;
esac


# Aggregate all instances of --enabled-features and --disabled-features
case $CHROMIUM_FLAGS in
  *--enable-features=*|*--disable-features=*)
    E="$(echo $CHROMIUM_FLAGS | grep -o '\-\-enable-features=[^ ]*' | aggregate_features)"
    D="$(echo $CHROMIUM_FLAGS | grep -o '\-\-disable-features=[^ ]*' | aggregate_features)"

    case $E in
      "")
        FEATURES= ;;

      *)
        FEATURES="--enable-features=$E" ;;
    esac

    case $D in
      "")
        FEATURES="$FEATURES" ;;

      *)
        FEATURES="$FEATURES --disable-features=$D" ;;
    esac

    CHROMIUM_FLAGS="$(echo $CHROMIUM_FLAGS | strip_features) $FEATURES" ;;
esac


if [ $want_debug -eq 1 ] && [ ! -x $GDB ]; then
  echo "Sorry, can't find usable $GDB. Please install it."
  exit 1
fi

if [ $want_temp -eq 1 ]; then
  TEMP_PROFILE=$(mktemp -d) && echo "Temporary profile: $TEMP_PROFILE"
  CHROMIUM_FLAGS="$CHROMIUM_FLAGS --user-data-dir=$TEMP_PROFILE"
fi

if [ $want_debug -eq 0 ]; then
  # Only use exec if we have no $TEMP_PROFILE to later delete
  [ $want_temp -eq 0 ] && exec $CHROMIUM $CHROMIUM_FLAGS "$@" || $CHROMIUM $CHROMIUM_FLAGS "$@"
else
  tmpfile=$(mktemp /tmp/chromiumargs.XXXXXX)
  trap " [ -f \"$tmpfile\" ] && /bin/rm -f -- \"$tmpfile\"" 0 1 2 3 13 15
  echo "set args $CHROMIUM_FLAGS --single-process ${1+"$@"}" > $tmpfile
  echo "# Env:"
  echo "#     LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
  echo "#                PATH=$PATH"
  echo "#            GTK_PATH=$GTK_PATH"
  echo "#      CHROMIUM_FLAGS=$CHROMIUM_FLAGS"
  echo "$GDB $CHROMIUM -x $tmpfile"
  $GDB "$CHROMIUM" -x $tmpfile
fi

[ $want_temp -eq 0 ] || rm -rf $TEMP_PROFILE


exit $?
