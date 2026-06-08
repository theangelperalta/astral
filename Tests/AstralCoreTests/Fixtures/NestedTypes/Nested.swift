struct Outer {
    struct Middle {
        struct Inner {
            let x: Int
        }
        enum Kind {
            case a
            case b
        }
    }
    typealias Pair = (Int, Int)
}

extension Outer.Middle {
    func doStuff() {}
}

actor Worker {
    var count: Int = 0
}
