# 16bits-audio-mcp

ゲーム用BGM・SE・ジングルを生成するZig製MCPサーバー。

## ビルド・実行

```bash
zig build                    # ビルド
zig fmt src/                 # フォーマット
```

バイナリ: `zig-out/bin/16bits-audio-mcp`

## テスト方法

```bash
# initialize
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}' | ./zig-out/bin/16bits-audio-mcp 2>/dev/null

# tools/list
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | ./zig-out/bin/16bits-audio-mcp 2>/dev/null

# SE生成
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"se_gen","arguments":{"output":"/tmp/test.wav","type":"jump","pitch":1.0,"volume":0.8,"sample_rate":44100}}}' | ./zig-out/bin/16bits-audio-mcp 2>/dev/null
```

## アーキテクチャ

```
src/
├── main.zig              # エントリーポイント
├── mcp/
│   ├── protocol.zig      # JSON-RPC 2.0 応答生成
│   ├── server.zig        # stdin読み取り・メソッドディスパッチ
│   └── tools.zig         # 9ツールの定義・引数パース・実行
└── audio/
    ├── wav.zig           # WAVファイル読み書き（16bit PCM）
    ├── oscillator.zig    # 波形生成（sine/square/sawtooth/triangle/pulse/noise）
    ├── envelope.zig      # ADSRエンベロープ
    ├── fm.zig            # FM合成（2オペレータ）
    ├── filter.zig        # ローパス/ハイパス/バンドパスフィルタ
    ├── effects.zig       # シュローダーリバーブ・ディレイ
    ├── sequencer.zig     # 音楽理論（ノート→Hz、スケール、コード進行）
    ├── mixer.zig         # マルチトラックミキシング・ノーマライズ・クロスフェード
    └── generators/
        ├── bgm.zig       # BGM生成（4トラック構成）
        ├── jingle.zig    # ジングル生成
        └── se.zig        # SE生成
```

## 重要な設計方針

- 外部依存ゼロ（Zig標準ライブラリのみ）
- 内部処理は f32 (-1.0〜1.0)、出力時に i16 クランプ
- stdout は JSON-RPC 専用、ログは stderr
- MCP: 改行区切り JSON-RPC 2.0（Content-Length ヘッダーなし）
- Zig 0.15.x の新IO API使用（`File.readerStreaming`/`writerStreaming` + `.interface`）
