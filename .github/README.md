# ungoogled-chromium-debian

This is my fork of the unified branch of [ungoogle-chromium-debian](https://github.com/ungoogled-software/ungoogled-chromium-debian).

There are debs in the release section, but these probably only work for
debian/devuan unstable (and possibly it's equivalents), since they are 
built in a debian unstable chroot.

The main features and changes are as follows :-


<<<< Performance improvements >>>>

Built with -march=x86-64-v2 - Nehalem/Jaguar era (circa 2009) onwards
Built with -fno-plt - speed improvement
Profile Guided Optimisation (PGO) - smaller, faster binaries
Upstream optimisation - levels vary per target (versus debian's -O2 everywhere default)
V8 pointer compression - memory usage/speed improvement (see [here](https://v8.dev/blog/pointer-compression))


<<<< Security/Privacy improvements >>>>

Control Flow Integrity (CFI) - a central pillar of chromium security
Extra bromite patches
  These include the following security-related clang options (originating from vanadium) :-
    -fwrapv - disables unsafe optimisations (see [here](https://gitlab.e.foundation/e/apps/browser/-/blob/master/build/patches/Enable-fwrapv-in-Clang-for-non-UBSan-builds.patch)).
    -ftrivial-auto-var-init=zero - improves security (see [here](https://lists.llvm.org/pipermail/cfe-dev/2020-April/065221.html))


<<<< Other features >>>>

Enabled pipewire - for wayland
Vulkan support - opt-in via runtime switches (see further below)
Google translate - optional build support
Shell script launcher - perhaps slightly more secure
Bundled libpng - avoids an upstream debian bug (see [here](https://github.com/ungoogled-software/ungoogled-chromium-debian/issues/169))
Upstream debian patches - a few hard to maintain and otherwise dubious patches have been dropped


<<<< Build system >>>>

Built with upstream google clang/llvm binaries (auto-downloaded during build setup)
A bit more robust in general eg rebuilds should be faster and less error prone
Upstream ungoogled patches are merged in with the debian patches during build setup
Several fixes and improvements



Vulkan can be enabled via the following runtime flags :-

--use-vulkan
--enable-features=vulkan
--disable-vulkan-fallback-to-gl-for-testing


To build with google translate enabled, instead of running debian/rules setup, run the following :-

debian/rules setup_translate



## Building a binary package

```sh
# Install initial packages
sudo apt install -y devscripts equivs

# Clone repository and switch to it (optional if are already in it)
git clone -b unified_pgo_hardened https://github.com/berkley4/ungoogled-chromium-debian.git
cd ungoogled-chromium-debian

# Initiate the submodules (optional if they are already initiated)
git submodule update --init --recursive

# Prepare the local source
debian/rules setup

# Install missing packages
sudo mk-build-deps -i debian/control
rm ungoogled-chromium-build-deps_*

# Build the package
dpkg-buildpackage -b -uc
```
