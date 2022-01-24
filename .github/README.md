# ungoogled-chromium-debian

This is my fork of the unified branch of [ungoogle-chromium-debian](https://github.com/ungoogled-software/ungoogled-chromium-debian).

There are debs in the release section which are built with -march=[x86-64-v2](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels) --mtune=generic.
These should run on cpus from the Nehalem/Jaguar era (circa 2009) onwards.

From 96.0.4664.93 onwards the debs are built in a debian stable chroot, so should work on that, Ubuntu Focal and newer.


The main features and changes are as follows :-


___Performance improvements___

- Profile Guided Optimisation (PGO) - smaller, faster binaries
- Upstream optimisation - levels vary per target (versus debian's -O2 everywhere default)
- V8 pointer compression - memory usage/speed improvement (see [here](https://v8.dev/blog/pointer-compression))
- Built with -fno-plt - speed improvement


___Security/Privacy improvements___

- Control Flow Integrity (CFI) is always kept enabled (unlike upstream debian)
- Extra bromite patches, which include the following clang options :-
    - -fwrapv - disables unsafe optimisations (see [here](https://gitlab.e.foundation/e/apps/browser/-/blob/master/build/patches/Enable-fwrapv-in-Clang-for-non-UBSan-builds.patch))
    - -ftrivial-auto-var-init=zero - improves security (see [here](https://lists.llvm.org/pipermail/cfe-dev/2020-April/065221.html))
- An example policy file is included in the repo (can be edited and enabled at build time)
- Some security/privacy themed flag files are installed to /etc/chromium.d (strict isolation is enabled by default)


___Other features/changes___

- Enabled pipewire - for wayland
- ~~Vulkan support - opt-in via runtime switches (see further below)~~
- Shell script launcher - perhaps slightly more secure
- Bundled libpng - avoids an upstream debian bug (see [here](https://github.com/ungoogled-software/ungoogled-chromium-debian/issues/169))
- Upstream debian patches - a few hard to maintain and otherwise dubious patches have been dropped
- Separate deb packages for chromium's components (eg chromedriver, sandbox, languages)
- Dropped ungoogled-chromium-common - its contents split between a new libraries package and the main one
- New ungoogled-chromium-libraries package for libEGL.so, libGLESv2.so, etc (likely not needed by everyone)
- Google translate - optional build support


___Build system___

- Built with upstream google clang/llvm binaries (auto-downloaded during build setup)
- A bit more robust in general eg rebuilds should be faster and less error prone
- All patching is handled by debian - ungoogled patches are merged with the debian patches during build setup
- The Extended Stable branch is built with a chromium git tree (google supplies no release tarballs for this branch)
- Several fixes and improvements


- - - -


The following are optional features :-


___Enable Vulkan___
[currently disabled]

~~Vulkan can be enabled via uncommenting the following runtime flags in /etc/chromium.d/gpu-options~~ :-

--use-vulkan
--enable-features=vulkan
--disable-vulkan-fallback-to-gl-for-testing

In addition, it appears that the environment variable VK_ICD_FILENAMES needs to be set, eg :-
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json chromium


___Google Translate___

Not enabled by default in the binaries, you need to build it yourself.

To build with google translate enabled, instead of running debian/rules setup, run the following :-

debian/rules setup_translate


Uncomment the runtime flag in /etc/chromium.d/google-translate to enable.


- - - -

## Prepare ungoogled-chromium-debian packaging

```sh
# Install initial packages
sudo apt install -y devscripts equivs

# Clone ungoogled-chromium-debian
git clone -b extended_stable https://github.com/berkley4/ungoogled-chromium-debian.git

# Update submodes
cd debian
git submodule update --init --recursive
cd ..
```

## Cloning and preparing the chromium git repo

```sh
# Clone depot_tools and put it in your PATH
git clone https://chromium.googlesource.com/chromium/tools/depot_tools
export PATH=$PATH:/path/to/depot_tools

# Clone the chromium repository
mkdir build
cd build
fetch --nohooks chromium --target_os=linux

# Fetch the tags and checkout the desired chromium version
cd src
git fetch origin --tags
git checkout 999.0.1234.567

# Prepare the tree for building
cd ..
gclient sync -D --force --nohooks --with_branch_heads
gclient runhooks
```


## Cleaning/Resetting an existing chromium git repo (skip if clone has just been made)

```sh
# Perform a hard reset to HEAD
cd build/src
git reset --hard HEAD

# Clean untracked files (a result of the unbundling process)
cd third_party
rm -rf flac fontconfig/src freetype/src icu jsoncpp/source libdrm/src libjpeg_turbo re2/src snappy/src

# Check to see if there are any more untracked files
cd ..
git status

# cd ..
gclient sync -D --force --nohooks --with_branch_heads
gclient runhooks
```


## Building the binary packages

```sh
# Copy over the debian directory into your source tree
cd src
cp -a ../../ungoogled-chromium-debian/debian .

# Prepare the local source
VERSION=999.0.1234.567 debian/rules gitsubreset
debian/rules setup

# Optional: apply and refresh patches
while quilt push; do quilt refresh; done

# Build the package
JOBS=4 dpkg-buildpackage -b -uc
```
