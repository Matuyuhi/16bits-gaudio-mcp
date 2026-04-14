const std = @import("std");

pub const WavInfo = struct {
    sample_rate: u32,
    channels: u16,
    bit_depth: u16,
    duration_ms: u64,
    total_samples: u64,
    rms_db: f64,
    peak_db: f64,
};

pub const WavData = struct {
    samples: []f32,
    info: WavInfo,
};

// Helper to write a little-endian integer as bytes
fn writeIntLe(comptime T: type, file: std.fs.File, value: T) !void {
    const n = @divExact(@typeInfo(T).int.bits, 8);
    var bytes: [n]u8 = undefined;
    std.mem.writeInt(T, &bytes, value, .little);
    const written = try file.write(&bytes);
    if (written != n) return error.ShortWrite;
}

/// Write mono f32 samples as 16-bit PCM WAV
pub fn writeWav(path: []const u8, samples: []const f32, sample_rate: u32) !void {
    const file = try createFilePath(path);
    defer file.close();

    const num_samples: u32 = @intCast(samples.len);
    const channels: u16 = 1;
    const bit_depth: u16 = 16;
    const byte_rate: u32 = sample_rate * @as(u32, channels) * @as(u32, bit_depth) / 8;
    const block_align: u16 = channels * bit_depth / 8;
    const data_size: u32 = num_samples * @as(u32, block_align);
    const file_size: u32 = 36 + data_size;

    // RIFF header
    _ = try file.write("RIFF");
    try writeIntLe(u32, file, file_size);
    _ = try file.write("WAVE");

    // fmt chunk
    _ = try file.write("fmt ");
    try writeIntLe(u32, file, 16); // chunk size
    try writeIntLe(u16, file, 1); // PCM
    try writeIntLe(u16, file, channels);
    try writeIntLe(u32, file, sample_rate);
    try writeIntLe(u32, file, byte_rate);
    try writeIntLe(u16, file, block_align);
    try writeIntLe(u16, file, bit_depth);

    // data chunk
    _ = try file.write("data");
    try writeIntLe(u32, file, data_size);

    // Write samples in batches for efficiency
    var batch_buf: [8192]u8 = undefined;
    var batch_pos: usize = 0;

    for (samples) |sample| {
        const clamped = @max(-1.0, @min(1.0, sample));
        const int_sample: i16 = @intFromFloat(clamped * 32767.0);
        std.mem.writeInt(i16, batch_buf[batch_pos..][0..2], int_sample, .little);
        batch_pos += 2;

        if (batch_pos >= batch_buf.len) {
            _ = try file.write(batch_buf[0..batch_pos]);
            batch_pos = 0;
        }
    }
    // Flush remaining
    if (batch_pos > 0) {
        _ = try file.write(batch_buf[0..batch_pos]);
    }
}

/// Read a 16-bit PCM WAV file, return f32 samples and metadata
pub fn readWav(allocator: std.mem.Allocator, path: []const u8) !WavData {
    const file = try openFilePath(path);
    defer file.close();

    // Read entire file for simplicity
    const file_data = try file.readToEndAlloc(allocator, 100 * 1024 * 1024); // 100MB max
    defer allocator.free(file_data);

    if (file_data.len < 44) return error.InvalidWavFile;

    // Check RIFF header
    if (!std.mem.eql(u8, file_data[0..4], "RIFF")) return error.InvalidWavFile;
    if (!std.mem.eql(u8, file_data[8..12], "WAVE")) return error.InvalidWavFile;

    var sample_rate: u32 = 0;
    var channels: u16 = 0;
    var bit_depth: u16 = 0;
    var data_offset: usize = 0;
    var data_size: u32 = 0;

    // Parse chunks
    var pos: usize = 12;
    while (pos + 8 <= file_data.len) {
        const chunk_id = file_data[pos..][0..4];
        const chunk_size = std.mem.readInt(u32, file_data[pos + 4 ..][0..4], .little);
        pos += 8;

        if (std.mem.eql(u8, chunk_id, "fmt ")) {
            if (pos + 16 > file_data.len) return error.InvalidWavFile;
            const format = std.mem.readInt(u16, file_data[pos..][0..2], .little);
            if (format != 1) return error.UnsupportedFormat;
            channels = std.mem.readInt(u16, file_data[pos + 2 ..][0..2], .little);
            sample_rate = std.mem.readInt(u32, file_data[pos + 4 ..][0..4], .little);
            // skip byte_rate (4) and block_align (2)
            bit_depth = std.mem.readInt(u16, file_data[pos + 14 ..][0..2], .little);
            if (bit_depth != 16) return error.UnsupportedBitDepth;
        } else if (std.mem.eql(u8, chunk_id, "data")) {
            data_offset = pos;
            data_size = chunk_size;
        }

        pos += chunk_size;
        // Align to 2-byte boundary
        if (chunk_size % 2 != 0) pos += 1;
    }

    if (data_offset == 0 or data_size == 0) return error.NoDataChunk;

    const num_samples = data_size / 2;
    const samples = try allocator.alloc(f32, num_samples);
    errdefer allocator.free(samples);

    var i: usize = 0;
    var dpos: usize = data_offset;
    while (i < num_samples and dpos + 2 <= file_data.len) {
        const int_val = std.mem.readInt(i16, file_data[dpos..][0..2], .little);
        samples[i] = @as(f32, @floatFromInt(int_val)) / 32768.0;
        dpos += 2;
        i += 1;
    }

    const chan: usize = @intCast(channels);
    const num_frames = if (chan > 0) num_samples / chan else num_samples;
    const duration_ms = @as(u64, @intCast(num_frames)) * 1000 / @as(u64, sample_rate);

    // Calculate RMS and peak
    var sum_sq: f64 = 0;
    var peak: f64 = 0;
    for (samples[0..i]) |v| {
        const fv: f64 = @floatCast(v);
        const abs_v = @abs(fv);
        if (abs_v > peak) peak = abs_v;
        sum_sq += fv * fv;
    }
    const count_f: f64 = @floatFromInt(i);
    const rms = @sqrt(sum_sq / @max(count_f, 1.0));
    const rms_db: f64 = if (rms > 0.0) 20.0 * std.math.log10(rms) else -100.0;
    const peak_db: f64 = if (peak > 0.0) 20.0 * std.math.log10(peak) else -100.0;

    return .{
        .samples = samples,
        .info = .{
            .sample_rate = sample_rate,
            .channels = channels,
            .bit_depth = bit_depth,
            .duration_ms = duration_ms,
            .total_samples = @intCast(i),
            .rms_db = rms_db,
            .peak_db = peak_db,
        },
    };
}

