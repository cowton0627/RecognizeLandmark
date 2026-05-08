//
//  PhotoStorage.swift
//  RecognizeLandmark
//

import Foundation
import UIKit

enum PhotoStorageError: Error {
    case writeFailed
    case fileNotFound
    case decodeFailed
}

struct PhotoStorage {
    static let shared = PhotoStorage()

    private let directoryName = "photos"
    private let jpegQuality: CGFloat = 0.85

    private var directoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(directoryName, isDirectory: true)
    }

    private func ensureDirectory() throws {
        let url = directoryURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    @discardableResult
    func save(_ image: UIImage) throws -> String {
        try ensureDirectory()
        guard let data = image.jpegData(compressionQuality: jpegQuality) else {
            throw PhotoStorageError.writeFailed
        }
        let filename = "\(UUID().uuidString).jpg"
        let url = directoryURL.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return filename
    }

    func load(_ filename: String) throws -> UIImage {
        let url = directoryURL.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PhotoStorageError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else {
            throw PhotoStorageError.decodeFailed
        }
        return image
    }

    func delete(_ filename: String) throws {
        let url = directoryURL.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func url(for filename: String) -> URL {
        directoryURL.appendingPathComponent(filename)
    }
}
