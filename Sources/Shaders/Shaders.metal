#include <metal_stdlib>
#include "Macros.h"

using namespace metal;

constant bool deviceSupportsNonuniformThreadgroups [[ function_constant(0) ]];

struct BlockSize {
    ushort width;
    ushort height;
};

// MARK: - Euclidean Distance

float euclideanDistance(float4 firstValue,
                        float4 secondValue,
                        float threshold) {
    const float4 diff = firstValue - secondValue;
    if (abs(diff.r) > threshold ||
        abs(diff.g) > threshold ||
        abs(diff.b) > threshold ||
        abs(diff.a) > threshold) {
        return sqrt(dot(pow(diff, 2.0f), 1.0f));
    } else {
        return 0.0f;
    }
}

template <typename T>
void euclideanDistance(texture2d<T, access::sample> textureOne,
                       texture2d<T, access::sample> textureTwo,
                       constant BlockSize& inputBlockSize,
                       constant float& threshold,
                       device float& result,
                       threadgroup float* sharedMemory,
                       const ushort index,
                       const ushort2 position,
                       const ushort2 threadsPerThreadgroup) {
    const ushort2 textureSize = ushort2(textureOne.get_width(),
                                        textureOne.get_height());

    ushort2 originalBlockSize = ushort2(inputBlockSize.width,
                                        inputBlockSize.height);
    const ushort2 blockStartPosition = position * originalBlockSize;

    ushort2 blockSize = originalBlockSize;
    if (position.x == threadsPerThreadgroup.x || position.y == threadsPerThreadgroup.y) {
        const ushort2 readTerritory = blockStartPosition + originalBlockSize;
        blockSize = originalBlockSize - (readTerritory - textureSize);
    }

    float euclideanDistanceSumInBlock = 0.0f;

    for (ushort x = 0; x < blockSize.x; x++) {
        for (ushort y = 0; y < blockSize.y; y++) {
            const ushort2 readPosition = blockStartPosition + ushort2(x, y);
            const float4 textureOneValue = float4(textureOne.read(readPosition));
            const float4 textureTwoValue = float4(textureTwo.read(readPosition));
            euclideanDistanceSumInBlock += euclideanDistance(textureOneValue,
                                                             textureTwoValue,
                                                             threshold);
        }
    }

    sharedMemory[index] = euclideanDistanceSumInBlock;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (index == 0) {
        float totalEuclideanDistanceSum = sharedMemory[0];
        const ushort threadsInThreadgroup = threadsPerThreadgroup.x * threadsPerThreadgroup.y;
        for (ushort i = 1; i < threadsInThreadgroup; i++) {
            totalEuclideanDistanceSum += sharedMemory[i];
        }

        result = totalEuclideanDistanceSum;
    }

}

#define outerArguments(T)                                          \
(texture2d<T, access::sample> textureOne [[ texture(0) ]],         \
texture2d<T, access::sample> textureTwo [[ texture(1) ]],          \
constant BlockSize& inputBlockSize [[ buffer(0) ]],                \
constant float& threshold [[ buffer(1) ]],                         \
device float& result [[ buffer(2) ]],                              \
threadgroup float* sharedMemory [[ threadgroup(0) ]],              \
const ushort index [[ thread_index_in_threadgroup ]],              \
const ushort2 position [[ thread_position_in_grid ]],              \
const ushort2 threadsPerThreadgroup [[ threads_per_threadgroup ]])

#define innerArguments \
(textureOne,           \
textureTwo,            \
inputBlockSize,        \
threshold,             \
result,                \
sharedMemory,          \
index,                 \
position,              \
threadsPerThreadgroup)

generateKernels(euclideanDistance)

#undef outerArguments
#undef innerArguments
