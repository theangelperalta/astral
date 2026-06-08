import Foundation
import SwiftSyntax

public struct ParsedFile {
    public let url: URL
    public let moduleName: String
    public let syntax: SourceFileSyntax
    public let locationConverter: SourceLocationConverter
    public let imports: [String]

    public init(url: URL,
                moduleName: String,
                syntax: SourceFileSyntax,
                locationConverter: SourceLocationConverter,
                imports: [String]) {
        self.url = url
        self.moduleName = moduleName
        self.syntax = syntax
        self.locationConverter = locationConverter
        self.imports = imports
    }
}
