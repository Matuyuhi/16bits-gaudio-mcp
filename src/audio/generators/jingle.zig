const std = @import("std");
const oscillator = @import("../oscillator.zig");
const envelope = @import("../envelope.zig");
const sequencer = @import("../sequencer.zig");
const effects = @import("../effects.zig");

pub const JingleConfig = struct {
    jingle_type: []const u8,
    sample_rate: f32 = 44100.0,
    key: []const u8 = "C",
    tempo_feel: []const u8 = "normal",
    seed: u32 = 0,
};

pub fn generate(allocator: std.mem.Allocator, config: JingleConfig) ![]f32 {
    oscillator.resetNoise(config.seed);
    if (std.mem.eql(u8, config.jingle_type, "stage_clear")) return generateStageClear(allocator, config);
    if (std.mem.eql(u8, config.jingle_type, "game_over")) return generateGameOver(allocator, config);
    if (std.mem.eql(u8, config.jingle_type, "level_up")) return generateLevelUp(allocator, config);
    if (std.mem.eql(u8, config.jingle_type, "item_get")) return generateItemGet(allocator, config);
    if (std.mem.eql(u8, config.jingle_type, "boss_clear")) return generateBossClear(allocator, config);
    if (std.mem.eql(u8, config.jingle_type, "victory")) return generateVictory(allocator, config);
    if (std.mem.eql(u8, config.jingle_type, "defeat")) return generateDefeat(allocator, config);
    if (std.mem.eql(u8, config.jingle_type, "secret_found")) return generateSecretFound(allocator, config);
    if (std.mem.eql(u8, config.jingle_type, "save")) return generateSave(allocator, config);
    if (std.mem.eql(u8, config.jingle_type, "shop_buy")) return generateShopBuy(allocator, config);
    if (std.mem.eql(u8, config.jingle_type, "danger")) return generateDanger(allocator, config);
    if (std.mem.eql(u8, config.jingle_type, "unlock")) return generateUnlock(allocator, config);
    return error.UnknownJingleType;
}

fn getSpeedMultiplier(tempo_feel: []const u8) f32 {
    if (std.mem.eql(u8, tempo_feel, "fast")) return 0.7;
    if (std.mem.eql(u8, tempo_feel, "slow")) return 1.5;
    if (std.mem.eql(u8, tempo_feel, "triumphant")) return 1.3;
    return 1.0; // normal
}

/// Render a sequence of notes into a buffer
fn renderNoteSequence(allocator: std.mem.Allocator, midi_notes: []const u8, note_durations_ms: []const f32, waveform: oscillator.Waveform, adsr_cfg: envelope.AdsrConfig, sample_rate: f32, volume: f32) ![]f32 {
    var total_ms: f32 = 0;
    for (note_durations_ms) |d| total_ms += d;
    const release_tail: f32 = adsr_cfg.release_ms;
    const total_samples: usize = @intFromFloat((total_ms + release_tail) * sample_rate / 1000.0);
    const buf = try allocator.alloc(f32, total_samples);
    @memset(buf, 0.0);

    var offset: usize = 0;
    for (midi_notes, 0..) |midi, n_idx| {
        const dur_ms = note_durations_ms[n_idx];
        const dur_samples: usize = @intFromFloat(dur_ms * sample_rate / 1000.0);
        const note_total = dur_samples + @as(usize, @intFromFloat(release_tail * sample_rate / 1000.0));
        const freq = sequencer.midiToHz(midi);

        var env = envelope.Adsr.init(adsr_cfg, sample_rate);
        var phase: f32 = 0.0;

        for (0..@min(note_total, total_samples - offset)) |i| {
            if (i == dur_samples) env.noteOff();
            const env_val = env.process();
            const s = oscillator.sample(waveform, phase) * env_val * volume;
            buf[offset + i] += s;
            phase += freq / sample_rate;
            phase -= @floor(phase);
            if (env.isFinished()) break;
        }
        offset += dur_samples;
    }
    return buf;
}

