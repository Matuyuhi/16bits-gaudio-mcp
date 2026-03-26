const std = @import("std");
const oscillator = @import("../oscillator.zig");
const envelope = @import("../envelope.zig");
const sequencer = @import("../sequencer.zig");
const mixer = @import("../mixer.zig");
const effects = @import("../effects.zig");
const filter = @import("../filter.zig");
const fm_mod = @import("../fm.zig");

pub const BgmConfig = struct {
    style: []const u8,
    bpm: f32,
    duration_bars: u32,
    sample_rate: f32 = 44100.0,
    key: []const u8 = "C",
    scale: []const u8 = "major",
    seed: u64 = 42,
};

pub fn generate(allocator: std.mem.Allocator, config: BgmConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const scale = try sequencer.parseScale(config.scale);
    const progression = try sequencer.getChordProgression(config.style);
    const beats_per_bar = sequencer.getBeatsPerBar(config.style);

    const beat_duration = 60.0 / config.bpm; // seconds per beat
    const bar_duration = beat_duration * @as(f32, @floatFromInt(beats_per_bar));
    const total_duration = bar_duration * @as(f32, @floatFromInt(config.duration_bars));
    const total_samples: usize = @intFromFloat(total_duration * config.sample_rate);
    const bar_samples: usize = @intFromFloat(bar_duration * config.sample_rate);
    const beat_samples: usize = @intFromFloat(beat_duration * config.sample_rate);

    // Initialize PRNG
    var prng = std.Random.DefaultPrng.init(config.seed);
    const random = prng.random();

    // Allocate track buffers
    const melody_buf = try allocator.alloc(f32, total_samples);
    defer allocator.free(melody_buf);
    @memset(melody_buf, 0.0);

    const bass_buf = try allocator.alloc(f32, total_samples);
    defer allocator.free(bass_buf);
    @memset(bass_buf, 0.0);

    const harmony_buf = try allocator.alloc(f32, total_samples);
    defer allocator.free(harmony_buf);
    @memset(harmony_buf, 0.0);

    const perc_buf = try allocator.alloc(f32, total_samples);
    defer allocator.free(perc_buf);
    @memset(perc_buf, 0.0);

    // Determine waveforms based on style
    const is_boss = std.mem.eql(u8, config.style, "boss");
    const melody_wf: oscillator.Waveform = if (is_boss) .sawtooth else .sine;
    const harmony_wf: oscillator.Waveform = .square;

    // Generate each bar
    var melody_note: i16 = 4; // Start on 5th scale degree (middle range)
    for (0..config.duration_bars) |bar_idx| {
        const chord_idx = bar_idx % progression.len;
        const chord = progression[chord_idx];
        const chord_tones = sequencer.getChordTones(chord.quality);
        const chord_root: u8 = @intCast(@as(i16, root) + chord.root_semitone);
        const bar_offset = bar_idx * bar_samples;

        // === MELODY TRACK ===
        // Generate one note per 8th note (2 per beat)
        const subdivisions = @as(usize, beats_per_bar) * 2;
        const sub_samples = beat_samples / 2;

        for (0..subdivisions) |sub_idx| {
            const sample_offset = bar_offset + sub_idx * sub_samples;
            if (sample_offset >= total_samples) break;

            // Decide whether to play (70%) or rest (30%)
            if (random.intRangeAtMost(u8, 0, 9) < 3) continue;

            // Choose note: bias toward chord tones on strong beats
            const is_strong_beat = (sub_idx % 2 == 0);
            if (is_strong_beat and random.intRangeAtMost(u8, 0, 9) < 6) {
                // Use a chord tone
                const tone_idx = random.intRangeAtMost(u8, 0, 2);
                const target_semitone: i16 = @as(i16, chord_root) + @as(i16, chord_tones[tone_idx]);
                _ = target_semitone;
                // Map to scale degree
                melody_note = @as(i16, random.intRangeAtMost(u8, 2, 8));
            } else {
                // Step motion: move by 1-2 scale degrees
                const step: i16 = @as(i16, random.intRangeAtMost(u8, 0, 3)) - 1; // -1 to 2
                melody_note += step;
                melody_note = @max(0, @min(12, melody_note));
            }

            const midi = sequencer.scaleNote(root, scale, melody_note, 4);
            const freq = sequencer.midiToHz(midi);
            const note_dur = sub_samples * 3 / 4; // 75% of subdivision

            var phase: f32 = 0.0;
            var env = envelope.Adsr.init(.{
                .attack_ms = 5.0,
                .decay_ms = 30.0,
                .sustain_level = 0.6,
                .release_ms = 40.0,
            }, config.sample_rate);

            for (0..note_dur) |i| {
                if (i == note_dur * 2 / 3) env.noteOff();
                const idx = sample_offset + i;
                if (idx < total_samples) {
                    melody_buf[idx] += oscillator.sample(melody_wf, phase) * env.process() * 0.35;
                }
                phase += freq / config.sample_rate;
                phase -= @floor(phase);
            }
        }

        // === BASS TRACK ===
        // Bass plays root note, one note per beat
        for (0..beats_per_bar) |beat_idx| {
            const sample_offset = bar_offset + beat_idx * beat_samples;
            if (sample_offset >= total_samples) break;

            const bass_midi: u8 = @intCast(@max(0, @min(127, @as(i16, chord_root) + 36))); // Octave 2
            const freq = sequencer.midiToHz(bass_midi);
            const note_dur = beat_samples * 9 / 10;

            var phase: f32 = 0.0;
            var env = envelope.Adsr.init(.{
                .attack_ms = 3.0,
                .decay_ms = 60.0,
                .sustain_level = 0.7,
                .release_ms = 50.0,
            }, config.sample_rate);

            for (0..note_dur) |i| {
                if (i == note_dur * 3 / 4) env.noteOff();
                const idx = sample_offset + i;
                if (idx < total_samples) {
                    bass_buf[idx] += oscillator.sawtooth(phase) * env.process() * 0.25;
                }
                phase += freq / config.sample_rate;
                phase -= @floor(phase);
            }
        }

        // === HARMONY TRACK ===
        // Play chord tones (3rd and 5th), sustained per bar
        {
            const third_midi: u8 = @intCast(@max(0, @min(127, @as(i16, chord_root) + @as(i16, chord_tones[1]) + 60)));
            const fifth_midi: u8 = @intCast(@max(0, @min(127, @as(i16, chord_root) + @as(i16, chord_tones[2]) + 60)));
            const note_dur = bar_samples * 9 / 10;

            // Third
            {
                const freq = sequencer.midiToHz(third_midi);
                var phase: f32 = 0.0;
                var env = envelope.Adsr.init(.{
                    .attack_ms = 20.0,
                    .decay_ms = 100.0,
                    .sustain_level = 0.5,
                    .release_ms = 80.0,
                }, config.sample_rate);

                for (0..note_dur) |i| {
                    if (i == note_dur * 3 / 4) env.noteOff();
                    const idx = bar_offset + i;
                    if (idx < total_samples) {
                        harmony_buf[idx] += oscillator.sample(harmony_wf, phase) * env.process() * 0.12;
                    }
                    phase += freq / config.sample_rate;
                    phase -= @floor(phase);
                }
            }
            // Fifth
            {
                const freq = sequencer.midiToHz(fifth_midi);
                var phase: f32 = 0.0;
                var env = envelope.Adsr.init(.{
                    .attack_ms = 20.0,
                    .decay_ms = 100.0,
                    .sustain_level = 0.5,
                    .release_ms = 80.0,
                }, config.sample_rate);

                for (0..note_dur) |i| {
                    if (i == note_dur * 3 / 4) env.noteOff();
                    const idx = bar_offset + i;
                    if (idx < total_samples) {
                        harmony_buf[idx] += oscillator.sample(harmony_wf, phase) * env.process() * 0.12;
                    }
                    phase += freq / config.sample_rate;
                    phase -= @floor(phase);
                }
            }
        }

        // === PERCUSSION TRACK ===
        for (0..beats_per_bar) |beat_idx| {
            const sample_offset = bar_offset + beat_idx * beat_samples;
            if (sample_offset >= total_samples) break;

            // Kick on beats 1 and 3 (or just 1 for 3/4)
            const play_kick = (beat_idx == 0) or (beats_per_bar == 4 and beat_idx == 2);
            if (play_kick) {
                renderKick(perc_buf, sample_offset, total_samples, config.sample_rate);
            }

            // Snare on beats 2 and 4
            const play_snare = (beats_per_bar == 4 and (beat_idx == 1 or beat_idx == 3));
            if (play_snare) {
                renderSnare(perc_buf, sample_offset, total_samples, config.sample_rate);
            }

            // Hihat on every 8th note
            for (0..2) |sub| {
                const hihat_offset = sample_offset + sub * (beat_samples / 2);
                if (hihat_offset < total_samples) {
                    renderHihat(perc_buf, hihat_offset, total_samples, config.sample_rate);
                }
            }
        }
    }

    // Mix all tracks
    const output = try allocator.alloc(f32, total_samples);
    for (output, 0..) |*s, i| {
        s.* = melody_buf[i] + bass_buf[i] + harmony_buf[i] + perc_buf[i];
    }

    // Crossfade for seamless loop
    const fade_samples: usize = @intFromFloat(config.sample_rate * 0.02); // 20ms
    mixer.crossfade(output, fade_samples);

    // Gentle normalize
    mixer.normalize(output, -3.0);

    return output;
}

