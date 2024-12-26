const std = @import("std");
const builtin = @import("builtin");

const Build = std.Build;
const CompileStep = Build.CompileStep;
const Step = Build.Step;
const Child = std.process.Child;

const assert = std.debug.assert;
const join = std.fs.path.join;
const print = std.debug.print;

// When changing this version, be sure to also update README.md in two places:
//     1) Getting Started
//     2) Version Changes
comptime {
    const required_zig = "0.14.0-dev.1573";
    const current_zig = builtin.zig_version;
    const min_zig = std.SemanticVersion.parse(required_zig) catch unreachable;
    if (current_zig.order(min_zig) == .lt) {
        const error_message =
            \\Sorry, it looks like your version of zig is too old. :-(
            \\
            \\Ziglings requires development build
            \\
            \\{}
            \\
            \\or higher.
            \\
            \\Please download a development ("master") build from
            \\
            \\https://ziglang.org/download/
            \\
            \\
        ;
        @compileError(std.fmt.comptimePrint(error_message, .{min_zig}));
    }
}

var use_color_escapes = false;
var red_text: []const u8 = "";
var red_bold_text: []const u8 = "";
var red_dim_text: []const u8 = "";
var green_text: []const u8 = "";
var bold_text: []const u8 = "";
var reset_text: []const u8 = "";

pub const AoCDay = struct {
    /// The key will be used as a shorthand to build just one example.
    main_file: []const u8,

    /// This is the desired output of the program.
    /// A program passes if its output, excluding trailing whitespace, is equal
    /// to this string.
    output: []const u8,

    /// By default, we verify output against stderr.
    /// Set this to true to check stdout instead.
    check_stdout: bool = false,

    /// This exercise makes use of C functions.
    /// We need to keep track of this, so we compile with libc.
    link_libc: bool = false,

    /// Returns the name of the main file with .zig stripped.
    pub fn name(self: AoCDay) []const u8 {
        return std.fs.path.stem(self.main_file);
    }
};

/// Build mode.
const Mode = enum {
    /// Normal build mode: `zig build`
    normal,
    /// Named build mode: `zig build -Dn=n`
    named,
    /// Random build mode: `zig build -Drandom`
    random,
};

pub const logo =
    \\    ___      _____    _____
    \\   / _ \    /  _  \  /  ___)
    \\  / /_\ \  /  / \  \ | /
    \\ / /---\ \ \  \_/  / | \___
    \\/_/     \_\ \_____/  \_____)
    \\
