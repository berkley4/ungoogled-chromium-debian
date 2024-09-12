# Installing third-party rust


___Pre-build___

You can prevent gclient runhooks from pulling in the whole rust toolchain by
applying DEPS-no-rust.patch. Refer to README.md for more information.


___System rustc package___

On unstable : ```apt-get install rustc```

On stable   : ```apt-get install rust-web```


To proceed, configure with SYS_RUST=1.

```... SYS_RUST=1 ./debian/configure.sh```


___Upstream rust___

```curl https://sh.rustup.rs -sSf | sh -s```

By default, the rust script will install a stable version version of rust to
the $HOME/.cargo directory. Try the beta or nightly versions if you run into
build problems.

Now make sure that SYS_RUST=2 is included in your configuration variables

```... SYS_RUST=2 ./debian/configure.sh```

More information on installation is available at the following links :-

https://rust-lang.github.io/rustup/
https://rust-lang.github.io/rustup/installation/other.html


To restore a the in-tree rust toolchain, run the following from the build
directory to pull in the rust toolchain.

```./src/tools/rust/update_rust.py```
