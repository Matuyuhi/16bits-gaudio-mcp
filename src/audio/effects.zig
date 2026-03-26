const std = @import("std");

/// Comb filter for Schroeder reverb
const CombFilter = struct {
    buffer: []f32,
    index: usize,
    feedback: f32,

    fn init(allocator: std.mem.Allocator, delay_samples: usize, feedback: f32) !CombFilter {
        const buf = try allocator.alloc(f32, delay_samples);
        @memset(buf, 0.0);
        return .{
            .buffer = buf,
            .index = 0,
            .feedback = feedback,
        };
    }

    fn deinit(self: *CombFilter, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    fn process(self: *CombFilter, input: f32) f32 {
        const output = self.buffer[self.index];
        self.buffer[self.index] = input + output * self.feedback;
        self.index = (self.index + 1) % self.buffer.len;
        return output;
    }
};

/// Allpass filter for Schroeder reverb
const AllpassFilter = struct {
    buffer: []f32,
    index: usize,
    feedback: f32,

    fn init(allocator: std.mem.Allocator, delay_samples: usize, feedback: f32) !AllpassFilter {
        const buf = try allocator.alloc(f32, delay_samples);
        @memset(buf, 0.0);
        return .{
            .buffer = buf,
            .index = 0,
            .feedback = feedback,
        };
    }

    fn deinit(self: *AllpassFilter, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    fn process(self: *AllpassFilter, input: f32) f32 {
        const buffered = self.buffer[self.index];
        const temp = input + buffered * self.feedback;
        self.buffer[self.index] = temp;
        self.index = (self.index + 1) % self.buffer.len;
        return buffered - input * self.feedback;
    }
};

/// Schroeder reverb: 4 parallel comb filters + 2 serial allpass filters
pub fn applyReverb(allocator: std.mem.Allocator, buf: []f32, room_size: f32, wet: f32) !void {
    // Comb filter delay lengths (in samples)
    const comb_delays = [_]usize{ 1557, 1617, 1491, 1422 };
    // Allpass filter delay lengths
    const allpass_delays = [_]usize{ 225, 556 };

    // Feedback coefficient scaled by room_size: 0.7 ~ 0.9
    const feedback = 0.7 + room_size * 0.2;
    const allpass_feedback: f32 = 0.7;

    // Initialize filters
    var combs: [4]CombFilter = undefined;
    for (&combs, 0..) |*comb, i| {
        comb.* = try CombFilter.init(allocator, comb_delays[i], feedback);
    }
    defer for (&combs) |*comb| {
        comb.deinit(allocator);
    };

    var allpasses: [2]AllpassFilter = undefined;
    for (&allpasses, 0..) |*ap, i| {
        ap.* = try AllpassFilter.init(allocator, allpass_delays[i], allpass_feedback);
    }
    defer for (&allpasses) |*ap| {
        ap.deinit(allocator);
    };

    // Process each sample
    for (buf) |*s| {
        const dry = s.*;

        // Sum of 4 parallel comb filters
        var comb_sum: f32 = 0.0;
        for (&combs) |*comb| {
            comb_sum += comb.process(dry);
        }
        comb_sum *= 0.25; // Average

        // Serial allpass filters
        var ap_out = comb_sum;
        for (&allpasses) |*ap| {
            ap_out = ap.process(ap_out);
        }

        // Mix wet/dry
        s.* = dry * (1.0 - wet) + ap_out * wet;
    }
}

/// Delay effect
pub fn applyDelay(allocator: std.mem.Allocator, buf: []f32, delay_ms: f32, feedback: f32, wet: f32, sample_rate: f32) !void {
    const delay_samples: usize = @intFromFloat(delay_ms * sample_rate / 1000.0);
    if (delay_samples == 0) return;

    const delay_buf = try allocator.alloc(f32, delay_samples);
    defer allocator.free(delay_buf);
    @memset(delay_buf, 0.0);

    var write_idx: usize = 0;

    for (buf) |*s| {
        const delayed = delay_buf[write_idx];
        const new_val = s.* + delayed * feedback;
        delay_buf[write_idx] = new_val;
        s.* = s.* * (1.0 - wet) + delayed * wet;
        write_idx = (write_idx + 1) % delay_samples;
    }
}

/// Chorus effect: modulated short delay for width and shimmer
pub fn applyChorus(allocator: std.mem.Allocator, buf: []f32, depth: f32, rate: f32, wet: f32, sample_rate: f32) !void {
    // Max delay ~25ms for chorus range
    const max_delay_samples: usize = @intFromFloat(0.025 * sample_rate);
    const center_delay: f32 = @as(f32, @floatFromInt(max_delay_samples)) * 0.5;
    const mod_depth: f32 = center_delay * depth;

    const delay_buf = try allocator.alloc(f32, max_delay_samples);
    defer allocator.free(delay_buf);
    @memset(delay_buf, 0.0);

    var write_idx: usize = 0;
    var lfo_phase: f32 = 0.0;
    const lfo_inc: f32 = rate / sample_rate;

    for (buf) |*s| {
        // Write current sample into delay buffer
        delay_buf[write_idx] = s.*;

        // LFO modulates the read position
        const lfo = @sin(lfo_phase * std.math.tau);
        const delay_f = center_delay + lfo * mod_depth;
        const delay_int: usize = @intFromFloat(@max(0.0, @min(delay_f, @as(f32, @floatFromInt(max_delay_samples - 1)))));
        const read_idx = (write_idx + max_delay_samples - delay_int) % max_delay_samples;

        const delayed = delay_buf[read_idx];
        s.* = s.* * (1.0 - wet) + delayed * wet;

        write_idx = (write_idx + 1) % max_delay_samples;
        lfo_phase += lfo_inc;
        lfo_phase -= @floor(lfo_phase);
    }
}

/// Distortion / overdrive effect: soft-clipping via tanh
pub fn applyDistortion(buf: []f32, drive: f32, wet: f32) void {
    const gain = 1.0 + drive * 20.0; // drive 0..1 maps to 1x..21x gain
    for (buf) |*s| {
        const dry = s.*;
        // Soft clip using approximated tanh
        const x = dry * gain;
        const clipped = tanhApprox(x);
        s.* = dry * (1.0 - wet) + clipped * wet;
    }
}

fn tanhApprox(x: f32) f32 {
    // Padé approximant for tanh: fast and smooth
    if (x > 3.0) return 1.0;
    if (x < -3.0) return -1.0;
    const x2 = x * x;
    return x * (27.0 + x2) / (27.0 + 9.0 * x2);
}

/// Bitcrusher: reduce bit depth and sample rate for retro lo-fi sound
pub fn applyBitcrusher(buf: []f32, bit_depth: f32, downsample: f32) void {
    // bit_depth: 1..16 (lower = more crushed)
    // downsample: 1..64 (higher = more crushed)
    const bits = @max(1.0, @min(16.0, bit_depth));
    const levels = std.math.pow(f32, 2.0, bits);
    const step: f32 = @max(1.0, @min(64.0, downsample));

    var hold: f32 = 0.0;
    var counter: f32 = 0.0;

    for (buf) |*s| {
        counter += 1.0;
        if (counter >= step) {
            counter -= step;
            // Quantize to reduced bit depth
            hold = @round(s.* * levels) / levels;
        }
        s.* = hold;
    }
}

/// Tremolo: amplitude modulation via LFO
pub fn applyTremolo(buf: []f32, rate: f32, depth: f32, sample_rate: f32) void {
    var phase: f32 = 0.0;
    const inc: f32 = rate / sample_rate;

    for (buf) |*s| {
        // LFO oscillates between (1-depth) and 1
        const lfo = (1.0 - depth) + depth * (0.5 + 0.5 * @sin(phase * std.math.tau));
        s.* *= lfo;
        phase += inc;
        phase -= @floor(phase);
    }
}
