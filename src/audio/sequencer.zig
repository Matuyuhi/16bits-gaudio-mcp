const std = @import("std");

pub const Scale = enum {
    major,
    minor,
    pentatonic,
    blues,
};

pub const ChordQuality = enum {
    major_chord,
    minor_chord,
};

pub const ChordInfo = struct {
    root_semitone: i8, // semitone offset from key root
    quality: ChordQuality,
};

/// Scale intervals (semitone offsets from root)
pub fn getScaleIntervals(scale: Scale) []const u8 {
    return switch (scale) {
        .major => &[_]u8{ 0, 2, 4, 5, 7, 9, 11 },
        .minor => &[_]u8{ 0, 2, 3, 5, 7, 8, 10 },
        .pentatonic => &[_]u8{ 0, 2, 4, 7, 9 },
        .blues => &[_]u8{ 0, 3, 5, 6, 7, 10 },
    };
}

/// Convert note name (e.g., "C4", "A#3", "Bb5") to MIDI number
pub fn noteToMidi(name: []const u8) !u8 {
    if (name.len < 2 or name.len > 3) return error.InvalidNoteName;

    var idx: usize = 0;
    const base: u8 = switch (name[idx]) {
        'C' => 0,
        'D' => 2,
        'E' => 4,
        'F' => 5,
        'G' => 7,
        'A' => 9,
        'B' => 11,
        else => return error.InvalidNoteName,
    };
    idx += 1;

    var semitone: i8 = @intCast(base);
    if (idx < name.len and name[idx] == '#') {
        semitone += 1;
        idx += 1;
    } else if (idx < name.len and name[idx] == 'b') {
        semitone -= 1;
        idx += 1;
    }

    if (idx >= name.len) return error.InvalidNoteName;
    const octave = std.fmt.parseInt(i8, name[idx..], 10) catch return error.InvalidNoteName;

    const midi: i16 = @as(i16, octave + 1) * 12 + @as(i16, semitone);
    if (midi < 0 or midi > 127) return error.InvalidNoteName;
    return @intCast(midi);
}

/// Convert MIDI number to frequency in Hz
pub fn midiToHz(midi: u8) f32 {
    const m: f32 = @floatFromInt(midi);
    return 440.0 * std.math.pow(f32, 2.0, (m - 69.0) / 12.0);
}

/// Convert note name directly to Hz
pub fn noteToHz(name: []const u8) !f32 {
    const midi = try noteToMidi(name);
    return midiToHz(midi);
}

/// Parse key name to root semitone (0=C, 1=C#, ..., 11=B)
pub fn keyToSemitone(key: []const u8) !u8 {
    if (key.len == 0) return error.InvalidKey;
    const base: u8 = switch (key[0]) {
        'C' => 0,
        'D' => 2,
        'E' => 4,
        'F' => 5,
        'G' => 7,
        'A' => 9,
        'B' => 11,
        else => return error.InvalidKey,
    };
    if (key.len > 1) {
        if (key[1] == '#') return (base + 1) % 12;
        if (key[1] == 'b') return (base + 11) % 12;
    }
    return base;
}

/// Parse scale name
pub fn parseScale(name: []const u8) !Scale {
    if (std.mem.eql(u8, name, "major")) return .major;
    if (std.mem.eql(u8, name, "minor")) return .minor;
    if (std.mem.eql(u8, name, "pentatonic")) return .pentatonic;
    if (std.mem.eql(u8, name, "blues")) return .blues;
    return error.InvalidScale;
}

/// Get chord progression for a given style.
/// Returns array of ChordInfo for a 4-bar loop.
pub fn getChordProgression(style: []const u8) ![]const ChordInfo {
    if (std.mem.eql(u8, style, "adventure")) {
        // I - IV - V - I
        return &[_]ChordInfo{
            .{ .root_semitone = 0, .quality = .major_chord },
            .{ .root_semitone = 5, .quality = .major_chord },
            .{ .root_semitone = 7, .quality = .major_chord },
            .{ .root_semitone = 0, .quality = .major_chord },
        };
    }
    if (std.mem.eql(u8, style, "dungeon")) {
        // i - VI - VII - i
        return &[_]ChordInfo{
            .{ .root_semitone = 0, .quality = .minor_chord },
            .{ .root_semitone = 8, .quality = .major_chord },
            .{ .root_semitone = 10, .quality = .major_chord },
            .{ .root_semitone = 0, .quality = .minor_chord },
        };
    }
    if (std.mem.eql(u8, style, "boss")) {
        // i - bVII - bVI - V
        return &[_]ChordInfo{
            .{ .root_semitone = 0, .quality = .minor_chord },
            .{ .root_semitone = 10, .quality = .major_chord },
            .{ .root_semitone = 8, .quality = .major_chord },
            .{ .root_semitone = 7, .quality = .major_chord },
        };
    }
    if (std.mem.eql(u8, style, "town")) {
        // I - V - vi - IV
        return &[_]ChordInfo{
            .{ .root_semitone = 0, .quality = .major_chord },
            .{ .root_semitone = 7, .quality = .major_chord },
            .{ .root_semitone = 9, .quality = .minor_chord },
            .{ .root_semitone = 5, .quality = .major_chord },
        };
    }
    if (std.mem.eql(u8, style, "battle")) {
        // ii - V - I - VI
        return &[_]ChordInfo{
            .{ .root_semitone = 2, .quality = .minor_chord },
            .{ .root_semitone = 7, .quality = .major_chord },
            .{ .root_semitone = 0, .quality = .major_chord },
            .{ .root_semitone = 9, .quality = .major_chord },
        };
    }
    return error.UnknownStyle;
}

/// Get beats per bar for a given style
pub fn getBeatsPerBar(style: []const u8) u8 {
    if (std.mem.eql(u8, style, "town")) return 3; // 3/4 time
    return 4; // 4/4 time
}

/// Get chord tones as semitone offsets from chord root
pub fn getChordTones(quality: ChordQuality) [3]u8 {
    return switch (quality) {
        .major_chord => .{ 0, 4, 7 }, // root, major 3rd, perfect 5th
        .minor_chord => .{ 0, 3, 7 }, // root, minor 3rd, perfect 5th
    };
}

/// Generate a scale-based MIDI note for a given degree in octave
pub fn scaleNote(root_semitone: u8, scale: Scale, degree: i16, octave: u8) u8 {
    const intervals = getScaleIntervals(scale);
    const len: i16 = @intCast(intervals.len);

    // Handle negative degrees
    var d = @mod(degree, len);
    const oct_offset: i16 = @divFloor(degree, len);

    if (d < 0) d += len;

    const semitone: i16 = @as(i16, root_semitone) + @as(i16, intervals[@intCast(d)]);
    const midi: i16 = (@as(i16, octave) + 1 + oct_offset) * 12 + semitone;

    if (midi < 0) return 0;
    if (midi > 127) return 127;
    return @intCast(midi);
}
