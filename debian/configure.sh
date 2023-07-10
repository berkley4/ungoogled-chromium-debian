#!/bin/sh
set -e

gn_disable=
gn_enable=

sys_disable=
sys_enable=

deps_disable=
deps_enable=

optional_patches='custom-import-limits march mtune'

MARCH_SET=0
POLLY_EXTRA_SET=0
RELEASE_SET=0
SYS_ICU_SET=0
XZ_EXTREME_SET=0

DEBIAN=$(dirname $0)
RT_DIR=$(dirname $DEBIAN)
UC_DIR=$DEBIAN/submodules/ungoogled-chromium

INSTALL=ungoogled-chromium.install
PRUNE_PATCH=$DEBIAN/misc_patches/no-exit-if-pruned.patch

real_dir_path () (
  OLDPWD=- CDPATH= cd -P -- $1 && pwd
)


####################
## Default values ##
####################

[ -n "$STABLE" ] || STABLE=0

[ -n "$BUNDLED_CLANG" ] || BUNDLED_CLANG=0
[ -n "$TARBALL" ] || TARBALL=0
[ -n "$TRANSLATE" ] || TRANSLATE=0

[ -n "$AES_PCLMUL" ] || AES_PCLMUL=1
[ -n "$AVX" ] || AVX=1
[ -n "$AVX2" ] || AVX2=0
[ -n "$POLLY_VECTORIZER" ] || POLLY_VECTORIZER=1
[ -n "$POLLY_PARALLEL" ] || POLLY_PARALLEL=0
[ -n "$V8_AVX2" ] || V8_AVX2=0

[ -n "$ATK_DBUS" ] || ATK_DBUS=1
[ -n "$CATAPULT" ] || CATAPULT=1
[ -n "$DRIVER" ] || DRIVER=1
[ -n "$OOP_PR" ] || OOP_PR=0
[ -n "$PDF_JS" ] || PDF_JS=0
[ -n "$POLICIES" ] || POLICIES=0
[ -n "$QT" ] || QT=1
[ -n "$WEBGPU" ] || WEBGPU=0
[ -n "$WIDEVINE" ] || WIDEVINE=1

[ -n "$OPENH264" ] || OPENH264=1
[ -n "$PIPEWIRE" ] || PIPEWIRE=1
[ -n "$PULSE" ] || PULSE=1
[ -n "$VAAPI" ] || VAAPI=1

[ -n "$SYS_JPEG" ] || SYS_JPEG=1
[ -n "$SYS_USB" ] || SYS_USB=0


# SYS_ICU is enabled by default (set to zero to disable)
[ -n "$SYS_ICU" ] && SYS_ICU_SET=1 || SYS_ICU=1

# POLLY_EXTRA is enabled if POLLY_VECTORIZER=1 (set to zero to disable)
[ -n "$POLLY_EXTRA" ] && POLLY_EXTRA_SET=1 || POLLY_EXTRA=0

# LTO Jobs (patch = 1; chromium default = all)
[ -n "$LTO_JOBS" ] || LTO_JOBS=0

# xz 'extreme' compression strategy (set to zero to disable if XZ_THREADED=1)
[ -n "$XZ_EXTREME" ] && XZ_EXTREME_SET=1 || XZ_EXTREME=0

# xz threaded compression (enabled if XZ_THREADED=1)
[ -n "$XZ_THREADED" ] || XZ_THREADED=0


# Allow overriding AUTHOR
if [ -z "$AUTHOR" ]; then
  AUTHOR='ungoogled-chromium Maintainers <github@null.invalid>'
fi

CON="$CON -e \"s;@@AUTHOR@@;$AUTHOR;\""


# By default RELEASE has a value of unstable if not explicitly set
[ -n "$RELEASE" ] && RELEASE_SET=1 || RELEASE=unstable

# If STABLE=1 then set RELEASE to stable (if not explicity set)
if [ $STABLE -eq 1 ]; then
  [ $RELEASE_SET -eq 1 ] && [ "$RELEASE" != "stable" ] || RELEASE=stable
