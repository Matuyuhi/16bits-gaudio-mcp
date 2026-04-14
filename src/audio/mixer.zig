const std = @import("std");
const wav = @import("wav.zig");

/// Mix multiple buffers into a single output buffer.
/// Each track has: samples, gain, offset_samples
pub const MixTrack = struct {
    samples: []const f32,
    gain: f32,
    offset_samples: usize,
};

/// Mix multiple tracks into one buffer
pub fn mixTracks(allocator: std.mem.Allocator, tracks: []const MixTrack) ![]f32 {
    // Find the total length needed
    var max_len: usize = 0;
    for (tracks) |track| {
        const end = track.offset_samples + track.samples.len;
        if (end > max_len) max_len = end;
    }

    if (max_len == 0) return error.EmptyMix;

    const output = try allocator.alloc(f32, max_len);
    @memset(output, 0.0);

    for (tracks) |track| {
        for (track.samples, 0..) |sample, i| {
            const out_idx = track.offset_samples + i;
            if (out_idx < output.len) {
                output[out_idx] += sample * track.gain;
            }
        }
    }

    return output;
}

/// Normalize buffer so peak is at target_db (e.g., -1.0 for -1dBFS)
pub fn normalize(buf: []f32, target_db: f32) void {
    var peak: f32 = 0.0;
    for (buf) |s| {
        const abs = @abs(s);
        if (abs > peak) peak = abs;
    }

    if (peak == 0.0) return;

    const target_linear = std.math.pow(f32, 10.0, target_db / 20.0);
    const gain = target_linear / peak;

    for (buf) |*s| {
        s.* *= gain;
    }
}

/// Crossfade the end of the buffer into the beginning for seamless looping
pub fn crossfade(buf: []f32, fade_samples: usize) void {
    if (buf.len < fade_samples * 2) return;

    const len = buf.len;
    for (0..fade_samples) |i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(fade_samples));
        // Fade out at end
        const end_idx = len - fade_samples + i;
        const end_val = buf[end_idx];
        // Fade in at start
        const start_val = buf[i];
        // Crossfade: start takes over from end
        buf[i] = start_val * t + end_val * (1.0 - t);
    }
}

pub const ConcatSegment = struct {
    samples: []const f32,
    gain: f32,
};

/// Concatenate audio segments sequentially with optional gap or crossfade.
/// If crossfade_samples > 0, it takes priority over gap_samples.
pub fn concatSegments(
    allocator: std.mem.Allocator,
    segments: []const ConcatSegment,
    gap_samples: usize,
    crossfade_samples: usize,
) ![]f32 {
    if (segments.len == 0) return error.EmptyMix;

    const use_crossfade = crossfade_samples > 0;

    // Calculate total output length
    var total_len: usize = 0;
    for (segments, 0..) |seg, i| {
        total_len += seg.samples.len;
        if (i < segments.len - 1) {
            if (use_crossfade) {
                const cf = @min(crossfade_samples, seg.samples.len);
                total_len -|= cf;
            } else {
                total_len += gap_samples;
            }
        }
    }

    const output = try allocator.alloc(f32, total_len);
    @memset(output, 0.0);

    var offset: usize = 0;
    for (segments, 0..) |seg, seg_i| {
        const cf = if (use_crossfade) @min(crossfade_samples, seg.samples.len) else 0;

        for (seg.samples, 0..) |s, j| {
            const idx = offset + j;
            if (idx >= total_len) break;

            var value = s * seg.gain;

            // Fade-in for non-first segments in crossfade region
            if (use_crossfade and seg_i > 0 and j < cf) {
                const t = @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(cf));
                value *= t;
            }

            // Fade-out at tail for non-last segments in crossfade region
            if (use_crossfade and seg_i < segments.len - 1) {
                const fade_start = seg.samples.len -| cf;
                if (j >= fade_start) {
                    const fade_pos = j - fade_start;
                    const t = @as(f32, @floatFromInt(fade_pos)) / @as(f32, @floatFromInt(cf));
                    value *= (1.0 - t);
                }
            }

            output[idx] += value;
        }

        // Advance offset for next segment
        if (seg_i < segments.len - 1) {
            if (use_crossfade) {
                offset += seg.samples.len -| cf;
            } else {
                offset += seg.samples.len + gap_samples;
            }
        }
    }

    return output;
}

