import Foundation

public struct ModuleLayout {
    private let inputRoots: [URL]
    private let explicitModuleRoots: [URL]
    public let allModules: [String]

    public init(inputRoots: [URL], explicitModuleRoots: [URL] = []) {
        self.inputRoots = inputRoots.map { $0.standardizedFileURL }
        self.explicitModuleRoots = explicitModuleRoots.map { $0.standardizedFileURL }
        var modules = Set<String>()
        // Explicit roots are themselves modules.
        for root in self.explicitModuleRoots {
            modules.insert(root.lastPathComponent)
        }
        // Synthetic _Root is reserved for files directly under an input root.
        modules.insert("_Root")
        self.allModules = modules.sorted()
    }

    public func moduleName(for file: URL) -> String {
        let absolute = file.standardizedFileURL.path

        // 1. Explicit module roots take precedence (longest path wins).
        let sortedExplicit = explicitModuleRoots.sorted { $0.path.count > $1.path.count }
        for root in sortedExplicit {
            if absolute == root.path || absolute.hasPrefix(root.path + "/") {
                return root.lastPathComponent
            }
        }

        // 2. Implicit: first directory under any input root.
        for root in inputRoots {
            let rootPath = root.path
            guard absolute.hasPrefix(rootPath + "/") else { continue }
            let tail = String(absolute.dropFirst(rootPath.count + 1))
            let components = tail.split(separator: "/", omittingEmptySubsequences: true)
            if components.count >= 2 {
                return String(components[0])
            } else {
                // File sits directly under the input root.
                return "_Root"
            }
        }

        return "_Root"
    }
}
