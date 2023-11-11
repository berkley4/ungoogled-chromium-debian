#!/bin/sh
set -e

arch_patches=

deps_disable=; deps_enable=
gn_disable=; gn_enable=
op_disable=; op_enable=
sys_disable=; sys_enable=

C_VER_SET=0
MARCH_SET=0
MTUNE_SET=0
POLLY_EXT_SET=0
RELEASE_SET=0
SYS_FREETYPE_SET=0
XZ_THREADED_SET=0

DEBIAN=$(dirname $0)
RT_DIR=$(dirname $DEBIAN)

MP_DIR=$DEBIAN/misc_patches
UC_DIR=$DEBIAN/submodules/ungoogled-chromium
UC_PATCH_DIRS="$UC_DIR/patches/core $UC_DIR/patches/extra"

INSTALL=ungoogled-chromium.install

DOMSUB_PATCH=$MP_DIR/revert-New-unpack-arg-to-skip-unused-dirs.patch
PRUNE_PATCH=$MP_DIR/no-exit-if-pruned.patch

TRANSLATE_FILE=debian/etc/chromium.d/google-translate

real_dir_path () (
  OLDPWD=- CDPATH= cd -P -- $1 && pwd
)


####################
## Default values ##
####################

[ -n "$PGO" ] || PGO=1
[ -n "$STABLE" ] || STABLE=0
[ -n "$TARBALL" ] || TARBALL=0
[ -n "$TRANSLATE" ] || TRANSLATE=1
[ -n "$X11_ONLY" ] || X11_ONLY=0

[ -n "$AES_PCLMUL" ] || AES_PCLMUL=1
[ -n "$AVX" ] || AVX=1
[ -n "$AVX2" ] || AVX2=0
[ -n "$RTC_AVX2" ] || RTC_AVX2=1
[ -n "$V8_AVX2" ] || V8_AVX2=1

[ -n "$ATK_DBUS" ] || ATK_DBUS=1
[ -n "$CATAPULT" ] || CATAPULT=1
[ -n "$CLICK_TO_CALL" ] || CLICK_TO_CALL=1
[ -n "$DRIVER" ] || DRIVER=1
[ -n "$EXT_TOOLS_MENU" ] || EXT_TOOLS_MENU=1
[ -n "$FEED" ] || FEED=1
[ -n "$MUTEX_PI" ] || MUTEX_PI=1
[ -n "$OAUTH2" ] || OAUTH2=0
[ -n "$OOP_PR" ] || OOP_PR=0
[ -n "$OZONE_WAYLAND" ] || OZONE_WAYLAND=1
[ -n "$PDF_JS" ] || PDF_JS=0
[ -n "$POLICIES" ] || POLICIES=0
[ -n "$QT" ] || QT=1
[ -n "$SKIA_GAMMA" ] || SKIA_GAMMA=0
[ -n "$SPEECH" ] || SPEECH=1
[ -n "$NOTIFICATIONS" ] || NOTIFICATIONS=1
[ -n "$VR" ] || VR=0
[ -n "$WEBGPU" ] || WEBGPU=0
[ -n "$WIDEVINE" ] || WIDEVINE=1

[ -n "$OPENH264" ] || OPENH264=1
[ -n "$PIPEWIRE" ] || PIPEWIRE=1
[ -n "$PULSE" ] || PULSE=1
[ -n "$VAAPI" ] || VAAPI=1

[ -n "$SYS_CLANG" ] || SYS_CLANG=0
[ -n "$SYS_FFMPEG" ] || SYS_FFMPEG=0
[ -n "$SYS_ICU" ] || SYS_ICU=0
[ -n "$SYS_JPEG" ] || SYS_JPEG=1

# Allow freetype setting to be force-enabled (for stable builds)
[ -n "$SYS_FREETYPE" ] && SYS_FREETYPE_SET=1 || SYS_FREETYPE=1

