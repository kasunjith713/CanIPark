// SignGrouper.swift
// CanIPark
//
// Groups individually detected sign panels into logical pole groups,
// associating each panel with its OCR text and arrow detection result.
// Uses union-find clustering by spatial proximity and propagates
// arrow direction information across a group.

import Foundation
import CoreGraphics

// MARK: - Sign Panel

/// A single sign panel with its detection, OCR, and arrow data.
struct SignPanel: Identifiable, Sendable {
    let id = UUID()
    /// The detected rectangular region.
    let region: DetectedSignRegion
    /// OCR result for this panel.
    let ocrResult: SignOCRResult
    /// Detected arrow direction on this panel.
    let arrowResult: ArrowDetectionResult
    /// Position index within the pole group (0 = topmost).
    var positionIndex: Int = 0
}

// MARK: - Sign Pole Group

/// A collection of sign panels mounted on the same pole.
struct SignPoleGroup: Identifiable, Sendable {
    let id = UUID()
    /// Panels sorted top-to-bottom.
    let panels: [SignPanel]
    /// Combined bounding box enclosing all panels (Vision coordinates).
    let combinedBoundingBox: CGRect
    /// The dominant arrow direction for this group after propagation.
    let effectiveArrowDirection: ArrowDirection
    /// Confidence of the group assignment (0-1).
    let groupingConfidence: Float

    /// All OCR text in the group, panels separated by double-newlines.
    var combinedText: String {
        panels.map(\.ocrResult.fullText).joined(separator: "\n\n")
    }
}

// MARK: - Sign Grouper

struct SignGrouper {

    // MARK: Configuration

    struct Configuration: Sendable {
        /// Maximum horizontal distance between panel centres (normalised) to consider them on the same pole.
        var horizontalAlignmentThreshold: CGFloat = 0.12
        /// Maximum vertical gap between adjacent panels (normalised) to group them.
        var verticalGapThreshold: CGFloat = 0.10
        /// Minimum overlap ratio of bounding box widths to consider panels aligned.
        var minimumWidthOverlap: CGFloat = 0.40

        static let `default` = Configuration()
    }

    private let configuration: Configuration

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Grouping API

    /// Group panels into pole groups.
    ///
    /// - Parameters:
    ///   - regions: Detected sign regions.
    ///   - ocrResults: OCR results corresponding 1:1 to `regions`.
    ///   - arrowResults: Arrow detection results corresponding 1:1 to `regions`.
    /// - Returns: An array of `SignPoleGroup` values.
    func groupIntoPoles(
        regions: [DetectedSignRegion],
        ocrResults: [SignOCRResult],
        arrowResults: [ArrowDetectionResult]
    ) -> [SignPoleGroup] {
        precondition(regions.count == ocrResults.count && regions.count == arrowResults.count,
                     "Regions, OCR results, and arrow results must have the same count.")

        let count = regions.count
        guard count > 0 else { return [] }

        // Build panels.
        let panels: [SignPanel] = (0..<count).map { i in
            SignPanel(
                region: regions[i],
                ocrResult: ocrResults[i],
                arrowResult: arrowResults[i]
            )
        }

        // Union-find clustering.
        let clusters = clusterByProximity(panels)

        // Build groups from clusters.
        return clusters.map { clusterPanels in
            buildPoleGroup(from: clusterPanels)
        }
        .sorted { $0.combinedBoundingBox.midY > $1.combinedBoundingBox.midY }
    }

    // MARK: - Union-Find Clustering

    private func clusterByProximity(_ panels: [SignPanel]) -> [[SignPanel]] {
        let count = panels.count
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

        for i in 0..<count {
            for j in (i + 1)..<count {
                if shouldGroup(panels[i], panels[j]) {
                    union(i, j)
                }
            }
        }

        // Collect.
        var groups: [Int: [Int]] = [:]
        for i in 0..<count {
            groups[find(i), default: []].append(i)
        }

        return groups.values.map { indices in
            indices.map { panels[$0] }
        }
    }

