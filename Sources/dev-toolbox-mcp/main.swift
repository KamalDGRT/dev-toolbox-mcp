import DevToolBoxMCP
import Foundation

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("dev-toolbox-mcp: \(message)\n".utf8))
    exit(1)
}

let config: ServerConfig
do {
    config = try ServerConfig.load()
} catch {
    fail((error as? LocalizedError)?.errorDescription ?? "\(error)")
}

let server = MCPServer(tool: FindNearestColorTool(config: config))
while let line = readLine(strippingNewline: true) {
    guard !line.isEmpty,
          let response = server.handle(line: Data(line.utf8)) else { continue }
    FileHandle.standardOutput.write(response + Data("\n".utf8))
}
