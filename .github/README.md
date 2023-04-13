# ungoogled-chromium-debian

This is my fork of the unified branch of [ungoogle-chromium-debian](https://github.com/ungoogled-software/ungoogled-chromium-debian).

There are debs in the release section which are built with -march=x86-64-v2 --mtune=generic -mavx (refer [here](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels) for more info about x86-64-v2).
These should run on CPUs which support AVX instructions, which should encompass the Intel Sandybridge/AMD Bulldozer era (circa 2011) onwards.
There's also a patch which can be used by builders to enable AVX2 support (cat /proc/cpuinfo is your friend here).

There are currently two release branches: stable and unstable, with their respective deb packages built in debian stable and unstable chroots.
The stable release should work on debian stable or equivalent (eg ubuntu focal).
The unstable release obviously needs debian unstable or a new enough distro.


# Installation

The ungoogled-chromium and ungoogled-chromium-libraries packages are mandatory.

The other debs are :-

* *-sandbox_*   : suid sandbox, recommended (see the [Sandbox](https://github.com/berkley4/ungoogled-chromium-debian/blob/stable/.github/README.md#sandbox) section below).
* *-l10n_*      : language localisation, needed if you want a non US English UI.
* *-libraries_* : contains files such as libEGL.so, libGLESv2.so.
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
- Various compiler flags aimed at improving speed
    - -march=[x86-64-v2](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels)
    - -maes - enables AES instructions
    - -mpclmul - enables CLMUL instructions
    - -mavx - enables AVX instructions (AVX2 is available via an optional patch)
    - -fno-plt - (see [here](https://patchwork.ozlabs.org/project/gcc/patch/alpine.LNX.2.11.1505061730460.22867@monopod.intra.ispras.ru/))
    - -ftrivial-auto-var-init set to zero - see [here](https://lists.llvm.org/pipermail/cfe-dev/2020-April/065221.html)
    - -import-instr-limit=25 and -import-hot-multiplier=16 - gives a hot import limit of 400 (25*16) vs default of 300 (30*10)
    - The following LLVM polly options are available (via optional patches, needs a capable toolchain) :-
        -polly-vectorizer=stripmine, -polly-run-dce, -polly-run-inliner, -polly-invariant-load-hoisting

___Security/Privacy improvements___

- Stack clash protection (-fstack-clash-protection) - see [here](https://blog.llvm.org/posts/2021-01-05-stack-clash-protection/)
- Intel control flow enforcement technology (-fcf-protection) - cpu-based control flow integrity (see [here](https://wiki.ubuntu.com/ToolChain/CompilerFlags#A-fcf-protection))
- ROP exploit mitigation (-fzero-call-used-regs=used-gpr) - see [here](https://www.jerkeby.se/newsletter/posts/rop-reduction-zero-call-user-regs/)
- Bad Cast Checking - see [here](https://clang.llvm.org/docs/ControlFlowIntegrity.html#bad-cast-checking)
- Extra Bromite and Vanadium patches, the later of which includes the following clang options
    - -fstack-protector-strong - chromium's default is the less-strict -fstack-protector
    - -ftrivial-auto-var-init=zero - see [here](https://lists.llvm.org/pipermail/cfe-dev/2020-April/065221.html)
    - -fwrapv - see [here](https://bugzilla.mozilla.org/show_bug.cgi?id=1031653) and [here](https://gitlab.e.foundation/e/apps/browser/-/blob/master/build/patches/Enable-fwrapv-in-Clang-for-non-UBSan-builds.patch)
- An example policy file is in the repo (install manually or edit ungoogled-chromium.install.in at build time4)
- Some security/privacy themed flag files are installed to /etc/chromium.d (strict isolation is enabled by default)


___Other features___

- The ungoogled-chromium-common package has split into the libraries and main packages
- A new ungoogled-chromium-libraries package
- Google translate - optional build support via a patch to re-enable this functionality
- Disable mDNS and service discovery - optional build support (a work in progress)


___Build system___

- Predominantly uses git to obtain and update source (release tarballs were supported until recently)
- System clang/llvm is preferred for building (upstream llvm is best to ensure compatibility with the PGO profile)
- Patches for -march/-mtune and various other CPU instructions
- Various patches to disable components (eg atk/dbus) and enable system libraries (eg icu)
- A configure script is provided to enable customisation of the build
- Ungoogled Chromium patches are merged into debian's build system with a variety of other patches
- Debug optimisation is now handled by building with -fdebug-types-section (instead of dwz)
- Several improvements have been made to make the build process more robust

- - - -


The following are optional features :-


___Google Translate___

Not enabled by default in the binaries, you need to build it yourself.

To build with google translate enabled, instead of running debian/rules setup, run the following :-

debian/rules setup_translate


___Disable mDNS and service discovery (a work-in-progress)___

To build with mdns (and service discovery) disabled, run the following :-

debian/rules setup_no_mdns


If you want to both enable google translate and disable mdns, run the following :-

debian/rules setup_no_mdns_translate


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

# Optional: verify the current version and revison of ungoogled-chromium upstream
cat debian/submodules/ungoogled-chromium/chromium_version.txt
cat debian/submodules/ungoogled-chromium/revision.txt
```

## Cloning the chromium git repo (recommended, tarball method is detailed further below)

```sh
# Clone depot_tools and put it in your PATH
git clone https://chromium.googlesource.com/chromium/tools/depot_tools
export PATH=$PATH:/path/to/depot_tools

# Optional: always have depot_tools in your path
echo 'export PATH=$PATH:/path/to/depot_tools' >> ~/.bashrc

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
# Update the chromium submodules
# After cloning for the first time run in build, otherwise run from build/src.
gclient sync -D --force --nohooks --no-history --shallow --jobs=$JOBS

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

# Download and extract the upstream tarball
debian/rules tarball
```

## Finish preparing the source

```sh
# Run the configuration script. Customisation can be done via the setting of
# variables (read the script and look at GN_FLAGS/SYS_LIBS in debian/rules)
#
# Example for stable :-
ATK_DBUS=0 CATAPULT=0 DRIVER=0 MARCH=native MTUNE=native JPEG=1 ./debian/configure.sh
# Example for unstable :-
ICU=0 PIPEWIRE=0 MARCH=native MTUNE=native JPEG=1 UNSTABLE=1 ./debian/configure.sh

# Normally you just need to run the following (see above for enabling translate)
debian/rules setup

# Change version (eg create a pre-release from an unmerged UC pull request)
# note: you need to specify the version and revision (eg '-1') as one string
VERSION=999.0.1234.567-1 debian/rules setup
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
