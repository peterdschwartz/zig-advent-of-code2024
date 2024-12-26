const std = @import("std");
const help = @import("./helper.zig");

const Kind = enum { blocked, empty, path, loc };

const Point = struct {
    x: usize,
    y: usize,
};
const Dir = enum { up, down, left, right };

const Path = struct {
    loc: Point,
    dir: Dir,
};

const IncDec = enum { inc, dec };
const PatrolError = error{ MapInit, NoLoop };
const Grid = struct {
    offgrid: bool,
    move: Dir,
    Nrow: usize,
    Ncol: usize,
    guard_loc: Point,
    grid: []Kind,
    buffer: []u8,
    dup_grid: []Kind,
    guard_start: Path,

    pub fn printGrid(self: *Grid) !void {
        var num_points: usize = 0;
        for (0..self.Nrow) |i| {
            for (0..self.Ncol) |j| {
                const bloc = i * (self.Ncol + 1) + j;
                const loc = i * self.Ncol + j;
                if (self.isGuard(i, j)) {
                    self.buffer[bloc] = guardDirection(self.move);
                } else {
                    switch (self.grid[loc]) {
                        .empty => self.buffer[bloc] = '.',
                        .blocked => self.buffer[bloc] = '#',
                        .path => {
                            num_points += 1;
                            self.buffer[bloc] = 'X';
                        },
                        .loc => {
                            num_points += 1;
                            self.buffer[bloc] = guardDirection(self.move);
                        },
                    }
                }
            }
        }

        std.debug.print("{s}\n", .{self.buffer});
        std.debug.print("Number of points traveled: {d}\n", .{num_points});
    }

    fn isGuard(self: *Grid, i: usize, j: usize) bool {
        return (self.guard_loc.x == i and self.guard_loc.y == j);
    }

    pub fn patrol(self: *Grid, path_map: *std.AutoHashMap(Path, bool)) !bool {
        var loc = self.guard_loc.x * self.Ncol + self.guard_loc.y;
        var next_loc = loc;

        self.grid[loc] = Kind.path;
        const start_point = Path{ .loc = self.convertLocationToGrid(loc), .dir = self.move };
        const gop0 = try path_map.*.getOrPut(start_point);
        if (gop0.found_existing) {
            std.debug.print("Error: Map is non-empty!\n", .{});
            return PatrolError.MapInit;
        } else {
            gop0.value_ptr.* = false;
        }

        while (!self.offgrid) {
            loc = self.guard_loc.x * self.Ncol + self.guard_loc.y;
            next_loc = self.checkOffGrid(loc);
            if (self.offgrid) {
                break;
            }

            var path_point: ?Path = null;

            switch (self.grid[next_loc]) {
                .blocked => {
                    self.rotateGuard();
                    next_loc = loc;
                },
                .path => {
                    // Already have crosse this point
                    self.moveGuard();
                    self.grid[loc] = Kind.path;
                    path_point = Path{ .loc = self.convertLocationToGrid(next_loc), .dir = self.move };
                },
                .empty => {
                    // std.debug.print("Guard Location: {d},{d}\n", .{ self.guard_loc.x, self.guard_loc.y });
                    self.moveGuard();
                    self.grid[loc] = Kind.path;
                    path_point = Path{ .loc = self.convertLocationToGrid(next_loc), .dir = self.move };
                },
                .loc => {
                    @panic("hmmm?");
                },
            }

            // if path_point is not NULL, then add it to the map
            if (path_point) |pt| {
                const gop = try path_map.*.getOrPut(pt);
                if (gop.found_existing) {
                    // Found a Loop
                    std.debug.print("Found Loop!\n", .{});
                    gop.value_ptr.* = true;
                    return true;
                } else {
                    gop.value_ptr.* = false;
                }
            }
        }
        return false;
    }

    fn checkOffGrid(self: *Grid, loc: usize) usize {
        const xy = self.convertLocationToGrid(loc);
        switch (self.move) {
            .up => {
                if (xy.x == 0) {
                    self.offgrid = true;
                    return loc;
                } else {
                    return loc - self.Ncol;
                }
            },
            .down => {
                if (xy.x == self.Nrow - 1) {
                    self.offgrid = true;
                    return loc;
                } else {
                    return loc + self.Ncol;
                }
            },
            .right => {
                if (xy.y == self.Ncol - 1) {
                    self.offgrid = true;
                    return loc;
                } else {
                    return loc + 1;
                }
            },
            .left => {
                if (xy.y == 0) {
                    self.offgrid = true;
                    return loc;
                } else {
                    return loc - 1;
                }
            },
        }
    }

    fn moveGuard(self: *Grid) void {
        switch (self.move) {
            .up => {
                self.offgrid = updateLocation(&self.guard_loc.x, 0, IncDec.dec);
            },
            .down => {
                self.offgrid = updateLocation(&self.guard_loc.x, self.Nrow, IncDec.inc);
            },
            .left => {
                self.offgrid = updateLocation(&self.guard_loc.y, 0, IncDec.dec);
            },
            .right => {
                self.offgrid = updateLocation(&self.guard_loc.y, self.Ncol, IncDec.inc);
            },
        }
    }

    fn convertLocationToGrid(self: *Grid, loc: usize) Point {
        const i = @divFloor(loc, self.Ncol);
        const j = @mod(loc, self.Ncol);

        return Point{ .x = i, .y = j };
    }
    fn rotateGuard(self: *Grid) void {
        switch (self.move) {
            .up => self.move = Dir.right,
            .right => self.move = Dir.down,
            .down => self.move = Dir.left,
            .left => self.move = Dir.up,
        }
        // std.debug.print("rotate -> {s}\n", .{@tagName(self.move)});
        return;
    }

    pub fn addObstruction(self: *Grid, pt: Point) void {
        const loc = pt.x * self.Ncol + pt.y;
        for (self.dup_grid, 0..) |g, i| {
            self.grid[i] = g;
        }
        self.grid[loc] = Kind.blocked;
        self.guard_loc = self.guard_start.loc;
        self.move = self.guard_start.dir;
        self.offgrid = false;
        return;
    }
};

