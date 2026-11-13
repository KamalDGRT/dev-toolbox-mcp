import Foundation

public enum ServerConfigError: Error, Equatable, LocalizedError {
    case notFound(searchedFrom: String)
    case unreadable(path: String, reason: String)
    case noCatalogs(path: String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let start):
            return "No \(ServerConfig.relativeConfigPath) found from \(start) upward. "
                + "Create one or set \(ServerConfig.configEnvironmentKey)."
        case .unreadable(let path, let reason):
            return "Cannot read config at \(path): \(reason)"
        case .noCatalogs(let path):
            return "Config at \(path) has an empty xcassetsPaths list."
        }
    }
}

/// Per-project settings, stored at `<project>/.devtoolboxmcp/config.json`:
/// `{ "xcassetsPaths": ["acv/Assets/ADSColors.xcassets"], "maxResults": 5 }`
/// `xcassetsPaths` resolve relative to the project root (the folder that
/// holds `.devtoolboxmcp`); absolute paths are used as-is.
public struct ServerConfig: Equatable, Sendable {
    public static let configDirectoryName = ".devtoolboxmcp"
    public static let configFileName = "config.json"
    public static let relativeConfigPath = "\(configDirectoryName)/\(configFileName)"
    public static let configEnvironmentKey = "DEV_TOOLBOX_MCP_CONFIG"
    public static let defaultMaxResults = 5

    public let catalogURLs: [URL]
    public let maxResults: Int

    private struct Payload: Decodable {
        let xcassetsPaths: [String]
        let maxResults: Int?
    }

    public static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectory: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    ) throws -> ServerConfig {
        if let override = environment[configEnvironmentKey] {
            return try load(fileURL: URL(fileURLWithPath: override))
        }
        var directory = currentDirectory.standardizedFileURL
        while true {
            let candidate = directory.appendingPathComponent(relativeConfigPath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try load(fileURL: candidate)
            }
            let parent = directory.deletingLastPathComponent()
            guard parent.path != directory.path else {
                throw ServerConfigError.notFound(searchedFrom: currentDirectory.path)
            }
            directory = parent
        }
    }

    public static func load(fileURL: URL) throws -> ServerConfig {
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(
                Payload.self,
                from: Data(contentsOf: fileURL)
            )
        } catch {
            throw ServerConfigError.unreadable(
                path: fileURL.path,
                reason: error.localizedDescription
            )
        }
        guard !payload.xcassetsPaths.isEmpty else {
            throw ServerConfigError.noCatalogs(path: fileURL.path)
        }
        let projectRoot = fileURL.deletingLastPathComponent()
            .deletingLastPathComponent()
        let urls = payload.xcassetsPaths.map { path in
            path.hasPrefix("/")
                ? URL(fileURLWithPath: path)
                : projectRoot.appendingPathComponent(path)
        }
        return ServerConfig(
            catalogURLs: urls,
            maxResults: payload.maxResults ?? defaultMaxResults
        )
    }
}
