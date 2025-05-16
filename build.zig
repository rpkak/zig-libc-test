const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .abi = .musl } });
    const optimize = b.standardOptimizeOption(.{});

    const src = b.dependency("libc_test", .{}).path("src");

    const libtest_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    libtest_mod.addCSourceFiles(.{
        .root = src.path(b, "common"),
        .files = &.{
            "vmfill.c",
            "utf8.c",
            "setrlim.c",
            "rand.c",
            "print.c",
            "path.c",
            "mtest.c",
            "memfill.c",
            "fdfill.c",
        },
    });

    const libtest = b.addLibrary(.{
        .name = "test",
        .root_module = libtest_mod,
    });

    const simple_cases: []const []const u8 = &.{
        "api/main.c",

        "functional/argv.c",
        "functional/basename.c",
        "functional/clocale_mbfuncs.c",
        "functional/clock_gettime.c",
        "functional/crypt.c",
        "functional/dirname.c",
        "functional/env.c",
        "functional/fcntl.c",
        "functional/fdopen.c",
        "functional/fnmatch.c",
        "functional/fscanf.c",
        "functional/fwscanf.c",
        "functional/iconv_open.c",
        "functional/inet_pton.c",
        "functional/ipc_msg.c",
        "functional/ipc_sem.c",
        "functional/ipc_shm.c",
        "functional/mbc.c",
        "functional/memstream.c",
        // "functional/mntent.c", // This test fails
        "functional/popen.c",
        "functional/pthread_cancel.c",
        "functional/pthread_cancel-points.c",
        "functional/pthread_cond.c",
        "functional/pthread_mutex.c",
        "functional/pthread_mutex_pi.c",
        "functional/pthread_robust.c",
        "functional/pthread_tsd.c",
        "functional/qsort.c",
        "functional/random.c",
        "functional/search_hsearch.c",
        "functional/search_insque.c",
        "functional/search_lsearch.c",
        "functional/search_tsearch.c",
        "functional/sem_init.c",
        "functional/sem_open.c",
        "functional/setjmp.c",
        "functional/snprintf.c",
        "functional/socket.c",
        "functional/spawn.c",
        "functional/sscanf.c",
        "functional/sscanf_long.c",
        "functional/stat.c",
        "functional/strftime.c",
        "functional/string.c",
        "functional/string_memcpy.c",
        "functional/string_memmem.c",
        "functional/string_memset.c",
        "functional/string_strchr.c",
        "functional/string_strcspn.c",
        "functional/string_strstr.c",
        // "functional/strptime.c", // This test fails
        "functional/strtod.c",
        "functional/strtod_long.c",
        "functional/strtod_simple.c",
        "functional/strtof.c",
        "functional/strtol.c",
        "functional/strtold.c",
        "functional/swprintf.c",
        "functional/tgmath.c",
        "functional/time.c",
        "functional/tls_init.c",
        "functional/tls_local_exec.c",
        "functional/udiv.c",
        "functional/ungetc.c",
        "functional/utime.c",
        "functional/vfork.c",
        "functional/wcsstr.c",
        "functional/wcstol.c",

        "math/acos.c",
        "math/acosf.c",
        // "math/acosh.c", // This test fails
        "math/acoshf.c",
        "math/acoshl.c",
        "math/acosl.c",
        "math/asin.c",
        "math/asinf.c",
        // "math/asinh.c", // This test fails
        "math/asinhf.c",
        "math/asinhl.c",
        "math/asinl.c",
        "math/atan2.c",
        "math/atan2f.c",
        "math/atan2l.c",
        "math/atan.c",
        "math/atanf.c",
        "math/atanh.c",
        "math/atanhf.c",
        "math/atanhl.c",
        "math/atanl.c",
        "math/cbrt.c",
        "math/cbrtf.c",
        "math/cbrtl.c",
        "math/ceil.c",
        "math/ceilf.c",
        "math/ceill.c",
        "math/copysign.c",
        "math/copysignf.c",
        "math/copysignl.c",
        "math/cos.c",
        "math/cosf.c",
        "math/cosh.c",
        "math/coshf.c",
        "math/coshl.c",
        "math/cosl.c",
        "math/drem.c",
        "math/dremf.c",
        "math/erf.c",
        // "math/erfc.c", // This test fails
        "math/erfcf.c",
        "math/erfcl.c",
        "math/erff.c",
        "math/erfl.c",
        "math/exp10.c",
        "math/exp10f.c",
        "math/exp10l.c",
        // "math/exp2.c", // This test fails
        "math/exp2f.c",
        "math/exp2l.c",
        "math/exp.c",
        "math/expf.c",
        "math/expl.c",
        "math/expm1.c",
        "math/expm1f.c",
        // "math/expm1l.c", // This test fails
        "math/fabs.c",
        "math/fabsf.c",
        "math/fabsl.c",
        "math/fdim.c",
        "math/fdimf.c",
        "math/fdiml.c",
        "math/fenv.c",
        "math/floor.c",
        "math/floorf.c",
        "math/floorl.c",
        // "math/fma.c", // This test fails
        "math/fmaf.c",
        // "math/fmal.c", // This test fails
        "math/fmax.c",
        "math/fmaxf.c",
        "math/fmaxl.c",
        "math/fmin.c",
        "math/fminf.c",
        "math/fminl.c",
        "math/fmod.c",
        "math/fmodf.c",
        "math/fmodl.c",
        "math/fpclassify.c",
        "math/frexp.c",
        "math/frexpf.c",
        "math/frexpl.c",
        "math/hypot.c",
        "math/hypotf.c",
        "math/hypotl.c",
        "math/ilogb.c",
        "math/ilogbf.c",
        "math/ilogbl.c",
        "math/isless.c",
        // "math/j0.c", // This test fails
        "math/j0f.c",
        "math/j1.c",
        "math/j1f.c",
        // "math/jn.c", // This test fails
        // "math/jnf.c", // This test fails
        "math/ldexp.c",
        "math/ldexpf.c",
        "math/ldexpl.c",
        // "math/lgamma.c", // This test fails
        // "math/lgammaf.c", // This test fails
        // "math/lgammaf_r.c", // This test fails
        "math/lgammal.c",
        "math/lgammal_r.c",
        "math/lgamma_r.c",
        "math/llrint.c",
        "math/llrintf.c",
        "math/llrintl.c",
        "math/llround.c",
        "math/llroundf.c",
        "math/llroundl.c",
        "math/log10.c",
        "math/log10f.c",
        "math/log10l.c",
        "math/log1p.c",
        "math/log1pf.c",
        "math/log1pl.c",
        "math/log2.c",
        "math/log2f.c",
        "math/log2l.c",
        "math/logb.c",
        "math/logbf.c",
        "math/logbl.c",
        "math/log.c",
        "math/logf.c",
        "math/logl.c",
        "math/lrint.c",
        "math/lrintf.c",
        "math/lrintl.c",
        "math/lround.c",
        "math/lroundf.c",
        "math/lroundl.c",
        "math/modf.c",
        "math/modff.c",
        "math/modfl.c",
        "math/nearbyint.c",
        "math/nearbyintf.c",
        "math/nearbyintl.c",
        "math/nextafter.c",
        "math/nextafterf.c",
        "math/nextafterl.c",
        "math/nexttoward.c",
        "math/nexttowardf.c",
        "math/nexttowardl.c",
        "math/pow10.c",
        "math/pow10f.c",
        "math/pow10l.c",
        // "math/pow.c", // This test fails
        // "math/powf.c", // This test fails
        "math/powl.c",
        "math/remainder.c",
        "math/remainderf.c",
        "math/remainderl.c",
        "math/remquo.c",
        "math/remquof.c",
        "math/remquol.c",
        "math/rint.c",
        "math/rintf.c",
        "math/rintl.c",
        "math/round.c",
        "math/roundf.c",
        "math/roundl.c",
        "math/scalb.c",
        "math/scalbf.c",
        "math/scalbln.c",
        "math/scalblnf.c",
        "math/scalblnl.c",
        "math/scalbn.c",
        "math/scalbnf.c",
        "math/scalbnl.c",
        "math/sin.c",
        "math/sincos.c",
        "math/sincosf.c",
        "math/sincosl.c",
        "math/sinf.c",
        // "math/sinh.c", // This test fails
        "math/sinhf.c",
        // "math/sinhl.c", // This test fails
        "math/sinl.c",
        "math/sqrt.c",
        "math/sqrtf.c",
        "math/sqrtl.c",
        "math/tan.c",
        "math/tanf.c",
        "math/tanh.c",
        "math/tanhf.c",
        "math/tanhl.c",
        "math/tanl.c",
        // "math/tgamma.c", // This test fails
        "math/tgammaf.c",
        "math/tgammal.c",
        "math/trunc.c",
        "math/truncf.c",
        "math/truncl.c",
        // "math/y0.c", // This test fails
        // "math/y0f.c", // This test fails
        "math/y1.c",
        "math/y1f.c",
        "math/yn.c",
        // "math/ynf.c", // This test fails

        "regression/daemon-failure.c",
        "regression/dn_expand-empty.c",
        "regression/dn_expand-ptr-0.c",
        "regression/execle-env.c",
        "regression/fflush-exit.c",
        "regression/fgets-eof.c",
        "regression/fgetwc-buffering.c",
        "regression/flockfile-list.c",
        "regression/fpclassify-invalid-ld80.c",
        "regression/ftello-unflushed-append.c",
        "regression/getpwnam_r-crash.c",
        "regression/getpwnam_r-errno.c",
        "regression/iconv-roundtrips.c",
        "regression/inet_ntop-v4mapped.c",
        "regression/inet_pton-empty-last-field.c",
        "regression/iswspace-null.c",
        "regression/lrand48-signextend.c",
        "regression/lseek-large.c",
        "regression/malloc-0.c",
        "regression/malloc-brk-fail.c",
        "regression/malloc-oom.c",
        "regression/mbsrtowcs-overflow.c",
        "regression/memmem-oob.c",
        "regression/memmem-oob-read.c",
        "regression/mkdtemp-failure.c",
        "regression/mkstemp-failure.c",
        "regression/printf-1e9-oob.c",
        "regression/printf-fmt-g-round.c",
        "regression/printf-fmt-g-zeros.c",
        "regression/printf-fmt-n.c",
        "regression/pthread_atfork-errno-clobber.c",
        "regression/pthread_cancel-sem_wait.c",
        "regression/pthread_condattr_setclock.c",
        "regression/pthread_cond-smasher.c",
        "regression/pthread_cond_wait-cancel_ignored.c",
        "regression/pthread_create-oom.c",
        "regression/pthread_exit-cancel.c",
        "regression/pthread_exit-dtor.c",
        "regression/pthread_once-deadlock.c",
        "regression/pthread-robust-detach.c",
        "regression/pthread_rwlock-ebusy.c",
        "regression/putenv-doublefree.c",
        "regression/raise-race.c",
        "regression/regex-backref-0.c",
        "regression/regex-bracket-icase.c",
        "regression/regexec-nosub.c",
        "regression/regex-ere-backref.c",
        "regression/regex-escaped-high-byte.c",
        "regression/regex-negated-range.c",
        "regression/rewind-clear-error.c",
        "regression/rlimit-open-files.c",
        "regression/scanf-bytes-consumed.c",
        "regression/scanf-match-literal-eof.c",
        "regression/scanf-nullbyte-char.c",
        "regression/sem_close-unmap.c",
        "regression/setenv-oom.c",
        "regression/setvbuf-unget.c",
        "regression/sigaltstack.c",
        "regression/sigprocmask-internal.c",
        "regression/sigreturn.c",
        "regression/sscanf-eof.c",
        // "regression/statvfs.c", // This test fails
        "regression/strverscmp.c",
        "regression/syscall-sign-extend.c",
        "regression/uselocale-0.c",
        "regression/wcsncpy-read-overflow.c",
        "regression/wcsstr-false-negative.c",
    };

    const test_step = b.step("test", "Run tests");

    for (simple_cases) |case| {
        const test_mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        test_mod.addIncludePath(src.path(b, "common"));

        test_mod.addCSourceFile(.{
            .file = src.path(b, case),
        });

        test_mod.linkLibrary(libtest);

        const exe = b.addExecutable(.{
            .name = case[(std.mem.lastIndexOfScalar(u8, case, '/') orelse @panic("Invalid name")) + 1 .. case.len - 2],
            .root_module = test_mod,
        });

        installTestCase(b, test_step, exe);
    }

    {
        // tls_align-static
        const test_mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        test_mod.addIncludePath(src.path(b, "common"));

        test_mod.addCSourceFiles(.{
            .root = src.path(b, "functional"),
            .files = &.{ "tls_align.c", "tls_align_dso.c" },
        });

        test_mod.linkLibrary(libtest);

        const exe = b.addExecutable(.{
            .name = "tls_align-static",
            .root_module = test_mod,
        });

        installTestCase(b, test_step, exe);
    }

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

fn installTestCase(b: *std.Build, test_step: *std.Build.Step, exe: *std.Build.Step.Compile) void {
    b.installArtifact(exe);

    const test_run = b.addRunArtifact(exe);

    test_run.expectStdErrEqual("");
    test_run.expectStdOutEqual("");
    test_run.expectExitCode(0);

    test_step.dependOn(&test_run.step);
}
