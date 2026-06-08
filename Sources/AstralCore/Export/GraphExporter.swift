import Foundation

/// Uniform exporter API for `DependencyGraph` serializations.
public protocol GraphExporter {
    func export(_ graph: DependencyGraph, to url: URL) throws
    func render(_ graph: DependencyGraph) throws -> Data
}

public extension GraphExporter {
    func export(_ graph: DependencyGraph, to url: URL) throws {
        let data = try render(graph)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}
