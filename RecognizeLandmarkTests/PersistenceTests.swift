//
//  PersistenceTests.swift
//  RecognizeLandmarkTests
//
//  SwiftData ModelContainer 的 CRUD smoke test。
//  用 Persistence.makeContainer(inMemory: true) 避免污染 production 資料。
//

import Testing
import SwiftData
@testable import RecognizeLandmark

@MainActor
struct PersistenceTests {

    @Test func insertAndFetchOneRecord() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext

        let record = LandmarkRecord(
            recognizedName: "Test Landmark",
            confidence: 0.75,
            photoFilename: "test.jpg",
            latitude: 25.0,
            longitude: 121.5,
            note: "Hello"
        )
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<LandmarkRecord>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.recognizedName == "Test Landmark")
        #expect(fetched.first?.note == "Hello")
    }

    @Test func deleteRecord() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext

        let record = LandmarkRecord(
            recognizedName: "ToDelete",
            confidence: 0.5,
            photoFilename: "d.jpg"
        )
        context.insert(record)
        try context.save()

        context.delete(record)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<LandmarkRecord>())
        #expect(remaining.isEmpty)
    }

    @Test func twoContainersAreIsolated() throws {
        let a = try Persistence.makeContainer(inMemory: true)
        let b = try Persistence.makeContainer(inMemory: true)

        a.mainContext.insert(LandmarkRecord(
            recognizedName: "OnlyInA",
            confidence: 0,
            photoFilename: "a.jpg"
        ))
        try a.mainContext.save()

        let inB = try b.mainContext.fetch(FetchDescriptor<LandmarkRecord>())
        #expect(inB.isEmpty, "in-memory container 之間應該不互通")
    }
}
