.PHONY: build run test fmt clean install

build:
	zig build

release:
	zig build -Doptimize=ReleaseSafe

run:
	zig build run

fmt:
	zig fmt src/

clean:
	rm -rf .zig-cache zig-out

install: release
	mkdir -p $(HOME)/.local/bin
	cp zig-out/bin/16bits-audio-mcp $(HOME)/.local/bin/
	@echo "Installed to $(HOME)/.local/bin/16bits-audio-mcp"

test: build
	@echo "=== initialize ==="
	@echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}' \
		| ./zig-out/bin/16bits-audio-mcp 2>/dev/null
	@echo ""
	@echo "=== se_gen ==="
	@echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"se_gen","arguments":{"output":"/tmp/test_se.wav","type":"jump","pitch":1.0,"volume":0.8,"sample_rate":44100}}}' \
		| ./zig-out/bin/16bits-audio-mcp 2>/dev/null
	@echo ""
	@echo "=== bgm_compose ==="
	@echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"bgm_compose","arguments":{"output":"/tmp/test_bgm.wav","style":"adventure","bpm":140,"duration_bars":4,"sample_rate":44100,"key":"C","scale":"major","seed":42}}}' \
		| ./zig-out/bin/16bits-audio-mcp 2>/dev/null
	@echo ""
	@echo "=== jingle_gen ==="
	@echo '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"jingle_gen","arguments":{"output":"/tmp/test_jingle.wav","type":"stage_clear","sample_rate":44100,"key":"C","tempo_feel":"normal"}}}' \
		| ./zig-out/bin/16bits-audio-mcp 2>/dev/null
	@echo ""
	@file /tmp/test_se.wav /tmp/test_bgm.wav /tmp/test_jingle.wav
	@echo ""
	@echo "All tests passed."
