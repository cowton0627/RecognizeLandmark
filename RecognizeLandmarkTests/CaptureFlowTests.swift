//
//  CaptureFlowTests.swift
//  RecognizeLandmarkTests
//

import Testing
import UIKit
import CoreLocation
@testable import RecognizeLandmark

struct CaptureFlowTests {
    private let image = UIImage()
    private let location = CLLocation(latitude: 25.0339, longitude: 121.5645)

    @Test func mergesBothSourcesAndRanksNearbyPOIFirst() async {
        let result = await CaptureFlow.run(
            image: image,
            location: location,
            classifier: { _ in [self.candidate("tower", source: .image, confidence: 0.9)] },
            placeFinder: { _ in [self.candidate("台北 101", source: .poi, distance: 8)] }
        )
        #expect(result.map(\.name) == ["台北 101", "tower"])
    }

    @Test func imageResultsRemainWhenPlaceLookupReturnsNothing() async {
        let result = await CaptureFlow.run(
            image: image,
            location: location,
            classifier: { _ in [self.candidate("building", source: .image, confidence: 0.7)] },
            placeFinder: { _ in [] }
        )
        #expect(result.map(\.name) == ["building"])
    }

    @Test func placeLookupIsNotCalledWithoutLocation() async {
        let result = await CaptureFlow.run(
            image: image,
            location: nil,
            classifier: { _ in [] },
            placeFinder: { _ in
                return [self.candidate("不應出現", source: .poi)]
            }
        )
        #expect(result.isEmpty)
    }

    @Test func higherScoringDuplicateWinsAcrossSources() async {
        let result = await CaptureFlow.run(
            image: image,
            location: location,
            classifier: { _ in [self.candidate("Taipei 101", source: .image, confidence: 0.99)] },
            placeFinder: { _ in [self.candidate(" taipei 101 ", source: .poi, distance: 5)] }
        )
        #expect(result.count == 1)
        #expect(result.first?.source == .poi)
    }

    private func candidate(_ name: String,
                           source: CaptureCandidate.Source,
                           confidence: Double? = nil,
                           distance: Double? = nil) -> CaptureCandidate {
        CaptureCandidate(
            name: name,
            source: source,
            secondaryText: nil,
            confidence: confidence,
            distanceMeters: distance
        )
    }
}
