import XCTest
import Alloy
import ResourcesBridge

open class SnapshotTestCase: XCTestCase {

    public enum Error: Swift.Error {
        case resourceSendingFailed
        case snaphotAssertingFailed
    }

    // MARK: - Public Properties

    public let snapshotsReferencesFolder = "/Users/eugenebokhan/Desktop/"

    // MARK: - Private Properties

    private let context = try! MTLContext()
    private lazy var textureDifference = try! TextureDifferenceHighlight(context: self.context)
    private lazy var l2Distance = try! EuclideanDistance(context: self.context)
    #if !targetEnvironment(simulator)
    private let bridge = try! ResourcesBridge()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    #endif

    public func assert(screenshot: XCUIScreenshot,
                       recording: Bool = false,
                       testName: String = #function,
                       file: StaticString = #file,
                       line: UInt = #line) throws {
        guard let cgImage = screenshot.image.cgImage
        else { throw Error.snaphotAssertingFailed }

        #if !targetEnvironment(simulator)
        self.bridge.tryToConnect()
        self.bridge.whaitForConnection()
        defer { self.bridge.abortConnection() }
        #endif

        let screenshotRemotePath = (self.snapshotsReferencesFolder + testName.sanitizedPathComponent + "/\(line).png")

        if recording {
            try self.bridge.writeResourceSynchronously(resource: screenshot.pngRepresentation,
                                                       at: screenshotRemotePath) { progress in
                #if DEBUG
                print("Sending: \(progress)")
                #endif
            }
        } else {
            let data = try self.bridge.readResourceSynchronously(at: screenshotRemotePath) { progress in
                #if DEBUG
                print("Receiving: \(progress)")
                #endif
            }
            guard let referenceCGImage = UIImage(data: data)?.cgImage
            else { throw Error.snaphotAssertingFailed }
            let referenceTexture = try self.context.texture(from: referenceCGImage)
            let texture = try self.context.texture(from: cgImage)
            let differenceTexture = try texture.matchingTexture()

            let distanceResultBuffer = try self.context.buffer(for: Float.self,
                                                               options: .storageModeShared)

            try self.context.scheduleAndWait { commandBuffer in
                self.l2Distance.encode(textureOne: texture,
                                       textureTwo: referenceTexture,
                                       resultBuffer: distanceResultBuffer,
                                       in: commandBuffer)
                self.textureDifference.encode(sourceTextureOne: texture,
                                              sourceTextureTwo: referenceTexture,
                                              destinationTexture: differenceTexture,
                                              color: .init(1, 0, 0, 1),
                                              threshold: 0.01,
                                              in: commandBuffer)
            }

            let distance = distanceResultBuffer.pointer(of: Float.self)?.pointee ?? 0
            let differenceImage = try differenceTexture.image()

            let distanceAttachment = XCTAttachment(string: "L2 distance: \(distance)")
            distanceAttachment.name = "L2 distance of snapshot"
            distanceAttachment.lifetime = .keepAlways
            self.add(distanceAttachment)

            let differenceAttachment = XCTAttachment(image: differenceImage)
            differenceAttachment.name = "Difference of snapshot"
            differenceAttachment.lifetime = .keepAlways
            self.add(differenceAttachment)

            print(distance)
        }
    }


    private static let textureUTI = "com.eugenebokhan.mtltextureviewer.texture"
}

fileprivate extension String {
    var sanitizedPathComponent: String {
        self.replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
    }
    init(_ staticString: StaticString) {
        self = staticString.withUTF8Buffer {
            String(decoding: $0, as: UTF8.self)
        }
    }
}
