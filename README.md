# zig-libc-test

To build the test cases into `zig-out/bin`, execute the following command:

```
zig build -Dtarget=[target]
```

To run the test cases, execute the following command:

```
zig build test -Dtarget=[target]
```

Not every test case passes on every target. For the following targets, failing tests are skipped by default.

- `aarch64-linux-musl`
- `aarch64_be-linux-musl`
- `hexagon-linux-musl`
- `loongarch64-linux-musl`
- `powerpc64-linux-musl`
- `powerpc64le-linux-musl`
- `riscv32-linux-musl`
- `riscv64-linux-musl`
- `s390x-linux-musl`
- `x86-linux-musl`
- `x86_64-linux-musl`
- `x86_64-linux-muslx32`

If you use another target (including `native-native-musl`), some test cases will probably fail.
If you want to build/run all test cases, use the `-Dno-skip` command line argument.
