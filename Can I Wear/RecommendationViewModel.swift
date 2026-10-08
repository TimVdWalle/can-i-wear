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
        case .fogOrMist:
            "Fog is expected."
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
    let diagnostics: DebugDiagnostics

    private let locationProvider: any LocationProvider
    private let weatherProvider: any WeatherProvider
    private let dailyEngine: DailyRecommendationEngine
    private let periodEngine: DayPeriodEngine
    private let locationCache: LocationCache
    private let weatherCache: WeatherCache
    private let reuseConfig: ReusePolicyConfig
    private let now: @Sendable () -> Date
    private let sleep: Sleep
    private var latestLocation: LocationReading?
    private var latestLocationSource = "Unavailable"
    private var latestLocationCacheStatus = "Unavailable"
    private var latestForecast: NormalizedForecast?
    private var latestWeatherTrigger = "Unavailable"
    private var latestWeatherOutcome = "Unavailable"
    private var latestWeatherCacheStatus = "Unavailable"
    private var latestWeatherDuration: TimeInterval?

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
        diagnostics: DebugDiagnostics? = nil,
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
        self.diagnostics = diagnostics ?? DebugDiagnostics()
        self.now = now
        self.sleep = sleep
        state = initialState
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        state = .loading
        diagnostics.record(
            category: .session,
            outcome: .started,
            title: "Recommendation load",
            detail: "Initial load or user retry requested."
        )

        let location: LocationReading
        switch await locationCache.lookup(at: now()) {
        case .valid(let cachedLocation, let age):
            location = cachedLocation
            latestLocation = cachedLocation
            latestLocationSource = "Location cache"
            latestLocationCacheStatus = "Reused: fresh and sufficiently accurate"
            diagnostics.updateLocation(
                cachedLocation,
                source: latestLocationSource,
                ageSeconds: age,
                cacheStatus: latestLocationCacheStatus
            )
            diagnostics.record(
                category: .cache,
                outcome: .reused,
                title: "Location cache",
                detail: "Reused a \(Self.durationText(age))-old reading with \(Self.accuracyText(cachedLocation.accuracyMeters))."
            )
        case .unavailable(let reason):
            diagnostics.record(
                category: .cache,
                outcome: .rejected,
                title: "Location cache",
                detail: Self.locationCacheReason(reason)
            )
            let startedAt = now()
            diagnostics.record(
                category: .location,
                outcome: .started,
                title: "Location request",
                detail: "Requested because the cache was not reusable: \(Self.locationCacheReason(reason))"
            )
            do {
                location = try await locationProvider.currentLocation()
                await locationCache.save(location)
                let duration = max(0, now().timeIntervalSince(startedAt))
                latestLocation = location
                latestLocationSource = "Live device location"
                latestLocationCacheStatus = "Fetched because cache was rejected: \(Self.locationCacheReason(reason))"
                diagnostics.updateLocation(
                    location,
                    source: latestLocationSource,
                    ageSeconds: max(0, now().timeIntervalSince(location.timestamp)),
                    cacheStatus: latestLocationCacheStatus
                )
                diagnostics.record(
                    category: .location,
                    outcome: .success,
                    title: "Location request",
                    detail: "Accepted and cached a reading with \(Self.accuracyText(location.accuracyMeters)).",
                    durationSeconds: duration
                )
            } catch LocationProviderError.permissionDenied {
                recordLocationFailure("Permission denied", startedAt: startedAt)
                state = .locationPermissionDenied
                return
            } catch LocationProviderError.cancelled {
                recordLocationFailure("Request cancelled", startedAt: startedAt)
                state = .idle
                return
            } catch {
                recordLocationFailure("\(error)", startedAt: startedAt)
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
        let weatherStartedAt = now()
        diagnostics.record(
            category: .weather,
            outcome: .started,
            title: "Weather request",
            detail: "Requested a live forecast after the location was resolved. Timeout: \(Self.durationText(reuseConfig.weatherRequestTimeout.timeInterval))."
        )
        do {
            liveForecast = try await fetchLiveForecast(for: location.identity)
        } catch WeatherProviderError.cancelled {
            recordWeatherFailure("Request cancelled", startedAt: weatherStartedAt)
            await finishRefreshWithCache(
                for: location.identity,
                otherwise: .idle,
                whenExpired: .idle
            )
            return
        } catch {
            recordWeatherFailure(Self.weatherErrorText(error), startedAt: weatherStartedAt)
            await finishRefreshWithCache(
                for: location.identity,
                otherwise: .weatherUnavailable,
                whenExpired: .weatherDataExpired
            )
            return
        }

        let weatherDuration = max(0, now().timeIntervalSince(weatherStartedAt))
        latestForecast = liveForecast
        latestWeatherTrigger = "Live refresh after location resolution"
        latestWeatherOutcome = "Success"
        latestWeatherCacheStatus = "Live response; saved after successful evaluation"
        latestWeatherDuration = weatherDuration
        diagnostics.updateWeather(
            liveForecast,
            provider: weatherProvider.diagnosticName,
            trigger: latestWeatherTrigger,
            outcome: latestWeatherOutcome,
            durationSeconds: weatherDuration,
            cacheStatus: latestWeatherCacheStatus
        )
        diagnostics.record(
            category: .weather,
            outcome: .success,
            title: "Weather request",
            detail: "Received \(liveForecast.hours.count) normalized hourly records from \(weatherProvider.diagnosticName).",
            durationSeconds: weatherDuration
        )

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
        diagnostics.record(
            category: .cache,
            outcome: .success,
            title: "Weather cache save",
            detail: "Saved the valid normalized forecast after evaluation."
        )
        state = .result(presentation)
    }

    func retry() async {
        diagnostics.record(
            category: .session,
            outcome: .started,
            title: "Retry requested",
            detail: "The user requested a new location/cache/weather attempt."
        )
        state = .idle
        await loadIfNeeded()
    }

    func refreshDebugSetting() {
        let wasEnabled = diagnostics.isEnabled
        diagnostics.refreshSetting()
        guard !wasEnabled, diagnostics.isEnabled else { return }

        if let latestLocation {
            diagnostics.updateLocation(
                latestLocation,
                source: latestLocationSource,
                ageSeconds: max(0, now().timeIntervalSince(latestLocation.timestamp)),
                cacheStatus: latestLocationCacheStatus
            )
        }
        if let latestForecast {
            diagnostics.updateWeather(
                latestForecast,
                provider: weatherProvider.diagnosticName,
                trigger: latestWeatherTrigger,
                outcome: latestWeatherOutcome,
                durationSeconds: latestWeatherDuration,
                cacheStatus: latestWeatherCacheStatus
            )
            _ = makePresentation(
                from: latestForecast,
                at: now(),
                cachedAge: state.result?.cachedAge,
                isRefreshing: false
            )
        }
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
        switch await weatherCache.diagnosticLookup(
            at: currentTime,
            for: location
        ) {
        case .valid(let forecast, let age, let distance):
            latestForecast = forecast
            latestWeatherTrigger = "Startup cache lookup"
            latestWeatherOutcome = "Reused while live refresh runs"
            latestWeatherCacheStatus = "Fresh; location separation \(Self.distanceText(distance))"
            latestWeatherDuration = nil
            diagnostics.updateWeather(
                forecast,
                provider: weatherProvider.diagnosticName,
                trigger: latestWeatherTrigger,
                outcome: latestWeatherOutcome,
                durationSeconds: nil,
                cacheStatus: latestWeatherCacheStatus
            )
            diagnostics.record(
                category: .cache,
                outcome: .reused,
                title: "Weather cache",
                detail: "Reused a \(Self.durationText(age))-old forecast; location separation \(Self.distanceText(distance))."
            )
            return makePresentation(
                from: forecast,
                at: currentTime,
                cachedAge: age,
                isRefreshing: isRefreshing
            )
        case .expired(_, let age, let distance):
            diagnostics.record(
                category: .cache,
                outcome: .rejected,
                title: "Weather cache",
                detail: "Expired at age \(Self.durationText(age)); location separation \(Self.distanceText(distance))."
            )
            return nil
        case .unavailable(let reason):
            diagnostics.record(
                category: .cache,
                outcome: .rejected,
                title: "Weather cache",
                detail: Self.weatherCacheReason(reason)
            )
            return nil
        }
    }

    private func finishRefreshWithCache(
        for location: LocationIdentity,
        otherwise fallbackState: State,
        whenExpired expiredState: State
    ) async {
        let currentTime = now()
        switch await weatherCache.diagnosticLookup(at: currentTime, for: location) {
        case .valid(let forecast, let age, let distance):
            latestForecast = forecast
            latestWeatherTrigger = "Fallback after live request failure"
            latestWeatherOutcome = "Reused cached forecast"
            latestWeatherCacheStatus = "Fresh; location separation \(Self.distanceText(distance))"
            latestWeatherDuration = nil
            diagnostics.updateWeather(
                forecast,
                provider: weatherProvider.diagnosticName,
                trigger: latestWeatherTrigger,
                outcome: latestWeatherOutcome,
                durationSeconds: nil,
                cacheStatus: latestWeatherCacheStatus
            )
            diagnostics.record(
                category: .cache,
                outcome: .reused,
                title: "Weather fallback",
                detail: "Live request failed; retained the \(Self.durationText(age))-old cached forecast."
            )
            guard let cached = makePresentation(
                from: forecast,
                at: currentTime,
                cachedAge: age,
                isRefreshing: false
            ) else {
                state = fallbackState
                return
            }
            state = .result(cached)
        case .expired(_, let age, _):
            diagnostics.record(
                category: .cache,
                outcome: .rejected,
                title: "Weather fallback",
                detail: "The saved forecast expired at age \(Self.durationText(age))."
            )
            state = expiredState
        case .unavailable(let reason):
            diagnostics.record(
                category: .cache,
                outcome: .rejected,
                title: "Weather fallback",
                detail: Self.weatherCacheReason(reason)
            )
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
            diagnostics.record(
                category: .evaluation,
                outcome: .failed,
                title: "Forecast evaluation",
                detail: "Timezone or remaining-day coverage requirements were not met."
            )
            return nil
        }
        let periods = periodEngine.periods(for: evaluation)
        guard !periods.isEmpty else {
            diagnostics.record(
                category: .evaluation,
                outcome: .failed,
                title: "Period generation",
                detail: "No displayable periods were produced."
            )
            return nil
        }
        diagnostics.updateEvaluation(forecast: forecast, evaluation: evaluation, periods: periods)
        diagnostics.record(
            category: .evaluation,
            outcome: .success,
            title: "Recommendation periods",
            detail: "Evaluated \(evaluation.hours.count) remaining hours into \(periods.count) period(s)."
        )

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

    private func recordLocationFailure(_ detail: String, startedAt: Date) {
        diagnostics.record(
            category: .error,
            outcome: .failed,
            title: "Location request",
            detail: detail,
            durationSeconds: max(0, now().timeIntervalSince(startedAt))
        )
    }

    private func recordWeatherFailure(_ detail: String, startedAt: Date) {
        diagnostics.record(
            category: .error,
            outcome: .failed,
            title: "Weather request",
            detail: detail,
            durationSeconds: max(0, now().timeIntervalSince(startedAt))
        )
    }

    private static func locationCacheReason(_ reason: LocationCacheRejectionReason) -> String {
        switch reason {
        case .missing: "No saved location exists."
        case .malformed: "The saved location could not be decoded."
        case .invalidCoordinate: "The saved coordinate is invalid."
        case .missingAccuracy: "The saved location has no accuracy value."
        case .inadequateAccuracy(let accuracy): "Accuracy \(distanceText(accuracy)) exceeds the accepted limit."
        case .futureTimestamp(let age): "The saved timestamp is in the future (age \(durationText(age)))."
        case .stale(let age): "The saved location is stale at age \(durationText(age))."
        }
    }

    private static func weatherCacheReason(_ reason: WeatherCacheRejectionReason) -> String {
        switch reason {
        case .missing: "No saved forecast exists."
        case .malformed: "The saved forecast could not be decoded."
        case .invalidRequestedLocation: "The requested location is invalid."
        case .invalidStructure: "The saved forecast structure is invalid."
        case .inadequateDayCoverage: "The saved forecast does not cover the remaining local day."
        case .locationMismatch(let distance): "The saved forecast location is too far away (\(distanceText(distance)))."
        case .futureTimestamp(let age): "The saved forecast timestamp is in the future (age \(durationText(age)))."
        }
    }

    private static func weatherErrorText(_ error: any Error) -> String {
        switch error as? WeatherProviderError {
        case .network: "Network failure"
        case .unauthorized: "Provider authorization failure"
        case .timedOut: "Request timed out"
        case .cancelled: "Request cancelled"
        case .unavailable: "Provider unavailable"
        case nil: String(describing: error)
        }
    }

    private static func accuracyText(_ accuracy: Double?) -> String {
        guard let accuracy, accuracy.isFinite else { return "unavailable accuracy" }
        return "\(distanceText(accuracy)) accuracy"
    }

    private static func distanceText(_ meters: Double) -> String {
        guard meters.isFinite else { return "non-finite distance" }
        return "\(meters.formatted(.number.precision(.fractionLength(0...1)))) m"
    }

    private static func durationText(_ seconds: TimeInterval) -> String {
        "\(seconds.formatted(.number.precision(.fractionLength(0...2)))) s"
    }
}

nonisolated private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

@MainActor
private extension RecommendationViewModel.State {
    var result: DailyRecommendationPresentation? {
        guard case .result(let result) = self else { return nil }
        return result
    }
}
