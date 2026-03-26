const std = @import("std");
const protocol = @import("protocol.zig");

// Audio modules
const wav = @import("../audio/wav.zig");
const oscillator_mod = @import("../audio/oscillator.zig");
const envelope_mod = @import("../audio/envelope.zig");
const fm_mod = @import("../audio/fm.zig");
const effects_mod = @import("../audio/effects.zig");
const mixer_mod = @import("../audio/mixer.zig");
const sequencer_mod = @import("../audio/sequencer.zig");
const filter_mod = @import("../audio/filter.zig");

// Generators
const bgm = @import("../audio/generators/bgm.zig");
const jingle = @import("../audio/generators/jingle.zig");
const se = @import("../audio/generators/se.zig");

const JsonValue = std.json.Value;

/// Tools list JSON response body (MUST be single line — MCP uses newline-delimited JSON-RPC)
pub const tools_list_json = "{\"tools\":[" ++
    "{\"name\":\"bgm_compose\",\"description\":\"Generate loopable game BGM with multi-track composition (melody, bass, harmony, percussion)\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"output\":{\"type\":\"string\",\"description\":\"Output WAV file path\"},\"style\":{\"type\":\"string\",\"enum\":[\"adventure\",\"dungeon\",\"boss\",\"town\",\"battle\"],\"description\":\"BGM style\"},\"bpm\":{\"type\":\"number\",\"description\":\"Beats per minute\"},\"duration_bars\":{\"type\":\"number\",\"description\":\"Number of bars to generate\"},\"sample_rate\":{\"type\":\"number\",\"description\":\"Sample rate (e.g. 44100)\"},\"key\":{\"type\":\"string\",\"description\":\"Musical key (e.g. C, D, F#)\"},\"scale\":{\"type\":\"string\",\"enum\":[\"major\",\"minor\",\"pentatonic\",\"blues\"],\"description\":\"Musical scale\"},\"seed\":{\"type\":\"number\",\"description\":\"Random seed for deterministic generation\"}},\"required\":[\"output\",\"style\",\"bpm\",\"duration_bars\",\"sample_rate\",\"key\",\"scale\",\"seed\"]}}," ++
    "{\"name\":\"jingle_gen\",\"description\":\"Generate short game event jingles (stage clear, game over, level up, etc.)\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"output\":{\"type\":\"string\",\"description\":\"Output WAV file path\"},\"type\":{\"type\":\"string\",\"enum\":[\"stage_clear\",\"game_over\",\"level_up\",\"item_get\",\"boss_clear\"],\"description\":\"Jingle type\"},\"sample_rate\":{\"type\":\"number\",\"description\":\"Sample rate\"},\"key\":{\"type\":\"string\",\"description\":\"Musical key\"},\"tempo_feel\":{\"type\":\"string\",\"enum\":[\"fast\",\"normal\",\"triumphant\"],\"description\":\"Tempo feel\"}},\"required\":[\"output\",\"type\",\"sample_rate\",\"key\",\"tempo_feel\"]}}," ++
    "{\"name\":\"se_gen\",\"description\":\"Generate game sound effects (jump, hit, coin, explosion, laser, powerup, error, footstep)\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"output\":{\"type\":\"string\",\"description\":\"Output WAV file path\"},\"type\":{\"type\":\"string\",\"enum\":[\"jump\",\"hit\",\"coin\",\"explosion\",\"laser\",\"powerup\",\"error\",\"footstep\"],\"description\":\"Sound effect type\"},\"pitch\":{\"type\":\"number\",\"description\":\"Pitch multiplier (1.0 = standard, 0.5 = octave down, 2.0 = octave up)\"},\"volume\":{\"type\":\"number\",\"description\":\"Volume (0.0 to 1.0)\"},\"sample_rate\":{\"type\":\"number\",\"description\":\"Sample rate\"}},\"required\":[\"output\",\"type\",\"pitch\",\"volume\",\"sample_rate\"]}}," ++
    "{\"name\":\"note_synth\",\"description\":\"Synthesize single notes or chords and write to WAV (low-level API)\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"output\":{\"type\":\"string\",\"description\":\"Output WAV file path\"},\"notes\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Note names (e.g. [C4, E4, G4])\"},\"waveform\":{\"type\":\"string\",\"enum\":[\"sine\",\"square\",\"sawtooth\",\"triangle\",\"pulse\"],\"description\":\"Waveform type\"},\"duration_ms\":{\"type\":\"number\",\"description\":\"Duration in milliseconds\"},\"adsr\":{\"type\":\"object\",\"properties\":{\"attack_ms\":{\"type\":\"number\"},\"decay_ms\":{\"type\":\"number\"},\"sustain_level\":{\"type\":\"number\"},\"release_ms\":{\"type\":\"number\"}},\"description\":\"ADSR envelope\"},\"sample_rate\":{\"type\":\"number\",\"description\":\"Sample rate\"},\"reverb\":{\"type\":\"boolean\",\"description\":\"Apply reverb\"}},\"required\":[\"output\",\"notes\",\"waveform\",\"duration_ms\",\"adsr\",\"sample_rate\"]}}," ++
    "{\"name\":\"fm_patch\",\"description\":\"Generate a single tone using FM synthesis (YM2612-style 2-operator)\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"output\":{\"type\":\"string\",\"description\":\"Output WAV file path\"},\"carrier_note\":{\"type\":\"string\",\"description\":\"Carrier note (e.g. A2)\"},\"modulator_ratio\":{\"type\":\"number\",\"description\":\"Modulator frequency ratio to carrier\"},\"modulation_index\":{\"type\":\"number\",\"description\":\"FM modulation depth\"},\"carrier_adsr\":{\"type\":\"object\",\"properties\":{\"attack_ms\":{\"type\":\"number\"},\"decay_ms\":{\"type\":\"number\"},\"sustain_level\":{\"type\":\"number\"},\"release_ms\":{\"type\":\"number\"}}},\"modulator_adsr\":{\"type\":\"object\",\"properties\":{\"attack_ms\":{\"type\":\"number\"},\"decay_ms\":{\"type\":\"number\"},\"sustain_level\":{\"type\":\"number\"},\"release_ms\":{\"type\":\"number\"}}},\"duration_ms\":{\"type\":\"number\",\"description\":\"Duration in milliseconds\"},\"sample_rate\":{\"type\":\"number\",\"description\":\"Sample rate\"}},\"required\":[\"output\",\"carrier_note\",\"modulator_ratio\",\"modulation_index\",\"carrier_adsr\",\"modulator_adsr\",\"duration_ms\",\"sample_rate\"]}}," ++
    "{\"name\":\"wav_fx\",\"description\":\"Apply audio effects (reverb, delay, lowpass, highpass) to an existing WAV file\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"input\":{\"type\":\"string\",\"description\":\"Input WAV file path\"},\"output\":{\"type\":\"string\",\"description\":\"Output WAV file path\"},\"effects\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"properties\":{\"type\":{\"type\":\"string\",\"enum\":[\"reverb\",\"delay\",\"lowpass\",\"highpass\"]},\"room_size\":{\"type\":\"number\"},\"wet\":{\"type\":\"number\"},\"delay_ms\":{\"type\":\"number\"},\"feedback\":{\"type\":\"number\"},\"cutoff_hz\":{\"type\":\"number\"}}},\"description\":\"Array of effects to apply\"}},\"required\":[\"input\",\"output\",\"effects\"]}}," ++
    "{\"name\":\"wav_mix\",\"description\":\"Mix multiple WAV files into one (supports different lengths, gains, and offsets)\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"tracks\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\"},\"gain\":{\"type\":\"number\"},\"offset_ms\":{\"type\":\"number\"}}},\"description\":\"Tracks to mix\"},\"output\":{\"type\":\"string\",\"description\":\"Output WAV file path\"},\"normalize\":{\"type\":\"boolean\",\"description\":\"Normalize to -1dBFS\"}},\"required\":[\"tracks\",\"output\"]}}," ++
    "{\"name\":\"wav_info\",\"description\":\"Get WAV file metadata and waveform statistics\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\",\"description\":\"WAV file path\"}},\"required\":[\"path\"]}}," ++
    "{\"name\":\"wav_play\",\"description\":\"Play a WAV file asynchronously (macOS: afplay, Linux: aplay)\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\",\"description\":\"WAV file path to play\"}},\"required\":[\"path\"]}}" ++
    "]}";

