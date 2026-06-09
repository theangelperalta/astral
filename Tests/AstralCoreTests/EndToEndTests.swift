import XCTest
@testable import AstralCore

final class EndToEndTests: XCTestCase {
    private func runPipeline(on fixturePath: String,
                             moduleRoots: [String] = []) throws -> DependencyGraph {
        let inputURL = try TestSupport.fixture(fixturePath)
        let moduleURLs = try moduleRoots.map { try TestSupport.fixture($0) }
        let config = Pipeline.Configuration(
            inputRoots: [inputURL],
            moduleRoots: moduleURLs
        )
        return try Pipeline().run(config)
    }

    func testMultiModulePipelineEndToEnd() throws {
        let graph = try runPipeline(
            on: "MultiModule",
            moduleRoots: ["MultiModule/ModuleA", "MultiModule/ModuleB"]
        )

        XCTAssertEqual(Set(graph.metadata.moduleNames), ["ModuleA", "ModuleB"])
        XCTAssertEqual(graph.nodes.count, 3)

        let drivableId = TypeDeclaration.makeId(
            qualifiedName: QualifiedName(module: "ModuleA", parents: [], name: "Drivable"),
            kind: .protocol
        )
        let engineId = TypeDeclaration.makeId(
            qualifiedName: QualifiedName(module: "ModuleA", parents: [], name: "Engine"),
            kind: .struct
        )
        let carId = TypeDeclaration.makeId(
            qualifiedName: QualifiedName(module: "ModuleB", parents: [], name: "Car"),
            kind: .class
        )

        XCTAssertNotNil(graph.nodes[drivableId])
        XCTAssertNotNil(graph.nodes[engineId])
        XCTAssertNotNil(graph.nodes[carId])

        let carEdges = graph.edges.filter { $0.fromId == carId }
        XCTAssertTrue(carEdges.contains {
            $0.to.rawText == "Drivable" && $0.resolvedToIds == [drivableId]
        })
        XCTAssertTrue(carEdges.contains {
            $0.to.rawText == "Engine" && $0.resolvedToIds == [engineId]
        })
    }

    func testConditionalCompilationTagsEdgesWithCondition() throws {
        let graph = try runPipeline(on: "ConditionalCompilation")
        let conditions = Set(graph.edges.compactMap { $0.condition })
        // We expect at least one `os(macOS)` (and the `#else` fallback / DEBUG branches)
        // to surface as condition strings on edges produced inside #if blocks.
        XCTAssertTrue(conditions.contains { $0.contains("os(macOS)") },
                      "Expected an os(macOS) condition; got \(conditions)")
        XCTAssertTrue(conditions.contains { $0.contains("DEBUG") || $0 == "#else" },
                      "Expected a DEBUG or #else condition; got \(conditions)")
    }

    func testPipelineToleratesDuplicateDeclarationIds() throws {
        // The DuplicateIds fixture intentionally declares:
        //   • multiple `extension Person { ... }` blocks (4 total)
        //   • two `typealias Parameters` inside extensions on the same type
        // The first case must surface as 4 distinct extension nodes; the second
        // must not trap Pipeline (first-wins dedup).
        let graph = try runPipeline(on: "DuplicateIds")

        let personExtensions = graph.nodes.values.filter {
            $0.kind == .extension && $0.qualifiedName.name == "Person"
        }
        XCTAssertEqual(personExtensions.count, 4,
                       "All four Person extensions should be preserved as distinct nodes")
        XCTAssertEqual(Set(personExtensions.map(\.id)).count, 4,
                       "Extension node ids must all differ")

        let parametersAliases = graph.nodes.values.filter {
            $0.kind == .typealias && $0.qualifiedName.name == "Parameters"
        }
        XCTAssertEqual(parametersAliases.count, 1,
                       "Colliding typealias ids should dedup to one node (first wins)")
    }

    func testDeterministicModeOmitsTimestampAndIsByteStable() throws {
        let inputURL = try TestSupport.fixture("MultiModule")
        let moduleURLs = try ["MultiModule/ModuleA", "MultiModule/ModuleB"]
            .map { try TestSupport.fixture($0) }
        let config = Pipeline.Configuration(
            inputRoots: [inputURL],
            moduleRoots: moduleURLs,
            deterministic: true
        )

        let first = try Pipeline().run(config)
        XCTAssertNil(first.metadata.generatedAt,
                     "Deterministic mode must omit the generation timestamp")

        // Two independent runs over identical inputs must render byte-identical JSON.
        let exporter = JSONExporter()
        let firstData = try exporter.render(first)
        let secondData = try exporter.render(try Pipeline().run(config))
        XCTAssertEqual(firstData, secondData)
        XCTAssertFalse(String(decoding: firstData, as: UTF8.self).contains("generatedAt"),
                       "generatedAt key should not appear when nil")
    }

    func testNonDeterministicModeRecordsTimestamp() throws {
        let graph = try runPipeline(on: "SimpleProtocol")
        XCTAssertNotNil(graph.metadata.generatedAt,
                        "Default mode should record a generation timestamp")
    }

    func testEndToEndExportsAllFormatsToDisk() throws {
        let graph = try runPipeline(
            on: "MultiModule",
            moduleRoots: ["MultiModule/ModuleA", "MultiModule/ModuleB"]
        )
        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("astral-e2e-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outDir) }

        let written = try Pipeline().export(graph,
                                            to: outDir,
                                            formats: Pipeline.Format.allCases)
        XCTAssertEqual(written.count, Pipeline.Format.allCases.count)
        for url in written {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }
}
