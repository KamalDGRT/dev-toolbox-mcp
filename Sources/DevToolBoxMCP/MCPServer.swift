import Foundation

/// Minimal MCP server over newline-delimited JSON-RPC (stdio transport).
public struct MCPServer: Sendable {
    public static let serverName = "dev-toolbox-mcp"
    public static let serverVersion = "0.1.0"
    static let fallbackProtocolVersion = "2025-03-26"

    private enum ErrorCode {
        static let parse = -32700
        static let methodNotFound = -32601
        static let invalidParams = -32602
    }

    private let tool: FindNearestColorTool

    public init(tool: FindNearestColorTool) {
        self.tool = tool
    }

    /// Handles one JSON-RPC message; returns the response, or nil for
    /// notifications (which must not be answered).
    public func handle(line: Data) -> Data? {
        guard let message = try? JSONSerialization.jsonObject(with: line)
                as? [String: Any] else {
            return encode(error: ErrorCode.parse, "Parse error", id: NSNull())
        }
        guard let id = message["id"] else { return nil }
        let params = message["params"] as? [String: Any] ?? [:]

        switch message["method"] as? String {
        case "initialize":
            return encode(result: [
                "protocolVersion": params["protocolVersion"]
                    ?? Self.fallbackProtocolVersion,
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": [
                    "name": Self.serverName,
                    "version": Self.serverVersion
                ]
            ], id: id)
        case "ping":
            return encode(result: [String: Any](), id: id)
        case "tools/list":
            return encode(
                result: ["tools": [FindNearestColorTool.definition]],
                id: id
            )
        case "tools/call":
            return callTool(params: params, id: id)
        default:
            return encode(
                error: ErrorCode.methodNotFound, "Method not found", id: id
            )
        }
    }

    private func callTool(params: [String: Any], id: Any) -> Data? {
        guard params["name"] as? String == FindNearestColorTool.name else {
            return encode(
                error: ErrorCode.invalidParams, "Unknown tool", id: id
            )
        }
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        do {
            let text = try tool.run(arguments: arguments)
            return encode(result: Self.content(text, isError: false), id: id)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            return encode(result: Self.content(message, isError: true), id: id)
        }
    }

    private static func content(_ text: String, isError: Bool) -> [String: Any] {
        [
            "content": [["type": "text", "text": text]],
            "isError": isError
        ]
    }

    private func encode(result: Any, id: Any) -> Data? {
        serialize(["jsonrpc": "2.0", "id": id, "result": result])
    }

    private func encode(error code: Int, _ message: String, id: Any) -> Data? {
        serialize([
            "jsonrpc": "2.0",
            "id": id,
            "error": ["code": code, "message": message]
        ])
    }

    private func serialize(_ object: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: object)
    }
}
