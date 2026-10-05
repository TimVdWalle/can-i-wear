import Foundation

nonisolated enum RecommendationLevel: Int, Comparable, Sendable {
    case okay
    case caution
    case avoid

    static func < (lhs: RecommendationLevel, rhs: RecommendationLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

nonisolated enum RecommendationReason: Equatable, Sendable {
    case suitableTemperature
    case warmTemperature
    case excessiveHeat
    case precipitationRisk
    case precipitation
    case incompleteForecast
}

nonisolated struct HourlyRecommendation: Equatable, Sendable {
    let level: RecommendationLevel
    let reason: RecommendationReason
}

nonisolated struct JacketDecisionEngine: Sendable {
    private let config: JacketRulesConfig

    init(config: JacketRulesConfig = AppConfiguration.jacketRules) {
        self.config = config
    }

    /// Returns nil when the hour lacks valid inputs required for a safe decision.
    func evaluate(_ hour: HourlyWeather) -> HourlyRecommendation? {
        guard
            let precipitationAmount = hour.precipitationAmountMillimeters,
            precipitationAmount.isFinite,
            precipitationAmount >= 0,
            let precipitationChance = hour.precipitationChanceFraction,
            precipitationChance.isFinite,
            (0...1).contains(precipitationChance),
            hour.precipitationType != .unknown,
            let temperature = selectedTemperature(for: hour)
        else {
            return nil
        }

        let precipitationLevel = precipitationLevel(
            amount: precipitationAmount,
            type: hour.precipitationType,
            chance: precipitationChance
        )
        let temperatureLevel = temperatureLevel(temperature)

        if precipitationLevel == .avoid {
            return HourlyRecommendation(level: .avoid, reason: .precipitation)
        }
        if temperatureLevel == .avoid {
            return HourlyRecommendation(level: .avoid, reason: .excessiveHeat)
        }
        if precipitationLevel == .caution {
            return HourlyRecommendation(level: .caution, reason: .precipitationRisk)
        }
        if temperatureLevel == .caution {
            return HourlyRecommendation(level: .caution, reason: .warmTemperature)
        }
        return HourlyRecommendation(level: .okay, reason: .suitableTemperature)
    }

    private func selectedTemperature(for hour: HourlyWeather) -> Double? {
        let temperatures = [
            hour.actualTemperatureCelsius,
            hour.apparentTemperatureCelsius
        ].compactMap { $0 }

        guard !temperatures.isEmpty, temperatures.allSatisfy(\.isFinite) else {
            return nil
        }
        return temperatures.max()
    }

    private func precipitationLevel(
        amount: Double,
        type: PrecipitationType?,
        chance: Double
    ) -> RecommendationLevel {
        if amount > config.maximumDryPrecipitationAmountMillimeters || type?.isPrecipitation == true {
            return .avoid
        }
        if chance >= config.avoidPrecipitationChanceFraction {
            return .avoid
        }
        if chance >= config.cautionPrecipitationChanceFraction {
            return .caution
        }
        return .okay
    }

    private func temperatureLevel(_ temperature: Double) -> RecommendationLevel {
        if temperature <= config.maximumOkayTemperatureCelsius {
            return .okay
        }
        if temperature <= config.maximumCautionTemperatureCelsius {
            return .caution
        }
        return .avoid
    }
}

nonisolated struct DailyRecommendationEngine: Sendable {
    private let hourlyEngine: JacketDecisionEngine

    init(hourlyEngine: JacketDecisionEngine = JacketDecisionEngine()) {
        self.hourlyEngine = hourlyEngine
    }

    /// Summarizes the remaining local calendar day. Returns nil when timezone or
    /// hourly coverage is insufficient for the approved conservative policy.
    func evaluate(_ forecast: NormalizedForecast, now: Date) -> HourlyRecommendation? {
        guard
            let timezoneIdentifier = forecast.hours.compactMap(\.timezoneIdentifier).first,
            let timezone = TimeZone(identifier: timezoneIdentifier)
        else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone

        guard
            let day = calendar.dateInterval(of: .day, for: now),
            let currentHour = calendar.dateInterval(of: .hour, for: now)?.start,
            currentHour < day.end
        else {
            return nil
        }

        var expectedTimestamps: [Date] = []
        var timestamp = currentHour
        while timestamp < day.end {
            expectedTimestamps.append(timestamp)
            timestamp = timestamp.addingTimeInterval(3_600)
        }

        var recommendations: [HourlyRecommendation?] = []
        for expectedTimestamp in expectedTimestamps {
            let matches = forecast.hours.filter { $0.timestamp == expectedTimestamp }
            guard matches.count <= 1 else {
                return nil
            }

            guard let hour = matches.first, hour.timezoneIdentifier == timezoneIdentifier else {
                recommendations.append(nil)
                continue
            }
            recommendations.append(hourlyEngine.evaluate(hour))
        }

        let missingIndices = recommendations.indices.filter { recommendations[$0] == nil }
        if missingIndices.count == 1, let missingIndex = missingIndices.first {
            guard
                missingIndex > recommendations.startIndex,
                missingIndex < recommendations.index(before: recommendations.endIndex),
                let previous = recommendations[recommendations.index(before: missingIndex)],
                let next = recommendations[recommendations.index(after: missingIndex)]
            else {
                return nil
            }

            recommendations[missingIndex] = HourlyRecommendation(
                level: max(.caution, previous.level, next.level),
                reason: .incompleteForecast
            )
        } else if !missingIndices.isEmpty {
            return nil
        }

        return recommendations.compactMap { $0 }.max(by: Self.isLessProtective)
    }

    private static func isLessProtective(
        _ lhs: HourlyRecommendation,
        _ rhs: HourlyRecommendation
    ) -> Bool {
        if lhs.level != rhs.level {
            return lhs.level < rhs.level
        }
        return reasonPriority(lhs.reason) < reasonPriority(rhs.reason)
    }

    private static func reasonPriority(_ reason: RecommendationReason) -> Int {
        switch reason {
        case .suitableTemperature:
            0
        case .warmTemperature:
            1
        case .incompleteForecast:
            2
        case .precipitationRisk:
            3
        case .excessiveHeat:
            4
        case .precipitation:
            5
        }
    }
}

private extension PrecipitationType {
    nonisolated var isPrecipitation: Bool {
        switch self {
        case .drizzle, .rain, .hail, .snow, .sleet, .mixed:
            true
        case .none, .unknown:
            false
        }
    }
}
