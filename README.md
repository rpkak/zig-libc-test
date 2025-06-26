# zig-libc-test

To build the test cases into `zig-out/bin`, execute the following command:

```
zig build -Dtarget=[target]
```

To run the test cases, execute the following command:

```
zig build test -Dtarget=[target]
```

Not every test case passes under all circumstances. Such unstable test cases are skipped by default. To build/run them anyway, use the `-Dunstable` command line argument.

To determine which tests are unstable, I ran the test cases on the following targets (mostly using qemu):

musl:

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

mingw:

- `x86_64-windows-gnu`
- `x86-windows-gnu`
