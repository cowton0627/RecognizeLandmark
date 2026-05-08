//
//  ViewController.swift
//  RecognizeLandmark
//
//  Created by RecognizeLandmark contributors on 2024/9/27.
//

import AVFoundation
import UIKit
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!

    @IBOutlet weak var recognizedLabel: UILabel!

    private let videoQueue = DispatchQueue(label: "videoQueue")
    private var lastClassifyTime: TimeInterval = 0
    private let classifyInterval: TimeInterval = 0.5

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
        // 放最底層,讓 storyboard 上的 recognizedLabel 蓋在預覽畫面上
        view.layer.insertSublayer(previewLayer, at: 0)

        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastClassifyTime >= classifyInterval else { return }
        lastClassifyTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNClassifyImageRequest { [weak self] request, _ in
            guard let results = request.results as? [VNClassificationObservation] else { return }
            let top = results
                .filter { $0.confidence >= 0.2 }
                .prefix(3)
                .map { String(format: "%@  %.0f%%", $0.identifier, $0.confidence * 100) }
                .joined(separator: "\n")

            DispatchQueue.main.async {
                self?.recognizedLabel.text = top.isEmpty ? "(無辨識結果)" : top
            }
        }

        // 後鏡頭 + 直立握持時,sample buffer 需要旋轉到 .right 才能正確分類
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .right,
                                            options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Vision request failed: \(error)")
        }
    }
}