## MARCH and MTUNE defaults
[ -n "$MARCH" ] && MARCH_SET=1 || MARCH=x86-64-v2
[ -n "$MTUNE" ] && MTUNE_SET=1 || MTUNE=generic

## POLLY_EXT is disabled if POLLY_VEC=0 or POLLY_EXT=0 (or both)
[ -n "$POLLY_EXT" ] && POLLY_EXT_SET=1 || POLLY_EXT=0
[ -n "$POLLY_VEC" ] || POLLY_VEC=1

## LTO Jobs (patch = 1; chromium default = all)
[ -n "$LTO_JOBS" ] || LTO_JOBS=0


## Package (deb) compression options
## XZ_THREADED is disabled If XZ_EXTREME=0 or XZ_THREADED=0 (or both)
[ -n "$XZ_EXTREME" ] || XZ_EXTREME=0
[ -n "$XZ_THREADED" ] && XZ_THREADED_SET=1 || XZ_THREADED=0



#########################
## Changelog variables ##
#########################

## Allow overriding AUTHOR
if [ -z "$AUTHOR" ]; then
  AUTHOR='ungoogled-chromium Maintainers <github@null.invalid>'
fi

## Also need to set AUTHOR in debian/control
CON="$CON -e \"s;@@AUTHOR@@;$AUTHOR;\""


## Set default RELEASE to unstable (if not explicitly set)
[ -n "$RELEASE" ] && RELEASE_SET=1 || RELEASE=unstable

## If STABLE=1 then set RELEASE to stable (if not explicity set)
if [ $STABLE -eq 1 ]; then
  [ $RELEASE_SET -eq 1 ] && [ "$RELEASE" != "stable" ] || RELEASE=stable
fi


## Set VERSION automatically from submodule files or manually via environment
case $VERSION in
  "")
    VER=$(cat $UC_DIR/chromium_version.txt)
    REV=$(cat $UC_DIR/revision.txt)

    case $RELEASE in
      stable)
        REV=stable$REV ;;
    esac

    VERSION=$VER-$REV
    ;;

  *)
    case $VERSION in
      -|-[0-9]|*-)
        printf '%s\n' "Malformed VERSION variable: $VERSION"
        exit 1
        ;;

      "")
        printf '%s\n' "VERSION variable is blank"
        exit 1
        ;;
    esac
    ;;
esac



################################################
##  Test mode | Clang versioning | PGO | LTO  ##
################################################

## Enter test mode if $RT_DIR/third_party does not exist
[ -d $RT_DIR/third_party ] && TEST=0 || TEST=1


## Get/set/override default clang version
C_VER_ORIG=$(sed -n 's@[ #]lld-\([^,]*\).*@\1@p' $DEBIAN/control.in)

[ -n "$C_VER" ] && C_VER_SET=1 || C_VER=$C_VER_ORIG

if [ $C_VER_SET -eq 1 ] && [ $C_VER -lt $C_VER_ORIG ]; then
  printf '%s\n' "WARN: Clang versions below $C_VER_ORIG are not supported"
  printf '%s\n' "Disabling PGO support"
  PGO=0
fi


## Set LTO cache directory and number of LTO jobs
if [ -n "$LTO_DIR" ]; then
  if [ ! -d $LTO_DIR ] && [ $TEST -eq 0 ]; then
    printf '\n%s\n' "LTO_DIR: path $LTO_DIR does not exist"
    exit 1
  fi

  op_enable="$op_enable thinlto-cache-location"

  sed -e "s@^\(+.*thinlto-cache-dir=\)[-_a-zA-Z0-9/]*@\1$LTO_DIR@" \
      -i $DEBIAN/patches/optional/thinlto-cache-location.patch
fi

case $LTO_JOBS in
  [1-9]|[1-9][0-9])
    op_enable="$op_enable thinlto-jobs"

    case $LTO_JOBS in
      [2-9]|[1-9][0-9])
        sed "s@\(thinlto-jobs=\)1@\1$LTO_JOBS@" \
          -i $DEBIAN/patches/optional/thinlto-jobs.patch
        ;;
    esac
    ;;
