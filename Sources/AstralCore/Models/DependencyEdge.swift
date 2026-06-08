import Foundation

public enum DependencyEdgeKind: String, Codable, Sendable, CaseIterable {
    case inherits
    case conforms
    case propertyType
    case parameterType
    case returnType
    case genericConstraint
    case extends
    case nests
    case aliases
}

public struct DependencyEdge: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let fromId: TypeDeclaration.ID
    public let to: TypeReference
    public let resolvedToIds: [TypeDeclaration.ID]
    public let kind: DependencyEdgeKind
    public let location: SourceLocation
    public let condition: String?

    public init(id: UUID = UUID(),
                fromId: TypeDeclaration.ID,
                to: TypeReference,
                resolvedToIds: [TypeDeclaration.ID] = [],
                kind: DependencyEdgeKind,
                location: SourceLocation,
                condition: String? = nil) {
        self.id = id
        self.fromId = fromId
        self.to = to
        self.resolvedToIds = resolvedToIds
        self.kind = kind
        self.location = location
        self.condition = condition
    }
}
