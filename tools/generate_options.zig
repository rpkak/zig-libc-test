const std = @import("std");

pub fn main() !void {
    var it = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer it.deinit();

    _ = it.next();
    const in_path = it.next().?;
    const out_path = it.next().?;
    const out_name = it.next().?;

    const in_file = try std.fs.cwd().openFile(in_path, .{});
    defer in_file.close();

    var out_dir = try std.fs.cwd().openDir(out_path, .{});
    defer out_dir.close();

    const out_file = try out_dir.createFile(out_name, .{});
    defer out_file.close();

    var line_buf: [512]u8 = undefined;
    var file_reader = in_file.reader(&line_buf);
    var reader = &file_reader.interface;

    var found_unistd_end = false;

    while (true) {
        const line = reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
            error.EndOfStream => break,
            error.ReadFailed => return error.ReadFailed,
            error.StreamTooLong => {
                // Skip lines that are too long
                _ = reader.discardDelimiterInclusive('\n') catch |e| switch (e) {
                    error.EndOfStream => break,
                    error.ReadFailed => return error.ReadFailed,
                };
                continue;
            },
        };

        if (std.mem.eql(u8, line, "optiongroups_unistd_end")) {
            found_unistd_end = true;
            continue;
        }

        if (!found_unistd_end or line.len == 0 or line[0] == '#')
            continue;

        try out_file.writeAll("#define ");
        try out_file.writeAll(line);
        try out_file.writeAll("\n");
    }
}
