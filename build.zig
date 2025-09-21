const std = @import("std");

const LibCTest = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    src: std.Build.LazyPath,
    options_include: std.Build.LazyPath,
    copy_file: *std.Build.Step.Compile,
    libtest: *std.Build.Step.Compile,
    test_step: *std.Build.Step,
    unstable: bool,
    skip_foreign_checks: bool,
    libc_impl: LibCImpl,
};

const LibCImpl = enum {
    darwin,
    gnu,
    musl,
    mingw,
    wasi,

    fn fromTarget(b: *std.Build, target: std.Target) !LibCImpl {
        if (target.isDarwinLibC()) return .darwin;
        if (target.isGnuLibC()) return .gnu;
        if (target.isMuslLibC()) return .musl;
        if (target.isMinGW()) return .mingw;
        if (target.isWasiLibC()) return .wasi;
        std.debug.panic("zig-libc-test does not support '{s}'", .{try target.zigTriple(b.allocator)});
    }

    const Support = struct {
        const Level = enum { passes, unstable, unsupported };

        darwin: Level,
        gnu: Level,
        musl: Level,
        mingw: Level,
        wasi: Level,

        const passes: Support = .{
            .darwin = .passes,
            .gnu = .passes,
            .musl = .passes,
            .mingw = .passes,
            .wasi = .passes,
        };

        const unstable: Support = .{
            .darwin = .unstable,
            .gnu = .unstable,
            .musl = .unstable,
            .mingw = .unstable,
            .wasi = .unstable,
        };

        fn shouldSkip(support: Support, libc_test: *const LibCTest) bool {
            const level = switch (libc_test.libc_impl) {
                .darwin => support.darwin,
                .gnu => support.gnu,
                .musl => support.musl,
                .mingw => support.mingw,
                .wasi => support.wasi,
            };

            return switch (level) {
                .passes => false,
                .unstable => !libc_test.unstable,
                .unsupported => true,
            };
        }
    };
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .abi = switch (b.graph.host.result.os.tag) {
                .linux => .musl,
                .windows => .gnu,
                else => null,
            },
        },
    });

    const optimize = b.standardOptimizeOption(.{});

    const unstable = b.option(bool, "unstable", "Do not skip test cases, which fail sometimes") orelse false;

    const skip_foreign_checks = b.option(bool, "skip-foreign-checks", "Skip foreign checks") orelse false;

    const src = b.dependency("libc_test", .{}).path("src");

    const copy_file = b.addExecutable(.{
        .name = "copy_file",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/copy_file.zig"),
            .target = b.graph.host,
            .optimize = .Debug, // for error checking
        }),
    });

    const libc_impl: LibCImpl = try .fromTarget(b, target.result);

    const libtest_mod = b.createModule(.{
        .root_source_file = b.path("libtest.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    var libtest_c_source_files: std.ArrayListUnmanaged([]const u8) = .empty;
    defer libtest_c_source_files.deinit(b.allocator);

    try libtest_c_source_files.appendSlice(b.allocator, &.{ "print.c", "mtest.c", "path.c" });

    if (libc_impl == .darwin or libc_impl == .gnu or libc_impl == .musl) {
        try libtest_c_source_files.appendSlice(b.allocator, &.{ "fdfill.c", "utf8.c" });
    }

    libtest_mod.addCSourceFiles(.{
        .root = src.path(b, "common"),
        .files = libtest_c_source_files.items,
    });

    const libtest = b.addLibrary(.{
        .name = "test",
        .root_module = libtest_mod,
    });

    const test_step = b.step("test", "Run tests");

    const libc_test: LibCTest = .{
        .b = b,
        .target = target,
        .optimize = optimize,
        .src = src,
        .options_include = try generateOptionsInclude(b, target, src),
        .copy_file = copy_file,
        .libtest = libtest,
        .test_step = test_step,
        .unstable = unstable,
        .skip_foreign_checks = skip_foreign_checks,
        .libc_impl = libc_impl,
    };

    installApiTestCase(&libc_test, "api/aio.c", .{
        .darwin = .unsupported,
        .gnu = .unsupported,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/arpa_inet.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/assert.c", .passes);
    installApiTestCase(&libc_test, "api/complex.c", .passes);
    installApiTestCase(&libc_test, "api/cpio.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/ctype.c", .passes);
    installApiTestCase(&libc_test, "api/dirent.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/dlfcn.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/errno.c", .passes);
    installApiTestCase(&libc_test, "api/fcntl.c", .{
        .darwin = .unsupported,
        .gnu = .unsupported,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/fenv.c", .passes);
    installApiTestCase(&libc_test, "api/float.c", .passes);
    installApiTestCase(&libc_test, "api/fmtmsg.c", .passes);
    installApiTestCase(&libc_test, "api/fnmatch.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/ftw.c", .passes);
    installApiTestCase(&libc_test, "api/glob.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/grp.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/iconv.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/inttypes.c", .passes);
    installApiTestCase(&libc_test, "api/iso646.c", .passes);
    installApiTestCase(&libc_test, "api/langinfo.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/libgen.c", .passes);
    installApiTestCase(&libc_test, "api/limits.c", .{
        .darwin = .passes,
        .gnu = .unsupported,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/locale.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/math.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/monetary.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/mqueue.c", .passes);
    installApiTestCase(&libc_test, "api/ndbm.c", .passes);
    installApiTestCase(&libc_test, "api/net_if.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/netdb.c", .{
        .darwin = .passes,
        .gnu = .unsupported,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/netinet_in.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/netinet_tcp.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/nl_types.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/poll.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/pthread.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/pwd.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/regex.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/sched.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/search.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/semaphore.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/setjmp.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/signal.c", .{
        .darwin = .passes,
        .gnu = .unsupported,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/spawn.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/stdarg.c", .passes);
    installApiTestCase(&libc_test, "api/stdbool.c", .passes);
    installApiTestCase(&libc_test, "api/stddef.c", .passes);
    installApiTestCase(&libc_test, "api/stdint.c", .passes);
    installApiTestCase(&libc_test, "api/stdio.c", .{
        .darwin = .passes,
        .gnu = .unsupported,
        .musl = .unsupported,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/stdlib.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/string.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/strings.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/sys_ipc.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/sys_mman.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/sys_msg.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/sys_resource.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/sys_select.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/sys_sem.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/sys_shm.c", .{
        .darwin = .passes,
        .gnu = .unsupported,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/sys_socket.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/sys_stat.c", .{
        .darwin = .unsupported,
        .gnu = .unsupported,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/sys_statvfs.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/sys_time.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/sys_times.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/sys_types.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/sys_uio.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/sys_un.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/sys_utsname.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/sys_wait.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/syslog.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/tar.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/termios.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/tgmath.c", .passes);
    installApiTestCase(&libc_test, "api/time.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/unistd.c", .{
        .darwin = .unsupported,
        .gnu = .unsupported,
        .musl = .unsupported,
        .mingw = .unsupported,
        .wasi = .unsupported,
    });
    installApiTestCase(&libc_test, "api/utmpx.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });
    installApiTestCase(&libc_test, "api/wchar.c", .passes);
    installApiTestCase(&libc_test, "api/wctype.c", .passes);
    installApiTestCase(&libc_test, "api/wordexp.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    });

    installSimpleTestCase(&libc_test, "functional/argv.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/basename.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/clocale_mbfuncs.c", .{
        .darwin = .passes,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/clock_gettime.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/crypt.c", .{
        .darwin = .unsupported,
        .gnu = .unsupported,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/dirname.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installDlopenTestCase(&libc_test, .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/env.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/fcntl.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/fdopen.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/fnmatch.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/fscanf.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/fwscanf.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/iconv_open.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/inet_pton.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/ipc_msg.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/ipc_sem.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/ipc_shm.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/mbc.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/memstream.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/mntent.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/popen.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/pthread_cancel.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/pthread_cancel-points.c", .{
        .darwin = .unsupported,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/pthread_cond.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/pthread_mutex.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/pthread_mutex_pi.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/pthread_robust.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/pthread_tsd.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/qsort.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/random.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/search_hsearch.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unstable,
    }, false);
    installSimpleTestCase(&libc_test, "functional/search_insque.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/search_lsearch.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/search_tsearch.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/sem_init.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/sem_open.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/setjmp.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/snprintf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/socket.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/spawn.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/sscanf.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/sscanf_long.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/stat.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/strftime.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/string.c", .{
        .darwin = .passes,
        .gnu = .unsupported,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/string_memcpy.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/string_memmem.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/string_memset.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/string_strchr.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/string_strcspn.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/string_strstr.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/strptime.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unstable,
    }, false);
    installSimpleTestCase(&libc_test, "functional/strtod.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/strtod_long.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/strtod_simple.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/strtof.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/strtol.c", .{
        .darwin = .passes,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/strtold.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/swprintf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "functional/tgmath.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/time.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installTlsAlignTestCase(&libc_test, .{
        .darwin = .passes,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installTlsAlignStaticTestCase(&libc_test, .passes, false);
    installSimpleTestCase(&libc_test, "functional/tls_init.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/tls_local_exec.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/udiv.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/ungetc.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/utime.c", .{
        .darwin = .unsupported,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/vfork.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "functional/wcsstr.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/wcstol.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);

    installSimpleTestCase(&libc_test, "math/acos.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/acosf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/acosh.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/acoshf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/acoshl.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/acosl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/asin.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/asinf.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/asinh.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .unstable,
    }, false);
    installSimpleTestCase(&libc_test, "math/asinhf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/asinhl.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/asinl.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/atan2.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/atan2f.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/atan2l.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/atan.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/atanf.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/atanh.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/atanhf.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/atanhl.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/atanl.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/cbrt.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/cbrtf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/cbrtl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/ceil.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/ceilf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/ceill.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/copysign.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/copysignf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/copysignl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/cos.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/cosf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/cosh.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/coshf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/coshl.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/cosl.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/drem.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/dremf.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/erf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/erfc.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .unstable,
    }, false);
    installSimpleTestCase(&libc_test, "math/erfcf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/erfcl.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/erff.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/erfl.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/exp10.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/exp10f.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/exp10l.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/exp2.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/exp2f.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/exp2l.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/exp.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/expf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/expl.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/expm1.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/expm1f.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/expm1l.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fabs.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/fabsf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/fabsl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/fdim.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fdimf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fdiml.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fenv.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/floor.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/floorf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/floorl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/fma.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .unstable,
    }, false);
    installSimpleTestCase(&libc_test, "math/fmaf.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fmal.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fmax.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fmaxf.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fmaxl.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fmin.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fminf.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fminl.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fmod.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fmodf.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fmodl.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/fpclassify.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/frexp.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/frexpf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/frexpl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/hypot.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/hypotf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/hypotl.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/ilogb.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/ilogbf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/ilogbl.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/isless.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/j0.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/j0f.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/j1.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/j1f.c", .{
        .darwin = .unsupported,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/jn.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/jnf.c", .{
        .darwin = .unsupported,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unstable,
    }, false);
    installSimpleTestCase(&libc_test, "math/ldexp.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/ldexpf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/ldexpl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/lgamma.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/lgammaf.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .unstable,
    }, false);
    installSimpleTestCase(&libc_test, "math/lgammaf_r.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unstable,
    }, false);
    installSimpleTestCase(&libc_test, "math/lgammal.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/lgammal_r.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/lgamma_r.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/llrint.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/llrintf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/llrintl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/llround.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/llroundf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/llroundl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/log10.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/log10f.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/log10l.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/log1p.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/log1pf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/log1pl.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/log2.c", .{
        .darwin = .passes,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/log2f.c", .{
        .darwin = .passes,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/log2l.c", .{
        .darwin = .passes,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/logb.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/logbf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/logbl.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/log.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/logf.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/logl.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/lrint.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/lrintf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/lrintl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/lround.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/lroundf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/lroundl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/modf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/modff.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/modfl.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/nearbyint.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/nearbyintf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/nearbyintl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/nextafter.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/nextafterf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/nextafterl.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/nexttoward.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/nexttowardf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/nexttowardl.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/pow10.c", .{
        .darwin = .unsupported,
        .gnu = .unsupported,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/pow10f.c", .{
        .darwin = .unsupported,
        .gnu = .unsupported,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/pow10l.c", .{
        .darwin = .unsupported,
        .gnu = .unsupported,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/pow.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/powf.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/powl.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/remainder.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/remainderf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/remainderl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/remquo.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/remquof.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/remquol.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/rint.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/rintf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/rintl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/round.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/roundf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/roundl.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/scalb.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/scalbf.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/scalbln.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/scalblnf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/scalblnl.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/scalbn.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/scalbnf.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/scalbnl.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/sin.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/sincos.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/sincosf.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/sincosl.c", .{
        .darwin = .unsupported,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/sinf.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/sinh.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/sinhf.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/sinhl.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/sinl.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/sqrt.c", .{
        .darwin = .passes,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/sqrtf.c", .{
        .darwin = .passes,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/sqrtl.c", .{
        .darwin = .passes,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/tan.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/tanf.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/tanh.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/tanhf.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/tanhl.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/tanl.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/tgamma.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/tgammaf.c", .{
        .darwin = .passes,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/tgammal.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/trunc.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/truncf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/truncl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/y0.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/y0f.c", .{
        .darwin = .unsupported,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unstable,
    }, false);
    installSimpleTestCase(&libc_test, "math/y1.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/y1f.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/yn.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "math/ynf.c", .{
        .darwin = .unsupported,
        .gnu = .unstable,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unstable,
    }, false);

    installSimpleTestCase(&libc_test, "regression/daemon-failure.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/dn_expand-empty.c", .{
        .darwin = .unsupported,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/dn_expand-ptr-0.c", .{
        .darwin = .unsupported,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/execle-env.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/fflush-exit.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/fgets-eof.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/fgetwc-buffering.c", .{
        .darwin = .passes,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/flockfile-list.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/fpclassify-invalid-ld80.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/ftello-unflushed-append.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/getpwnam_r-crash.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/getpwnam_r-errno.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/iconv-roundtrips.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unstable,
    }, false);
    installSimpleTestCase(&libc_test, "regression/inet_ntop-v4mapped.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/inet_pton-empty-last-field.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/iswspace-null.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/lrand48-signextend.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/lseek-large.c", .{
        .darwin = .passes,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/malloc-0.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/malloc-brk-fail.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, true);
    installSimpleTestCase(&libc_test, "regression/malloc-oom.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, true);
    installSimpleTestCase(&libc_test, "regression/mbsrtowcs-overflow.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/memmem-oob.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/memmem-oob-read.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/mkdtemp-failure.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/mkstemp-failure.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/printf-1e9-oob.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/printf-fmt-g-round.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/printf-fmt-g-zeros.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/printf-fmt-n.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_atfork-errno-clobber.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_cancel-sem_wait.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_condattr_setclock.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_cond-smasher.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_cond_wait-cancel_ignored.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_create-oom.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_exit-cancel.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unstable,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_exit-dtor.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_once-deadlock.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/pthread-robust-detach.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_rwlock-ebusy.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/putenv-doublefree.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/raise-race.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/regex-backref-0.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/regex-bracket-icase.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/regexec-nosub.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/regex-ere-backref.c", .{
        .darwin = .passes,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/regex-escaped-high-byte.c", .{
        .darwin = .unstable,
        .gnu = .unstable,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/regex-negated-range.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/rewind-clear-error.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/rlimit-open-files.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/scanf-bytes-consumed.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/scanf-match-literal-eof.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/scanf-nullbyte-char.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/sem_close-unmap.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/setenv-oom.c", .{
        .darwin = .unstable,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/setvbuf-unget.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/sigaltstack.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/sigprocmask-internal.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/sigreturn.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .passes,
        .wasi = .unsupported,
    }, false); //passes with libwasi-emulated-signal
    installSimpleTestCase(&libc_test, "regression/sscanf-eof.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/statvfs.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .unstable,
        .mingw = .unsupported,
        .wasi = .unstable,
    }, false);
    installSimpleTestCase(&libc_test, "regression/strverscmp.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/syscall-sign-extend.c", .{
        .darwin = .unsupported,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .unsupported,
    }, false);
    installSimpleTestCase(&libc_test, "regression/uselocale-0.c", .{
        .darwin = .passes,
        .gnu = .passes,
        .musl = .passes,
        .mingw = .unsupported,
        .wasi = .passes,
    }, false);
    installSimpleTestCase(&libc_test, "regression/wcsncpy-read-overflow.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/wcsstr-false-negative.c", .passes, false);

    // TODO
    // "functional/tls_align_dlopen.c"
    // "functional/tls_align_dso.c"
    // "functional/tls_init_dlopen.c"
    // "functional/tls_init_dso.c"
    // "regression/tls_get_new-dtv.c"
    // "regression/tls_get_new-dtv_dso.c"
}

/// Generate options.h based on libc-test/src/common/options.h.in
fn generateOptionsInclude(b: *std.Build, target: std.Build.ResolvedTarget, src: std.Build.LazyPath) !std.Build.LazyPath {
    var zig_run = b.addSystemCommand(&.{ b.graph.zig_exe, "cc", "-E", "-x", "c" });

    if (!target.query.isNative()) {
        zig_run.addArg("-target");
        zig_run.addArg(try target.query.zigTriple(b.allocator));
    }

    zig_run.addArg("-o");
    const preprocessed = zig_run.addOutputFileArg("options-in.h");

    zig_run.addFileArg(src.path(b, "common/options.h.in"));

    const exe = b.addExecutable(.{
        .name = "generate_options",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/generate_options.zig"),
            .target = b.graph.host,
            .optimize = .Debug, // for error checking
        }),
    });

    const exe_run = b.addRunArtifact(exe);
    exe_run.addFileArg(preprocessed);
    const include = exe_run.addOutputDirectoryArg("options-include");
    exe_run.addArg("options.h");

    return include;
}

fn installApiTestCase(libc_test: *const LibCTest, case: []const u8, support: LibCImpl.Support) void {
    if (support.shouldSkip(libc_test)) return;

    const b = libc_test.b;
    const test_mod = b.createModule(.{
        .target = libc_test.target,
        .optimize = libc_test.optimize,
        .link_libc = true,
    });

    test_mod.addIncludePath(libc_test.src.path(b, "common"));

    // Add directory containing 'options.h' to include path
    test_mod.addIncludePath(libc_test.options_include);

    test_mod.addCSourceFiles(.{
        .root = libc_test.src,
        .files = &.{ "api/main.c", case },
    });

    test_mod.linkLibrary(libc_test.libtest);

    const exe = b.addExecutable(.{
        .name = std.fs.path.stem(case),
        .root_module = test_mod,
    });

    installTestCase(libc_test, exe, .{});
}

fn installSimpleTestCase(libc_test: *const LibCTest, case: []const u8, support: LibCImpl.Support, debug_only: bool) void {
    if (support.shouldSkip(libc_test)) return;
    if (debug_only and libc_test.optimize != .Debug) return;

    const b = libc_test.b;
    const test_mod = b.createModule(.{
        .target = libc_test.target,
        .optimize = libc_test.optimize,
        .link_libc = true,
    });

    test_mod.addIncludePath(libc_test.src.path(b, "common"));

    test_mod.addCSourceFile(.{
        .file = libc_test.src.path(b, case),
    });

    test_mod.linkLibrary(libc_test.libtest);

    const exe = b.addExecutable(.{
        .name = std.fs.path.stem(case),
        .root_module = test_mod,
    });

    installTestCase(libc_test, exe, .{});
}

fn installDlopenTestCase(libc_test: *const LibCTest, support: LibCImpl.Support, debug_only: bool) void {
    if (support.shouldSkip(libc_test)) return;
    if (debug_only and libc_test.optimize != .Debug) return;

    const b = libc_test.b;
    const test_mod = b.createModule(.{
        .target = libc_test.target,
        .optimize = libc_test.optimize,
        .link_libc = true,
    });

    test_mod.addIncludePath(libc_test.src.path(b, "common"));

    test_mod.addCSourceFile(.{
        .file = libc_test.src.path(b, "functional/dlopen.c"),
    });

    test_mod.linkLibrary(libc_test.libtest);

    const exe = b.addExecutable(.{
        .name = "dlopen",
        .root_module = test_mod,
    });

    // Add '-rdynamic' flag
    exe.rdynamic = true;

    // Copy 'dlopen_dso.so' to same directory as 'dlopen' executable
    const lib = installTestLibrary(libc_test, "functional/dlopen_dso.c");
    const copy_dso = b.addRunArtifact(libc_test.copy_file);
    copy_dso.addFileArg(lib.getEmittedBin());
    copy_dso.addFileArg(exe.getEmittedBin().dirname().path(b, "dlopen_dso.so"));

    installTestCase(libc_test, exe, .{ .run_dep = &copy_dso.step });
}

fn installTlsAlignTestCase(libc_test: *const LibCTest, support: LibCImpl.Support, debug_only: bool) void {
    if (support.shouldSkip(libc_test)) return;
    if (debug_only and libc_test.optimize != .Debug) return;

    const b = libc_test.b;
    const test_mod = b.createModule(.{
        .target = libc_test.target,
        .optimize = libc_test.optimize,
        .link_libc = true,
    });

    test_mod.addIncludePath(libc_test.src.path(b, "common"));

    test_mod.addCSourceFile(.{
        .file = libc_test.src.path(b, "functional/tls_align.c"),
    });

    test_mod.linkLibrary(libc_test.libtest);

    // Link against 'tls_align_dso.so'
    test_mod.linkLibrary(installTestLibrary(libc_test, "functional/tls_align_dso.c"));

    const exe = b.addExecutable(.{
        .name = "tls_align",
        .root_module = test_mod,
    });

    installTestCase(libc_test, exe, .{});
}

fn installTlsAlignStaticTestCase(libc_test: *const LibCTest, support: LibCImpl.Support, debug_only: bool) void {
    if (support.shouldSkip(libc_test)) return;
    if (debug_only and libc_test.optimize != .Debug) return;

    const b = libc_test.b;
    const test_mod = b.createModule(.{
        .target = libc_test.target,
        .optimize = libc_test.optimize,
        .link_libc = true,
    });

    test_mod.addIncludePath(libc_test.src.path(b, "common"));

    test_mod.addCSourceFiles(.{
        .root = libc_test.src.path(b, "functional"),
        .files = &.{ "tls_align.c", "tls_align_dso.c" },
    });

    test_mod.linkLibrary(libc_test.libtest);

    const exe = b.addExecutable(.{
        .name = "tls_align-static",
        .root_module = test_mod,
    });

    installTestCase(libc_test, exe, .{});
}

fn installTestCase(
    libc_test: *const LibCTest,
    exe: *std.Build.Step.Compile,
    options: struct {
        run_dep: ?*std.Build.Step = null,
    },
) void {
    const b = libc_test.b;
    b.installArtifact(exe);

    const test_run = b.addRunArtifact(exe);

    if (options.run_dep) |dep|
        test_run.step.dependOn(dep);

    test_run.skip_foreign_checks = libc_test.skip_foreign_checks;

    test_run.expectStdErrEqual("");
    test_run.expectStdOutEqual("");
    test_run.expectExitCode(0);

    libc_test.test_step.dependOn(&test_run.step);
}

fn installTestLibrary(libc_test: *const LibCTest, library: []const u8) *std.Build.Step.Compile {
    const b = libc_test.b;
    const lib_mod = b.createModule(.{
        .target = libc_test.target,
        .optimize = libc_test.optimize,
        .link_libc = true,
        .pic = true,
    });

    lib_mod.addCSourceFile(.{
        .file = libc_test.src.path(b, library),
    });

    const lib = b.addLibrary(.{
        .name = std.fs.path.stem(library),
        .root_module = lib_mod,
        .linkage = .dynamic,
    });

    b.installArtifact(lib);

    return lib;
}