// Helper functions to extract JSON values
fn getString(val: ?JsonValue) ?[]const u8 {
    const v = val orelse return null;
    return switch (v) {
        .string => |s| s,
        else => null,
    };
}

fn getNumber(val: ?JsonValue) ?f64 {
    const v = val orelse return null;
    return switch (v) {
        .integer => |n| @floatFromInt(n),
        .float => |f| f,
        else => null,
    };
}

fn getBool(val: ?JsonValue) ?bool {
    const v = val orelse return null;
    return switch (v) {
        .bool => |b| b,
        else => null,
    };
}

fn getObject(val: ?JsonValue) ?std.json.ObjectMap {
    const v = val orelse return null;
    return switch (v) {
        .object => |o| o,
        else => null,
    };
}

fn getArray(val: ?JsonValue) ?std.json.Array {
    const v = val orelse return null;
    return switch (v) {
        .array => |a| a,
        else => null,
    };
}

fn parseAdsr(obj: ?std.json.ObjectMap) envelope_mod.AdsrConfig {
    const o = obj orelse return .{};
    return .{
        .attack_ms = @floatCast(getNumber(o.get("attack_ms")) orelse 10.0),
        .decay_ms = @floatCast(getNumber(o.get("decay_ms")) orelse 50.0),
        .sustain_level = @floatCast(getNumber(o.get("sustain_level")) orelse 0.7),
        .release_ms = @floatCast(getNumber(o.get("release_ms")) orelse 100.0),
    };
}