/// Add a chord layer at a given time position
fn addChordLayer(buf: []f32, chord_notes: []const u8, start_ms: f32, dur_ms: f32, waveform: oscillator.Waveform, adsr_cfg: envelope.AdsrConfig, sample_rate: f32, volume: f32) void {
    const chord_start: usize = @intFromFloat(start_ms * sample_rate / 1000.0);
    const chord_dur: usize = @intFromFloat(dur_ms * sample_rate / 1000.0);

    for (chord_notes) |note| {
        const freq = sequencer.midiToHz(note);
        var phase: f32 = 0.0;
        var env = envelope.Adsr.init(adsr_cfg, sample_rate);

        for (0..@min(chord_dur, buf.len -| chord_start)) |i| {
            if (i == chord_dur * 7 / 10) env.noteOff();
            const idx = chord_start + i;
            if (idx < buf.len) {
                buf[idx] += oscillator.sample(waveform, phase) * env.process() * volume;
            }
            phase += freq / sample_rate;
            phase -= @floor(phase);
        }
    }
}

// ============================================================
// Original 5 jingles
// ============================================================

fn generateStageClear(allocator: std.mem.Allocator, config: JingleConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const speed = getSpeedMultiplier(config.tempo_feel);
    const base_oct: u8 = 4;

    const notes = [_]u8{
        @as(u8, root) + (base_oct + 1) * 12,
        @as(u8, root) + 4 + (base_oct + 1) * 12,
        @as(u8, root) + 7 + (base_oct + 1) * 12,
        @as(u8, root) + (base_oct + 2) * 12,
    };
    const durations = [_]f32{
        250.0 * speed,
        250.0 * speed,
        250.0 * speed,
        800.0 * speed,
    };

    const adsr = envelope.AdsrConfig{
        .attack_ms = 5.0,
        .decay_ms = 80.0,
        .sustain_level = 0.6,
        .release_ms = 200.0,
    };

    const buf = try renderNoteSequence(allocator, &notes, &durations, .sine, adsr, config.sample_rate, 0.7);

    const chord_notes = [_]u8{
        @as(u8, root) + (base_oct + 1) * 12,
        @as(u8, root) + 4 + (base_oct + 1) * 12,
        @as(u8, root) + 7 + (base_oct + 1) * 12,
    };
    addChordLayer(buf, &chord_notes, 750.0 * speed, 1000.0 * speed, .square, .{
        .attack_ms = 10.0, .decay_ms = 200.0, .sustain_level = 0.4, .release_ms = 300.0,
    }, config.sample_rate, 0.15);

    try effects.applyReverb(allocator, buf, 0.5, 0.3);
    return buf;
}

fn generateGameOver(allocator: std.mem.Allocator, config: JingleConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const speed = getSpeedMultiplier(config.tempo_feel);
    const base_oct: u8 = 4;

    const notes = [_]u8{
        @as(u8, root) + 7 + (base_oct + 1) * 12,
        @as(u8, root) + 3 + (base_oct + 1) * 12,
        @as(u8, root) + (base_oct + 1) * 12,
        @as(u8, root) + base_oct * 12,
    };
    const durations = [_]f32{
        300.0 * speed,
        300.0 * speed,
        400.0 * speed,
        600.0 * speed,
    };

    const adsr = envelope.AdsrConfig{
        .attack_ms = 10.0,
        .decay_ms = 150.0,
        .sustain_level = 0.5,
        .release_ms = 300.0,
    };

    const buf = try renderNoteSequence(allocator, &notes, &durations, .triangle, adsr, config.sample_rate, 0.6);
    try effects.applyReverb(allocator, buf, 0.6, 0.35);
    return buf;
}

fn generateLevelUp(allocator: std.mem.Allocator, config: JingleConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const speed = getSpeedMultiplier(config.tempo_feel);
    const base_oct: u8 = 4;

    const notes = [_]u8{
        @as(u8, root) + (base_oct + 1) * 12,
        @as(u8, root) + 2 + (base_oct + 1) * 12,
        @as(u8, root) + 4 + (base_oct + 1) * 12,
        @as(u8, root) + 7 + (base_oct + 1) * 12,
        @as(u8, root) + (base_oct + 2) * 12,
    };
    const durations = [_]f32{
        120.0 * speed,
        120.0 * speed,
        120.0 * speed,
        120.0 * speed,
        400.0 * speed,
    };

    const adsr = envelope.AdsrConfig{
        .attack_ms = 3.0,
        .decay_ms = 50.0,
        .sustain_level = 0.6,
        .release_ms = 100.0,
    };

    const buf = try renderNoteSequence(allocator, &notes, &durations, .sine, adsr, config.sample_rate, 0.7);
    try effects.applyReverb(allocator, buf, 0.3, 0.2);
    return buf;
}

