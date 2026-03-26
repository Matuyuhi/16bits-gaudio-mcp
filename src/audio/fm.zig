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
