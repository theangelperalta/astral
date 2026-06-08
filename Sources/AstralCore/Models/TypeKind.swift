import Foundation

public enum TypeKind: String, Codable, Sendable, CaseIterable {
    case `protocol`
    case `class`
    case `struct`
    case `enum`
    case `actor`
    case `typealias`
    case `extension`
}