fn generateItemGet(allocator: std.mem.Allocator, config: JingleConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const speed = getSpeedMultiplier(config.tempo_feel);
    const base_oct: u8 = 5;

    const notes = [_]u8{
        @as(u8, root) + 4 + base_oct * 12,
        @as(u8, root) + (base_oct + 1) * 12,
    };
    const durations = [_]f32{
        150.0 * speed,
        300.0 * speed,
    };

    const adsr = envelope.AdsrConfig{
        .attack_ms = 2.0,
        .decay_ms = 40.0,
        .sustain_level = 0.5,
        .release_ms = 150.0,
    };

    return try renderNoteSequence(allocator, &notes, &durations, .sine, adsr, config.sample_rate, 0.7);
}

fn generateBossClear(allocator: std.mem.Allocator, config: JingleConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const speed = getSpeedMultiplier(config.tempo_feel);
    const base_oct: u8 = 4;

    const notes = [_]u8{
        @as(u8, root) + 7 + base_oct * 12,
        @as(u8, root) + (base_oct + 1) * 12,
        @as(u8, root) + 4 + (base_oct + 1) * 12,
        @as(u8, root) + 7 + (base_oct + 1) * 12,
        @as(u8, root) + (base_oct + 2) * 12,
    };
    const durations = [_]f32{
        300.0 * speed,
        300.0 * speed,
        300.0 * speed,
        400.0 * speed,
        1200.0 * speed,
    };

    const adsr = envelope.AdsrConfig{
        .attack_ms = 8.0,
        .decay_ms = 100.0,
        .sustain_level = 0.65,
        .release_ms = 400.0,
    };

    const buf = try renderNoteSequence(allocator, &notes, &durations, .sine, adsr, config.sample_rate, 0.6);

    const chord_notes = [_]u8{
        @as(u8, root) + (base_oct + 1) * 12,
        @as(u8, root) + 4 + (base_oct + 1) * 12,
        @as(u8, root) + 7 + (base_oct + 1) * 12,
        @as(u8, root) + (base_oct + 2) * 12,
    };
    addChordLayer(buf, &chord_notes, 1300.0 * speed, 1500.0 * speed, .square, .{
        .attack_ms = 20.0, .decay_ms = 300.0, .sustain_level = 0.5, .release_ms = 500.0,
    }, config.sample_rate, 0.12);

    try effects.applyReverb(allocator, buf, 0.7, 0.4);
    return buf;
}

// ============================================================
// New 7 jingles
// ============================================================

/// Victory fanfare: triumphant brass-like ascending with final sustained chord
fn generateVictory(allocator: std.mem.Allocator, config: JingleConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const speed = getSpeedMultiplier(config.tempo_feel);
    const base_oct: u8 = 4;

    // Fanfare: C4, E4, G4, C5, E5, then big C major chord
    const notes = [_]u8{
        @as(u8, root) + (base_oct + 1) * 12,
        @as(u8, root) + 4 + (base_oct + 1) * 12,
        @as(u8, root) + 7 + (base_oct + 1) * 12,
        @as(u8, root) + (base_oct + 2) * 12,
        @as(u8, root) + 4 + (base_oct + 2) * 12,
    };
    const durations = [_]f32{
        200.0 * speed,
        200.0 * speed,
        200.0 * speed,
        350.0 * speed,
        600.0 * speed,
    };

    const adsr = envelope.AdsrConfig{
        .attack_ms = 5.0,
        .decay_ms = 60.0,
        .sustain_level = 0.65,
        .release_ms = 200.0,
    };

    const buf = try renderNoteSequence(allocator, &notes, &durations, .sawtooth, adsr, config.sample_rate, 0.5);

    // Big final chord
    const chord_notes = [_]u8{
        @as(u8, root) + (base_oct + 1) * 12,
        @as(u8, root) + 4 + (base_oct + 1) * 12,
        @as(u8, root) + 7 + (base_oct + 1) * 12,
        @as(u8, root) + (base_oct + 2) * 12,
    };
    addChordLayer(buf, &chord_notes, 950.0 * speed, 1200.0 * speed, .square, .{
        .attack_ms = 15.0, .decay_ms = 250.0, .sustain_level = 0.45, .release_ms = 400.0,
    }, config.sample_rate, 0.15);

    try effects.applyReverb(allocator, buf, 0.6, 0.35);
    return buf;
}

