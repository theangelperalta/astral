import Foundation

protocol Container {
    associatedtype Element: Hashable
    func add(_ x: Element)
}

class Box<T: Equatable, U>: Container where U == Int {
    typealias Element = T

    var items: [T]
    var counter: U?
    let pair: (T, U)

    init(items: [T], counter: U?) {
        self.items = items
        self.counter = counter
        self.pair = (items[0], counter ?? 0)
    }

    func add(_ x: T) {
        items.append(x)
    }

    func transform<V>(_ f: (T) -> V) -> [V] where V: Comparable {
        return items.map(f)
    }
}

struct Pair<A, B> {
    let first: A
    let second: B
}
