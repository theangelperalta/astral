import Foundation

protocol Drawable {
    func draw()
}

struct Circle: Drawable {
    let radius: Double
    func draw() {}
}

class Canvas {
    let shape: Circle
    init(shape: Circle) { self.shape = shape }
}
