const std = @import("std");

pub const Waveform = enum {
    sine,
    square,
    sawtooth,
    triangle,
    pulse,
    noise,
};

/// Generate a single sample for the given waveform at the given phase [0.0, 1.0)
pub fn sample(waveform: Waveform, phase: f32) f32 {
    return switch (waveform) {
        .sine => sine(phase),
        .square => square(phase),
        .sawtooth => sawtooth(phase),
        .triangle => triangle(phase),
        .pulse => pulse(phase, 0.25),
        .noise => noise(),
    };
}

pub fn sine(phase: f32) f32 {
    return @sin(phase * std.math.tau);
}

pub fn square(phase: f32) f32 {
    return if (phase < 0.5) @as(f32, 1.0) else @as(f32, -1.0);
}

pub fn sawtooth(phase: f32) f32 {
    return 2.0 * phase - 1.0;
}

pub fn triangle(phase: f32) f32 {
    if (phase < 0.25) {
        return phase * 4.0;
    } else if (phase < 0.75) {
        return 2.0 - phase * 4.0;
    } else {
        return phase * 4.0 - 4.0;
    }
}

pub fn pulse(phase: f32, duty: f32) f32 {
    return if (phase < duty) @as(f32, 1.0) else @as(f32, -1.0);
}

/// White noise using xorshift
var noise_state: u32 = 0x12345678;

pub fn noise() f32 {
    noise_state ^= noise_state << 13;
    noise_state ^= noise_state >> 17;
    noise_state ^= noise_state << 5;
    return @as(f32, @floatFromInt(@as(i32, @bitCast(noise_state)))) / 2147483648.0;
}

pub fn resetNoise(seed: u32) void {
    noise_state = if (seed == 0) 0x12345678 else seed;
}

/// Parse waveform name from string
pub fn parseWaveform(name: []const u8) ?Waveform {
    if (std.mem.eql(u8, name, "sine")) return .sine;
    if (std.mem.eql(u8, name, "square")) return .square;
    if (std.mem.eql(u8, name, "sawtooth")) return .sawtooth;
    if (std.mem.eql(u8, name, "triangle")) return .triangle;
    if (std.mem.eql(u8, name, "pulse")) return .pulse;
    if (std.mem.eql(u8, name, "noise")) return .noise;
    return null;
}

test "sine waveform" {
    const testing = std.testing;
    try testing.expectApproxEqAbs(@as(f32, 0.0), sine(0.0), 0.01);
    try testing.expectApproxEqAbs(@as(f32, 1.0), sine(0.25), 0.01);
}

test "square waveform" {
    const testing = std.testing;
    try testing.expectEqual(@as(f32, 1.0), square(0.25));
    try testing.expectEqual(@as(f32, -1.0), square(0.75));
}

test "sawtooth waveform" {
    const testing = std.testing;
    try testing.expectApproxEqAbs(@as(f32, -1.0), sawtooth(0.0), 0.01);
    try testing.expectApproxEqAbs(@as(f32, 0.0), sawtooth(0.5), 0.01);
    // Near 1.0 (approaching but not wrapping)
    try testing.expect(sawtooth(1.0 - 0.001) > 0.99);
}

test "triangle waveform" {
    const testing = std.testing;
    try testing.expectApproxEqAbs(@as(f32, 0.0), triangle(0.0), 0.01);
    try testing.expectApproxEqAbs(@as(f32, 1.0), triangle(0.25), 0.01);
    try testing.expectApproxEqAbs(@as(f32, -1.0), triangle(0.75), 0.01);
}

test "pulse waveform" {
    const testing = std.testing;
    try testing.expectEqual(@as(f32, 1.0), pulse(0.1, 0.25));
    try testing.expectEqual(@as(f32, -1.0), pulse(0.3, 0.25));
}

test "noise waveform range" {
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const v = noise();
        try std.testing.expect(v >= -1.0 and v <= 1.0);
    }
}

test "noise reset produces same sequence" {
    const testing = std.testing;
    resetNoise(42);
    const a0 = noise();
    const a1 = noise();
    const a2 = noise();

    resetNoise(42);
    const b0 = noise();
    const b1 = noise();
    const b2 = noise();

    try testing.expectEqual(a0, b0);
    try testing.expectEqual(a1, b1);
    try testing.expectEqual(a2, b2);
}

test "parseWaveform" {
    const testing = std.testing;
    try testing.expectEqual(Waveform.sine, parseWaveform("sine").?);
    try testing.expect(parseWaveform("invalid") == null);
}
