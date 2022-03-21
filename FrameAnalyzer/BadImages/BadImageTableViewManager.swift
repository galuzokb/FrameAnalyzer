//
//  BadImageTableViewManager.swift
//  asd
//
//  Created by Kirill Galuzo on 15.09.2022.
//

import UIKit

final class BadImageTableViewManager: NSObject
{
	private let tableView: UITableView

	private var badImages = [BadImageEntity]()

	init(tableView: UITableView) {
		self.tableView = tableView
		super.init()
		self.configure()
	}

	func set(badImages: [BadImageEntity]) {
		self.badImages = badImages
		self.tableView.reloadData()
	}
}

extension BadImageTableViewManager: UITableViewDelegate { }

extension BadImageTableViewManager: UITableViewDataSource
{
	func numberOfSections(in tableView: UITableView) -> Int {
		return self.badImages.isEmpty ? 0 : 1
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		self.badImages.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let cell = tableView.dequeueReusableCell(withIdentifier: BadImageCell.reuseId) as? BadImageCell else {
			fatalError("не та ячейка")
		}

		let imageCount = self.badImages.count
		if indexPath.row < imageCount {
			cell.badImage = badImages[indexPath.row]
		}
		else {
			print("Чет не сошлось IP: \(indexPath.row) images: \(imageCount)")
		}

		return cell
	}
}

// MARK: - Configuration

private extension BadImageTableViewManager
{
	func configure() {
		self.tableView.rowHeight = UITableView.automaticDimension
		self.tableView.dataSource = self
		self.tableView.delegate = self
		self.tableView.register(BadImageCell.self, forCellReuseIdentifier: BadImageCell.reuseId)
		self.tableView.tableFooterView = UIView()
	}
}
