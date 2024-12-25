const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const print = std.debug.print;
const help = @import("./helper.zig");
const Grid = error{
    OffGrid,
};

const Point = struct {
    row: usize,
    col: usize,
};
const Direction = enum {
    inc,
    dec,
    none,

    pub fn updateIndex(self: Direction, i: usize, N: usize) Grid!usize {
        switch (self) {
            .inc => {
                const i_ = i + 1;
                if (i_ > N - 1) {
                    return Grid.OffGrid;
                }
                return i_;
            },
            .dec => {
                if (i == 0) {
                    return Grid.OffGrid;
                }
                return i - 1;
            },
            .none => {
                return i;
            },
        }
    }
};

const CrossWord = struct {
    nrows: usize,
    ncols: usize,
    keyword: []const u8,
    count: usize,
    lines: ArrayList([]const u8),
    a_list: std.AutoHashMap(Point, usize),
    p: Point,

    pub fn find_word(self: *CrossWord) !void {
        // Start top-left and go character by character looking for "X"
        for (self.lines.items, 0..) |line, row| {
            for (line, 0..) |ch, col| {
                if (ch == self.keyword[0]) {
                    // std.debug.print("Found X at {d},{d}\n", .{ row, col });
                    try self.checkKeyword(row, col);
                }
            }
        }
    }
    pub fn print(self: *CrossWord) void {
        for (self.lines.items) |line| {
            for (line) |ch| {
                std.debug.print("{c}", .{ch});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print(" Nrows X Ncols: {d} X {d}\n", .{ self.nrows, self.ncols });
    }
    fn checkKeyword(self: *CrossWord, row: usize, col: usize) !void {
        var count: usize = 0;
        const depth: u32 = 1;

        count += try self.search(row, col, depth, Direction.dec, Direction.dec);
        // count += try self.search(row, col, depth, Direction.dec, Direction.none);
        count += try self.search(row, col, depth, Direction.dec, Direction.inc);
        // count += try self.search(row, col, depth, Direction.none, Direction.dec);
        // count += try self.search(row, col, depth, Direction.none, Direction.inc);
        count += try self.search(row, col, depth, Direction.inc, Direction.dec);
        // count += try self.search(row, col, depth, Direction.inc, Direction.none);
        count += try self.search(row, col, depth, Direction.inc, Direction.inc);

        std.debug.print("Found {d} words @ {d},{d}\n", .{ count, row, col });
        self.count += count;
        return;
    }

    fn search(
        self: *CrossWord,
        row: usize,
        col: usize,
        depth: u32,
        rowdir: Direction,
        coldir: Direction,
    ) !usize {
        if (depth > self.keyword.len - 1) {
            const gop = try self.a_list.getOrPut(self.p);
            if (gop.found_existing) {
                gop.value_ptr.* += 1;
            } else {
                gop.value_ptr.* = 1;
            }
            return 1;
        }
        const srow = rowdir.updateIndex(row, self.nrows) catch {
            return 0;
        };
        const scol = coldir.updateIndex(col, self.ncols) catch {
            return 0;
        };

        const ch = self.getChar(srow, scol);
        if (ch == self.keyword[depth]) {
            if (ch == 'A') {
                const p = Point{ .row = srow, .col = scol };
                self.p = p;
            }
            const res = try self.search(srow, scol, depth + 1, rowdir, coldir);
            return res;
        } else {
            return 0;
        }
    }

    fn getChar(self: *CrossWord, row: usize, col: usize) u8 {
        return self.lines.items[row][col];
    }

    pub fn checkIntersect(self: *CrossWord) void {
        var keys = self.a_list.keyIterator();
        var i: usize = 0;
        while (keys.next()) |p| {
            const val = self.a_list.get(p.*).?;
            if (val > 1) {
                i += 1;
                std.debug.print("{d}: {d},{d}: {d}\n", .{ i, p.row + 1, p.col + 1, val });
            }
        }
    }
};

pub fn crossword() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            @panic("Mem Leak!!");
        }
    }
    // const arena = std.heap.ArenaAllocator.init(allocator);
    // defer arena.deinit();

    const filename = "./input-files/aoc-input4.txt";

    const buffer = try help.read_file_to_buffer(filename, allocator);
    defer allocator.free(buffer);
    var lines = std.mem.splitAny(u8, buffer, "\n");
    var xword_lines = try ArrayList([]const u8).initCapacity(allocator, 200);
    defer xword_lines.deinit();

    var a_points = std.AutoHashMap(Point, usize).init(allocator);
    defer a_points.deinit();

    while (lines.next()) |line| {
        if (line.len > 0) {
            try xword_lines.append(line);
        }
    }

    const Nrows = xword_lines.items.len;
    const Ncols = xword_lines.items[0].len;

    var xword: CrossWord = CrossWord{
        .nrows = Nrows,
        .ncols = Ncols,
        .count = 0,
        .keyword = "MAS",
        .lines = xword_lines,
        .a_list = a_points,
        .p = Point{ .row = 0, .col = 0 },
    };
    defer {
        xword.a_list.deinit();
    }

    xword.print();
    try xword.find_word();
    xword.checkIntersect();
    print("{d} #XMAS\n", .{xword.count});
}
