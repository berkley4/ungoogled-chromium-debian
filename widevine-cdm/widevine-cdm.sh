#!/bin/sh
set -e

base_url=https://dl.google.com/linux/deb/pool/main/g/google-chrome-stable

W_DIR=$(dirname $0)

[ -n "$CHECK" ] || CHECK=0
[ -n "$DL_CACHE" ] || DL_CACHE=$W_DIR/../download_cache

if [ -z "$CHROME_VER" ]; then
  printf '%s\n' "You must specify the CHROME_VER variable"
  exit 1
fi


## PREPARATION

for dir in $DL_CACHE $W_DIR/DEB/usr/lib; do
  [ -d $dir ] || mkdir -p $dir
done


## DOWNLOADING

command -v aria2c >/dev/null 2>&1 && D_LOADER=aria2c || D_LOADER=wget

dl_args="--continue -P $DL_CACHE"
[ "$D_LOADER" = "wget" ] || dl_args="-x2 -s2 -c -d $DL_CACHE"

$D_LOADER $dl_args $base_url/google-chrome-stable_${CHROME_VER}_amd64.deb


## FILE EXTRACTION

printf '\n%s\n' "Extracting files....."

ar p $DL_CACHE/google-chrome-stable_${CHROME_VER}_amd64.deb data.tar.xz | \
  tar -C $W_DIR/DEB/usr/lib -xpJf - \
      --strip-components 4 ./opt/google/chrome/WidevineCdm


## VERSION CHECKING

w_man=$W_DIR/DEB/usr/lib/WidevineCdm/manifest.json
w_ver=$(sed -n 's@.*"version": "\([^"]*\).*@\1@p' $w_man)

if [ $CHECK -eq 1 ]; then
  d_ver=$(apt-cache show widevine-cdm 2>/dev/null | sed -n 's@^Version: @@p')

  if [ "$w_ver" = "$d_ver" ]; then
    printf '%s\n' "Installed version $d_ver matches upstream, not building."
    exit 0
  fi
fi


## BUILDING

sed "s/@@W_VERSION@@/$w_ver/" < $W_DIR/control.in > $W_DIR/DEB/DEBIAN/control

chmod 0755 $W_DIR/DEB/DEBIAN

dpkg-deb --root-owner-group -z 9 -S extreme -b $W_DIR/DEB \
  $W_DIR/widevine-cdm_${w_ver}_amd64.deb


exit $?
