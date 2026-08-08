//
//  LandmarkRecord.swift
//  RecognizeLandmark
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class LandmarkRecord {
    var timestamp: Date
    /// 使用者確認的地點名稱（歷史名稱保留以避免破壞既有 SwiftData store）。
    var recognizedName: String
    /// 舊版欄位，保留供既有資料 migration；新 UI 使用 imageConfidence。
    var confidence: Double
    var imageLabel: String?
    var imageConfidence: Double?
    var photoFilename: String
    var latitude: Double?
    var longitude: Double?
    var note: String

    init(timestamp: Date = Date(),
         recognizedName: String,
         confidence: Double,
         imageLabel: String? = nil,
         imageConfidence: Double? = nil,
         photoFilename: String,
         latitude: Double? = nil,
         longitude: Double? = nil,
         note: String = "") {
        self.timestamp = timestamp
        self.recognizedName = recognizedName
        self.confidence = confidence
        self.imageLabel = imageLabel
        self.imageConfidence = imageConfidence
        self.photoFilename = photoFilename
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// 舊資料若曾保存非零影像信心，仍可顯示；0 代表舊版「未評分」。
    var effectiveImageConfidence: Double? {
        imageConfidence ?? (confidence > 0 ? confidence : nil)
    }
}