/// Execute a tool by name with the given arguments.
/// Returns a result string on success, or an error message.
pub fn executeTool(allocator: std.mem.Allocator, name: []const u8, args: std.json.ObjectMap) ![]const u8 {
    if (std.mem.eql(u8, name, "bgm_compose")) return execBgmCompose(allocator, args);
    if (std.mem.eql(u8, name, "jingle_gen")) return execJingleGen(allocator, args);
    if (std.mem.eql(u8, name, "se_gen")) return execSeGen(allocator, args);
    if (std.mem.eql(u8, name, "note_synth")) return execNoteSynth(allocator, args);
    if (std.mem.eql(u8, name, "fm_patch")) return execFmPatch(allocator, args);
    if (std.mem.eql(u8, name, "wav_fx")) return execWavFx(allocator, args);
    if (std.mem.eql(u8, name, "wav_mix")) return execWavMix(allocator, args);
    if (std.mem.eql(u8, name, "wav_info")) return execWavInfo(allocator, args);
    if (std.mem.eql(u8, name, "wav_play")) return execWavPlay(allocator, args);
    return error.UnknownTool;
}

fn execBgmCompose(allocator: std.mem.Allocator, args: std.json.ObjectMap) ![]const u8 {
    const output = getString(args.get("output")) orelse return error.MissingParam;
    const style = getString(args.get("style")) orelse return error.MissingParam;
    const bpm_f = getNumber(args.get("bpm")) orelse return error.MissingParam;
    const bars_f = getNumber(args.get("duration_bars")) orelse return error.MissingParam;
    const sr_f = getNumber(args.get("sample_rate")) orelse return error.MissingParam;
    const key = getString(args.get("key")) orelse return error.MissingParam;
    const scale = getString(args.get("scale")) orelse return error.MissingParam;
    const seed_f = getNumber(args.get("seed")) orelse return error.MissingParam;

    const sample_rate: u32 = @intFromFloat(sr_f);
    const samples = try bgm.generate(allocator, .{
        .style = style,
        .bpm = @floatCast(bpm_f),
        .duration_bars = @intFromFloat(bars_f),
        .sample_rate = @floatCast(sr_f),
        .key = key,
        .scale = scale,
        .seed = @intFromFloat(seed_f),
    });
    defer allocator.free(samples);

    try wav.writeWav(output, samples, sample_rate);

    const duration_ms = @as(u64, samples.len) * 1000 / @as(u64, sample_rate);
    return try std.fmt.allocPrint(
        allocator,
        "Generated: {s}\nstyle: {s}\nbpm: {d}\nbars: {d}\nduration_ms: {d}\ntracks: 4\nsample_rate: {d}\nloopable: true",
        .{ output, style, @as(u32, @intFromFloat(bpm_f)), @as(u32, @intFromFloat(bars_f)), duration_ms, sample_rate },
    );
}

