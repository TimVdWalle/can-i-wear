import Foundation

nonisolated struct ItemDecisionEngine: Sendable {
    private let config: ItemRulesConfig
    private let jacketEngine: JacketDecisionEngine

    init(
        config: ItemRulesConfig = AppConfiguration.itemRules,
        jacketEngine: JacketDecisionEngine = JacketDecisionEngine()
    ) {
        self.config = config
        self.jacketEngine = jacketEngine
    }

    func evaluate(_ hour: HourlyWeather, for item: PredefinedItem) -> ItemHourlyAdvice? {
        switch item {
        case .leatherJacket: jacketEngine.evaluate(hour).map(ItemHourlyAdvice.init(jacket:))
        case .warmCoat: coldWeather(hour, rules: config.warmCoat)
        case .sweater: coldWeather(hour, rules: config.sweater)
        case .gloves: coldWeather(hour, rules: config.gloves)
        case .shorts: shorts(hour)
        case .raincoat: raincoat(hour)
        case .sunglasses: sunglasses(hour)
        }
    }

    private func temperature(_ hour: HourlyWeather) -> Double? {
        if let apparent = hour.apparentTemperatureCelsius, apparent.isFinite { return apparent }
        guard let value = hour.actualTemperatureCelsius, value.isFinite else { return nil }
        return value
    }

    private func coldWeather(_ hour: HourlyWeather, rules: ColdWeatherItemRules) -> ItemHourlyAdvice? {
        guard let value = temperature(hour) else { return nil }
        let level: ItemAdviceLevel = value <= rules.maximumUsefulCelsius ? .yes
            : value <= rules.maximumMaybeCelsius ? .maybe : .no
        return ItemHourlyAdvice(level: level, reason: .temperature(celsius: value))
    }

    private func shorts(_ hour: HourlyWeather) -> ItemHourlyAdvice? {
        guard let value = temperature(hour) else { return nil }
        let level: ItemAdviceLevel = value >= config.shortsMinimumUsefulCelsius ? .yes
            : value >= config.shortsMinimumMaybeCelsius ? .maybe : .no
        return ItemHourlyAdvice(level: level, reason: .temperature(celsius: value))
    }

    private func raincoat(_ hour: HourlyWeather) -> ItemHourlyAdvice? {
        guard let amount = hour.precipitationAmountMillimeters, amount.isFinite, amount >= 0,
              let chance = hour.precipitationChanceFraction, chance.isFinite,
              (0...1).contains(chance) else { return nil }
        if amount >= config.raincoatUsefulAmountMillimeters {
            return ItemHourlyAdvice(level: .yes, reason: .precipitation)
        }
        if amount > 0 {
            if let wind = hour.windSpeedKilometersPerHour, wind.isFinite,
               wind >= config.raincoatWindUpgradeKilometersPerHour {
                return ItemHourlyAdvice(level: .yes, reason: .windDrivenPrecipitation)
            }
            return ItemHourlyAdvice(level: .maybe, reason: .lightPrecipitation)
        }
        if chance >= config.raincoatMaybeChanceFraction {
            return ItemHourlyAdvice(level: .maybe, reason: .precipitationChance)
        }
        return ItemHourlyAdvice(level: .no, reason: .dryWeather)
    }

    private func sunglasses(_ hour: HourlyWeather) -> ItemHourlyAdvice? {
        // Required sky and daylight must be present even when UV is high or it is night.
        guard let daylight = hour.isDaylight, let sky = hour.skyCondition else { return nil }
        guard daylight else { return ItemHourlyAdvice(level: .no, reason: .night) }
        if let uv = hour.uvIndex, uv.isFinite, uv >= config.sunglassesUsefulUVIndex {
            return ItemHourlyAdvice(level: .yes, reason: .highUV)
        }
        switch sky {
        case .clear, .mainlyClear: return ItemHourlyAdvice(level: .yes, reason: .sunshine)
        case .partlyCloudy: return ItemHourlyAdvice(level: .maybe, reason: .partlyCloudy)
        case .overcast: return ItemHourlyAdvice(level: .no, reason: .overcast)
        case .fogOrMist: return ItemHourlyAdvice(level: .no, reason: .fogOrMist)
        }
    }
}