/// Get WAV info without keeping samples in memory
pub fn getWavInfo(allocator: std.mem.Allocator, path: []const u8) !WavInfo {
    const data = try readWav(allocator, path);
    defer allocator.free(data.samples);
    return data.info;
}

fn createFilePath(path: []const u8) !std.fs.File {
    if (std.fs.path.isAbsolute(path)) {
        return std.fs.createFileAbsolute(path, .{});
    } else {
        return std.fs.cwd().createFile(path, .{});
    }
}

fn openFilePath(path: []const u8) !std.fs.File {
    if (std.fs.path.isAbsolute(path)) {
        return std.fs.openFileAbsolute(path, .{});
    } else {
        return std.fs.cwd().openFile(path, .{});
    }
}

test "WAV write and read round-trip" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const path = "/tmp/zig_test_wav_roundtrip.wav";
    defer std.fs.deleteFileAbsolute(path) catch {};

    const sample_rate: u32 = 44100;
    const num_samples: usize = 100;
    var samples: [num_samples]f32 = undefined;
    for (&samples, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));
        s.* = @sin(2.0 * std.math.pi * 440.0 * t);
    }

    try writeWav(path, &samples, sample_rate);

    const data = try readWav(allocator, path);
    defer allocator.free(data.samples);

    try testing.expectEqual(num_samples, data.samples.len);
    for (samples, data.samples) |orig, read| {
        try testing.expectApproxEqAbs(orig, read, 0.001);
    }
}

test "WAV f32 to i16 clamping" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const path = "/tmp/zig_test_wav_clamp.wav";
    defer std.fs.deleteFileAbsolute(path) catch {};

    const samples = [_]f32{ 2.0, -2.0, 0.5, -0.5 };
    try writeWav(path, &samples, 44100);

    const data = try readWav(allocator, path);
    defer allocator.free(data.samples);

    try testing.expectEqual(@as(usize, 4), data.samples.len);
    // Over-range values should be clamped to approximately +/-1.0
    try testing.expectApproxEqAbs(@as(f32, 1.0), data.samples[0], 0.001);
    try testing.expectApproxEqAbs(@as(f32, -1.0), data.samples[1], 0.001);
    // In-range values should be preserved
    try testing.expectApproxEqAbs(@as(f32, 0.5), data.samples[2], 0.001);
    try testing.expectApproxEqAbs(@as(f32, -0.5), data.samples[3], 0.001);
}

test "getWavInfo returns correct metadata" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const path = "/tmp/zig_test_wav_info.wav";
    defer std.fs.deleteFileAbsolute(path) catch {};

    const sample_rate: u32 = 44100;
    const num_samples: usize = 441;
    var samples: [num_samples]f32 = undefined;
    for (&samples) |*s| {
        s.* = 0.5;
    }

    try writeWav(path, &samples, sample_rate);

    const info = try getWavInfo(allocator, path);

    try testing.expectEqual(@as(u32, 44100), info.sample_rate);
    try testing.expectEqual(@as(u16, 1), info.channels);
    try testing.expectEqual(@as(u16, 16), info.bit_depth);
    try testing.expectEqual(@as(u64, 10), info.duration_ms);
}