esac


## Set path to PGO profile
if [ $PGO -eq 1 ] && [ $TEST -eq 0 ]; then
  PGO_PROF=$(cat $RT_DIR/chrome/build/linux.pgo.txt)
  PGO_PATH=$(real_dir_path $RT_DIR/chrome/build/pgo_profiles)/$PGO_PROF
fi




#############################
##  Fetch/Extract Tarball  ##
#############################

if [ $TARBALL -eq 1 ]; then
  if [ "$RT_DIR" != "tarball" ]; then
    printf '%s\n' "Cannot run outside of tarball directory"
    exit 1
  fi

  [ -n "$DL_CACHE" ] || DL_CACHE=$RT_DIR/../download_cache
  [ -d $DL_CACHE ] || mkdir -p $DL_CACHE

  find $RT_DIR/ -mindepth 1 -maxdepth 1 \
    -type d \( -name debian -o -name out -o -name .pc \) -prune \
      -o -exec rm -rf "{}" +

  if [ ! -f $RT_DIR/base/BUILD.gn ]; then
    $UC_DIR/utils/downloads.py retrieve \
      -i $UC_DIR/downloads.ini -c $DL_CACHE

    $UC_DIR/utils/downloads.py unpack \
      -i $UC_DIR/downloads.ini -c $DL_CACHE $RT_DIR
  fi

  if [ $PGO -eq 1 ] && [ ! -d $RT_DIR/chrome/build/pgo_profiles ]; then
    $RT_DIR/tools/update_pgo_profiles.py \
      --target linux update \
      --gs-url-base=chromium-optimization-profiles/pgo_profiles
  fi
fi



###############################
## Clang/Polly configuration ##
###############################

if [ $SYS_CLANG -eq 0 ]; then
  # Polly not available on bundled toolchain
  POLLY_VEC=0

  # Stop bundled toolchain directories from being pruned
  PRU="$PRU -e \"/^third_party\/llvm/d\""
  PRU="$PRU -e \"/^tools\/clang/d\""
