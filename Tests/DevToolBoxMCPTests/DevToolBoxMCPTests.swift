import Foundation
import Testing
@testable import DevToolBoxMCP

/// Builds `<root>/.devtoolboxmcp/config.json` plus a one-color catalog.
private struct Fixture {
    let root: URL

    init(maxResults: Int? = nil) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let colorset = root.appendingPathComponent(
            "Assets/T.xcassets/darkBlue.colorset"
        )
        try FileManager.default.createDirectory(
            at: colorset, withIntermediateDirectories: true
        )
        let contents: [String: Any] = ["colors": [["color": ["components": [
            "red": "0x00", "green": "0x61", "blue": "0xA5", "alpha": "1.000"
        ]]]]]
        try JSONSerialization.data(withJSONObject: contents)
            .write(to: colorset.appendingPathComponent("Contents.json"))

        var config: [String: Any] = ["xcassetsPaths": ["Assets/T.xcassets"]]
        if let maxResults { config["maxResults"] = maxResults }
        let configDir = root.appendingPathComponent(
            ServerConfig.configDirectoryName
        )
        try FileManager.default.createDirectory(
            at: configDir, withIntermediateDirectories: true
        )
        try JSONSerialization.data(withJSONObject: config).write(
            to: configDir.appendingPathComponent(ServerConfig.configFileName)
        )
    }
}

struct ServerConfigTests {
    @Test func resolvesRelativePathsAgainstProjectRoot() throws {
        let fixture = try Fixture(maxResults: 3)
        let nested = fixture.root.appendingPathComponent("Assets")
        let config = try ServerConfig.load(
            environment: [:], currentDirectory: nested
        )

        #expect(config.maxResults == 3)
        #expect(config.catalogURLs.first?.path.hasSuffix("Assets/T.xcassets") == true)
    }

    @Test func defaultsMaxResultsWhenOmitted() throws {
        let fixture = try Fixture()
        let config = try ServerConfig.load(
            environment: [:], currentDirectory: fixture.root
        )
        #expect(config.maxResults == ServerConfig.defaultMaxResults)
    }

    @Test func throwsNotFoundWhenNoConfigAnywhere() {
        let empty = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        #expect(throws: ServerConfigError.self) {
            try ServerConfig.load(environment: [:], currentDirectory: empty)
        }
    }
}

struct MCPServerTests {
    private func makeServer() throws -> MCPServer {
        let fixture = try Fixture()
        let config = try ServerConfig.load(
            environment: [:], currentDirectory: fixture.root
        )
        return MCPServer(tools: [FindNearestColorTool(config: config)])
    }

    private func send(_ server: MCPServer, _ json: String) throws -> [String: Any]? {
        guard let data = server.handle(line: Data(json.utf8)) else { return nil }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func toolText(_ reply: [String: Any]?) throws -> String {
        let result = try #require(reply?["result"] as? [String: Any])
        let content = try #require(result["content"] as? [[String: Any]])
        return try #require(content.first?["text"] as? String)
    }

    @Test func initializeEchoesProtocolVersionAndAdvertisesTools() throws {
        let reply = try send(makeServer(), """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}
        """)
        let result = try #require(reply?["result"] as? [String: Any])
        #expect(result["protocolVersion"] as? String == "2024-11-05")
        #expect((result["capabilities"] as? [String: Any])?["tools"] != nil)
    }

    @Test func missingConfigDoesNotStopServerAndIsReportedPerCall() throws {
        let empty = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let server = MCPServer(tools: [FindNearestColorTool(loadConfig: {
            try ServerConfig.load(environment: [:], currentDirectory: empty)
        })])
        let initialize = try send(server, """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
        """)
        #expect(initialize?["result"] != nil, "server must start without config")
        let call = try send(server, """
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"find_nearest_color","arguments":{"hex":"#FFFFFF"}}}
        """)
        let result = try #require(call?["result"] as? [String: Any])
        #expect(result["isError"] as? Bool == true)
        #expect(try toolText(call).contains(".devtoolboxmcp/config.json"))
    }

    @Test func deltaEIsRoundedToTwoDecimalsInJSON() throws {
        let reply = try send(makeServer(), """
        {"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"find_nearest_color","arguments":{"hex":"#0261A5"}}}
        """)
        let text = try toolText(reply)
        let pattern = #""deltaE" *: *(\d+(\.\d{1,2})?)[,\s}]"#
        #expect(text.range(of: pattern, options: .regularExpression) != nil, "got \(text)")
    }

    @Test func notificationsGetNoReply() throws {
        let reply = try send(makeServer(), """
        {"jsonrpc":"2.0","method":"notifications/initialized"}
        """)
        #expect(reply == nil)
    }

    @Test func listsEveryTool() throws {
        let fixture = try Fixture()
        let server = MCPServer.standard(loadConfig: {
            try ServerConfig.load(environment: [:], currentDirectory: fixture.root)
        })
        let reply = try send(server, """
        {"jsonrpc":"2.0","id":2,"method":"tools/list"}
        """)
        let tools = (reply?["result"] as? [String: Any])?["tools"] as? [[String: Any]]
        let names = tools?.compactMap { $0["name"] as? String }.sorted()
        #expect(names == [
            "compare_colors", "find_duplicate_colors", "find_nearest_color",
            "rgba_to_rgb", "search_assets"
        ], "got \(String(describing: names))")
    }

    @Test func listsTheNearestColorTool() throws {
        let reply = try send(makeServer(), """
        {"jsonrpc":"2.0","id":2,"method":"tools/list"}
        """)
        let result = reply?["result"] as? [String: Any]
        let tools = result?["tools"] as? [[String: Any]]
        #expect(tools?.first?["name"] as? String == FindNearestColorTool.name)
    }

    @Test func callByHexReturnsExactMatch() throws {
        let reply = try send(makeServer(), """
        {"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"find_nearest_color","arguments":{"hex":"#0061A5"}}}
        """)
        let text = try toolText(reply)
        #expect(text.contains("\"name\" : \"darkBlue\""), "got: \(text)")
        #expect(text.contains("\"exact\" : true"), "got: \(text)")
    }

    @Test func callByRGBResolvesToSameQueryAsHex() throws {
        let reply = try send(makeServer(), """
        {"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"find_nearest_color","arguments":{"r":0,"g":97,"b":165}}}
        """)
        let text = try toolText(reply)
        #expect(text.contains("\"query\" : \"#0061A5\""), "got: \(text)")
    }

    @Test func badHexIsReportedAsToolErrorNotProtocolError() throws {
        let reply = try send(makeServer(), """
        {"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"find_nearest_color","arguments":{"hex":"nope"}}}
        """)
        #expect(reply?["error"] == nil)
        let result = try #require(reply?["result"] as? [String: Any])
        #expect(result["isError"] as? Bool == true)
    }

    @Test func unknownMethodReturnsMethodNotFound() throws {
        let reply = try send(makeServer(), """
        {"jsonrpc":"2.0","id":6,"method":"nope"}
        """)
        #expect((reply?["error"] as? [String: Any])?["code"] as? Int == -32601)
    }

    @Test func garbageInputReturnsParseError() throws {
        let reply = try send(makeServer(), "not json")
        #expect((reply?["error"] as? [String: Any])?["code"] as? Int == -32700)
    }
}


