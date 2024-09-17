//
//  Panglong_iKeyboardApp.swift
//  Panglong_iKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import SwiftUI
import SwiftData

@main
struct Panglong_iKeyboardApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
