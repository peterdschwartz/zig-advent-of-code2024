const std = @import("std");
pub fn read_file_to_buffer(filename: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // read file into buffer.
    const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();

    const stat = try file.stat();
    const buffer = try file.readToEndAlloc(allocator, stat.size);

    return buffer;
}
