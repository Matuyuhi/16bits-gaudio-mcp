const std = @import("std");
const protocol = @import("protocol.zig");
const tools = @import("tools.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const stdin_file = std.fs.File.stdin();
    const stdout_file = std.fs.File.stdout();

    // Allocate read buffer (1MB for large JSON-RPC messages)
    const read_buf = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(read_buf);

    var file_reader = stdin_file.readerStreaming(read_buf);

    std.debug.print("16bits-audio-mcp: server started, waiting for input...\n", .{});

    while (true) {
        const line = file_reader.interface.takeDelimiter('\n') catch |err| switch (err) {
            error.StreamTooLong => {
                std.debug.print("16bits-audio-mcp: line too long, skipping\n", .{});
                continue;
            },
            error.ReadFailed => break,
        } orelse break; // EOF

        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;

        std.debug.print("16bits-audio-mcp: received: {s}\n", .{trimmed});

        // Copy line since takeDelimiter returns a slice into the read buffer
        const line_copy = allocator.dupe(u8, trimmed) catch continue;
        defer allocator.free(line_copy);

        // Build response into a buffer, then write all at once to stdout
        const response = processLine(allocator, line_copy) catch |err| {
            std.debug.print("16bits-audio-mcp: process error: {}\n", .{err});
            continue;
        } orelse continue; // notification, no response
        defer allocator.free(response);

        _ = stdout_file.write(response) catch |err| {
            std.debug.print("16bits-audio-mcp: write error: {}\n", .{err});
        };
    }

    std.debug.print("16bits-audio-mcp: server shutting down\n", .{});
}

/// Process a JSON-RPC line. Returns allocated response string, or null for notifications.
fn processLine(allocator: std.mem.Allocator, line: []const u8) !?[]const u8 {
    // Parse JSON
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, line, .{}) catch {
        return try protocol.buildJsonRpcError(allocator, "null", -32700, "Parse error");
    };
    defer parsed.deinit();

    const root = switch (parsed.value) {
        .object => |o| o,
        else => {
            return try protocol.buildJsonRpcError(allocator, "null", -32600, "Invalid Request");
        },
    };

    // Get method
    const method = switch (root.get("method") orelse {
        return try protocol.buildJsonRpcError(allocator, "null", -32600, "Invalid Request: missing method");
    }) {
        .string => |s| s,
        else => {
            return try protocol.buildJsonRpcError(allocator, "null", -32600, "Invalid Request: method must be string");
        },
    };

    // Format id for response
    var id_buf: [256]u8 = undefined;
    const id_json = protocol.formatId(root.get("id"), &id_buf);

    // Handle notifications (no response needed)
    if (std.mem.startsWith(u8, method, "notifications/")) {
        std.debug.print("16bits-audio-mcp: notification: {s}\n", .{method});
        return null;
    }

    // Dispatch method
    if (std.mem.eql(u8, method, "initialize")) {
        return try protocol.buildInitializeResult(allocator, id_json);
    } else if (std.mem.eql(u8, method, "tools/list")) {
        return try protocol.buildJsonRpcResult(allocator, id_json, tools.tools_list_json);
    } else if (std.mem.eql(u8, method, "tools/call")) {
        return try handleToolsCall(allocator, id_json, root.get("params"));
    } else {
        return try protocol.buildJsonRpcError(allocator, id_json, -32601, "Method not found");
    }
}

fn handleToolsCall(allocator: std.mem.Allocator, id_json: []const u8, params_val: ?std.json.Value) ![]const u8 {
    const params = switch (params_val orelse {
        return try protocol.buildToolResult(allocator, id_json, "Error: missing params", true);
    }) {
        .object => |o| o,
        else => {
            return try protocol.buildToolResult(allocator, id_json, "Error: params must be object", true);
        },
    };

    const tool_name = switch (params.get("name") orelse {
        return try protocol.buildToolResult(allocator, id_json, "Error: missing tool name", true);
    }) {
        .string => |s| s,
        else => {
            return try protocol.buildToolResult(allocator, id_json, "Error: tool name must be string", true);
        },
    };

    const arguments = switch (params.get("arguments") orelse {
        return try protocol.buildToolResult(allocator, id_json, "Error: missing arguments", true);
    }) {
        .object => |o| o,
        else => {
            return try protocol.buildToolResult(allocator, id_json, "Error: arguments must be object", true);
        },
    };

    std.debug.print("16bits-audio-mcp: executing tool: {s}\n", .{tool_name});

    const result = tools.executeTool(allocator, tool_name, arguments) catch |err| {
        const err_msg = switch (err) {
            error.UnknownTool => try std.fmt.allocPrint(allocator, "Error: unknown tool: {s}", .{tool_name}),
            error.MissingParam => try std.fmt.allocPrint(allocator, "Error: missing required parameter", .{}),
            error.InvalidParam => try std.fmt.allocPrint(allocator, "Error: invalid parameter value", .{}),
            error.InvalidWavFile => try std.fmt.allocPrint(allocator, "Error: invalid WAV file", .{}),
            error.UnsupportedBitDepth => try std.fmt.allocPrint(allocator, "Error: only 16-bit PCM WAV is supported", .{}),
            error.UnsupportedFormat => try std.fmt.allocPrint(allocator, "Error: unsupported WAV format", .{}),
            error.InvalidNoteName => try std.fmt.allocPrint(allocator, "Error: invalid note name", .{}),
            error.UnknownStyle => try std.fmt.allocPrint(allocator, "Error: unknown style", .{}),
            error.InvalidKey => try std.fmt.allocPrint(allocator, "Error: invalid key", .{}),
            error.InvalidScale => try std.fmt.allocPrint(allocator, "Error: invalid scale", .{}),
            error.UnknownSeType => try std.fmt.allocPrint(allocator, "Error: unknown SE type", .{}),
            error.UnknownJingleType => try std.fmt.allocPrint(allocator, "Error: unknown jingle type", .{}),
            error.FileNotFound => try std.fmt.allocPrint(allocator, "Error: file not found", .{}),
            else => try std.fmt.allocPrint(allocator, "Error: {}", .{err}),
        };
        defer allocator.free(err_msg);
        return try protocol.buildToolResult(allocator, id_json, err_msg, true);
    };
    defer allocator.free(result);

    return try protocol.buildToolResult(allocator, id_json, result, false);
}
