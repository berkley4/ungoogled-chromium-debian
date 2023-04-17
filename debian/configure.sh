#!/bin/sh
set -e

gn_disable=
gn_enable=
sys_enable=

optional_deps=
optional_patches='custom-import-limits aes-pclmul march mtune avx'

ICU_SET=0
POLLY_EXTRA_SET=0

## Default values ##
[ -n "$BUNDLED_CLANG" ] || BUNDLED_CLANG=0
[ -n "$POLLY_VECTORIZER" ] || POLLY_VECTORIZER=1
[ -n "$POLLY_PARALLEL" ] || POLLY_PARALLEL=0
[ -n "$TRANSLATE" ] || TRANSLATE=0

[ -n "$ATK_DBUS" ] || ATK_DBUS=1
[ -n "$CATAPULT" ] || CATAPULT=1
[ -n "$DRIVER" ] || DRIVER=1
[ -n "$OOP_PR" ] || OOP_PR=0
[ -n "$PDF_JS" ] || PDF_JS=0
[ -n "$POLICIES" ] || POLICIES=0
[ -n "$WIDEVINE" ] || WIDEVINE=1

[ -n "$JPEG" ] || JPEG=1
[ -n "$PIPEWIRE" ] || PIPEWIRE=1
[ -n "$PULSE" ] || PULSE=1
[ -n "$UNSTABLE" ] || UNSTABLE=0
[ -n "$USB" ] || USB=0
[ -n "$VAAPI" ] || VAAPI=1

# ICU is automatically enabled when UNSTABLE=1
[ -n "$ICU" ] && ICU_SET=1 || ICU=0

# POLLY_EXTRA is automatically enabled when POLLY_VECTORIZER=1
[ -n "$POLLY_EXTRA" ] && POLLY_EXTRA_SET=1 || POLLY_EXTRA=0


DEBIAN=$(dirname $0)



#######################
##  Customise build  ##
#######################

if [ $BUNDLED_CLANG -eq 0 ]; then
  clang_patches="fix-missing-symbols"

  if [ $POLLY_VECTORIZER -eq 1 ]; then
    clang_patches="$clang_patches llvm-polly-vectorizer"

    # Enable POLLY_EXTRA unless explicity disabled via the environment
    [ $POLLY_EXTRA_SET -eq 1 ] && [ $POLLY_EXTRA -eq 0 ] || POLLY_EXTRA=1

    if [ $POLLY_EXTRA -eq 1 ]; then
      clang_patches="$clang_patches llvm-polly-extra"
    fi
  fi

  if [ $POLLY_PARALLEL -eq 1 ]; then
    clang_patches="$clang_patches llvm-polly-parallel"
  fi

  optional_patches="$optional_patches $clang_patches"

  RUL="$RUL -e \"s@^#\(.*[a-z][a-z]*_toolchain\)@\1@\""
  RUL="$RUL -e \"s@^#\(export [A-Z].*llvm-\)@\1@\""
  RUL="$RUL -e \"s@^#\(export [A-Z].*clang\)@\1@\""
  RUL="$RUL -e \"s@^#\(export DEB_C[_A-Z]*FLAGS_MAINT_SET\)@\1@\""
fi


if [ -n "$LTO_DIR" ]; then
  optional_patches="$optional_patches custom-thin-lto-cache-location"

  sed -e "s@/custom/path/to/thinlto-cache@$LTO_DIR@" \
      -i $DEBIAN/patches/optional/custom-thin-lto-cache-location.patch

  if [ ! -d $LTO_DIR ]; then
    printf '\n%s\n' "LTO_DIR: path $LTO_DIR does not exist"
  fi
fi


