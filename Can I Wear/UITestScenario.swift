#if DEBUG
import Foundation

@MainActor
enum UITestScenario {
    static var model: RecommendationViewModel? {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let flagIndex = arguments.firstIndex(of: "-ui-test-scenario"),
            arguments.indices.contains(flagIndex + 1)
        else { return nil }

        let scenario = arguments[flagIndex + 1]
        UserDefaults.standard.set(scenario == "diagnostics", forKey: DebugSettings.enabledKey)

        let state: RecommendationViewModel.State
        switch scenario {
        case "periods":
            state = .result(periodResult)
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

    private static var periodResult: DailyRecommendationPresentation {
        let start = Date(timeIntervalSince1970: 1_791_180_000)
        return DailyRecommendationPresentation(
            periods: [
                period(
                    start: start,
                    duration: 3 * 3_600,
                    level: .avoid,
                    reason: .precipitation
                ),
                period(
                    start: start.addingTimeInterval(3 * 3_600),
                    duration: 3 * 3_600,
                    level: .okay,
                    reason: .suitableTemperature
                ),
                period(
                    start: start.addingTimeInterval(6 * 3_600),
                    duration: 3 * 3_600,
                    level: .caution,
                    reason: .warmTemperature
                )
            ],
            weatherFetchedAt: Date(),
            isUsingSavedWeather: false,
            isRefreshing: false,
            refreshFailed: false,
            refreshAvailableAt: Date().addingTimeInterval(15 * 60)
        )
    }

    private static func singleResult(
        weatherAge: TimeInterval,
        isUsingSavedWeather: Bool,
        isRefreshing: Bool,
        level: RecommendationLevel = .caution,
        reason: RecommendationReason = .warmTemperature
    ) -> DailyRecommendationPresentation {
        let fetchedAt = Date().addingTimeInterval(-weatherAge)
        return DailyRecommendationPresentation(
            periods: [
                period(
                    start: Date(timeIntervalSince1970: 1_791_180_000),
                    duration: 9 * 3_600,
                    level: level,
                    reason: reason
                )
            ],
            weatherFetchedAt: fetchedAt,
            isUsingSavedWeather: isUsingSavedWeather,
            isRefreshing: isRefreshing,
            refreshFailed: false,
            refreshAvailableAt: fetchedAt.addingTimeInterval(15 * 60)
        )
    }

    private static func period(
        start: Date,
        duration: TimeInterval,
        level: RecommendationLevel,
        reason: RecommendationReason
    ) -> PeriodPresentation {
        PeriodPresentation(
            interval: DateInterval(start: start, duration: duration),
            timezoneIdentifier: "UTC",
            recommendation: RecommendationPresentation(
                recommendation: HourlyRecommendation(level: level, reason: reason)
            )
        )
    }
}
#endif
