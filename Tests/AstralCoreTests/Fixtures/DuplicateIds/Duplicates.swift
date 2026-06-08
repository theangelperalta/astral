import Foundation

class Person {
    let name: String = ""
}

// Two extensions of the same type in the same file/module — must produce
// two distinct extension nodes (id disambiguated by file:line).
extension Person {
    func greet() -> String { "Hi, \(name)" }
}

extension Person {
    func farewell() -> String { "Bye, \(name)" }
}

// Two `typealias Parameters` inside extensions on the same type — collide on
// the synthesized id (`_Root.Person.Parameters#typealias`). Pipeline must
// survive this gracefully (first wins) instead of trapping.
extension Person {
    typealias Parameters = (String, Int)
    func describe(_ p: Parameters) -> String { "\(p.0)-\(p.1)" }
}

extension Person {
    typealias Parameters = (Double, Bool)
    func summarize(_ p: Parameters) -> String { "\(p.0)/\(p.1)" }
}
