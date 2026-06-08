public protocol Drivable {
    func drive()
}

public struct Engine {
    public let horsepower: Int
    public init(horsepower: Int) { self.horsepower = horsepower }
}
