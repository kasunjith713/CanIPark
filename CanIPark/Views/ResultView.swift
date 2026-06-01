// ResultView.swift
// CanIPark
//
// THE MOST IMPORTANT SCREEN.
// Displays the parking verdict with all supporting details.

import SwiftUI

struct ResultView: View {

    let result: ParkingAnalysisResult
    let capturedImage: UIImage?

    @Environment(AppState.self) private var appState
    @Environment(ScanHistoryStore.self) private var historyStore
    @Environment(\.dismiss) private var dismiss

    @State private var showDetails = false
    @State private var showEvidence = false
    @State private var saved = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    verdictBanner
                    timeInfoSection
                    warningsSection
                    confidenceBadge
                    actionButtons
                    detailsSection
                }
                .padding()
            }
            .background(backgroundGradient)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share result")
                }
            }
            .sheet(isPresented: $showEvidence) {
                EvidenceDetailView(result: result)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareText])
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [verdictColor.opacity(0.08), Color(.systemBackground)],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }

    // MARK: - Verdict Banner

    private var verdictBanner: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: result.verdict.iconName)
                .font(.system(size: 72))
                .foregroundStyle(verdictColor)
                .symbolEffect(.bounce, value: result.verdict)
                .accessibilityHidden(true)

            // Headline
            Text(result.verdict.headline)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(verdictColor)
                .multilineTextAlignment(.center)
                .accessibilityLabel(result.verdict.headline)
                .accessibilityAddTraits(.isHeader)

            // Scan time
            Text("Scanned \(result.scanDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    // MARK: - Time Info

    @ViewBuilder
    private var timeInfoSection: some View {
        let hasTimeInfo = result.timeLimit != nil || result.maxStay != nil || result.paymentStatus != nil

        if hasTimeInfo {
            VStack(spacing: 0) {
                if let timeLimit = result.timeLimit {
                    infoRow(icon: "clock.fill", label: "Time", value: timeLimit)
                    if result.maxStay != nil || result.paymentStatus != nil {
                        Divider().padding(.leading, 44)
                    }
                }

                if let maxStay = result.maxStay {
                    infoRow(icon: "hourglass", label: "Max Stay", value: maxStay)
                    if result.paymentStatus != nil {
                        Divider().padding(.leading, 44)
                    }
                }

                if let payment = result.paymentStatus {
                    infoRow(
                        icon: payment.lowercased() == "free" ? "banknote" : "creditcard.fill",
                        label: "Payment",
                        value: payment
                    )
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Parking details")
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(verdictColor)
                .frame(width: 32)
                .accessibilityHidden(true)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Warnings

    @ViewBuilder
    private var warningsSection: some View {
        if !result.warnings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(result.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)

                        Text(warning)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Warning: \(warning)")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Confidence Badge

    private var confidenceBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: result.confidence.iconName)
                .foregroundStyle(confidenceColor)

            Text("\(result.confidence.displayName) Confidence")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(confidenceColor.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Confidence level: \(result.confidence.displayName)")
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save scan
            Button {
                saveScan()
            } label: {
                Label(saved ? "Saved" : "Save Scan", systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(saved ? .green : .blue)
            .disabled(saved)
            .accessibilityLabel(saved ? "Scan saved" : "Save this scan")

            HStack(spacing: 12) {
                // Scan again
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        appState.resetAnalysis()
                        appState.showingCamera = true
                    }
                } label: {
                    Label("Scan Again", systemImage: "camera.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Scan another sign")

                // View evidence
                Button {
                    showEvidence = true
                } label: {
                    Label("Evidence", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("View evidence and reasoning")
            }
        }
    }

    // MARK: - Expandable Details

    private var detailsSection: some View {
        DisclosureGroup("Details", isExpanded: $showDetails) {
            VStack(alignment: .leading, spacing: 12) {
                if !result.detectedSigns.isEmpty {
                    detailLabel("Signs Detected", value: "\(result.detectedSigns.count)")
                }

                if let location = result.locationDescription {
                    detailLabel("Location", value: location)
                }

                detailLabel("Scan Date", value: result.scanDate.formatted(date: .long, time: .shortened))

                detailLabel("Verdict", value: result.verdict.headline)

                if !result.reasoningChain.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reasoning")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(Array(result.reasoningChain.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 6) {
                                Text("\(index + 1).")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Text(step)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    private func detailLabel(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Helpers

    private var verdictColor: Color {
        switch result.verdict {
        case .canPark:    return .green
        case .cannotPark: return .red
        case .uncertain:  return .orange
        }
    }

    private var confidenceColor: Color {
        switch result.confidence {
        case .high:   return .green
        case .medium: return .orange
        case .low:    return .red
        }
    }

    private var shareText: String {
        var text = "CanIPark Result: \(result.verdict.headline)"
        if let timeLimit = result.timeLimit {
            text += "\nTime: \(timeLimit)"
        }
        if let maxStay = result.maxStay {
            text += "\nMax Stay: \(maxStay)"
        }
        if let payment = result.paymentStatus {
            text += "\nPayment: \(payment)"
        }
        if !result.warnings.isEmpty {
            text += "\nWarnings: \(result.warnings.joined(separator: "; "))"
        }
        text += "\nConfidence: \(result.confidence.displayName)"
        text += "\nScanned: \(result.scanDate.formatted(date: .abbreviated, time: .shortened))"
        return text
    }

    private func saveScan() {
        var thumbnailData: Data?
        if let image = capturedImage {
            thumbnailData = image.jpegData(compressionQuality: 0.5)
        }
        historyStore.add(result, thumbnailData: thumbnailData)
        saved = true
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("Can Park") {
    ResultView(
        result: ParkingAnalysisResult(
            verdict: .canPark,
            confidence: .high,
            timeLimit: "Until 6:00 PM",
            maxStay: "2 hours",
            paymentStatus: "Metered",
            warnings: ["Payment required: use the meter."],
            detectedSigns: [
                DetectedSign(ocrText: "2P 8:30AM-6:00PM MON-FRI TICKET", parsedRestriction: "2-hour timed parking", confidence: 0.92)
            ],
            reasoningChain: [
                "Detected 1 parking sign",
                "Read text: \"2P 8:30AM-6:00PM MON-FRI TICKET\"",
                "Parsed as 2-hour timed parking, Mon-Fri",
                "Current time is within restricted window",
                "Verdict: You can park here for up to 2 hours"
            ]
        ),
        capturedImage: nil
    )
    .environment(AppState())
    .environment(ScanHistoryStore())
}

#Preview("Cannot Park") {
    ResultView(
        result: ParkingAnalysisResult(
            verdict: .cannotPark,
            confidence: .high,
            warnings: ["No stopping means you cannot stop your vehicle here at all."],
            detectedSigns: [
                DetectedSign(ocrText: "NO STOPPING", parsedRestriction: "No stopping at any time", confidence: 0.97)
            ],
            reasoningChain: ["Detected no stopping sign", "Applies 24/7", "Verdict: You cannot park here"]
        ),
        capturedImage: nil
    )
    .environment(AppState())
    .environment(ScanHistoryStore())
}

#Preview("Uncertain") {
    ResultView(
        result: ParkingAnalysisResult(
            verdict: .uncertain,
            confidence: .low,
            warnings: ["The sign could not be fully interpreted."],
            reasoningChain: ["Could not read sign text clearly"]
        ),
        capturedImage: nil
    )
    .environment(AppState())
    .environment(ScanHistoryStore())
}
