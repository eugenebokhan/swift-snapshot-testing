import Alloy
import DeviceKit
#if !targetEnvironment(simulator)
import ResourcesBridge
#endif
import XCTest

open class SnapshotTestCase: XCTestCase {
    
    /// Snapshot configuration.
    public struct Configuration {
        
        /// The way of comparing snapshots with reference images.
        public enum ComparisonPolicy {
            /// Per-pixel L2 distance.
            case eucledean(Float)
            
            fileprivate var assertionThreshold: Float {
                switch self {
                case .eucledean(_): return 0
                }
            }
            fileprivate var threshold: Float {
                switch self {
                case let .eucledean(threshold): return threshold
                }
            }
        }
        
        /// The way of comparing snapshots with reference images.
        public var comparisonPolicy: ComparisonPolicy
        /// The color of the highligted difference in the test attachment.
        public var diffHighlightColor: SIMD4<Float>
        
        public init(comparisonPolicy: ComparisonPolicy = .eucledean(0.0),
                    diffHighlightColor: SIMD4<Float> = .init(1, 0, 0, 1)) {
            self.comparisonPolicy = comparisonPolicy
            self.diffHighlightColor = diffHighlightColor
        }
        
        public static let `default` = Configuration()
    }
    
    /// Element to ignore while asserting snapshot.
    public enum Ignorable: Hashable {
        case element(XCUIElement)
        case rect(CGRect)
        case statusBar
        
        fileprivate var ignoringFrame: CGRect {
            switch self {
            case let .element(element): return element.frame
            case let .rect(rect): return rect
            case .statusBar: return XCUIApplication.springboard.statusBars.firstMatch.frame
            }
        }
    }

    public enum Error: Swift.Error {
        case resourceSendingFailed
        case cgImageCreeationFailed
        case recordModeIsOn
        
        var localizedDescription: String {
            switch self {
            case .resourceSendingFailed:
                return "Failed to send reference snapshot."
            case .cgImageCreeationFailed:
                return "Failed to create a `CGImage` of current snapshot."
            case .recordModeIsOn:
                return "Recording mode is on."
            }
        }
    }

    // MARK: - Public Properties
    
    /// The directory in Mac to save reference snapshots.
    open var snapshotsReferencesFolder: String { "/" }

    // MARK: - Private Properties

    private let context = try! MTLContext()
    private lazy var rendererRect = try! RectangleRenderer(context: self.context)
    private lazy var textureCopy = try! TextureCopy(context: self.context)
    private lazy var textureDifference = try! TextureDifferenceHighlight(context: self.context)
    private lazy var l2Distance = try! EuclideanDistance(context: self.context)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    #if !targetEnvironment(simulator)
    private let bridge = try! ResourcesBridge()
    #endif
    
