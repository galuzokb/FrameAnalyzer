//
//  FrameAnalyzer.swift
//  asd
//
//  Created by Kirill Galuzo on 14.09.2022.
//

import AVFoundation
import Metal
import MetalPerformanceShaders
import MetalKit

typealias FrameAnalyzerType = AVCaptureVideoDataOutputSampleBufferDelegate & IFrameAnalyzer

protocol IFrameAnalyzer: AnyObject
{
	func configure(with completionHandler: @escaping (NSAttributedString) -> Void)
	func startAnalyzing()
	func stopAnalyzing(_ overralResultHandler: @escaping (OverralResult) -> Void)
}

final class FrameAnalyzer: NSObject
{
	private enum Constants
	{
		static let standartDeviationThreshold: Double = 25.0

		static let brightPixelShareThreshold: Double = 0.4
		static let darkPixelShareThreshold: Double = 0.45

		static let brightPixelValueThreshold: Float = 210 / 255
		static let darkPixelValueThreshold: Float = 40 / 255
	}

	private let errorMapper = ErrorMapper()
	private let frameCounter = FrameCounter()
	private let badImageCollector = BadImageCollector()

	private var mtlDevice: MTLDevice?
	private var mtlCommandQueue: MTLCommandQueue?

	private var completionHandler: ((NSAttributedString) -> Void)?

	override init() {
		self.mtlDevice = MTLCreateSystemDefaultDevice()
		self.mtlCommandQueue = self.mtlDevice?.makeCommandQueue()

		super.init()
	}
}

// MARK: - IFrameAnalyzer

extension FrameAnalyzer: IFrameAnalyzer
{
	func configure(with completionHandler: @escaping (NSAttributedString) -> Void) {
		self.completionHandler = completionHandler
	}

	func startAnalyzing() {
		self.frameCounter.reset()
		self.badImageCollector.reset()
	}

	func stopAnalyzing(_ overralResultHandler: @escaping (OverralResult) -> Void) {
		let badImages = self.badImageCollector.getBadImages()
		let result: OverralResult = badImages.isEmpty ? .thisIsFine : .someFramesAreBad(badImages)
		overralResultHandler(result)
	}
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension FrameAnalyzer: AVCaptureVideoDataOutputSampleBufferDelegate
{
	func captureOutput(_ output: AVCaptureOutput,
					   didOutput sampleBuffer: CMSampleBuffer,
					   from connection: AVCaptureConnection) {
		self.frameCounter.frameReceived()
		self.processFrame(sampleBuffer: sampleBuffer)
	}
}

// MARK: - Frame Processing

private extension FrameAnalyzer
{
	func processFrame(sampleBuffer: CMSampleBuffer) {
		let id = UUID()
		self.frameCounter.frameStartedHandling(id: id)

		guard
			let device = self.mtlDevice,
			let commandQueue = self.mtlCommandQueue,
			let pixelBuffer = sampleBuffer.imageBuffer,
			let image = self.makeImage(from: pixelBuffer)
		else {
			return
		}

		let resultBuilder = FrameAnalyzerResultBuilder(errorMapper: self.errorMapper)
		defer {
			self.frameCounter.frameFinishedHandling(id: id)
			let thresholds = FrameAnalyzerResultBuilder.Thresholds(
				standartDeviation: Constants.standartDeviationThreshold,
				darkPixelShare: Constants.darkPixelShareThreshold,
				brightPixelShare: Constants.brightPixelShareThreshold
			)
			let result = resultBuilder.build(thresholds: thresholds,
											 image: image)
			self.complete(with: result)
		}

		do {
			let sourceTexture = try self.makeSourceTexture(from: image, with: device)
			let grayScaleTexture = try self.makeGrayScaleTexture(from: sourceTexture,
																 commandQueue: commandQueue,
																 device: device)
			let brightness = try self.getBrightness(from: sourceTexture,
													commandQueue: commandQueue,
													device: device)
			resultBuilder.set(brightness: brightness)
			let standartDeviation = try self.getStandartDeviation(from: grayScaleTexture,
																  commandQueue: commandQueue,
																  device: device)
			resultBuilder.set(standartDeviation: standartDeviation)
		}
		catch {
			resultBuilder.set(error: error)
		}
	}

	func collectBadImages(from result: FrameAnalyzerResult) {
		func collect(key: String, value: Double, image: CGImage) {
			self.badImageCollector.addBadImage(
				BadImage(image: image, reason: "\(key): \(String(format: "%.2f", value))")
			)
		}
		if case let .bad(value, image) = result.darkPixel {
			collect(key: "Dark", value: value, image: image)
		}
		if case let .bad(value, image) = result.brightPixel {
			collect(key: "Bright", value: value, image: image)
		}
		if case let .bad(value, image) = result.standartDeviation {
			collect(key: "STD", value: value, image: image)
		}
	}

