//
//  BadImageCell.swift
//  asd
//
//  Created by Kirill Galuzo on 15.09.2022.
//

import UIKit

final class BadImageCell: UITableViewCell
{
	static let reuseId = "badImageCell"

	var badImage: BadImageEntity? {
		didSet {
			self.setup()
		}
	}

	private lazy var badImageView: UIImageView = {
		let imageView = UIImageView()
		imageView.contentMode = .scaleAspectFit
		imageView.clipsToBounds = true
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.backgroundColor = .lightGray
		return imageView
	}()

	private lazy var stdLabel: UILabel = {
		let label = UILabel()
		label.numberOfLines = 0
		label.textAlignment = .center
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		self.configure()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

private extension BadImageCell
{
	func configure() {
		self.addSubview(self.stdLabel)
		self.stdLabel.pin(to: self,
						  attribute: .left,
						  secondViewAttribute: .left)
		self.stdLabel.pin(to: self,
						  attribute: .top,
						  secondViewAttribute: .top)
		self.stdLabel.pin(to: self,
						  attribute: .right,
						  secondViewAttribute: .right)
		self.addSubview(self.badImageView)
		self.badImageView.pin(to: self,
							  attribute: .bottom,
							  secondViewAttribute: .bottom)
		self.badImageView.pin(to: self.stdLabel,
							  attribute: .top,
							  secondViewAttribute: .bottom)
		self.badImageView.heightAnchor.constraint(equalToConstant: 300).isActive = true
		self.badImageView.widthAnchor.constraint(equalToConstant: 300).isActive = true
		self.badImageView.pin(to: self,
							  attribute: .centerX,
							  secondViewAttribute: .centerX)
	}

	func setup() {
		if let badImage = self.badImage {
			self.badImageView.image = badImage.image
			self.stdLabel.text = badImage.text
		}
		else {
			self.badImageView.image = nil
			self.stdLabel.text = nil
		}
	}
}
