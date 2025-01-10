#!/bin/sh -e

SCRIPT=${0##*/}
USAGE="Usage: $SCRIPT <clean|c|help|h>"

DL_CACHE=.download_cache

NODE_DIR=src/third_party/node
NODE_VER=20.18.1
NODE_URL=https://nodejs.org/dist/v$NODE_VER/node-v$NODE_VER-linux-x64.tar.xz
NODE_FILE=${NODE_URL##.*/}


case $USER in
  root)
    printf '%s\n' "Run this script as an unprivileged user"
    exit 1 ;;
esac

case $0 in
  ./$SCRIPT|$SCRIPT)
    : ;;

  *)
    printf '%s\n' "Please run this script from the directory containing it"
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


if [ -d $NODE_DIR/linux ]; then
  printf '%s\n' "$NODE_DIR/linux/node-linux-x64 already exists"
  exit 1
fi

mkdir $NODE_DIR/linux


## Prefer aria2c/fall back to wget
command -v aria2c >/dev/null 2>&1 && D_LOADER=aria2c || D_LOADER=wget

dl_args="-x1 -s1 -c -o $NODE_FILE -d $DL_CACHE"

case $D_LOADER in
  wget)
    dl_args="--continue -O $NODE_FILE -P $DL_CACHE" ;;
esac

[ -d $DL_CACHE ] || mkdir $DL_CACHE



if [ ! -f $DL_CACHE/${NODE_URL##*/} ]; then
  $D_LOADER $dl_args $NODE_URL
fi


printf '\n%s\n\n\n' "Extracting $NODE_FILE..."

tar -C $NODE_DIR/linux --transform="s/-v$NODE_VER//" -xf $DL_CACHE/$NODE_FILE



exit $?
