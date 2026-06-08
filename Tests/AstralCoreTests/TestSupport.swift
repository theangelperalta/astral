import Foundation
import XCTest
@testable import AstralCore

/// Shared helpers for tests.
enum TestSupport {
    /// URL of a fixture directory (or file) bundled as a resource.
    static func fixture(_ relativePath: String,
                        file: StaticString = #filePath,
                        line: UInt = #line) throws -> URL {
        let bundle = Bundle.module
        // The fixtures are copied as a flat resource directory `Fixtures/...`.
        guard let base = bundle.url(forResource: "Fixtures", withExtension: nil) else {
            XCTFail("Missing Fixtures resource directory", file: file, line: line)
            throw NSError(domain: "TestSupport", code: 1)
        }
        return base.appendingPathComponent(relativePath)
    }
}
