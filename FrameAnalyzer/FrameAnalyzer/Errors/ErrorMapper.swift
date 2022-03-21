//
//  ErrorMapper.swift
//  asd
//
//  Created by Kirill Galuzo on 22.09.2022.
//

import Foundation

final class ErrorMapper
{
	func map(error: Error) -> String {
		(error as? FrameAnalyzerError).map { self.map(frameAnalyzerError: $0) } ?? error.localizedDescription
	}
}

private extension ErrorMapper
{
	func map(frameAnalyzerError error: FrameAnalyzerError) -> String {
		switch error {
		case .configuration(let configurationError):
			return self.map(configurationError: configurationError)
		case .sourceTexture(let sourceTexureError):
			return self.map(sourceTexureError: sourceTexureError)
		case .grayScale(let grayScaleError):
			return self.map(grayScaleError: grayScaleError)
		case .standartDeviation(let stanartDeviationError):
			return self.map(stanartDeviationError: stanartDeviationError)
		case .brightness(let brightnessError):
			return self.map(brightnessError: brightnessError)
		}
	}

	func map(configurationError error: FrameAnalyzerConfigurationError) -> String {
		switch error {
		case .commandBufferCreationFailure:
			return "Не удалось создать MTLCommandBuffer"
		}
	}

	func map(sourceTexureError error: SourceTextureError) -> String {
		switch error {
		case .textureCreationFailed:
			return "Не удалось создать MTLTexture из исходного изображения"
		}
	}

	func map(grayScaleError error: GrayScaleTextureError) -> String {
		switch error {
		case .textureCreationFailed:
			return "Не удалось создать MTLTexture для перевода в grayscale"
		}
	}

	func map(stanartDeviationError error: StandartDeviationError) -> String {
		switch error {
		case .laplacianTextureCreationFailed:
			return "Не удалось создать MTLTexture для применения фильра Лапласиана"
		case .meanAndVarianceTextureCreationFailed:
			return "Не удалось создать MTLTexture для вычисления mean and variance"
		case .emptyResults:
			return "Результаты вычисления mean and variance пусты"
		}
	}

	func map(brightnessError error: BrightnessError) -> String {
		switch error {
		case .libraryCreationFailure:
			return "Не удалось создать MTLLibrary"
		case .computeCommandEncoderCreationFailure:
			return "Не удалось создать MTLComputeCommandEncoder"
		case .functionCreationFailure(let functionName):
			return "Не удалось создать функцию \(functionName)"
		case .computePipelineStateCreationFailure:
			return "Не удалось создать MTLComputePipleneState"
		case .brightPixelResultEmpty:
			return "MTLBuffer для brightPixel пуст"
		case .darkPixelResultEmpty:
			return "MTLBuffer для darkPixel пуст"
		}
	}
}
