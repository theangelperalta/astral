import ArgumentParser
import AstralCore
import Foundation

@main
struct AstralCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "astral",
        abstract: "SwiftSyntax-based dependency graph extractor.",
        subcommands: [Graph.self, ListDecls.self, Version.self],
        defaultSubcommand: Graph.self
    )
}

struct Graph: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "graph",
        abstract: "Build and export a typed dependency graph."
    )

    @Option(name: .long, parsing: .upToNextOption,
            help: "One or more input directories (recursive).")
    var input: [String]

    @Option(name: .long, help: "Directory to write outputs.")
    var outputDir: String = "./astral-out"

    @Option(name: .long, parsing: .upToNextOption,
            help: "Output formats: json, dot, mermaid.")
    var format: [String] = ["json", "dot", "mermaid"]

    @Option(name: .long, parsing: .upToNextOption,
            help: "Override module roots (each path becomes one module).")
    var moduleRoots: [String] = []

    @Option(name: .long, parsing: .upToNextOption,
            help: "Glob patterns to exclude.")
    var exclude: [String] = []

    @Flag(name: .long, help: "Emit edges to known stdlib/Foundation types.")
    var includeStdlibRefs: Bool = false

    @Flag(name: .long, help: "Omit the generation timestamp for reproducible output.")
    var deterministic: Bool = false

    @Flag(name: .long) var quiet: Bool = false
    @Flag(name: .long) var verbose: Bool = false

    func run() async throws {
        guard !input.isEmpty else {
            throw ValidationError("At least one --input directory is required.")
        }
        let formats = try format.map { raw -> Pipeline.Format in
            guard let f = Pipeline.Format.parse(raw) else {
                throw ValidationError("Unknown --format value: \(raw)")
            }
            return f
        }
        let config = Pipeline.Configuration(
            inputRoots: input.map { URL(fileURLWithPath: $0) },
            moduleRoots: moduleRoots.map { URL(fileURLWithPath: $0) },
            excludeGlobs: exclude,
            includeStdlibRefs: includeStdlibRefs,
            deterministic: deterministic
        )
        let pipeline = Pipeline()
        let graph = try pipeline.run(config)
        let outputURL = URL(fileURLWithPath: outputDir)
        let written = try pipeline.export(graph, to: outputURL, formats: formats)
        if !quiet {
            FileHandle.standardError.write(Data(
                "astral: wrote \(graph.nodes.count) nodes, \(graph.edges.count) edges to:\n".utf8
            ))
            for url in written {
                FileHandle.standardError.write(Data("  \(url.path)\n".utf8))
            }
        }
    }
}

struct ListDecls: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-decls",
        abstract: "Print discovered declarations (id, kind, qualified name)."
    )

    @Option(name: .long, parsing: .upToNextOption) var input: [String]
    @Option(name: .long, parsing: .upToNextOption) var moduleRoots: [String] = []

    func run() async throws {
        guard !input.isEmpty else {
            throw ValidationError("At least one --input directory is required.")
        }
        let config = Pipeline.Configuration(
            inputRoots: input.map { URL(fileURLWithPath: $0) },
            moduleRoots: moduleRoots.map { URL(fileURLWithPath: $0) }
        )
        let graph = try Pipeline().run(config)
        for decl in graph.nodes.values.sorted(by: { $0.id < $1.id }) {
            print("\(decl.kind.rawValue)\t\(decl.qualifiedName.dotted)\t\(decl.location.file):\(decl.location.line)")
        }
    }
}

struct Version: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "version")
    func run() throws { print("astral \(AstralVersion.current)") }
}