    private lazy var rectsPassDescriptor: MTLRenderPassDescriptor = {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].loadAction = .load
        descriptor.colorAttachments[0].storeAction = .store
        return descriptor
    }()
    
    // MARK: - Public
    
    /// Default test name used to give a snapshpot a unique name.
    /// - Parameters:
    ///   - funcName: Current test function.
    ///   - line: The line of the assertion call.
    /// - Returns: String including function name, line and device description.
    public func testName(funcName: String = #function,
                         line: Int = #line) -> String {
        return "\(funcName)-\(line)"
    }
    
    /// Test `XCUIElement`.
    /// - Parameters:
    ///   - element: Element to test.
    ///   - testName: Current test's name.
    ///   - rects: Rects (possible subviews' frames) to ignore.
    ///   - configuration: Current test configuration.
    ///   - recording: Recording mode.
    /// - Throws: Error on test fail.
    public func assert(element: XCUIElement,
                       testName: String,
                       ignore rects: Set<CGRect> = [],
                       configuration: Configuration = .default,
                       recording: Bool = false) throws {
        XCTAssert(element.exists)
        XCTAssert(element.isHittable)

        let screenshot = XCUIApplication().screenshot()
        guard let cgImage = screenshot.image.cgImage
        else { throw Error.cgImageCreeationFailed }

        let appFrame = XCUIApplication().frame
        let elementFrame = element.frame

        let origin = MTLOrigin(x: .init(elementFrame.origin.x / appFrame.width * .init(cgImage.width)),
                               y: .init(elementFrame.origin.y / appFrame.height * .init(cgImage.height)),
                               z: .zero)
        let size = MTLSize(width: .init(elementFrame.size.width / appFrame.width * .init(cgImage.width)),
                           height: .init(elementFrame.size.height / appFrame.height * .init(cgImage.height)),
                           depth: 1)
        let region = MTLRegion(origin: origin,
                               size: size)

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
                        ignore: rects,
                        configuration: configuration,
                        recording: recording)
    }
    
    /// Test `XCUIScreenshot`.
    /// - Parameters:
    ///   - screenshot: Screenshot to test.
    ///   - testName: Current test's name.
    ///   - ignorables: UI elements to ignore.
    ///   - configuration: Current test configurartion.
    ///   - recording: Recording mode.
    /// - Throws: Error on test fail.
    public func assert(screenshot: XCUIScreenshot,
                       testName: String,
                       ignore ignorables: Set<Ignorable> = [.statusBar],
                       configuration: Configuration = .default,
                       recording: Bool = false) throws {
        guard let cgImage = screenshot.image.cgImage
        else { throw Error.cgImageCreeationFailed }
        let screenTexture = try self.context.texture(from: cgImage,
                                                     srgb: false)

        try self.assert(texture: screenTexture,
                        testName: testName,
                        ignore: .init(ignorables.map { $0.ignoringFrame }),
                        configuration: configuration,
                        recording: recording)
    }
    
    /// Test `MTLTexture`.
    ///
    ///  This is a basic assertion function of this framework. Every element and screenshot is converted to texture and passed to this func.
    ///
    /// - Parameters:
    ///   - texture: Texture to test.
    ///   - testName: Current test's name.
    ///   - rects: Rects to ignore.
    ///   - configuration: Current test configurartion.
    ///   - recording: Recording mode.
    /// - Throws: Error on test fail.
    public func assert(texture: MTLTexture,
                       testName: String,
                       ignore rects: Set<CGRect> = [],
                       configuration: Configuration = .default,
                       recording: Bool = false) throws {
        
        #if !targetEnvironment(simulator)
        try self.bridge.waitForConnection()
        #endif

        let fileExtension = ".compressedTexture"
        let referenceScreenshotPath = self.snapshotsReferencesFolder
                                    + "\(testName)-\(Device.current.description)".sanitizedPathComponent
                                    + fileExtension
        
        if !rects.isEmpty {
            let scale = UIScreen.main.scale
            self.rectsPassDescriptor.colorAttachments[0].texture = texture
            let referenceSize = CGSize(width: CGFloat(texture.width) / scale,
                                       height: CGFloat(texture.height) / scale)
            let referenceRect = CGRect(origin: .zero, size: referenceSize)
            self.rendererRect.color = .init(0, 0, 0, 1)
            try self.context.scheduleAndWait { commandBuffer in
                rects.forEach { rect in
                    self.rendererRect.normalizedRect = rect.normalized(reference: referenceRect)
                    self.rendererRect(renderPassDescriptor: self.rectsPassDescriptor,
                                      commandBuffer: commandBuffer)
                }
            }
        }
        
        if recording {
            let textureData = try self.encoder.encode(texture.codable()).compressed()
            
            #if targetEnvironment(simulator)
            let referenceURL = URL(fileURLWithPath: referenceScreenshotPath)
            let referenceFolder = referenceURL.deletingLastPathComponent()
            var isDirectory: ObjCBool = true
            if !FileManager.default.fileExists(atPath: referenceFolder.path,
                                               isDirectory: &isDirectory) {
                try FileManager.default.createDirectory(at: referenceFolder,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
            }

            if FileManager.default.fileExists(atPath: referenceScreenshotPath) {
                try FileManager.default.removeItem(atPath: referenceScreenshotPath)
            }
            
            try textureData.write(to: referenceURL)
            #else
            try self.bridge.writeResource(textureData,
                                          at: referenceScreenshotPath) { progress in
                #if DEBUG
                print("Sending reference: \(progress)")
                #endif
            }
            #endif
            
            XCTFail("""
                \(Error.recordModeIsOn.localizedDescription)
                Turn recording mode off and re-run the \(testName) test with the newly-recorded reference.
                """)
        } else {
            let data: Data
            #if targetEnvironment(simulator)
            data = try Data(contentsOf: URL(fileURLWithPath: referenceScreenshotPath))
            #else
            data = try self.bridge.readResource(from: referenceScreenshotPath) { progress in
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
                self.l2Distance(textureOne: texture,
                                textureTwo: referenceTexture,
                                threshold: configuration.comparisonPolicy.threshold,
                                resultBuffer: distanceResultBuffer,
                                in: commandBuffer)
                self.textureDifference(sourceOne: texture,
                                       sourceTwo: referenceTexture,
                                       destination: differenceTexture,
                                       color: configuration.diffHighlightColor,
                                       threshold: configuration.comparisonPolicy.threshold,
                                       in: commandBuffer)
            }

            let distance = distanceResultBuffer.pointer(of: Float.self)?.pointee ?? .zero
            let differenceImage = try differenceTexture.image()

            let distanceAttachment = XCTAttachment(string: "L2 distance: \(distance)")
            distanceAttachment.name = "L2 distance of snapshot \(testName)"
            distanceAttachment.lifetime = .keepAlways
            self.add(distanceAttachment)

            let differenceAttachment = XCTAttachment(image: differenceImage)
            differenceAttachment.name = "Difference of snapshot \(testName)"
            differenceAttachment.lifetime = .keepAlways
            self.add(differenceAttachment)

            XCTAssertLessThanOrEqual(distance, configuration.comparisonPolicy.assertionThreshold)
        }
    }
}
