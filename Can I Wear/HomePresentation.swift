import Foundation

nonisolated struct RecommendationPresentation: Equatable, Sendable {
    let recommendation: HourlyRecommendation

    var level: RecommendationLevel { recommendation.level }

    var title: String {
        switch level {
        case .okay: "OK"
        case .caution: "CAUTION"
        case .avoid: "AVOID"
        }
    }

    var symbolName: String {
        switch level {
        case .okay: "checkmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .avoid: "xmark.circle.fill"
        }
    }

    var segmentSymbol: String {
        switch level {
        case .okay: "checkmark"
        case .caution: "exclamationmark"
        case .avoid: "xmark"
        }
    }

    var reason: String {
        switch recommendation.reason {
        case .suitableTemperature: "Dry and cool enough."
        case .warmTemperature: "It may feel too warm."
        case .excessiveHeat: "Too warm for leather."
        case .precipitationRisk: "A chance of precipitation."
        case .precipitation: "Precipitation could damage leather."
        case .fogOrMist: "Fog is expected."
        case .incompleteForecast: "Part of the forecast is uncertain."
        }
    }
}

nonisolated struct PeriodPresentation: Equatable, Sendable {
    let interval: DateInterval
    let timezoneIdentifier: String
    let recommendation: RecommendationPresentation

    // Exact ranges preserve dynamic grouping without inventing fixed dayparts.
    var label: String {
        let zone = TimeZone(identifier: timezoneIdentifier) ?? .gmt
        let changesOffset = zone.secondsFromGMT(for: interval.start) != zone.secondsFromGMT(for: interval.end)
        return "\(HomeTime.label(interval.start, timezone: timezoneIdentifier, offset: changesOffset))–\(HomeTime.label(interval.end, timezone: timezoneIdentifier, offset: changesOffset))"
    }

    var compactLabel: String {
        label.replacingOccurrences(of: ":00", with: "")
    }

    var symbolName: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezoneIdentifier) ?? .gmt
        switch calendar.component(.hour, from: interval.start) {
        case 6..<12: return "sunrise"
        case 12..<18: return "sun.max"
        case 18..<22: return "sunset"
        default: return "moon"
        }
    }
}

nonisolated struct HourlySuitabilityPresentation: Equatable, Sendable, Identifiable {
    let hour: EvaluatedHour
    let timezoneIdentifier: String

    var id: Date { hour.timestamp }
    var recommendation: RecommendationPresentation {
        RecommendationPresentation(recommendation: hour.recommendation)
    }
    var isInferred: Bool { hour.recommendation.reason == .incompleteForecast }
    var timeLabel: String { HomeTime.label(id, timezone: timezoneIdentifier) }
    var unambiguousTimeLabel: String { HomeTime.label(id, timezone: timezoneIdentifier, offset: true) }
    var accessibilityLabel: String {
        if isInferred {
            return "\(unambiguousTimeLabel), forecast uncertain; conservatively inferred \(recommendation.title)"
        }
        return "\(unambiguousTimeLabel), \(recommendation.title). \(recommendation.reason)"
    }
}

nonisolated struct DailyRecommendationPresentation: Equatable, Sendable {
    let periods: [PeriodPresentation]
    /// Raw daily evaluations, before D-026 consolidation. Never expanded from periods.
    let hours: [HourlySuitabilityPresentation]
    let weatherFetchedAt: Date
    let isUsingSavedWeather: Bool
    let isRefreshing: Bool
    let refreshFailed: Bool
    let refreshAvailableAt: Date

    var summary: RecommendationPresentation? {
        HourlyRecommendation.mostProtective(in: hours.map(\.hour.recommendation))
            .map { RecommendationPresentation(recommendation: $0) }
    }

    var hasConsolidatedDifferences: Bool {
        hours.contains { hour in
            periods.contains { period in
                hour.id >= period.interval.start && hour.id < period.interval.end
                    && hour.recommendation.level != period.recommendation.level
            }
        }
    }

    var hasInferredHour: Bool { hours.contains(where: \.isInferred) }

    var hasRepeatedLocalHour: Bool {
        Set(hours.map(\.timeLabel)).count != hours.count
    }
}

nonisolated private enum HomeTime {
    static func label(_ date: Date, timezone: String, offset: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timezone) ?? .gmt
        // Explicit 24-hour local times keep ranges compact. Offsets distinguish DST repeats.
        formatter.dateFormat = offset ? "HH:mm 'UTC'xxx" : "HH:mm"
        return formatter.string(from: date)
    }
}
