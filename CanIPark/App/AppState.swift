// AppState.swift
// CanIPark
//
// Central observable state for the app: analysis lifecycle, jurisdiction, permissions.

import Foundation
import SwiftUI
import AVFoundation
import Photos

// MARK: - Jurisdiction

enum AustralianJurisdiction: String, CaseIterable, Identifiable, Codable {
    case nsw = "NSW"
    case vic = "VIC"
    case qld = "QLD"
    case wa  = "WA"
    case sa  = "SA"
    case tas = "TAS"
    case act = "ACT"
    case nt  = "NT"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nsw: return "New South Wales"
        case .vic: return "Victoria"
        case .qld: return "Queensland"
        case .wa:  return "Western Australia"
        case .sa:  return "South Australia"
        case .tas: return "Tasmania"
        case .act: return "Australian Capital Territory"
        case .nt:  return "Northern Territory"
        }
    }
}

// MARK: - Analysis Phase

enum AnalysisPhase: Equatable {
    case idle
    case detectingSigns
    case readingText
    case interpretingRules
    case determiningVerdict
    case complete

    var description: String {
        switch self {
        case .idle:               return "Ready"
        case .detectingSigns:     return "Detecting signs..."
        case .readingText:        return "Reading text..."
        case .interpretingRules:  return "Interpreting rules..."
        case .determiningVerdict: return "Determining verdict..."
        case .complete:           return "Analysis complete"
        }
    }

    var progress: Double {
        switch self {
        case .idle:               return 0.0
        case .detectingSigns:     return 0.25
        case .readingText:        return 0.50
        case .interpretingRules:  return 0.75
        case .determiningVerdict: return 0.90
        case .complete:           return 1.0
        }
    }
}

// MARK: - App State

@Observable
final class AppState {

    // MARK: - Analysis

    var analysisPhase: AnalysisPhase = .idle
    var currentResult: ParkingAnalysisResult?
    var capturedImage: UIImage?
    var analysisError: String?

    var isAnalysing: Bool {
        analysisPhase != .idle && analysisPhase != .complete
    }

    // MARK: - Navigation

    var selectedTab: AppTab = .home
    var showingCamera = false
    var showingResult = false

    // MARK: - Settings

    var selectedJurisdiction: AustralianJurisdiction {
        didSet { UserDefaults.standard.set(selectedJurisdiction.rawValue, forKey: "selectedJurisdiction") }
    }

    // MARK: - Permissions

    var cameraPermission: AVAuthorizationStatus = .notDetermined
    var photoLibraryPermission: PHAuthorizationStatus = .notDetermined

    // MARK: - Init

    init() {
        if let saved = UserDefaults.standard.string(forKey: "selectedJurisdiction"),
           let jurisdiction = AustralianJurisdiction(rawValue: saved) {
            self.selectedJurisdiction = jurisdiction
        } else {
            self.selectedJurisdiction = .nsw
        }
        refreshPermissions()
    }

    // MARK: - Permission Checks

    func refreshPermissions() {
        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        photoLibraryPermission = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestCameraPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            cameraPermission = granted ? .authorized : .denied
        }
    }

    func requestPhotoLibraryPermission() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            photoLibraryPermission = status
        }
    }

    // MARK: - Analysis Lifecycle

    func beginAnalysis(image: UIImage) {
        capturedImage = image
        analysisError = nil
        currentResult = nil
        analysisPhase = .detectingSigns

        Task { @MainActor in
            await runMockAnalysis(image: image)
        }
    }

    func resetAnalysis() {
        analysisPhase = .idle
        currentResult = nil
        capturedImage = nil
        analysisError = nil
        showingResult = false
    }

    /// Simulates analysis pipeline phases. Replace with real Vision/OCR pipeline.
    @MainActor
    private func runMockAnalysis(image: UIImage) async {
        do {
            analysisPhase = .detectingSigns
            try await Task.sleep(for: .milliseconds(800))

            analysisPhase = .readingText
            try await Task.sleep(for: .milliseconds(600))

            analysisPhase = .interpretingRules
            try await Task.sleep(for: .milliseconds(700))

            analysisPhase = .determiningVerdict
            try await Task.sleep(for: .milliseconds(400))

            // Demo result - replace with real OCR + decision engine call
            let demoResult = ParkingAnalysisResult(
                verdict: .canPark,
                confidence: .high,
                timeLimit: "Until 6:00 PM",
                maxStay: "2 hours",
                paymentStatus: "Metered",
                warnings: ["Payment required: use the meter."],
                detectedSigns: [
                    DetectedSign(
                        ocrText: "2P\n8:30AM-6:00PM\nMON-FRI\nTICKET",
                        parsedRestriction: "2-hour timed parking, Mon-Fri 8:30 AM to 6:00 PM, ticketed",
                        confidence: 0.92,
                        arrowDirection: "left"
                    )
                ],
                reasoningChain: [
                    "Detected 1 parking sign",
                    "Read text: \"2P 8:30AM-6:00PM MON-FRI TICKET\"",
                    "Parsed as: 2-hour timed parking with ticket payment",
                    "Current time falls within Mon-Fri 8:30 AM - 6:00 PM window",
                    "Verdict: You can park here for up to 2 hours with a valid ticket"
                ],
                scanDate: Date(),
                locationDescription: nil
            )

            currentResult = demoResult
            analysisPhase = .complete
            showingResult = true
        } catch {
            analysisError = "Analysis was interrupted."
            analysisPhase = .idle
        }
    }
}

// MARK: - Tab

enum AppTab: String, CaseIterable {
    case home
    case history
    case settings

    var title: String {
        switch self {
        case .home:     return "Home"
        case .history:  return "History"
        case .settings: return "Settings"
        }
    }

    var iconName: String {
        switch self {
        case .home:     return "car.fill"
        case .history:  return "clock.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
