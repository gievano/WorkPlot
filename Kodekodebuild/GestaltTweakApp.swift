//
//  GestaltTweakApp.swift
//  GestaltTweak
//
//  Licensed under the MIT License.
//

import SwiftUI

@main
struct GestaltTweakApp: App {
    @StateObject private var viewModel = GestaltViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
