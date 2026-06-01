// CanIParkApp.swift
// CanIPark
//
// Main entry point for the CanIPark Australian parking sign interpreter.

import SwiftUI

@main
struct CanIParkApp: App {

    @State private var appState = AppState()
    @State private var historyStore = ScanHistoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(historyStore)
        }
    }
}
