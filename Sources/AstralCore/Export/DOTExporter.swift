import Foundation

/// Graphviz DOT exporter. Edge style: inherits/conforms = solid; member-type
/// kinds = dashed; structural (extends/nests/aliases) = dotted. A legend
/// subgraph is appended at the end.
public struct DOTExporter: GraphExporter {
    public init() {}

    public func render(_ graph: DependencyGraph) throws -> Data {
        var out = "digraph Astral {\n"
        out += "  rankdir=LR;\n"
        out += "  node [shape=box, fontname=\"Helvetica\"];\n\n"

        for node in graph.nodes.values.sorted(by: { $0.id < $1.id }) {
            let label = "«\(node.kind.rawValue)»\\n\(node.qualifiedName.name)"
            out += "  \(quoted(node.id)) [label=\"\(label)\"];\n"
        }
        out += "\n"

        let sortedEdges = graph.edges.sorted {
            ($0.fromId, $0.kind.rawValue, $0.location.line)
                < ($1.fromId, $1.kind.rawValue, $1.location.line)
        }
        for edge in sortedEdges {
            let style = Self.style(for: edge.kind)
            let target = edge.resolvedToIds.first ?? edge.to.rawText
            out += "  \(quoted(edge.fromId)) -> \(quoted(target)) "
            out += "[label=\"\(edge.kind.rawValue)\", style=\(style.line), arrowhead=\(style.head)];\n"
        }

        out += "\n  subgraph cluster_legend {\n"
        out += "    label=\"Legend\";\n"
        out += "    L_inherits -> L_inherits2 [label=\"inherits/conforms\", style=solid, arrowhead=onormal];\n"
        out += "    L_property -> L_property2 [label=\"property/param/return/constraint\", style=dashed, arrowhead=vee];\n"
        out += "    L_structural -> L_structural2 [label=\"nests/extends/aliases\", style=dotted, arrowhead=odot];\n"
        out += "  }\n}\n"
        return Data(out.utf8)
    }

    private func quoted(_ s: String) -> String { "\"\(s)\"" }

    private struct Style { let line: String; let head: String }

    private static func style(for kind: DependencyEdgeKind) -> Style {
        switch kind {
        case .inherits, .conforms:
            return Style(line: "solid", head: "onormal")
        case .propertyType, .parameterType, .returnType, .genericConstraint:
            return Style(line: "dashed", head: "vee")
        case .extends, .nests, .aliases:
            return Style(line: "dotted", head: "odot")
        }
    }
}