fi



#############################
##  Fetch/Extract Tarball  ##
#############################

if [ $TARBALL -eq 1 ]; then
  TB_DIR=$(dirname $DEBIAN)

  if [ "$TB_DIR" != "tarball" ]; then
    printf '%s\n' "Cannot run outside of tarball directory"
    exit 1
  fi

  find $TB_DIR/ -mindepth 1 -maxdepth 1 \
    -type d \( -name debian -o -name out \) -prune -o -exec rm -rf "{}" +

  [ -d $TB_DIR/../download_cache ] || mkdir -p $TB_DIR/../download_cache

  if [ ! -f $TB_DIR/base/BUILD.gn ]; then
    $UC_DIR/utils/downloads.py retrieve \
      -i $UC_DIR/downloads.ini -c $DEBIAN/../../download_cache

    $UC_DIR/utils/downloads.py unpack \
      -i $UC_DIR/downloads.ini -c $TB_DIR/../download_cache $TB_DIR
  fi

  if [ ! -d $TB_DIR/chrome/build/pgo_profiles ]; then
    $TB_DIR/tools/update_pgo_profiles.py \
      --target linux update \
      --gs-url-base=chromium-optimization-profiles/pgo_profiles
  fi
fi



#######################
##  Customise build  ##
#######################

if [ $BUNDLED_CLANG -eq 0 ]; then
  clang_patches="fix-missing-symbols"

  if [ $POLLY_VECTORIZER -eq 1 ]; then
    clang_patches="$clang_patches llvm-polly-vectorizer"

    [ $POLLY_EXTRA_SET -eq 1 ] && [ $POLLY_EXTRA -eq 0 ] || POLLY_EXTRA=1

    if [ $POLLY_EXTRA -eq 1 ]; then
      clang_patches="$clang_patches llvm-polly-extra"
    fi
  fi

  if [ $POLLY_PARALLEL -eq 1 ]; then
    clang_patches="$clang_patches llvm-polly-parallel scope-bug"
  fi

  optional_patches="$optional_patches $clang_patches"

  RUL="$RUL -e \"s@^#\(.*[a-z][a-z]*_toolchain\)@\1@\""
  RUL="$RUL -e \"s@^#\(export [A-Z].*llvm-\)@\1@\""
  RUL="$RUL -e \"s@^#\(export [A-Z].*clang\)@\1@\""
  RUL="$RUL -e \"s@^#\(export DEB_C[_A-Z]*FLAGS_MAINT_SET\)@\1@\""
else
  PRU="$PRU -e \"/^third_party\/llvm/d\""
  PRU="$PRU -e \"/^tools\/clang/d\""
fi


if [ -n "$LTO_DIR" ]; then
  optional_patches="$optional_patches custom-thin-lto-cache-location"

  sed -e "s@/custom/path/to/thinlto-cache@$LTO_DIR@" \
      -i $DEBIAN/patches/optional/custom-thin-lto-cache-location.patch

  if [ ! -d $LTO_DIR ]; then
    printf '\n%s\n' "LTO_DIR: path $LTO_DIR does not exist"
  fi
fi


case $LTO_JOBS in
  [1-9]|[1-9][0-9])
    optional_patches="$optional_patches thinlto-jobs"

    case $LTO_JOBS in
      [2-9]|[1-9][0-9])
        sed "s@\(thinlto-jobs=\)1@\1$LTO_JOBS@" \
          -i $DEBIAN/patches/optional/thinlto-jobs.patch
        ;;
    esac
    ;;
esac


