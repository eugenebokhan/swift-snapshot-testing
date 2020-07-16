import Alloy

final class EuclideanDistance {

    // MARK: - Properties

    let pipelineState: MTLComputePipelineState

    // MARK: - Life Cycle

    convenience init(context: MTLContext,
                     scalarType: MTLPixelFormat.ScalarType = .half) throws {
        try self.init(library: context.library(for: Self.self),
                      scalarType: scalarType)
    }

    init(library: MTLLibrary,
         scalarType: MTLPixelFormat.ScalarType = .half) throws {
        let functionName = Self.functionName + "_" + scalarType.rawValue
        self.pipelineState = try library.computePipelineState(function: functionName)
    }

    // MARK: - Encode

    func callAsFunction(textureOne: MTLTexture,
                        textureTwo: MTLTexture,
                        threshold: Float,
                        resultBuffer: MTLBuffer,
                        in commandBuffer: MTLCommandBuffer) {
        self.encode(textureOne: textureOne,
                    textureTwo: textureTwo,
                    threshold: threshold,
                    resultBuffer: resultBuffer,
                    in: commandBuffer)
    }

    func callAsFunction(textureOne: MTLTexture,
                        textureTwo: MTLTexture,
                        threshold: Float,
                        resultBuffer: MTLBuffer,
                        using encoder: MTLComputeCommandEncoder) {
        self.encode(textureOne: textureOne,
                    textureTwo: textureTwo,
                    threshold: threshold,
                    resultBuffer: resultBuffer,
                    using: encoder)
    }

    func encode(textureOne: MTLTexture,
                textureTwo: MTLTexture,
                threshold: Float,
                resultBuffer: MTLBuffer,
                in commandBuffer: MTLCommandBuffer) {
        commandBuffer.compute { encoder in
            encoder.label = "Euclidean Distance"
            self.encode(textureOne: textureOne,
                        textureTwo: textureTwo,
                        threshold: threshold,
                        resultBuffer: resultBuffer,
                        using: encoder)
        }
    }

    func encode(textureOne: MTLTexture,
                textureTwo: MTLTexture,
                threshold: Float,
                resultBuffer: MTLBuffer,
                using encoder: MTLComputeCommandEncoder) {
        let threadgroupSize = MTLSize(width: 8, height: 8, depth: 1).clamped(to: textureOne.size)
        let blockSizeWidth = (textureOne.width + threadgroupSize.width - 1)
                           / threadgroupSize.width
        let blockSizeHeight = (textureOne.height + threadgroupSize.height - 1)
                            / threadgroupSize.height
        let blockSize = BlockSize(width: blockSizeWidth,
                                  height: blockSizeHeight)

        encoder.set(textures: [textureOne,
                               textureTwo])
        encoder.set(blockSize, at: 0)
        encoder.set(threshold, at: 1)
        encoder.setBuffer(resultBuffer,
                          offset: 0,
                          index: 2)

        let threadgroupMemoryLength = threadgroupSize.width
                                    * threadgroupSize.height
                                    * 4
                                    * MemoryLayout<Float32>.stride

        encoder.setThreadgroupMemoryLength(threadgroupMemoryLength,
                                           index: 0)
        encoder.dispatch2d(state: self.pipelineState,
                           covering: .one,
                           threadgroupSize: threadgroupSize)
    }

    static let functionName = "euclideanDistance"
}
