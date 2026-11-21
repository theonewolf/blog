# mkdocs-material Based Blog

This powers [theonewolf.com](https://www.theonewolf.com/).

## Running in Developer Mode (Live Reload)

Install dependencies once with [`uv`](https://docs.astral.sh/uv/) (requires Python 3.11+):

```bash
uv sync
```

Start the local live-reloading dev server:

```bash
uv run mkdocs serve
```

- Opens at **http://127.0.0.1:8000/** by default and automatically rebuilds/reloads your browser whenever you edit files under `docs/`, `mkdocs.yml`, or `src/`.
- To use a different port: `uv run mkdocs serve -a 127.0.0.1:8080`
- For faster incremental rebuilds on large edits: `uv run mkdocs serve --dirtyreload`
- Press `Ctrl+C` in the terminal to stop the server.

## Build

```bash
uv run mkdocs build --strict
```

## Zig FFSEM Source & WebAssembly

Source code lives under `src/zig-ffsem/` (kept out of published site pages, embedded in posts via `pymdownx.snippets`):

```bash
# Run unit tests
zig test src/zig-ffsem/ffsem.zig
zig test src/zig-ffsem/wasm.zig

# Rebuild docs/wasm/ffsem.wasm
zig build-exe src/zig-ffsem/wasm.zig \
  -target wasm32-freestanding -O ReleaseSmall -fno-entry -rdynamic \
  -femit-bin=docs/wasm/ffsem.wasm
```
