#!/bin/sh
set -e

case $USER in
  root)
    printf '%s\n' "Run this script as an unprivileged user"
    exit 1 ;;
esac


arch_patches=

deps_disable=; deps_enable=
gn_disable=; gn_enable=
op_disable=; op_enable=
sys_disable=; sys_enable=

C_VER_SET=0
MARCH_SET=0
MEDIA_REMOTING_SET=0
MTUNE_SET=0
RELEASE_SET=0
SYS_FREETYPE_SET=0
SYS_HARFBUZZ_SET=0
XZ_THREADED_SET=0

# ${example%/*} = $(dirname example)
DEBIAN=${0%/*}
RT_DIR=${DEBIAN%/*}

FLAG_DIR=$DEBIAN/etc/chromium.d
OP_DIR=$DEBIAN/patches/optional

UC_DIR=$DEBIAN/submodules/ungoogled-chromium
UC_PATCH_DIRS="$UC_DIR/patches/core $UC_DIR/patches/extra"

INSTALL=ungoogled-chromium.install
P_FILE=etc/chromium/policies/managed/policies.json

PRUNE_PATCH=$DEBIAN/misc_patches/no-exit-if-pruned.patch

sanitise_op () {
  printf '%s\n' "Unnecessary optional prefix: $i"
  i=$(echo $i | sed 's@^optional/@@')
}


####################
## Default values ##
####################

[ -n "$CCACHE" ] || CCACHE=0
[ -n "$PGO" ] || PGO=1
[ -n "$STABLE" ] || STABLE=0
[ -n "$SYMBOLS" ] || SYMBOLS=0
[ -n "$SYMBOLS_BLINK" ] || SYMBOLS_BLINK=0
[ -n "$SYS_CLANG" ] || SYS_CLANG=0
[ -n "$SYS_RUST" ] || SYS_RUST=0

[ -n "$AES_PCLMUL" ] || AES_PCLMUL=1
[ -n "$AVX" ] || AVX=1
[ -n "$AVX2" ] || AVX2=0
[ -n "$RTC_AVX2" ] || RTC_AVX2=1
[ -n "$V8_AVX2" ] || V8_AVX2=1

[ -n "$INTEL_CET" ] || INTEL_CET=0
[ -n "$MF_SPLIT" ] || MF_SPLIT=1
[ -n "$POLLY" ] || POLLY=0

[ -n "$ATK_DBUS" ] || ATK_DBUS=1
[ -n "$CATAPULT" ] || CATAPULT=1
[ -n "$CLICK_TO_CALL" ] || CLICK_TO_CALL=1
[ -n "$CHROMECAST" ] || CHROMECAST=1
[ -n "$DRIVER" ] || DRIVER=1
[ -n "$EXTENSIONS_ROOT_MENU" ] || EXTENSIONS_ROOT_MENU=0
[ -n "$FEED" ] || FEED=1
[ -n "$GOOGLE_API_KEYS" ] || GOOGLE_API_KEYS=0
[ -n "$HLS_PLAYER" ] || HLS_PLAYER=1
[ -n "$LABS_TOOLBAR_BUTTON" ] || LABS_TOOLBAR_BUTTON=0
[ -n "$LENS" ] || LENS=1
[ -n "$LENS_TRANSLATE" ] || LENS_TRANSLATE=1
[ -n "$MEDIA_REMOTING" ] || MEDIA_REMOTING=1
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
[ -n "$SUPERVISED_USER" ] || SUPERVISED_USER=0
[ -n "$SWIFTSHADER" ] || SWIFTSHADER=1
[ -n "$SWIFTSHADER_WEBGPU" ] || SWIFTSHADER_WEBGPU=1
[ -n "$TRANSLATE" ] || TRANSLATE=1
[ -n "$VR" ] || VR=0
[ -n "$VAAPI" ] || VAAPI=1
[ -n "$WEBGPU" ] || WEBGPU=0
[ -n "$WIDEVINE" ] || WIDEVINE=1
[ -n "$ZSTD" ] || ZSTD=0

[ -n "$SYS_FFMPEG" ] || SYS_FFMPEG=0
[ -n "$SYS_ICU" ] || SYS_ICU=0
[ -n "$SYS_JPEG" ] || SYS_JPEG=1

## Allow freetype to be force-enabled (for stable builds)
[ -n "$SYS_FREETYPE" ] && SYS_FREETYPE_SET=1 || SYS_FREETYPE=1

## Allow harfbuzz to be force-enabled (for stable builds)
[ -n "$SYS_HARFBUZZ" ] && SYS_HARFBUZZ_SET=1 || SYS_HARFBUZZ=1

## OpenH254 support
[ -n "$OPENH264" ] && [ $OPENH264 -eq 0 ] && SYS_OPENH264=0 || OPENH264=1
[ -n "$SYS_OPENH264" ] || SYS_OPENH264=1

## MARCH and MTUNE defaults
[ -n "$MARCH" ] && MARCH_SET=1 || MARCH=x86-64-v2
[ -n "$MTUNE" ] && MTUNE_SET=1 || MTUNE=generic

## LTO Jobs (patch = 1; chromium default = all)
[ -n "$LTO_JOBS" ] || LTO_JOBS=0

## Managed Policy: Capture of audio/video/screen (eg for WebRTC)
[ -n "$CAP" ] && [ $CAP -eq 0 ] && CAP_AUD=0 && CAP_SCR=0 && CAP_VID=0 || CAP=1
[ -n "$CAP_AUD" ] || CAP_AUD=1
[ -n "$CAP_SCR" ] || CAP_SCR=1
[ -n "$CAP_VID" ] || CAP_VID=1

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
  SER="$SER -e \"s@^\(cromite/\)@#\1@\" -e \"s@^\(vanadium/\)@#\1@\""
  SUPERVISED_USER=1  # Setting this to zero requires a (non-free) cromite patch
  if [ $OPENH264 -eq 1 ] && [ $SYS_OPENH264 -eq 0 ]; then
    printf '%s\n' "Error: Not a non-free build"
    printf '%s\n' "Error: When NON_FREE=0, you must set SYS_OPENH264=1"
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
    AUTHOR='ungoogled-chromium Maintainers <github@null.invalid>'
    ;;
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

    VERSION=$VER-$REV
    ;;

  -|-[1-9]|-stable[1-9]|*-)
    printf '%s\n' "Malformed VERSION variable: $VERSION"
    exit 1
    ;;
esac



#####################################################
## Test mode | Clang versioning | LTO | Skia Gamma ##
#####################################################

## Enter test mode if $RT_DIR/third_party does not exist
[ -d $RT_DIR/third_party ] && TEST=0 || TEST=1


## Get/set/override default clang version from debian/rules.in
CR_VER=$(sed -n 's@^#export LLVM_VERSION := @@p' $DEBIAN/rules.in)

[ -n "$C_VER" ] && C_VER_SET=1 || C_VER=$CR_VER

if [ $C_VER_SET -eq 1 ] && [ $C_VER -lt $CR_VER ]; then
  printf '%s\n' "WARN: Clang versions below $CR_VER are not supported"
  printf '%s\n' "Disabling PGO support"
  PGO=0
fi



## Set LTO cache directory and number of LTO jobs
if [ -n "$LTO_DIR" ]; then
  if [ ! -d $LTO_DIR ] && [ $TEST -eq 0 ]; then
    printf '\n%s\n' "LTO_DIR: path $LTO_DIR does not exist"
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
          -i $OP_DIR/compiler-flags/thinlto-jobs.patch
        ;;
    esac
    ;;
esac



# Range is 1.0 to 3.0. Make 2 and 3 become 2.0 and 3.0.
case $SKIA_GAMMA in
  [23])
    # Ensure skia gamma values have one decimal place
    SKIA_GAMMA=${SKIA_GAMMA}.0 ;;
esac

# A value of 1 (not 1.0) just enables the patch
case $SKIA_GAMMA in
  1|[12].[0-9]|3.0)
    case $SKIA_GAMMA in
      [12].[0-9]|3.0)
        sed "s@2\.2@$SKIA_GAMMA@" -i $OP_DIR/fixes/skia-gamma.patch
        ;;
    esac

    op_enable="$op_enable skia-gamma"
    ;;
esac




#########################
## Symbol levels | PGO ##
#########################

## Set Symbol levels
case $SYMBOLS in
  -1|[1-2])
    RUL="$RUL -e \"s@^\([ \t]*symbol_level=\)0@\1$SYMBOLS@\"" ;;
esac

case $SYMBOLS_BLINK in
  -1|[1-2])
    RUL="$RUL -e \"s@^\([ \t]*blink_symbol_level=\)0@\1$SYMBOLS_BLINK@\"" ;;
esac



# Machine function splitting relies on PGO being enabled
if [ $PGO -eq 0 ] && [ $MF_SPLIT -eq 1 ]; then
  printf '%s\n' "WARN: MF_SPLIT depends on PGO=1"
  printf '%s\n' "Setting MF_SPLIT=0"
  MF_SPLIT=0
fi




####################################
## Clang/Polly/Rust configuration ##
####################################

## Enable the use of ccache
if [ $CCACHE -eq 1 ]; then
  # GN_FLAGS += cc_wrapper=ccache
  gn_enable="$gn_enable cc_wrapper"
fi


if [ $SYS_CLANG -eq 0 ]; then
  # Polly not available on bundled toolchain
  if [ $POLLY -eq 1 ]; then
    printf '%s\n' "ERROR: when SYS_CLANG=0 you cannot set POLLY=1"
    exit 1
  fi

  # Stop bundled toolchain directories from being pruned
  PRU="$PRU -e \"/^third_party\/llvm/d\""
  PRU="$PRU -e \"/^tools\/clang/d\""
else
  op_enable="$op_enable system/clang/clang-version-check"

  #GN_FLAGS += clang_base_path=CLANG_DIR clang_verion=CLANG_VER
  gn_enable="$gn_enable clang_base_path"

  CLANG_DIR=/usr/lib/llvm-$C_VER
  CLANG_VER=$C_VER

  if [ $SYS_CLANG -eq 1 ]; then
    # Grab the clang version used in debian/control.in
    CC_VER=$(sed -n 's@[ #]lld-\([^,]*\).*@\1@p' $DEBIAN/control.in)

    #### Clang/LLVM version sanity chack
    if [ $CC_VER -ne $CR_VER ]; then
      printf '%s\n' "WARN: Clang/LLVM version mismatch in d/control.in and d/rules.in"
    fi

    # Check that package version $C_VER is actually installed on the system
    if [ ! -x /usr/lib/llvm-$C_VER/bin/clang ] && [ $TEST -eq 0 ]; then
      printf '%s\n' "Cannot find /usr/lib/llvm-${C_VER}/bin/clang"
      exit 1
    fi

    deps_enable="$deps_enable lld clang libclang-rt"
    op_enable="$op_enable system/clang/rust-clanglib"

    # Change clang version in d/control if override version differs
    if [ $CC_VER -ne $C_VER ]; then
      CON="$CON -e \"s@\(lld-\)$CC_VER@\1$C_VER@\""
      CON="$CON -e \"s@\(clang-\)$CC_VER@\1$C_VER@\""
      CON="$CON -e \"s@\(libclang-rt-\)$CC_VER\(-dev\)@\1$C_VER\2@\""
    fi

    # Change clang version in d/rules if override version differs
    if [ $CR_VER -ne $C_VER ]; then
      RUL="$RUL -e \"s@^\(#export LLVM_VERSION :=\) $CR_VER@\1 $C_VER@\""
    fi

    # Uncomment the export of LLVM_VERSION and LLVM_DIR variables
    RUL="$RUL -e \"s@^#\(export LLVM_VERSION\)@\1@\""
    RUL="$RUL -e \"s@^#\(export LLVM_DIR\)@\1@\""

    # Prefix clang, clang++ and llvm-{ar,nm,ranlib} with $LLVM_DIR path
    RUL="$RUL -e \"s@^\(#export [ANR].*\)\(llvm-.*\)@\1\$LLVM_DIR/\2@\""
    RUL="$RUL -e \"s@^\(#export C[CX].*\)\(clang.*\)@\1\$LLVM_DIR/\2@\""
  else
    # Autodetect C_VER if it's not explicity set
    if [ $C_VER_SET -eq 0 ] && [ $TEST -eq 0 ]; then
      C_VER=$(realpath $(command -v clang) | sed 's@/usr/local/bin/clang-@@')
    fi

    CLANG_DIR=/usr/local
    CLANG_VER=$C_VER
  fi

  # Enable the system package/local toolchain
  RUL="$RUL -e \"s@^#\(.*_toolchain=\)@\1@\""
  RUL="$RUL -e \"s@^#\(export [ANR].*llvm-\)@\1@\""
  RUL="$RUL -e \"s@^#\(export C[CX].*clang\)@\1@\""
  RUL="$RUL -e \"s@^#\(export DEB_C[FX].*\)@\1@\""

  # Set clang path/version build flags in d/rules
  RUL="$RUL -e \"s@\(clang_base_path=\)_CLANG_DIR@\1\x5c\x22$CLANG_DIR\x5c\x22@\""
  RUL="$RUL -e \"s@\(clang_version=\)_CLANG_VER@\1\x5c\x22$CLANG_VER\x5c\x22@\""
fi


if [ $POLLY -eq 0 ]; then
  op_disable="$op_disable compiler-flags/polly"
fi


if [ $SYS_RUST -gt 0 ]; then
  # GN_FLAGS += rust_sysroot_absolute=RUST_PATH rustc_version=RUST_DASHV
  gn_enable="$gn_enable rust_sysroot_absolute"

  RUST_PATH="$HOME/.cargo"

  if [ $SYS_RUST -eq 1 ]; then
    op_enable="$op_enable system/rust"
    deps_enable="$deps_enable rustc"

    RUST_PATH="/usr"
    RUL="$RUL -e \"s@^#\(export \)@\1@\""
  fi

  RUST="$RUST_PATH/bin/rustc"
  RUST_VER="TEST"

  if [ $TEST -eq 0 ]; then
    if [ ! -x $RUST ]; then
      printf '%s\n' "$RUST does not exist (or is not executable)"
      exit 1
    fi

    RUST_VER="$($RUST -V)"
  fi

  RUL="$RUL -e \"s@^#\(export RUSTC_BOOTSTRAP=1\)@\1@\""
  RUL="$RUL -e \"s@\(rust_sysroot_absolute=\)_RUST_PATH@\1\x5c\x22$RUST_PATH\x5c\x22@\""
  RUL="$RUL -e \"s@\(rustc_version=\)_RUST_VER@\1\x5c\x22$RUST_VER\x5c\x22@\""
fi



#####################################################
## CPU architecture/instructions and optimisations ##
#####################################################

if [ $INTEL_CET -eq 1 ]; then
  op_enable="$op_enable compiler-flags/cpu/intel-cet/"
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
        -i $OP_DIR/compiler-flags/cpu/$i.patch
  done
fi


if [ $AVX2 -eq 1 ]; then
  AVX=1
  op_enable="$op_enable compiler-flags/cpu/avx2"
fi

if [ $AVX -eq 0 ]; then
  op_disable="$op_disable compiler-flags/cpu/avx"
else
  AES_PCLMUL=1
fi

if [ $AES_PCLMUL -eq 0 ]; then
  op_disable="$op_disable compiler-flags/cpu/aes-pclmul"
fi

if [ $RTC_AVX2 -eq 0 ]; then
  # GN_FLAGS += rtc_enable_avx2=false
  gn_enable="$gn_enable rtc_enable_avx2"
fi

if [ $V8_AVX2 -eq 0 ]; then
  # GN_FLAGS += v8_enable_wasm_simd256_revec=true
  gn_disable="$gn_disable v8_enable_wasm_simd256_revec"
fi




####################
## Managed Policy ##
####################

[ $CAP_AUD -eq 1 ] || POL="$POL -e \"/AudioCaptureAllowed/s@true@false@\""
[ $CAP_SCR -eq 1 ] || POL="$POL -e \"/ScreenCaptureAllowed/s@true@false@\""
[ $CAP_VID -eq 1 ] || POL="$POL -e \"/VideoCaptureAllowed/s@true@false@\""


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

if [ $ATK_DBUS -eq 0 ]; then
  op_enable="$op_enable disable/atk-dbus"

  # GN_FLAGS += use_atk=false use_dbus=false
  gn_enable="$gn_enable use_atk"
fi


if [ $CATAPULT -eq 0 ]; then
  op_enable="$op_enable disable/catapult"
fi


if [ $CHROMECAST -eq 0 ]; then
  op_enable="$op_enable disable/media-router"
  op_disable="$op_disable chromecast/"

  MEDIA_REMOTING=0
else
  P=fix-building-without-mdns-and-service-discovery
  SER_UC="$SER_UC -e \"s@^\(extra/ungoogled-chromium/$P\)@#\1@\""

  SMF="$SMF -e \"/^enable_mdns=false/d\""
  SMF="$SMF -e \"/^enable_remoting=false/d\""

  if [ $CHROMECAST -ge 2 ]; then
    sed -e 's@^\(export.*media-router=0\)@#\1@' \
        -e 's@^#\(export.*enable-mdns\)@\1@' \
        -i $FLAG_DIR/network
  fi
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

  rm $DEBIAN/ungoogled-chromium-driver.*
fi


if [ $EXTENSIONS_ROOT_MENU -eq 1 ]; then
  op_disable="$op_disable disable/extensions-in-root-menu"
fi


if [ $FEED -eq 0 ]; then
  # GN_FLAGS += enable_feed_v2=false
  gn_enable="$gn_enable enable_feed_v2"
fi


if [ $HLS_PLAYER -eq 0 ]; then
  gn_disable="$gn_disable enable_hls_demuxer"

  INS="$INS -e \"s@^\(debian/etc/chromium.d/hls-player\)@#\1@\""
elif [ $HLS_PLAYER -ge 2 ]; then
  sed -e 's@^#\(export.*enable-builtin-hls\)@\1@' \
      -e 's@^#\(export.*enable-features==HlsPlayer\)@\1@' \
      -i $FLAG_DIR/hls-player
fi


if [ $LABS_TOOLBAR_BUTTON -eq 1 ]; then
  sed 's@^#\(export.*chrome-labs\)@\1@' -i $FLAG_DIR/ui
fi


if [ $LENS -eq 0 ]; then
  # GN_FLAGS += enable_lens_desktop=false
  gn_enable="$gn_enable enable_lens_desktop"

  INS="$INS -e \"s@^\(debian/etc/chromium.d/google-lens\)@#\1@\""
else
  DSB="$DSB -e \"/^components\/lens\/lens_features\.cc/d\""

  if [ $LENS -ge 2 ]; then
    GOOGLE_API_KEYS=1
    if [ $LENS_TRANSLATE -eq 0 ]; then
      sed -e 's@^#\(export.*enable-lens-standalone\)@\1@' \
          -e 's@^\(export.*enable-lens-image-translate\)@#\1@' \
          -i $FLAG_DIR/google-lens
    else
      sed -e 's@^#\(export.*enable-lens-standalone\)@\1@' \
          -i $FLAG_DIR/google-lens
    fi
  fi
fi


if [ $MEDIA_REMOTING -eq 0 ]; then
  op_enable="$op_enable disable/media-remoting/"

  # GN_FLAGS += enable_media_remoting=false
  gn_enable="$gn_enable enable_media_remoting"
fi


if [ $MUTEX_PI -eq 0 ]; then
  op_disable="$op_disable mutex-priority-inheritance"
  gn_disable="$gn_disable enable_mutex_priority_inheritance"
fi


if [ $NOTIFICATIONS -eq 0 ]; then
  # GN_FLAGS += enable_system_notifications=false
  gn_enable="$gn_enable enable_system_notifications"
fi


if [ $OAUTH2 -eq 1 ]; then
  op_enable="$op_enable use-oauth2-client-switches-as-default"
fi


if [ $OPENTYPE_SVG -eq 0 ]; then
  op_disable="$op_disable opentype-svg/"
fi


if [ $OZONE_WAYLAND -eq 0 ]; then
  # GN_FLAGS += ozone_platform_wayland=false
  gn_enable="$gn_enable ozone_platform_wayland"
fi


if [ $PDF_JS -eq 1 ]; then
  # GN_FLAGS += pdf_enable_v8=false pdf_enable_xfa=false
  gn_disable="$gn_disable pdf_enable_v8"
fi


if [ $PRINT_PREVIEW -eq 0 ]; then
  # GN_FLAGS += enable_print_preview=false enable_oop_printing=false
  gn_enable="$gn_enable enable_print_preview"
fi


if [ $SPEECH -eq 0 ]; then
  # GN_FLAGS += enable_speech_service=false
  gn_enable="$gn_enable enable_speech_service"
fi


if [ $SUPERVISED_USER -eq 1 ]; then
  op_disable="$op_disable disable/supervised-users"

  # GN_FLAGS += enable_supervised_users=false
  gn_disable="$gn_disable enable_supervised_users"
fi


if [ $TRANSLATE -eq 0 ]; then
  op_disable="$op_disable translate/"

  INS="$INS -e \"s@^\($FLAG_DIR/google-translate\)@#\1@\""
else
  DSB="$DSB -e \"/\/translate_manager_browsertest\.cc/d\""
  DSB="$DSB -e \"/\/translate_script\.cc/d\""
  DSB="$DSB -e \"/\/translate_util\.cc/d\""

  if [ $TRANSLATE -ge 2 ]; then
    GOOGLE_API_KEYS=1
    sed 's@^#\(export.*translate-script-url=\)@\1@' -i $FLAG_DIR/google-translate
  fi
fi


if [ $VR -eq 1 ]; then
  gn_disable="$gn_disable enable_vr"
fi


if [ $WEBGPU -eq 0 ]; then
  # GN_FLAGS += use_dawn=false skia_use_dawn=false
  gn_enable="$gn_enable use_dawn"

  SWIFTSHADER_WEBGPU=0
elif [ $WEBGPU -ge 2 ]; then
  sed 's@^#\(.*enable-unsafe-webgpu\)@\1@' -i $DEBIAN/etc/chromium.d/gpu
fi


if [ $SWIFTSHADER -eq 0 ]; then
  # GN_FLAGS += enable_swiftshader=false
  gn_enable="$gn_enable enable_swiftshader"

  INS="$INS -e \"s@^\(out/Release/.*swiftshader\)@#\1@\""
else
  if [ $SWIFTSHADER_WEBGPU -eq 0 ]; then
    # GN_FLAGS += dawn_use_swiftshader=false
    gn_enable="$gn_enable dawn_use_swiftshader"
  fi
fi


if [ $WIDEVINE -eq 0 ]; then
  op_disable="$op_disable fixes/widevine/"
  SMF="$SMF -e \"s@^\(enable_widevine=\)true@\1false@\""
fi


if [ $XZ_EXTREME -eq 1 ]; then
  RUL="$RUL -e \"s@\(dh_builddeb .*\)@\1 -S extreme@\""
  [ $XZ_THREADED_SET -eq 1 ] && [ $XZ_THREADED -eq 0 ] || XZ_THREADED=1
fi

if [ $XZ_THREADED -eq 1 ]; then
  RUL="$RUL -e \"s@\(dh_builddeb .*\)@\1 --threads-max=\x24(JOBS)@\""
fi



## Enable Google API keys for google services
if [ $GOOGLE_API_KEYS -eq 1 ]; then
  sed 's@^#\(export GOOGLE_\)@\1@' -i $FLAG_DIR/google-api-keys
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
else
  sed '/disable-features=AllowQt/s@^@#@' -i $DEBIAN/etc/chromium.d/ui
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
  SYS_ICU=0

  # Disable by default if not force-enabled
  [ $SYS_FREETYPE_SET -eq 1 ] && [ $SYS_FREETYPE -eq 1 ] || SYS_FREETYPE=0

  # harfbuzz and freetpye need brotli 1.1 (see d/rules for dependency chain info)
  if [ $SYS_HARFBUZZ_SET -eq 1 ] && [ $SYS_HARFBUZZ -eq 1 ]; then
    # Force-enable freetype if harfbuzz has been force-enabled
    SYS_FREETYPE=1
  else
    # Disable harfbuzz by default on stable
    SYS_HARFBUZZ=0
  fi

  if [ $SYS_FREETYPE -eq 1 ]; then
    op_enable="$op_enable system/freetype-COLRV1"
  fi

  op_disable="$op_disable system/unstable/dav1d/"
  op_enable="$op_enable fixes/dav1d-bundled-header"

  sys_disable="$sys_disable dav1d"
  deps_disable="$deps_disable libdav1d"

  # Build error since v117 seemingly only affecting stable
  op_enable="$op_enable fixes/no-ELOC_PROTO-mnemonic"
fi


if [ $SYS_FREETYPE -eq 0 ]; then
  if [ $OPENTYPE_SVG -eq 1 ]; then
    op_enable="$op_enable fixes/opentype-svg-on-bundled-freetype"
  fi

  # SYS_LIBS += fontconfig freetype brotli libpng
  sys_disable="$sys_disable fontconfig"
  deps_disable="$deps_disable libfontconfig brotli"

  ## System libpng must be enabled separately when SYS_FREETYPE=0
  sys_enable="$sys_enable libpng"
fi


if [ $SYS_HARFBUZZ -eq 0 ]; then
  sys_disable="$sys_disable harfbuzz-ng"
  deps_disable="$deps_disable libharfbuzz"
fi


if [ $SYS_ICU -eq 0 ]; then
  op_disable="$op_disable system/unstable/icu/"
  op_enable="$op_enable fixes/convertutf-bundled"

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
DSB="$DSB -e \"/^content\/browser\/resources\/gpu\/info_view\.ts/d\""
DSB="$DSB -e \"/^third_party\/depot_tools\//d\""
DSB="$DSB -e \"/^tools\/clang\//d\""


## Pruning/Submodule flags
PRU="$PRU -e \"/^third_party\/depot_tools/d\""

if [ $PGO -eq 1 ]; then
  PRU="$PRU -e \"/^chrome\/build\/pgo_profiles/d\""
  SMF="$SMF -e \"/^chrome_pgo_phase/d\""
fi

SMF="$SMF -e \"/^enable_hangout_services_extension/d\""
SMF="$SMF -e \"/^enable_nacl/d\""
SMF="$SMF -e \"/^enable_service_discovery/d\""
SMF="$SMF -e \"/^exclude_unwind_tables/d\""
SMF="$SMF -e \"/^google_api_key/d\""
SMF="$SMF -e \"/^google_default_client_id/d\""
SMF="$SMF -e \"/^google_default_client_secret/d\""




##############################
##  Aggregate sed commands  ##
##############################

## dependencies

if [ -n "$deps_disable" ]; then
  for i in $deps_disable; do
    CON="$CON -e \"s@^[ ]*\($i\)@#\1@\""
  done
fi

if [ -n "$deps_enable" ]; then
  for i in $deps_enable; do
    CON="$CON -e \"s@^[ ]*#[ ]*\($i\)@ \1@\""
  done
fi


## optional patches

if [ -n "$op_disable" ]; then
  for i in $op_disable; do
    case $i in
      optional/*)
        sanitise_op ;;
    esac

    case $i in
      */|*.patch)
        SER="$SER -e \"s@^\(optional/$i\)@#\1@\""
        ;;

      *)
        SER="$SER -e \"s@^\(optional/$i\.patch\)@#\1@\""
        ;;
    esac
  done
