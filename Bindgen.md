__General information___

A build-bindgen.sh script is provided to help builders compile a copy of the
bindgen binary that's now required to compile ungoogled chromium.

Bindgen is linked with libclang libraries and needs to be be built by the same
clang toolchain that will be used to build ungoogled chromium.

With system packaged bindgen, I assume that (on unstable) it's built with the
default clang release, which is clang 16. So sticking with the system package
restricts one to an older version of clang, at least on debian unstable.

Those wanting to use a newer system clang, say version 18 or even 19, will
need to run build-bindgen.sh. Those wanting to use bundled or self-compiled
clang will need to do the same.


___Script requirements___

Make sure you have copies of the following installed :-

cargo
curl
rustc
unzip


___System bindgen package___

```apt-get install bindgen```

Configure with ```... SYS_BINDGEN=1 SYS_CLANG=1 ./debian/configure.sh```


___Upstream bindgen___

Run the script with the same SYS_CLANG and SYS_RUST values that you intend to
use for the configuration script. Valid examples are given below.

In-tree clang :-
```SYS_CLANG=0 SYS_RUST=0 ./build-bindgen.sh```

System clang package (using clang 19) :-
```CLANG_VER=19 SYS_CLANG=1 SYS_RUST=1 ./build-bindgen.sh```
```CLANG_VER=19 SYS_CLANG=1 SYS_RUST=2 ./build-bindgen.sh```

Self-build clang (in /usr/local) :-
```SYS_CLANG=2 SYS_RUST=1 ./build-bindgen.sh```
```SYS_CLANG=2 SYS_RUST=2 ./build-bindgen.sh```

Rules of thumb :-

SYS_CLANG=1 requires CLANG_VER to also be set.
SYS_CLANG=0 requires SYS_RUST=0 (and vice versa).


The SYS_BINDGEN variable in configure.sh takes the following values :-

1 - Use bindgen from the system package
2 - Use self-compiled bindgen installed in /usr/local

Some valid examples follow for different values of SYS_CLANG :-

In-tree clang :-
```... SYS_BINDGEN=2 SYS_CLANG=0 ./debian/configure.sh```

System clang package :-
```... SYS_BINDGEN=1 SYS_CLANG=1 ./debian/configure.sh```
```... SYS_BINDGEN=2 SYS_CLANG=1 ./debian/configure.sh```

Self-build clang (in /usr/local) :-
```... SYS_BINDGEN=2 SYS_CLANG=2 ./debian/configure.sh```

Some rules of thumb :-

SYS_BINDGEN=1 is only compatible with SYS_CLANG=1
SYS_BINDGEN=2 is compatible with all values of SYS_CLANG


___Cleaning bindgen build files___

The script can delete the rust-bindgen and ncursesw folders when 'c'
(or 'clean') is supplied as a positional argument :-

```./build-bindgen.sh c```

The 'hc' (or 'hardclean') argument will additionally delete the
ncursesw-linux-amd64.zip file.

```./build-bindgen.sh hc```