    /// Determine whether two panels should be on the same pole.
    private func shouldGroup(_ a: SignPanel, _ b: SignPanel) -> Bool {
        let boxA = a.region.boundingBox
        let boxB = b.region.boundingBox

        // 1. Horizontal alignment: centres must be close.
        let centerDiffX = abs(boxA.midX - boxB.midX)
        guard centerDiffX <= configuration.horizontalAlignmentThreshold else { return false }

        // 2. Width overlap: the narrower panel must overlap significantly
        //    with the wider one.
        let overlapLeft = max(boxA.minX, boxB.minX)
        let overlapRight = min(boxA.maxX, boxB.maxX)
        let overlapWidth = max(0, overlapRight - overlapLeft)
        let minWidth = min(boxA.width, boxB.width)
        guard minWidth > 0 else { return false }
        let overlapRatio = overlapWidth / minWidth
        guard overlapRatio >= configuration.minimumWidthOverlap else { return false }

        // 3. Vertical gap: must be reasonably close.
        let topOfLower = min(boxA.maxY, boxB.maxY)
        let bottomOfUpper = max(boxA.minY, boxB.minY)
        let gap = max(0, bottomOfUpper - topOfLower)
        // Allow gap relative to the average panel height.
        let avgHeight = (boxA.height + boxB.height) / 2
        let normalizedGap = avgHeight > 0 ? gap / avgHeight : gap
        guard normalizedGap <= 2.0 && gap <= configuration.verticalGapThreshold else { return false }

        return true
    }

    // MARK: - Group Building

    private func buildPoleGroup(from rawPanels: [SignPanel]) -> SignPoleGroup {
        // Sort top-to-bottom (highest Vision Y = top).
        var sorted = rawPanels.sorted { $0.region.boundingBox.midY > $1.region.boundingBox.midY }

        // Assign position indices.
        for i in 0..<sorted.count {
            sorted[i].positionIndex = i
        }

        let combined = combinedBoundingBox(of: sorted)
        let arrowDirection = propagateArrowDirection(in: sorted)
        let confidence = computeGroupingConfidence(sorted)

        return SignPoleGroup(
            panels: sorted,
            combinedBoundingBox: combined,
            effectiveArrowDirection: arrowDirection,
            groupingConfidence: confidence
        )
    }

    // MARK: - Arrow Direction Propagation

    /// Determine the effective arrow direction for a pole group.
    ///
    /// Rules:
    /// 1. If any panel has a detected arrow, that direction is used.
    /// 2. If multiple panels have arrows, prefer the one with highest confidence.
    /// 3. If panels have conflicting arrows (left vs right), use `.both`.
    private func propagateArrowDirection(in panels: [SignPanel]) -> ArrowDirection {
        let detectedArrows = panels
            .map(\.arrowResult)
            .filter { $0.direction != .none && $0.confidence > 0.3 }

        guard !detectedArrows.isEmpty else { return .none }

        // Check for conflicts.
        let directions = Set(detectedArrows.map(\.direction))

        if directions.contains(.both) {
            return .both
        }
        if directions.contains(.left) && directions.contains(.right) {
            return .both
        }

        // Return the highest confidence direction.
        if let best = detectedArrows.max(by: { $0.confidence < $1.confidence }) {
            return best.direction
        }

        return .none
    }

    // MARK: - Confidence

    private func computeGroupingConfidence(_ panels: [SignPanel]) -> Float {
        guard panels.count > 1 else { return 1.0 }

        var totalScore: Float = 0
        var comparisons = 0

        for i in 0..<panels.count {
            for j in (i + 1)..<panels.count {
                let boxA = panels[i].region.boundingBox
                let boxB = panels[j].region.boundingBox

                // Horizontal alignment score.
                let centerDiff = abs(boxA.midX - boxB.midX)
                let alignScore = max(0, 1.0 - Float(centerDiff / configuration.horizontalAlignmentThreshold))

                // Width similarity score.
                let widthRatio = min(boxA.width, boxB.width) / max(boxA.width, boxB.width)
                let widthScore = Float(widthRatio)

                totalScore += (alignScore + widthScore) / 2.0
                comparisons += 1
            }
        }

        return comparisons > 0 ? totalScore / Float(comparisons) : 1.0
    }

    // MARK: - Helpers

    private func combinedBoundingBox(of panels: [SignPanel]) -> CGRect {
        guard let first = panels.first else { return .zero }
        var minX = first.region.boundingBox.minX
        var minY = first.region.boundingBox.minY
        var maxX = first.region.boundingBox.maxX
        var maxY = first.region.boundingBox.maxY

        for panel in panels.dropFirst() {
            let box = panel.region.boundingBox
            minX = min(minX, box.minX)
            minY = min(minY, box.minY)
            maxX = max(maxX, box.maxX)
            maxY = max(maxY, box.maxY)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