else
  op_enable="$op_enable system/clang/fix-missing-symbols"
  op_enable="$op_enable system/clang/clang-version-check"
  op_enable="$op_enable system/clang/rust-clanglib-local"

  CL_PATCH=$DEBIAN/patches/optional/system/clang/rust-clanglib-local.patch

  if [ $SYS_CLANG -eq 1 ]; then
    # Grab the clang version used in rust-clanglib-local.patch
    CP_VER=$(sed -n 's@.*clang/\([0-9]*\)/lib.*@\1@p' $CL_PATCH)

    # We can autodetect C_VER if it's not explicity set
    C_PATH=$(realpath $(command -v clang))
    if [ $C_VER_SET -eq 0 ]; then
      C_VER=$(echo $C_PATH | sed 's@/usr/local/bin/clang-@@')
    fi

    # Change clang version in the patch if it differs from installed version
    if [ $C_VER -ne $CP_VER ]; then
      sed "s@\(/usr/local/lib/clang/\)[^/]*\(/lib\)@\1$C_VER\2@" -i $CL_PATCH
    fi
  else
    # Check that package version $C_VER is actually installed on the system
    if [ ! -f /usr/lib/llvm-$C_VER/bin/clang ]; then
      printf '%s\n' "Cannot find /usr/lib/llvm-${C_VER}/bin/clang"
      exit 1
    fi

    # Path to libclang_rt.builtins.a
    C_LIB_DIR=/usr/lib/llvm-$C_VER/lib/clang/$C_VER/lib/linux

    # Alter patch to use $C_LIB_DIR instead of the /usr/local/lib default
    sed "s@/usr/local/lib/clang/[^/]*/lib@$C_LIB_DIR@" -i $CL_PATCH

    deps_enable="$deps_enable lld clang libclang-rt"
    op_enable="$op_enable system/clang/rust-clanglib"

    # Grab the clang version used in debian/control.in and debian/rules.in
    CC_VER=$C_VER_ORIG
    CR_VER=$(sed -n 's@.*LLVM_DIR.*/llvm-\([^/]*\)/bin@\1@p' $DEBIAN/rules.in)

    # Clang/LLVM version sanity chack
    if [ $CC_VER -ne $CR_VER ]; then
      printf '%s\n' "Clang/LLVM version mismatch in d/control.in and d/rules.in"
      exit 1
    fi

    # Change clang version in d/rules and d/control if we override version
    if [ $C_VER -ne $CR_VER ]; then
      CON="$CON -e \"s@\(lld-\)$CC_VER@\1$C_VER@\""
      CON="$CON -e \"s@\(clang-\)$CC_VER@\1$C_VER@\""
      CON="$CON -e \"s@\(libclang-rt-\)$CC_VER\(-dev\)@\1$C_VER\2@\""

      RUL="$RUL -e \"s@\(.*LLVM_DIR.*/llvm-\)$CR_VER\(/bin\)@\1$C_VER\2@\""
    fi

    # Uncomment the export of LLVM_DIR path variable
    RUL="$RUL -e \"s@^#\(export LLVM_DIR\)@\1@\""

    # Prefix clang, clang++ and llvm-{ar,nm,ranlib} with $LLVM_DIR path
    RUL="$RUL -e \"s@^\(#export [ANR].*\)\(llvm-.*\)@\1\$LLVM_DIR/\2@\""
    RUL="$RUL -e \"s@^\(#export C[CX].*\)\(clang.*\)@\1\$LLVM_DIR/\2@\""
  fi

  # Enable the local clang/llvm tool chain
  RUL="$RUL -e \"s@^#\(.*_toolchain=\)@\1@\""
  RUL="$RUL -e \"s@^#\(export [ANR].*llvm-\)@\1@\""
  RUL="$RUL -e \"s@^#\(export C[CX].*clang\)@\1@\""
  RUL="$RUL -e \"s@^#\(export DEB_C[FX].*\)@\1@\""

  if [ $POLLY_VEC -eq 1 ]; then
    [ $POLLY_EXT_SET -eq 1 ] && [ $POLLY_EXT -eq 0 ] || POLLY_EXT=1
  fi
fi


if [ $POLLY_VEC -eq 0 ]; then
  op_disable="$op_disable polly-vectorizer"
fi

if [ $POLLY_EXT -eq 0 ]; then
  op_disable="$op_disable polly-extra"
fi



#######################
## CPU optimisations ##
#######################

if [ $MARCH_SET -eq 1 ] || [ $MTUNE_SET -eq 1 ]; then
  # Save initial (default) values
  OLD_MARCH=$MARCH; OLD_MTUNE=$MTUNE

  if [ $MARCH_SET -eq 1 ] && [ $MTUNE_SET -eq 0 ]; then
    MTUNE=$MARCH
  elif [ $MARCH_SET -eq 0 ] && [ $MTUNE_SET -eq 1 ]; then
    MARCH=$MTUNE
  fi

  # Catch any quirks
  case $MARCH in
    x86-64*)
      MTUNE=generic ;;

    generic)
      MARCH=x86-64-v2
      MTUNE=generic ;;
  esac

  if [ "$OLD_MARCH" != "$MARCH" ] || [ "$OLD_MTUNE" != "$MTUNE" ]; then
    printf '%s\n' "Using: MARCH=$MARCH MTUNE=$MTUNE"
  fi
fi


## Check if we have any patches to alter due to non-default cpu options

[ "$MARCH" = "x86-64-v2" ] || arch_patches="march"
[ "$MTUNE" = "generic" ] || arch_patches="$arch_patches mtune"

[ $AVX -eq 0 ] || arch_patches="$arch_patches avx"
[ $AVX2 -eq 0 ] || arch_patches="$arch_patches avx2"


