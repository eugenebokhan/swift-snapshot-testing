import Foundation

public struct SnapshotOptions {
    public var ignoreRects: [CGRect]
    public var threshold: SnapshotThreshold
    public var recording: Bool
    public var savePreview: Bool
    
    public init(threshold: SnapshotThreshold = .eucledean(10),
                ignoreRects: [CGRect] = [],
                recording: Bool = false,
                savePreview: Bool = false) {
        self.threshold = threshold
        self.ignoreRects = ignoreRects
        self.recording = recording
        self.savePreview = savePreview
    }
}

public enum SnapshotThreshold {
    case eucledean(Float)
    
    func toEucledean() -> Float {
        switch self {
        case let .eucledean(threshold):
            return threshold
        }
    }
}
