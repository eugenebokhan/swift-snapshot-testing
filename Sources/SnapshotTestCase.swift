import XCTest
import Alloy
import ResourcesBridge
import DeviceKit

open class SnapshotTestCase: XCTestCase {

    public enum Error: Swift.Error {
        case resourceSendingFailed
        case snaphotAssertingFailed
    }

    // MARK: - Public Properties

    open var snapshotsReferencesFolder: String { "/" }

    // MARK: - Private Properties

    private let context = try! MTLContext()
    private lazy var textureCopy = try! TextureCopy(context: self.context)
    private lazy var textureDifference = try! TextureDifferenceHighlight(context: self.context)
    private lazy var l2Distance = try! EuclideanDistance(context: self.context)
    private let device = Device.current
    #if targetEnvironment(simulator)
    private let fileManager = FileManager.default
    #else
    private let bridge = try! ResourcesBridge()
    #endif
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()


    public func testName(funcName: String = #function,
                         line: Int = #line) -> String {
        let deviceDescription = self.device.safeDescription
        return "\(funcName)-\(line)-\(deviceDescription)"
    }

    public func assert(element: XCUIElement,
                       testName: String,
                       threshold: Float = 10,
                       recording: Bool = false) throws {
        XCTAssert(element.exists)
        XCTAssert(element.isHittable)

        let screenshot = XCUIApplication().screenshot()
        guard let cgImage = screenshot.image.cgImage
        else { throw Error.snaphotAssertingFailed }

        let appFrame = XCUIApplication().frame
        let elementFrame = element.frame

        let region = MTLRegion(origin: .init(x: .init(elementFrame.origin.x / appFrame.width * .init(cgImage.width)),
                                             y: .init(elementFrame.origin.y / appFrame.height * .init(cgImage.height)),
                                             z: 0),
                               size: .init(width: .init(elementFrame.size.width / appFrame.width * .init(cgImage.width)),
                                           height: .init(elementFrame.size.height / appFrame.height * .init(cgImage.height)),
                                           depth: 1))

        let screenTexture = try self.context.texture(from: cgImage)
        let elementTexture = try self.context.texture(width: region.size.width,
                                                          height: region.size.height,
                                                          pixelFormat: .bgra8Unorm,
                                                          usage: [.shaderRead, .shaderWrite])
        try self.context.scheduleAndWait { commandBuffer in
            self.textureCopy.copy(region: region,
                                  from: screenTexture,
                                  to: .zero,
                                  of: elementTexture,
                                  in: commandBuffer)
        }

        try self.assert(texture: elementTexture,
                        testName: testName,
                        threshold: threshold,
                        recording: recording)
    }

    public func assert(screenshot: XCUIScreenshot,
                       testName: String,
                       ignoreStatusBar: Bool = true,
                       threshold: Float = 10,
                       recording: Bool = false) throws {
        let texture: MTLTexture

        guard let cgImage = screenshot.image.cgImage
        else { throw Error.snaphotAssertingFailed }
        let screenTexture = try self.context.texture(from: cgImage, srgb: false)

        if ignoreStatusBar {
            var yOffset: CGFloat = 0
            if !self.device.isOneOf(Device.allDevicesWithSensorHousing) {
                yOffset = 22
            } else if self.device.isOneOf(Device.allDevicesWithSensorHousing)
                   && !self.device.isOneOf(Device.allPlusSizedDevices) {
                yOffset = 44
            } else if self.device.isOneOf(Device.allDevicesWithSensorHousing)
                   && self.device.isOneOf(Device.allPlusSizedDevices) {
                yOffset = 48.6
            }

            let appFrame = XCUIApplication().frame

            let origin = MTLOrigin(x: 0,
                                   y: .init(yOffset / appFrame.height * .init(cgImage.height)),
                                   z: 0)
            let size = MTLSize(width: screenTexture.width,
                               height: screenTexture.height - origin.x,
                               depth: 1)
            let region = MTLRegion(origin: origin,
                                   size: size)

            texture = try self.context.texture(width: region.size.width,
                                               height: region.size.height,
                                               pixelFormat: .bgra8Unorm,
                                               usage: [.shaderRead, .shaderWrite])
            try self.context.scheduleAndWait { commandBuffer in
                self.textureCopy.copy(region: region,
                                      from: screenTexture,
                                      to: .zero,
                                      of: texture,
                                      in: commandBuffer)
            }
        } else {
            texture = screenTexture
        }

        try self.assert(texture: texture,
                        testName: testName,
                        threshold: threshold,
                        recording: recording)
    }

    public func assert(texture: MTLTexture,
                       testName: String,
                       threshold: Float = 10,
                       recording: Bool = false) throws {
        #if !targetEnvironment(simulator)
        self.bridge.waitForConnection()
        #endif

        let fileExtension = ".compressedTexture"
        let screenshotRemotePath = self.snapshotsReferencesFolder
                                 + testName.sanitizedPathComponent
                                 + fileExtension

        let textureData = try self.encoder.encode(texture.codable()).compressed()
        let resourceURL = URL(fileURLWithPath: screenshotRemotePath)

        if recording {
            #if targetEnvironment(simulator)
            let resourceFolder = resourceURL.deletingLastPathComponent()
            var isDirectory: ObjCBool = true
            if !self.fileManager.fileExists(atPath: resourceFolder.path,
                                            isDirectory: &isDirectory) {
                try self.fileManager.createDirectory(at: resourceFolder,
                                                     withIntermediateDirectories: true,
                                                     attributes: nil)
            }

            if self.fileManager.fileExists(atPath: screenshotRemotePath) {
                try self.fileManager.removeItem(atPath: screenshotRemotePath)
            }
            try textureData.write(to: resourceURL)
            #else
            try self.bridge.writeResourceSynchronously(resource: textureData,
                                                       at: screenshotRemotePath) { progress in
                #if DEBUG
                print("Sending: \(progress)")
                #endif
            }
            #endif
        } else {
            let data: Data
            #if targetEnvironment(simulator)
            data = try .init(contentsOf: resourceURL)
            #else
            data = try self.bridge.readResourceSynchronously(at: screenshotRemotePath) { progress in
                #if DEBUG
                print("Receiving: \(progress)")
                #endif
            }
            #endif

            let referenceTexture = try self.decoder
                                           .decode(MTLTextureCodableBox.self,
                                                   from: data.decompressed())
                                           .texture(device: self.context.device)

            XCTAssertEqual(texture.size, referenceTexture.size)

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
            distanceAttachment.name = "L2 distance of snapshot \(testName)"
            distanceAttachment.lifetime = .keepAlways
            self.add(distanceAttachment)

            let differenceAttachment = XCTAttachment(image: differenceImage)
            differenceAttachment.name = "Difference of snapshot \(testName)"
            differenceAttachment.lifetime = .keepAlways
            self.add(differenceAttachment)

            XCTAssertLessThan(distance, threshold)
        }
    }

    private static let textureUTI = "com.eugenebokhan.mtltextureviewer.texture"
}

private extension String {
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

extension MTLSize: Equatable {
    public static func == (lhs: MTLSize, rhs: MTLSize) -> Bool {
        return lhs.width == rhs.width
            && lhs.height == rhs.height
            && lhs.depth == rhs.depth
    }
}
