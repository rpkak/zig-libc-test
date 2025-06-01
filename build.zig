const std = @import("std");

const LibCTest = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    src: std.Build.LazyPath,
    libtest: *std.Build.Step.Compile,
    test_step: *std.Build.Step,
    no_skip: bool,
};

const Skip = struct {
    always: bool = false,

    release: bool = false,

    x86: bool = false,
    x86_64: bool = false,
    x32: bool = false,

    aarch64: bool = false,
    aarch64_be: bool = false,

    riscv: bool = false,
    riscv32: bool = false,

    powerpc64: bool = false,
    powerpc64le: bool = false,

    s390x: bool = false,

    loongarch64: bool = false,

    hexagon: bool = false,

    big_endian: bool = false,

    fn shouldSkip(skip: Skip, libc_test: *const LibCTest) bool {
        if (libc_test.no_skip) return false;

        if (skip.always) return true;

        if (skip.release and libc_test.optimize != .Debug) return true;

        if (skip.x86 and libc_test.target.result.cpu.arch.isX86()) return true;
        if (skip.x86_64 and libc_test.target.result.cpu.arch == .x86_64) return true;
        if (skip.x32 and libc_test.target.result.abi == .muslx32) return true;

        if (skip.aarch64 and libc_test.target.result.cpu.arch.isAARCH64()) return true;
        if (skip.aarch64_be and libc_test.target.result.cpu.arch == .aarch64_be) return true;

        if (skip.riscv and libc_test.target.result.cpu.arch.isRISCV()) return true;
        if (skip.riscv32 and libc_test.target.result.cpu.arch == .riscv32) return true;

        if (skip.powerpc64 and libc_test.target.result.cpu.arch.isPowerPC64()) return true;
        if (skip.powerpc64le and libc_test.target.result.cpu.arch == .powerpc64le) return true;

        if (skip.s390x and libc_test.target.result.cpu.arch == .s390x) return true;

        if (skip.loongarch64 and libc_test.target.result.cpu.arch == .loongarch64) return true;

        if (skip.hexagon and libc_test.target.result.cpu.arch == .hexagon) return true;

        if (skip.big_endian and libc_test.target.result.cpu.arch.endian() == .big) return true;
        return false;
    }
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .abi = .musl } });
    const optimize = b.standardOptimizeOption(.{});

    const no_skip = b.option(bool, "no-skip", "Do not skip failing test cases") orelse false;

    const src = b.dependency("libc_test", .{}).path("src");

    const libtest_mod = b.createModule(.{
        .root_source_file = b.path("libtest.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    libtest_mod.addCSourceFiles(.{
        .root = src.path(b, "common"),
        .files = &.{
            "utf8.c",
            "print.c",
            "mtest.c",
            "fdfill.c",
        },
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
        .no_skip = no_skip,
    };

    installSimpleTestCase(&libc_test, "api/main.c", .{});

    installSimpleTestCase(&libc_test, "functional/argv.c", .{});
    installSimpleTestCase(&libc_test, "functional/basename.c", .{});
    installSimpleTestCase(&libc_test, "functional/clocale_mbfuncs.c", .{});
    installSimpleTestCase(&libc_test, "functional/clock_gettime.c", .{});
    installSimpleTestCase(&libc_test, "functional/crypt.c", .{});
    installSimpleTestCase(&libc_test, "functional/dirname.c", .{});
    installSimpleTestCase(&libc_test, "functional/env.c", .{});
    installSimpleTestCase(&libc_test, "functional/fcntl.c", .{});
    installSimpleTestCase(&libc_test, "functional/fdopen.c", .{});
    installSimpleTestCase(&libc_test, "functional/fnmatch.c", .{});
    installSimpleTestCase(&libc_test, "functional/fscanf.c", .{});
    installSimpleTestCase(&libc_test, "functional/fwscanf.c", .{});
    installSimpleTestCase(&libc_test, "functional/iconv_open.c", .{});
    installSimpleTestCase(&libc_test, "functional/inet_pton.c", .{});
    installSimpleTestCase(&libc_test, "functional/ipc_msg.c", .{ .big_endian = true, .x32 = true });
    installSimpleTestCase(&libc_test, "functional/ipc_sem.c", .{ .aarch64_be = true, .s390x = true });
    installSimpleTestCase(&libc_test, "functional/ipc_shm.c", .{ .aarch64_be = true, .s390x = true });
    installSimpleTestCase(&libc_test, "functional/mbc.c", .{});
    installSimpleTestCase(&libc_test, "functional/memstream.c", .{});
    installSimpleTestCase(&libc_test, "functional/mntent.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "functional/popen.c", .{});
    installSimpleTestCase(&libc_test, "functional/pthread_cancel.c", .{});
    installSimpleTestCase(&libc_test, "functional/pthread_cancel-points.c", .{});
    installSimpleTestCase(&libc_test, "functional/pthread_cond.c", .{});
    installSimpleTestCase(&libc_test, "functional/pthread_mutex.c", .{});
    installSimpleTestCase(&libc_test, "functional/pthread_mutex_pi.c", .{ .big_endian = true });
    installSimpleTestCase(&libc_test, "functional/pthread_robust.c", .{ .powerpc64 = true, .aarch64 = true, .s390x = true, .riscv = true, .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "functional/pthread_tsd.c", .{});
    installSimpleTestCase(&libc_test, "functional/qsort.c", .{});
    installSimpleTestCase(&libc_test, "functional/random.c", .{});
    installSimpleTestCase(&libc_test, "functional/search_hsearch.c", .{});
    installSimpleTestCase(&libc_test, "functional/search_insque.c", .{});
    installSimpleTestCase(&libc_test, "functional/search_lsearch.c", .{});
    installSimpleTestCase(&libc_test, "functional/search_tsearch.c", .{});
    installSimpleTestCase(&libc_test, "functional/sem_init.c", .{});
    installSimpleTestCase(&libc_test, "functional/sem_open.c", .{});
    installSimpleTestCase(&libc_test, "functional/setjmp.c", .{});
    installSimpleTestCase(&libc_test, "functional/snprintf.c", .{});
    installSimpleTestCase(&libc_test, "functional/socket.c", .{});
    installSimpleTestCase(&libc_test, "functional/spawn.c", .{});
    installSimpleTestCase(&libc_test, "functional/sscanf.c", .{});
    installSimpleTestCase(&libc_test, "functional/sscanf_long.c", .{});
    installSimpleTestCase(&libc_test, "functional/stat.c", .{});
    installSimpleTestCase(&libc_test, "functional/strftime.c", .{});
    installSimpleTestCase(&libc_test, "functional/string.c", .{});
    installSimpleTestCase(&libc_test, "functional/string_memcpy.c", .{});
    installSimpleTestCase(&libc_test, "functional/string_memmem.c", .{});
    installSimpleTestCase(&libc_test, "functional/string_memset.c", .{});
    installSimpleTestCase(&libc_test, "functional/string_strchr.c", .{});
    installSimpleTestCase(&libc_test, "functional/string_strcspn.c", .{});
    installSimpleTestCase(&libc_test, "functional/string_strstr.c", .{});
    installSimpleTestCase(&libc_test, "functional/strptime.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "functional/strtod.c", .{});
    installSimpleTestCase(&libc_test, "functional/strtod_long.c", .{});
    installSimpleTestCase(&libc_test, "functional/strtod_simple.c", .{});
    installSimpleTestCase(&libc_test, "functional/strtof.c", .{});
    installSimpleTestCase(&libc_test, "functional/strtol.c", .{});
    installSimpleTestCase(&libc_test, "functional/strtold.c", .{});
    installSimpleTestCase(&libc_test, "functional/swprintf.c", .{});
    installSimpleTestCase(&libc_test, "functional/tgmath.c", .{});
    installSimpleTestCase(&libc_test, "functional/time.c", .{});
    installTlsAlignStaticTestCase(&libc_test, .{});
    installSimpleTestCase(&libc_test, "functional/tls_init.c", .{});
    installSimpleTestCase(&libc_test, "functional/tls_local_exec.c", .{});
    installSimpleTestCase(&libc_test, "functional/udiv.c", .{});
    installSimpleTestCase(&libc_test, "functional/ungetc.c", .{});
    installSimpleTestCase(&libc_test, "functional/utime.c", .{});
    installSimpleTestCase(&libc_test, "functional/vfork.c", .{});
    installSimpleTestCase(&libc_test, "functional/wcsstr.c", .{});
    installSimpleTestCase(&libc_test, "functional/wcstol.c", .{});

    installSimpleTestCase(&libc_test, "math/acos.c", .{});
    installSimpleTestCase(&libc_test, "math/acosf.c", .{});
    installSimpleTestCase(&libc_test, "math/acosh.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/acoshf.c", .{});
    installSimpleTestCase(&libc_test, "math/acoshl.c", .{ .powerpc64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/acosl.c", .{});
    installSimpleTestCase(&libc_test, "math/asin.c", .{});
    installSimpleTestCase(&libc_test, "math/asinf.c", .{});
    installSimpleTestCase(&libc_test, "math/asinh.c", .{ .powerpc64 = true, .x86_64 = true, .aarch64 = true, .s390x = true, .riscv = true, .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/asinhf.c", .{});
    installSimpleTestCase(&libc_test, "math/asinhl.c", .{ .powerpc64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/asinl.c", .{});
    installSimpleTestCase(&libc_test, "math/atan2.c", .{});
    installSimpleTestCase(&libc_test, "math/atan2f.c", .{});
    installSimpleTestCase(&libc_test, "math/atan2l.c", .{});
    installSimpleTestCase(&libc_test, "math/atan.c", .{});
    installSimpleTestCase(&libc_test, "math/atanf.c", .{});
    installSimpleTestCase(&libc_test, "math/atanh.c", .{});
    installSimpleTestCase(&libc_test, "math/atanhf.c", .{});
    installSimpleTestCase(&libc_test, "math/atanhl.c", .{});
    installSimpleTestCase(&libc_test, "math/atanl.c", .{});
    installSimpleTestCase(&libc_test, "math/cbrt.c", .{});
    installSimpleTestCase(&libc_test, "math/cbrtf.c", .{});
    installSimpleTestCase(&libc_test, "math/cbrtl.c", .{});
    installSimpleTestCase(&libc_test, "math/ceil.c", .{});
    installSimpleTestCase(&libc_test, "math/ceilf.c", .{});
    installSimpleTestCase(&libc_test, "math/ceill.c", .{});
    installSimpleTestCase(&libc_test, "math/copysign.c", .{});
    installSimpleTestCase(&libc_test, "math/copysignf.c", .{});
    installSimpleTestCase(&libc_test, "math/copysignl.c", .{});
    installSimpleTestCase(&libc_test, "math/cos.c", .{});
    installSimpleTestCase(&libc_test, "math/cosf.c", .{});
    installSimpleTestCase(&libc_test, "math/cosh.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/coshf.c", .{});
    installSimpleTestCase(&libc_test, "math/coshl.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/cosl.c", .{});
    installSimpleTestCase(&libc_test, "math/drem.c", .{});
    installSimpleTestCase(&libc_test, "math/dremf.c", .{});
    installSimpleTestCase(&libc_test, "math/erf.c", .{});
    installSimpleTestCase(&libc_test, "math/erfc.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/erfcf.c", .{});
    installSimpleTestCase(&libc_test, "math/erfcl.c", .{ .powerpc64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/erff.c", .{});
    installSimpleTestCase(&libc_test, "math/erfl.c", .{});
    installSimpleTestCase(&libc_test, "math/exp10.c", .{});
    installSimpleTestCase(&libc_test, "math/exp10f.c", .{});
    installSimpleTestCase(&libc_test, "math/exp10l.c", .{});
    installSimpleTestCase(&libc_test, "math/exp2.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/exp2f.c", .{});
    installSimpleTestCase(&libc_test, "math/exp2l.c", .{ .powerpc64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/exp.c", .{});
    installSimpleTestCase(&libc_test, "math/expf.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/expl.c", .{});
    installSimpleTestCase(&libc_test, "math/expm1.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/expm1f.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/expm1l.c", .{ .x86 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/fabs.c", .{});
    installSimpleTestCase(&libc_test, "math/fabsf.c", .{});
    installSimpleTestCase(&libc_test, "math/fabsl.c", .{});
    installSimpleTestCase(&libc_test, "math/fdim.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/fdimf.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/fdiml.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/fenv.c", .{});
    installSimpleTestCase(&libc_test, "math/floor.c", .{});
    installSimpleTestCase(&libc_test, "math/floorf.c", .{});
    installSimpleTestCase(&libc_test, "math/floorl.c", .{});
    installSimpleTestCase(&libc_test, "math/fma.c", .{ .x86 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/fmaf.c", .{});
    installSimpleTestCase(&libc_test, "math/fmal.c", .{ .x86 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/fmax.c", .{});
    installSimpleTestCase(&libc_test, "math/fmaxf.c", .{});
    installSimpleTestCase(&libc_test, "math/fmaxl.c", .{});
    installSimpleTestCase(&libc_test, "math/fmin.c", .{});
    installSimpleTestCase(&libc_test, "math/fminf.c", .{});
    installSimpleTestCase(&libc_test, "math/fminl.c", .{});
    installSimpleTestCase(&libc_test, "math/fmod.c", .{});
    installSimpleTestCase(&libc_test, "math/fmodf.c", .{});
    installSimpleTestCase(&libc_test, "math/fmodl.c", .{});
    installSimpleTestCase(&libc_test, "math/fpclassify.c", .{});
    installSimpleTestCase(&libc_test, "math/frexp.c", .{});
    installSimpleTestCase(&libc_test, "math/frexpf.c", .{});
    installSimpleTestCase(&libc_test, "math/frexpl.c", .{});
    installSimpleTestCase(&libc_test, "math/hypot.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/hypotf.c", .{});
    installSimpleTestCase(&libc_test, "math/hypotl.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/ilogb.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/ilogbf.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/ilogbl.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/isless.c", .{});
    installSimpleTestCase(&libc_test, "math/j0.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/j0f.c", .{});
    installSimpleTestCase(&libc_test, "math/j1.c", .{});
    installSimpleTestCase(&libc_test, "math/j1f.c", .{});
    installSimpleTestCase(&libc_test, "math/jn.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/jnf.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/ldexp.c", .{});
    installSimpleTestCase(&libc_test, "math/ldexpf.c", .{});
    installSimpleTestCase(&libc_test, "math/ldexpl.c", .{});
    installSimpleTestCase(&libc_test, "math/lgamma.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/lgammaf.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/lgammaf_r.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/lgammal.c", .{ .powerpc64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/lgammal_r.c", .{});
    installSimpleTestCase(&libc_test, "math/lgamma_r.c", .{});
    installSimpleTestCase(&libc_test, "math/llrint.c", .{ .riscv32 = true });
    installSimpleTestCase(&libc_test, "math/llrintf.c", .{ .riscv32 = true });
    installSimpleTestCase(&libc_test, "math/llrintl.c", .{});
    installSimpleTestCase(&libc_test, "math/llround.c", .{ .riscv32 = true });
    installSimpleTestCase(&libc_test, "math/llroundf.c", .{ .riscv32 = true });
    installSimpleTestCase(&libc_test, "math/llroundl.c", .{});
    installSimpleTestCase(&libc_test, "math/log10.c", .{});
    installSimpleTestCase(&libc_test, "math/log10f.c", .{});
    installSimpleTestCase(&libc_test, "math/log10l.c", .{});
    installSimpleTestCase(&libc_test, "math/log1p.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/log1pf.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/log1pl.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/log2.c", .{});
    installSimpleTestCase(&libc_test, "math/log2f.c", .{});
    installSimpleTestCase(&libc_test, "math/log2l.c", .{});
    installSimpleTestCase(&libc_test, "math/logb.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/logbf.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/logbl.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/log.c", .{});
    installSimpleTestCase(&libc_test, "math/logf.c", .{});
    installSimpleTestCase(&libc_test, "math/logl.c", .{});
    installSimpleTestCase(&libc_test, "math/lrint.c", .{});
    installSimpleTestCase(&libc_test, "math/lrintf.c", .{});
    installSimpleTestCase(&libc_test, "math/lrintl.c", .{});
    installSimpleTestCase(&libc_test, "math/lround.c", .{});
    installSimpleTestCase(&libc_test, "math/lroundf.c", .{});
    installSimpleTestCase(&libc_test, "math/lroundl.c", .{});
    installSimpleTestCase(&libc_test, "math/modf.c", .{});
    installSimpleTestCase(&libc_test, "math/modff.c", .{});
    installSimpleTestCase(&libc_test, "math/modfl.c", .{});
    installSimpleTestCase(&libc_test, "math/nearbyint.c", .{});
    installSimpleTestCase(&libc_test, "math/nearbyintf.c", .{});
    installSimpleTestCase(&libc_test, "math/nearbyintl.c", .{});
    installSimpleTestCase(&libc_test, "math/nextafter.c", .{});
    installSimpleTestCase(&libc_test, "math/nextafterf.c", .{});
    installSimpleTestCase(&libc_test, "math/nextafterl.c", .{});
    installSimpleTestCase(&libc_test, "math/nexttoward.c", .{});
    installSimpleTestCase(&libc_test, "math/nexttowardf.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/nexttowardl.c", .{});
    installSimpleTestCase(&libc_test, "math/pow10.c", .{});
    installSimpleTestCase(&libc_test, "math/pow10f.c", .{});
    installSimpleTestCase(&libc_test, "math/pow10l.c", .{});
    installSimpleTestCase(&libc_test, "math/pow.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/powf.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/powl.c", .{ .powerpc64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/remainder.c", .{});
    installSimpleTestCase(&libc_test, "math/remainderf.c", .{});
    installSimpleTestCase(&libc_test, "math/remainderl.c", .{});
    installSimpleTestCase(&libc_test, "math/remquo.c", .{});
    installSimpleTestCase(&libc_test, "math/remquof.c", .{});
    installSimpleTestCase(&libc_test, "math/remquol.c", .{});
    installSimpleTestCase(&libc_test, "math/rint.c", .{});
    installSimpleTestCase(&libc_test, "math/rintf.c", .{});
    installSimpleTestCase(&libc_test, "math/rintl.c", .{});
    installSimpleTestCase(&libc_test, "math/round.c", .{});
    installSimpleTestCase(&libc_test, "math/roundf.c", .{});
    installSimpleTestCase(&libc_test, "math/roundl.c", .{});
    installSimpleTestCase(&libc_test, "math/scalb.c", .{});
    installSimpleTestCase(&libc_test, "math/scalbf.c", .{});
    installSimpleTestCase(&libc_test, "math/scalbln.c", .{});
    installSimpleTestCase(&libc_test, "math/scalblnf.c", .{});
    installSimpleTestCase(&libc_test, "math/scalblnl.c", .{});
    installSimpleTestCase(&libc_test, "math/scalbn.c", .{});
    installSimpleTestCase(&libc_test, "math/scalbnf.c", .{});
    installSimpleTestCase(&libc_test, "math/scalbnl.c", .{});
    installSimpleTestCase(&libc_test, "math/sin.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/sincos.c", .{});
    installSimpleTestCase(&libc_test, "math/sincosf.c", .{});
    installSimpleTestCase(&libc_test, "math/sincosl.c", .{});
    installSimpleTestCase(&libc_test, "math/sinf.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/sinh.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/sinhf.c", .{});
    installSimpleTestCase(&libc_test, "math/sinhl.c", .{ .x86 = true, .powerpc64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/sinl.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/sqrt.c", .{});
    installSimpleTestCase(&libc_test, "math/sqrtf.c", .{});
    installSimpleTestCase(&libc_test, "math/sqrtl.c", .{});
    installSimpleTestCase(&libc_test, "math/tan.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/tanf.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/tanh.c", .{});
    installSimpleTestCase(&libc_test, "math/tanhf.c", .{});
    installSimpleTestCase(&libc_test, "math/tanhl.c", .{});
    installSimpleTestCase(&libc_test, "math/tanl.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "math/tgamma.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/tgammaf.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/tgammal.c", .{ .powerpc64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/trunc.c", .{});
    installSimpleTestCase(&libc_test, "math/truncf.c", .{});
    installSimpleTestCase(&libc_test, "math/truncl.c", .{});
    installSimpleTestCase(&libc_test, "math/y0.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/y0f.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "math/y1.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/y1f.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/yn.c", .{ .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "math/ynf.c", .{ .always = true });

    installSimpleTestCase(&libc_test, "regression/daemon-failure.c", .{});
    installSimpleTestCase(&libc_test, "regression/dn_expand-empty.c", .{});
    installSimpleTestCase(&libc_test, "regression/dn_expand-ptr-0.c", .{});
    installSimpleTestCase(&libc_test, "regression/execle-env.c", .{});
    installSimpleTestCase(&libc_test, "regression/fflush-exit.c", .{});
    installSimpleTestCase(&libc_test, "regression/fgets-eof.c", .{});
    installSimpleTestCase(&libc_test, "regression/fgetwc-buffering.c", .{});
    installSimpleTestCase(&libc_test, "regression/flockfile-list.c", .{});
    installSimpleTestCase(&libc_test, "regression/fpclassify-invalid-ld80.c", .{});
    installSimpleTestCase(&libc_test, "regression/ftello-unflushed-append.c", .{});
    installSimpleTestCase(&libc_test, "regression/getpwnam_r-crash.c", .{});
    installSimpleTestCase(&libc_test, "regression/getpwnam_r-errno.c", .{});
    installSimpleTestCase(&libc_test, "regression/iconv-roundtrips.c", .{});
    installSimpleTestCase(&libc_test, "regression/inet_ntop-v4mapped.c", .{});
    installSimpleTestCase(&libc_test, "regression/inet_pton-empty-last-field.c", .{});
    installSimpleTestCase(&libc_test, "regression/iswspace-null.c", .{});
    installSimpleTestCase(&libc_test, "regression/lrand48-signextend.c", .{});
    installSimpleTestCase(&libc_test, "regression/lseek-large.c", .{});
    installSimpleTestCase(&libc_test, "regression/malloc-0.c", .{});
    installSimpleTestCase(&libc_test, "regression/malloc-brk-fail.c", .{ .release = true });
    installSimpleTestCase(&libc_test, "regression/malloc-oom.c", .{ .release = true, .powerpc64le = true });
    installSimpleTestCase(&libc_test, "regression/mbsrtowcs-overflow.c", .{});
    installSimpleTestCase(&libc_test, "regression/memmem-oob.c", .{});
    installSimpleTestCase(&libc_test, "regression/memmem-oob-read.c", .{});
    installSimpleTestCase(&libc_test, "regression/mkdtemp-failure.c", .{});
    installSimpleTestCase(&libc_test, "regression/mkstemp-failure.c", .{});
    installSimpleTestCase(&libc_test, "regression/printf-1e9-oob.c", .{});
    installSimpleTestCase(&libc_test, "regression/printf-fmt-g-round.c", .{});
    installSimpleTestCase(&libc_test, "regression/printf-fmt-g-zeros.c", .{});
    installSimpleTestCase(&libc_test, "regression/printf-fmt-n.c", .{});
    installSimpleTestCase(&libc_test, "regression/pthread_atfork-errno-clobber.c", .{});
    installSimpleTestCase(&libc_test, "regression/pthread_cancel-sem_wait.c", .{});
    installSimpleTestCase(&libc_test, "regression/pthread_condattr_setclock.c", .{});
    installSimpleTestCase(&libc_test, "regression/pthread_cond-smasher.c", .{});
    installSimpleTestCase(&libc_test, "regression/pthread_cond_wait-cancel_ignored.c", .{ .hexagon = true });
    installSimpleTestCase(&libc_test, "regression/pthread_create-oom.c", .{ .powerpc64 = true });
    installSimpleTestCase(&libc_test, "regression/pthread_exit-cancel.c", .{});
    installSimpleTestCase(&libc_test, "regression/pthread_exit-dtor.c", .{});
    installSimpleTestCase(&libc_test, "regression/pthread_once-deadlock.c", .{});
    installSimpleTestCase(&libc_test, "regression/pthread-robust-detach.c", .{ .powerpc64 = true, .aarch64 = true, .s390x = true, .riscv = true, .loongarch64 = true, .hexagon = true });
    installSimpleTestCase(&libc_test, "regression/pthread_rwlock-ebusy.c", .{});
    installSimpleTestCase(&libc_test, "regression/putenv-doublefree.c", .{});
    installSimpleTestCase(&libc_test, "regression/raise-race.c", .{});
    installSimpleTestCase(&libc_test, "regression/regex-backref-0.c", .{});
    installSimpleTestCase(&libc_test, "regression/regex-bracket-icase.c", .{});
    installSimpleTestCase(&libc_test, "regression/regexec-nosub.c", .{});
    installSimpleTestCase(&libc_test, "regression/regex-ere-backref.c", .{});
    installSimpleTestCase(&libc_test, "regression/regex-escaped-high-byte.c", .{});
    installSimpleTestCase(&libc_test, "regression/regex-negated-range.c", .{});
    installSimpleTestCase(&libc_test, "regression/rewind-clear-error.c", .{});
    installSimpleTestCase(&libc_test, "regression/rlimit-open-files.c", .{});
    installSimpleTestCase(&libc_test, "regression/scanf-bytes-consumed.c", .{});
    installSimpleTestCase(&libc_test, "regression/scanf-match-literal-eof.c", .{});
    installSimpleTestCase(&libc_test, "regression/scanf-nullbyte-char.c", .{});
    installSimpleTestCase(&libc_test, "regression/sem_close-unmap.c", .{});
    installSimpleTestCase(&libc_test, "regression/setenv-oom.c", .{ .powerpc64 = true });
    installSimpleTestCase(&libc_test, "regression/setvbuf-unget.c", .{});
    installSimpleTestCase(&libc_test, "regression/sigaltstack.c", .{});
    installSimpleTestCase(&libc_test, "regression/sigprocmask-internal.c", .{});
    installSimpleTestCase(&libc_test, "regression/sigreturn.c", .{});
    installSimpleTestCase(&libc_test, "regression/sscanf-eof.c", .{});
    installSimpleTestCase(&libc_test, "regression/statvfs.c", .{ .always = true });
    installSimpleTestCase(&libc_test, "regression/strverscmp.c", .{});
    installSimpleTestCase(&libc_test, "regression/syscall-sign-extend.c", .{});
    installSimpleTestCase(&libc_test, "regression/uselocale-0.c", .{});
    installSimpleTestCase(&libc_test, "regression/wcsncpy-read-overflow.c", .{});
    installSimpleTestCase(&libc_test, "regression/wcsstr-false-negative.c", .{});

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

fn installSimpleTestCase(libc_test: *const LibCTest, case: []const u8, skip: Skip) void {
    if (skip.shouldSkip(libc_test))
        return;

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

    installTestCase(b, libc_test.test_step, exe);
}

fn installTlsAlignStaticTestCase(libc_test: *const LibCTest, skip: Skip) void {
    if (skip.shouldSkip(libc_test))
        return;

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

    installTestCase(b, libc_test.test_step, exe);
}

fn installTestCase(b: *std.Build, test_step: *std.Build.Step, exe: *std.Build.Step.Compile) void {
    b.installArtifact(exe);

    const test_run = b.addRunArtifact(exe);

    test_run.expectStdErrEqual("");
    test_run.expectStdOutEqual("");
    test_run.expectExitCode(0);

    test_step.dependOn(&test_run.step);
}
