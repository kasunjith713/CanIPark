// JurisdictionResolver.swift
// CanIPark

import Foundation
import CoreLocation

// MARK: - Jurisdiction Resolver

/// Resolves the user's Australian state or territory from GPS coordinates or manual selection.
/// Uses offline bounding boxes for fast, network-free resolution.
struct JurisdictionResolver {

    // MARK: - Bounding Box

    /// A simple axis-aligned bounding box defined by latitude/longitude ranges.
    struct BoundingBox {
        let minLatitude: Double
        let maxLatitude: Double
        let minLongitude: Double
        let maxLongitude: Double

        func contains(latitude: Double, longitude: Double) -> Bool {
            latitude >= minLatitude && latitude <= maxLatitude
                && longitude >= minLongitude && longitude <= maxLongitude
        }
    }

    // MARK: - State Bounding Boxes

    /// Approximate bounding boxes for each Australian state and territory.
    /// These are intentionally generous to avoid false negatives at borders.
    /// Checked in priority order (smaller territories first for specificity).
    private static let stateBounds: [(state: AustralianState, box: BoundingBox)] = [
        // ACT — small, check first
        (.act, BoundingBox(minLatitude: -35.95, maxLatitude: -35.10,
                           minLongitude: 148.75, maxLongitude: 149.40)),
        // NT
        (.nt, BoundingBox(minLatitude: -26.00, maxLatitude: -10.90,
                          minLongitude: 129.00, maxLongitude: 138.00)),
        // TAS — island, distinct longitude/latitude
        (.tas, BoundingBox(minLatitude: -43.70, maxLatitude: -39.50,
                           minLongitude: 143.50, maxLongitude: 148.50)),
        // WA
        (.wa, BoundingBox(minLatitude: -35.20, maxLatitude: -13.50,
                          minLongitude: 112.90, maxLongitude: 129.00)),
        // SA
        (.sa, BoundingBox(minLatitude: -38.10, maxLatitude: -26.00,
                          minLongitude: 129.00, maxLongitude: 141.00)),
        // QLD
        (.qld, BoundingBox(minLatitude: -29.20, maxLatitude: -10.60,
                           minLongitude: 138.00, maxLongitude: 153.60)),
        // VIC
        (.vic, BoundingBox(minLatitude: -39.20, maxLatitude: -33.98,
                           minLongitude: 140.95, maxLongitude: 150.05)),
        // NSW — largest overlap, check last among eastern states
        (.nsw, BoundingBox(minLatitude: -37.60, maxLatitude: -28.15,
                           minLongitude: 140.95, maxLongitude: 153.70)),
    ]

    // MARK: - Resolution from Coordinates

    /// Resolves the Australian state from a GPS coordinate.
    /// Returns `nil` if the coordinate is outside Australia.
    static func resolve(latitude: Double, longitude: Double) -> AustralianState? {
        for entry in stateBounds {
            if entry.box.contains(latitude: latitude, longitude: longitude) {
                return entry.state
            }
        }
        return nil
    }

    /// Resolves the Australian state from a `CLLocationCoordinate2D`.
    static func resolve(coordinate: CLLocationCoordinate2D) -> AustralianState? {
        return resolve(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// Resolves the Australian state from a `CLLocation`.
    static func resolve(location: CLLocation) -> AustralianState? {
        return resolve(coordinate: location.coordinate)
    }

    // MARK: - Resolution Result

    /// Encapsulates a jurisdiction resolution result with metadata.
    struct ResolutionResult {
        let state: AustralianState
        let source: ResolutionSource
        let confidence: ResolutionConfidence
    }

    enum ResolutionSource {
        case gps
        case manualSelection
        case cached
    }

    enum ResolutionConfidence {
        /// Coordinate is well within state boundaries.
        case high
        /// Coordinate is near a state border.
        case medium
        /// Fallback or manual selection.
        case low
    }

    /// Resolves the state from a coordinate and returns a result with confidence metadata.
    static func resolveWithConfidence(latitude: Double, longitude: Double) -> ResolutionResult? {
        guard let state = resolve(latitude: latitude, longitude: longitude) else {
            return nil
        }

        // Check if the point is near a border by testing if multiple boxes contain it
        let matchCount = stateBounds.filter { $0.box.contains(latitude: latitude, longitude: longitude) }.count
        let confidence: ResolutionConfidence = matchCount > 1 ? .medium : .high

        return ResolutionResult(state: state, source: .gps, confidence: confidence)
    }

    /// Creates a manual selection result.
    static func manualSelection(_ state: AustralianState) -> ResolutionResult {
        return ResolutionResult(state: state, source: .manualSelection, confidence: .low)
    }

    // MARK: - Validation

    /// Returns `true` if the coordinate is within Australia's approximate overall bounding box.
    static func isInAustralia(latitude: Double, longitude: Double) -> Bool {
        // Broad bounding box for the Australian continent and Tasmania
        return latitude >= -44.0 && latitude <= -10.0
            && longitude >= 112.0 && longitude <= 154.0
    }

    /// Returns all states whose bounding box contains the given coordinate.
    /// Useful for border regions where the user may need to choose.
    static func candidateStates(latitude: Double, longitude: Double) -> [AustralianState] {
        return stateBounds
            .filter { $0.box.contains(latitude: latitude, longitude: longitude) }
            .map { $0.state }
    }
}