;
pub fn build(b: *std.Build) !void {
    if (std.io.getStdErr().supportsAnsiEscapeCodes()) {
        use_color_escapes = true;
    } else if (builtin.os.tag == .windows) {
        const w32 = struct {
            const WINAPI = std.os.windows.WINAPI;
            const DWORD = std.os.windows.DWORD;
            const ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;
            const STD_ERROR_HANDLE: DWORD = @bitCast(@as(i32, -12));
            extern "kernel32" fn GetStdHandle(id: DWORD) callconv(WINAPI) ?*anyopaque;
            extern "kernel32" fn GetConsoleMode(console: ?*anyopaque, out_mode: *DWORD) callconv(WINAPI) u32;
            extern "kernel32" fn SetConsoleMode(console: ?*anyopaque, mode: DWORD) callconv(WINAPI) u32;
        };
        const handle = w32.GetStdHandle(w32.STD_ERROR_HANDLE);
        var mode: w32.DWORD = 0;
        if (w32.GetConsoleMode(handle, &mode) != 0) {
            mode |= w32.ENABLE_VIRTUAL_TERMINAL_PROCESSING;
            use_color_escapes = w32.SetConsoleMode(handle, mode) != 0;
        }
    }
    if (use_color_escapes) {
        red_text = "\x1b[31m";
        red_bold_text = "\x1b[31;1m";
        red_dim_text = "\x1b[31;2m";
        green_text = "\x1b[32m";
        bold_text = "\x1b[1m";
        reset_text = "\x1b[0m";
    }

    // exe.addIncludePath(b.path("src/lib/"));
    // exe.linkLibC();
    b.top_level_steps = .{};
    const exno: ?usize = b.option(usize, "n", "Select exercise");
    const rand: ?bool = b.option(bool, "random", "Select random exercise");
    const compare: bool = b.option(bool, "run", "Run normally") orelse false;
    const work_path = "src";

    const header_step = PrintStep.create(b, logo);
    if (exno) |n| {
        // Named build mode: verifies a single exercise.
        if (n == 0 or n > calendar.len) {
            print("unknown exercise number: {d}\n", .{n});
            std.process.exit(2);
        }
        const ex = calendar[n - 1];

        const aoc_step = b.step(
            "AoC",
            b.fmt("Check the solution of {s}", .{ex.main_file}),
        );
        b.default_step = aoc_step;
        aoc_step.dependOn(&header_step.step);

        const verify_step = Challenge.create(b, ex, work_path, .named, compare);
        verify_step.step.dependOn(&header_step.step);

        aoc_step.dependOn(&verify_step.step);

        return;
    }

    if (rand) |_| {
        // Random build mode: verifies one random exercise.
        // like for 'exno' but chooses a random exersise number.
        print("work in progress: check a random exercise\n", .{});

        var prng = std.Random.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rnd = prng.random();
        const ex = calendar[rnd.intRangeLessThan(usize, 0, calendar.len)];

        print("random exercise: {s}\n", .{ex.main_file});

        const aoc_step = b.step(
            "random",
            b.fmt("Check the solution of {s}", .{ex.main_file}),
        );
        b.default_step = aoc_step;
        aoc_step.dependOn(&header_step.step);
        const verify_step = Challenge.create(b, ex, work_path, .random, compare);
        verify_step.step.dependOn(&header_step.step);
        aoc_step.dependOn(&verify_step.step);
        return;
    }

    // const target = b.standardTargetOptions(.{});
    // const optimize = b.standardOptimizeOption(.{});
    //
    // const exe = b.addExecutable(.{
    //     .name = "aoc",
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // b.installArtifact(exe);
    //
    // const run_cmd = b.addRunArtifact(exe);
    // run_cmd.step.dependOn(b.getInstallStep());
    // if (b.args) |args| {
    //     run_cmd.addArgs(args);
    // }
    //
    // const run_step = b.step("run", "Run the app");
    // run_step.dependOn(&run_cmd.step);
    //
    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    //
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);
}

/// Prints a message to stderr.
const PrintStep = struct {
    step: Step,
    message: []const u8,

    pub fn create(owner: *Build, message: []const u8) *PrintStep {
        const self = owner.allocator.create(PrintStep) catch @panic("OOM");
        self.* = .{
            .step = Step.init(.{
                .id = .custom,
                .name = "print",
                .owner = owner,
                .makeFn = make,
            }),
            .message = message,
        };

        return self;
    }

    fn make(step: *Step, _: Step.MakeOptions) !void {
        const self: *PrintStep = @alignCast(@fieldParentPtr("step", step));
        print("{s}", .{self.message});
    }
};

