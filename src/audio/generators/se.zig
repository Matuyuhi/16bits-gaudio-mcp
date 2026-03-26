const std = @import("std");
const oscillator = @import("../oscillator.zig");
const envelope = @import("../envelope.zig");
const filter = @import("../filter.zig");

pub const SeConfig = struct {
    se_type: []const u8,
    pitch: f32 = 1.0,
    volume: f32 = 0.8,
    sample_rate: f32 = 44100.0,
};

pub fn generate(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    if (std.mem.eql(u8, config.se_type, "jump")) return generateJump(allocator, config);
    if (std.mem.eql(u8, config.se_type, "hit")) return generateHit(allocator, config);
    if (std.mem.eql(u8, config.se_type, "coin")) return generateCoin(allocator, config);
    if (std.mem.eql(u8, config.se_type, "explosion")) return generateExplosion(allocator, config);
    if (std.mem.eql(u8, config.se_type, "laser")) return generateLaser(allocator, config);
    if (std.mem.eql(u8, config.se_type, "powerup")) return generatePowerup(allocator, config);
    if (std.mem.eql(u8, config.se_type, "error")) return generateError(allocator, config);
    if (std.mem.eql(u8, config.se_type, "footstep")) return generateFootstep(allocator, config);
    return error.UnknownSeType;
}

fn generateJump(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 200.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var phase: f32 = 0.0;
    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        // Frequency sweep from 400 to 800 Hz
        const freq = (400.0 + t * 400.0) * config.pitch;
        const env_val = 1.0 - t; // linear decay
        s.* = oscillator.sine(phase) * env_val * config.volume;
        phase += freq / config.sample_rate;
        phase -= @floor(phase);
    }
    return buf;
}

fn generateHit(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 100.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        // Noise burst with rapid exponential decay
        const env_val = std.math.pow(f32, 1.0 - t, 4.0);
        s.* = oscillator.noise() * env_val * config.volume * config.pitch;
    }
    return buf;
}

fn generateCoin(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 150.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var phase: f32 = 0.0;
    const half = total / 2;
    for (buf, 0..) |*s, i| {
        // C6 for first half, E6 for second half
        const freq = if (i < half) 1046.5 * config.pitch else 1318.5 * config.pitch;
        const local_t = if (i < half)
            @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(half))
        else
            @as(f32, @floatFromInt(i - half)) / @as(f32, @floatFromInt(half));
        const env_val = 1.0 - local_t * 0.5; // gentle decay per note
        s.* = oscillator.sine(phase) * env_val * config.volume;
        phase += freq / config.sample_rate;
        phase -= @floor(phase);
    }
    return buf;
}

fn generateExplosion(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 800.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var lp = filter.LowpassFilter.init(300.0 * config.pitch, config.sample_rate);

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        const env_val = std.math.pow(f32, 1.0 - t, 2.0);
        const raw = oscillator.noise();
        s.* = lp.process(raw) * env_val * config.volume * 1.5;
    }
    return buf;
}

fn generateLaser(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 300.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var phase: f32 = 0.0;
    var lp = filter.LowpassFilter.init(4000.0, config.sample_rate);

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        // Rapid downward sweep: 2000 -> 200 Hz
        const freq = (2000.0 - t * 1800.0) * config.pitch;
        const env_val = 1.0 - t * 0.7;
        const raw = oscillator.sawtooth(phase);
        s.* = lp.process(raw) * env_val * config.volume;
        phase += freq / config.sample_rate;
        phase -= @floor(phase);
    }
    return buf;
}

fn generatePowerup(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 500.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    // Pentatonic ascending arpeggio: C5, D5, E5, G5, A5
    const freqs = [_]f32{ 523.25, 587.33, 659.25, 783.99, 880.0 };
    const note_len = total / freqs.len;

    var phase: f32 = 0.0;
    for (buf, 0..) |*s, i| {
        const note_idx = @min(i / note_len, freqs.len - 1);
        const freq = freqs[note_idx] * config.pitch;
        const local_i = i % note_len;
        const local_t = @as(f32, @floatFromInt(local_i)) / @as(f32, @floatFromInt(note_len));
        const env_val = 1.0 - local_t * 0.4;
        s.* = oscillator.sine(phase) * env_val * config.volume;
        phase += freq / config.sample_rate;
        phase -= @floor(phase);
    }
    return buf;
}

fn generateError(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 200.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var phase: f32 = 0.0;
    const freq: f32 = 200.0 * config.pitch;

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        // Tremolo: rapid on/off
        const tremolo_freq: f32 = 20.0;
        const tremolo = @abs(@sin(@as(f32, @floatFromInt(i)) * tremolo_freq * std.math.tau / config.sample_rate));
        const env_val = (1.0 - t * 0.5);
        s.* = oscillator.square(phase) * env_val * tremolo * config.volume * 0.5;
        phase += freq / config.sample_rate;
        phase -= @floor(phase);
    }
    return buf;
}

fn generateFootstep(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 200.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);
    @memset(buf, 0.0);

    // Two short noise bursts
    const burst_len = @as(usize, @intFromFloat(20.0 * config.sample_rate / 1000.0));
    const gap = @as(usize, @intFromFloat(80.0 * config.sample_rate / 1000.0));

    var lp = filter.LowpassFilter.init(2000.0 * config.pitch, config.sample_rate);

    // First burst
    for (0..@min(burst_len, total)) |i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(burst_len));
        buf[i] = lp.process(oscillator.noise()) * (1.0 - t) * config.volume;
    }

    // Second burst
    lp.reset();
    const start2 = burst_len + gap;
    for (0..@min(burst_len, total -| start2)) |i| {
        if (start2 + i < total) {
            const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(burst_len));
            buf[start2 + i] = lp.process(oscillator.noise()) * (1.0 - t) * config.volume * 0.8;
        }
    }
    return buf;
}
