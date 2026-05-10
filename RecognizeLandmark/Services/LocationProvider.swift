//
//  LocationProvider.swift
//  RecognizeLandmark
//

import Foundation
import CoreLocation

final class LocationProvider: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation() async -> CLLocation? {
        // 同時間只允許一個請求,避免 continuation 互踩
        if continuation != nil { return nil }

        return await withCheckedContinuation { cont in
            self.continuation = cont
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
                // 等 locationManagerDidChangeAuthorization 觸發後再 requestLocation
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                finish(with: nil)
            @unknown default:
                finish(with: nil)
            }
        }
    }

    private func finish(with location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(with: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(with: nil)
        default:
            break
        }
    }
}
