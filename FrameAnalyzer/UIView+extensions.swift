//
//  UIView+extensions.swift
//  asd
//
//  Created by Kirill Galuzo on 13.09.2022.
//

import UIKit

extension UIView
{
	@discardableResult
	func pin(to secondView: UIView,
			 constant: CGFloat = 0,
			 attribute: NSLayoutConstraint.Attribute,
			 secondViewAttribute: NSLayoutConstraint.Attribute) -> NSLayoutConstraint {
		let constraint = NSLayoutConstraint(item: self,
											attribute: attribute,
											relatedBy: .equal,
											toItem: secondView,
											attribute: secondViewAttribute,
											multiplier: 1.0,
											constant: constant)
		constraint.isActive = true
		return constraint
	}
}
