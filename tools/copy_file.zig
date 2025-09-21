const std = @import("std");

pub fn main() !void {
    var it = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer it.deinit();

    _ = it.next();
    const in_path = it.next().?;
    const out_path = it.next().?;

    const in_file = try std.fs.cwd().openFile(in_path, .{});
    defer in_file.close();

    const out_file = try std.fs.cwd().createFile(out_path, .{});
    defer out_file.close();

    var buffer: [512]u8 = undefined;
    while (true) {
        const read = try in_file.read(&buffer);
        if (read == 0) break;
        const written = try out_file.write(buffer[0..read]);
        std.debug.assert(read == written);
    }
}
