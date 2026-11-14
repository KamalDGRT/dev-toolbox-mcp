import DevToolBoxCore
import Foundation

/// `find_duplicate_colors`: colorsets that share the same hex under different names.
public struct FindDuplicateColorsTool: MCPTool {
    public static let name = "find_duplicate_colors"

    public let loadConfig: @Sendable () throws -> ServerConfig

    public init(loadConfig: @escaping @Sendable () throws -> ServerConfig) {
        self.loadConfig = loadConfig
    }

    public static var definition: [String: Any] { [
        "name": name,
        "description": "List color assets that resolve to the same hex value under different names.",
        "inputSchema": ["type": "object", "properties": [String: Any]()] as [String: Any]
    ] }

    public func run(arguments: [String: Any]) throws -> String {
        let groups = DuplicateColorFinder.groups(in: try loadConfig().loadAssets())
        return try ToolJSON.pretty([
            "groupCount": groups.count,
            "groups": groups.map { group in
                ["hex": group.hex, "assets": group.assets.map(ToolJSON.row)] as [String: Any]
            }
        ])
    }
}