/// Defeat: slow descending minor with dissonance
fn generateDefeat(allocator: std.mem.Allocator, config: JingleConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const speed = getSpeedMultiplier(config.tempo_feel);
    const base_oct: u8 = 4;

    // Descending minor: Eb5, C5, Ab4, G4, then low Eb3
    const notes = [_]u8{
        @as(u8, root) + 3 + (base_oct + 2) * 12,
        @as(u8, root) + (base_oct + 2) * 12,
        @as(u8, root) + 8 + (base_oct + 1) * 12,
        @as(u8, root) + 7 + (base_oct + 1) * 12,
        @as(u8, root) + 3 + base_oct * 12,
    };
    const durations = [_]f32{
        350.0 * speed,
        350.0 * speed,
        350.0 * speed,
        400.0 * speed,
        800.0 * speed,
    };

    const adsr = envelope.AdsrConfig{
        .attack_ms = 15.0,
        .decay_ms = 120.0,
        .sustain_level = 0.4,
        .release_ms = 400.0,
    };

    const buf = try renderNoteSequence(allocator, &notes, &durations, .triangle, adsr, config.sample_rate, 0.55);
    try effects.applyReverb(allocator, buf, 0.8, 0.45);
    return buf;
}

/// Secret found: mysterious ascending with sparkle
fn generateSecretFound(allocator: std.mem.Allocator, config: JingleConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const speed = getSpeedMultiplier(config.tempo_feel);
    const base_oct: u8 = 5;

    // Chromatic sparkle: C5, Db5, E5, G5, B5, C6
    const notes = [_]u8{
        @as(u8, root) + base_oct * 12,
        @as(u8, root) + 1 + base_oct * 12,
        @as(u8, root) + 4 + base_oct * 12,
        @as(u8, root) + 7 + base_oct * 12,
        @as(u8, root) + 11 + base_oct * 12,
        @as(u8, root) + (base_oct + 1) * 12,
    };
    const durations = [_]f32{
        100.0 * speed,
        100.0 * speed,
        100.0 * speed,
        100.0 * speed,
        150.0 * speed,
        500.0 * speed,
    };

    const adsr = envelope.AdsrConfig{
        .attack_ms = 2.0,
        .decay_ms = 30.0,
        .sustain_level = 0.5,
        .release_ms = 120.0,
    };

    const buf = try renderNoteSequence(allocator, &notes, &durations, .sine, adsr, config.sample_rate, 0.6);
    try effects.applyReverb(allocator, buf, 0.7, 0.4);
    return buf;
}

/// Save complete: gentle confirmation chime
fn generateSave(allocator: std.mem.Allocator, config: JingleConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const speed = getSpeedMultiplier(config.tempo_feel);
    const base_oct: u8 = 5;

    // Gentle two-chord: G5, C6 (perfect 4th resolution)
    const notes = [_]u8{
        @as(u8, root) + 7 + base_oct * 12,
        @as(u8, root) + (base_oct + 1) * 12,
    };
    const durations = [_]f32{
        200.0 * speed,
        400.0 * speed,
    };

    const adsr = envelope.AdsrConfig{
        .attack_ms = 8.0,
        .decay_ms = 60.0,
        .sustain_level = 0.4,
        .release_ms = 200.0,
    };

    const buf = try renderNoteSequence(allocator, &notes, &durations, .sine, adsr, config.sample_rate, 0.5);

    // Soft chord underneath
    const chord_notes = [_]u8{
        @as(u8, root) + base_oct * 12,
        @as(u8, root) + 4 + base_oct * 12,
    };
    addChordLayer(buf, &chord_notes, 200.0 * speed, 500.0 * speed, .sine, .{
        .attack_ms = 20.0, .decay_ms = 100.0, .sustain_level = 0.3, .release_ms = 200.0,
    }, config.sample_rate, 0.1);

    try effects.applyReverb(allocator, buf, 0.5, 0.25);
    return buf;
}

