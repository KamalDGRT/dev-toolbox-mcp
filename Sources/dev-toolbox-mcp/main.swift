import DevToolBoxMCP
import Foundation

let server = MCPServer.standard(loadConfig: { try ServerConfig.load() })
while let line = readLine(strippingNewline: true) {
    guard !line.isEmpty,
          let response = server.handle(line: Data(line.utf8)) else { continue }
    FileHandle.standardOutput.write(response + Data("\n".utf8))
}
