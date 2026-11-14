import DevToolBoxCore
import Foundation

/// `search_assets`: text search over the project's color assets.
public struct SearchAssetsTool: MCPTool {
    public static let name = "search_assets"
    static let defaultLimit = 50

    public let loadConfig: @Sendable () throws -> ServerConfig

    public init(loadConfig: @escaping @Sendable () throws -> ServerConfig) {
        self.loadConfig = loadConfig
    }

    public static var definition: [String: Any] { [
        "name": name,
        "description": "Search the project's color assets by name, hex (e.g. \"#0061A5\"), "
            + "RGB (e.g. \"0, 97, 165\") or folder. Case-insensitive substring match. "
            + "For the closest color to an arbitrary value use find_nearest_color.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "query": ["type": "string"],
                "limit": ["type": "integer", "minimum": 1,
                          "description": "Max results; default \(defaultLimit)."]
            ],
            "required": ["query"]
        ] as [String: Any]
    ] }

    public func run(arguments: [String: Any]) throws -> String {
        guard let query = arguments["query"] as? String,
              !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolError.missingQuery
        }
        let limit = (arguments["limit"] as? Int).map { max($0, 1) } ?? Self.defaultLimit
        let found = ColorAssetSearch.matching(query, in: try loadConfig().loadAssets())
        return try ToolJSON.pretty([
            "query": query,
            "total": found.count,
            "matches": found.prefix(limit).map(ToolJSON.row)
        ])
    }
}
