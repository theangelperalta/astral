import XCTest
@testable import AstralCore

final class ModelsRoundTripTests: XCTestCase {
    func testGraphRoundTrip() throws {
        let qn = QualifiedName(module: "M", parents: ["Outer"], name: "Inner")
        let loc = SourceLocation(file: "/tmp/a.swift", line: 1, column: 1)
        let decl = TypeDeclaration(
            id: TypeDeclaration.makeId(qualifiedName: qn, kind: .struct),
            kind: .struct,
            qualifiedName: qn,
            location: loc,
            genericParameters: ["T"],
            genericConstraints: ["T: Hashable"],
            inheritanceClauseRawNames: ["Drawable"],
            nestedTypeIds: [],
            memberSummary: .init(storedPropertyCount: 1)
        )
        let ref = TypeReference(
            rawText: "Drawable",
            candidateQualifiedNames: [QualifiedName(module: nil, parents: [], name: "Drawable")],
            genericArguments: [],
            location: loc,
            role: .conforms
        )
        let edge = DependencyEdge(fromId: decl.id, to: ref, resolvedToIds: [], kind: .conforms, location: loc)
        let graph = DependencyGraph(
            nodes: [decl.id: decl],
            edges: [edge],
            unresolvedReferences: [ref],
            metadata: .init(astralVersion: AstralVersion.current,
                            generatedAt: Date(timeIntervalSince1970: 0),
                            inputRoots: ["/tmp"],
                            moduleNames: ["M"])
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(graph)
        let decoded = try JSONDecoder().decode(DependencyGraph.self, from: data)

        XCTAssertEqual(decoded.nodes.count, 1)
        XCTAssertEqual(decoded.edges.count, 1)
        XCTAssertEqual(decoded.unresolvedReferences.count, 1)
        XCTAssertEqual(decoded.nodes[decl.id]?.qualifiedName.dotted, "M.Outer.Inner")
        XCTAssertEqual(decoded.edges.first?.kind, .conforms)
    }

    func testQualifiedNameDotted() {
        let a = QualifiedName(module: "M", parents: ["Outer"], name: "Inner")
        XCTAssertEqual(a.dotted, "M.Outer.Inner")
        let b = QualifiedName(module: nil, parents: [], name: "Foo")
        XCTAssertEqual(b.dotted, "Foo")
    }
}
