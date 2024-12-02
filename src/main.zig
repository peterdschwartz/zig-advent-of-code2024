//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");

const ArrayList = std.ArrayList;

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            @panic("Mem LeakF!!");
        }
    }

    const cwd = std.fs.cwd();
    std.debug.print("Current Working Directory is {}", .{cwd});
    const file = try std.fs.cwd().openFile("./input-files/aoc-input1.txt", .{ .mode = .read_only });
    defer file.close();

    const stat = try file.stat();
    const buffer = try file.readToEndAlloc(allocator, stat.size);
    defer allocator.free(buffer);

    var numbers_list = try ArrayList(i32).initCapacity(allocator, 2000);

    var list1 = try ArrayList(i32).initCapacity(allocator, 1000);
    var list2 = try ArrayList(i32).initCapacity(allocator, 1000);
    defer {
        numbers_list.deinit();
        list1.deinit();
        list2.deinit();
    }

    //var lines = std.mem.splitAny(u8, buffer, "\n");
    var numbers = std.mem.splitAny(u8, buffer, " \n");
    var sum: u32 = 0;
    while (numbers.next()) |n| {
        if (n.len > 0) {
            sum += 1;
            const num = try std.fmt.parseInt(i32, n, 10);
            try numbers_list.append(num);
        }
    }
    std.debug.print("Total number of numbers:{d}\n", .{sum});

    const nrows = sum / 2;

    for (0..nrows) |i| {
        const index = 2 * i;
        try list1.append(numbers_list.items[index]);
        try list2.append(numbers_list.items[index + 1]);
    }

    std.mem.sort(i32, list1.items, {}, comptime std.sort.asc(i32));
    std.mem.sort(i32, list2.items, {}, comptime std.sort.asc(i32));

    var diff: i32 = 0;
    for (0..nrows) |i| {
        // std.debug.print("row {d}: {d}, {d}\n", .{ i, list1.items[i], list2.items[i] });
        const idx: usize = @intCast(i);
        const diff_val = @abs(list1.items[idx] - list2.items[idx]);
        const d: i32 = @intCast(diff_val);
        diff += d;
    }

    std.debug.print("Total difference is {d}!\n", .{diff});

    var li2_ids = std.AutoHashMap(i32, i32).init(allocator);
    defer li2_ids.deinit();

    for (list2.items) |id| {
        const gop = try li2_ids.getOrPut(id);
        if (gop.found_existing) {
            gop.value_ptr.* += 1;
        } else {
            gop.value_ptr.* = 1;
        }
    }

    const lookup: i32 = 62605;
    std.debug.print("{d} is in list2 {d} times\n", .{ lookup, li2_ids.get(lookup).? });

    var sim_score: i32 = 0;

    for (list1.items) |id| {
        const ntimes_li2 = li2_ids.get(id) orelse 0;
        sim_score += id * ntimes_li2;
    }

    std.debug.print("Similarity Score is: {d}\n", .{sim_score});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const global = struct {
        fn testOne(input: []const u8) anyerror!void {
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(global.testOne, .{});
}