/// Shop buy: cheerful cash register chime
fn generateShopBuy(allocator: std.mem.Allocator, config: JingleConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const speed = getSpeedMultiplier(config.tempo_feel);
    const base_oct: u8 = 5;

    // Quick ascending ding: E5, G5, C6
    const notes = [_]u8{
        @as(u8, root) + 4 + base_oct * 12,
        @as(u8, root) + 7 + base_oct * 12,
        @as(u8, root) + (base_oct + 1) * 12,
    };
    const durations = [_]f32{
        80.0 * speed,
        80.0 * speed,
        250.0 * speed,
    };

    const adsr = envelope.AdsrConfig{
        .attack_ms = 1.0,
        .decay_ms = 20.0,
        .sustain_level = 0.5,
        .release_ms = 80.0,
    };

    return try renderNoteSequence(allocator, &notes, &durations, .square, adsr, config.sample_rate, 0.5);
}

/// Danger / warning: urgent pulsing alarm
fn generateDanger(allocator: std.mem.Allocator, config: JingleConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const speed = getSpeedMultiplier(config.tempo_feel);
    const base_oct: u8 = 4;

    // Alternating minor 2nd: C4, Db4, C4, Db4, C4
    const notes = [_]u8{
        @as(u8, root) + (base_oct + 1) * 12,
        @as(u8, root) + 1 + (base_oct + 1) * 12,
        @as(u8, root) + (base_oct + 1) * 12,
        @as(u8, root) + 1 + (base_oct + 1) * 12,
        @as(u8, root) + (base_oct + 1) * 12,
    };
    const durations = [_]f32{
        150.0 * speed,
        150.0 * speed,
        150.0 * speed,
        150.0 * speed,
        300.0 * speed,
    };

    const adsr = envelope.AdsrConfig{
        .attack_ms = 2.0,
        .decay_ms = 10.0,
        .sustain_level = 0.8,
        .release_ms = 30.0,
    };

    const buf = try renderNoteSequence(allocator, &notes, &durations, .square, adsr, config.sample_rate, 0.5);
    try effects.applyReverb(allocator, buf, 0.3, 0.15);
    return buf;
}

/// Unlock / achievement: ascending with bright shimmer
fn generateUnlock(allocator: std.mem.Allocator, config: JingleConfig) ![]f32 {
    const root = try sequencer.keyToSemitone(config.key);
    const speed = getSpeedMultiplier(config.tempo_feel);
    const base_oct: u8 = 5;

    // Bright ascending: G4, C5, E5, G5, then shimmer chord
    const notes = [_]u8{
        @as(u8, root) + 7 + base_oct * 12,
        @as(u8, root) + (base_oct + 1) * 12,
        @as(u8, root) + 4 + (base_oct + 1) * 12,
        @as(u8, root) + 7 + (base_oct + 1) * 12,
    };
    const durations = [_]f32{
        120.0 * speed,
        120.0 * speed,
        120.0 * speed,
        500.0 * speed,
    };

    const adsr = envelope.AdsrConfig{
        .attack_ms = 3.0,
        .decay_ms = 40.0,
        .sustain_level = 0.55,
        .release_ms = 150.0,
    };

    const buf = try renderNoteSequence(allocator, &notes, &durations, .sine, adsr, config.sample_rate, 0.65);

    // Shimmer chord
    const chord_notes = [_]u8{
        @as(u8, root) + (base_oct + 1) * 12,
        @as(u8, root) + 4 + (base_oct + 1) * 12,
        @as(u8, root) + 7 + (base_oct + 1) * 12,
    };
    addChordLayer(buf, &chord_notes, 360.0 * speed, 600.0 * speed, .triangle, .{
        .attack_ms = 10.0, .decay_ms = 150.0, .sustain_level = 0.35, .release_ms = 250.0,
    }, config.sample_rate, 0.12);

    try effects.applyReverb(allocator, buf, 0.5, 0.3);
    return buf;
}
