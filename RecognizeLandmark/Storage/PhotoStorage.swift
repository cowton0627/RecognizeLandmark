//
//  PhotoStorage.swift
//  RecognizeLandmark
//

import Foundation
import UIKit

enum PhotoStorageError: Error, Equatable {
    case writeFailed
    case fileNotFound
    case decodeFailed
}

struct PhotoStorage {
    static let shared = PhotoStorage()

    private let directoryName = "photos"
    private let jpegQuality: CGFloat = 0.85
    private let customDirectoryURL: URL?
    private let fileManager: FileManager

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.customDirectoryURL = directoryURL
        self.fileManager = fileManager
    }

    private var directoryURL: URL {
        if let customDirectoryURL { return customDirectoryURL }
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(directoryName, isDirectory: true)
    }

    private func ensureDirectory() throws {
        let url = directoryURL
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
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
        guard fileManager.fileExists(atPath: url.path) else {
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
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func url(for filename: String) -> URL {
        directoryURL.appendingPathComponent(filename)
    }
}
