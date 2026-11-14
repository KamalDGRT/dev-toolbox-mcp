# dev-toolbox-mcp

[MCP](https://modelcontextprotocol.io) server (stdio) that exposes DevToolBox logic to AI assistants. It
uses [DevToolBoxCore](https://github.com/KamalDGRT/DevToolBoxCore), the same package the
[DevToolBox](https://github.com/KamalDGRT/DevToolBox) macOS app uses, so results match the app.

## Tools

| Tool | Input | Output |
|---|---|---|
| `find_nearest_color` | `hex` (`#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`) **or** `r`,`g`,`b` (0-255) | Closest `.colorset` assets by CIE76 ΔE (`< 1` = exact). |

## Setup

1. Build:
   ```bash
   swift build -c release   # binary: .build/release/dev-toolbox-mcp
   ```
2. Add `<project>/.devtoolboxmcp/config.json` (found by walking up from the working directory, or set
   `DEV_TOOLBOX_MCP_CONFIG` to an explicit file):
   ```json
   { "xcassetsPaths": ["App/Assets/Colors.xcassets"], "maxResults": 5 }
   ```
   Relative paths resolve against the folder holding `.devtoolboxmcp`; absolute paths are used as-is.
   `maxResults` is optional (default 5).
3. Register with your client, e.g. Claude Code:
   ```bash
   claude mcp add dev-toolbox -- /path/to/dev-toolbox-mcp/.build/release/dev-toolbox-mcp
   ```
   Run it from (or below) the project that holds the config.

## Develop

```bash
swift test
```

DevToolBoxCore is pulled from GitHub at the version in `Package.swift`. To hack on both together, temporarily
use `.package(path: "../DevToolBoxCore")`; switch back to the tagged URL before committing.

## Versioning

[Semantic Versioning](https://semver.org), tagged `vX.Y.Z` on `main`. Bump the `DevToolBoxCore` `from:`
version whenever you need new Core API. Release: `git tag vX.Y.Z && git push origin main --tags`.

| Version | Notes |
|---|---|
| 0.2.0 | Depends on DevToolBoxCore 0.2.0 (hex shorthand/alpha, shared byte validation). Fix: config search no longer loops forever at filesystem root. |
| 0.1.0 | Initial `find_nearest_color` tool. |
