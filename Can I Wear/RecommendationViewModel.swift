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
    let weatherFetchedAt: Date
    let isUsingSavedWeather: Bool
    let isRefreshing: Bool
    let refreshFailed: Bool
    let refreshAvailableAt: Date
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
    private(set) var locality: String?
    private(set) var retryAvailableAt: Date?
    let diagnostics: DebugDiagnostics

    private let locationProvider: any LocationProvider
    private let weatherProvider: any WeatherProvider
    private let dailyEngine: DailyRecommendationEngine
    private let periodEngine: DayPeriodEngine
    private let locationCache: LocationCache
    private let weatherCache: WeatherCache
    private let reuseConfig: ReusePolicyConfig
    private let localityResolver: any LocalityResolving
    private let now: @Sendable () -> Date
    private let sleep: Sleep
    private let isLifecycleManaged: Bool
    private var latestLocation: LocationReading?
    private var latestLocationSource = "Unavailable"
    private var latestLocationCacheStatus = "Unavailable"
    private var latestForecast: NormalizedForecast?
    private var latestWeatherTrigger = "Unavailable"
    private var latestWeatherOutcome = "Unavailable"
    private var latestWeatherCacheStatus = "Unavailable"
    private var latestWeatherDuration: TimeInterval?
    private var isRequestInFlight = false
    private var localityLocation: LocationIdentity?
    private var routineRefreshAttemptedForForecast: Date?
    private var expiryRefreshAttemptedForForecast: Date?
    private var refreshFailureCooldownUntil: Date?

    private enum LoadTrigger: Equatable {
        case initial
        case automatic
        case manual
        case retry

        var diagnosticText: String {
            switch self {
            case .initial: "App load"
            case .automatic: "Automatic refresh"
            case .manual: "Pull-to-refresh"
            case .retry: "Retry"
            }
        }
    }

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
        localityResolver: (any LocalityResolving)? = nil,
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
        self.localityResolver = localityResolver ?? SystemLocalityResolver()
        self.now = now
        self.sleep = sleep
        isLifecycleManaged = initialState == .idle
        state = initialState
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        await performLoad(trigger: .initial, forceLiveWeather: false)
    }

    func appBecameActive() async {
        refreshDebugSetting()

        if state == .idle {
            await performLoad(trigger: .initial, forceLiveWeather: false)
            return
        }

        if latestForecast != nil {
            await automaticRefreshIfNeeded()
        } else if isLifecycleManaged,
                  retryAvailableAt.map({ $0 <= now() }) ?? true {
            await performLoad(trigger: .automatic, forceLiveWeather: true)
        }
    }

    func monitorAutomaticRefreshes() async {
        while !Task.isCancelled {
            guard let actionDate = nextAutomaticActionDate else { return }
            let delay = max(0, actionDate.timeIntervalSince(now()))
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await automaticRefreshIfNeeded()
        }
    }

    func manualRefresh() async {
        guard !isRequestInFlight else {
            recordRefreshBlocked(title: "Manual refresh blocked", detail: "A weather request is already running.")
            return
        }
        guard let forecast = latestForecast else {
            recordRefreshBlocked(title: "Manual refresh blocked", detail: "No displayed forecast is available to refresh.")
            return
        }

        let currentTime = now()
        if let cooldown = refreshFailureCooldownUntil, cooldown > currentTime {
            recordRefreshBlocked(
                title: "Manual refresh blocked",
                detail: "Available in \(Self.countdownText(cooldown.timeIntervalSince(currentTime))) after the previous failure."
            )
            return
        }

        let age = max(0, currentTime.timeIntervalSince(forecast.metadata.fetchedAt))
        guard age >= reuseConfig.weatherRefreshInterval else {
            let remaining = reuseConfig.weatherRefreshInterval - age
            recordRefreshBlocked(
                title: "Manual refresh blocked",
                detail: "Weather is current; refresh is available in \(Self.countdownText(remaining))."
            )
            return
        }

        diagnostics.record(
            category: .weather,
            outcome: .started,
            title: "Manual refresh started",
            detail: "The user pulled down to request current weather."
        )
        await performLoad(trigger: .manual, forceLiveWeather: true)
    }

    func retry() async {
        guard !isRequestInFlight else {
            recordRefreshBlocked(title: "Retry blocked", detail: "A request is already running.")
            return
        }
        let currentTime = now()
        if let retryAvailableAt, retryAvailableAt > currentTime {
            recordRefreshBlocked(
                title: "Retry blocked",
                detail: "Available in \(Self.countdownText(retryAvailableAt.timeIntervalSince(currentTime)))."
            )
            return
        }

        diagnostics.record(
            category: .session,
            outcome: .started,
            title: "Retry requested",
            detail: "The user requested a new location and weather attempt."
        )
        await performLoad(trigger: .retry, forceLiveWeather: true)
    }

    func canRetry(at date: Date) -> Bool {
        !isRequestInFlight && (retryAvailableAt.map { $0 <= date } ?? true)
    }

    func retryCountdown(at date: Date) -> Int? {
        guard let retryAvailableAt, retryAvailableAt > date else { return nil }
        return max(1, Int(ceil(retryAvailableAt.timeIntervalSince(date))))
    }

    private func performLoad(trigger: LoadTrigger, forceLiveWeather: Bool) async {
        guard !isRequestInFlight else { return }
        isRequestInFlight = true
        defer { isRequestInFlight = false }

        if let current = state.result,
           now().timeIntervalSince(current.weatherFetchedAt) <= reuseConfig.weatherFreshness {
            state = .result(DailyRecommendationPresentation(
                periods: current.periods,
                weatherFetchedAt: current.weatherFetchedAt,
                isUsingSavedWeather: true,
                isRefreshing: true,
                refreshFailed: false,
                refreshAvailableAt: current.refreshAvailableAt
            ))
        } else {
            state = .loading
        }
        diagnostics.record(
            category: .session,
            outcome: .started,
            title: "Recommendation load",
            detail: "\(trigger.diagnosticText) requested."
        )

        let location: LocationReading
        switch await locationCache.lookup(at: now()) {
        case .valid(let cachedLocation, let age):
            location = cachedLocation
            latestLocation = cachedLocation
            latestLocationSource = "Location cache"
            latestLocationCacheStatus = "Reused: fresh and sufficiently accurate"
            resolveLocality(for: cachedLocation.identity)
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
                latestLocationCacheStatus = "New reading • \(Self.shortLocationCacheReason(reason))"
                resolveLocality(for: location.identity)
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
                finishLocationFailure(.locationPermissionDenied, trigger: trigger)
                return
            } catch LocationProviderError.cancelled {
                recordLocationFailure("Request cancelled", startedAt: startedAt)
                finishLocationFailure(.idle, trigger: trigger)
                return
            } catch {
                recordLocationFailure("\(error)", startedAt: startedAt)
                finishLocationFailure(.locationUnavailable, trigger: trigger)
                return
            }
        }

        let cache = await cachedWeather(for: location.identity)
        var fallback: CachedWeather?
        switch cache {
        case .usable(let cached):
            fallback = cached
            let shouldFetch = forceLiveWeather
                || cached.age >= reuseConfig.weatherRefreshInterval
            if !shouldFetch {
                latestForecast = cached.forecast
                latestWeatherTrigger = "Cache policy"
                latestWeatherOutcome = "Refresh skipped"
                latestWeatherCacheStatus = "Used; \(Self.ageText(cached.age)) old; refresh skipped"
                latestWeatherDuration = nil
                diagnostics.updateWeather(
                    cached.forecast,
                    provider: weatherProvider.diagnosticName,
                    trigger: latestWeatherTrigger,
                    outcome: latestWeatherOutcome,
                    durationSeconds: nil,
                    cacheStatus: latestWeatherCacheStatus
                )
                diagnostics.record(
                    category: .cache,
                    outcome: .reused,
                    title: "Weather cache used",
                    detail: "\(Self.ageText(cached.age)) old; refresh skipped because weather is current for \(Self.ageText(reuseConfig.weatherRefreshInterval))."
                )
                guard let presentation = makePresentation(
                    from: cached.forecast,
                    at: now(),
                    isUsingSavedWeather: true,
                    isRefreshing: false,
                    refreshFailed: false
                ) else {
                    state = .forecastIncomplete
                    return
                }
                state = .result(presentation)
                return
            }

            if let presentation = makePresentation(
                from: cached.forecast,
                at: now(),
                isUsingSavedWeather: true,
                isRefreshing: true,
                refreshFailed: false
            ) {
                state = .result(presentation)
            }
            diagnostics.record(
                category: .cache,
                outcome: .reused,
                title: "Weather cache used",
                detail: "\(Self.ageText(cached.age)) old; \(trigger == .manual ? "manual" : "background") refresh started."
            )
        case .expired:
            state = .loading
        case .unavailable:
            if state.result == nil { state = .loading }
        }

        markRefreshAttempt(forecast: fallback?.forecast)

        let liveForecast: NormalizedForecast
        let weatherStartedAt = now()
        diagnostics.record(
            category: .weather,
            outcome: .started,
            title: "Weather request",
            detail: "\(trigger.diagnosticText) requested live weather. Timeout: \(Self.durationText(reuseConfig.weatherRequestTimeout.timeInterval))."
        )
        do {
            liveForecast = try await fetchLiveForecast(for: location.identity)
        } catch WeatherProviderError.cancelled {
            recordWeatherFailure("Request cancelled", startedAt: weatherStartedAt)
            finishWeatherFailure(
                fallback: fallback,
                otherwise: .idle,
                whenExpired: .idle,
                trigger: trigger
            )
            return
        } catch {
            recordWeatherFailure(Self.weatherErrorText(error), startedAt: weatherStartedAt)
            finishWeatherFailure(
                fallback: fallback,
                otherwise: .weatherUnavailable,
                whenExpired: cache.isExpired ? .weatherDataExpired : .weatherUnavailable,
                trigger: trigger
            )
            return
        }

        let weatherDuration = max(0, now().timeIntervalSince(weatherStartedAt))
        latestForecast = liveForecast
        latestWeatherTrigger = "Live refresh after location resolution"
        latestWeatherOutcome = "Success"
        latestWeatherCacheStatus = "Live response; saved after successful evaluation"
        latestWeatherDuration = weatherDuration
        refreshFailureCooldownUntil = nil
        retryAvailableAt = nil
        routineRefreshAttemptedForForecast = nil
        expiryRefreshAttemptedForForecast = nil
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
            isUsingSavedWeather: false,
            isRefreshing: false,
            refreshFailed: false
        ) else {
            finishWeatherFailure(
                fallback: fallback,
                otherwise: .forecastIncomplete,
                whenExpired: .forecastIncomplete,
                trigger: trigger
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
                isUsingSavedWeather: state.result?.isUsingSavedWeather ?? false,
                isRefreshing: state.result?.isRefreshing ?? false,
                refreshFailed: state.result?.refreshFailed ?? false
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

    private struct CachedWeather {
        let forecast: NormalizedForecast
        let age: TimeInterval
    }

    private enum CachedWeatherLookup {
        case usable(CachedWeather)
        case expired
        case unavailable

        var isExpired: Bool {
            if case .expired = self { return true }
            return false
        }
    }

    private func cachedWeather(for location: LocationIdentity) async -> CachedWeatherLookup {
        let currentTime = now()
        switch await weatherCache.diagnosticLookup(
            at: currentTime,
            for: location
        ) {
        case .valid(let forecast, let age, let distance):
            latestForecast = forecast
            latestWeatherTrigger = "Cache policy"
            latestWeatherOutcome = "Usable saved forecast"
            latestWeatherCacheStatus = "\(Self.ageText(age)) old; location separation \(Self.distanceText(distance))"
            latestWeatherDuration = nil
            diagnostics.updateWeather(
                forecast,
                provider: weatherProvider.diagnosticName,
                trigger: latestWeatherTrigger,
                outcome: latestWeatherOutcome,
                durationSeconds: nil,
                cacheStatus: latestWeatherCacheStatus
            )
            return .usable(CachedWeather(forecast: forecast, age: age))
        case .expired(_, let age, let distance):
            diagnostics.record(
                category: .cache,
                outcome: .rejected,
                title: "Weather cache",
                detail: "Rejected at \(Self.ageText(age)) old because the \(Self.ageText(reuseConfig.weatherFreshness)) usable limit was exceeded; location separation \(Self.distanceText(distance))."
            )
            return .expired
        case .unavailable(let reason):
            diagnostics.record(
                category: .cache,
                outcome: .rejected,
                title: "Weather cache",
                detail: Self.weatherCacheReason(reason)
            )
            return .unavailable
        }
    }

    private func finishWeatherFailure(
        fallback: CachedWeather?,
        otherwise fallbackState: State,
        whenExpired expiredState: State,
        trigger: LoadTrigger
    ) {
        let currentTime = now()
        if let fallback {
            let age = max(0, currentTime.timeIntervalSince(fallback.forecast.metadata.fetchedAt))
            guard age <= reuseConfig.weatherFreshness else {
                diagnostics.record(
                    category: .cache,
                    outcome: .rejected,
                    title: "Weather fallback",
                    detail: "The saved forecast crossed the \(Self.ageText(reuseConfig.weatherFreshness)) limit while the request was running."
                )
                applyRetryCooldownIfNeeded(for: trigger)
                state = expiredState
                return
            }

            refreshFailureCooldownUntil = currentTime.addingTimeInterval(reuseConfig.failedRequestCooldown)
            latestForecast = fallback.forecast
            latestWeatherTrigger = "Fallback after live request failure"
            latestWeatherOutcome = "Reused cached forecast"
            latestWeatherCacheStatus = "Refresh failed; using \(Self.ageText(age))-old saved weather"
            latestWeatherDuration = nil
            diagnostics.updateWeather(
                fallback.forecast,
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
                detail: "Refresh failed; retained the \(Self.ageText(age))-old saved forecast. Manual refresh is available again in \(Self.countdownText(reuseConfig.failedRequestCooldown))."
            )
            guard let cached = makePresentation(
                from: fallback.forecast,
                at: currentTime,
                isUsingSavedWeather: true,
                isRefreshing: false,
                refreshFailed: true
            ) else {
                state = fallbackState
                return
            }
            state = .result(cached)
            return
        }

        applyRetryCooldownIfNeeded(for: trigger)
        state = expiredState
    }

    private func makePresentation(
        from forecast: NormalizedForecast,
        at currentTime: Date,
        isUsingSavedWeather: Bool,
        isRefreshing: Bool,
        refreshFailed: Bool
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
            weatherFetchedAt: forecast.metadata.fetchedAt,
            isUsingSavedWeather: isUsingSavedWeather,
            isRefreshing: isRefreshing,
            refreshFailed: refreshFailed,
            refreshAvailableAt: max(
                forecast.metadata.fetchedAt.addingTimeInterval(reuseConfig.weatherRefreshInterval),
                refreshFailureCooldownUntil ?? .distantPast
            )
        )
    }

    private func automaticRefreshIfNeeded() async {
        guard !isRequestInFlight, let forecast = latestForecast else { return }
        let currentTime = now()
        let age = max(0, currentTime.timeIntervalSince(forecast.metadata.fetchedAt))
        guard age >= reuseConfig.weatherRefreshInterval else { return }
        if let cooldown = refreshFailureCooldownUntil, cooldown > currentTime, age < reuseConfig.weatherFreshness {
            return
        }

        if age >= reuseConfig.weatherFreshness {
            if expiryRefreshAttemptedForForecast == forecast.metadata.fetchedAt {
                if age > reuseConfig.weatherFreshness {
                    diagnostics.record(
                        category: .cache,
                        outcome: .rejected,
                        title: "Weather recommendation expired",
                        detail: "The displayed saved forecast crossed the \(Self.ageText(reuseConfig.weatherFreshness)) usable limit."
                    )
                    state = .weatherDataExpired
                }
                return
            }
        } else {
            guard routineRefreshAttemptedForForecast != forecast.metadata.fetchedAt else { return }
        }
        await performLoad(trigger: .automatic, forceLiveWeather: true)
    }

    private var nextAutomaticActionDate: Date? {
        guard let forecast = latestForecast, state.result != nil else { return nil }
        let fetchedAt = forecast.metadata.fetchedAt
        let currentTime = now()
        let refreshDate = fetchedAt.addingTimeInterval(reuseConfig.weatherRefreshInterval)
        let expiryDate = fetchedAt.addingTimeInterval(reuseConfig.weatherFreshness)

        if currentTime < refreshDate { return refreshDate }
        if currentTime < expiryDate {
            if routineRefreshAttemptedForForecast != fetchedAt {
                return max(currentTime, refreshFailureCooldownUntil ?? .distantPast)
            }
            return expiryDate
        }
        if expiryRefreshAttemptedForForecast == fetchedAt {
            return currentTime <= expiryDate
                ? expiryDate.addingTimeInterval(0.001)
                : currentTime
        }
        return currentTime
    }

    private func markRefreshAttempt(forecast: NormalizedForecast?) {
        guard let forecast else { return }
        let age = max(0, now().timeIntervalSince(forecast.metadata.fetchedAt))
        if age >= reuseConfig.weatherFreshness {
            expiryRefreshAttemptedForForecast = forecast.metadata.fetchedAt
        } else {
            routineRefreshAttemptedForForecast = forecast.metadata.fetchedAt
        }
    }

    private func finishLocationFailure(_ failureState: State, trigger: LoadTrigger) {
        guard let forecast = latestForecast,
              now().timeIntervalSince(forecast.metadata.fetchedAt) <= reuseConfig.weatherFreshness,
              let current = state.result
        else {
            applyRetryCooldownIfNeeded(for: trigger)
            state = failureState
            return
        }

        refreshFailureCooldownUntil = now().addingTimeInterval(reuseConfig.failedRequestCooldown)
        state = .result(DailyRecommendationPresentation(
            periods: current.periods,
            weatherFetchedAt: current.weatherFetchedAt,
            isUsingSavedWeather: true,
            isRefreshing: false,
            refreshFailed: true,
            refreshAvailableAt: refreshFailureCooldownUntil ?? current.refreshAvailableAt
        ))
    }

    private func applyRetryCooldownIfNeeded(for trigger: LoadTrigger) {
        guard trigger == .retry else { return }
        retryAvailableAt = now().addingTimeInterval(reuseConfig.failedRequestCooldown)
        diagnostics.record(
            category: .session,
            outcome: .rejected,
            title: "Retry cooldown",
            detail: "Another retry is available in \(Self.countdownText(reuseConfig.failedRequestCooldown))."
        )
    }

    private func recordRefreshBlocked(title: String, detail: String) {
        diagnostics.record(
            category: .weather,
            outcome: .rejected,
            title: title,
            detail: detail
        )
    }

    private func resolveLocality(for location: LocationIdentity) {
        guard localityLocation != location else { return }
        localityLocation = location
        Task { [weak self, localityResolver] in
            let resolved = await localityResolver.locality(for: location)
            guard let self, self.localityLocation == location else { return }
            self.locality = resolved
        }
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

    private static func shortLocationCacheReason(_ reason: LocationCacheRejectionReason) -> String {
        switch reason {
        case .missing: "No saved location"
        case .malformed: "Saved location unreadable"
        case .invalidCoordinate: "Saved coordinate invalid"
        case .missingAccuracy: "Saved accuracy missing"
        case .inadequateAccuracy: "Saved location too imprecise"
        case .futureTimestamp: "Saved timestamp invalid"
        case .stale: "Saved location expired"
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

    private static func ageText(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        if minutes < 1 { return "less than 1 minute" }
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    private static func countdownText(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(max(1, Int(ceil(seconds)))) seconds"
        }
        let minutes = max(1, Int(ceil(seconds / 60)))
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
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
