import Foundation

public struct TypeDeclaration: Identifiable, Codable, Sendable, Hashable {
    public typealias ID = String

    public let id: ID
    public let kind: TypeKind
    public let qualifiedName: QualifiedName
    public let location: SourceLocation
    public let genericParameters: [String]
    public let genericConstraints: [String]
    public let inheritanceClauseRawNames: [String]
    public let nestedTypeIds: [ID]
    public let memberSummary: MemberSummary

    public struct MemberSummary: Codable, Sendable, Hashable {
        public let storedPropertyCount: Int
        public let computedPropertyCount: Int
        public let methodCount: Int
        public let initializerCount: Int

        public init(storedPropertyCount: Int = 0,
                    computedPropertyCount: Int = 0,
                    methodCount: Int = 0,
                    initializerCount: Int = 0) {
            self.storedPropertyCount = storedPropertyCount
            self.computedPropertyCount = computedPropertyCount
            self.methodCount = methodCount
            self.initializerCount = initializerCount
        }
    }

    public init(id: ID,
                kind: TypeKind,
                qualifiedName: QualifiedName,
                location: SourceLocation,
                genericParameters: [String] = [],
                genericConstraints: [String] = [],
                inheritanceClauseRawNames: [String] = [],
                nestedTypeIds: [ID] = [],
                memberSummary: MemberSummary = .init()) {
        self.id = id
        self.kind = kind
        self.qualifiedName = qualifiedName
        self.location = location
        self.genericParameters = genericParameters
        self.genericConstraints = genericConstraints
        self.inheritanceClauseRawNames = inheritanceClauseRawNames
        self.nestedTypeIds = nestedTypeIds
        self.memberSummary = memberSummary
    }

    /// Build a stable id from a qualified name and kind.
    public static func makeId(qualifiedName: QualifiedName, kind: TypeKind) -> ID {
        "\(qualifiedName.dotted)#\(kind.rawValue)"
    }

    /// Extensions can repeat for the same type in the same module. Their ids are
    /// disambiguated with the source location so each block becomes a distinct
    /// node. Both the declaration collector and the usage collector must use
    /// this helper so a declaration's `id` matches the `fromId` on its edges.
    public static func makeExtensionId(qualifiedName: QualifiedName,
                                       location: SourceLocation) -> ID {
        let fileTag = (location.file as NSString).lastPathComponent
        return "\(makeId(qualifiedName: qualifiedName, kind: .extension))@\(fileTag):\(location.line):\(location.column)"
    }
}