if [ -n "$MARCH" ] || [ -n "$MTUNE" ]; then
  [ -n "$MARCH" ] && MARCH_SET=1 || MARCH=x86-64-v2

  if [ -z "$MTUNE" ]; then
    if [ $MARCH_SET -eq 1 ]; then
      printf '%s\n' "WARN: setting MTUNE unspecified, using MTUNE=generic"
    fi

    MTUNE=generic
  fi

  for i in avx avx2 march mtune; do
    sed -e "s@\(march=\)[^"]*@\1$MARCH@" -e "s@\(mtune=\)[^"]*@\1$MTUNE@" \
        -i $DEBIAN/patches/optional/$i.patch
  done
fi


if [ $AVX2 -eq 1 ]; then
  AES_PCLMUL=1
  AVX=1
  V8_AVX2=1
  optional_patches="$optional_patches avx2"
fi

if [ $AVX -eq 1 ]; then
  AES_PCLMUL=1
  optional_patches="$optional_patches avx"
fi

if [ $AES_PCLMUL -eq 1 ]; then
  optional_patches="$optional_patches aes-pclmul"
fi

if [ $V8_AVX2 -eq 1 ]; then
  gn_enable="$gn_enable v8_enable_wasm_simd256_revec"
fi


if [ $TRANSLATE -eq 1 ]; then
  cp -a $DEBIAN/misc_patches/translate-reverse-enable.patch $DEBIAN/patches/
  cp -a $DEBIAN/shims/google-translate $DEBIAN/etc/chromium.d/

  DSB="$DSB -e \"/\/translate_manager_browsertest\.cc/d\""
  DSB="$DSB -e \"/\/translate_script\.cc/d\""
  DSB="$DSB -e \"/\/translate_util\.cc/d\""

  INS="$INS -e \"s@^#\(debian/etc/chromium.d/google-translate\)@\1@\""

  if [ -z "$(grep ^translate-reverse $DEBIAN/patches/series.debian)" ]; then
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


if [ $WEBGPU -eq 1 ]; then
  gn_enable="$gn_enable skia_use_dawn"
fi


if [ $WIDEVINE -eq 0 ]; then
  SMF="$SMF -e \"s@^\(enable_widevine=\)true@\1false@\""
fi



#################
##  Libraries  ##
#################

if [ $QT -eq 0 ]; then
  # GN_FLAGS += use_qt=false
  gn_enable="$gn_enable use_qt"
  deps_disable="$deps_disable qtbase5"
else
  optional_patches="$optional_patches qt/0001-handle_scale_factor_changes"
  optional_patches="$optional_patches qt/0002-fix_font_double_scaling"
  optional_patches="$optional_patches qt/0003-printing_deps"
  optional_patches="$optional_patches qt/0004-enable_AllowQt_feature_flag"
  optional_patches="$optional_patches qt/0005-logical_scale_factor"

  optional_deps="$optional_deps qtbase5"

  INS="$INS -e \"s@^#\(out/Release/libqt5_shim.so\)@\1@\""
fi


if [ $PIPEWIRE -eq 0 ]; then
  gn_disable="$gn_disable rtc_use_pipewire"
  deps_disable="$deps_disable libpipewire"
fi


if [ $PULSE -eq 0 ]; then
  # GN_FLAGS += link_pulseaudio=true
  gn_disable="$gn_disable link_pulseaudio"
  # GN_FLAGS += use_pulseaudio=false
  gn_enable="$gn_enable use_pulseaudio"
  deps_disable="$deps_disable libpulse"
fi


if [ $VAAPI -eq 0 ]; then
  # #GN_FLAGS += use_vaapi=false
  gn_enable="$gn_enable use_vaapi"
  deps_disable="$deps_disable libva"
else
  optional_patches="$optional_patches system/vaapi-add-av1-support"
  optional_patches="$optional_patches system/vaapi-disable-libaom-encoding"
  optional_patches="$optional_patches system/vaapi-wayland"
fi


if [ $SYS_JPEG -eq 0 ]; then
  sys_disable="$sys_disable libjpeg"
else
  optional_patches="$optional_patches system/jpeg"
fi


if [ $SYS_USB -eq 1 ]; then
  optional_patches="$optional_patches system/libusb.patch"

  gn_enable="$gn_enable libusb"
  deps_enable="$deps_enable libusb"
fi



## Items which are likely to become unstable-only as stable ages

[ $SYS_ICU_SET -eq 1 ] && [ $SYS_ICU -eq 0 ] || SYS_ICU=1

if [ $SYS_ICU -eq 1 ]; then
  icu_patches="icu icu-headers"
  icu_patches="$(echo $icu_patches | sed "s@\([^ ]*\)@system/unstable/\1@g")"
  optional_patches="$optional_patches $icu_patches"

  # SYS_LIBS += icu libxml libxslt (last two depend on icu)
  sys_enable="$sys_enable icu"
  deps_enable="$deps_enable icu libxml libxslt"

  INS="$INS -e \"s@^\(out/Release/icudtl\.dat\)@#\1@\""
fi


if [ $OPENH264 -eq 0 ]; then
  # GN_FLAGS += media_use_openh264=false
  gn_enable="$gn_enable media_use_openh264"
  sys_disable="$sys_disable openh264"
  deps_disable="$deps_disable libopenh264"
else
  optional_patches="$optional_patches system/unstable/openh264"
fi


sys_patches="libaom-headers"
sys_patches="$(echo $sys_patches | sed "s@\([^ ]*\)@system/unstable/\1@g")"
optional_patches="$optional_patches $sys_patches"

# SYS_LIBS += libaom libavif
sys_enable="$sys_enable libaom"

deps_enable="$deps_enable libaom libavif"


if [ $STABLE -eq 0 ]; then
  sys_patches="dav1d"
  sys_patches="$(echo $sys_patches | sed "s@\([^ ]*\)@system/unstable/\1@g")"
  optional_patches="$optional_patches $sys_patches"

  sys_enable="$sys_enable dav1d"
  deps_enable="$deps_enable libdav1d"
fi



########################
##  PGO profile path  ##
########################

PGO_PROF=$(cat $RT_DIR/chrome/build/linux.pgo.txt)
PGO_PATH=$(real_dir_path $RT_DIR/chrome/build/pgo_profiles)/$PGO_PROF



############################################################
##  Domain substitution, flags, pruning list and other items
############################################################

## Domain substitution
DSB="$DSB -e \"/^chrome\/browser\/flag_descriptions\.cc/d\""
DSB="$DSB -e \"/^content\/browser\/resources\/gpu\/info_view\.js/d\""
DSB="$DSB -e \"/^third_party\/depot_tools\//d\""
DSB="$DSB -e \"/^tools\/clang\//d\""


## Submodule flags
SMF="$SMF -e \"/^build_with_tflite_lib/d\""
SMF="$SMF -e \"/^chrome_pgo_phase/d\""
SMF="$SMF -e \"/^enable_hangout_services_extension/d\""
SMF="$SMF -e \"/^enable_nacl/d\""
SMF="$SMF -e \"/^enable_service_discovery/d\""
SMF="$SMF -e \"/^exclude_unwind_tables/d\""
SMF="$SMF -e \"/^google_api_key/d\""
SMF="$SMF -e \"/^google_default_client_id/d\""
SMF="$SMF -e \"/^google_default_client_secret/d\""

if [ -z "$(grep ^pgo_data_path $UC_DIR/flags.gn)" ]; then
  SMF="$SMF -e \"$ a\pgo_data_path=\x22$PGO_PATH\x22\""
fi


## Pruning
PRU="$PRU -e \"/^chrome\/build\/pgo_profiles/d\""
PRU="$PRU -e \"/^third_party\/depot_tools/d\""

if ! patch -R -p1 -f --dry-run < $PRUNE_PATCH >/dev/null 2>&1; then
  patch -p1 < $PRUNE_PATCH >/dev/null
fi


if [ $XZ_THREADED -eq 1 ]; then
  if [ -z "$(grep "dh_builddeb.*--threads-max=" $DEBIAN/rules)" ]; then
    RUL="$RUL -e \"s@^\([ \t]*dh_builddeb.*\)@\1 --threads-max=\x24(JOBS)@\""
  fi

  [ $XZ_EXTREME_SET -eq 1 ] && [ $XZ_EXTREME -eq 0 ] || XZ_EXTREME=1
fi

if [ $XZ_EXTREME -eq 1 ]; then
  if [ -z "$(grep "dh_builddeb.*-S extreme" $DEBIAN/rules)" ]; then
    RUL="$RUL -e \"s@^\([ \t]*dh_builddeb.*\)@\1 -S extreme@\""
  fi
fi



##############################
##  Aggregate sed commands  ##
##############################

if [ -n "$deps_disable" ]; then
  for i in $deps_disable; do
    CON="$CON -e \"s@^ \(${i}.*-dev\)@#\1@\""
  done
fi

if [ -n "$deps_enable" ]; then
  for i in $deps_enable; do
    CON="$CON -e \"s@^#\(${i}.*-dev\)@ \1@\""
  done
fi


if [ -n "$optional_patches" ]; then
  for i in $optional_patches; do
    SER="$SER -e \"s@^#\(optional/${i}\.patch\)@\1@\""
  done
fi


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


if [ -n "$sys_disable" ]; then
  for i in $sys_disable; do
    RUL="$RUL -e \"s@^\(SYS_LIBS += ${i}\)@#\1@\""
  done
fi

if [ -n "$sys_enable" ]; then
  for i in $sys_enable; do
    RUL="$RUL -e \"s@^#\(SYS_LIBS += ${i}\)@\1@\""
  done
fi



#####################################
##  Modify debian directory files  ##
#####################################

[ -z "$CON" ] || eval sed $CON < $DEBIAN/control.in > $DEBIAN/control

[ -z "$INS" ] || eval sed $INS < $DEBIAN/$INSTALL.in > $DEBIAN/$INSTALL

[ -z "$RUL" ] || eval sed $RUL -i $DEBIAN/rules

[ -z "$SER" ] || eval sed $SER -i $DEBIAN/patches/series.debian

[ -z "$DSB" ] || eval sed $DSB -i $UC_DIR/domain_substitution.list

[ -z "$SMF" ] || eval sed $SMF -i $UC_DIR/flags.gn

[ -z "$PRU" ] || eval sed $PRU -i $UC_DIR/pruning.list



###################################
##  Prepare miscellaneous files  ##
###################################

## Create control and ungoogled-chromium.install if they don't yet exist
[ -f $DEBIAN/control ] || cp -a $DEBIAN/control.in $DEBIAN/control

[ -f $DEBIAN/$INSTALL ] || cp -a $DEBIAN/$INSTALL.in $DEBIAN/$INSTALL
[ -x $DEBIAN/$INSTALL ] || chmod 0700 $DEBIAN/$INSTALL


## Shell launcher
if [ ! -f $DEBIAN/shims/chromium ]; then
  $DEBIAN/devutils/update_launcher.sh \
    < $DEBIAN/shims/chromium.sh > $DEBIAN/shims/chromium
fi


## Merge upstream UC patches
if [ ! -d $DEBIAN/patches/core ] || [ ! -d $DEBIAN/patches/extra ]; then
  UC_PATCH_DIRS="$UC_DIR/patches/core $UC_DIR/patches/extra"
  if [ -d $UC_DIR/patches/upstream ]; then
    UC_PATCH_DIRS="$UC_PATCH_DIRS $UC_DIR/patches/upstream"
  fi

  cp -a $UC_PATCH_DIRS $DEBIAN/patches/
fi

cat $UC_DIR/patches/series $DEBIAN/patches/series.debian \
  > $DEBIAN/patches/series


## Allow overriding VERSION
if [ -z "$VERSION" ]; then
  VER=$(cat $UC_DIR/chromium_version.txt)
  REV=$(cat $UC_DIR/revision.txt)

  case $RELEASE in
    stable)
      REV=stable$REV ;;
  esac

  VERSION=$VER-$REV
fi


## Produce changelog from template
sed -e "s;@@VERSION@@;$VERSION;" \
    -e "s;@@RELEASE@@;$RELEASE;" \
    -e "s;@@AUTHOR@@;$AUTHOR;" \
    -e "s;@@DATETIME@@;$(date -R);" \
  < $DEBIAN/changelog.in \
  > $DEBIAN/changelog



exit $?