fi

if [ -n "$op_enable" ]; then
  for i in $op_enable; do
    case $i in
      optional/*)
        sanitise_op ;;
    esac

    case $i in
      */|*.patch)
        SER="$SER -e \"s@^#\(optional/$i\)@\1@\""
        ;;

      *)
        SER="$SER -e \"s@^#\(optional/$i\.patch\)@\1@\""
        ;;
    esac
  done
fi


## Build flags (GN_FLAGS)

if [ -n "$gn_disable" ]; then
  for i in $gn_disable; do
    RUL="$RUL -e \"s@^\(GN_FLAGS += $i=*\)@#\1@\""
  done
fi

if [ -n "$gn_enable" ]; then
  for i in $gn_enable; do
    RUL="$RUL -e \"s@^#\(GN_FLAGS += $i=*\)@\1@\""
  done
fi


## System libraries (SYS_LIBS)

if [ -n "$sys_disable" ]; then
  for i in $sys_disable; do
    RUL="$RUL -e \"s@^\(SYS_LIBS += $i\)@#\1@\""
  done
fi

if [ -n "$sys_enable" ]; then
  for i in $sys_enable; do
    RUL="$RUL -e \"s@^#\(SYS_LIBS += $i\)@\1@\""
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


case $SER in
  "")
    SERIES_DEBIAN="$(cat $DEBIAN/patches/series.debian)" ;;

  *)
    SERIES_DEBIAN="$(eval sed $SER $DEBIAN/patches/series.debian)" ;;
