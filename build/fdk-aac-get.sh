#!/bin/sh -e

LIBAVCODEC_DIR=src/third_party/ffmpeg/libavcodec
USAGE="Usage: ${0##*/} <clean|c|help|h>"

case $USER in
  root)
    printf '%s\n' "Run this script as an unprivileged user"
    exit 1 ;;
esac

case $0 in
  ./fdk-aac-get.sh|fdk-aac-get.sh)
    : ;;

  *)
    printf '%s\n' "Please run this script from the directory containing it"
    exit 1 ;;
esac

case $1 in
  clean|c)
    [ ! -d $LIBAVCODEC_DIR/fdk-aac ] || rm -rf $LIBAVCODEC_DIR/fdk-aac
    exit $? ;;

  help|h)
    printf '%s\n' "$USAGE"
    exit 0 ;;
esac


if [ ! -d $LIBAVCODEC_DIR ]; then
  printf '%s\n' "Cannot find $LIBAVCODEC_DIR"
  printf '%s\n' "Fully prepare your build tree before re-running this script"
  exit 1
fi

if [ ! -d $LIBAVCODEC_DIR/fdk-aac ]; then
  cd $LIBAVCODEC_DIR
  git clone --depth 1 https://github.com/mstorsjo/fdk-aac.git
  cd - >/dev/null
fi


exit $?