/// Mix WAV files from disk
pub fn mixWavFiles(allocator: std.mem.Allocator, paths: []const []const u8, gains: []const f32, offsets_ms: []const f32, sample_rate: f32) ![]f32 {
    var tracks_list: std.ArrayList(MixTrack) = .empty;
    defer {
        for (tracks_list.items) |track| {
            allocator.free(@constCast(track.samples));
        }
        tracks_list.deinit(allocator);
    }

    for (paths, 0..) |path, i| {
        const data = try wav.readWav(allocator, path);
        const gain = if (i < gains.len) gains[i] else 1.0;
        const offset_ms = if (i < offsets_ms.len) offsets_ms[i] else 0.0;
        const offset_samples: usize = @intFromFloat(offset_ms * sample_rate / 1000.0);

        try tracks_list.append(allocator, .{
            .samples = data.samples,
            .gain = gain,
            .offset_samples = offset_samples,
        });
    }

    return try mixTracks(allocator, tracks_list.items);
}

// ── Unit Tests ──────────────────────────────────────────────────────────────

test "mixTracks combines two signals" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const a = [_]f32{ 1.0, 0.5, 0.0, -0.5 };
    const b = [_]f32{ 0.0, 0.5, 1.0, 0.5 };
    const tracks = [_]MixTrack{
        .{ .samples = &a, .gain = 1.0, .offset_samples = 0 },
        .{ .samples = &b, .gain = 1.0, .offset_samples = 0 },
    };

    const output = try mixTracks(allocator, &tracks);
    defer allocator.free(output);

    try testing.expectApproxEqAbs(@as(f32, 1.0), output[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 1.0), output[1], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 1.0), output[2], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0.0), output[3], 1e-5);
}

test "mixTracks with offset" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const samples = [_]f32{ 1.0, 1.0, 1.0 };
    const tracks = [_]MixTrack{
        .{ .samples = &samples, .gain = 0.5, .offset_samples = 2 },
    };

    const output = try mixTracks(allocator, &tracks);
    defer allocator.free(output);

    try testing.expectEqual(@as(usize, 5), output.len);
    try testing.expectApproxEqAbs(@as(f32, 0.0), output[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0.0), output[1], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0.5), output[2], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0.5), output[3], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0.5), output[4], 1e-5);
}

test "mixTracks empty returns error" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const tracks = [_]MixTrack{};
    try testing.expectError(error.EmptyMix, mixTracks(allocator, &tracks));
}

test "normalize scales peak to target" {
    const testing = std.testing;

    var buf = [_]f32{ 0.5, -0.25, 0.0, 0.5 };
    normalize(&buf, -1.0);

    // target_linear = 10^(-1/20) ≈ 0.891251, peak was 0.5
    const expected: f32 = std.math.pow(f32, 10.0, -1.0 / 20.0);
    try testing.expectApproxEqAbs(expected, buf[0], 1e-4);
}

test "normalize handles silence" {
    const testing = std.testing;

    var buf = [_]f32{ 0.0, 0.0, 0.0 };
    normalize(&buf, -1.0);

    try testing.expectApproxEqAbs(@as(f32, 0.0), buf[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0.0), buf[1], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0.0), buf[2], 1e-5);
}

test "crossfade blends endpoints" {
    const testing = std.testing;

    // First 10 samples = 0.0, last 10 samples = 1.0
    var buf = [_]f32{
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
    };
    crossfade(&buf, 5);

    // i=0: t=0.0, buf[0] = 0.0*0.0 + buf[15]*1.0 = 1.0
    try testing.expectApproxEqAbs(@as(f32, 1.0), buf[0], 1e-5);
    // i=4: t=0.8, buf[4] = 0.0*0.8 + buf[19]*0.2 = 0.2
    try testing.expectApproxEqAbs(@as(f32, 0.2), buf[4], 1e-5);
}