esac

case $SER_UC in
  "")
    SERIES_UC="$(cat $UC_DIR/patches/series)" ;;

  *)
    SERIES_UC="$(eval sed $SER_UC $UC_DIR/patches/series)" ;;
esac

echo "$SERIES_UC" "$SERIES_DEBIAN" > $DEBIAN/patches/series


[ -z "$INS" ] || eval sed $INS < $DEBIAN/$INSTALL.in > $DEBIAN/$INSTALL

[ -z "$POL" ] || eval sed $POL < $DEBIAN/$P_FILE.in > $DEBIAN/$P_FILE

eval sed $CON < $DEBIAN/control.in > $DEBIAN/control

eval sed $RUL < $DEBIAN/rules.in > $DEBIAN/rules

eval sed $DSB -i $UC_DIR/domain_substitution.list

eval sed $SMF -i $UC_DIR/flags.gn

eval sed $PRU -i $UC_DIR/pruning.list


## Ensure control, rules, ungoogled-chromium.install and policies.json exist
for file in control rules $INSTALL $P_FILE; do
  [ -f $DEBIAN/$file ] || mv $DEBIAN/$file.in $DEBIAN/$file
done

## Make d/rules and d/ungoogled-chromium.install executable
chmod 0700 $DEBIAN/rules
chmod 0700 $DEBIAN/ungoogled-chromium.install



###################################
##  Prepare miscellaneous files  ##
###################################

## Shell launcher
if [ $TEST -eq 0 ]; then
  $DEBIAN/devutils/update_launcher.sh \
    < $DEBIAN/shims/chromium.sh > $DEBIAN/shims/chromium
fi


## Copy upstream UC patches into debian/patches
if [ -d $UC_DIR/patches/upstream ]; then
  UC_PATCH_DIRS="$UC_PATCH_DIRS $UC_DIR/patches/upstream"
fi

mv $UC_PATCH_DIRS $DEBIAN/patches/


## Submodule patching
patch -p1 < $PRUNE_PATCH >/dev/null


exit $?
