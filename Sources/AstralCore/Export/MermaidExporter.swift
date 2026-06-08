import Foundation

/// Mermaid `classDiagram` exporter. Each `TypeKind` becomes a `class`
/// block (with a `<<stereotype>>` for non-class kinds). Edge mapping:
///   inherits          → `<|--`
///   conforms          → `<|..`
///   propertyType      → `*--`
///   parameterType     → `-->`
///   returnType        → `..>`
///   genericConstraint → `..>`
///   extends           → `o--`
///   nests             → `*--`
///   aliases           → `..>`
public struct MermaidExporter: GraphExporter {
    public init() {}

    public func render(_ graph: DependencyGraph) throws -> Data {
        var out = "classDiagram\n"
        for node in graph.nodes.values.sorted(by: { $0.id < $1.id }) {
            let alias = mermaidId(node.id)
            let stereotype = node.kind == .class ? nil : node.kind.rawValue
            if let stereotype = stereotype {
                out += "  class \(alias)[\"\(node.qualifiedName.name)\"] {\n"
                out += "    <<\(stereotype)>>\n"
                out += "  }\n"
            } else {
                out += "  class \(alias)[\"\(node.qualifiedName.name)\"]\n"
            }
        }

        let sorted = graph.edges.sorted {
            ($0.fromId, $0.kind.rawValue, $0.location.line)
                < ($1.fromId, $1.kind.rawValue, $1.location.line)
        }
        for edge in sorted {
            guard let target = edge.resolvedToIds.first else { continue }
            let relation = Self.relation(for: edge.kind)
            out += "  \(mermaidId(edge.fromId)) \(relation) \(mermaidId(target)) : \(edge.kind.rawValue)\n"
        }
        return Data(out.utf8)
    }

    private func mermaidId(_ id: TypeDeclaration.ID) -> String {
        var sanitized = ""
        for ch in id {
            if ch.isLetter || ch.isNumber || ch == "_" {
                sanitized.append(ch)
            } else {
                sanitized.append("_")
            }
        }
        if let first = sanitized.first, first.isNumber { sanitized = "n" + sanitized }
        return sanitized
    }

    private static func relation(for kind: DependencyEdgeKind) -> String {
        switch kind {
        case .inherits: return "<|--"
        case .conforms: return "<|.."
        case .propertyType: return "*--"
        case .parameterType: return "-->"
        case .returnType: return "..>"
        case .genericConstraint: return "..>"
        case .extends: return "o--"
        case .nests: return "*--"
        case .aliases: return "..>"
        }
    }
}
