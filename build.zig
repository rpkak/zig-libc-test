const std = @import("std");

const LibCTest = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    src: std.Build.LazyPath,
    libtest: *std.Build.Step.Compile,
    test_step: *std.Build.Step,
    unstable: bool,
    skip_foreign_checks: bool,
    libc_impl: LibCImpl,
};

const LibCImpl = enum {
    musl,
    mingw,

    fn fromTarget(b: *std.Build, target: std.Target) !LibCImpl {
        if (target.isMuslLibC()) return .musl;
        if (target.isMinGW()) return .mingw;
        std.debug.panic("zig-libc-test does not support '{s}'. Use musl or mingw instead.", .{try target.zigTriple(b.allocator)});
    }

    const Support = struct {
        const Level = enum { passes, unstable, unsupported };

        musl: Level,
        mingw: Level,

        const passes: Support = .{ .musl = .passes, .mingw = .passes };
        const unstable: Support = .{ .musl = .unstable, .mingw = .unstable };

        fn shouldSkip(support: Support, libc_test: *const LibCTest) bool {
            const level = switch (libc_test.libc_impl) {
                .musl => support.musl,
                .mingw => support.mingw,
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

    const libc_impl: LibCImpl = try .fromTarget(b, target.result);

    const libtest_mod = b.createModule(.{
        .root_source_file = b.path("libtest.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    var libtest_c_source_files: std.ArrayListUnmanaged([]const u8) = .empty;
    defer libtest_c_source_files.deinit(b.allocator);

    try libtest_c_source_files.appendSlice(b.allocator, &.{
        "print.c",
        "mtest.c",
        "fdfill.c",
    });

    if (libc_impl == .musl) {
        try libtest_c_source_files.append(b.allocator, "utf8.c");
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
        .libtest = libtest,
        .test_step = test_step,
        .unstable = unstable,
        .skip_foreign_checks = skip_foreign_checks,
        .libc_impl = libc_impl,
    };

    installSimpleTestCase(&libc_test, "api/main.c", .passes, false);

    installSimpleTestCase(&libc_test, "functional/argv.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/basename.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/clocale_mbfuncs.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/clock_gettime.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/crypt.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/dirname.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/env.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/fcntl.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/fdopen.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/fnmatch.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/fscanf.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/fwscanf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "functional/iconv_open.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/inet_pton.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/ipc_msg.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/ipc_sem.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/ipc_shm.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/mbc.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/memstream.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/mntent.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/popen.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/pthread_cancel.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "functional/pthread_cancel-points.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/pthread_cond.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/pthread_mutex.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "functional/pthread_mutex_pi.c", .unstable, false);
    installSimpleTestCase(&libc_test, "functional/pthread_robust.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/pthread_tsd.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/qsort.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/random.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/search_hsearch.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/search_insque.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/search_lsearch.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/search_tsearch.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/sem_init.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/sem_open.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/setjmp.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/snprintf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "functional/socket.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/spawn.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/sscanf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "functional/sscanf_long.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/stat.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/strftime.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/string.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/string_memcpy.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/string_memmem.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/string_memset.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/string_strchr.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/string_strcspn.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/string_strstr.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/strptime.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/strtod.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/strtod_long.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/strtod_simple.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/strtof.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/strtol.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "functional/strtold.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/swprintf.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/tgmath.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/time.c", .passes, false);
    installTlsAlignStaticTestCase(&libc_test, .passes, false);
    installSimpleTestCase(&libc_test, "functional/tls_init.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/tls_local_exec.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/udiv.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/ungetc.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "functional/utime.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/vfork.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "functional/wcsstr.c", .passes, false);
    installSimpleTestCase(&libc_test, "functional/wcstol.c", .{ .musl = .passes, .mingw = .unstable }, false);

    installSimpleTestCase(&libc_test, "math/acos.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/acosf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/acosh.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/acoshf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/acoshl.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/acosl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/asin.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/asinf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/asinh.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/asinhf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/asinhl.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/asinl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/atan2.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/atan2f.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/atan2l.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/atan.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/atanf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/atanh.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/atanhf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/atanhl.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/atanl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/cbrt.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/cbrtf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/cbrtl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/ceil.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/ceilf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/ceill.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/copysign.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/copysignf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/copysignl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/cos.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/cosf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/cosh.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/coshf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/coshl.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/cosl.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/drem.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/dremf.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/erf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/erfc.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/erfcf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/erfcl.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/erff.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/erfl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/exp10.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/exp10f.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/exp10l.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/exp2.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/exp2f.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/exp2l.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/exp.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/expf.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/expl.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/expm1.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/expm1f.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/expm1l.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/fabs.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/fabsf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/fabsl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/fdim.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/fdimf.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/fdiml.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/fenv.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/floor.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/floorf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/floorl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/fma.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/fmaf.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/fmal.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/fmax.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/fmaxf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/fmaxl.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/fmin.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/fminf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/fminl.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/fmod.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/fmodf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/fmodl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/fpclassify.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/frexp.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/frexpf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/frexpl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/hypot.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/hypotf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/hypotl.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/ilogb.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/ilogbf.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/ilogbl.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/isless.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/j0.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/j0f.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/j1.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/j1f.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/jn.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/jnf.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/ldexp.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/ldexpf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/ldexpl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/lgamma.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/lgammaf.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/lgammaf_r.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/lgammal.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/lgammal_r.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/lgamma_r.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/llrint.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/llrintf.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/llrintl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/llround.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/llroundf.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/llroundl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/log10.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/log10f.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/log10l.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/log1p.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/log1pf.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/log1pl.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/log2.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/log2f.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/log2l.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/logb.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/logbf.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/logbl.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/log.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/logf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/logl.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/lrint.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/lrintf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/lrintl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/lround.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/lroundf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/lroundl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/modf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/modff.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/modfl.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/nearbyint.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/nearbyintf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/nearbyintl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/nextafter.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/nextafterf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/nextafterl.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/nexttoward.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/nexttowardf.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/nexttowardl.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/pow10.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/pow10f.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/pow10l.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/pow.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/powf.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/powl.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/remainder.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/remainderf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/remainderl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/remquo.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/remquof.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/remquol.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/rint.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/rintf.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/rintl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/round.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/roundf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/roundl.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/scalb.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/scalbf.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/scalbln.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/scalblnf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/scalblnl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/scalbn.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/scalbnf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/scalbnl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/sin.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/sincos.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/sincosf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/sincosl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/sinf.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/sinh.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/sinhf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/sinhl.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/sinl.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/sqrt.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/sqrtf.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/sqrtl.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/tan.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/tanf.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/tanh.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/tanhf.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "math/tanhl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/tanl.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "math/tgamma.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/tgammaf.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/tgammal.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/trunc.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/truncf.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/truncl.c", .passes, false);
    installSimpleTestCase(&libc_test, "math/y0.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/y0f.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/y1.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/y1f.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "math/yn.c", .unstable, false);
    installSimpleTestCase(&libc_test, "math/ynf.c", .{ .musl = .unstable, .mingw = .unsupported }, false);

    installSimpleTestCase(&libc_test, "regression/daemon-failure.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/dn_expand-empty.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/dn_expand-ptr-0.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/execle-env.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/fflush-exit.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/fgets-eof.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/fgetwc-buffering.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/flockfile-list.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/fpclassify-invalid-ld80.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "regression/ftello-unflushed-append.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/getpwnam_r-crash.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/getpwnam_r-errno.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/iconv-roundtrips.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/inet_ntop-v4mapped.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/inet_pton-empty-last-field.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/iswspace-null.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/lrand48-signextend.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/lseek-large.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "regression/malloc-0.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/malloc-brk-fail.c", .{ .musl = .passes, .mingw = .unsupported }, true);
    installSimpleTestCase(&libc_test, "regression/malloc-oom.c", .{ .musl = .unstable, .mingw = .unsupported }, true);
    installSimpleTestCase(&libc_test, "regression/mbsrtowcs-overflow.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/memmem-oob.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/memmem-oob-read.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/mkdtemp-failure.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/mkstemp-failure.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/printf-1e9-oob.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/printf-fmt-g-round.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/printf-fmt-g-zeros.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/printf-fmt-n.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_atfork-errno-clobber.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_cancel-sem_wait.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/pthread_condattr_setclock.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/pthread_cond-smasher.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/pthread_cond_wait-cancel_ignored.c", .{ .musl = .unstable, .mingw = .passes }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_create-oom.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_exit-cancel.c", .{ .musl = .passes, .mingw = .unstable }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_exit-dtor.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_once-deadlock.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/pthread-robust-detach.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/pthread_rwlock-ebusy.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/putenv-doublefree.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/raise-race.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/regex-backref-0.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/regex-bracket-icase.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/regexec-nosub.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/regex-ere-backref.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/regex-escaped-high-byte.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/regex-negated-range.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/rewind-clear-error.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/rlimit-open-files.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/scanf-bytes-consumed.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/scanf-match-literal-eof.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/scanf-nullbyte-char.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/sem_close-unmap.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/setenv-oom.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/setvbuf-unget.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/sigaltstack.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/sigprocmask-internal.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/sigreturn.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/sscanf-eof.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/statvfs.c", .{ .musl = .unstable, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/strverscmp.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/syscall-sign-extend.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/uselocale-0.c", .{ .musl = .passes, .mingw = .unsupported }, false);
    installSimpleTestCase(&libc_test, "regression/wcsncpy-read-overflow.c", .passes, false);
    installSimpleTestCase(&libc_test, "regression/wcsstr-false-negative.c", .passes, false);

    // TODO
    // "functional/dlopen.c",
    // "functional/dlopen_dso.c"
    // "functional/tls_align.c"
    // "functional/tls_align_dlopen.c"
    // "functional/tls_align_dso.c"
    // "functional/tls_init_dlopen.c"
    // "functional/tls_init_dso.c"
    // "regression/tls_get_new-dtv.c"
    // "regression/tls_get_new-dtv_dso.c"
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
        .name = case[(std.mem.lastIndexOfScalar(u8, case, '/') orelse @panic("Invalid name")) + 1 .. case.len - 2],
        .root_module = test_mod,
    });

    installTestCase(libc_test, exe);
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

    installTestCase(libc_test, exe);
}

fn installTestCase(libc_test: *const LibCTest, exe: *std.Build.Step.Compile) void {
    const b = libc_test.b;
    b.installArtifact(exe);

    const test_run = b.addRunArtifact(exe);

    test_run.skip_foreign_checks = libc_test.skip_foreign_checks;

    test_run.expectStdErrEqual("");
    test_run.expectStdOutEqual("");
    test_run.expectExitCode(0);

    libc_test.test_step.dependOn(&test_run.step);
}
