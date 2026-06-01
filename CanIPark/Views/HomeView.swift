// HomeView.swift
// CanIPark
//
// Main landing screen with scan button and quick tips.

import SwiftUI

struct HomeView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    heroSection
                    scanButton
                    quickTipsSection
                }
                .padding()
            }
            .navigationTitle("CanIPark")
            .sheet(isPresented: Binding(
                get: { appState.showingCamera },
                set: { appState.showingCamera = $0 }
            )) {
                CameraView()
            }
            .fullScreenCover(isPresented: Binding(
                get: { appState.isAnalysing },
                set: { _ in }
            )) {
                AnalysisView()
            }
            .fullScreenCover(isPresented: Binding(
                get: { appState.showingResult && appState.currentResult != nil },
                set: { newValue in
                    if !newValue { appState.resetAnalysis() }
                }
            )) {
                if let result = appState.currentResult {
                    ResultView(result: result, capturedImage: appState.capturedImage)
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "car.side.and.exclamationmark")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("Australian Parking Sign Interpreter")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text("Point your camera at a parking sign to find out if you can park here right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: - Scan Button

    private var scanButton: some View {
        Button {
            appState.showingCamera = true
        } label: {
            Label("Scan Sign", systemImage: "camera.fill")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel("Scan a parking sign")
        .accessibilityHint("Opens the camera to photograph a parking sign")
    }

    // MARK: - Quick Tips

    private var quickTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Tips")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            tipRow(
                icon: "camera.viewfinder",
                title: "Frame the sign",
                detail: "Get all signs in the photo, including arrows and time plates."
            )

            tipRow(
                icon: "sun.max.fill",
                title: "Good lighting",
                detail: "Avoid glare and shadows for the best reading."
            )

            tipRow(
                icon: "arrow.left.arrow.right",
                title: "Check all signs",
                detail: "Multiple signs may apply. Capture the full sign post."
            )

            tipRow(
                icon: "exclamationmark.triangle.fill",
                title: "Always verify",
                detail: "This app is a guide only. Always read the signs yourself."
            )
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func tipRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeView()
        .environment(AppState())
        .environment(ScanHistoryStore())
}
