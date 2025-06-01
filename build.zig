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
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .abi = .musl } });
    const optimize = b.standardOptimizeOption(.{});

    const unstable = b.option(bool, "unstable", "Do not skip test cases, which fail sometimes") orelse false;

    const skip_foreign_checks = b.option(bool, "skip-foreign-checks", "Skip foreign checks") orelse false;

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
        .unstable = unstable,
        .skip_foreign_checks = skip_foreign_checks,
    };

    installSimpleTestCase(&libc_test, "api/main.c", false, false);

    installSimpleTestCase(&libc_test, "functional/argv.c", false, false);
    installSimpleTestCase(&libc_test, "functional/basename.c", false, false);
    installSimpleTestCase(&libc_test, "functional/clocale_mbfuncs.c", false, false);
    installSimpleTestCase(&libc_test, "functional/clock_gettime.c", false, false);
    installSimpleTestCase(&libc_test, "functional/crypt.c", false, false);
    installSimpleTestCase(&libc_test, "functional/dirname.c", false, false);
    installSimpleTestCase(&libc_test, "functional/env.c", false, false);
    installSimpleTestCase(&libc_test, "functional/fcntl.c", false, false);
    installSimpleTestCase(&libc_test, "functional/fdopen.c", false, false);
    installSimpleTestCase(&libc_test, "functional/fnmatch.c", false, false);
    installSimpleTestCase(&libc_test, "functional/fscanf.c", false, false);
    installSimpleTestCase(&libc_test, "functional/fwscanf.c", false, false);
    installSimpleTestCase(&libc_test, "functional/iconv_open.c", false, false);
    installSimpleTestCase(&libc_test, "functional/inet_pton.c", false, false);
    installSimpleTestCase(&libc_test, "functional/ipc_msg.c", true, false);
    installSimpleTestCase(&libc_test, "functional/ipc_sem.c", true, false);
    installSimpleTestCase(&libc_test, "functional/ipc_shm.c", true, false);
    installSimpleTestCase(&libc_test, "functional/mbc.c", false, false);
    installSimpleTestCase(&libc_test, "functional/memstream.c", false, false);
    installSimpleTestCase(&libc_test, "functional/mntent.c", true, false);
    installSimpleTestCase(&libc_test, "functional/popen.c", false, false);
    installSimpleTestCase(&libc_test, "functional/pthread_cancel.c", false, false);
    installSimpleTestCase(&libc_test, "functional/pthread_cancel-points.c", false, false);
    installSimpleTestCase(&libc_test, "functional/pthread_cond.c", false, false);
    installSimpleTestCase(&libc_test, "functional/pthread_mutex.c", false, false);
    installSimpleTestCase(&libc_test, "functional/pthread_mutex_pi.c", true, false);
    installSimpleTestCase(&libc_test, "functional/pthread_robust.c", true, false);
    installSimpleTestCase(&libc_test, "functional/pthread_tsd.c", false, false);
    installSimpleTestCase(&libc_test, "functional/qsort.c", false, false);
    installSimpleTestCase(&libc_test, "functional/random.c", false, false);
    installSimpleTestCase(&libc_test, "functional/search_hsearch.c", false, false);
    installSimpleTestCase(&libc_test, "functional/search_insque.c", false, false);
    installSimpleTestCase(&libc_test, "functional/search_lsearch.c", false, false);
    installSimpleTestCase(&libc_test, "functional/search_tsearch.c", false, false);
    installSimpleTestCase(&libc_test, "functional/sem_init.c", false, false);
    installSimpleTestCase(&libc_test, "functional/sem_open.c", false, false);
    installSimpleTestCase(&libc_test, "functional/setjmp.c", false, false);
    installSimpleTestCase(&libc_test, "functional/snprintf.c", false, false);
    installSimpleTestCase(&libc_test, "functional/socket.c", false, false);
    installSimpleTestCase(&libc_test, "functional/spawn.c", false, false);
    installSimpleTestCase(&libc_test, "functional/sscanf.c", false, false);
    installSimpleTestCase(&libc_test, "functional/sscanf_long.c", false, false);
    installSimpleTestCase(&libc_test, "functional/stat.c", false, false);
    installSimpleTestCase(&libc_test, "functional/strftime.c", false, false);
    installSimpleTestCase(&libc_test, "functional/string.c", false, false);
    installSimpleTestCase(&libc_test, "functional/string_memcpy.c", false, false);
    installSimpleTestCase(&libc_test, "functional/string_memmem.c", false, false);
    installSimpleTestCase(&libc_test, "functional/string_memset.c", false, false);
    installSimpleTestCase(&libc_test, "functional/string_strchr.c", false, false);
    installSimpleTestCase(&libc_test, "functional/string_strcspn.c", false, false);
    installSimpleTestCase(&libc_test, "functional/string_strstr.c", false, false);
    installSimpleTestCase(&libc_test, "functional/strptime.c", true, false);
    installSimpleTestCase(&libc_test, "functional/strtod.c", false, false);
    installSimpleTestCase(&libc_test, "functional/strtod_long.c", false, false);
    installSimpleTestCase(&libc_test, "functional/strtod_simple.c", false, false);
    installSimpleTestCase(&libc_test, "functional/strtof.c", false, false);
    installSimpleTestCase(&libc_test, "functional/strtol.c", false, false);
    installSimpleTestCase(&libc_test, "functional/strtold.c", false, false);
    installSimpleTestCase(&libc_test, "functional/swprintf.c", false, false);
    installSimpleTestCase(&libc_test, "functional/tgmath.c", false, false);
    installSimpleTestCase(&libc_test, "functional/time.c", false, false);
    installTlsAlignStaticTestCase(&libc_test, false, false);
    installSimpleTestCase(&libc_test, "functional/tls_init.c", false, false);
    installSimpleTestCase(&libc_test, "functional/tls_local_exec.c", false, false);
    installSimpleTestCase(&libc_test, "functional/udiv.c", false, false);
    installSimpleTestCase(&libc_test, "functional/ungetc.c", false, false);
    installSimpleTestCase(&libc_test, "functional/utime.c", false, false);
    installSimpleTestCase(&libc_test, "functional/vfork.c", false, false);
    installSimpleTestCase(&libc_test, "functional/wcsstr.c", false, false);
    installSimpleTestCase(&libc_test, "functional/wcstol.c", false, false);

    installSimpleTestCase(&libc_test, "math/acos.c", false, false);
    installSimpleTestCase(&libc_test, "math/acosf.c", false, false);
    installSimpleTestCase(&libc_test, "math/acosh.c", true, false);
    installSimpleTestCase(&libc_test, "math/acoshf.c", false, false);
    installSimpleTestCase(&libc_test, "math/acoshl.c", true, false);
    installSimpleTestCase(&libc_test, "math/acosl.c", false, false);
    installSimpleTestCase(&libc_test, "math/asin.c", false, false);
    installSimpleTestCase(&libc_test, "math/asinf.c", false, false);
    installSimpleTestCase(&libc_test, "math/asinh.c", true, false);
    installSimpleTestCase(&libc_test, "math/asinhf.c", false, false);
    installSimpleTestCase(&libc_test, "math/asinhl.c", true, false);
    installSimpleTestCase(&libc_test, "math/asinl.c", false, false);
    installSimpleTestCase(&libc_test, "math/atan2.c", false, false);
    installSimpleTestCase(&libc_test, "math/atan2f.c", false, false);
    installSimpleTestCase(&libc_test, "math/atan2l.c", false, false);
    installSimpleTestCase(&libc_test, "math/atan.c", false, false);
    installSimpleTestCase(&libc_test, "math/atanf.c", false, false);
    installSimpleTestCase(&libc_test, "math/atanh.c", false, false);
    installSimpleTestCase(&libc_test, "math/atanhf.c", false, false);
    installSimpleTestCase(&libc_test, "math/atanhl.c", false, false);
    installSimpleTestCase(&libc_test, "math/atanl.c", false, false);
    installSimpleTestCase(&libc_test, "math/cbrt.c", false, false);
    installSimpleTestCase(&libc_test, "math/cbrtf.c", false, false);
    installSimpleTestCase(&libc_test, "math/cbrtl.c", false, false);
    installSimpleTestCase(&libc_test, "math/ceil.c", false, false);
    installSimpleTestCase(&libc_test, "math/ceilf.c", false, false);
    installSimpleTestCase(&libc_test, "math/ceill.c", false, false);
    installSimpleTestCase(&libc_test, "math/copysign.c", false, false);
    installSimpleTestCase(&libc_test, "math/copysignf.c", false, false);
    installSimpleTestCase(&libc_test, "math/copysignl.c", false, false);
    installSimpleTestCase(&libc_test, "math/cos.c", false, false);
    installSimpleTestCase(&libc_test, "math/cosf.c", false, false);
    installSimpleTestCase(&libc_test, "math/cosh.c", true, false);
    installSimpleTestCase(&libc_test, "math/coshf.c", false, false);
    installSimpleTestCase(&libc_test, "math/coshl.c", true, false);
    installSimpleTestCase(&libc_test, "math/cosl.c", false, false);
    installSimpleTestCase(&libc_test, "math/drem.c", false, false);
    installSimpleTestCase(&libc_test, "math/dremf.c", false, false);
    installSimpleTestCase(&libc_test, "math/erf.c", false, false);
    installSimpleTestCase(&libc_test, "math/erfc.c", true, false);
    installSimpleTestCase(&libc_test, "math/erfcf.c", false, false);
    installSimpleTestCase(&libc_test, "math/erfcl.c", true, false);
    installSimpleTestCase(&libc_test, "math/erff.c", false, false);
    installSimpleTestCase(&libc_test, "math/erfl.c", false, false);
    installSimpleTestCase(&libc_test, "math/exp10.c", false, false);
    installSimpleTestCase(&libc_test, "math/exp10f.c", false, false);
    installSimpleTestCase(&libc_test, "math/exp10l.c", false, false);
    installSimpleTestCase(&libc_test, "math/exp2.c", true, false);
    installSimpleTestCase(&libc_test, "math/exp2f.c", false, false);
    installSimpleTestCase(&libc_test, "math/exp2l.c", true, false);
    installSimpleTestCase(&libc_test, "math/exp.c", false, false);
    installSimpleTestCase(&libc_test, "math/expf.c", true, false);
    installSimpleTestCase(&libc_test, "math/expl.c", false, false);
    installSimpleTestCase(&libc_test, "math/expm1.c", true, false);
    installSimpleTestCase(&libc_test, "math/expm1f.c", true, false);
    installSimpleTestCase(&libc_test, "math/expm1l.c", true, false);
    installSimpleTestCase(&libc_test, "math/fabs.c", false, false);
    installSimpleTestCase(&libc_test, "math/fabsf.c", false, false);
    installSimpleTestCase(&libc_test, "math/fabsl.c", false, false);
    installSimpleTestCase(&libc_test, "math/fdim.c", true, false);
    installSimpleTestCase(&libc_test, "math/fdimf.c", true, false);
    installSimpleTestCase(&libc_test, "math/fdiml.c", true, false);
    installSimpleTestCase(&libc_test, "math/fenv.c", false, false);
    installSimpleTestCase(&libc_test, "math/floor.c", false, false);
    installSimpleTestCase(&libc_test, "math/floorf.c", false, false);
    installSimpleTestCase(&libc_test, "math/floorl.c", false, false);
    installSimpleTestCase(&libc_test, "math/fma.c", true, false);
    installSimpleTestCase(&libc_test, "math/fmaf.c", true, false);
    installSimpleTestCase(&libc_test, "math/fmal.c", true, false);
    installSimpleTestCase(&libc_test, "math/fmax.c", false, false);
    installSimpleTestCase(&libc_test, "math/fmaxf.c", false, false);
    installSimpleTestCase(&libc_test, "math/fmaxl.c", false, false);
    installSimpleTestCase(&libc_test, "math/fmin.c", false, false);
    installSimpleTestCase(&libc_test, "math/fminf.c", false, false);
    installSimpleTestCase(&libc_test, "math/fminl.c", false, false);
    installSimpleTestCase(&libc_test, "math/fmod.c", false, false);
    installSimpleTestCase(&libc_test, "math/fmodf.c", false, false);
    installSimpleTestCase(&libc_test, "math/fmodl.c", false, false);
    installSimpleTestCase(&libc_test, "math/fpclassify.c", false, false);
    installSimpleTestCase(&libc_test, "math/frexp.c", false, false);
    installSimpleTestCase(&libc_test, "math/frexpf.c", false, false);
    installSimpleTestCase(&libc_test, "math/frexpl.c", false, false);
    installSimpleTestCase(&libc_test, "math/hypot.c", true, false);
    installSimpleTestCase(&libc_test, "math/hypotf.c", false, false);
    installSimpleTestCase(&libc_test, "math/hypotl.c", true, false);
    installSimpleTestCase(&libc_test, "math/ilogb.c", true, false);
    installSimpleTestCase(&libc_test, "math/ilogbf.c", true, false);
    installSimpleTestCase(&libc_test, "math/ilogbl.c", true, false);
    installSimpleTestCase(&libc_test, "math/isless.c", false, false);
    installSimpleTestCase(&libc_test, "math/j0.c", true, false);
    installSimpleTestCase(&libc_test, "math/j0f.c", false, false);
    installSimpleTestCase(&libc_test, "math/j1.c", false, false);
    installSimpleTestCase(&libc_test, "math/j1f.c", false, false);
    installSimpleTestCase(&libc_test, "math/jn.c", true, false);
    installSimpleTestCase(&libc_test, "math/jnf.c", true, false);
    installSimpleTestCase(&libc_test, "math/ldexp.c", false, false);
    installSimpleTestCase(&libc_test, "math/ldexpf.c", false, false);
    installSimpleTestCase(&libc_test, "math/ldexpl.c", false, false);
    installSimpleTestCase(&libc_test, "math/lgamma.c", true, false);
    installSimpleTestCase(&libc_test, "math/lgammaf.c", true, false);
    installSimpleTestCase(&libc_test, "math/lgammaf_r.c", true, false);
    installSimpleTestCase(&libc_test, "math/lgammal.c", true, false);
    installSimpleTestCase(&libc_test, "math/lgammal_r.c", false, false);
    installSimpleTestCase(&libc_test, "math/lgamma_r.c", false, false);
    installSimpleTestCase(&libc_test, "math/llrint.c", true, false);
    installSimpleTestCase(&libc_test, "math/llrintf.c", true, false);
    installSimpleTestCase(&libc_test, "math/llrintl.c", false, false);
    installSimpleTestCase(&libc_test, "math/llround.c", true, false);
    installSimpleTestCase(&libc_test, "math/llroundf.c", true, false);
    installSimpleTestCase(&libc_test, "math/llroundl.c", false, false);
    installSimpleTestCase(&libc_test, "math/log10.c", false, false);
    installSimpleTestCase(&libc_test, "math/log10f.c", false, false);
    installSimpleTestCase(&libc_test, "math/log10l.c", false, false);
    installSimpleTestCase(&libc_test, "math/log1p.c", true, false);
    installSimpleTestCase(&libc_test, "math/log1pf.c", true, false);
    installSimpleTestCase(&libc_test, "math/log1pl.c", true, false);
    installSimpleTestCase(&libc_test, "math/log2.c", false, false);
    installSimpleTestCase(&libc_test, "math/log2f.c", false, false);
    installSimpleTestCase(&libc_test, "math/log2l.c", false, false);
    installSimpleTestCase(&libc_test, "math/logb.c", true, false);
    installSimpleTestCase(&libc_test, "math/logbf.c", true, false);
    installSimpleTestCase(&libc_test, "math/logbl.c", true, false);
    installSimpleTestCase(&libc_test, "math/log.c", false, false);
    installSimpleTestCase(&libc_test, "math/logf.c", false, false);
    installSimpleTestCase(&libc_test, "math/logl.c", false, false);
    installSimpleTestCase(&libc_test, "math/lrint.c", false, false);
    installSimpleTestCase(&libc_test, "math/lrintf.c", false, false);
    installSimpleTestCase(&libc_test, "math/lrintl.c", false, false);
    installSimpleTestCase(&libc_test, "math/lround.c", false, false);
    installSimpleTestCase(&libc_test, "math/lroundf.c", false, false);
    installSimpleTestCase(&libc_test, "math/lroundl.c", false, false);
    installSimpleTestCase(&libc_test, "math/modf.c", false, false);
    installSimpleTestCase(&libc_test, "math/modff.c", false, false);
    installSimpleTestCase(&libc_test, "math/modfl.c", false, false);
    installSimpleTestCase(&libc_test, "math/nearbyint.c", false, false);
    installSimpleTestCase(&libc_test, "math/nearbyintf.c", false, false);
    installSimpleTestCase(&libc_test, "math/nearbyintl.c", false, false);
    installSimpleTestCase(&libc_test, "math/nextafter.c", false, false);
    installSimpleTestCase(&libc_test, "math/nextafterf.c", false, false);
    installSimpleTestCase(&libc_test, "math/nextafterl.c", false, false);
    installSimpleTestCase(&libc_test, "math/nexttoward.c", false, false);
    installSimpleTestCase(&libc_test, "math/nexttowardf.c", true, false);
    installSimpleTestCase(&libc_test, "math/nexttowardl.c", false, false);
    installSimpleTestCase(&libc_test, "math/pow10.c", false, false);
    installSimpleTestCase(&libc_test, "math/pow10f.c", false, false);
    installSimpleTestCase(&libc_test, "math/pow10l.c", false, false);
    installSimpleTestCase(&libc_test, "math/pow.c", true, false);
    installSimpleTestCase(&libc_test, "math/powf.c", true, false);
    installSimpleTestCase(&libc_test, "math/powl.c", true, false);
    installSimpleTestCase(&libc_test, "math/remainder.c", false, false);
    installSimpleTestCase(&libc_test, "math/remainderf.c", false, false);
    installSimpleTestCase(&libc_test, "math/remainderl.c", false, false);
    installSimpleTestCase(&libc_test, "math/remquo.c", false, false);
    installSimpleTestCase(&libc_test, "math/remquof.c", false, false);
    installSimpleTestCase(&libc_test, "math/remquol.c", false, false);
    installSimpleTestCase(&libc_test, "math/rint.c", true, false);
    installSimpleTestCase(&libc_test, "math/rintf.c", true, false);
    installSimpleTestCase(&libc_test, "math/rintl.c", false, false);
    installSimpleTestCase(&libc_test, "math/round.c", false, false);
    installSimpleTestCase(&libc_test, "math/roundf.c", false, false);
    installSimpleTestCase(&libc_test, "math/roundl.c", false, false);
    installSimpleTestCase(&libc_test, "math/scalb.c", false, false);
    installSimpleTestCase(&libc_test, "math/scalbf.c", false, false);
    installSimpleTestCase(&libc_test, "math/scalbln.c", false, false);
    installSimpleTestCase(&libc_test, "math/scalblnf.c", false, false);
    installSimpleTestCase(&libc_test, "math/scalblnl.c", false, false);
    installSimpleTestCase(&libc_test, "math/scalbn.c", false, false);
    installSimpleTestCase(&libc_test, "math/scalbnf.c", false, false);
    installSimpleTestCase(&libc_test, "math/scalbnl.c", false, false);
    installSimpleTestCase(&libc_test, "math/sin.c", true, false);
    installSimpleTestCase(&libc_test, "math/sincos.c", false, false);
    installSimpleTestCase(&libc_test, "math/sincosf.c", false, false);
    installSimpleTestCase(&libc_test, "math/sincosl.c", false, false);
    installSimpleTestCase(&libc_test, "math/sinf.c", true, false);
    installSimpleTestCase(&libc_test, "math/sinh.c", true, false);
    installSimpleTestCase(&libc_test, "math/sinhf.c", false, false);
    installSimpleTestCase(&libc_test, "math/sinhl.c", true, false);
    installSimpleTestCase(&libc_test, "math/sinl.c", true, false);
    installSimpleTestCase(&libc_test, "math/sqrt.c", true, false);
    installSimpleTestCase(&libc_test, "math/sqrtf.c", true, false);
    installSimpleTestCase(&libc_test, "math/sqrtl.c", false, false);
    installSimpleTestCase(&libc_test, "math/tan.c", true, false);
    installSimpleTestCase(&libc_test, "math/tanf.c", true, false);
    installSimpleTestCase(&libc_test, "math/tanh.c", false, false);
    installSimpleTestCase(&libc_test, "math/tanhf.c", false, false);
    installSimpleTestCase(&libc_test, "math/tanhl.c", false, false);
    installSimpleTestCase(&libc_test, "math/tanl.c", true, false);
    installSimpleTestCase(&libc_test, "math/tgamma.c", true, false);
    installSimpleTestCase(&libc_test, "math/tgammaf.c", true, false);
    installSimpleTestCase(&libc_test, "math/tgammal.c", true, false);
    installSimpleTestCase(&libc_test, "math/trunc.c", false, false);
    installSimpleTestCase(&libc_test, "math/truncf.c", false, false);
    installSimpleTestCase(&libc_test, "math/truncl.c", false, false);
    installSimpleTestCase(&libc_test, "math/y0.c", true, false);
    installSimpleTestCase(&libc_test, "math/y0f.c", true, false);
    installSimpleTestCase(&libc_test, "math/y1.c", true, false);
    installSimpleTestCase(&libc_test, "math/y1f.c", true, false);
    installSimpleTestCase(&libc_test, "math/yn.c", true, false);
    installSimpleTestCase(&libc_test, "math/ynf.c", true, false);

    installSimpleTestCase(&libc_test, "regression/daemon-failure.c", false, false);
    installSimpleTestCase(&libc_test, "regression/dn_expand-empty.c", false, false);
    installSimpleTestCase(&libc_test, "regression/dn_expand-ptr-0.c", false, false);
    installSimpleTestCase(&libc_test, "regression/execle-env.c", false, false);
    installSimpleTestCase(&libc_test, "regression/fflush-exit.c", false, false);
    installSimpleTestCase(&libc_test, "regression/fgets-eof.c", false, false);
    installSimpleTestCase(&libc_test, "regression/fgetwc-buffering.c", false, false);
    installSimpleTestCase(&libc_test, "regression/flockfile-list.c", false, false);
    installSimpleTestCase(&libc_test, "regression/fpclassify-invalid-ld80.c", false, false);
    installSimpleTestCase(&libc_test, "regression/ftello-unflushed-append.c", false, false);
    installSimpleTestCase(&libc_test, "regression/getpwnam_r-crash.c", false, false);
    installSimpleTestCase(&libc_test, "regression/getpwnam_r-errno.c", false, false);
    installSimpleTestCase(&libc_test, "regression/iconv-roundtrips.c", false, false);
    installSimpleTestCase(&libc_test, "regression/inet_ntop-v4mapped.c", false, false);
    installSimpleTestCase(&libc_test, "regression/inet_pton-empty-last-field.c", false, false);
    installSimpleTestCase(&libc_test, "regression/iswspace-null.c", false, false);
    installSimpleTestCase(&libc_test, "regression/lrand48-signextend.c", false, false);
    installSimpleTestCase(&libc_test, "regression/lseek-large.c", false, false);
    installSimpleTestCase(&libc_test, "regression/malloc-0.c", false, false);
    installSimpleTestCase(&libc_test, "regression/malloc-brk-fail.c", false, true);
    installSimpleTestCase(&libc_test, "regression/malloc-oom.c", true, true);
    installSimpleTestCase(&libc_test, "regression/mbsrtowcs-overflow.c", false, false);
    installSimpleTestCase(&libc_test, "regression/memmem-oob.c", false, false);
    installSimpleTestCase(&libc_test, "regression/memmem-oob-read.c", false, false);
    installSimpleTestCase(&libc_test, "regression/mkdtemp-failure.c", false, false);
    installSimpleTestCase(&libc_test, "regression/mkstemp-failure.c", false, false);
    installSimpleTestCase(&libc_test, "regression/printf-1e9-oob.c", false, false);
    installSimpleTestCase(&libc_test, "regression/printf-fmt-g-round.c", false, false);
    installSimpleTestCase(&libc_test, "regression/printf-fmt-g-zeros.c", false, false);
    installSimpleTestCase(&libc_test, "regression/printf-fmt-n.c", false, false);
    installSimpleTestCase(&libc_test, "regression/pthread_atfork-errno-clobber.c", true, false);
    installSimpleTestCase(&libc_test, "regression/pthread_cancel-sem_wait.c", false, false);
    installSimpleTestCase(&libc_test, "regression/pthread_condattr_setclock.c", false, false);
    installSimpleTestCase(&libc_test, "regression/pthread_cond-smasher.c", false, false);
    installSimpleTestCase(&libc_test, "regression/pthread_cond_wait-cancel_ignored.c", true, false);
    installSimpleTestCase(&libc_test, "regression/pthread_create-oom.c", true, false);
    installSimpleTestCase(&libc_test, "regression/pthread_exit-cancel.c", false, false);
    installSimpleTestCase(&libc_test, "regression/pthread_exit-dtor.c", false, false);
    installSimpleTestCase(&libc_test, "regression/pthread_once-deadlock.c", false, false);
    installSimpleTestCase(&libc_test, "regression/pthread-robust-detach.c", true, false);
    installSimpleTestCase(&libc_test, "regression/pthread_rwlock-ebusy.c", false, false);
    installSimpleTestCase(&libc_test, "regression/putenv-doublefree.c", false, false);
    installSimpleTestCase(&libc_test, "regression/raise-race.c", false, false);
    installSimpleTestCase(&libc_test, "regression/regex-backref-0.c", false, false);
    installSimpleTestCase(&libc_test, "regression/regex-bracket-icase.c", false, false);
    installSimpleTestCase(&libc_test, "regression/regexec-nosub.c", false, false);
    installSimpleTestCase(&libc_test, "regression/regex-ere-backref.c", false, false);
    installSimpleTestCase(&libc_test, "regression/regex-escaped-high-byte.c", false, false);
    installSimpleTestCase(&libc_test, "regression/regex-negated-range.c", false, false);
    installSimpleTestCase(&libc_test, "regression/rewind-clear-error.c", false, false);
    installSimpleTestCase(&libc_test, "regression/rlimit-open-files.c", false, false);
    installSimpleTestCase(&libc_test, "regression/scanf-bytes-consumed.c", false, false);
    installSimpleTestCase(&libc_test, "regression/scanf-match-literal-eof.c", false, false);
    installSimpleTestCase(&libc_test, "regression/scanf-nullbyte-char.c", false, false);
    installSimpleTestCase(&libc_test, "regression/sem_close-unmap.c", false, false);
    installSimpleTestCase(&libc_test, "regression/setenv-oom.c", true, false);
    installSimpleTestCase(&libc_test, "regression/setvbuf-unget.c", false, false);
    installSimpleTestCase(&libc_test, "regression/sigaltstack.c", false, false);
    installSimpleTestCase(&libc_test, "regression/sigprocmask-internal.c", false, false);
    installSimpleTestCase(&libc_test, "regression/sigreturn.c", false, false);
    installSimpleTestCase(&libc_test, "regression/sscanf-eof.c", false, false);
    installSimpleTestCase(&libc_test, "regression/statvfs.c", true, false);
    installSimpleTestCase(&libc_test, "regression/strverscmp.c", false, false);
    installSimpleTestCase(&libc_test, "regression/syscall-sign-extend.c", false, false);
    installSimpleTestCase(&libc_test, "regression/uselocale-0.c", false, false);
    installSimpleTestCase(&libc_test, "regression/wcsncpy-read-overflow.c", false, false);
    installSimpleTestCase(&libc_test, "regression/wcsstr-false-negative.c", false, false);

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

fn installSimpleTestCase(libc_test: *const LibCTest, case: []const u8, unstable: bool, debug_only: bool) void {
    if (unstable and !libc_test.unstable) return;
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

fn installTlsAlignStaticTestCase(libc_test: *const LibCTest, unstable: bool, debug_only: bool) void {
    if (unstable and !libc_test.unstable) return;
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
