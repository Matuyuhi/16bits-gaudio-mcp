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
    custom_chords: ?[]const sequencer.ChordInfo = null,
    melody_density_override: ?u8 = null,
    swing_override: ?f32 = null,
};

/// Per-style generation parameters that vary timbre, rhythm, and feel
const StyleParams = struct {
    melody_wf: oscillator.Waveform,
    harmony_wf: oscillator.Waveform,
    bass_wf: oscillator.Waveform,
    melody_oct: u8,
    bass_oct: u8,
    melody_vol: f32,
    bass_vol: f32,
    harmony_vol: f32,
    perc_vol: f32,
    melody_density: u8, // 0-10: how many subdivisions play (out of 10)
    swing: f32, // 0.0 = straight, 0.3 = swing feel
    use_kick: bool,
    use_snare: bool,
    use_hihat: bool,
    use_rim: bool,
    use_shaker: bool,
    melody_adsr: envelope.AdsrConfig,
    bass_adsr: envelope.AdsrConfig,
    reverb_room: f32,
    reverb_wet: f32,
};

fn getStyleParams(style: []const u8) StyleParams {
    if (std.mem.eql(u8, style, "adventure")) return .{
        .melody_wf = .sine,
        .harmony_wf = .square,
        .bass_wf = .sawtooth,
        .melody_oct = 4,
        .bass_oct = 2,
        .melody_vol = 0.35,
        .bass_vol = 0.25,
        .harmony_vol = 0.12,
        .perc_vol = 1.0,
        .melody_density = 7,
        .swing = 0.0,
        .use_kick = true,
        .use_snare = true,
        .use_hihat = true,
        .use_rim = false,
        .use_shaker = false,
        .melody_adsr = .{ .attack_ms = 5.0, .decay_ms = 30.0, .sustain_level = 0.6, .release_ms = 40.0 },
        .bass_adsr = .{ .attack_ms = 3.0, .decay_ms = 60.0, .sustain_level = 0.7, .release_ms = 50.0 },
        .reverb_room = 0.3,
        .reverb_wet = 0.15,
    };
    if (std.mem.eql(u8, style, "dungeon")) return .{
        .melody_wf = .triangle,
        .harmony_wf = .square,
        .bass_wf = .sawtooth,
        .melody_oct = 4,
        .bass_oct = 2,
        .melody_vol = 0.30,
        .bass_vol = 0.28,
        .harmony_vol = 0.10,
        .perc_vol = 0.8,
        .melody_density = 5,
        .swing = 0.0,
        .use_kick = true,
        .use_snare = false,
        .use_hihat = true,
        .use_rim = true,
        .use_shaker = false,
        .melody_adsr = .{ .attack_ms = 10.0, .decay_ms = 50.0, .sustain_level = 0.5, .release_ms = 80.0 },
        .bass_adsr = .{ .attack_ms = 5.0, .decay_ms = 80.0, .sustain_level = 0.6, .release_ms = 60.0 },
        .reverb_room = 0.7,
        .reverb_wet = 0.35,
    };
    if (std.mem.eql(u8, style, "boss")) return .{
        .melody_wf = .sawtooth,
        .harmony_wf = .square,
        .bass_wf = .square,
        .melody_oct = 4,
        .bass_oct = 2,
        .melody_vol = 0.40,
        .bass_vol = 0.30,
        .harmony_vol = 0.15,
        .perc_vol = 1.2,
        .melody_density = 8,
        .swing = 0.0,
        .use_kick = true,
        .use_snare = true,
        .use_hihat = true,
        .use_rim = false,
        .use_shaker = false,
        .melody_adsr = .{ .attack_ms = 3.0, .decay_ms = 20.0, .sustain_level = 0.7, .release_ms = 30.0 },
        .bass_adsr = .{ .attack_ms = 2.0, .decay_ms = 40.0, .sustain_level = 0.8, .release_ms = 30.0 },
        .reverb_room = 0.4,
        .reverb_wet = 0.2,
    };
    if (std.mem.eql(u8, style, "town")) return .{
        .melody_wf = .sine,
        .harmony_wf = .triangle,
        .bass_wf = .sine,
        .melody_oct = 5,
        .bass_oct = 3,
        .melody_vol = 0.35,
        .bass_vol = 0.20,
        .harmony_vol = 0.10,
        .perc_vol = 0.5,
        .melody_density = 6,
        .swing = 0.2,
        .use_kick = true,
        .use_snare = false,
        .use_hihat = false,
        .use_rim = false,
        .use_shaker = true,
        .melody_adsr = .{ .attack_ms = 8.0, .decay_ms = 40.0, .sustain_level = 0.5, .release_ms = 60.0 },
        .bass_adsr = .{ .attack_ms = 5.0, .decay_ms = 70.0, .sustain_level = 0.5, .release_ms = 80.0 },
        .reverb_room = 0.5,
        .reverb_wet = 0.25,
    };
    if (std.mem.eql(u8, style, "battle")) return .{
        .melody_wf = .sawtooth,
        .harmony_wf = .pulse,
        .bass_wf = .sawtooth,
        .melody_oct = 4,
        .bass_oct = 2,
        .melody_vol = 0.38,
        .bass_vol = 0.30,
        .harmony_vol = 0.13,
        .perc_vol = 1.1,
        .melody_density = 8,
        .swing = 0.0,
        .use_kick = true,
        .use_snare = true,
        .use_hihat = true,
        .use_rim = false,
        .use_shaker = false,
        .melody_adsr = .{ .attack_ms = 3.0, .decay_ms = 25.0, .sustain_level = 0.65, .release_ms = 35.0 },
        .bass_adsr = .{ .attack_ms = 2.0, .decay_ms = 50.0, .sustain_level = 0.75, .release_ms = 40.0 },
        .reverb_room = 0.3,
        .reverb_wet = 0.15,
    };
    if (std.mem.eql(u8, style, "field")) return .{
        .melody_wf = .sine,
        .harmony_wf = .triangle,
        .bass_wf = .sine,
        .melody_oct = 5,
        .bass_oct = 3,
        .melody_vol = 0.30,
        .bass_vol = 0.18,
        .harmony_vol = 0.10,
        .perc_vol = 0.4,
        .melody_density = 5,
        .swing = 0.15,
        .use_kick = false,
        .use_snare = false,
        .use_hihat = false,
        .use_rim = false,
        .use_shaker = true,
        .melody_adsr = .{ .attack_ms = 15.0, .decay_ms = 60.0, .sustain_level = 0.5, .release_ms = 100.0 },
        .bass_adsr = .{ .attack_ms = 10.0, .decay_ms = 80.0, .sustain_level = 0.4, .release_ms = 120.0 },
        .reverb_room = 0.6,
        .reverb_wet = 0.3,
    };
    if (std.mem.eql(u8, style, "puzzle")) return .{
        .melody_wf = .square,
        .harmony_wf = .sine,
        .bass_wf = .triangle,
        .melody_oct = 5,
        .bass_oct = 3,
        .melody_vol = 0.25,
        .bass_vol = 0.18,
        .harmony_vol = 0.08,
        .perc_vol = 0.6,
        .melody_density = 6,
        .swing = 0.1,
        .use_kick = false,
        .use_snare = false,
        .use_hihat = true,
        .use_rim = true,
        .use_shaker = false,
        .melody_adsr = .{ .attack_ms = 3.0, .decay_ms = 40.0, .sustain_level = 0.4, .release_ms = 50.0 },
        .bass_adsr = .{ .attack_ms = 5.0, .decay_ms = 60.0, .sustain_level = 0.5, .release_ms = 70.0 },
        .reverb_room = 0.4,
        .reverb_wet = 0.2,
    };
    if (std.mem.eql(u8, style, "menu")) return .{
        .melody_wf = .sine,
        .harmony_wf = .sine,
        .bass_wf = .sine,
        .melody_oct = 5,
        .bass_oct = 3,
        .melody_vol = 0.25,
        .bass_vol = 0.15,
        .harmony_vol = 0.08,
        .perc_vol = 0.3,
        .melody_density = 4,
        .swing = 0.0,
        .use_kick = false,
        .use_snare = false,
        .use_hihat = false,
        .use_rim = false,
        .use_shaker = true,
        .melody_adsr = .{ .attack_ms = 20.0, .decay_ms = 80.0, .sustain_level = 0.4, .release_ms = 150.0 },
        .bass_adsr = .{ .attack_ms = 15.0, .decay_ms = 100.0, .sustain_level = 0.3, .release_ms = 200.0 },
        .reverb_room = 0.6,
        .reverb_wet = 0.3,
    };
    if (std.mem.eql(u8, style, "horror")) return .{
        .melody_wf = .triangle,
        .harmony_wf = .sawtooth,
        .bass_wf = .sine,
        .melody_oct = 4,
        .bass_oct = 1,
        .melody_vol = 0.22,
        .bass_vol = 0.25,
        .harmony_vol = 0.15,
        .perc_vol = 0.4,
        .melody_density = 3,
        .swing = 0.0,
        .use_kick = false,
        .use_snare = false,
        .use_hihat = false,
        .use_rim = true,
        .use_shaker = false,
        .melody_adsr = .{ .attack_ms = 30.0, .decay_ms = 100.0, .sustain_level = 0.4, .release_ms = 200.0 },
        .bass_adsr = .{ .attack_ms = 20.0, .decay_ms = 150.0, .sustain_level = 0.5, .release_ms = 300.0 },
        .reverb_room = 0.9,
        .reverb_wet = 0.5,
    };
    if (std.mem.eql(u8, style, "space")) return .{
        .melody_wf = .sine,
        .harmony_wf = .sine,
        .bass_wf = .triangle,
        .melody_oct = 5,
        .bass_oct = 2,
        .melody_vol = 0.28,
        .bass_vol = 0.18,
        .harmony_vol = 0.12,
        .perc_vol = 0.3,
        .melody_density = 4,
        .swing = 0.0,
        .use_kick = false,
        .use_snare = false,
        .use_hihat = true,
        .use_rim = false,
        .use_shaker = false,
        .melody_adsr = .{ .attack_ms = 40.0, .decay_ms = 120.0, .sustain_level = 0.5, .release_ms = 250.0 },
        .bass_adsr = .{ .attack_ms = 30.0, .decay_ms = 100.0, .sustain_level = 0.4, .release_ms = 200.0 },
        .reverb_room = 0.9,
        .reverb_wet = 0.45,
    };
    if (std.mem.eql(u8, style, "shop")) return .{
        .melody_wf = .square,
        .harmony_wf = .triangle,
        .bass_wf = .sine,
        .melody_oct = 5,
        .bass_oct = 3,
        .melody_vol = 0.30,
        .bass_vol = 0.20,
        .harmony_vol = 0.10,
        .perc_vol = 0.6,
        .melody_density = 7,
        .swing = 0.25,
        .use_kick = true,
        .use_snare = false,
        .use_hihat = false,
        .use_rim = false,
        .use_shaker = true,
        .melody_adsr = .{ .attack_ms = 3.0, .decay_ms = 30.0, .sustain_level = 0.5, .release_ms = 40.0 },
        .bass_adsr = .{ .attack_ms = 5.0, .decay_ms = 50.0, .sustain_level = 0.5, .release_ms = 60.0 },
        .reverb_room = 0.3,
        .reverb_wet = 0.15,
    };
    if (std.mem.eql(u8, style, "castle")) return .{
        .melody_wf = .triangle,
        .harmony_wf = .square,
        .bass_wf = .sawtooth,
        .melody_oct = 4,
        .bass_oct = 2,
        .melody_vol = 0.32,
        .bass_vol = 0.25,
        .harmony_vol = 0.13,
        .perc_vol = 0.8,
        .melody_density = 6,
        .swing = 0.0,
        .use_kick = true,
        .use_snare = true,
        .use_hihat = false,
        .use_rim = true,
        .use_shaker = false,
        .melody_adsr = .{ .attack_ms = 8.0, .decay_ms = 50.0, .sustain_level = 0.55, .release_ms = 70.0 },
        .bass_adsr = .{ .attack_ms = 5.0, .decay_ms = 70.0, .sustain_level = 0.6, .release_ms = 50.0 },
        .reverb_room = 0.7,
        .reverb_wet = 0.3,
    };
    if (std.mem.eql(u8, style, "underwater")) return .{
        .melody_wf = .sine,
        .harmony_wf = .sine,
        .bass_wf = .sine,
        .melody_oct = 4,
        .bass_oct = 2,
        .melody_vol = 0.25,
        .bass_vol = 0.18,
        .harmony_vol = 0.10,
        .perc_vol = 0.2,
        .melody_density = 4,
        .swing = 0.0,
        .use_kick = false,
        .use_snare = false,
        .use_hihat = false,
        .use_rim = false,
        .use_shaker = true,
        .melody_adsr = .{ .attack_ms = 50.0, .decay_ms = 150.0, .sustain_level = 0.4, .release_ms = 300.0 },
        .bass_adsr = .{ .attack_ms = 40.0, .decay_ms = 120.0, .sustain_level = 0.3, .release_ms = 250.0 },
        .reverb_room = 0.95,
        .reverb_wet = 0.5,
    };
    if (std.mem.eql(u8, style, "forest")) return .{
        .melody_wf = .sine,
        .harmony_wf = .triangle,
        .bass_wf = .sine,
        .melody_oct = 5,
        .bass_oct = 3,
        .melody_vol = 0.28,
        .bass_vol = 0.16,
        .harmony_vol = 0.09,
        .perc_vol = 0.3,
        .melody_density = 5,
        .swing = 0.2,
        .use_kick = false,
        .use_snare = false,
        .use_hihat = false,
        .use_rim = false,
        .use_shaker = true,
        .melody_adsr = .{ .attack_ms = 20.0, .decay_ms = 80.0, .sustain_level = 0.45, .release_ms = 120.0 },
        .bass_adsr = .{ .attack_ms = 15.0, .decay_ms = 90.0, .sustain_level = 0.4, .release_ms = 150.0 },
        .reverb_room = 0.7,
        .reverb_wet = 0.35,
    };
    if (std.mem.eql(u8, style, "cyber")) return .{
        .melody_wf = .pulse,
        .harmony_wf = .sawtooth,
        .bass_wf = .square,
        .melody_oct = 4,
        .bass_oct = 2,
        .melody_vol = 0.35,
        .bass_vol = 0.30,
        .harmony_vol = 0.12,
        .perc_vol = 1.0,
        .melody_density = 8,
        .swing = 0.0,
        .use_kick = true,
        .use_snare = true,
        .use_hihat = true,
        .use_rim = false,
        .use_shaker = false,
        .melody_adsr = .{ .attack_ms = 2.0, .decay_ms = 15.0, .sustain_level = 0.7, .release_ms = 20.0 },
        .bass_adsr = .{ .attack_ms = 2.0, .decay_ms = 30.0, .sustain_level = 0.8, .release_ms = 25.0 },
        .reverb_room = 0.3,
        .reverb_wet = 0.15,
    };
    // Fallback to adventure
    return .{
        .melody_wf = .sine,
        .harmony_wf = .square,
        .bass_wf = .sawtooth,
        .melody_oct = 4,
        .bass_oct = 2,
        .melody_vol = 0.35,
        .bass_vol = 0.25,
        .harmony_vol = 0.12,
        .perc_vol = 1.0,
        .melody_density = 7,
        .swing = 0.0,
        .use_kick = true,
        .use_snare = true,
        .use_hihat = true,
        .use_rim = false,
        .use_shaker = false,
        .melody_adsr = .{ .attack_ms = 5.0, .decay_ms = 30.0, .sustain_level = 0.6, .release_ms = 40.0 },
        .bass_adsr = .{ .attack_ms = 3.0, .decay_ms = 60.0, .sustain_level = 0.7, .release_ms = 50.0 },
        .reverb_room = 0.3,
        .reverb_wet = 0.15,
    };
}

