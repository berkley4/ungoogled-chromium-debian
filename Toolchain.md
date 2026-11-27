# Building Clang/LLVM

The bundled Clang/LLVM toolchain does not support LLVM Polly optimisations, so if
you want to enable the llvm-polly-* patches then a different toolchain is required.

To build a PGO-optimised chromium (using the bundled PGO profile) a sufficiently new
version of clang is required, whereby the major version (eg 18) equals or exceeds
that of the bundled toolchain.

The clang/llvm packages from debian experimental often suffice, however these can be
several months old. Versions of clang from stable or unstable almost always require
extra patches, while the llvm repo (apt.llvm.org) offers up-to-date snapshots for
both stable and unstable.

Building your own Clang/LLVM toolchain offers a certain advantages over installing
from debian or apt.llvm.org :-

- The ability to customise what gets installed (ie less bloat)
- One can match the exact version (even the git commit) of the bundled version
- Build an PGO/Bolt/LTO optimised toolchain

Note: it's recommended when using BOLT-PGO.config with LTO to have at least 32GB
of ram. Those with 16GB or less should use PGO.cmake and configure the build with
DPGO_INSTRUMENT_LTO=Off.

With building chromium taking some hours on an older PC, the best argument is
probably speed. As far as I know, the packages from the debian and llvm repos
are not bolt-optimised (which gives a significant speed boost).

Below are the steps needed to build and install. Compilation time should be no
more than a couple of hours on a cpu from the last decade or so, probably half
that or less on anything relatively new.


___Clone (if you have NOT built before)___

```sh
git clone --depth 1 -b main https://github.com/llvm/llvm-project
```

___Update (if you have built before)___

```sh
git clean -dfx
git reset --hard HEAD
```

