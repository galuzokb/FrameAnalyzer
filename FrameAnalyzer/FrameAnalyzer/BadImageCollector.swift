//
//  BadImageCollector.swift
//  asd
//
//  Created by Kirill Galuzo on 15.09.2022.
//

import Foundation

final class BadImageCollector
{
	private enum Constants
	{
		static let maxCount = 20
	}

	private var semaphore = DispatchSemaphore(value: 1)

	private var badImages: [BadImage] = []

	func addBadImage(_ badImage: BadImage) {
		self.semaphore.wait(); defer { self.semaphore.signal() }
		if self.badImages.count > (Constants.maxCount - 1) {
			self.badImages.removeFirst()
		}
		self.badImages.append(badImage)
	}

	func getBadImages() -> [BadImage] {
		self.semaphore.wait(); defer { self.semaphore.signal() }
		return self.badImages
	}

	func reset() {
		self.semaphore.wait(); defer { self.semaphore.signal() }
		self.badImages = []
	}
}
