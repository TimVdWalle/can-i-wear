import Foundation

nonisolated struct RecommendationPresentation: Equatable, Sendable {
    let recommendation: HourlyRecommendation

    var level: RecommendationLevel { recommendation.level }

    var title: String {
        switch level {
        case .okay: "YES"
        case .caution: "MAYBE"
        case .avoid: "NO"
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
        case .suitableTemperature: "Dry weather and suitable temperatures."
        case .warmTemperature: "It may feel too warm."
        case .excessiveHeat: "Too warm for leather."
        case .precipitationRisk: "Precipitation is possible today."
        case .precipitation: "Wet weather is expected and could damage leather."
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
    var axisTimeLabel: String { HomeTime.hourLabel(id, timezone: timezoneIdentifier) }
    var unambiguousAxisTimeLabel: String {
        HomeTime.hourLabel(id, timezone: timezoneIdentifier, offset: true)
    }
    var accessibilityLabel: String {
        if isInferred {
            return "\(unambiguousTimeLabel), forecast uncertain; conservatively inferred \(recommendation.title)"
        }
        return "\(unambiguousTimeLabel), \(recommendation.title). \(recommendation.reason)"
    }
}

/// Shared visual timeline values, without sharing item classification rules.
nonisolated struct HourlyTimelineSegment: Identifiable {
    let id: Date
    let timezoneIdentifier: String
    let tone: ItemAdviceTone
    let isInferred: Bool
    let isPast: Bool
    let accessibilityLabel: String

    init(_ hour: HourlySuitabilityPresentation) {
        id = hour.id
        timezoneIdentifier = hour.timezoneIdentifier
        switch hour.recommendation.level {
        case .okay: tone = .positive
        case .caution: tone = .caution
        case .avoid: tone = .negative
        }
        isInferred = hour.isInferred
        isPast = hour.isPast
        accessibilityLabel = hour.accessibilityLabel
    }

    init(_ hour: EvaluatedItemHour, item: PredefinedItem, timezone: String, currentTime: Date?) {
        id = hour.timestamp
        timezoneIdentifier = timezone
        tone = ItemHomePresentation.tone(hour.advice.level, item: item, inferred: hour.isInferred)
        isInferred = hour.isInferred
        isPast = currentTime.map { hour.timestamp.addingTimeInterval(3_600) <= $0 } ?? false
        let title: String
        switch hour.advice.level {
        case .yes: title = "YES"
        case .maybe: title = "MAYBE"
        case .no: title = "NO"
        }
        let meaning = ItemHomePresentation.levelTitle(hour.advice.level, item: item, inferred: hour.isInferred)
        accessibilityLabel = "\(HomeTime.label(id, timezone: timezone, offset: true)), \(hour.isInferred ? "Forecast uncertain" : title), \(meaning)\(isPast ? ", finished for today" : ""). \(ItemHomePresentation.reasonText(hour.advice.reason))"
    }

    var timeLabel: String { HomeTime.label(id, timezone: timezoneIdentifier) }
    var axisTimeLabel: String { HomeTime.hourLabel(id, timezone: timezoneIdentifier) }
    var unambiguousAxisTimeLabel: String { HomeTime.hourLabel(id, timezone: timezoneIdentifier, offset: true) }
}

nonisolated enum FixedDayPart: String, CaseIterable, Sendable {
    case morning
    case afternoon
    case evening

    var label: String { rawValue.capitalized }

    var symbolName: String {
        switch self {
        case .morning: "sun.max"
        case .afternoon: "sun.max.fill"
        case .evening: "sun.horizon"
        }
    }

    var startHour: Int {
        switch self {
        case .morning: 6
        case .afternoon: 12
        case .evening: 18
        }
    }

    var endHour: Int {
        switch self {
        case .morning: 12
        case .afternoon: 18
        case .evening: 24
        }
    }

    var hourCount: Int { endHour - startHour }
    var timeRangeLabel: String {
        String(format: "%02d–%02d", startHour, endHour)
    }
}

nonisolated struct FixedDayPartPresentation: Equatable, Sendable, Identifiable {
    let dayPart: FixedDayPart
    let interval: DateInterval
    let recommendation: RecommendationPresentation?
    let isPast: Bool
    var item: PredefinedItem = .leatherJacket
    var itemAdvicePeriods: [ItemAdvicePeriod] = []

    var id: FixedDayPart { dayPart }
    var label: String { dayPart.label }
    var symbolName: String { dayPart.symbolName }
    var timeRangeLabel: String { dayPart.timeRangeLabel }

    /// D-074: a daypart answers whether the item is useful sometime within it.
    /// This never feeds the remaining-day useful-hour count.
    var itemSummaryLevel: ItemAdviceLevel? {
        guard let first = itemAdvicePeriods.first, first.interval.start == interval.start,
              itemAdvicePeriods.last?.interval.end == interval.end else { return nil }
        for pair in zip(itemAdvicePeriods, itemAdvicePeriods.dropFirst()) where pair.0.interval.end != pair.1.interval.start {
            return nil
        }
        if itemAdvicePeriods.contains(where: { $0.level == .yes && !$0.isInferred }) { return .yes }
        if itemAdvicePeriods.contains(where: { $0.level == .maybe || $0.isInferred }) { return .maybe }
        return .no
    }

    var statusTitle: String {
        if item == .leatherJacket { return recommendation?.title ?? "—" }
        switch itemSummaryLevel {
        case .yes: return "YES"
        case .maybe: return "MAYBE"
        case .no: return "NO"
        case nil: return "—"
        }
    }

    var accessibilityLabel: String {
        let result: String
        if item == .leatherJacket {
            result = recommendation?.title ?? "Unavailable"
        } else {
            let intervals = itemAdvicePeriods.map { period in
                let range = ItemHomePresentation.range(period.interval, timezone: period.timezoneIdentifier)
                let status = ItemHomePresentation.levelTitle(period.level, item: item, inferred: period.isInferred)
                return "\(range), \(status)"
            }.joined(separator: ". ")
            let summary: String
            switch itemSummaryLevel {
            case .yes: summary = "YES, useful sometime within this daypart, not necessarily throughout"
            case .maybe: summary = "MAYBE, borderline or uncertain advice within this daypart"
            case .no: summary = "NO, not needed during this daypart"
            case nil: summary = "Unavailable"
            }
            result = [summary, intervals].filter { !$0.isEmpty }.joined(separator: ". ")
        }
        return isPast
            ? "\(label), \(timeRangeLabel), \(result), finished for today"
            : "\(label), \(timeRangeLabel), \(result)"
    }

    static func make(
        from evaluation: DailyEvaluation,
        at currentTime: Date
    ) -> [FixedDayPartPresentation] {
        make(timezoneIdentifier: evaluation.timezoneIdentifier, at: currentTime).map { context in
            let hours = evaluation.hours.filter {
                $0.timestamp >= context.interval.start && $0.timestamp < context.interval.end
            }
            let recommendation = HourlyRecommendation.mostProtective(in: hours.map(\.recommendation))
                .map { RecommendationPresentation(recommendation: $0) }
            return FixedDayPartPresentation(
                dayPart: context.dayPart, interval: context.interval,
                recommendation: recommendation, isPast: context.isPast
            )
        }
    }

    /// Retain exact intervals for accessibility; D-074 summarizes them in one visible badge.
    static func make(from evaluation: ItemDailyEvaluation, at currentTime: Date) -> [FixedDayPartPresentation] {
        make(timezoneIdentifier: evaluation.timezoneIdentifier, at: currentTime).map { context in
            var part = context
            part.item = evaluation.item
            part.itemAdvicePeriods = evaluation.periods.compactMap { period in
                let start = max(context.interval.start, period.interval.start)
                let end = min(context.interval.end, period.interval.end)
                guard start < end else { return nil }
                return ItemAdvicePeriod(
                    interval: DateInterval(start: start, end: end), timezoneIdentifier: period.timezoneIdentifier,
                    level: period.level, reasons: period.reasons, isInferred: period.isInferred
                )
            }
            return part
        }
    }

    private static func make(timezoneIdentifier: String, at currentTime: Date) -> [FixedDayPartPresentation] {
        guard let timezone = TimeZone(identifier: timezoneIdentifier) else { return [] }
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
            let isPast = end <= currentTime

            return FixedDayPartPresentation(
                dayPart: dayPart,
                interval: interval,
                recommendation: nil,
                isPast: isPast
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
    let itemResults: [ItemForecastResult]
    /// Planning-day display only. Never use these verdicts/counts as the remaining-day answer.
    let itemPlanningResults: [ItemForecastResult]
    let evaluationHour: Date?

    init(
        periods: [PeriodPresentation],
        hours: [HourlySuitabilityPresentation],
        weatherFetchedAt: Date,
        isUsingSavedWeather: Bool,
        isRefreshing: Bool,
        refreshFailed: Bool,
        refreshAvailableAt: Date,
        dayParts: [FixedDayPartPresentation] = [],
        displayHours: [HourlySuitabilityPresentation]? = nil,
        itemResults: [ItemForecastResult] = [],
        itemPlanningResults: [ItemForecastResult] = [],
        evaluationHour: Date? = nil
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
        self.itemResults = itemResults
        self.itemPlanningResults = itemPlanningResults
        self.evaluationHour = evaluationHour
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

nonisolated enum HomeTime {
    static func label(_ date: Date, timezone: String, offset: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timezone) ?? .gmt
        // Explicit 24-hour local times keep ranges compact. Offsets distinguish DST repeats.
        formatter.dateFormat = offset ? "HH:mm 'UTC'xxx" : "HH:mm"
        return formatter.string(from: date)
    }

    static func hourLabel(_ date: Date, timezone: String, offset: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timezone) ?? .gmt
        formatter.dateFormat = offset ? "HH 'UTC'xxx" : "HH"
        return formatter.string(from: date)
    }
}
