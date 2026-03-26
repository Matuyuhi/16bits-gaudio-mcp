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
    for (buf) |*sample| {
        const dry = sample.*;

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
        sample.* = dry * (1.0 - wet) + ap_out * wet;
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

    for (buf) |*sample| {
        const delayed = delay_buf[write_idx];
        const new_val = sample.* + delayed * feedback;
        delay_buf[write_idx] = new_val;
        sample.* = sample.* * (1.0 - wet) + delayed * wet;
        write_idx = (write_idx + 1) % delay_samples;
    }
}
