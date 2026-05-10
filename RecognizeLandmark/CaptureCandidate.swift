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
