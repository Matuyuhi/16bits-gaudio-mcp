const std = @import("std");
const mcp = @import("zig-mcp-sdk");
const tools = @import("tools.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    mcp.run(allocator, .{
        .name = "16bits-audio-mcp",
        .version = "0.6.0",
        .tools_list_json = tools.tools_list_json,
        .tool_handler = &tools.executeTool,
    }) catch |err| {
        std.debug.print("16bits-audio-mcp: fatal error: {}\n", .{err});
        return err;
    };
}
