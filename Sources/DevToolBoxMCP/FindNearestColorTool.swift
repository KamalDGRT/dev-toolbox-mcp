import DevToolBoxCore
import Foundation

public enum ToolError: Error, Equatable, LocalizedError {
    case missingColor
    case invalidHex(String)
    case invalidRGB

    public var errorDescription: String? {
        switch self {
        case .missingColor:
            return "Provide either `hex` (e.g. \"#F26522\") or all of `r`, `g`, `b`."
        case .invalidHex(let value):
            return "Invalid hex \"\(value)\"; expected #RGB, #RGBA, #RRGGBB or #RRGGBBAA."
        case .invalidRGB:
            return "r, g, b must be integers between 0 and 255."
        }
    }
}

/// `find_nearest_color`: maps a hex/RGB value to the closest color assets.
public struct FindNearestColorTool: Sendable {
    public static let name = "find_nearest_color"

    /// Resolved on every call so a missing config surfaces as a tool error
    /// (the server still starts) and config edits apply without a restart.
    public let loadConfig: @Sendable () throws -> ServerConfig

    public init(loadConfig: @escaping @Sendable () throws -> ServerConfig) {
        self.loadConfig = loadConfig
    }

    public init(config: ServerConfig) {
        self.init(loadConfig: { config })
    }

    public static var definition: [String: Any] { [
        "name": name,
        "description": "Find the Xcode color assets closest to a hex or RGB "
            + "value (CIE76 Delta E). Delta E < 1 is an exact match; use the "
            + "returned asset name instead of a hardcoded hex.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "hex": ["type": "string", "description": "#RGB, #RGBA, #RRGGBB or #RRGGBBAA (hash optional)"],
                "r": ["type": "integer", "minimum": 0, "maximum": 255],
                "g": ["type": "integer", "minimum": 0, "maximum": 255],
                "b": ["type": "integer", "minimum": 0, "maximum": 255],
                "limit": ["type": "integer", "minimum": 1,
                          "description": "Max matches; defaults to config maxResults."]
            ]
        ] as [String: Any]
    ] }

    /// Returns pretty JSON text listing matches, closest first.
    public func run(arguments: [String: Any]) throws -> String {
        let target = try Self.targetColor(from: arguments)
        let config = try loadConfig()
        let limit = (arguments["limit"] as? Int).map { max($0, 1) }
            ?? config.maxResults
        var assets: [ColorAsset] = []
        for catalogURL in config.catalogURLs {
            assets += try ColorAssetCatalog.load(from: catalogURL)
        }
        let matches = NearestColorFinder.nearest(
            to: target, in: assets, limit: limit
        )
        let rows: [[String: Any]] = matches.map { match in
            [
                "name": match.asset.name,
                "hex": match.asset.color.hexString,
                "deltaE": (match.deltaE * 100).rounded() / 100,
                "exact": match.isExact,
                "alpha": match.asset.color.alpha,
                "catalog": match.asset.catalogName,
                "folder": match.asset.folderPath
            ]
        }
        let payload: [String: Any] = [
            "query": target.hexString,
            "matches": rows
        ]
        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(decoding: data, as: UTF8.self)
    }

    static func targetColor(from arguments: [String: Any]) throws -> SRGBColor {
        if let hex = arguments["hex"] as? String {
            guard let color = SRGBColor(hex: hex) else {
                throw ToolError.invalidHex(hex)
            }
            return color
        }
        guard arguments["r"] != nil || arguments["g"] != nil
                || arguments["b"] != nil else {
            throw ToolError.missingColor
        }
        guard let red = arguments["r"] as? Int,
              let green = arguments["g"] as? Int,
              let blue = arguments["b"] as? Int,
              let color = SRGBColor(redByte: red, greenByte: green, blueByte: blue) else {
            throw ToolError.invalidRGB
        }
        return color
    }
}
