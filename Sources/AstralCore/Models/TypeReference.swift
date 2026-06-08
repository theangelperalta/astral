import Foundation

public struct TypeReference: Codable, Sendable, Hashable {
    public enum Role: String, Codable, Sendable, CaseIterable {
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

    public let rawText: String
    public let candidateQualifiedNames: [QualifiedName]
    public let genericArguments: [TypeReference]
    public let location: SourceLocation
    public let role: Role

    public init(rawText: String,
                candidateQualifiedNames: [QualifiedName],
                genericArguments: [TypeReference],
                location: SourceLocation,
                role: Role) {
        self.rawText = rawText
        self.candidateQualifiedNames = candidateQualifiedNames
        self.genericArguments = genericArguments
        self.location = location
        self.role = role
    }
}
