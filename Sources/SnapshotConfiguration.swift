import Foundation
import XCTest

public struct SnapshotConfiguration {
    public var ignorables: [Ignorable]
    public var comparisonPolicy: ComparisonPolicy
    public var diffHighlightColor: SIMD4<Float>
    public var recording: Bool
    
    
    public init(comparisonPolicy: ComparisonPolicy = .eucledean(10),
                diffHighlightColor: SIMD4<Float> = .init(1, 0, 0, 1),
                ignore ignorables: [Ignorable] = [],
                recording: Bool = false) {
        self.comparisonPolicy = comparisonPolicy
        self.diffHighlightColor = diffHighlightColor
        self.ignorables = ignorables
        self.recording = recording
    }
}

public enum ComparisonPolicy {
    case eucledean(Float)
    
    func toEucledean() -> Float {
        switch self {
        case let .eucledean(threshold):
            return threshold
        }
    }
}

public protocol Ignorable {
    var ignoreFrame: CGRect { get }
}

extension XCUIElement: Ignorable {
    public var ignoreFrame: CGRect {
        self.frame
    }
}

public struct IgnoreFrame: Ignorable {
    public var ignoreFrame: CGRect
    
    public init(_ frame: CGRect) {
        self.ignoreFrame = frame
    }
}
