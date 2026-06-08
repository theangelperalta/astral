import Foundation
import SwiftSyntax
import SwiftParser

public struct SourceFileParser {
    public init() {}

    public func parse(_ url: URL, module: String) throws -> ParsedFile {
        let source = try String(contentsOf: url, encoding: .utf8)
        let syntax = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: url.path, tree: syntax)
        let imports = ImportCollector.imports(of: syntax)
        return ParsedFile(
            url: url,
            moduleName: module,
            syntax: syntax,
            locationConverter: converter,
            imports: imports
        )
    }
}

enum ImportCollector {
    static func imports(of file: SourceFileSyntax) -> [String] {
        var result: [String] = []
        for statement in file.statements {
            guard let importDecl = statement.item.as(ImportDeclSyntax.self) else { continue }
            let path = importDecl.path.map { $0.name.text }.joined(separator: ".")
            if !path.isEmpty { result.append(path) }
        }
        return result
    }
}
