import DevToolBoxCore
import Foundation

/// `rgba_to_rgb`: flattens a translucent color over a background.
public struct RGBAToRGBTool: MCPTool {
    public static let name = "rgba_to_rgb"
    private static let whiteKeyword = "white"
    private static let blackKeyword = "black"

    public init() {}

    public static var definition: [String: Any] { [
        "name": name,
        "description": "Composite an RGBA color over a background and return the flat "
            + "RGB value as hex and rgb. Background defaults to white.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "color": ColorSchema.value,
                "background": [
                    "description": "\"white\" (default), \"black\", a hex string or an {r,g,b} object."
                ]
            ],
            "required": ["color"]
        ] as [String: Any]
    ] }

    public func run(arguments: [String: Any]) throws -> String {
        let color = try ColorArgument.parse(arguments["color"], argument: "color")
        let background = try Self.background(from: arguments["background"])
        let flat = color.composited(over: background)
        return try ToolJSON.pretty([
            "input": ["hex": color.hexString, "alpha": color.alpha],
            "background": background.hexString,
            "hex": flat.hexString,
            "rgb": flat.rgbString
        ])
    }

    private static func background(from value: Any?) throws -> SRGBColor {
        guard let value else { return .white }
        if let keyword = (value as? String)?.lowercased() {
            if keyword == whiteKeyword { return .white }
            if keyword == blackKeyword { return .black }
        }
        do {
            return try ColorArgument.parse(value, argument: "background")
        } catch {
            throw ToolError.invalidBackground(String(describing: value))
        }
    }
}
