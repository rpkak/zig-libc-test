const builtin = @import("builtin");
const std = @import("std");
const posix = std.posix;

extern fn t_printf(s: [*:0]const u8, ...) c_int;

var rand: std.Random.DefaultPrng = .init(0);

export fn t_randseed(s: u64) void {
    rand.seed(s);
}

export fn t_randn(n: u64) u64 {
    return rand.random().uintLessThan(u64, n);
}

export fn t_shuffle(p: [*]u64, n: usize) void {
    rand.random().shuffle(u64, p[0..n]);
}

fn testMapLength(length: usize) !bool {
    const memory = posix.mmap(null, length, posix.PROT.NONE, .{ .TYPE = .PRIVATE, .ANONYMOUS = true }, -1, 0) catch |err| return switch (err) {
        error.OutOfMemory => false,
        else => err,
    };
    posix.munmap(memory);
    return true;
}

fn t_vmfill(p: [*][*]align(std.heap.page_size_min) u8, n: [*]usize, len: c_int) callconv(.c) c_int {
    var upper_bound_log: std.math.Log2Int(usize) = @typeInfo(usize).int.bits - 1;

    var i: std.math.IntFittingRange(0, std.math.maxInt(c_int)) = 0;

    const page_size_log = @ctz(std.heap.pageSize());

    while (true) : (i += 1) {
        while (!(testMapLength(@as(usize, 1) << upper_bound_log) catch return -1)) : (upper_bound_log -= 1) {
            if (upper_bound_log == page_size_log) {
                return i;
            }
        }

        var length = @as(usize, 1) << upper_bound_log;
        var bit = upper_bound_log - 1;
        while (bit != page_size_log - 1) : (bit -= 1) {
            const new_length = length | (@as(usize, 1) << bit);
            if (testMapLength(new_length) catch return -1) {
                length = new_length;
            }
        }

        const memory = posix.mmap(null, length, posix.PROT.NONE, .{ .TYPE = .PRIVATE, .ANONYMOUS = true }, -1, 0) catch return -1;
        if (i < len) {
            p[i] = memory.ptr;
            n[i] = memory.len;
        }
    }
}

fn t_setrlim(r: std.c.rlimit_resource, lim: c_long) callconv(.c) c_int {
    var rl = std.posix.getrlimit(r) catch |err| {
        _ = t_printf(std.fmt.comptimePrint("{s}:{d}: getrlimit %s: %s\n", .{ @src().file, @src().line }), @tagName(r).ptr, @errorName(err).ptr);
        return -1;
    };

    if (lim > rl.max)
        return -1;

    if (lim == rl.max and lim == rl.cur)
        return 0;

    rl.max = @intCast(lim);
    rl.cur = @intCast(lim);

    std.posix.setrlimit(r, rl) catch |err| {
        _ = t_printf(std.fmt.comptimePrint("{s}:{d}: setrlimit(%s, %ld): %s\n", .{ @src().file, @src().line }), @tagName(r).ptr, lim, @errorName(err).ptr);
        return -1;
    };
    return 0;
}

fn t_memfill() callconv(.c) c_int {
    var err = false;
    if (t_vmfill(undefined, undefined, 0) == -1) {
        _ = t_printf(std.fmt.comptimePrint("{s}:{d}: vmfill failed: %s\n", .{ @src().file, @src().line }), @tagName(@as(std.posix.E, @enumFromInt(std.c._errno().*))).ptr);
        err = true;
    }
    if (t_setrlim(.DATA, 0) == -1) {
        err = true;
    }

    if (err) {
        return -1;
    }

    while (true) {
        const ptr = std.c.malloc(1);
        if (ptr) |p| {
            std.mem.doNotOptimizeAway(p);
        } else {
            return 0;
        }
    }
}

comptime {
    if (builtin.target.isMuslLibC()) {
        @export(&t_vmfill, .{ .name = "t_vmfill" });
        @export(&t_setrlim, .{ .name = "t_setrlim" });
        @export(&t_memfill, .{ .name = "t_memfill" });
    }
}
