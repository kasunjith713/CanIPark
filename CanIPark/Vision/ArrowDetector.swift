// ArrowDetector.swift
// CanIPark
//
// Detects arrow symbols on parking signs through two complementary
// strategies: (1) text-based detection of Unicode arrows and keywords
// such as "BEGIN" / "END", and (2) contour-based shape analysis using
// the Vision framework.

import UIKit
import Vision
import CoreImage

// MARK: - Arrow Detection Result

struct ArrowDetectionResult: Sendable {
    /// Detected arrow direction.
    let direction: ArrowDirection
    /// Confidence of the detection (0-1).
    let confidence: Float
    /// Which detection method produced this result.
    let method: DetectionMethod
    /// Bounding box of the arrow region in normalised Vision coordinates (if available).
    let boundingBox: CGRect?

    enum DetectionMethod: String, Sendable {
        case textBased
        case contourBased
        case combined
    }
}

// MARK: - Arrow Detector

actor ArrowDetector {

    // MARK: Configuration

    struct Configuration: Sendable {
        /// Minimum confidence for contour-based detection.
        var minimumContourConfidence: Float = 0.5
        /// Whether to perform contour analysis (heavier but more accurate).
        var enableContourAnalysis: Bool = true
        /// Minimum area of a contour relative to the ROI to consider it an arrow.
        var minimumContourArea: CGFloat = 0.005
        /// Maximum area of a contour relative to the ROI.
        var maximumContourArea: CGFloat = 0.25

        static let `default` = Configuration()
        static let fast = Configuration(enableContourAnalysis: false)
    }

    private let configuration: Configuration

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Public API

    /// Detect arrows in the full image.
    func detectArrows(in image: UIImage) async throws -> [ArrowDetectionResult] {
        guard let cgImage = image.cgImage else {
            throw ArrowDetectorError.invalidImage
        }
        return try await detectArrows(in: cgImage, regionOfInterest: nil)
    }

    /// Detect arrows within a specific sign region.
    func detectArrows(in image: UIImage, region: CGRect) async throws -> [ArrowDetectionResult] {
        guard let cgImage = image.cgImage else {
            throw ArrowDetectorError.invalidImage
        }
        return try await detectArrows(in: cgImage, regionOfInterest: region)
    }

    /// Detect arrow from OCR text (fast path, no image analysis required).
    func detectArrowFromText(_ text: String) -> ArrowDetectionResult {
        let (direction, confidence) = analyseTextForArrows(text)
        return ArrowDetectionResult(
            direction: direction,
            confidence: confidence,
            method: .textBased,
            boundingBox: nil
        )
    }

    /// Detect arrows using all available methods and merge results.
    func detectArrows(in image: UIImage, ocrText: String?, region: CGRect?) async throws -> ArrowDetectionResult {
        var results: [ArrowDetectionResult] = []

        // Text-based detection.
        if let text = ocrText, !text.isEmpty {
            let textResult = detectArrowFromText(text)
            if textResult.direction != .none {
                results.append(textResult)
            }
        }

        // Contour-based detection.
        if configuration.enableContourAnalysis, let cgImage = image.cgImage {
            let contourResults = try await detectArrowsByContour(in: cgImage, regionOfInterest: region)
            results.append(contentsOf: contourResults)
        }

        return mergeResults(results)
    }

    // MARK: - Text-Based Detection

    private func analyseTextForArrows(_ text: String) -> (ArrowDirection, Float) {
        let upper = text.uppercased()

        // Unicode arrows.
        let hasLeftArrow = upper.contains("\u{2190}") || upper.contains("\u{21E6}") // ← ⇦
            || upper.contains("<-") || upper.contains("<\u{2013}")  // <- <–
            || upper.contains("<\u{2014}")  // <—
        let hasRightArrow = upper.contains("\u{2192}") || upper.contains("\u{21E8}") // → ⇨
            || upper.contains("->") || upper.contains("\u{2013}>")  // –>
            || upper.contains("\u{2014}>")  // —>
        let hasBothArrow = upper.contains("\u{2194}") || upper.contains("\u{21D4}") // ↔ ⇔
            || upper.contains("<->") || upper.contains("<\u{2013}>")

        if hasBothArrow {
            return (.both, 0.90)
        }
        if hasLeftArrow && hasRightArrow {
            return (.both, 0.88)
        }
        if hasLeftArrow {
            return (.left, 0.90)
        }
        if hasRightArrow {
            return (.right, 0.90)
        }

        // Keyword-based detection.
        // "BEGIN" often paired with a direction arrow but can itself indicate the start of a zone.
        // "END" indicates the zone is ending.
        if matchesPattern(upper, #"\bBEGIN\b"#) {
            // BEGIN without a visible arrow often means the restriction starts at this sign.
            // Convention: the arrow typically points in the direction the zone extends.
            // Without an explicit arrow, treat as "both" with lower confidence.
            return (.both, 0.50)
        }

        if matchesPattern(upper, #"\bEND\b"#) {
            // END typically means the zone stops here.
            return (.none, 0.60)
        }

        // Check for textual direction words.
        let hasLeftWord = matchesPattern(upper, #"\bLEFT\b"#)
        let hasRightWord = matchesPattern(upper, #"\bRIGHT\b"#)

        if hasLeftWord && hasRightWord { return (.both, 0.75) }
        if hasLeftWord { return (.left, 0.75) }
        if hasRightWord { return (.right, 0.75) }

        return (.none, 0.0)
    }

    // MARK: - Contour-Based Detection

    private func detectArrows(in cgImage: CGImage, regionOfInterest: CGRect?) async throws -> [ArrowDetectionResult] {
        var results: [ArrowDetectionResult] = []

        // Text-based not available here; proceed with contour if enabled.
        if configuration.enableContourAnalysis {
            let contourResults = try await detectArrowsByContour(in: cgImage, regionOfInterest: regionOfInterest)
            results.append(contentsOf: contourResults)
        }

        return results
    }

    private func detectArrowsByContour(in cgImage: CGImage, regionOfInterest: CGRect?) async throws -> [ArrowDetectionResult] {
        let contours = try await performContourDetection(on: cgImage, regionOfInterest: regionOfInterest)
        return analyseContoursForArrows(contours, regionOfInterest: regionOfInterest)
    }

    private func performContourDetection(on cgImage: CGImage, regionOfInterest: CGRect?) async throws -> [VNContour] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectContoursRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observation = (request.results as? [VNContoursObservation])?.first else {
                    continuation.resume(returning: [])
                    return
                }
                let topLevel = (0..<observation.contourCount).compactMap { index in
                    try? observation.contour(at: index)
                }
                continuation.resume(returning: topLevel)
            }

            request.contrastAdjustment = 2.0
            request.detectsDarkOnLight = true
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

    /// Analyse contour shapes for arrow-like geometry.
    ///
    /// An arrow contour is identified by:
    /// 1. Having a triangular "head" on one side.
    /// 2. Being significantly wider than tall (or tall than wide for vertical arrows).
    /// 3. Having a centroid offset indicating directionality.
    private func analyseContoursForArrows(
        _ contours: [VNContour],
        regionOfInterest: CGRect?
    ) -> [ArrowDetectionResult] {
        var results: [ArrowDetectionResult] = []

        for contour in contours {
            let points = contour.normalizedPoints
            guard points.count >= 5 else { continue }

            let bbox = boundingBox(of: points)
            let area = Double(bbox.width * bbox.height)

            guard area >= configuration.minimumContourArea,
                  area <= configuration.maximumContourArea else {
                continue
            }

            // Compute centroid.
            let centroidX = points.reduce(Float(0)) { $0 + $1.x } / Float(points.count)
            let midX = bbox.origin.x + bbox.width / 2

            // Arrow directionality heuristic: if the centroid is shifted
            // towards one side, the arrow head is on the opposite side.
            let shiftRatio = (CGFloat(centroidX) - midX) / bbox.width

            // Require the shape to be wider than tall (horizontal arrow-like).
            let aspectRatio = bbox.width / bbox.height
            guard aspectRatio > 1.2 else { continue }

            let direction: ArrowDirection
            let confidence: Float

            if abs(shiftRatio) < 0.05 {
                // Nearly centred - could be a double-headed arrow.
                // Check if both ends taper (simplified: skip for now).
                direction = .both
                confidence = 0.45
            } else if shiftRatio > 0.05 {
                // Centroid is right of centre -> arrow points left (head is on left).
                direction = .left
                confidence = min(1.0, Float(abs(shiftRatio)) * 3.0)
            } else {
                direction = .right
                confidence = min(1.0, Float(abs(shiftRatio)) * 3.0)
            }

            guard confidence >= configuration.minimumContourConfidence else { continue }

            results.append(ArrowDetectionResult(
                direction: direction,
                confidence: confidence,
                method: .contourBased,
                boundingBox: bbox
            ))
        }

        return results
    }

    // MARK: - Merging

    private func mergeResults(_ results: [ArrowDetectionResult]) -> ArrowDetectionResult {
        guard !results.isEmpty else {
            return ArrowDetectionResult(direction: .none, confidence: 0, method: .textBased, boundingBox: nil)
        }

        if results.count == 1 {
            return results[0]
        }

        // If text-based and contour-based agree, boost confidence.
        let textResults = results.filter { $0.method == .textBased }
        let contourResults = results.filter { $0.method == .contourBased }

        if let textResult = textResults.first, let contourResult = contourResults.first {
            if textResult.direction == contourResult.direction {
                // Strong agreement.
                let boostedConfidence = min(1.0, max(textResult.confidence, contourResult.confidence) + 0.1)
                return ArrowDetectionResult(
                    direction: textResult.direction,
                    confidence: boostedConfidence,
                    method: .combined,
                    boundingBox: contourResult.boundingBox
                )
            } else {
                // Disagreement - prefer text-based as it is typically more reliable for parking signs.
                return textResult
            }
        }

        // Return highest-confidence result.
        return results.max(by: { $0.confidence < $1.confidence }) ?? results[0]
    }

    // MARK: - Helpers

    private func boundingBox(of points: [SIMD2<Float>]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = CGFloat(first.x)
        var minY = CGFloat(first.y)
        var maxX = CGFloat(first.x)
        var maxY = CGFloat(first.y)
        for point in points.dropFirst() {
            minX = min(minX, CGFloat(point.x))
            minY = min(minY, CGFloat(point.y))
            maxX = max(maxX, CGFloat(point.x))
            maxY = max(maxY, CGFloat(point.y))
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func matchesPattern(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Errors

enum ArrowDetectorError: LocalizedError {
    case invalidImage
    case detectionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image could not be processed for arrow detection."
        case .detectionFailed(let underlying):
            return "Arrow detection failed: \(underlying.localizedDescription)"
        }
    }
}
