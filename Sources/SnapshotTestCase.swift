import XCTest
import Alloy
import ResourcesBridge
import DeviceKit
import UIKit

open class SnapshotTestCase: XCTestCase {

    public enum Error: Swift.Error {
        case resourceSendingFailed
        case snaphotAssertingFailed
    }

    // MARK: - Public Properties

    open var snapshotsReferencesFolder: String { "/" }

    // MARK: - Private Properties

    private let context = try! MTLContext()
    private lazy var rectangleRenderer = try! RectangleRenderer(context: self.context)
    private lazy var textureCopy = try! TextureCopy(context: self.context)
    private lazy var textureDifference = try! TextureDifferenceHighlight(context: self.context)
    private lazy var l2Distance = try! EuclideanDistance(context: self.context)
    private let device = Device.current
    private let bridge = try! ResourcesBridge()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private lazy var rectsPassDescriptor: MTLRenderPassDescriptor = {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].loadAction = .load
        descriptor.colorAttachments[0].storeAction = .store
        return descriptor
    }()


    public func testName(funcName: String = #function,
                         line: Int = #line) -> String {
        let deviceDescription = self.device.safeDescription
        return "\(funcName)-\(line)-\(deviceDescription)"
    }

    public func assert(element: XCUIElement,
                       testName: String,
                       options: SnapshotConfiguration) throws {
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
                        options: options)
    }

    public func assert(screenshot: XCUIScreenshot,
                       testName: String,
                       ignoreStatusBar: Bool = true,
                       options: SnapshotConfiguration) throws {
        guard let cgImage = screenshot.image.cgImage
        else { throw Error.snaphotAssertingFailed }
        let screenTexture = try self.context.texture(from: cgImage, srgb: false)

        if ignoreStatusBar {
            var yOffset: CGFloat = 0
            let sensorHousing = Device.allDevicesWithSensorHousing
                              + Device.allSimulatorDevicesWithSensorHousing
            let plusSized = Device.allPlusSizedDevices
                          + Device.allSimulatorPlusSizedDevices
            if !self.device.isOneOf(sensorHousing) {
                yOffset = 22
            } else if self.device.isOneOf(sensorHousing)
                   && !self.device.isOneOf(plusSized) {
                yOffset = 44
            } else if self.device.isOneOf(sensorHousing)
                   && self.device.isOneOf(plusSized) {
                yOffset = 48.6
            }
            
            let statusBarRect = CGRect(x: .zero,
                                       y: .zero,
                                       width: .init(screenTexture.width),
                                       height: yOffset)
            
            var options = options
            options.ignoreRects.append(statusBarRect)
            
            try self.assert(texture: screenTexture,
                            testName: testName,
                            options: options)
        } else {
            try self.assert(texture: screenTexture,
                            testName: testName,
                            options: options)
        }
    }

    public func assert(texture: MTLTexture,
                       testName: String,
                       options: SnapshotConfiguration) throws {
        
        #if !targetEnvironment(simulator)
        self.bridge.waitForConnection()
        #endif

        let fileExtension = ".compressedTexture"
        let referenceScreenshotPath = self.snapshotsReferencesFolder
                                    + testName.sanitizedPathComponent
                                    + fileExtension
        
        if !options.ignoreRects.isEmpty {
            let scale = UIScreen.main.scale
            rectsPassDescriptor.colorAttachments[0].texture = texture
            let referenceSize = CGSize(width: CGFloat(texture.width) / scale,
                                       height: CGFloat(texture.height) / scale)
            let referenceRect = CGRect(origin: .zero, size: referenceSize)
            rectangleRenderer.color = .init(0, 0, 0, 1)
            try self.context.scheduleAndWait { commandBuffer in
                for rect in options.ignoreRects {
                    rectangleRenderer.normalizedRect = rect.normalized(reference: referenceRect)
                    try rectangleRenderer.render(renderPassDescriptor: self.rectsPassDescriptor,
                                                 commandBuffer: commandBuffer)
                }
            }
        }
        
        if options.recording {
            let textureData = try self.encoder.encode(texture.codable()).compressed()
            
            #if targetEnvironment(simulator)
            try textureData.write(to: URL(fileURLWithPath: referenceScreenshotPath))
            #else
            try self.bridge.writeResourceSynchronously(resource: textureData,
                                                       at: referenceScreenshotPath) { progress in
                #if DEBUG
                print("Sending reference: \(progress)")
                #endif
            }
            #endif
        } else {
            let data: Data
            #if targetEnvironment(simulator)
            data = try Data(contentsOf: URL(fileURLWithPath: referenceScreenshotPath))
            #else
            data = try self.bridge.readResourceSynchronously(at: referenceScreenshotPath) { progress in
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
                                              color: options.differenceColor,
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

            XCTAssertLessThan(distance, options.comparingPolicy.toEucledean())
        }
    }

    private static let textureUTI = "com.eugenebokhan.mtltextureviewer.texture"
}
