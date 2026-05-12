//
//  Persistence.swift
//  RecognizeLandmark
//

import Foundation
import SwiftData

enum Persistence {
    /// 全 App 共用的 production container(磁碟持久化)。
    static let container: ModelContainer = {
        do {
            return try makeContainer(inMemory: false)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// 工廠方法:`inMemory: true` 給單元測試用,不寫磁碟。
    /// 測試裡每個 case 應該自己建一個新的 in-memory container,避免互相污染。
    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema([LandmarkRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: config)
    }
}
