#!/bin/sh -e

case $USER in
  root)
    printf '%s\n' "ERROR: Run this script as an unprivileged user"
    exit 1 ;;
esac


arch_patches=

deps_disable=; deps_enable=
gn_disable=; gn_enable=
ins_disable=; ins_enable=
op_disable=; op_enable=
sys_disable=; sys_enable=

SER_DB=; SER_U=; SERIES_DB=; SERIES_UC=

BLUEZ_SET=0
BUILD_TS_SET=0
CLANG_VER_SET=0
DBUS_SET=0
MARCH_SET=0
MEDIA_REMOTING_SET=0
MTUNE_SET=0
POLLY_SET=0
RELEASE_SET=0
SYS_BROTLI_SET=0
SYS_DRM_SET=0
SYS_ICU_SET=0
SYS_WEBP_SET=0

LLVM_PGO_VER=20

# ${example%/*} = $(dirname example)
DEBIAN=$(OLDPWD=- CDPATH= cd -P -- ${0%/*} && pwd)
RT_DIR=${DEBIAN%/*}

FLAG_DIR=$DEBIAN/etc/chromium.d
M_DIR=$DEBIAN/misc_files
OP_DIR=$DEBIAN/patches/optional
OUT_DIR=$RT_DIR/out/Release

UC_DIR=$DEBIAN/submodules/ungoogled-chromium
UC_P_DIRS="$UC_DIR/patches/core $UC_DIR/patches/extra"

INSTALL=ungoogled-chromium.install
POLICIES=etc/chromium/policies/managed/policies.json


####################
## Default values ##
####################

[ -n "$CCACHE" ] || CCACHE=0
[ -n "$ESBUILD" ] || ESBUILD=0
[ -n "$PGO" ] || PGO=1
[ -n "$STABLE" ] || STABLE=0
[ -n "$SYMBOLS" ] || SYMBOLS=0
[ -n "$SYMBOLS_BLINK" ] || SYMBOLS_BLINK=0
[ -n "$SYS_CLANG" ] || SYS_CLANG=0
[ -n "$SYS_RUST" ] || SYS_RUST=0
[ -n "$SYS_BINDGEN" ] || SYS_BINDGEN=2
[ -n "$SYS_GN" ] || SYS_GN=1
[ -n "$SYS_NODE" ] || SYS_NODE=0

[ -n "$AES_PCLMUL" ] || AES_PCLMUL=1
[ -n "$AVX" ] || AVX=1
[ -n "$AVX2" ] || AVX2=0
[ -n "$RTC_AVX2" ] || RTC_AVX2=1
[ -n "$V8_AVX2" ] || V8_AVX2=1

[ -n "$INTEL_CET" ] || INTEL_CET=1
[ -n "$MEDIA_OPT_SPEED" ] || MEDIA_OPT_SPEED=1
[ -n "$MF_SPLIT" ] || MF_SPLIT=1

[ -n "$ATK" ] || ATK=1
[ -n "$CATAPULT" ] || CATAPULT=0
[ -n "$CHROMECAST" ] || CHROMECAST=0
[ -n "$CLICK_TO_CALL" ] || CLICK_TO_CALL=1
[ -n "$DRIVER" ] || DRIVER=1
[ -n "$ENTERPRISE_WATERMARK" ] || ENTERPRISE_WATERMARK=0
[ -n "$FAST_RESTART" ] || FAST_RESTART=0
[ -n "$FONTATIONS" ] || FONTATIONS=1
[ -n "$FONTATIONS_PDF" ] || FONTATIONS_PDF=1
[ -n "$GL_DESKTOP_FRONTEND" ] || GL_DESKTOP_FRONTEND=0
[ -n "$GOOGLE_API_KEYS" ] || GOOGLE_API_KEYS=1
[ -n "$GOOGLE_UI_URLS" ] || GOOGLE_UI_URLS=1
[ -n "$GRCACHE_PURGE" ] || GRCACHE_PURGE=0
[ -n "$HEADLESS" ] || HEADLESS=1
[ -n "$HLS_PLAYER" ] || HLS_PLAYER=1
[ -n "$HYPHENATION" ] || HYPHENATION=1
[ -n "$IDB_FG_CLIENT_BOOST" ] || IDB_FG_CLIENT_BOOST=1
[ -n "$LENS" ] || LENS=0
[ -n "$LENS_TRANSLATE" ] || LENS_TRANSLATE=1
[ -n "$LOCALES_EXTRA" ] || LOCALES_EXTRA=1
[ -n "$MCLICK_AUTOSCROLL" ] || MCLICK_AUTOSCROLL=1
[ -n "$MUTEX_PI" ] || MUTEX_PI=1
[ -n "$NO_SYS_LIBS" ] || NO_SYS_LIBS=0
[ -n "$OAUTH2" ] || OAUTH2=0
[ -n "$OPENTYPE_SVG" ] || OPENTYPE_SVG=0
[ -n "$OZONE_WAYLAND" ] || OZONE_WAYLAND=1
[ -n "$PART_LOCK_PI" ] || PART_LOCK_PI=1
[ -n "$PDF_JS" ] || PDF_JS=0
[ -n "$PIPEWIRE" ] || PIPEWIRE=1
[ -n "$PRINT_PREVIEW" ] || PRINT_PREVIEW=1
[ -n "$PULSE" ] || PULSE=1
[ -n "$QT" ] || QT=1
[ -n "$RUSTY_PNG" ] || RUSTY_PNG=1
[ -n "$SKIA_GAMMA" ] || SKIA_GAMMA=0
[ -n "$SPEECH" ] || SPEECH=1
[ -n "$SPOOF_WEBGL_INFO" ] || SPOOF_WEBGL_INFO=1
[ -n "$SWIFTSHADER" ] || SWIFTSHADER=1
[ -n "$SWIFTSHADER_VULKAN" ] || SWIFTSHADER_VULKAN=1
[ -n "$SWIFTSHADER_WEBGPU" ] || SWIFTSHADER_WEBGPU=1
[ -n "$SWITCH_BLOCKING" ] || SWITCH_BLOCKING=1
[ -n "$SYS_NOTIFICATIONS" ] || SYS_NOTIFICATIONS=1
[ -n "$TP_STORAGE_PART" ] || TP_STORAGE_PART=1
[ -n "$TRANSLATE" ] || TRANSLATE=1
[ -n "$VR" ] || VR=0
[ -n "$VAAPI" ] || VAAPI=1
[ -n "$VULKAN" ] || VULKAN=1
[ -n "$WEBASSEMBLY" ] || WEBASSEMBLY=0
[ -n "$WEBFEED" ] || WEBFEED=1
[ -n "$WEBGPU" ] || WEBGPU=0
[ -n "$WIDEVINE" ] || WIDEVINE=1
[ -n "$XZ_EXTREME" ] || XZ_EXTREME=0


if [ $NO_SYS_LIBS -eq 1 ]; then
  # Zero all SYS_* library variables before any are declared later on
  for i in SYS_BROTLI SYS_DRM SYS_ICU SYS_JPEG SYS_OPENH264 SYS_WEBP SYS_ZSTD VAAPI; do
    eval $i=0
  done

  # Disable dependencies for system libraries without configuration variables
  for i in double-conversion libflac libopus libpng libsecret libusb libXNVCtrl; do
    deps_disable="$deps_disable $i"
  done

  # Disable the unbundle toolchain, sys library GN_FLAGS and non-configurable SYS_LIBS
  RUL="$RUL -e \"/_toolchain=/s@^@#@\" -e \"/^[^#].*use_system/s@^@#@\""
  RUL="$RUL -e \"/^SYS_LIBS.*double-conversion/s@^@#@\""
fi

[ -n "$SYS_JPEG" ] || SYS_JPEG=1
[ -n "$SYS_ZSTD" ] || SYS_ZSTD=1

## Allow force-enabling brotli for stable users who have installed my deb packages
[ -n "$SYS_BROTLI" ] && SYS_BROTLI_SET=1 || SYS_BROTLI=1

## Allow force-enabling libdrm for stable users who have installed libdrm from backports
[ -n "$SYS_DRM" ] && SYS_DRM_SET=1 || SYS_DRM=1

## Allow stable users to force enable icu (eg if they have self-compiled an icu package)
[ -n "$SYS_ICU" ] && SYS_ICU_SET=1 || SYS_ICU=1

## Allow force-enabling libwebp for stable users who have installed libsharpyuv from backports
[ -n "$SYS_WEBP" ] && SYS_WEBP_SET=1 || SYS_WEBP=1

## Need to error out if MEDIA_REMOTING is explicitly enabled when CHROMECAST=0
[ -n "$MEDIA_REMOTING" ] && MEDIA_REMOTING_SET=1 || MEDIA_REMOTING=0

## OpenH264 support
[ -n "$OPENH264" ] && [ $OPENH264 -eq 0 ] && SYS_OPENH264=0 || OPENH264=1
[ -n "$SYS_OPENH264" ] || SYS_OPENH264=1

## FFmpeg codecs
FF_AC="aac"

FF_AAC=1
[ -n "$FF_AC3" ] || FF_AC3=1
[ -n "$FF_AC4" ] || FF_AC4=0
[ -n "$FF_ALAC" ] || FF_ALAC=0
[ -n "$FF_FDK" ] || FF_FDK=0
[ -n "$FF_HEVC" ] || FF_HEVC=1

## MARCH and MTUNE defaults
[ -n "$MARCH" ] && MARCH_SET=1 || MARCH=x86-64-v2
[ -n "$MTUNE" ] && MTUNE_SET=1 || MTUNE=generic

# Clang Polly defaults
[ -n "$POLLY" ] && POLLY_SET=1 || POLLY=0

## LTO Jobs (patch = 1; chromium default = all)
[ -n "$LTO_JOBS" ] || LTO_JOBS=0

## Managed Policy: Capture of audio/video/screen (eg for WebRTC)
[ -n "$CAP" ] && [ $CAP -eq 0 ] && CAP_AUD=0 && CAP_SCR=0 && CAP_VID=0 || CAP=1
[ -n "$CAP_AUD" ] || CAP_AUD=1
[ -n "$CAP_SCR" ] || CAP_SCR=1
[ -n "$CAP_VID" ] || CAP_VID=1

## Managed Policy: Block all downloads
[ -n "$DL_RESTRICT" ] || DL_RESTRICT=0

## Managed Policy: DNS_BUILTIN can be enabled by editing the managed policy file
[ -n "$DNS_BUILTIN" ] || DNS_BUILTIN=0
[ -n "$DNS_HOST" ] || DNS_HOST=
[ -n "$DNS_INTERCEPT" ] || DNS_INTERCEPT=1

## DNS config service
[ -n "$DNS_CONFIG" ] || DNS_CONFIG=0


## Disable non-free stuff if NON_FREE=0
[ -n "$NON_FREE" ] || NON_FREE=1

if [ $NON_FREE -eq 0 ]; then
  sed -e '/EnforceNoopenerOnBlobURLNavigation/s@^#@@' -i $FLAG_DIR/isolation

  SER_DB="$SER_DB -e \"s@^\(cromite/\)@#\1@\" -e \"s@^\(vanadium/\)@#\1@\""

  if [ $FF_FDK -eq 1 ]; then
    printf '%s\n' "ERROR: Cannot set FF_FDK=0 when NON_FREE=0"
    exit 1
  fi

  if [ $OPENH264 -eq 1 ] && [ $SYS_OPENH264 -eq 0 ]; then
    printf '%s\n' "ERROR: Cannot set SYS_OPENH264=1 when NON_FREE=0"
    exit 1
  fi
fi


## X11_ONLY=1 is an alias for OZONE_WAYLAND=0
## Note that OZONE_WAYLAND=1 is experimental and wayland users
## can also set X11_ONLY=1 (or alternatively OZONE_WAYLAND=0)
[ -n "$X11_ONLY" ] && [ $X11_ONLY -eq 1 ] && OZONE_WAYLAND=0 || X11_ONLY=0


## Make NOTIFICATIONS an alias for DBUS (but have DBUS take precedence)
[ -n "$DBUS" ] && DBUS_SET=1 || DBUS=1
[ -z "$NOTIFICATIONS" ] || [ $DBUS_SET -eq 1 ] || DBUS=$NOTIFICATIONS


## Check if BLUEZ is explicitly set
[ -n "$BLUEZ" ] && BLUEZ_SET=1 || BLUEZ=1

## DBUS=0 will (implicitly) disable BLUEZ
## Only error out if BLUEZ is explicitly enabled when DBUS=0
if [ $BLUEZ_SET -eq 1 ] && [ $BLUEZ -eq 1 ] && [ $DBUS -eq 0 ]; then
  printf '%s\n' "ERROR: Cannot set BLUEZ=1 when DBUS=0 (BLUEZ depends on DBUS)"
  exit 1
fi


if [ $QT -ge 1 ]; then
  [ $QT -ne 6 ] || QT_6=1

  # Default to using Qt 5
  [ -n "$QT_6" ] || QT_6=0

  # Bail out if QT_6=1 and STABLE=1
  if [ $QT_6 -eq 1 ] && [ $STABLE -eq 1 ]; then
    printf '%s\n' "ERROR: Cannot set QT_6=1 when STABLE=1"
    exit 1
  fi
fi


if [ $FONTATIONS -eq 0 ] && [ $FONTATIONS_PDF -eq 1 ]; then
  printf '%s\n' "ERROR: Cannot set FONTATIONS_PDF=1 when FONTATIONS=0"
  exit 1
fi


if [ $MUTEX_PI -eq 0 ] && [ $PART_LOCK_PI -eq 1 ]; then
  printf '%s\n' "ERROR: Cannot set PART_LOCK_PI=1 when MUTEX_PI=0"
  exit 1
fi


if [ -n "$TIMESTAMP" ] && [ -n "$BUILD_TS" ] && [ $BUILD_TS -lt 2 ]; then
  printf '%s\n' "ERROR: Cannot set TIMESTAMP when BUILD_TS=$BUILD_TS"
  exit 1
fi

case $TIMESTAMP in
  [1-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
    BUILD_TS=2 ;;

  "")
    # This is inert as we test for TIMESTAMP > 0 in the main BUILD_TS section
    TIMESTAMP=0 ;;

  *)
    printf '%s\n' "ERROR: Invalid value for TIMESTAMP: $TIMESTAMP"
    exit 1 ;;
esac


[ -n "$BUILD_TS" ] && BUILD_TS_SET=1 || BUILD_TS=0




## Enter test mode if $RT_DIR/third_party does not exist
[ -d $RT_DIR/third_party ] && TEST=0 && DEPS_PATCH=0 || TEST=1

# Allow setting DEPS_PATCH when TEST=1
[ -n "$DEPS_PATCH" ] || DEPS_PATCH=0


if [ $TEST -eq 0 ]; then
  ## Get clang_version from build/toolchain/toolchain.gni when TEST=0
  tc_gni=$RT_DIR/build/toolchain/toolchain.gni
  LLVM_PGO_VER=$(sed -n '/clang_version =/h; ${x;s@[ _="a-z]@@gp;}' $tc_gni)

  # Check that hyphenation files are present when HYPHENATION=1
  hyphen_dir=$RT_DIR/third_party/hyphenation-patterns
  if [ $HYPHENATION -eq 1 ] && [ ! -f $hyphen_dir/hyb/hyph-en-us.hyb ]; then
    printf '%s\n' "Please run build/hyphen-data-get-sh to generate the data files"
    exit 1
  fi
fi



#########################
## Changelog variables ##
#########################

## Allow overriding AUTHOR
case $AUTHOR in
  "")
    AUTHOR='ungoogled-chromium Maintainers <github@null.invalid>' ;;
esac

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
    read VER < $UC_DIR/chromium_version.txt
    read REV < $UC_DIR/revision.txt

    case $RELEASE in
      stable)
        REV=stable$REV ;;
    esac

    VERSION=$VER-$REV ;;

  -|-[1-9]|-stable[1-9]|*-)
    printf '%s\n' "ERROR: Malformed VERSION variable: $VERSION"
    exit 1 ;;
esac




###############################################
## LTO | Symbol levels | Package compression ##
###############################################

## Set LTO cache directory and number of LTO jobs
if [ -n "$LTO_DIR" ]; then
  if [ $TEST -eq 0 ] && [ ! -d $LTO_DIR ]; then
    printf '\n%s\n' "ERROR: LTO_DIR path $LTO_DIR does not exist"
    exit 1
  fi

  op_enable="$op_enable compiler-flags/thinlto-cache-location.patch"

  sed -e "s@_thinlto_cache_dir@$LTO_DIR@" \
      -i $OP_DIR/compiler-flags/thinlto-cache-location.patch
fi

case $LTO_JOBS in
  [1-9]|[1-9][0-9])
    op_enable="$op_enable compiler-flags/thinlto-jobs.patch"

    case $LTO_JOBS in
      [2-9]|[1-9][0-9])
        sed "s@\(thinlto-jobs=\)1@\1$LTO_JOBS@" \
          -i $OP_DIR/compiler-flags/thinlto-jobs.patch ;;
    esac ;;
esac



## Set Symbol levels
case $SYMBOLS in
  -1|[1-2])
    RUL="$RUL -e \"/[^_]symbol_level=/s@=0@=$SYMBOLS@\"" ;;
esac

case $SYMBOLS_BLINK in
  -1|[1-2])
    RUL="$RUL -e \"/blink_symbol_level=/s@=0@=$SYMBOLS_BLINK@\"" ;;
esac



if [ $XZ_EXTREME -eq 1 ]; then
  RUL="$RUL -e \"/dh_builddeb /s@\(.*\)@\1 -S extreme@\""
fi




###################################################################
## Clang/ESbuild/gn/Machine Function Splitter/Rust configuration ##
###################################################################

## Enable the use of ccache
if [ $CCACHE -eq 1 ]; then
  gn_enable="$gn_enable cc_wrapper="
  RUL="$RUL -e \"/^#export PATH/s@^#@@\""

  case $CCACHE_BASEDIR in
    ""|0|1)
      RUL="$RUL -e \"/CCACHE_BASEDIR=/s@_CCACHE_BASEDIR@\x24\x28RT_DIR\x29@\"" ;;

    /*)
      RUL="$RUL -e \"/CCACHE_BASEDIR=/s@_CCACHE_BASEDIR@$CCACHE_BASEDIR@\"" ;;
  esac

  case $CCACHE_BASEDIR in
    /*|1)
      RUL="$RUL -e \"/^#export CCACHE_BASEDIR=/s@^#@@\"" ;;
  esac

  [ $BUILD_TS_SET -eq 1 ] || BUILD_TS=1
fi


if [ $BUILD_TS -eq 1 ]; then
  op_enable="$op_enable build-timestamp/use-non-official-build-timestamp.patch"
elif [ $BUILD_TS -eq 2 ]; then
  if [ $TIMESTAMP -gt 0 ]; then
    sed "/print/s@[0-9][0-9]*@$TIMESTAMP@" \
      -i $OP_DIR/build-timestamp/compute-fixed-build-timestamp.patch
  fi
  op_enable="$op_enable build-timestamp/compute-fixed-build-timestamp.patch"
fi


if [ $ESBUILD -ge 0 ]; then
  # Avoid the hassle of having to re-obtain after deletion
  PRU_PY="$PRU_PY -e \"/third_party\/esbuild\//d\""

  if [ $ESBUILD -eq 1 ]; then
    op_enable="$op_enable enable-esbuild-for-official-builds.patch"
    gn_enable="$gn_enable devtools_fast_bundle=true"
  fi
fi


if [ $SYS_CLANG -eq 0 ]; then
  # Polly not available on bundled toolchain
  if [ $POLLY -eq 1 ]; then
    printf '%s\n' "ERROR: when SYS_CLANG=0 you cannot set POLLY=1"
    exit 1
  fi

  # Stop bundled toolchain directories from being pruned
  PRU="$PRU -e \"/^tools\/clang/d\""
  PRU_PY="$PRU_PY -e \"/third_party\/llvm\//d\""

  LLVM_VER=$LLVM_PGO_VER
else
  # Default enable POLLY when SYS_CLANG > 0 unless explicitly disabled
  [ $POLLY_SET -eq 1 ] && [ $POLLY -eq 0 ] || POLLY=1

  ## Check for clang binary existence and PGO compatibility

  LLVM_CTRL_VER=$(sed -n '/^#clang-/s@[-#,a-z]@@gp' $DEBIAN/control.in)

  case $CLANG_VER in
    "")
      CLANG_VER=$LLVM_CTRL_VER ;;

    [1-9][0-9]*)
      CLANG_VER=${CLANG_VER%%.*}
      CLANG_VER_SET=1 ;;

    *)
      printf '%s\n' "ERROR: malformed CLANG_VER variable $CLANG_VER"
      exit 1 ;;
  esac

  LLVM_BASE_DIR=/usr/lib/llvm-$CLANG_VER
  [ $SYS_CLANG -eq 1 ] || LLVM_BASE_DIR=/usr/local

  if [ $TEST -eq 0 ]; then
    if [ $CLANG_VER_SET -eq 0 ]; then
      # If CLANG_VER has NOT been set explicity then set LLVM_VER via querying the clang binary
      LLVM_VER=$($LLVM_BASE_DIR/bin/clang --version | sed -n 's@.*version \([^.]*\).*@\1@p')
    else
      # If CLANG_VER has been set explicity then trust the version and do a quick usability check
      if [ ! -x $LLVM_BASE_DIR/bin/clang ]; then
        printf '%s\n' "ERROR: Cannot find $LLVM_BASE_DIR/bin/clang"
        exit 1
      fi
    fi
  fi

  # Start using LLVM_VER instead of CLANG_VER now that the actual version is known
  [ -n "$LLVM_VER" ] || LLVM_VER=$CLANG_VER

  if [ $PGO -eq 1 ] && [ $LLVM_VER -lt $LLVM_PGO_VER ]; then
    printf '%s\n' "ERROR: Clang versions below $LLVM_PGO_VER are incompatible with PGO"
    exit 1
  fi

  ## Set optional patches, build flags and format d/rules and d/control
  op_enable="$op_enable system/clang/clang-version-check.patch"
  gn_enable="$gn_enable clang_base_path= custom_toolchain= host_toolchain="

  RUL="$RUL -e \"/^#export LLVM_DIR /s@^#@@\""
  RUL="$RUL -e \"/^#export.*:= \x24\x28LLVM_DIR\x29\//s@^#@@\""
  RUL="$RUL -e \"/^#export.*_MAINT_SET/s@^#@@\""

  RUL="$RUL -e \"s@_LLVM_BASE_DIR@$LLVM_BASE_DIR@\""

  if [ $PGO -eq 1 ] && [ $LLVM_VER -ne $LLVM_PGO_VER ]; then
    gn_enable="$gn_enable clang_version="
    RUL="$RUL -e \"s@_LLVM_VER@$LLVM_VER@\""

    printf '%s\n' "INFO: Using clang $LLVM_VER"
  fi

  if [ $SYS_CLANG -eq 1 ]; then
    op_enable="$op_enable system/clang/rust-clanglib.patch"
    deps_enable="$deps_enable lld clang libclang-rt"

    # Change version in d/control and d/rules if LLVM_CTRL_VER & LLVM_VER differ
    if [ $LLVM_CTRL_VER -ne $LLVM_VER ]; then
      CON="$CON -e \"/^#lld-/s@$LLVM_CTRL_VER@$LLVM_VER@\""
      CON="$CON -e \"/^#clang-/s@$LLVM_CTRL_VER@$LLVM_VER@\""
      CON="$CON -e \"/^#libclang-rt-/s@$LLVM_CTRL_VER@$LLVM_VER@\""
    fi
  fi
fi


if [ $LLVM_VER -ge 19 ]; then
  # Do not apply hardware destructive interference patch for clang versions >= 19
  P=hardware_destructive_interference_size.patch
  SER_UC="$SER_UC -e \"/^upstream-fixes\/$P/s@^@#@\""
else
  # Enable the non-hdis version of the enum table patch for older clang versions
  op_disable="$op_disable fixes/enum-table-crash-hdis.patch"
  op_enable="$op_enable fixes/enum-table-crash.patch"
fi


if [ $SYS_RUST -ge 1 ]; then
  op_enable="$op_enable optional/system/rust.patch"

  # GN_FLAGS += rust_sysroot_absolute=\"$(RUST_PATH)\" rustc_version=\"$(RUST_VER)\"
  gn_enable="$gn_enable rust_sysroot_absolute="

  RUST_PATH="$HOME/.cargo"

  if [ $SYS_RUST -eq 1 ]; then
    deps_enable="$deps_enable rustc"

    RUST_PATH="/usr"
  fi

  if [ $TEST -eq 0 ] && [ ! -x $RUST_PATH/bin/rustc ]; then
    printf '%s\n' "ERROR: $RUST does not exist (or is not executable)"
    exit 1
  fi

  # Enable getting rust version string via d/rules (for passing to a build flag)
  RUL="$RUL -e \"/^#RUST_PATH /s@^#@@\""
  RUL="$RUL -e \"/^RUST_PATH /s@_RUST_PATH@$RUST_PATH@\""
  RUL="$RUL -e \"/^#RUST_VER /s@^#@@\""
fi


if [ $SYS_BINDGEN -gt 0 ]; then
  BINDGEN_PATH="/usr/local"

  if [ $SYS_BINDGEN -eq 1 ]; then
    if [ $SYS_CLANG -eq 0 ] || [ $SYS_CLANG -ge 2 ]; then
      printf '%s\n' "SYS_BINDGEN=1 is incompatible with SYS_CLANG=0 or SYS_CLANG=2"
      printf '%s\n' "Set SYS_BINDGEN=2 or SYS_CLANG=1 and re-run the script"
      exit 1
    fi

    op_enable="$op_enable system/bindgen-crabbyav1f.patch"

    BINDGEN_PATH="/usr"
  fi

  if [ $TEST -eq 0 ] && [ ! -x $BINDGEN_PATH/bin/bindgen ]; then
    printf '%s\n' "ERROR: $BINDGEN_PATH/bin/bindgen does not exist/is not executable"
    exit 1
  fi

  # GN_FLAGS += rust_bindgen_root=\"_BINDGEN_PATH\"
  gn_enable="$gn_enable rust_bindgen_root="

  # Set BINDGEN_PATH in d/rules (for passing to rust_bindgen_root build flag)
  RUL="$RUL -e \"s@_BINDGEN_PATH@$BINDGEN_PATH@\""
fi


if [ $SYS_GN -eq 0 ]; then
  deps_disable="$deps_disable generate-ninja"
else
  # The patches are only needed on stable
  if [ $STABLE -eq 1 ]; then
    op_enable="$op_enable system/gn/"
  fi
fi


if [ $SYS_NODE -eq 1 ]; then
  op_enable="$op_enable system/node/"
  deps_enable="$deps_enable nodejs"
fi


# Machine function splitting relies on PGO being enabled
if [ $PGO -eq 0 ] && [ $MF_SPLIT -eq 1 ]; then
  printf '%s\n' "WARN: MF_SPLIT depends on PGO=1"
  printf '%s\n' "WARN: Setting MF_SPLIT=0"
  MF_SPLIT=0
fi




#####################################################
## CPU architecture/instructions and optimisations ##
#####################################################

if [ $INTEL_CET -eq 0 ]; then
  gn_enable="$gn_enable enable_cet_shadow_stack=false"
fi

if [ $MEDIA_OPT_SPEED -eq 0 ]; then
  op_disable="$op_disable compiler-flags/media-optimize-speed-O3.patch"
fi

if [ $MF_SPLIT -eq 0 ]; then
  op_disable="$op_disable compiler-flags/machine-function-splitting.patch"
fi


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

    0)
      op_disable="$op_disable compiler-flags/cpu/march.patch"
      op_disable="$op_disable compiler-flags/cpu/mtune.patch"

      AES_PCLMUL=0; AVX=0; RTC_AVX2=0; V8_AVX2=0 ;;
  esac

  if [ "$OLD_MARCH" != "$MARCH" ] || [ "$OLD_MTUNE" != "$MTUNE" ]; then
    printf '%s\n' "WARN: Using MARCH=$MARCH MTUNE=$MTUNE"
  fi
fi


## Check if we have any patches to alter due to non-default cpu options

if [ "$MARCH" != "0" ]; then
  [ "$MARCH" = "x86-64-v2" ] || arch_patches="march"
  [ "$MTUNE" = "generic" ] || arch_patches="$arch_patches mtune"
fi

[ $AVX -eq 0 ] || arch_patches="$arch_patches avx"
[ $AVX2 -eq 0 ] || arch_patches="$arch_patches avx2"


if [ -n "$arch_patches" ]; then
  for i in $arch_patches; do
    sed -e "s@x86-64-v2@$MARCH@" -e "s@generic@$MTUNE@" \
        -i $OP_DIR/compiler-flags/cpu/$i.patch
  done
fi


# Initial rust cpu instructions
RUST_INST="+aes,+pclmulqdq"

if [ $AVX2 -eq 1 ]; then
  AVX=1; RUST_INST="$RUST_INST,+avx2"
  op_enable="$op_enable compiler-flags/cpu/avx2.patch"
fi

if [ $AVX -eq 0 ]; then
  POLLY_VEC=0
  op_disable="$op_disable compiler-flags/cpu/avx.patch"
else
  AES_PCLMUL=1; RUST_INST="$RUST_INST,+avx"

  # Let users be able to turn this off
  [ -n "$POLLY_VEC" ] || POLLY_VEC=1
fi

if [ $AES_PCLMUL -eq 0 ]; then
  RUST_INST=${RUST_INST#+aes,+pclmulqdq}
  op_disable="$op_disable compiler-flags/cpu/aes-pclmul.patch"
fi

case $RUST_INST in
  "")
    op_disable="$op_disable compiler-flags/cpu/rust-instructions.patch" ;;

  *)
    # Remove potential leading comma from RUST_INST string
    RUST_INST=${RUST_INST#,}

    sed -e "s@_RUST_INST@$RUST_INST@" \
        -i $OP_DIR/compiler-flags/cpu/rust-instructions.patch ;;
esac


if [ $RTC_AVX2 -eq 0 ]; then
  gn_enable="$gn_enable rtc_enable_avx2=false"
fi

if [ $V8_AVX2 -eq 0 ]; then
  gn_disable="$gn_disable v8_enable_wasm_simd256_revec=true"
fi



# Our Polly implementation currently depends on AVX
if [ $POLLY -eq 1 ]; then
  op_enable="$op_enable compiler-flags/polly.patch"

  if [ $POLLY_VEC -eq 1 ]; then
    op_enable="$op_enable compiler-flags/polly-vectorizer.patch"
  fi
fi



####################
## Managed Policy ##
####################

[ $CAP_AUD -eq 1 ] || POL="$POL -e \"/AudioCaptureAllowed/s@true@false@\""
[ $CAP_SCR -eq 1 ] || POL="$POL -e \"/ScreenCaptureAllowed/s@true@false@\""
[ $CAP_VID -eq 1 ] || POL="$POL -e \"/VideoCaptureAllowed/s@true@false@\""
[ $DL_RESTRICT -eq 0 ] || POL="$POL -e \"/DownloadRestrictions/s@0@3@\""
[ $DNS_BUILTIN -eq 0 ] || POL="$POL -e \"/BuiltInDnsClientEnabled/s@false@true@\""
[ -z "$DNS_HOST" ] || POL="$POL -e \"/doh.opendns.com/s@doh.opendns.com@$DNS_HOST@\""
[ $DNS_INTERCEPT -eq 1 ] || POL="$POL -e \"/DNSInterceptionChecksEnabled/s@true@false@\""

# Not part of managed policy but set this here with the other dns variables
if [ $DNS_CONFIG -eq 0 ]; then
  op_disable="$op_disable disable/dns_config_service.patch"
fi



#############################################
## Non-library features/components/patches ##
#############################################

if [ $ATK -eq 0 ]; then
  op_enable="$op_enable disable/atk.patch"
  gn_enable="$gn_enable use_atk=false"
fi


if [ $CATAPULT -eq 1 ]; then
  op_disable="$op_disable disable/catapult.patch"
fi


if [ $CHROMECAST -eq 0 ]; then
  if [ $MEDIA_REMOTING -eq 1 ]; then
    if [ $MEDIA_REMOTING_SET -eq 0 ]; then
      printf '$s\n' "WARN: Setting MEDIA_REMOTING=0 since CHROMECAST=0"
      printf '%s\n' "WARN: Set MEDIA_REMOTING=0 to silence these warnings"
      MEDIA_REMOTING=0
    else
      printf '%s\n' "ERROR: Cannot set MEDIA_REMOTING=1 when CHROMECAST=0"
      exit 1
    fi
  fi
else
  op_disable="$op_disable disable/media-router.patch"
  op_enable="$op_enable chromecast/"

  P=fix-building-without-mdns-and-service-discovery.patch
  SER_UC="$SER_UC -e \"/^extra\/ungoogled-chromium\/$P/s@^@#@\""

  SMF="$SMF -e \"/^enable_mdns=false/d\""
  SMF="$SMF -e \"/^enable_remoting=false/d\""

  if [ $CHROMECAST -ge 2 ]; then
    sed -e '/media-router=0/s@^@#@' \
        -e '/enable-mdns/s@^#@@' \
        -i $FLAG_DIR/network
  fi
fi


if [ $CLICK_TO_CALL -eq 0 ]; then
  op_enable="$op_enable disable/click-to-call.patch"
  gn_enable="$gn_enable enable_click_to_call=false"
fi


if [ $DBUS -eq 0 ]; then
  op_disable="$op_disable system/libdbus.patch"
  op_enable="$op_enable disable/dbus-and-notifications/"

  gn_enable="$gn_enable use_dbus=false"
  deps_disable="$deps_disable libdbus-1"

  SYS_NOTIFICATIONS=0
else
  # BLUEZ=0 should only effect DBUS=1
  if [ $BLUEZ -eq 0 ]; then
    op_enable="$op_enable disable/bluez.patch"
    gn_enable="$gn_enable use_bluez=false"
  fi
fi


if [ $DRIVER -eq 0 ]; then
  op_disable="$op_disable fixes/chromedriver/"

  CON="$CON -e \"/^Package: ungoogled-chromium-driver/,/^Package:/{//!d}\""
  CON="$CON -e \"/^Package: ungoogled-chromium-driver/d\""
  RUL="$RUL -e \"s@ chromedriver@@\""
fi


if [ $ENTERPRISE_WATERMARK -eq 1 ]; then
  op_disable="$op_disable disable/enterprise-watermark.patch"
  gn_disable="$gn_disable enterprise_watermark=false"
fi


if [ $FAST_RESTART -eq 1 ]; then
  [ ! -f $OUT_DIR/args.gn ] || rm $OUT_DIR/args.gn

  RUL="$RUL -e \"/gn gen/s@^\t@\ttest -f \x24\x28ARGS_GN\x29 || @\""
fi


if [ $FF_FDK -eq 1 ]; then
  op_enable="$op_enable ffmpeg-extra-codecs/fdk-aac/"

  FF_AAC=0
  FF_AC="libfdk_aac"

  FDK_DIR=$RT_DIR/third_party/ffmpeg/libavcodec/fdk-aac
  if [ $TEST -eq 0 ] && [ ! -d $FDK_DIR ]; then
    printf '%s\n' "ERROR: Cannot find $FDK_DIR"
    exit 1
  fi
fi


if [ $FF_AC3 -eq 0 ]; then
  op_disable="$op_disable ffmpeg-extra-codecs/ac3/"
  gn_disable="$gn_disable enable_platform_ac3_eac3_audio=true"
else
  FF_AC="$FF_AC,ac3,eac3"
fi


if [ $FF_AC4 -eq 1 ]; then
  op_enable="$op_enable ffmpeg-extra-codecs/ac4/"
  gn_enable="$gn_enable enable_platform_ac4_audio=true"
  FF_AC="$FF_AC,ac4"
fi


if [ $FF_ALAC -eq 1 ]; then
  op_enable="$op_enable ffmpeg-extra-codecs/alac/"
  FF_AC="$FF_AC,alac"
fi


if [ $FF_HEVC -eq 0 ]; then
  op_disable="$op_disable ffmpeg-extra-codecs/hevc/"
  gn_enable="$gn_enable enable_platform_hevc=false"

  RUL="$RUL -e \"/^HEVC_/s@^@#@\""
  RUL="$RUL -e \"/libavcodec-hevc-/s@\(for\)@#\1@\""
fi


if [ $FONTATIONS -eq 0 ]; then
  op_enable="$op_enable disable/fontations.patch"
else
  if [ $FONTATIONS -eq 2 ]; then
    sed -e '/enable-fontations-backend/s@^#@@' -i $FLAG_DIR/miscellaneous
  fi

  if [ $FONTATIONS_PDF -eq 0 ]; then
    gn_disable="$gn_disable pdf_enable_fontations=true"
  fi
fi


if [ $GL_DESKTOP_FRONTEND -eq 1 ]; then
  gn_enable="$gn_enable angle_enable_gl_desktop_frontend=true"
fi


if [ $GOOGLE_UI_URLS -eq 1 ]; then
  DSB="$DSB -e \"/^chrome\/common\/url_constants\.h/d\""
fi


if [ $GRCACHE_PURGE -eq 1 ]; then
  sed -e '/ClearGrShaderDiskCacheOnInvalidPrefix/s@^#@@' -i $FLAG_DIR/gpu
fi


if [ $HEADLESS -eq 0 ]; then
  op_enable="$op_enable disable/headless.patch"
  gn_enable="$gn_enable headless_enable_commands=false headless_use_policy=false"
fi


if [ $HLS_PLAYER -eq 0 ]; then
  gn_enable="$gn_enable enable_hls_demuxer=false"
  ins_disable="$ins_disable hls-player"
elif [ $HLS_PLAYER -ge 2 ]; then
  sed -e '/enable-builtin-hls/s@^#@@' \
      -e '/enable-features=HlsPlayer/s@^#@@' \
      -i $FLAG_DIR/hls-player
fi


if [ $HYPHENATION -eq 0 ]; then
  op_disable="$op_disable bundle-hyphen-data.patch"
fi


if [ $IDB_FG_CLIENT_BOOST -eq 0  ]; then
  sed -e '/IdbExpediteBackend/s@^@#@' -i $FLAG_DIR/miscellaneous
fi


if [ $LENS -eq 0 ]; then
  gn_enable="$gn_enable enable_lens_desktop=false"
else
  ins_enable="$ins_enable google-lens"
  DSB="$DSB -e \"/^components\/lens\/lens_features\.cc/d\""

  if [ $LENS -ge 2 ]; then
    GOOGLE_API_KEYS=2

    L="-e \"/enable-lens-standalone/s@^#@@\""
    [ $LENS_TRANSLATE -eq 1 ] || L="$L -e \"/enable-lens-image-translate/s@^@#@\""

    eval sed $L -i $FLAG_DIR/google-lens
  fi
fi


if [ $LOCALES_EXTRA -eq 0 ]; then
  a="af, am, ar, bg, bn, ca, cs, da, de, el, en-GB, es-419, es, et, fa, fi, fil, fr,"
  b="gu, he, hi, hr, hu, id, it, ja, kn, ko, lt, lv, ml, mr, ms, nb, nl, pl, pt-BR,"
  c="pt-PT, ro, ru, sk, sl, sr, sv, sw, ta, te, th, tr, uk, ur, vi, zh-CN, zh-TW"
  CON="$CON -e \"s@af, am, ar, as, az, be, bg,.*@$a@\""
  CON="$CON -e \"s@et, eu, fa, fi, fil, fr, fr-CA,.*@$b@\""
  CON="$CON -e \"s@ka, kk, km, kn, ko, ky, lo, lt,.*@$c@\""
  CON="$CON -e \"/pa, pl, pt-BR, pt-PT, ro, ru,/d\""
  CON="$CON -e \"/th, tr, uk, ur, uz, vi, zh-CN,/d\""

  P=enable-extra-locales.patch
  SER_UC="$SER_UC -e \"/^extra\/ungoogled-chromium\/$P/s@^@#@\""
fi


if [ $MCLICK_AUTOSCROLL -eq 0 ]; then
  op_disable="$op_disable enable-middle-click-autoscroll.patch"
fi


if [ $MEDIA_REMOTING -eq 1 ]; then
  op_disable="$op_disable disable/media-remoting/"
  gn_disable="$gn_disable enable_media_remoting=false"
fi


if [ $MUTEX_PI -eq 0 ]; then
  op_disable="$op_disable mutex-priority-inheritance.patch"
  gn_disable="$gn_disable enable_mutex_priority_inheritance=true"
else
  # The build flag is disabled separately a few lines below
  if [ $PART_LOCK_PI -eq 0 ]; then
    op_enable="$op_enable fixes/partition-lock-priority-inheritance.patch"
  fi
fi


if [ $OAUTH2 -eq 1 ]; then
  op_enable="$op_enable use-oauth2-client-switches-as-default.patch"
fi


if [ $OPENTYPE_SVG -eq 1 ]; then
  op_enable="$op_enable opentype-svg/"
fi


if [ $OZONE_WAYLAND -eq 0 ]; then
  gn_enable="$gn_enable ozone_platform_wayland=false"
fi


if [ $PART_LOCK_PI -eq 0 ]; then
  gn_disable="$gn_disable enable_partition_lock_priority_inheritance=true"
fi


if [ $PDF_JS -eq 1 ]; then
  # GN_FLAGS += pdf_enable_v8=false pdf_enable_xfa=false
  gn_disable="$gn_disable pdf_enable_v8=false"
fi


if [ $PRINT_PREVIEW -eq 0 ]; then
  # GN_FLAGS += enable_print_preview=false enable_oop_printing=false
  gn_enable="$gn_enable enable_print_preview=false"
fi


if [ $SPEECH -eq 0 ]; then
  op_enable="$op_enable disable/speech.patch"
  gn_enable="$gn_enable enable_speech_service=false"
fi


if [ $SPOOF_WEBGL_INFO -eq 0 ]; then
  sed -e '/SpoofWebGLInfo/s@^@#@' -i $FLAG_DIR/anti-fingerprint
fi


if [ $SWITCH_BLOCKING -ne 1 ]; then
  sed "/^SWITCH_BLOCKING/s@=1@=$SWITCH_BLOCKING@" -i $DEBIAN/etc/chromium/launcher.vars
fi


if [ $SYS_NOTIFICATIONS -eq 0 ]; then
  ins_disable="$ins_disable sys-notifications"
fi


if [ $TP_STORAGE_PART -eq 0 ]; then
  sed -e '/third-party-storage-partitioning/s@^@#@' -i $FLAG_DIR/isolation
fi


if [ $TRANSLATE -eq 0 ]; then
  op_disable="$op_disable translate/"
  ins_disable="$ins_disable google-translate"
else
  DSB="$DSB -e \"/\/translate_manager_browsertest\.cc/d\""
  DSB="$DSB -e \"/\/translate_script\.cc/d\""
  DSB="$DSB -e \"/\/translate_util\.cc/d\""

  if [ $TRANSLATE -ge 2 ]; then
    GOOGLE_API_KEYS=2
    POL="$POL -e \"/TranslateEnabled/s@false@true@\""
    sed -e '/translate-script-url=/s@^#@@' -i $FLAG_DIR/google-translate
  fi
fi


if [ $VR -eq 1 ]; then
  gn_disable="$gn_disable enable_vr=false"
fi


if [ $VULKAN -eq 0 ]; then
  op_enable="$op_enable disable/vulkan.patch"

  # Refer to debian/rules.in to see which flags are disabled
  gn_enable="$gn_enable enable_vulkan=false"
  gn_enable="$gn_enable angle_build_vulkan_system_info=false"

  ins_disable="$ins_disable libVkICD_mock_icd.so"
  ins_disable="$ins_disable libvulkan.so.1"

  SWIFTSHADER=0
  WEBGPU=0
fi


if [ $WEBASSEMBLY -eq 1 ]; then
  sed '/noexpose_wasm/s@^@#@' -i $FLAG_DIR/webassembly
fi


if [ $WEBFEED -eq 0 ]; then
  sed -e '/WebFeedKillSwitch/s@^#@@' -i $FLAG_DIR/miscellaneous
fi


if [ $WEBGPU -ge 1 ]; then
  op_disable="$op_disable disable/webgpu.patch"

  # Refer to debian/rules.in to see which flags are disabled
  gn_disable="$gn_disable use_dawn=false"
  gn_disable="$gn_disable dawn_enable_desktop_gl=false"
  gn_disable="$gn_disable tint_build_glsl_validator=false"
  gn_disable="$gn_disable tint_build_glsl_writer=false"

  if [ $WEBGPU -ge 2 ]; then
    sed -e '/enable-unsafe-webgpu/s@^#@@' -i $FLAG_DIR/gpu
  fi
fi


if [ $VULKAN -eq 1 ] && [ $WEBGPU -ge 1 ]; then
  # Refer to debian/rules.in to see which flags are disabled
  gn_disable="$gn_disable dawn_enable_vulkan=false"
fi


if [ $SWIFTSHADER -eq 0 ]; then
  op_disable="$op_disable fixes/swiftshader-color-input-nullptr-crash.patch"
  gn_enable="$gn_enable enable_swiftshader=false"
  ins_disable="$ins_disable swiftshader"
else
  if [ $VULKAN -eq 0 ] || ([ $VULKAN -eq 1 ] && [ $SWIFTSHADER_VULKAN -eq 0 ]); then
    gn_enable="$gn_enable enable_swiftshader_vulkan=false"
  fi

  if [ $WEBGPU -eq 0 ] || ([ $WEBGPU -eq 1 ] && [ $SWIFTSHADER_WEBGPU -eq 0 ]); then
    gn_enable="$gn_enable dawn_use_swiftshader=false"
  fi
fi


if [ $WIDEVINE -eq 0 ]; then
  op_disable="$op_disable fixes/widevine/"
  SMF="$SMF -e \"/^enable_widevine=/s@true@false@\""
fi



## Handle audio codecs with a single patch to avoid patch conflict
if [ $FF_AAC -eq 1 ] && [ $FF_AC3 -eq 0 ] && [ $FF_AC4 -eq 0 ] && \
   [ $FF_ALAC -eq 0 ] && [ $FF_FDK -eq 0]; then
  op_disable="$op_disable ffmpeg-extra-codecs/audio-codecs.patch"
  op_disable="$op_disable ffmpeg-extra-codecs/context-fixup.patch"
else
  sed "s@_ff_ac@$FF_AC@" -i $OP_DIR/ffmpeg-extra-codecs/audio-codecs.patch
fi



## Enable Google API keys for google services
if [ $GOOGLE_API_KEYS -eq 0 ]; then
  ins_disable="$ins_disable google-api-keys"
elif [ $GOOGLE_API_KEYS -ge 2 ]; then
  sed -e '/^#export GOOGLE_/s@^#@@' -i $FLAG_DIR/google-api-keys
fi



## Skia gamma range: 1.0 to 3.0 (a value of 1 just enables the patch)
case $SKIA_GAMMA in
  [23])
    # Ensure skia gamma values have one decimal place
    SKIA_GAMMA=${SKIA_GAMMA}.0 ;;
esac

case $SKIA_GAMMA in
  1|[12].[0-9]|3.0)
    case $SKIA_GAMMA in
      [12].[0-9]|3.0)
        sed "s@2\.2@$SKIA_GAMMA@" -i $OP_DIR/fixes/skia-gamma.patch ;;
    esac

    op_enable="$op_enable skia-gamma.patch" ;;
esac



#################
##  Libraries  ##
#################

if [ $QT -eq 0 ]; then
  op_disable="$op_disable fixes/qt-ui.patch"
  deps_disable="$deps_disable qtbase"
  ins_disable="$ins_disable qt"
  gn_disable="$gn_disable use_qt"
else
  if [ $QT_6 -eq 1 ]; then
    CON="$CON -e \"/qtbase/s@5@6@\""
    RUL="$RUL -e \"/use_qt/s@5@6@\""
  fi
fi


if [ $OPENH264 -eq 0 ]; then
  # GN_FLAGS += media_use_openh264=false rtc_use_h264=false
  gn_enable="$gn_enable media_use_openh264=false"
fi


if [ $PIPEWIRE -eq 0 ]; then
  gn_disable="$gn_disable rtc_use_pipewire=false"
  deps_disable="$deps_disable libpipewire"
fi


if [ $PULSE -eq 0 ]; then
  gn_disable="$gn_disable link_pulseaudio=true"
  gn_enable="$gn_enable use_pulseaudio=false"
  deps_disable="$deps_disable libpulse"
fi


if [ $RUSTY_PNG -eq 0 ]; then
  sed -e '/rusty-png/s@^@#@' -i $FLAG_DIR/miscellaneous
fi


if [ $VAAPI -eq 0 ]; then
  op_disable="$op_disable system/vaapi/"
  gn_enable="$gn_enable use_vaapi=false"
  deps_disable="$deps_disable libva"
  ins_disable="$ins_disable hw-decoding-encoding"
fi



if [ $SYS_JPEG -eq 0 ]; then
  op_disable="$op_disable system/jpeg.patch"
  sys_disable="$sys_disable libjpeg"
fi


if [ $SYS_OPENH264 -eq 0 ]; then
  op_disable="$op_disable system/openh264.patch"
  sys_disable="$sys_disable openh264"
  deps_disable="$deps_disable libopenh264"
fi


if [ $SYS_ZSTD -eq 0 ]; then
  sys_disable="$sys_disable zstd"
  deps_disable="$deps_disable libzstd"

  POL="$POL -e \"/ZstdContentEncodingEnabled/s@true@false@\""
fi


## Items which are (or are likely to become) unstable-only

if [ $STABLE -eq 1 ]; then
  # For STABLE=1 we disable brotli by default but allow force-enablement
  [ $SYS_BROTLI_SET -eq 1 ] && [ $SYS_BROTLI -eq 1 ] || SYS_BROTLI=0

  if [ $SYS_BROTLI -eq 1 ]; then
    # Implied enablement of system freetype when SYS_BROTLI=1
    op_enable="$op_enable system/freetype-COLRV1.patch"
  fi

  # For STABLE=1 we disable libdrm by default but allow force-enablement
  [ $SYS_DRM_SET -eq 1 ] && [ $SYS_DRM -eq 1 ] || SYS_DRM=0

  # Allow stable users (eg with a self-compiled icu package) to enable SYS_ICU
  [ $SYS_ICU_SET -eq 1 ] && [ $SYS_ICU -eq 1 ] || SYS_ICU=0

  # For STABLE=1 we disable libwebp by default but allow force-enablement
  [ $SYS_WEBP_SET -eq 1 ] && [ $SYS_WEBP -eq 1 ] || SYS_WEBP=0

  # Disable dav1d (too old)
  op_disable="$op_disable system/unstable/dav1d/"
  sys_disable="$sys_disable dav1d"
  deps_disable="$deps_disable libdav1d"

  # Reverse time_t transition dependencies for stable
  CON="$CON -e \"/libgtk-3-0t64/s@t64@@\""
fi


if [ $SYS_BROTLI -eq 0 ]; then
  op_disable="$op_disable system/unstable/freetype.patch"
  op_enable="$op_enable fixes/skia-allow-bundled-freetype.patch"

  if [ $OPENTYPE_SVG -eq 1 ]; then
    op_enable="$op_enable fixes/opentype-svg-on-bundled-freetype.patch"
  fi

  # SYS_LIBS += fontconfig freetype brotli libpng
  sys_disable="$sys_disable fontconfig"

  # libfontconfig pulls in libfreetype
  # libfreetype pulls in libbrotli and libpng
  deps_disable="$deps_disable libfontconfig"

  if [ $SYS_ICU -eq 0 ]; then
    sys_enable="$sys_enable libpng"
  fi
fi


if [ $SYS_DRM -eq 0 ]; then
  op_disable="$op_disable system/libdrm.patch"
  sys_disable="$sys_disable libdrm"
  deps_disable="$deps_disable libdrm"
fi


if [ $SYS_ICU -eq 1 ]; then
  op_disable="$op_disable fixes/icudata-file-path.patch"
  op_disable="$op_disable fixes/skia-allow-bundled-harfbuzz.patch"
  op_enable="$op_enable system/unstable/icu.patch"

  gn_disable="$gn_disable icu_copy_icudata_to_root_build_dir=false"

  # GN_FLAGS += icu_use_data_file=false use_system_harfbuzz=true
  gn_enable="$gn_enable icu_use_data_file=false"

  # SYS_LIBS += harfbuzz-ng libxslt libxml icu
  sys_enable="$sys_enable harfbuzz-ng"

  # harfbuzz-ng pulls in libicu
  # libxslt1 pulls in libicu via dependency on libxml2
  # include libicu in so we can control its version
  deps_enable="$deps_enable libharfbuzz libicu libxslt1"

  # icudtl.dat is not needed with system icu
  ins_disable="$ins_disable icudtl.dat"
  RUL="$RUL -e \"/icudtl.dat/s@^\t@\t#@\""
fi


if [ $SYS_WEBP -eq 0 ]; then
  sys_disable="$sys_disable libwebp"
  deps_disable="$deps_disable libwebp"
fi





############################################################
##  Domain substitution, submodule flags and pruning list ##
############################################################

# Check whether DEPS.patch, DEPS-no-rust.patch or DEPS-no-node.patch have been applied
# Sum combinations of 1, 2 and 4 to determine which patches have been used
if [ $TEST -eq 0 ] && [ -f $RT_DIR/DEPS ]; then
  # Check for DEPS.patch application
  case $(sed -n '/webvr_info/p' $RT_DIR/DEPS) in
    *src/chrome/test/data/xr/webvr_info*)
      : ;;

    *)
      DEPS_PATCH=$((DEPS_PATCH+1)) ;;
  esac

  # Check for DEPS-no-rust.patch application
  case $(sed -n '/Linux_x64\/rust-toolchain-/,/condition/{/==/p}' $RT_DIR/DEPS) in
    *condition*!=*)
      DEPS_PATCH=$((DEPS_PATCH+2)) ;;
  esac

  # Check for DEPS-no-node.patch application
  case $(sed -n '\/node\/linux/,/condition/{/checkout_src_internal/p}' $RT_DIR/DEPS) in
    *checkout_src_internal*)
      DEPS_PATCH=$((DEPS_PATCH+4)) ;;
  esac
fi

## Domain substitution exclusions
DSB="$DSB -e \"/^chrome\/browser\/flag_descriptions\.cc/d\""
DSB="$DSB -e \"/^chrome\/installer\/linux\/common\/appdata\.xml\.template/d\""
DSB="$DSB -e \"/^content\/browser\/resources\/gpu\/info_view\.ts/d\""
DSB="$DSB -e \"/^tools\/clang\//d\""

# Exclude hyphenation-related files
if [ $HYPHENATION -eq 1 ]; then
  DSB="$DSB -e \"/^third_party\/blink\/renderer\/platform\/text\/hyphenation\/hyphenation_minikin\.cc/d\""
  DSB="$DSB -e \"/^third_party\/hyphenation-patterns\//d\""
fi

# Exclude bundled library files
DSB="$DSB -e \"/^base\/third_party\/double_conversion\/BUILD\.gn/d\""
DSB="$DSB -e \"/^build\/config\/freetype\/freetype\.gni/d\""
DSB="$DSB -e \"/^third_party\/angle\/src\/third_party\/libXNVCtrl\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/brotli\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/dav1d\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/ffmpeg\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/flac\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/fontconfig\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/harfbuzz-ng\/harfbuzz\.gni/d\""
DSB="$DSB -e \"/^third_party\/icu\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/libdrm\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/libjpeg\.gni/d\""
DSB="$DSB -e \"/^third_party\/libpng\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/libsecret\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/libusb\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/libxml\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/libxslt\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/openh264\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/opus\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/zlib\/BUILD\.gn/d\""
DSB="$DSB -e \"/^third_party\/zstd\/BUILD\.gn/d\""

if [ $DEPS_PATCH -gt 0 ] && [ $DEPS_PATCH -ne 4 ]; then
  # Exclude files that don't exist after patching with DEPS.patch
  if [ $DEPS_PATCH -ne 2 ] && [ $DEPS_PATCH -ne 6 ]; then
    DSB="$DSB -e \"/^build\/linux\/debian_bullseye_i386-sysroot\//d\""
    DSB="$DSB -e \"/^build\/linux\/debian_bullseye_amd64-sysroot\//d\""
    DSB="$DSB -e \"/^docs\/website\//d\""
    DSB="$DSB -e \"/^third_party\/beto-core\//d\""
    DSB="$DSB -e \"/^third_party\/blink\/renderer\/core\/css\/perftest_data\//d\""
    DSB="$DSB -e \"/^third_party\/colorama\//d\""
    DSB="$DSB -e \"/^third_party\/cros-components\//d\""
    DSB="$DSB -e \"/^third_party\/crossbench\//d\""
    DSB="$DSB -e \"/^third_party\/depot_tools\//d\""
    DSB="$DSB -e \"/^third_party\/domato\//d\""
    DSB="$DSB -e \"/^third_party\/freetype-testing\//d\""
    DSB="$DSB -e \"/^third_party\/fuzztest\//d\""
    DSB="$DSB -e \"/^third_party\/libFuzzer\//d\""
    DSB="$DSB -e \"/^third_party\/liblouis\//d\""
    DSB="$DSB -e \"/^third_party\/libva-fake-driver\//d\""
    DSB="$DSB -e \"/^third_party\/nearby\//d\""
    DSB="$DSB -e \"/^third_party\/pywebsocket3\//d\""
    DSB="$DSB -e \"/^third_party\/speedometer\//d\""
    DSB="$DSB -e \"/^third_party\/text-fragments-polyfill\//d\""
    DSB="$DSB -e \"/^third_party\/webpagereplay\//d\""
    DSB="$DSB -e \"/^third_party\/xdg-utils\//d\""
  fi

  # Exclude rust toolchain after patching with DEPS-no-rust.patch
  if [ $DEPS_PATCH -ne 1 ] && [ $DEPS_PATCH -ne 5 ]; then
    DSB="$DSB -e \"/^third_party\/rust-toolchain\//d\""
  fi
fi

## Pruning list
PRU="$PRU -e \"/^chrome\/build\/pgo_profiles\//d\""
PRU="$PRU -e \"/^third_party\/depot_tools\//d\""
PRU="$PRU -e \"/^third_party\/node\/node_modules\//d\""

if [ $HYPHENATION -eq 1 ]; then
  PRU="$PRU -e \"/^third_party\/hyphenation-patterns\//d\""
fi

## Exempt node from pruning only if DEPS-no-node.patch has NOT been applied
if [ $DEPS_PATCH -lt 4 ]; then
  PRU_PY="$PRU_PY -e \"/third_party\/node\/linux\//d\""
fi

## Submodule flags
SMF="$SMF -e \"/^enable_hangout_services_extension/d\""
SMF="$SMF -e \"/^enable_nacl/d\""
SMF="$SMF -e \"/^enable_service_discovery/d\""
SMF="$SMF -e \"/^exclude_unwind_tables/d\""
SMF="$SMF -e \"/^google_api_key/d\""
SMF="$SMF -e \"/^google_default_client_id/d\""
SMF="$SMF -e \"/^google_default_client_secret/d\""

if [ $PGO -eq 1 ]; then
  SMF="$SMF -e \"/^chrome_pgo_phase/d\""
fi




##############################
##  Aggregate sed commands  ##
##############################

if [ -n "$deps_disable" ]; then
  for i in $deps_disable; do
    CON="$CON -e \"/^[ ]*$i/s@^[ ]*@#@\""
  done
fi

if [ -n "$deps_enable" ]; then
  for i in $deps_enable; do
    CON="$CON -e \"/^#$i/s@^#@ @\""
  done
fi


if [ -n "$ins_disable" ]; then
  for i in $ins_disable; do
    INS="$INS -e \"/$i/s@^@#@\""
  done
fi

if [ -n "$ins_enable" ]; then
  for i in $ins_enable; do
    INS="$INS -e \"/$i/s@^#@@\""
  done
fi


if [ -n "$op_disable" ]; then
  case $op_disable in
    *optional/*)
      op_disable="$(echo $op_disable | sed 's@optional/@@g')" ;;
  esac

  for i in $op_disable; do
    SER_DB="$SER_DB -e \"s@^\(optional/$i\)@#\1@\""
  done
fi

if [ -n "$op_enable" ]; then
  case $op_enable in
    *optional/*)
      op_enable="$(echo $op_enable | sed 's@optional/@@g')" ;;
  esac

  for i in $op_enable; do
    SER_DB="$SER_DB -e \"s@^#\(optional/$i\)@\1@\""
  done
fi


if [ -n "$gn_disable" ]; then
  for i in $gn_disable; do
    RUL="$RUL -e \"/^GN_FLAGS += $i=*/s@^@#@\""
  done
fi

if [ -n "$gn_enable" ]; then
  for i in $gn_enable; do
    RUL="$RUL -e \"/^#GN_FLAGS += $i=*/s@^#@@\""
  done
fi


if [ -n "$sys_disable" ]; then
  for i in $sys_disable; do
    RUL="$RUL -e \"/^SYS_LIBS += $i/s@^@#@\""
  done
fi

if [ -n "$sys_enable" ]; then
  for i in $sys_enable; do
    RUL="$RUL -e \"/^#SYS_LIBS += $i/s@^#@@\""
  done
fi



#####################################
##  Modify debian directory files  ##
#####################################

sed -e "s;@@VERSION@@;$VERSION;" -e "s;@@RELEASE@@;$RELEASE;" \
    -e "s;@@AUTHOR@@;$AUTHOR;" -e "s;@@DATETIME@@;$(date -R);" \
  < $DEBIAN/changelog.in > $DEBIAN/changelog


[ -n "$SER_DB" ] || SER_DB="-n p"
[ -n "$SER_UC" ] || SER_UC="-n p"

SERIES_DB="$(eval sed $SER_DB $DEBIAN/patches/series.debian)"
SERIES_UC="$(eval sed $SER_UC $UC_DIR/patches/series)"

echo "$SERIES_UC" "$SERIES_DB" > $DEBIAN/patches/series


[ -z "$INS" ] || eval sed $INS < $DEBIAN/$INSTALL.in > $DEBIAN/$INSTALL
[ -z "$POL" ] || eval sed $POL < $DEBIAN/$POLICIES.in > $DEBIAN/$POLICIES
[ -z "$PRU_PY" ] || eval sed $PRU_PY -i $UC_DIR/utils/prune_binaries.py

eval sed $CON < $DEBIAN/control.in > $DEBIAN/control
eval sed $RUL < $DEBIAN/rules.in > $DEBIAN/rules
eval sed $DSB -i $UC_DIR/domain_substitution.list
eval sed $SMF -i $UC_DIR/flags.gn
eval sed $PRU -i $UC_DIR/pruning.list


## Ensure ungoogled-chromium.install and policies.json exist
for file in $INSTALL $POLICIES; do
  [ -f $DEBIAN/$file ] || mv $DEBIAN/$file.in $DEBIAN/$file
done

## Make d/rules and d/ungoogled-chromium.install executable
chmod 0700 $DEBIAN/rules $DEBIAN/$INSTALL



###################################
##  Prepare miscellaneous files  ##
###################################

## Chromedriver file removal
[ $DRIVER -eq 1 ] || rm $DEBIAN/ungoogled-chromium-driver.*


## Shell launcher
[ $TEST -eq 1 ] || $M_DIR/update_launcher.sh < $M_DIR/chromium.sh > $M_DIR/chromium


## Submodule patching
patch -s -p1 < $M_DIR/no-exit-if-pruned.patch


## Ungoogled chromium patch integration
for dir in upstream upstream-fixes; do
  [ ! -d $UC_DIR/patches/$dir ] || UC_P_DIRS="$UC_P_DIRS $UC_DIR/patches/$dir"
done

mv $UC_P_DIRS $DEBIAN/patches/


exit $?
