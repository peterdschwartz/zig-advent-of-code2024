const std = @import("std");
const helper = @import("./helper.zig");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// const TOKENS = enum {
//     number,
//     ident,
//     rparen,
//     comma,
// };
// var Token = std.StringHashMap(TOKENS){};
const Pair = struct {
    a: i32,
    b: i32,
};

pub fn parseMultiply() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const filename: []const u8 = "./input-files/aoc-input3.txt";
    const buffer = try helper.read_file_to_buffer(filename, allocator);

    // var lines = std.mem.splitAny(u8, buffer, "\n");
    var lines = std.mem.tokenizeSequence(u8, buffer, "do");
    var sum: i32 = 0;

    const first = lines.next();
    sum += try checkMul(first.?, false);

    while (lines.next()) |line| {
        if (line.len > 0) {
            sum += try checkMul(line, true);
        }
    }

    print("Sum: {d}\n", .{sum});
}

fn parseToken(token: []const u8) !Pair {
    var test_split = std.mem.tokenizeSequence(u8, token, ")");
    const t = test_split.next() orelse return Pair{ .a = 0, .b = 0 };
    var comma: usize = 0;
    for (t) |ch| {
        const isNum = std.ascii.isDigit(ch);
        if (!isNum) {
            if (ch == ',') {
                comma += 1;
            } else {
                return Pair{ .a = 0, .b = 0 };
            }
        }
    }
    if (comma != 1) {
        return Pair{ .a = 0, .b = 0 };
    }
    // Valid Pair:
    var pair_it = std.mem.tokenizeSequence(u8, t, ",");
    const a: i32 = try std.fmt.parseInt(i32, pair_it.next().?, 10);
    const b: i32 = try std.fmt.parseInt(i32, pair_it.next().?, 10);
    if (pair_it.next()) |err| {
        print("Error: {s} too many commas -- {s}\n", .{ err, t });
    }
    return Pair{ .a = a, .b = b };
}

fn checkMul(line: []const u8, check: bool) !i32 {
    if (check) {
        const op = "()";
        const do = std.mem.eql(u8, line[0..2], op);
        if (!do) {
            print("Inactive: {s}\n", .{line});
            return 0;
        }
    }
    print("active line: {s}\n", .{line});
    var tokens = std.mem.tokenizeSequence(u8, line, "mul(");
    var sum: i32 = 0;
    while (tokens.next()) |token| {
        if (token.len > 0) {
            const xy = try parseToken(token);
            // print("Adding: {d}*{d} from {s}\n", .{ xy.a, xy.b, token });
            sum += xy.a * xy.b;
        }
    }
    return sum;
}
