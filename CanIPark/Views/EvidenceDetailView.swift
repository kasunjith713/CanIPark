// EvidenceDetailView.swift
// CanIPark
//
// Shows detected signs, OCR text, and the reasoning chain behind the verdict.

import SwiftUI

struct EvidenceDetailView: View {

    let result: ParkingAnalysisResult

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Summary
                summarySection

                // Detected Signs
                if !result.detectedSigns.isEmpty {
                    detectedSignsSection
                }

                // Reasoning Chain
                if !result.reasoningChain.isEmpty {
                    reasoningSection
                }

                // Warnings
                if !result.warnings.isEmpty {
                    warningsSection
                }
            }
            .navigationTitle("Evidence")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section {
            HStack {
                Image(systemName: result.verdict.iconName)
                    .font(.title2)
                    .foregroundStyle(verdictColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.verdict.headline)
                        .font(.headline)
                        .foregroundStyle(verdictColor)

                    Text("Confidence: \(result.confidence.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(result.verdict.headline), \(result.confidence.displayName) confidence")

            if let timeLimit = result.timeLimit {
                Label(timeLimit, systemImage: "clock.fill")
                    .font(.subheadline)
                    .accessibilityLabel("Time limit: \(timeLimit)")
            }

            if let maxStay = result.maxStay {
                Label("Max stay: \(maxStay)", systemImage: "hourglass")
                    .font(.subheadline)
                    .accessibilityLabel("Maximum stay: \(maxStay)")
            }

            if let payment = result.paymentStatus {
                Label("Payment: \(payment)", systemImage: "creditcard.fill")
                    .font(.subheadline)
                    .accessibilityLabel("Payment: \(payment)")
            }
        } header: {
            Text("Summary")
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Detected Signs

    private var detectedSignsSection: some View {
        Section {
            ForEach(Array(result.detectedSigns.enumerated()), id: \.element.id) { index, sign in
                VStack(alignment: .leading, spacing: 10) {
                    // Sign header
                    HStack {
                        Label("Sign \(index + 1)", systemImage: "rectangle.and.text.magnifyingglass")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        confidencePill(sign.confidence)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Sign \(index + 1), \(Int(sign.confidence * 100)) percent confidence")

                    // OCR Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OCR Text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(sign.ocrText)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("OCR text: \(sign.ocrText)")

                    // Parsed restriction
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Interpreted As")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(sign.parsedRestriction)
                            .font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Interpreted as: \(sign.parsedRestriction)")

                    // Arrow direction
                    if let arrow = sign.arrowDirection, arrow != "none" {
                        Label("Arrow: \(arrow)", systemImage: arrowIcon(arrow))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Arrow direction: \(arrow)")
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Detected Signs (\(result.detectedSigns.count))")
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Reasoning Chain

    private var reasoningSection: some View {
        Section {
            ForEach(Array(result.reasoningChain.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(.blue, in: Circle())
                        .accessibilityHidden(true)

                    Text(step)
                        .font(.subheadline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Step \(index + 1): \(step)")
            }
        } header: {
            Text("Reasoning Chain")
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Warnings

    private var warningsSection: some View {
        Section {
            ForEach(result.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Warning: \(warning)")
            }
        } header: {
            Text("Warnings")
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Helpers

    private func confidencePill(_ confidence: Double) -> some View {
        let percent = Int(confidence * 100)
        let color: Color = confidence >= 0.75 ? .green : (confidence >= 0.5 ? .orange : .red)
        return Text("\(percent)%")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private func arrowIcon(_ direction: String) -> String {
        switch direction.lowercased() {
        case "left":  return "arrow.left"
        case "right": return "arrow.right"
        case "both":  return "arrow.left.arrow.right"
        default:      return "minus"
        }
    }

    private var verdictColor: Color {
        switch result.verdict {
        case .canPark:    return .green
        case .cannotPark: return .red
        case .uncertain:  return .orange
        }
    }
}

#Preview {
    EvidenceDetailView(
        result: ParkingAnalysisResult(
            verdict: .canPark,
            confidence: .high,
            timeLimit: "Until 6:00 PM",
            maxStay: "2 hours",
            paymentStatus: "Metered",
            warnings: ["Payment required: use the meter.", "Restrictions apply at other times."],
            detectedSigns: [
                DetectedSign(
                    ocrText: "2P\n8:30AM-6:00PM\nMON-FRI\nTICKET",
                    parsedRestriction: "2-hour timed parking, Mon-Fri 8:30 AM to 6:00 PM, ticketed",
                    confidence: 0.92,
                    arrowDirection: "left"
                ),
                DetectedSign(
                    ocrText: "NO PARKING\n6PM-8:30AM\nMON-FRI",
                    parsedRestriction: "No parking, Mon-Fri 6:00 PM to 8:30 AM",
                    confidence: 0.88,
                    arrowDirection: "left"
                )
            ],
            reasoningChain: [
                "Detected 2 parking signs on the sign post",
                "Sign 1: \"2P 8:30AM-6:00PM MON-FRI TICKET\"",
                "Sign 2: \"NO PARKING 6PM-8:30AM MON-FRI\"",
                "Parsed sign 1 as: 2-hour timed parking with ticket payment",
                "Parsed sign 2 as: No parking zone (off-hours)",
                "Current time falls within the 2P timed parking window",
                "Verdict: You can park here for up to 2 hours with a valid ticket"
            ]
        )
    )
}
