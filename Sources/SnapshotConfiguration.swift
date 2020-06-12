import Foundation

public struct SnapshotConfiguration {
    public var ignoreRects: [CGRect]
    public var comparingPolicy: ComparisonPolicy
    public var differenceColor: SIMD4<Float>
    public var recording: Bool
    
    
    public init(comparingPolicy: ComparisonPolicy = .eucledean(10),
                differenceColor: SIMD4<Float> = .init(1, 0, 0, 1),
                ignoreRects: [CGRect] = [],
                recording: Bool = false) {
        self.comparingPolicy = comparingPolicy
        self.differenceColor = differenceColor
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
