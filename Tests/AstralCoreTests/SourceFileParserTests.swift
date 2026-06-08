import XCTest
import SwiftSyntax
@testable import AstralCore

final class SourceFileParserTests: XCTestCase {
    func testParsesSimpleFixture() throws {
        let url = try TestSupport.fixture("SimpleProtocol/Simple.swift")
        let parsed = try SourceFileParser().parse(url, module: "SimpleProtocol")
        XCTAssertFalse(parsed.syntax.statements.isEmpty)
        XCTAssertEqual(parsed.imports, ["Foundation"])
        XCTAssertEqual(parsed.moduleName, "SimpleProtocol")
    }
}
