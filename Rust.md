# Installing third-party rust


___Pre-build___

You can prevent gclient runhooks from pulling in the whole rust toolchain by
running the following command.

```'checkout_rust': False,```

If things don't work out, you can run the following from the build directory
to pull in the rust toolchain.

```./src/tools/rust/update_rust.py```

After that you will need to comment out the 'export RUSTC_BOOTSTRAP=1' and
GN_FLAGS lines in debian/rules.


___System rustc package___

```apt-get install rustc```

Most rust packages will be too old. If you know that your package new enough
then you can force SYS_RUST=1 to succeed by including SYS_RUST_FORCE=1 in your
configuration variables. A version matching that of upstream stable rust should
suffice.

Then make sure that SYS_RUST=1 is included in your configuration variable

```... SYS_RUST=1 ./debian/configure.sh```


___Upstream rust___

```curl https://sh.rustup.rs -sSf | sh -s```

By default, the rust script will install a stable version version of rust to
the $HOME/.cargo directory. Try the beta or nightly versions if you run into
build problems.

Now make sure that SYS_RUST=2 is included in your configuration variable

```... SYS_RUST=2 ./debian/configure.sh```

More information on installation is available at the following links :-

https://rust-lang.github.io/rustup/
https://rust-lang.github.io/rustup/installation/other.html
