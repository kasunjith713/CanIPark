// ParkingSignOCR.swift
// CanIPark
//
// Performs on-device text recognition on parking sign images using the
// Vision framework, with a custom vocabulary tuned for Australian
// parking sign terminology.

import UIKit
import Vision

// MARK: - OCR Result

struct SignOCRResult: Sendable {
    /// The full recognised text, lines joined by newlines.
    let fullText: String
    /// Individual lines of text with their confidence and bounding boxes.
    let lines: [RecognisedLine]
    /// Overall confidence across all lines (0-1).
    let confidence: Float
    /// The region of interest that was scanned (normalised Vision coordinates).
    let regionOfInterest: CGRect?

    struct RecognisedLine: Sendable {
        let text: String
        let confidence: Float
        let boundingBox: CGRect
    }

    /// True when no text was found.
    var isEmpty: Bool { fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// MARK: - Parking Sign OCR

actor ParkingSignOCR {

    // MARK: Configuration

    struct Configuration: Sendable {
        /// Recognition level (.accurate or .fast).
        var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
        /// Minimum height of text to recognise (fraction of image, 0-1).
        var minimumTextHeight: Float = 0.0
        /// Use language correction.
        var usesLanguageCorrection: Bool = true
        /// Recognition languages.
        var recognitionLanguages: [String] = ["en-AU", "en-GB", "en-US"]
        /// Minimum confidence to accept a text observation.
        var minimumConfidence: Float = 0.25

        static let `default` = Configuration()

        static let fast = Configuration(
            recognitionLevel: .fast,
            usesLanguageCorrection: false
        )
    }

    private let configuration: Configuration

    /// Custom vocabulary of parking-sign terms to boost recognition accuracy.
    static let parkingVocabulary: [String] = [
        // Sign categories
        "NO STOPPING", "NO PARKING", "CLEARWAY", "LOADING ZONE",
        "BUS ZONE", "TAXI ZONE", "TRUCK ZONE", "WORKS ZONE",
        "MAIL ZONE", "PERMIT ZONE", "PERMIT HOLDERS ONLY",
        "ACCESSIBLE", "DISABILITY", "ACROD", "EV CHARGING",
        // Time tokens
        "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN",
        "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY",
        "AM", "PM", "MIDNIGHT", "NOON",
        // Duration tokens
        "MIN", "MINS", "MINUTE", "MINUTES", "HOUR", "HOURS", "HR", "HRS",
        "1/2P", "1/4P", "1P", "2P", "3P", "4P", "5P", "10P",
        // Payment
        "METER", "TICKET", "PAY HERE", "PAY & DISPLAY", "PAY BY APP",
        "APP PARKING", "FREE",
        // Exemptions
        "EXCEPT BUSES", "EXCEPT TAXIS", "EXCEPT TRUCKS",
        "PERMIT HOLDERS EXCEPTED", "EXCEPT PERMIT HOLDERS",
        "EMERGENCY VEHICLES", "MOTORCYCLES", "BICYCLES",
        // Directional / modifier
        "BEGIN", "END", "AREA", "AHEAD",
        "SCHOOL DAYS", "SCHOOL ZONE", "PUBLIC HOLIDAY",
        // Arrow text representations
        "LEFT", "RIGHT",
        // Other common sign words
        "TIMED", "PARKING", "ZONE", "ONLY",
        "AT ALL TIMES", "OTHER TIMES",
    ]

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Full Image OCR

    /// Recognise text in the entire image.
    func recogniseText(in image: UIImage) async throws -> SignOCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        return try await recogniseText(in: cgImage, regionOfInterest: nil)
    }

    // MARK: - Region-of-Interest OCR

    /// Recognise text within a specific region of the image.
    /// - Parameter region: Normalised bounding box in Vision coordinates (origin bottom-left).
    func recogniseText(in image: UIImage, region: CGRect) async throws -> SignOCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        return try await recogniseText(in: cgImage, regionOfInterest: region)
    }

    /// Recognise text for each detected sign region independently.
    func recogniseText(in image: UIImage, regions: [DetectedSignRegion]) async throws -> [SignOCRResult] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        var results: [SignOCRResult] = []
        for region in regions {
            let result = try await recogniseText(in: cgImage, regionOfInterest: region.boundingBox)
            results.append(result)
        }
        return results
    }

    // MARK: - Core Recognition

    private func recogniseText(in cgImage: CGImage, regionOfInterest: CGRect?) async throws -> SignOCRResult {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: SignOCRResult(
                        fullText: "",
                        lines: [],
                        confidence: 0,
                        regionOfInterest: regionOfInterest
                    ))
                    return
                }

                let result = Self.buildResult(
                    from: observations,
                    minimumConfidence: self.configuration.minimumConfidence,
                    regionOfInterest: regionOfInterest
                )
                continuation.resume(returning: result)
            }

            request.recognitionLevel = configuration.recognitionLevel
            request.usesLanguageCorrection = configuration.usesLanguageCorrection
            request.recognitionLanguages = configuration.recognitionLanguages
            request.minimumTextHeight = configuration.minimumTextHeight
            request.customWords = Self.parkingVocabulary

            if let roi = regionOfInterest {
                request.regionOfInterest = roi
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Result Building

    private static func buildResult(
        from observations: [VNRecognizedTextObservation],
        minimumConfidence: Float,
        regionOfInterest: CGRect?
    ) -> SignOCRResult {
        var lines: [SignOCRResult.RecognisedLine] = []

        // Sort observations top-to-bottom (highest y first in Vision coordinates).
        let sorted = observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }

        for observation in sorted {
            guard observation.confidence >= minimumConfidence,
                  let candidate = observation.topCandidates(1).first else {
                continue
            }

            lines.append(SignOCRResult.RecognisedLine(
                text: candidate.string,
                confidence: candidate.confidence ?? observation.confidence,
                boundingBox: observation.boundingBox
            ))
        }

        let fullText = lines.map(\.text).joined(separator: "\n")
        let averageConfidence: Float = lines.isEmpty ? 0 :
            lines.reduce(Float(0)) { $0 + $1.confidence } / Float(lines.count)

        return SignOCRResult(
            fullText: fullText,
            lines: lines,
            confidence: averageConfidence,
            regionOfInterest: regionOfInterest
        )
    }
}

// MARK: - Errors

enum OCRError: LocalizedError {
    case invalidImage
    case recognitionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image could not be processed for text recognition."
        case .recognitionFailed(let underlying):
            return "Text recognition failed: \(underlying.localizedDescription)"
        }
    }
}
