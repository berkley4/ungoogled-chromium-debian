# Building Clang/LLVM

The bundled Clang/LLVM toolchain does not support LLVM Polly optimisations, so a
different toolchain is required.

To build a PGO-optimised chromium (using the bundled PGO profile) a sufficiently new
version of clang is required (at least the major version numbers must match).

For debian unstable these are normally available via experimental, however these can
be several months old. The llvm repo (apt.llvm.org) offers up-to-date snapshots for
both stable and unstable.

Building your own Clang/LLVM toolchain offers some advantages over installing from
debian or apt.llvm.org :-

- Ability to customise what gets installed (less bloat)
- You can build with native cpu optimisation (-march=native)
- Build an LTO, PGO and Bolt-optimised toolchain

With building chromium taking some hours on an older PC, the best argument is
probably speed. As far as I know, the packages from the debian and llvm
repositories are not Bolt-optimised (which gives a significant speed boost).

Below are the steps needed to build and install. Replace anything in angle brackets
with what applies to your own machine/setup.


___Clone___

git clone --depth 1 -b main https://github.com/llvm/llvm-project


___Updating___

git fetch --depth 1 --jobs=<number of threads> origin
git checkout origin/main


___Clean the build___

git reset --hard HEAD


___Configure___

```sh
export LLVM_DIR=/usr/lib/llvm-16/bin
```

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

Paste the following as a single line (ie without the '\' linebreaks) :-

```sh
AR=$LLVM_DIR/llvm-ar NM=$LLVM_DIR/llvm-nm RANLIB=$LLVM_DIR/llvm-ranlib CC=$LLVM_DIR/clang CXX=$LLVM_DIR/clang++ \
CFLAGS="-fno-plt -march=native -Wno-profile-instr-unprofiled" CXXFLAGS="-fno-plt -march=native -Wno-profile-instr-unprofiled" \
LDFLAGS="-Wl,-mllvm,-import-instr-limit=25 -Wl,-mllvm,-import-hot-multiplier=16" \
cmake -B build -G Ninja llvm -C clang/cmake/caches/BOLT-PGO.cmake -DCMAKE_BUILD_TYPE=Release \
-DLLVM_ENABLE_PROJECTS='bolt;clang;lld;openmp;polly' -DLLVM_BUILD_UTILS=OFF -DLLVM_TARGETS_TO_BUILD="X86;WebAssembly" \
-DLLVM_ENABLE_CURL=OFF -DLLVM_ENABLE_LLD=ON -DLLVM_ENABLE_TERMINFO=OFF -DLLVM_ENABLE_UNWIND_TABLES=OFF -DLLVM_ENABLE_Z3_SOLVER=OFF \
-DLLVM_INCLUDE_GO_TESTS=OFF -DLLVM_USE_SPLIT_DWARF=ON -DCLANG_ENABLE_ARCMT=OFF -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
-DCLANG_PLUGIN_SUPPORT=OFF -DCOMPILER_RT_BUILD_BUILTINS=OFF -DCOMPILER_RT_BUILD_CRT=OFF -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
-DCOMPILER_RT_BUILD_SANITIZERS=ON -DCOMPILER_RT_BUILD_XRAY=OFF \
-DCOMPILER_RT_SANITIZERS_TO_BUILD='asan;dfsan;msan;hwasan;tsan;safestack;cfi' -DCOMPILER_RT_USE_LIBCXX=NO -DLLVM_BUILD_LLVM_DYLIB=ON \
-DLLVM_LINK_LLVM_DYLIB=ON -DBOOTSTRAP_LLVM_ENABLE_LLD=ON -DBOOTSTRAP_BOOTSTRAP_LLVM_ENABLE_LLD=ON -DPGO_INSTRUMENT_LTO=Thin
```

If you have built before then run :-

```sh
ninja -j4 -C build -t cleandead
```

___Compile___
```sh
cd build
ninja -j4 stage2-clang-bolt
```

(-j4 = four threads)


___Install___

Default install target is /usr/local, so do this as root :-

```sh
ninja -j4 install
```


___Check for root-only permissions___

Note: you need to be root to do the following.

Installing generates root-owned objects in the build directory, which interfere with
subsequent builds. So after installing, do the following :-

```sh
chown -R <user>:<user> build
```

Permissions of 0700 won't allow users to access directories, and cause runtime errors.

Check to see if you have any :-

```sh
find /usr/local/ -type d | while read l; do [ $(stat -c %a "$l") -eq 0700 ] && ls -ld "$l"; done
```

Correct them with :-

```sh
find /usr/local/ -type d | while read l; do [ $(stat -c %a "$l") -eq 0700 ] && chmod 0755 "$l"; done
```


___Uninstalling___

The easiest way to uninstall is to literally delete each file/directory listed in the
various install_manifest.txt files.

```sh
find -type f -name install_manifest.txt | while read l; do xargs rm -rf < $l; done
```