if [ -n "$MARCH" ] || [ -n "$MTUNE" ]; then
  [ -n "$MARCH" ] || MARCH=x86-64-v2
  [ -n "$MTUNE" ] || MTUNE=generic

  for i in avx avx2 march mtune; do
    sed -e "s@\(march=\)[^"]*@\1$MARCH@" -e "s@\(mtune=\)[^"]*@\1$MTUNE@" \
        -i $DEBIAN/patches/optional/$i.patch
  done
fi


if [ $TRANSLATE -eq 1 ]; then
  cp -a $DEBIAN/misc_patches/translate-reverse-enable.patch $DEBIAN/patches/
  cp -a $DEBIAN/shims/google-translate $DEBIAN/etc/chromium.d/

  sed -e '/\/translate_manager_browsertest\.cc/d' \
      -e '/\/translate_script\.cc/d' \
      -e '/\/translate_util\.cc/d' \
      -i $DEBIAN/submodules/ungoogled-chromium/domain_substitution.list

  INS="$INS \"s@^#\(debian/etc/chromium.d/google-translate\)@\1@\""

  if [ -z "$(grep ^translate-reverse-enable\.patch $DEBIAN/patches/series.debian)" ]; then
    SER="$SER -e \"$ a\translate-reverse-enable.patch\""
  fi
fi



##############################
##  Non-library components  ##
##############################

if [ $ATK_DBUS -eq 0 ]; then
  optional_patches="$optional_patches disable/atk-dbus"

  # use_atk=false use_dbus=false
  gn_enable="$gn_enable use_atk"
fi


if [ $CATAPULT -eq 0 ]; then
  optional_patches="$optional_patches disable/catapult disable/rtc-protobuf"
fi


if [ $DRIVER -eq 0 ]; then
  CON="$CON -e \"/^Package: ungoogled-chromium-driver/,/^Package:/{//!d}\""
  CON="$CON -e \"/^Package: ungoogled-chromium-driver/d\""
  RUL="$RUL -e \"s@ chromedriver@@\""

  find $DEBIAN/ -maxdepth 1 -name ungoogled-chromium-driver.\* -delete
fi


if [ $OOP_PR -eq 1 ]; then
  gn_enable="$gn_enable enable_oop_basic_print_dialog"
fi


if [ $PDF_JS -eq 1 ]; then
  # pdf_enable_v8=false pdf_enable_xfa=false
  gn_disable="$gn_disable pdf_enable_v8"
fi


if [ $POLICIES -eq 1 ]; then
  INS="$INS -e \"s@^#\(.*/managed/policies\.json\)@\1@\""
fi


if [ $WIDEVINE -eq 0 ]; then
  sed -e 's@^\(enable_widevine=\)true@\1false@' \
      -i $DEBIAN/submodules/ungoogled-chromium/flags.gn
fi



#########################
##  Bundled libraries  ##
#########################

if [ $JPEG -eq 1 ]; then
  optional_patches="$optional_patches system/jpeg"
  sys_enable="$sys_enable libjpeg"
fi


if [ $PIPEWIRE -eq 0 ]; then
  gn_disable="$gn_disable rtc_use_pipewire"
fi


if [ $PULSE -eq 0 ]; then
  gn_disable="$gn_disable link_pulseaudio"
  gn_enable="$gn_enable use_pulseaudio"
fi


if [ $UNSTABLE -eq 1 ]; then
  # Enable ICU unless explicity disabled via the environment
  [ $ICU_SET -eq 1 ] && [ $ICU -eq 0 ] || ICU=1

  if [ $ICU -eq 1 ]; then
    icu_patches="icu icu-headers"
    icu_patches="$(echo $icu_patches | sed "s@\([^ ]*\)@system/unstable/\1@g")"
    optional_patches="$optional_patches $icu_patches"

    sys_enable="$sys_enable icu"

    INS="$INS -e \"s@^\(out/Release/icudtl\.dat\)@#\1@\""
  fi

  sys_patches="dav1d libaom-headers openh264"
  sys_patches="$(echo $sys_patches | sed "s@\([^ ]*\)@system/unstable/\1@g")"

  optional_patches="$optional_patches $sys_patches"
  optional_deps="$optional_deps libaom libavif libdav1d libopenh264 libxslt1"

  gn_enable="$gn_enable use_system_libpng"

  # dav1d libaom libavif libpng libxml libxslt openh264
  sys_enable="$sys_enable dav1d"

  RUL="$RUL -e \"/^RELEASE/{s/stable/unstable/}\""
fi


if [ $USB -eq 1 ]; then
  optional_patches="$optional_patches system/libusb.patch"
  gn_enable="$gn_enable libusb"
fi


if [ $VAAPI -eq 0 ]; then
  gn_enable="$gn_enable use_vaapi"
fi



#################################################
##  Aggregate dependencies, patches and flags  ##
#################################################

if [ -n "$optional_deps" ]; then
  for i in $optional_deps; do
    CON="$CON -e \"s@^#\(${i}-dev\)@ \1@\""
  done
fi


if [ -n "$optional_patches" ]; then
  for i in $optional_patches; do
    SER="$SER -e \"s@^#\(optional/${i}\.patch\)@\1@\""
  done
fi


if [ -n "$gn_disable" ] || [ -n "$gn_enable" ] || [ -n "$sys_enable" ]; then
  if [ -n "$gn_disable" ]; then
    for i in $gn_disable; do
      RUL="$RUL -e \"s@^\(GN_FLAGS += ${i}=\)@#\1@\""
    done
  fi

  if [ -n "$gn_enable" ]; then
    for i in $gn_enable; do
      RUL="$RUL -e \"s@^#\(GN_FLAGS += ${i}=\)@\1@\""
    done
  fi

  if [ -n "$sys_enable" ]; then
    for i in $sys_enable; do
      RUL="$RUL -e \"s@^#\(SYS_LIBS += ${i}\)@\1@\""
    done
  fi
fi



##########################
##  Modify build files  ##
##########################

[ -z "$CON" ] || eval sed $CON -i $DEBIAN/control.in

[ -z "$RUL" ] || eval sed $RUL -i $DEBIAN/rules

[ -z "$INS" ] || eval sed $INS -i $DEBIAN/ungoogled-chromium.install.in

[ -z "$SER" ] || eval sed $SER -i $DEBIAN/patches/series.debian



exit $?