fn guardDirection(move: Dir) u8 {
    switch (move) {
        .up => return '^',
        .down => return 'v',
        .left => return '<',
        .right => return '>',
    }
}

fn updateLocation(indx: *usize, bound: usize, mode: IncDec) bool {
    switch (mode) {
        .dec => {
            indx.* -= 1;
            return (indx.* < bound);
        },
        .inc => {
            indx.* += 1;
            return (indx.* > bound);
        },
    }
}

pub fn main() !void {
    try patrolPoints();
}

pub fn patrolPoints() !void {
    const filename = "./input-files/aoc-test6.txt";
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

    const num_rows = std.mem.count(u8, buffer, "\n");
    const num_cols = buffer.len / num_rows - 1;
    var lines = std.mem.splitAny(u8, buffer, "\n");
    std.debug.print("rows x cols: {d} x {d}\n", .{ num_rows, num_cols });
    var grid: []Kind = try allocator.alloc(Kind, num_rows * num_cols);
    var dup_grid: []Kind = try allocator.alloc(Kind, num_rows * num_cols);
    defer {
        allocator.free(grid);
        allocator.free(dup_grid);
    }

    // Use HashMap to hold patrol locations
    var path_map = std.AutoHashMap(Path, bool).init(allocator);
    defer path_map.deinit();

    var i: usize = 0;
    var guard_start = Point{ .x = undefined, .y = undefined };
    while (lines.next()) |line| {
        if (line.len > 0) {
            for (0..num_cols) |j| {
                const loc = i * num_cols + j;
                switch (line[j]) {
                    '.' => grid[loc] = Kind.empty,
                    '#' => grid[loc] = Kind.blocked,
                    '^' => {
                        guard_start.x = i;
                        guard_start.y = j;
                        grid[loc] = Kind.loc;
                    },
                    else => unreachable,
                }
                dup_grid[loc] = grid[loc];
            }
            i += 1;
        }
    }
    var layout = Grid{
        .Nrow = num_rows,
        .Ncol = num_cols,
        .guard_loc = Point{ .x = guard_start.x, .y = guard_start.y },
        .grid = grid[0..],
        .buffer = buffer[0..],
        .move = Dir.up,
        .offgrid = false,
        .dup_grid = dup_grid[0..],
        .guard_start = Path{ .loc = guard_start, .dir = Dir.up },
    };
    _ = try layout.patrol(&path_map);

    // Take the path_map and extract only the Points
    var loop_points = std.AutoHashMap(Point, bool).init(allocator);
    defer loop_points.deinit();

    var keys = path_map.keyIterator();
    while (keys.next()) |key| {
        const gop = try loop_points.getOrPut(key.*.loc);
        if (!gop.found_existing) {
            gop.value_ptr.* = false;
        }
    }

    std.debug.print("Finding Loops\n", .{});
    try findLoops(&layout, &loop_points, allocator);
    print_path(loop_points);
}

fn print_path(path_map: std.AutoHashMap(Point, bool)) void {
    var keys = path_map.keyIterator();
    var num_loops: usize = 0;
    std.debug.print("Number of Points in Map {d}\n", .{path_map.count()});
    while (keys.next()) |key| {
        const value = path_map.get(key.*);
        if (value.?) {
            std.debug.print("P: {d},{d} loop:{any}\n", .{ key.*.x, key.*.y, value.? });
            num_loops += 1;
        }
    }
    std.debug.print("!#ANS Potential Loops: {d}\n", .{num_loops});
}

fn findLoops(
    layout: *Grid,
    path_map: *std.AutoHashMap(Point, bool),
    allocator: std.mem.Allocator,
) !void {
    // Function goes through the patrol map
    // and adds an obstruction to each point to see if it causes a loop
    var temp_map = std.AutoHashMap(Path, bool).init(allocator);
    defer temp_map.deinit();

    var path_pts = path_map.*.keyIterator();
    while (path_pts.next()) |pt| {
        layout.*.addObstruction(pt.*);
        const loop = try layout.*.patrol(&temp_map);
        if (loop) {
            const value = path_map.*.getPtr(pt.*).?;
            value.* = true;
            try layout.*.printGrid();
        }
        temp_map.clearRetainingCapacity();
    }
}
