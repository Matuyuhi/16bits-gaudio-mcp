const std = @import("std");
const protocol = @import("protocol.zig");
const tools = @import("tools.zig");

const IoReader = std.io.Reader;
const IoWriter = std.io.Writer;

pub fn run(allocator: std.mem.Allocator) !void {
    const stdin_file = std.fs.File.stdin();
    const stdout_file = std.fs.File.stdout();

    // Allocate read buffer (1MB for large JSON-RPC messages)
    const read_buf = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(read_buf);

    // Allocate write buffer
    const write_buf = try allocator.alloc(u8, 65536);
    defer allocator.free(write_buf);

    var file_reader = stdin_file.readerStreaming(read_buf);
    var file_writer = stdout_file.writerStreaming(write_buf);

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

        processLine(allocator, line_copy, &file_writer.interface) catch |err| {
            std.debug.print("16bits-audio-mcp: process error: {}\n", .{err});
        };

        file_writer.interface.flush() catch {};
    }

    std.debug.print("16bits-audio-mcp: server shutting down\n", .{});
}

fn processLine(allocator: std.mem.Allocator, line: []const u8, writer: *IoWriter) !void {
    // Parse JSON
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, line, .{}) catch {
        try protocol.writeJsonRpcError(writer, "null", -32700, "Parse error");
        return;
    };
    defer parsed.deinit();

    const root = switch (parsed.value) {
        .object => |o| o,
        else => {
            try protocol.writeJsonRpcError(writer, "null", -32600, "Invalid Request");
            return;
        },
    };

    // Get method
    const method = switch (root.get("method") orelse {
        try protocol.writeJsonRpcError(writer, "null", -32600, "Invalid Request: missing method");
        return;
    }) {
        .string => |s| s,
        else => {
            try protocol.writeJsonRpcError(writer, "null", -32600, "Invalid Request: method must be string");
            return;
        },
    };

    // Format id for response
    var id_buf: [256]u8 = undefined;
    const id_json = protocol.formatId(root.get("id"), &id_buf);

    // Handle notifications (no response needed)
    if (std.mem.startsWith(u8, method, "notifications/")) {
        std.debug.print("16bits-audio-mcp: notification: {s}\n", .{method});
        return;
    }

    // Dispatch method
    if (std.mem.eql(u8, method, "initialize")) {
        try protocol.writeInitializeResult(writer, id_json);
    } else if (std.mem.eql(u8, method, "tools/list")) {
        try protocol.writeJsonRpcResult(writer, id_json, tools.tools_list_json);
    } else if (std.mem.eql(u8, method, "tools/call")) {
        try handleToolsCall(allocator, writer, id_json, root.get("params"));
    } else {
        try protocol.writeJsonRpcError(writer, id_json, -32601, "Method not found");
    }
}

fn handleToolsCall(allocator: std.mem.Allocator, writer: *IoWriter, id_json: []const u8, params_val: ?std.json.Value) !void {
    const params = switch (params_val orelse {
        try protocol.writeToolResult(writer, id_json, "Error: missing params", true);
        return;
    }) {
        .object => |o| o,
        else => {
            try protocol.writeToolResult(writer, id_json, "Error: params must be object", true);
            return;
        },
    };

    const tool_name = switch (params.get("name") orelse {
        try protocol.writeToolResult(writer, id_json, "Error: missing tool name", true);
        return;
    }) {
        .string => |s| s,
        else => {
            try protocol.writeToolResult(writer, id_json, "Error: tool name must be string", true);
            return;
        },
    };

    const arguments = switch (params.get("arguments") orelse {
        try protocol.writeToolResult(writer, id_json, "Error: missing arguments", true);
        return;
    }) {
        .object => |o| o,
        else => {
            try protocol.writeToolResult(writer, id_json, "Error: arguments must be object", true);
            return;
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
        try protocol.writeToolResult(writer, id_json, err_msg, true);
        return;
    };
    defer allocator.free(result);

    try protocol.writeToolResult(writer, id_json, result, false);
}
