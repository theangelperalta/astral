import Foundation

public struct DependencyGraph: Codable, Sendable {
    public var nodes: [TypeDeclaration.ID: TypeDeclaration]
    public var edges: [DependencyEdge]
    public var unresolvedReferences: [TypeReference]
    public var metadata: Metadata

    public struct Metadata: Codable, Sendable {
        public let astralVersion: String
        /// Generation timestamp. `nil` when the graph was produced in
        /// deterministic mode, in which case it is omitted from output so
        /// repeated runs over identical inputs yield byte-identical results.
        public let generatedAt: Date?
        public let inputRoots: [String]
        public let moduleNames: [String]

        public init(astralVersion: String,
                    generatedAt: Date?,
                    inputRoots: [String],
                    moduleNames: [String]) {
            self.astralVersion = astralVersion
            self.generatedAt = generatedAt
            self.inputRoots = inputRoots
            self.moduleNames = moduleNames
        }
    }

    public init(nodes: [TypeDeclaration.ID: TypeDeclaration] = [:],
                edges: [DependencyEdge] = [],
                unresolvedReferences: [TypeReference] = [],
                metadata: Metadata) {
        self.nodes = nodes
        self.edges = edges
        self.unresolvedReferences = unresolvedReferences
        self.metadata = metadata
    }
}
