const std = @import("std");
const envelope = @import("envelope.zig");

pub const FmConfig = struct {
    carrier_freq: f32,
    modulator_ratio: f32,
    modulation_index: f32,
    carrier_adsr: envelope.AdsrConfig,
    modulator_adsr: envelope.AdsrConfig,
    duration_ms: f32,
    sample_rate: f32,
};

/// Generate an FM synthesis tone (2-operator: carrier + modulator, YM2612-style)
pub fn generate(allocator: std.mem.Allocator, config: FmConfig) ![]f32 {
    const total_samples: usize = @intFromFloat(config.duration_ms * config.sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total_samples);
    errdefer allocator.free(buf);

    var carrier_phase: f32 = 0.0;
    var mod_phase: f32 = 0.0;

    var carrier_env = envelope.Adsr.init(config.carrier_adsr, config.sample_rate);
    var mod_env = envelope.Adsr.init(config.modulator_adsr, config.sample_rate);

    const mod_freq = config.carrier_freq * config.modulator_ratio;

    // Calculate when to trigger release (80% of duration for sustain, then release)
    const sustain_end: usize = @intFromFloat(config.duration_ms * 0.7 * config.sample_rate / 1000.0);

    for (buf, 0..) |*s, i| {
        if (i == sustain_end) {
            carrier_env.noteOff();
            mod_env.noteOff();
        }

        const mod_env_val = mod_env.process();
        const carrier_env_val = carrier_env.process();

        // Modulator output
        const mod_out = mod_env_val * @sin(mod_phase * std.math.tau);

        // Carrier with FM: freq is modulated by modulator output
        const carrier_out = @sin(carrier_phase * std.math.tau);

        s.* = carrier_env_val * carrier_out;

        // Advance phases
        const mod_contribution = config.modulation_index * mod_out;
        carrier_phase += (config.carrier_freq + mod_contribution * config.carrier_freq) / config.sample_rate;
        carrier_phase -= @floor(carrier_phase);

        mod_phase += mod_freq / config.sample_rate;
        mod_phase -= @floor(mod_phase);
    }

    return buf;
}

test "FM synthesis produces non-silent output" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const config = FmConfig{
        .carrier_freq = 440.0,
        .modulator_ratio = 2.0,
        .modulation_index = 1.0,
        .carrier_adsr = .{},
        .modulator_adsr = .{},
        .duration_ms = 100.0,
        .sample_rate = 44100.0,
    };

    const samples = try generate(allocator, config);
    defer allocator.free(samples);

    var any_nonzero = false;
    for (samples) |s| {
        if (@abs(s) > 0.01) {
            any_nonzero = true;
            break;
        }
    }
    try testing.expect(any_nonzero);
}

test "FM modulation index affects timbre" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const config_pure = FmConfig{
        .carrier_freq = 440.0,
        .modulator_ratio = 2.0,
        .modulation_index = 0.0,
        .carrier_adsr = .{},
        .modulator_adsr = .{},
        .duration_ms = 100.0,
        .sample_rate = 44100.0,
    };

    const config_modulated = FmConfig{
        .carrier_freq = 440.0,
        .modulator_ratio = 2.0,
        .modulation_index = 5.0,
        .carrier_adsr = .{},
        .modulator_adsr = .{},
        .duration_ms = 100.0,
        .sample_rate = 44100.0,
    };

    const samples_pure = try generate(allocator, config_pure);
    defer allocator.free(samples_pure);

    const samples_modulated = try generate(allocator, config_modulated);
    defer allocator.free(samples_modulated);

    // The two signals should differ at sample index 1000
    const diff = @abs(samples_pure[1000] - samples_modulated[1000]);
    try testing.expect(diff > 0.01);
}

test "FM synthesis output is within range" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const config = FmConfig{
        .carrier_freq = 440.0,
        .modulator_ratio = 2.0,
        .modulation_index = 3.0,
        .carrier_adsr = .{},
        .modulator_adsr = .{},
        .duration_ms = 200.0,
        .sample_rate = 44100.0,
    };

    const samples = try generate(allocator, config);
    defer allocator.free(samples);

    for (samples) |s| {
        try testing.expect(s >= -1.5 and s <= 1.5);
    }
}
