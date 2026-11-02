import Foundation

/// Text for recommendation-load diagnostics, independent of request state and UI rendering.
nonisolated enum RecommendationDiagnosticText {
    static func locationCacheReason(_ reason: LocationCacheRejectionReason) -> String {
        switch reason {
        case .missing: "No saved location exists."
        case .malformed: "The saved location could not be decoded."
        case .invalidCoordinate: "The saved coordinate is invalid."
        case .missingAccuracy: "The saved location has no accuracy value."
        case .inadequateAccuracy(let accuracy): "Accuracy \(distanceText(accuracy)) exceeds the accepted limit."
        case .futureTimestamp(let age): "The saved timestamp is in the future (age \(durationText(age)))."
        case .stale(let age): "The saved location is stale at age \(durationText(age))."
        }
    }

    static func shortLocationCacheReason(_ reason: LocationCacheRejectionReason) -> String {
        switch reason {
        case .missing: "No saved location"
        case .malformed: "Saved location unreadable"
        case .invalidCoordinate: "Saved coordinate invalid"
        case .missingAccuracy: "Saved accuracy missing"
        case .inadequateAccuracy: "Saved location too imprecise"
        case .futureTimestamp: "Saved timestamp invalid"
        case .stale: "Saved location expired"
        }
    }

    static func weatherCacheReason(_ reason: WeatherCacheRejectionReason) -> String {
        switch reason {
        case .missing: "No saved forecast exists."
        case .malformed: "The saved forecast could not be decoded."
        case .invalidRequestedLocation: "The requested location is invalid."
        case .invalidStructure: "The saved forecast structure is invalid."
        case .inadequateDayCoverage: "The saved forecast does not cover the remaining local day."
        case .locationMismatch(let distance): "The saved forecast location is too far away (\(distanceText(distance)))."
        case .futureTimestamp(let age): "The saved forecast timestamp is in the future (age \(durationText(age)))."
        }
    }

    static func weatherErrorText(_ error: any Error) -> String {
        switch error as? WeatherProviderError {
        case .network: "Network failure"
        case .unauthorized: "Provider authorization failure"
        case .timedOut: "Request timed out"
        case .cancelled: "Request cancelled"
        case .unavailable: "Provider unavailable"
        case nil: String(describing: error)
        }
    }

    static func accuracyText(_ accuracy: Double?) -> String {
        guard let accuracy, accuracy.isFinite else { return "unavailable accuracy" }
        return "\(distanceText(accuracy)) accuracy"
    }

    static func distanceText(_ meters: Double) -> String {
        guard meters.isFinite else { return "non-finite distance" }
        return "\(meters.formatted(.number.precision(.fractionLength(0...1)))) m"
    }

    static func durationText(_ seconds: TimeInterval) -> String {
        "\(seconds.formatted(.number.precision(.fractionLength(0...2)))) s"
    }

    static func ageText(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        if minutes < 1 { return "less than 1 minute" }
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    static func countdownText(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(max(1, Int(ceil(seconds)))) seconds"
        }
        let minutes = max(1, Int(ceil(seconds / 60)))
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}
