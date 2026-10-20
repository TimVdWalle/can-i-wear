import Foundation

nonisolated enum DailyAggregationPolicy: Sendable {
    case canIWear
    case shouldIWear
}

nonisolated enum PredefinedItem: String, CaseIterable, Codable, Sendable {
    case leatherJacket
    case warmCoat
    case sweater
    case raincoat
    case sunglasses
    case shorts
    case gloves

    var dailyPolicy: DailyAggregationPolicy {
        self == .leatherJacket ? .canIWear : .shouldIWear
    }
}

/// Semantic hourly levels, not display strings or a common daily algorithm.
nonisolated enum ItemAdviceLevel: Equatable, Sendable {
    case yes
    case maybe
    case no
}

nonisolated enum ItemAdviceReason: Equatable, Sendable {
    case jacket(RecommendationReason)
    case temperature(celsius: Double)
    case precipitation
    case lightPrecipitation
    case precipitationChance
    case windDrivenPrecipitation
    case dryWeather
    case sunshine
    case partlyCloudy
    case overcast
    case fogOrMist
    case night
    case highUV
    case incompleteForecast
}

nonisolated struct ItemHourlyAdvice: Equatable, Sendable {
    let level: ItemAdviceLevel
    let reason: ItemAdviceReason

    init(level: ItemAdviceLevel, reason: ItemAdviceReason) {
        self.level = level
        self.reason = reason
    }

    init(jacket recommendation: HourlyRecommendation) {
        switch recommendation.level {
        case .okay: level = .yes
        case .caution: level = .maybe
        case .avoid: level = .no
        }
        reason = recommendation.reason == .incompleteForecast
            ? .incompleteForecast : .jacket(recommendation.reason)
    }
}

nonisolated struct EvaluatedItemHour: Equatable, Sendable {
    let timestamp: Date
    let advice: ItemHourlyAdvice

    var isInferred: Bool { advice.reason == .incompleteForecast }
}

nonisolated enum ItemDailyVerdict: Equatable, Sendable {
    case goodForRemainingDay
    case caution
    case restricted
    case useful
    case brieflyUseful
    case maybeUseful
    case notNeeded
}

nonisolated struct ItemAdvicePeriod: Equatable, Sendable {
    let interval: DateInterval
    let timezoneIdentifier: String
    let level: ItemAdviceLevel
    /// Same-level hours may have different reasons. Do not fabricate a common weather cause.
    let reasons: [ItemAdviceReason]
    let isInferred: Bool
}

nonisolated struct ItemDailyEvaluation: Equatable, Sendable {
    let item: PredefinedItem
    let interval: DateInterval
    let timezoneIdentifier: String
    let verdict: ItemDailyVerdict
    let reasons: [ItemAdviceReason]
    let hours: [EvaluatedItemHour]
    let periods: [ItemAdvicePeriod]

    /// Raw, directly evaluated useful/suitable hours, never period-expanded or inferred time.
    var qualifyingHours: [EvaluatedItemHour] {
        hours.filter { $0.advice.level == .yes && !$0.isInferred }
    }
}

nonisolated struct ItemForecastResult: Equatable, Sendable {
    let item: PredefinedItem
    /// Nil means this item's daily coverage is unavailable, not a negative recommendation.
    let evaluation: ItemDailyEvaluation?
}
