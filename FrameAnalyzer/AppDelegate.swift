//
//  AppDelegate.swift
//  asd
//
//  Created by Kirill Galuzo on 21.03.2022.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		// Override point for customization after application launch.
		window = UIWindow(frame: UIScreen.main.bounds)
		window?.makeKeyAndVisible()
		window?.backgroundColor = .systemBackground
		let nc = UINavigationController(rootViewController: ViewController(frameAnalyzer: FrameAnalyzer()))
		window?.rootViewController = nc
		return true
	}

}

