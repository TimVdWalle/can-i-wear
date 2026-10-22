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
        if arguments.contains("-ui-test-reset-selection") {
            UserDefaults.standard.removeObject(forKey: AppConfiguration.selectedItemIDsKey)
            UserDefaults.standard.set(false, forKey: AppConfiguration.itemSelectionCompletedKey)
        } else if !arguments.contains("-ui-test-preserve-selection") {
            let selected: Set<PredefinedItem>
            if let index = arguments.firstIndex(of: "-ui-test-items"), arguments.indices.contains(index + 1) {
                selected = Set(arguments[index + 1].split(separator: ",").compactMap { PredefinedItem(rawValue: String($0)) })
            } else {
                selected = scenario.hasPrefix("items-") ? [.leatherJacket, .sunglasses, .raincoat] : [.leatherJacket]
            }
            ItemSelectionStore().save(selected)
        }
        if arguments.contains("-ui-test-reset-home-introduction") {
            UserDefaults.standard.removeObject(forKey: AppConfiguration.homeIntroductionAcknowledgedKey)
            UserDefaults.standard.set(true, forKey: AppConfiguration.showHomeIntroductionKey)
        }

        if scenario.hasPrefix("items-") { return itemModel(scenario: scenario) }

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
            },
            itemResults: [jacketResult(evaluation)]
        )
    }

    private static func jacketResult(_ evaluation: DailyEvaluation) -> ItemForecastResult {
        let hours = evaluation.hours.map { evaluated in
            let recommendation = evaluated.recommendation
            return HourlyWeather(
                timestamp: evaluated.timestamp, timezoneIdentifier: evaluation.timezoneIdentifier,
                actualTemperatureCelsius: recommendation.reason == .excessiveHeat ? 24 : recommendation.level == .caution ? 18 : 12,
                apparentTemperatureCelsius: nil,
                precipitationAmountMillimeters: recommendation.reason == .precipitation ? 1 : 0,
                precipitationType: PrecipitationType.none,
                precipitationChanceFraction: recommendation.reason == .precipitationRisk ? 0.10 : 0,
                fogOrMistCondition: recommendation.reason == .fogOrMist ? .fog : FogOrMistCondition.none
            )
        }
        let forecast = NormalizedForecast(
            hours: hours,
            metadata: ForecastMetadata(fetchedAt: evaluation.interval.start, location: LocationIdentity(latitude: 50.85, longitude: 4.35))
        )
        return ItemForecastResult(item: .leatherJacket, evaluation: MultiItemRecommendationEngine().evaluate(
            forecast, for: .leatherJacket, now: evaluation.interval.start
        ))
    }

    private static func itemModel(scenario: String) -> RecommendationViewModel {
        let startHour = scenario == "items-early-morning" ? 0 : 6
        let start = ISO8601DateFormatter().date(from: "2026-10-13T00:00:00Z")!
            .addingTimeInterval(Double(startHour) * 3_600)
        let currentHour: Int
        switch scenario {
        case "items-early-morning": currentHour = 0
        case "items-last-hour", "items-evening-sun": currentHour = 23
        case "items-late-evening": currentHour = 22
        default: currentHour = 9
        }
        let now = start.addingTimeInterval(Double(currentHour - startHour) * 3_600 + 1_800)
        let location = LocationIdentity(latitude: 50.85, longitude: 4.35)
        let hours = (startHour..<24).map { hour -> HourlyWeather in
            let sun: Bool
            switch scenario {
            case "items-evening-sun": sun = hour == 18
            case "items-brief": sun = hour == 12
            case "items-separated": sun = hour == 12 || hour == 14
            case "items-borderline", "items-uncertain", "items-unavailable": sun = false
            default: sun = (12..<15).contains(hour)
            }
            let amount: Double = scenario == "items-jacket-four-periods" ? ((9..<12).contains(hour) || hour >= 18 ? 1 : 0)
                : scenario == "items-last-hour" ? (hour == 23 ? 1 : 0)
                : scenario == "items-early-morning" ? (hour < 6 ? 1 : 0)
                : scenario == "items-late-evening" ? ((18..<22).contains(hour) ? 1 : 0)
                : scenario == "items-borderline"
                ? ((14..<16).contains(hour) ? 0.1 : 0)
                : (["items-uncertain", "items-unavailable", "items-brief"].contains(scenario) ? 0 : ((15..<18).contains(hour) ? 1 : 0))
            let missingSky = scenario == "items-unavailable" || (scenario == "items-uncertain" && hour == 14)
            return HourlyWeather(
                timestamp: start.addingTimeInterval(Double(hour - startHour) * 3_600), timezoneIdentifier: "UTC",
                actualTemperatureCelsius: scenario == "items-no-jacket" ? nil : 12,
                apparentTemperatureCelsius: nil, precipitationAmountMillimeters: amount,
                precipitationType: PrecipitationType.none, precipitationChanceFraction: 0,
                isDaylight: hour < 19, skyCondition: missingSky ? nil : sun ? .clear : .overcast
            )
        }
        let forecast = NormalizedForecast(hours: hours, metadata: ForecastMetadata(fetchedAt: now, location: location))
        let store = UITestCacheStore()
        return RecommendationViewModel(
            locationProvider: UITestLocationProvider(reading: LocationReading(identity: location, accuracyMeters: 10, timestamp: now)),
            weatherProvider: UITestWeatherProvider(forecast: forecast),
            locationCache: LocationCache(store: store), weatherCache: WeatherCache(store: store),
            localityResolver: UITestLocalityResolver(), now: { now },
            initialState: scenario == "items-expired" ? .weatherDataExpired : .idle
        )
    }
}

private actor UITestCacheStore: CacheDataStore {
    private var values: [String: Data] = [:]
    func data(forKey key: String) -> Data? { values[key] }
    func set(_ data: Data?, forKey key: String) { values[key] = data }
}

private struct UITestLocationProvider: LocationProvider {
    let reading: LocationReading
    func currentLocation() async throws -> LocationReading { reading }
}

private struct UITestWeatherProvider: WeatherProvider {
    let forecast: NormalizedForecast
    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast { forecast }
}

private struct UITestLocalityResolver: LocalityResolving {
    func locality(for location: LocationIdentity) async -> String? { "Ghent" }
}
#endif
