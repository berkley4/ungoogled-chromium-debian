#!/bin/sh

# Chromium launcher

# Authors:
#  Fabien Tassin <fta@sofaraway.org>
# License: GPLv2 or later

# Anyone with an Intel GEN8+ GPU (Broadwell onwards) who is using the
# intel-media-va-driver (iHD) package and cannot get VAAPI to work
# might want to try installing the i965-va-driver package and
# uncommenting the line below.
#export LIBVA_DRIVER_NAME=i965

# Might be useful to help enable hardware video decoding in some setups.
#export LIBVA_DRI3_DISABLE=1

# Uncomment one of the following to possibly avoid the below error message
# InitializeSandbox() called with multiple threads in process gpu-process.
# If using Mesa 21.1.0 or later, uncomment the MESA_SHADER_CACHE_DISABLE line
# instead of the MESA_GLSL_CACHE_DISABLE one.
#export MESA_GLSL_CACHE_DISABLE=true
#export MESA_SHADER_CACHE_DISABLE=true

APPNAME=chromium
BINNAME=chrome

GDB=/usr/bin/gdb
LIBDIR=/usr/lib/$APPNAME

usage () {
  echo "$APPNAME [-h|--help] [-g|--debug] [--temp-profile] [options] [URL]"
  echo
  echo "        -g or --debug              Start within $GDB"
  echo "        -h or --help               This help screen"
  echo "        --temp-profile             Start with a new and temporary profile"
  echo "        --enable-remote-extensions Allow extensions from remote sites"
  echo
  echo " Other supported options are:"
  MANWIDTH=80 man chromium | sed -e '1,/OPTIONS/d; /ENVIRONMENT/,$d'
  echo " See 'man chromium' for more details"
}

@PRINT_DIST@

nosse3="\
The hardware on this system lacks support for the sse3 instruction set.
The upstream chromium project no longer supports this configuration.
For more information, please go to https://crbug.com/1123353."

case $(uname -m) in
  i386|i586|i686|x86_64)
    # Check whether this system supports sse3
    if ! grep -q sse3 /proc/cpuinfo; then
      xmessage "$nosse3"
      exit 1
    fi ;;
esac

# Source additional settings
for file in /etc/chromium.d/*; do
  case $file in
    /etc/chromium.d/*.dpkg-*|/etc/chromium.d/README)
      continue ;;
  esac
  . $file
done

# Use the /usr/bin helper script for generated launchers
case "$CHROME_WRAPPER" in
  "")
    export CHROME_WRAPPER="/usr/bin/$APPNAME" ;;
esac

# Set the correct file name for the desktop file
export CHROME_DESKTOP="chromium.desktop"

# Set CHROME_VERSION_EXTRA text, which is displayed in the About dialog
DIST=$(print_dist)
BUILD_DIST="@BUILD_DIST@"
export CHROME_VERSION_EXTRA="built on $BUILD_DIST, running on $DIST"

# Add LIBDIR to LD_LIBRARY_PATH to load libffmpeg.so (if built as a component)
case "${LD_LIBRARY_PATH:+nonempty}" in
  "")
    LD_LIBRARY_PATH=$LIBDIR ;;

  *)
    LD_LIBRARY_PATH=$LIBDIR:$LD_LIBRARY_PATH ;;
esac

export LD_LIBRARY_PATH

want_debug=0
want_temp_profile=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help | -help )
      usage
      exit 0 ;;
    -g | --debug )
      want_debug=1
      shift ;;
    --temp-profile )
      want_temp_profile=1
      shift ;;
    --enable-remote-extensions )
      CHROMIUM_FLAGS="$CHROMIUM_FLAGS --enable-remote-extensions"
      shift ;;
    -- ) # Stop option prcessing
      shift
      break ;;
    * )
      break ;;
  esac
done

if [ $want_debug -eq 1 ] && [ ! -x $GDB ]; then
  echo "Sorry, can't find usable $GDB. Please install it."
  exit 1
fi

if [ $want_temp_profile -eq 1 ]; then
  TEMP_PROFILE=$(mktemp -d)
  CHROMIUM_FLAGS="$CHROMIUM_FLAGS --user-data-dir=$TEMP_PROFILE"
  echo "Using temporary profile: $TEMP_PROFILE"
fi

if [ $want_debug -eq 1 ]; then
  tmpfile=$(mktemp /tmp/chromiumargs.XXXXXX) || { echo "Cannot create temporary file" >&2; exit 1; }
  trap " [ -f \"$tmpfile\" ] && /bin/rm -f -- \"$tmpfile\"" 0 1 2 3 13 15
  echo "set args $CHROMIUM_FLAGS --single-process ${1+"$@"}" > $tmpfile
  echo "# Env:"
  echo "#     LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
  echo "#                PATH=$PATH"
  echo "#            GTK_PATH=$GTK_PATH"
  echo "#      CHROMIUM_FLAGS=$CHROMIUM_FLAGS"
  echo "$GDB $LIBDIR/$BINNAME -x $tmpfile"
  $GDB "$LIBDIR/$BINNAME" -x $tmpfile
else
  # Use exec here as we will have no $TEMP_PROFILE to later delete
  [ $want_temp_profile -eq 1 ] || exec $LIBDIR/$BINNAME $CHROMIUM_FLAGS "$@"
  $LIBDIR/$BINNAME $CHROMIUM_FLAGS "$@"
fi

[ $want_temp_profile -eq 0 ] || rm -rf $TEMP_PROFILE

exit $?
