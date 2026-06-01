// ContentView.swift
// CanIPark
//
// Root TabView with Home, History, and Settings tabs.

import SwiftUI

struct ContentView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.iconName, value: .home) {
                HomeView()
            }

            Tab(AppTab.history.title, systemImage: AppTab.history.iconName, value: .history) {
                HistoryView()
            }

            Tab(AppTab.settings.title, systemImage: AppTab.settings.iconName, value: .settings) {
                SettingsView()
            }
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(ScanHistoryStore())
}
