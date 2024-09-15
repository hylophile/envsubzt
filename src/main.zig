const std = @import("std");

fn substituteEnvVars(input: []const u8, env: std.process.EnvMap, alloc: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).init(alloc);
    errdefer output.deinit();
    var start_index: usize = 0;
    while (true) {
        if (std.mem.indexOfPos(
            u8,
            input,
            start_index,
            "${",
        )) |var_ref_start| {
            const var_key_start = var_ref_start + 2;
            try output.appendSlice(input[start_index..var_ref_start]);
            if (std.mem.indexOfPos(
                u8,
                input,
                var_key_start,
                "}",
            )) |var_key_end| { // found ${var_key}
                const var_key = input[var_key_start..var_key_end];
                const var_value = env.get(var_key) orelse {
                    std.debug.print("Error: Environment variable '{s}' is not set.\n", .{var_key});
                    return error.EnvVarNotSet;
                };
                try output.appendSlice(var_value);
                start_index = var_key_end + 1;
            } else { // only found ${...
                try output.appendSlice(input[var_ref_start..var_key_start]);
                start_index = var_key_start;
            }
        } else { // remaining text
            try output.appendSlice(input[start_index..]);
            break;
        }
    }

    return output.toOwnedSlice();
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const in = std.io.getStdIn();
    var buf = std.io.bufferedReader(in.reader());
    var r = buf.reader();
    var msg_buf: [4096]u8 = undefined;
    var msg: ?[]u8 = undefined;
    var input = std.ArrayList(u8).init(allocator);
    while (true) {
        msg = try r.readUntilDelimiterOrEof(&msg_buf, '\n');

        if (msg) |m| {
            try input.appendSlice(m);
        } else {
            break;
        }
    }

    const inputSlice = try input.toOwnedSlice();
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    if (substituteEnvVars(inputSlice, env, allocator)) |result| {
        const stdout_file = std.io.getStdOut().writer();
        var bw = std.io.bufferedWriter(stdout_file);
        const stdout = bw.writer();
        try stdout.print("{s}", .{result});
        try bw.flush();
    } else |err| switch (err) {
        error.EnvVarNotSet => {
            std.process.exit(1);
        },
        else => |leftover_err| return leftover_err,
    }
}

test "success" {
    var env = std.process.EnvMap.init(std.testing.allocator);
    defer env.deinit();
    try env.put("FOO", "bar");
    try env.put("BAR", "baz");

    var result: []const u8 = undefined;

    result = try substituteEnvVars("${FOO} ${FOO} ${BAR}", env, std.testing.allocator);
    try std.testing.expectEqualSlices(u8, "bar bar baz", result);
    std.testing.allocator.free(result);

    result = try substituteEnvVars("hello", env, std.testing.allocator);
    try std.testing.expectEqualSlices(u8, "hello", result);
    std.testing.allocator.free(result);

    result = try substituteEnvVars("hello ${FOO} meow", env, std.testing.allocator);
    try std.testing.expectEqualSlices(u8, "hello bar meow", result);
    std.testing.allocator.free(result);
}

test "short name" {
    var env = std.process.EnvMap.init(std.testing.allocator);
    defer env.deinit();
    try env.put("X", "bar");
    const result = try substituteEnvVars("${X}", env, std.testing.allocator);
    try std.testing.expectEqualSlices(u8, "bar", result);
    defer std.testing.allocator.free(result);
}

test "incomplete match" {
    var env = std.process.EnvMap.init(std.testing.allocator);
    defer env.deinit();
    try env.put("FOO", "bar");
    var result: []const u8 = undefined;

    result = try substituteEnvVars("{FOO}hi {FOO} ${FOO", env, std.testing.allocator);
    try std.testing.expectEqualSlices(u8, "{FOO}hi {FOO} ${FOO", result);
    std.testing.allocator.free(result);

    result = try substituteEnvVars("${FOOhi $FOO ${FOO", env, std.testing.allocator);
    try std.testing.expectEqualSlices(u8, "${FOOhi $FOO ${FOO", result);
    std.testing.allocator.free(result);
}

test "unset env var" {
    var env = std.process.EnvMap.init(std.testing.allocator);
    defer env.deinit();
    const result = substituteEnvVars("${FOO}", env, std.testing.allocator);
    try std.testing.expectError(error.EnvVarNotSet, result);
}

test "unset env var, nesting" {
    var env = std.process.EnvMap.init(std.testing.allocator);
    defer env.deinit();
    const result = substituteEnvVars("${F${OO}", env, std.testing.allocator);
    try std.testing.expectError(error.EnvVarNotSet, result);
}
