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
    var recognizedName: String
    var confidence: Double
    var photoFilename: String
    var latitude: Double?
    var longitude: Double?
    var note: String

    init(timestamp: Date = Date(),
         recognizedName: String,
         confidence: Double,
         photoFilename: String,
         latitude: Double? = nil,
         longitude: Double? = nil,
         note: String = "") {
        self.timestamp = timestamp
        self.recognizedName = recognizedName
        self.confidence = confidence
        self.photoFilename = photoFilename
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