pub fn generate(allocator: std.mem.Allocator, config: BgmConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const scale = try sequencer.parseScale(config.scale);
    const progression = config.custom_chords orelse try sequencer.getChordProgression(config.style);
    const beats_per_bar = sequencer.getBeatsPerBar(config.style);
    var sp = getStyleParams(config.style);
    if (config.melody_density_override) |md| sp.melody_density = md;
    if (config.swing_override) |sw| sp.swing = sw;

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

    // Generate each bar
    var melody_note: i16 = 4; // Start on 5th scale degree (middle range)
    for (0..config.duration_bars) |bar_idx| {
        const chord_idx = bar_idx % progression.len;
        const chord = progression[chord_idx];
        const chord_tones = sequencer.getChordTones(chord.quality);
        const chord_root: u8 = @intCast(@as(i16, root) + chord.root_semitone);
        const bar_offset = bar_idx * bar_samples;

        // === MELODY TRACK ===
        const subdivisions = @as(usize, beats_per_bar) * 2;
        const sub_samples = beat_samples / 2;

        for (0..subdivisions) |sub_idx| {
            // Apply swing to even subdivisions
            const swing_offset: usize = if (sub_idx % 2 == 1)
                @intFromFloat(sp.swing * @as(f32, @floatFromInt(sub_samples)))
            else
                0;
            const sample_offset = bar_offset + sub_idx * sub_samples + swing_offset;
            if (sample_offset >= total_samples) break;

            // Density check: play or rest
            if (random.intRangeAtMost(u8, 0, 9) >= sp.melody_density) continue;

            // Choose note: bias toward chord tones on strong beats
            const is_strong_beat = (sub_idx % 2 == 0);
            if (is_strong_beat and random.intRangeAtMost(u8, 0, 9) < 6) {
                const tone_idx = random.intRangeAtMost(u8, 0, @as(u8, @intCast(@min(chord_tones.len, 3) - 1)));
                _ = chord_tones[tone_idx];
                melody_note = @as(i16, random.intRangeAtMost(u8, 2, 8));
            } else {
                const step: i16 = @as(i16, random.intRangeAtMost(u8, 0, 3)) - 1;
                melody_note += step;
                melody_note = @max(0, @min(12, melody_note));
            }

            const midi = sequencer.scaleNote(root, scale, melody_note, sp.melody_oct);
            const freq = sequencer.midiToHz(midi);
            const note_dur = sub_samples * 3 / 4;

            var phase: f32 = 0.0;
            var env = envelope.Adsr.init(sp.melody_adsr, config.sample_rate);

            for (0..note_dur) |i| {
                if (i == note_dur * 2 / 3) env.noteOff();
                const idx = sample_offset + i;
                if (idx < total_samples) {
                    melody_buf[idx] += oscillator.sample(sp.melody_wf, phase) * env.process() * sp.melody_vol;
                }
                phase += freq / config.sample_rate;
                phase -= @floor(phase);
            }
        }

        // === BASS TRACK ===
        for (0..beats_per_bar) |beat_idx| {
            const sample_offset = bar_offset + beat_idx * beat_samples;
            if (sample_offset >= total_samples) break;

            const bass_midi: u8 = @intCast(@max(0, @min(127, @as(i16, chord_root) + @as(i16, sp.bass_oct) * 12 + 12)));
            const freq = sequencer.midiToHz(bass_midi);
            const note_dur = beat_samples * 9 / 10;

            var phase: f32 = 0.0;
            var env = envelope.Adsr.init(sp.bass_adsr, config.sample_rate);

            for (0..note_dur) |i| {
                if (i == note_dur * 3 / 4) env.noteOff();
                const idx = sample_offset + i;
                if (idx < total_samples) {
                    bass_buf[idx] += oscillator.sample(sp.bass_wf, phase) * env.process() * sp.bass_vol;
                }
                phase += freq / config.sample_rate;
                phase -= @floor(phase);
            }
        }

        // === HARMONY TRACK ===
        {
            const note_dur = bar_samples * 9 / 10;
            // Render up to 4 chord tones
            for (0..@min(chord_tones.len, 4)) |ct_idx| {
                const tone_midi: u8 = @intCast(@max(0, @min(127, @as(i16, chord_root) + @as(i16, chord_tones[ct_idx]) + 60)));
                const freq = sequencer.midiToHz(tone_midi);
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
                        harmony_buf[idx] += oscillator.sample(sp.harmony_wf, phase) * env.process() * sp.harmony_vol;
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

            // Kick
            if (sp.use_kick) {
                const play_kick = (beat_idx == 0) or (beats_per_bar == 4 and beat_idx == 2);
                if (play_kick) {
                    renderKick(perc_buf, sample_offset, total_samples, config.sample_rate, sp.perc_vol);
                }
            }

            // Snare
            if (sp.use_snare) {
                const play_snare = (beats_per_bar >= 4 and (beat_idx == 1 or beat_idx == 3));
                if (play_snare) {
                    renderSnare(perc_buf, sample_offset, total_samples, config.sample_rate, sp.perc_vol);
                }
            }

            // Rim click (on off-beats for styles that use it)
            if (sp.use_rim) {
                if (beat_idx % 2 == 1) {
                    renderRim(perc_buf, sample_offset, total_samples, config.sample_rate, sp.perc_vol);
                }
            }

            // Hihat on every 8th note
            if (sp.use_hihat) {
                for (0..2) |sub| {
                    const hihat_offset = sample_offset + sub * (beat_samples / 2);
                    if (hihat_offset < total_samples) {
                        renderHihat(perc_buf, hihat_offset, total_samples, config.sample_rate, sp.perc_vol);
                    }
                }
            }

            // Shaker (gentle, every 16th note)
            if (sp.use_shaker) {
                for (0..4) |sub| {
                    const shaker_offset = sample_offset + sub * (beat_samples / 4);
                    if (shaker_offset < total_samples) {
                        renderShaker(perc_buf, shaker_offset, total_samples, config.sample_rate, sp.perc_vol);
                    }
                }
            }
        }
    }

    // Mix all tracks
    const output = try allocator.alloc(f32, total_samples);
    for (output, 0..) |*s, i| {
        s.* = melody_buf[i] + bass_buf[i] + harmony_buf[i] + perc_buf[i];
    }

    // Apply style-specific reverb
    if (sp.reverb_wet > 0.0) {
        try effects.applyReverb(allocator, output, sp.reverb_room, sp.reverb_wet);
    }

    // Crossfade for seamless loop
    const fade_samples: usize = @intFromFloat(config.sample_rate * 0.02); // 20ms
    mixer.crossfade(output, fade_samples);

    // Gentle normalize
    mixer.normalize(output, -3.0);

    return output;
}

fn renderKick(buf: []f32, offset: usize, total_samples: usize, sample_rate: f32, vol: f32) void {
    const dur: usize = @intFromFloat(0.08 * sample_rate);
    var phase: f32 = 0.0;
    for (0..dur) |i| {
        const idx = offset + i;
        if (idx >= total_samples) break;
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(dur));
        const freq = 60.0 + 90.0 * std.math.pow(f32, 1.0 - t, 3.0);
        const env_val = std.math.pow(f32, 1.0 - t, 2.0);
        buf[idx] += @sin(phase * std.math.tau) * env_val * 0.35 * vol;
        phase += freq / sample_rate;
        phase -= @floor(phase);
    }
}

