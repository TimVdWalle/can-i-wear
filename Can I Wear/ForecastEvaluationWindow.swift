import Foundation

/// Shared local-day/timestamp validation, independent of item policy or presentation.
nonisolated struct ForecastEvaluationWindow: Sendable {
    struct Slot: Sendable {
        let timestamp: Date
        let weather: HourlyWeather?
    }

    let interval: DateInterval
    let timezoneIdentifier: String
    let slots: [Slot]

    init?(forecast: NormalizedForecast, now: Date, includesPlanningMorning: Bool = false) {
        let identifiers = Set(forecast.hours.compactMap(\.timezoneIdentifier))
        guard identifiers.count == 1,
              let identifier = identifiers.first,
              let timezone = TimeZone(identifier: identifier) else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        guard let day = calendar.dateInterval(of: .day, for: now) else { return nil }
        let start = includesPlanningMorning
            ? calendar.date(bySettingHour: 6, minute: 0, second: 0, of: day.start)
            : calendar.dateInterval(of: .hour, for: now)?.start
        guard let start, start < day.end else { return nil }

        var byTimestamp: [Date: HourlyWeather] = [:]
        for hour in forecast.hours where hour.timestamp >= start && hour.timestamp < day.end {
            guard byTimestamp.updateValue(hour, forKey: hour.timestamp) == nil else { return nil }
        }

        var slots: [Slot] = []
        var timestamp = start
        while timestamp < day.end {
            let weather = byTimestamp[timestamp]
            slots.append(Slot(
                timestamp: timestamp,
                weather: weather?.timezoneIdentifier == identifier ? weather : nil
            ))
            timestamp = timestamp.addingTimeInterval(3_600)
        }
        self.interval = DateInterval(start: start, end: day.end)
        self.timezoneIdentifier = identifier
        self.slots = slots
    }
}