fn execJingleGen(allocator: std.mem.Allocator, args: std.json.ObjectMap) ![]const u8 {
    const output = getString(args.get("output")) orelse return error.MissingParam;
    const jingle_type = getString(args.get("type")) orelse return error.MissingParam;
    const sr_f = getNumber(args.get("sample_rate")) orelse return error.MissingParam;
    const key = getString(args.get("key")) orelse return error.MissingParam;
    const tempo_feel = getString(args.get("tempo_feel")) orelse return error.MissingParam;

    const sample_rate: u32 = @intFromFloat(sr_f);
    const samples = try jingle.generate(allocator, .{
        .jingle_type = jingle_type,
        .sample_rate = @floatCast(sr_f),
        .key = key,
        .tempo_feel = tempo_feel,
    });
    defer allocator.free(samples);

    try wav.writeWav(output, samples, sample_rate);

    const duration_ms = @as(u64, samples.len) * 1000 / @as(u64, sample_rate);
    return try std.fmt.allocPrint(
        allocator,
        "Generated: {s}\ntype: {s}\nduration_ms: {d}\nsample_rate: {d}",
        .{ output, jingle_type, duration_ms, sample_rate },
    );
}

fn execSeGen(allocator: std.mem.Allocator, args: std.json.ObjectMap) ![]const u8 {
    const output = getString(args.get("output")) orelse return error.MissingParam;
    const se_type = getString(args.get("type")) orelse return error.MissingParam;
    const pitch_f = getNumber(args.get("pitch")) orelse 1.0;
    const volume_f = getNumber(args.get("volume")) orelse 0.8;
    const sr_f = getNumber(args.get("sample_rate")) orelse return error.MissingParam;

    const sample_rate: u32 = @intFromFloat(sr_f);
    const samples = try se.generate(allocator, .{
        .se_type = se_type,
        .pitch = @floatCast(pitch_f),
        .volume = @floatCast(volume_f),
        .sample_rate = @floatCast(sr_f),
    });
    defer allocator.free(samples);

    try wav.writeWav(output, samples, sample_rate);

    const duration_ms = @as(u64, samples.len) * 1000 / @as(u64, sample_rate);
    return try std.fmt.allocPrint(
        allocator,
        "Generated: {s}\ntype: {s}\nduration_ms: {d}\nsample_rate: {d}",
        .{ output, se_type, duration_ms, sample_rate },
    );
}

fn execNoteSynth(allocator: std.mem.Allocator, args: std.json.ObjectMap) ![]const u8 {
    const output = getString(args.get("output")) orelse return error.MissingParam;
    const waveform_str = getString(args.get("waveform")) orelse return error.MissingParam;
    const duration_ms_f = getNumber(args.get("duration_ms")) orelse return error.MissingParam;
    const sr_f = getNumber(args.get("sample_rate")) orelse return error.MissingParam;
    const apply_reverb = getBool(args.get("reverb")) orelse false;

    const waveform = oscillator_mod.parseWaveform(waveform_str) orelse return error.InvalidParam;
    const adsr_cfg = parseAdsr(getObject(args.get("adsr")));
    const notes_arr = getArray(args.get("notes")) orelse return error.MissingParam;

    const sample_rate: u32 = @intFromFloat(sr_f);
    const total_samples: usize = @intFromFloat(duration_ms_f * @as(f64, sr_f) / 1000.0);
    const buf = try allocator.alloc(f32, total_samples);
    defer allocator.free(buf);
    @memset(buf, 0.0);

    // Render each note
    for (notes_arr.items) |note_val| {
        const note_name = getString(note_val) orelse continue;
        const freq = try sequencer_mod.noteToHz(note_name);
        const sr: f32 = @floatCast(sr_f);

        var env = envelope_mod.Adsr.init(adsr_cfg, sr);
        var phase: f32 = 0.0;
        const sustain_end = total_samples * 7 / 10;

        for (buf, 0..) |*s, i| {
            if (i == sustain_end) env.noteOff();
            const env_val = env.process();
            s.* += oscillator_mod.sample(waveform, phase) * env_val * 0.5;
            phase += freq / sr;
            phase -= @floor(phase);
        }
    }

    if (apply_reverb) {
        try effects_mod.applyReverb(allocator, buf, 0.5, 0.3);
    }

    try wav.writeWav(output, buf, sample_rate);

    const duration_ms_out = @as(u64, total_samples) * 1000 / @as(u64, sample_rate);
    return try std.fmt.allocPrint(
        allocator,
        "Generated: {s}\nnotes: {d}\nwaveform: {s}\nduration_ms: {d}\nsample_rate: {d}",
        .{ output, notes_arr.items.len, waveform_str, duration_ms_out, sample_rate },
    );
}

