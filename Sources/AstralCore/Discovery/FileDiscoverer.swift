import Foundation

public struct FileDiscoverer {
    public struct Options {
        public var excludeGlobs: [String]
        public var followSymlinks: Bool

        public static let defaultExcludes: [String] = [
            ".build/**",
            "Pods/**",
            "DerivedData/**",
            "**/*.generated.swift",
            ".git/**"
        ]

        public init(excludeGlobs: [String] = [], followSymlinks: Bool = false) {
            self.excludeGlobs = excludeGlobs
            self.followSymlinks = followSymlinks
        }
    }

    private let options: Options

    public init(options: Options = .init()) {
        self.options = options
    }

    public func discover(roots: [URL]) throws -> [URL] {
        var results: [URL] = []
        let fm = FileManager.default
        let allExcludes = Options.defaultExcludes + options.excludeGlobs

        for root in roots {
            let standardizedRoot = root.standardizedFileURL
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: standardizedRoot.path, isDirectory: &isDir) else { continue }

            if !isDir.boolValue {
                if standardizedRoot.pathExtension == "swift" {
                    let rel = relative(of: standardizedRoot, against: standardizedRoot.deletingLastPathComponent())
                    if !GlobMatcher.matchesAny(path: rel, patterns: allExcludes) {
                        results.append(standardizedRoot)
                    }
                }
                continue
            }

            var enumOptions: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
            if !options.followSymlinks { enumOptions.insert(.skipsPackageDescendants) }

            guard let enumerator = fm.enumerator(
                at: standardizedRoot,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: enumOptions
            ) else { continue }

            for case let url as URL in enumerator {
                let absolute = url.standardizedFileURL
                let rel = relative(of: absolute, against: standardizedRoot)

                if GlobMatcher.matchesAny(path: rel, patterns: allExcludes) {
                    if (try? absolute.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                let values = try absolute.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                if values.isSymbolicLink == true && !options.followSymlinks { continue }
                guard values.isRegularFile == true else { continue }
                guard absolute.pathExtension == "swift" else { continue }
                results.append(absolute)
            }
        }

        // Deterministic, sorted, deduplicated.
        let unique = Array(Set(results))
        return unique.sorted { $0.path < $1.path }
    }

    private func relative(of url: URL, against base: URL) -> String {
        let urlPath = url.path
        let basePath = base.path
        if urlPath.hasPrefix(basePath + "/") {
            return String(urlPath.dropFirst(basePath.count + 1))
        }
        if urlPath == basePath { return url.lastPathComponent }
        return urlPath
    }
}
