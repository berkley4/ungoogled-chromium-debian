#!/bin/sh -e

USAGE="Usage: ${0##*/} <clean|c|help|h>"

DL_CACHE=.download_cache

NODE_DIR=src/third_party/node
NODE_BASE_URL=http://storage.googleapis.com/chromium-nodejs
NODE_FILE=node-linux-x64.tar.gz


case $USER in
  root)
    printf '%s\n' "Run this script as an unprivileged user"
    exit 1 ;;
esac

case ${PWD##*/} in
  build)
    : ;;

  *)
    printf '%s\n' "Please run this script from the build directory"
    exit 1 ;;
esac

case $1 in
  clean|c)
    [ ! -d $NODE_DIR/linux ] || rm -rf $NODE_DIR/linux
    exit $? ;;

  help|h)
    printf '%s\n' "$USAGE"
    exit 0 ;;
esac


if [ -d $NODE_DIR/linux/node-linux-x64 ]; then
  printf '%s\n' "$NODE_DIR/linux/node-linux-x64 already exists"
  exit 1
fi

if [ ! -f src/DEPS ]; then
  printf '%s\n' "Cannot find src/DEPS"
  exit 1
fi


[ -d $DL_CACHE ] || mkdir $DL_CACHE
[ -d $NODE_DIR/linux ] || mkdir $NODE_DIR/linux


O=$(sed -n '/\/node\/linux/,/object_/s@.*_name\x27: \x27\([a-f0-9]*\).*@\1@p' src/DEPS)

NODE_URL=$NODE_BASE_URL/$O


## Prefer aria2c/fall back to wget
command -v aria2c >/dev/null 2>&1 && D_LOADER=aria2c || D_LOADER=wget

dl_args="-x1 -s1 -c -o $NODE_FILE -d $DL_CACHE"

case $D_LOADER in
  wget)
    dl_args="--continue -O $NODE_FILE -P $DL_CACHE" ;;
esac

[ -f $DL_CACHE/$NODE_FILE ] || $D_LOADER $dl_args $NODE_URL


printf '\n%s\n\n\n' "Extracting $NODE_FILE..."

tar -C $NODE_DIR/linux -xf $DL_CACHE/$NODE_FILE


exit $?
