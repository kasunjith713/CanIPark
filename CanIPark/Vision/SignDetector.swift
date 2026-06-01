// SignDetector.swift
// CanIPark
//
// Detects rectangular sign-like regions in a camera image using the
// Vision framework and groups nearby panels into sign stacks.

import UIKit
import Vision

// MARK: - Detected Sign Region

struct DetectedSignRegion: Identifiable, Sendable {
    let id = UUID()
    /// Normalised bounding box in Vision coordinate space (origin bottom-left).
    let boundingBox: CGRect
    /// Detection confidence 0-1.
    let confidence: Float
    /// The observation that produced this region.
    let observation: VNRectangleObservation

    /// Convert the Vision coordinate bounding box to UIKit coordinates for the given image size.
    func boundingBoxInImageCoordinates(imageSize: CGSize) -> CGRect {
        let x = boundingBox.origin.x * imageSize.width
        let y = (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height
        let width = boundingBox.width * imageSize.width
        let height = boundingBox.height * imageSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Sign Stack

/// A vertical group of sign panels that appear on the same pole.
struct SignStack: Identifiable, Sendable {
    let id = UUID()
    /// Regions sorted top-to-bottom.
    let panels: [DetectedSignRegion]
    /// Combined bounding box covering all panels.
    let combinedBoundingBox: CGRect
}

// MARK: - Sign Detector

actor SignDetector {

    // MARK: Configuration

    struct Configuration: Sendable {
        /// Minimum aspect ratio (width / height) to accept as a sign.
        var minAspectRatio: Float = 0.3
        /// Maximum aspect ratio (width / height) to accept as a sign.
        var maxAspectRatio: Float = 3.5
        /// Minimum confidence for a detected rectangle.
        var minimumConfidence: Float = 0.4
        /// Maximum number of rectangles to request from Vision.
        var maximumObservations: Int = 20
        /// Minimum size of a detected rectangle relative to the image (0-1 on the shorter axis).
        var minimumSize: Float = 0.03
        /// Maximum vertical gap between panels (as a fraction of image height) to group them.
        var stackingGapThreshold: CGFloat = 0.08
        /// Maximum horizontal offset between panel centres to group them on the same pole.
        var stackingAlignmentThreshold: CGFloat = 0.10

        static let `default` = Configuration()
    }

    private let configuration: Configuration

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Detection

    /// Detect sign-like rectangles in the provided image.
    func detectSigns(in image: UIImage) async throws -> [DetectedSignRegion] {
        guard let cgImage = image.cgImage else {
            throw SignDetectorError.invalidImage
        }
        return try await detectSigns(in: cgImage)
    }

    /// Detect sign-like rectangles in a CGImage.
    func detectSigns(in cgImage: CGImage) async throws -> [DetectedSignRegion] {
        let observations = try await performRectangleDetection(on: cgImage)
        return filterByAspectRatio(observations)
    }

    /// Detect signs and group them into pole stacks.
    func detectSignStacks(in image: UIImage) async throws -> [SignStack] {
        let regions = try await detectSigns(in: image)
        return groupIntoStacks(regions)
    }

    // MARK: - Vision Request

    private func performRectangleDetection(on cgImage: CGImage) async throws -> [VNRectangleObservation] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRectangleObservation]) ?? []
                continuation.resume(returning: observations)
            }
            request.minimumConfidence = configuration.minimumConfidence
            request.maximumObservations = configuration.maximumObservations
            request.minimumSize = configuration.minimumSize
            request.minimumAspectRatio = configuration.minAspectRatio
            request.maximumAspectRatio = configuration.maxAspectRatio
            // Prefer accurate results over speed.
            request.revision = VNDetectRectanglesRequestRevision1

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Filtering

    private func filterByAspectRatio(_ observations: [VNRectangleObservation]) -> [DetectedSignRegion] {
        observations.compactMap { observation in
            let box = observation.boundingBox
            guard box.width > 0, box.height > 0 else { return nil }

            let aspectRatio = Float(box.width / box.height)
            guard aspectRatio >= configuration.minAspectRatio,
                  aspectRatio <= configuration.maxAspectRatio else {
                return nil
            }

            return DetectedSignRegion(
                boundingBox: box,
                confidence: observation.confidence,
                observation: observation
            )
        }
        .sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Stacking / Grouping

    /// Groups sign regions that are vertically aligned into stacks.
    func groupIntoStacks(_ regions: [DetectedSignRegion]) -> [SignStack] {
        guard !regions.isEmpty else { return [] }

        let count = regions.count
        var parent = Array(0..<count)
        var rank = Array(repeating: 0, count: count)

        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x {
                parent[x] = parent[parent[x]]
                x = parent[x]
            }
            return x
        }

        func union(_ a: Int, _ b: Int) {
            let rootA = find(a)
            let rootB = find(b)
            guard rootA != rootB else { return }
            if rank[rootA] < rank[rootB] { parent[rootA] = rootB }
            else if rank[rootA] > rank[rootB] { parent[rootB] = rootA }
            else { parent[rootB] = rootA; rank[rootA] += 1 }
        }

        // Merge regions that are horizontally aligned and close vertically.
        for i in 0..<count {
            for j in (i + 1)..<count {
                let boxA = regions[i].boundingBox
                let boxB = regions[j].boundingBox

                let centerAx = boxA.midX
                let centerBx = boxB.midX
                let horizontalDiff = abs(centerAx - centerBx)

                guard horizontalDiff < configuration.stackingAlignmentThreshold else { continue }

                let topA = boxA.origin.y + boxA.height
                let bottomA = boxA.origin.y
                let topB = boxB.origin.y + boxB.height
                let bottomB = boxB.origin.y

                let verticalGap = max(0, max(bottomA - topB, bottomB - topA))
                guard verticalGap < configuration.stackingGapThreshold else { continue }

                union(i, j)
            }
        }

        // Collect groups.
        var groups: [Int: [Int]] = [:]
        for i in 0..<count {
            let root = find(i)
            groups[root, default: []].append(i)
        }

        return groups.values.map { indices in
            // Sort panels top-to-bottom (highest y = top in Vision coordinates).
            let sortedIndices = indices.sorted { regions[$0].boundingBox.origin.y > regions[$1].boundingBox.origin.y }
            let panels = sortedIndices.map { regions[$0] }
            let combined = combinedBoundingBox(of: panels)
            return SignStack(panels: panels, combinedBoundingBox: combined)
        }
        .sorted { $0.combinedBoundingBox.origin.y > $1.combinedBoundingBox.origin.y }
    }

    private func combinedBoundingBox(of regions: [DetectedSignRegion]) -> CGRect {
        guard let first = regions.first else { return .zero }
        var minX = first.boundingBox.minX
        var minY = first.boundingBox.minY
        var maxX = first.boundingBox.maxX
        var maxY = first.boundingBox.maxY

        for region in regions.dropFirst() {
            minX = min(minX, region.boundingBox.minX)
            minY = min(minY, region.boundingBox.minY)
            maxX = max(maxX, region.boundingBox.maxX)
            maxY = max(maxY, region.boundingBox.maxY)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// MARK: - Errors

enum SignDetectorError: LocalizedError {
    case invalidImage
    case detectionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image could not be processed."
        case .detectionFailed(let underlying):
            return "Sign detection failed: \(underlying.localizedDescription)"
        }
    }
}
