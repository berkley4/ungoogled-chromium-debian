# ungoogled-chromium-debian

This is my fork of the unified branch of [ungoogle-chromium-debian](https://github.com/ungoogled-software/ungoogled-chromium-debian).

There are debs in the release section which are built with -march=x86-64-v2. These should run on 
cpus from the Nehalem/Jaguar era (circa 2009) onwards, and are optimised for Haswell/Excavator (circa 2015).

From 96.0.4664.93 onwards the debs are built in a debian stable chroot, so should work on that, Ubuntu Focal and newer.


The main features and changes are as follows :-


___Performance improvements___

- Profile Guided Optimisation (PGO) - smaller, faster binaries
- Upstream optimisation - levels vary per target (versus debian's -O2 everywhere default)
- V8 pointer compression - memory usage/speed improvement (see [here](https://v8.dev/blog/pointer-compression))
- Built with -fno-plt - speed improvement


___Security/Privacy improvements___

- Built with Control Flow Integrity (CFI) enabled
- Extra bromite patches, which include the following clang options :-
    - -fwrapv - disables unsafe optimisations (see [here](https://gitlab.e.foundation/e/apps/browser/-/blob/master/build/patches/Enable-fwrapv-in-Clang-for-non-UBSan-builds.patch)).
    - -ftrivial-auto-var-init=zero - improves security (see [here](https://lists.llvm.org/pipermail/cfe-dev/2020-April/065221.html))
- An example policy file is included in the repo (can be edited and enabled at build time)
- Some security/privacy themed flag files are installed to /etc/chromium.d (strict isolation is enabled by default)


___Other features/changes___

- Enabled pipewire - for wayland
- Vulkan support - opt-in via runtime switches (see further below)
- Google translate - optional build support
- Shell script launcher - perhaps slightly more secure
- Bundled libpng - avoids an upstream debian bug (see [here](https://github.com/ungoogled-software/ungoogled-chromium-debian/issues/169))
- Upstream debian patches - a few hard to maintain and otherwise dubious patches have been dropped
- Separate deb packages for chromium's components (eg chromedriver, sandbox)
- Dropped ungoogled-chromium-common - its contents split between a new libraries package and the main one
- The new ungoogled-chromium-libraries package for libEGL.so, libGLESv2.so, etc (likely not needed by everyone)


___Build system___

- Built with upstream google clang/llvm binaries (auto-downloaded during build setup)
- A bit more robust in general eg rebuilds should be faster and less error prone
- Upstream ungoogled patches are merged in with the debian patches during build setup
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

To build with google translate enabled, instead of running debian/rules setup, run the following :-

debian/rules setup_translate


Enable with the following runtime flag :-

--translate-script-url=https://translate.googleapis.com/translate_a/element.js


- - - -


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
JOBS=4 dpkg-buildpackage -b -uc
```