if [ -n "$arch_patches" ]; then
  for i in $arch_patches; do
    sed -e "s@\(march=\)[-a-z0-9]*@\1$MARCH@" \
        -e "s@\(mtune=\)[-a-z0-9]*@\1$MTUNE@" \
        -i $DEBIAN/patches/optional/cpu/$i.patch
  done
fi


if [ $AVX2 -eq 1 ]; then
  AES_PCLMUL=1
  AVX=1
  op_enable="$op_enable cpu/avx2"
fi

if [ $AVX -eq 0 ]; then
  op_disable="$op_disable cpu/avx"
else
  AES_PCLMUL=1
fi

if [ $AES_PCLMUL -eq 0 ]; then
  op_disable="$op_disable cpu/aes-pclmul"
fi

if [ $RTC_AVX2 -eq 0 ]; then
  # GN_FLAGS += rtc_enable_avx2=false
  gn_enable="$gn_enable rtc_enable_avx2"
fi

if [ $V8_AVX2 -eq 0 ]; then
  # GN_FLAGS += v8_enable_wasm_simd256_revec=true
  gn_disable="$gn_disable v8_enable_wasm_simd256_revec"
fi




##############################
##  Non-library components  ##
##############################

if [ $X11_ONLY -eq 1 ]; then
  OOP_PR=1
  OZONE_WAYLAND=0
fi


if [ $ATK_DBUS -eq 0 ]; then
  op_enable="$op_enable disable/atk-dbus"

  # GN_FLAGS += use_atk=false use_dbus=false
  gn_enable="$gn_enable use_atk"
fi


if [ $CATAPULT -eq 0 ]; then
  op_enable="$op_enable disable/catapult disable/rtc-protobuf"
fi


if [ $CLICK_TO_CALL -eq 0 ]; then
  op_enable="$op_enable disable/click-to-call"

  # GN_FLAGS += enable_click_to_call=false
  gn_enable="$gn_enable enable_click_to_call"
fi


if [ $DRIVER -eq 0 ]; then
  CON="$CON -e \"/^Package: ungoogled-chromium-driver/,/^Package:/{//!d}\""
  CON="$CON -e \"/^Package: ungoogled-chromium-driver/d\""
  RUL="$RUL -e \"s@ chromedriver@@\""

  find $DEBIAN/ -maxdepth 1 -name ungoogled-chromium-driver.\* -delete
fi


if [ $EXT_TOOLS_MENU -eq 0 ]; then
  op_disable="$op_disable disable/extensions-in-tools-menu"
fi


if [ $FEED -eq 0 ]; then
  # GN_FLAGS += enable_feed_v2=false
  gn_enable="$gn_enable enable_feed_v2"
fi


if [ $MUTEX_PI -eq 0 ]; then
  op_disable="$op_disable mutex-priority-inheritance"
  gn_disable="$gn_disable enable_mutex_priority_inheritance"
fi


if [ $OAUTH2 -eq 1 ]; then
  op_enable="$op_enable use-oauth2-client-switches-as-default"
fi


if [ $OOP_PR -eq 1 ]; then
  gn_enable="$gn_enable enable_oop_basic_print_dialog"
fi


if [ $OZONE_WAYLAND -eq 0 ]; then
  # GN_FLAGS += ozone_platform_wayland=false
  gn_enable="$gn_enable ozone_platform_wayland"
fi


if [ $PDF_JS -eq 1 ]; then
  # GN_FLAGS += pdf_enable_v8=false pdf_enable_xfa=false
  gn_disable="$gn_disable pdf_enable_v8"
fi


if [ $POLICIES -eq 1 ]; then
  INS="$INS -e \"s@^#\(.*/managed/policies\.json\)@\1@\""
fi


if [ $SKIA_GAMMA -eq 1 ]; then
  op_enable="$op_enable skia-gamma"
fi


if [ $SPEECH -eq 0 ]; then
  # GN_FLAGS += enable_speech_service=false
  gn_enable="$gn_enable enable_speech_service"
fi


if [ $NOTIFICATIONS -eq 0 ]; then
  # GN_FLAGS += enable_system_notifications=false
  gn_enable="$gn_enable enable_system_notifications"