Note that I'm using --jobs=4 to use 4 threads and '<HASH>' is the clang
git hash listed in the 'Build toolchain' section of [Releases](https://github.com/berkley4/ungoogled-chromium-debian/releases).

```sh
git fetch --depth 1 --jobs=4 origin <HASH>
git checkout FETCH_HEAD
```

___Configuration___

See what /usr/bin/x86_64-linux-gnu-ld points to :-

```sh
ls -l /usr/bin/x86_64-linux-gnu-ld
```

Note this down in case you want to change back. Now make sure
that ld points at /usr/lib/llvm-16/bin/lld :-

```sh
cd /usr/bin

ln -sf $LLVM_DIR/lld x86_64-linux-gnu-ld
```

You can optionally add the following feature flags to the command below :-

-DLLVM_ENABLE_RTTI=ON to enable RTTI (needed by mesa)

-DLLVM_PARALLEL_LINK_JOBS=1 if you are ram limited

Note: limiting the link jobs is probably a good idea even with 32GB if compiling the BOLT-PGO config.

Export your clang bin directory, for example :-

```sh
export LLVM_DIR=/usr/lib/llvm-24/bin
```

or

```sh
export LLVM_DIR=/usr/local/bin
```

Now edit the text below into a single line and execute it inside the git root directory.
Note that /usr/local is used for CMAKE_INSTALL_PREFIX.

```sh
AR=$LLVM_DIR/llvm-ar NM=$LLVM_DIR/llvm-nm RANLIB=$LLVM_DIR/llvm-ranlib CC=$LLVM_DIR/clang CXX=$LLVM_DIR/clang++ \
cmake -B build -G Ninja -S llvm -C clang/cmake/caches/BOLT-PGO.cmake \
-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DPGO_INSTRUMENT_LTO=Thin \
-DLLVM_ENABLE_PROJECTS="clang;lld;bolt" -DLLVM_ENABLE_RUNTIMES="compiler-rt" \
-DLLVM_TARGETS_TO_BUILD="Native" -DLLVM_ENABLE_LLD=ON -DLLVM_BUILD_UTILS=OFF \
-DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_GO_TESTS=OFF -DLLVM_ENABLE_CURL=OFF \
-DLLVM_ENABLE_TERMINFO=OFF -DLLVM_ENABLE_Z3_SOLVER=OFF -DLLVM_PARALLEL_LINK_JOBS=1 \
-DCLANG_ENABLE_OBJC_REWRITER=OFF -DCLANG_ENABLE_STATIC_ANALYZER=OFF -DCLANG_PLUGIN_SUPPORT=OFF \
-DCOMPILER_RT_BUILD_BUILTINS=OFF -DCOMPILER_RT_BUILD_CRT=OFF -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
-DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF -DBOOTSTRAP_CMAKE_BUILD_TYPE=Release \
-DBOOTSTRAP_LLVM_ENABLE_PROJECTS="clang;lld" -DBOOTSTRAP_LLVM_TARGETS_TO_BUILD="X86;WebAssembly" \
-DBOOTSTRAP_LLVM_ENABLE_LLD=ON -DBOOTSTRAP_LLVM_BUILD_UTILS=OFF -DBOOTSTRAP_LLVM_INCLUDE_TESTS=OFF \
-DBOOTSTRAP_LLVM_INCLUDE_GO_TESTS=OFF -DBOOTSTRAP_LLVM_ENABLE_CURL=OFF -DBOOTSTRAP_LLVM_ENABLE_TERMINFO=OFF \
-DBOOTSTRAP_LLVM_ENABLE_Z3_SOLVER=OFF -DBOOTSTRAP_LLVM_PARALLEL_LINK_JOBS=1 -DBOOTSTRAP_CLANG_ENABLE_OBJC_REWRITER=OFF \
-DBOOTSTRAP_CLANG_ENABLE_STATIC_ANALYZER=OFF -DBOOTSTRAP_CLANG_PLUGIN_SUPPORT=OFF -DBOOTSTRAP_BOOTSTRAP_CMAKE_BUILD_TYPE=Release \
-DBOOTSTRAP_BOOTSTRAP_LLVM_ENABLE_PROJECTS="bolt;clang;lld;polly" -DBOOTSTRAP_BOOTSTRAP_LLVM_ENABLE_RUNTIMES="compiler-rt" \
-DBOOTSTRAP_BOOTSTRAP_LLVM_TARGETS_TO_BUILD="X86;WebAssembly" -DBOOTSTRAP_BOOTSTRAP_LLVM_ENABLE_LLD=ON \
-DBOOTSTRAP_BOOTSTRAP_LLVM_BUILD_LLVM_DYLIB=OFF -DBOOTSTRAP_BOOTSTRAP_LLVM_LINK_LLVM_DYLIB=OFF \
-DBOOTSTRAP_BOOTSTRAP_LLVM_POLLY_LINK_INTO_TOOLS=ON -DBOOTSTRAP_BOOTSTRAP_LLVM_BUILD_UTILS=OFF \
-DBOOTSTRAP_BOOTSTRAP_LLVM_INCLUDE_TESTS=OFF -DBOOTSTRAP_BOOTSTRAP_LLVM_INCLUDE_GO_TESTS=OFF \
-DBOOTSTRAP_BOOTSTRAP_LLVM_ENABLE_CURL=OFF -DBOOTSTRAP_BOOTSTRAP_LLVM_ENABLE_RTTI=ON \
-DBOOTSTRAP_BOOTSTRAP_LLVM_ENABLE_TERMINFO=OFF -DBOOTSTRAP_BOOTSTRAP_LLVM_ENABLE_UNWIND_TABLES=OFF \
-DBOOTSTRAP_BOOTSTRAP_LLVM_ENABLE_Z3_SOLVER=OFF -DBOOTSTRAP_BOOTSTRAP_LLVM_USE_SPLIT_DWARF=ON \
-DBOOTSTRAP_BOOTSTRAP_LLVM_PARALLEL_LINK_JOBS=1 -DBOOTSTRAP_BOOTSTRAP_CLANG_ENABLE_OBJC_REWRITER=OFF \
-DBOOTSTRAP_BOOTSTRAP_CLANG_ENABLE_STATIC_ANALYZER=OFF -DBOOTSTRAP_BOOTSTRAP_CLANG_PLUGIN_SUPPORT=OFF \
-DBOOTSTRAP_BOOTSTRAP_COMPILER_RT_BUILD_BUILTINS=OFF -DBOOTSTRAP_BOOTSTRAP_COMPILER_RT_BUILD_CRT=OFF \
-DBOOTSTRAP_BOOTSTRAP_COMPILER_RT_BUILD_LIBFUZZER=OFF -DBOOTSTRAP_BOOTSTRAP_COMPILER_RT_BUILD_SANITIZERS=ON \
-DBOOTSTRAP_BOOTSTRAP_COMPILER_RT_BUILD_XRAY=OFF -DBOOTSTRAP_BOOTSTRAP_COMPILER_RT_SANITIZERS_TO_BUILD="asan;tsan;safestack;cfi" \
-DBOOTSTRAP_BOOTSTRAP_COMPILER_RT_USE_LIBCXX=NO \
-DBOOTSTRAP_BOOTSTRAP_LLVM_DISTRIBUTION_COMPONENTS="clang;clang-format;clang-scan-deps;clang-resource-headers;lld;LTO;runtimes;llvm-ar;llvm-ranlib;llvm-nm;llvm-objcopy;llvm-objdump;llvm-readobj;llvm-strip;llvm-symbolizer;llvm-cxxfilt;llvm-profdata;llvm-cov"
```


For clarity I'll use -j4 below instead of -j`<number of threads>`.


___Compile___
```sh
cd build
cmake --build build -j4 --target stage2-clang-bolt
```


___Install___

To install a stripped target run the following command as root :-

```sh
ninja -j4 -C build/tools/clang/stage2-instrumented-bins/tools/clang/stage2-bins install-distribution-stripped
```


___Check for existence of cfi_ignorelist.txt (Not normally needed, but worth checking)___

This seems to be a bug which is easiest to solve by manually
copying the file from your git checkout to your installation.

```sh
ls compiler-rt/lib/cfi/cfi_ignorelist.txt
```
```sh
cp compiler-rt/lib/cfi/cfi_ignorelist.txt /usr/local/lib/clang/24/share/
```

As root, make sure this file is readable by all :-
```sh
chmod 0644 /usr/local/lib/clang/24/share/cfi_ignorelist.txt
```


___Fix permissions___

Note: you need to be root to do the following.

Installing generates root-owned objects in the build directory, which interfere with
subsequent builds. So after installing, do the following :-

```sh
chown -R <user>:<user> build
```

Permissions of 0700 won't allow users to access directories, and cause runtime errors.

Check to see if you have any :-

```sh
find /usr/local/ -type d | while read l; do [ $(stat -c %a "$l") -eq 755 ] || ls -ld "$l"; done
```

Correct them with :-

```sh
find /usr/local/ -type d | while read l; do [ $(stat -c %a "$l") -eq 755 ] || chmod 0755 "$l"; done
```


___Uninstalling___

The easiest way to uninstall is to literally delete each file/directory listed in the
various install_manifest.txt files.

```sh
find -type f -name install_manifest.txt | while read l; do xargs rm -rf < $l; done
```
