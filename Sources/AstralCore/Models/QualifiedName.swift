import Foundation

public struct QualifiedName: Hashable, Codable, Sendable {
    public let module: String?
    public let parents: [String]
    public let name: String

    public init(module: String?, parents: [String], name: String) {
        self.module = module
        self.parents = parents
        self.name = name
    }

    public var simple: String { name }

    public var dotted: String {
        var components: [String] = []
        if let module = module { components.append(module) }
        components.append(contentsOf: parents)
        components.append(name)
        return components.joined(separator: ".")
    }
}
