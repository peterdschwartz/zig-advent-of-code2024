const std = @import("std");
const help = @import("./helper.zig");
const print = std.debug.print;

const Operations = enum { add, mul, concat };

const Calibration = struct {
    answer: i64,
    numbers: [20]i64,
    length: usize,
    ops: []Operations,
    valid: bool,
    alloc: std.mem.Allocator,

    pub fn calibrate(self: *Calibration) !bool {
        const N = self.length;
        self.ops = try self.alloc.alloc(Operations, N - 1);
        // Doesn't seem to work with enums at least.
        // @memset(&ops_arr[0..], Operations.add);

        // for (0..N - 1) |i| {
        //     self.ops[i] = Operations.add;
        // }
        // There are 2^(N-1) possible combinations
        const num_ops: u32 = @as(u32, @intCast(N - 1));
        const MAX_ITERS: u32 = std.math.pow(u32, 3, num_ops); // @as(u32, @intCast(1)) << num_ops;
        var iter: u32 = 0;

        while (iter < MAX_ITERS) : (iter += 1) {
            self.changeOps(iter);
            self.validate();
            if (self.valid) {
                break;
            }
        }

        return self.valid;
    }

    fn changeOps(self: *Calibration, iter: u32) void {
        // Function to validate new combination of operations.
        // NOTE: start with all adds (all zeros), end with all multiplies (all ones)
        const choices: [3]Operations = .{ Operations.add, Operations.mul, Operations.concat };
        const num_ops = self.ops.len;
        for (0..num_ops) |j| {
            // bit shift stuff --- no longer used!:
            //iter: 0  (0>>0)&1->0, (0>>1)&1 -> 0, etc..
            //iter: 1  (1>>0)&1->1, (1>>1)&1->0, (1>>2)&1->0
            //iter: 7  111: (7>>2)&1->1
            //
            //const op_idx = (iter >> @as(u5, @intCast(j))) & 1;
            const op_idx = (iter / std.math.pow(u32, 3, @as(u32, @intCast(j)))) % 3;
            self.ops[j] = choices[op_idx];
        }
        return;
    }

    pub fn cleanUp(self: *Calibration) void {
        self.alloc.free(self.ops);
    }
    fn validate(self: *Calibration) void {
        var result: i64 = self.numbers[0];
        for (1..self.length) |i| {
            switch (self.ops[i - 1]) {
                .add => result += self.numbers[i],
                .mul => result *= self.numbers[i],
                .concat => {
                    const num_digits = countDigits(self.numbers[i]);
                    result = result * std.math.pow(i64, 10, num_digits) + self.numbers[i];
                },
            }
        }
        if (result == self.answer) {
            self.valid = true;
        } else {
            self.valid = false;
        }
        return;
    }
};

pub fn main() !void {
    try ops();
}

pub fn ops() !void {
    const filename = "./input-files/aoc-input7.txt";
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const gpa_status = gpa.deinit();
        if (gpa_status == .leak) {
            @panic("Memory Leak!");
        }
    }

    const buffer = try help.read_file_to_buffer(filename, allocator);
    defer allocator.free(buffer);

    var calibs = try std.ArrayList(Calibration).initCapacity(allocator, 100);
    defer calibs.deinit();

    var lines = std.mem.splitAny(u8, buffer, "\n");
    var length: usize = 0;
    var numbers: [20]i64 = undefined;
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        var temp = std.mem.splitAny(u8, line, ":");
        const ans_str = temp.next().?;
        print("parsing: {s}\n", .{ans_str});
        const ans = try std.fmt.parseInt(i64, ans_str, 10);

        const num_list = temp.next().?;

        print("num_list: {s}\n", .{num_list});
        var nums = std.mem.splitAny(u8, num_list, " ");
        length = 0;
        @memset(&numbers, 0);
        while (nums.next()) |num| {
            if (num.len > 0) {
                length += 1;
                numbers[length - 1] = try std.fmt.parseInt(i64, num, 10);
            }
        }
        try calibs.append(Calibration{
            .length = length,
            .numbers = numbers,
            .answer = ans,
            .ops = undefined,
            .valid = false,
            .alloc = allocator,
        });
    }
    printCalibrations(calibs);

    try testCalibrations(&calibs);
    for (calibs.items) |*calib| {
        calib.cleanUp();
    }
}

fn printCalibrations(calibs: std.ArrayList(Calibration)) void {
    for (calibs.items) |calib| {
        print("{d}: ", .{calib.answer});
        for (0..calib.length) |i| {
            print("{d} ", .{calib.numbers[i]});
        }
        print("\n", .{});
    }
}

fn testCalibrations(calibs: *std.ArrayList(Calibration)) !void {
    var sum: i64 = 0;
    for (calibs.items) |*calib| {
        const valid = try calib.calibrate();
        if (valid) {
            sum += calib.*.answer;
        }
    }
    print("Summ of Valid Answers: {d}\n", .{sum});
}

fn countDigits(arg1: i64) i64 {
    if (arg1 == 0) {
        return 1;
    }

    var temp = arg1;
    var num: i64 = 0;
    while (temp != 0) {
        temp = @divFloor(temp, 10);
        num += 1;
    }
    return num;
}