fn execFmPatch(allocator: std.mem.Allocator, args: std.json.ObjectMap) ![]const u8 {
    const output = getString(args.get("output")) orelse return error.MissingParam;
    const carrier_note = getString(args.get("carrier_note")) orelse return error.MissingParam;
    const mod_ratio_f = getNumber(args.get("modulator_ratio")) orelse return error.MissingParam;
    const mod_index_f = getNumber(args.get("modulation_index")) orelse return error.MissingParam;
    const duration_ms_f = getNumber(args.get("duration_ms")) orelse return error.MissingParam;
    const sr_f = getNumber(args.get("sample_rate")) orelse return error.MissingParam;

    const carrier_freq = try sequencer_mod.noteToHz(carrier_note);
    const carrier_adsr = parseAdsr(getObject(args.get("carrier_adsr")));
    const modulator_adsr = parseAdsr(getObject(args.get("modulator_adsr")));

    const sample_rate: u32 = @intFromFloat(sr_f);
    const samples = try fm_mod.generate(allocator, .{
        .carrier_freq = carrier_freq,
        .modulator_ratio = @floatCast(mod_ratio_f),
        .modulation_index = @floatCast(mod_index_f),
        .carrier_adsr = carrier_adsr,
        .modulator_adsr = modulator_adsr,
        .duration_ms = @floatCast(duration_ms_f),
        .sample_rate = @floatCast(sr_f),
    });
    defer allocator.free(samples);

    try wav.writeWav(output, samples, sample_rate);

    const duration_ms_out = @as(u64, samples.len) * 1000 / @as(u64, sample_rate);
    return try std.fmt.allocPrint(
        allocator,
        "Generated: {s}\ncarrier_note: {s}\nmodulator_ratio: {d:.2}\nmodulation_index: {d:.2}\nduration_ms: {d}\nsample_rate: {d}",
        .{ output, carrier_note, @as(f32, @floatCast(mod_ratio_f)), @as(f32, @floatCast(mod_index_f)), duration_ms_out, sample_rate },
    );
}

fn execWavFx(allocator: std.mem.Allocator, args: std.json.ObjectMap) ![]const u8 {
    const input_path = getString(args.get("input")) orelse return error.MissingParam;
    const output_path = getString(args.get("output")) orelse return error.MissingParam;
    const fx_array = getArray(args.get("effects")) orelse return error.MissingParam;

    // Read input WAV
    const data = try wav.readWav(allocator, input_path);
    defer allocator.free(data.samples);

    const sample_rate: f32 = @floatFromInt(data.info.sample_rate);

    // Apply each effect
    for (fx_array.items) |fx_val| {
        const fx_obj = getObject(fx_val) orelse continue;
        const fx_type = getString(fx_obj.get("type")) orelse continue;

        if (std.mem.eql(u8, fx_type, "reverb")) {
            const room_size: f32 = @floatCast(getNumber(fx_obj.get("room_size")) orelse 0.5);
            const wet_val: f32 = @floatCast(getNumber(fx_obj.get("wet")) orelse 0.3);
            try effects_mod.applyReverb(allocator, data.samples, room_size, wet_val);
        } else if (std.mem.eql(u8, fx_type, "delay")) {
            const delay_ms: f32 = @floatCast(getNumber(fx_obj.get("delay_ms")) orelse 250.0);
            const feedback: f32 = @floatCast(getNumber(fx_obj.get("feedback")) orelse 0.3);
            const wet_val: f32 = @floatCast(getNumber(fx_obj.get("wet")) orelse 0.3);
            try effects_mod.applyDelay(allocator, data.samples, delay_ms, feedback, wet_val, sample_rate);
        } else if (std.mem.eql(u8, fx_type, "lowpass")) {
            const cutoff: f32 = @floatCast(getNumber(fx_obj.get("cutoff_hz")) orelse 1000.0);
            var lp = filter_mod.LowpassFilter.init(cutoff, sample_rate);
            lp.processBuffer(data.samples);
        } else if (std.mem.eql(u8, fx_type, "highpass")) {
            const cutoff: f32 = @floatCast(getNumber(fx_obj.get("cutoff_hz")) orelse 1000.0);
            var hp = filter_mod.HighpassFilter.init(cutoff, sample_rate);
            hp.processBuffer(data.samples);
        }
    }

    try wav.writeWav(output_path, data.samples, data.info.sample_rate);

    return try std.fmt.allocPrint(
        allocator,
        "Processed: {s} -> {s}\neffects_applied: {d}\nsample_rate: {d}",
        .{ input_path, output_path, fx_array.items.len, data.info.sample_rate },
    );
}

