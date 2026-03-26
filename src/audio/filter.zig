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
