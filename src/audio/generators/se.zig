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
    if (std.mem.eql(u8, config.se_type, "menu_select")) return generateMenuSelect(allocator, config);
    if (std.mem.eql(u8, config.se_type, "menu_cancel")) return generateMenuCancel(allocator, config);
    if (std.mem.eql(u8, config.se_type, "dash")) return generateDash(allocator, config);
    if (std.mem.eql(u8, config.se_type, "shield")) return generateShield(allocator, config);
    if (std.mem.eql(u8, config.se_type, "heal")) return generateHeal(allocator, config);
    if (std.mem.eql(u8, config.se_type, "charge")) return generateCharge(allocator, config);
    if (std.mem.eql(u8, config.se_type, "warp")) return generateWarp(allocator, config);
    if (std.mem.eql(u8, config.se_type, "door")) return generateDoor(allocator, config);
    if (std.mem.eql(u8, config.se_type, "switch")) return generateSwitch(allocator, config);
    if (std.mem.eql(u8, config.se_type, "splash")) return generateSplash(allocator, config);
    if (std.mem.eql(u8, config.se_type, "wind")) return generateWind(allocator, config);
    if (std.mem.eql(u8, config.se_type, "thunder")) return generateThunder(allocator, config);
    return error.UnknownSeType;
}

// ============================================================
// Original 8
// ============================================================

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

// ============================================================
// New 12 SE types
// ============================================================

/// Menu cursor / select: bright short blip
fn generateMenuSelect(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 80.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var phase: f32 = 0.0;
    const freq: f32 = 1200.0 * config.pitch;

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        const env_val = std.math.pow(f32, 1.0 - t, 3.0);
        s.* = oscillator.square(phase) * env_val * config.volume * 0.4;
        phase += freq / config.sample_rate;
        phase -= @floor(phase);
    }
    return buf;
}

/// Menu cancel: descending two-note blip
fn generateMenuCancel(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 120.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var phase: f32 = 0.0;
    const half = total / 2;

    for (buf, 0..) |*s, i| {
        const freq = if (i < half) 800.0 * config.pitch else 500.0 * config.pitch;
        const local_t = if (i < half)
            @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(half))
        else
            @as(f32, @floatFromInt(i - half)) / @as(f32, @floatFromInt(half));
        const env_val = 1.0 - local_t * 0.6;
        s.* = oscillator.square(phase) * env_val * config.volume * 0.35;
        phase += freq / config.sample_rate;
        phase -= @floor(phase);
    }
    return buf;
}

/// Dash / swoosh: fast noise sweep with highpass
fn generateDash(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 250.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var hp = filter.HighpassFilter.init(1000.0 * config.pitch, config.sample_rate);

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        // Bell curve envelope: peaks at 30%
        const env_val = std.math.pow(f32, t * 2.0, 1.5) * std.math.pow(f32, @max(0.0, 1.0 - t), 2.0) * 4.0;
        s.* = hp.process(oscillator.noise()) * env_val * config.volume * 0.7;
    }
    return buf;
}

/// Shield / barrier: resonant metallic tone
fn generateShield(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 400.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var phase1: f32 = 0.0;
    var phase2: f32 = 0.0;
    const freq1: f32 = 600.0 * config.pitch;
    const freq2: f32 = 900.0 * config.pitch; // inharmonic partial for metallic ring

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        const env_val = std.math.pow(f32, 1.0 - t, 1.5);
        const sig = oscillator.sine(phase1) * 0.6 + oscillator.sine(phase2) * 0.4;
        s.* = sig * env_val * config.volume;
        phase1 += freq1 / config.sample_rate;
        phase1 -= @floor(phase1);
        phase2 += freq2 / config.sample_rate;
        phase2 -= @floor(phase2);
    }
    return buf;
}

/// Heal / recovery: gentle ascending shimmer
fn generateHeal(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 600.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    // Three ascending tones: C5, E5, G5
    const freqs = [_]f32{ 523.25, 659.25, 783.99 };
    const note_len = total / 3;

    var phase: f32 = 0.0;
    for (buf, 0..) |*s, i| {
        const note_idx = @min(i / note_len, 2);
        const freq = freqs[note_idx] * config.pitch;
        const global_t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        // Swell then fade
        const env_val = @sin(global_t * std.math.pi);
        s.* = oscillator.sine(phase) * env_val * config.volume * 0.6;
        phase += freq / config.sample_rate;
        phase -= @floor(phase);
    }
    return buf;
}

