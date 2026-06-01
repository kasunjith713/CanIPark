// ImageAnalysisPipeline.swift
// CanIPark
//
// Main orchestrator that takes a UIImage through the full computer
// vision pipeline: quality check -> sign detection -> OCR -> arrow
// detection -> grouping, producing structured results for the
// parking decision engine.

import UIKit
import Foundation

// MARK: - Pipeline Stage

enum PipelineStage: String, Sendable, CaseIterable {
    case qualityCheck    = "Checking image quality"
    case signDetection   = "Detecting signs"
    case textRecognition = "Reading sign text"
    case arrowDetection  = "Detecting arrows"
    case grouping        = "Grouping signs"
    case parsing         = "Interpreting restrictions"

    var order: Int {
        switch self {
        case .qualityCheck:    return 0
        case .signDetection:   return 1
        case .textRecognition: return 2
        case .arrowDetection:  return 3
        case .grouping:        return 4
        case .parsing:         return 5
        }
    }

    /// Progress fraction at the start of this stage (0-1).
    var progressStart: Float {
        Float(order) / Float(PipelineStage.allCases.count)
    }
}

// MARK: - Pipeline Progress

struct PipelineProgress: Sendable {
    let stage: PipelineStage
    let fractionComplete: Float
    let message: String
}

// MARK: - Pipeline Configuration

struct PipelineConfiguration: Sendable {
    /// Whether to run the quality check before processing.
    var runQualityCheck: Bool = true
    /// Whether to abort if quality is below threshold.
    var abortOnPoorQuality: Bool = false
    /// Sign detector configuration.
    var signDetectorConfig: SignDetector.Configuration = .default
    /// OCR configuration.
    var ocrConfig: ParkingSignOCR.Configuration = .default
    /// Arrow detector configuration.
    var arrowDetectorConfig: ArrowDetector.Configuration = .default
    /// Sign grouper configuration.
    var signGrouperConfig: SignGrouper.Configuration = .default
    /// Image quality assessor configuration.
    var qualityConfig: ImageQualityAssessor.Configuration = .default

    static let `default` = PipelineConfiguration()

    static let fast = PipelineConfiguration(
        runQualityCheck: false,
        signDetectorConfig: .default,
        ocrConfig: .fast,
        arrowDetectorConfig: .fast
    )
}

// MARK: - Pipeline Error

enum PipelineError: LocalizedError {
    case invalidImage
    case poorImageQuality(report: ImageQualityReport)
    case noSignsDetected
    case ocrFailed(underlying: Error)
    case cancelled
    case internalError(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The image could not be processed."
        case .poorImageQuality(let report):
            return "Image quality is too low. \(report.guidanceMessages.joined(separator: " "))"
        case .noSignsDetected:
            return "No parking signs were detected in the image."
        case .ocrFailed(let underlying):
            return "Text recognition failed: \(underlying.localizedDescription)"
        case .cancelled:
            return "Analysis was cancelled."
        case .internalError(let message):
            return "Internal pipeline error: \(message)"
        }
    }
}

// MARK: - Pipeline Result

struct PipelineResult: Sendable {
    /// Quality assessment report (nil if quality check was skipped).
    let qualityReport: ImageQualityReport?
    /// Detected sign regions.
    let detectedRegions: [DetectedSignRegion]
    /// Grouped sign poles.
    let signGroups: [SignPoleGroup]
    /// Parsed parking restrictions from all sign groups.
    let restrictions: [ParkingRestriction]
    /// Per-panel OCR results.
    let ocrResults: [SignOCRResult]
    /// Total processing time in seconds.
    let processingTime: TimeInterval
    /// Overall pipeline confidence (0-1).
    let confidence: Float

    /// Convenience: all OCR text concatenated.
    var allText: String {
        ocrResults.map(\.fullText).joined(separator: "\n\n")
    }

    /// Number of sign panels detected.
    var panelCount: Int { detectedRegions.count }

    /// Number of sign groups (poles).
    var groupCount: Int { signGroups.count }
}

// MARK: - Image Analysis Pipeline

