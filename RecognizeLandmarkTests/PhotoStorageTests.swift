//
//  PhotoStorageTests.swift
//  RecognizeLandmarkTests
//

import Testing
import UIKit
@testable import RecognizeLandmark

struct PhotoStorageTests {
    @Test func saveLoadDeleteRoundTrip() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }

        let filename = try fixture.storage.save(makeImage())
        #expect(FileManager.default.fileExists(atPath: fixture.storage.url(for: filename).path))

        let loaded = try fixture.storage.load(filename)
        #expect(loaded.size.width > 0)
        #expect(loaded.size.height > 0)

        try fixture.storage.delete(filename)
        #expect(!FileManager.default.fileExists(atPath: fixture.storage.url(for: filename).path))
    }

    @Test func loadingMissingFileThrows() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        #expect(throws: PhotoStorageError.fileNotFound) {
            try fixture.storage.load("missing.jpg")
        }
    }

    @Test func loadingInvalidJPEGThrows() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let url = fixture.storage.url(for: "broken.jpg")
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
        try Data("not an image".utf8).write(to: url)
        #expect(throws: PhotoStorageError.decodeFailed) {
            try fixture.storage.load("broken.jpg")
        }
    }

    @Test func deletingMissingFileIsIdempotent() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        try fixture.storage.delete("already-gone.jpg")
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.systemOrange.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
    }

    private struct Fixture {
        let directory: URL
        let storage: PhotoStorage

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("PhotoStorageTests-\(UUID().uuidString)", isDirectory: true)
            storage = PhotoStorage(directoryURL: directory)
        }

        func cleanup() {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