fn renderKick(buf: []f32, offset: usize, total_samples: usize, sample_rate: f32) void {
    const dur: usize = @intFromFloat(0.08 * sample_rate);
    var phase: f32 = 0.0;
    for (0..dur) |i| {
        const idx = offset + i;
        if (idx >= total_samples) break;
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(dur));
        // Start at 150Hz, rapid pitch drop to 60Hz (exponential)
        const freq = 60.0 + 90.0 * std.math.pow(f32, 1.0 - t, 3.0);
        const env_val = std.math.pow(f32, 1.0 - t, 2.0);
        buf[idx] += @sin(phase * std.math.tau) * env_val * 0.35;
        phase += freq / sample_rate;
        phase -= @floor(phase);
    }
}

fn renderSnare(buf: []f32, offset: usize, total_samples: usize, sample_rate: f32) void {
    const dur: usize = @intFromFloat(0.06 * sample_rate);
    var bp = filter.BandpassFilter.init(200.0, 2000.0, sample_rate);
    var phase: f32 = 0.0;
    for (0..dur) |i| {
        const idx = offset + i;
        if (idx >= total_samples) break;
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(dur));
        const env_val = std.math.pow(f32, 1.0 - t, 3.0);
        // Mix: bandpass noise + sine at 200Hz
        const noise_val = bp.process(oscillator.noise());
        const sine_val = @sin(phase * std.math.tau);
        buf[idx] += (noise_val * 0.6 + sine_val * 0.4) * env_val * 0.2;
        phase += 200.0 / sample_rate;
        phase -= @floor(phase);
    }
}

fn renderHihat(buf: []f32, offset: usize, total_samples: usize, sample_rate: f32) void {
    const dur: usize = @intFromFloat(0.02 * sample_rate);
    var hp = filter.HighpassFilter.init(6000.0, sample_rate);
    for (0..dur) |i| {
        const idx = offset + i;
        if (idx >= total_samples) break;
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(dur));
        const env_val = std.math.pow(f32, 1.0 - t, 5.0);
        buf[idx] += hp.process(oscillator.noise()) * env_val * 0.1;
    }
}
