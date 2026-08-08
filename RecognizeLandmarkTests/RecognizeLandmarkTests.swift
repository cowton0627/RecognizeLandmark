//
//  RecognizeLandmarkTests.swift
//  RecognizeLandmarkTests
//
//  CaptureCandidate.dedupedByName 的單元測試。
//  PlaceLookup 與 CaptureFlow 共用這個 dedup,所以這支測試
//  變動時要連同那兩個檔的行為一起想清楚。
//

import Testing
@testable import RecognizeLandmark

struct CandidateDedupTests {

    @Test func emptyInputReturnsEmpty() {
        #expect(CaptureCandidate.dedupedByName([]).isEmpty)
    }

    @Test func ranksNearbyPOIBeforeGeocodeAndImage() {
        let input = [
            makeCandidate(name: "龍山寺", source: .poi),
            makeCandidate(name: "西門町", source: .geocode),
            makeCandidate(name: "building", source: .image),
        ]
        let result = CaptureCandidate.dedupedByName(input)
        #expect(result.map(\.name) == ["龍山寺", "西門町", "building"])
    }

    @Test func dropsLaterDuplicatesBySameName() {
        let input = [
            makeCandidate(name: "Tokyo Tower", source: .poi),
            makeCandidate(name: "Tokyo Tower", source: .geocode),
            makeCandidate(name: "Tokyo Tower", source: .image),
        ]
        let result = CaptureCandidate.dedupedByName(input)
        #expect(result.count == 1)
        #expect(result.first?.source == .poi)
    }

    @Test func keepsHigherScoringDuplicateRegardlessOfInputOrder() {
        let input = [
            makeCandidate(name: "Taipei 101", source: .image, confidence: 0.95),
            makeCandidate(name: " taipei 101 ", source: .poi, distance: 12),
        ]
        let result = CaptureCandidate.dedupedByName(input)
        #expect(result.count == 1)
        #expect(result.first?.source == .poi)
    }

    @Test func nearerPOIRanksFirst() {
        let result = CaptureCandidate.dedupedByName([
            makeCandidate(name: "遠處", source: .poi, distance: 90),
            makeCandidate(name: "近處", source: .poi, distance: 8),
        ])
        #expect(result.map(\.name) == ["近處", "遠處"])
    }

    @Test func higherConfidenceImageRanksFirst() {
        let result = CaptureCandidate.dedupedByName([
            makeCandidate(name: "low", source: .image, confidence: 0.3),
            makeCandidate(name: "high", source: .image, confidence: 0.9),
        ])
        #expect(result.map(\.name) == ["high", "low"])
    }

    @Test func preservesPlaceCandidatesBeforeImageCandidates() {
        // 模擬 CaptureFlow 的合併順序:place 在前、image 在後。
        // 同名時 place 版本應勝出。
        let place = [
            makeCandidate(name: "101", source: .poi),
            makeCandidate(name: "信義區", source: .geocode),
        ]
        let image = [
            makeCandidate(name: "101", source: .image, confidence: 0.8),
            makeCandidate(name: "tower", source: .image, confidence: 0.6),
        ]
        let result = CaptureCandidate.dedupedByName(place + image)
        #expect(result.map(\.name) == ["101", "信義區", "tower"])
        #expect(result.first?.source == .poi)
    }

    // MARK: - helpers

    private func makeCandidate(name: String,
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