fi


if [ $TRANSLATE -eq 0 ]; then
  op_disable="$op_disable translate/"

  INS="$INS -e \"s@^\($TRANSLATE_FILE\)@#\1@\""
else
  DSB="$DSB -e \"/\/translate_manager_browsertest\.cc/d\""
  DSB="$DSB -e \"/\/translate_script\.cc/d\""
  DSB="$DSB -e \"/\/translate_util\.cc/d\""

  if [ $TRANSLATE -ge 2 ]; then
    sed 's@^#\(export.*translate-script-url=\)@\1@' -i $DEBIAN/$TRANSLATE_FILE
  fi
fi


if [ $VR -eq 1 ]; then
  gn_disable="$gn_disable enable_vr"
fi


if [ $WEBGPU -eq 1 ]; then
  gn_enable="$gn_enable skia_use_dawn"
fi


if [ $WIDEVINE -eq 0 ]; then
  op_disable="$op_disable fixes/widevine/"
  SMF="$SMF -e \"s@^\(enable_widevine=\)true@\1false@\""
fi


if [ $XZ_EXTREME -eq 1 ]; then
  if [ -z "$(sed -n '/dh_builddeb.*-S extreme/p' $DEBIAN/rules.in)" ]; then
    RUL="$RUL -e \"s@^\([ \t]*dh_builddeb.*\)@\1 -S extreme@\""
  fi

  [ $XZ_THREADED_SET -eq 1 ] && [ $XZ_THREADED -eq 0 ] || XZ_THREADED=1
fi

if [ $XZ_THREADED -eq 1 ]; then
  if [ -z "$(sed -n '/dh_builddeb.*--threads-max=/p' $DEBIAN/rules.in)" ]; then
    RUL="$RUL -e \"s@^\([ \t]*dh_builddeb.*\)@\1 --threads-max=\x24(JOBS)@\""
  fi
fi



#################
##  Libraries  ##
#################

if [ $QT -eq 0 ]; then
  op_disable="$op_disable qt/"

  # GN_FLAGS += use_qt=false
  gn_enable="$gn_enable use_qt"
  deps_disable="$deps_disable qtbase5"

  INS="$INS -e \"s@^\(out/Release/libqt5_shim.so\)@#\1@\""
fi


if [ $OPENH264 -eq 0 ]; then
  op_disable="$op_disable system/openh264"

  # GN_FLAGS += media_use_openh264=false
  gn_enable="$gn_enable media_use_openh264"
  sys_disable="$sys_disable openh264"
  deps_disable="$deps_disable libopenh264"
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
  op_disable="$op_disable system/vaapi/"

  # GN_FLAGS += use_vaapi=false
  gn_enable="$gn_enable use_vaapi"
  deps_disable="$deps_disable libva"

  INS="$INS -e \"s@^\(debian/.*/drirc\.d/10-chromium\.conf\)@#\1@\""
fi



if [ $SYS_FFMPEG -eq 1 ]; then
  op_enable="$op_enable system/unstable/ffmpeg/"

  sys_enable="$sys_enable ffmpeg"
  deps_enable="$deps_enable libavutil libavcodec libavformat"
fi


if [ $SYS_JPEG -eq 0 ]; then
  op_disable="$op_disable system/jpeg"
  sys_disable="$sys_disable libjpeg"
fi



## Items which are (or are likely to become) unstable-only

if [ $STABLE -eq 1 ]; then
  SYS_ICU=0

  # Disable by default if not force-enabled
  [ $SYS_FREETYPE_SET -eq 1 ] && [ $SYS_FREETYPE -eq 1 ] || SYS_FREETYPE=0

  op_disable="$op_disable system/unstable/dav1d/"
  op_enable="$op_enable system/dav1d-bundled-header"

  sys_disable="$sys_disable dav1d"
  deps_disable="$deps_disable libdav1d"

  # Build error since v117 seemingly only affecting stable
  op_enable="$op_enable no-ELOC_PROTO-mnemonic"

  if [ $SYS_FREETYPE -eq 1 ]; then
    op_enable="$op_enable system/freetype-COLRV1"
  fi
