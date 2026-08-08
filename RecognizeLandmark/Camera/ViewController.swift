//
//  ViewController.swift
//  RecognizeLandmark
//
//  Created by RecognizeLandmark contributors on 2024/9/27.
//

import AVFoundation
import UIKit
import Vision
import SwiftData
import SwiftUI
import CoreLocation
import PhotosUI

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!

    private let videoQueue = DispatchQueue(label: "videoQueue")
    private var lastClassifyTime: TimeInterval = 0
    private let classifyInterval: TimeInterval = 0.5

    private let locationProvider = LocationProvider()
    private let authStatusManager = CLLocationManager()
    private var captureStartedAt: Date?
    private var isProcessing = false

    // 給拍照按鈕用的最新 frame,videoQueue 與 main 都會碰到,需要鎖
    private var latestPixelBuffer: CVPixelBuffer?
    private let stateLock = NSLock()

    // MARK: - Sketched UI 元件(Stage 6a)

    private lazy var recordsCountChip: SketchedCapsuleView = {
        let v = SketchedCapsuleView(seed: 42)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isUserInteractionEnabled = true
        v.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                     action: #selector(recordsChipTapped)))
        return v
    }()

    private lazy var reticleView: SketchedReticleView = {
        let v = SketchedReticleView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var recognitionBubble: SketchedBubbleView = {
        let v = SketchedBubbleView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.setText("(對準景點看看)")
        return v
    }()

    private lazy var gpsChip: SketchedCapsuleView = {
        let v = SketchedCapsuleView(seed: 99)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isUserInteractionEnabled = true
        v.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                     action: #selector(gpsChipTapped)))
        return v
    }()

    private lazy var captureButton: SketchedShutterView = {
        let b = SketchedShutterView()
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        return b
    }()

    private lazy var importButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "相簿"
        configuration.image = UIImage(systemName: "photo.on.rectangle")
        configuration.imagePadding = 6
        configuration.baseBackgroundColor = Sketch.paper.withAlphaComponent(0.95)
        configuration.baseForegroundColor = Sketch.ink
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(importPhotoTapped), for: .touchUpInside)
        return button
    }()

    private lazy var toastLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = Sketch.ink
        label.backgroundColor = Sketch.paper.withAlphaComponent(0.95)
        label.font = Sketch.font(size: 14)
        label.layer.cornerRadius = 10
        label.layer.borderColor = Sketch.ink.cgColor
        label.layer.borderWidth = 1.5
        label.layer.masksToBounds = true
        label.numberOfLines = 0
        label.alpha = 0
        return label
    }()

    private lazy var processingView: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 16
        blur.clipsToBounds = true
        blur.alpha = 0
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        let label = UILabel()
        label.text = "正在辨識地點…"
        label.font = Sketch.font(size: 16)
        label.textColor = Sketch.ink
        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 10
        blur.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -14),
        ])
        return blur
    }()

    private lazy var cameraPermissionPanel: UIStackView = {
        let title = UILabel()
        title.text = "需要相機權限"
        title.font = Sketch.font(size: 20, wide: true)
        title.textColor = Sketch.ink
        title.textAlignment = .center
        let detail = UILabel()
        detail.text = "開啟相機權限才能拍攝地標，或改用右下角的相簿匯入。"
        detail.font = .preferredFont(forTextStyle: .subheadline)
        detail.textColor = Sketch.ink
        detail.textAlignment = .center
        detail.numberOfLines = 0
        let button = UIButton(type: .system)
        button.setTitle("前往設定", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.addTarget(self, action: #selector(openAppSettings), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [title, detail, button])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 16, right: 20)
        stack.backgroundColor = Sketch.paper.withAlphaComponent(0.96)
        stack.layer.cornerRadius = 18
        stack.isHidden = true
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupOverlay()
        refreshRecordsCount()
        refreshGPSChip()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
        prepareCamera()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshRecordsCount()
        refreshGPSChip()
        if captureSession == nil {
            prepareCamera()
        } else if !isProcessing {
            startSessionIfPossible()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if presentedViewController == nil { stopSessionIfNeeded() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupOverlay() {
        view.addSubview(reticleView)
        view.addSubview(recognitionBubble)
        view.addSubview(recordsCountChip)
        view.addSubview(gpsChip)
        view.addSubview(captureButton)
        view.addSubview(importButton)
        view.addSubview(toastLabel)
        view.addSubview(processingView)
        view.addSubview(cameraPermissionPanel)

        NSLayoutConstraint.activate([
            // 中央 reticle(略偏上)
            reticleView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            reticleView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            reticleView.widthAnchor.constraint(equalToConstant: 200),
            reticleView.heightAnchor.constraint(equalToConstant: 200),

            // 辨識結果膠囊在 reticle 下方
            recognitionBubble.topAnchor.constraint(equalTo: reticleView.bottomAnchor, constant: 28),
            recognitionBubble.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recognitionBubble.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.78),
            recognitionBubble.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),

            // 記錄數 chip 右上
            recordsCountChip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            recordsCountChip.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),

            // GPS chip 左下、在快門上方
            gpsChip.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            gpsChip.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -8),

            // 快門按鈕
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            captureButton.widthAnchor.constraint(equalToConstant: 88),
            captureButton.heightAnchor.constraint(equalToConstant: 88),

            importButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            importButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),

            // toast(沿用、改為 sketch 樣式)
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: gpsChip.topAnchor, constant: -10),
            toastLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.85),
            toastLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),

            processingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            processingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            cameraPermissionPanel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cameraPermissionPanel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cameraPermissionPanel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.82),
        ])
    }

    private func prepareCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCameraIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.configureCameraIfNeeded() : self?.showCameraPermissionPanel()
                }
            }
        case .denied, .restricted:
            showCameraPermissionPanel()
        @unknown default:
            showCameraPermissionPanel()
        }
    }

    private func configureCameraIfNeeded() {
        guard captureSession == nil else { startSessionIfPossible(); return }
        guard let backCamera = AVCaptureDevice.default(for: .video) else {
            showToast("找不到可用的後置相機，仍可從相簿匯入")
            return
        }
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            guard session.canAddInput(input) else { throw CameraSetupError.cannotAddInput }
            session.addInput(input)
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            guard session.canAddOutput(videoOutput) else { throw CameraSetupError.cannotAddOutput }
            session.addOutput(videoOutput)
            captureSession = session
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.layer.bounds
            view.layer.insertSublayer(previewLayer, at: 0)
            cameraPermissionPanel.isHidden = true
            captureButton.isEnabled = true
            startSessionIfPossible()
        } catch {
            showToast("相機啟動失敗，仍可從相簿匯入")
            print("Camera setup failed: \(error)")
        }
    }

    private func showCameraPermissionPanel() {
        cameraPermissionPanel.isHidden = false
        captureButton.isEnabled = false
    }

    @objc private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @objc private func appDidBecomeActive() {
        refreshGPSChip()
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            configureCameraIfNeeded()
        } else {
            showCameraPermissionPanel()
        }
    }

    private func startSessionIfPossible() {
        guard let session = captureSession, !session.isRunning, !isProcessing else { return }
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    private func stopSessionIfNeeded() {
        guard let session = captureSession, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
    }

    @discardableResult
    private func beginProcessing() -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        captureButton.isEnabled = false
        importButton.isEnabled = false
        UIView.animate(withDuration: 0.2) { self.processingView.alpha = 1 }
        return true
    }

    private func endProcessing(resumeCamera: Bool = true) {
        isProcessing = false
        importButton.isEnabled = true
        captureButton.isEnabled = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        UIView.animate(withDuration: 0.2) { self.processingView.alpha = 0 }
        if resumeCamera { startSessionIfPossible() }
    }

    // MARK: - Sketched UI 狀態同步

    private func refreshRecordsCount() {
        let context = Persistence.container.mainContext
        let descriptor = FetchDescriptor<LandmarkRecord>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        let text = count == 0 ? "還沒記錄 ✏️" : "已記錄 \(count) 個 📚"
        recordsCountChip.setText(text)
    }

    private func refreshGPSChip() {
        let text: String
        switch authStatusManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            text = "📍 已定位"
        case .denied, .restricted:
            text = "🚫 無位置權限"
        default:
            text = "📍 尚未授權"
        }
        gpsChip.setText(text)
    }

    @objc private func recordsChipTapped() {
        tabBarController?.selectedIndex = 1
    }

    @objc private func gpsChipTapped() {
        switch authStatusManager.authorizationStatus {
        case .denied, .restricted:
            openAppSettings()
        case .notDetermined:
            showToast("拍照時會詢問位置權限；拒絕後仍可手動選位置")
        case .authorizedAlways, .authorizedWhenInUse:
            showToast("只在拍照當下取得一次位置")
        @unknown default:
            break
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        stateLock.lock()
        latestPixelBuffer = pixelBuffer
        stateLock.unlock()

        let now = CACurrentMediaTime()
        guard now - lastClassifyTime >= classifyInterval else { return }
        lastClassifyTime = now

        let request = VNClassifyImageRequest { [weak self] request, _ in
            guard let self,
                  let results = request.results as? [VNClassificationObservation] else { return }

            let filtered = results.filter { $0.confidence >= 0.2 }
            let top = filtered
                .prefix(3)
                .map { String(format: "%@  %.0f%%", $0.identifier, $0.confidence * 100) }
                .joined(separator: "\n")

            DispatchQueue.main.async {
                self.recognitionBubble.setText(top.isEmpty ? "(對準景點看看)" : top)
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .right,
                                            options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Vision request failed: \(error)")
        }
    }

    @objc private func captureTapped() {
        guard beginProcessing() else { return }
        stateLock.lock()
        let pixelBuffer = latestPixelBuffer
        stateLock.unlock()

        guard let pixelBuffer else {
            endProcessing()
            showToast("尚未取得畫面,請稍候")
            return
        }
        guard let image = makeUIImage(from: pixelBuffer) else {
            endProcessing()
            showToast("照片擷取失敗")
            return
        }
        captureStartedAt = Date()

        // 暫停 capture session,避免 review 期間背景繼續跑 Vision
        let session = captureSession!
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let location = await self.locationProvider.currentLocation()
            let candidates = await CaptureFlow.run(image: image, location: location)
            CaptureDiagnostics.recordCandidateResult(count: candidates.count)
            self.presentReview(image: image,
                               candidates: candidates,
                               location: location,
                               capturedAt: Date())
        }
    }

    @objc private func importPhotoTapped() {
        guard !isProcessing, presentedViewController == nil else { return }
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func processImportedPhoto(_ photo: ImportedPhoto) async {
        captureStartedAt = Date()
        if let session = captureSession {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    session.stopRunning()
                    continuation.resume()
                }
            }
        }
        let candidates = await CaptureFlow.run(image: photo.image, location: photo.location)
        CaptureDiagnostics.recordCandidateResult(count: candidates.count)
        presentReview(image: photo.image,
                      candidates: candidates,
                      location: photo.location,
                      capturedAt: photo.capturedAt)
        processingView.alpha = 0
    }

    private func presentReview(image: UIImage,
                               candidates: [CaptureCandidate],
                               location: CLLocation?,
                               capturedAt: Date) {
        let review = CaptureReviewView(
            image: image,
            candidates: candidates,
            location: location,
            capturedAt: capturedAt,
            onConfirm: { [weak self] result in
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(self.captureStartedAt ?? Date())
                self.dismissReviewAndResume {
                    self.saveRecord(image: image,
                                    result: result,
                                    elapsed: elapsed)
                }
            },
            onCancel: { [weak self] in
                CaptureDiagnostics.recordCancelled()
                self?.dismissReviewAndResume(then: nil)
            }
        )
        let host = UIHostingController(rootView: review)
        host.modalPresentationStyle = .fullScreen
        present(host, animated: true)
        processingView.alpha = 0
    }

    private func dismissReviewAndResume(then: (() -> Void)?) {
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            self.endProcessing()
            then?()
        }
    }

    private func saveRecord(image: UIImage,
                            result: CaptureReviewResult,
                            elapsed: TimeInterval) {
        var savedFilename: String?
        do {
            let filename = try PhotoStorage.shared.save(image)
            savedFilename = filename
            let record = LandmarkRecord(
                timestamp: result.capturedAt,
                recognizedName: result.placeName,
                confidence: result.imageConfidence ?? 0,
                imageLabel: result.imageLabel,
                imageConfidence: result.imageConfidence,
                photoFilename: filename,
                latitude: result.location?.coordinate.latitude,
                longitude: result.location?.coordinate.longitude,
                note: result.note
            )
            let context = Persistence.container.mainContext
            context.insert(record)
            try context.save()
            CaptureDiagnostics.recordSaved(selectedFirst: result.selectedFirst,
                                           manualName: result.manualName,
                                           elapsed: elapsed)
            print("Capture diagnostics: \(CaptureDiagnostics.summary)")
            showToast("已儲存「\(result.placeName)」")
            refreshRecordsCount()
            refreshGPSChip()
        } catch {
            Persistence.container.mainContext.rollback()
            if let savedFilename {
                do {
                    try PhotoStorage.shared.delete(savedFilename)
                } catch {
                    print("Failed to roll back photo \(savedFilename): \(error)")
                }
            }
            showToast("儲存失敗，照片未加入足跡")
            print("Save record failed: \(error)")
        }
    }

    private func makeUIImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        // 與 Vision 用的 .right 一致,確保存下來的圖跟畫面方向相同
        return UIImage(cgImage: cgImage, scale: 1, orientation: .right)
    }

    private func showToast(_ message: String) {
        toastLabel.text = "  \(message)  "
        toastLabel.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.2, animations: {
            self.toastLabel.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.6, options: [], animations: {
                self.toastLabel.alpha = 0
            })
        })
    }
}

extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self, let result = results.first else { return }
            guard self.beginProcessing() else { return }
            Task { @MainActor in
                do {
                    let photo = try await PhotoImportService.load(from: result)
                    await self.processImportedPhoto(photo)
                } catch {
                    self.endProcessing()
                    self.showToast(error.localizedDescription)
                }
            }
        }
    }
}

private enum CameraSetupError: Error {
    case cannotAddInput
    case cannotAddOutput
}
