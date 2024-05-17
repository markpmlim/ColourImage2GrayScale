/*
 Apple's Demo: Converting Color Images to Grayscale
 Convert a color image to grayscale using matrix multiplication.
 */
import UIKit
import Accelerate.vImage

let uiImage = UIImage(named: "Food_4.JPG")
var cgImage = uiImage?.cgImage
// 5 - non-premultiplied RGBX
//print(cgImage?.bitmapInfo)

// A bitmapInfo of CGImageAlphaInfo.first indicates non-premultiplied ARGB
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue)
var imageFormat = vImage_CGImageFormat(
    bitsPerComponent:8,
    bitsPerPixel: 8*4,
    colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: bitmapInfo,
    renderingIntent: .defaultIntent)!

var sourceBuffer = vImage_Buffer()
var error = vImageBuffer_InitWithCGImage(
    &sourceBuffer,
    &imageFormat,
    nil,
    cgImage!,
    vImage_Flags(kvImageNoFlags))

// Verify the pixels are in 32ARGB format
var bytePtr = sourceBuffer.data.assumingMemoryBound(to: UInt8.self)
for _ in 0..<2 * imageFormat.componentCount {
    print(bytePtr.pointee)
    bytePtr = bytePtr.advanced(by: 1)
}

let divisor: Int32 = 0x1000         // 4096 decimal
let fDivisor = Float(divisor)

// y = 0.2126*R + 0.7152*G + 0.0722*B where y is the luminance
// of the red, green and blue components of a pixel.
let redCoefficient: Float = 0.2126
let greenCoefficient: Float = 0.7152
let blueCoefficient: Float = 0.0722

// The function vImageMatrixMultiply_ARGB8888ToPlanar8 only accepts an Integer Matrix
var coefficientsMatrix = [
    Int16(redCoefficient * fDivisor),
    Int16(greenCoefficient * fDivisor),
    Int16(blueCoefficient * fDivisor)
]

// Allocate memory for the destination vImage_Buffer
let memoryPtr = malloc(sourceBuffer.rowBytes * Int(sourceBuffer.height))
var destinationBuffer = vImage_Buffer(
    data: memoryPtr,
    height: sourceBuffer.height,
    width: sourceBuffer.width,
    rowBytes: sourceBuffer.rowBytes
)

defer {
    destinationBuffer.free()
}

/*
 Define pre- and post-bias as zero: the color-to-grayscale calculation is
 the sum of the products of each color value and its corresponding coefficient.
 */
let preBias: [Int16] = [0, 0, 0, 0]
let postBias: Int32 = 0

error = vImageMatrixMultiply_ARGB8888ToPlanar8(
    &sourceBuffer,
    &destinationBuffer,
    &coefficientsMatrix,
    divisor,
    preBias,
    postBias,
    vImage_Flags(kvImageNoFlags))

// Create a Grayscale Core Graphics Image.
// Create a 1-channel grayscale CGImage instance from the destination buffer.
// A bitmapInfo of CGImageAlphaInfo.none means RGB
guard let monoFormat = vImage_CGImageFormat(
    bitsPerComponent: 8,
    bitsPerPixel: 8,
    colorSpace: CGColorSpaceCreateDeviceGray(),
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
    renderingIntent: .defaultIntent)
else {
    fatalError("Can't create the image format")
}

let result = try? destinationBuffer.createCGImage(format: monoFormat)

