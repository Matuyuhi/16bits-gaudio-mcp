const std = @import("std");

/// Simple single-pole lowpass filter
pub const LowpassFilter = struct {
    alpha: f32,
    prev: f32,

    pub fn init(cutoff_hz: f32, sample_rate: f32) LowpassFilter {
        const rc = 1.0 / (2.0 * std.math.pi * cutoff_hz);
        const dt = 1.0 / sample_rate;
        return .{
            .alpha = dt / (rc + dt),
            .prev = 0.0,
        };
    }

    pub fn process(self: *LowpassFilter, input: f32) f32 {
        self.prev = self.prev + self.alpha * (input - self.prev);
        return self.prev;
    }

    pub fn processBuffer(self: *LowpassFilter, buf: []f32) void {
        for (buf) |*s| {
            s.* = self.process(s.*);
        }
    }

    pub fn reset(self: *LowpassFilter) void {
        self.prev = 0.0;
    }
};

/// Simple single-pole highpass filter
pub const HighpassFilter = struct {
    alpha: f32,
    prev_input: f32,
    prev_output: f32,

    pub fn init(cutoff_hz: f32, sample_rate: f32) HighpassFilter {
        const rc = 1.0 / (2.0 * std.math.pi * cutoff_hz);
        const dt = 1.0 / sample_rate;
        return .{
            .alpha = rc / (rc + dt),
            .prev_input = 0.0,
            .prev_output = 0.0,
        };
    }

    pub fn process(self: *HighpassFilter, input: f32) f32 {
        self.prev_output = self.alpha * (self.prev_output + input - self.prev_input);
        self.prev_input = input;
        return self.prev_output;
    }

    pub fn processBuffer(self: *HighpassFilter, buf: []f32) void {
        for (buf) |*s| {
            s.* = self.process(s.*);
        }
    }

    pub fn reset(self: *HighpassFilter) void {
        self.prev_input = 0.0;
        self.prev_output = 0.0;
    }
};

/// Bandpass filter (combination of lowpass and highpass)
pub const BandpassFilter = struct {
    lp: LowpassFilter,
    hp: HighpassFilter,

    pub fn init(low_hz: f32, high_hz: f32, sample_rate: f32) BandpassFilter {
        return .{
            .lp = LowpassFilter.init(high_hz, sample_rate),
            .hp = HighpassFilter.init(low_hz, sample_rate),
        };
    }

    pub fn process(self: *BandpassFilter, input: f32) f32 {
        const lp_out = self.lp.process(input);
        return self.hp.process(lp_out);
    }

    pub fn processBuffer(self: *BandpassFilter, buf: []f32) void {
        self.lp.processBuffer(buf);
        self.hp.processBuffer(buf);
    }
};

test "LowpassFilter reduces high-frequency amplitude" {
    // Create a low-cutoff filter (100 Hz) at 44100 Hz sample rate
    var lpf = LowpassFilter.init(100.0, 44100.0);

    // Feed a high-frequency signal (10000 Hz) and measure steady-state amplitude
    const freq_hz: f32 = 10000.0;
    const sample_rate: f32 = 44100.0;
    var max_out: f32 = 0.0;
    var i: usize = 0;
    while (i < 4410) : (i += 1) {
        const phase = @as(f32, @floatFromInt(i)) * freq_hz / sample_rate;
        const input = @sin(phase * std.math.tau);
        const output = lpf.process(input);
        if (i > 2000) {
            const abs_out = @abs(output);
            if (abs_out > max_out) max_out = abs_out;
        }
    }
    // High-frequency signal should be significantly attenuated
    try std.testing.expect(max_out < 0.1);
}

test "HighpassFilter reduces low-frequency amplitude" {
    // Create a high-cutoff filter (10000 Hz) at 44100 Hz sample rate
    var hpf = HighpassFilter.init(10000.0, 44100.0);

    // Feed a low-frequency signal (100 Hz) and measure steady-state amplitude
    const freq_hz: f32 = 100.0;
    const sample_rate: f32 = 44100.0;
    var max_out: f32 = 0.0;
    var i: usize = 0;
    while (i < 44100) : (i += 1) {
        const phase = @as(f32, @floatFromInt(i)) * freq_hz / sample_rate;
        const input = @sin(phase * std.math.tau);
        const output = hpf.process(input);
        if (i > 22050) {
            const abs_out = @abs(output);
            if (abs_out > max_out) max_out = abs_out;
        }
    }
    // Low-frequency signal should be significantly attenuated
    try std.testing.expect(max_out < 0.1);
}

test "BandpassFilter passes in-band signal" {
    // Bandpass: 400 Hz to 600 Hz, test 500 Hz signal passes
    var bpf = BandpassFilter.init(400.0, 600.0, 44100.0);

    const freq_hz: f32 = 500.0;
    const sample_rate: f32 = 44100.0;
    var max_out: f32 = 0.0;
    var i: usize = 0;
    while (i < 44100) : (i += 1) {
        const phase = @as(f32, @floatFromInt(i)) * freq_hz / sample_rate;
        const input = @sin(phase * std.math.tau);
        const output = bpf.process(input);
        if (i > 22050) {
            const abs_out = @abs(output);
            if (abs_out > max_out) max_out = abs_out;
        }
    }
    // In-band signal should have significant amplitude
    try std.testing.expect(max_out > 0.01);
}

test "LowpassFilter reset clears state" {
    const testing = std.testing;
    var lpf = LowpassFilter.init(1000.0, 44100.0);
    // Process something to build up state
    _ = lpf.process(1.0);
    _ = lpf.process(1.0);
    lpf.reset();
    try testing.expectApproxEqAbs(@as(f32, 0.0), lpf.prev, 0.001);
}

test "HighpassFilter reset clears state" {
    const testing = std.testing;
    var hpf = HighpassFilter.init(1000.0, 44100.0);
    _ = hpf.process(1.0);
    _ = hpf.process(1.0);
    hpf.reset();
    try testing.expectApproxEqAbs(@as(f32, 0.0), hpf.prev_input, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0.0), hpf.prev_output, 0.001);
}
