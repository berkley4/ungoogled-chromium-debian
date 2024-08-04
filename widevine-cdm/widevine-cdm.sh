#!/bin/sh -e

case $USER in
  root)
    printf '%s\n' "Run this script as an unprivileged user"
    exit 1 ;;
esac


url=https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

# Directory containing this script (relative to where it's executed from).
# Also force CUR_DIR to be '.' (current directory) if it evaluates to null.
CUR_DIR=${0%/*}
case $CUR_DIR in
  "")
    CUR_DIR='.' ;;
esac


# Set/check initial variables

case $CHECK in
  "")
    CHECK=0 ;;
esac

case $DL_CACHE in
  "")
    DL_CACHE=$CUR_DIR/../download_cache ;;
esac


## MAKE NEEDED DIRECTORIES

for dir in $DL_CACHE $CUR_DIR/DEB/usr/lib; do
  [ -d $dir ] || mkdir -p $dir
done


## DOWNLOAD

command -v aria2c >/dev/null 2>&1 && D_LOADER=aria2c || D_LOADER=wget

case $D_LOADER in
  aria2c)
    dl_args="-x4 -s4 -c -d $DL_CACHE" ;;

  *)
    dl_args="--continue -P $DL_CACHE" ;;
esac

$D_LOADER $dl_args $url


## EXTRACT FILES

printf '\n%s\n' "Extracting files....."

# ${url##*/} = $(basename $url)
ar p $DL_CACHE/${url##*/} data.tar.xz | \
  tar -C $CUR_DIR/DEB/usr/lib -xpJf - --strip-components 4 ./opt/google/chrome/WidevineCdm


## GET/CHECK WIDEVINE VERSION

w_man=$CUR_DIR/DEB/usr/lib/WidevineCdm/manifest.json
w_ver=$(sed -n '/"version"/s@[":,a-z ]@@gp' $w_man)

if [ $CHECK -eq 1 ]; then
  case $w_ver in
    $(apt-cache show widevine-cdm 2>/dev/null | sed -n 's@^Version: @@p'))
      printf '%s\n' "Installed version $w_ver matches upstream, not building."
      exit 0 ;;
  esac
fi


## BUILD DEB PACKAGE

sed "s/@@W_VERSION@@/$w_ver/" < $CUR_DIR/control.in > $CUR_DIR/DEB/DEBIAN/control

chmod 0755 $CUR_DIR/DEB/DEBIAN

dpkg-deb --root-owner-group -z 9 -S extreme -b $CUR_DIR/DEB \
  $CUR_DIR/widevine-cdm_${w_ver}_amd64.deb


exit $?