	func complete(with result: FrameAnalyzerResult) {
		self.collectBadImages(from: result)
		let frameInfoString = NSAttributedString(string: "\n\(self.frameCounter.getTotalInfoAsString())")
		let resultString = NSMutableAttributedString(attributedString: result.string)
		resultString.append(frameInfoString)
		DispatchQueue.main.async { [weak self] in
			self?.completionHandler?(resultString)
		}
	}
}

// MARK: - Яркость

private extension FrameAnalyzer
{
	func makeImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
		let ciContext = CIContext()
		let ciImage = CIImage(cvImageBuffer: pixelBuffer)
		return ciContext.createCGImage(ciImage, from: ciImage.extent)
	}

	func makeSourceTexture(from image: CGImage,
						   with device: MTLDevice) throws -> MTLTexture {

		let textureLoader = MTKTextureLoader(device: device)

		guard let sourceTexture = try? textureLoader.newTexture(cgImage: image) else {
			throw FrameAnalyzerError.sourceTexture(.textureCreationFailed)
		}

		return sourceTexture
	}

	func makeGrayScaleTexture(from sourceTexture: MTLTexture,
							  commandQueue: MTLCommandQueue,
							  device: MTLDevice) throws -> MTLTexture {
		guard let commandBuffer = commandQueue.makeCommandBuffer() else {
			throw FrameAnalyzerError.configuration(.commandBufferCreationFailure)
		}

		let conversionInfo = CGColorConversionInfo(src: CGColorSpaceCreateDeviceRGB(),
												   dst: CGColorSpaceCreateDeviceGray())
			 
		let grayScaleConversion = MPSImageConversion(device: device,
													 srcAlpha: .alphaIsOne,
													 destAlpha: .alphaIsOne,
													 backgroundColor: nil,
													 conversionInfo: conversionInfo)

		let grayScaleTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: .r16Unorm,
			width: sourceTexture.width,
			height: sourceTexture.height,
			mipmapped: false
		)
		grayScaleTextureDescriptor.usage = [
			.shaderWrite,
			.shaderRead,
		]

		guard let grayScaleTexture = device.makeTexture(descriptor: grayScaleTextureDescriptor) else {
			throw FrameAnalyzerError.grayScale(.textureCreationFailed)
		}

		grayScaleConversion.encode(commandBuffer: commandBuffer,
								   sourceTexture: sourceTexture,
								   destinationTexture: grayScaleTexture)

		commandBuffer.commit()
		commandBuffer.waitUntilCompleted()

