# ungoogled-chromium-debian

This is my fork of the unified branch of [ungoogle-chromium-debian](https://github.com/ungoogled-software/ungoogled-chromium-debian).

There are debs in the release section which are built with -march=x86-64-v2 --mtune=generic -mavx (refer [here](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels) for more info about x86-64-v2).
These should run on CPUs which support AVX instructions, which should encompass the Intel Sandybridge/AMD Bulldozer era (circa 2011) onwards.
There's also a patch which can be used by builders to enable AVX2 support (cat /proc/cpuinfo is your friend here).

There are currently two release branches: stable and unstable

Currently there are deb packages for unstable, with build support for stable.


# Installation

The ungoogled-chromium package is mandatory. The other debs are :-

* *-sandbox_*   : suid sandbox, recommended (see the [Sandbox](https://github.com/berkley4/ungoogled-chromium-debian/blob/stable/.github/README.md#sandbox) section below).
* *-l10n_*      : language localisation, needed if you want a non US English UI.
* *-driver_*    : chromedriver, not normally needed.
* *-dbgsym_*    : not normally needed (unless you need to debug).

For example, to install the main and sandbox packages, run the following :-

```sh
dpkg -i ungoogled-chromium_*.deb ungoogled-chromium_sandbox_*.deb
```

- - - -


The main features and changes are as follows :-


___Performance improvements___

- Profile Guided Optimisation (PGO) - a smaller, faster chrome binary
- PartitionAlloc pointer compression - should help reduce memory usage and help boost performance
- Mutex Priority Inheritance - greater smoothness and responsiveness (see [here](https://lwn.net/Articles/177111/))
- Various compiler flags aimed at improving speed
    - -march=[x86-64-v2](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels)
    - -maes - enables AES instructions
    - -mpclmul - enables CLMUL instructions
    - -mavx - enables AVX instructions (AVX2 is available via an optional patch)
    - -fno-plt - (see [here](https://patchwork.ozlabs.org/project/gcc/patch/alpine.LNX.2.11.1505061730460.22867@monopod.intra.ispras.ru/))
    - -fsplit-machine-functions - (see [here](https://groups.google.com/g/llvm-dev/c/RUegaMg-iqc/m/wFAVxa6fCgAJ))
    - -import-instr-limit=24 and -import-hot-multiplier=15
        - gives a hot import limit of 360 (24x15) vs default of 300 (30x10)
    - The following LLVM polly options are available (needs a capable toolchain)
        - -polly-vectorizer=stripmine, -polly-run-dce, -polly-invariant-load-hoisting


___Security/Privacy improvements___

- Stack clash protection (-fstack-clash-protection) - see [here](https://blog.llvm.org/posts/2021-01-05-stack-clash-protection/)
- Intel control flow enforcement technology (-fcf-protection) - cpu-based [control flow integrity](https://wiki.ubuntu.com/ToolChain/CompilerFlags#A-fcf-protection)
- Bad Cast Checking (use_cfi_cast=true) - see [here](https://clang.llvm.org/docs/ControlFlowIntegrity.html#bad-cast-checking)
- Enhanced stack protection (-fstack-protector-strong; chromium's default is the less-strict -fstack-protector)
- Overflow prevention (-fwrapv) - see [here](https://bugzilla.mozilla.org/show_bug.cgi?id=1031653) and [here](https://gitlab.e.foundation/e/apps/browser/-/blob/master/build/patches/Enable-fwrapv-in-Clang-for-non-UBSan-builds.patch)
- Extra cromite and vanadium patches (and generic copies of patches derived from these projects)
- A policy file is installed to help lock down the browser (use [this](https://chromeenterprise.google/policies/) as a reference guide)
- The Web Bluetooth/HID/Serial/USB APIs are disabled, and the audio/video/screen capture APIs can be disabled via the policy file
- Text fragments are disabled by default via the opilcy file (see [here](https://xsleaks.dev/docs/attacks/experiments/scroll-to-text-fragment/) for more info)
- Built without possibly privacy unfriendly Lens Desktop and Screen AI Service components
- Some security/privacy themed flag files are installed to /etc/chromium.d


___Other features___

- Lots of extra runtime flags (via the flag files in /etc/chromium.d)
- Lots of extra build flags to try and prevent the building of unneeded testing/debug features
- The crashpad handler binary is redundant on Ungoogled Chromium and has been patched out
- Google translate - can be enabled via an edit to /etc/chromium.d/google-translate
- Various patches to disable several potentially unwanted components/enable system libraries
- Experimental Opentype SVG support via third party patches


___Build system___

- Predominantly uses git to obtain and update source (release tarballs are not actively supported)
- Using git often avoids compatibility/availabilty issues associated with tarball sources
- Self-built BOLT/LTO/PGO optimised and polly-enabled clang/llvm is preferred for building
    - requiring a recent version of clang often means fewer build headaches
- A configure shell script is provided to enable easy customisation of the build
    - it takes out much of the complexity might otherwise be present in debian/rules
    - it handles dependencies, patches, enabling/disabling system libraries and components
    - set variables when running the script eg PIPEWIRE=0 PULSE=0 QT=0 ./debian/configure.sh
- A script is provided to automate the building of a Widevine CDM deb package

- - - -


___Google Translate___

To enable, you just need to edit /etc/chromium.d/google-translate and uncomment the
line containing the '--translate-script-url' runtime switch.

To build with everything enabled (no need to edit the above flag file), pass TRANSLATE=2
to the configure script :-

TRANSLATE=2 ./debian/configure.sh

To build with translate disabled, include TRANSLATE=0 in your configure
variables :-

TRANSLATE=0 ./debian/configure.sh



___VAAPI (hardware video decoding/encoding)___

To test whether hardware decoding is functional, have a look at chrome://media-internals/
(or the newer media tab in devtools).

I found that I needed to install the NON-FREE intel-media-va-driver-non-free (as opposed to the free
intel-media-va-driver), as well running with the '--disable-features=UseChromeOSDirectVideoDecoder'
runtime flag enabled in /etc/chromium.d/hw-decoding-encoding.

If that doesn't work, then try playing around with the options in /etc/chromium.d/hw-decoding-encoding
or uncommenting the LIBVA variable exports in /usr/bin/chromium.



- - - -


# Sandbox

By default, chromium sandboxing on linux relies on using kernel unprivileged user namespaces. An alternative is via
the sandbox package which uses a suid helper binary. The pros and cons of unprivileged user namespaces can be read
about via the links [here](https://github.com/a13xp0p0v/kconfig-hardened-check#questions-and-answers).

The relevant sysctl (at least on debian) is kernel.unprivileged_userns_clone. Check its value by running :-

```sh
cat /proc/sys/kernel/unprivileged_userns_clone
```

Normally it's value is 1 (enabled). To disable it (ie if installing the sandbox package instead), as root run :-

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

# LLVM/Clang (for those wanting to self-compile)

You will need llvm/clang where at least the major version matches that of the bundled
version in order to avoid PGO-related build errors. Ideally, the same major version
should be used, or even a version built from the same upstream commit.

Getting a version of clang to do the job means (in-tree) bundled clang, a matching
version via the apt.llvm.org snapshot branch, or perhaps debian experimental.

Howver, bundled clang lacks support LLVM Polly optimisations, and debian experimental
packages are often months old and unsuitable for debian stable. Bundled clang has LTO and
PGO optimisations, which as far as I know is not the case with the debian or llvm.org
packages.

Compiling your own toolchain has speed advantages due to being able compile with BOLT
optimisation in addition to LTO and PGO.

Rough instructions for self-building are available [here](https://github.com/berkley4/ungoogled-chromium-debian/blob/unstable/Toolchain.md).



- - - -

## Prepare ungoogled-chromium-debian packaging

```sh
# Install initial packages
sudo apt install -y devscripts equivs

# Define QUILT_SERIES and QUILT_PATCHES, you might want to put these in your ~/.bashrc
export QUILT_SERIES=series
export QUILT_PATCHES=debian/patches

# Clone ungoogled-chromium-debian
git clone [-b <stable|unstable>] https://github.com/berkley4/ungoogled-chromium-debian.git
cd ungoogled-chromium-debian

# Update submodules
cd debian
git submodule foreach git reset --hard
git submodule update --init --recursive
cd ..
```

## Cloning the chromium git repo (recommended, tarball method is detailed further below)

```sh
# Clone depot_tools and put it in your PATH
git clone https://chromium.googlesource.com/chromium/tools/depot_tools
export PATH=$PATH:$PWD/depot_tools

# Optional: always have depot_tools in your path
echo 'export PATH=$PATH:'"$PWD"'/depot_tools' >> ~/.bashrc

# Clone the chromium repository (creates build/src)
cd build
export CHROMIUM_VER=102.0.5005.61 (obviously change this to the current version)
git clone --depth 1 -b $CHROMIUM_VER https://chromium.googlesource.com/chromium/src.git

# continue with preparing the chromium git repo below
```

## Repo reset (skip if you have just cloned for the first time)
## If re-compiling or updating, go into build/src and do the following :-

```sh
# If build/src/debian/domsubcache.tar.gz exists, revert domain substitution
./debian/submodules/ungoogled-chromium/utils/domain_substitution.py revert \
-c ./debian/domsubcache.tar.gz ./

# Unapply patches
quilt pop -a

# Clean and hard reset
git clean -dfx -e out/Release
git reset --hard HEAD

# Optional: check for any untracked files (delete them if there are any)
git status -u

# Continue with updating and/or preparing the chromium git repo
```

## Updating an existing repo (see previous step if you have not reset)

```sh
# Set the chromium version (obviously change the one below) and number of jobs
export TAG=999.0.1234.567-1 JOBS=4

# Update and checkout the desired chromium version (in build/src)
git fetch --depth 1 --jobs=$JOBS origin tag $TAG
git checkout tags/$TAG
```

## Pull in chromium submodules and components
```
# Optional: patch the DEPS file to omit downloading unwanted components
# (Tarball users can skip this step)
patch -p1 < /path/to/DEPS.patch

# Update the chromium build tree submodules
cd ../build/src
gclient sync -D --force --nohooks --no-history --shallow --jobs=$JOBS
export DEPOT_TOOLS_UPDATE=0

# Download various build components
gclient runhooks --jobs=$JOBS

# Copy over the debian directory into your source tree
cp -a ../../debian .
```

## Tarball download/extraction (instead of cloning the chromium git repo)

```sh
cd build/tarball

# Copy over the debian directory
cp -a ../../debian .

# Include TARBALL=1 in your variables and run the configure script to
# download and extract (refer below and to the script to configure further)
TARBALL=1 ./debian/configure.sh
```

## Prepare build setup and prune source binaries

```sh
# Run the configuration script. Customisation can be done via the setting of
# variables (read the script and look at GN_FLAGS/SYS_LIBS in debian/rules)
#
# Example for unstable :-
ATK_DBUS=0 CATAPULT=0 DRIVER=0 MARCH=native MTUNE=native ./debian/configure.sh
# Example for stable :-
DRIVER=0 MARCH=native MTUNE=native TRANSLATE=1 STABLE=1 ./debian/configure.sh

# Prune the binaries :-
debian/rules prune
```

## Building the binary packages

```sh
# Recommended: apply and refresh patches
while quilt push; do quilt refresh; done

# Build the package (remove the '-nc' to rebuild after a successful build)
JOBS=4 dpkg-buildpackage --source-option=--no-preparation -b -uc -nc
```

## Optional: clean out all built objects/configs (not routinely needed)

```sh
debian/rules hardclean
```
