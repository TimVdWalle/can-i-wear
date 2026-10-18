#if DEBUG
import Foundation

@MainActor
enum UITestScenario {
    static var homePresentationModeOverride: HomePresentationMode? {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let flagIndex = arguments.firstIndex(of: "-ui-test-home-mode"),
            arguments.indices.contains(flagIndex + 1)
        else { return nil }
        return arguments[flagIndex + 1] == "compact" ? .compact : .guided
    }

    static var model: RecommendationViewModel? {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let flagIndex = arguments.firstIndex(of: "-ui-test-scenario"),
            arguments.indices.contains(flagIndex + 1)
        else { return nil }

        let scenario = arguments[flagIndex + 1]
        UserDefaults.standard.set(scenario == "diagnostics", forKey: DebugSettings.enabledKey)
        if arguments.contains("-ui-test-reset-home-introduction") {
            UserDefaults.standard.removeObject(forKey: AppConfiguration.homeIntroductionAcknowledgedKey)
            UserDefaults.standard.set(true, forKey: AppConfiguration.showHomeIntroductionKey)
        }

        let state: RecommendationViewModel.State
        switch scenario {
        case "periods":
            state = .result(result(levels: Array(repeating: .okay, count: 6)
                + Array(repeating: .caution, count: 3)
                + Array(repeating: .okay, count: 6)
                + Array(repeating: .avoid, count: 3)))
        case "many-periods":
            state = .result(result(levels: [.okay, .caution, .avoid, .okay, .caution, .avoid]
                .flatMap { Array(repeating: $0, count: 3) }))
        case "okay":
            state = .result(singleResult(weatherAge: 0, isUsingSavedWeather: false, isRefreshing: false, level: .okay, reason: .suitableTemperature))
        case "loading": state = .loading
        case "denied": state = .locationPermissionDenied
        case "unavailable": state = .weatherUnavailable
        case "incomplete": state = .forecastIncomplete
        case "cached":
            state = .result(singleResult(weatherAge: 10 * 60, isUsingSavedWeather: true, isRefreshing: false))
        case "refreshing":
            state = .result(singleResult(weatherAge: 60, isUsingSavedWeather: true, isRefreshing: true))
        case "expired":
            state = .weatherDataExpired
        case "fog":
            state = .result(singleResult(
                weatherAge: 0,
                isUsingSavedWeather: false,
                isRefreshing: false,
                level: .avoid,
                reason: .fogOrMist
            ))
        case "diagnostics":
            state = .result(singleResult(weatherAge: 0, isUsingSavedWeather: false, isRefreshing: false))
        default:
            return nil
        }
        return RecommendationViewModel(initialState: state)
    }

    private static func singleResult(
        weatherAge: TimeInterval,
        isUsingSavedWeather: Bool,
        isRefreshing: Bool,
        level: RecommendationLevel = .caution,
        reason: RecommendationReason = .warmTemperature
    ) -> DailyRecommendationPresentation {
        result(levels: Array(repeating: level, count: 18), reason: reason,
               weatherAge: weatherAge, isUsingSavedWeather: isUsingSavedWeather, isRefreshing: isRefreshing)
    }

    private static func result(
        levels: [RecommendationLevel],
        reason: RecommendationReason? = nil,
        weatherAge: TimeInterval = 0,
        isUsingSavedWeather: Bool = false,
        isRefreshing: Bool = false
    ) -> DailyRecommendationPresentation {
        let start = ISO8601DateFormatter().date(from: "2026-10-13T06:00:00Z")!
        let evaluation = DailyEvaluation(
            interval: DateInterval(start: start, duration: Double(levels.count) * 3_600),
            timezoneIdentifier: "UTC",
            hours: levels.enumerated().map { index, level in
                EvaluatedHour(timestamp: start.addingTimeInterval(Double(index) * 3_600), recommendation: HourlyRecommendation(
                    level: level,
                    reason: reason ?? (level == .okay ? .suitableTemperature : level == .caution ? .warmTemperature : .precipitation)
                ))
            }
        )
        let fetchedAt = Date().addingTimeInterval(-weatherAge)
        return DailyRecommendationPresentation(
            periods: DayPeriodEngine().periods(for: evaluation).map {
                PeriodPresentation(interval: $0.interval, timezoneIdentifier: $0.timezoneIdentifier,
                                   recommendation: RecommendationPresentation(recommendation: $0.recommendation))
            },
            hours: evaluation.hours.map { HourlySuitabilityPresentation(hour: $0, timezoneIdentifier: evaluation.timezoneIdentifier) },
            weatherFetchedAt: fetchedAt,
            isUsingSavedWeather: isUsingSavedWeather,
            isRefreshing: isRefreshing,
            refreshFailed: false,
            refreshAvailableAt: fetchedAt.addingTimeInterval(15 * 60),
            dayParts: FixedDayPartPresentation.make(from: evaluation, at: start),
            displayHours: evaluation.hours.map {
                HourlySuitabilityPresentation(
                    hour: $0,
                    timezoneIdentifier: evaluation.timezoneIdentifier,
                    isPast: false
                )
            }
        )
    }
}
#endif
