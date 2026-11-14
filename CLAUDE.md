# CLAUDE.md

MCP stdio server exposing DevToolBox logic. See [README.md](README.md).

## Rules
- Color/catalog logic lives in DevToolBoxCore. Never reimplement parsing, validation or math here; add it to Core, tag a release, bump `from:` in `Package.swift`.
- This package only does MCP protocol, config loading and tool wiring.
- Keep `Package.swift` on the tagged remote URL when committing (no `path:` dependency).
- `swift test` before committing (tests must finish in seconds; a hang is a bug).
- Trunk: `main`. No co-author trailers on commits.
