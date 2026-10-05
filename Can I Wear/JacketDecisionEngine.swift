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
