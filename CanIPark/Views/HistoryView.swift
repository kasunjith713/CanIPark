// HistoryView.swift
// CanIPark
//
// List of past scans with thumbnails, swipe to delete.

import SwiftUI

struct HistoryView: View {

    @Environment(ScanHistoryStore.self) private var historyStore
    @State private var selectedResult: ParkingAnalysisResult?
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if historyStore.scans.isEmpty {
                    emptyState
                } else {
                    scanList
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !historyStore.scans.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear All", role: .destructive) {
                            showClearConfirmation = true
                        }
                        .accessibilityLabel("Clear all scan history")
                    }
                }
            }
            .confirmationDialog("Clear All History?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) {
                    withAnimation {
                        historyStore.clearAll()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all saved scans. This action cannot be undone.")
            }
            .sheet(item: $selectedResult) { result in
                ResultView(result: result, capturedImage: nil)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Scans Yet", systemImage: "clock.badge.questionmark")
        } description: {
            Text("Your scan history will appear here after you scan a parking sign.")
        } actions: {
            // No action needed
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No scan history. Scan a parking sign to get started.")
    }

    // MARK: - Scan List

    private var scanList: some View {
        List {
            ForEach(historyStore.scans) { scan in
                Button {
                    selectedResult = scan
                } label: {
                    scanRow(scan)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(scanAccessibilityLabel(scan))
                .accessibilityHint("Double tap to view details")
            }
            .onDelete { offsets in
                withAnimation {
                    historyStore.delete(at: offsets)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Scan Row

    private func scanRow(_ scan: ParkingAnalysisResult) -> some View {
        HStack(spacing: 14) {
            // Thumbnail or placeholder
            thumbnailView(for: scan)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(scan.verdict.headline)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(verdictColor(scan.verdict))
                        .lineLimit(1)

                    Spacer()

                    confidenceDot(scan.confidence)
                }

                if let timeLimit = scan.timeLimit {
                    Text(timeLimit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(scan.scanDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if let location = scan.locationDescription {
                    Text(location)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private func thumbnailView(for scan: ParkingAnalysisResult) -> some View {
        if let image = historyStore.thumbnail(for: scan.id) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(verdictColor(scan.verdict).opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: scan.verdict.iconName)
                    .font(.title3)
                    .foregroundStyle(verdictColor(scan.verdict))
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Confidence Dot

    private func confidenceDot(_ confidence: ConfidenceLevel) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor(confidence))
                .frame(width: 8, height: 8)

            Text(confidence.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func verdictColor(_ verdict: Verdict) -> Color {
        switch verdict {
        case .canPark:    return .green
        case .cannotPark: return .red
        case .uncertain:  return .orange
        }
    }

    private func confidenceColor(_ confidence: ConfidenceLevel) -> Color {
        switch confidence {
        case .high:   return .green
        case .medium: return .orange
        case .low:    return .red
        }
    }

    private func scanAccessibilityLabel(_ scan: ParkingAnalysisResult) -> String {
        var parts = [scan.verdict.headline]
        if let timeLimit = scan.timeLimit { parts.append(timeLimit) }
        parts.append("scanned \(scan.scanDate.formatted(date: .abbreviated, time: .shortened))")
        parts.append("\(scan.confidence.displayName) confidence")
        return parts.joined(separator: ", ")
    }
}

#Preview("With History") {
    let store = ScanHistoryStore()
    store.add(ParkingAnalysisResult(
        verdict: .canPark, confidence: .high,
        timeLimit: "Until 6:00 PM", maxStay: "2 hours", paymentStatus: "Metered",
        warnings: ["Payment required."]
    ))
    store.add(ParkingAnalysisResult(
        verdict: .cannotPark, confidence: .high,
        warnings: ["No stopping zone."],
        scanDate: Date().addingTimeInterval(-3600)
    ))
    store.add(ParkingAnalysisResult(
        verdict: .uncertain, confidence: .low,
        warnings: ["Could not read sign."],
        scanDate: Date().addingTimeInterval(-7200)
    ))
    return HistoryView()
        .environment(store)
        .environment(AppState())
}

#Preview("Empty") {
    HistoryView()
        .environment(ScanHistoryStore())
        .environment(AppState())
}