struct NewToolTests {
    private func call(_ tool: some MCPTool, _ arguments: [String: Any]) throws -> String {
        try tool.run(arguments: arguments)
    }

    @Test func compareColorsReportsDeltaEForHexAndRGBMix() throws {
        let text = try call(CompareColorsTool(), [
            "a": "#000000", "b": ["r": 255, "g": 255, "b": 255]
        ])
        #expect(text.contains("\"deltaE\" : 100"), "got: \(text)")
        #expect(text.contains("\"identical\" : false"), "got: \(text)")
        let same = try call(CompareColorsTool(), ["a": "#0061A5", "b": "0061a5"])
        #expect(same.contains("\"identical\" : true"), "got: \(same)")
    }

    @Test func compareColorsRejectsBadInput() {
        #expect(throws: ToolError.invalidColor(argument: "b")) {
            try CompareColorsTool().run(arguments: ["a": "#000", "b": "nope"])
        }
        #expect(throws: ToolError.invalidColor(argument: "a")) {
            try CompareColorsTool().run(arguments: ["b": "#000"])
        }
        #expect(throws: ToolError.invalidColor(argument: "a")) {
            try CompareColorsTool().run(arguments: ["a": ["r": 256, "g": 0, "b": 0], "b": "#000"])
        }
    }

    @Test func rgbaToRGBDefaultsToWhiteBackground() throws {
        let text = try call(RGBAToRGBTool(), ["color": "#00000080"])
        #expect(text.contains("\"hex\" : \"#7F7F7F\"") || text.contains("\"hex\" : \"#808080\""), "got: \(text)")
        #expect(text.contains("\"background\" : \"#FFFFFF\""), "got: \(text)")
    }

    @Test func rgbaToRGBHonoursObjectInputAndBlackBackground() throws {
        let text = try call(RGBAToRGBTool(), [
            "color": ["r": 255, "g": 255, "b": 255, "a": 0.5],
            "background": "black"
        ])
        #expect(text.contains("\"hex\" : \"#808080\""), "got: \(text)")
        #expect(text.contains("\"rgb\" : \"RGB(128, 128, 128)\""), "got: \(text)")
    }

    @Test func rgbaToRGBRejectsBadBackground() {
        #expect(throws: ToolError.invalidBackground("purple")) {
            try RGBAToRGBTool().run(arguments: ["color": "#000", "background": "purple"])
        }
    }

    @Test func searchAssetsFindsByHexAndNameAndRejectsEmptyQuery() throws {
        let fixture = try Fixture()
        let config = try ServerConfig.load(environment: [:], currentDirectory: fixture.root)
        let tool = SearchAssetsTool(loadConfig: { config })
        let byHex = try tool.run(arguments: ["query": "0061a5"])
        #expect(byHex.contains("\"name\" : \"darkBlue\""), "got: \(byHex)")
        let byRGB = try tool.run(arguments: ["query": "0, 97, 165"])
        #expect(byRGB.contains("\"total\" : 1"), "got: \(byRGB)")
        let none = try tool.run(arguments: ["query": "zzz"])
        #expect(none.contains("\"total\" : 0"), "got: \(none)")
        #expect(throws: ToolError.missingQuery) { try tool.run(arguments: ["query": " "]) }
    }

    @Test func findDuplicatesReportsNoneForSingleColorCatalog() throws {
        let fixture = try Fixture()
        let config = try ServerConfig.load(environment: [:], currentDirectory: fixture.root)
        let text = try FindDuplicateColorsTool(loadConfig: { config }).run(arguments: [:])
        #expect(text.contains("\"groupCount\" : 0"), "got: \(text)")
    }
}
