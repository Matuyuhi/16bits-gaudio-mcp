const std = @import("std");
const server = @import("mcp/server.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    server.run(allocator) catch |err| {
        std.debug.print("16bits-audio-mcp: fatal error: {}\n", .{err});
        return err;
    };
}
