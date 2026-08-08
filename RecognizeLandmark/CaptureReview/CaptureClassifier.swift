//
//  CaptureClassifier.swift
//  RecognizeLandmark
//
//  把影像 ML 從 ViewController 抽出來,讓未來換成 Core ML 地標模型時只動這支。
//

import Foundation
import UIKit
import Vision

enum CaptureClassifier {

    /// 對單張靜止照片做一次性辨識,回傳信心 ≥ 0.2 的前 3 名候選。
    static func classify(_ image: UIImage) async -> [CaptureCandidate] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cgImage = image.cgImage else {
                    cont.resume(returning: [])
                    return
                }
                let orientation = CGImagePropertyOrientation(image.imageOrientation)
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage,
                                                    orientation: orientation,
                                                    options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let candidates = observations
                        .filter { $0.confidence >= 0.2 }
                        .prefix(3)
                        .map { obs in
                            CaptureCandidate(
                                name: obs.identifier,
                                source: .image,
                                secondaryText: String(format: "%.0f%%", obs.confidence * 100),
                                confidence: Double(obs.confidence),
                                distanceMeters: nil
                            )
                        }
                    cont.resume(returning: Array(candidates))
                } catch {
                    cont.resume(returning: [])
                }
            }
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:            self = .up
        case .upMirrored:    self = .upMirrored
        case .down:          self = .down
        case .downMirrored:  self = .downMirrored
        case .left:          self = .left
        case .leftMirrored:  self = .leftMirrored
        case .right:         self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}
