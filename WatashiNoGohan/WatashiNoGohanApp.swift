//
//  WatashiNoGohanApp.swift
//  WatashiNoGohan
//
//  Created by Tatsuki Kato on 2025/07/18.
//

import SwiftUI

@main
struct WatashiNoGohanApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
