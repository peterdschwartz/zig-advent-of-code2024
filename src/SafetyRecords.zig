const std = @import("std");
const helper = @import("./helper.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const print = std.debug.print;
const SafetyError = error{UnsafeError};
const TOLERANCE = 1;
const IncDec = enum { inc, dec };
const Record = struct {
    safe: bool,
    mode: ?IncDec,
    cur: usize,
    peek: usize,
    strikes: u32,
    data: []i32,
    allocator: Allocator,

    pub fn checkMode(self: *Record) void {
        const N: usize = self.data.len;
        self.safe = self.checkSafety(N);
        var lvl: usize = 0;

        while (!self.safe and lvl < N) {
            self.safe = self.checkRemoval(lvl);
            lvl += 1;
        }
        return;
    }

    fn checkSafety(self: *Record, N: usize) bool {
        if (N == 1) {
            self.safe = true;
            self.mode = IncDec.inc;
            return true;
        }
        self.peek = 1;
        while (self.peek < N) : (self.peek += 1) {
            self.cur = self.peek - 1;
            self.mode = self.compare() catch {
                return false;
            };
        }
        return true;
    }

    fn checkRemoval(self: *Record, idx: usize) bool {
        // create temp record with current removed:
        var data_temp = self.allocator.alloc(i32, self.data.len - 1) catch {
            @panic("Couldn't allocate temp data array");
        };
        defer self.allocator.free(data_temp);

        // self.remove_idx(idx, &data_temp);
        var new_idx: usize = 0;
        for (self.data, 0..) |item, old_index| {
            if (old_index != idx) {
                data_temp[new_idx] = item;
                new_idx += 1;
            }
        }
        var level_removed = Record{
            .data = data_temp,
            .mode = null,
            .cur = 0,
            .peek = 0,
            .safe = false,
            .strikes = 0,
            .allocator = self.allocator,
        };
        const N = data_temp.len;
        const safe_now = level_removed.checkSafety(N);
        if (safe_now) {
            self.mode = level_removed.mode;
        }

        return safe_now;
    }
    fn remove_idx(self: *Record, idx: usize, pruned: []i32) void {
        var new_i: usize = 0;
        var i: usize = 0;
        while (i < self.data.len) : (i += 1) {
            if (i != idx) {
                pruned[new_i] = self.data[i];
                new_i += 1;
            }
        }
        return;
    }

    fn compare(self: *Record) SafetyError!?IncDec {
        const cur0: i32 = self.data[self.cur];
        const peek0: i32 = self.data[self.peek];
        var mode: ?IncDec = undefined;
        const toolarge: bool = (@abs(cur0 - peek0) > 3);
        if (cur0 == peek0 or toolarge) {
            // Unsafe?
            self.strikes += 1;
            return SafetyError.UnsafeError;
        } else if (cur0 < peek0) {
            mode = IncDec.inc;
        } else {
            mode = IncDec.dec;
        }
        if (self.mode == null) {
            return mode;
        }
        if (self.mode.? != mode) {
            self.strikes += 1;
            return SafetyError.UnsafeError;
        } else {
            return mode;
        }
    }

    pub fn print_record(self: *Record) void {
        print("Record data {any} :: ", .{self.data});
        if (self.safe) {
            switch (self.mode.?) {
                .inc => print("Increasing!\n", .{}),
                .dec => print("Decreasing!\n", .{}),
            }
        } else {
            print("UNSAFE!!\n", .{});
        }
    }
};

pub fn main() !void {
    try safety_records();
}

pub fn safety_records() !void {
    // AoC day 2
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            @panic("Mem Leak!!");
        }
    }
    print("SAFETY RECORDS\n", .{});
    // const filename: []const u8 = "input-files/aoc-test.txt";
    const filename: []const u8 = "input-files/aoc-input2.txt";
    const buffer = try helper.read_file_to_buffer(filename, allocator);
    defer allocator.free(buffer);

    var lines = std.mem.splitAny(u8, buffer, "\n");
    var record_list = try ArrayList(Record).initCapacity(allocator, 1000);
    defer record_list.deinit();
    var sum: i32 = 0;

    while (lines.next()) |line| {
        if (line.len > 0) {
            var num_it = std.mem.splitAny(u8, line, " ");
            var data = ArrayList(i32).init(allocator);
            defer data.deinit();
            while (num_it.next()) |number| {
                if (number.len > 0) {
                    const val = try std.fmt.parseInt(i32, number, 10);
                    try data.append(val);
                }
            }
            var record = Record{
                .data = data.items,
                .mode = null,
                .cur = 0,
                .peek = 0,
                .safe = false,
                .strikes = 0,
                .allocator = allocator,
            };
            record.checkMode();
            if (record.safe) {
                sum += 1;
                record.print_record();
            }

            try record_list.append(record);
        }
    }
    print("!#ANS Number of Records : {d}\n", .{sum});
}
