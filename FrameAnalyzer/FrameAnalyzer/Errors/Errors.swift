//
//  Errors.swift
//  asd
//
//  Created by Kirill Galuzo on 22.09.2022.
//

import Foundation

enum FrameAnalyzerConfigurationError: Error
{
	case commandBufferCreationFailure
}

enum GrayScaleTextureError: Error
{
	case textureCreationFailed
}

enum SourceTextureError: Error
{
	case textureCreationFailed
}

enum StandartDeviationError: Error
{
	case laplacianTextureCreationFailed
	case meanAndVarianceTextureCreationFailed
	case emptyResults
}

enum BrightnessError: Error
{
	case libraryCreationFailure
	case computeCommandEncoderCreationFailure
	case functionCreationFailure(functionName: String)
	case computePipelineStateCreationFailure
	case brightPixelResultEmpty
	case darkPixelResultEmpty
}

enum FrameAnalyzerError: Error
{
	case configuration(FrameAnalyzerConfigurationError)
	case sourceTexture(SourceTextureError)
	case grayScale(GrayScaleTextureError)
	case standartDeviation(StandartDeviationError)
	case brightness(BrightnessError)
}