fn execWavMix(allocator: std.mem.Allocator, args: std.json.ObjectMap) ![]const u8 {
    const output_path = getString(args.get("output")) orelse return error.MissingParam;
    const do_normalize = getBool(args.get("normalize")) orelse false;
    const tracks_arr = getArray(args.get("tracks")) orelse return error.MissingParam;

    var track_data: std.ArrayList(struct { samples: []f32, sr: u32 }) = .empty;
    defer {
        for (track_data.items) |td| {
            allocator.free(td.samples);
        }
        track_data.deinit(allocator);
    }

    var mix_tracks: std.ArrayList(mixer_mod.MixTrack) = .empty;
    defer mix_tracks.deinit(allocator);

    var max_sr: u32 = 44100;

    for (tracks_arr.items) |track_val| {
        const track_obj = getObject(track_val) orelse continue;
        const path = getString(track_obj.get("path")) orelse continue;
        const gain_f = getNumber(track_obj.get("gain")) orelse 1.0;
        const offset_ms_f = getNumber(track_obj.get("offset_ms")) orelse 0.0;

        const data = try wav.readWav(allocator, path);
        if (data.info.sample_rate > max_sr) max_sr = data.info.sample_rate;

        const sr_f: f32 = @floatFromInt(data.info.sample_rate);
        const offset_samples: usize = @intFromFloat(@as(f64, offset_ms_f) * @as(f64, sr_f) / 1000.0);

        try track_data.append(allocator, .{ .samples = data.samples, .sr = data.info.sample_rate });
        try mix_tracks.append(allocator, .{
            .samples = data.samples,
            .gain = @floatCast(gain_f),
            .offset_samples = offset_samples,
        });
    }

    const mixed = try mixer_mod.mixTracks(allocator, mix_tracks.items);
    defer allocator.free(mixed);

    if (do_normalize) {
        mixer_mod.normalize(mixed, -1.0);
    }

    try wav.writeWav(output_path, mixed, max_sr);

    const duration_ms = @as(u64, mixed.len) * 1000 / @as(u64, max_sr);
    return try std.fmt.allocPrint(
        allocator,
        "Mixed: {s}\ntracks: {d}\nduration_ms: {d}\nsample_rate: {d}",
        .{ output_path, tracks_arr.items.len, duration_ms, max_sr },
    );
}

fn execWavInfo(allocator: std.mem.Allocator, args: std.json.ObjectMap) ![]const u8 {
    const path = getString(args.get("path")) orelse return error.MissingParam;
    const info = try wav.getWavInfo(allocator, path);

    return try std.fmt.allocPrint(
        allocator,
        "path: {s}\nsample_rate: {d}\nchannels: {d}\nbit_depth: {d}\nduration_ms: {d}\ntotal_samples: {d}\nrms_db: {d:.1}\npeak_db: {d:.1}",
        .{ path, info.sample_rate, info.channels, info.bit_depth, info.duration_ms, info.total_samples, info.rms_db, info.peak_db },
    );
}

fn execWavPlay(allocator: std.mem.Allocator, args: std.json.ObjectMap) ![]const u8 {
    const path = getString(args.get("path")) orelse return error.MissingParam;

    // Check OS and spawn appropriate player
    const os_tag = @import("builtin").os.tag;
    if (os_tag == .macos) {
        var child = std.process.Child.init(&[_][]const u8{ "afplay", path }, allocator);
        _ = try child.spawn();
        return try std.fmt.allocPrint(allocator, "Playing: {s} (afplay)", .{path});
    } else if (os_tag == .linux) {
        var child = std.process.Child.init(&[_][]const u8{ "aplay", path }, allocator);
        _ = try child.spawn();
        return try std.fmt.allocPrint(allocator, "Playing: {s} (aplay)", .{path});
    } else {
        return error.UnsupportedPlatform;
    }
}
