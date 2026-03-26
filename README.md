# 16bits-audio-mcp

ゲーム用BGM・SE・ジングルを高品質に生成できるZig製MCPサーバー。
Claudeがツールを呼ぶだけで、ループ可能なBGM・クリア音・効果音などの.wavファイルを生成できます。

- 外部依存ゼロ（全てZig標準ライブラリのみ）
- 16bit PCM WAV出力
- FM合成・シュローダーリバーブ・ADSR・マルチトラックミキシング搭載

## インストール

### Homebrew（推奨）

```bash
brew tap Matuyuhi/Matuyuhi-homebrew-tools https://github.com/Matuyuhi/Matuyuhi-homebrew-tools
brew install 16bits-audio-mcp
```

### ワンライナー

```bash
curl -fsSL https://raw.githubusercontent.com/Matuyuhi/16bits-gaudio-mcp/main/install.sh | bash
```

### ソースからビルド

```bash
git clone https://github.com/Matuyuhi/16bits-gaudio-mcp.git
cd 16bits-gaudio-mcp
make install   # ~/.local/bin にインストール
```

または:

```bash
zig build
# バイナリ: zig-out/bin/16bits-audio-mcp
```

## Claude Desktop設定

`~/Library/Application Support/Claude/claude_desktop_config.json` に以下を追加:

```json
{
  "mcpServers": {
    "16bits-audio": {
      "command": "16bits-audio-mcp"
    }
  }
}
```

Homebrew/install.shでインストールした場合はバイナリ名だけでOKです。
ソースビルドの場合はフルパスを指定してください:

```json
{
  "mcpServers": {
    "16bits-audio": {
      "command": "/path/to/zig-out/bin/16bits-audio-mcp"
    }
  }
}
```

設定例は `examples/claude_desktop_config.json` にあります。

## ツールリファレンス（全9種）

### bgm_compose

ループ可能なBGMをマルチトラック（メロディ・ベース・ハーモニー・パーカッション）で生成。

| パラメータ | 型 | 説明 |
|---|---|---|
| output | string | 出力WAVファイルパス |
| style | string | `adventure` / `dungeon` / `boss` / `town` / `battle` |
| bpm | number | テンポ（BPM） |
| duration_bars | number | 小節数 |
| sample_rate | number | サンプルレート（例: 44100） |
| key | string | 調（例: "C", "F#"） |
| scale | string | `major` / `minor` / `pentatonic` / `blues` |
| seed | number | 乱数シード（決定的生成用） |

### jingle_gen

ゲームイベント用ジングル・クリア音を生成（0.8〜5秒）。

| パラメータ | 型 | 説明 |
|---|---|---|
| output | string | 出力WAVファイルパス |
| type | string | `stage_clear` / `game_over` / `level_up` / `item_get` / `boss_clear` |
| sample_rate | number | サンプルレート |
| key | string | 調 |
| tempo_feel | string | `fast` / `normal` / `triumphant` |

### se_gen

ゲーム効果音を生成（0.1〜1.5秒）。

| パラメータ | 型 | 説明 |
|---|---|---|
| output | string | 出力WAVファイルパス |
| type | string | `jump` / `hit` / `coin` / `explosion` / `laser` / `powerup` / `error` / `footstep` |
| pitch | number | ピッチ倍率（1.0=標準、0.5=1oct下、2.0=1oct上） |
| volume | number | 音量（0.0〜1.0） |
| sample_rate | number | サンプルレート |

### note_synth

単音または和音を合成してWAVに書き出す（ローレベルAPI）。

| パラメータ | 型 | 説明 |
|---|---|---|
| output | string | 出力WAVファイルパス |
| notes | string[] | ノート名（例: ["C4", "E4", "G4"]） |
| waveform | string | `sine` / `square` / `sawtooth` / `triangle` / `pulse` |
| duration_ms | number | 長さ（ms） |
| adsr | object | `{attack_ms, decay_ms, sustain_level, release_ms}` |
| sample_rate | number | サンプルレート |
| reverb | boolean | リバーブ適用 |

### fm_patch

FM合成で1音を生成（YM2612風2オペレータ構成）。

| パラメータ | 型 | 説明 |
|---|---|---|
| output | string | 出力WAVファイルパス |
| carrier_note | string | キャリアノート（例: "A2"） |
| modulator_ratio | number | モジュレータ周波数比 |
| modulation_index | number | FM変調の深さ |
| carrier_adsr | object | キャリアADSR |
| modulator_adsr | object | モジュレータADSR |
| duration_ms | number | 長さ（ms） |
| sample_rate | number | サンプルレート |

### wav_fx

既存WAVにエフェクトをかけて新しいWAVを生成。

| パラメータ | 型 | 説明 |
|---|---|---|
| input | string | 入力WAVファイルパス |
| output | string | 出力WAVファイルパス |
| effects | object[] | エフェクト配列 |

エフェクト種別:
- `reverb`: `room_size`（0.0〜1.0）, `wet`（0.0〜1.0）
- `delay`: `delay_ms`, `feedback`（0.0〜0.9）, `wet`（0.0〜1.0）
- `lowpass`: `cutoff_hz`
- `highpass`: `cutoff_hz`

### wav_mix

複数WAVをミックス。

| パラメータ | 型 | 説明 |
|---|---|---|
| tracks | object[] | `{path, gain, offset_ms}` の配列 |
| output | string | 出力WAVファイルパス |
| normalize | boolean | true でピークを -1dBFS にノーマライズ |

### wav_info

WAVファイルのメタデータと波形統計を返す。

| パラメータ | 型 | 説明 |
|---|---|---|
| path | string | WAVファイルパス |

### wav_play

WAVを非同期再生（macOS: afplay、Linux: aplay）。

| パラメータ | 型 | 説明 |
|---|---|---|
| path | string | WAVファイルパス |

## Claudeへのサンプルプロンプト

```
アドベンチャーゲーム用BGMを8バー、BPM140のCメジャーで生成して再生して
```

```
ステージクリア音を生成して
```

```
ジャンプSEと爆発SEを生成して
```

```
BGMにリバーブをかけて別ファイルで保存して
```

```
Cメジャーの和音（C4, E4, G4）をサイン波で1秒間合成して
```

```
FM合成でA2のベース音を作って。モジュレータ比2.0、変調深度3.0で
```

## 音楽理論の制約

### 対応キー

C, C#, D, D#, E, F, F#, G, G#, A, A#, B（及びフラット表記: Db, Eb, Gb, Ab, Bb）

### 対応スケール

| スケール | 半音オフセット |
|---|---|
| major | 0, 2, 4, 5, 7, 9, 11 |
| minor | 0, 2, 3, 5, 7, 8, 10 |
| pentatonic | 0, 2, 4, 7, 9 |
| blues | 0, 3, 5, 6, 7, 10 |

### BGMスタイル

| スタイル | 拍子 | コード進行 | BPM目安 |
|---|---|---|---|
| adventure | 4/4 | I-IV-V-I | 120-160 |
| dungeon | 4/4 | i-VI-VII-i | 80-100 |
| boss | 4/4 | i-bVII-bVI-V | 140-180 |
| town | 3/4 | I-V-vi-IV | 90-110 |
| battle | 4/4 | ii-V-I-VI | 160-200 |

### ノート範囲

C0〜B9（MIDI 12〜131）。A4 = 440Hz。
