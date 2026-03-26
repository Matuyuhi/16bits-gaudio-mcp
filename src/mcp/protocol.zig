const std = @import("std");

const IoWriter = std.io.Writer;

/// Write a JSON-escaped string (without surrounding quotes)
fn writeJsonStringContent(writer: *IoWriter, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    try writer.print("\\u{x:0>4}", .{@as(u16, c)});
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
}

/// Write a JSON string with surrounding quotes
fn writeJsonString(writer: *IoWriter, s: []const u8) !void {
    try writer.writeByte('"');
    try writeJsonStringContent(writer, s);
    try writer.writeByte('"');
}

/// Convert a JSON Value representing an id to its JSON text representation.
pub fn formatId(value: ?std.json.Value, buf: []u8) []const u8 {
    const val = value orelse return "null";
    switch (val) {
        .null => return "null",
        .integer => |n| {
            return std.fmt.bufPrint(buf, "{d}", .{n}) catch "null";
        },
        .string => |s| {
            var pos: usize = 0;
            if (pos < buf.len) {
                buf[pos] = '"';
                pos += 1;
            }
            for (s) |c| {
                if (pos >= buf.len - 1) break;
                if (c == '"' or c == '\\') {
                    if (pos < buf.len - 1) {
                        buf[pos] = '\\';
                        pos += 1;
                    }
                }
                buf[pos] = c;
                pos += 1;
            }
            if (pos < buf.len) {
                buf[pos] = '"';
                pos += 1;
            }
            return buf[0..pos];
        },
        else => return "null",
    }
}

/// Write JSON-RPC error response
pub fn writeJsonRpcError(writer: *IoWriter, id_json: []const u8, code: i32, message: []const u8) !void {
    try writer.writeAll("{\"jsonrpc\":\"2.0\",\"id\":");
    try writer.writeAll(id_json);
    try writer.writeAll(",\"error\":{\"code\":");
    try writer.print("{d}", .{code});
    try writer.writeAll(",\"message\":");
    try writeJsonString(writer, message);
    try writer.writeAll("}}\n");
}

/// Write JSON-RPC success response with a raw JSON result
pub fn writeJsonRpcResult(writer: *IoWriter, id_json: []const u8, result_json: []const u8) !void {
    try writer.writeAll("{\"jsonrpc\":\"2.0\",\"id\":");
    try writer.writeAll(id_json);
    try writer.writeAll(",\"result\":");
    try writer.writeAll(result_json);
    try writer.writeAll("}\n");
}

/// Write MCP tool result (success or error)
pub fn writeToolResult(writer: *IoWriter, id_json: []const u8, text: []const u8, is_error: bool) !void {
    try writer.writeAll("{\"jsonrpc\":\"2.0\",\"id\":");
    try writer.writeAll(id_json);
    try writer.writeAll(",\"result\":{\"content\":[{\"type\":\"text\",\"text\":");
    try writeJsonString(writer, text);
    try writer.writeAll("}],\"isError\":");
    if (is_error) {
        try writer.writeAll("true");
    } else {
        try writer.writeAll("false");
    }
    try writer.writeAll("}}\n");
}

/// Write the initialize response
pub fn writeInitializeResult(writer: *IoWriter, id_json: []const u8) !void {
    try writeJsonRpcResult(writer, id_json,
        \\{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"16bits-audio-mcp","version":"0.1.0"}}
    );
}