		return grayScaleTexture
	}

	/// - Parameter sourceTexture: MTLTexture исходного изображения, переведенная в gray scale
	func getStandartDeviation(from sourceTexture: MTLTexture,
							  commandQueue: MTLCommandQueue,
							  device: MTLDevice) throws -> Double {
		guard let commandBuffer = commandQueue.makeCommandBuffer() else {
			throw FrameAnalyzerError.configuration(.commandBufferCreationFailure)
		}

		let laplacianKernel = MPSImageLaplacian(device: device)

		let laplacianTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: sourceTexture.pixelFormat,
			width: sourceTexture.width,
			height: sourceTexture.height,
			mipmapped: false
		)
		laplacianTextureDescriptor.usage = [
			.shaderWrite,
			.shaderRead,
		]

		guard let laplacianTexture = device.makeTexture(descriptor: laplacianTextureDescriptor) else {
			throw FrameAnalyzerError.standartDeviation(.laplacianTextureCreationFailed)
		}

		laplacianKernel.encode(commandBuffer: commandBuffer,
							   sourceTexture: sourceTexture,
							   destinationTexture: laplacianTexture)


		let meanAndVarianceKernel = MPSImageStatisticsMeanAndVariance(device: device)

		let varianceTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: .r32Float,
			width: 2,
			height: 1,
			mipmapped: false
		)
		varianceTextureDescriptor.usage = [
			.shaderWrite,
			.shaderRead,
		]

		guard let meanAndVarianceTexture = device.makeTexture(descriptor: varianceTextureDescriptor) else {
			throw FrameAnalyzerError.standartDeviation(.meanAndVarianceTextureCreationFailed)
		}

		meanAndVarianceKernel.encode(commandBuffer: commandBuffer,
									 sourceTexture: laplacianTexture,
									 destinationTexture: meanAndVarianceTexture)

		commandBuffer.commit()
		commandBuffer.waitUntilCompleted()

		var result = [Float](repeatElement(0, count: 2))
		let region = MTLRegionMake2D(0, 0, 2, 1)
		meanAndVarianceTexture.getBytes(&result, bytesPerRow: 1 * 2 * 4, from: region, mipmapLevel: 0)

		guard let variance = result.first else {
			throw FrameAnalyzerError.standartDeviation(.emptyResults)
		}

		let standartDeviation = sqrt(Double(variance)) * 255
		return standartDeviation
	}

	/// - Parameter sourceTexture: MTLTexture исходного изображения, переведенная в gray scale
	func getBrightness(from sourceTexture: MTLTexture,
					   commandQueue: MTLCommandQueue,
					   device: MTLDevice) throws -> Brightness {
		guard let defaultLibrary = device.makeDefaultLibrary() else {
			throw FrameAnalyzerError.brightness(.libraryCreationFailure)
		}

		guard
			let commandBuffer = commandQueue.makeCommandBuffer(),
			let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
		else {
			throw FrameAnalyzerError.brightness(.computeCommandEncoderCreationFailure)
		}

		var threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
		var thredGroupsPerGrid = MTLSizeMake(sourceTexture.width / threadsPerThreadgroup.width,
											 sourceTexture.height / threadsPerThreadgroup.height,
											 1);

		let functionName = "calculateBrightAndDarkPixelsCount"
		guard let function = defaultLibrary.makeFunction(name: functionName) else {
			throw FrameAnalyzerError.brightness(.functionCreationFailure(functionName: functionName))
		}
		guard let computePipelineState = try? device.makeComputePipelineState(function: function) else {
			throw FrameAnalyzerError.brightness(.computePipelineStateCreationFailure)
		}

		var darkPixelCounterBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size,
													   options: .storageModeShared)
		var brightPixelCounterBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size,
														 options: .storageModeShared)
		var brightAndDarkParameters = BrightAndDarkParameters(
			brightThreshold: Constants.brightPixelValueThreshold,
			darkThreshhold: Constants.darkPixelValueThreshold
		)
		var paramsBuffer = device.makeBuffer(
			bytes: &brightAndDarkParameters,
			length: MemoryLayout<BrightAndDarkParameters>.stride,
			options: .storageModeShared
		)

		computeCommandEncoder.setComputePipelineState(computePipelineState)
		computeCommandEncoder.setTexture(sourceTexture, index: 0)
		computeCommandEncoder.setBuffer(darkPixelCounterBuffer, offset: 0, index: 0)
		computeCommandEncoder.setBuffer(brightPixelCounterBuffer, offset: 0, index: 1)
		computeCommandEncoder.setBuffer(paramsBuffer, offset: 0, index: 2)
		computeCommandEncoder.dispatchThreadgroups(thredGroupsPerGrid,
												   threadsPerThreadgroup: threadsPerThreadgroup)
		computeCommandEncoder.endEncoding()

		commandBuffer.commit()
		commandBuffer.waitUntilCompleted()

		guard let darkPixelCount = darkPixelCounterBuffer.map(self.getResult) else {
			throw FrameAnalyzerError.brightness(.darkPixelResultEmpty)
		}

		guard let brightPixelCount = brightPixelCounterBuffer.map(self.getResult) else {
			throw FrameAnalyzerError.brightness(.brightPixelResultEmpty)
		}

		let totalPixelCount = Double(sourceTexture.width * sourceTexture.height)

		let darkPixelShare = Double(darkPixelCount) / totalPixelCount
		let brightPixelShare = Double(brightPixelCount) / totalPixelCount

		return Brightness(brightShare: brightPixelShare, darkShare: darkPixelShare)
	}
}

struct Brightness
{
	let brightShare: Double
	let darkShare: Double
}

enum BrightnessResult
{
	struct Params
	{
		let brightShare: Double
		let darkShare: Double

		var string: String {
			"bright: \(brightShare),\ndark: \(darkShare)"
		}
	}

	case success(Params)
	case tooBright(Params)
	case tooDark(Params)
	case failure(String)

	static let empty: BrightnessResult = .failure("Пусто")

	var resultString: String {
		switch self {
		case .success(let params):
			return ".success:\n\(params.string)"
		case .tooBright(let params):
			return ".tooBright:\n\(params.string)"
		case .tooDark(let params):
			return ".tooDark:\n\(params.string)"
		case .failure(let reason):
			return ".faulure with:\n\(reason)"
		}
	}
}

private extension FrameAnalyzer
{
	func getResult(from buffer: MTLBuffer) -> UInt32 {
		var data = NSData(bytesNoCopy: buffer.contents(),
						  length: MemoryLayout<UInt32>.size,
						  freeWhenDone: false)
		// b. prepare Swift array large enough to receive data from GPU
		var resultArray = [UInt32](repeating: 0, count: 1)

		// c. get data from GPU into Swift array
		data.getBytes(&resultArray, length: MemoryLayout<UInt>.size)

		if resultArray.first == nil { print("массив пустой") }
		return resultArray.first ?? 0
	}
}

struct BrightAndDarkParameters
{
	let brightThreshold: Float
	let darkThreshhold: Float
}
