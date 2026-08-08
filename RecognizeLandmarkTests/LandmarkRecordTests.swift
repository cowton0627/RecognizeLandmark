//
//  LandmarkRecordTests.swift
//  RecognizeLandmarkTests
//
//  LandmarkRecord 上的 computed property(coordinate)的單元測試。
//

import Testing
import CoreLocation
@testable import RecognizeLandmark

struct LandmarkRecordTests {

    @Test func coordinateIsNilWhenLatitudeMissing() {
        let record = LandmarkRecord(
            recognizedName: "x",
            confidence: 0,
            photoFilename: "x.jpg",
            latitude: nil,
            longitude: 121.5
        )
        #expect(record.coordinate == nil)
    }

    @Test func coordinateIsNilWhenLongitudeMissing() {
        let record = LandmarkRecord(
            recognizedName: "x",
            confidence: 0,
            photoFilename: "x.jpg",
            latitude: 25.0,
            longitude: nil
        )
        #expect(record.coordinate == nil)
    }

    @Test func coordinateReturnsValueWhenBothPresent() {
        let record = LandmarkRecord(
            recognizedName: "Taipei 101",
            confidence: 0.9,
            photoFilename: "x.jpg",
            latitude: 25.0339,
            longitude: 121.5645
        )
        let coord = record.coordinate
        #expect(coord != nil)
        #expect(coord?.latitude == 25.0339)
        #expect(coord?.longitude == 121.5645)
    }

    @Test func zeroLegacyConfidenceMeansNotRated() {
        let record = LandmarkRecord(
            recognizedName: "Office",
            confidence: 0,
            photoFilename: "x.jpg"
        )
        #expect(record.effectiveImageConfidence == nil)
    }

    @Test func imageConfidenceTakesPriorityOverLegacyValue() {
        let record = LandmarkRecord(
            recognizedName: "Office",
            confidence: 0.4,
            imageLabel: "laptop",
            imageConfidence: 0.82,
            photoFilename: "x.jpg"
        )
        #expect(record.effectiveImageConfidence == 0.82)
        #expect(record.imageLabel == "laptop")
    }

    @Test func nearbyRecordsShareOneMapCluster() {
        let first = makeRecord(name: "A", latitude: 25.0330, longitude: 121.5654)
        let second = makeRecord(name: "B", latitude: 25.0333, longitude: 121.5654)
        let clusters = RecordCluster.make(from: [first, second])
        #expect(clusters.count == 1)
        #expect(clusters.first?.records.count == 2)
    }

    @Test func distantRecordsUseSeparateMapClusters() {
        let taipei = makeRecord(name: "台北", latitude: 25.0330, longitude: 121.5654)
        let kaohsiung = makeRecord(name: "高雄", latitude: 22.6273, longitude: 120.3014)
        #expect(RecordCluster.make(from: [taipei, kaohsiung]).count == 2)
    }

    @Test func mapClustersIgnoreRecordsWithoutCoordinates() {
        let record = LandmarkRecord(
            recognizedName: "No GPS",
            confidence: 0,
            photoFilename: "x.jpg"
        )
        #expect(RecordCluster.make(from: [record]).isEmpty)
    }

    private func makeRecord(name: String, latitude: Double, longitude: Double) -> LandmarkRecord {
        LandmarkRecord(
            recognizedName: name,
            confidence: 0,
            photoFilename: "\(name).jpg",
            latitude: latitude,
            longitude: longitude
        )
    }
}
