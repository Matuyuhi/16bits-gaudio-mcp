const std = @import("std");

pub const AdsrConfig = struct {
    attack_ms: f32 = 10.0,
    decay_ms: f32 = 50.0,
    sustain_level: f32 = 0.7,
    release_ms: f32 = 100.0,
};

const Phase = enum {
    attack,
    decay,
    sustain,
    release,
    done,
};

pub const Adsr = struct {
    config: AdsrConfig,
    sample_rate: f32,
    phase: Phase,
    level: f32,
    sample_count: f32,
    attack_samples: f32,
    decay_samples: f32,
    release_samples: f32,
    release_start_level: f32,

    pub fn init(config: AdsrConfig, sample_rate: f32) Adsr {
        return .{
            .config = config,
            .sample_rate = sample_rate,
            .phase = .attack,
            .level = 0.0,
            .sample_count = 0.0,
            .attack_samples = config.attack_ms * sample_rate / 1000.0,
            .decay_samples = config.decay_ms * sample_rate / 1000.0,
            .release_samples = config.release_ms * sample_rate / 1000.0,
            .release_start_level = config.sustain_level,
        };
    }

    pub fn process(self: *Adsr) f32 {
        switch (self.phase) {
            .attack => {
                if (self.attack_samples <= 0) {
                    self.level = 1.0;
                    self.phase = .decay;
                    self.sample_count = 0;
                    return self.level;
                }
                self.level = self.sample_count / self.attack_samples;
                self.sample_count += 1.0;
                if (self.sample_count >= self.attack_samples) {
                    self.level = 1.0;
                    self.phase = .decay;
                    self.sample_count = 0;
                }
                return self.level;
            },
            .decay => {
                if (self.decay_samples <= 0) {
                    self.level = self.config.sustain_level;
                    self.phase = .sustain;
                    return self.level;
                }
                const t = self.sample_count / self.decay_samples;
                self.level = 1.0 - t * (1.0 - self.config.sustain_level);
                self.sample_count += 1.0;
                if (self.sample_count >= self.decay_samples) {
                    self.level = self.config.sustain_level;
                    self.phase = .sustain;
                }
                return self.level;
            },
            .sustain => {
                return self.config.sustain_level;
            },
            .release => {
                if (self.release_samples <= 0) {
                    self.level = 0.0;
                    self.phase = .done;
                    return 0.0;
                }
                const t = self.sample_count / self.release_samples;
                self.level = self.release_start_level * (1.0 - t);
                self.sample_count += 1.0;
                if (self.sample_count >= self.release_samples) {
                    self.level = 0.0;
                    self.phase = .done;
                }
                return self.level;
            },
            .done => {
                return 0.0;
            },
        }
    }

    pub fn noteOff(self: *Adsr) void {
        if (self.phase != .done) {
            self.release_start_level = self.level;
            self.phase = .release;
            self.sample_count = 0;
        }
    }

    pub fn isFinished(self: *const Adsr) bool {
        return self.phase == .done;
    }

    pub fn reset(self: *Adsr) void {
        self.phase = .attack;
        self.level = 0.0;
        self.sample_count = 0.0;
    }
};

/// Generate a full note (attack → decay → sustain for hold_samples, then release)
pub fn generateNote(config: AdsrConfig, sample_rate: f32, hold_samples: usize) []f32 {
    _ = config;
    _ = sample_rate;
    _ = hold_samples;
    // This is a placeholder; actual generation is done inline in generators
    return &[_]f32{};
}
