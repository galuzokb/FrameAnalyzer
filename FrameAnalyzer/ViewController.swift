//
//  ViewController.swift
//  asd
//
//  Created by Kirill Galuzo on 21.03.2022.
//

import UIKit
import AVFoundation

final class View: UIView
{
	struct LabelConfig
	{
		let text: String
		let textColor: UIColor
	}

	private lazy var label: UILabel = {
		let label = UILabel()
		label.numberOfLines = 0
		label.textAlignment = .center
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	private lazy var button: UIButton = {
		let button = UIButton()
		button.translatesAutoresizingMaskIntoConstraints = false
		button.addTarget(self, action: #selector(onTouchUpInside(_:)), for: .touchUpInside)
		return button
	}()

	var buttonTapHandler: (() -> Void)?

	init() {
		super.init(frame: .zero)

		self.addSubview(self.label)
		self.label.pin(to: self,
					   constant: 35,
					   attribute: .top,
					   secondViewAttribute: .top)
		self.label.pin(to: self,
					   constant: 40,
					   attribute: .left,
					   secondViewAttribute: .left)
		self.label.pin(to: self,
					   constant: -40,
					   attribute: .right,
					   secondViewAttribute: .right)
		self.addSubview(self.button)
		self.button.pin(to: self,
						attribute: .centerX,
						secondViewAttribute: .centerX)
		self.button.pin(to: self,
						constant: -40,
						attribute: .bottom,
						secondViewAttribute: .bottom)
		self.button.heightAnchor.constraint(equalToConstant: 40).isActive = true
		self.button.widthAnchor.constraint(equalToConstant: 250).isActive = true
		self.backgroundColor = .lightGray
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func set(labelConfig: LabelConfig) {
		self.label.text = labelConfig.text
		self.label.textColor = labelConfig.textColor
	}

	func set(previewLayer: CALayer) {
		self.layer.insertSublayer(previewLayer, at: 0)
		previewLayer.frame = self.layer.frame
	}

	func updateButton(text: String) {
		self.button.setTitle(text, for: .normal)
	}

	func set(attributedString: NSAttributedString) {
		self.label.attributedText = attributedString
	}

	@objc
	private func onTouchUpInside(_ sender: UIButton) {
		self.buttonTapHandler?()
	}
}

final class ViewController: UIViewController
{
	// MARK: - BlurDetector

	private let frameAnalyzer: FrameAnalyzerType

	// MARK: - Capture

	private let captureSession = AVCaptureSession()
	private let captureVideoDataOutput = AVCaptureVideoDataOutput()
	
	// MARK: - Views

	private let mainView = View()

	private var isAnalyzing = false

	override func loadView() {
		self.view = self.mainView
	}

	init(frameAnalyzer: FrameAnalyzerType) {
		self.frameAnalyzer = frameAnalyzer

		super.init(nibName: nil, bundle: nil)

		frameAnalyzer.configure { [weak self] result in
			self?.showResult(result)
		}
	}

	
	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		self.mainView.set(labelConfig: .init(text: "DidLoad", textColor: .green))
		self.mainView.updateButton(text: "Старт")
		self.mainView.buttonTapHandler = { [weak self] in
			self?.onButtonTap()
		}

		self.checkCameraPermissionAndRequestIfNeeded { [weak self] result in
			guard let self = self else { return }
			switch result {
			case .success:
				self.showMessage("Доступ есть")
				self.configureSession()
			case .failure:
				self.showError("Нужен доступ к камере")
			}
		}
	}
}

// MARK: - Tap Handling

private extension ViewController
{
	func onButtonTap() {
		if self.isAnalyzing {
			self.mainView.updateButton(text: "Старт")
			self.isAnalyzing = false
			self.captureVideoDataOutput.setSampleBufferDelegate(nil, queue: nil)
			self.frameAnalyzer.stopAnalyzing { [weak self] overralResult in
				switch overralResult {
				case .someFramesAreBad(let array):
					self?.showAlert(
						with: "Количество \"плохих\" кадров: \(array.count)",
						okHandler: { self?.showBadImages(array) }
					)
				case .thisIsFine:
					self?.showAlert(
						with: "Все кадры прошли валидацию",
						okHandler: { }
					)
				}
			}
		}
		else {
			self.mainView.updateButton(text: "Стоп")
			self.isAnalyzing = true
			self.frameAnalyzer.startAnalyzing()
			let captureVideoQueue = DispatchQueue(label: "output_queue")
			self.captureVideoDataOutput.setSampleBufferDelegate(self.frameAnalyzer, queue: captureVideoQueue)
		}
	}
}

// MARK: - Bad Images

private extension ViewController
{
	func showBadImages(_ badImages: [BadImage]) {
		let badImagesVC = BadImagesViewController(badImages: badImages)
		self.navigationController?.pushViewController(badImagesVC, animated: true)
	}
}

// MARK: - Messages

private extension ViewController
{
	func showResult(_ result: NSAttributedString) {
		self.mainView.set(attributedString: result)
	}

	func showMessage(_ message: String) {
		self.mainView.set(labelConfig: .init(text: message, textColor: .green))
	}

	func showError(_ error: String) {
		self.mainView.set(labelConfig: .init(text: error, textColor: .red))
	}
}

// MARK: - Premissions

private extension ViewController
{
	enum PermissionResult
	{
		case success
		case failure
	}

	func checkCameraPermissionAndRequestIfNeeded(_ completion: @escaping (PermissionResult) -> Void) {
		switch AVCaptureDevice.authorizationStatus(for: .video) {
		case .authorized:
			completion(.success)
		case .notDetermined:
			AVCaptureDevice.requestAccess(for: .video) { granted in
				completion(granted ? .success : .failure)
			}
		default:
			completion(.failure)
		}
	}
}

// MARK: - Session Configuration

private extension ViewController
{
	enum SessionConfigurationResult
	{
		case success
		case failure(reason: String)
	}

	func configureSession() {
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			guard let self = self else { return }

			self.captureSession.beginConfiguration()

			self.captureSession.sessionPreset = .hd1920x1080

			// setup inputs
			guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
				self.showError("Не получилось создать device")
				return
			}

			defer { device.unlockForConfiguration() }

			guard let _ = try? device.lockForConfiguration(),
				  let deviceInput = try? AVCaptureDeviceInput(device: device),
				  self.captureSession.canAddInput(deviceInput) else {
				self.showError("Не удалось добавить инпут в сессию")
				return
			}
			self.captureSession.addInput(deviceInput)
			device.isSubjectAreaChangeMonitoringEnabled = true
				
			guard self.captureSession.canAddOutput(self.captureVideoDataOutput) else {
				self.showError("Не удалось добавить аутпут в сессию")
				return
			}
			self.captureSession.addOutput(self.captureVideoDataOutput)

			DispatchQueue.main.async { [weak self] in
				self?.setupPreviewLayer()
			}

			self.captureSession.commitConfiguration()
		
			self.captureSession.startRunning()
		}
	}

	func setupPreviewLayer() {
		let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
		layer.videoGravity = .resizeAspect
		self.mainView.set(previewLayer: layer)
	}
}

// MARK: - Alert

private extension ViewController
{
	func showAlert(with message: String,
				   okHandler: @escaping () -> Void,
				   cancelHandler: (() -> Void)? = nil) {
		let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in okHandler() }))
		alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in cancelHandler?() }))
		self.present(alertController, animated: true, completion: nil)
	}
}
