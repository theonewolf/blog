# mkdocs-material Based Blog

This powers [theonewolf.com](https://www.theonewolf.com/).

## Local Development

```bash
uv sync
uv run mkdocs serve
```

## Build

```bash
uv run mkdocs build
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
