import DevToolBoxCore
import Foundation

/// `compare_colors`: perceptual difference (CIE76 Delta E) between two colors.
public struct CompareColorsTool: MCPTool {
    public static let name = "compare_colors"

    public init() {}

    public static var definition: [String: Any] { [
        "name": name,
        "description": "Delta E (CIE76) between two colors given as hex or RGB. "
            + "Delta E < 1 is imperceptible; ~2 barely noticeable; > 10 clearly different.",
        "inputSchema": [
            "type": "object",
            "properties": ["a": ColorSchema.value, "b": ColorSchema.value],
            "required": ["a", "b"]
        ] as [String: Any]
    ] }

    public func run(arguments: [String: Any]) throws -> String {
        let first = try ColorArgument.parse(arguments["a"], argument: "a")
        let second = try ColorArgument.parse(arguments["b"], argument: "b")
        let delta = ColorDistance.deltaE(first, second)
        return try ToolJSON.pretty([
            "a": ["hex": first.hexString, "rgb": first.rgbString],
            "b": ["hex": second.hexString, "rgb": second.rgbString],
            "deltaE": ToolJSON.roundedDeltaE(delta),
            "identical": delta < NearestColorFinder.exactDeltaEThreshold
        ])
    }
}
