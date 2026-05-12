//
//  CaptureCandidate.swift
//  RecognizeLandmark
//

import Foundation

struct CaptureCandidate: Identifiable, Hashable {
    enum Source: Hashable {
        case poi        // MKLocalSearch 附近 POI
        case geocode    // CLGeocoder reverse geocode
        case image      // 影像 ML
        case fallback   // 兜底(時間戳記等)
    }

    let id = UUID()
    let name: String
    let source: Source
    let secondaryText: String?
    let confidence: Double?       // 0–1;只有 image source 會有
    let distanceMeters: Double?   // 只有 poi source 會有
}

extension CaptureCandidate {
    /// 依名稱去重,保留第一次出現的順序。
    /// `PlaceLookup` 與 `CaptureFlow` 共用,避免兩處各寫一份 Set 邏輯。
    static func dedupedByName(_ candidates: [CaptureCandidate]) -> [CaptureCandidate] {
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.name).inserted }
    }
}
