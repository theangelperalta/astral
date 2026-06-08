import XCTest
@testable import AstralCore

final class FileDiscovererTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("astral-discoverer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    private func write(_ relPath: String, _ contents: String = "// stub") throws -> URL {
        let url = tempRoot.appendingPathComponent(relPath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testDiscoversSwiftFilesRecursivelySorted() throws {
        let a = try write("ModuleA/Foo.swift")
        let b = try write("ModuleB/Sub/Bar.swift")
        _ = try write("README.md", "# ignored")

        let result = try FileDiscoverer().discover(roots: [tempRoot])
        let paths = result.map { $0.path }
        XCTAssertEqual(paths, [a, b].map { $0.standardizedFileURL.path }.sorted())
    }

    func testDefaultExcludesIgnoreBuildAndGenerated() throws {
        _ = try write(".build/Debug/Foo.swift")
        _ = try write("Pods/Bar.swift")
        _ = try write("DerivedData/Baz.swift")
        let included = try write("Sources/Real.swift")
        _ = try write("Sources/Generated.generated.swift")

        let result = try FileDiscoverer().discover(roots: [tempRoot])
        XCTAssertEqual(result.map { $0.lastPathComponent }, ["Real.swift"])
        XCTAssertTrue(result.contains(included.standardizedFileURL))
    }

    func testUserExcludeGlob() throws {
        _ = try write("Sources/Keep.swift")
        _ = try write("Sources/Skip/Drop.swift")

        let opts = FileDiscoverer.Options(excludeGlobs: ["Sources/Skip/**"])
        let result = try FileDiscoverer().discover(roots: [tempRoot])
        XCTAssertEqual(result.count, 2)

        let filtered = try FileDiscoverer(options: opts).discover(roots: [tempRoot])
        XCTAssertEqual(filtered.map { $0.lastPathComponent }, ["Keep.swift"])
    }

    func testGlobMatcher() {
        XCTAssertTrue(GlobMatcher.matches(path: ".build/Foo.swift", pattern: ".build/**"))
        XCTAssertTrue(GlobMatcher.matches(path: "a/b/c/x.generated.swift", pattern: "**/*.generated.swift"))
        XCTAssertFalse(GlobMatcher.matches(path: "Sources/Foo.swift", pattern: ".build/**"))
        XCTAssertTrue(GlobMatcher.matches(path: "Foo.swift", pattern: "*.swift"))
    }
}
