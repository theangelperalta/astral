import XCTest
@testable import AstralCore

final class ResolverTests: XCTestCase {
    /// Loads ModuleA + ModuleB fixtures and returns parsed files plus the
    /// declarations and edges harvested by the parsing pipeline.
    private struct LoadedGraph {
        let parsed: [ParsedFile]
        let declarations: [TypeDeclaration]
        let edges: [DependencyEdge]
        let fileImports: [String: Set<String>]
    }

    private func loadMultiModule() throws -> LoadedGraph {
        let parser = SourceFileParser()
        let aURL = try TestSupport.fixture("MultiModule/ModuleA/ModuleA.swift")
        let bURL = try TestSupport.fixture("MultiModule/ModuleB/ModuleB.swift")
        let parsedA = try parser.parse(aURL, module: "ModuleA")
        let parsedB = try parser.parse(bURL, module: "ModuleB")

        var decls: [TypeDeclaration] = []
        var edges: [DependencyEdge] = []
        var fileImports: [String: Set<String>] = [:]
        for parsed in [parsedA, parsedB] {
            decls.append(contentsOf: DeclarationCollector(parsedFile: parsed).collect(parsed.syntax))
            edges.append(contentsOf: TypeUsageCollector(parsedFile: parsed).collect(parsed.syntax))
            fileImports[parsed.url.path] = Set(parsed.imports)
        }
        return LoadedGraph(parsed: [parsedA, parsedB],
                           declarations: decls,
                           edges: edges,
                           fileImports: fileImports)
    }

    // MARK: - Symbol table

    func testSymbolTableLookups() throws {
        let loaded = try loadMultiModule()
        let table = SymbolTable(declarations: loaded.declarations)

        XCTAssertEqual(table.modules, ["ModuleA", "ModuleB"])
        XCTAssertEqual(table.candidates(simple: "Engine", inModule: "ModuleA").count, 1)
        XCTAssertEqual(table.candidates(simple: "Engine", inModule: "ModuleB").count, 1,
                       "Cross-module fallback should still surface ModuleA.Engine")
        let drivable = QualifiedName(module: "ModuleA", parents: [], name: "Drivable")
        XCTAssertEqual(table.candidates(qualified: drivable).count, 1)
    }

    // MARK: - Cross-module resolution

    func testResolverResolvesCrossModuleViaImports() throws {
        let loaded = try loadMultiModule()
        let table = SymbolTable(declarations: loaded.declarations)
        let resolver = Resolver(table: table, fileImports: loaded.fileImports)
        let output = resolver.resolve(edges: loaded.edges, declarations: loaded.declarations)

        let carId = TypeDeclaration.makeId(
            qualifiedName: QualifiedName(module: "ModuleB", parents: [], name: "Car"),
            kind: .class
        )
        let drivableId = TypeDeclaration.makeId(
            qualifiedName: QualifiedName(module: "ModuleA", parents: [], name: "Drivable"),
            kind: .protocol
        )
        let engineId = TypeDeclaration.makeId(
            qualifiedName: QualifiedName(module: "ModuleA", parents: [], name: "Engine"),
            kind: .struct
        )

        let carEdges = output.resolvedEdges.filter { $0.fromId == carId }
        // Lexically the first inheritance of a class is emitted as .inherits even
        // when the target is a protocol; resolution then disambiguates the id.
        let drivableEdge = carEdges.first {
            ($0.kind == .inherits || $0.kind == .conforms) && $0.to.rawText == "Drivable"
        }
        XCTAssertEqual(drivableEdge?.resolvedToIds, [drivableId])

        let engineRefs = carEdges.filter { $0.to.rawText == "Engine" }
        XCTAssertFalse(engineRefs.isEmpty)
        for edge in engineRefs {
            XCTAssertEqual(edge.resolvedToIds, [engineId])
        }
    }

    // MARK: - Unresolved + stdlib filtering

    func testUnresolvedFiltersStdlibByDefault() throws {
        let loaded = try loadMultiModule()
        let table = SymbolTable(declarations: loaded.declarations)
        let resolver = Resolver(table: table, fileImports: loaded.fileImports)
        let output = resolver.resolve(edges: loaded.edges, declarations: loaded.declarations)

        // `horsepower: Int` should resolve to nothing (no Int decl in fixtures)
        // but be filtered out as a known stdlib name.
        XCTAssertFalse(output.unresolvedReferences.contains { $0.rawText == "Int" })
    }

    func testUnresolvedKeepsStdlibWhenFlagOn() throws {
        let loaded = try loadMultiModule()
        let table = SymbolTable(declarations: loaded.declarations)
        let resolver = Resolver(table: table,
                                fileImports: loaded.fileImports,
                                includeStdlibRefs: true)
        let output = resolver.resolve(edges: loaded.edges, declarations: loaded.declarations)
        XCTAssertTrue(output.unresolvedReferences.contains { $0.rawText == "Int" })
    }

    // MARK: - Same-file / nested resolution

    func testSameFileNestedResolution() throws {
        // Build an in-memory parse of NestedTypes — Outer.Middle.Inner referenced
        // from Outer should resolve to the nested decl.
        let parser = SourceFileParser()
        let url = try TestSupport.fixture("NestedTypes/Nested.swift")
        let parsed = try parser.parse(url, module: "Nested")
        let decls = DeclarationCollector(parsedFile: parsed).collect(parsed.syntax)
        let edges = TypeUsageCollector(parsedFile: parsed).collect(parsed.syntax)
        let table = SymbolTable(declarations: decls)
        let resolver = Resolver(table: table)
        let output = resolver.resolve(edges: edges, declarations: decls)

        // The extension `Outer.Middle` resolves through the dotted candidate path.
        // Extension ids are file:line-tagged, so look the declaration up by
        // qualified name rather than rebuilding the id.
        let extDecl = try XCTUnwrap(decls.first {
            $0.kind == .extension && $0.qualifiedName.name == "Outer.Middle"
        })
        let middleId = TypeDeclaration.makeId(
            qualifiedName: QualifiedName(module: "Nested", parents: ["Outer"], name: "Middle"),
            kind: .struct
        )
        let extendsEdge = output.resolvedEdges.first {
            $0.fromId == extDecl.id && $0.kind == .extends
        }
        XCTAssertEqual(extendsEdge?.resolvedToIds, [middleId])
    }

    // MARK: - KnownExternalTypes coverage

    func testKnownExternalTypesCoversCommonFrameworks() {
        // Spot-check that the symbols leaking through the unresolved list on
        // real-world iOS codebases are now part of the allowlist.
        for symbol in [
            "Decoder", "Encoder", "CodingKey", "StaticString",
            "NSObject", "NSError",
            "CGSize", "CGRect", "CGFloat", "CGPoint",
            "AVPlayer", "AVQueuePlayer", "AVURLAsset", "AVPlayerViewController",
            "MPRemoteCommandHandlerStatus", "MPNowPlayingInfoCenter",
            "PreviewProvider", "ObservableObject", "AnyPublisher",
            "UIView", "UIViewController", "UIColor"
        ] {
            XCTAssertTrue(KnownExternalTypes.isKnown(symbol),
                          "\(symbol) should be in KnownExternalTypes")
        }
    }
}
