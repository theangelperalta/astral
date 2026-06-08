import XCTest
@testable import AstralCore

final class TypeUsageCollectorTests: XCTestCase {
    private func collectEdges(_ fixture: String, module: String) throws -> [DependencyEdge] {
        let url = try TestSupport.fixture(fixture)
        let parsed = try SourceFileParser().parse(url, module: module)
        let collector = TypeUsageCollector(parsedFile: parsed)
        return collector.collect(parsed.syntax)
    }

    private func makeOwnerId(module: String, parents: [String] = [], name: String, kind: TypeKind) -> String {
        let qn = QualifiedName(module: module, parents: parents, name: name)
        return TypeDeclaration.makeId(qualifiedName: qn, kind: kind)
    }

    // MARK: - GenericsAndConstraints

    func testGenericsFixtureProducesExpectedEdges() throws {
        let module = "Gen"
        let edges = try collectEdges("GenericsAndConstraints/Generics.swift", module: module)

        let containerId = makeOwnerId(module: module, name: "Container", kind: .protocol)
        let boxId = makeOwnerId(module: module, name: "Box", kind: .class)
        let pairId = makeOwnerId(module: module, name: "Pair", kind: .struct)

        let containerEdges = edges.filter { $0.fromId == containerId }
        let boxEdges = edges.filter { $0.fromId == boxId }
        let pairEdges = edges.filter { $0.fromId == pairId }

        XCTAssertFalse(containerEdges.isEmpty)
        XCTAssertFalse(boxEdges.isEmpty)
        // `Pair<A, B>` still emits property-type edges to the generic-param names
        // (the flattener is intentionally name-blind to type-parameter scope).
        XCTAssertEqual(Set(pairEdges.map { $0.to.rawText }), Set(["A", "B"]))

        // Container's associatedtype Element: Hashable -> genericConstraint edge to Hashable
        XCTAssertTrue(containerEdges.contains { $0.kind == .genericConstraint && $0.to.rawText == "Hashable" })

        // Box: class generic constraints T: Equatable, where U == Int
        XCTAssertTrue(boxEdges.contains { $0.kind == .genericConstraint && $0.to.rawText == "Equatable" })
        XCTAssertTrue(boxEdges.contains { $0.kind == .genericConstraint && $0.to.rawText == "Int" })

        // Box: typealias Element = T -> own typealias edge with role .aliases.
        let typealiasId = makeOwnerId(module: module, parents: ["Box"], name: "Element", kind: .typealias)
        let aliasEdges = edges.filter { $0.fromId == typealiasId && $0.kind == .aliases }
        XCTAssertEqual(aliasEdges.count, 1)
        XCTAssertEqual(aliasEdges.first?.to.rawText, "T")

        // Box: init signature parameters: items: [T] (unwraps to T), counter: U? (unwraps to U).
        let initParamRaws = boxEdges
            .filter { $0.kind == .parameterType }
            .map { $0.to.rawText }
        XCTAssertTrue(initParamRaws.contains("T"))
        XCTAssertTrue(initParamRaws.contains("U"))

        // Box.transform<V>(_ f: (T) -> V) -> [V] where V: Comparable
        // returnType edge for [V] (unwrapped to V); genericConstraint edge for Comparable.
        XCTAssertTrue(boxEdges.contains { $0.kind == .returnType && $0.to.rawText == "V" })
        XCTAssertTrue(boxEdges.contains { $0.kind == .genericConstraint && $0.to.rawText == "Comparable" })
    }

    // MARK: - ExtensionsAndAliases

    func testExtensionsAndAliasesFixture() throws {
        let module = "Ext"
        let edges = try collectEdges("ExtensionsAndAliases/Aliases.swift", module: module)

        // Extension ids are file:line-tagged, so collect all owner ids that
        // emitted an `extends → Person` edge — these are the Person extensions.
        let personExtensionIds = Set(
            edges.filter { $0.kind == .extends && $0.to.rawText == "Person" }
                .map(\.fromId)
        )
        XCTAssertEqual(personExtensionIds.count, 2,
                       "Expected two extension owner ids extending Person")
        let extEdges = edges.filter { personExtensionIds.contains($0.fromId) }

        // Conformance edges to Greetable and Identifiable from one of the extensions.
        let conformedNames = Set(extEdges.filter { $0.kind == .conforms }.map { $0.to.rawText })
        XCTAssertTrue(conformedNames.contains("Greetable"))
        XCTAssertTrue(conformedNames.contains("Identifiable"))

        // The first extension declares `var id: String` and `func greet() -> String`
        // → propertyType edge for String and returnType edge for String.
        XCTAssertTrue(extEdges.contains { $0.kind == .propertyType && $0.to.rawText == "String" })
        XCTAssertTrue(extEdges.contains { $0.kind == .returnType && $0.to.rawText == "String" })

        // Nested typealias inside the second extension: Person.Nickname = String.
        let nicknameId = makeOwnerId(module: module, parents: ["Person"], name: "Nickname", kind: .typealias)
        let nicknameEdges = edges.filter { $0.fromId == nicknameId }
        XCTAssertEqual(nicknameEdges.count, 1)
        XCTAssertEqual(nicknameEdges.first?.kind, .aliases)
        XCTAssertEqual(nicknameEdges.first?.to.rawText, "String")

        // Top-level `typealias People = [Person]` → aliases edge to Person (array unwrapped).
        let peopleId = makeOwnerId(module: module, name: "People", kind: .typealias)
        let peopleEdges = edges.filter { $0.fromId == peopleId }
        XCTAssertEqual(peopleEdges.first?.kind, .aliases)
        XCTAssertEqual(peopleEdges.first?.to.rawText, "Person")
    }
}
