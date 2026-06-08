import Foundation

protocol Greetable {
    func greet() -> String
}

protocol Identifiable {
    var id: String { get }
}

struct Person {
    let name: String
}

extension Person: Greetable, Identifiable {
    var id: String { name }
    func greet() -> String { "Hi \(name)" }
}

extension Person {
    typealias Nickname = String
    func nickname() -> Nickname { name }
}

typealias People = [Person]
typealias Pair<T> = (T, T)
