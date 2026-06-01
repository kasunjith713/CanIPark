// AnalysisView.swift
// CanIPark
//
// Progress screen with animated analysis steps.

import SwiftUI

struct AnalysisView: View {

    @Environment(AppState.self) private var appState

    private let steps: [AnalysisPhase] = [
        .detectingSigns,
        .readingText,
        .interpretingRules,
        .determiningVerdict
    ]

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Animated icon
            animatedIcon

            // Phase description
            Text(appState.analysisPhase.description)
                .font(.title2)
                .fontWeight(.semibold)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: appState.analysisPhase)
                .accessibilityLabel("Analysis status: \(appState.analysisPhase.description)")

            // Progress bar
            progressBar

            // Step list
            stepList

            Spacer()

            // Error message
            if let error = appState.analysisError {
                errorBanner(error)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Animated Icon

    private var animatedIcon: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.1))
                .frame(width: 120, height: 120)

            Circle()
                .strokeBorder(.blue.opacity(0.3), lineWidth: 4)
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(appState.isAnalysing ? 360 : 0))
                .animation(
                    appState.isAnalysing
                        ? .linear(duration: 2).repeatForever(autoreverses: false)
                        : .default,
                    value: appState.isAnalysing
                )

            Image(systemName: iconForPhase(appState.analysisPhase))
                .font(.system(size: 40))
                .foregroundStyle(.blue)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
        }
    }

    private func iconForPhase(_ phase: AnalysisPhase) -> String {
        switch phase {
        case .idle:               return "camera.fill"
        case .detectingSigns:     return "viewfinder"
        case .readingText:        return "doc.text.magnifyingglass"
        case .interpretingRules:  return "brain"
        case .determiningVerdict: return "checkmark.shield"
        case .complete:           return "checkmark.circle.fill"
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            ProgressView(value: appState.analysisPhase.progress, total: 1.0)
                .tint(.blue)
                .animation(.easeInOut(duration: 0.4), value: appState.analysisPhase.progress)
                .accessibilityLabel("Analysis progress")
                .accessibilityValue("\(Int(appState.analysisPhase.progress * 100)) percent")

            Text("\(Int(appState.analysisPhase.progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step List

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(steps.enumerated()), id: \.element) { index, step in
                HStack(spacing: 12) {
                    stepIcon(for: step)

                    Text(step.description)
                        .font(.subheadline)
                        .foregroundStyle(stepColor(for: step))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(step.description), \(stepStatusLabel(for: step))")
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.analysisPhase)
    }

    @ViewBuilder
    private func stepIcon(for step: AnalysisPhase) -> some View {
        let current = appState.analysisPhase

        if step == current {
            ProgressView()
                .controlSize(.small)
                .frame(width: 20, height: 20)
        } else if step.progress < current.progress {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
    }

    private func stepColor(for step: AnalysisPhase) -> Color {
        let current = appState.analysisPhase
        if step == current { return .primary }
        if step.progress < current.progress { return .secondary }
        return .secondary.opacity(0.5)
    }

    private func stepStatusLabel(for step: AnalysisPhase) -> String {
        let current = appState.analysisPhase
        if step == current { return "in progress" }
        if step.progress < current.progress { return "complete" }
        return "pending"
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        VStack(spacing: 12) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)

            Button("Dismiss") {
                appState.resetAnalysis()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

#Preview {
    let state = AppState()
    state.analysisPhase = .readingText
    return AnalysisView()
        .environment(state)
}
