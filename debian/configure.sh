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

CLANG_VER_SET=0
MARCH_SET=0
MEDIA_REMOTING_SET=0
MTUNE_SET=0
POLLY_SET=0
RELEASE_SET=0
SYS_BROTLI_SET=0
XZ_THREADED_SET=0

# ${example%/*} = $(dirname example)
DEBIAN=${0%/*}
RT_DIR=${DEBIAN%/*}

FLAG_DIR=$DEBIAN/etc/chromium.d
OP_DIR=$DEBIAN/patches/optional

UC_DIR=$DEBIAN/submodules/ungoogled-chromium
UC_PATCH_DIRS="$UC_DIR/patches/core $UC_DIR/patches/extra"

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
[ -n "$SYS_NODE" ] || SYS_NODE=0

[ -n "$AES_PCLMUL" ] || AES_PCLMUL=1
[ -n "$AVX" ] || AVX=1
[ -n "$AVX2" ] || AVX2=0
[ -n "$RTC_AVX2" ] || RTC_AVX2=1
[ -n "$V8_AVX2" ] || V8_AVX2=1

[ -n "$INTEL_CET" ] || INTEL_CET=0
[ -n "$MEDIA_OPT_SPEED" ] || MEDIA_OPT_SPEED=1
[ -n "$MF_SPLIT" ] || MF_SPLIT=1

[ -n "$ASYNC_LEVELDB" ] || ASYNC_LEVELDB=1
[ -n "$ATK_DBUS" ] || ATK_DBUS=1
[ -n "$BLUEZ" ] || BLUEZ=1
[ -n "$CATAPULT" ] || CATAPULT=0
[ -n "$CHROMECAST" ] || CHROMECAST=1
[ -n "$CLICK_TO_CALL" ] || CLICK_TO_CALL=1
[ -n "$COMPOSE" ] || COMPOSE=1
[ -n "$DRIVER" ] || DRIVER=1
[ -n "$ENTERPRISE_WATERMARK" ] || ENTERPRISE_WATERMARK=0
[ -n "$EXTENSIONS_ROOT_MENU" ] || EXTENSIONS_ROOT_MENU=0
[ -n "$FF_ALAC" ] || FF_ALAC=1
[ -n "$FF_FDK_AAC" ] || FF_FDK_AAC=0
[ -n "$FF_HEVC" ] || FF_HEVC=1
[ -n "$GL_DESKTOP_FRONTEND" ] || GL_DESKTOP_FRONTEND=0
[ -n "$GOOGLE_API_KEYS" ] || GOOGLE_API_KEYS=0
[ -n "$GOOGLE_UI_URLS" ] || GOOGLE_UI_URLS=1
[ -n "$GRCACHE_PURGE" ] || GRCACHE_PURGE=0
[ -n "$HEADLESS" ] || HEADLESS=1
[ -n "$HLS_PLAYER" ] || HLS_PLAYER=1
[ -n "$LABS_TOOLBAR_BUTTON" ] || LABS_TOOLBAR_BUTTON=0
[ -n "$LENS" ] || LENS=1
[ -n "$LENS_TRANSLATE" ] || LENS_TRANSLATE=1
[ -n "$MUTEX_PI" ] || MUTEX_PI=1
[ -n "$NOTIFICATIONS" ] || NOTIFICATIONS=1
[ -n "$OAUTH2" ] || OAUTH2=0
[ -n "$OPENTYPE_SVG" ] || OPENTYPE_SVG=1
[ -n "$OZONE_WAYLAND" ] || OZONE_WAYLAND=1
[ -n "$PDF_JS" ] || PDF_JS=0
[ -n "$PIPEWIRE" ] || PIPEWIRE=1
[ -n "$PRINT_PREVIEW" ] || PRINT_PREVIEW=1
[ -n "$PULSE" ] || PULSE=1
[ -n "$QT" ] || QT=1
[ -n "$SKIA_GAMMA" ] || SKIA_GAMMA=0
[ -n "$SPEECH" ] || SPEECH=1
[ -n "$SW_OFF_MAIN" ] || SW_OFF_MAIN=1
[ -n "$SWIFTSHADER" ] || SWIFTSHADER=1
[ -n "$SWIFTSHADER_VULKAN" ] || SWIFTSHADER_VULKAN=1
[ -n "$SWIFTSHADER_WEBGPU" ] || SWIFTSHADER_WEBGPU=0
[ -n "$SWITCH_BLOCKING" ] || SWITCH_BLOCKING=1
[ -n "$TRANSLATE" ] || TRANSLATE=1
[ -n "$VISUAL_QUERY" ] || VISUAL_QUERY=0
[ -n "$VR" ] || VR=0
[ -n "$VAAPI" ] || VAAPI=1
[ -n "$VULKAN" ] || VULKAN=1
[ -n "$WEBGPU" ] || WEBGPU=0
[ -n "$WIDEVINE" ] || WIDEVINE=1
[ -n "$ZSTD" ] || ZSTD=0

[ -n "$SYS_FFMPEG" ] || SYS_FFMPEG=0
[ -n "$SYS_ICU" ] || SYS_ICU=0
[ -n "$SYS_JPEG" ] || SYS_JPEG=1

## Allow force-enabling brotli for stable users who have installed my deb packages
[ -n "$SYS_BROTLI" ] && SYS_BROTLI_SET=1 || SYS_BROTLI=1

## Need to error out if MEDIA_REMOTING explicitly set with CHROMECAST=0
[ -n "$MEDIA_REMOTING" ] && MEDIA_REMOTING_SET=1 || MEDIA_REMOTING=1

## OpenH254 support
[ -n "$OPENH264" ] && [ $OPENH264 -eq 0 ] && SYS_OPENH264=0 || OPENH264=1
[ -n "$SYS_OPENH264" ] || SYS_OPENH264=1

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
[ -n "$DNS_CONFIG" ] || DNS_CONFIG=1

## Package conpression: XZ_THREADED is disabled If XZ_EXTREME=0 or XZ_THREADED=0 (or both)
[ -n "$XZ_EXTREME" ] || XZ_EXTREME=0
[ -n "$XZ_THREADED" ] && XZ_THREADED_SET=1 || XZ_THREADED=0


## Disable non-free stuff if NON_FREE=0
[ -n "$NON_FREE" ] || NON_FREE=1

if [ $NON_FREE -eq 0 ]; then
  ins_disable="$ins_disable anti-audio-fingerprint"
  SER_DB="$SER_DB -e \"s@^\(cromite/\)@#\1@\" -e \"s@^\(vanadium/\)@#\1@\""

  if [ $FF_FDK_AAC -eq 1 ]; then
    printf '%s\n' "ERROR: Cannot set FF_FDK_AAC=0 when NON_FREE=0"
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




###########################################################
## Test mode | LTO | Symbol levels | Package compression ##
###########################################################

## Enter test mode if $RT_DIR/third_party does not exist
[ -d $RT_DIR/third_party ] && TEST=0 || TEST=1


## Set LTO cache directory and number of LTO jobs
if [ -n "$LTO_DIR" ]; then
  if [ $TEST -eq 0 ] && [ ! -d $LTO_DIR ]; then
    printf '\n%s\n' "ERROR: LTO_DIR path $LTO_DIR does not exist"
    exit 1
  fi

  op_enable="$op_enable compiler-flags/thinlto-cache-location"

  sed -e "s@^\(+.*thinlto-cache-dir=\)[-_a-zA-Z0-9/]*@\1$LTO_DIR@" \
      -i $OP_DIR/compiler-flags/thinlto-cache-location.patch
fi

case $LTO_JOBS in
  [1-9]|[1-9][0-9])
    op_enable="$op_enable compiler-flags/thinlto-jobs"

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
  [ $XZ_THREADED_SET -eq 1 ] && [ $XZ_THREADED -eq 0 ] || XZ_THREADED=1
fi

if [ $XZ_THREADED -eq 1 ]; then
  RUL="$RUL -e \"/dh_builddeb /s@\(.*\)@\1 --threads-max=\x24(JOBS)@\""
fi




################################################################
## Clang/ESbuild/Machine Function Splitter/Rust configuration ##
################################################################

## Enable the use of ccache
if [ $CCACHE -eq 1 ]; then
  gn_enable="$gn_enable cc_wrapper=ccache"
fi


if [ $ESBUILD -ge 0 ]; then
  # Avoid the hassle of having to re-obtain after deletion
  PRU_PY="$PRU_PY -e \"/third_party\/esbuild\//d\""

  if [ $ESBUILD -eq 1 ]; then
    op_enable="$op_enable enable-esbuild-for-official-builds"
    gn_enable="$gn_enable devtools_fast_bundle"
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
else
  # Default enable POLLY when SYS_CLANG > 0 unless explicitly disabled
  [ $POLLY_SET -eq 1 ] && [ $POLLY -eq 0 ] || POLLY=1

  ## Check for clang binary existence and PGO compatibility

  CC_VER=$(sed -n '/^[ #]clang-/s@[-#,a-z ]@@gp' $DEBIAN/control.in)

  case $CLANG_VER in
    "")
      CLANG_VER=$CC_VER ;;

    [1-9][0-9])
      CLANG_VER_SET=1 ;;

    [1-9][0-9].*)
      CLANG_VER="$(echo $CLANG_VER | sed 's@\..*@@')"
      CLANG_VER_SET=1 ;;

    *)
      printf '%s\n' "ERROR: malformed CLANG_VER variable $CLANG_VER"
      exit 1 ;;
  esac

  LLVM_BASE_DIR=/usr/lib/llvm-$CLANG_VER
  [ $SYS_CLANG -eq 1 ] || LLVM_BASE_DIR=/usr/local

  if [ $TEST -eq 0 ]; then
    if [ $CLANG_VER_SET -eq 0 ]; then
      # If CLANG_VER has NOT been set explicity then get the version from the binary
      LLVM_VER=$($LLVM_BASE_DIR/bin/clang --version | sed -n 's@.*version \([^.]*\).*@\1@p')
    else
      # If CLANG_VER has been set explicity then trust the version and do a quick usability check
      if [ ! -x $LLVM_BASE_DIR/bin/clang ]; then
        printf '%s\n' "ERROR: Cannot find $LLVM_BASE_DIR/bin/clang"
        exit 1
      fi
    fi
  fi

  [ -n "$LLVM_VER" ] || LLVM_VER=$CLANG_VER

  if [ $PGO -eq 1 ] && [ $LLVM_VER -lt $CC_VER ]; then
    printf '%s\n' "ERROR: Clang versions below $CC_VER are incompatible with PGO"
    exit 1
  fi


  ## Set optional patches, build flags and format d/rules and d/control
  op_enable="$op_enable system/clang/clang-version-check"
  gn_enable="$gn_enable clang_base_path custom_toolchain host_toolchain"

  RUL="$RUL -e \"/^#export LLVM_DIR /s@^#@@\""
  RUL="$RUL -e \"/^#export.*:= \x24\x28LLVM_DIR\x29\//s@^#@@\""
  RUL="$RUL -e \"/^#export.*_MAINT_SET/s@^#@@\""

  RUL="$RUL -e \"s@_LLVM_BASE_DIR@$LLVM_BASE_DIR@\""
  RUL="$RUL -e \"s@_LLVM_VER@$LLVM_VER@\""

  if [ $SYS_CLANG -eq 1 ]; then
    op_enable="$op_enable system/clang/rust-clanglib"
    deps_enable="$deps_enable lld clang libclang-rt"

    # Change version in d/control and d/rules if CC_VER and CLANG_VER differ
    if [ $CC_VER -ne $CLANG_VER ]; then
      CON="$CON -e \"/^#lld-/s@$CC_VER@$CLANG_VER@\""
      CON="$CON -e \"/^#clang-/s@$CC_VER@$CLANG_VER@\""
      CON="$CON -e \"/^#libclang-rt-/s@$CC_VER@$CLANG_VER@\""
    fi
  fi
fi


if [ $SYS_RUST -ge 1 ]; then
  # GN_FLAGS += rust_sysroot_absolute=\"$(RUST_PATH)\" rustc_version=\"$(RUST_VER)\"
  gn_enable="$gn_enable rust_sysroot_absolute"

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

    op_enable="$op_enable system/bindgen-crabbyav1f"
    op_enable="$op_enable system/clang/bindgen-clang-paths"

    BINDGEN_PATH="/usr"
  fi

  if [ $TEST -eq 0 ] && [ ! -x $BINDGEN_PATH/bin/bindgen ]; then
    printf '%s\n' "ERROR: $BINDGEN_PATH/bin/bindgen does not exist/is not executable"
    exit 1
  fi

  # GN_FLAGS += rust_bindgen_root=\"_BINDGEN_PATH\"
  gn_enable="$gn_enable rust_bindgen_root"

  # Set BINDGEN_PATH in d/rules (for passing to rust_bindgen_root build flag)
  RUL="$RUL -e \"s@_BINDGEN_PATH@$BINDGEN_PATH@\""
fi


if [ $SYS_NODE -eq 1 ]; then
  op_enable="$op_enable system/node"
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

if [ $INTEL_CET -eq 1 ]; then
  op_enable="$op_enable compiler-flags/cpu/intel-cet/"
fi

if [ $MEDIA_OPT_SPEED -eq 0 ]; then
  op_disable="$op_disable compiler-flags/media-optimize-speed-O3"
fi

if [ $MF_SPLIT -eq 0 ]; then
  op_disable="$op_disable compiler-flags/machine-function-splitting"
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
      SER_DB=$SER_DB -e \"/\/cpu\/march\.patch/s@^@#@\""
      SER_DB=$SER_DB -e \"/\/cpu\/mtune\.patch/s@^@#@\""

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
    sed -e "s@\(march=\)[-a-z0-9]*@\1$MARCH@" \
        -e "s@\(mtune=\)[-a-z0-9]*@\1$MTUNE@" \
        -i $OP_DIR/compiler-flags/cpu/$i.patch
  done
fi


if [ $AVX2 -eq 1 ]; then
  AVX=1
  op_enable="$op_enable compiler-flags/cpu/avx2"
fi

if [ $AVX -eq 0 ]; then
  POLLY_VEC=0
  op_disable="$op_disable compiler-flags/cpu/avx"
else
  AES_PCLMUL=1
fi

if [ $AES_PCLMUL -eq 0 ]; then
  op_disable="$op_disable compiler-flags/cpu/aes-pclmul"
fi

if [ $RTC_AVX2 -eq 0 ]; then
  gn_enable="$gn_enable rtc_enable_avx2=false"
fi

if [ $V8_AVX2 -eq 0 ]; then
  gn_disable="$gn_disable v8_enable_wasm_simd256_revec=true"
fi



# Our Polly implementation currently depends on AVX
if [ $POLLY -eq 1 ]; then
  op_enable="$op_enable compiler-flags/polly.patch"

  [ -n "$POLLY_VEC" ] || POLLY_VEC=1
fi

if [ $POLLY_VEC -eq 1 ]; then
  op_enable="$op_enable compiler-flags/polly-vectorizer"

  if [ $POLLY -eq 0 ]; then
    printf '%s\n' "Cannot set POLLY_VEC=1 when POLLY=0"
    exit 1
  fi
fi



####################
## Managed Policy ##
####################

[ $CAP_AUD -eq 1 ] || POL="$POL -e \"/AudioCaptureAllowed/s@true@false@\""
[ $CAP_SCR -eq 1 ] || POL="$POL -e \"/ScreenCaptureAllowed/s@true@false@\""
[ $CAP_VID -eq 1 ] || POL="$POL -e \"/VideoCaptureAllowed/s@true@false@\""

[ $DL_RESTRICT -eq 0 ] || POL="$POL -e \"/DownloadRestrictions/s@0@3@\""

if [ -n "$DNS_HOST" ]; then
  POL="$POL -e \"/doh.opendns.com/s@doh.opendns.com@$DNS_HOST@\""
fi

if [ $DNS_INTERCEPT -eq 0 ]; then
  POL="$POL -e \"/DNSInterceptionChecksEnabled/s@true@false@\""
else
  # The DNS config service is needed for DNS interception checking
  if [ $DNS_CONFIG -eq 0 ]; then
    printf '%s\n' "ERROR: cannot set DNS_CONFIG=0 with DNS_INTERCEPT=1"
    exit 1
  fi
fi

if [ $DNS_BUILTIN -eq 1 ]; then
  POL="$POL -e \"/BuiltInDnsClientEnabled/s@false@true@\""
fi

# Not part of managed policy but DNS_INTERCEPT=1 depends on DNS_CONFIG=1
if [ $DNS_CONFIG -eq 0 ]; then
  op_enable="$op_enable disable/dns_config_service"
fi




#############################################
## Non-library features/components/patches ##
#############################################

if [ $ASYNC_LEVELDB -eq 0 ]; then
  sed '/LevelDBProtoAsyncWrite/s@^#@@' -i $FLAG_DIR/miscellaneous
fi


if [ $ATK_DBUS -eq 0 ]; then
  op_enable="$op_enable disable/atk-dbus"

  # GN_FLAGS += use_atk=false use_dbus=false
  gn_enable="$gn_enable use_atk"

  # No point disabling BLUEZ since use_bluez depends on use_dbus
  BLUEZ=1
fi


if [ $BLUEZ -eq 0 ]; then
  gn_enable="$gn_enable use_bluez=false"
fi


if [ $CATAPULT -eq 0 ]; then
  op_enable="$op_enable disable/catapult"
fi


if [ $CHROMECAST -eq 0 ]; then
  op_enable="$op_enable disable/media-router"
  op_disable="$op_disable chromecast/"

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
  P=fix-building-without-mdns-and-service-discovery
  SER_UC="$SER_UC -e \"s@^\(extra/ungoogled-chromium/$P\)@#\1@\""

  SMF="$SMF -e \"/^enable_mdns=false/d\""
  SMF="$SMF -e \"/^enable_remoting=false/d\""

  if [ $CHROMECAST -ge 2 ]; then
    sed -e '/media-router=0/s@^@#@' \
        -e '/enable-mdns/s@^#@@' \
        -i $FLAG_DIR/network
  fi
fi


if [ $CLICK_TO_CALL -eq 0 ]; then
  op_enable="$op_enable disable/click-to-call"
  gn_enable="$gn_enable enable_click_to_call=false"
fi


if [ $COMPOSE -eq 0 ]; then
  gn_enable="$gn_enable enable_compose"
fi


if [ $DRIVER -eq 0 ]; then
  op_disable="$op_disable fixes/chromedriver/"

  CON="$CON -e \"/^Package: ungoogled-chromium-driver/,/^Package:/{//!d}\""
  CON="$CON -e \"/^Package: ungoogled-chromium-driver/d\""
  RUL="$RUL -e \"s@ chromedriver@@\""
fi


if [ $ENTERPRISE_WATERMARK -eq 1 ]; then
  op_disable="$op_disable disable/enterprise-watermark"
  gn_disable="$gn_disable enterprise_watermark=false"
fi


if [ $EXTENSIONS_ROOT_MENU -eq 1 ]; then
  op_disable="$op_disable disable/extensions-in-root-menu"
fi


if [ $FF_ALAC -eq 0 ]; then
  op_disable="$op_disable ffmpeg-extra-codecs/alac/"
fi


if [ $FF_FDK_AAC -eq 1 ]; then
  op_enable="$op_enable ffmpeg-extra-codecs/fdk-aac/"
  FDK_DIR=$RT_DIR/third_party/ffmpeg/libavcodec/fdk-aac

  if [ $TEST -eq 0 ] && [ ! -d $FDK_DIR ]; then
    printf '%s\n' "ERROR: Cannot find $FDK_DIR"
    exit 1
  fi
fi


if [ $FF_HEVC -eq 0 ]; then
  op_disable="$op_disable ffmpeg-extra-codecs/hevc/"
fi


if [ $GL_DESKTOP_FRONTEND -eq 1 ]; then
  gn_enable="$gn_enable angle_enable_gl_desktop_frontend"
fi


if [ $GOOGLE_UI_URLS -eq 1 ]; then
  DSB="$DSB -e \"/^chrome\/common\/url_constants\.h/d\""
fi


if [ $GRCACHE_PURGE -eq 1 ]; then
  sed -e '/ClearGrShaderDiskCacheOnInvalidPrefix/s@^#@@' -i $FLAG_DIR/gpu
fi


if [ $HEADLESS -eq 0 ]; then
  op_enable="$op_enable disable/headless"
  gn_enable="$gn_enable headless_enable_commands=false headless_use_policy=false"

  if [ $VISUAL_QUERY -eq 0 ]; then
    SER_DB="$SER_DB -e \"s@\(visual-query\)/headless@\1@\""
  fi
fi


if [ $HLS_PLAYER -eq 0 ]; then
  gn_disable="$gn_disable enable_hls_demuxer"
  ins_disable="$ins_disable hls-player"
elif [ $HLS_PLAYER -ge 2 ]; then
  sed -e '/enable-builtin-hls/s@^#@@' \
      -e '/enable-features=HlsPlayer/s@^#@@' \
      -i $FLAG_DIR/hls-player
fi


if [ $LABS_TOOLBAR_BUTTON -eq 1 ]; then
  sed -e '/chrome-labs/s@^#@@' -i $FLAG_DIR/ui
fi


if [ $LENS -eq 0 ]; then
  gn_enable="$gn_enable enable_lens_desktop=false"
  ins_disable="$ins_disable google-lens"
else
  DSB="$DSB -e \"/^components\/lens\/lens_features\.cc/d\""

  if [ $LENS -ge 2 ]; then
    GOOGLE_API_KEYS=1

    L="-e \"/enable-lens-standalone/s@^#@@\""
    [ $LENS_TRANSLATE -eq 1 ] || L="$L -e \"/enable-lens-image-translate/s@^@#@\""

    eval sed $L -i $FLAG_DIR/google-lens
  fi
fi


if [ $MEDIA_REMOTING -eq 0 ]; then
  op_enable="$op_enable disable/media-remoting/"
  gn_enable="$gn_enable enable_media_remoting=false"
fi


if [ $MUTEX_PI -eq 0 ]; then
  op_disable="$op_disable mutex-priority-inheritance"
  gn_disable="$gn_disable enable_mutex_priority_inheritance"
fi


if [ $NOTIFICATIONS -eq 0 ]; then
  gn_enable="$gn_enable enable_system_notifications=false"
fi


if [ $OAUTH2 -eq 1 ]; then
  op_enable="$op_enable use-oauth2-client-switches-as-default"
fi


if [ $OPENTYPE_SVG -eq 0 ]; then
  op_disable="$op_disable opentype-svg/"
fi


if [ $OZONE_WAYLAND -eq 0 ]; then
  gn_enable="$gn_enable ozone_platform_wayland=false"
fi


if [ $PDF_JS -eq 1 ]; then
  # GN_FLAGS += pdf_enable_v8=false pdf_enable_xfa=false
  # GN_FLAGS += use_system_libtiff=true
  gn_disable="$gn_disable pdf_enable_v8 use_system_libtiff"

  # Prevent libzstd being enabled twice
  if [ $ZSTD -eq 0 ]; then
    deps_enable="$deps_enable libzstd"
  fi
fi


if [ $PRINT_PREVIEW -eq 0 ]; then
  # GN_FLAGS += enable_print_preview=false enable_oop_printing=false
  gn_enable="$gn_enable enable_print_preview"
fi


if [ $SPEECH -eq 0 ]; then
  op_enable="$op_enable disable/speech"
  gn_enable="$gn_enable enable_speech_service=false"
fi


if [ $SW_OFF_MAIN -eq 0 ]; then
  sed '/ServiceWorkerAvoidMainThreadForInitialization/s@^@#@' \
    -i $FLAG_DIR/miscellaneous
fi


if [ $SWITCH_BLOCKING -ne 1 ]; then
  sed "/^SWITCH_BLOCKING/s@=1@=$SWITCH_BLOCKING@" -i $DEBIAN/misc_files/chromium.sh
fi


if [ $TRANSLATE -eq 0 ]; then
  op_disable="$op_disable translate/"
  ins_disable="$ins_disable google-translate"
else
  DSB="$DSB -e \"/\/translate_manager_browsertest\.cc/d\""
  DSB="$DSB -e \"/\/translate_script\.cc/d\""
  DSB="$DSB -e \"/\/translate_util\.cc/d\""

  if [ $TRANSLATE -ge 2 ]; then
    GOOGLE_API_KEYS=1
    sed -e '/translate-script-url=/s@^#@@' -i $FLAG_DIR/google-translate
  fi
fi


if [ $VISUAL_QUERY -eq 1 ]; then
  op_disable="$op_disable disable/visual-query/"
fi


if [ $VR -eq 1 ]; then
  gn_disable="$gn_disable enable_vr"
fi


if [ $VULKAN -eq 0 ]; then
  op_enable="$op_enable disable/vulkan"

  # Refer to debian/rules.in to see which flags are disabled
  gn_enable="$gn_enable enable_vulkan=false"
  gn_enable="$gn_enable angle_build_vulkan_system_info=false"

  ins_disable="$ins_disable libVkICD_mock_icd.so"
  ins_disable="$ins_disable libvulkan.so.1"

  SWIFTSHADER=0
  WEBGPU=0
fi


if [ $WEBGPU -ge 1 ]; then
  op_disable="$op_disable disable/webgpu"

  # Refer to debian/rules.in to see which flags are disabled
  gn_disable="$gn_disable use_dawn=false"
  gn_disable="$gn_disable dawn_enable_desktop_gl=false"

  # Disable certain flags in debian/rules which will go out of scope
  gn_enable="$gn_enable tint_build_benchmarks=false"

  SWIFTSHADER_WEBGPU=1

  if [ $WEBGPU -ge 2 ]; then
    sed -e '/enable-unsafe-webgpu/s@^#@@' -i $FLAG_DIR/gpu
  fi
fi


if [ $VULKAN -eq 0 ] || [ $WEBGPU -eq 0 ]; then
  # Refer to debian/rules.in to see which flags are disabled
  gn_enable="$gn_enable dawn_enable_vulkan=false"
fi


if [ $SWIFTSHADER -eq 0 ]; then
  gn_enable="$gn_enable enable_swiftshader=false"
  ins_disable="$ins_disable swiftshader"
else
  if [ $SWIFTSHADER_VULKAN -eq 0 ]; then
    gn_enable="$gn_enable enable_swiftshader_vulkan=false"
  fi

  if [ $SWIFTSHADER_WEBGPU -eq 1 ]; then
    gn_disable="$gn_disable dawn_use_swiftshader=false"
  fi
fi


if [ $WIDEVINE -eq 0 ]; then
  op_disable="$op_disable fixes/widevine/"
  SMF="$SMF -e \"/^enable_widevine=/s@true@false@\""
fi



## Enable Google API keys for google services
if [ $GOOGLE_API_KEYS -eq 1 ]; then
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

    op_enable="$op_enable skia-gamma" ;;
esac



#################
##  Libraries  ##
#################

if [ $QT -eq 0 ]; then
  gn_enable="$gn_enable use_qt=false"
  deps_disable="$deps_disable qtbase5"
  ins_disable="$ins_disable qt"
elif [ $QT -ge 2 ]; then
  sed '/disable-features=AllowQt/s@^@#@' -i $FLAG_DIR/qt
fi


if [ $OPENH264 -eq 0 ]; then
  # GN_FLAGS += media_use_openh264=false rtc_use_h264=false
  gn_enable="$gn_enable media_use_openh264"
fi


if [ $PIPEWIRE -eq 0 ]; then
  gn_disable="$gn_disable rtc_use_pipewire"
  deps_disable="$deps_disable libpipewire"
fi


if [ $PULSE -eq 0 ]; then
  gn_disable="$gn_disable link_pulseaudio=true"
  gn_enable="$gn_enable use_pulseaudio=false"
  deps_disable="$deps_disable libpulse"
fi


if [ $VAAPI -eq 0 ]; then
  op_disable="$op_disable system/vaapi/"
  gn_enable="$gn_enable use_vaapi=false"
  deps_disable="$deps_disable libva"
  ins_disable="$ins_disable hw-decoding-encoding"
  ins_disable="$ins_disable 10-chromium.conf"
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


if [ $SYS_OPENH264 -eq 0 ]; then
  op_disable="$op_disable system/openh264"
  sys_disable="$sys_disable openh264"
  deps_disable="$deps_disable libopenh264"
fi


if [ $ZSTD -eq 1 ]; then
  op_enable="$op_enable system/zstd/"
  sys_enable="$sys_enable zstd"
  deps_enable="$deps_enable libzstd"

  POL="$POL  -e \"/ZstdContentEncodingEnabled/s@false@true@\""
fi


## Items which are (or are likely to become) unstable-only

if [ $STABLE -eq 1 ]; then
  if [ $SYS_ICU -eq 1 ]; then
    printf '%s\n' "ERROR: SYS_ICU=1 cannot be used with STABLE=1"
    exit 1
  fi

  # Disable by default if not force-enabled
  [ $SYS_BROTLI_SET -eq 1 ] && [ $SYS_BROTLI -eq 1 ] || SYS_BROTLI=0

  if [ $SYS_BROTLI -eq 1 ]; then
    # Implied enablement of system freetype when SYS_BROTLI=1
    op_enable="$op_enable system/freetype-COLRV1"
  fi

  # Disable dav1d (too old)
  op_disable="$op_disable system/unstable/dav1d/"
  op_enable="$op_enable fixes/dav1d-bundled-header"
  sys_disable="$sys_disable dav1d"
  deps_disable="$deps_disable libdav1d"

  # Reverse time_t transition dependencies for stable
  CON="$CON -e \"/libgtk-3-0t64/s@t64@@\""
fi


if [ $SYS_BROTLI -eq 0 ]; then
  op_enable="$op_enable fixes/skia-allow-bundled-freetype"

  if [ $OPENTYPE_SVG -eq 1 ]; then
    op_enable="$op_enable fixes/opentype-svg-on-bundled-freetype"
  fi

  # SYS_LIBS += fontconfig freetype brotli libpng
  sys_disable="$sys_disable fontconfig"

  # libfontconfig pulls in libfreetype
  # libfreetype pulls in libbrotli and libpng
  deps_disable="$deps_disable libfontconfig"

  if [ $SYS_ICU -eq 0 ]; then
    sys_enable="$sys_enable libpng"
    deps_enable="$deps_enable libpng"
  fi
fi


if [ $SYS_ICU -eq 0 ]; then
  # Enable generation of a symlink to icudtl.dat in out/Release
  RUL="$RUL -e \"/icudtl.dat/s@#@@\""
else
  op_enable="$op_enable system/unstable/icu"
  op_disable="$op_disable fixes/icudata-file-path fixes/skia-allow-bundled-harfbuzz"

  gn_disable="$gn_disable icu_copy_icudata_to_root_build_dir=false"
  gn_enable="$gn_enable use_system_harfbuzz"

  # SYS_LIBS += harfbuzz-ng libxslt libxml icu
  sys_enable="$sys_enable harfbuzz-ng"

  # harfbuzz-ng pulls in libicu
  # libxslt1 pulls in libicu via dependency on libxml2
  # include libicu in so we can control its version
  deps_enable="$deps_enable libharfbuzz libicu libxslt1"

  # icudtl.dat is not needed with system icu
  ins_disable="$ins_disable icudtl.dat"
fi




############################################################
##  Domain substitution, submodule flags and pruning list ##
############################################################

# Check whether DEPS.patch has been applied
[ $TEST -eq 0 ] && grep -q 'webvr_info' $RT_DIR/DEPS && DEPS_PATCH=0 || DEPS_PATCH=1

# Check whether DEPS-no-rust.patch has been applied
if [ $TEST -eq 0 ] && [ $DEPS_PATCH -eq 1 ]; then
  grep -q -A9 'src/third_party/rust-toolchain' $RT_DIR/DEPS | grep -q 'host_os == "linux"' || DEPS_PATCH=2
fi

## Domain substitution
DSB="$DSB -e \"/^chrome\/browser\/flag_descriptions\.cc/d\""
DSB="$DSB -e \"/^content\/browser\/resources\/gpu\/info_view\.ts/d\""
DSB="$DSB -e \"/^tools\/clang\//d\""

if [ $DEPS_PATCH -ge 1 ]; then
  DSB="$DSB -e \"/^build\/linux\/debian_bullseye_i386-sysroot\//d\""
  DSB="$DSB -e \"/^build\/linux\/debian_bullseye_amd64-sysroot\//d\""
  DSB="$DSB -e \"/^third_party\/blink\/renderer\/core\/css\/perftest_data\//d\""
  DSB="$DSB -e \"/^third_party\/cros-components\//d\""
  DSB="$DSB -e \"/^third_party\/crossbench\//d\""
  DSB="$DSB -e \"/^third_party\/depot_tools\//d\""
  DSB="$DSB -e \"/^third_party\/domato\//d\""
  DSB="$DSB -e \"/^third_party\/freetype-testing\//d\""
  DSB="$DSB -e \"/^third_party\/libFuzzer\//d\""
  DSB="$DSB -e \"/^third_party\/speedometer\//d\""
  DSB="$DSB -e \"/^third_party\/xdg-utils\//d\""

  if [ $DEPS_PATCH -eq 2 ]; then
    DSB="$DSB -e \"/^third_party\/rust-toolchain\//d\""
  fi
fi

## Pruning list
PRU="$PRU -e \"/^chrome\/build\/pgo_profiles\//d\""
PRU="$PRU -e \"/^third_party\/depot_tools\//d\""
PRU="$PRU -e \"/^third_party\/node\/node_modules\//d\""

## Pruning script
if [ $SYS_NODE -eq 0 ]; then
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
    case $i in
      */|*.patch)
        SER_DB="$SER_DB -e \"s@^\(optional/$i\)@#\1@\"" ;;

      *)
        SER_DB="$SER_DB -e \"s@^\(optional/$i\.patch\)@#\1@\"" ;;
    esac
  done
