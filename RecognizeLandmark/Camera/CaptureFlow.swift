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

    /// 對單張照片同時跑影像 ML(`CaptureClassifier`)與(若有座標)`PlaceLookup`,
    /// 合併兩路候選並依名稱去重。順序固定為 POI/geocode 在前、image 在後,
    /// 與 DECISIONS.md「候選排序」一致。
    static func run(image: UIImage, location: CLLocation?) async -> [CaptureCandidate] {
        async let mlCandidates = CaptureClassifier.classify(image)
        async let placeCandidates: [CaptureCandidate] = {
            guard let location else { return [] }
            return await PlaceLookup.lookup(location)
        }()

        let merged = await placeCandidates + mlCandidates
        return CaptureCandidate.dedupedByName(merged)
    }
}
