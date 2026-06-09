import Foundation
import CryptoKit

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

    /// Builds a stable id derived from the edge's salient content so that
    /// repeated runs over identical inputs produce identical ids (and therefore
    /// byte-identical output). Identical edges intentionally collapse to the
    /// same id.
    public static func deterministicID(fromId: TypeDeclaration.ID,
                                       to rawText: String,
                                       kind: DependencyEdgeKind,
                                       location: SourceLocation,
                                       condition: String?) -> UUID {
        let seed = [
            fromId, rawText, kind.rawValue,
            location.file, String(location.line), String(location.column),
            condition ?? ""
        ].joined(separator: "\u{1F}")
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        // Stamp UUID version (5) and variant bits for a well-formed UUID.
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                           bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11],
                           bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
