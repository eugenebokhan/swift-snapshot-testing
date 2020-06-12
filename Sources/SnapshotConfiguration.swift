import Foundation

public struct SnapshotConfiguration {
    public var ignoreRects: [CGRect]
    public var comparisonPolicy: ComparisonPolicy
    public var diffHighlightColor: SIMD4<Float>
    public var recording: Bool
    
    
    public init(comparisonPolicy: ComparisonPolicy = .eucledean(10),
                diffHighlightColor: SIMD4<Float> = .init(1, 0, 0, 1),
                ignoreRects: [CGRect] = [],
                recording: Bool = false) {
        self.comparisonPolicy = comparisonPolicy
        self.diffHighlightColor = diffHighlightColor
        self.ignoreRects = ignoreRects
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
