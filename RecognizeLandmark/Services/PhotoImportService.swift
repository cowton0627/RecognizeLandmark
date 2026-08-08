//
//  PhotoImportService.swift
//  RecognizeLandmark
//
//  Loads an image selected through PHPicker and extracts embedded capture
//  date / GPS without requesting full Photo Library access.
//

import Foundation
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import ImageIO
import CoreLocation

struct ImportedPhoto {
    let image: UIImage
    let capturedAt: Date
    let location: CLLocation?
}

enum PhotoImportError: LocalizedError {
    case unreadableImage

    var errorDescription: String? {
        "無法讀取選取的照片"
    }
}

enum PhotoImportService {
    static func load(from result: PHPickerResult) async throws -> ImportedPhoto {
        let data = try await loadImageData(from: result.itemProvider)
        guard let image = UIImage(data: data) else { throw PhotoImportError.unreadableImage }
        let metadata = metadata(from: data)
        return ImportedPhoto(
            image: image,
            capturedAt: metadata.date ?? Date(),
            location: metadata.location
        )
    }

    private static func loadImageData(from provider: NSItemProvider) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? PhotoImportError.unreadableImage)
                }
            }
        }
    }

    private static func metadata(from data: Data) -> (date: Date?, location: CLLocation?) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return (nil, nil) }

        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let dateText = exif?[kCGImagePropertyExifDateTimeOriginal] as? String
        let date = dateText.flatMap(parseEXIFDate)

        guard let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let rawLatitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              let rawLongitude = gps[kCGImagePropertyGPSLongitude] as? Double
        else { return (date, nil) }

        let latitudeRef = (gps[kCGImagePropertyGPSLatitudeRef] as? String)?.uppercased()
        let longitudeRef = (gps[kCGImagePropertyGPSLongitudeRef] as? String)?.uppercased()
        let latitude = latitudeRef == "S" ? -rawLatitude : rawLatitude
        let longitude = longitudeRef == "W" ? -rawLongitude : rawLongitude
        guard CLLocationCoordinate2DIsValid(.init(latitude: latitude, longitude: longitude)) else {
            return (date, nil)
        }
        return (date, CLLocation(latitude: latitude, longitude: longitude))
    }

    private static func parseEXIFDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: text)
    }
}