fn renderSnare(buf: []f32, offset: usize, total_samples: usize, sample_rate: f32, vol: f32) void {
    const dur: usize = @intFromFloat(0.06 * sample_rate);
    var bp = filter.BandpassFilter.init(200.0, 2000.0, sample_rate);
    var phase: f32 = 0.0;
    for (0..dur) |i| {
        const idx = offset + i;
        if (idx >= total_samples) break;
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(dur));
        const env_val = std.math.pow(f32, 1.0 - t, 3.0);
        const noise_val = bp.process(oscillator.noise());
        const sine_val = @sin(phase * std.math.tau);
        buf[idx] += (noise_val * 0.6 + sine_val * 0.4) * env_val * 0.2 * vol;
        phase += 200.0 / sample_rate;
        phase -= @floor(phase);
    }
}

fn renderHihat(buf: []f32, offset: usize, total_samples: usize, sample_rate: f32, vol: f32) void {
    const dur: usize = @intFromFloat(0.02 * sample_rate);
    var hp = filter.HighpassFilter.init(6000.0, sample_rate);
    for (0..dur) |i| {
        const idx = offset + i;
        if (idx >= total_samples) break;
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(dur));
        const env_val = std.math.pow(f32, 1.0 - t, 5.0);
        buf[idx] += hp.process(oscillator.noise()) * env_val * 0.1 * vol;
    }
}

fn renderRim(buf: []f32, offset: usize, total_samples: usize, sample_rate: f32, vol: f32) void {
    const dur: usize = @intFromFloat(0.015 * sample_rate);
    var bp = filter.BandpassFilter.init(1000.0, 5000.0, sample_rate);
    for (0..dur) |i| {
        const idx = offset + i;
        if (idx >= total_samples) break;
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(dur));
        const env_val = std.math.pow(f32, 1.0 - t, 8.0);
        buf[idx] += bp.process(oscillator.noise()) * env_val * 0.15 * vol;
    }
}

fn renderShaker(buf: []f32, offset: usize, total_samples: usize, sample_rate: f32, vol: f32) void {
    const dur: usize = @intFromFloat(0.01 * sample_rate);
    var hp = filter.HighpassFilter.init(8000.0, sample_rate);
    for (0..dur) |i| {
        const idx = offset + i;
        if (idx >= total_samples) break;
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(dur));
        const env_val = std.math.pow(f32, 1.0 - t, 4.0);
        buf[idx] += hp.process(oscillator.noise()) * env_val * 0.05 * vol;
    }
}
