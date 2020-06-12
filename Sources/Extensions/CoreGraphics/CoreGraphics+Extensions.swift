import Foundation

extension CGRect {
    func normalized(reference: CGRect) -> CGRect {
        return .init(x: min(self.origin.x / reference.width, 1),
                     y: min(self.origin.y / reference.height, 1),
                     width: min(self.size.width / reference.width, 1),
                     height: min(self.size.height / reference.height, 1))
    }
}

extension CGRect: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.origin)
        hasher.combine(self.size)
    }
}
