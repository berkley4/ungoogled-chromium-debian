# ungoogled-chromium-debian

This is my fork of the unified branch of [ungoogle-chromium-debian](https://github.com/ungoogled-software/ungoogled-chromium-debian).

There are debs in the release section which are built with -march=x86-64-v2 --mtune=generic -mavx (refer [here](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels) for more info about x86-64-v2).
These should run on CPUs which support AVX instructions, which should encompass the Intel Sandybridge/AMD Bulldozer era (circa 2011) onwards.
There's also a patch which can be used by builders to enable FMA/FMA3/FMA4/AVX2 support (cat /proc/cpuinfo is your friend here).

The debs are built in a debian stable chroot, so should work on that, Ubuntu Focal and newer.


# Installation

Only ungoogled-chromium_*.deb is mandatory. The other debs are

* *-sandbox_*   : suid sandbox, recommended (see the [Sandbox](https://github.com/berkley4/ungoogled-chromium-debian/blob/stable/.github/README.md#sandbox) section below).
* *-l10n_*      : language localisation, needed if you want a non US English UI.
* *-libraries_* : contains files such as libEGL.so, libGLESv2.so; might prevent (probably harmless) error messages and likely not needed by everyone.
* *-driver_*    : chromedriver, not normally needed.
* *-dbgsym_*    : not normally needed (unless you need to debug).

For example, to install the main and sandbox packages, run the following :-

```sh
dpkg -i ungoogled-chromium_*.deb ungoogled-chromium_sandbox_*.deb
```

- - - -


The main features and changes are as follows :-


___Performance improvements___

- Profile Guided Optimisation (PGO) - a smaller and faster chrome binary with cold functions heavily optimised for size
- V8 pointer compression - memory usage/speed improvement (see [here](https://v8.dev/blog/pointer-compression))
- Upstream optimisation - levels vary per target (versus debian's -O2 everywhere default)
- Built with -march=[x86-64-v2](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels) and -mavx to enable AVX instructions (with optional patches to enable FMA/FMA3/FMA4/AVX2)
- Built with -fno-plt - speed improvement
- Build with -ftrivial-auto-var-init set to zero instead of pattern - speed improvement
- Built with a higher hot function import multiplier to further optimise frequently used functions

___Security/Privacy improvements___

- Bad Cast Checking in addition to regular Control Flow Integrity (see [here](https://clang.llvm.org/docs/ControlFlowIntegrity.html#bad-cast-checking) for details)
- Extra Bromite and Vanadium patches, the later of which includes the following clang options :-
    - -fstack-protector-strong - as opposed to chromium's default of -fstack-protector
    - -ftrivial-auto-var-init=zero - improves security (see [here](https://lists.llvm.org/pipermail/cfe-dev/2020-April/065221.html))
    - -fwrapv - disables unsafe optimisations (see [here](https://gitlab.e.foundation/e/apps/browser/-/blob/master/build/patches/Enable-fwrapv-in-Clang-for-non-UBSan-builds.patch))
- An example policy file is included in the repo (ungoogled-chromium.install.in can be edited and enabled at build time or copied into /etc/chromium/policies/managed)
- Some security/privacy themed flag files are installed to /etc/chromium.d (strict isolation is enabled by default)


___Other features/changes___

- Enabled pipewire
- Vulkan support - opt-in via runtime switches (see further below)
- Bundled libpng - avoids an upstream debian bug (see [here](https://github.com/ungoogled-software/ungoogled-chromium-debian/issues/169))
- Upstream debian patches - a few hard to maintain and otherwise dubious patches have been dropped
- Separate deb packages for chromium's components (eg chromedriver, sandbox, languages)
- Dropped ungoogled-chromium-common - its contents split between a new libraries package and the main one
- New ungoogled-chromium-libraries package for libEGL.so, libGLESv2.so, etc (likely not needed by everyone)
- Google translate - optional build support
- Chromecast - optional build support (untested and experimental)


___Build system___

- Built with upstream google clang/llvm binaries (auto-downloaded during build setup)
- A bit more robust in general eg rebuilds should be faster and less error prone
- All patching is handled by debian - ungoogled patches are merged with the debian patches during build setup
- Built with a chromium git tree instead of tarball releases
- Debug optimisation is now handled by building with -fdebug-types-section versus using dwz post build
- Several other fixes and improvements

- - - -


The following are optional features :-


___Enable Vulkan___

Vulkan can be enabled via uncommenting the following runtime flags in /etc/chromium.d/gpu-options :-

--use-vulkan

In the past it appeared that the environment variable VK_ICD_FILENAMES needed to be set, but this 
no longer appears to be the case.
(eg VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json chromium)


___Google Translate___

Not enabled by default in the binaries, you need to build it yourself.

To build with google translate enabled, instead of running debian/rules setup, run the following :-

debian/rules setup_translate


___Chromecast___

To build with chromecast enabled, instead of running debian/rules setup, run the following :-

debian/rules setup_cast


If you want both google translate and chromecast enabled, run the following :-

debian/rules setup_cast_translate


- - - -


# Sandbox

By default, chromium sandboxing on linux relies on using kernel unprivileged user namespaces. An alternative is via
the sandbox package which uses a suid helper binary. The pros and cons of unprivileged user namespaces can be read
about via the links [here](https://github.com/a13xp0p0v/kconfig-hardened-check#questions-and-answers).

The relevant sysctl (at least on debian) is kernel.unprivileged_userns_clone. Check its value by running :-

```sh
cat /proc/sys/kernel/unprivileged_userns_clone
```

Normally it's value is 1 (ie enabled). If you wish to disable it (and install the sandbox package)
do the following (as root) :-

```sh
sysctl -w kernel.unprivileged_userns_clone=0
```

To make this permanent across reboots :-

```sh
touch /etc/systctl.d/userns
chmod 0644 /etc/systctl.d/userns
echo "kernel.unprivileged_userns_clone = 0" > /etc/systctl.d/userns
```


- - - -

## Prepare ungoogled-chromium-debian packaging

```sh
# Install initial packages
sudo apt install -y devscripts equivs

# Define QUILT_SERIES and QUILT_PATCHES, you might want to put it in your .bashrc
export QUILT_SERIES=series
export QUILT_PATCHES=debian/patches

# Clone ungoogled-chromium-debian
git clone [-b <stable|extended_stable>] https://github.com/berkley4/ungoogled-chromium-debian.git
cd ungoogled-chromium-debian

# Update submodules
cd debian
git submodule foreach git reset --hard
git submodule update --init --recursive
# show the current version of ungoogled-chromium upstream
cat submodules/ungoogled-chromium/chromium_version.txt
cd ..
```

## Cloning the chromium git repo

```sh
# Clone depot_tools and put it in your PATH
git clone https://chromium.googlesource.com/chromium/tools/depot_tools
export PATH=$PATH:/path/to/depot_tools

# Clone the chromium repository (creates build/src)
cd build
export CHROMIUM_VER=102.0.5005.61 (obviously change this to the current version)
git clone --depth 1 -b $CHROMIUM_VER https://chromium.googlesource.com/chromium/src.git

# continue with preparing the chromium git repo below
```

## Resetting an existing repo (do before updating & skip if clone/prep has just been done)

If you want to re-compile and need to reset the build environment in (build/src), do this
```sh
# If build/src/debian/domsubcache.tar.gz exists (eg a failed/aborted build), revert domain substitution
cd src
./debian/submodules/ungoogled-chromium/utils/domain_substitution.py revert \
-c ./debian/domsubcache.tar.gz ./

# If 'quilt applied' shows applied patches or you have just reverted domain substitution (in build/src)
quilt pop -a

# Clean and hard reset (in build/src)
git clean -dfx
git reset --hard HEAD

# Check to see if there are any more untracked files (delete them if there are any)
git status
cd ..
# continue with preparing the chromium git repo, or update the repo as well
```

## Updating an existing repo (make sure you reset beforehand - see previous step)

```sh
# Set the chromium version (obviously change the one below to the desired version)
export CHROMIUM_VER=102.0.5005.61

# Update and checkout the desired chromium version (in build/src)
cd src
git fetch --depth 1
git checkout tags/$CHROMIUM_VER
cd ..
```

## Preparing the chromium git repo
```
# Prepare the tree for building (in build/)
gclient sync -D --force --nohooks --no-history --shallow
gclient runhooks
```

## Building the binary packages

```sh
# Copy over the debian directory into your source tree (in build/src)
cd src
cp -a ../../debian .

# Prepare the source
debian/rules setup

# To build a version of newer than upstream's (eg to build extended stable) :-
VERSION=999.0.1234.567 debian/rules setup

# Recommended: apply and refresh patches
while quilt push; do quilt refresh; done

# Build the package
JOBS=4 dpkg-buildpackage -b -uc
```
