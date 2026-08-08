//
//  CaptureFlow.swift
//  RecognizeLandmark
//
//  把「按下快門 → 取得候選」的流程從 ViewController 抽出來。
//  ViewController 只負責拍照觸發、Review presentation 與 save;
//  CaptureFlow 同時跑影像 ML 與 PlaceLookup,合併兩路候選並去重。
//

import Foundation
import UIKit
import CoreLocation

enum CaptureFlow {

    typealias Classifier = (UIImage) async -> [CaptureCandidate]
    typealias PlaceFinder = (CLLocation) async -> [CaptureCandidate]

    /// 對單張照片同時跑影像 ML(`CaptureClassifier`)與(若有座標)`PlaceLookup`,
    /// 合併兩路候選,依名稱去重並用距離、來源、信心排序。
    /// 依賴以 closure 注入,production 使用預設 service,測試不需相機、網路或 MapKit。
    static func run(image: UIImage,
                    location: CLLocation?,
                    classifier: @escaping Classifier = CaptureClassifier.classify,
                    placeFinder: @escaping PlaceFinder = PlaceLookup.lookup) async -> [CaptureCandidate] {
        async let mlCandidates = classifier(image)
        async let placeCandidates: [CaptureCandidate] = {
            guard let location else { return [] }
            return await placeFinder(location)
        }()

        let merged = await placeCandidates + mlCandidates
        return CaptureCandidate.dedupedByName(merged)
    }
}

/// 僅存在裝置上的開發診斷摘要；不包含照片、名稱或座標，也不會上傳。
enum CaptureDiagnostics {
    private static let defaults = UserDefaults.standard
    private static let prefix = "captureDiagnostics."

    static func recordCandidateResult(count: Int) {
        increment("captures")
        if count > 0 { increment("withCandidates") }
    }

    static func recordSaved(selectedFirst: Bool, manualName: Bool, elapsed: TimeInterval) {
        increment("saved")
        if selectedFirst { increment("selectedFirst") }
        if manualName { increment("manualName") }
        defaults.set(defaults.double(forKey: prefix + "totalSaveSeconds") + max(0, elapsed),
                     forKey: prefix + "totalSaveSeconds")
    }

    static func recordCancelled() { increment("cancelled") }

    static var summary: String {
        let captures = defaults.integer(forKey: prefix + "captures")
        let withCandidates = defaults.integer(forKey: prefix + "withCandidates")
        let saved = defaults.integer(forKey: prefix + "saved")
        let first = defaults.integer(forKey: prefix + "selectedFirst")
        let manual = defaults.integer(forKey: prefix + "manualName")
        let average = saved == 0 ? 0 : defaults.double(forKey: prefix + "totalSaveSeconds") / Double(saved)
        let averageText = String(format: "%.1fs", average)
        return "captures=\(captures), candidates=\(withCandidates), saved=\(saved), first=\(first), manual=\(manual), avgSave=\(averageText)"
    }

    private static func increment(_ key: String) {
        let fullKey = prefix + key
        defaults.set(defaults.integer(forKey: fullKey) + 1, forKey: fullKey)
    }
}
