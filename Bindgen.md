__General information___

A build-bindgen.sh script is provided to help builders compile a copy of the
bindgen binary that's now required to compile ungoogled chromium.

Bindgen is linked with libclang libraries and needs to be be built by the same
clang toolchain that will be used to build ungoogled chromium.

With system packaged bindgen, I assume that (on unstable) it's built with the
default clang release, which is clang 16. So sticking with system packages
restricts one to an older version of clang, at least on debian unstable.

Those wanting to use a newer system clang, say version 18 or even 19, will
need to run build-bindgen.sh. Those wanting to use bundled or self-compiled
clang will likewise need to do the same.


___System bindgen package___

```apt-get install bindgen```

Configure with ```... SYS_CLANG=1 ./debian/configure.sh```

Note: when you subsequently run configure.sh, you will need to omit the
SYS_BINDGEN configuration variable in order for the correct bindgen path
to be employed.

Passing SYS_BINDGEN=1 to configure.sh is for those who intend to use a
self-build bindgen (eg a newer, up-to-date version) which has been linked
against the system version of the libclang library.


___Upstream bindgen___

Run the script with the same SYS_CLANG value as you intend to use for
the configuration script.

In-tree clang :-
 ```SYS_CLANG=0 ./build-bindgen.sh```

System clang package :-
 ```CLANG_VER=18 SYS_CLANG=1 ./build-bindgen.sh```

Self-build clang (in /usr/local) :-
```SYS_CLANG=2 ./build-bindgen.sh```

Note that SYS_CLANG=1 requires CLANG_VER to also be set. This is because
the path to the clang binaries is version dependent (eg /usr/lib/llvm-18).

The SYS_BINDGEN variable in configure.sh takes the following values :-

1 - Use bindgen from the system package (eg from debian unstable/backports repo)
2 - Use self-compiled bindgen installed in /usr/local

A couple of rules of thumb :-

SYS_BINDGEN=1 is only compatible with SYS_CLANG=1 (clang in to /usr)
SYS_BINDGEN=2 is compatible with all values of SYS_CLANG (clang in /usr/local)

In-tree clang :-
```... SYS_BINDGEN=1 SYS_CLANG=0 ./debian/configure.sh```

System clang package :-
```... SYS_BINDGEN=0 SYS_CLANG=1 ./debian/configure.sh```

Self-build clang (in /usr/local) :-
```... SYS_BINDGEN=1 SYS_CLANG=2 ./debian/configure.sh```


___Cleaning bindgen build files___

The script can delete the rust-bindgen and ncursesw folders when 'c'
(or 'clean') is supplied as a positional argument :-

```./build-bindgen.sh c```

The 'hc' (or 'hardclean') argument will additionally delete the
ncursesw-linux-amd64.zip file.

```./build-bindgen.sh hc```
