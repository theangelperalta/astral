import Foundation

public enum AstralVersion {
    public static let current = "0.1.0"
}

/// Composes file discovery, parsing, declaration & usage collection,
/// resolution, and (optionally) export. Designed to be testable without
/// requiring any CLI-layer types.
public struct Pipeline {
    public struct Configuration {
        public var inputRoots: [URL]
        public var moduleRoots: [URL]
        public var excludeGlobs: [String]
        public var includeStdlibRefs: Bool
        /// When true, omit the generation timestamp so repeated runs over
        /// identical inputs produce byte-identical output.
        public var deterministic: Bool

        public init(inputRoots: [URL],
                    moduleRoots: [URL] = [],
                    excludeGlobs: [String] = [],
                    includeStdlibRefs: Bool = false,
                    deterministic: Bool = false) {
            self.inputRoots = inputRoots
            self.moduleRoots = moduleRoots
            self.excludeGlobs = excludeGlobs
            self.includeStdlibRefs = includeStdlibRefs
            self.deterministic = deterministic
        }
    }

    public init() {}

    public func run(_ config: Configuration) throws -> DependencyGraph {
        let discoverer = FileDiscoverer(options: .init(excludeGlobs: config.excludeGlobs))
        let files = try discoverer.discover(roots: config.inputRoots)
        let layout = ModuleLayout(inputRoots: config.inputRoots,
                                  explicitModuleRoots: config.moduleRoots)
        let parser = SourceFileParser()

        // Parsing is the expensive stage and each file is independent, so parse
        // in parallel. `parallelMap` preserves source order in the result.
        let parsedFiles = try parallelMap(files) { file in
            try parser.parse(file, module: layout.moduleName(for: file))
        }

        var declarations: [TypeDeclaration] = []
        var edges: [DependencyEdge] = []
        var fileImports: [String: Set<String>] = [:]
        var moduleNames: Set<String> = []
        for parsed in parsedFiles {
            declarations.append(contentsOf: DeclarationCollector(parsedFile: parsed).collect(parsed.syntax))
            edges.append(contentsOf: TypeUsageCollector(parsedFile: parsed).collect(parsed.syntax))
            fileImports[parsed.url.path] = Set(parsed.imports)
            moduleNames.insert(parsed.moduleName)
        }

        let table = SymbolTable(declarations: declarations)
        let resolver = Resolver(table: table,
                                fileImports: fileImports,
                                includeStdlibRefs: config.includeStdlibRefs)
        let resolved = resolver.resolve(edges: edges, declarations: declarations)

        // Tolerate duplicate ids defensively (e.g. two declarations colliding on
        // the same synthesized id); first occurrence wins, matching source order.
        let nodeIndex = Dictionary(declarations.map { ($0.id, $0) },
                                   uniquingKeysWith: { first, _ in first })
        let metadata = DependencyGraph.Metadata(
            astralVersion: AstralVersion.current,
            generatedAt: config.deterministic ? nil : Date(),
            inputRoots: config.inputRoots.map { $0.path },
            moduleNames: moduleNames.sorted()
        )
        return DependencyGraph(
            nodes: nodeIndex,
            edges: resolved.resolvedEdges,
            unresolvedReferences: resolved.unresolvedReferences,
            metadata: metadata
        )
    }

    /// Writes the graph in every requested format under `outputDir`,
    /// returning the URLs of the files written.
    @discardableResult
    public func export(_ graph: DependencyGraph,
                       to outputDir: URL,
                       formats: [Format]) throws -> [URL] {
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        var written: [URL] = []
        for format in formats {
            let url = outputDir.appendingPathComponent("graph.\(format.fileExtension)")
            try format.exporter.export(graph, to: url)
            written.append(url)
        }
        return written
    }

    public enum Format: String, CaseIterable {
        case json, dot, mermaid

        public var fileExtension: String {
            switch self {
            case .json: return "json"
            case .dot: return "dot"
            case .mermaid: return "mmd"
            }
        }

        public var exporter: GraphExporter {
            switch self {
            case .json: return JSONExporter()
            case .dot: return DOTExporter()
            case .mermaid: return MermaidExporter()
            }
        }

        public static func parse(_ raw: String) -> Format? {
            Format(rawValue: raw.lowercased())
        }
    }
}