fi

if [ -n "$op_enable" ]; then
  case $op_enable in
    *optional/*)
      op_enable="$(echo $op_enable | sed 's@optional/@@g')" ;;
  esac

  for i in $op_enable; do
    case $i in
      */|*.patch)
        SER_DB="$SER_DB -e \"s@^#\(optional/$i\)@\1@\"" ;;

      *)
        SER_DB="$SER_DB -e \"s@^#\(optional/$i\.patch\)@\1@\"" ;;
    esac
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

sed -e "s;@@VERSION@@;$VERSION;" \
    -e "s;@@RELEASE@@;$RELEASE;" \
    -e "s;@@AUTHOR@@;$AUTHOR;" \
    -e "s;@@DATETIME@@;$(date -R);" \
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
if [ $DRIVER -eq 0 ]; then
  rm $DEBIAN/ungoogled-chromium-driver.*
fi


## Shell launcher
if [ $TEST -eq 0 ]; then
  $DEBIAN/devutils/update_launcher.sh \
    < $DEBIAN/misc_files/chromium.sh > $DEBIAN/misc_files/chromium
fi


## Move upstream UC patches into debian/patches
for dir in upstream upstream-fixes; do
  if [ -d $UC_DIR/patches/$dir ]; then
    UC_PATCH_DIRS="$UC_PATCH_DIRS $UC_DIR/patches/$dir"
  fi
done

mv $UC_PATCH_DIRS $DEBIAN/patches/


## Submodule patching
patch -p1 < $DEBIAN/misc_files/no-exit-if-pruned.patch >/dev/null


exit $?
