# ungoogled-chromium-debian

This is my fork of the unified branch of [ungoogle-chromium-debian](https://github.com/ungoogled-software/ungoogled-chromium-debian).

There are debs in the release section which are built with -march=x86-64-v2 --mtune=generic (refer [here](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels) for more info about x86-64-v2).
These should run on cpus from the Nehalem/Jaguar era (circa 2009) onwards.

From 96.0.4664.93 onwards the debs are built in a debian stable chroot, so should work on that, Ubuntu Focal and newer.


# Installation

Only ungoogled-chromium_*.deb is mandatory. The other debs are

* *-sandbox_*   : suid sandbox, recommended (see the [Sandbox](https://github.com/berkley4/ungoogled-chromium-debian/blob/stable/.github/README.md#sandbox) section below).
* *-l10n_*      : language localisation, needed if you want a non US English UI.
* *-libraries_* : contains files such as libEGL.so, libGLESv2.so (likely not needed by everyone).
* *-driver_*    : chromedriver, not normally needed.
* *-dbgsym_*    : not normally needed (unless you are debugging things like crashes).

For example, to install the main and sandbox packages, run the following :-

```sh
dpkg -i ungoogled-chromium_*.deb ungoogled-chromium_sandbox_*.deb
```

- - - -


The main features and changes are as follows :-


___Performance improvements___

- Profile Guided Optimisation (PGO) - smaller, faster binaries
- Upstream optimisation - levels vary per target (versus debian's -O2 everywhere default)
- V8 pointer compression - memory usage/speed improvement (see [here](https://v8.dev/blog/pointer-compression))
- Built with -fno-plt - speed improvement


___Security/Privacy improvements___

- Bad Cast Checking in addition to regular Control Flow Integrity (see [here](https://clang.llvm.org/docs/ControlFlowIntegrity.html#bad-cast-checking) for details)
- Extra Bromite and Vanadium patches, which include the following clang options :-
    - -fwrapv - disables unsafe optimisations (see [here](https://gitlab.e.foundation/e/apps/browser/-/blob/master/build/patches/Enable-fwrapv-in-Clang-for-non-UBSan-builds.patch))
    - -ftrivial-auto-var-init=zero - improves security (see [here](https://lists.llvm.org/pipermail/cfe-dev/2020-April/065221.html))
- An example policy file is included in the repo (can be edited and enabled at build time)
- Some security/privacy themed flag files are installed to /etc/chromium.d (strict isolation is enabled by default)


___Other features/changes___

- Enabled pipewire - for wayland
- Vulkan support - opt-in via runtime switches (see further below)
- Shell script launcher - perhaps slightly more secure
- Bundled libpng - avoids an upstream debian bug (see [here](https://github.com/ungoogled-software/ungoogled-chromium-debian/issues/169))
- Upstream debian patches - a few hard to maintain and otherwise dubious patches have been dropped
- Separate deb packages for chromium's components (eg chromedriver, sandbox, languages)
- Dropped ungoogled-chromium-common - its contents split between a new libraries package and the main one
- New ungoogled-chromium-libraries package for libEGL.so, libGLESv2.so, etc (likely not needed by everyone)
- Chromecase - optional build support
- Google translate - optional build support


___Build system___

- Built with upstream google clang/llvm binaries (auto-downloaded during build setup)
- A bit more robust in general eg rebuilds should be faster and less error prone
- All patching is handled by debian - ungoogled patches are merged with the debian patches during build setup
- Built with a chromium git tree instead of tarball releases
- Several fixes and improvements

- - - -


The following are optional features :-


___Enable Vulkan___

Vulkan can be enabled via uncommenting the following runtime flags in /etc/chromium.d/gpu-options :-

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

# Clone ungoogled-chromium-debian
git clone -b <stable|extended_stable> https://github.com/berkley4/ungoogled-chromium-debian.git

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
gclient config https://chromium.googlesource.com/chromium/src.git

# Fetch the tags and checkout the desired chromium version
cd src
git fetch origin --tags
git checkout tags/999.0.1234.567

# Prepare the tree for building
cd ..
gclient sync -D --force --nohooks --with_branch_heads
gclient runhooks
```


## Resetting/updating an existing repo (skip if clone/prep has just been done)

```sh
# If needed, revert domain substitution
./debian/submodules/ungoogled-chromium/utils/domain_substitution.py revert \
-c path_to_parent/build/src/debian/domsubcache.tar.gz path_to_parent/build/src

# If needed, unapply patches
cd build/src
quilt pop -a

# Clean and hard reset
git clean -dfx
git reset --hard HEAD

# Check to see if there are any more untracked files (delete them if there are any)
git status

# Update and checkout the desired chromium version
git rebase-update

# If updating to a new version
git fetch origin --tags

# Checkout desired version
git checkout tags/999.0.1234.567

# Prepare the tree for building
cd ..
gclient sync -D --force --nohooks --with_branch_heads
gclient runhooks
```


## Building the binary packages

```sh
# Copy over the debian directory into your source tree (build/src)
cp -a ../../ungoogled-chromium-debian/debian .

# Prepare the source
VERSION=999.0.1234.567 debian/rules gitsubreset
debian/rules setup_pgo

# Optional: apply and refresh patches
while quilt push; do quilt refresh; done

# Build the package
JOBS=4 dpkg-buildpackage -b -uc
```
