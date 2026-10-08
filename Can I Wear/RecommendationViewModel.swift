import Foundation
import Observation

nonisolated struct RecommendationPresentation: Equatable, Sendable {
    let title: String
    let reason: String
    let symbolName: String

    init(recommendation: HourlyRecommendation) {
        switch recommendation.level {
        case .okay:
            title = "Wear"
            symbolName = "checkmark.circle.fill"
        case .caution:
            title = "Maybe"
            symbolName = "exclamationmark.triangle.fill"
        case .avoid:
            title = "Don’t wear"
            symbolName = "xmark.circle.fill"
        }

        reason = switch recommendation.reason {
        case .suitableTemperature:
            "No precipitation is expected, and it should not feel too warm."
        case .warmTemperature:
            "It may feel warm for a leather jacket."
        case .excessiveHeat:
            "It is expected to feel too warm for a leather jacket."
        case .precipitationRisk:
            "There is a small chance of precipitation."
        case .precipitation:
            "Precipitation is expected and could damage leather."
        case .incompleteForecast:
            "Part of the forecast is uncertain."
        }
    }
}

nonisolated struct PeriodPresentation: Equatable, Sendable {
    let interval: DateInterval
    let timezoneIdentifier: String
    let recommendation: RecommendationPresentation
}

nonisolated struct DailyRecommendationPresentation: Equatable, Sendable {
    let periods: [PeriodPresentation]
    /// Present only when this result came from the weather cache.
    let cachedAge: TimeInterval?
    let isRefreshing: Bool
}

@MainActor
@Observable
final class RecommendationViewModel {
    typealias Sleep = @Sendable (Duration) async throws -> Void

    enum State: Equatable {
        case idle
        case loading
        case result(DailyRecommendationPresentation)
        case locationPermissionDenied
        case locationUnavailable
        case weatherUnavailable
        case weatherDataExpired
        case forecastIncomplete
    }

    private(set) var state: State

    private let locationProvider: any LocationProvider
    private let weatherProvider: any WeatherProvider
    private let dailyEngine: DailyRecommendationEngine
    private let periodEngine: DayPeriodEngine
    private let locationCache: LocationCache
    private let weatherCache: WeatherCache
    private let reuseConfig: ReusePolicyConfig
    private let now: @Sendable () -> Date
    private let sleep: Sleep

    convenience init() {
        self.init(
            locationProvider: CoreLocationProvider(),
            weatherProvider: OpenMeteoProvider()
        )
    }

    convenience init(initialState: State) {
        self.init(
            locationProvider: CoreLocationProvider(),
            weatherProvider: OpenMeteoProvider(),
            initialState: initialState
        )
    }

    init(
        locationProvider: any LocationProvider,
        weatherProvider: any WeatherProvider,
        dailyEngine: DailyRecommendationEngine = DailyRecommendationEngine(),
        periodEngine: DayPeriodEngine = DayPeriodEngine(),
        locationCache: LocationCache = LocationCache(),
        weatherCache: WeatherCache = WeatherCache(),
        reuseConfig: ReusePolicyConfig = AppConfiguration.reusePolicy,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping Sleep = { duration in try await Task.sleep(for: duration) },
        initialState: State = .idle
    ) {
        self.locationProvider = locationProvider
        self.weatherProvider = weatherProvider
        self.dailyEngine = dailyEngine
        self.periodEngine = periodEngine
        self.locationCache = locationCache
        self.weatherCache = weatherCache
        self.reuseConfig = reuseConfig
        self.now = now
        self.sleep = sleep
        state = initialState
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        state = .loading

        let location: LocationReading
        if let cachedLocation = await locationCache.validReading(at: now()) {
            location = cachedLocation
        } else {
            do {
                location = try await locationProvider.currentLocation()
                await locationCache.save(location)
            } catch LocationProviderError.permissionDenied {
                state = .locationPermissionDenied
                return
            } catch LocationProviderError.cancelled {
                state = .idle
                return
            } catch {
                state = .locationUnavailable
                return
            }
        }

        if let cached = await cachedPresentation(
            for: location.identity,
            isRefreshing: true
        ) {
            state = .result(cached)
        }

        let liveForecast: NormalizedForecast
        do {
            liveForecast = try await fetchLiveForecast(for: location.identity)
        } catch WeatherProviderError.cancelled {
            await finishRefreshWithCache(
                for: location.identity,
                otherwise: .idle,
                whenExpired: .idle
            )
            return
        } catch {
            await finishRefreshWithCache(
                for: location.identity,
                otherwise: .weatherUnavailable,
                whenExpired: .weatherDataExpired
            )
            return
        }

        guard let presentation = makePresentation(
            from: liveForecast,
            at: now(),
            cachedAge: nil,
            isRefreshing: false
        ) else {
            await finishRefreshWithCache(
                for: location.identity,
                otherwise: .forecastIncomplete,
                whenExpired: .forecastIncomplete
            )
            return
        }

        await weatherCache.save(liveForecast)
        state = .result(presentation)
    }

    func retry() async {
        state = .idle
        await loadIfNeeded()
    }

    private func fetchLiveForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        let weatherProvider = weatherProvider
        let timeout = reuseConfig.weatherRequestTimeout
        let sleep = sleep

        return try await withThrowingTaskGroup(of: NormalizedForecast.self) { group in
            group.addTask {
                try await weatherProvider.hourlyForecast(for: location)
            }
            group.addTask {
                try await sleep(timeout)
                throw WeatherProviderError.timedOut
            }
            defer { group.cancelAll() }

            guard let forecast = try await group.next() else {
                throw WeatherProviderError.unavailable
            }
            return forecast
        }
    }

    private func cachedPresentation(
        for location: LocationIdentity,
        isRefreshing: Bool
    ) async -> DailyRecommendationPresentation? {
        let currentTime = now()
        guard case .valid(let forecast) = await weatherCache.lookup(
            at: currentTime,
            for: location
        ) else {
            return nil
        }
        return makePresentation(
            from: forecast,
            at: currentTime,
            cachedAge: currentTime.timeIntervalSince(forecast.metadata.fetchedAt),
            isRefreshing: isRefreshing
        )
    }

    private func finishRefreshWithCache(
        for location: LocationIdentity,
        otherwise fallbackState: State,
        whenExpired expiredState: State
    ) async {
        let currentTime = now()
        switch await weatherCache.lookup(at: currentTime, for: location) {
        case .valid(let forecast):
            guard let cached = makePresentation(
                from: forecast,
                at: currentTime,
                cachedAge: currentTime.timeIntervalSince(forecast.metadata.fetchedAt),
                isRefreshing: false
            ) else {
                state = fallbackState
                return
            }
            state = .result(cached)
        case .expired:
            state = expiredState
        case .unavailable:
            state = fallbackState
        }
    }

    private func makePresentation(
        from forecast: NormalizedForecast,
        at currentTime: Date,
        cachedAge: TimeInterval?,
        isRefreshing: Bool
    ) -> DailyRecommendationPresentation? {
        guard let evaluation = dailyEngine.evaluateHours(forecast, now: currentTime) else {
            return nil
        }
        let periods = periodEngine.periods(for: evaluation)
        guard !periods.isEmpty else { return nil }

        return DailyRecommendationPresentation(
            periods: periods.map {
                PeriodPresentation(
                    interval: $0.interval,
                    timezoneIdentifier: $0.timezoneIdentifier,
                    recommendation: RecommendationPresentation(recommendation: $0.recommendation)
                )
            },
            cachedAge: cachedAge,
            isRefreshing: isRefreshing
        )
    }
}
