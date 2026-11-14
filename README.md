# dev-toolbox-mcp

[MCP](https://modelcontextprotocol.io) server (stdio) that exposes DevToolBox logic to AI assistants. It
uses [DevToolBoxCore](https://github.com/KamalDGRT/DevToolBoxCore), the same package the
[DevToolBox](https://github.com/KamalDGRT/DevToolBox) macOS app uses, so results match the app.

## Tools

| Tool | Input | Output |
|---|---|---|
| `find_nearest_color` | `hex` (`#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`) **or** `r`,`g`,`b` (0-255), optional `limit` | Closest `.colorset` assets by CIE76 ΔE (`< 1` = exact, so the asset name replaces a hardcoded hex). |
| `search_assets` | `query` (name, hex, RGB or folder substring), optional `limit` (default 50) | Matching assets with name, hex, rgb, alpha, catalog, folder. |
| `find_duplicate_colors` | none | Groups of assets that share the same hex. |
| `compare_colors` | `a`, `b`: each a hex string or `{r,g,b,a?}` | ΔE between the two, and whether they are identical (`< 1`). |
| `rgba_to_rgb` | `color` (hex incl. alpha or `{r,g,b,a}`), optional `background` (`white` default, `black`, hex, `{r,g,b}`) | Flattened hex and rgb. |

`compare_colors` and `rgba_to_rgb` need no config; the asset tools read `.devtoolboxmcp/config.json`.

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
   Use `--scope user` to register it for every project. Claude Code starts the server in the project's
   directory, so each project uses its own config. Projects without one get a clear error from the tool call;
   the server itself still connects.

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
| 0.3.0 | New tools: `search_assets`, `find_duplicate_colors`, `compare_colors`, `rgba_to_rgb`. Depends on DevToolBoxCore 0.3.0. |
| 0.2.2 | `deltaE` in tool output rounded to two decimals (was `0.34999999999999998`). |
| 0.2.1 | Fix: server no longer exits when no config is found (`CONNECTION_CLOSED` in `claude mcp list`); the error is returned by the tool call instead. Config is read per call, so edits apply without a restart. |
| 0.2.0 | Depends on DevToolBoxCore 0.2.0 (hex shorthand/alpha, shared byte validation). Fix: config search no longer loops forever at filesystem root. |
| 0.1.0 | Initial `find_nearest_color` tool. |
