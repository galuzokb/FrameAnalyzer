//
//  FrameCounter.swift
//  asd
//
//  Created by Kirill Galuzo on 14.09.2022.
//

import Foundation

final class FrameProcessInfo
{
	private let processStartedAt: Date
	private var processFinishedAt: Date?

	init(processStartedAt: Date) {
		self.processStartedAt = processStartedAt
	}

	var processTime: Double? {
		self.processFinishedAt.map { $0 - self.processStartedAt }
	}

	func finished(at date: Date) {
		self.processFinishedAt = date
	}
}

private extension Date
{
	static func - (lhs: Date, rhs: Date) -> TimeInterval {
		return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
	}
}

final class FrameCounter
{
	private var semaphore = DispatchSemaphore(value: 1)

	private var totalFrameCount: Int = 0

	private var processedFrameInfo: [UUID: FrameProcessInfo] = [:]

	func frameReceived() {
		self.semaphore.wait(); defer { self.semaphore.signal() }
		self.totalFrameCount += 1
	}

	func frameStartedHandling(id: UUID) {
		self.semaphore.wait(); defer { self.semaphore.signal() }
		self.processedFrameInfo[id] = FrameProcessInfo(processStartedAt: Date())
	}

	func frameFinishedHandling(id: UUID) {
		self.semaphore.wait(); defer { self.semaphore.signal() }
		self.processedFrameInfo[id]?.finished(at: Date())
	}

	func getTotalInfoAsString() -> String {
		self.semaphore.wait(); defer { self.semaphore.signal() }
		let processTimes = self.processedFrameInfo.compactMap { (key: UUID, value: FrameProcessInfo) in
			value.processTime
		}
		let handeledFramesCount = processTimes.count
		let totalProcessTime = processTimes.reduce(into: 0.0) { partialResult, processTime in
			partialResult += processTime
		}
		let meanProcessTime = totalProcessTime / Double(handeledFramesCount)
		return "Обработано \(handeledFramesCount) / \(self.totalFrameCount).\nСреднее время: \(meanProcessTime) сек"
	}

	func reset() {
		self.semaphore.wait(); defer { self.semaphore.signal() }
		self.totalFrameCount = 0
		self.processedFrameInfo = [:]
	}
}
