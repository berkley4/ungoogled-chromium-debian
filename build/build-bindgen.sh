#!/bin/sh -e

USAGE="[CLANG_VER=<version>] [SYS_CLANG=<0|1|2>] SYS_RUST=<0|1|2> ${0##*/} [h|help] [c|clean|hc|hardclean]"

case $USER in
  root)
    printf '%s\n' "Run this script as an unprivileged user"
    exit 1 ;;
esac

case $0 in
  ./build-bindgen.sh|build-bindgen.sh)
    : ;;

  *)
    printf '%s\n' "Please run this script from the directory containing it"
    exit 1 ;;
esac


DL_CACHE=.download_cache

bg_tag=upstream/v0.69.4
nc_ver=Ws0ru48A4IYoYLVKbV5K5_mDYT4ml9LAQUKdkiczdlMC

bg_repo=https://chromium.googlesource.com/external/github.com/rust-lang/rust-bindgen.git
nc_base_url=https://chrome-infra-packages.appspot.com/p/infra/3pp/static_libs/ncursesw/linux-amd64

nc_page_url="$nc_base_url/+/$nc_ver"
nc_file=ncursesw-linux-amd64.zip


get_nc_url() {
  sed -n -e 's@\&amp;@\&@g' -e 's@.*"\(https://storage.googleapis.com/[^"]*\).*@\1@p'
}

real_dir_path() {
  OLDPWD=- CDPATH= cd -P -- $1 && pwd
}


case $1 in
  c|clean|hc|hardclean)
    for dir in rust-bindgen ncursesw; do
      [ ! -d $dir ] || files="$files $dir"
    done

    case $1 in
      hc|hardclean)
        [ ! -d $DL_CACHE ] || files="$files $DL_CACHE" ;;
    esac

    rm -rf $files

    exit $? ;;

  h|help)
    printf '%s\n' "$USAGE"
    exit 0 ;;
esac


# Set CLANG_PATH values acording to SYS_CLANG from the environment
case $SYS_CLANG in
  "")
    printf '%s\n' "ERROR: SYS_CLANG not set, please specify a value for it"
    printf '%s\n' "ERROR: for example: SYS_CLANG=2 SYS_RUST=1 ./build-bindgen.sh"
    exit 1 ;;
esac


case $SYS_RUST in
  "")
    printf '%s\n' "ERROR: SYS_RUST is not set, please specify a value for it"
    printf '%s\n' "ERROR: for example: SYS_CLANG=2 SYS_RUST=1 ./build-bindgen.sh"
    exit 1 ;;
esac


# Set RUST_PATH according to value of SYS_RUST (default is SYS_RUST=0)
RUST_PATH=third_party/rust-toolchain/bin
if [ $SYS_RUST -eq 1 ]; then
  RUST_PATH=/usr/bin
elif [ $SYS_RUST -ge 2 ]; then
  RUST_PATH=$HOME/.cargo/bin
fi

if [ $SYS_RUST -eq 0 ] || [ $SYS_RUST -ge 2 ]; then
  export PATH="$RUST_PATH:$PATH"

  if [ $SYS_RUST -eq 0 ] && [ $SYS_CLANG -ne 0 ]; then
    printf '%s\n' "ERROR: cannot set SYS_CLANG=$SYS_CLANG when SYS_RUST=0"
    exit 1
  fi
fi


# Set CLANG_PATH according to value of SYS_CLANG (default is SYS_CLANG=0)
# This variable is used for pointing at the location of the libclang.so library
# Note: for SYS_CLANG=0 it's NOT set to third_party/llvm-build/Release+Asserts
CLANG_PATH=${RUST_PATH%/*}
if [ $SYS_CLANG -eq 1 ]; then
  case $CLANG_VER in
    "")
      printf '%s\n' "ERROR: SYS_CLANG=1 requires setting CLANG_VER"
      printf '%s\n' "ERROR: for example: CLANG_VER=19 SYS_CLANG=1 ./build-bindgen.sh"
      exit 1 ;;
  esac

  CLANG_PATH=/usr/lib/llvm-$CLANG_VER
elif [ $SYS_CLANG -ge 2 ]; then
  CLANG_PATH=/usr/local
fi


# Set both LIBCLANG_PATH and LIBCLANG_STATIC_PATH to this value at build time
LIBCLANG_PATH=$CLANG_PATH/lib


if [ ! -f build-bindgen.sh ]; then
  printf '%s\n' "ERROR: please run the script from the directory containing it"
  exit 1
fi


## Check that cargo, curl, rustc and unzip are available
for prog in cargo curl rustc unzip; do
  if ! command -v $prog >/dev/null 2>&1; then
    printf '%s\n' "ERROR: please install $prog and re-run the script"
    exit 1
  fi
done


if [ ! -d ncursesw ]; then
  ## Download/extract ncursesw (prefer aria2c, fall back to wget).
  command -v aria2c >/dev/null 2>&1 && D_LOADER=aria2c || D_LOADER=wget

  mkdir ncursesw
  [ -d $DL_CACHE ] || mkdir $DL_CACHE

  case $D_LOADER in
    aria2c)
      dl_args="-x1 -s1 -c -o $nc_file -d $DL_CACHE" ;;

    *)
      dl_args="--continue -O $nc_file -P $DL_CACHE" ;;
  esac

  if [ ! -f $DL_CACHE/$nc_file ]; then
    $D_LOADER $dl_args "$(curl -s $nc_page_url | get_nc_url)"
  fi

  unzip -q $DL_CACHE/$nc_file -d ncursesw
fi

nc_path=$(real_dir_path ncursesw)


## Clone/update the rust-bindgen repo
if [ -d rust-bindgen ]; then
  cd rust-bindgen
  git clean -dfx
  git reset --hard HEAD
  git fetch --depth 1 origin tag $bg_tag
  git checkout tags/$bg_tag
else
  git clone --depth=1 -c advice.detachedHead=false -b $bg_tag $bg_repo
  cd rust-bindgen
fi


[ ! -d target ] || rm -rf target


LLVM_CONFIG_PATH=$CLANG_PATH/bin/llvm-config \
LIBCLANG_PATH=$LIBCLANG_PATH \
LIBCLANG_STATIC_PATH=$LIBCLANG_PATH \
CC=$CLANG_PATH/bin/clang \
CXX=$CLANG_PATH/bin/clang++ \
LD=clang \
CFLAGS=-I$nc_path/include \
CXXFLAGS=-I$nc_path/include \
LDFLAGS="-L$nc_path/lib -fuse-ld=lld" \
RUSTFLAGS="-Clink-arg=-L$nc_path/lib -Clink-arg=-fuse-ld=lld -Clinker=clang" \
cargo build --no-default-features --features=logging,runtime --release --bin bindgen


$CLANG_PATH/bin/llvm-strip target/release/bindgen
chmod 0755 target/release/bindgen

printf '\n%s\n\n' "Run the following as root :-"
printf '%s\n' "cp --preserve=timestamps,mode $(real_dir_path target/release)/bindgen /usr/local/bin/"


cd - >/dev/null



exit $?
