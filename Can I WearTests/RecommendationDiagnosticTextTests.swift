import Foundation
import Testing
@testable import Can_I_Wear

struct RecommendationDiagnosticTextTests {
    @Test func preservesEveryLocationCacheReasonAndShortDescription() {
        let distance = RecommendationDiagnosticText.distanceText(5_001)
        let duration = RecommendationDiagnosticText.durationText(-1)
        let cases: [(LocationCacheRejectionReason, String, String)] = [
            (.missing, "No saved location exists.", "No saved location"),
            (.malformed, "The saved location could not be decoded.", "Saved location unreadable"),
            (.invalidCoordinate, "The saved coordinate is invalid.", "Saved coordinate invalid"),
            (.missingAccuracy, "The saved location has no accuracy value.", "Saved accuracy missing"),
            (.inadequateAccuracy(5_001), "Accuracy \(distance) exceeds the accepted limit.", "Saved location too imprecise"),
            (.futureTimestamp(-1), "The saved timestamp is in the future (age \(duration)).", "Saved timestamp invalid"),
            (.stale(-1), "The saved location is stale at age \(duration).", "Saved location expired")
        ]
        for (reason, full, short) in cases {
            #expect(RecommendationDiagnosticText.locationCacheReason(reason) == full)
            #expect(RecommendationDiagnosticText.shortLocationCacheReason(reason) == short)
        }
    }

    @Test func preservesEveryWeatherCacheReasonAndProviderError() {
        let distance = RecommendationDiagnosticText.distanceText(5_001)
        let duration = RecommendationDiagnosticText.durationText(-1)
        let cases: [(WeatherCacheRejectionReason, String)] = [
            (.missing, "No saved forecast exists."),
            (.malformed, "The saved forecast could not be decoded."),
            (.invalidRequestedLocation, "The requested location is invalid."),
            (.invalidStructure, "The saved forecast structure is invalid."),
            (.inadequateDayCoverage, "The saved forecast does not cover the remaining local day."),
            (.locationMismatch(distanceMeters: 5_001), "The saved forecast location is too far away (\(distance))."),
            (.futureTimestamp(-1), "The saved forecast timestamp is in the future (age \(duration)).")
        ]
        for (reason, expected) in cases {
            #expect(RecommendationDiagnosticText.weatherCacheReason(reason) == expected)
        }
        for (error, expected) in [
            (WeatherProviderError.network, "Network failure"), (.unauthorized, "Provider authorization failure"),
            (.timedOut, "Request timed out"), (.cancelled, "Request cancelled"), (.unavailable, "Provider unavailable")
        ] {
            #expect(RecommendationDiagnosticText.weatherErrorText(error) == expected)
        }
        // Match the formatter's existing Error boundary, including Foundation error bridging.
        let other: any Error = URLError(.badURL)
        #expect(RecommendationDiagnosticText.weatherErrorText(other) == String(describing: other))
    }

    @Test func preservesMeasurementFormattingAndInvalidAccuracyFallbacks() {
        let number = 12.34
        let formatted = number.formatted(.number.precision(.fractionLength(0...1)))
        #expect(RecommendationDiagnosticText.distanceText(number) == "\(formatted) m")
        #expect(RecommendationDiagnosticText.accuracyText(number) == "\(formatted) m accuracy")
        #expect(RecommendationDiagnosticText.accuracyText(nil) == "unavailable accuracy")
        #expect(RecommendationDiagnosticText.accuracyText(.nan) == "unavailable accuracy")
        #expect(RecommendationDiagnosticText.accuracyText(.infinity) == "unavailable accuracy")
        #expect(RecommendationDiagnosticText.distanceText(.infinity) == "non-finite distance")
        #expect(RecommendationDiagnosticText.durationText(number) == "\(number.formatted(.number.precision(.fractionLength(0...2)))) s")
    }

    @Test func preservesAgeAndCountdownRoundingBoundaries() {
        for (seconds, expected) in [
            (-1.0, "less than 1 minute"), (0, "less than 1 minute"), (59.99, "less than 1 minute"),
            (60, "1 minute"), (119.99, "1 minute"), (120, "2 minutes")
        ] {
            #expect(RecommendationDiagnosticText.ageText(seconds) == expected)
        }
        for (seconds, expected) in [
            (-1.0, "1 seconds"), (0, "1 seconds"), (1.01, "2 seconds"), (59.99, "60 seconds"),
            (60, "1 minute"), (60.01, "2 minutes"), (120, "2 minutes")
        ] {
            #expect(RecommendationDiagnosticText.countdownText(seconds) == expected)
        }
    }
}
