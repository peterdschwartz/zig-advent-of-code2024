const std = @import("std");
const help = @import("./helper.zig");
const ArrayList = std.ArrayList;
const print = std.debug.print;

const Order = struct {
    first: []const u8,
    last: []const u8,
};

const Updates = struct {
    allocator: std.mem.Allocator,
    update_map: std.StringHashMap(usize),
    valid: bool,
    num_swaps: usize,
    orders: ArrayList(Order),

    pub fn findMid(self: *Updates) ?usize {
        const N = self.update_map.count();

        const mid_idx = @divFloor(N, 2) + @mod(N, 2);
        var keys = self.update_map.keyIterator();
        const midpg = result: while (keys.next()) |pg| {
            const val = self.update_map.get(pg.*);
            if (val.? == mid_idx) {
                break :result pg.*;
            }
        } else {
            break :result null;
        };
        const res = std.fmt.parseInt(u8, midpg.?, 10) catch @panic("No middle found!");
        return res;
    }

    pub fn evaluateOrder(self: *Updates, order: Order) bool {
        const first_order = self.update_map.getPtr(order.first) orelse return true;
        const last_order = self.update_map.getPtr(order.last) orelse return true;
        const valid: bool = (first_order.* < last_order.*);

        if (!valid) {
            //Swap order of both:
            self.num_swaps += 1;
            first_order.* ^= last_order.*;
            last_order.* ^= first_order.*;
            first_order.* ^= last_order.*;
            if (self.num_swaps > 10) {
                std.debug.print("Failing {s}|{s}\n", .{ order.first, order.last });
            }
        }
        return valid;
    }

    pub fn fixOrder(self: *Updates) !void {
        while (!self.valid) {
            for (self.orders.items) |order| {
                self.valid = self.evaluateOrder(order);
                if (!self.valid) {
                    break;
                }
                if (self.num_swaps > 100) {
                    try self.print_update();
                    @panic("too many swaps");
                }
            }
        }
    }

    pub fn retrieveOrders(self: *Updates, all_orders: ArrayList(Order)) !void {
        for (all_orders.items) |ord| {
            const first_order = self.update_map.getPtr(ord.first);
            const last_order = self.update_map.getPtr(ord.last);
            if (first_order != null and last_order != null) {
                try self.orders.append(ord);
            }
        }
    }

    pub fn print_update(self: *Updates) !void {
        const N = self.update_map.count();
        const update_list = try self.allocator.alloc(usize, N);
        defer self.allocator.free(update_list);

        var keys = self.update_map.keyIterator();
        while (keys.next()) |pg| {
            const val = self.update_map.get(pg.*).? - 1;
            update_list[val] = try std.fmt.parseInt(u8, pg.*, 10);
        }
        print("Prepared Updates:\n", .{});
        for (update_list) |pg| {
            std.debug.print("{d},", .{pg});
        }
        std.debug.print("\n Orders:\n", .{});
        for (self.orders.items) |order| {
            print("{s}|{s}, ", .{ order.first, order.last });
        }
        print("\n", .{});
    }
};

pub fn main() !void {
    try parseOrders();
}

pub fn parseOrders() !void {
    const filename = "./input-files/aoc-input5.txt";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            @panic("Mem LeakF!!");
        }
    }
    const buffer = try help.read_file_to_buffer(filename, allocator);
    defer allocator.free(buffer);
    var lines = std.mem.splitAny(u8, buffer, "\n");

    var orders = try ArrayList(Order).initCapacity(allocator, 100);
    defer orders.deinit();

    var update_list = try ArrayList(Updates).initCapacity(allocator, 100);
    defer update_list.deinit();

    var update_map = std.StringHashMap(usize).init(allocator);
    defer update_map.deinit();

    var read_updates: bool = false;
    var index: usize = 0;
    while (lines.next()) |line| {
        if (line.len > 0) {
            if (read_updates) {
                var csv = std.mem.splitAny(u8, line, ",");
                index = 0;
                while (csv.next()) |val| {
                    if (val.len > 0) {
                        index += 1;
                        try update_map.put(val, index);
                    }
                }
                try update_list.append(Updates{
                    .allocator = allocator,
                    .update_map = try update_map.clone(),
                    .valid = false,
                    .num_swaps = 0,
                    .orders = ArrayList(Order).init(allocator),
                });
                update_map.clearRetainingCapacity();
            } else {
                var o = std.mem.splitAny(u8, line, "|");
                const o_first = o.next().?;
                const o_last = o.next().?;
                try orders.append(Order{ .first = o_first, .last = o_last });
            }
        } else {
            read_updates = true;
        }
    }
    // printOrders(orders);
    // printUpdate(update_list);

    for (update_list.items) |*update| {
        try update.retrieveOrders(orders);
        // try update.print_update();
    }

    var sum: usize = 0;
    var sum_fixed: usize = 0;
    for (update_list.items) |*update| {
        for (update.orders.items) |order| {
            update.valid = update.evaluateOrder(order);
            if (!update.valid) {
                break;
            }
        }
        if (update.valid) {
            const mid_pg = update.findMid();
            sum += mid_pg.?;
        } else {
            try update.fixOrder();
            const mid_pg = update.findMid();
            sum_fixed += mid_pg.?;
            try update.print_update();
            print("mid:{d}, num_swaps: {d}\n", .{ mid_pg.?, update.num_swaps });
        }
    }

    print("sum Normal/Fixed: {d}, {d}\n", .{ sum, sum_fixed });

    cleanUp(&update_list);
}

fn printOrders(orders: ArrayList(Order)) void {
    for (orders.items) |ord| {
        print("{s}|{s}\n", .{ ord.first, ord.last });
    }
}

fn printUpdate(data: ArrayList(Updates)) void {
    for (data.items) |update| {
        var keys = update.update_map.keyIterator();
        while (keys.next()) |pg| {
            const val = update.update_map.get(pg.*);
            print("{s}:{d}, ", .{ pg.*, val.? });
        }
        print("\n", .{});
    }
}

fn cleanUp(data: *ArrayList(Updates)) void {
    for (data.items) |*update| {
        update.update_map.deinit();
        update.orders.deinit();
    }
}
