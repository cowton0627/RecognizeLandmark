//
//  Persistence.swift
//  RecognizeLandmark
//

import Foundation
import SwiftData

enum Persistence {
    static let container: ModelContainer = {
        let schema = Schema([LandmarkRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
