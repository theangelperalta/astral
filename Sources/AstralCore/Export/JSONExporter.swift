import Foundation

/// JSON exporter that emits the schema defined in `plan §8`. Output is
/// deterministic: nodes are ordered by id, edges by (fromId, kind, location).
public struct JSONExporter: GraphExporter {
    public init() {}

    public func render(_ graph: DependencyGraph) throws -> Data {
        let payload = Payload(
            metadata: graph.metadata,
            nodes: graph.nodes.values.sorted { $0.id < $1.id },
            edges: graph.edges.sorted {
                ($0.fromId, $0.kind.rawValue, $0.location.line)
                    < ($1.fromId, $1.kind.rawValue, $1.location.line)
            },
            unresolved: graph.unresolvedReferences.sorted {
                ($0.rawText, $0.location.line) < ($1.rawText, $1.location.line)
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    private struct Payload: Codable {
        let metadata: DependencyGraph.Metadata
        let nodes: [TypeDeclaration]
        let edges: [DependencyEdge]
        let unresolved: [TypeReference]
    }
}
