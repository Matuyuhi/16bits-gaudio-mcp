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
