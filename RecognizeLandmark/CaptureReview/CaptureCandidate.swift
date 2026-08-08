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
    /// 依正規化名稱去重,保留分數較高的候選,最後按分數排序。
    static func dedupedByName(_ candidates: [CaptureCandidate]) -> [CaptureCandidate] {
        var bestByName: [String: CaptureCandidate] = [:]
        for candidate in candidates where !candidate.normalizedName.isEmpty {
            let key = candidate.normalizedName
            if let existing = bestByName[key], existing.rankingScore >= candidate.rankingScore {
                continue
            }
            bestByName[key] = candidate
        }
        return bestByName.values.sorted {
            if $0.rankingScore == $1.rankingScore {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.rankingScore > $1.rankingScore
        }
    }

    /// 可解釋的第一版 ranking：附近具名 POI 優先，其次為 geocode，影像結果依信心排序。
    /// 分數只用於排序，不直接顯示成「準確率」。
    var rankingScore: Double {
        switch source {
        case .poi:
            let distance = max(0, distanceMeters ?? 100)
            return 0.75 + 0.25 * max(0, 1 - min(distance, 100) / 100)
        case .geocode:
            return 0.62
        case .image:
            return 0.30 + 0.30 * min(max(confidence ?? 0, 0), 1)
        case .fallback:
            return 0
        }
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