fi


if [ $SYS_FREETYPE -eq 0 ]; then
  # SYS_LIBS += fontconfig freetype brotli libpng
  sys_disable="$sys_disable fontconfig"
  deps_disable="$deps_disable libfontconfig brotli"

  ## System libpng must be enabled separately when SYS_FREETYPE=0
  sys_enable="$sys_enable libpng"
fi


if [ $SYS_ICU -eq 0 ]; then
  op_disable="$op_disable system/unstable/icu/"
  op_enable="$op_enable system/convertutf-bundled"

  # SYS_LIBS += icu libxml libxslt
  sys_disable="$sys_disable icu"

  # libxslt1-dev will pull in libxml2-dev, which pulls in libicu-dev
  # It's not unreasonable to include libicu-dev so that it can be versioned
  deps_disable="$deps_disable libicu libxslt1"

  INS="$INS -e \"s@^#\(out/Release/icudtl\.dat\)@\1@\""
fi




##################################################
##  Domain substitution, flags and pruning list ##
##################################################

## Domain substitution
DSB="$DSB -e \"/^chrome\/browser\/flag_descriptions\.cc/d\""
DSB="$DSB -e \"/^content\/browser\/resources\/gpu\/info_view\.js/d\""
DSB="$DSB -e \"/^third_party\/depot_tools\//d\""
DSB="$DSB -e \"/^tools\/clang\//d\""


## Submodule flags
SMF="$SMF -e \"/^build_with_tflite_lib/d\""
SMF="$SMF -e \"/^enable_hangout_services_extension/d\""
SMF="$SMF -e \"/^enable_nacl/d\""
SMF="$SMF -e \"/^enable_service_discovery/d\""
SMF="$SMF -e \"/^exclude_unwind_tables/d\""
SMF="$SMF -e \"/^google_api_key/d\""
SMF="$SMF -e \"/^google_default_client_id/d\""
SMF="$SMF -e \"/^google_default_client_secret/d\""

if [ $PGO -eq 1 ]; then
  SMF="$SMF -e \"/^chrome_pgo_phase/d\""
  if [ -z "$(sed -n '/^pgo_data_path/p' $UC_DIR/flags.gn)" ]; then
    SMF="$SMF -e \"$ a\pgo_data_path=\x22$PGO_PATH\x22\""
  fi
fi


## Pruning
[ $PGO -eq 0 ] || PRU="$PRU -e \"/^chrome\/build\/pgo_profiles/d\""
PRU="$PRU -e \"/^third_party\/depot_tools/d\""




##############################
##  Aggregate sed commands  ##
##############################

## dependencies

if [ -n "$deps_disable" ]; then
  for i in $deps_disable; do
    case $i in
      *-dev)
        CON="$CON -e \"s@^[ ]*\(${i}.*-dev\)@#\1@\"" ;;

      *)
        CON="$CON -e \"s@^[ ]*\($i\)@#\1@\"" ;;
    esac
  done
fi

if [ -n "$deps_enable" ]; then
  for i in $deps_enable; do
    case $i in
      *-dev)
        CON="$CON -e \"s@^[ ]*#[ ]*\(${i}.*-dev\)@ \1@\"" ;;

      *)
        CON="$CON -e \"s@^[ ]*#[ ]*\($i\)@ \1@\"" ;;
    esac
  done
fi


## optional patches

if [ -n "$op_disable" ]; then
  for i in $op_disable; do
    case $i in
      */)
        SER="$SER -e \"s@^\(optional/${i}\)@#\1@\""
        ;;

      *)
        SER="$SER -e \"s@^\(optional/${i}\.patch\)@#\1@\""
        ;;
    esac
  done
fi