const Challenge = struct {
    step: Step,
    exercise: AoCDay,
    work_path: []const u8,
    mode: Mode,
    compare: bool,

    pub fn create(
        b: *Build,
        exercise: AoCDay,
        work_path: []const u8,
        mode: Mode,
        compare: bool,
    ) *Challenge {
        const self = b.allocator.create(Challenge) catch @panic("OOM");
        self.* = .{
            .step = Step.init(.{
                .id = .custom,
                .name = exercise.main_file,
                .owner = b,
                .makeFn = make,
            }),
            .exercise = exercise,
            .work_path = work_path,
            .mode = mode,
            .compare = compare,
        };
        return self;
    }

    fn make(step: *Step, options: Step.MakeOptions) !void {
        // NOTE: Using exit code 2 will prevent the Zig compiler to print the message:
        // "error: the following build command failed with exit code 1:..."
        const self: *Challenge = @alignCast(@fieldParentPtr("step", step));

        const exe_path = self.compile(options.progress_node) catch {
            self.printErrors();
            std.process.exit(2);
        };

        self.run(exe_path, options.progress_node) catch {
            self.printErrors();
            std.process.exit(2);
        };

        // Print possible warning/debug messages.
        self.printErrors();
    }

    fn run(self: *Challenge, exe_path: []const u8, _: std.Progress.Node) !void {
        print("Checking: {s}\n", .{self.exercise.main_file});

        const b = self.step.owner;

        // Allow up to 1 MB of stdout capture.
        const max_output_bytes = 1 * 1024 * 1024;

        const result = Child.run(.{
            .allocator = b.allocator,
            .argv = &.{exe_path},
            .cwd = b.build_root.path.?,
            .cwd_dir = b.build_root.handle,
            .max_output_bytes = max_output_bytes,
        }) catch |err| {
            return self.step.fail("unable to spawn {s}: {s}", .{
                exe_path, @errorName(err),
            });
        };

        if (self.compare) {
            return self.check_output(result);
        } else {
            return self.print_output(result);
        }
    }

    fn print_output(self: *Challenge, result: Child.RunResult) !void {
        const b = self.step.owner;

        // Make sure it exited cleanly.
        switch (result.term) {
            .Exited => |code| {
                if (code != 0) {
                    return self.step.fail("{s} exited with error code {d} (expected {})", .{
                        self.exercise.main_file, code, 0,
                    });
                }
            },
            else => {
                return self.step.fail("{s} terminated unexpectedly", .{
                    self.exercise.main_file,
                });
            },
        }

        const raw_output = if (self.exercise.check_stdout)
            result.stdout
        else
            result.stderr;

        const output = trimLines(b.allocator, raw_output) catch @panic("OOM");

        var lines = std.mem.splitAny(u8, output, "\n");
        while (lines.next()) |line| {
            print("{s}\n", .{line});
        }
        return;
    }

    fn check_output(self: *Challenge, result: Child.RunResult) !void {
        const b = self.step.owner;

        // Make sure it exited cleanly.
        switch (result.term) {
            .Exited => |code| {
                if (code != 0) {
                    return self.step.fail("{s} exited with error code {d} (expected {})", .{
                        self.exercise.main_file, code, 0,
                    });
                }
            },
            else => {
                return self.step.fail("{s} terminated unexpectedly", .{
                    self.exercise.main_file,
                });
            },
        }

        const raw_output = if (self.exercise.check_stdout)
            result.stdout
        else
            result.stderr;

        // Validate the output.
        // NOTE: exercise.output can never contain a CR character.
        // See https://ziglang.org/documentation/master/#Source-Encoding.
        const output = trimLines(b.allocator, raw_output) catch @panic("OOM");
        const exercise_output = self.exercise.output;
        var ans: []const u8 = "EMPTY";
        if (!std.mem.eql(u8, exercise_output, "")) {
            // Hold 10 lines of output for printing
            const num_lines = std.mem.count(u8, output, "\n");
            const N = @min(10, num_lines);
            print("N = {d}, num_lines = {d}\n", .{ N, num_lines });

            var line_list: [][]const u8 = try b.allocator.alloc([]const u8, N);
            defer b.allocator.free(line_list);

            var lines = std.mem.splitAny(u8, output, "\n");
            var i: usize = 0;
            var ln: usize = 0;
            while (lines.next()) |line| {
                if (line.len > 0) {
                    if (std.mem.startsWith(u8, line, "!#ANS")) {
                        ans = findAnswer(line);
                        break;
                    }
                    if (num_lines - i < N) {
                        line_list[ln] = line[0..];
                        ln += 1;
                    }
                    i += 1;
                }
            }

            if (std.mem.eql(u8, ans, "EMPTY")) {
                print("ERROR: couldn't find answer!\n", .{});
                return;
            }
            if (!std.mem.eql(u8, ans, exercise_output)) {
                const red = red_bold_text;
                const reset = reset_text;
                print("====== output =======\n", .{});
                print("ans: {s}\n", .{ans});
                for (line_list) |line| {
                    print("{s}\n", .{line});
                }

                // Override the coloring applied by the printError method.
                // NOTE: the first red and the last reset are not necessary, they
                // are here only for alignment.
                return self.step.fail(
                    \\
                    \\{s}========= expected this output: =========={s}
                    \\{s}
                    \\{s}========= but found: ====================={s}
                    \\{s}
                    \\{s}=========================================={s}
                , .{ red, reset, exercise_output, red, reset, ans, red, reset });
            }

            print("{s}PASSED:\n{s}{s}\n\n", .{ green_text, ans, reset_text });
        }
    }

    fn check_test(self: *Challenge, result: Child.RunResult) !void {
        switch (result.term) {
            .Exited => |code| {
                if (code != 0) {
                    // The test failed.
                    const stderr = std.mem.trimRight(u8, result.stderr, " \r\n");

                    return self.step.fail("\n{s}", .{stderr});
                }
            },
            else => {
                return self.step.fail("{s} terminated unexpectedly", .{
                    self.exercise.main_file,
                });
            },
        }

        print("{s}PASSED{s}\n\n", .{ green_text, reset_text });
    }

    fn compile(self: *Challenge, prog_node: std.Progress.Node) ![]const u8 {
        print("Compiling: {s}\n", .{self.exercise.main_file});

        const b = self.step.owner;
        const exercise_path = self.exercise.main_file;
        const path = join(b.allocator, &.{ self.work_path, exercise_path }) catch
            @panic("OOM");

        var zig_args = std.ArrayList([]const u8).init(b.allocator);
        defer zig_args.deinit();

        zig_args.append(b.graph.zig_exe) catch @panic("OOM");

        // const cmd = switch (self.exercise.kind) {
        //     .exe => "build-exe",
        //     .@"test" => "test",
        // };
        const cmd = "build-exe";
        zig_args.append(cmd) catch @panic("OOM");

        // Enable C support for exercises that use C functions.
        if (self.exercise.link_libc) {
            zig_args.append("-lc") catch @panic("OOM");
        }

        zig_args.append(b.pathFromRoot(path)) catch @panic("OOM");

        zig_args.append("--cache-dir") catch @panic("OOM");
        zig_args.append(b.pathFromRoot(b.cache_root.path.?)) catch @panic("OOM");

        zig_args.append("--listen=-") catch @panic("OOM");

        //
        // NOTE: After many changes in zig build system, we need to create the cache path manually.
        // See https://github.com/ziglang/zig/pull/21115
        // Maybe there is a better way (in the future).
        const exe_dir = try self.step.evalZigProcess(zig_args.items, prog_node, false);
        // const exe_name = switch (self.exercise.kind) {
        //     .exe => self.exercise.name(),
        //     .@"test" => "test",
        // };
        const exe_name = self.exercise.name();
        const sep = std.fs.path.sep_str;
        const root_path = exe_dir.?.root_dir.path.?;
        const sub_path = exe_dir.?.subPathOrDot();
        const exe_path = b.fmt("{s}{s}{s}{s}{s}", .{ root_path, sep, sub_path, sep, exe_name });
        print("Exe path {s}\n", .{exe_path});

        return exe_path;
    }

    fn printErrors(self: *Challenge) void {

        // Display error/warning messages.
        if (self.step.result_error_msgs.items.len > 0) {
            for (self.step.result_error_msgs.items) |msg| {
                print("{s}error: {s}{s}{s}{s}\n", .{
                    red_bold_text, reset_text, red_dim_text, msg, reset_text,
                });
            }
        }

        // Render compile errors at the bottom of the terminal.
        // TODO: use the same ttyconf from the builder.
        const ttyconf: std.io.tty.Config = if (use_color_escapes)
            .escape_codes
        else
            .no_color;
        if (self.step.result_error_bundle.errorMessageCount() > 0) {
            self.step.result_error_bundle.renderToStdErr(.{ .ttyconf = ttyconf });
        }
    }
};

