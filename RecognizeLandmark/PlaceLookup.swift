//
//  PlaceLookup.swift
//  RecognizeLandmark
//

import Foundation
import CoreLocation
import MapKit

enum PlaceLookup {

    /// 同時跑 MKLocalSearch(附近 POI)與 CLGeocoder(反向地理編碼),
    /// 合併後依 source 排序、依名稱去重。
    static func lookup(_ location: CLLocation) async -> [CaptureCandidate] {
        async let pois = nearbyPOIs(location)
        async let geo = reverseGeocode(location)
        let combined = await pois + geo
        var seen = Set<String>()
        return combined.filter { seen.insert($0.name).inserted }
    }

    private static func nearbyPOIs(_ location: CLLocation) async -> [CaptureCandidate] {
        let radius: CLLocationDistance = 100
        let poiRequest = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: radius)
        let request = MKLocalSearch.Request(pointsOfInterestRequest: poiRequest)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            let candidates = response.mapItems.compactMap { item -> CaptureCandidate? in
                guard let name = item.name else { return nil }
                let dist = item.placemark.location?.distance(from: location)
                return CaptureCandidate(
                    name: name,
                    source: .poi,
                    secondaryText: dist.map { String(format: "約 %.0f m", $0) },
                    confidence: nil,
                    distanceMeters: dist
                )
            }
            let sorted = candidates.sorted {
                ($0.distanceMeters ?? .infinity) < ($1.distanceMeters ?? .infinity)
            }
            return Array(sorted.prefix(5))
        } catch {
            return []
        }
    }

    private static func reverseGeocode(_ location: CLLocation) async -> [CaptureCandidate] {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let pm = placemarks.first else { return [] }
            var results: [CaptureCandidate] = []

            // areasOfInterest 通常是最像「具名地標」的欄位
            if let aoi = pm.areasOfInterest?.first, !aoi.isEmpty {
                results.append(CaptureCandidate(
                    name: aoi,
                    source: .geocode,
                    secondaryText: pm.locality ?? pm.administrativeArea,
                    confidence: nil,
                    distanceMeters: nil
                ))
            }

            // 退而求其次:用 placemark name / 街道組合當候選
            let parts = [pm.name, pm.thoroughfare, pm.locality]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            if let primary = parts.first,
               !results.contains(where: { $0.name == primary }) {
                let secondary = parts.dropFirst().joined(separator: ", ")
                results.append(CaptureCandidate(
                    name: primary,
                    source: .geocode,
                    secondaryText: secondary.isEmpty ? nil : secondary,
                    confidence: nil,
                    distanceMeters: nil
                ))
            }
            return results
        } catch {
            return []
        }
    }
}
