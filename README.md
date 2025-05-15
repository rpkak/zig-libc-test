# zig-libc-test

```
zig build test -Dtarget=x86_64-linux-musl
```

Inside of [build.zig](./build.zig) is a TODO list of test cases not run by this repo.

Also, some tests are commented out. When run with `zig build test -Dtarget=x86_64-linux-musl`, these test cases seem to fail on my machine.
If this is run with `zig build test -Dtarget=native-native-musl` on my machine, more tests fail.
Even more tests fail if this is run with `zig build test -Dtarget=native-native-gnu` on my machine.
