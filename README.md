# 16bits-audio-mcp

A Zig-powered MCP server that generates game audio — loopable BGMs, sound effects, and jingles — as 16-bit PCM WAV files.

Claude calls the tools, and `.wav` files come out. That's it.

- Zero external dependencies (Zig standard library only)
- 16-bit PCM WAV output
- FM synthesis, Schroeder reverb, ADSR envelopes, multi-track mixing

## Install

### Homebrew (recommended)

```bash
brew tap Matuyuhi/tools
brew install 16bits-audio-mcp
```

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/Matuyuhi/16bits-gaudio-mcp/main/install.sh | bash
```

### Build from source

```bash
git clone https://github.com/Matuyuhi/16bits-gaudio-mcp.git
cd 16bits-gaudio-mcp
make install   # installs to ~/.local/bin
```

Or just:

```bash
zig build
# binary: zig-out/bin/16bits-audio-mcp
```

## Configuration

### Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "16bits-audio": {
      "command": "16bits-audio-mcp"
    }
  }
}
```

### Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "16bits-audio": {
      "command": "16bits-audio-mcp"
    }
  }
}
```

If you built from source, use the full path instead:

```json
{
  "mcpServers": {
    "16bits-audio": {
      "command": "/path/to/zig-out/bin/16bits-audio-mcp"
    }
  }
}
```

## Tools (9 total)

### bgm_compose

Generate loopable BGM with 4 tracks (melody, bass, harmony, percussion).

| Parameter | Type | Description |
|---|---|---|
| output | string | Output WAV file path |
| style | string | `adventure` / `dungeon` / `boss` / `town` / `battle` |
| bpm | number | Beats per minute |
| duration_bars | number | Number of bars |
| sample_rate | number | Sample rate (e.g. 44100) |
| key | string | Musical key (e.g. "C", "F#") |
| scale | string | `major` / `minor` / `pentatonic` / `blues` |
| seed | number | Random seed for deterministic generation |

### jingle_gen

Generate short game event jingles (0.8–5 seconds).

| Parameter | Type | Description |
|---|---|---|
| output | string | Output WAV file path |
| type | string | `stage_clear` / `game_over` / `level_up` / `item_get` / `boss_clear` |
| sample_rate | number | Sample rate |
| key | string | Musical key |
| tempo_feel | string | `fast` / `normal` / `triumphant` |

### se_gen

Generate game sound effects (0.1–1.5 seconds).

| Parameter | Type | Description |
|---|---|---|
| output | string | Output WAV file path |
| type | string | `jump` / `hit` / `coin` / `explosion` / `laser` / `powerup` / `error` / `footstep` |
| pitch | number | Pitch multiplier (1.0 = standard, 0.5 = octave down, 2.0 = octave up) |
| volume | number | Volume (0.0–1.0) |
| sample_rate | number | Sample rate |

### note_synth

Synthesize single notes or chords to WAV (low-level API).

| Parameter | Type | Description |
|---|---|---|
| output | string | Output WAV file path |
| notes | string[] | Note names (e.g. ["C4", "E4", "G4"]) |
| waveform | string | `sine` / `square` / `sawtooth` / `triangle` / `pulse` |
| duration_ms | number | Duration in milliseconds |
| adsr | object | `{attack_ms, decay_ms, sustain_level, release_ms}` |
| sample_rate | number | Sample rate |
| reverb | boolean | Apply reverb |

### fm_patch

Generate a tone using FM synthesis (YM2612-style 2-operator).

| Parameter | Type | Description |
|---|---|---|
| output | string | Output WAV file path |
| carrier_note | string | Carrier note (e.g. "A2") |
| modulator_ratio | number | Modulator frequency ratio |
| modulation_index | number | FM modulation depth |
| carrier_adsr | object | Carrier ADSR envelope |
| modulator_adsr | object | Modulator ADSR envelope |
| duration_ms | number | Duration in milliseconds |
| sample_rate | number | Sample rate |

### wav_fx

Apply effects to an existing WAV file.

| Parameter | Type | Description |
|---|---|---|
| input | string | Input WAV file path |
| output | string | Output WAV file path |
| effects | object[] | Array of effects |

Effect types:
- `reverb`: `room_size` (0.0–1.0), `wet` (0.0–1.0)
- `delay`: `delay_ms`, `feedback` (0.0–0.9), `wet` (0.0–1.0)
- `lowpass`: `cutoff_hz`
- `highpass`: `cutoff_hz`

### wav_mix

Mix multiple WAV files into one.

| Parameter | Type | Description |
|---|---|---|
| tracks | object[] | `{path, gain, offset_ms}` array |
| output | string | Output WAV file path |
| normalize | boolean | Normalize peak to -1 dBFS |

### wav_info

Get WAV file metadata and waveform statistics.

| Parameter | Type | Description |
|---|---|---|
| path | string | WAV file path |

### wav_play

Play a WAV file asynchronously (macOS: afplay, Linux: aplay).

| Parameter | Type | Description |
|---|---|---|
| path | string | WAV file path |

## Example Prompts

```
Generate an 8-bar adventure BGM at 140 BPM in C major and play it
```

```
Create a stage clear jingle
```

```
Generate a jump SE and an explosion SE
```

```
Add reverb to the BGM and save it as a separate file
```

```
Synthesize a C major chord (C4, E4, G4) with sine wave for 1 second
```

```
Create an FM bass sound on A2 with modulator ratio 2.0 and depth 3.0
```

## Music Theory Reference

### Supported Keys

C, C#, D, D#, E, F, F#, G, G#, A, A#, B (and flats: Db, Eb, Gb, Ab, Bb)

### Scales

| Scale | Semitone offsets |
|---|---|
| major | 0, 2, 4, 5, 7, 9, 11 |
| minor | 0, 2, 3, 5, 7, 8, 10 |
| pentatonic | 0, 2, 4, 7, 9 |
| blues | 0, 3, 5, 6, 7, 10 |

### BGM Styles

| Style | Time sig. | Chord progression | BPM range |
|---|---|---|---|
| adventure | 4/4 | I–IV–V–I | 120–160 |
| dungeon | 4/4 | i–VI–VII–i | 80–100 |
| boss | 4/4 | i–bVII–bVI–V | 140–180 |
| town | 3/4 | I–V–vi–IV | 90–110 |
| battle | 4/4 | ii–V–I–VI | 160–200 |

### Note Range

C0–B9 (MIDI 12–131). A4 = 440 Hz.

## License

MIT
