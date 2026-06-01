// ImageQualityAssessor.swift
// CanIPark
//
// Assesses image quality for parking sign recognition by checking
// blur (Laplacian variance), exposure level, and sign size. Returns
// actionable guidance messages such as "Move closer" or "Too blurry".

import UIKit
import CoreImage
import Accelerate

// MARK: - Image Quality Report

struct ImageQualityReport: Sendable {
    /// Overall quality score (0-1). Values above 0.6 are generally acceptable.
    let overallScore: Float
    /// Individual quality dimension scores.
    let blurScore: Float
    let exposureScore: Float
    let signSizeScore: Float
    let contrastScore: Float
    /// Whether the image is usable for OCR.
    let isAcceptable: Bool
    /// Human-readable guidance messages for the user.
    let guidanceMessages: [String]
    /// Severity level of the quality issues found.
    let severity: Severity

    enum Severity: String, Sendable {
        case good
        case acceptable
        case poor
        case unusable
    }
}

// MARK: - Image Quality Assessor

struct ImageQualityAssessor {

    // MARK: Configuration

    struct Configuration: Sendable {
        /// Minimum Laplacian variance to consider the image sharp enough.
        var minimumSharpness: Float = 50.0
        /// Ideal mean luminance range (0-255).
        var idealLuminanceRange: ClosedRange<Float> = 60...200
        /// Minimum sign area as a fraction of total image area.
        var minimumSignAreaFraction: Float = 0.01
        /// Ideal sign area fraction.
        var idealSignAreaFraction: Float = 0.10
        /// Overall score threshold below which image is unacceptable.
        var acceptableThreshold: Float = 0.45

        static let `default` = Configuration()
    }

    private let configuration: Configuration

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Assessment API

    /// Assess the quality of an image for parking sign recognition.
    func assess(image: UIImage, detectedSignRegions: [DetectedSignRegion] = []) -> ImageQualityReport {
        guard let cgImage = image.cgImage else {
            return makeUnusableReport(reason: "Unable to process image.")
        }

        let blurScore = assessBlur(cgImage: cgImage)
        let exposureScore = assessExposure(cgImage: cgImage)
        let contrastScore = assessContrast(cgImage: cgImage)
        let signSizeScore = assessSignSize(regions: detectedSignRegions)

        // Weighted overall score.
        let overallScore =
            blurScore * 0.35 +
            exposureScore * 0.25 +
            signSizeScore * 0.25 +
            contrastScore * 0.15

        let guidance = buildGuidance(
            blurScore: blurScore,
            exposureScore: exposureScore,
            signSizeScore: signSizeScore,
            contrastScore: contrastScore,
            hasDetections: !detectedSignRegions.isEmpty
        )

        let severity = classifySeverity(overallScore)

        return ImageQualityReport(
            overallScore: overallScore,
            blurScore: blurScore,
            exposureScore: exposureScore,
            signSizeScore: signSizeScore,
            contrastScore: contrastScore,
            isAcceptable: overallScore >= configuration.acceptableThreshold,
            guidanceMessages: guidance,
            severity: severity
        )
    }

    /// Quick blur-only check for live preview frames.
    func quickBlurCheck(pixelBuffer: CVPixelBuffer) -> Float {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return laplacianVariance(from: ciImage)
    }

    // MARK: - Blur Assessment (Laplacian Variance)

    private func assessBlur(cgImage: CGImage) -> Float {
        let ciImage = CIImage(cgImage: cgImage)
        let variance = laplacianVariance(from: ciImage)

        // Map variance to a 0-1 score.
        // Below minimum -> poor; above 2x minimum -> excellent.
        let ratio = variance / configuration.minimumSharpness
        return min(1.0, max(0.0, ratio))
    }

