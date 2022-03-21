//
//  BlurDetector.swift
//  asd
//
//  Created by Kirill Galuzo on 13.09.2022.
//
/* Пусть пока останется на память, может я где-то и ошибся, а может оно так долго и работает
import AVFoundation
import Accelerate
import UIKit
 https://developer.apple.com/documentation/accelerate/finding_the_sharpest_image_in_a_sequence_of_captured_images
// MARK: BlurDetector
class BlurDetector: NSObject
{
	private let frameCounter = FrameCounter()

	let laplacian: [Float] = [0, -1, 0,
							  -1,  4, -1,
							  0, -1, 0]
	
	var resultHandler: ((BlurDetectionResult) -> Void)?

	/// Creates a grayscale `CGImage` from a array of pixel values, applying specified gamma.
	///
	/// - Parameter pixels: The array of `UInt8` values representing the image data.
	/// - Parameter width: The image width.
	/// - Parameter height: The image height.
	/// - Parameter gamma: The gamma to apply.
	/// - Parameter orientation: The orientation of of the image.
	///
	/// - Returns: A grayscale Core Graphics image.
	static func makeImage(fromPixels pixels: inout [Pixel_8],
						  width: Int,
						  height: Int,
						  gamma: Float,
						  orientation: CGImagePropertyOrientation) -> CGImage? {
		
		let alignmentAndRowBytes = try? vImage_Buffer.preferredAlignmentAndRowBytes(
			width: width,
			height: height,
			bitsPerPixel: 8)
		
		let image: CGImage? = pixels.withUnsafeMutableBufferPointer {
			var buffer = vImage_Buffer(data: $0.baseAddress!,
									   height: vImagePixelCount(height),
									   width: vImagePixelCount(width),
									   rowBytes: alignmentAndRowBytes?.rowBytes ?? width)
			
			vImagePiecewiseGamma_Planar8(&buffer,
										 &buffer,
										 [1, 0, 0],
										 gamma,
										 [1, 0],
										 0,
										 vImage_Flags(kvImageNoFlags))
			
			return BlurDetector.makeImage(fromPlanarBuffer: buffer,
										  orientation: orientation)
		}
		
		return image
	}
	
	/// Creates a grayscale `CGImage` from an 8-bit planar buffer.
	///
	/// - Parameter sourceBuffer: The vImage containing the image data.
	/// - Parameter orientation: The orientation of of the image.
	///
	/// - Returns: A grayscale Core Graphics image.
	static func makeImage(fromPlanarBuffer sourceBuffer: vImage_Buffer,
						  orientation: CGImagePropertyOrientation) -> CGImage? {
		
		guard  let monoFormat = vImage_CGImageFormat(bitsPerComponent: 8,
													 bitsPerPixel: 8,
													 colorSpace: CGColorSpaceCreateDeviceGray(),
													 bitmapInfo: []) else {
														return nil
		}
		
		var outputBuffer: vImage_Buffer
		var outputRotation: Int
		
		do {
			if orientation == .right || orientation == .left {
				outputBuffer = try vImage_Buffer(width: Int(sourceBuffer.height),
												 height: Int(sourceBuffer.width),
												 bitsPerPixel: 8)
				
				outputRotation = orientation == .right ?
					kRotate90DegreesClockwise : kRotate90DegreesCounterClockwise
			} else if orientation == .up || orientation == .down {
				outputBuffer = try vImage_Buffer(width: Int(sourceBuffer.width),
												 height: Int(sourceBuffer.height),
												 bitsPerPixel: 8)
				outputRotation = orientation == .down ?
					kRotate180DegreesClockwise : kRotate0DegreesClockwise
			} else {
				return nil
			}
		} catch {
			return nil
		}
		
		defer {
			outputBuffer.free()
		}
		
		var error = kvImageNoError
		
		withUnsafePointer(to: sourceBuffer) { src in
			error = vImageRotate90_Planar8(src,
										   &outputBuffer,
										   UInt8(outputRotation),
										   0,
										   vImage_Flags(kvImageNoFlags))
		}
		
		if error != kvImageNoError {
			return nil
		} else {
			return try? outputBuffer.createCGImage(format: monoFormat)
		}
	}
}

// MARK: BlurDetector AVCapturePhotoCaptureDelegate extension

extension BlurDetector: AVCaptureVideoDataOutputSampleBufferDelegate
{
	func captureOutput(_ output: AVCaptureOutput,
					   didOutput sampleBuffer: CMSampleBuffer,
					   from connection: AVCaptureConnection) {
		self.frameCounter.frameReceived()
		sampleBuffer.imageBuffer.map(self.processPixelBuffer)
	}

	func processPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
		let frameID = UUID()
		self.frameCounter.frameStartedHandling(id: frameID)
		CVPixelBufferLockBaseAddress(pixelBuffer,
									 CVPixelBufferLockFlags.readOnly)

		let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
		let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
		let count = width * height
		
		let lumaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
		let lumaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
		
		let lumaCopy = UnsafeMutableRawPointer.allocate(byteCount: count,
														alignment: MemoryLayout<Pixel_8>.alignment)
		lumaCopy.copyMemory(from: lumaBaseAddress!,
							byteCount: count)
		
		
		CVPixelBufferUnlockBaseAddress(pixelBuffer,
									   CVPixelBufferLockFlags.readOnly)
		
		DispatchQueue.global(qos: .utility).async {
			self.processImage(id: frameID,
							  data: lumaCopy,
							  rowBytes: lumaRowBytes,
							  width: width,
							  height: height)
			
			lumaCopy.deallocate()
		}
	}
}

extension BlurDetector {
	
	func processImage(id: UUID,
					  data: UnsafeMutableRawPointer,
					  rowBytes: Int,
					  width: Int, height: Int) {

		let redCoefficient: Float = 0.2126
		let greenCoefficient: Float = 0.7152
		let blueCoefficient: Float = 0.0722

		let divisor: Int32 = 0x1000
		let fDivisor = Float(divisor)

		var coefficientsMatrix = [
			Int16(redCoefficient * fDivisor),
			Int16(greenCoefficient * fDivisor),
			Int16(blueCoefficient * fDivisor)
		]

		let preBias: [Int16] = [0, 0, 0, 0]
		let postBias: Int32 = 0
		
		var sourceBuffer = vImage_Buffer(data: data,
										 height: vImagePixelCount(height),
										 width: vImagePixelCount(width),
										 rowBytes: rowBytes)

////		var destinationBuffer = vImage_Buffer(data: data,
////											  height: vImagePixelCount(height),
////											  width: vImagePixelCount(width),
////											  rowBytes: rowBytes)
//
//		vImageMatrixMultiply_ARGB8888ToPlanar8(&sourceBuffer,
//											   &destinationBuffer,
//											   &coefficientsMatrix,
//											   divisor,
//											   preBias,
//											   postBias,
//											   vImage_Flags(kvImageNoFlags))
		
		var floatPixels: [Float]
		let count = width * height
		
		if sourceBuffer.rowBytes == width * MemoryLayout<Pixel_8>.stride {
			let start = sourceBuffer.data.assumingMemoryBound(to: Pixel_8.self)
			floatPixels = vDSP.integerToFloatingPoint(
				UnsafeMutableBufferPointer(start: start,
										   count: count),
				floatingPointType: Float.self)
		} else {
			floatPixels = [Float](unsafeUninitializedCapacity: count) {
				buffer, initializedCount in
				
				var floatBuffer = vImage_Buffer(data: buffer.baseAddress,
												height: sourceBuffer.height,
												width: sourceBuffer.width,
												rowBytes: width * MemoryLayout<Float>.size)
				
				vImageConvert_Planar8toPlanarF(&sourceBuffer,
											   &floatBuffer,
											   0, 255,
											   vImage_Flags(kvImageNoFlags))
				
				initializedCount = count
			}
		}
		
		// Convolve with Laplacian.
		vDSP.convolve(floatPixels,
					  rowCount: height,
					  columnCount: width,
					  with3x3Kernel: laplacian,
					  result: &floatPixels)
		
		// Calculate standard deviation.
		var mean = Float.nan
		var stdDev = Float.nan
		
		vDSP_normalize(floatPixels, 1,
					   nil, 1,
					   &mean, &stdDev,
					   vDSP_Length(count))
		self.frameCounter.frameFinishedHandling(id: id)
		DispatchQueue.main.async { [weak self] in
			self?.result(stdDev)
		}
	}

	func result(_ stdDev: Float) {
		let state: BlurDetectionResult.State
		if stdDev > 15 {
			state = .good
		}
		else {
			state = .bad
		}
		let frameInfoString = self.frameCounter.getTotalInfoAsString()
		self.resultHandler?(BlurDetectionResult(state: state, string: "STD DEV: \(stdDev)\n\(frameInfoString)", uiimage: nil))
	}
}

// Extensions to simplify conversion between orientation enums.
extension UIImage.Orientation {
	init(_ cgOrientation: CGImagePropertyOrientation) {
		switch cgOrientation {
		case .up:
			self = .up
		case .upMirrored:
			self = .upMirrored
		case .down:
			self = .down
		case .downMirrored:
			self = .downMirrored
		case .left:
			self = .left
		case .leftMirrored:
			self = .leftMirrored
		case .right:
			self = .right
		case .rightMirrored:
			self = .rightMirrored
		}
	}
}

extension AVCaptureVideoOrientation {
	init?(_ uiInterfaceOrientation: UIInterfaceOrientation) {
		switch uiInterfaceOrientation {
		case .unknown:
			return nil
		case .portrait:
			self = .portrait
		case .portraitUpsideDown:
			self = .portraitUpsideDown
		case .landscapeLeft:
			self = .landscapeLeft
		case .landscapeRight:
			self = .landscapeRight
		@unknown default:
			return nil
		}
	}
}
*/