actor ImageAnalysisPipeline {

    private let configuration: PipelineConfiguration
    private let signDetector: SignDetector
    private let ocr: ParkingSignOCR
    private let arrowDetector: ArrowDetector
    private let signGrouper: SignGrouper
    private let qualityAssessor: ImageQualityAssessor

    private var isCancelled = false

    init(configuration: PipelineConfiguration = .default) {
        self.configuration = configuration
        self.signDetector = SignDetector(configuration: configuration.signDetectorConfig)
        self.ocr = ParkingSignOCR(configuration: configuration.ocrConfig)
        self.arrowDetector = ArrowDetector(configuration: configuration.arrowDetectorConfig)
        self.signGrouper = SignGrouper(configuration: configuration.signGrouperConfig)
        self.qualityAssessor = ImageQualityAssessor(configuration: configuration.qualityConfig)
    }

    // MARK: - Cancellation

    func cancel() {
        isCancelled = true
    }

    private func checkCancellation() throws {
        if isCancelled { throw PipelineError.cancelled }
    }

    // MARK: - Main Pipeline

    /// Run the full analysis pipeline on an image.
    func analyse(image: UIImage) async throws -> PipelineResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        isCancelled = false

        // 1. Quality check.
        var qualityReport: ImageQualityReport?
        if configuration.runQualityCheck {
            let report = qualityAssessor.assess(image: image)
            qualityReport = report

            if configuration.abortOnPoorQuality && !report.isAcceptable {
                throw PipelineError.poorImageQuality(report: report)
            }
        }

        try checkCancellation()

        // 2. Sign detection.
        let detectedRegions: [DetectedSignRegion]
        do {
            detectedRegions = try await signDetector.detectSigns(in: image)
        } catch {
            throw PipelineError.internalError("Sign detection failed: \(error.localizedDescription)")
        }

        // Update quality report with sign regions if available.
        if configuration.runQualityCheck && !detectedRegions.isEmpty {
            qualityReport = qualityAssessor.assess(image: image, detectedSignRegions: detectedRegions)
        }

        try checkCancellation()

        // 3. OCR on each detected region (or full image if no regions).
        let ocrResults: [SignOCRResult]
        if detectedRegions.isEmpty {
            // No rectangles detected; try full-image OCR.
            let fullResult = try await ocr.recogniseText(in: image)
            if fullResult.isEmpty {
                throw PipelineError.noSignsDetected
            }
            ocrResults = [fullResult]
        } else {
            ocrResults = try await ocr.recogniseText(in: image, regions: detectedRegions)
        }

        try checkCancellation()

        // 4. Arrow detection on each region.
        var arrowResults: [ArrowDetectionResult] = []
        if detectedRegions.isEmpty {
            // Use text-only arrow detection from the full OCR.
            let textArrow = await arrowDetector.detectArrowFromText(ocrResults.first?.fullText ?? "")
            arrowResults = [textArrow]
        } else {
            for (i, region) in detectedRegions.enumerated() {
                let ocrText = i < ocrResults.count ? ocrResults[i].fullText : nil
                let result = try await arrowDetector.detectArrows(
                    in: image,
                    ocrText: ocrText,
                    region: region.boundingBox
                )
                arrowResults.append(result)
            }
        }

        try checkCancellation()

        // 5. Grouping.
        let groups: [SignPoleGroup]
        if detectedRegions.isEmpty {
            // Single group from full-image OCR.
            let panel = SignPanel(
                region: DetectedSignRegion(
                    boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
                    confidence: 0.5,
                    observation: makeDummyObservation()
                ),
                ocrResult: ocrResults[0],
                arrowResult: arrowResults[0]
            )
            groups = [SignPoleGroup(
                panels: [panel],
                combinedBoundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
                effectiveArrowDirection: arrowResults[0].direction,
                groupingConfidence: 0.5
            )]
        } else {
            groups = signGrouper.groupIntoPoles(
                regions: detectedRegions,
                ocrResults: ocrResults,
                arrowResults: arrowResults
            )
        }

        try checkCancellation()

        // 6. Parse restrictions from OCR text.
        var allRestrictions: [ParkingRestriction] = []
        for group in groups {
            let combinedText = group.combinedText
            let parsed = SignTextParser.parse(ocrText: combinedText)
            allRestrictions.append(contentsOf: parsed)
        }

        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        let confidence = computeOverallConfidence(
            qualityReport: qualityReport,
            ocrResults: ocrResults,
            groups: groups,
            restrictions: allRestrictions
        )

        return PipelineResult(
            qualityReport: qualityReport,
            detectedRegions: detectedRegions,
            signGroups: groups,
            restrictions: allRestrictions,
            ocrResults: ocrResults,
            processingTime: processingTime,
            confidence: confidence
        )
    }

    // MARK: - Overall Confidence

    private func computeOverallConfidence(
        qualityReport: ImageQualityReport?,
        ocrResults: [SignOCRResult],
        groups: [SignPoleGroup],
        restrictions: [ParkingRestriction]
    ) -> Float {
        var factors: [Float] = []

        // Quality factor.
        if let quality = qualityReport {
            factors.append(quality.overallScore)
        }

        // Average OCR confidence.
        let ocrConfidences = ocrResults.map(\.confidence)
        if !ocrConfidences.isEmpty {
            factors.append(ocrConfidences.reduce(0, +) / Float(ocrConfidences.count))
        }

        // Grouping confidence.
        let groupConfidences = groups.map(\.groupingConfidence)
        if !groupConfidences.isEmpty {
            factors.append(groupConfidences.reduce(0, +) / Float(groupConfidences.count))
        }

        // Restriction parsing confidence.
        let restrictionConfidences = restrictions.map { Float($0.confidence) }
        if !restrictionConfidences.isEmpty {
            factors.append(restrictionConfidences.reduce(0, +) / Float(restrictionConfidences.count))
        }

        guard !factors.isEmpty else { return 0.0 }
        return factors.reduce(0, +) / Float(factors.count)
    }

    // MARK: - Helpers

    /// Create a dummy VNRectangleObservation for the full-image fallback path.
    private nonisolated func makeDummyObservation() -> VNRectangleObservation {
        // VNRectangleObservation doesn't have a public initialiser with
        // corner points, but we can use the class method on VNDetectedObjectObservation.
        // In practice this is only used as a placeholder when no regions were detected.
        return VNRectangleObservation(boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}

// MARK: - Progress-Reporting Pipeline

/// A wrapper around ImageAnalysisPipeline that emits progress updates
/// via an AsyncStream, suitable for driving a progress UI.
actor ProgressReportingPipeline {

    private let pipeline: ImageAnalysisPipeline
    private let configuration: PipelineConfiguration

    init(configuration: PipelineConfiguration = .default) {
        self.configuration = configuration
        self.pipeline = ImageAnalysisPipeline(configuration: configuration)
    }

    /// Analyse an image and stream progress updates.
    ///
    /// Returns a tuple of (progress stream, result task). The caller should
    /// iterate the stream for UI updates and await the task for the final result.
    func analyse(image: UIImage) -> (AsyncStream<PipelineProgress>, Task<PipelineResult, Error>) {
        let (stream, continuation) = AsyncStream<PipelineProgress>.makeStream()

        let task = Task { [pipeline, configuration] () -> PipelineResult in
            defer { continuation.finish() }

            func report(_ stage: PipelineStage) {
                continuation.yield(PipelineProgress(
                    stage: stage,
                    fractionComplete: stage.progressStart,
                    message: stage.rawValue
                ))
            }

            let startTime = CFAbsoluteTimeGetCurrent()

            // Quality check.
            var qualityReport: ImageQualityReport?
            if configuration.runQualityCheck {
                report(.qualityCheck)
                let assessor = ImageQualityAssessor(configuration: configuration.qualityConfig)
                qualityReport = assessor.assess(image: image)
                if configuration.abortOnPoorQuality, let report = qualityReport, !report.isAcceptable {
                    throw PipelineError.poorImageQuality(report: report)
                }
            }

            try Task.checkCancellation()

            // Sign detection.
            report(.signDetection)
            let detector = SignDetector(configuration: configuration.signDetectorConfig)
            let regions = try await detector.detectSigns(in: image)

            if configuration.runQualityCheck && !regions.isEmpty {
                let assessor = ImageQualityAssessor(configuration: configuration.qualityConfig)
                qualityReport = assessor.assess(image: image, detectedSignRegions: regions)
            }

            try Task.checkCancellation()

            // OCR.
            report(.textRecognition)
            let ocr = ParkingSignOCR(configuration: configuration.ocrConfig)
            let ocrResults: [SignOCRResult]
            if regions.isEmpty {
                let full = try await ocr.recogniseText(in: image)
                if full.isEmpty { throw PipelineError.noSignsDetected }
                ocrResults = [full]
            } else {
                ocrResults = try await ocr.recogniseText(in: image, regions: regions)
            }

            try Task.checkCancellation()

            // Arrow detection.
            report(.arrowDetection)
            let arrowDet = ArrowDetector(configuration: configuration.arrowDetectorConfig)
            var arrowResults: [ArrowDetectionResult] = []
            if regions.isEmpty {
                let textArrow = await arrowDet.detectArrowFromText(ocrResults.first?.fullText ?? "")
                arrowResults = [textArrow]
            } else {
                for (i, region) in regions.enumerated() {
                    let text = i < ocrResults.count ? ocrResults[i].fullText : nil
                    let result = try await arrowDet.detectArrows(in: image, ocrText: text, region: region.boundingBox)
                    arrowResults.append(result)
                }
            }

            try Task.checkCancellation()

            // Grouping.
            report(.grouping)
            let grouper = SignGrouper(configuration: configuration.signGrouperConfig)
            let groups: [SignPoleGroup]
            if regions.isEmpty {
                let dummyObs = VNRectangleObservation(boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1))
                let panel = SignPanel(
                    region: DetectedSignRegion(boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
                                              confidence: 0.5, observation: dummyObs),
                    ocrResult: ocrResults[0],
                    arrowResult: arrowResults[0]
                )
                groups = [SignPoleGroup(
                    panels: [panel],
                    combinedBoundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
                    effectiveArrowDirection: arrowResults[0].direction,
                    groupingConfidence: 0.5
                )]
            } else {
                groups = grouper.groupIntoPoles(regions: regions, ocrResults: ocrResults, arrowResults: arrowResults)
            }

            try Task.checkCancellation()

            // Parsing.
            report(.parsing)
            var allRestrictions: [ParkingRestriction] = []
            for group in groups {
                let parsed = SignTextParser.parse(ocrText: group.combinedText)
                allRestrictions.append(contentsOf: parsed)
            }

            let processingTime = CFAbsoluteTimeGetCurrent() - startTime

            // Compute confidence.
            var factors: [Float] = []
            if let q = qualityReport { factors.append(q.overallScore) }
            let avgOCR = ocrResults.isEmpty ? Float(0) : ocrResults.map(\.confidence).reduce(0, +) / Float(ocrResults.count)
            factors.append(avgOCR)
            let avgGroup = groups.isEmpty ? Float(0) : groups.map(\.groupingConfidence).reduce(0, +) / Float(groups.count)
            factors.append(avgGroup)
            let avgRestriction = allRestrictions.isEmpty ? Float(0) : allRestrictions.map { Float($0.confidence) }.reduce(0, +) / Float(allRestrictions.count)
            factors.append(avgRestriction)
            let confidence = factors.isEmpty ? Float(0) : factors.reduce(0, +) / Float(factors.count)

            continuation.yield(PipelineProgress(stage: .parsing, fractionComplete: 1.0, message: "Done"))

            return PipelineResult(
                qualityReport: qualityReport,
                detectedRegions: regions,
                signGroups: groups,
                restrictions: allRestrictions,
                ocrResults: ocrResults,
                processingTime: processingTime,
                confidence: confidence
            )
        }

        return (stream, task)
    }

    /// Cancel the current pipeline run.
    func cancel() async {
        await pipeline.cancel()
    }
}

// MARK: - Import for VNRectangleObservation
import Vision
