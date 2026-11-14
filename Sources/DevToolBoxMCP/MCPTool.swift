import DevToolBoxCore
import Foundation

/// One MCP tool: static metadata plus a synchronous `run` returning text.
public protocol MCPTool: Sendable {
    static var name: String { get }
    static var definition: [String: Any] { get }
    func run(arguments: [String: Any]) throws -> String
}

public enum ToolError: Error, Equatable, LocalizedError {
    case missingColor
    case invalidHex(String)
    case invalidRGB
    case invalidColor(argument: String)
    case invalidBackground(String)
    case missingQuery

    public var errorDescription: String? {
        switch self {
        case .missingColor:
            return "Provide either `hex` (e.g. \"#F26522\") or all of `r`, `g`, `b`."
        case .invalidHex(let value):
            return "Invalid hex \"\(value)\"; expected #RGB, #RGBA, #RRGGBB or #RRGGBBAA."
        case .invalidRGB:
            return "r, g, b must be integers between 0 and 255."
        case .invalidColor(let argument):
            return "`\(argument)` must be a hex string (#RGB, #RGBA, #RRGGBB, #RRGGBBAA) "
                + "or an object {\"r\":0-255,\"g\":0-255,\"b\":0-255,\"a\":0-1 (optional)}."
        case .invalidBackground(let value):
            return "Invalid background \"\(value)\"; use \"white\", \"black\", a hex string or an {r,g,b} object."
        case .missingQuery:
            return "Provide a non-empty `query`."
        }
    }
}

/// Schema fragment shared by every tool that takes a color value.
enum ColorSchema {
    static var value: [String: Any] { [
        "description": "Hex string (#RGB, #RGBA, #RRGGBB, #RRGGBBAA) or object {r,g,b: 0-255, a: 0-1 optional}.",
        "oneOf": [
            ["type": "string"],
            ["type": "object", "properties": [
                "r": ["type": "integer", "minimum": 0, "maximum": 255],
                "g": ["type": "integer", "minimum": 0, "maximum": 255],
                "b": ["type": "integer", "minimum": 0, "maximum": 255],
                "a": ["type": "number", "minimum": 0, "maximum": 1]
            ], "required": ["r", "g", "b"]] as [String: Any]
        ]
    ] }
}

enum ColorArgument {
    /// Parses a hex string or an `{r,g,b,a?}` object.
    static func parse(_ value: Any?, argument: String) throws -> SRGBColor {
        if let hex = value as? String {
            guard let color = SRGBColor(hex: hex) else {
                throw ToolError.invalidColor(argument: argument)
            }
            return color
        }
        guard let object = value as? [String: Any],
              let red = integer(object["r"]),
              let green = integer(object["g"]),
              let blue = integer(object["b"]) else {
            throw ToolError.invalidColor(argument: argument)
        }
        let alpha = object["a"] == nil ? 1.0 : (object["a"] as? Double)
        guard let alpha,
              let color = SRGBColor(
                redByte: red, greenByte: green, blueByte: blue, alpha: alpha
              ) else {
            throw ToolError.invalidColor(argument: argument)
        }
        return color
    }
}

extension ColorArgument {
    /// JSON has one number type: accept `255` and `255.0`, reject `0.5`.
    static func integer(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        guard let double = value as? Double, double == double.rounded() else { return nil }
        return Int(exactly: double)
    }
}

enum ToolJSON {
    private static let deltaEDecimalPlaces = 2

    static func pretty(_ payload: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(decoding: data, as: UTF8.self)
    }

    /// Decimal (not Double) so JSON prints `0.35`, not `0.34999999999999998`.
    static func roundedDeltaE(_ value: Double) -> NSDecimalNumber {
        var source = Decimal(value)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, deltaEDecimalPlaces, .plain)
        return NSDecimalNumber(decimal: rounded)
    }

    static func row(_ asset: ColorAsset) -> [String: Any] {
        [
            "name": asset.name,
            "hex": asset.color.hexString,
            "rgb": asset.color.rgbString,
            "alpha": asset.color.alpha,
            "catalog": asset.catalogName,
            "folder": asset.folderPath
        ]
    }
}

extension ServerConfig {
    func loadAssets() throws -> [ColorAsset] {
        try catalogURLs.flatMap { try ColorAssetCatalog.load(from: $0) }
    }
}
