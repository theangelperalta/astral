import XCTest
@testable import AstralCore

final class ExporterTests: XCTestCase {
    /// Builds the toy graph used in the plan's exporter examples.
    private func makeToyGraph() -> DependencyGraph {
        let loc = SourceLocation(file: "/tmp/Toy.swift", line: 1, column: 1)
        let drawable = TypeDeclaration(
            id: "Toy.Drawable#protocol", kind: .protocol,
            qualifiedName: QualifiedName(module: "Toy", parents: [], name: "Drawable"),
            location: loc
        )
        let circle = TypeDeclaration(
            id: "Toy.Circle#struct", kind: .struct,
            qualifiedName: QualifiedName(module: "Toy", parents: [], name: "Circle"),
            location: loc
        )
        let canvas = TypeDeclaration(
            id: "Toy.Canvas#class", kind: .class,
            qualifiedName: QualifiedName(module: "Toy", parents: [], name: "Canvas"),
            location: loc
        )
        let drawableRef = TypeReference(
            rawText: "Drawable",
            candidateQualifiedNames: [QualifiedName(module: nil, parents: [], name: "Drawable")],
            genericArguments: [], location: loc, role: .conforms
        )
        let circleRef = TypeReference(
            rawText: "Circle",
            candidateQualifiedNames: [QualifiedName(module: nil, parents: [], name: "Circle")],
            genericArguments: [], location: loc, role: .propertyType
        )
        let conforms = DependencyEdge(
            fromId: circle.id, to: drawableRef,
            resolvedToIds: [drawable.id], kind: .conforms, location: loc
        )
        let propertyType = DependencyEdge(
            fromId: canvas.id, to: circleRef,
            resolvedToIds: [circle.id], kind: .propertyType, location: loc
        )
        let metadata = DependencyGraph.Metadata(
            astralVersion: "0.1.0",
            generatedAt: Date(timeIntervalSince1970: 0),
            inputRoots: ["/src"],
            moduleNames: ["Toy"]
        )
        return DependencyGraph(
            nodes: [drawable.id: drawable, circle.id: circle, canvas.id: canvas],
            edges: [conforms, propertyType],
            unresolvedReferences: [],
            metadata: metadata
        )
    }

    // MARK: - JSON

    func testJSONExporterRoundTripsThroughSchema() throws {
        let graph = makeToyGraph()
        let data = try JSONExporter().render(graph)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let nodes = try XCTUnwrap(json?["nodes"] as? [[String: Any]])
        let edges = try XCTUnwrap(json?["edges"] as? [[String: Any]])
        XCTAssertEqual(nodes.count, 3)
        XCTAssertEqual(edges.count, 2)
        let ids = Set(nodes.compactMap { $0["id"] as? String })
        XCTAssertEqual(ids, ["Toy.Drawable#protocol", "Toy.Circle#struct", "Toy.Canvas#class"])
        let kinds = Set(edges.compactMap { $0["kind"] as? String })
        XCTAssertEqual(kinds, ["conforms", "propertyType"])
    }

    func testJSONExporterIsDeterministic() throws {
        let graph = makeToyGraph()
        let a = try JSONExporter().render(graph)
        let b = try JSONExporter().render(graph)
        XCTAssertEqual(a, b)
    }

    // MARK: - DOT

    func testDOTExporterContainsLegendAndNodes() throws {
        let graph = makeToyGraph()
        let data = try DOTExporter().render(graph)
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.hasPrefix("digraph Astral"))
        XCTAssertTrue(text.contains("\"Toy.Drawable#protocol\""))
        XCTAssertTrue(text.contains("style=solid, arrowhead=onormal"))
        XCTAssertTrue(text.contains("style=dashed, arrowhead=vee"))
        XCTAssertTrue(text.contains("cluster_legend"))
    }

    // MARK: - Mermaid

    func testMermaidExporterContainsRelationsAndStereotypes() throws {
        let graph = makeToyGraph()
        let data = try MermaidExporter().render(graph)
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.hasPrefix("classDiagram"))
        XCTAssertTrue(text.contains("<<protocol>>"))
        XCTAssertTrue(text.contains("<|.."), "conforms relation missing")
        XCTAssertTrue(text.contains("*--"), "propertyType relation missing")
    }

    // MARK: - Disk export

    func testExportWritesFile() throws {
        let graph = makeToyGraph()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("astral-test-\(UUID().uuidString)")
            .appendingPathComponent("graph.json")
        try JSONExporter().export(graph, to: tmp)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.path))
        let bytes = try Data(contentsOf: tmp)
        XCTAssertGreaterThan(bytes.count, 100)
        try? FileManager.default.removeItem(at: tmp.deletingLastPathComponent())
    }
}