const calendar = [_]AoCDay{
    .{
        .main_file = "day1.zig",
        .output = "",
    },
    .{
        .main_file = "SafetyRecords.zig",
        .output = "700",
    },
    .{
        .main_file = "parse.zig",
        .output = "90044227",
    },
    .{
        .main_file = "crossword.zig",
        .output = "1948",
    },
    .{
        .main_file = "orders.zig",
        .output = "4719",
    },
    .{
        .main_file = "patrol.zig",
        .output = "1705",
    },
    .{
        .main_file = "ops.zig",
        .output = "1026766857276279",
    },
    .{
        .main_file = "antinodes.zig",
        .output = "?",
    },
};

/// Removes trailing whitespace for each line in buf, also ensuring that there
/// are no trailing LF characters at the end.
pub fn trimLines(allocator: std.mem.Allocator, buf: []const u8) ![]const u8 {
    var list = try std.ArrayList(u8).initCapacity(allocator, buf.len);

    var iter = std.mem.splitSequence(u8, buf, " \n");
    while (iter.next()) |line| {
        // TODO: trimming CR characters is probably not necessary.
        const data = std.mem.trimRight(u8, line, " \r");
        try list.appendSlice(data);
        try list.append('\n');
    }

    const result = try list.toOwnedSlice(); // TODO: probably not necessary

    // Remove the trailing LF character, that is always present in the exercise
    // output.
    return std.mem.trimRight(u8, result, "\n");
}

fn findAnswer(line: []const u8) []const u8 {
    const idx = std.mem.indexOfScalar(u8, line, ':').?;
    const ans: []const u8 = line[idx + 1 ..];
    return std.mem.trim(u8, ans, " ");
}
