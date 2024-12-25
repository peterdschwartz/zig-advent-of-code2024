const std = @import("std");
const help = @import("./helper.zig");
const print = std.debug.print;

const Point = struct {
    x: usize,
    y: usize,
};

pub fn main() !void {
    try antinodes();
}
pub fn antinodes() !void {
    const filename = "./input-files/aoc-test8.txt";
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();
    // defer {
    //     const gpa_status = gpa.deinit();
    //     if (gpa_status == .leak) {
    //         @panic("Memory Leak!");
    //     }
    // }

    const buffer = try help.read_file_to_buffer(filename, allocator);
    defer allocator.free(buffer);

    const num_rows = std.mem.count(u8, buffer, "\n");
    const num_cols = buffer.len / num_rows - 1;

    var antenna = std.AutoHashMap(u8, std.ArrayList(Point)).init(allocator);
    defer antenna.deinit();

    var temp_list = std.ArrayList(Point).init(allocator);
    defer temp_list.deinit();

    var grid: [][]u8 = try allocator.alloc([]u8, num_rows);
    for (grid) |*row| {
        row.* = try allocator.alloc(u8, num_cols);
    }

    var lines = std.mem.splitAny(u8, buffer, "\n");
    var i: usize = 0;
    while (lines.next()) |row| {
        if (row.len > 0) {
            if (row.len != num_cols) {
                print("Error: Wrong number of columns {d} != {d}\n", .{ row.len, num_cols });
                break;
            }
            for (0..num_cols) |j| {
                const ch = row[j];
                grid[i][j] = ch;
                if (ch != '.') {
                    const gop = try antenna.getOrPut(ch);
                    if (gop.found_existing) {
                        try gop.value_ptr.*.append(Point{ .x = i, .y = j });
                    } else {
                        gop.value_ptr.* = try temp_list.clone();
                        try gop.value_ptr.*.append(Point{ .x = i, .y = j });
                    }
                }
            }
            i += 1;
        }
    }

    var iter = antenna.iterator();
    while (iter.next()) |it| {
        print("{c} -> ", .{it.key_ptr.*});
        for (it.value_ptr.*.items) |pt| {
            print("({d},{d})", .{ pt.x, pt.y });
        }
        print("\n", .{});
    }

    //freeMatrix(grid, allocator);
}

fn freeMatrix(mat: [][]u8, alloc: std.mem.Allocator) void {
    for (mat) |*row| {
        alloc.free(row.*);
    }
    alloc.free(mat);
    return;
}
