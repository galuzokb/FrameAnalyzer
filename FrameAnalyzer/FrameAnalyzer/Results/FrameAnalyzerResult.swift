//
//  FrameAnalyzerResult.swift
//  asd
//
//  Created by Kirill Galuzo on 14.09.2022.
//

import Foundation
import UIKit

struct FrameAnalyzerResult
{
	var standartDeviation: FrameAnalyzerResultType?
	var darkPixel: FrameAnalyzerResultType?
	var brightPixel: FrameAnalyzerResultType?
	var error: Error?
	var string: NSAttributedString

	init() {
		self.standartDeviation = nil
		self.darkPixel = nil
		self.brightPixel = nil
		self.error = nil
		self.string = NSAttributedString()
	}
}

enum FrameAnalyzerResultType
{
	case good(value: Double)
	case bad(value: Double, image: CGImage)

	var value: Double {
		switch self {
		case .good(let value), .bad(let value, _): return value
		}
	}

	var image: CGImage? {
		switch self {
		case .good: 				return nil
		case .bad(_, let image): 	return image
		}
	}
}

final class FrameAnalyzerResultBuilder
{
	struct Thresholds
	{
		let standartDeviation: Double
		let darkPixelShare: Double
		let brightPixelShare: Double
	}

	private struct Result
	{
		let string: String
		let type: FrameAnalyzerResultType
	}

	private let errorMapper: ErrorMapper

	private var standartDeviation: Double?
	private var brightness: Brightness?
	private var error: Error?

	init(errorMapper: ErrorMapper) {
		self.errorMapper = errorMapper
	}

	func set(standartDeviation: Double) {
		self.standartDeviation = standartDeviation
	}

	func set(brightness: Brightness) {
		self.brightness = brightness
	}

	func set(error: Error) {
		self.error = error
	}

	func build(thresholds: Thresholds, image: CGImage) -> FrameAnalyzerResult {
		var output = FrameAnalyzerResult()
		let outputString = NSMutableAttributedString()
		if let standartDeviation = self.standartDeviation {
			let standartDeviationResult = self.makeStandartDeviationResult(
				std: standartDeviation,
				threshold: thresholds.standartDeviation,
				image: image
			)
			let standartDeviationString = self.makeAttributedString(for: standartDeviationResult)
			outputString.append(standartDeviationString)
			output.standartDeviation = standartDeviationResult.type
		}

		if let brightness = self.brightness {
			let darkPixelResult = self.makeDarkPixelResult(
				darkPixelShare: brightness.darkShare,
				threshold: thresholds.darkPixelShare,
				image: image
			)
			let darkPixelString = self.makeAttributedString(for: darkPixelResult)

			let brightPixelResult = self.makeBrightPixelResult(
				brightPixelShare: brightness.brightShare,
				threshold: thresholds.brightPixelShare,
				image: image
			)
			let brightPixelString = self.makeAttributedString(for: brightPixelResult)

			if outputString.isEmpty == false {
				outputString.append(.newLine)
			}

			outputString.append(darkPixelString)
			outputString.append(.newLine)
			outputString.append(brightPixelString)

			output.darkPixel = darkPixelResult.type
			output.brightPixel = brightPixelResult.type
		}

		if let error = self.error {
			if outputString.isEmpty == false {
				outputString.append(.newLine)
			}

			let errorString = self.makeAttributedString(for: error)
			outputString.append(errorString)

			output.error = error
		}

		output.string = outputString

		return output
	}
}


// MARK: - Results

private extension FrameAnalyzerResultBuilder
{
	private func makeStandartDeviationResult(std: Double,
											 threshold: Double,
											 image: CGImage) -> Result {
		Result(
			string: "STD: \(String(format: "%.2f", std))",
			type: std > threshold
				? .good(value: std)
				: .bad(value: std, image: image)
		)
	}

	private func makeDarkPixelResult(darkPixelShare: Double,
									 threshold: Double,
									 image: CGImage) -> Result {
		let percent = darkPixelShare * 100
		return Result(
			string: "Dark Pixels: \(String(format: "%.2f", percent))",
			type: darkPixelShare < threshold
				? .good(value: percent)
				: .bad(value: percent, image: image)
		)
	}

	private func makeBrightPixelResult(brightPixelShare: Double,
									   threshold: Double,
									   image: CGImage) -> Result {
		let percent = brightPixelShare * 100
		return Result(
			string: "Bright Pixels: \(String(format: "%.2f", percent))",
			type: brightPixelShare < threshold
				? .good(value: percent)
				: .bad(value: percent, image: image)
		)
	}
}

// MARK: - Attributed String

private extension FrameAnalyzerResultBuilder
{
	private func makeAttributedString(for result: Result) -> NSAttributedString {
		NSAttributedString(
			string: result.string,
			attributes: [
				NSAttributedString.Key.foregroundColor: result.type.color,
			]
		)
	}

	private func makeAttributedString(for error: Error) -> NSAttributedString {
		NSAttributedString(
			string: self.errorMapper.map(error: error),
			attributes: [
				NSAttributedString.Key.foregroundColor: UIColor.orange,
			]
		)
	}
}

private extension NSAttributedString
{
	static var newLine: NSAttributedString {
		NSAttributedString(string: "\n")
	}
}

private extension NSMutableAttributedString
{
	var isEmpty: Bool {
		self.length == 0
	}
}

private extension FrameAnalyzerResultType
{
	var color: UIColor {
		switch self {
		case .good: 	return .green
		case .bad: 		return .red
		}
	}
}
