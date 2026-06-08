import XCTest
@testable import AstralCore

final class DeclarationCollectorTests: XCTestCase {
    private func collect(_ fixture: String, module: String) throws -> [TypeDeclaration] {
        let url = try TestSupport.fixture(fixture)
        let parsed = try SourceFileParser().parse(url, module: module)
        let collector = DeclarationCollector(parsedFile: parsed)
        return collector.collect(parsed.syntax)
    }

    func testSimpleProtocolFixture() throws {
        let decls = try collect("SimpleProtocol/Simple.swift", module: "SimpleProtocol")
        let byName = Dictionary(uniqueKeysWithValues: decls.map { ($0.qualifiedName.dotted, $0) })

        XCTAssertEqual(decls.count, 3)
        XCTAssertEqual(byName["SimpleProtocol.Drawable"]?.kind, .protocol)
        XCTAssertEqual(byName["SimpleProtocol.Circle"]?.kind, .struct)
        XCTAssertEqual(byName["SimpleProtocol.Canvas"]?.kind, .class)

        let circle = try XCTUnwrap(byName["SimpleProtocol.Circle"])
        XCTAssertEqual(circle.inheritanceClauseRawNames, ["Drawable"])
        XCTAssertEqual(circle.memberSummary.storedPropertyCount, 1)
        XCTAssertEqual(circle.memberSummary.methodCount, 1)

        let canvas = try XCTUnwrap(byName["SimpleProtocol.Canvas"])
        XCTAssertEqual(canvas.memberSummary.storedPropertyCount, 1)
        XCTAssertEqual(canvas.memberSummary.initializerCount, 1)
    }

    func testNestedTypesFixture() throws {
        let decls = try collect("NestedTypes/Nested.swift", module: "Nested")
        func find(_ dotted: String, _ kind: TypeKind) -> TypeDeclaration? {
            decls.first { $0.qualifiedName.dotted == dotted && $0.kind == kind }
        }

        let outer = try XCTUnwrap(find("Nested.Outer", .struct))
        let middle = try XCTUnwrap(find("Nested.Outer.Middle", .struct))
        let inner = try XCTUnwrap(find("Nested.Outer.Middle.Inner", .struct))
        let kind = try XCTUnwrap(find("Nested.Outer.Middle.Kind", .enum))
        let pair = try XCTUnwrap(find("Nested.Outer.Pair", .typealias))
        let worker = try XCTUnwrap(find("Nested.Worker", .actor))

        XCTAssertEqual(worker.kind, .actor)

        XCTAssertEqual(Set(middle.nestedTypeIds), Set([inner.id, kind.id]))
        XCTAssertEqual(Set(outer.nestedTypeIds), Set([middle.id, pair.id]))

        // Extension is a first-class node whose name is the extended type's text.
        let extDecl = decls.first { $0.kind == .extension }
        XCTAssertEqual(extDecl?.qualifiedName.name, "Outer.Middle")
    }

    func testMultipleExtensionsOfSameTypeProduceDistinctIds() throws {
        // ExtensionsAndAliases/Aliases.swift declares two `extension Person {}`
        // blocks. Each must surface as its own node with a unique id.
        let decls = try collect("ExtensionsAndAliases/Aliases.swift",
                                module: "ExtensionsAndAliases")
        let personExtensions = decls.filter {
            $0.kind == .extension && $0.qualifiedName.name == "Person"
        }
        XCTAssertEqual(personExtensions.count, 2,
                       "Expected two extension nodes for Person")
        XCTAssertEqual(Set(personExtensions.map(\.id)).count, 2,
                       "Extension nodes must have distinct ids")
        // Both ids must carry the file:line tag added for extensions.
        for ext in personExtensions {
            XCTAssertTrue(ext.id.contains("#extension@"),
                          "Extension id should include file:line tag, got \(ext.id)")
        }
    }
}