if [ -n "$op_enable" ]; then
  for i in $op_enable; do
    case $i in
      */)
        SER="$SER -e \"s@^#\(optional/${i}\)@\1@\""
        ;;

      *)
        SER="$SER -e \"s@^#\(optional/${i}\.patch\)@\1@\""
        ;;
    esac
  done
fi


## Build flags (GN_FLAGS)

if [ -n "$gn_disable" ]; then
  for i in $gn_disable; do
    case $i in
      *=true|*=false)
        RUL="$RUL -e \"s@^\(GN_FLAGS += $i\)@#\1@\""
        ;;

      *)
        RUL="$RUL -e \"s@^\(GN_FLAGS += ${i}=\)@#\1@\""
        ;;
    esac
  done
fi

if [ -n "$gn_enable" ]; then
  for i in $gn_enable; do
    case $i in
      *=true|*=false)
        RUL="$RUL -e \"s@^#\(GN_FLAGS += $i\)@\1@\""
        ;;

      *)
        RUL="$RUL -e \"s@^#\(GN_FLAGS += ${i}=\)@\1@\""
        ;;
    esac
  done
fi


## System libraries (SYS_LIBS)

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

sed -e "s;@@VERSION@@;$VERSION;" \
    -e "s;@@RELEASE@@;$RELEASE;" \
    -e "s;@@AUTHOR@@;$AUTHOR;" \
    -e "s;@@DATETIME@@;$(date -R);" \
  < $DEBIAN/changelog.in \
  > $DEBIAN/changelog

SERIES_DEBIAN="$(eval sed $SER $DEBIAN/patches/series.debian)"
echo "$(cat $UC_DIR/patches/series)" "$SERIES_DEBIAN" > $DEBIAN/patches/series

[ -z "$INS" ] || eval sed $INS < $DEBIAN/$INSTALL.in > $DEBIAN/$INSTALL

eval sed $CON < $DEBIAN/control.in > $DEBIAN/control

eval sed $RUL < $DEBIAN/rules.in > $DEBIAN/rules

eval sed $DSB -i $UC_DIR/domain_substitution.list

eval sed $SMF -i $UC_DIR/flags.gn

eval sed $PRU -i $UC_DIR/pruning.list



###################################
##  Prepare miscellaneous files  ##
###################################

## Create control, rules and ungoogled-chromium.install if they don't yet exist
[ -f $DEBIAN/control ] || cp -a $DEBIAN/control.in $DEBIAN/control
[ -f $DEBIAN/rules ] || cp -a $DEBIAN/rules.in $DEBIAN/rules
[ -f $DEBIAN/$INSTALL ] || cp -a $DEBIAN/$INSTALL.in $DEBIAN/$INSTALL

# Make sure rules and ungoogled-chromium.install are executable
[ -x $DEBIAN/rules ] || chmod 0700 $DEBIAN/rules
[ -x $DEBIAN/$INSTALL ] || chmod 0700 $DEBIAN/$INSTALL


## Shell launcher
if [ ! -f $DEBIAN/shims/chromium ] && [ $TEST -eq 0 ]; then
  $DEBIAN/devutils/update_launcher.sh \
    < $DEBIAN/shims/chromium.sh > $DEBIAN/shims/chromium
fi


## Copy upstream UC patches into debian/patches
if [ ! -d $DEBIAN/patches/core ] || [ ! -d $DEBIAN/patches/extra ]; then
  if [ -d $UC_DIR/patches/upstream ]; then
    UC_PATCH_DIRS="$UC_PATCH_DIRS $UC_DIR/patches/upstream"
  fi

  cp -a $UC_PATCH_DIRS $DEBIAN/patches/
fi


## Submodule patching
if ! patch -R -p1 -f --dry-run < $PRUNE_PATCH >/dev/null 2>&1; then
  patch -p1 < $PRUNE_PATCH >/dev/null
fi

if ! patch -p1 -f --dry-run < $DOMSUB_PATCH >/dev/null 2>&1; then
  patch -R -p1 < $DOMSUB_PATCH >/dev/null
fi


exit $?
