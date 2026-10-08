//
//  Can_I_WearApp.swift
//  Can I Wear
//
//  Created by Tim Vande Walle on 04/10/2026.
//

import SwiftUI

@main
struct Can_I_WearApp: App {
    init() {
        DebugSettings.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let model = UITestScenario.model {
                ContentView(model: model)
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
    }
}
