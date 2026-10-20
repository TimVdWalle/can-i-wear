import Foundation
@testable import Can_I_Wear

enum ItemEngineFixtures {
    static let dayEnd = date(year: 2026, month: 10, day: 21)

    static func date(year: Int, month: Int, day: Int, timezone: String = "UTC") -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func hour(
        at timestamp: Date = dayEnd.addingTimeInterval(-3_600),
        timezone: String? = "UTC",
        actual: Double? = 12,
        apparent: Double? = nil,
        amount: Double? = 0,
        chance: Double? = 0,
        type: PrecipitationType? = PrecipitationType.none,
        fog: FogOrMistCondition? = nil,
        wind: Double? = nil,
        daylight: Bool? = true,
        sky: SkyCondition? = .clear,
        uv: Double? = nil
    ) -> HourlyWeather {
        HourlyWeather(
            timestamp: timestamp, timezoneIdentifier: timezone,
            actualTemperatureCelsius: actual, apparentTemperatureCelsius: apparent,
            precipitationAmountMillimeters: amount, precipitationType: type,
            precipitationChanceFraction: chance, fogOrMistCondition: fog,
            windSpeedKilometersPerHour: wind, isDaylight: daylight, skyCondition: sky, uvIndex: uv
        )
    }

    static func forecast(_ hours: [HourlyWeather]) -> NormalizedForecast {
        NormalizedForecast(
            hours: hours,
            metadata: ForecastMetadata(fetchedAt: dayEnd, location: LocationIdentity(latitude: 50.85, longitude: 4.35))
        )
    }

    static func hour(for item: PredefinedItem, level: ItemAdviceLevel, at timestamp: Date) -> HourlyWeather {
        switch item {
        case .leatherJacket:
            return hour(at: timestamp, chance: level == .yes ? 0 : level == .maybe ? 0.10 : 0.20)
        case .warmCoat:
            return hour(at: timestamp, actual: level == .yes ? 5 : level == .maybe ? 6 : 13)
        case .sweater:
            return hour(at: timestamp, actual: level == .yes ? 12 : level == .maybe ? 13 : 19)
        case .gloves:
            return hour(at: timestamp, actual: level == .yes ? 5 : level == .maybe ? 6 : 11)
        case .shorts:
            return hour(at: timestamp, actual: level == .yes ? 22 : level == .maybe ? 17 : 16)
        case .raincoat:
            return hour(at: timestamp, amount: level == .yes ? 0.5 : level == .maybe ? 0.1 : 0)
        case .sunglasses:
            return hour(at: timestamp, sky: level == .yes ? .clear : level == .maybe ? .partlyCloudy : .overcast)
        }
    }

    static func sequence(_ levels: [ItemAdviceLevel], for item: PredefinedItem) -> NormalizedForecast {
        let start = dayEnd.addingTimeInterval(-Double(levels.count) * 3_600)
        return forecast(levels.enumerated().map { index, level in
            hour(for: item, level: level, at: start.addingTimeInterval(Double(index) * 3_600))
        })
    }
}
