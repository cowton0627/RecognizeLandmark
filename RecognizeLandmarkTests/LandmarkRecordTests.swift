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
}
