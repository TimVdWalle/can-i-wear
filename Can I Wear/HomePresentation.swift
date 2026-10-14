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
    let isPast: Bool

    init(
        hour: EvaluatedHour,
        timezoneIdentifier: String,
        isPast: Bool = false
    ) {
        self.hour = hour
        self.timezoneIdentifier = timezoneIdentifier
        self.isPast = isPast
    }

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

nonisolated enum FixedDayPart: String, CaseIterable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    var label: String { rawValue.capitalized }

    var symbolName: String {
        switch self {
        case .morning: "sun.max"
        case .afternoon: "sun.max.fill"
        case .evening: "sun.horizon"
        case .night: "moon"
        }
    }

    var startHour: Int {
        switch self {
        case .morning: 6
        case .afternoon: 12
        case .evening: 18
        case .night: 22
        }
    }

    var endHour: Int {
        switch self {
        case .morning: 12
        case .afternoon: 18
        case .evening: 22
        case .night: 24
        }
    }
}

nonisolated struct FixedDayPartPresentation: Equatable, Sendable, Identifiable {
    let dayPart: FixedDayPart
    let interval: DateInterval
    let recommendation: RecommendationPresentation?
    let isPast: Bool

    var id: FixedDayPart { dayPart }
    var label: String { dayPart.label }
    var symbolName: String { dayPart.symbolName }

    var accessibilityLabel: String {
        let result = recommendation?.title ?? "Unavailable"
        return isPast
            ? "\(label), \(result), finished for today"
            : "\(label), \(result)"
    }

    static func make(
        from evaluation: DailyEvaluation,
        at currentTime: Date
    ) -> [FixedDayPartPresentation] {
        guard let timezone = TimeZone(identifier: evaluation.timezoneIdentifier) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        guard let day = calendar.dateInterval(of: .day, for: currentTime) else { return [] }

        return FixedDayPart.allCases.compactMap { dayPart in
            guard let start = calendar.date(
                bySettingHour: dayPart.startHour,
                minute: 0,
                second: 0,
                of: day.start
            ) else { return nil }
            let end: Date
            if dayPart.endHour == 24 {
                end = day.end
            } else if let boundary = calendar.date(
                bySettingHour: dayPart.endHour,
                minute: 0,
                second: 0,
                of: day.start
            ) {
                end = boundary
            } else {
                return nil
            }

            let interval = DateInterval(start: start, end: end)
            let recommendation = HourlyRecommendation.mostProtective(
                in: evaluation.hours
                    .filter { $0.timestamp >= start && $0.timestamp < end }
                    .map(\.recommendation)
            ).map { RecommendationPresentation(recommendation: $0) }

            return FixedDayPartPresentation(
                dayPart: dayPart,
                interval: interval,
                recommendation: recommendation,
                isPast: end <= currentTime
            )
        }
    }
}

nonisolated struct DailyRecommendationPresentation: Equatable, Sendable {
    let periods: [PeriodPresentation]
    /// Raw daily evaluations, before D-026 consolidation. Never expanded from periods.
    let hours: [HourlySuitabilityPresentation]
    let dayParts: [FixedDayPartPresentation]
    let displayHours: [HourlySuitabilityPresentation]
    let weatherFetchedAt: Date
    let isUsingSavedWeather: Bool
    let isRefreshing: Bool
    let refreshFailed: Bool
    let refreshAvailableAt: Date

    init(
        periods: [PeriodPresentation],
        hours: [HourlySuitabilityPresentation],
        weatherFetchedAt: Date,
        isUsingSavedWeather: Bool,
        isRefreshing: Bool,
        refreshFailed: Bool,
        refreshAvailableAt: Date,
        dayParts: [FixedDayPartPresentation] = [],
        displayHours: [HourlySuitabilityPresentation]? = nil
    ) {
        self.periods = periods
        self.hours = hours
        self.dayParts = dayParts
        self.displayHours = displayHours ?? hours
        self.weatherFetchedAt = weatherFetchedAt
        self.isUsingSavedWeather = isUsingSavedWeather
        self.isRefreshing = isRefreshing
        self.refreshFailed = refreshFailed
        self.refreshAvailableAt = refreshAvailableAt
    }

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

    var hasInferredHour: Bool { displayHours.contains(where: \.isInferred) }

    var hasRepeatedLocalHour: Bool {
        Set(displayHours.map(\.timeLabel)).count != displayHours.count
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
