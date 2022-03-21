//
//  BadImagesViewController.swift
//  asd
//
//  Created by Kirill Galuzo on 15.09.2022.
//

import Foundation
import UIKit

final class BadImagesViewController: UIViewController
{
	private lazy var activityIndicator: UIActivityIndicatorView = {
		let indicator = UIActivityIndicatorView(style: .large)
		indicator.hidesWhenStopped = true
		indicator.translatesAutoresizingMaskIntoConstraints = false
		return indicator
	}()
	private lazy var tableView: UITableView = {
		let tableView = UITableView()
		tableView.translatesAutoresizingMaskIntoConstraints = false
		return tableView
	}()

	private var tableViewManager: BadImageTableViewManager!

	private let badImages: [BadImage]

	init(badImages: [BadImage]) {
		self.badImages = badImages
		super.init(nibName: nil, bundle: nil)

		self.view.addSubview(self.tableView)
		self.tableView.pin(to: self.view,
						   attribute: .top,
						   secondViewAttribute: .top)
		self.tableView.pin(to: self.view,
						   attribute: .right,
						   secondViewAttribute: .right)
		self.tableView.pin(to: self.view,
						   attribute: .bottom,
						   secondViewAttribute: .bottom)
		self.tableView.pin(to: self.view,
						   attribute: .left,
						   secondViewAttribute: .left)
		self.view.addSubview(self.activityIndicator)
		self.activityIndicator.pin(to: self.view,
								   attribute: .centerX,
								   secondViewAttribute: .centerX)
		self.activityIndicator.pin(to: self.view,
								   attribute: .centerY,
								   secondViewAttribute: .centerY)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		self.tableViewManager = BadImageTableViewManager(tableView: self.tableView)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		self.activityIndicator.startAnimating()
		self.makeEntities { [weak self] entities in
			guard let self = self else { return }
			self.activityIndicator.stopAnimating()
			self.tableViewManager.set(badImages: entities)
		}
	}
}

private extension BadImagesViewController
{
	func makeEntities(_ completion: @escaping ([BadImageEntity]) -> Void) {
		self.activityIndicator.startAnimating()
		DispatchQueue.global(qos: .utility).async { [weak self] in
			guard let self = self else { return }
			let badImageEntities = self.badImages
				.map { badImage in
					BadImageEntity(image: UIImage(cgImage: badImage.image),
								   text: badImage.reason)
				
				}
			DispatchQueue.main.async {
				completion(badImageEntities)
			}
		}
	}
}