    /// Compute Laplacian variance as a measure of image sharpness.
    private func laplacianVariance(from ciImage: CIImage) -> Float {
        let context = CIContext(options: [.useSoftwareRenderer: false])

        // Downscale for performance.
        let maxDimension: CGFloat = 512
        let extent = ciImage.extent
        let scale = min(maxDimension / extent.width, maxDimension / extent.height, 1.0)
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Convert to grayscale.
        guard let grayscaleFilter = CIFilter(name: "CIPhotoEffectMono") else { return 0 }
        grayscaleFilter.setValue(scaled, forKey: kCIInputImageKey)
        guard let grayscale = grayscaleFilter.outputImage else { return 0 }

        let outputExtent = grayscale.extent
        let width = Int(outputExtent.width)
        let height = Int(outputExtent.height)
        guard width > 2, height > 2 else { return 0 }

        // Render to a pixel buffer.
        var pixelData = [UInt8](repeating: 0, count: width * height)
        context.render(
            grayscale,
            toBitmap: &pixelData,
            rowBytes: width,
            bounds: outputExtent,
            format: .L8,
            colorSpace: CGColorSpaceCreateDeviceGray()
        )

        // Apply 3x3 Laplacian kernel: [0,1,0; 1,-4,1; 0,1,0]
        var sum: Float = 0
        var sumSq: Float = 0
        var count: Int = 0

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = Float(pixelData[y * width + x])
                let top    = Float(pixelData[(y - 1) * width + x])
                let bottom = Float(pixelData[(y + 1) * width + x])
                let left   = Float(pixelData[y * width + (x - 1)])
                let right  = Float(pixelData[y * width + (x + 1)])

                let laplacian = top + bottom + left + right - 4 * center
                sum += laplacian
                sumSq += laplacian * laplacian
                count += 1
            }
        }

        guard count > 0 else { return 0 }
        let mean = sum / Float(count)
        let variance = sumSq / Float(count) - mean * mean
        return max(0, variance)
    }

    // MARK: - Exposure Assessment

    private func assessExposure(cgImage: CGImage) -> Float {
        let meanLuminance = computeMeanLuminance(cgImage: cgImage)

        let low = configuration.idealLuminanceRange.lowerBound
        let high = configuration.idealLuminanceRange.upperBound

        if meanLuminance >= low && meanLuminance <= high {
            return 1.0
        }

        if meanLuminance < low {
            // Underexposed.
            let deficit = low - meanLuminance
            return max(0.0, 1.0 - deficit / low)
        } else {
            // Overexposed.
            let excess = meanLuminance - high
            let headroom = 255.0 - high
            return max(0.0, 1.0 - excess / max(1.0, headroom))
        }
    }

    private func computeMeanLuminance(cgImage: CGImage) -> Float {
        let width = min(cgImage.width, 256)
        let height = min(cgImage.height, 256)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        var pixelData = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 128 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let total = pixelData.reduce(0) { $0 + Int($1) }
        return Float(total) / Float(pixelData.count)
    }

    // MARK: - Contrast Assessment

    private func assessContrast(cgImage: CGImage) -> Float {
        let width = min(cgImage.width, 256)
        let height = min(cgImage.height, 256)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        var pixelData = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0.5 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let count = pixelData.count
        guard count > 0 else { return 0.5 }

        let mean = Float(pixelData.reduce(0) { $0 + Int($1) }) / Float(count)
        let variance = pixelData.reduce(Float(0)) { acc, pixel in
            let diff = Float(pixel) - mean
            return acc + diff * diff
        } / Float(count)

        let stdDev = sqrt(variance)

        // Good contrast has stddev > ~40. Map to 0-1 score.
        return min(1.0, stdDev / 60.0)
    }

    // MARK: - Sign Size Assessment

    private func assessSignSize(regions: [DetectedSignRegion]) -> Float {
        guard !regions.isEmpty else {
            // No signs detected: might be too far away or not a sign image.
            return 0.3
        }

        // Use the largest detected sign region.
        let largestArea = regions
            .map { $0.boundingBox.width * $0.boundingBox.height }
            .max() ?? 0

        let areaFraction = Float(largestArea)

        if areaFraction >= configuration.idealSignAreaFraction {
            return 1.0
        }
        if areaFraction < configuration.minimumSignAreaFraction {
            return max(0.1, areaFraction / configuration.minimumSignAreaFraction)
        }

        // Between minimum and ideal.
        let range = configuration.idealSignAreaFraction - configuration.minimumSignAreaFraction
        let progress = (areaFraction - configuration.minimumSignAreaFraction) / range
        return 0.5 + progress * 0.5
    }

    // MARK: - Guidance Generation

    private func buildGuidance(
        blurScore: Float,
        exposureScore: Float,
        signSizeScore: Float,
        contrastScore: Float,
        hasDetections: Bool
    ) -> [String] {
        var messages: [String] = []

        if blurScore < 0.4 {
            messages.append("Too blurry. Hold the phone steadier or tap to focus.")
        } else if blurScore < 0.6 {
            messages.append("Slightly blurry. Try holding steadier.")
        }

        if exposureScore < 0.4 {
            messages.append("Image is too dark or too bright. Move to better lighting.")
        } else if exposureScore < 0.6 {
            messages.append("Lighting could be better. Avoid glare or deep shadows.")
        }

        if signSizeScore < 0.4 {
            if !hasDetections {
                messages.append("No sign detected. Point the camera at a parking sign.")
            } else {
                messages.append("Move closer to the sign for better recognition.")
            }
        } else if signSizeScore < 0.6 {
            messages.append("Move a bit closer for best results.")
        }

        if contrastScore < 0.3 {
            messages.append("Low contrast. The sign may be faded or in shadow.")
        }

        if messages.isEmpty {
            messages.append("Image quality looks good.")
        }

        return messages
    }

    // MARK: - Severity Classification

    private func classifySeverity(_ overallScore: Float) -> ImageQualityReport.Severity {
        if overallScore >= 0.75 { return .good }
        if overallScore >= 0.55 { return .acceptable }
        if overallScore >= configuration.acceptableThreshold { return .poor }
        return .unusable
    }

    // MARK: - Helpers

    private func makeUnusableReport(reason: String) -> ImageQualityReport {
        ImageQualityReport(
            overallScore: 0,
            blurScore: 0,
            exposureScore: 0,
            signSizeScore: 0,
            contrastScore: 0,
            isAcceptable: false,
            guidanceMessages: [reason],
            severity: .unusable
        )
    }
}
