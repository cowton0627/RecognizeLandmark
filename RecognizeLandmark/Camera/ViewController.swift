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

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!

    private let videoQueue = DispatchQueue(label: "videoQueue")
    private var lastClassifyTime: TimeInterval = 0
    private let classifyInterval: TimeInterval = 0.5

    private let locationProvider = LocationProvider()
    private let authStatusManager = CLLocationManager()

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
        return v
    }()

    private lazy var captureButton: SketchedShutterView = {
        let b = SketchedShutterView()
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        return b
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

    override func viewDidLoad() {
        super.viewDidLoad()

        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        guard let backCamera = AVCaptureDevice.default(for: .video) else {
            print("Unable to access back camera!")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            captureSession.addInput(input)

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
        } catch let error {
            print("Error Unable to initialize back camera: \(error.localizedDescription)")
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        view.layer.insertSublayer(previewLayer, at: 0)

        setupOverlay()
        refreshRecordsCount()
        refreshGPSChip()

        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshRecordsCount()
        refreshGPSChip()
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
        view.addSubview(toastLabel)

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

            // toast(沿用、改為 sketch 樣式)
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: gpsChip.topAnchor, constant: -10),
            toastLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.85),
            toastLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
        ])
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
        stateLock.lock()
        let pixelBuffer = latestPixelBuffer
        stateLock.unlock()

        guard let pixelBuffer else {
            showToast("尚未取得畫面,請稍候")
            return
        }
        guard let image = makeUIImage(from: pixelBuffer) else {
            showToast("照片擷取失敗")
            return
        }

        captureButton.isEnabled = false

        // 暫停 capture session,避免 review 期間背景繼續跑 Vision
        let session = captureSession!
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let location = await self.locationProvider.currentLocation()
            async let mlCandidates = CaptureClassifier.classify(image)
            async let placeCandidates: [CaptureCandidate] = {
                guard let location else { return [] }
                return await PlaceLookup.lookup(location)
            }()

            let merged = await self.mergeCandidates(place: placeCandidates,
                                                    image: mlCandidates)
            self.presentReview(image: image, candidates: merged, location: location)
        }
    }

    private func mergeCandidates(place: [CaptureCandidate],
                                 image: [CaptureCandidate]) -> [CaptureCandidate] {
        var seen = Set<String>()
        return (place + image).filter { seen.insert($0.name).inserted }
    }

    private func presentReview(image: UIImage,
                               candidates: [CaptureCandidate],
                               location: CLLocation?) {
        let review = CaptureReviewView(
            image: image,
            candidates: candidates,
            location: location,
            onConfirm: { [weak self] name, confidence, note in
                self?.dismissReviewAndResume {
                    self?.saveRecord(image: image,
                                     name: name,
                                     confidence: confidence,
                                     note: note,
                                     location: location)
                }
            },
            onCancel: { [weak self] in
                self?.dismissReviewAndResume(then: nil)
            }
        )
        let host = UIHostingController(rootView: review)
        host.modalPresentationStyle = .fullScreen
        present(host, animated: true)
    }

    private func dismissReviewAndResume(then: (() -> Void)?) {
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            let session = self.captureSession!
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
            self.captureButton.isEnabled = true
            then?()
        }
    }

    private func saveRecord(image: UIImage,
                            name: String,
                            confidence: Double,
                            note: String,
                            location: CLLocation?) {
        do {
            let filename = try PhotoStorage.shared.save(image)
            let record = LandmarkRecord(
                recognizedName: name,
                confidence: confidence,
                photoFilename: filename,
                latitude: location?.coordinate.latitude,
                longitude: location?.coordinate.longitude,
                note: note
            )
            let context = Persistence.container.mainContext
            context.insert(record)
            try context.save()
            showToast("已儲存「\(name)」")
            refreshRecordsCount()
            refreshGPSChip()
        } catch {
            showToast("儲存失敗:\(error.localizedDescription)")
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