/// Charge / power building: rising frequency with increasing volume
fn generateCharge(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 800.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var phase: f32 = 0.0;

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        // Exponential frequency rise: 200 -> 2000 Hz
        const freq = (200.0 + std.math.pow(f32, t, 2.0) * 1800.0) * config.pitch;
        // Volume crescendo
        const env_val = t * 0.8 + 0.2;
        s.* = oscillator.sawtooth(phase) * env_val * config.volume * 0.5;
        phase += freq / config.sample_rate;
        phase -= @floor(phase);
    }
    return buf;
}

/// Warp / teleport: wobbly FM sweep
fn generateWarp(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 500.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var carrier_phase: f32 = 0.0;
    var mod_phase: f32 = 0.0;
    const carrier_freq: f32 = 500.0 * config.pitch;
    const mod_freq: f32 = 8.0; // slow wobble

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        // FM modulation creates warp wobble
        const mod = @sin(mod_phase * std.math.tau) * 300.0 * (1.0 - t);
        const freq = carrier_freq + mod;
        // Bell-shaped envelope
        const env_val = @sin(t * std.math.pi) * (1.0 - t * 0.3);
        s.* = oscillator.sine(carrier_phase) * env_val * config.volume * 0.6;
        carrier_phase += freq / config.sample_rate;
        carrier_phase -= @floor(carrier_phase);
        mod_phase += mod_freq / config.sample_rate;
        mod_phase -= @floor(mod_phase);
    }
    return buf;
}

/// Door open/close: low resonant thud
fn generateDoor(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 350.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var phase: f32 = 0.0;
    var lp = filter.LowpassFilter.init(500.0 * config.pitch, config.sample_rate);

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        const freq = (120.0 + (1.0 - t) * 80.0) * config.pitch;
        const env_val = std.math.pow(f32, 1.0 - t, 2.5);
        const raw = oscillator.sine(phase) * 0.7 + oscillator.noise() * 0.3;
        s.* = lp.process(raw) * env_val * config.volume;
        phase += freq / config.sample_rate;
        phase -= @floor(phase);
    }
    return buf;
}

/// Switch / toggle: short click-clack
fn generateSwitch(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 60.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var bp = filter.BandpassFilter.init(2000.0, 6000.0, config.sample_rate);

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        const env_val = std.math.pow(f32, 1.0 - t, 6.0);
        s.* = bp.process(oscillator.noise()) * env_val * config.volume * config.pitch;
    }
    return buf;
}

/// Splash / water: filtered noise with resonance
fn generateSplash(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 500.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var lp = filter.LowpassFilter.init(3000.0 * config.pitch, config.sample_rate);
    var hp = filter.HighpassFilter.init(200.0, config.sample_rate);

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        // Fast attack, slow decay
        const env_val = if (t < 0.05)
            t * 20.0
        else
            std.math.pow(f32, 1.0 - (t - 0.05) / 0.95, 2.0);
        const raw = oscillator.noise();
        s.* = hp.process(lp.process(raw)) * env_val * config.volume * 0.8;
    }
    return buf;
}

/// Wind: sustained filtered noise with slow modulation
fn generateWind(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 1000.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var lp = filter.LowpassFilter.init(800.0, config.sample_rate);

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        // Slow amplitude modulation for wind gusts
        const mod = 0.5 + 0.5 * @sin(t * std.math.pi * 4.0 * config.pitch);
        // Fade in and out
        const fade = @sin(t * std.math.pi);
        const raw = oscillator.noise();
        s.* = lp.process(raw) * mod * fade * config.volume * 0.5;
    }
    return buf;
}

/// Thunder: low rumble with crack
fn generateThunder(allocator: std.mem.Allocator, config: SeConfig) ![]f32 {
    const duration_ms: f32 = 1200.0;
    const total: usize = @intFromFloat(duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total);

    var lp = filter.LowpassFilter.init(200.0 * config.pitch, config.sample_rate);
    const crack_end: usize = @intFromFloat(50.0 * config.sample_rate / 1000.0);

    for (buf, 0..) |*s, i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total));
        const raw = oscillator.noise();

        if (i < crack_end) {
            // Sharp initial crack: unfiltered noise
            const crack_t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(crack_end));
            s.* = raw * (1.0 - crack_t) * config.volume * 1.2;
        } else {
            // Low rumble
            const rumble_env = std.math.pow(f32, 1.0 - (t - 0.04) / 0.96, 1.5);
            s.* = lp.process(raw) * rumble_env * config.volume * 1.5;
        }
    }
    return buf;
}
